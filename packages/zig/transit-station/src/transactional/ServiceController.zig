//! Server-embedded transactional Station controller (`observe` and `lifecycle`).
//! Replaces 100 ms KV page scans with `QueueWait` Timer Queue claiming and O(1)
//! point reads on `SUC1` supervisor intents and `Actor.Head` control rows.
const std = @import("std");
const c = @import("transit_catalog");
const p = c.protocol;
const d = p.DataLifecycle;
const g = p.Growth;
const Actor = @import("Actor.zig");
const Runner = @import("Runner.zig");
const Envelope = @import("Envelope.zig");
const Timer = @import("Timer.zig");
const Observer = @import("Observer.zig");
const Supervisor = @import("Supervisor.zig");
const KV = c.DirectKVClient;
const Queue = c.DirectQueueClient;
const Self = @This();

pub const resident_bytes = 16 * 1024 * 1024;
pub const Mode = enum { observe, lifecycle };

pub const ChildTarget = struct {
    pid: u64,
    control: d.Definition,
    worker_principal: u64,
};

pub const Watch = struct {
    connection: c.DirectTableProtocol.Connection,
    timers: ?p.StreamQueue.Partition = null,
    supervisor_pid: ?u64 = null,
    supervisor_state: ?d.Definition = null,
    supervisor_inbox: ?p.StreamQueue.Partition = null,
    child: ?ChildTarget = null,
};

pub const RetryGate = struct {
    context: *anyopaque,
    stopped: *const fn (*anyopaque, g.Process) anyerror!bool,
};

pub const Point = enum { after_own };
pub const Hook = struct {
    context: *anyopaque,
    hit: *const fn (*anyopaque, Point) anyerror!void,
};

const Token = struct {
    owner: u64,
    identity: u64,
    generation: u64,
    detail: u64,
    kind: u8,
};

const View = struct {
    process: g.Process,
    principal_sequence: u64,
    position: u64,
};

parent: std.mem.Allocator,
memory: *c.fuze.MemoryBudget,
output: std.heap.ArenaAllocator,
scratch: std.heap.ArenaAllocator,
native: *c.client.Client,
service: *c.client.Client,
observed_epoch: ?u64 = null,
realm: u64,
principal: u64,
key: p.Ed25519.KeyPair,
mode: Mode,
watches: []const Watch,
lease_ms: u64,
instance: u64,
retry_gate: ?RetryGate = null,
hook: ?Hook = null,
pending_native: ?g.SignedRequest = null,
pending_token: ?Token = null,
seen: [128]?Token = @splat(null),
next_seen: usize = 0,
watch_index: usize = 0,
next_claim_seq: u64 = 1,
completed_passes: u64 = 0,

pub fn validateWatches(principal: u64, realm: u64, mode: Mode, watches: []const Watch) !void {
    if (principal == 0 or principal > p.max_counter or realm == 0 or realm > p.max_counter or
        watches.len == 0 or watches.len > 4)
        return error.InvalidController;
    for (watches, 0..) |watch, j| {
        try watch.connection.validate();
        if (watch.connection.principal != principal or watch.connection.scope.realm != realm or watch.connection.role != null)
            return error.InvalidWatch;
        if (watch.timers) |tmr| {
            try tmr.validate();
            try watch.connection.object(tmr.interpretation.object);
        }
        if (watch.supervisor_pid) |sup_pid| {
            if (sup_pid == 0 or sup_pid > p.max_counter) return error.InvalidWatch;
        }
        if (watch.supervisor_state) |sup_state| {
            try sup_state.validate();
            try watch.connection.object(sup_state.object);
        }
        if (watch.supervisor_inbox) |sup_inbox| {
            try sup_inbox.validate();
            try watch.connection.object(sup_inbox.interpretation.object);
        }
        if (watch.child) |ch| {
            if (ch.pid == 0 or ch.pid > p.max_counter or ch.worker_principal == 0 or ch.worker_principal > p.max_counter)
                return error.InvalidWatch;
            try ch.control.validate();
            try watch.connection.object(ch.control.object);
        }
        switch (mode) {
            .observe => {
                const any_sup = watch.supervisor_pid != null or watch.supervisor_state != null or
                    watch.supervisor_inbox != null or watch.child != null;
                if (any_sup) {
                    if (watch.supervisor_pid == null or watch.supervisor_state == null or
                        watch.supervisor_inbox == null or watch.child == null)
                        return error.InvalidWatch;
                } else if (watch.timers == null) {
                    return error.InvalidWatch;
                }
            },
            .lifecycle => {
                if (watch.timers != null or watch.supervisor_pid == null or
                    watch.supervisor_state == null or watch.child == null)
                    return error.InvalidWatch;
                if (watch.child.?.pid != watches[0].child.?.pid) return error.InvalidWatch;
            },
        }
        for (watches[0..j]) |old| if (std.meta.eql(old, watch)) return error.InvalidWatch;
    }
}

pub fn init(
    parent: std.mem.Allocator,
    native: *c.client.Client,
    service: *c.client.Client,
    realm: u64,
    principal: u64,
    key: p.Ed25519.KeyPair,
    mode: Mode,
    watches: []const Watch,
    lease_ms: u64,
    instance: u64,
) !Self {
    try validateWatches(principal, realm, mode, watches);
    if (lease_ms == 0 or instance == 0) return error.InvalidController;
    const memory = try parent.create(c.fuze.MemoryBudget);
    errdefer parent.destroy(memory);
    memory.* = .{ .parent = parent, .limit = resident_bytes };
    return .{
        .parent = parent,
        .memory = memory,
        .output = .init(memory.allocator()),
        .scratch = .init(memory.allocator()),
        .native = native,
        .service = service,
        .realm = realm,
        .principal = principal,
        .key = key,
        .mode = mode,
        .watches = watches,
        .lease_ms = lease_ms,
        .instance = instance,
    };
}

pub fn deinit(self: *Self) void {
    std.crypto.secureZero(u8, std.mem.asBytes(&self.key));
    self.output.deinit();
    self.scratch.deinit();
    self.parent.destroy(self.memory);
    self.* = undefined;
}

fn reset(self: *Self) void {
    _ = self.output.reset(.retain_capacity);
    _ = self.scratch.reset(.retain_capacity);
}

fn tableClient(self: *Self, connection: c.DirectTableProtocol.Connection) c.DirectTableClient {
    return .{
        .allocator = self.memory.allocator(),
        .authority = self.native,
        .service = self.service,
        .connection = connection,
        .key = self.key,
        .observed_epoch = &self.observed_epoch,
    };
}

fn known(self: *const Self, token: Token) bool {
    for (self.seen) |slot| if (slot) |old| if (std.meta.eql(old, token)) return true;
    return false;
}

fn remember(self: *Self, token: Token) void {
    self.seen[self.next_seen] = token;
    self.next_seen = (self.next_seen + 1) % self.seen.len;
}

fn view(self: *Self, pid: u64) !View {
    const response = try self.native.query(.{
        .realm = self.realm,
        .principal = self.principal,
        .kind = .{ .process = pid },
    }, self.key);
    const proc = response.body.process.process;
    if (proc.pid != pid) return error.InvalidAuthorityResponse;
    return .{
        .process = proc,
        .principal_sequence = response.principal_sequence,
        .position = response.position,
    };
}

fn applyKV(output: *std.heap.ArenaAllocator, caller: c.DirectTableClient, action: KV.Action) !KV.Result {
    var last_err: anyerror = error.AuthorityUnavailable;
    for (0..4) |_| {
        return KV.apply(output, caller, action) catch |err| {
            if (err != error.AuthorityUnavailable or caller.service.last_rejection != .AuthorityUnavailable) return err;
            last_err = err;
            continue;
        };
    }
    return last_err;
}

fn applyQueue(output: *std.heap.ArenaAllocator, caller: c.DirectTableClient, action: Queue.Action) !Queue.Result {
    var last_err: anyerror = error.AuthorityUnavailable;
    for (0..4) |_| {
        return Queue.apply(output, caller, action) catch |err| {
            if (err != error.AuthorityUnavailable or caller.service.last_rejection != .AuthorityUnavailable) return err;
            last_err = err;
            continue;
        };
    }
    return last_err;
}

/// Readiness check over current native and data-plane grants. Advances neither
/// `principal_sequence` nor any Queue/KV state while idle.
pub fn check(self: *Self) !void {
    self.reset();
    try validateWatches(self.principal, self.realm, self.mode, self.watches);
    const identity = (try self.native.query(.{
        .realm = self.realm,
        .principal = self.principal,
        .kind = .identity,
    }, self.key)).body.identity;
    if (identity.principal != self.principal) return error.UnsafeControllerPrincipal;
    switch (self.mode) {
        .observe => {
            const inspect_only = p.permission(.inspect);
            const inspect_send = p.permission(.inspect) | p.permission(.send);
            if (identity.permissions != inspect_only and identity.permissions != inspect_send)
                return error.UnsafeControllerPrincipal;
        },
        .lifecycle => {
            if (identity.permissions != (p.permission(.inspect) | p.permission(.admin)) or
                identity.pid != self.watches[0].child.?.pid)
                return error.UnsafeControllerPrincipal;
        },
    }

    for (self.watches) |watch| {
        self.reset();
        const caller = self.tableClient(watch.connection);
        if (watch.timers) |tmr| {
            _ = (try applyQueue(&self.output, caller, .{ .observe = tmr })).cut;
        }
        if (self.mode == .observe) {
            if (watch.supervisor_pid) |sup_pid| {
                _ = try self.view(sup_pid);
            }
        }
        if (watch.supervisor_state) |sup_state| {
            const def = (try applyKV(&self.output, caller, .{ .observe = sup_state.object })).definition.interpretation.interpretation;
            if (!std.meta.eql(def, sup_state)) return error.InvalidWatch;
            if (watch.child) |ch| {
                const ck = Supervisor.key(ch.pid);
                _ = try applyKV(&self.output, caller, .{ .get = .{ .object = sup_state.object, .key = &ck } });
            }
        }
        if (watch.supervisor_inbox) |sup_inbox| {
            _ = (try applyQueue(&self.output, caller, .{ .observe = sup_inbox })).cut;
        }
        if (watch.child) |ch| {
            _ = try self.view(ch.pid);
            const ctrl_def = (try applyKV(&self.output, caller, .{ .observe = ch.control.object })).definition;
            if (!std.meta.eql(ctrl_def.interpretation.interpretation, ch.control)) return error.InvalidWatch;
            _ = try applyKV(&self.output, caller, .{ .get = .{ .object = ch.control.object, .key = &Actor.key(ch.pid) } });
            if (self.mode == .lifecycle) {
                _ = try self.native.query(.{
                    .realm = self.realm,
                    .principal = self.principal,
                    .kind = .{ .authorization = .{ .kind = .{ .decision = .{
                        .object = c.TableAuthority.reference(ctrl_def.authorization),
                        .privileges = c.KVAuthority.inspect | c.KVAuthority.read | c.KVAuthority.write,
                    } } } },
                }, self.key);
            }
        }
    }
}

const LoadedHead = struct {
    head: Actor.Head,
    revision: c.fuze.TableRow.Identity,
};

fn loadActorHead(self: *Self, caller: c.DirectTableClient, control: d.Definition, pid: u64) !?LoadedHead {
    const read = (try applyKV(&self.output, caller, .{ .get = .{ .object = control.object, .key = &Actor.key(pid) } })).value;
    if (!std.meta.eql(read.interpretation.interpretation, control) or !std.meta.eql(read.spec, Actor.spec))
        return error.ActorIdentityConflict;
    const cell = read.value orelse return null;
    if (cell != .value or cell.value != .atom or cell.value.atom != .bytes) return error.ActorIdentityConflict;
    const bytes = cell.value.atom.bytes;
    if (bytes.len > Actor.max_bytes) return error.TurnCapacity;
    const parsed = try p.Json.parseFromSliceOwned(Actor.Head, self.output.allocator(), bytes);
    if (parsed.value.definition != g.current_definition or parsed.value.next_turn == 0 or
        parsed.value.completed >= parsed.value.next_turn)
        return error.ActorIdentityConflict;
    return .{
        .head = parsed.value,
        .revision = read.revision orelse return error.ActorIdentityConflict,
    };
}

pub fn inspectBlockedFailure(self: *Self, watch: Watch, pid: u64) !?struct { generation: u64, failure: u64 } {
    self.reset();
    const ch = watch.child orelse return null;
    if (ch.pid != pid) return null;
    const loaded = (try self.loadActorHead(self.tableClient(watch.connection), ch.control, pid)) orelse return null;
    if (!loaded.head.blocked or loaded.head.failure == 0) return null;
    return .{ .generation = loaded.head.blocked_generation, .failure = loaded.head.failure };
}

fn loadSupervisorChild(self: *Self, caller: c.DirectTableClient, sup_state: d.Definition, child_pid: u64) !?Supervisor.Child {
    const ck = Supervisor.key(child_pid);
    const read = (try applyKV(&self.output, caller, .{ .get = .{ .object = sup_state.object, .key = &ck } })).value;
    if (!std.meta.eql(read.interpretation.interpretation, sup_state)) return error.InvalidWatch;
    const cell = read.value orelse return null;
    if (cell != .value or cell.value != .atom or cell.value.atom != .bytes) return error.InvalidChild;
    return try Supervisor.Child.decode(cell.value.atom.bytes);
}

fn unblockChildHead(self: *Self, caller: c.DirectTableClient, ch: ChildTarget, loaded: LoadedHead) !void {
    var updated = loaded.head;
    if (updated.pending != null or updated.retired) return error.ActorProgressUnresolved;
    updated.blocked = false;
    updated.failure = 0;
    updated.blocked_generation = 0;
    updated.conflict_retries = 0;
    updated.held_input = updated.blocked_input;
    updated.blocked_input = null;
    const bytes = try p.Json.valueAllocBounded(self.scratch.allocator(), updated, Actor.max_bytes);
    const commitment = try p.Json.hashBounded("transit.station.private.lifecycle.unblock.v1\x00", .{
        .pid = ch.pid,
        .revision = loaded.revision,
        .next_turn = updated.next_turn,
    }, 4096);
    const identity = Actor.operation(caller.connection, commitment, updated.next_turn, "lifecycle-unblock", 0);
    const mutation = try KV.prepareMutation(&self.scratch, .{
        .definition = g.current_definition,
        .identity = identity,
        .target = ch.control.object,
        .action = .insert,
        .expected_definition = ch.control,
        .expected_data = null,
        .intent = undefined,
    }, Actor.spec, &.{.{
        .put = .{
            .key = &Actor.key(ch.pid),
            .value = .{ .value = .{ .atom = .{ .bytes = bytes } } },
            .expect = .present,
            .expected_revision = loaded.revision,
        },
    }});
    const receipt = (try applyKV(&self.output, caller, .{ .mutate = mutation })).operation orelse return error.ActorProgressUnresolved;
    _ = try KV.singlePutRevision(mutation, receipt);
    _ = self.scratch.reset(.retain_capacity);
}

fn submitNative(self: *Self, sequence: u64, command: g.Command, token: ?Token) !void {
    self.pending_native = try g.sign(.{
        .realm = self.realm,
        .principal = self.principal,
        .sequence = try std.math.add(u64, sequence, 1),
        .command = command,
    }, self.key);
    self.pending_token = token;
    _ = try self.native.submit(self.pending_native.?);
    self.pending_native = null;
    if (self.pending_token) |tok| self.remember(tok);
    self.pending_token = null;
}

fn advanceWatchCursor(self: *Self) void {
    self.watch_index = (self.watch_index + 1) % self.watches.len;
    if (self.watch_index == 0) self.completed_passes +%= 1;
}

pub fn step(self: *Self, wait_ms: ?u32) !bool {
    self.reset();
    if (self.pending_native) |signed| {
        _ = try self.native.submit(signed);
        self.pending_native = null;
        if (self.pending_token) |tok| self.remember(tok);
        self.pending_token = null;
        return true;
    }

    const watch = self.watches[self.watch_index];
    defer self.advanceWatchCursor();
    const caller = self.tableClient(watch.connection);

    switch (self.mode) {
        .observe => {
            var progressed = false;
            if (watch.child) |ch| {
                if (try self.stepObserveChild(caller, watch, ch)) progressed = true;
            }
            if (watch.timers) |tmr| {
                const effective_wait: ?u32 = if (!progressed and self.watches.len == 1) wait_ms else null;
                if (try self.stepTimers(caller, tmr, effective_wait)) progressed = true;
            }
            return progressed;
        },
        .lifecycle => return self.stepLifecycle(caller, watch),
    }
}

fn stepTimers(self: *Self, caller: c.DirectTableClient, timers: p.StreamQueue.Partition, wait_ms: ?u32) !bool {
    var inspector: Observer.NativeInspector = .{
        .client = self.native,
        .realm = self.realm,
        .principal = self.principal,
        .key = self.key,
    };
    var responder: Supervisor.BackoffResponder = .{ .process_view = inspector.view() };
    const seq = self.next_claim_seq;
    self.next_claim_seq = try std.math.add(u64, self.next_claim_seq, 1);
    const combined_instance = self.instance ^ (seq *% 0x9e3779b97f4a7c15) | 1;
    var obs = try Observer.init(self.parent, caller, timers, null, self.lease_ms, combined_instance, inspector.view());
    defer obs.deinit();
    obs.backoff_builder = responder.builder();
    const res = try obs.step(wait_ms);
    return res != .idle;
}

fn stepObserveChild(self: *Self, caller: c.DirectTableClient, watch: Watch, ch: ChildTarget) !bool {
    const sup_pid = watch.supervisor_pid.?;
    const sup_state = watch.supervisor_state.?;
    const sup_inbox = watch.supervisor_inbox.?;

    const child_rec = (try self.loadSupervisorChild(caller, sup_state, ch.pid)) orelse return false;
    if (child_rec.observer != self.principal or child_rec.phase == .retired) return false;

    const current = try self.view(ch.pid);
    const proc = current.process;
    const maybe_head = try self.loadActorHead(caller, ch.control, ch.pid);

    var kind: Supervisor.Kind = .activation;
    var failure: u64 = 0;
    if (proc.lifecycle == .terminated) {
        kind = .terminated;
    } else if (proc.lifecycle == .expired) {
        kind = .expired;
    } else if (maybe_head != null and maybe_head.?.head.blocked and maybe_head.?.head.failure != 0 and
        maybe_head.?.head.blocked_generation == proc.generation)
    {
        kind = .failed;
        failure = maybe_head.?.head.failure;
    } else if (proc.failure != null) {
        kind = .failed;
        failure = proc.failure.?;
    } else if (proc.control) |ctrl| {
        kind = switch (ctrl.phase) {
            .initializing => .initializing,
            .suspended => .suspended,
            .ready => .activation,
        };
    }

    const time_obs = (try applyQueue(&self.output, caller, .{ .current_time = sup_inbox })).current_time;
    try time_obs.validate();
    const now_ms = time_obs.time.earliest_ms;
    const due = child_rec.phase == .retry_wait and now_ms >= child_rec.retry_at_ms;
    if (!due and child_rec.generation == proc.generation and child_rec.failure == failure) {
        if ((kind == .activation and child_rec.phase == .watching) or
            (kind == .failed and (child_rec.phase == .retry_requested or child_rec.phase == .exhausted or child_rec.phase == .retry_wait)) or
            (kind == .suspended and child_rec.phase == .suspended) or
            (kind == .initializing and child_rec.phase == .initializing))
            return false;
    }

    const token: Token = .{
        .owner = sup_pid,
        .identity = ch.pid,
        .generation = proc.generation,
        .detail = if (due) child_rec.retry_at_ms else failure,
        .kind = @backingInt(kind),
    };
    if (self.known(token)) return false;

    const obs: Supervisor.Observation = .{
        .pid = ch.pid,
        .generation = proc.generation,
        .failure = failure,
        .cut = current.position,
        .observed_ms = now_ms,
        .kind = kind,
    };
    const sup_bytes = try obs.encode();
    const env_bytes = try (Envelope{ .kind = .cast, .payload = &sup_bytes }).encodeAlloc(self.output.allocator());
    const append_op = try observeChildOperation(watch.connection, sup_pid, obs);
    const cells = [_]c.fuze.Types.Values.Cell{
        .{ .value = .{ .atom = .{ .signed = @intCast(sup_pid) } } },
        .{ .value = .{ .atom = .{ .bytes = env_bytes } } },
    };
    const batch_buf = try self.scratch.allocator().alloc(u8, env_bytes.len + 4096);
    defer _ = self.scratch.reset(.retain_capacity);
    const payload = try c.storage.LogBatch.encode(Runner.logSchema(sup_inbox.interpretation.object.object), append_op, .queue, &.{.{ .cells = &cells }}, batch_buf);
    const append: p.StreamQueue.Append = .{
        .target = sup_inbox,
        .operation = append_op,
        .kind = .queue,
        .producer = null,
        .rows = 1,
        .payload = c.storage.LogBatch.content(payload),
    };
    const receipt = (try applyQueue(&self.output, caller, .{
        .mutate = .{ .work = .{ .enqueue = append }, .payload = payload },
    })).operation orelse return error.ObserverProgressUnresolved;
    if (receipt != .enqueue) return error.ObserverProgressUnresolved;
    self.remember(token);
    return true;
}

fn stepLifecycle(self: *Self, caller: c.DirectTableClient, watch: Watch) !bool {
    const sup_pid = watch.supervisor_pid.?;
    const sup_state = watch.supervisor_state.?;
    const ch = watch.child.?;

    const child_rec = (try self.loadSupervisorChild(caller, sup_state, ch.pid)) orelse return false;
    if (child_rec.phase != .retry_requested) return false;

    const current = try self.view(ch.pid);
    const proc = current.process;
    if (proc.lifecycle != .running) return false;

    const loaded = (try self.loadActorHead(caller, ch.control, ch.pid)) orelse return false;
    if (loaded.head.retired or loaded.head.pending != null or !loaded.head.blocked or loaded.head.failure != child_rec.failure)
        return false;

    if (proc.binding) |binding| {
        if (binding.desired == .running and loaded.head.blocked_generation < proc.generation) {
            try self.unblockChildHead(caller, ch, loaded);
            return true;
        }
        if (binding.phase == .pending or binding.phase == .unknown or binding.upgrade_from != null) return false;
        if (binding.desired != .stopped) {
            if (proc.generation != child_rec.generation or loaded.head.blocked_generation != child_rec.generation)
                return false;
            try self.submitNative(current.principal_sequence, .{
                .runtime_intent = .{
                    .pid = ch.pid,
                    .expected_revision = binding.revision,
                    .instance = binding.instance,
                    .resource = binding.resource,
                    .workload = binding.workload,
                    .desired = .stopped,
                },
            }, .{ .owner = sup_pid, .identity = ch.pid, .generation = child_rec.generation, .detail = binding.revision, .kind = 254 });
            return true;
        }
        if (binding.phase != .stopped) return false;
        if (proc.generation < loaded.head.blocked_generation) return false;
        try self.submitNative(current.principal_sequence, .{
            .runtime_intent = .{
                .pid = ch.pid,
                .expected_revision = binding.revision,
                .instance = binding.instance,
                .resource = binding.resource,
                .workload = binding.workload,
                .desired = .running,
            },
        }, .{ .owner = sup_pid, .identity = ch.pid, .generation = proc.generation, .detail = child_rec.failure, .kind = 255 });
        if (self.hook) |hook| try hook.hit(hook.context, .after_own);
        try self.unblockChildHead(caller, ch, loaded);
        return true;
    }

    // Post-own crash recovery: if native `own` already bumped generation past `blocked_generation`,
    // complete the conditional `Actor.Head` unblock without issuing a second `own`.
    if (loaded.head.blocked_generation < proc.generation) {
        try self.unblockChildHead(caller, ch, loaded);
        return true;
    }
    if (proc.generation != child_rec.generation or loaded.head.blocked_generation != child_rec.generation)
        return false;

    if (self.retry_gate) |gate| {
        var gated_proc = proc;
        if (gated_proc.failure == null) gated_proc.failure = loaded.head.failure;
        if (!try gate.stopped(gate.context, gated_proc)) return false;
    }

    try self.submitNative(current.principal_sequence, .{
        .own = .{
            .pid = ch.pid,
            .expected_generation = child_rec.generation,
            .worker = ch.worker_principal,
        },
    }, .{ .owner = sup_pid, .identity = ch.pid, .generation = child_rec.generation, .detail = child_rec.failure, .kind = 255 });

    if (self.hook) |hook| try hook.hit(hook.context, .after_own);
    try self.unblockChildHead(caller, ch, loaded);
    return true;
}

pub fn observeChildOperation(connection: c.DirectTableProtocol.Connection, sup_pid: u64, obs: Supervisor.Observation) !d.Operation {
    const op_digest = try p.Json.hashBounded("transit.station.private.service.observe.v1\x00", .{
        .supervisor = sup_pid,
        .pid = obs.pid,
        .generation = obs.generation,
        .failure = obs.failure,
        .cut = obs.cut,
        .observed_ms = obs.observed_ms,
        .kind = @backingInt(obs.kind),
    }, 4096);
    return Actor.operation(connection, op_digest, 1, "sup-observe", 0);
}

test "private transactional service controller validates observe and lifecycle watch invariants" {
    const t = std.testing;
    const scope: d.Scope = .{ .realm = 42, .resource = 2, .catalog = 3 };
    const conn: c.DirectTableProtocol.Connection = .{
        .scope = scope,
        .branch = 1,
        .audience = 4,
        .principal = 10,
        .role = null,
    };
    const timers: p.StreamQueue.Partition = .{
        .definition = g.current_definition,
        .interpretation = .{ .object = .{ .scope = scope, .branch = 1, .object = 8 }, .revision = 1, .digest = @splat(1) },
        .partition = 0,
    };
    const sup_state: d.Definition = .{
        .object = .{ .scope = scope, .branch = 1, .object = 9 },
        .revision = 1,
        .digest = @splat(2),
    };
    const child_ctrl: d.Definition = .{
        .object = .{ .scope = scope, .branch = 1, .object = 10 },
        .revision = 1,
        .digest = @splat(3),
    };

    try validateWatches(10, 42, .observe, &.{.{ .connection = conn, .timers = timers }});
    try t.expectError(error.InvalidWatch, validateWatches(10, 42, .lifecycle, &.{.{ .connection = conn, .timers = timers }}));
    try validateWatches(10, 42, .lifecycle, &.{.{
        .connection = conn,
        .supervisor_pid = 5,
        .supervisor_state = sup_state,
        .child = .{ .pid = 6, .control = child_ctrl, .worker_principal = 11 },
    }});

    const obs_a: Supervisor.Observation = .{ .pid = 6, .generation = 2, .failure = 0, .cut = 915, .observed_ms = 1000, .kind = .activation };
    const obs_b: Supervisor.Observation = .{ .pid = 6, .generation = 2, .failure = 0, .cut = 915, .observed_ms = 2000, .kind = .activation };
    try t.expectEqualDeep(try observeChildOperation(conn, 5, obs_a), try observeChildOperation(conn, 5, obs_a));
    try t.expect(!std.meta.eql(try observeChildOperation(conn, 5, obs_a), try observeChildOperation(conn, 5, obs_b)));
}
