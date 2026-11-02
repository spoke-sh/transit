//! Queue operations under current catalog policy. The host serializes this
//! partition with declaration edits and bounds residency independently of backlog.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const d = p.DataLifecycle;
const q = p.StreamQueue;
const read = p.QueueRead;
const s = c.storage;
const Queue = s.QueuePartition;
const Mutation = c.DirectQueueMutation;
const w = c.DirectTableProtocol;

pub const Request = union(enum) {
    observe: q.Partition,
    mutate: struct { work: Mutation.Request, payload: ?w.Binary },
    operation: Mutation.Request,
    cancel: Mutation.Request,
    page: struct { cursor: read.Cursor, limits: Queue.ClaimReadLimits },
    wait: struct { claim: q.Claim, milliseconds: u32 },

    pub fn mutation(self: Request) bool {
        return self == .mutate or self == .wait or self == .cancel;
    }
    pub fn control(self: Request) bool {
        return switch (self) {
            .operation, .cancel => true,
            .mutate => |value| value.work.control(),
            else => false,
        };
    }
    pub fn target(self: Request) q.Partition {
        return switch (self) {
            .observe => |value| value,
            .mutate => |value| value.work.target(),
            .operation, .cancel => |value| value.target(),
            .page => |value| value.cursor.receipt.claim.target,
            .wait => |value| value.claim.target,
        };
    }
    pub fn access(self: Request) c.LogAuthority.Access {
        return switch (self) {
            .mutate => |value| value.work.access(),
            .operation, .cancel => |value| value.access(),
            .observe => .inspect,
            .page, .wait => .acquire,
        };
    }
    pub fn identity(self: Request) ?d.Operation {
        return switch (self) {
            .mutate => |value| value.work.identity(),
            .operation, .cancel => |value| value.identity(),
            .page => |value| value.cursor.receipt.claim.operation,
            .wait => |value| value.claim.operation,
            .observe => null,
        };
    }
    pub fn validate(self: Request, principal: u64, scope: d.Scope) !void {
        try self.target().validate();
        if (!std.meta.eql(self.target().interpretation.object.scope, scope)) return error.CatalogDenied;
        if (self.identity()) |original| {
            try original.validate();
            if (original.principal != principal or !std.meta.eql(original.scope, scope)) return error.CatalogDenied;
        }
        switch (self) {
            .mutate => |value| {
                try value.work.validate();
                if ((value.work == .enqueue) != (value.payload != null)) return error.InvalidQueuePayload;
            },
            .operation, .cancel => |value| try value.validate(),
            .page => |value| {
                try value.cursor.validate();
                if (value.limits.rows == 0 or value.limits.rows > s.QueueSelection.max_rows or value.limits.encoded_bytes == 0 or value.limits.encoded_bytes > 4 * 1024 * 1024) return error.InvalidQueueReadBudget;
            },
            .observe => {},
            .wait => |value| {
                try value.claim.validate();
                if (value.milliseconds == 0 or value.milliseconds > c.client.WaitHint.max_ms) return error.InvalidQueueWait;
            },
        }
    }
};
pub const Receipt = union(enum) { enqueue: q.AppendReceipt, claim: q.ClaimReceipt, settle: q.SettlementReceipt, release: read.ReleaseReceipt, closed: p.LogWorkload.Closure };
pub const Row = struct {
    lease: read.LeaseObservation,
    operation: d.Operation,
    ordinal: u32,
    visible_ms: u64,
    encoded: w.Binary,
};
pub const Page = struct {
    pub const json_schema_sequence_bounds = .{ .rows = s.QueueSelection.max_rows };
    source: c.DirectLogProtocol.Definition,
    basis: read.Basis,
    rows: []const Row,
    cursor: read.Cursor,
    encoded_bytes: u32,
};
pub const Result = union(enum) {
    recovering: Queue.Recovery,
    cut: q.Cut,
    operation: ?Receipt,
    page: Page,
    /// No claim was accepted by this attempt. Another concurrent attempt with
    /// the same identity can still require original-operation reconciliation.
    timed_out: q.Cut,
    pub fn deinit(self: Result, allocator: std.mem.Allocator) void {
        if (self == .page) {
            allocator.free(self.page.source.schema.base64);
            for (self.page.rows) |row| allocator.free(row.encoded.base64);
            allocator.free(self.page.rows);
        }
    }
};
pub const Cached = struct {
    initialization: s.LogInitialization.Request,
    owner: Queue,
    pub fn deinit(self: *Cached) void {
        self.owner.deinit() catch unreachable;
        self.* = undefined;
    }
};
pub const Environment = struct { clock: ?s.LogTime.Source, recovery_steps: u16 = 256, waiting: ?c.DirectLog.Waiting = null };
fn authorize(guard: s.PublicationGuard) !void {
    _ = try guard.acquire(guard.context);
    guard.release(guard.context);
}
fn originalReceipt(work: Mutation.Request, record: s.LogEvidence.Record) !Receipt {
    const result: Receipt = switch (record.outcome) {
        .append => |value| .{ .enqueue = value },
        .claim => |value| .{ .claim = value.receipt },
        .settlement => |value| .{ .settle = value.receipt },
        .queue_release => |value| .{ .release = value },
        .closed => |value| .{ .closed = value },
        else => return error.LogOperationConflict,
    };
    try c.DirectQueueResponse.requireReceipt(work, result);
    return result;
}

fn mutate(owner: *Queue, declared: s.LogDeclaration.Stored, request: Mutation.Request, payload: []const u8, environment: Environment, guard: s.PublicationGuard, nonempty: bool) !Receipt {
    _ = environment;
    return switch (request) {
        .enqueue => |work| .{ .enqueue = try owner.enqueue(declared, work, payload, guard) },
        .claim => |work| .{ .claim = if (nonempty)
            owner.claimNonempty(declared, work, guard) catch |err| return if (err == error.QueueNotEligible) error.QueueTimeUnavailable else err
        else
            try owner.claim(declared, work, guard) },
        .settle => |work| .{ .settle = try owner.settle(declared, work, guard) },
        .release => |work| .{ .release = try owner.releaseClaimRead(declared, work, guard) },
    };
}

/// Output owns all returned bytes; scratch and the clock capability are scoped
/// to this request. Neither original claims nor cached owners grant rights.
pub fn apply(scratch: std.mem.Allocator, output: std.mem.Allocator, catalog: *c.DirectCatalog, slot: *?Cached, options: Queue.Options, environment: Environment, request: Request, policy: c.DirectCatalog.Policy) !Result {
    try request.validate(policy.subject.principal(), catalog.store.root.configuration.scope);
    if (environment.recovery_steps == 0 or environment.recovery_steps > 256) return error.InvalidLogRecoveryBudget;
    const current = try catalog.logAuthorization(scratch, .queue, request.target(), request.access(), policy);
    const binding: ?Mutation.Binding = switch (request) {
        .mutate => |value| try value.work.binding(scratch),
        .operation, .cancel => |value| try value.binding(scratch),
        .wait => |value| try (Mutation.Request{ .claim = value.claim }).binding(scratch),
        else => null,
    };
    const private_observation: ?c.DirectTransactionLogWork.Work = if (request == .operation) switch (request.operation) {
        .enqueue => |value| .{ .append = value },
        .settle => |value| if (value.action == .ack) .{ .queue_ack = value } else null,
        else => null,
    } else null;
    const reserved = if (private_observation) |work| try c.OperationBinding.transactionLogObservation(scratch, catalog.data_objects, work) else false;
    if (!reserved) if (binding) |original| if (try c.OperationBinding.lookupQueue(scratch, catalog.data_objects, original.operation)) |known| try known.requireSame(original);
    const initial = try current.definition.genesis(request.target().partition);
    if (slot.*) |*cached| if (!std.meta.eql(cached.initialization, initial)) {
        cached.deinit();
        slot.* = null;
    };
    if (slot.* == null) {
        var owned_options = options;
        owned_options.clock = null;
        owned_options.control = .{ .log = catalog.store.log, .objects = catalog.store.objects };
        slot.* = .{ .initialization = initial, .owner = try Queue.open(catalog.allocator, catalog.data_log, catalog.data_objects, initial, current.guard, owned_options) };
    }
    const owner = &slot.*.?.owner;
    owner.owner.options.clock = environment.clock;
    defer owner.owner.options.clock = null;
    if (!owner.owner.ready or try owner.owner.log.tail(initial.partition) != owner.owner.root.next_lsn) {
        const recovered = try owner.recoverStep(current.guard, environment.recovery_steps);
        if (!recovered.complete) return .{ .recovering = recovered };
    }
    var selected = request;
    if (request == .wait) {
        const waiting = environment.waiting orelse return error.QueueWaitUnavailable;
        const work: Mutation.Request = .{ .claim = request.wait.claim };
        if (try owner.operation(work.identity(), current.guard) != null) {
            selected = .{ .operation = work };
        } else {
            const readiness = try owner.claimReadiness(current.definition.stored, request.wait.claim, current.guard);
            if (!readiness.available) {
                const cut = try owner.observe(current.definition.stored, current.guard);
                try authorize(current.guard);
                if (waiting.expired) return .{ .timed_out = cut };
                if (waiting.registrations == 0 or waiting.registrations > current.definition.stored.declaration.limits.waiters) return error.QueueWaitCapacity;
                if (waiting.wake_after_ms) |hint| hint.* = readiness.wake_after_ms;
                return error.QueueWaitPending;
            }
            selected = .{ .mutate = .{ .work = work, .payload = null } };
        }
    }
    const result: Result = switch (selected) {
        .wait => unreachable,
        .cancel => |value| blk: {
            try authorize(current.guard);
            try c.OperationBinding.claimQueue(scratch, catalog.store.objects, binding.?);
            break :blk .{ .operation = try originalReceipt(value, try owner.cancel(current.definition.stored, value, current.guard)) };
        },
        .observe => .{ .cut = try owner.observe(current.definition.stored, current.guard) },
        .operation => |value| .{ .operation = if (try owner.operation(value.identity(), current.guard)) |record| try originalReceipt(value, record) else null },
        .page => |value| blk: {
            var page = try owner.readClaimPage(current.definition.stored, value.cursor, value.limits, catalog.allocator, current.guard);
            defer page.deinit();
            var declaration = try s.LogDeclaration.load(catalog.allocator, catalog.data_objects, page.source);
            defer declaration.deinit();
            var definition = current.definition;
            definition.stored = page.source;
            definition.properties = try c.DirectCatalog.Properties.decode(scratch, declaration.definition.properties);
            const schema_buffer = try catalog.allocator.alloc(u8, c.fuze.TableSchema.max_bytes);
            defer catalog.allocator.free(schema_buffer);
            const schema = try w.Binary.encode(output, try declaration.definition.schema.encode(schema_buffer));
            errdefer output.free(schema.base64);
            const rows = try output.alloc(Row, page.len);
            errdefer output.free(rows);
            var copied: usize = 0;
            errdefer for (rows[0..copied]) |row| output.free(row.encoded.base64);
            for (page.rows(), rows) |source, *row| {
                row.* = .{ .lease = source.lease, .operation = source.operation, .ordinal = source.ordinal, .visible_ms = source.visible_ms, .encoded = try w.Binary.encode(output, source.encoded) };
                copied += 1;
            }
            break :blk .{ .page = .{ .source = .{ .declaration = definition, .schema = schema }, .basis = page.basis, .rows = rows, .cursor = page.cursor, .encoded_bytes = page.encoded_bytes } };
        },
        .mutate => |value| blk: {
            const payload = if (value.payload) |encoded| try encoded.decode(scratch, options.batch_bytes) else &.{};
            if (value.work == .enqueue and !std.meta.eql(s.LogBatch.content(payload), value.work.enqueue.payload)) return error.LogPayloadConflict;
            try authorize(current.guard);
            const objects = if (value.work.control()) catalog.store.objects else catalog.data_objects;
            try c.OperationBinding.claimQueue(scratch, objects, binding.?);
            const accepted = mutate(owner, current.definition.stored, value.work, payload, environment, current.guard, request == .wait) catch |err| failure: {
                // The mutation owner already checks original success. Only its
                // closed/conflicting path needs another receipt lookup.
                if (err == error.LogOperationConflict) if (try owner.operation(value.work.identity(), current.guard)) |record|
                    break :failure try originalReceipt(value.work, record);
                break :failure try originalReceipt(value.work, try owner.refuse(current.definition.stored, value.work, err, current.guard));
            };
            break :blk .{ .operation = accepted };
        },
    };
    errdefer result.deinit(output);
    try authorize(current.guard);
    return result;
}
