//! Independent-peer transport proof; dispatch authority is qualified separately.
const std = @import("std");
const http = @import("transport_under_test");
const t = std.testing;
const Gate = struct {
    io: std.Io,
    path: []const u8,
    calls: u32 = 0,
    exited: bool = false,
    fn check(context: *anyopaque) !void {
        const self: *Gate = @ptrCast(@alignCast(context));
        self.calls += 1;
        defer self.exited = true;
        if (std.mem.eql(u8, self.path, "/gate-revoked")) return error.DispatchRevoked;
        if (std.mem.eql(u8, self.path, "/gate-timeout")) try self.io.sleep(.fromSeconds(60), .awake);
    }
};
const Collector = struct {
    hash: std.crypto.hash.sha2.Sha256 = .init(.{}),
    bytes: usize = 0,
    calls: usize = 0,
    fail: bool = false,
    fail_terminal: bool = false,
    completed: bool = false,
    fn capture(raw: *anyopaque, kind: http.Kind, bytes: []const u8) !void {
        const self: *Collector = @ptrCast(@alignCast(raw));
        if (self.fail or (self.fail_terminal and std.mem.eql(u8, @tagName(kind), "completion"))) return error.CaptureUnavailable;
        try t.expect(bytes.len <= http.Transport.segment_bytes);
        try t.expect(std.mem.indexOf(u8, bytes, "fixture-secret") == null);
        if (kind == .response_body) {
            self.hash.update(bytes);
            self.bytes += bytes.len;
        }
        self.calls += 1;
        if (std.mem.eql(u8, @tagName(kind), "completion")) self.completed = true;
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
    var collector: Collector = .{ .fail = std.mem.eql(u8, args[2], "/capture-failure"), .fail_terminal = std.mem.eql(u8, args[2], "/terminal-capture-failure") };
    var gate: Gate = .{ .io = init.io, .path = args[2] };
    const gated = std.mem.startsWith(u8, args[2], "/gate-");
    var capture: http.Transport.Capture = .{ .context = &collector, .segment = Collector.capture };
    if (@hasField(http.Transport.Capture, "complete")) {
        const Callback = struct {
            fn complete(raw: *anyopaque, report: http.Transport.Report) !void {
                const collected: *Collector = @ptrCast(@alignCast(raw));
                if (collected.fail or collected.fail_terminal) return error.CaptureUnavailable;
                try t.expectEqual(collected.bytes, report.completion.response_bytes);
                try t.expectEqual(@as(u64, 12), report.completion.request_bytes);
                try t.expect(report.completion.heads > 0);
                try t.expect(report.timing.started_ms > 0);
                collected.completed = true;
            }
        };
        capture.complete = Callback.complete;
    }
    const result = http.Transport.execute(init.gpa, init.io, endpoint, request, &body, null, capture, if (gated) .{ .context = &gate, .check = Gate.check } else null);
    var output_buffer: [4096]u8 = undefined;
    var output = std.Io.File.stdout().writerStreaming(init.io, &output_buffer);
    if (result) |r| {
        try output.interface.print("{{\"status\":{d},\"bytes\":{d},\"omitted\":{d},\"sha256\":\"{x}\"", .{ r.status, r.bytes, r.omitted_headers, collector.hash.finalResult() });
    } else |err| try output.interface.print("{{\"error\":\"{s}\",\"captured\":{d},\"completed\":{}", .{ @errorName(err), collector.bytes, collector.completed });
    if (gated) try output.interface.print(",\"gate_calls\":{d},\"gate_exited\":{}", .{ gate.calls, gate.exited });
    try output.interface.writeAll("}\n");
    try output.interface.flush();
}
