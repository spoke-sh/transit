//! Connector callers preserve the saved typed request and original identity.
//! Returning a pending reservation is not command completion or dispatch.
const std = @import("std");
const c = @import("root.zig");
pub const Action = c.DirectSource.Action;
pub const Result = c.DirectSource.Result;
pub const Saved = struct {
    definition: c.protocol.Growth.Definition,
    connection: c.DirectTableProtocol.Connection,
    request: c.DirectSource.Request,
    pub fn validate(self: Saved, allocator: std.mem.Allocator) !void {
        if (self.definition != c.protocol.Growth.current_definition) return error.IncompatibleDefinition;
        try self.connection.validate();
        try (Action{ .declaration = .{ .request = self.request, .command = .inspect } }).validate(allocator, self.connection);
    }
    pub fn decode(allocator: std.mem.Allocator, bytes: []const u8) !std.json.Parsed(Saved) {
        const parsed = try c.protocol.Json.parseFromSliceOwned(Saved, allocator, bytes);
        errdefer parsed.deinit();
        try parsed.value.validate(allocator);
        return parsed;
    }
    pub fn requireCaller(self: Saved, caller: c.DirectTableClient) !void {
        try self.validate(caller.allocator);
        if (!std.meta.eql(self.connection, caller.connection)) return error.DataIdentityConflict;
    }
};
pub fn apply(output: *std.heap.ArenaAllocator, caller: c.DirectTableClient, action: Action) !Result {
    var response = try caller.call(.{ .source = action });
    defer response.deinit();
    if (response.value.result != .source) return error.InvalidTableResponse;
    const value = response.value.result.source;
    try c.DirectSource.validateResult(caller.allocator, caller.connection, action, value);
    const bytes = try c.protocol.Json.valueAlloc(caller.allocator, value);
    defer caller.allocator.free(bytes);
    return std.json.parseFromSliceLeaky(Result, output.allocator(), bytes, .{ .allocate = .alloc_always });
}

test "SOURCE saved caller request owns text after input reuse at full width" {
    const t = std.testing;
    const p = c.protocol;
    const scope: c.Model.Scope = .{ .realm = 1, .resource = 7, .catalog = 9 };
    const intent: c.DirectSource.Intent = .{ .kind = .connection, .namespace = 1, .name = try .init("upstream"), .action = .{ .create = .{ .owner = 0, .payload = .{ .connection = .{ .endpoint = "https://example.com" } } } } };
    const saved: Saved = .{
        .definition = p.Growth.current_definition,
        .connection = .{ .scope = scope, .audience = 19, .principal = p.max_counter - 7, .branch = 1, .role = null },
        .request = .{ .binding = .{
            .definition = p.Growth.current_definition,
            .identity = .{ .scope = scope, .principal = p.max_counter - 7, .operation = p.max_counter - 9 },
            .target = .{ .scope = scope, .branch = 1, .object = p.max_counter - 3 },
            .action = .create,
            .expected_definition = null,
            .expected_data = null,
            .intent = try intent.digest(t.allocator),
        }, .intent = intent },
    };
    const bytes = try p.Json.valueAlloc(t.allocator, saved);
    defer t.allocator.free(bytes);
    const decoded = try Saved.decode(t.allocator, bytes);
    defer decoded.deinit();
    @memset(bytes, 0);
    try decoded.value.validate(t.allocator);
    try t.expectEqualDeep(saved, decoded.value);
    try t.expectEqualStrings("https://example.com", decoded.value.request.intent.action.create.payload.connection.endpoint);
}
