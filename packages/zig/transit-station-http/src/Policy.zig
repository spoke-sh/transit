//! Pure endpoint-policy decisions. A returned reference records a decision; it
//! cannot dispatch, prove remote idempotency or renew an exchange's budget.
const std = @import("std");
const http = @import("root.zig");
pub const Reason = http.exchange.Exchange.FollowupReason;
pub const Reference = struct {
    id: u64,
    revision: u64,
    pub fn validate(self: Reference) !void {
        if (self.id == 0 or self.revision == 0) return error.HttpFollowupNotGranted;
    }
};
pub const Retry = struct { id: u64, revision: u64, key_header: []const u8 };
pub const Action = struct { id: u64, revision: u64, method: std.http.Method, target: []const u8 };
pub const Prepared = struct {
    version: u32 = 1,
    endpoint_revision: u64,
    host: []const u8,
    address: []const u8,
    port: u16,
    tls: bool,
    timeout_ms: u32,
    request_bytes: u64,
    response_bytes: u64,
    response_headers: []const []const u8,
    trust_digest: ?[32]u8,
    retry_policy: ?Retry = null,
    redirect_policy: ?Reference = null,
    reconcile_policy: ?Action = null,
    cancel_policy: ?Action = null,
    request: http.Request,
    pub fn selected(self: Prepared, reason: Reason) !Reference {
        const result: Reference = switch (reason) {
            .retry => if (self.retry_policy) |p| .{ .id = p.id, .revision = p.revision } else return error.HttpFollowupNotGranted,
            .redirect => self.redirect_policy orelse return error.HttpFollowupNotGranted,
            .reconcile => if (self.reconcile_policy) |p| .{ .id = p.id, .revision = p.revision } else return error.HttpFollowupNotGranted,
            .cancel => if (self.cancel_policy) |p| .{ .id = p.id, .revision = p.revision } else return error.HttpFollowupNotGranted,
        };
        try result.validate();
        return result;
    }
};
/// Parent capture/kernel disposition and body equality are checked by the worker.
/// This function permits only the declared request change under frozen scope.
pub fn followup(gpa: std.mem.Allocator, reason: Reason, parent: Prepared, next: Prepared, status: ?u16, location: ?[]const u8) !Reference {
    var head: [http.Request.maximum_head_bytes]u8 = undefined;
    _ = try next.request.render(next.host, next.port, &head, null, false);
    const selected = try parent.selected(reason);
    var expected = parent;
    switch (reason) {
        .retry => {
            const policy = parent.retry_policy.?;
            try http.validateHeader(policy.key_header, "");
            var count: usize = 0;
            for (next.request.headers) |header| if (std.ascii.eqlIgnoreCase(header.name, policy.key_header)) {
                count += 1;
                if (header.value.len != 1 or header.value[0] != .literal or header.value[0].literal.len == 0 or header.value[0].literal.len > 128) return error.InvalidHttpIdempotencyKey;
            };
            if (count != 1) return error.InvalidHttpIdempotencyKey;
        },
        .redirect => {
            const code = status orelse return error.HttpRedirectNotCaptured;
            if (code != 301 and code != 302 and code != 303 and code != 307 and code != 308) return error.HttpRedirectNotCaptured;
            // Keep methods and bytes. Ambiguous legacy POST-to-GET rewrites are
            // outside this finite profile; 307/308 explicitly preserve methods.
            if (code != 307 and code != 308 and parent.request.method != .GET and parent.request.method != .HEAD) return error.UnsupportedHttpRedirect;
            const target = location orelse return error.HttpReplayGap;
            if (!std.mem.startsWith(u8, target, "/") or std.mem.startsWith(u8, target, "//")) return error.HttpRedirectScope;
            if (next.request.target.len != 1 or next.request.target[0] != .literal or !std.mem.eql(u8, next.request.target[0].literal, target)) return error.HttpRedirectChanged;
            expected.request.target = next.request.target;
        },
        .reconcile, .cancel => {
            const action = if (reason == .reconcile) parent.reconcile_policy.? else parent.cancel_policy.?;
            if (reason == .reconcile and action.method != .GET and action.method != .HEAD) return error.UnsupportedHttpReconciliation;
            if (reason == .cancel and action.method != .POST and action.method != .DELETE) return error.UnsupportedHttpCancellation;
            if (next.request.target.len != 1 or next.request.target[0] != .literal or !std.mem.eql(u8, next.request.target[0].literal, action.target)) return error.HttpFollowupTargetChanged;
            expected.request.target = next.request.target;
            expected.request.method = action.method;
            expected.request.body_bytes = 0;
        },
    }
    const before = try std.json.Stringify.valueAlloc(gpa, expected, .{});
    defer gpa.free(before);
    const after = try std.json.Stringify.valueAlloc(gpa, next, .{});
    defer gpa.free(after);
    if (!std.mem.eql(u8, before, after)) return error.HttpFollowupChanged;
    return selected;
}
