//! Bounded v3 startup body. Fields borrow the payload, with duplicate rejection
//! before account selection. Session settings are validated by their owner.
const std = @import("std");
const pg = @import("root.zig");
const g = pg.gateway;
const Self = @This();
pub const maximum_bytes = 8192;
pub const max_parameters = 16;
pub const Parameter = struct { name: []const u8, value: []const u8 };
minor: u16,
parameters: [max_parameters]Parameter = undefined,
count: u8 = 0,
pub fn decode(code: u32, payload: []const u8) !Self {
    if (code >> 16 != 3) return error.UnsupportedProtocolVersion;
    if (payload.len > maximum_bytes - 8) return error.FrameTooLarge;
    var result: Self = .{ .minor = @truncate(code) };
    var reader: g.Bytes = .{ .bytes = payload };
    while (true) {
        const name = try reader.cstring(63);
        if (name.len == 0) break;
        if (result.count == max_parameters) return error.TooManyStartupOptions;
        const value = try reader.cstring(256);
        if (!std.unicode.utf8ValidateSlice(name) or !std.unicode.utf8ValidateSlice(value)) return error.InvalidWireText;
        if (result.get(name) != null) return error.DuplicateStartupOption;
        result.parameters[result.count] = .{ .name = name, .value = value };
        result.count += 1;
    }
    try reader.finish();
    const user = result.get("user") orelse return error.MissingStartupAccount;
    if (user.len == 0 or user.len > g.Limits.max_name_bytes) return error.InvalidStartupAccount;
    if (result.get("database")) |selected| if (selected.len == 0 or selected.len > g.Limits.max_name_bytes) return error.InvalidStartupDatabase;
    return result;
}
pub fn get(self: *const Self, name: []const u8) ?[]const u8 {
    for (self.parameters[0..self.count]) |parameter| if (std.mem.eql(u8, name, parameter.name)) return parameter.value;
    return null;
}
pub fn database(self: *const Self) []const u8 {
    return self.get("database") orelse self.get("user").?;
}
pub const Owned = struct {
    allocator: std.mem.Allocator,
    code: u32,
    payload: []u8,
    pub fn deinit(self: *Owned) void {
        self.allocator.free(self.payload);
        self.* = undefined;
    }
};
pub fn read(allocator: std.mem.Allocator, transport: anytype) !Owned {
    var header: [8]u8 = undefined;
    try transport.readExact(&header);
    const length = std.mem.readInt(u32, header[0..4], .big);
    if (length < 8 or length > maximum_bytes) return error.InvalidStartupLength;
    const code = std.mem.readInt(u32, header[4..8], .big);
    if ((code == pg.Frame.ssl_request or code == pg.Frame.gss_request) and length != 8) return error.InvalidUpgradeRequest;
    if (code == pg.Frame.cancel_request and length != 16) return error.InvalidCancelRequest;
    const payload = try allocator.alloc(u8, length - 8);
    errdefer allocator.free(payload);
    try transport.readExact(payload);
    return .{ .allocator = allocator, .code = code, .payload = payload };
}
test "startup selects a bounded explicit account and rejects duplicates and ambiguous endings" {
    const t = std.testing;
    const parsed = try decode(196610, "user\x00alice\x00database\x00tables\x00client_encoding\x00UTF8\x00\x00");
    try t.expectEqual(@as(u16, 2), parsed.minor);
    try t.expectEqualStrings("tables", parsed.database());
    try t.expectEqualStrings("alice", (try decode(196608, "user\x00alice\x00\x00")).database());
    try t.expectError(error.DuplicateStartupOption, decode(196608, "user\x00alice\x00user\x00bob\x00\x00"));
    try t.expectError(error.InvalidWireMessage, decode(196608, "user\x00alice\x00\x00x"));
    try t.expectError(error.MissingStartupAccount, decode(196608, "database\x00tables\x00\x00"));
    try t.expectError(error.UnsupportedProtocolVersion, decode(131072, "user\x00alice\x00\x00"));
    try t.expectError(error.InvalidStartupAccount, decode(196608, "user\x00\x00\x00"));
}
