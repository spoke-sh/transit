//! Original effect bookkeeping over the existing native owned-record and
//! conditional progress owners. No transport, credential or response bytes
//! enter these records. Only begin() returning fresh permits a caller to proceed
//! to its separate current-authority/guard checks and one transport attempt.
const std = @import("std");
const q = @import("root.zig");
const c = q.catalog;
const p = q.protocol;
const d = p.DataLifecycle;
const a = q.fuze.ApplicationProgram;
const T = c.DirectClientToken;
const R = c.DirectRecord;
const Self = @This();
pub const format: u32 = R.guarded_bit | 0x41454631; // guarded AEF1
pub const max_state_bytes = 16 * 1024;
pub const reserved_bytes = 4 * max_state_bytes + 4096;

pub const Descriptor = struct {
    definition: p.Growth.Definition,
    invocation: T.Key,
    program: d.Definition,
    input: p.StreamQueue.RecordIdentity,
    request: R.Reference,
    namespace: u64,
    step: u32,
    instruction: a.Id,
    sink: d.Definition,
    operation: [16]u8,

    pub fn validate(self: Descriptor) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.invocation.validate();
        try self.program.validate();
        try self.input.validate();
        try self.request.validate();
        try self.sink.validate();
        try c.Model.nativeId(self.namespace);
        if (self.instruction == 0 or self.step > a.max_nodes * 3 or self.request.format != c.DirectOwnedRecord.format or
            std.mem.allEqual(u8, &self.operation, 0) or std.meta.eql(self.program.object, self.sink.object)) return error.InvalidApplicationEffect;
        try self.request.scope.connection.object(self.program.object);
        try self.request.scope.connection.object(self.sink.object);
        if (!std.meta.eql(self.request.scope.connection.scope, self.invocation.connection.scope) or
            self.request.scope.connection.principal != self.invocation.connection.principal or
            self.request.scope.connection.audience != self.invocation.connection.audience or
            self.request.scope.connection.branch != self.invocation.connection.branch or
            !std.meta.eql(self.input.operation.scope, self.program.object.scope)) return error.InvalidApplicationEffect;
    }
    /// The effect operand cannot choose another original for the same step.
    /// Changed operands conflict with its frozen descriptor fingerprint.
    pub fn key(self: Descriptor) !T.Key {
        try self.validate();
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        hash.update("transit.application.effect.v1\x00");
        hash.update(&try self.invocation.digest());
        var bytes: [8]u8 = undefined;
        std.mem.writeInt(u32, bytes[0..4], self.step, .big);
        std.mem.writeInt(u32, bytes[4..8], self.instruction, .big);
        hash.update(&bytes);
        var account: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash("transit.application.effects.v1", &account, .{});
        return .{ .definition = p.Growth.current_definition, .connection = self.request.scope.connection, .account = account, .token = hash.finalResult()[0..16].* };
    }
    pub fn digest(self: Descriptor) ![32]u8 {
        try self.validate();
        var buffer: [max_state_bytes]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&buffer);
        try std.json.Stringify.value(self, .{}, &writer);
        var result: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(writer.buffered(), &result, .{});
        return result;
    }
};
pub const Refusal = enum { guard, authority, deadline, request_lost, budget, incomplete_dispatch };
pub const Response = struct {
    status: u16,
    bytes: u32,
    sha256: [32]u8,
    /// A transient protected JSON handle, never the provider body. Null means
    /// the complete response was observed but its protected bytes were lost.
    body: ?a.Values.Reference,
    pub fn validate(self: Response) !void {
        if (self.status < 200 or self.status > 599 or self.bytes > 64 * 1024 or
            std.mem.allEqual(u8, &self.sha256, 0)) return error.InvalidApplicationEffect;
        if (self.body) |body| if (std.mem.allEqual(u8, &body.id, 0)) return error.InvalidApplicationEffect;
    }
};
pub const Outcome = union(enum) { not_dispatched: Refusal, unknown, response: Response };
pub const Dispatch = struct {
    /// Fresh entropy identifies this one live attempt. Retained bytes are
    /// observation evidence and cannot reconstruct a fresh attempt on replay.
    nonce: [32]u8,
    lease: T.Lease,
};
pub const State = struct {
    definition: p.Growth.Definition,
    descriptor: Descriptor,
    phase: enum { dispatching, finished },
    dispatch: ?Dispatch,
    outcome: ?Outcome,
    pub fn validate(self: State) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.descriptor.validate();
        if (self.dispatch) |dispatch| {
            if (std.mem.allEqual(u8, &dispatch.nonce, 0)) return error.InvalidApplicationEffect;
            try dispatch.lease.validate(self.descriptor.request.scope.connection);
        }
        switch (self.phase) {
            .dispatching => if (self.dispatch == null or self.outcome != null) return error.InvalidApplicationEffect,
            .finished => {
                const outcome = self.outcome orelse return error.InvalidApplicationEffect;
                if (outcome != .not_dispatched and self.dispatch == null) return error.InvalidApplicationEffect;
                if (outcome == .response) try outcome.response.validate();
            },
        }
    }
};
/// Fixed metadata only: no slice points into a decoded envelope or scratch.
pub const Observation = struct { progress: T.Progress, state: State };
/// Exists only after one successful begin call in the live worker. Never
/// reconstruct this value from retained Dispatch metadata during recovery.
pub const Attempt = struct { key: T.Key, descriptor: [32]u8, dispatch: Dispatch, revision: d.Position };
pub const Begin = union(enum) { fresh: Attempt, observed: Observation };

scope: q.ApplicationExecution.Context,
descriptor: Descriptor,

pub fn init(scope: q.ApplicationExecution.Context, request: R.Reference, instruction: a.Id, sink: []const u8, operation: [16]u8) !Self {
    if (scope.client.transaction != null) return error.EffectInsideAtomic;
    if (!std.meta.eql(request.scope.connection, scope.client.connection)) return error.InvalidApplicationEffect;
    var index = try a.Cursor.Index.init(scope.scratch, &scope.declaration.program);
    defer index.deinit();
    const entry = try index.instruction(instruction);
    if (entry.value != .let or entry.value.let.value != .effect or
        !std.mem.eql(u8, entry.value.let.value.effect.sink, sink)) return error.InvalidApplicationEffect;
    var selected: ?d.Definition = null;
    for (scope.declaration.resources) |resource| if (std.mem.eql(u8, resource.name().slice(), sink)) {
        if (resource.value != .sink) return error.ProgramResourceKindMismatch;
        selected = resource.interpretation();
    };
    const descriptor: Descriptor = .{
        .definition = p.Growth.current_definition,
        .invocation = scope.invocation,
        .program = try scope.declaration.interpretation(scope.scratch),
        .input = scope.input.source,
        .request = request,
        .namespace = scope.declaration.namespace,
        .step = scope.step,
        .instruction = instruction,
        .sink = selected orelse return error.UnknownProgramResource,
        .operation = operation,
    };
    try descriptor.validate();
    return .{ .scope = scope, .descriptor = descriptor };
}
fn guards(self: Self, output: *[q.ApplicationDeclaration.max_resources + 1]d.Object) []const d.Object {
    output[0] = self.scope.declaration.object;
    for (self.scope.declaration.resources, output[1 .. self.scope.declaration.resources.len + 1]) |resource, *target| target.* = resource.interpretation().object;
    return output[0 .. self.scope.declaration.resources.len + 1];
}
fn requireGuards(self: Self, guarded: R.Guarded) !void {
    try guarded.validate(self.scope.client.connection);
    var objects: [q.ApplicationDeclaration.max_resources + 1]d.Object = undefined;
    const expected = self.guards(&objects);
    if (expected.len != guarded.objects.len) return error.InvalidApplicationEffect;
    for (expected, guarded.objects) |left, right| if (!std.meta.eql(left, right)) return error.InvalidApplicationEffect;
}
/// A content reference alone cannot establish that the intent exists or that
/// its original owner has retained it. Once retained, native closure cannot
/// remove it between this observation and dispatch admission.
fn requireRequest(self: Self) !void {
    const bytes = try R.read(self.scope.scratch, self.scope.client, self.descriptor.request);
    defer self.scope.scratch.free(bytes);
    const envelope = try p.Json.parseFromSlice(c.DirectOwnedRecord.Envelope, self.scope.scratch, bytes);
    defer envelope.deinit();
    try envelope.value.validate(self.descriptor.request);
    if (envelope.value.format & R.guarded_bit == 0) return error.InvalidApplicationEffect;
    const inner = try envelope.value.bytes.decode(self.scope.scratch, R.max_bytes);
    defer self.scope.scratch.free(inner);
    const guarded = try p.Json.parseFromSlice(R.Guarded, self.scope.scratch, inner);
    defer guarded.deinit();
    try self.requireGuards(guarded.value);
    const progress = try T.inspect(self.scope.client, envelope.value.key) orelse return error.ClientOperationMissing;
    if (progress.original == null or progress.original.?.attachment != null or progress.receipt.binding.intent != .external or
        progress.receipt.binding.intent.external.namespace != self.descriptor.namespace) return error.InvalidApplicationEffect;
    try self.descriptor.request.requireSame(progress.receipt.binding.intent.external.record);
    if (progress.cancel or progress.original.?.phase == .closed) return error.OwnedRecordClosed;
    if (progress.pending or progress.original.?.phase != .retained) return error.OwnedRecordPending;
}
fn encode(self: Self, state: State) ![]u8 {
    try state.validate();
    if (!std.meta.eql(state.descriptor, self.descriptor)) return error.InvalidApplicationEffect;
    const bytes = try p.Json.valueAllocBounded(self.scope.scratch, state, max_state_bytes);
    defer self.scope.scratch.free(bytes);
    var objects: [q.ApplicationDeclaration.max_resources + 1]d.Object = undefined;
    return R.encodeGuarded(self.scope.scratch, self.scope.client.connection, self.guards(&objects), bytes);
}
fn decode(self: Self, reference: R.Reference) !State {
    const client = self.scope.client;
    const bytes = try R.read(self.scope.scratch, client, reference);
    defer self.scope.scratch.free(bytes);
    const inner = switch (reference.format) {
        c.DirectOwnedRecord.format => blk: {
            const value = try p.Json.parseFromSlice(c.DirectOwnedRecord.Envelope, self.scope.scratch, bytes);
            defer value.deinit();
            try value.value.validate(reference);
            try (try self.descriptor.key()).requireSame(value.value.key);
            if (value.value.format != format) return error.InvalidApplicationEffect;
            break :blk try value.value.bytes.decode(self.scope.scratch, R.max_bytes);
        },
        c.DirectProgressRecord.format => blk: {
            const value = try p.Json.parseFromSlice(c.DirectProgressRecord.Envelope, self.scope.scratch, bytes);
            defer value.deinit();
            try value.value.validate(reference);
            try (try self.descriptor.key()).requireSame(value.value.advance.key);
            if (value.value.advance.format != format) return error.InvalidApplicationEffect;
            break :blk try value.value.advance.bytes.decode(self.scope.scratch, R.max_bytes);
        },
        else => return error.InvalidApplicationEffect,
    };
    defer self.scope.scratch.free(inner);
    const guarded = try p.Json.parseFromSlice(R.Guarded, self.scope.scratch, inner);
    defer guarded.deinit();
    try self.requireGuards(guarded.value);
    const payload = try guarded.value.payload.decode(self.scope.scratch, max_state_bytes);
    defer self.scope.scratch.free(payload);
    const parsed = try p.Json.parseFromSlice(State, self.scope.scratch, payload);
    defer parsed.deinit();
    try parsed.value.validate();
    if (!std.meta.eql(parsed.value.descriptor, self.descriptor)) return error.InvalidApplicationEffect;
    return parsed.value;
}
fn observation(self: Self, progress: T.Progress) !Observation {
    try (try self.descriptor.key()).requireSame(progress.receipt.binding.key);
    if (progress.original == null or progress.original.?.attachment != null or progress.receipt.binding.intent != .external or
        progress.receipt.binding.intent.external.namespace != self.descriptor.namespace or
        progress.receipt.binding.intent.external.record.format != c.DirectOwnedRecord.format) return error.InvalidApplicationEffect;
    if (!std.mem.eql(u8, &try self.descriptor.digest(), &progress.receipt.binding.fingerprint)) return error.ClientTokenConflict;
    // A nonattached original cannot close after retention. Closing ready or
    // reserved bytes therefore establishes that begin never returned fresh.
    const state: State = if (progress.original.?.phase == .closed and progress.record == null)
        .{ .definition = p.Growth.current_definition, .descriptor = self.descriptor, .phase = .finished, .dispatch = null, .outcome = .{ .not_dispatched = .incomplete_dispatch } }
    else
        try self.decode(progress.record orelse progress.receipt.binding.intent.external.record);
    if (progress.record != null) {
        const original = try self.decode(progress.receipt.binding.intent.external.record);
        // Recovery bookkeeping cannot replace the permanent dispatch choice.
        if (!std.meta.eql(original.dispatch, state.dispatch) or
            (original.phase == .finished and !std.meta.eql(original, state))) return error.InvalidApplicationEffect;
    }
    if (state.phase == .dispatching and !progress.pending) return error.InvalidApplicationEffect;
    if (state.phase == .finished and progress.pending and
        (state.outcome.? != .not_dispatched or progress.record != null)) return error.InvalidApplicationEffect;
    return .{ .progress = progress, .state = state };
}
pub fn observe(self: Self) !?Observation {
    const progress = try T.inspect(self.scope.client, try self.descriptor.key()) orelse return null;
    if (progress.original == null or progress.original.?.phase == .reserved) return error.OwnedRecordPending;
    return try self.observation(progress);
}
fn admit(self: Self, state: State) !Observation {
    const key = try self.descriptor.key();
    const bytes = try self.encode(state);
    defer self.scope.scratch.free(bytes);
    const digest = try key.digest();
    var progress = try c.DirectOwnedRecord.stage(self.scope.client, key, self.descriptor.namespace, std.mem.readInt(u64, digest[0..8], .big) | 1, try self.descriptor.digest(), .{ .bytes = reserved_bytes }, format, bytes);
    if (progress.original == null or progress.original.?.phase == .closed or progress.cancel) return error.OwnedRecordClosed;
    progress = try c.DirectOwnedRecord.call(self.scope.client, .{ .retain_original = .{ .key = key, .expected = progress.revision } });
    const observed = try self.observation(progress);
    if (!std.meta.eql(observed.state, state)) return error.InvalidApplicationEffect;
    return observed;
}
fn advance(self: Self, expected: d.Position, cancel: bool, next: State) !Observation {
    const bytes = try self.encode(next);
    defer self.scope.scratch.free(bytes);
    const binary = try c.DirectTableProtocol.Binary.encode(self.scope.scratch, bytes);
    defer self.scope.scratch.free(binary.base64);
    const progress = try c.DirectProgressRecord.advance(self.scope.client, .{ .key = try self.descriptor.key(), .expected = expected, .pending = next.phase != .finished, .cancel = cancel, .format = format, .bytes = binary });
    const observed = try self.observation(progress);
    if (!std.meta.eql(observed.state, next)) return error.InvalidApplicationEffect;
    return observed;
}
pub fn begin(self: Self, io: std.Io) !Begin {
    try self.scope.requireCurrent();
    if (try self.observe()) |previous| return .{ .observed = previous };
    try self.requireRequest();
    var dispatch: Dispatch = .{ .nonce = undefined, .lease = self.scope.client.lease orelse return error.DataflowLeaseFenced };
    try io.randomSecure(&dispatch.nonce);
    if (std.mem.allEqual(u8, &dispatch.nonce, 0)) return error.InvalidApplicationEffect;
    const next: State = .{ .definition = p.Growth.current_definition, .descriptor = self.descriptor, .phase = .dispatching, .dispatch = dispatch, .outcome = null };
    try self.scope.requireCurrent();
    // Admission binds the nonce in the PERMANENT original receipt. Native
    // stage_original compares the complete binding, so two workers with fresh
    // nonces cannot both win even though the descriptor fingerprint is equal.
    // Mutable recovery progress can never create another dispatch admission.
    // Any lost reply returns no Attempt; a later call observes, never retries.
    const accepted = try self.admit(next);
    return .{ .fresh = .{ .key = accepted.progress.receipt.binding.key, .descriptor = try self.descriptor.digest(), .dispatch = dispatch, .revision = accepted.progress.revision } };
}
pub fn finish(self: Self, attempt: Attempt, outcome: Outcome) !Observation {
    try (try self.descriptor.key()).requireSame(attempt.key);
    if (!std.mem.eql(u8, &attempt.descriptor, &try self.descriptor.digest())) return error.InvalidApplicationEffect;
    const previous = try self.observe() orelse return error.ClientOperationMissing;
    if (!std.meta.eql(previous.state.dispatch, @as(?Dispatch, attempt.dispatch))) return error.InvalidApplicationEffect;
    if (previous.state.phase == .finished) {
        if (!std.meta.eql(previous.state.outcome.?, outcome)) return error.ClientOperationConflict;
        return previous;
    }
    if (previous.state.phase != .dispatching) return error.ClientOperationConflict;
    var next = previous.state;
    next.phase = .finished;
    next.outcome = outcome;
    // Preserve the original expected revision when completing an interrupted
    // native publication. Changed outcome bytes conflict with that reservation.
    return self.advance(if (previous.progress.staged) |staged| staged.expected else previous.progress.revision, previous.progress.cancel, next);
}

pub fn refuse(self: Self, reason: Refusal) !Observation {
    try self.scope.requireCurrent();
    var previous = (try self.observe()) orelse blk: {
        try self.requireRequest();
        break :blk try self.admit(.{ .definition = p.Growth.current_definition, .descriptor = self.descriptor, .phase = .finished, .dispatch = null, .outcome = .{ .not_dispatched = reason } });
    };
    if (previous.state.phase != .finished or !previous.progress.pending) return previous;
    if (previous.state.outcome.? != .not_dispatched) return error.ClientOperationPending;
    if (previous.progress.original.?.phase == .ready)
        previous = try self.observation(try c.DirectOwnedRecord.call(self.scope.client, .{ .retain_original = .{ .key = try self.descriptor.key(), .expected = previous.progress.revision } }));
    return self.advance(if (previous.progress.staged) |staged| staged.expected else previous.progress.revision, previous.progress.cancel, previous.state);
}
/// Join/withdraw the live task before invoking this recovery operation. Native
/// closure races retention with its exact revision: either closure proves no
/// fresh Attempt escaped, or retention wins and the outcome remains uncertain.
pub fn closeUnretained(self: Self) !Observation {
    const key = try self.descriptor.key();
    const previous = try T.inspect(self.scope.client, key) orelse return error.ClientOperationMissing;
    if (previous.original == null or previous.original.?.attachment != null or previous.record != null or
        !std.mem.eql(u8, &previous.receipt.binding.fingerprint, &try self.descriptor.digest())) return error.InvalidApplicationEffect;
    const next = try c.DirectOwnedRecord.call(self.scope.client, .{ .close_original = .{ .key = key, .expected = previous.revision } });
    return self.observation(next);
}
fn fenced(self: Self, fence: T.Fence) !bool {
    try fence.validate(self.scope.client.connection);
    // The invocation/coordinator token belongs to its original role, which can
    // differ from the program executor. Inspect that exact scope while keeping
    // the current recovery lease and the same signing principal. Native policy
    // still checks the role assumption and this read; the key grants no rights.
    var observer = self.scope.client;
    observer.connection = fence.key.connection;
    const current = try T.inspect(observer, fence.key) orelse return error.ClientOperationMissing;
    return !std.meta.eql(current.revision, fence.revision);
}
/// A replaced service/invocation fence is durable evidence that the old worker
/// cannot publish more native work. Its external attempt may have happened;
/// recovery records unknown and never returns another fresh Attempt. An
/// unfinished progress reservation is resumed from its exact saved bytes; a
/// missing payload remains unresolved rather than replacing that outcome.
pub fn recoverFenced(self: Self) !Observation {
    const previous = try self.observe() orelse return error.ClientOperationMissing;
    if (previous.state.phase != .dispatching) return previous;
    if (previous.progress.staged) |staged| {
        const next = try self.decode(staged.reference);
        if (next.phase != .finished or staged.pending or !std.meta.eql(next.dispatch, previous.state.dispatch)) return error.InvalidApplicationEffect;
        return self.advance(staged.expected, staged.cancel, next);
    }
    const lease = previous.state.dispatch.?.lease;
    if (!try self.fenced(lease.primary())) {
        const additional = lease.additional orelse return previous;
        if (!try self.fenced(additional)) return previous;
    }
    var next = previous.state;
    next.phase = .finished;
    next.outcome = .unknown;
    return self.advance(previous.progress.revision, previous.progress.cancel, next);
}

test "application effect identity cannot change when retry operands change" {
    const t = std.testing;
    const descriptor = proofDescriptor();
    const key = try descriptor.key();
    var other = descriptor;
    other.operation[0] ^= 1;
    try t.expectEqualDeep(key, try other.key());
    try t.expect(!std.mem.eql(u8, &try descriptor.digest(), &try other.digest()));
    other = descriptor;
    other.request.content.sha256[0] ^= 1;
    try t.expectEqualDeep(key, try other.key());
    try t.expect(!std.mem.eql(u8, &try descriptor.digest(), &try other.digest()));
    other = descriptor;
    other.step += 1;
    try t.expect(!std.meta.eql(key, try other.key()));
    other = descriptor;
    other.request.scope.connection.principal += 1;
    try t.expectError(error.InvalidApplicationEffect, other.validate());
}
test "application effect metadata distinguishes unsent unknown and lost protected response" {
    const t = std.testing;
    var state: State = .{ .definition = p.Growth.current_definition, .descriptor = proofDescriptor(), .phase = .finished, .dispatch = null, .outcome = .unknown };
    try t.expectError(error.InvalidApplicationEffect, state.validate());
    state.outcome = .{ .not_dispatched = .guard };
    try state.validate();
    state.dispatch = .{ .nonce = @splat(9), .lease = .{ .key = state.descriptor.invocation, .revision = .{ .partition = 7, .next_lsn = 2 }, .additional = null } };
    state.outcome = .{ .response = .{ .status = 200, .bytes = 32, .sha256 = @splat(5), .body = null } };
    try state.validate();
    state.phase = .dispatching;
    try t.expectError(error.InvalidApplicationEffect, state.validate());
    state.outcome = null;
    try state.validate();
    state.dispatch.?.nonce = @splat(0);
    try t.expectError(error.InvalidApplicationEffect, state.validate());
}
fn proofDescriptor() Descriptor {
    const connection: c.DirectTableProtocol.Connection = .{ .scope = .{ .realm = 1, .resource = 2, .catalog = 3 }, .branch = 1, .audience = 5, .principal = 7, .role = 9 };
    const definition: d.Definition = .{ .object = .{ .scope = connection.scope, .branch = 1, .object = 11 }, .revision = 1, .digest = @splat(1) };
    var sink = definition;
    sink.object.object = 12;
    return .{
        .definition = p.Growth.current_definition,
        .invocation = .{ .definition = p.Growth.current_definition, .connection = connection, .account = @splat(1), .token = @splat(2) },
        .program = definition,
        .input = .{ .target = .{ .definition = p.Growth.current_definition, .interpretation = definition, .partition = 0 }, .operation = .{ .scope = connection.scope, .principal = connection.principal, .operation = 13 }, .ordinal = 0 },
        .request = .{ .scope = .{ .definition = p.Growth.current_definition, .connection = connection, .account = @splat(3) }, .format = c.DirectOwnedRecord.format, .content = .{ .bytes = 100, .sha256 = @splat(4) } },
        .namespace = 1,
        .step = 1,
        .instruction = 3,
        .sink = sink,
        .operation = @splat(8),
    };
}
