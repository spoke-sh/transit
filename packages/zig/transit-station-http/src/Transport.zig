//! Durable HTTP capture adapter. Network mechanics have no Exchange/Station dependency.
const std = @import("std");
const http = @import("root.zig");
const transport = @import("transit_http").Transport;
pub const Endpoint = transport.Endpoint;
pub const Result = transport.Result;
pub const WriteGate = transport.WriteGate;
pub const segment_bytes = transport.segment_bytes;
pub const captureHeaders = transport.captureHeaders;
pub const Capture = struct {
    context: *anyopaque,
    /// Return only after the bytes are durably sealed. Failure leaves the remote
    /// outcome uncertain and prevents transport from reporting completion.
    segment: *const fn (*anyopaque, http.Kind, []const u8) anyerror!void,

    fn emit(raw: *anyopaque, kind: transport.Kind, bytes: []const u8) !void {
        const self: *const Capture = @ptrCast(@alignCast(raw));
        const recorded: http.Kind = switch (kind) {
            .response_head => .response_head,
            .response_body => .response_body,
            .response_trailers => .response_trailers,
        };
        try self.segment(self.context, recorded, bytes);
    }
    fn complete(raw: *anyopaque, report: transport.Report) !void {
        const self: *const Capture = @ptrCast(@alignCast(raw));
        inline for (.{ .{ http.Kind.timing, report.timing }, .{ http.Kind.omission, report.omission }, .{ http.Kind.completion, report.completion } }) |item| {
            const bytes = try http.exchange.codec.encode(item[1]);
            try self.segment(self.context, item[0], bytes.slice());
        }
    }
};

pub fn execute(gpa: std.mem.Allocator, io: std.Io, endpoint: Endpoint, request: http.Request, body: *std.Io.Reader, secrets: ?http.Request.Resolver, capture: Capture, gate: ?WriteGate) !Result {
    var adapter = capture;
    return transport.execute(gpa, io, endpoint, request, body, secrets, .{ .context = &adapter, .segment = Capture.emit, .complete = Capture.complete }, gate);
}

test "durable adapter seals unchanged terminal records and stops at capture failure" {
    const t = std.testing;
    const Collector = struct {
        kinds: [3]http.Kind = undefined,
        records: [3]http.exchange.p.Value = undefined,
        count: usize = 0,
        fail_at: ?usize = null,
        fn segment(raw: *anyopaque, kind: http.Kind, bytes: []const u8) !void {
            const self: *@This() = @ptrCast(@alignCast(raw));
            if (self.fail_at == self.count) return error.CaptureUnavailable;
            if (self.count == self.records.len) return error.UnexpectedCapture;
            self.kinds[self.count] = kind;
            self.records[self.count] = try http.exchange.p.Value.init(bytes);
            self.count += 1;
        }
    };
    const report: transport.Report = .{
        .timing = .{ .started_ms = 7, .elapsed_ns = 19 },
        .omission = .{ .response_headers = 1, .request_secrets = 2 },
        .completion = .{ .status = 200, .request_bytes = 4, .response_bytes = 513, .heads = 2, .framing = .length },
    };
    var collected: Collector = .{};
    var adapter: Capture = .{ .context = &collected, .segment = Collector.segment };
    try Capture.complete(&adapter, report);
    try t.expectEqualSlices(http.Kind, &.{ .timing, .omission, .completion }, &collected.kinds);
    // Independent literal wire vectors, including little-endian widths and tags.
    try t.expectEqualSlices(u8, "HTT1\x07\x00\x00\x00\x00\x00\x00\x00\x13\x00\x00\x00\x00\x00\x00\x00", collected.records[0].slice());
    try t.expectEqualSlices(u8, "HTO1\x01\x00\x00\x00\x02\x00\x00\x00", collected.records[1].slice());
    try t.expectEqualSlices(u8, "HTC1\xc8\x00\x04\x00\x00\x00\x00\x00\x00\x00\x01\x02\x00\x00\x00\x00\x00\x00\x02\x02", collected.records[2].slice());
    for (0..3) |index| {
        collected = .{ .fail_at = index };
        try t.expectError(error.CaptureUnavailable, Capture.complete(&adapter, report));
        try t.expectEqual(index, collected.count);
    }
}
