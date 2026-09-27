//! Finite durable RPC adapter. Publication/capture do not grant dispatch.
pub const exchange = @import("transit_exchange");
pub const transport = @import("transit_grpc");
pub const Shape = transport.Shape;
pub const Request = @import("Request.zig");
pub const Batch = @import("Batch.zig");
pub const RequestRecord = @import("RequestRecord.zig");
pub const protocol_format: u32 = 2;
test {
    _ = @import("request_test.zig");
}
