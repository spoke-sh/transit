//! Finite durable RPC adapter. Publication/capture do not grant dispatch.
pub const exchange = @import("transit_exchange");
pub const transport = @import("transit_grpc");
pub const Shape = transport.Shape;
pub const Request = @import("Request.zig");
pub const Batch = @import("Batch.zig");
pub const RequestRecord = @import("RequestRecord.zig");
pub const Policy = @import("Policy.zig");
pub const Metadata = @import("Metadata.zig");
pub const Capture = @import("Capture.zig");
pub const Replay = @import("Replay.zig");
pub const protocol_format: u32 = 2;
test {
    _ = @import("request_test.zig");
    _ = @import("capture_test.zig");
}
