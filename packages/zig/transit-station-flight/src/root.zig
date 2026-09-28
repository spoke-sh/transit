//! Flight construction and interpretation over the existing recorded RPC boundary.
//! No sockets, credentials, retries or independent persistence live here.
const std = @import("std");
pub const flight = @import("transit_flight");
pub const rpc = @import("transit_station_grpc");
pub const Replay = @import("Replay.zig");
pub const Call = struct {
    request: rpc.Request,
    /// Borrows the caller's fixed output buffer until RequestRecord is staged.
    message: []const u8,
    pub fn prepare(self: Call, resource: u64, namespace: u64, endpoint_revision: u64, deadline: u64, attempts: u32, metadata_buffer: []u8, batch_buffer: []u8) !rpc.RequestRecord.Prepared {
        return rpc.RequestRecord.prepare(resource, namespace, self.request, &.{self.message}, endpoint_revision, deadline, attempts, metadata_buffer, batch_buffer);
    }
};
fn encoded(descriptor: *const rpc.transport.Descriptor, comptime name: []const u8, value: anytype, metadata: []const rpc.Request.Entry, output: []u8) !Call {
    const method = try descriptor.method(flight.method_prefix ++ name);
    const expected: rpc.Shape = if (std.mem.eql(u8, name, "DoGet")) .server_streaming else .unary;
    if (method.shape != expected) return error.InvalidFlightDescriptor;
    const request: rpc.Request = .{ .method = method.path, .shape = method.shape, .descriptor_digest = method.descriptor_digest, .metadata = metadata };
    try request.validate();
    const size = try flight.grpc.protobuf.encodeInto(output[0..@min(output.len, 16384)], value, .{});
    return .{ .request = request, .message = output[0..size] };
}
pub fn get(descriptor: *const rpc.transport.Descriptor, ticket: []const u8, metadata: []const rpc.Request.Entry, output: []u8) !Call {
    if (ticket.len == 0 or ticket.len > 8192) return error.InvalidFlightTicket;
    return encoded(descriptor, "DoGet", flight.Wire.Ticket{ .ticket = ticket }, metadata, output);
}
pub fn info(descriptor: *const rpc.transport.Descriptor, command: flight.Wire.FlightDescriptor, metadata: []const rpc.Request.Entry, output: []u8) !Call {
    return encoded(descriptor, "GetFlightInfo", command, metadata, output);
}
pub fn schema(descriptor: *const rpc.transport.Descriptor, command: flight.Wire.FlightDescriptor, metadata: []const rpc.Request.Entry, output: []u8) !Call {
    return encoded(descriptor, "GetSchema", command, metadata, output);
}
test {
    _ = Replay;
}
