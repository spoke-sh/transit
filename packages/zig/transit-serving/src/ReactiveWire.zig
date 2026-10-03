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
pub const Terminal = enum { denied, closed, expired, fenced, reset_required, interrupted, invalid_message, capacity };
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
    terminal: struct { reason: Terminal, diagnostic: ?root.protocol.Diagnostic = null },
};
/// OpenAPI models an SSE item at the media-type level: data is a JSON string,
/// not the already-decoded ServerMessage used by the application.
pub const SseKind = enum { attached, event, heartbeat, terminal };
pub const SseItem = struct {
    pub const json_schema_fields = .{
        .data = .{ .type = "string", .maxLength = r.max_message_bytes, .contentMediaType = "application/json", .contentSchema = .{ .@"$ref" = "#/components/schemas/ServerMessage" } },
        .id = .{ .type = "string", .pattern = "^(?:[0-9a-f]{2})+$", .maxLength = 512 },
    };
    event: SseKind,
    data: []const u8,
    id: ?[]const u8 = null,
};
pub fn terminal(err: anyerror) Terminal {
    return switch (err) {
        error.AccessDenied, error.ServingDenied, error.QueryDenied, error.SignatureVerificationFailed => .denied,
        error.ReactiveSessionExpired => .expired,
        error.ResourceUnavailable => .interrupted,
        error.ReactiveSessionClosed => .closed,
        error.ReactiveAttachmentConflict, error.ReactiveGenerationConflict, error.ReactiveSubscriptionConflict => .fenced,
        error.UnsupportedReactiveSource, error.ReactiveResetRequired, error.ServiceUnpublished => .reset_required,
        error.ReactiveCapacity, error.ServingCallerCapacity => .capacity,
        error.WebSocketProtocol, error.WebSocketBinaryUnsupported, error.WebSocketInvalidUtf8, error.WebSocketMessageTooLarge, error.InvalidJsonShape, error.InvalidJsonConstant, error.InvalidReactiveScope, error.InvalidReactiveCursor, error.InvalidServingCommand, error.DuplicateField, error.SyntaxError, error.UnexpectedToken, error.UnknownField, error.MissingField, error.InvalidEnumTag => .invalid_message,
        else => .interrupted,
    };
}
/// Only controls which release/renew existing work enter the reserved HTTP pool.
/// Neither publication nor new command/session admission may consume it.
pub fn isControl(command: root.Model.Command) bool {
    if (command == .refresh) return command.refresh == .pause;
    if (command != .reactive) return false;
    return switch (command.reactive) {
        .renew, .unsubscribe, .close, .expire, .observe_clock => true,
        else => false,
    };
}
