//! Request-local adapter evidence. Reads never settle an earlier command, and
//! only the native submission boundary can mark a command attempt uncertain.
const std = @import("std");
const root = @import("root.zig");
const p = root.protocol;
const d = p.Diagnostic;
pub const Reason = enum { denied, closed, expired, fenced, reset_required, not_found, conflict, result_not_completed, unavailable, capacity, invalid_request, internal_failure };
pub const codes = @import("AdapterCodes.zig");
pub const Class = codes.Class;
pub fn classification(cause: anyerror) Class {
    return codes.fromError(cause) orelse .{ .code = "serving.adapter_internal_failure", .reason = .internal_failure, .category = .internal, .status = 503, .message = "The serving adapter could not complete this attempt. Preserve the original cause and any saved signed work for inspection. This failure does not establish an application outcome." };
}
pub const Attempt = struct {
    mode: enum { input, control, read } = .input,
    operation: ?d.Code = null,
    identity: ?d.Identity = null,
    dispatched: bool = false,
    response_started: bool = false,
    receipt: ?u64 = null,
    native_cause: ?p.ErrorCode = null,
    authority_rejected: bool = false,
    input_cause: ?anyerror = null,
    domain_diagnostic: ?d = null,
    pub fn label(self: *Attempt, mode: @FieldType(Attempt, "mode"), operation: []const u8) !void {
        self.mode = mode;
        self.operation = try d.Code.init(operation);
    }
    pub fn rejected(self: *Attempt, cause: anyerror, native: ?p.ErrorCode) void {
        self.native_cause = native;
        self.authority_rejected = native != null and (cause == error.Rejected or cause == error.Conflict or cause == error.AccessDenied);
    }
    pub fn disposition(self: Attempt, cause: anyerror) Class {
        // These declarations are read from stored service/session state. In a
        // control request the same validators instead check caller input.
        if (self.mode == .read and (cause == error.InvalidServiceBinding or cause == error.InvalidServicePolicy or cause == error.InvalidReactiveSource))
            return .{ .code = "serving.invalid_evidence", .reason = .internal_failure, .category = .integrity, .status = 502, .message = "A retained service binding, policy or watch source violates its declared shape or bounds. No complete authorized observation is available. Preserve the selected scope and original cause for inspection; do not replace saved work." };
        return classification(cause);
    }
    pub fn project(self: Attempt, cause: anyerror) !d {
        if (cause == error.ServingResultPending) if (self.domain_diagnostic) |detail| return detail;
        const info = self.disposition(cause);
        var result = if (self.receipt != null)
            try d.init("serving.ingress_accepted", .lifecycle, .submit, .pending, .native_receipt, "The authority accepted this exact native input. Its application or control outcome still requires an authorized disposition/status read. Preserve the original signed work; do not prepare a replacement command.")
        else if (self.dispatched and !self.authority_rejected)
            try d.init("serving.send_unknown", .unavailable, .submit, .unknown, .saved_intent, "Admission of the exact signed command is unknown. Preserve its bytes, signature and sequence. Reconcile that saved submission and its domain status before preparing any new work.")
        else if (self.dispatched)
            try d.init("serving.command_rejected", info.category, .submit, .not_applicable, .none, "The authority rejected this signed command attempt. This is not a terminal application outcome. Preserve the original command and inspect its native cause and exact domain status before preparing new work.")
        else
            try d.init(info.code, info.category, if (self.mode == .read) .read else .input, if (self.mode == .read) .not_applicable else .not_submitted, if (self.mode == .read) .none else .local_before_dispatch, info.message);
        result.cause = try d.Code.init(@errorName(self.input_cause orelse cause));
        result.identity = self.identity;
        if (self.operation) |operation| try result.text(.operation, .caller, operation.slice());
        if (!self.dispatched and cause == error.EndOfStream) try result.absent(.source_kind, .owner, .unrecorded);
        if (self.native_cause) |native| try result.text(.native_cause, .authority, @tagName(native));
        if (self.receipt) |input| try result.fact(.native_input, .authority, .{ .unsigned = .init(input) });
        if (self.dispatched) {
            try result.action(.inspect_status);
            if (self.receipt == null and !self.authority_rejected and self.identity != null) try result.action(.resume_exact);
        } else switch (info.category) {
            .access => try result.action(.inspect_scope),
            .syntax, .binding, .unsupported => try result.action(.correct_input),
            .internal, .integrity => try result.action(.contact_operator),
            .unavailable, .conflict => try result.action(if (self.mode == .read and info.reason != .reset_required and info.reason != .fenced) .retry_read else .inspect_status),
            .lifecycle => try result.action(.inspect_status),
            .limit => try result.action(.inspect_scope),
            .constraint => try result.action(.correct_input),
        }
        try result.validate();
        return result;
    }
};

/// Only command decoding normalizes byte exhaustion to invalid input. An
/// EndOfStream from transport I/O retains its unavailable/uncertain meaning.
pub fn decodeCommand(value: p.Value, attempt: ?*Attempt) !root.Model.Command {
    return root.Model.Command.decode(value) catch |err| {
        if (attempt) |detail| detail.input_cause = err;
        return error.InvalidServingCommand;
    };
}

test "adapter evidence distinguishes read failure, local rejection, unknown send and native receipt" {
    const t = std.testing;
    var attempt: Attempt = .{};
    try t.expectEqual(.not_submitted, (try attempt.project(error.SignatureVerificationFailed)).outcome);
    try attempt.label(.read, "refresh_status");
    try t.expectEqual(.not_applicable, (try attempt.project(error.ResourceUnavailable)).outcome);
    try t.expectEqual(.unavailable, classification(error.ResourceUnavailable).reason);
    try t.expectEqual(.expired, classification(error.ReactiveSessionExpired).reason);
    try t.expectEqual(.closed, classification(error.ReactiveSessionClosed).reason);
    try attempt.label(.control, "submit");
    attempt.identity = .{ .domain = .transport, .id = .init(8), .realm = .init(1), .sequence = .init(8) };
    attempt.dispatched = true;
    try t.expectEqual(.unknown, (try attempt.project(error.AuthorityTimeout)).outcome);
    attempt.rejected(error.AuthorityUnavailable, .HttpCapacity);
    const capacity = try attempt.project(error.AuthorityUnavailable);
    try t.expectEqual(.unknown, capacity.outcome);
    try t.expectEqualStrings("HttpCapacity", capacity.facts[1].?.value.?.text.slice());
    attempt.rejected(error.Conflict, .SequenceGap);
    try t.expectEqual(.not_applicable, (try attempt.project(error.ServingSequenceConflict)).outcome);
    attempt.receipt = 12;
    try t.expectEqual(.pending, (try attempt.project(error.BrokenPipe)).outcome);
}

test "truncated command input cannot become a transport interruption" {
    var attempt: Attempt = .{};
    try std.testing.expectError(error.InvalidServingCommand, decodeCommand(.{}, &attempt));
    const detail = try attempt.project(error.InvalidServingCommand);
    try std.testing.expectEqualStrings("serving.invalid_command", detail.code.slice());
    try std.testing.expectEqual(.not_submitted, detail.outcome);
    try std.testing.expectEqualStrings("EndOfStream", detail.cause.?.slice());
    attempt = .{ .mode = .read };
    const read = try attempt.project(error.EndOfStream);
    try std.testing.expectEqualStrings("serving.attempt_unavailable", read.code.slice());
    try std.testing.expectEqual(.not_applicable, read.outcome);
}

test "every serving adapter cause preserves read input dispatch and receipt evidence" {
    const t = std.testing;
    for (codes.entries) |entry| {
        var attempt: Attempt = .{};
        try attempt.label(.input, "prepare");
        const local = try attempt.project(entry.cause);
        try t.expectEqualStrings(entry.code, local.code.slice());
        try t.expectEqual(entry.category, local.category);
        try t.expectEqual(.not_submitted, local.outcome);
        try t.expectEqual(.local_before_dispatch, local.evidence);
        try attempt.label(.read, "status");
        const read = try attempt.project(entry.cause);
        try t.expectEqual(.not_applicable, read.outcome);
        try t.expectEqual(.none, read.evidence);
        for (read.actions) |slot| if (slot) |action| try t.expect(action.kind != .resume_exact and action.kind != .cancel_mutation and action.kind != .reconcile_effect);
        attempt.identity = .{ .domain = .transport, .id = .init(12), .realm = .init(46), .sequence = .init(12) };
        attempt.dispatched = true;
        const unknown = try attempt.project(entry.cause);
        try t.expectEqual(.unknown, unknown.outcome);
        try t.expectEqual(.saved_intent, unknown.evidence);
        try t.expectEqual(.resume_exact, unknown.actions[1].?.kind);
        try t.expectEqualDeep(attempt.identity, unknown.actions[1].?.target);
        attempt.receipt = 17;
        const admitted = try attempt.project(entry.cause);
        try t.expectEqual(.pending, admitted.outcome);
        try t.expectEqual(.native_receipt, admitted.evidence);
        try t.expectEqual(.inspect_status, admitted.actions[0].?.kind);
        try t.expect(admitted.actions[1] == null);
    }
    const read: Attempt = .{ .mode = .read };
    inline for (.{ error.InvalidServiceBinding, error.InvalidServicePolicy, error.InvalidReactiveSource }) |cause| {
        try t.expectEqual(.integrity, (try read.project(cause)).category);
        try t.expectEqual(@as(u16, 502), read.disposition(cause).status);
        try t.expectEqual(@as(u16, 400), classification(cause).status);
    }
    try t.expectEqual(.unavailable, classification(error.WebSocketConnectionClosed).reason);
    try t.expectEqual(.closed, classification(error.ReactiveSessionClosed).reason);
}
