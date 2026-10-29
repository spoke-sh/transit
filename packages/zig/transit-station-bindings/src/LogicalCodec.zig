//! Ownership/transport boundary for Fuze's pure logical-value codec.
const std = @import("std");
const base = @import("Abi.zig");
pub const model = @import("transit_fuze").LogicalCodec;
pub const Action = model.Action;
pub const Result = model.Result;
pub fn codec(json: [*]const u8, len: usize, out: *?*base.Buffer) callconv(.c) base.Status {
    out.* = null;
    if (len == 0 or len > model.max_request_bytes) return .invalid_argument;
    var arena: std.heap.ArenaAllocator = .init(std.heap.page_allocator);
    defer arena.deinit();
    const bytes = model.execute(arena.allocator(), json[0..len]) catch |err| {
        const status = base.failure(err, out);
        return switch (err) {
            error.IncompatibleDefinition => .incompatible_version,
            error.CodecBudgetExceeded, error.ValueBudgetExceeded, error.TypeBudgetExceeded => .budget_exceeded,
            else => status,
        };
    };
    base.outputEncoded(bytes, out) catch |err| return base.status(err);
    return .ok;
}
test "logical ABI result owns bytes after the call arena is released" {
    const testing = std.testing;
    const input = "{\"capabilities\":{}}";
    var output: ?*base.Buffer = null;
    try testing.expectEqual(.ok, codec(input.ptr, input.len, &output));
    defer base.Api.station_buffer_destroy(output);
    const result = try std.json.parseFromSlice(Result, testing.allocator, base.Api.station_buffer_data(output.?)[0..base.Api.station_buffer_size(output.?)], .{});
    defer result.deinit();
    try testing.expectEqualStrings(@import("transit_fuze").Types.definition, result.value.capabilities.definition);
}
