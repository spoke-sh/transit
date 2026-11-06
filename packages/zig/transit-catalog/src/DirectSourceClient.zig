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
