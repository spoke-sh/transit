//! Protocol profile v1. No transport, OS clock, scheduling, or application I/O.
const std = @import("std");
pub const Ed25519 = std.crypto.sign.Ed25519;
pub const Time = @import("Time.zig");
pub const Runtime = @import("Runtime.zig");
pub const max_principals = 16;
pub const max_processes = 64;
pub const max_effects = 128;
pub const max_outputs = 256;
pub const max_turn_outputs = 4;
pub const max_counter = (1 << 53) - 1;
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
pub const Principal = struct {
    grant: Grant,
    revision: u64,
    sequence: u64 = 0,
    digest: [32]u8 = @splat(0),
    receipt: u64 = 0,
};
pub const Pid = struct { realm: u64, local: u64 };
pub const Process = struct {
    pid: u64,
    code: u32,
    allow_trim: bool = false,
    owner: ?u8 = null,
    generation: u64 = 0,
    lifecycle: enum { running, terminated, expired } = .running,
    state: i64 = 0,
    admitted: u64 = 0,
    consumed: u64 = 0,
    cancelled: u64 = 0,
    // Journal position of the last consumed input; backlog stays in storage.
    input_cursor: u64 = 0,
    work_before_ms: ?u64 = null,
    settle_before_ms: ?u64 = null,
    turn_permit: ?struct { id: u64, input: u64 } = null,
    binding: ?Runtime.Binding = null,
};
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
    max_observations: u16 = 16,
    observations: u16 = 0,
};
pub const Output = struct { pid: u64, value: i64 };
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
    turn: struct { pid: u64, generation: u64, input: u64, result: i64, effect: ?i64 = null, permit: ?u64 = null, outputs: [max_turn_outputs]?Output = @splat(null) },
    deliver: struct { pid: u64, output: u64, courier: u8 },
    dispatch: struct { pid: u64, effect: u64, reconcile_before_ms: ?u64 = null, max_observations: u16 = 16 },
    observe: struct { pid: u64, effect: u64, attempt: u64, result: ?i64 },
    close_effect: struct { pid: u64, effect: u64, attempt: u64, reason: enum { abandoned, deadline } = .abandoned },
    terminate: u64,
    expire: u64,
    inspect: u64,
    checkpoint: void,
};
pub const Request = struct {
    version: u32 = 1,
    realm: u64,
    principal: u8,
    sequence: u64,
    command: Command,
};
pub const SignedRequest = struct { request: Request, signature: [64]u8 };
pub const Record = struct {
    version: u32 = 1,
    position: u64,
    policy_revision: u64,
    request: Request,
    time: ?Time.Sample = null,
    admission: ?Message = null,
};
pub const RetryPolicy = enum { unlimited, last_per_principal };
pub const Genesis = struct {
    version: u32 = 1,
    realm: u64,
    root_key: [32]u8,
    retry_policy: RetryPolicy = .unlimited,
    max_clock_error_ms: ?u32 = null,
};
pub const Entry = union(enum) { genesis: Genesis, operation: Record };

/// The v1 experiment uses scalar state/input and one compiled workload version.
/// The executable supplies the reviewed reducer; Transit owns its sequencing.
pub const Decision = struct { state: i64, effect: ?i64 = null, outputs: [max_turn_outputs]?Output = @splat(null) };
pub const Reducer = *const fn (i64, i64) anyerror!Decision;

pub const Message = struct { pid: u64, value: i64 };
pub fn messageOf(record: Record) ?Message {
    return record.admission;
}

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

pub const State = struct {
    realm: u64,
    retry_policy: RetryPolicy,
    position: u64 = 1,
    history_floor: u64 = 0,
    principals: [max_principals]?Principal = @splat(null),
    processes: [max_processes]?Process = @splat(null),
    effects: [max_effects]?Effect = @splat(null),
    outputs: [max_outputs]?Outbox = @splat(null),
    output_count: u64 = 0,
    max_clock_error_ms: ?u32 = null,
    time_floor_ms: u64 = 0,

    pub fn init(genesis: Genesis) !State {
        if (genesis.version != 1 or genesis.realm == 0 or genesis.realm > max_counter) return error.InvalidGenesis;
        _ = try Ed25519.PublicKey.fromBytes(genesis.root_key);
        var state: State = .{ .realm = genesis.realm, .retry_policy = genesis.retry_policy, .max_clock_error_ms = genesis.max_clock_error_ms };
        state.principals[0] = .{ .grant = .{ .subject = 0, .public_key = genesis.root_key, .permissions = all_permissions }, .revision = 0 };
        return state;
    }

    pub fn principal(self: *const State, id: u8) !Principal {
        if (id >= max_principals) return error.Unauthorized;
        return self.principals[id] orelse error.Unauthorized;
    }

    pub fn process(self: *State, pid: u64) !*Process {
        for (&self.processes) |*slot| if (slot.*) |*p| {
            if (p.pid == pid) return p;
        };
        return error.UnknownProcess;
    }

    pub fn effect(self: *State, id: u64) !*Effect {
        for (&self.effects) |*slot| if (slot.*) |*e| {
            if (e.id == id) return e;
        };
        return error.UnknownEffect;
    }

    pub fn output(self: *State, id: u64) !*Outbox {
        if (id == 0 or id > self.output_count) return error.UnknownOutput;
        return &self.outputs[@intCast(id - 1)].?;
    }

    pub fn authenticate(self: *const State, signed: SignedRequest) !void {
        const request = signed.request;
        if (request.version != 1 or request.realm != self.realm) return error.WrongProtocolRealm;
        const p = try self.principal(request.principal);
        const public = try Ed25519.PublicKey.fromBytes(p.grant.public_key);
        try Ed25519.Signature.fromBytes(signed.signature).verify(&digest(request), public);
    }

    pub fn authorize(self: *const State, request: Request) !void {
        if (request.version != 1 or request.realm != self.realm) return error.WrongProtocolRealm;
        const p = try self.principal(request.principal);
        const required: Permission = switch (request.command) {
            .grant, .revoke, .own, .terminate, .expire, .checkpoint, .deliver, .runtime_intent, .runtime_observe, .activate => .admin,
            .spawn => .spawn,
            .send => .send,
            .turn, .begin_turn => .execute,
            .inspect => .inspect,
            .dispatch, .observe, .close_effect => .effect,
        };
        if (p.grant.permissions & permission(required) == 0) return error.Forbidden;
        const pid: ?u64 = switch (request.command) {
            .own => |c| c.pid,
            .runtime_intent => |c| c.pid,
            .runtime_observe => |c| c.pid,
            .activate => |c| c.pid,
            .send => |c| c.pid,
            .turn => |c| c.pid,
            .begin_turn => |c| c.pid,
            .deliver => |c| c.pid,
            .dispatch => |c| c.pid,
            .observe => |c| c.pid,
            .close_effect => |c| c.pid,
            .terminate, .expire, .inspect => |id| id,
            else => null,
        };
        if (p.grant.pid) |scope| if (pid != scope) return error.Forbidden;
    }

    /// Current permission is checked even when disclosing an existing receipt.
    pub fn duplicate(self: *const State, request: Request) !?u64 {
        try self.authorize(request);
        const p = try self.principal(request.principal);
        if (request.sequence == 0 or request.sequence > max_counter) return error.InvalidSequence;
        if (request.sequence < p.sequence) return if (self.retry_policy == .unlimited) error.HistoricalReceiptRequired else error.RetryHorizonExceeded;
        if (request.sequence == p.sequence) {
            if (!std.mem.eql(u8, &p.digest, &digest(request))) return error.ConflictingRetry;
            return p.receipt;
        }
        if (request.sequence != p.sequence + 1) return error.SequenceGap;
        return null;
    }

    /// Validate a transition on a copy. The caller publishes it only after CAS.
    /// `input` must be fetched from the journal by the trusted engine, never from
    /// a worker-supplied envelope. State alone does not hold the mailbox backlog.
    pub fn apply(self: *State, record: Record, input: ?Record, reducer: Reducer) !?Message {
        if (record.version != 1 or record.position != self.position or self.position >= max_counter) return error.InvalidPosition;
        const req = record.request;
        if (try self.duplicate(req) != null) return error.DuplicateRecord;
        if ((try self.principal(req.principal)).revision != record.policy_revision) return error.StalePolicy;
        if (record.time) |time| {
            const bound = self.max_clock_error_ms orelse return error.UnsupportedDeadline;
            if (time.error_ms > bound or time.unix_ms > max_counter) return error.UntrustedTime;
            if (time.unix_ms < self.time_floor_ms) return error.ClockRollback;
            self.time_floor_ms = time.unix_ms;
        }
        var admission: ?Message = null;
        switch (req.command) {
            .grant => |g| {
                if (req.principal != 0) return error.Forbidden;
                if (g.subject == 0 or g.subject >= max_principals or g.permissions & ~all_permissions != 0) return error.InvalidGrant;
                _ = try Ed25519.PublicKey.fromBytes(g.public_key);
                var p = self.principals[g.subject] orelse Principal{ .grant = g, .revision = record.position };
                p.grant = g;
                p.revision = record.position;
                self.principals[g.subject] = p;
            },
            .revoke => |subject| {
                if (req.principal != 0) return error.Forbidden;
                if (subject == 0 or subject >= max_principals) return error.InvalidGrant;
                if (self.principals[subject]) |*p| {
                    p.grant.permissions = 0;
                    p.revision = record.position;
                } else return error.UnknownPrincipal;
            },
            .spawn => |c| {
                if (c.code != 1) return error.UnsupportedWorkload;
                if (c.deadline_ms) |deadline| {
                    const time = try self.trustedTime(record);
                    const settle = c.settle_before_ms orelse return error.InvalidLifetime;
                    if (deadline > settle or settle > max_counter) return error.InvalidLifetime;
                    try time.before(deadline);
                } else if (c.settle_before_ms != null) return error.InvalidLifetime;
                const free = for (&self.processes) |*slot| {
                    if (slot.* == null) break slot;
                } else return error.ProcessCapacity;
                free.* = .{ .pid = record.position, .code = c.code, .allow_trim = c.allow_trim, .work_before_ms = c.deadline_ms, .settle_before_ms = c.settle_before_ms };
            },
            .own => |c| {
                const p = try self.process(c.pid);
                if (p.binding != null) return error.RuntimeActivationRequired;
                try running(p);
                if (p.work_before_ms) |deadline| {
                    const time = try self.trustedTime(record);
                    try time.before(if (p.turn_permit != null) p.settle_before_ms.? else deadline);
                }
                if (c.expected_generation != p.generation) return error.StaleGeneration;
                const worker = try self.principal(c.worker);
                if (worker.grant.permissions & permission(.execute) == 0) return error.Forbidden;
                if (worker.grant.pid) |scope| if (scope != c.pid) return error.Forbidden;
                p.generation = try std.math.add(u64, p.generation, 1);
                p.owner = c.worker;
            },
            .runtime_intent => |c| {
                const p = try self.process(c.pid);
                if (c.desired == .running) {
                    try running(p);
                    if (p.work_before_ms) |deadline| try (try self.trustedTime(record)).before(if (p.turn_permit != null) p.settle_before_ms.? else deadline);
                }
                const previous = p.binding;
                if (c.expected_revision != (if (previous) |old| old.revision else @as(u64, 0))) return error.StaleBinding;
                if (previous) |old| {
                    if (old.phase == .pending or old.phase == .unknown) return error.PendingProviderOperation;
                    // M1 pins one association and workload. Provider replacement
                    // or migration requires an explicit future retirement protocol.
                    if (!std.meta.eql(c.instance, old.instance) or !std.meta.eql(c.resource, old.resource) or !std.meta.eql(c.workload, old.workload)) return error.BindingReplacementUnsupported;
                }
                if (std.mem.allEqual(u8, &c.instance, 0) or std.mem.allEqual(u8, &c.resource, 0) or std.mem.allEqual(u8, &c.workload, 0)) return error.InvalidBinding;
                for (self.processes) |slot| if (slot) |other| {
                    if (other.pid != c.pid) if (other.binding) |b| {
                        if (std.meta.eql(c.instance, b.instance) and std.meta.eql(c.resource, b.resource)) return error.ResourceAlreadyBound;
                    };
                };
                p.binding = .{
                    .revision = try std.math.add(u64, c.expected_revision, 1),
                    .operation = record.position,
                    .instance = c.instance,
                    .resource = c.resource,
                    .workload = c.workload,
                    .incarnation = if (previous) |old| old.incarnation else null,
                    .desired = if (c.desired == .running) .running else .stopped,
                    .last_worker_incarnation = if (previous) |old| old.last_worker_incarnation else null,
                };
                p.owner = null;
                p.generation = try std.math.add(u64, p.generation, 1);
            },
            .runtime_observe => |c| {
                const p = try self.process(c.pid);
                const binding = if (p.binding) |*b| b else return error.InvalidBinding;
                if (c.revision != binding.revision or c.operation != binding.operation) return error.StaleBinding;
                if (binding.phase != .pending and binding.phase != .unknown) return error.ProviderOperationClosed;
                if (c.incarnation) |id| {
                    if (std.mem.allEqual(u8, &id, 0)) return error.InvalidBinding;
                    if (binding.incarnation) |old| if (!std.meta.eql(old, id)) return error.ProviderIncarnationMismatch;
                    binding.incarnation = id;
                }
                switch (c.outcome) {
                    .unknown => binding.phase = .unknown,
                    .ready => {
                        if (binding.desired != .running or c.incarnation == null) return error.InvalidBinding;
                        binding.phase = .ready;
                    },
                    .stopped => {
                        if (binding.desired != .stopped and p.lifecycle == .running) return error.InvalidBinding;
                        binding.phase = .stopped;
                    },
                }
            },
            .activate => |c| {
                const p = try self.process(c.pid);
                try running(p);
                if (p.work_before_ms) |deadline| try (try self.trustedTime(record)).before(if (p.turn_permit != null) p.settle_before_ms.? else deadline);
                const binding = if (p.binding) |*b| b else return error.InvalidBinding;
                if (c.revision != binding.revision) return error.StaleBinding;
                if (binding.desired != .running or binding.phase != .ready or binding.incarnation == null) return error.ProviderNotReady;
                if (binding.activation != null) return error.AlreadyActivated;
                if (binding.last_worker_incarnation) |old| if (std.meta.eql(old, c.worker_incarnation)) return error.StaleWorkerIncarnation;
                if (c.expected_generation != p.generation) return error.StaleGeneration;
                if (c.worker == 0 or std.mem.allEqual(u8, &c.worker_incarnation, 0)) return error.InvalidGrant;
                const old = try self.principal(c.worker);
                if (old.grant.pid != c.pid or old.grant.permissions & (permission(.execute) | permission(.inspect)) != (permission(.execute) | permission(.inspect))) return error.Forbidden;
                if (std.meta.eql(old.grant.public_key, c.public_key)) return error.FreshKeyRequired;
                _ = try Ed25519.PublicKey.fromBytes(c.public_key);
                self.principals[c.worker].?.grant.public_key = c.public_key;
                self.principals[c.worker].?.revision = record.position;
                p.generation = try std.math.add(u64, p.generation, 1);
                p.owner = c.worker;
                binding.activation = .{ .worker_incarnation = c.worker_incarnation, .generation = p.generation };
                binding.last_worker_incarnation = c.worker_incarnation;
            },
            .send => |c| {
                const p = try self.process(c.pid);
                try self.newWork(p, record);
                p.admitted = try std.math.add(u64, p.admitted, 1);
                admission = .{ .pid = c.pid, .value = c.value };
            },
            .begin_turn => |c| {
                const p = try self.process(c.pid);
                try self.newWork(p, record);
                if (p.owner != req.principal or p.generation != c.generation) return error.StaleGeneration;
                if (p.turn_permit != null) return error.TurnAlreadyAuthorized;
                const message = input orelse return error.MissingInput;
                if (message.position != c.input or (messageOf(message) orelse return error.InvalidInput).pid != c.pid) return error.InvalidInput;
                p.turn_permit = .{ .id = record.position, .input = c.input };
            },
            .turn => |c| {
                const p = try self.process(c.pid);
                try running(p);
                if (c.generation != p.generation or p.owner != req.principal) return error.StaleGeneration;
                if (p.turn_permit) |permit| {
                    if (c.permit != permit.id or c.input != permit.input) return error.InvalidTurnPermit;
                } else if (c.permit != null or p.work_before_ms != null) return error.MissingTurnPermit;
                if (p.settle_before_ms) |deadline| try (try self.trustedTime(record)).before(deadline);
                const message = input orelse return error.MissingInput;
                const body = messageOf(message) orelse return error.InvalidInput;
                if (body.pid != c.pid or
                    c.input != message.position or c.input <= p.input_cursor or c.input >= record.position or p.consumed >= p.admitted) return error.InvalidInput;
                const decision = try reducer(p.state, body.value);
                if (c.result != decision.state) return error.InvalidResult;
                if (c.effect != decision.effect) return error.InvalidEffectIntent;
                if (!std.meta.eql(c.outputs, decision.outputs)) return error.InvalidOutputs;
                for (c.outputs, 0..) |slot, index| if (slot) |out| {
                    try self.newWork(p, record);
                    if ((try self.principal(req.principal)).grant.permissions & permission(.publish) == 0) return error.Forbidden;
                    _ = try self.process(out.pid);
                    if (self.output_count == max_outputs) return error.OutputCapacity;
                    self.outputs[@intCast(self.output_count)] = .{ .id = self.output_count + 1, .source = p.pid, .turn = record.position, .index = @intCast(index), .destination = out.pid, .value = out.value };
                    self.output_count += 1;
                };
                if (c.effect) |payload| {
                    try self.newWork(p, record);
                    if ((try self.principal(req.principal)).grant.permissions & permission(.effect) == 0) return error.Forbidden;
                    const free = for (&self.effects) |*slot| {
                        if (slot.* == null) break slot;
                    } else return error.EffectCapacity;
                    free.* = .{ .id = record.position, .pid = c.pid, .payload = payload };
                }
                p.state = c.result;
                p.consumed += 1;
                p.input_cursor = c.input;
                p.turn_permit = null;
            },
            .deliver => |c| {
                const out = try self.output(c.output);
                if (out.destination != c.pid) return error.InvalidOutput;
                if (out.phase != .pending) return error.OutputAlreadyResolved;
                for (self.outputs) |slot| if (slot) |earlier| {
                    if (earlier.id < out.id and earlier.source == out.source and earlier.destination == out.destination and earlier.phase == .pending) return error.RouteBlocked;
                };
                const destination = try self.process(c.pid);
                // The controller resolves delivery under a named courier's
                // current destination grant. Historical source acceptance alone
                // is not permission to deliver after that grant is revoked.
                const courier = self.principal(c.courier) catch null;
                const allowed = if (courier) |p| p.grant.permissions & permission(.send) != 0 and (p.grant.pid == null or p.grant.pid == c.pid) else false;
                out.courier = c.courier;
                out.policy_revision = if (courier) |p| p.revision else null;
                out.phase = if (!allowed) .denied else if (destination.lifecycle == .expired) .expired else if (destination.lifecycle == .terminated) .retired else .delivered;
                if (out.phase == .delivered) if (destination.work_before_ms) |deadline| {
                    const time = try self.trustedTime(record);
                    if (time.lower() >= deadline) {
                        out.phase = .expired;
                    } else try time.before(deadline);
                };
                if (out.phase == .delivered) {
                    destination.admitted = try std.math.add(u64, destination.admitted, 1);
                    admission = .{ .pid = c.pid, .value = out.value };
                }
                out.resolved_at = record.position;
            },
            .dispatch => |c| {
                const e = try self.effect(c.effect);
                if (e.pid != c.pid) return error.InvalidEffect;
                try self.newWork(try self.process(c.pid), record);
                if (e.phase != .pending) return error.AttemptAlreadyAuthorized;
                if (c.max_observations == 0) return error.InvalidBudget;
                if (c.reconcile_before_ms) |deadline| {
                    if (deadline > max_counter) return error.InvalidLifetime;
                    try (try self.trustedTime(record)).before(deadline);
                }
                e.phase = .authorized;
                e.attempt = record.position;
                e.executor = req.principal;
                e.reconcile_before_ms = c.reconcile_before_ms;
                e.max_observations = c.max_observations;
            },
            .observe => |c| {
                const e = try self.effect(c.effect);
                if (e.pid != c.pid or e.attempt != c.attempt or e.executor != req.principal) return error.InvalidAttempt;
                if (e.phase != .authorized and e.phase != .unknown) return error.ReconciliationClosed;
                if (e.reconcile_before_ms) |deadline| try (try self.trustedTime(record)).before(deadline);
                e.observations += 1;
                e.phase = if (c.result != null) .observed else .unknown;
                if (e.phase == .unknown and e.observations == e.max_observations) e.phase = .closed_unknown;
                e.result = c.result;
                if (e.phase == .observed or e.phase == .closed_unknown) e.closed_at = record.position;
                const p = try self.process(c.pid);
                if (c.result != null and p.lifecycle == .running) {
                    // Finite callers need a separately authorized continuation
                    // to process an outcome after their work cutoff. This first
                    // profile keeps such late outcomes as connector evidence.
                    const accepts = if (p.work_before_ms) |deadline| (try self.trustedTime(record)).upper() < deadline else true;
                    if (accepts) {
                        p.admitted = try std.math.add(u64, p.admitted, 1);
                        admission = .{ .pid = c.pid, .value = c.result.? };
                    }
                }
            },
            .close_effect => |c| {
                const e = try self.effect(c.effect);
                if (e.pid != c.pid or e.attempt != c.attempt) return error.InvalidAttempt;
                const caller = try self.principal(req.principal);
                // The executor can abandon its own attempt. A controller with
                // an administrative grant can close it if that executor is lost
                // or revoked. Neither path claims remote cancellation.
                if (e.executor != req.principal and caller.grant.permissions & permission(.admin) == 0) return error.Forbidden;
                if (e.phase != .authorized and e.phase != .unknown) return error.ReconciliationClosed;
                if (c.reason == .deadline) try (try self.trustedTime(record)).after(e.reconcile_before_ms orelse return error.NoDeadline);
                e.phase = .closed_unknown;
                e.closed_at = record.position;
            },
            .terminate, .expire => |pid| {
                const p = try self.process(pid);
                try running(p);
                if (req.command == .expire) try (try self.trustedTime(record)).after(p.settle_before_ms orelse return error.NoDeadline);
                p.lifecycle = if (req.command == .expire) .expired else .terminated;
                p.owner = null;
                p.turn_permit = null;
                p.cancelled = p.admitted - p.consumed;
                for (&self.effects) |*slot| if (slot.*) |*e| {
                    if (e.pid == pid and e.phase == .pending) {
                        e.phase = .cancelled;
                        e.closed_at = record.position;
                    }
                };
                for (&self.outputs) |*slot| if (slot.*) |*out| {
                    if (out.source == pid and out.phase == .pending) {
                        out.phase = .cancelled;
                        out.resolved_at = record.position;
                    }
                };
            },
            .inspect => |pid| {
                _ = try self.process(pid);
            },
            .checkpoint => {
                if (self.retry_policy != .last_per_principal) return error.HistoryPinned;
                for (self.processes) |slot| if (slot) |p| {
                    if (!p.allow_trim) return error.RetentionNotEnabled;
                    // This first compaction profile only trims quiescent queues.
                    if (p.admitted != p.consumed + p.cancelled) return error.PendingWork;
                };
                self.history_floor = record.position + 1;
            },
        }
        const caller = &self.principals[req.principal].?;
        caller.sequence = req.sequence;
        caller.digest = digest(req);
        caller.receipt = record.position;
        self.position += 1;
        return admission;
    }

    fn trustedTime(self: *const State, record: Record) !Time.Sample {
        if (self.max_clock_error_ms == null) return error.UnsupportedDeadline;
        return record.time orelse error.ClockUnavailable;
    }

    /// Clocks constrain time-sensitive rights, not revocation/retirement or
    /// read access. A synchronization outage must not disable control authority.
    pub fn requiresTime(self: *State, command: Command) !bool {
        const pid: u64 = switch (command) {
            .spawn => |c| return c.deadline_ms != null,
            .expire => return true,
            .close_effect => |c| return c.reason == .deadline,
            .own => |c| c.pid,
            .activate => |c| c.pid,
            .runtime_intent => |c| if (c.desired == .running) c.pid else return false,
            .send => |c| c.pid,
            .begin_turn => |c| c.pid,
            .turn => |c| c.pid,
            .deliver => |c| c.pid,
            .dispatch => |c| if (c.reconcile_before_ms != null) return true else c.pid,
            .observe => |c| blk: {
                const attempt = try self.effect(c.effect);
                if (attempt.phase != .authorized and attempt.phase != .unknown) return false;
                if (attempt.reconcile_before_ms != null) return true;
                break :blk c.pid;
            },
            else => return false,
        };
        const p = try self.process(pid);
        return p.lifecycle == .running and p.work_before_ms != null;
    }

    fn newWork(self: *const State, p: *const Process, record: Record) !void {
        try running(p);
        if (p.work_before_ms) |deadline| try (try self.trustedTime(record)).before(deadline);
    }

    /// Rebuildable bounded control scan. The returned command still needs a
    /// signed, currently authorized commit; scanning does not mutate authority.
    pub fn nextMaintenance(self: *const State, sample: Time.Sample) !?Command {
        const bound = self.max_clock_error_ms orelse return error.UnsupportedDeadline;
        if (sample.error_ms > bound or sample.unix_ms > max_counter) return error.UntrustedTime;
        if (sample.unix_ms < self.time_floor_ms) return error.ClockRollback;
        for (self.processes) |slot| if (slot) |p| {
            if (p.lifecycle == .running) if (p.settle_before_ms) |deadline| {
                if (sample.lower() >= deadline) return .{ .expire = p.pid };
            };
        };
        for (self.effects) |slot| if (slot) |e| {
            if (e.phase == .authorized or e.phase == .unknown) if (e.reconcile_before_ms) |deadline| {
                if (sample.lower() >= deadline) return .{ .close_effect = .{ .pid = e.pid, .effect = e.id, .attempt = e.attempt.?, .reason = .deadline } };
            };
        };
        return null;
    }
};

pub const Checkpoint = struct {
    version: u32 = 1,
    genesis: Genesis,
    state: State,
    checksum: [32]u8,

    fn hash(allocator: std.mem.Allocator, genesis: Genesis, state: State) ![32]u8 {
        const bytes = try std.json.Stringify.valueAlloc(allocator, .{ .genesis = genesis, .state = state }, .{});
        defer allocator.free(bytes);
        var sum: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(bytes, &sum, .{});
        return sum;
    }
    pub fn create(allocator: std.mem.Allocator, genesis: Genesis, state: State) !Checkpoint {
        if (state.history_floor == 0) return error.NoCheckpointIntent;
        return .{ .genesis = genesis, .state = state, .checksum = try hash(allocator, genesis, state) };
    }
    pub fn validate(self: Checkpoint, allocator: std.mem.Allocator, genesis: Genesis) !void {
        if (self.version != 1 or !std.meta.eql(self.genesis, genesis) or
            self.state.realm != genesis.realm or self.state.retry_policy != genesis.retry_policy or
            self.state.max_clock_error_ms != genesis.max_clock_error_ms or
            self.state.position == 0 or self.state.history_floor == 0 or self.state.history_floor > self.state.position) return error.InvalidCheckpoint;
        if (!std.mem.eql(u8, &self.checksum, &try hash(allocator, self.genesis, self.state))) return error.InvalidCheckpoint;
        const root = try self.state.principal(0);
        if (!std.mem.eql(u8, &root.grant.public_key, &genesis.root_key)) return error.GenesisMismatch;
    }
};

fn running(p: *const Process) !void {
    if (p.lifecycle != .running) return error.RetiredProcess;
}

/// Store contract: immutable positions, authoritative tail, conditional append.
/// Read buffers and the state have fixed limits independent of mailbox backlog.
pub fn Engine(comptime Store: type, comptime reducer: Reducer) type {
    return struct {
        const Self = @This();
        store: *Store,
        genesis: Genesis,
        state: State,
        clock: ?Time.Source = null,

        pub fn open(store: *Store, genesis: Genesis) !Self {
            if (@hasDecl(Store, "loadCheckpoint")) {
                if (try store.loadCheckpoint(genesis)) |checkpoint| {
                    var self: Self = .{ .store = store, .genesis = genesis, .state = checkpoint.state };
                    try self.refresh();
                    return self;
                }
            }
            const first = (try store.read(0)) orelse return error.MissingGenesis;
            if (first != .genesis or !std.meta.eql(first.genesis, genesis)) return error.GenesisMismatch;
            var self: Self = .{ .store = store, .genesis = genesis, .state = try State.init(genesis) };
            try self.refresh();
            return self;
        }

        pub fn bootstrap(store: *Store, genesis: Genesis) !Self {
            _ = try State.init(genesis);
            _ = try store.append(0, .{ .genesis = genesis });
            return open(store, genesis);
        }

        pub fn nextInput(self: *Self, pid: u64, limit: u64) !?Record {
            const p = try self.state.process(pid);
            if (p.admitted == p.consumed + p.cancelled) return null;
            var at = @max(p.input_cursor + 1, self.state.history_floor);
            while (at < limit) : (at += 1) {
                const entry = (try self.store.read(at)) orelse return error.IncompleteHistory;
                if (entry == .operation) {
                    if (messageOf(entry.operation)) |message| if (message.pid == pid) return entry.operation;
                }
            }
            return error.MissingInput;
        }

        pub fn refresh(self: *Self) !void {
            self.replayTail() catch |err| {
                if (err != error.HistoryReclaimed) return err;
                if (!@hasDecl(Store, "loadCheckpoint")) return err;
                const checkpoint = (try self.store.loadCheckpoint(self.genesis)) orelse return error.MissingCheckpoint;
                // Another maintainer may trim while this authority is idle or
                // reading an input. Recovery must advance, never reset/revive.
                if (checkpoint.state.position <= self.state.position or
                    checkpoint.state.history_floor < self.state.history_floor) return error.StaleCheckpoint;
                if (checkpoint.state.position > try self.store.tail()) return error.HistoryRollback;
                self.state = checkpoint.state;
                // A second concurrent trim can be retried by the caller; bound
                // each refresh instead of chasing maintenance indefinitely.
                try self.replayTail();
            };
        }

        fn replayTail(self: *Self) !void {
            const target = try self.store.tail();
            if (target < self.state.position) return error.HistoryRollback;
            while (self.state.position < target) {
                const entry = (try self.store.read(self.state.position)) orelse return error.IncompleteHistory;
                if (entry != .operation) return error.InvalidHistory;
                const r = entry.operation;
                const input = switch (r.request.command) {
                    .turn => |c| try self.nextInput(c.pid, r.position),
                    .begin_turn => |c| try self.nextInput(c.pid, r.position),
                    else => null,
                };
                var next = self.state;
                const admission = try next.apply(r, input, reducer);
                if (!std.meta.eql(admission, r.admission)) return error.InvalidAdmission;
                self.state = next;
            }
        }

        pub const Prepared = struct { record: Record, next: State };

        pub fn prepare(self: *Self, signed: SignedRequest) !Prepared {
            try self.refresh();
            try self.state.authenticate(signed);
            const req = signed.request;
            if (try self.state.duplicate(req) != null) return error.AlreadyCommitted;
            const needs_time = try self.state.requiresTime(req.command);
            var r: Record = .{ .position = self.state.position, .policy_revision = (try self.state.principal(req.principal)).revision, .request = req, .time = if (needs_time) (if (self.clock) |clock| try clock.sample() else null) else null };
            const input = switch (req.command) {
                .turn => |c| try self.nextInput(c.pid, r.position),
                .begin_turn => |c| try self.nextInput(c.pid, r.position),
                else => null,
            };
            var next = self.state;
            r.admission = try next.apply(r, input, reducer);
            return .{ .record = r, .next = next };
        }

        pub fn commit(self: *Self, prepared: Prepared) !u64 {
            if (!try self.store.append(prepared.record.position, .{ .operation = prepared.record })) return error.Conflict;
            self.state = prepared.next;
            return prepared.record.position;
        }

        pub fn submit(self: *Self, signed: SignedRequest) !u64 {
            try self.refresh();
            try self.state.authenticate(signed);
            const receipt = self.state.duplicate(signed.request) catch |err| switch (err) {
                error.HistoricalReceiptRequired => {
                    var at: u64 = 1;
                    while (at < self.state.position) : (at += 1) {
                        const old = (try self.store.read(at)) orelse return error.IncompleteHistory;
                        if (old != .operation) return error.InvalidHistory;
                        const request = old.operation.request;
                        if (request.principal == signed.request.principal and request.sequence == signed.request.sequence) {
                            if (!std.mem.eql(u8, &digest(request), &digest(signed.request))) return error.ConflictingRetry;
                            return at;
                        }
                    }
                    return error.MissingReceipt;
                },
                else => return err,
            };
            if (receipt) |position| return position;
            return self.commit(try self.prepare(signed));
        }
    };
}

test {
    _ = @import("tests.zig");
}
