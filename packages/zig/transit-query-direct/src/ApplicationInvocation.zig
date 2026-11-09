//! Original Queue input and protected continuation ownership for ordered
//! programs. Recovery metadata contains no application values. Every data call
//! carries both the service generation and the invocation progress fence.
const std = @import("std");
const q = @import("root.zig");
const c = q.catalog;
const p = q.protocol;
const a = q.fuze.ApplicationProgram;
const d = p.DataLifecycle;
const M = q.ManagedApplication;
const T = c.DirectClientToken;
const R = c.DirectRecord;
const Self = @This();
pub const work_format: u32 = 0x41505731; // APW1
pub const input_format: u32 = R.guarded_bit | 0x41504931; // protected API1
manager: M,

pub const Input = struct {
    definition: p.Growth.Definition,
    claim: p.StreamQueue.ClaimReceipt,
    lease: p.StreamQueue.Lease,
    environment: a.Environment.Snapshot,
};

pub const Work = struct {
    definition: p.Growth.Definition,
    declaration: R.Reference,
    lease: p.Dataflow.Lease,
    attachment: ?c.DirectKV.Mutation,
    claim: p.StreamQueue.Claim,
    receipt: ?p.StreamQueue.ClaimReceipt,
    input_lease: ?p.StreamQueue.Lease,
    environment: ?R.Reference,
    phase: enum { claiming, reading, ready },
    pub fn validate(self: Work, value: M.Declaration, allocator: std.mem.Allocator) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.declaration.validate();
        try self.lease.validate();
        try self.claim.validate();
        if (!std.meta.eql(self.lease.target, try value.interpretation(allocator)) or
            !std.meta.eql(self.declaration.scope.connection, value.connection) or
            !std.meta.eql(self.claim, try value.inputClaim(allocator, self.claim.target.partition, self.claim.operation))) return error.InvalidDirectRecord;
        if (self.attachment) |mutation| {
            if (self.phase != .claiming) return error.InvalidDirectRecord;
            try value.connection.binding(mutation.binding);
            if (!std.meta.eql(mutation.binding.target, value.object)) return error.InvalidDirectRecord;
        }
        if (self.receipt) |receipt| {
            try receipt.validate();
            if (!std.meta.eql(receipt.claim, self.claim) or receipt.rows != 1) return error.InvalidDirectRecord;
        }
        if (self.input_lease) |lease| {
            try lease.validate();
            if (!std.meta.eql(lease.claim, self.claim.operation) or !std.meta.eql(lease.target, self.claim.target) or
                self.receipt == null or lease.expires_ms != self.receipt.?.expires_ms) return error.InvalidDirectRecord;
        }
        if (self.environment) |reference| {
            try reference.validate();
            if (reference.format != c.DirectOwnedRecord.format or reference.scope.connection.role != value.executor_role or
                reference.scope.connection.principal != value.connection.principal or
                !std.meta.eql(reference.scope.connection.scope, value.connection.scope) or
                reference.scope.connection.branch != value.connection.branch or
                reference.scope.connection.audience != value.connection.audience) return error.InvalidDirectRecord;
        }
        switch (self.phase) {
            .claiming => if (self.receipt != null or self.input_lease != null or self.environment != null) return error.InvalidDirectRecord,
            .reading => if (self.receipt == null or self.input_lease != null or self.environment != null) return error.InvalidDirectRecord,
            .ready => if (self.receipt == null or self.input_lease == null or self.environment == null) return error.InvalidDirectRecord,
        }
    }
};

pub fn key(self: Self, value: M.Declaration, epoch: u64, domain: []const u8) T.Key {
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update(domain);
    var bytes: [8]u8 = undefined;
    for ([_]u64{ value.object.object, value.operation.operation, epoch }) |number| {
        std.mem.writeInt(u64, &bytes, number, .big);
        hash.update(&bytes);
    }
    return .{ .definition = p.Growth.current_definition, .connection = self.manager.client.connection, .account = M.workAccount(), .token = hash.finalResult()[0..16].* };
}

fn inputKey(self: Self, value: M.Declaration, epoch: u64, connection: c.DirectTableProtocol.Connection) T.Key {
    var token = self.key(value, epoch, "transit.application.input.v1\x00");
    std.crypto.hash.sha2.Sha256.hash("transit.application.inputs.v1", &token.account, .{});
    token.connection = connection;
    return token;
}

pub fn load(self: Self, reference: R.Reference) !std.json.Parsed(Work) {
    const client = self.manager.client;
    if (!std.meta.eql(reference.scope.connection, client.connection)) return error.InvalidDirectRecord;
    const bytes = try R.read(client.allocator, client, reference);
    defer client.allocator.free(bytes);
    const binary = switch (reference.format) {
        c.DirectOwnedRecord.format => blk: {
            const parsed = try p.Json.parseFromSlice(c.DirectOwnedRecord.Envelope, client.allocator, bytes);
            defer parsed.deinit();
            try parsed.value.validate(reference);
            if (parsed.value.format != work_format) return error.InvalidDirectRecord;
            break :blk try parsed.value.bytes.decode(client.allocator, R.max_bytes);
        },
        c.DirectProgressRecord.format => blk: {
            const parsed = try p.Json.parseFromSlice(c.DirectProgressRecord.Envelope, client.allocator, bytes);
            defer parsed.deinit();
            try parsed.value.validate(reference);
            if (parsed.value.advance.format != work_format) return error.InvalidDirectRecord;
            break :blk try parsed.value.advance.bytes.decode(client.allocator, R.max_bytes);
        },
        else => return error.InvalidDirectRecord,
    };
    defer client.allocator.free(binary);
    return p.Json.parseFromSliceOwned(Work, client.allocator, binary);
}

/// Attach the immutable work before any Queue action. The caller supplies the
/// selected partition; the persisted original owns all subsequent retries.
pub fn start(self: Self, value: M.Declaration, partition: u32) !?T.Key {
    const m = self.manager;
    const observed = try m.inspect(value);
    if (observed.head.pending) |pending| return pending;
    if (observed.head.control.state != .active) return null;
    try m.requireDependencies(value, observed);
    var next = observed.head;
    next.attempt = try std.math.add(u64, next.attempt, 1);
    const token = self.key(value, next.attempt, "transit.application.invocation.v1\x00");
    next.pending = token;
    const known = try T.inspect(m.client, token);
    if (known) |progress| {
        const original = progress.original orelse return error.InvalidDirectRecord;
        if (original.phase == .closed) {
            var skipped = observed.head;
            skipped.attempt = next.attempt;
            skipped.refused = try std.math.add(u64, skipped.refused, 1);
            var scratch: std.heap.ArenaAllocator = .init(m.client.allocator);
            defer scratch.deinit();
            _ = try c.DirectKVClient.apply(&scratch, m.client, .{ .mutate = try m.mutation(&scratch, value, observed.storage, observed.position, skipped, m.operation(value, "skip-closed", observed.position.next_lsn), .present) });
            return null;
        }
        if (original.phase != .reserved) {
            const saved = try self.load(progress.record orelse progress.receipt.binding.intent.external.record);
            defer saved.deinit();
            try saved.value.validate(value, m.client.allocator);
            if (original.phase != .attached) _ = try self.attach(progress, saved.value);
            return token;
        }
    }
    const publication = try T.inspect(m.client, m.nameKey(value.namespace, value.name)) orelse return error.ClientOperationMissing;
    if (publication.original == null or publication.original.?.phase != .retained) return error.InvalidDirectRecord;
    var scratch: std.heap.ArenaAllocator = .init(m.client.allocator);
    defer scratch.deinit();
    const work: Work = .{
        .definition = p.Growth.current_definition,
        .declaration = publication.receipt.binding.intent.external.record,
        .lease = .{ .target = try value.interpretation(m.client.allocator), .control = next.control, .owner = m.operation(value, "worker", next.attempt), .epoch = next.attempt },
        .attachment = try m.mutation(&scratch, value, observed.storage, observed.position, next, m.operation(value, "claim", next.attempt), .present),
        .claim = try value.inputClaim(m.client.allocator, partition, m.operation(value, "queue-claim", next.attempt)),
        .receipt = null,
        .input_lease = null,
        .environment = null,
        .phase = .claiming,
    };
    try work.validate(value, m.client.allocator);
    const bytes = try p.Json.valueAllocBounded(scratch.allocator(), work, 64 * 1024);
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    if (known) |progress| if (!std.mem.eql(u8, &progress.receipt.binding.fingerprint, &digest)) {
        // The initial payload never became ready and a control change defeated
        // its exact attachment. Close that reservation before selecting again.
        _ = try c.DirectOwnedRecord.call(m.client, .{ .close_original = .{ .key = token, .expected = progress.revision } });
        return null;
    };
    const progress = try c.DirectOwnedRecord.stage(m.client, token, value.namespace, work.lease.owner.operation, digest, .{ .bytes = 128 * 1024 }, work_format, bytes);
    if (progress.original.?.phase == .closed) return error.OwnedRecordClosed;
    _ = try self.attach(progress, work);
    return token;
}
pub fn attach(self: Self, progress: T.Progress, work: Work) !T.Progress {
    return c.DirectOwnedRecord.call(self.manager.client, .{ .attach_original = .{ .key = progress.receipt.binding.key, .expected = progress.revision, .mutation = work.attachment orelse return error.InvalidDirectRecord } });
}

pub fn advance(self: Self, value: M.Declaration, progress: T.Progress, work: Work) !T.Progress {
    try work.validate(value, self.manager.client.allocator);
    const bytes = try p.Json.valueAllocBounded(self.manager.client.allocator, work, 64 * 1024);
    defer self.manager.client.allocator.free(bytes);
    const binary = try c.DirectTableProtocol.Binary.encode(self.manager.client.allocator, bytes);
    defer self.manager.client.allocator.free(binary.base64);
    return c.DirectProgressRecord.advance(self.manager.client, .{ .key = progress.receipt.binding.key, .expected = progress.revision, .pending = true, .cancel = progress.cancel, .format = work_format, .bytes = binary });
}

pub fn executor(self: Self, value: M.Declaration, progress: T.Progress, work: Work) !c.DirectTableClient {
    try progress.receipt.binding.key.requireSame(self.key(value, work.lease.epoch, "transit.application.invocation.v1\x00"));
    if (!std.meta.eql(work.lease.owner, self.manager.operation(value, "worker", work.lease.epoch)) or
        !std.meta.eql(work.claim.operation, self.manager.operation(value, "queue-claim", work.lease.epoch))) return error.DataflowIdentityConflict;
    const observed = try self.manager.inspect(value);
    try work.lease.requireCurrent(try value.interpretation(self.manager.client.allocator), observed.head.control, observed.head.attempt);
    if (!progress.pending or progress.cancel or observed.head.pending == null or
        !std.meta.eql(observed.head.pending.?, progress.receipt.binding.key) or
        progress.original == null or progress.original.?.phase != .attached) return error.DataflowLeaseFenced;
    try self.manager.requireDependencies(value, observed);
    var client = try self.manager.executor(value, observed);
    client.lease = try T.Lease.combine(client.lease, .{ .key = progress.receipt.binding.key, .revision = progress.revision });
    return client;
}

/// One bounded acquisition unit. A timeout accepts no replacement identity.
/// A receipt is saved separately before reading its immutable original payload.
pub fn acquire(self: Self, value: M.Declaration, progress: T.Progress, work: Work) !T.Progress {
    try value.validate(self.manager.client.allocator);
    try work.validate(value, self.manager.client.allocator);
    const client = try self.executor(value, progress, work);
    if (work.phase == .ready) return progress;
    var output: std.heap.ArenaAllocator = .init(client.allocator);
    defer output.deinit();
    var next = work;
    next.attachment = null;
    if (work.phase == .claiming) {
        const result = try c.DirectQueueClient.apply(&output, client, .{ .wait = .{ .claim = work.claim, .milliseconds = 1 } });
        if (result == .timed_out or result == .recovering) return progress;
        if (result != .operation or result.operation == null or result.operation.? != .claim) return error.InvalidQueueResponse;
        const receipt = result.operation.?.claim;
        if (receipt.rows != 1) return error.InvalidQueueResponse;
        next.receipt = receipt;
        next.phase = .reading;
    } else {
        const input_key = self.inputKey(value, work.lease.epoch, client.connection);
        if (try T.inspect(client, input_key)) |stored| {
            if (stored.original == null or stored.cancel or stored.original.?.phase == .closed) return error.OwnedRecordClosed;
            if (stored.original.?.phase != .reserved) {
                const input = try self.loadInput(client, value, work, stored.receipt.binding.intent.external.record);
                defer input.deinit();
                _ = try retainInput(client, input_key, stored);
                next.environment = stored.receipt.binding.intent.external.record;
                next.input_lease = input.value.lease;
                next.phase = .ready;
                return self.advance(value, progress, next);
            }
        }
        const result = try c.DirectQueueClient.apply(&output, client, .{ .page = .{ .cursor = .{ .receipt = work.receipt.?, .next = 0 }, .limits = .{ .rows = 1, .encoded_bytes = value.limits.continuation_bytes } } });
        if (result == .recovering) return progress;
        if (result != .page or result.page.rows.len != 1 or !result.page.cursor.complete()) return error.InvalidQueueResponse;
        const row = result.page.rows[0];
        try row.lease.requireBasis(result.page.basis, work.receipt.?);
        switch (row.lease.liveness) {
            .live => {},
            .unavailable => return error.QueueTimeUnavailable,
            .expired => return error.QueueLeaseExpired,
            .fenced => return error.DataflowLeaseFenced,
        }
        if (!std.meta.eql(result.page.source.declaration.stored.declaration.interpretation, work.claim.target.interpretation)) return error.TableDefinitionChanged;
        const input = try q.ApplicationData.rowValue(output.allocator(), result.page.source.schema, row.value.cells, null, null);
        var bound = try value.bind(client.allocator);
        defer bound.deinit();
        var index = try a.Cursor.Index.init(client.allocator, &value.program);
        defer index.deinit();
        var env = try a.Environment.init(client.allocator, index, bound, input);
        defer env.deinit();
        const input_record: Input = .{ .definition = p.Growth.current_definition, .claim = work.receipt.?, .lease = row.lease.original, .environment = env.snapshot(try value.digest(client.allocator)) };
        try a.Environment.validate(index, bound, try value.digest(client.allocator), input_record.environment);
        const bytes = try p.Json.valueAllocBounded(output.allocator(), input_record, value.limits.continuation_bytes);
        const guarded = try R.encodeGuarded(output.allocator(), client.connection, &.{ work.claim.target.interpretation.object, value.object }, bytes);
        var fingerprint: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(guarded, &fingerprint, .{});
        const stored = try c.DirectOwnedRecord.stage(client, input_key, value.namespace, self.manager.operation(value, "input", work.lease.epoch).operation, fingerprint, .{ .bytes = 4 * @as(u64, value.limits.continuation_bytes) + 4096 }, input_format, guarded);
        if (stored.original.?.phase == .closed or stored.cancel) return error.OwnedRecordClosed;
        _ = try retainInput(client, input_key, stored);
        next.environment = stored.receipt.binding.intent.external.record;
        next.input_lease = row.lease.original;
        next.phase = .ready;
    }
    return self.advance(value, progress, next);
}

fn retainInput(client: c.DirectTableClient, token: T.Key, stored: T.Progress) !T.Progress {
    var retained = try c.DirectOwnedRecord.call(client, .{ .retain_original = .{ .key = token, .expected = stored.revision } });
    if (retained.pending) retained = try T.update(client, .{ .key = token, .expected = retained.revision, .pending = false, .cancel = false, .record = null });
    return retained;
}

pub fn loadInput(self: Self, client: c.DirectTableClient, value: M.Declaration, work: Work, reference: R.Reference) !std.json.Parsed(Input) {
    if (reference.format != c.DirectOwnedRecord.format or !std.meta.eql(reference.scope.connection, client.connection)) return error.InvalidDirectRecord;
    const bytes = try R.read(client.allocator, client, reference);
    defer client.allocator.free(bytes);
    const envelope = try p.Json.parseFromSlice(c.DirectOwnedRecord.Envelope, client.allocator, bytes);
    defer envelope.deinit();
    try envelope.value.validate(reference);
    if (envelope.value.format != input_format) return error.InvalidDirectRecord;
    try envelope.value.key.requireSame(self.inputKey(value, work.lease.epoch, client.connection));
    const encoded = try envelope.value.bytes.decode(client.allocator, R.max_bytes);
    defer client.allocator.free(encoded);
    const guarded = try p.Json.parseFromSlice(R.Guarded, client.allocator, encoded);
    defer guarded.deinit();
    try guarded.value.validate(client.connection);
    if (guarded.value.objects.len != 2 or !std.meta.eql(guarded.value.objects[0], work.claim.target.interpretation.object) or
        !std.meta.eql(guarded.value.objects[1], value.object)) return error.InvalidDirectRecord;
    const payload = try guarded.value.payload.decode(client.allocator, value.limits.continuation_bytes);
    defer client.allocator.free(payload);
    const parsed = try p.Json.parseFromSliceOwned(Input, client.allocator, payload);
    errdefer parsed.deinit();
    if (parsed.value.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
    try parsed.value.claim.validate();
    try parsed.value.lease.validate();
    if (work.receipt == null or !std.meta.eql(parsed.value.claim, work.receipt.?) or
        !std.meta.eql(parsed.value.lease.target, work.claim.target) or !std.meta.eql(parsed.value.lease.claim, work.claim.operation) or
        parsed.value.lease.expires_ms != parsed.value.claim.expires_ms) return error.InvalidDirectRecord;
    var bound = try value.bind(client.allocator);
    defer bound.deinit();
    var index = try a.Cursor.Index.init(client.allocator, &value.program);
    defer index.deinit();
    try a.Environment.validate(index, bound, try value.digest(client.allocator), parsed.value.environment);
    // An input owner always retains the initial cursor, never a substituted
    // later instruction or fabricated completion.
    const cursor = parsed.value.environment.cursor;
    if (cursor.phase != .body or cursor.step != 0 or cursor.frames.len != 1 or
        !std.meta.eql(cursor.frames[0], a.Cursor.initial().frames[0])) return error.InvalidProgramNode;
    return parsed;
}

test "application invocation rejects invalid declarations before native acquisition" {
    const t = std.testing;
    const connection: c.DirectTableProtocol.Connection = .{ .scope = .{ .realm = 42, .resource = 3, .catalog = 9 }, .branch = 1, .audience = 5, .principal = 4, .role = null };
    const client: c.DirectTableClient = .{ .allocator = t.allocator, .authority = undefined, .service = undefined, .connection = connection, .key = undefined };
    const owner: Self = .{ .manager = .{ .client = client } };
    const invalid: M.Declaration = .{ .definition = p.Growth.current_definition, .connection = connection, .executor_role = 6, .namespace = 1, .name = try .init("invalid"), .object = .{ .scope = connection.scope, .branch = 1, .object = 7 }, .operation = .{ .scope = connection.scope, .principal = 4, .operation = 8 }, .source_digest = @splat(1), .program = undefined, .resources = &.{}, .limits = .{ .requests = 0, .scan_rows = 0, .result_bytes = 0, .continuation_bytes = 0 } };
    try t.expectError(error.InvalidQueryBudget, owner.start(invalid, 0));
    try t.expectError(error.InvalidQueryBudget, owner.acquire(invalid, undefined, undefined));
    try t.expect(!std.meta.eql(owner.key(invalid, 1, "work"), owner.key(invalid, 2, "work")));
    try t.expect(!std.meta.eql(owner.key(invalid, 1, "work"), owner.key(invalid, 1, "input")));
}
