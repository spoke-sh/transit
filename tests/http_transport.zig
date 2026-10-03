//! Independent-peer transport proof; dispatch authority is qualified separately.
const std = @import("std");
const http = @import("transit_station_http");
const t = std.testing;
const Collector = struct {
    hash: std.crypto.hash.sha2.Sha256 = .init(.{}),
    bytes: usize = 0,
    calls: usize = 0,
    fail: bool = false,
    completed: bool = false,
    fn capture(raw: *anyopaque, kind: http.Kind, bytes: []const u8) !void {
        const self: *Collector = @ptrCast(@alignCast(raw));
        if (self.fail) return error.CaptureUnavailable;
        try t.expect(bytes.len <= http.Transport.segment_bytes);
        try t.expect(std.mem.indexOf(u8, bytes, "fixture-secret") == null);
        if (kind == .response_body) {
            self.hash.update(bytes);
            self.bytes += bytes.len;
        }
        self.calls += 1;
        if (kind == .completion) self.completed = true;
    }
};
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 5) return error.ExpectedPortPathTlsCa;
    var endpoint: http.Transport.Endpoint = .{ .host = "localhost", .address = "127.0.0.1", .port = try std.fmt.parseInt(u16, args[1], 10), .tls = !std.mem.eql(u8, args[3], "plain"), .timeout_ms = 1000 };
    if (endpoint.tls) endpoint.ca_file = args[4];
    if (std.mem.eql(u8, args[2], "/wrong-host")) endpoint.host = "wrong.test";
    if (std.mem.eql(u8, args[2], "/pinned-name")) endpoint.host = "http-pin.invalid";
    if (std.mem.eql(u8, args[2], "/dns-address")) endpoint.address = "localhost";
    if (std.mem.eql(u8, args[2], "/small")) endpoint.response_bytes = 8;
    var body: std.Io.Reader = .fixed("request-body");
    const request: http.Request = .{ .method = .POST, .target = &.{.{ .literal = args[2] }}, .body_bytes = 12, .headers = &.{ .{ .name = "X-Order", .value = &.{.{ .literal = "first" }} }, .{ .name = "X-Order", .value = &.{.{ .literal = "second" }} } } };
    var collector: Collector = .{ .fail = std.mem.eql(u8, args[2], "/capture-failure") };
    const result = http.Transport.execute(init.gpa, init.io, endpoint, request, &body, null, .{ .context = &collector, .segment = Collector.capture });
    var output_buffer: [4096]u8 = undefined;
    var output = std.Io.File.stdout().writerStreaming(init.io, &output_buffer);
    if (result) |r| {
        try output.interface.print("{{\"status\":{d},\"bytes\":{d},\"omitted\":{d},\"sha256\":\"{x}\"}}\n", .{ r.status, r.bytes, r.omitted_headers, collector.hash.finalResult() });
    } else |err| try output.interface.print("{{\"error\":\"{s}\",\"captured\":{d},\"completed\":{}}}\n", .{ @errorName(err), collector.bytes, collector.completed });
    try output.interface.flush();
}
