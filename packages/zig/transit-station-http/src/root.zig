//! HTTP adapter. Capture is durable Station state; parsing grants no dispatch.
const http = @import("transit_http");
pub const exchange = @import("transit_exchange");
pub const Request = http.Request;
pub const Transport = @import("Transport.zig");
pub const ReplayWithClient = @import("Replay.zig").WithClient;
pub const Replay = ReplayWithClient(exchange.Client);
pub const Policy = @import("Policy.zig");
pub const RequestRecord = @import("RequestRecord.zig");
pub const Service = @import("Service.zig");
pub const Inspection = @import("Inspection.zig");
pub const protocol_format: u32 = 1;
pub const Kind = enum(u32) { request_template = 1, request_head = 2, request_body = 3, response_head = 4, response_body = 5, response_trailers = 6, timing = 7, omission = 8, completion = 9 };
pub const Timing = http.Timing;
pub const Omission = http.Omission;
pub const Completion = http.Completion;

/// Request and body text use the common segment publication/coverage lifecycle.
/// Each call is private until its enclosing fenced turn commits.
pub fn beginSegment(capture: exchange.Exchange, turn: *exchange.station.Turn, ordinal: u32, kind: Kind, bytes: []const u8) !exchange.Publication.Outcome {
    if ((try capture.inspect(turn)).protocol != protocol_format) return error.WrongExchangeProtocol;
    return capture.beginSegment(turn, ordinal, @backingInt(kind), try exchange.Publication.Digest.of(protocol_format, bytes));
}
pub const validateHeader = http.validateHeader;
pub const validateResponse = http.validateResponse;
pub const renderDiagnostic = @import("RequestDiagnostic.zig").render;
test {
    _ = Request;
    _ = Inspection;
    _ = @import("http_test.zig");
    _ = @import("service_test.zig");
    _ = Transport;
}
