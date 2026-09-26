//! HTTP adapter. Capture is durable Station state; parsing grants no dispatch.
const std = @import("std");
pub const exchange = @import("transit_exchange");
pub const Request = @import("Request.zig");
pub const Transport = @import("Transport.zig");
pub const protocol_format: u32 = 1;
pub const Kind = enum(u32) { request_template = 1, request_head = 2, request_body = 3, response_head = 4, response_body = 5, response_trailers = 6, timing = 7, omission = 8 };

/// Request and body text use the common segment publication/coverage lifecycle.
/// Each call is private until its enclosing fenced turn commits.
pub fn beginSegment(capture: exchange.Exchange, turn: *exchange.station.GrowingTurn, ordinal: u32, kind: Kind, bytes: []const u8) !exchange.Publication.Outcome {
    if ((try capture.inspect(turn)).protocol != protocol_format) return error.WrongExchangeProtocol;
    return capture.beginSegment(turn, ordinal, @backingInt(kind), try exchange.Publication.Digest.of(protocol_format, bytes));
}
pub fn validateHeader(name: []const u8, value: []const u8) !void {
    if (name.len == 0) return error.InvalidHttpHeader;
    for (name) |b| if (!std.ascii.isAlphanumeric(b) and std.mem.indexOfScalar(u8, "!#$%&'*+-.^_`|~", b) == null) return error.InvalidHttpHeader;
    for (value) |b| if ((b < 32 and b != '\t') or b == 127) return error.InvalidHttpHeader;
}
/// Reject ambiguous framing even where a general-purpose HTTP parser accepts it.
/// Ordered duplicate application headers remain allowed.
pub fn validateResponse(bytes: []const u8) !std.http.Client.Response.Head {
    if (bytes.len > Request.maximum_head_bytes) return error.HttpHeadersOversize;
    if (bytes.len < 15 or bytes[12] != ' ') return error.InvalidHttpFraming;
    for (bytes[9..12]) |b| if (!std.ascii.isDigit(b)) return error.InvalidHttpFraming;
    if (!std.mem.endsWith(u8, bytes, "\r\n\r\n")) return error.InvalidHttpFraming;
    const head = try std.http.Client.Response.Head.parse(bytes);
    if (head.version != .@"HTTP/1.1" or @backingInt(head.status) < 100 or @backingInt(head.status) > 599) return error.UnsupportedHttpResponse;
    var iter = head.iterateHeaders();
    var content_length: bool = false;
    var transfer: bool = false;
    var encoding: bool = false;
    var count: usize = 0;
    while (iter.next()) |field| {
        count += 1;
        if (count > Request.maximum_headers) return error.HttpHeadersOversize;
        try validateHeader(field.name, field.value);
        if (std.ascii.eqlIgnoreCase(field.name, "content-length")) {
            if (content_length or field.value.len == 0) return error.InvalidHttpFraming;
            for (field.value) |b| if (!std.ascii.isDigit(b)) return error.InvalidHttpFraming;
            content_length = true;
        }
        if (std.ascii.eqlIgnoreCase(field.name, "transfer-encoding")) {
            if (transfer or !std.ascii.eqlIgnoreCase(field.value, "chunked")) return error.UnsupportedHttpFraming;
            transfer = true;
        }
        if (std.ascii.eqlIgnoreCase(field.name, "content-encoding")) {
            if (encoding or !std.ascii.eqlIgnoreCase(field.value, "identity")) return error.UnsupportedHttpEncoding;
            encoding = true;
        }
    }
    if (transfer and content_length) return error.InvalidHttpFraming;
    if ((head.status.class() == .informational or head.status == .no_content) and (transfer or content_length)) return error.InvalidHttpFraming;
    return head;
}
test {
    _ = Request;
    _ = @import("http_test.zig");
}
