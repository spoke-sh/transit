//! Shared public JSON messages for HTTP control, fetch SSE and WebSocket v1.
const root = @import("root.zig");
const r = root.ReactiveModel;
pub const Bootstrap = struct {
    pub const json_schema_fields = .{ .version = .{ .@"const" = 1 } };
    version: u8 = 1,
    attach: r.SignedSend,
    read: r.SignedRead,
};
pub const ClientMessage = union(enum) {
    attach: Bootstrap,
    command: r.SignedSend,
    control: r.SignedSend,
    read: r.SignedRead,
};
pub const Terminal = enum { denied, expired, fenced, reset_required, interrupted, invalid_message, capacity };
pub const Challenge = struct {
    pub const json_schema_fields = .{ .version = .{ .@"const" = 1 } };
    version: u8 = 1,
    nonce: [16]u8,
    valid_for_ms: u32 = 2000,
};
pub const Heartbeat = struct {
    pub const json_schema_fields = .{ .version = .{ .@"const" = 1 } };
    version: u8 = 1,
};
pub const ServerMessage = union(enum) {
    challenge: Challenge,
    attached: struct { session: u64, generation: u64, attachment: u64 },
    receipt: root.Adapter.Receipt,
    observation: root.ReactiveAdapter.Response,
    event: struct { cursor: r.Cursor, event: root.ReactiveAdapter.Event },
    heartbeat: Heartbeat,
    terminal: struct { reason: Terminal },
};
pub fn terminal(err: anyerror) Terminal {
    return switch (err) {
        error.AccessDenied, error.ServingDenied, error.SignatureVerificationFailed => .denied,
        error.ResourceUnavailable, error.ReactiveSessionExpired => .expired,
        error.ReactiveAttachmentConflict, error.ReactiveGenerationConflict, error.ReactiveSubscriptionConflict => .fenced,
        error.UnsupportedReactiveSource, error.ReactiveResetRequired, error.ServiceUnpublished => .reset_required,
        error.ReactiveCapacity, error.ServingCallerCapacity => .capacity,
        error.InvalidJsonShape, error.InvalidJsonConstant, error.InvalidReactiveScope, error.InvalidReactiveCursor, error.InvalidServingCommand, error.DuplicateField, error.SyntaxError, error.UnexpectedToken, error.UnknownField, error.MissingField, error.InvalidEnumTag => .invalid_message,
        else => .interrupted,
    };
}
/// Only controls which release/renew existing work enter the reserved HTTP pool.
/// Neither publication nor new command/session admission may consume it.
pub fn isControl(command: root.Model.Command) bool {
    if (command != .reactive) return false;
    return switch (command.reactive) {
        .renew, .unsubscribe, .close, .expire, .observe_clock => true,
        else => false,
    };
}
