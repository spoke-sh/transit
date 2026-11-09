//! Ordered invocation recovery over native common transactions. The program
//! owner retains proposed successor environments separately from safe recovery
//! metadata; an accepted private statement is not a committed application turn.
const std = @import("std");
const q = @import("root.zig");
const c = q.catalog;
const p = q.protocol;
const a = q.fuze.ApplicationProgram;
const d = p.DataLifecycle;
const R = c.DirectRecord;
const T = c.DirectClientToken;
const M = q.ManagedApplication;
const I = q.ApplicationInvocation;
const Tx = c.DirectTransactionClient;
const Native = q.ApplicationTransaction;
const E = q.ApplicationEffect;
const EffectRequest = q.ApplicationEffectRequest;
const Self = @This();
pub const candidate_format: u32 = R.guarded_bit | 0x41504331; // protected APC1
owner: I,
native: Host,

/// A binding lives only through one evaluation and its retained candidate. All
/// fields borrow that evaluation; hosts must not retain clients or scratch
/// pointers across a native call or use a previous progress/transaction fence.
pub const Context = struct {
    client: c.DirectTableClient,
    declaration: M.Declaration,
    work: I.Work,
    invocation: T.Key,
    input: I.Input,
    step: u32,
    scratch: std.mem.Allocator,
    reads: ?*q.ApplicationReadSet = null,

    /// Recheck a trusted native host's already verified original input against
    /// current invocation/control fences and registered dependency privileges.
    /// The control read is current even while data helpers use a private cut.
    /// This is an observation, never a dispatch permit or retained authority.
    pub fn requireCurrent(self: Context) !void {
        if (self.client.connection.role != self.work.executor_role) return error.DataflowLeaseFenced;
        const lease = self.client.lease orelse return error.DataflowLeaseFenced;
        try lease.validate(self.client.connection);
        if (!std.meta.eql(lease.key, self.invocation) and
            (lease.additional == null or !std.meta.eql(lease.additional.?.key, self.invocation))) return error.DataflowLeaseFenced;
        try self.input.source.validate();
        if (self.input.definition != p.Growth.current_definition or self.work.phase != .ready or
            self.work.receipt == null or self.work.input_lease == null or
            !std.meta.eql(self.input.claim, self.work.receipt.?) or !std.meta.eql(self.input.lease, self.work.input_lease.?) or
            !std.meta.eql(self.input.source.target, self.work.claim.target)) return error.InvalidDirectRecord;
        var control = self.client;
        control.transaction = null;
        const observed = try M.inspectExecutor(control, self.declaration);
        try self.work.lease.requireCurrent(try self.declaration.interpretation(control.allocator), observed.head.control, observed.head.attempt);
        if (self.work.execution.cancelled or observed.head.pending == null or
            !std.meta.eql(observed.head.pending.?, self.invocation)) return error.DataflowLeaseFenced;
        if (self.reads) |reads| try reads.add(.{ .current_state = .{ .namespace = self.declaration.namespace, .kind = .kv, .guard = observed.guard } }, observed.policy_revision);
        try M.observeExecutorDependencies(control, self.declaration, observed, self.reads);
    }
};
/// One evaluation's borrow. The expression context, rather than a shared
/// factory, identifies the state to release. Factories may serve concurrent
/// evaluations using distinct contexts; each borrow must be finished once.
pub const BoundHost = struct {
    expressions: a.Evaluation.Host,
    release: *const fn (*anyopaque) void,

    pub fn deinit(self: *BoundHost) void {
        self.release(self.expressions.context);
        self.* = undefined;
    }
};
pub const Host = struct {
    context: *anyopaque,
    /// Check complete-program support and physical placement before acquiring
    /// input. This observation grants no rights and cannot replace native fences.
    ready: *const fn (*anyopaque, std.mem.Allocator, M.Declaration) anyerror!void,
    /// The returned context lives through candidate retention. A failed bind
    /// releases its own partial borrow; every successful bind returns cleanup.
    bind: *const fn (*anyopaque, Context) anyerror!BoundHost,
    effects: ?Effects = null,
};

/// Fixed task metadata. The deployment owns the worker's clients and I/O and
/// reopens these exact native records; no evaluation borrow escapes into a task.
pub const EffectJob = struct {
    declaration: R.Reference,
    descriptor: E.Descriptor,
    revision: d.Position,
    lease: T.Lease,
    pub fn validate(self: EffectJob) !void {
        try self.declaration.validate();
        try self.descriptor.validate();
        try self.revision.validate();
        try self.lease.validate(self.descriptor.request.scope.connection);
        if (self.declaration.format != c.DirectOwnedRecord.format or
            !std.meta.eql(self.declaration.scope.connection, self.descriptor.invocation.connection)) return error.InvalidApplicationEffect;
        const fence = if (std.meta.eql(self.lease.key, self.descriptor.invocation)) self.lease.primary() else self.lease.additional orelse return error.InvalidApplicationEffect;
        try fence.key.requireSame(self.descriptor.invocation);
        if (!std.meta.eql(fence.revision, self.revision)) return error.InvalidApplicationEffect;
    }
    /// Remove only this job's invocation restriction before reopening its
    /// original manager. executor() then recomposes and verifies the exact pair.
    fn serviceLease(self: EffectJob) !?T.Lease {
        try self.validate();
        if (std.meta.eql(self.lease.key, self.descriptor.invocation)) {
            if (self.lease.additional != null) return error.InvalidApplicationEffect;
            return null;
        }
        return .{ .key = self.lease.key, .revision = self.lease.revision, .additional = null };
    }
};
pub const EffectCompletion = struct { attempt: E.Attempt, outcome: E.Outcome };
pub const EffectPoll = union(enum) { waiting, abandoned, completed: EffectCompletion };
pub const EffectJoin = union(enum) { waiting, joined: ?EffectCompletion };
pub const Effects = struct {
    context: *anyopaque,
    /// Schedule or observe this original task without blocking on remote I/O.
    /// A completion remains owned until release, including across lost native replies.
    poll: *const fn (*anyopaque, EffectJob) anyerror!EffectPoll,
    /// Withdraw and join any task for the descriptor, including an older fence.
    /// Only joined establishes that no live local attempt can still escape.
    join: *const fn (*anyopaque, E.Descriptor) anyerror!EffectJoin,
    /// Called only after join and verified native settlement. Forgetting a
    /// known response at join would lose it if its native publication then failed.
    release: *const fn (*anyopaque, E.Descriptor) void,
    /// Verify that the protected body belongs to this recorded response before
    /// adopting its handle. The context is borrowed for this call only.
    response: *const fn (*anyopaque, Context, E.Descriptor, E.Response) anyerror!void,
};
pub const EffectResult = struct {
    descriptor: E.Descriptor,
    outcome: E.Outcome,
    pub fn validate(self: EffectResult) !void {
        try self.descriptor.validate();
        if (self.outcome == .response) try self.outcome.response.validate();
    }
};

pub const Transaction = struct {
    key: T.Key,
    step: u32,
    kind: enum { atomic, read, final },
    sequence: u64,
};
pub const Failure = struct {
    refusal: ?a.Id,
    reason: enum { none, authorization, budget, source_changed, row_assertion, lease_expired, lease_fenced, original_lost, request_lost, request_expired, effect_unknown, execution },
    evidence: ?struct {
        transaction: T.Key,
        statement: ?c.DirectTransactionWorkspace.StatementCompletion,
        decision: ?p.Transaction.Decision,
    },
    effect: ?EffectResult,
    pub fn validate(self: Failure) !void {
        if ((self.refusal != null) != (self.reason == .none)) return error.InvalidDirectRecord;
        if (self.evidence) |evidence| {
            try evidence.transaction.validate();
            if (evidence.statement) |statement| try statement.validate();
            if (evidence.decision) |decision| try decision.validate();
        }
        if (self.effect) |effect| try effect.validate();
    }
    pub fn code(self: Failure, index: a.Cursor.Index) ![]const u8 {
        try self.validate();
        if (self.refusal) |id| {
            const instruction = try index.instruction(id);
            return switch (instruction.value) {
                .require => |check| check.refusal,
                .let => |binding| if (binding.value == .effect) "EffectGuardRefused" else error.InvalidProgramNode,
                .respond => |response| if (response.guard != null) "ResponseGuardRefused" else error.InvalidProgramNode,
                else => error.InvalidProgramNode,
            };
        }
        return switch (self.reason) {
            .none => unreachable,
            .authorization => "AccessDenied",
            .budget => "ApplicationBudget",
            .source_changed => "DefinitionChanged",
            .row_assertion => "ProgramRowAssertionFailed",
            .lease_expired => "QueueLeaseExpired",
            .lease_fenced => "DataflowLeaseFenced",
            .original_lost => "OriginalInputLost",
            .request_lost => "ApplicationReservationLost",
            .request_expired => "ApplicationReservationExpired",
            .effect_unknown => "ApplicationEffectUnknown",
            .execution => "ProgramExecutionFailed",
        };
    }
};
pub const State = struct {
    phase: enum { evaluate, effect, effect_closing, begin, acquire, stage, execute, ack, checkpoint, settle, abort, fail, closing, release, detach, complete },
    current: ?R.Reference,
    candidate: ?R.Reference,
    transaction: ?Transaction,
    statement: ?c.DirectTransactionWorkspace.StatementWork,
    purpose: enum { instruction, ack, checkpoint },
    basis: ?d.Position,
    checkpoint: ?R.Reference,
    boundary: ?enum { atomic, final },
    atomic_aborted: bool,
    acknowledged: bool,
    terminal: ?p.Transaction.Decision,
    retained_bytes: u64,
    failure: ?Failure,
    aborting: ?Failure,
    completion: ?c.DirectTransactionWorkspace.StatementCompletion,
    cancelled: bool,
    effect: ?struct { descriptor: E.Descriptor, outcome: ?E.Outcome, withdrawn: ?T.Fence },
    pub fn initial() State {
        return .{ .phase = .evaluate, .current = null, .candidate = null, .transaction = null, .statement = null, .purpose = .instruction, .basis = null, .checkpoint = null, .boundary = null, .atomic_aborted = false, .acknowledged = false, .terminal = null, .retained_bytes = 0, .failure = null, .aborting = null, .completion = null, .cancelled = false, .effect = null };
    }
    fn effectEvidence(self: State) !?EffectResult {
        const effect = self.effect orelse return null;
        return .{ .descriptor = effect.descriptor, .outcome = effect.outcome orelse return error.ApplicationEffectPending };
    }
    pub fn validate(self: State) !void {
        if (self.current) |reference| try reference.validate();
        if (self.candidate) |reference| try reference.validate();
        if (self.transaction) |transaction| try transaction.key.validate();
        if (self.statement) |statement| {
            try statement.validate();
            if (self.transaction == null or statement.statement().sequence != self.transaction.?.sequence + 1) return error.InvalidDirectRecord;
        }
        if (self.failure) |failure| try failure.validate();
        if (self.aborting) |failure| try failure.validate();
        if (self.completion) |completion| try completion.validate();
        switch (self.phase) {
            .begin, .acquire, .stage, .execute, .ack, .checkpoint, .settle, .abort => if (self.transaction == null) return error.InvalidDirectRecord,
            .evaluate, .fail, .closing, .release, .detach, .complete => {},
            .effect, .effect_closing => if (self.transaction != null or self.effect == null or self.candidate == null) return error.InvalidDirectRecord,
        }
        if (self.effect) |effect| {
            try effect.descriptor.validate();
            if (effect.withdrawn) |fence| {
                try fence.validate(effect.descriptor.request.scope.connection);
                try fence.key.requireSame(effect.descriptor.invocation);
            }
            if (self.phase == .effect_closing and effect.withdrawn == null) return error.InvalidDirectRecord;
            if (effect.outcome) |outcome| {
                try (EffectResult{ .descriptor = effect.descriptor, .outcome = outcome }).validate();
            } else if (self.phase != .effect and self.phase != .effect_closing) return error.InvalidDirectRecord;
        }
        if (self.terminal) |decision| {
            try decision.validate();
            if (decision.outcome != .committed or !self.acknowledged or (self.phase != .release and self.phase != .detach and self.phase != .complete)) return error.InvalidDirectRecord;
        }
        if (self.basis) |position| try position.validate();
        if (self.checkpoint) |reference| {
            try reference.validate();
            if (reference.format != c.DirectTransactionRecord.format or self.boundary == null) return error.InvalidDirectRecord;
        }
        if (self.candidate) |reference| if (reference.format != c.DirectOwnedRecord.format) return error.InvalidDirectRecord;
        if (self.phase == .execute and (self.statement == null or self.candidate == null)) return error.InvalidDirectRecord;
        if (self.phase == .fail and (self.failure == null or self.transaction != null)) return error.InvalidDirectRecord;
        if (self.phase == .stage and self.candidate == null) return error.InvalidDirectRecord;
        if (self.phase == .ack or self.phase == .checkpoint or self.phase == .settle) {
            if (self.candidate == null or self.boundary == null or self.basis == null or self.transaction.?.kind == .read) return error.InvalidDirectRecord;
        }
        if (self.phase == .complete and (self.transaction != null or self.statement != null or self.checkpoint != null or self.aborting != null)) return error.InvalidDirectRecord;
    }
};
pub const Candidate = struct {
    definition: p.Growth.Definition,
    invocation: T.Key,
    previous: ?R.Reference,
    step: u32,
    instruction: a.Id,
    transaction: ?T.Key,
    environment: a.Environment.Snapshot,
    basis: ?d.Position,
    sequence: u64,
    action: union(enum) {
        advance,
        state: c.DirectTableIntent.Work,
        kv: c.DirectKV.Mutation,
        log: q.ApplicationData.Append,
        boundary: enum { atomic, final },
        failure: Failure,
        effect: EffectRequest,
        effect_result: EffectResult,
    },
};

const CandidateKind = enum { step, failure, effect_result };
fn candidateKind(candidate: Candidate) CandidateKind {
    return switch (candidate.action) {
        .failure => .failure,
        .effect_result => .effect_result,
        else => .step,
    };
}
fn candidateKey(self: Self, value: M.Declaration, work: I.Work, step: u32, kind: CandidateKind, client: c.DirectTableClient) T.Key {
    var label: [32]u8 = undefined;
    @memcpy(label[0..24], "transit.application.step");
    std.mem.writeInt(u64, label[24..32], step, .big);
    label[0] = switch (kind) {
        .step => 't',
        .failure => 'f',
        .effect_result => 'r',
    };
    var key = self.owner.key(value, work.lease.epoch, &label);
    std.crypto.hash.sha2.Sha256.hash("transit.application.continuations.v1", &key.account, .{});
    key.connection = client.connection;
    return key;
}
fn objects(value: M.Declaration, output: *[M.Declaration.max_resources + 1]d.Object) []const d.Object {
    output[0] = value.object;
    for (value.resources, output[1 .. value.resources.len + 1]) |binding, *target| target.* = binding.interpretation().object;
    return output[0 .. value.resources.len + 1];
}
fn store(self: Self, client: c.DirectTableClient, value: M.Declaration, work: I.Work, candidate: Candidate) !R.Reference {
    const bytes = p.Json.valueAllocBounded(client.allocator, candidate, value.limits.continuation_bytes) catch |err| return if (err == error.WriteFailed) error.QueryResultBudget else err;
    defer client.allocator.free(bytes);

    var guards: [M.Declaration.max_resources + 1]d.Object = undefined;
    const guarded = try R.encodeGuarded(client.allocator, client.connection, objects(value, &guards), bytes);
    defer client.allocator.free(guarded);
    const key = self.candidateKey(value, work, candidate.step, candidateKind(candidate), client);
    const binary = try c.DirectTableProtocol.Binary.encode(client.allocator, guarded);
    defer client.allocator.free(binary.base64);
    const encoded = try c.DirectOwnedRecord.encode(client.allocator, key, candidate_format, binary);
    defer client.allocator.free(encoded);
    if (encoded.len > value.limits.retained_bytes -| work.execution.retained_bytes) return error.QueryResultBudget;
    var fingerprint: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(guarded, &fingerprint, .{});
    const original_operation = self.operation(value, work, candidate.step, switch (candidateKind(candidate)) {
        .step => "candidate",
        .failure => "failure-candidate",
        .effect_result => "effect-result",
    });
    var progress = try c.DirectOwnedRecord.stage(client, key, value.namespace, original_operation.operation, fingerprint, .{ .bytes = 4 * @as(u64, value.limits.continuation_bytes) + 4096 }, candidate_format, guarded);
    if (progress.cancel or progress.original.?.phase == .closed) return error.OwnedRecordClosed;
    progress = try c.DirectOwnedRecord.call(client, .{ .retain_original = .{ .key = key, .expected = progress.revision } });
    if (progress.pending) _ = try T.update(client, .{ .key = key, .expected = progress.revision, .pending = false, .cancel = false, .record = null });
    return progress.receipt.binding.intent.external.record;
}
fn operation(self: Self, value: M.Declaration, work: I.Work, step: u32, label: []const u8) d.Operation {
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update(label);
    var bytes: [4]u8 = undefined;
    std.mem.writeInt(u32, &bytes, step, .big);
    hash.update(&bytes);
    return self.owner.manager.operation(value, &hash.finalResult(), work.lease.epoch);
}
fn load(self: Self, client: c.DirectTableClient, value: M.Declaration, work: I.Work, reference: R.Reference) !std.json.Parsed(Candidate) {
    if (!std.meta.eql(reference.scope.connection, client.connection)) return error.InvalidDirectRecord;
    const bytes = try R.read(client.allocator, client, reference);
    defer client.allocator.free(bytes);
    var original_key: ?T.Key = null;
    var transaction_key: ?T.Key = null;
    const inner = switch (reference.format) {
        c.DirectOwnedRecord.format => blk: {
            const envelope = try p.Json.parseFromSlice(c.DirectOwnedRecord.Envelope, client.allocator, bytes);
            defer envelope.deinit();
            try envelope.value.validate(reference);
            if (envelope.value.format != candidate_format) return error.InvalidDirectRecord;
            original_key = envelope.value.key;
            break :blk try envelope.value.bytes.decode(client.allocator, R.max_bytes);
        },
        c.DirectTransactionRecord.format => blk: {
            const envelope = try p.Json.parseFromSlice(c.DirectTransactionRecord.Envelope, client.allocator, bytes);
            defer envelope.deinit();
            try envelope.value.validate(reference);
            if (envelope.value.format != candidate_format) return error.InvalidDirectRecord;
            transaction_key = envelope.value.transaction;
            break :blk try envelope.value.payload.decode(client.allocator, R.max_bytes);
        },
        else => return error.InvalidDirectRecord,
    };
    defer client.allocator.free(inner);
    const guarded = try p.Json.parseFromSlice(R.Guarded, client.allocator, inner);
    defer guarded.deinit();
    try guarded.value.validate(client.connection);
    var expected: [M.Declaration.max_resources + 1]d.Object = undefined;
    const guard_objects = objects(value, &expected);
    if (guarded.value.objects.len != guard_objects.len) return error.InvalidDirectRecord;
    for (guarded.value.objects, guard_objects) |found, target| if (!std.meta.eql(found, target)) return error.InvalidDirectRecord;
    const payload = try guarded.value.payload.decode(client.allocator, value.limits.continuation_bytes);
    defer client.allocator.free(payload);
    try a.Codec.validateEncoding(payload);
    const parsed = try p.Json.parseFromSliceOwned(Candidate, client.allocator, payload);
    errdefer parsed.deinit();
    const candidate = parsed.value;
    if (candidate.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
    try candidate.invocation.requireSame(self.owner.key(value, work.lease.epoch, "transit.application.invocation.v1\x00"));
    if (original_key) |key| try key.requireSame(self.candidateKey(value, work, candidate.step, candidateKind(candidate), client));
    if (transaction_key) |key| try key.requireSame(candidate.transaction orelse return error.InvalidDirectRecord);
    var bound = try value.bind(client.allocator);
    defer bound.deinit();
    var index = try a.Cursor.Index.init(client.allocator, &value.program);
    defer index.deinit();
    try a.Environment.validate(index, bound, try value.digest(client.allocator), candidate.environment);
    switch (candidate.action) {
        .effect => |request| {
            if (candidate.transaction != null or candidate.basis != null or candidate.sequence != 0 or
                candidate.environment.cursor.step != candidate.step) return error.InvalidApplicationEffect;
            const cursor = try a.Cursor.restore(index, candidate.environment.cursor);
            const event = try cursor.next(index);
            if (event != .instruction or event.instruction.id != candidate.instruction) return error.InvalidApplicationEffect;
            _ = try request.expression(index, bound, candidate.instruction);
        },
        .effect_result => |result| {
            try result.validate();
            if (candidate.transaction != null or candidate.basis != null or candidate.sequence != 0 or
                result.descriptor.step != candidate.step or result.descriptor.instruction != candidate.instruction or
                result.outcome != .response or result.outcome.response.body == null or
                candidate.environment.cursor.step != candidate.step + 1) return error.InvalidApplicationEffect;
        },
        else => {},
    }
    return parsed;
}

fn storeCheckpoint(self: Self, client: c.DirectTableClient, value: M.Declaration, work: I.Work, candidate: Candidate) !R.Reference {
    _ = self;
    const transaction = work.execution.transaction orelse return error.InvalidDirectRecord;
    try transaction.key.requireSame(candidate.transaction orelse return error.InvalidDirectRecord);
    if (candidate.action != .boundary) return error.InvalidDirectRecord;
    const bytes = p.Json.valueAllocBounded(client.allocator, candidate, value.limits.continuation_bytes) catch |err| return if (err == error.WriteFailed) error.QueryResultBudget else err;
    defer client.allocator.free(bytes);
    var guards: [M.Declaration.max_resources + 1]d.Object = undefined;
    const guarded = try R.encodeGuarded(client.allocator, client.connection, objects(value, &guards), bytes);
    defer client.allocator.free(guarded);
    const encoded = try c.DirectTransactionRecord.encode(client.allocator, transaction.key, candidate_format, guarded);
    defer client.allocator.free(encoded);
    if (encoded.len > value.limits.retained_bytes -| work.execution.retained_bytes) return error.QueryResultBudget;
    return c.DirectTransactionRecord.stage(client, transaction.key, candidate_format, guarded);
}

const Environment = union(enum) {
    input: std.json.Parsed(I.Input),
    candidate: std.json.Parsed(Candidate),
    fn deinit(self: Environment) void {
        switch (self) {
            inline else => |value| value.deinit(),
        }
    }
    fn snapshot(self: Environment) a.Environment.Snapshot {
        return switch (self) {
            inline else => |value| value.value.environment,
        };
    }
};
fn environment(self: Self, client: c.DirectTableClient, value: M.Declaration, work: I.Work) !Environment {
    if (work.execution.current) |reference| return .{ .candidate = try self.load(client, value, work, reference) };
    return .{ .input = try self.owner.loadInput(client, value, work, work.environment orelse return error.InvalidDirectRecord) };
}
fn resource(value: M.Declaration, name: []const u8) !q.ApplicationBinding {
    for (value.resources) |binding| if (std.mem.eql(u8, binding.name().slice(), name)) return binding;
    return error.UnknownProgramResource;
}
fn beginKey(self: Self, client: c.DirectTableClient, value: M.Declaration, work: I.Work, step: u32, kind: @FieldType(Transaction, "kind")) T.Key {
    const identity = self.operation(value, work, step, @tagName(kind));
    var bytes: [8]u8 = undefined;
    std.mem.writeInt(u64, &bytes, identity.operation, .big);
    var key = self.owner.key(value, work.lease.epoch, &bytes);
    key.connection = client.connection;
    std.crypto.hash.sha2.Sha256.hash("transit.application.transactions.v1", &key.account, .{});
    return key;
}
fn startTransaction(self: Self, client: c.DirectTableClient, value: M.Declaration, work: *I.Work, step: u32, kind: @FieldType(Transaction, "kind")) !void {
    if (work.execution.transaction != null) return error.NestedAtomicProgram;
    work.execution.transaction = .{ .key = self.beginKey(client, value, work.*, step, kind), .step = step, .kind = kind, .sequence = 0 };
    work.execution.completion = null;
    work.execution.phase = .begin;
}
fn adopt(self: Self, client: c.DirectTableClient, value: M.Declaration, work: *I.Work, reference: R.Reference, candidate: Candidate) !void {
    if (!std.meta.eql(candidate.previous, work.execution.current)) return error.InvalidDirectRecord;
    work.execution.retained_bytes = try std.math.add(u64, work.execution.retained_bytes, reference.content.bytes);
    switch (candidate.action) {
        .advance, .failure, .effect_result => {
            if (candidate.action == .effect_result) {
                const effect = work.execution.effect orelse return error.InvalidApplicationEffect;
                if (!std.meta.eql(effect.descriptor, candidate.action.effect_result.descriptor) or
                    !std.meta.eql(effect.outcome, @as(?E.Outcome, candidate.action.effect_result.outcome))) return error.InvalidApplicationEffect;
            }
            if (work.execution.transaction) |transaction| if (transaction.kind == .read) {
                work.execution.candidate = reference;
                work.execution.phase = .abort;
                return;
            };
            work.execution.current = reference;
            work.execution.candidate = null;
            work.execution.phase = .evaluate;
            work.execution.atomic_aborted = false;
        },
        .state, .kv, .log => {
            work.execution.candidate = reference;
            work.execution.phase = .stage;
            work.execution.purpose = .instruction;
        },
        .boundary => {
            work.execution.candidate = reference;
            work.execution.boundary = if (candidate.action.boundary == .atomic) .atomic else .final;
            work.execution.basis = candidate.basis orelse return error.InvalidDirectRecord;
            work.execution.phase = if (work.execution.acknowledged) .checkpoint else .ack;
        },
        .effect => |request| {
            if (work.execution.transaction != null or candidate.transaction != null) return error.EffectInsideAtomic;
            var scope = try self.effectScope(client, value, work.*, reference, candidate.step, candidate.instruction, request);
            defer scope.deinit();
            const retained = try std.math.add(u64, work.execution.retained_bytes, E.reserved_bytes);
            if (retained > value.limits.retained_bytes) return error.QueryResultBudget;
            work.execution.retained_bytes = retained;
            work.execution.candidate = reference;
            work.execution.effect = .{ .descriptor = scope.effect.descriptor, .outcome = null, .withdrawn = null };
            work.execution.phase = .effect;
        },
    }
}

const EffectScope = struct {
    input: std.json.Parsed(I.Input),
    effect: E,
    fn deinit(self: EffectScope) void {
        self.input.deinit();
    }
};
fn effectScope(self: Self, client: c.DirectTableClient, value: M.Declaration, work: I.Work, request: R.Reference, step: u32, instruction: a.Id, operands: EffectRequest) !EffectScope {
    const input = try self.owner.loadInput(client, value, work, work.environment orelse return error.InvalidDirectRecord);
    errdefer input.deinit();
    const scope: Context = .{ .client = client, .declaration = value, .work = work, .invocation = self.owner.key(value, work.lease.epoch, "transit.application.invocation.v1\x00"), .input = input.value, .step = step, .scratch = client.allocator };
    return .{ .input = input, .effect = try E.init(scope, request, instruction, operands.sink, operands.operation) };
}

/// Owned decoded inputs for a physical task. Its client transport and allocator
/// remain caller-owned and must outlive this value. No coordinator borrow is used.
pub const EffectWorker = struct {
    declaration: std.json.Parsed(M.Declaration),
    invocation: std.json.Parsed(I.Work),
    request: std.json.Parsed(Candidate),
    input: std.json.Parsed(I.Input),
    owner: E,

    pub fn deinit(self: EffectWorker) void {
        self.input.deinit();
        self.request.deinit();
        self.invocation.deinit();
        self.declaration.deinit();
    }
    /// Recheck the original guard against the frozen pre-step environment.
    /// This method never evaluates request operands or performs HTTP I/O.
    pub fn guard(self: EffectWorker, host: Host) !bool {
        var reads: q.ApplicationReadSet = .{ .connection = self.owner.scope.client.connection };
        const result = try self.evaluateGuard(host, &reads);
        try reads.verify(self.owner.scope.client);
        return result;
    }
    /// Collect the original guard's actual public bases. A physical owner may
    /// add protected-operand reads before verify; evaluation alone is no permit.
    pub fn evaluateGuard(self: EffectWorker, host: Host, reads: *q.ApplicationReadSet) !bool {
        var scope = self.owner.scope;
        scope.reads = reads;
        try scope.requireCurrent();
        const allocator = self.owner.scope.scratch;
        const value = self.declaration.value;
        var index = try a.Cursor.Index.init(allocator, &value.program);
        defer index.deinit();
        var bound = try value.bind(allocator);
        defer bound.deinit();
        var env = try a.Environment.restore(allocator, index, bound, try value.digest(allocator), self.request.value.environment);
        defer env.deinit();
        var native = try host.bind(host.context, scope);
        defer native.deinit();
        var driver: a.Step = .{ .index = index, .bound = bound, .environment = &env, .scratch = allocator, .native = native.expressions };
        const expression = try self.request.value.action.effect.expression(index, bound, self.request.value.instruction);
        const evaluation = driver.evaluator();
        return evaluation.condition(try evaluation.evaluate(expression.guard));
    }
};
pub fn openEffect(manager_: M, job: EffectJob) !EffectWorker {
    try job.validate();
    if (!std.meta.eql(manager_.client.connection, job.declaration.scope.connection) or manager_.client.transaction != null) return error.InvalidApplicationEffect;
    var manager = manager_;
    const service_lease = try job.serviceLease();
    if (manager.client.lease != null and !std.meta.eql(manager.client.lease, service_lease)) return error.DataflowLeaseFenced;
    manager.client.lease = service_lease;
    const owner: I = .{ .manager = manager };
    const progress = try T.inspect(manager.client, job.descriptor.invocation) orelse return error.ClientOperationMissing;
    if (!std.meta.eql(progress.revision, job.revision)) return error.DataflowLeaseFenced;
    const work = try owner.load(progress);
    errdefer work.deinit();
    try work.value.declaration.requireSame(job.declaration);
    if (work.value.phase != .ready or work.value.execution.phase != .effect or work.value.execution.cancelled or
        work.value.execution.effect == null or !std.meta.eql(work.value.execution.effect.?.descriptor, job.descriptor)) return error.DataflowLeaseFenced;
    const value = try manager.load(job.declaration);
    errdefer value.deinit();
    try work.value.validate(value.value, manager.client.allocator);
    const client = try owner.executor(value.value, progress, work.value);
    if (!std.meta.eql(client.lease, @as(?T.Lease, job.lease))) return error.DataflowLeaseFenced;
    var ordinary: q.ApplicationHost = .{ .scratch = client.allocator, .io = client.service.http.io };
    const execution: Self = .{ .owner = owner, .native = ordinary.recovery() };
    const reference = work.value.execution.candidate orelse return error.InvalidApplicationEffect;
    try reference.requireSame(job.descriptor.request);
    const request = try execution.load(client, value.value, work.value, reference);
    errdefer request.deinit();
    if (request.value.action != .effect) return error.InvalidApplicationEffect;
    const scope = try execution.effectScope(client, value.value, work.value, reference, request.value.step, request.value.instruction, request.value.action.effect);
    errdefer scope.deinit();
    if (!std.meta.eql(scope.effect.descriptor, job.descriptor)) return error.InvalidApplicationEffect;
    return .{ .declaration = value, .invocation = work, .request = request, .input = scope.input, .owner = scope.effect };
}

fn withdrawEffect(client: c.DirectTableClient, work: *I.Work) !void {
    const lease = client.lease orelse return error.DataflowLeaseFenced;
    const invocation = work.execution.effect.?.descriptor.invocation;
    const fence = if (std.meta.eql(lease.key, invocation)) lease.primary() else lease.additional orelse return error.DataflowLeaseFenced;
    try fence.key.requireSame(invocation);
    work.execution.effect.?.withdrawn = fence;
    work.execution.phase = .effect_closing;
}

fn advanceEffect(self: Self, client: c.DirectTableClient, value: M.Declaration, work: *I.Work) !void {
    const facilities = self.native.effects orelse return error.ApplicationHostUnavailable;
    // Withdrawal cannot depend on permission to reopen protected operands.
    // Revocation may block native settlement, but must not keep a local task live.
    const withdrawal: ?EffectJoin = if (work.execution.phase == .effect_closing)
        try facilities.join(facilities.context, work.execution.effect.?.descriptor)
    else
        null;
    if (withdrawal != null and withdrawal.? == .waiting) return;
    const reference = work.execution.candidate orelse return error.InvalidApplicationEffect;
    const loaded = try self.load(client, value, work.*, reference);
    defer loaded.deinit();
    const candidate = loaded.value;
    if (candidate.action != .effect or candidate.transaction != null or
        !std.meta.eql(candidate.previous, work.execution.current)) return error.InvalidApplicationEffect;
    var scope = try self.effectScope(client, value, work.*, reference, candidate.step, candidate.instruction, candidate.action.effect);
    defer scope.deinit();
    const owner = scope.effect;
    if (!std.meta.eql(owner.descriptor, work.execution.effect.?.descriptor)) return error.InvalidApplicationEffect;
    var observed: ?E.Observation = null;
    if (work.execution.phase == .effect_closing) {
        if (withdrawal.?.joined) |completed| {
            observed = try owner.finish(completed.attempt, completed.outcome);
        } else {
            const original = try T.inspect(client, try owner.descriptor.key());
            if (original == null) {
                observed = try owner.recoverUnstarted(work.execution.effect.?.withdrawn.?);
            } else if (original.?.original == null) {
                return error.InvalidApplicationEffect;
            } else if (original.?.original.?.phase == .reserved or original.?.original.?.phase == .ready) {
                observed = try owner.closeUnretained();
            } else {
                observed = try owner.recoverFenced();
                if (observed.?.state.phase == .finished and observed.?.progress.pending)
                    observed = try owner.recoverUnstarted(work.execution.effect.?.withdrawn.?);
            }
        }
    } else {
        observed = owner.observe() catch |err| switch (err) {
            error.OwnedRecordPending => null,
            else => return err,
        };
        if (observed == null or observed.?.state.phase != .finished or observed.?.progress.pending) {
            const lease = client.lease orelse return error.DataflowLeaseFenced;
            const fence = if (std.meta.eql(lease.key, owner.descriptor.invocation)) lease.primary() else lease.additional orelse return error.DataflowLeaseFenced;
            try fence.key.requireSame(owner.descriptor.invocation);
            switch (try facilities.poll(facilities.context, .{ .declaration = work.declaration, .descriptor = owner.descriptor, .revision = fence.revision, .lease = lease })) {
                .waiting => return,
                .abandoned => return withdrawEffect(client, work),
                .completed => |completed| observed = try owner.finish(completed.attempt, completed.outcome),
            }
        }
        const joined = try facilities.join(facilities.context, owner.descriptor);
        if (joined == .waiting) return;
        if (joined.joined) |completed| observed = try owner.finish(completed.attempt, completed.outcome);
    }
    const terminal = observed orelse return error.InvalidApplicationEffect;
    if (terminal.state.phase != .finished or terminal.progress.pending) return error.ApplicationEffectPending;
    facilities.release(facilities.context, owner.descriptor);
    const outcome = terminal.state.outcome.?;
    work.execution.effect.?.outcome = outcome;
    if (work.execution.aborting) |reason| {
        var failure = reason;
        failure.effect = try work.execution.effectEvidence();
        work.execution.failure = failure;
        work.execution.aborting = null;
        work.execution.candidate = null;
        work.execution.phase = if (work.execution.cancelled) .closing else .fail;
        return;
    }
    if (outcome != .response or outcome.response.body == null) {
        var failure: Failure = .{ .refusal = null, .reason = .execution, .evidence = null, .effect = try work.execution.effectEvidence() };
        switch (outcome) {
            .unknown => failure.reason = .effect_unknown,
            .response => failure.reason = .request_lost,
            .not_dispatched => |reason| switch (reason) {
                .guard => {
                    failure.reason = .none;
                    failure.refusal = candidate.instruction;
                },
                .authority => {
                    failure.reason = .authorization;
                    work.execution.cancelled = true;
                },
                .deadline => failure.reason = .request_expired,
                .request_lost => failure.reason = .request_lost,
                .budget => failure.reason = .budget,
                .incomplete_dispatch => {},
            },
        }
        work.execution.failure = failure;
        work.execution.candidate = null;
        work.execution.phase = if (work.execution.cancelled) .closing else .fail;
        return;
    }
    if (work.execution.phase == .effect_closing) {
        // Cleanup used current recovery rights. Re-enter the normal executor
        // boundary before adopting a protected response into application state.
        work.execution.phase = .effect;
        work.execution.effect.?.withdrawn = null;
        return;
    }
    // A response candidate has its own permanent key. Recover it before any
    // protected host access; its predecessor remains the frozen pre-effect env.
    const key = self.candidateKey(value, work.*, candidate.step, .effect_result, client);
    if (try T.inspect(client, key)) |known| {
        const original = known.original orelse return error.InvalidDirectRecord;
        if (original.phase == .reserved) {
            _ = try c.DirectOwnedRecord.call(client, .{ .close_original = .{ .key = key, .expected = known.revision } });
            return error.OwnedRecordClosed;
        }
        if (original.phase == .closed) return error.OwnedRecordClosed;
        const result = try self.load(client, value, work.*, known.receipt.binding.intent.external.record);
        defer result.deinit();
        if (result.value.step != candidate.step or result.value.action != .effect_result) return error.InvalidApplicationEffect;
        var retained = try c.DirectOwnedRecord.call(client, .{ .retain_original = .{ .key = key, .expected = known.revision } });
        if (retained.pending) retained = try T.update(client, .{ .key = key, .expected = retained.revision, .pending = false, .cancel = false, .record = null });
        return self.adopt(client, value, work, retained.receipt.binding.intent.external.record, result.value);
    }
    try facilities.response(facilities.context, owner.scope, owner.descriptor, outcome.response);
    var index = try a.Cursor.Index.init(client.allocator, &value.program);
    defer index.deinit();
    var bound = try value.bind(client.allocator);
    defer bound.deinit();
    const digest = try value.digest(client.allocator);
    var environment_ = try a.Environment.restore(client.allocator, index, bound, digest, candidate.environment);
    defer environment_.deinit();
    var ordinary: q.ApplicationHost = .{ .scratch = client.allocator, .io = client.service.http.io, .scope = owner.scope };
    const driver: a.Step = .{ .index = index, .bound = bound, .environment = &environment_, .scratch = client.allocator, .native = ordinary.host() };
    const response: a.Values.Value = .{ .record = &.{ .{ .name = "status", .value = .{ .integer = outcome.response.status } }, .{ .name = "body", .value = .{ .protected_json = outcome.response.body.? } } } };
    var proposed = try driver.propose(client.allocator, try candidate.action.effect.prepared(index, bound, candidate.step, candidate.instruction), .{ .value = response });
    defer proposed.deinit();
    var result = candidate;
    result.environment = proposed.snapshot(digest);
    result.action = .{ .effect_result = .{ .descriptor = owner.descriptor, .outcome = outcome } };
    return self.adopt(client, value, work, try self.store(client, value, work.*, result), result);
}

fn evaluate(self: Self, client: c.DirectTableClient, value: M.Declaration, work: *I.Work) !void {
    const saved = try self.environment(client, value, work.*);
    defer saved.deinit();
    var index = try a.Cursor.Index.init(client.allocator, &value.program);
    defer index.deinit();
    var bound = try value.bind(client.allocator);
    defer bound.deinit();
    const digest = try value.digest(client.allocator);
    var env = try a.Environment.restore(client.allocator, index, bound, digest, saved.snapshot());
    defer env.deinit();
    // Resolve an already retained candidate before evaluating host operations
    // (including NOW/random) again. Missing reserved bytes are explicit loss.
    const key = self.candidateKey(value, work.*, env.cursor.step, if (work.execution.phase == .fail) .failure else .step, client);
    if (try T.inspect(client, key)) |known| {
        const original = known.original orelse return error.InvalidDirectRecord;
        if (original.phase == .reserved) {
            _ = try c.DirectOwnedRecord.call(client, .{ .close_original = .{ .key = key, .expected = known.revision } });
            return error.OwnedRecordClosed;
        }
        if (original.phase == .closed) return error.OwnedRecordClosed;
        const previous = try self.load(client, value, work.*, known.receipt.binding.intent.external.record);
        defer previous.deinit();
        if (previous.value.step != env.cursor.step) return error.InvalidProgramNode;
        var retained = try c.DirectOwnedRecord.call(client, .{ .retain_original = .{ .key = key, .expected = known.revision } });
        if (retained.pending) retained = try T.update(client, .{ .key = key, .expected = retained.revision, .pending = false, .cancel = false, .record = null });
        return self.adopt(client, value, work, retained.receipt.binding.intent.external.record, previous.value);
    }
    var output: std.heap.ArenaAllocator = .init(client.allocator);
    defer output.deinit();
    var rows: std.heap.ArenaAllocator = .init(client.allocator);
    defer rows.deinit();
    const allocator = output.allocator();
    var candidate: Candidate = .{
        .definition = p.Growth.current_definition,
        .invocation = self.owner.key(value, work.lease.epoch, "transit.application.invocation.v1\x00"),
        .previous = work.execution.current,
        .step = env.cursor.step,
        .instruction = 0,
        .transaction = if (work.execution.transaction) |transaction| transaction.key else null,
        .environment = undefined,
        .basis = null,
        .sequence = 0,
        .action = .advance,
    };
    if (work.execution.phase == .fail) {
        const failure = work.execution.failure orelse return error.InvalidDirectRecord;
        try env.refuse(index, env.cursor.step, .{ .failure = .{ .code = try failure.code(index), .effect_outcome = if (failure.effect) |effect| @tagName(effect.outcome) else "not_dispatched" } }, work.execution.atomic_aborted);
        candidate.environment = env.snapshot(digest);
        candidate.action = .{ .failure = failure };
        return self.adopt(client, value, work, try self.store(client, value, work.*, candidate), candidate);
    }
    const private = if (work.execution.transaction) |transaction| try Native.privateClient(client, transaction.key) else client;
    // Load the original acquisition even after the environment has advanced.
    // The current checkpoint alone cannot prove ownership of a request handle.
    const original_input = if (saved == .input) null else try self.owner.loadInput(client, value, work.*, work.environment orelse return error.InvalidDirectRecord);
    defer if (original_input) |input| input.deinit();
    var host = try self.native.bind(self.native.context, .{
        .client = private,
        .declaration = value,
        .work = work.*,
        .invocation = candidate.invocation,
        .input = if (original_input) |input| input.value else saved.input.value,
        .step = env.cursor.step,
        .scratch = allocator,
    });
    defer host.deinit();
    var driver: a.Step = .{ .index = index, .bound = bound, .environment = &env, .scratch = allocator, .native = host.expressions };
    const step = try driver.prepare();
    candidate.instruction = step.instruction;
    var outcome: a.Step.Outcome = .applied;
    if (private.transaction) |transaction| {
        candidate.basis = transaction.revision;
        candidate.sequence = work.execution.transaction.?.sequence + 1;
    }
    switch (step.action) {
        .begin => {
            if (work.execution.transaction == null) return self.startTransaction(client, value, work, step.step, .atomic);
            const transaction = work.execution.transaction.?;
            if (transaction.kind != .atomic or transaction.step != step.step) return error.NestedAtomicProgram;
        },
        .complete => {
            if (work.execution.transaction == null) return self.startTransaction(client, value, work, step.step, .final);
            if (work.execution.transaction.?.kind != .final) return error.InvalidDirectRecord;
            candidate.action = .{ .boundary = .final };
            candidate.environment = env.snapshot(digest);
            return self.adopt(client, value, work, try self.store(client, value, work.*, candidate), candidate);
        },
        .commit => {
            if (work.execution.transaction == null or work.execution.transaction.?.kind != .atomic) return error.InvalidTransactionGuard;
            candidate.action = .{ .boundary = .atomic };
        },
        .bind, .advance => {},
        .refused => {
            const instruction = try index.instruction(step.instruction);
            const new_effect = instruction.value == .let and instruction.value.let.value == .effect;
            const refusal: Failure = .{ .refusal = step.instruction, .reason = .none, .evidence = null, .effect = if (new_effect) null else try work.execution.effectEvidence() };
            if (work.execution.transaction != null) work.execution.aborting = refusal else work.execution.failure = refusal;
            work.execution.phase = if (work.execution.transaction != null) .abort else .fail;
            return;
        },
        .get => |get| {
            const binding = try resource(value, get.target);
            if (binding.value != .kv) return error.ProgramResourceKindMismatch;
            const response = try client.call(.{ .kv_lookup = .{ .namespace = binding.namespace(), .name = binding.name().slice() } });
            defer response.deinit();
            const metadata = response.value.result.kv_lookup orelse return error.TableNotFound;
            if (!std.meta.eql(metadata.interpretation.interpretation, binding.interpretation())) return error.TableDefinitionChanged;
            outcome = .{ .value = try q.ApplicationData.get(&output, private, metadata, get.key) };
        },
        .select => |select| {
            if (work.execution.transaction == null) return self.startTransaction(client, value, work, step.step, .read);
            const binding = try resource(value, select.target);
            const response = try Native.table(private, binding);
            defer response.deinit();
            const metadata = try Native.tableMetadata(response.value.result);
            outcome = .{ .value = try q.ApplicationData.select(allocator, &rows, &driver, private, metadata, try Native.snapshot(metadata), select, .{ .requests = value.limits.requests, .scan_rows = value.limits.scan_rows, .result_bytes = value.limits.result_bytes }) };
        },
        .put => |put| {
            if (private.transaction == null) return error.InvalidTransactionGuard;
            const binding = try resource(value, put.target);
            if (binding.value != .kv) return error.ProgramResourceKindMismatch;
            const response = try client.call(.{ .kv_lookup = .{ .namespace = binding.namespace(), .name = binding.name().slice() } });
            defer response.deinit();
            const metadata = response.value.result.kv_lookup orelse return error.TableNotFound;
            if (!std.meta.eql(metadata.interpretation.interpretation, binding.interpretation())) return error.TableDefinitionChanged;
            candidate.action = .{ .kv = try q.ApplicationData.preparePut(&output, private, metadata, self.operation(value, work.*, step.step, "put").operation, put) };
        },
        .insert => |insert| {
            if (private.transaction == null) return error.InvalidTransactionGuard;
            const binding = try resource(value, insert.target);
            const response = try Native.table(private, binding);
            defer response.deinit();
            const metadata = try Native.tableMetadata(response.value.result);
            if (try q.ApplicationData.prepareInsert(allocator, private, metadata, try Native.snapshot(metadata), self.operation(value, work.*, step.step, "insert").operation, insert)) |prepared| {
                var intent = prepared;
                defer intent.deinit();
                const bytes = try p.Json.valueAllocBounded(allocator, intent.parsed.value.work, c.DirectTableProtocol.max_work_bytes);
                const owned = try std.json.parseFromSliceLeaky(c.DirectTableIntent.Work, allocator, bytes, .{ .allocate = .alloc_always });
                candidate.action = .{ .state = owned };
            }
        },
        .append => |append| {
            if (private.transaction == null) return error.InvalidTransactionGuard;
            const binding = try resource(value, append.target);
            if (binding.value != .log) return error.ProgramResourceKindMismatch;
            var metadata = try c.DirectLogProtocol.decodeMetadata(client.allocator, client.connection, binding.value.log);
            defer metadata.deinit();
            candidate.action = .{ .log = try q.ApplicationData.prepareAppend(allocator, client.connection, .{ .declaration = binding.value.log.declaration, .schema = metadata.definition.schema }, self.operation(value, work.*, step.step, "append").operation, append) };
        },
        .effect => {
            if (work.execution.transaction != null) return error.EffectInsideAtomic;
            if (self.native.effects == null) return error.ApplicationHostUnavailable;
            candidate.action = .{ .effect = try EffectRequest.freeze(index, bound, step) };
            candidate.environment = env.snapshot(digest);
            return self.adopt(client, value, work, try self.store(client, value, work.*, candidate), candidate);
        },
        .handoff, .respond, .respond_error, .page => return error.ProgramResourceKindMismatch,
    }
    var proposed = try driver.propose(client.allocator, step, outcome);
    defer proposed.deinit();
    candidate.environment = proposed.snapshot(digest);
    const reference = try self.store(client, value, work.*, candidate);
    try self.adopt(client, value, work, reference, candidate);
}

/// Advance one persisted phase. Settlement/cleanup resolve their original
/// transaction without consulting a participant that may already be prepared.
/// Every new data instruction still requires current declaration authority.
pub fn tick(self: Self, value: M.Declaration, progress: T.Progress, original: I.Work) !T.Progress {
    try original.requireOrigin(self.owner.manager.client.allocator, progress);
    try value.validate(self.owner.manager.client.allocator);
    try original.validate(value, self.owner.manager.client.allocator);
    try progress.receipt.binding.key.requireSame(self.owner.key(value, original.lease.epoch, "transit.application.invocation.v1\x00"));
    if (original.execution.effect) |selected| try selected.descriptor.invocation.requireSame(progress.receipt.binding.key);
    if (!std.meta.eql(original.lease.owner, self.owner.manager.operation(value, "worker", original.lease.epoch)) or
        !std.meta.eql(original.claim.operation, self.owner.manager.operation(value, "queue-claim", original.lease.epoch))) return error.DataflowIdentityConflict;
    var executor_identity = self.owner.manager.client;
    executor_identity.connection.role = original.executor_role;
    if (original.execution.transaction) |transaction| try transaction.key.requireSame(self.beginKey(executor_identity, value, original, transaction.step, transaction.kind));
    if (original.execution.phase == .complete) return self.closeOriginal(progress);
    if (!progress.pending or progress.original == null or progress.original.?.phase != .attached) return error.InvalidDirectRecord;
    var work = original;
    work.attachment = null;
    if (progress.cancel and !work.execution.cancelled) {
        work.execution.cancelled = true;
        if (work.execution.terminal != null) return self.owner.advance(value, progress, work);
        work.execution.aborting = .{ .refusal = null, .reason = .lease_fenced, .evidence = null, .effect = null };
        if (work.execution.phase == .effect or work.execution.phase == .effect_closing) {
            work.execution.phase = .effect_closing;
            work.execution.effect.?.withdrawn = .{ .key = progress.receipt.binding.key, .revision = progress.revision };
        } else {
            work.execution.aborting.?.effect = try work.execution.effectEvidence();
            work.execution.phase = if (work.execution.transaction != null) .abort else .closing;
        }
        return self.owner.advance(value, progress, work);
    }
    if (work.phase != .ready and work.execution.phase == .evaluate) return self.owner.acquire(value, progress, work) catch |err| self.refuse(value, progress, work, err);
    var client = self.owner.manager.client;
    client.connection.role = work.executor_role;
    switch (work.execution.phase) {
        .abort, .closing, .release, .detach, .effect_closing => {},
        .settle => client.lease = try T.Lease.combine(client.lease, .{ .key = progress.receipt.binding.key, .revision = progress.revision }),
        else => client = self.owner.executor(value, progress, work) catch |err| return self.refuse(value, progress, work, err),
    }
    self.advance(client, value, &work) catch |err| return self.refuse(value, progress, work, err);
    // Publishing identical waiting progress would fence the asynchronous task.
    if ((work.execution.phase == .effect or work.execution.phase == .effect_closing) and
        std.meta.eql(work.execution, original.execution)) return progress;
    const next = try self.owner.advance(value, progress, work);
    return if (next.pending) next else self.closeOriginal(next);
}

fn closeOriginal(self: Self, progress: T.Progress) !T.Progress {
    if (progress.original == null or progress.pending) return error.InvalidDirectRecord;
    if (progress.original.?.phase == .closed) return progress;
    return c.DirectOwnedRecord.call(self.owner.manager.client, .{ .close_original = .{ .key = progress.receipt.binding.key, .expected = progress.revision } });
}

fn refuse(self: Self, value: M.Declaration, progress: T.Progress, original: I.Work, err: anyerror) !T.Progress {
    // Transport errors and unavailable observations leave the original phase
    // intact. They cannot prove that its accepted native work was rejected.
    const reason: @FieldType(Failure, "reason") = switch (err) {
        error.AccessDenied => .authorization,
        error.DataflowLeaseFenced => .lease_fenced,
        error.QueueLeaseExpired => .lease_expired,
        error.TableDefinitionChanged, error.DataflowSourceChanged => .source_changed,
        error.ProgramRowAssertionFailed => .row_assertion,
        error.ProgramCardinalityMismatch,
        error.Overflow,
        error.ProgramTypeMismatch,
        error.ProgramArgumentMismatch,
        error.InvalidProgramJson,
        error.DuplicateProgramField,
        error.ProtectedProgramValue,
        error.ProgramNullabilityMismatch,
        error.DuplicateBrowserParameter,
        error.DuplicateOrEmptyCookie,
        => .execution,
        error.QueryResultBudget, error.QueryPageBudget, error.TransactionCapacity, error.ProgramTooComplex, error.ProgramTooDeep, error.ApplicationReservationCapacity => .budget,
        error.OwnedRecordClosed => .original_lost,
        // Loss of transient bytes does not establish loss of the durable input
        // or cancellation. Settle an original transaction, then run ON FAILURE.
        error.ApplicationReservationLost => .request_lost,
        error.ApplicationReservationExpired => .request_expired,
        error.ApplicationRequestOwnerMismatch => .authorization,
        error.ApplicationEffectUnknown => .effect_unknown,
        else => return err,
    };
    if (original.execution.phase == .abort or original.execution.phase == .closing or original.execution.phase == .release or original.execution.phase == .detach or original.execution.phase == .effect_closing) return err;
    var work = original;
    if (work.execution.transaction != null) work.execution.aborting = .{ .refusal = null, .reason = reason, .evidence = null, .effect = null } else work.execution.failure = .{ .refusal = null, .reason = reason, .evidence = null, .effect = null };
    if (original.phase != .ready or reason == .authorization or reason == .lease_fenced or reason == .lease_expired or reason == .source_changed or reason == .original_lost or (reason == .budget and original.execution.phase == .fail))
        work.execution.cancelled = true;
    if (work.execution.phase == .effect) {
        work.execution.aborting = work.execution.failure;
        work.execution.failure = null;
        work.execution.effect.?.withdrawn = .{ .key = progress.receipt.binding.key, .revision = progress.revision };
        work.execution.phase = .effect_closing;
    } else {
        if (work.execution.transaction != null) work.execution.aborting.?.effect = try work.execution.effectEvidence() else work.execution.failure.?.effect = try work.execution.effectEvidence();
        work.execution.phase = if (work.execution.transaction != null) .abort else if (work.execution.cancelled) .closing else .fail;
    }
    return self.owner.advance(value, progress, work);
}

fn advance(self: Self, client: c.DirectTableClient, value: M.Declaration, work: *I.Work) !void {
    const tx: Tx = .{ .catalog = client };
    switch (work.execution.phase) {
        .evaluate, .fail => return self.evaluate(client, value, work),
        .effect, .effect_closing => return self.advanceEffect(client, value, work),
        .begin => {
            const transaction = work.execution.transaction.?;
            const request = try Native.prepareBegin(client.allocator, value, work.executor_role, work.claim, transaction.key, self.operation(value, work.*, transaction.step, "begin"));
            defer client.allocator.free(request.selection.explicit_objects);
            _ = try tx.begin(request);
            work.execution.phase = .acquire;
        },
        .acquire => {
            const transaction = work.execution.transaction.?;
            _ = try tx.acquire(transaction.key);
            const private = try Native.privateClient(client, transaction.key);
            for (value.resources) |binding| try binding.requireCurrent(if (binding.value == .table) private else client);
            work.execution.phase = .evaluate;
        },
        .stage => {
            const transaction = work.execution.transaction.?;
            const loaded = try self.load(client, value, work.*, work.execution.candidate.?);
            defer loaded.deinit();
            const candidate = loaded.value;
            try transaction.key.requireSame(candidate.transaction orelse return error.InvalidDirectRecord);
            if (candidate.sequence != transaction.sequence + 1) return error.InvalidDirectRecord;
            const basis = candidate.basis orelse return error.InvalidDirectRecord;
            work.execution.statement = switch (candidate.action) {
                .state => |statement| .{ .state = try tx.stage(transaction.key, basis, candidate.sequence, statement) },
                .kv => |statement| .{ .state = try tx.stageKV(transaction.key, basis, candidate.sequence, statement) },
                .log => |statement| .{ .log = try tx.stageLog(transaction.key, basis, candidate.sequence, statement.work, statement.payload) },
                else => return error.InvalidDirectRecord,
            };
            work.execution.phase = .execute;
        },
        .execute => {
            const transaction = work.execution.transaction.?;
            const completion = try Native.execute(client, transaction.key, work.execution.statement.?);
            work.execution.completion = completion;
            const reason: ?@FieldType(Failure, "reason") = switch (completion) {
                .state => |result| if (result.outcome == .provisional) null else .execution,
                .log => |result| if (result.outcome == .provisional) null else switch (result.outcome.rejected.reason) {
                    .lease_expired => .lease_expired,
                    .lease_fenced => .lease_fenced,
                    else => .execution,
                },
            };
            work.execution.transaction.?.sequence = completion.request().statement().sequence;
            work.execution.statement = null;
            if (reason) |why| {
                work.execution.aborting = .{ .refusal = null, .reason = why, .evidence = .{ .transaction = transaction.key, .statement = completion, .decision = null }, .effect = try work.execution.effectEvidence() };
                work.execution.cancelled = why == .lease_fenced or why == .lease_expired;
                work.execution.phase = .abort;
                return;
            }
            switch (work.execution.purpose) {
                .instruction => {
                    work.execution.current = work.execution.candidate;
                    work.execution.candidate = null;
                    work.execution.phase = .evaluate;
                },
                .ack => {
                    work.execution.basis = (try tx.inspect(transaction.key)).revision;
                    work.execution.phase = .checkpoint;
                },
                .checkpoint => work.execution.phase = .settle,
            }
        },
        .ack => {
            const transaction = work.execution.transaction.?;
            work.execution.statement = .{ .log = try tx.stageLog(transaction.key, work.execution.basis.?, transaction.sequence + 1, .{ .queue_ack = .{
                .operation = self.operation(value, work.*, transaction.step, "ack"),
                .lease = work.input_lease.?,
                .action = .ack,
            } }, null) };
            work.execution.purpose = .ack;
            work.execution.phase = .execute;
        },
        .checkpoint => return self.checkpoint(client, value, work),
        .settle => {
            const transaction = work.execution.transaction.?;
            const status = try tx.settle(transaction.key, self.operation(value, work.*, transaction.step, "commit"), .commit, 1);
            if (status.observation != .decided or !status.cleanup_complete) return;
            if (status.observation.decided.outcome == .committed) return self.committed(client, value, work, status.observation.decided);
            work.execution.aborting = .{ .refusal = null, .reason = .execution, .evidence = .{ .transaction = transaction.key, .statement = work.execution.completion, .decision = status.observation.decided }, .effect = try work.execution.effectEvidence() };
            work.execution.phase = .abort;
        },
        .abort => return self.abort(client, value, work),
        .closing => return self.closeInput(client, work),
        .detach => return self.detach(client, value, work),
        .release => {
            if (work.receipt == null) {
                if (!work.execution.cancelled or work.phase != .claiming) return error.InvalidDirectRecord;
                work.execution.phase = .detach;
                return;
            }
            var output: std.heap.ArenaAllocator = .init(client.allocator);
            defer output.deinit();
            const request: p.QueueRead.Release = .{ .operation = self.owner.manager.operation(value, "release-input", work.lease.epoch), .claim = work.receipt.? };
            const result = try c.DirectQueueClient.apply(&output, client, .{ .mutate = .{ .work = .{ .release = request } } });
            if (result != .operation or result.operation == null or result.operation.? != .release) return error.InvalidQueueResponse;
            try result.operation.?.release.requireRelease(request);
            work.execution.phase = .detach;
        },
        .complete => {},
    }
}

fn checkpoint(self: Self, client: c.DirectTableClient, value: M.Declaration, work: *I.Work) !void {
    const transaction = work.execution.transaction.?;
    const tx: Tx = .{ .catalog = client };
    const loaded = try self.load(client, value, work.*, work.execution.candidate.?);
    defer loaded.deinit();
    const candidate = loaded.value;
    if (candidate.action != .boundary) return error.InvalidDirectRecord;
    if (work.execution.checkpoint == null) {
        const reference = try self.storeCheckpoint(client, value, work.*, candidate);
        work.execution.checkpoint = reference;
        work.execution.retained_bytes = try std.math.add(u64, work.execution.retained_bytes, reference.content.bytes);
        work.execution.basis = (try tx.inspect(transaction.key)).revision;
        return;
    }
    var output: std.heap.ArenaAllocator = .init(client.allocator);
    defer output.deinit();
    const private = try Native.privateClient(client, transaction.key);
    const response = try c.DirectKVClient.apply(&output, private, .{ .get = .{ .object = value.object, .key = M.head_key } });
    const read = response.value;
    const cell = read.value orelse return error.InvalidDirectRecord;
    if (cell != .value or cell.value != .atom or cell.value.atom != .bytes) return error.InvalidDirectRecord;
    const parsed = try p.Json.parseFromSlice(M.Head, client.allocator, cell.value.atom.bytes);
    defer parsed.deinit();
    var head = parsed.value;
    try head.validate();
    if (!std.mem.eql(u8, &head.declaration, &try value.digest(client.allocator)) or head.executor_role != work.executor_role or head.pending == null) return error.DataflowLeaseFenced;
    try work.lease.requireCurrent(try value.interpretation(client.allocator), head.control, head.attempt);
    try head.pending.?.requireSame(self.owner.key(value, work.lease.epoch, "transit.application.invocation.v1\x00"));
    head.checkpoint = work.execution.checkpoint;
    if (candidate.action.boundary == .final) {
        if (work.execution.failure != null) head.refused = try std.math.add(u64, head.refused, 1) else head.completed = try std.math.add(u64, head.completed, 1);
    }
    const mutation = try self.owner.manager.mutation(&output, value, read.interpretation.interpretation, null, head, self.operation(value, work.*, transaction.step, "checkpoint"), .present);
    work.execution.statement = .{ .state = try tx.stageKV(transaction.key, work.execution.basis.?, transaction.sequence + 1, mutation) };
    work.execution.purpose = .checkpoint;
    work.execution.phase = .execute;
}

fn committed(self: Self, client: c.DirectTableClient, value: M.Declaration, work: *I.Work, decision: p.Transaction.Decision) !void {
    const reference = work.execution.checkpoint orelse return error.InvalidDirectRecord;
    _ = self;
    _ = client;
    _ = value;
    const final = (work.execution.boundary orelse return error.InvalidDirectRecord) == .final;
    work.execution.current = reference;
    work.execution.candidate = null;
    work.execution.transaction = null;
    work.execution.statement = null;
    work.execution.checkpoint = null;
    work.execution.boundary = null;
    work.execution.basis = null;
    work.execution.acknowledged = true;
    work.execution.aborting = null;
    if (final) work.execution.terminal = decision;
    work.execution.phase = if (final) .release else if (work.execution.cancelled) .closing else .evaluate;
}

fn abort(self: Self, client: c.DirectTableClient, value: M.Declaration, work: *I.Work) !void {
    const transaction = work.execution.transaction.?;
    const tx: Tx = .{ .catalog = client };
    if (try T.lookup(client, transaction.key)) |_| {
        const before = try tx.inspect(transaction.key);
        const operation_ = if (before.attempt) |attempt| attempt.operation else self.operation(value, work.*, transaction.step, "abort");
        const status = try tx.settle(transaction.key, operation_, .abort, 1);
        if (status.observation != .decided or !status.cleanup_complete) return;
        if (status.observation.decided.outcome == .committed) return self.committed(client, value, work, status.observation.decided);
        if (work.execution.aborting) |*failure| failure.evidence = .{ .transaction = transaction.key, .statement = work.execution.completion, .decision = status.observation.decided };
    }
    work.execution.transaction = null;
    work.execution.statement = null;
    work.execution.checkpoint = null;
    work.execution.boundary = null;
    work.execution.basis = null;
    if (work.execution.aborting) |failure| work.execution.failure = failure;
    work.execution.aborting = null;
    if (work.execution.cancelled or transaction.kind == .final) {
        work.execution.candidate = null;
        work.execution.phase = .closing;
    } else if (transaction.kind == .read and work.execution.candidate != null) {
        work.execution.current = work.execution.candidate orelse return error.InvalidDirectRecord;
        work.execution.candidate = null;
        work.execution.phase = .evaluate;
    } else {
        const saved = try self.environment(client, value, work.*);
        defer saved.deinit();
        work.execution.atomic_aborted = false;
        for (saved.snapshot().cursor.frames) |frame| if (frame.branch == .atomic) {
            work.execution.atomic_aborted = true;
            break;
        };
        work.execution.candidate = null;
        work.execution.phase = .fail;
    }
}

fn closeInput(self: Self, client: c.DirectTableClient, work: *I.Work) !void {
    _ = self;
    if (work.execution.aborting) |failure| work.execution.failure = failure;
    work.execution.aborting = null;
    if (work.receipt == null) {
        if (work.phase != .claiming) return error.InvalidDirectRecord;
        // Resolve or irreversibly close the original claim before detaching its
        // head. Current cleanup authority is still required; no input is ACKed.
        const response = try client.call(.{ .queue = .{ .cancel = .{ .claim = work.claim } } });
        defer response.deinit();
        const result = response.value.result.queue;
        if (result == .recovering) return;
        if (result != .operation or result.operation == null) return error.InvalidQueueResponse;
        switch (result.operation.?) {
            .claim => |receipt| {
                try receipt.requireClaim(work.claim);
                work.receipt = receipt;
                work.phase = .reading;
            },
            .closed => {},
            else => return error.InvalidQueueResponse,
        }
    }
    work.execution.phase = .release;
}

fn detach(self: Self, client: c.DirectTableClient, value: M.Declaration, work: *I.Work) !void {
    const manager = self.owner.manager;
    const observed = try manager.inspect(value);
    if (observed.head.pending) |pending| {
        const token = self.owner.key(value, work.lease.epoch, "transit.application.invocation.v1\x00");
        if (std.meta.eql(pending, token)) {
            var head = observed.head;
            head.pending = null;
            if (work.execution.terminal == null) head.refused = try std.math.add(u64, head.refused, 1);
            var output: std.heap.ArenaAllocator = .init(client.allocator);
            defer output.deinit();
            _ = try c.DirectKVClient.apply(&output, manager.client, .{ .mutate = try manager.mutation(&output, value, observed.storage, observed.position, head, manager.operation(value, "close", observed.position.next_lsn), .present) });
        }
    }
    work.execution.phase = .complete;
}

test "application execution validates safe original progress before data calls" {
    const t = std.testing;
    try State.initial().validate();
    var state = State.initial();
    state.phase = .settle;
    try t.expectError(error.InvalidDirectRecord, state.validate());
    state = .initial();
    state.phase = .execute;
    try t.expectError(error.InvalidDirectRecord, state.validate());
    try t.expectError(error.InvalidDirectRecord, (Failure{ .refusal = null, .reason = .none, .evidence = null, .effect = null }).validate());
    try t.expectError(error.InvalidDirectRecord, (Failure{ .refusal = 4, .reason = .execution, .evidence = null, .effect = null }).validate());
    try (Failure{ .refusal = null, .reason = .execution, .evidence = null, .effect = null }).validate();
}

test "application refusal codes preserve effect and response guards" {
    const t = std.testing;
    var parsed = try a.parse(t.allocator,
        \\CREATE DATAFLOW guarded FROM QUEUE requests AS request AS BEGIN
        \\  REQUIRE FALSE ELSE 'RejectedInput';
        \\  LET result = EXECUTE SINK target EFFECT request.id GUARD FALSE FORM (value = 'public') ON REPLAY OBSERVE ONLY;
        \\  RESPOND TO request.ref STATUS 303 LOCATION '/' GUARD FALSE;
        \\  LET ordinary = 1;
        \\  RESPOND TO request.ref STATUS 303 LOCATION '/';
        \\END;
    , null);
    defer parsed.deinit();
    var index = try a.Cursor.Index.init(t.allocator, &parsed.program);
    defer index.deinit();
    for ([_][]const u8{ "RejectedInput", "EffectGuardRefused", "ResponseGuardRefused" }, parsed.program.body.instructions[0..3]) |expected, instruction| {
        const failure: Failure = .{ .refusal = instruction.id, .reason = .none, .evidence = null, .effect = null };
        try t.expectEqualStrings(expected, try failure.code(index));
    }
    for (parsed.program.body.instructions[3..]) |instruction| {
        const failure: Failure = .{ .refusal = instruction.id, .reason = .none, .evidence = null, .effect = null };
        try t.expectError(error.InvalidProgramNode, failure.code(index));
    }
}

test "application host bindings release their own context when another borrow remains live" {
    const t = std.testing;
    const Factory = struct {
        slots: [2]q.ApplicationHost,
        fn bind(context: *anyopaque, scope: Context) !BoundHost {
            const self: *@This() = @ptrCast(@alignCast(context));
            if (scope.step >= self.slots.len) return error.InvalidProgramNode;
            const selected = self.slots[scope.step].recovery();
            return selected.bind(selected.context, scope);
        }
        fn fail(binding: BoundHost) !void {
            var owned = binding;
            defer owned.deinit();
            _ = try owned.expressions.lookup(owned.expressions.context, "missing");
        }
    };
    var factory: Factory = .{ .slots = @splat(.{ .scratch = t.allocator, .io = t.io }) };
    const host: Host = .{ .context = &factory, .ready = q.ApplicationHost.requireReady, .bind = Factory.bind };
    // Public host binding does not read authority. Native operations check it
    // when used; these unused fields intentionally cannot authorize an action.
    var scope: Context = .{ .client = undefined, .declaration = undefined, .work = undefined, .invocation = undefined, .input = undefined, .step = 0, .scratch = t.allocator };
    const first = try host.bind(host.context, scope);
    scope.step = 1;
    var second = try host.bind(host.context, scope);
    try t.expect(factory.slots[0].scope != null and factory.slots[1].scope != null);
    try t.expectError(error.UnknownProgramVariable, Factory.fail(first));
    try t.expect(factory.slots[0].scope == null);
    try t.expectEqual(1, factory.slots[1].scope.?.step);
    second.deinit();
    try t.expect(factory.slots[1].scope == null);
    scope.step = 2;
    try t.expectError(error.InvalidProgramNode, host.bind(host.context, scope));
    try t.expect(factory.slots[0].scope == null and factory.slots[1].scope == null);
}
