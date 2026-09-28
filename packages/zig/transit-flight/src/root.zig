//! Flight wire formats and the selected finite Table query adapter.
const std = @import("std");
pub const grpc = @import("transit_grpc");
pub const query = @import("transit_query");
pub const serving = @import("transit_serving");
pub const Wire = @import("Wire.zig");
pub const Ipc = @import("Ipc.zig");
pub const Metadata = @import("Metadata.zig");
pub const Ticket = @import("Ticket.zig");
pub const method_prefix = "/arrow.flight.protocol.FlightService/";
pub const command_prefix = "type.googleapis.com/arrow.flight.protocol.sql.";
test {
    _ = Ipc;
    _ = Ticket;
    _ = Metadata;
}

test "Flight encodes real protobuf field tags with full-width counts" {
    const t = std.testing;
    const value: Wire.FlightInfo = .{ .total_records = -1, .total_bytes = -1, .ordered = true };
    const bytes = try grpc.protobuf.encodeAlloc(t.allocator, value, .{});
    defer t.allocator.free(bytes);
    var decoded = try grpc.protobuf.decode(Wire.FlightInfo, t.allocator, bytes, .{ .max_arena_bytes = 65536 });
    defer decoded.deinit();
    try t.expectEqual(@as(i64, -1), decoded.value.total_records);
    try t.expect(decoded.value.ordered);
}
