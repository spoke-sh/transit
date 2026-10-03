//! Request-local adapter evidence. Reads never settle an earlier command, and
//! only the native submission boundary can mark a command attempt uncertain.
const std = @import("std");
const root = @import("root.zig");
const p = root.protocol;
const d = p.Diagnostic;
pub const Reason = enum { denied, closed, expired, fenced, reset_required, not_found, conflict, pending, unavailable, capacity, invalid_request, internal_failure };
pub const Class = struct { code: []const u8, reason: Reason, category: d.Category, status: u16, message: []const u8 };
pub fn classification(cause: anyerror) Class {
    return switch (cause) {
        error.ReactiveChallengeTimeout => .{ .code = "reactive.challenge_timeout", .reason = .invalid_request, .category = .lifecycle, .status = 408, .message = "No complete authenticated attachment arrived within the 2000 millisecond WebSocket challenge deadline. This connection submitted no attachment. Open another connection for a fresh challenge; earlier saved work retains its own outcome." },
        error.HttpDeadline => .{ .code = "serving.transport_deadline", .reason = .unavailable, .category = .unavailable, .status = 504, .message = "The transport task exceeded its deadline. This interruption does not establish whether earlier work was admitted or completed. Inspect the exact saved work under current authority." },
        error.InvalidServingCommand => .{ .code = "serving.invalid_command", .reason = .invalid_request, .category = .syntax, .status = 400, .message = "The serving command payload is truncated, malformed or invalid for this operation. Correct its fields using the current command contract before submitting it. No native command was dispatched by this decoding attempt." },
        error.ReadAccessUnavailable => .{ .code = "serving.read_access_unavailable", .reason = .unavailable, .category = .unsupported, .status = 503, .message = "The authority does not expose the required resource read-access capability. This host cannot establish current scoped read permission. Check matching host and authority contracts before enabling Follow." },
        error.WebSocketProtocol => .{ .code = "reactive.websocket_protocol", .reason = .invalid_request, .category = .syntax, .status = 400, .message = "The WebSocket frame violates the masking, opcode, length, fragmentation or control-frame rules. Use the declared RFC 6455 text profile. Closing the socket does not cancel accepted work." },
        error.WebSocketBinaryUnsupported => .{ .code = "reactive.websocket_binary", .reason = .invalid_request, .category = .unsupported, .status = 400, .message = "This WebSocket interface accepts UTF-8 JSON text messages. Binary messages are unsupported. Preserve any earlier signed command whose receipt is unknown." },
        error.WebSocketInvalidUtf8 => .{ .code = "reactive.websocket_utf8", .reason = .invalid_request, .category = .syntax, .status = 400, .message = "The assembled WebSocket text or close reason contains invalid UTF-8. No complete message can be interpreted. Socket failure does not settle an earlier command." },
        error.WebSocketMessageTooLarge => .{ .code = "reactive.websocket_limit", .reason = .invalid_request, .category = .limit, .status = 413, .message = "The WebSocket message exceeds 8192 bytes or 32 fragments. No complete message can be accepted in this profile. Keep exact signed recovery bytes for earlier submissions." },
        error.ServingDenied, error.AccessDenied, error.QueryDenied, error.SignatureVerificationFailed => .{ .code = "serving.access_denied", .reason = .denied, .category = .access, .status = 403, .message = "Current authority or signature validation denied this request. Check the caller, service and resource scope. This observation does not settle earlier accepted commands." },
        error.ReactiveSessionClosed => .{ .code = "reactive.session_closed", .reason = .closed, .category = .lifecycle, .status = 410, .message = "The session is explicitly closed. It cannot attach, renew or produce another live snapshot. Previously accepted application commands and selected queries retain their independent outcomes." },
        error.ReactiveSessionExpired => .{ .code = "reactive.session_expired", .reason = .expired, .category = .lifecycle, .status = 410, .message = "The session lease deadline was reached or expiry was recorded. Inspect its exact session state before explicitly opening another session. Expiry does not cancel previously accepted application work." },
        error.ReactiveAttachmentConflict => .{ .code = "reactive.attachment_conflict", .reason = .fenced, .category = .conflict, .status = 409, .message = "The attachment generation or challenge does not match the current session attachment. Recover the exact pending attachment and inspect its committed state before attaching again." },
        error.ReactiveGenerationConflict, error.RefreshGenerationConflict => .{ .code = "reactive.generation_conflict", .reason = .fenced, .category = .conflict, .status = 409, .message = "The requested session or Follow generation differs from the retained owner generation. Inspect the original control disposition and current generation; an older response cannot replace newer work." },
        error.ReactiveSubscriptionConflict => .{ .code = "reactive.subscription_conflict", .reason = .fenced, .category = .conflict, .status = 409, .message = "The subscription identity or generation differs from the current session subscription. Inspect the original subscription control before preparing any successor." },
        error.ReactiveResetRequired => .{ .code = "reactive.source_changed", .reason = .reset_required, .category = .conflict, .status = 409, .message = "The watch declaration, schema or progress basis no longer matches this read or cursor. No replacement coverage was established. Acquire a new authorized snapshot explicitly; retain earlier command identities." },
        error.UnsupportedReactiveSource => .{ .code = "reactive.unsupported_source", .reason = .reset_required, .category = .unsupported, .status = 409, .message = "This watch supports an int64 Table value column. The acquired source does not have that shape. Review its declaration before explicitly acquiring another snapshot." },
        error.InvalidReactiveProgress => .{ .code = "reactive.invalid_progress", .reason = .reset_required, .category = .integrity, .status = 409, .message = "The watch progress marker is invalid for the acquired source revision. No continuity or replacement coverage was established. Inspect the application owner's progress update and source basis." },
        error.ServingOperationNotFound, error.ReactiveSessionNotFound, error.RefreshNotFound, error.TableNotFound => .{ .code = "serving.object_absent", .reason = .not_found, .category = .lifecycle, .status = 404, .message = "The requested operation, session, Follow view or Table was absent in this authorized observation. Inspect the exact original identity and any saved input receipt; absence does not prove an uncertain command was never admitted." },
        error.ServiceUnpublished => .{ .code = "serving.unpublished", .reason = .reset_required, .category = .lifecycle, .status = 409, .message = "The required service or watch publication is absent, unpublished or targets another source. Inspect the accepted declarations. This read establishes no replacement coverage or application outcome." },
        error.ServingResultPending => .{ .code = "serving.result_not_completed", .reason = .pending, .category = .lifecycle, .status = 409, .message = "The selected operation has no completed reply to return. Inspect its exact status: admission, cancellation, timeout and failed result delivery are distinct. Do not submit the application command again to obtain a result." },
        error.ServingSequenceConflict => .{ .code = "serving.sequence_conflict", .reason = .conflict, .category = .conflict, .status = 409, .message = "Native sequence or exact-retry identity validation rejected the submitted command. Preserve its original bytes and inspect its native receipt and domain status before preparing another sequence." },
        error.ServiceReadConflict => .{ .code = "serving.read_conflict", .reason = .conflict, .category = .conflict, .status = 409, .message = "The resource cut, selected namespace or service policy changed during the bounded read. No complete observation is available. Retry the read under current rights; this does not authorize repeating a command." },
        error.ResourceUnavailable, error.QuerySourceUnavailable, error.ResultUnavailable => .{ .code = "serving.resource_unavailable", .reason = .unavailable, .category = .unavailable, .status = 410, .message = "A required process, source or retained result is unavailable. This is not evidence of session expiry, permission revocation or command completion. Inspect the original resource and saved work under current authority." },
        error.PublicationNotPublished => .{ .code = "serving.result_unpublished", .reason = .unavailable, .category = .lifecycle, .status = 409, .message = "The required result publication is not complete. Partial publication does not establish a usable result. Inspect the exact query or operation before reading again." },
        error.ClockUnavailable => .{ .code = "reactive.clock_unavailable", .reason = .unavailable, .category = .unavailable, .status = 503, .message = "The host has no usable observer clock within its allowed freshness and clock-error bounds. It cannot establish a new lease or live-read validity. Inspect the clock observer; do not infer expiry or renew from a local guess." },
        error.ServingCallerCapacity, error.ReactiveCapacity => .{ .code = "serving.caller_capacity", .reason = .capacity, .category = .limit, .status = 429, .message = "The finite caller or session capacity is occupied. Preserve pending signed work and use reserved recovery controls. Capacity pressure does not expire sessions or cancel accepted commands." },
        error.AuthorityTimeout => .{ .code = "serving.authority_timeout", .reason = .unavailable, .category = .unavailable, .status = 504, .message = "The authority did not complete this attempt before its deadline. A failed read gives no command outcome. Preserve any saved signed work and its exact identity." },
        error.AuthorityUnavailable, error.OutOfMemory, error.ConnectionResetByPeer, error.ConnectionRefused, error.BrokenPipe, error.EndOfStream, error.Canceled => .{ .code = "serving.attempt_unavailable", .reason = .unavailable, .category = .unavailable, .status = 503, .message = "This attempt was interrupted or could not obtain bounded resources. A failed read does not settle pending application work. Preserve exact command identities and retry only the applicable read or saved submission." },
        error.Rejected, error.Conflict => .{ .code = "serving.native_rejection", .reason = .conflict, .category = .conflict, .status = 409, .message = "The native authority rejected this attempt. Inspect the native cause and current scope. A query rejection from the authority does not establish a terminal outcome for an earlier application command." },
        error.StreamTooLong, error.MessageTooLarge, error.ValueTooLarge, error.ServingPayloadTooLarge => .{ .code = "serving.request_too_large", .reason = .invalid_request, .category = .limit, .status = 413, .message = "The request exceeds the finite message or inline-payload bound for this interface. Check the operation's declared byte limit. This failure cannot establish the outcome of an earlier saved command." },
        error.WebSocketHandshake, error.InvalidJsonShape, error.InvalidJsonConstant, error.InvalidReactiveScope, error.InvalidReactiveCursor, error.InvalidServingRead, error.InvalidServingIdentity, error.InvalidFrame, error.UnsupportedFrame, error.InvalidCorrelation, error.InvalidValue, error.InvalidSequence, error.WrongProtocolRealm, error.InvalidCharacter, error.Overflow, error.DuplicateField, error.SyntaxError, error.UnexpectedToken, error.UnknownField, error.MissingField, error.InvalidEnumTag => .{ .code = "serving.invalid_request", .reason = .invalid_request, .category = .syntax, .status = 400, .message = "The request does not match this interface's fields, types, scope, signature framing or value bounds. Inspect the original cause and current generated contract. Preserve any earlier uncertain signed work." },
        error.InvalidServingRecord, error.InvalidServingReceipt, error.InvalidAuthorityResponse => .{ .code = "serving.invalid_evidence", .reason = .internal_failure, .category = .integrity, .status = 502, .message = "The host received invalid stored or authority evidence. It cannot establish a complete observation. Preserve saved identities and report the original cause; do not infer empty state, rollback or successful completion." },
        else => .{ .code = "serving.adapter_internal_failure", .reason = .internal_failure, .category = .internal, .status = 503, .message = "The serving adapter could not complete this attempt. Preserve the original cause and any saved signed work for inspection. This failure does not establish an application outcome." },
    };
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
    pub fn label(self: *Attempt, mode: @FieldType(Attempt, "mode"), operation: []const u8) !void {
        self.mode = mode;
        self.operation = try d.Code.init(operation);
    }
    pub fn rejected(self: *Attempt, cause: anyerror, native: ?p.ErrorCode) void {
        self.native_cause = native;
        self.authority_rejected = native != null and (cause == error.Rejected or cause == error.Conflict or cause == error.AccessDenied);
    }
    pub fn project(self: Attempt, cause: anyerror) !d {
        const info = classification(cause);
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
        if (self.native_cause) |native| try result.text(.native_cause, .authority, @tagName(native));
        if (self.receipt) |input| try result.fact(.native_input, .authority, .{ .unsigned = .init(input) });
        if (self.dispatched) {
            try result.action(.inspect_status);
            if (self.receipt == null and !self.authority_rejected and self.identity != null) try result.action(.resume_exact);
        } else switch (info.category) {
            .access => try result.action(.inspect_scope),
            .syntax, .binding, .unsupported => try result.action(.correct_input),
            .internal, .integrity => try result.action(.contact_operator),
            .unavailable, .conflict => if (self.mode == .read and info.reason != .reset_required and info.reason != .fenced) try result.action(.retry_read),
            else => {},
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
