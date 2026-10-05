//! Bounded HTTP scheduling hint. It carries no authority or durable cursor.
const std = @import("std");
const p = @import("root.zig").protocol;
const Self = @This();
after: u64,
milliseconds: u32,
pub const max_ms = 1000;
pub fn validate(self: Self) !void {
    if (self.after > p.max_counter or self.milliseconds == 0 or self.milliseconds > max_ms) return error.InvalidWaitHint;
}
pub fn format(self: Self, buffer: []u8) ![]const u8 {
    try self.validate();
    return std.fmt.bufPrint(buffer, "{d}:{d}", .{ self.after, self.milliseconds });
}
pub fn parse(text: []const u8) !Self {
    const colon = std.mem.indexOfScalar(u8, text, ':') orelse return error.InvalidWaitHint;
    const result: Self = .{
        .after = std.fmt.parseInt(u64, text[0..colon], 10) catch return error.InvalidWaitHint,
        .milliseconds = std.fmt.parseInt(u32, text[colon + 1 ..], 10) catch return error.InvalidWaitHint,
    };
    var buffer: [32]u8 = undefined;
    if (!std.mem.eql(u8, text, try result.format(&buffer))) return error.InvalidWaitHint;
    return result;
}
pub fn allows(query: p.Growth.Query) bool {
    return switch (query.kind) {
        .process, .delivery, .outputs => true,
        else => false,
    };
}
test "wait scheduling hints are canonical, bounded and grant no broader query surface" {
    const t = std.testing;
    try t.expectEqualDeep(Self{ .after = p.max_counter, .milliseconds = 1000 }, try parse("9007199254740991:1000"));
    for ([_][]const u8{ "1", "1:0", "1:1001", "-1:1", "+1:1", "01:1", "1:01", "1:1:1", "9007199254740992:1" }) |text|
        try t.expectError(error.InvalidWaitHint, parse(text));
    try t.expect(!allows(.{ .realm = 1, .principal = 1, .kind = .capabilities }));
    try t.expect(allows(.{ .realm = 1, .principal = 1, .kind = .{ .process = 1 } }));
}
