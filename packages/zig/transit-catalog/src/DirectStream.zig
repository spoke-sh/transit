//! Stream payload composition under the catalog's current native policy. Hosts
//! serialize each partition with declaration edits and own the bounded cache.
//! Request scratch, proofs and private signing/time capabilities are never cached.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const d = p.DataLifecycle;
const q = p.StreamQueue;
const read = p.StreamRead;
const s = c.storage;
const Stream = s.StreamPartition;
const Mutation = c.DirectStreamMutation;
const w = c.DirectTableProtocol;

pub const Request = union(enum) {
    observe: q.Partition,
    mutate: struct { work: Mutation.Request, payload: ?w.Binary },
    operation: Mutation.Request,
    group: struct { target: q.Partition, id: u64 },
    cursor: struct { target: q.Partition, read: read.Handle },
    page: struct { cursor: read.Cursor, limits: Stream.ReadLimits },

    pub fn mutation(self: Request) bool {
        return self == .mutate;
    }
    pub fn control(self: Request) bool {
        return switch (self) {
            .operation => true,
            .mutate => |value| value.work.control(),
            else => false,
        };
    }
    pub fn target(self: Request) q.Partition {
        return switch (self) {
            .observe => |value| value,
            .mutate => |value| value.work.target(),
            .operation => |value| value.target(),
            .page => |value| value.cursor.coverage.cut.target,
            inline .group, .cursor => |value| value.target,
        };
    }
    pub fn access(self: Request) c.LogAuthority.Access {
        return switch (self) {
            .mutate => |value| value.work.access(),
            .operation => |value| value.access(),
            .group => .acquire,
            .observe => .inspect,
            .cursor, .page => .read,
        };
    }
    pub fn identity(self: Request) ?d.Operation {
        return switch (self) {
            .mutate => |value| value.work.identity(),
            .operation => |value| value.identity(),
            .cursor => |value| value.read.owner,
            .page => |value| value.cursor.read.owner,
            .observe, .group => null,
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
                if ((value.work == .append) != (value.payload != null)) return error.InvalidStreamPayload;
            },
            .operation => |value| try value.validate(),
            .group => |value| if (value.id == 0) return error.InvalidLogGroup,
            .cursor => |value| try value.read.validate(),
            .page => |value| {
                try value.cursor.validate();
                if (value.limits.rows == 0 or value.limits.rows > 65536 or value.limits.scanned_rows == 0 or value.limits.scanned_rows > 65536 or value.limits.encoded_bytes == 0 or value.limits.encoded_bytes > 4 * 1024 * 1024) return error.InvalidStreamReadBudget;
            },
            .observe => {},
        }
    }
};

pub const Receipt = union(enum) {
    append: q.AppendReceipt,
    assign: q.GroupAssignmentReceipt,
    consume: read.Receipt,
    release: read.ReleaseReceipt,
    offset: q.OffsetReceipt,
};
pub const Row = struct {
    offset: u64,
    operation: d.Operation,
    ordinal: u32,
    tombstone: bool,
    encoded: w.Binary,
};
pub const Page = struct {
    pub const json_schema_sequence_bounds = .{ .rows = 65536 };
    source: c.DirectLogProtocol.Definition,
    rows: []const Row,
    cursor: read.Cursor,
    examined: u32,
    encoded_bytes: u32,
};
pub const Result = union(enum) {
    /// Bounded replay has not reached the current accepted frontier. This
    /// result accepts no new mutation and supplies no complete data coverage.
    recovering: Stream.Recovery,
    cut: q.Cut,
    operation: ?Receipt,
    group: ?q.GroupProgress,
    cursor: read.Cursor,
    page: Page,
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
    owner: Stream,
    pub fn deinit(self: *Cached) void {
        self.owner.deinit() catch unreachable; // Public pages own their rows.
        self.* = undefined;
    }
};
pub const Environment = struct {
    authority: s.LogRead.Authority,
    clock: ?s.LogTime.Source,
    recovery_steps: u16 = 256,
};
fn authorize(guard: s.PublicationGuard) !void {
    _ = try guard.acquire(guard.context);
    guard.release(guard.context);
}
fn receipt(record: s.LogEvidence.Record) Receipt {
    return switch (record.outcome) {
        .append => |value| .{ .append = value },
        .assignment => |value| .{ .assign = value },
        .read => |value| .{ .consume = value },
        .release => |value| .{ .release = value },
        .offset => |value| .{ .offset = value.receipt },
    };
}
fn originalReceipt(work: Mutation.Request, record: s.LogEvidence.Record) !Receipt {
    switch (work) {
        .append => |value| {
            if (record.outcome != .append) return error.LogOperationConflict;
            try record.outcome.append.requireAppend(value);
        },
        .assign => |value| {
            if (record.outcome != .assignment) return error.LogOperationConflict;
            try record.outcome.assignment.requireAssignment(value);
        },
        .consume => |value| {
            if (record.outcome != .read) return error.LogOperationConflict;
            try record.outcome.read.requireRequest(value);
        },
        .release => |value| {
            if (record.outcome != .release) return error.LogOperationConflict;
            try record.outcome.release.requireRelease(value);
        },
        .offset => |value| {
            if (record.outcome != .offset) return error.LogOperationConflict;
            try record.outcome.offset.receipt.requireCommit(value.commit);
            if (!std.meta.eql(record.outcome.offset.cursor, value.cursor)) return error.StreamReadConflict;
        },
    }
    return receipt(record);
}

/// `slot` and its provider/allocator lifetimes belong to the host. The slot
/// bounds active residency, never durable cardinality. Results use output;
/// scratch may reset immediately after this call and must differ from output.
pub fn apply(scratch: std.mem.Allocator, output: std.mem.Allocator, catalog: *c.DirectCatalog, slot: *?Cached, options: Stream.Options, environment: Environment, request: Request, policy: c.DirectCatalog.Policy) !Result {
    try request.validate(policy.subject.principal(), catalog.store.root.configuration.scope);
    if (environment.recovery_steps == 0 or environment.recovery_steps > 256) return error.InvalidLogRecoveryBudget;
    var current = try catalog.streamAuthorization(scratch, request.target(), request.access(), policy);
    const binding: ?Mutation.Binding = switch (request) {
        .mutate => |value| try value.work.binding(scratch),
        .operation => |value| try value.binding(scratch),
        else => null,
    };
    if (binding) |original| if (try c.OperationBinding.lookupStream(scratch, catalog.data_objects, original.operation)) |known| try known.requireSame(original);
    const initial = try current.definition.genesis(request.target().partition);
    if (slot.*) |*cached| if (!std.meta.eql(cached.initialization, initial)) {
        cached.deinit();
        slot.* = null;
    };
    if (slot.* == null) {
        var owned_options = options;
        owned_options.clock = null;
        owned_options.control = .{ .log = catalog.store.log, .objects = catalog.store.objects };
        slot.* = .{ .initialization = initial, .owner = try Stream.open(catalog.allocator, catalog.data_log, catalog.data_objects, initial, current.guard, owned_options) };
    }
    const owner = &slot.*.?.owner;
    owner.options.clock = environment.clock;
    defer owner.options.clock = null;
    if (!owner.ready or try owner.log.tail(initial.partition) != owner.root.next_lsn) {
        const recovered = try owner.recoverStep(current.guard, environment.recovery_steps);
        if (!recovered.complete) return .{ .recovering = recovered };
    }
    // A retained group pin does not preserve acquire rights. Resolve its real
    // request before deciding whether the current disclosure needs that right;
    // a caller cannot relabel group consumption as an ordinary positional read.
    const handle: ?read.Handle = switch (request) {
        .cursor => |value| value.read,
        .page => |value| value.cursor.read,
        else => null,
    };
    if (handle) |retained| {
        const original = try owner.operation(retained.owner, current.guard) orelse return error.StreamReadMissing;
        if (original.outcome != .read or !std.meta.eql(original.outcome.read.handle(), retained)) return error.StreamReadConflict;
        if (original.outcome.read.request.group != null)
            current = try catalog.streamAuthorization(scratch, request.target(), .acquire, policy);
    }
    const result: Result = switch (request) {
        .observe => .{ .cut = try owner.observe(current.definition.stored, current.guard) },
        .operation => |value| .{ .operation = if (try owner.operation(value.identity(), current.guard)) |record| try originalReceipt(value, record) else null },
        .group => |value| .{ .group = try owner.group(value.id, current.guard) },
        .cursor => |value| .{ .cursor = try owner.readCursor(value.read, environment.authority, current.guard) },
        .page => |value| blk: {
            var page = try owner.readPage(value.cursor, environment.authority, value.limits, catalog.allocator, current.guard);
            defer page.deinit();
            const original = (try owner.operation(value.cursor.read.owner, current.guard)).?;
            var declaration = try s.LogDeclaration.load(catalog.allocator, catalog.data_objects, original.declared);
            defer declaration.deinit();
            var definition = current.definition;
            definition.stored = original.declared;
            definition.properties = try c.DirectCatalog.Properties.decode(scratch, declaration.definition.properties);
            const schema_buffer = try catalog.allocator.alloc(u8, c.fuze.TableSchema.max_bytes);
            defer catalog.allocator.free(schema_buffer);
            const schema = try w.Binary.encode(output, try declaration.definition.schema.encode(schema_buffer));
            errdefer output.free(schema.base64);
            const rows = try output.alloc(Row, page.count);
            errdefer output.free(rows);
            var copied: usize = 0;
            errdefer for (rows[0..copied]) |row| output.free(row.encoded.base64);
            for (page.rows(), rows) |source, *row| {
                row.* = .{
                    .offset = source.offset,
                    .operation = source.operation,
                    .ordinal = source.encoded.ordinal,
                    .tombstone = source.encoded.tombstone,
                    .encoded = try w.Binary.encode(output, source.encoded.bytes),
                };
                copied += 1;
            }
            break :blk .{ .page = .{ .source = .{ .declaration = definition, .schema = schema }, .rows = rows, .cursor = page.cursor, .examined = page.examined, .encoded_bytes = page.encoded_bytes } };
        },
        .mutate => |value| blk: {
            // A smaller successor declaration cannot invalidate an already
            // accepted append retry. Storage applies current declaration limits
            // only after original-result lookup; deployment bounds still apply.
            const payload = if (value.payload) |encoded| try encoded.decode(scratch, options.batch_bytes) else &.{};
            if (value.work == .append and !std.meta.eql(s.LogBatch.content(payload), value.work.append.payload)) return error.LogPayloadConflict;
            try authorize(current.guard);
            const objects = if (value.work.control()) catalog.store.objects else catalog.data_objects;
            try c.OperationBinding.claimStream(scratch, objects, binding.?);
            const accepted: Receipt = switch (value.work) {
                .append => |work| .{ .append = try owner.append(current.definition.stored, work, payload, current.guard) },
                .assign => |work| .{ .assign = try owner.assign(current.definition.stored, work, current.guard) },
                .consume => |work| .{ .consume = try owner.beginRead(current.definition.stored, work, current.guard) },
                .release => |work| .{ .release = try owner.releaseRead(current.definition.stored, work, current.guard) },
                .offset => |work| .{ .offset = try owner.commitOffset(current.definition.stored, work.commit, work.cursor, environment.authority, current.guard) },
            };
            break :blk .{ .operation = accepted };
        },
    };
    errdefer result.deinit(output);
    try authorize(current.guard);
    return result;
}
