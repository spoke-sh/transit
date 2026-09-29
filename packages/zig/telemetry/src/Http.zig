//! Request state has one writer (the handler); read only after cancellation joins.
const std = @import("std");
const t = @import("root.zig");
const Http = @This();
span: t.Span = .{},
route: []const u8 = "unmatched",
method: []const u8 = "OTHER",
status: ?u16 = null,
written: bool = false,
error_type: ?[]const u8 = null,
protocol_outcome: t.ProtocolOutcome = .none,
operation: ?[]const u8 = null,
realm: ?u64 = null,
pid: ?u64 = null,
sequence: ?u64 = null,
position: ?u64 = null,
wait_ns: ?u64 = null,
work_ns: ?u64 = null,
cache_hits: ?u64 = null,
cache_misses: ?u64 = null,

pub fn received(self: *Http, req: *std.http.Server.Request, route: []const u8, trusted_parent: bool) void {
    self.method = @tagName(req.head.method);
    self.route = route;
    if (t.Context.fromRequest(req, trusted_parent)) |parent| {
        // Keep this server span's own identity; only its remote relationship changes.
        if (self.span.context) |*context| {
            context.trace_id = parent.trace_id;
            context.parent_span_id = parent.span_id;
        }
    }
}

pub fn finish(self: *Http, name: []const u8, err: ?anyerror, timed_out: bool, quiet_success: bool) void {
    const status = self.status orelse 0;
    const outcome: t.Outcome = if (timed_out) .timeout else if (err != null or self.status == null) .failed else if (status >= 500) .failed else if (status == 409) .conflict else if (status >= 400) .rejected else .ok;
    self.span.finish(.{
        .name = name,
        .route = self.route,
        .method = self.method,
        .status = self.status,
        .response_written = self.written,
        .outcome = outcome,
        .error_type = self.error_type orelse if (timed_out) "RequestTimeout" else if (err) |e| @errorName(e) else null,
        .level = if (outcome != .ok) .warn else if (quiet_success) .debug else .info,
        .protocol_outcome = self.protocol_outcome,
        .operation = self.operation,
        .realm = self.realm,
        .pid = self.pid,
        .sequence = self.sequence,
        .position = self.position,
        .wait_ns = self.wait_ns,
        .work_ns = self.work_ns,
        .cache_hits = self.cache_hits,
        .cache_misses = self.cache_misses,
    });
}
