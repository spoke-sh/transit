//! Public connector reply projections. Capture status and remote application
//! status are distinct. A reply does not carry the separate capture-failure or
//! native-closure record; absent original detail is explicit, never reconstructed.
const std = @import("std");
const x = @import("root.zig");
const d = x.p.Diagnostic;
pub const Protocol = enum { http, grpc };

pub fn outcome(comptime protocol: Protocol, value: anytype, realm: ?u64) !d {
    try value.validate();
    var buffer: [384]u8 = undefined;
    const prefix = @tagName(protocol);
    const Description = struct { code: []const u8, category: d.Category = .lifecycle, outcome: d.Outcome, message: []const u8 };
    const description: Description = switch (value.phase) {
        .observed => .{
            .code = if (protocol == .http) switch (value.status / 100) {
                2 => "http.response_observed",
                3 => "http.redirect_observed",
                4 => "http.client_error_observed",
                5 => "http.server_error_observed",
                else => unreachable,
            } else grpc_codes[value.status],
            .outcome = .completed,
            .message = if (protocol == .http)
                try std.fmt.bufPrint(&buffer, "HTTP peer returned {d} {s}. The response capture is complete. HTTP status does not establish application rollback or make a new request safe.", .{ value.status, @as(std.http.Status, @fromBackingInt(@intCast(value.status))).phrase() orelse "(unregistered status)" })
            else
                try std.fmt.bufPrint(&buffer, "gRPC peer returned {d} ({s}). The response capture is complete. Protocol status does not prove business success, rollback or permission to retry.", .{ value.status, grpc_names[value.status] }),
        },
        .closed_unknown => .{ .code = prefix ++ ".remote_outcome_unknown", .outcome = .closed_unknown, .message = "The exchange closed without a known remote outcome. The request may have run. Inspect its retained capture failure, native effect and connector policy before further work; closure does not permit a fresh retry." },
        .not_dispatched => .{ .code = prefix ++ ".not_dispatched", .outcome = .not_dispatched, .message = "The exchange settled without an authorized dispatch attempt. No remote request was dispatched for this exchange. This does not cancel other exchanges or establish their outcomes." },
    };
    var result = try d.init(description.code, description.category, .reconcile, description.outcome, .domain_status, description.message);
    result.identity = .{ .domain = .exchange, .id = .init(value.exchange), .resource = .init(value.resource), .realm = if (realm) |r| .init(r) else null };
    try result.text(.operation, .owner, prefix);
    if (value.effect != 0) try result.fact(.native_effect, .execution, .{ .unsigned = .init(value.effect) }) else try result.absent(.native_effect, .execution, .inapplicable);
    if (value.attempt != 0) try result.fact(.attempt, .execution, .{ .unsigned = .init(value.attempt) }) else try result.absent(.attempt, .execution, .inapplicable);
    if (value.phase == .observed) {
        try result.fact(.protocol_status, .execution, .{ .unsigned = .init(value.status) });
        try result.fact(.completion, .execution, .{ .boolean = true });
        try result.fact(.source_basis, .execution, .{ .digest = value.chain });
    } else {
        try result.absent(.protocol_status, .execution, if (value.phase == .not_dispatched) .inapplicable else .unrecorded);
        try result.absent(.resolution_reason, .execution, .unrecorded);
        try result.absent(.native_cause, .execution, .unrecorded);
        // Unknown native settlement does not establish whether capture completed.
        try result.absent(.completion, .execution, .unrecorded);
    }
    try result.action(.inspect_status);
    try result.validate();
    return result;
}

pub fn rejection(comptime protocol: Protocol, value: anytype) !d {
    try value.validate();
    const prefix = @tagName(protocol);
    const Descriptor = struct { []const u8, d.Category, []const u8 };
    const description: Descriptor = switch (value.reason) {
        .denied => .{ prefix ++ ".request_denied", .access, "The connector rejected this call under its admission or follow-up policy. This rejection does not settle a previous exchange. Inspect current scope and the original exchange before further work." },
        .invalid_request => .{ prefix ++ ".invalid_request", .integrity, "The connector rejected this request. Inspect its recorded validation details; this input rejection does not settle earlier work." },
        .busy => .{ prefix ++ ".exchange_busy", .conflict, "The connector rejected this call because the exchange route is occupied or not ready for the requested control. Inspect the original exchange; this does not cancel or replace it." },
    };
    const rule = validationRule(value.check);
    var quoted_field: [194]u8 = undefined;
    var field_writer: std.Io.Writer = .fixed(&quoted_field);
    try std.json.Stringify.value(value.field[0..value.field_len], .{ .escape_unicode = true }, &field_writer);
    var message: [384]u8 = undefined;
    const summary = if (rule) |text| try std.fmt.bufPrint(&message, "{s} Field: {s}{s}. This input rejection does not settle earlier work.", .{ text, field_writer.buffered(), if (value.field_truncated != 0) " [truncated]" else "" }) else description[2];
    var result = try d.init(description[0], description[1], .admission, .input_rejected, .domain_status, summary);
    try result.text(.operation, .owner, prefix);
    try result.text(.resolution_reason, .execution, @tagName(value.reason));
    if (value.input != 0) {
        try result.fact(.native_input, .execution, .{ .unsigned = .init(value.input) });
        try result.fact(.proposal, .caller, .{ .digest = value.request });
    } else try result.absent(.native_input, .execution, .unrecorded);
    try validationFacts(&result, value);
    try result.action(if (value.reason == .denied) .inspect_scope else .inspect_status);
    try result.validate();
    return result;
}
pub fn validationRule(check: x.AdmissionRejection.Check) ?[]const u8 {
    return switch (check) {
        .unrecorded => null,
        .decode => "The request representation failed validation.",
        .equal => "The supplied value must equal the required value.",
        .maximum => "The supplied value must not exceed the permitted maximum.",
        .different => "The supplied value must differ from the prohibited value.",
        .available => "Required state is not available to this caller.",
        .state => "The recorded exchange state does not permit this operation.",
        .policy => "The request does not satisfy the connector policy.",
        .occupied => "The exchange is already bound to different work.",
        .before => "The observed time must precede the recorded deadline.",
        .mode => "This worker is configured for a different operation.",
    };
}
pub fn validationFacts(result: *d, value: anytype) !void {
    const rule = validationRule(value.check);
    if (value.cause_len != 0) {
        if (value.cause_truncated == 0) result.cause = try d.Code.init(value.cause[0..value.cause_len]);
        try ownedText(result, .native_cause, .execution, value.cause[0..value.cause_len], value.cause_truncated != 0);
    } else try result.absent(.native_cause, .execution, if (value.check == .unrecorded) .unrecorded else .inapplicable);
    if (value.field_len != 0) try ownedText(result, .field_path, .owner, value.field[0..value.field_len], value.field_truncated != 0) else try result.absent(.field_path, .execution, .unrecorded);
    if (rule) |text| try result.text(.constraint, .owner, text);
    inline for (.{ "expected", "actual" }) |name| {
        const field: d.Field = if (comptime std.mem.eql(u8, name, "expected")) .expected_value else .supplied_value;
        const origin: d.Origin = if (comptime std.mem.eql(u8, name, "expected")) .owner else .execution;
        switch (@field(value, name ++ "_kind")) {
            .unrecorded => try result.absent(field, origin, .unrecorded),
            .redacted => try result.absent(field, origin, .withheld),
            .inapplicable => try result.absent(field, origin, .inapplicable),
            .digest => try result.fact(field, origin, .{ .digest = @field(value, name ++ "_text") }),
            .unsigned => try result.fact(field, origin, .{ .unsigned = .init(@field(value, name ++ "_number")) }),
            .text => try ownedText(result, field, origin, @field(value, name ++ "_text")[0..@field(value, name ++ "_len")], @field(value, name ++ "_truncated") != 0),
        }
    }
}
fn ownedText(result: *d, field: d.Field, origin: d.Origin, bytes: []const u8, truncated: bool) !void {
    try result.add(.{ .field = field, .origin = origin, .availability = if (truncated) .truncated else .provided, .value = .{ .text = try d.Text.init(bytes) } });
}

const grpc_names = [_][]const u8{ "OK", "CANCELLED", "UNKNOWN", "INVALID_ARGUMENT", "DEADLINE_EXCEEDED", "NOT_FOUND", "ALREADY_EXISTS", "PERMISSION_DENIED", "RESOURCE_EXHAUSTED", "FAILED_PRECONDITION", "ABORTED", "OUT_OF_RANGE", "UNIMPLEMENTED", "INTERNAL", "UNAVAILABLE", "DATA_LOSS", "UNAUTHENTICATED" };
const grpc_codes = [_][]const u8{ "grpc.ok_observed", "grpc.cancelled_observed", "grpc.unknown_observed", "grpc.invalid_argument_observed", "grpc.deadline_exceeded_observed", "grpc.not_found_observed", "grpc.already_exists_observed", "grpc.permission_denied_observed", "grpc.resource_exhausted_observed", "grpc.failed_precondition_observed", "grpc.aborted_observed", "grpc.out_of_range_observed", "grpc.unimplemented_observed", "grpc.internal_observed", "grpc.unavailable_observed", "grpc.data_loss_observed", "grpc.unauthenticated_observed" };
