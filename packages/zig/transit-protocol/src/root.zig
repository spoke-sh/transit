//! Public Transit wire contract. No kernel, storage, application, or provider implementation.
const std = @import("std");
pub const Ed25519 = std.crypto.sign.Ed25519;
pub const Runtime = @import("Runtime.zig");
pub const max_principals = 16;
pub const max_processes = 64;
pub const max_effects = 128;
pub const max_effect_observations = 16;
pub const max_outputs = 256;
pub const max_payloads = 16;
pub const max_payload_bytes = 64 * 1024;
pub const max_turn_outputs = 4;
pub const max_counter = (1 << 53) - 1;
pub const max_admission_ceiling = 65536;
pub const max_entry_bytes = 4096;
pub const max_checkpoint_bytes = 1024 * 1024;

pub const Permission = enum(u4) { admin, spawn, send, execute, inspect, effect, publish };
pub const all_permissions: u16 = 0x7f;
pub fn permission(p: Permission) u16 {
    return @as(u16, 1) << @backingInt(p);
}

pub const Grant = struct {
    subject: u8,
    public_key: [32]u8,
    permissions: u16,
    pid: ?u64 = null,
};
pub const Pid = struct { realm: u64, local: u64 };
pub const Effect = struct {
    id: u64,
    pid: u64,
    payload: i64,
    phase: enum { pending, authorized, unknown, observed, cancelled, closed_unknown } = .pending,
    attempt: ?u64 = null,
    executor: ?u8 = null,
    result: ?i64 = null,
    closed_at: ?u64 = null,
    reconcile_before_ms: ?u64 = null,
    max_observations: u16 = max_effect_observations,
    observations: u16 = 0,
};
pub const Output = struct { pid: u64, value: i64 };
/// Immutable, standalone payload. M1 has no references from live mailbox/state
/// values to these bytes. Declaration authorizes one trusted creation attempt;
/// recovery may verify it but never blindly issue another create.
pub const Payload = struct {
    id: u64,
    pid: u64,
    publisher: u8,
    sha256: [32]u8,
    bytes: u32,
    allow_delete: bool = false,
    phase: enum { creating, ready, retiring, deleted } = .creating,
    retired_at: ?u64 = null,
    deleted_at: ?u64 = null,
};
pub const PayloadRef = struct { pid: u64, payload: u64 };
pub const Outbox = struct {
    id: u64,
    source: u64,
    turn: u64,
    index: u8,
    destination: u64,
    value: i64,
    phase: enum { pending, delivered, denied, expired, retired, cancelled } = .pending,
    resolved_at: ?u64 = null,
    courier: ?u8 = null,
    policy_revision: ?u64 = null,
};
pub const Command = union(enum) {
    grant: Grant,
    revoke: u8,
    spawn: struct { code: u32 = 1, deadline_ms: ?u64 = null, settle_before_ms: ?u64 = null, allow_trim: bool = false },
    own: struct { pid: u64, expected_generation: u64, worker: u8 },
    runtime_intent: Runtime.Intent,
    runtime_observe: Runtime.Observation,
    activate: Runtime.Activate,
    send: struct { pid: u64, value: i64 },
    begin_turn: struct { pid: u64, generation: u64, input: u64 },
    turn: struct { pid: u64, generation: u64, input: u64, result: i64, failed: bool = false, effect: ?i64 = null, permit: ?u64 = null, outputs: [max_turn_outputs]?Output = @splat(null) },
    deliver: struct { pid: u64, output: u64, courier: u8 },
    dispatch: struct { pid: u64, effect: u64, reconcile_before_ms: ?u64 = null, max_observations: u16 = max_effect_observations },
    observe: struct { pid: u64, effect: u64, attempt: u64, result: ?i64 },
    close_effect: struct { pid: u64, effect: u64, attempt: u64, reason: enum { abandoned, deadline } = .abandoned },
    terminate: u64,
    expire: u64,
    inspect: u64,
    checkpoint: void,
    declare_payload: struct { pid: u64, sha256: [32]u8, bytes: u32, allow_delete: bool = false },
    payload_ready: PayloadRef,
    retire_payload: PayloadRef,
    payload_deleted: PayloadRef,
};
pub const Request = struct {
    version: u32 = 1,
    realm: u64,
    principal: u8,
    sequence: u64,
    command: Command,
};
pub const SignedRequest = struct { request: Request, signature: [64]u8 };
pub const ProcessView = struct {
    pid: u64,
    code: u32,
    allow_trim: bool = false,
    owner: ?u8 = null,
    generation: u64 = 0,
    lifecycle: enum { running, terminated, expired } = .running,
    state: i64 = 0,
    failure: ?struct { input: u64, recorded_at: u64 } = null,
    admitted: u64 = 0,
    consumed: u64 = 0,
    cancelled: u64 = 0,
    work_before_ms: ?u64 = null,
    settle_before_ms: ?u64 = null,
    turn_permit: ?struct { id: u64, input: u64 } = null,
    binding: ?Runtime.Binding = null,
};
pub fn digest(request: Request) [32]u8 {
    // The typed encoder is the canonical wire representation: fixed fields/order,
    // integer values, no user-controlled object ordering or float normalization.
    var output: [2048]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&output);
    std.json.Stringify.value(request, .{}, &writer) catch unreachable;
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("rey.transit.request.v1\x00");
    hash.update(writer.buffered());
    return hash.finalResult();
}

pub fn sign(request: Request, key: Ed25519.KeyPair) !SignedRequest {
    return .{ .request = request, .signature = (try key.sign(&digest(request), null)).toBytes() };
}

pub const max_body = 64 * 1024;
pub const Input = struct { position: u64, value: i64 };
pub const View = struct {
    position: u64,
    principal_sequence: u64,
    process: ProcessView,
    input: ?Input,
    effects: [max_effects]?Effect = @splat(null),
    payloads: [max_payloads]?Payload = @splat(null),
};
pub const Receipt = struct { position: u64 };
