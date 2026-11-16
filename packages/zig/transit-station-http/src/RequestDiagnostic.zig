//! Project borrowed HTTP validation into owned, original Station admission evidence.
const http = @import("root.zig");
const Diagnostic = http.Request.Diagnostic;
const Rejection = http.Service.Rejection;
const Admission = http.exchange.AdmissionRejection;

fn scalar(value: Diagnostic.Scalar) Admission.Scalar {
    return switch (value) {
        .unrecorded => .unrecorded,
        .redacted => .redacted,
        .unsigned => |number| .{ .unsigned = number },
        .text => |bytes| .{ .text = bytes },
    };
}
fn record(raw: *anyopaque, check: Diagnostic.Check, field: []const u8, expected: Diagnostic.Scalar, actual: Diagnostic.Scalar, cause: anyerror) void {
    const slot: *?Rejection = @ptrCast(@alignCast(raw));
    if (slot.* != null) return;
    const owned_check: Admission.Check = switch (check) {
        .decode => .decode,
        .maximum => .maximum,
        .different => .different,
        .policy => .policy,
    };
    slot.* = Rejection.detail(.invalid_request, owned_check, field, scalar(expected), scalar(actual), cause);
}

pub fn render(request: http.Request, host: []const u8, port: u16, buffer: []u8, resolver: ?http.Request.Resolver, template: bool, failure: ?*?Rejection) ![]const u8 {
    return request.renderDiagnostic(host, port, buffer, resolver, template, if (failure) |slot| .{ .context = slot, .record = record } else null);
}
