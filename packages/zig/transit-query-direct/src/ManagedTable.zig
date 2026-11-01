//! Finite managed Table computation over catalog declarations and the common
//! Table/KV transaction owner. No Station turns or process-local durable queue.
const std = @import("std");
const q = @import("root.zig");
const c = q.catalog;
const p = q.protocol;
const d = p.DataLifecycle;
const f = q.fuze;
const flow = p.Dataflow;
const KV = c.DirectKVClient;
const Tx = c.DirectTransactionClient;
const w = c.DirectTableProtocol;
const Self = @This();
pub const declaration_format: u32 = 0x44464431; // DFD1
pub const work_format: u32 = 0x44465731; // DFW1
pub const page_format: u32 = 0x44465031; // DFP1
pub const head_key = "\x00dataflow/head";
pub const max_definition_bytes = 64 * 1024;
pub const spec: c.storage.KVDeclaration.Spec = .{ .value_type = .binary, .nullable = false };

pub const Declaration = struct {
    definition: p.Growth.Definition,
    connection: w.Connection,
    namespace: u64,
    name: c.TableAuthority.Name,
    object: d.Object,
    operation: d.Operation,
    source: c.DirectTableBinding,
    output: c.DirectTableBinding,
    sql: []const u8,
    options: q.DirectRelationalQuery.Options,

    pub fn validate(self: Declaration) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.connection.validate();
        try self.connection.object(self.object);
        try self.operation.validate();
        try self.name.validate();
        try self.source.validate();
        try self.output.validate();
        if (self.namespace == 0 or self.sql.len == 0 or self.sql.len > f.Sql.max_statement_bytes or
            !std.meta.eql(self.operation.scope, self.connection.scope) or self.operation.principal != self.connection.principal or
            !std.meta.eql(self.source.connection, self.connection) or !std.meta.eql(self.output.connection, self.connection) or
            self.namespace != self.source.namespace or self.namespace != self.output.namespace or
            std.meta.eql(self.source.interpretation.interpretation.object, self.output.interpretation.interpretation.object) or
            std.meta.eql(self.object, self.source.interpretation.interpretation.object) or std.meta.eql(self.object, self.output.interpretation.interpretation.object) or
            self.options.consistency != .independent_table_snapshots) return error.UnsupportedManagedTable;
    }
    pub fn digest(self: Declaration, allocator: std.mem.Allocator) ![32]u8 {
        try self.validate();
        const bytes = try p.Json.valueAllocBounded(allocator, self, max_definition_bytes);
        defer allocator.free(bytes);
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        hash.update("transit.managed.table.definition.v1\x00");
        hash.update(bytes);
        return hash.finalResult();
    }
    pub fn interpretation(self: Declaration, allocator: std.mem.Allocator) !d.Definition {
        return .{ .object = self.object, .revision = 1, .digest = try self.digest(allocator) };
    }
};

/// The named computation's current head is a normal direct KV participant.
/// Complete revisions remain separate durable keys in that same paged object.
pub const Head = struct {
    definition: p.Growth.Definition,
    declaration: [32]u8,
    control: flow.Control,
    attempt: u64,
    revision: u64,
    completed_refresh: u64,
    source: ?d.Position,
    rows: u64,
    pending: ?c.DirectClientToken.Key,
    pending_record: ?c.DirectRecord.Reference,
    completed: ?c.DirectClientToken.Key,
    blocked: flow.Blocked,
    retirement_complete: bool,

    pub fn initial(digest: [32]u8) Head {
        return .{ .definition = p.Growth.current_definition, .declaration = digest, .control = .initial(), .attempt = 0, .revision = 0, .completed_refresh = 0, .source = null, .rows = 0, .pending = null, .pending_record = null, .completed = null, .blocked = .none, .retirement_complete = false };
    }
    pub fn validate(self: Head) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.control.validate();
        if (self.retirement_complete and self.control.state != .retired) return error.InvalidManagedTableHead;
        if ((self.revision == 0) != (self.completed == null) or (self.revision == 0) != (self.source == null) or
            self.completed_refresh > self.control.refresh or (self.pending != null and self.attempt == 0) or ((self.pending == null) != (self.pending_record == null))) return error.InvalidManagedTableHead;
        if (self.source) |source| try source.validate();
        if (self.pending) |key| try key.validate();
        if (self.completed) |key| try key.validate();
    }
};
pub const Observation = struct {
    head: Head,
    storage: d.Definition,
    position: d.Position,
    completion: ?p.Transaction.Decision,
};
pub const Work = struct {
    definition: p.Growth.Definition,
    declaration: c.DirectRecord.Reference,
    lease: flow.Lease,
    previous: Head,
    transaction: c.DirectClientToken.Key,
    phase: enum { acquiring, evaluating, staging, checkpoint, deciding, complete },
    pages: ?c.DirectRecord.Reference,
    page_count: u64,
    rows: u64,
    source: ?d.Position,
    next_page: ?c.DirectRecord.Reference,
    sequence: u64,
    statement: ?c.DirectTransactionWorkspace.Request,
};
pub const Page = struct {
    definition: p.Growth.Definition,
    transaction: c.DirectClientToken.Key,
    ordinal: u64,
    previous: ?c.DirectRecord.Reference,
    row: w.Binary,
};
client: c.DirectTableClient,

pub fn account() [32]u8 {
    var result: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash("transit.managed.table.declarations.v1", &result, .{});
    return result;
}
pub fn nameKey(self: Self, namespace: u64, name: c.TableAuthority.Name) c.DirectClientToken.Key {
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    var bytes: [8]u8 = undefined;
    std.mem.writeInt(u64, &bytes, namespace, .big);
    hash.update(&bytes);
    hash.update(name.slice());
    const digest = hash.finalResult();
    return .{ .definition = p.Growth.current_definition, .connection = self.client.connection, .account = account(), .token = digest[0..16].* };
}
fn operation(self: Self, declaration: Declaration, label: []const u8, ordinal: u64) d.Operation {
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.managed.table.operation.v1\x00");
    hash.update(label);
    var bytes: [8]u8 = undefined;
    for ([_]u64{ declaration.object.object, declaration.operation.operation, ordinal }) |value| {
        std.mem.writeInt(u64, &bytes, value, .big);
        hash.update(&bytes);
    }
    const digest = hash.finalResult();
    return .{ .scope = self.client.connection.scope, .principal = self.client.connection.principal, .operation = std.mem.readInt(u64, digest[0..8], .big) | 1 };
}
fn workKey(self: Self, declaration: Declaration, attempt: u64, label: []const u8) c.DirectClientToken.Key {
    var result = self.nameKey(declaration.namespace, declaration.name);
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update(label);
    hash.update(&result.token);
    var bytes: [8]u8 = undefined;
    std.mem.writeInt(u64, &bytes, attempt, .big);
    hash.update(&bytes);
    const digest = hash.finalResult();
    result.token = digest[0..16].*;
    std.crypto.hash.sha2.Sha256.hash(label, &result.account, .{});
    return result;
}

/// Read-only preparation. This first profile accepts one ordinary Table source,
/// a separately declared output Table and the existing finite relational plan.
pub fn prepare(self: Self, namespace: u64, name: []const u8, object: u64, identity: u64, output: []const u8, sql: []const u8, options: q.DirectRelationalQuery.Options) !Declaration {
    var compiled = try q.DirectRelationalCompilation.prepare(self.client.allocator, &.{self.client}, namespace, sql, .maintained, options, null);
    defer compiled.deinit();
    const response = try self.client.call(.{ .lookup = .{ .namespace = namespace, .name = output } });
    defer response.deinit();
    const metadata = response.value.result.lookup orelse return error.TableNotFound;
    const binding = try c.DirectTableBinding.init(self.client.connection, metadata);
    _ = try binding.require(self.client, .insert);
    _ = try binding.require(self.client, .delete);
    const bytes = try metadata.schema.decode(self.client.allocator, f.TableSchema.max_bytes);
    defer self.client.allocator.free(bytes);
    var schema = try f.TableSchema.decode(self.client.allocator, bytes);
    defer schema.deinit();
    var fields: [f.Relational.max_outputs]f.Types.Field = undefined;
    const row_type = try compiled.plan.outputSchema(&fields);
    if (row_type.structure.len != schema.schema.columns.len) return error.ManagedTableSchemaMismatch;
    for (row_type.structure, schema.schema.columns) |field, column| {
        if (!std.mem.eql(u8, field.name, column.name) or !try field.type.eql(column.type) or (field.nullable and !column.nullable)) return error.ManagedTableSchemaMismatch;
    }
    var selected_object = object;
    if (selected_object == 0) {
        selected_object = 1;
        while (selected_object == binding.interpretation.interpretation.object.object or selected_object == compiled.bindings[0].interpretation.interpretation.object.object) selected_object += 1;
    }
    const result: Declaration = .{
        .definition = p.Growth.current_definition,
        .connection = self.client.connection,
        .namespace = namespace,
        .name = try .init(name),
        .object = .{ .scope = self.client.connection.scope, .branch = self.client.connection.branch, .object = selected_object },
        .operation = .{ .scope = self.client.connection.scope, .principal = self.client.connection.principal, .operation = identity },
        .source = compiled.bindings[0],
        .output = binding,
        .sql = sql,
        .options = options,
    };
    try result.validate();
    return result;
}

fn store(self: Self, selected: [32]u8, format: u32, value: anytype) !c.DirectRecord.Reference {
    const bytes = try p.Json.valueAllocBounded(self.client.allocator, value, c.DirectRecord.max_bytes);
    defer self.client.allocator.free(bytes);
    return c.DirectRecord.stage(self.client, selected, format, bytes);
}
pub fn load(self: Self, comptime T: type, reference: c.DirectRecord.Reference, format: u32) !std.json.Parsed(T) {
    if (reference.format != format or !std.meta.eql(reference.scope.connection, self.client.connection)) return error.InvalidManagedTableRecord;
    const bytes = try c.DirectRecord.read(self.client.allocator, self.client, reference);
    defer self.client.allocator.free(bytes);
    return p.Json.parseFromSliceOwned(T, self.client.allocator, bytes);
}
pub fn find(self: Self, namespace: u64, name: c.TableAuthority.Name) !?std.json.Parsed(Declaration) {
    const progress = try c.DirectClientToken.inspect(self.client, self.nameKey(namespace, name)) orelse return null;
    if (progress.receipt.binding.intent != .external) return error.InvalidManagedTableRecord;
    const result = try self.load(Declaration, progress.receipt.binding.intent.external.record, declaration_format);
    errdefer result.deinit();
    try result.value.validate();
    if (result.value.namespace != namespace or !std.meta.eql(result.value.name, name)) return error.DataflowIdentityConflict;
    return result;
}

/// Save the complete Declaration before invoking publication. Initialization and
/// dependency registration are resumed under that original accepted identity.
pub fn publish(self: Self, value: Declaration) !Observation {
    try value.validate();
    if (!std.meta.eql(value.connection, self.client.connection)) return error.DataflowIdentityConflict;
    const token = self.nameKey(value.namespace, value.name);
    const reference = try self.store(token.account, declaration_format, value);
    const receipt = try c.DirectClientToken.bind(self.client, .{ .key = token, .fingerprint = try value.digest(self.client.allocator), .intent = .{ .external = .{ .connection = value.connection, .namespace = value.namespace, .operation = value.operation.operation, .record = reference } } });
    try receipt.binding.intent.external.record.requireSame(reference);
    if ((try c.DirectClientToken.inspect(self.client, token)).?.cancel) return error.DataflowSourceChanged;
    return self.initialize(value, token);
}
pub fn initialize(self: Self, value: Declaration, token: c.DirectClientToken.Key) !Observation {
    var output: std.heap.ArenaAllocator = .init(self.client.allocator);
    defer output.deinit();
    const owner = (try self.client.require(.{ .namespace = value.namespace, .target = null, .access = .create_table })).role;
    const create = try KV.prepareDeclaration(self.client.allocator, .{
        .binding = .{ .definition = p.Growth.current_definition, .identity = self.operation(value, "create", 0), .target = value.object, .action = .create, .expected_definition = null, .expected_data = null, .intent = @splat(0) },
        .namespace = value.namespace,
        .name = value.name,
        .action = .{ .create = .{ .owner = owner, .spec = spec } },
    });
    _ = try KV.apply(&output, self.client, .{ .declaration = .{ .declaration = create, .command = .admit, .steps = 1 } });
    const initialized = try KV.apply(&output, self.client, .{ .declaration = .{ .declaration = create, .command = .execute, .steps = 64 } });
    if (initialized.declaration.operation != .committed) return error.ManagedTableInitializationPending;
    const metadata = (try KV.apply(&output, self.client, .{ .observe = value.object })).definition;
    const head = Head.initial(try value.digest(self.client.allocator));
    try self.put(value, metadata.interpretation.interpretation, null, head, self.operation(value, "initial", 0), .absent);
    for ([_]c.DirectTableBinding{ value.source, value.output }, 0..) |binding, index| {
        const edge: c.DirectDependency.Binding = .{
            .definition = p.Growth.current_definition,
            .connection = self.client.connection,
            .operation = self.operation(value, "dependency", index).operation,
            .edge = .{ .source = binding.interpretation.interpretation, .dependent = .{ .kind = .managed, .interpretation = metadata.interpretation.interpretation }, .privileges = if (index == 0) c.TableAuthority.select else c.TableAuthority.insert | c.TableAuthority.delete },
            .action = .register,
            .authority = .dependent,
        };
        const response = try self.client.call(.{ .dependency_operation = .{ .binding = edge, .command = .accept } });
        defer response.deinit();
        if (response.value.result.dependency_operation != .outcome or response.value.result.dependency_operation.outcome.phase != .applied) {
            const observed = try self.inspect(value);
            var blocked = observed.head;
            blocked.blocked = .source_changed;
            try self.put(value, observed.storage, observed.position, blocked, self.operation(value, "publication-refused", observed.position.next_lsn), .present);
            const progress = (try c.DirectClientToken.inspect(self.client, token)).?;
            _ = try c.DirectClientToken.update(self.client, .{ .key = token, .expected = progress.revision, .pending = false, .cancel = true, .record = null });
            return error.DataflowSourceChanged;
        }
    }
    const progress = (try c.DirectClientToken.inspect(self.client, token)).?;
    if (progress.pending) _ = try c.DirectClientToken.update(self.client, .{ .key = token, .expected = progress.revision, .pending = false, .cancel = false, .record = null });
    return self.inspect(value);
}

pub fn inspect(self: Self, value: Declaration) !Observation {
    var output: std.heap.ArenaAllocator = .init(self.client.allocator);
    defer output.deinit();
    const read = (try KV.apply(&output, self.client, .{ .get = .{ .object = value.object, .key = head_key } })).value;
    const cell = read.value orelse return error.ManagedTableInitializationPending;
    if (cell != .value or cell.value != .atom or cell.value.atom != .bytes) return error.InvalidManagedTableRecord;
    const parsed = try p.Json.parseFromSlice(Head, self.client.allocator, cell.value.atom.bytes);
    defer parsed.deinit();
    try parsed.value.validate();
    if (!std.mem.eql(u8, &parsed.value.declaration, &try value.digest(self.client.allocator))) return error.DataflowIdentityConflict;
    var completion: ?p.Transaction.Decision = null;
    if (parsed.value.completed) |key| {
        const tx: Tx = .{ .catalog = self.client };
        const status = try tx.inspect(key);
        if (status.observation != .decided or status.observation.decided.outcome != .committed) return error.IncompleteDataflowCoverage;
        completion = status.observation.decided;
    }
    return .{ .head = parsed.value, .storage = read.interpretation.interpretation, .position = read.position, .completion = completion };
}
fn mutation(_: Self, arena: *std.heap.ArenaAllocator, value: Declaration, storage: d.Definition, position: ?d.Position, head: Head, identity: d.Operation, expect: @FieldType(@FieldType(c.storage.KVPartition.Change, "put"), "expect")) !c.DirectKV.Mutation {
    const bytes = try p.Json.valueAllocBounded(arena.allocator(), head, max_definition_bytes);
    return KV.prepareMutation(arena, .{ .definition = p.Growth.current_definition, .identity = identity, .target = value.object, .action = .insert, .expected_definition = storage, .expected_data = position, .intent = @splat(0) }, spec, &.{.{ .put = .{ .key = head_key, .value = .{ .value = .{ .atom = .{ .bytes = bytes } } }, .expect = expect } }});
}
fn put(self: Self, value: Declaration, storage: d.Definition, position: ?d.Position, head: Head, identity: d.Operation, expect: @FieldType(@FieldType(c.storage.KVPartition.Change, "put"), "expect")) !void {
    var output: std.heap.ArenaAllocator = .init(self.client.allocator);
    defer output.deinit();
    const request = try self.mutation(&output, value, storage, position, head, identity, expect);
    const result = try KV.apply(&output, self.client, .{ .mutate = request });
    if (result.operation == null) return error.ManagedTableConflict;
}

/// Commands preserve pending recovery and the last completed revision. The KV
/// conflict guard fences an in-flight output transaction at its real decision.
pub fn prepareControl(self: Self, value: Declaration, attempt: flow.ControlAttempt) ![]u8 {
    try attempt.validate();
    if (!std.meta.eql(attempt.target, try value.interpretation(self.client.allocator))) return error.DataflowIdentityConflict;
    const observed = try self.inspect(value);
    var next = observed.head;
    if (!std.meta.eql(next.control, attempt.expected)) return error.DataflowLeaseFenced;
    next.control = try next.control.apply(attempt.command);
    switch (attempt.command) {
        .authorize, .activate, .resume_computation, .refresh => {
            _ = try value.source.require(self.client, .read);
            _ = try value.output.require(self.client, .insert);
            _ = try value.output.require(self.client, .delete);
            for ([_]c.DirectTableBinding{ value.source, value.output }, 0..) |binding, index| {
                const response = try self.client.call(.{ .dependency_state = .{ .source = binding.interpretation.interpretation, .dependent = .{ .kind = .managed, .interpretation = observed.storage }, .privileges = if (index == 0) c.TableAuthority.select else c.TableAuthority.insert | c.TableAuthority.delete } });
                defer response.deinit();
                if (!response.value.result.dependency_state.present) return error.DataflowSourceChanged;
            }
        },
        .suspend_computation, .retire => {},
    }
    next.attempt = try std.math.add(u64, next.attempt, 1);
    next.blocked = .none;
    var arena: std.heap.ArenaAllocator = .init(self.client.allocator);
    defer arena.deinit();
    const frozen = try self.mutation(&arena, value, observed.storage, observed.position, next, attempt.operation, .any);
    return KV.save(self.client.allocator, self.client.connection, frozen);
}

/// Persist the bytes returned by prepareControl before calling. Repeating these
/// bytes observes the original KV receipt even after later controls or progress.
pub fn applyControl(self: Self, saved: []const u8) !c.storage.TablePartition.Evidence {
    const loaded = try KV.load(self.client.allocator, saved);
    defer loaded.deinit();
    if (!std.meta.eql(loaded.value.connection, self.client.connection)) return error.DataflowIdentityConflict;
    var output: std.heap.ArenaAllocator = .init(self.client.allocator);
    defer output.deinit();
    const mutation_ = loaded.value.mutation;
    const result = KV.apply(&output, self.client, .{ .mutate = mutation_ }) catch |err| {
        // A transport error is not rejection. First observe a newer head, then
        // inspect the original receipt: this ordering also covers a concurrent
        // successful retry between the failed call and these observations.
        const expected = mutation_.binding.expected_data orelse return err;
        const current = (KV.apply(&output, self.client, .{ .get = .{ .object = mutation_.binding.target, .key = head_key } }) catch return err).value;
        const receipt = (KV.apply(&output, self.client, .{ .operation = mutation_.binding }) catch return err).operation;
        if (receipt) |evidence| return evidence;
        if (current.position.partition == expected.partition and current.position.next_lsn > expected.next_lsn) return error.ManagedTableConflict;
        return err;
    };
    return result.operation orelse error.ManagedTableConflict;
}

fn progressWork(self: Self, progress: c.DirectClientToken.Progress, work: Work) !void {
    const reference = try self.store(progress.receipt.binding.key.account, work_format, work);
    _ = try c.DirectClientToken.update(self.client, .{ .key = progress.receipt.binding.key, .expected = progress.revision, .pending = work.phase != .complete, .cancel = false, .record = reference });
}

/// Claim one complete successor under an exact current control/head. The work
/// record exists before the head can reference it. A lost claim reply is retried
/// with the same immutable request; it cannot select a different source basis.
pub fn start(self: Self, value: Declaration) !?c.DirectClientToken.Key {
    return self.startInner(value) catch |err| {
        const reason: flow.Blocked = switch (err) {
            error.CatalogDenied, error.AccessDenied, error.Rejected => .authorization,
            error.TableDefinitionChanged, error.TableNotFound, error.DataflowSourceChanged => .source_changed,
            else => return err,
        };
        const observed = try self.inspect(value);
        if (observed.head.control.state != .active or observed.head.pending != null) return err;
        if (observed.head.blocked != reason) {
            var next = observed.head;
            next.blocked = reason;
            try self.put(value, observed.storage, observed.position, next, self.operation(value, "blocked", observed.position.next_lsn), .present);
        }
        return null;
    };
}
fn startInner(self: Self, value: Declaration) !?c.DirectClientToken.Key {
    const observed = try self.inspect(value);
    if (observed.head.pending) |pending| {
        const reference = observed.head.pending_record orelse return error.InvalidManagedTableRecord;
        const original = try self.load(Work, reference, work_format);
        defer original.deinit();
        _ = try c.DirectClientToken.bind(self.client, .{ .key = pending, .fingerprint = reference.content.sha256, .intent = .{ .external = .{ .connection = self.client.connection, .namespace = value.namespace, .operation = original.value.lease.owner.operation, .record = reference } } });
        const progress = (try c.DirectClientToken.inspect(self.client, pending)).?;
        if (progress.pending) return pending;
        var next = observed.head;
        next.pending = null;
        next.pending_record = null;
        // The identity includes the exact head position. Concurrent controls may
        // defeat this CAS, but can never change an already accepted request.
        try self.put(value, observed.storage, observed.position, next, self.operation(value, "release", observed.position.next_lsn), .present);
        return self.start(value);
    }
    if (observed.head.control.state == .retired) {
        if (observed.head.retirement_complete) return null;
        for ([_]c.DirectTableBinding{ value.source, value.output }, 0..) |binding, index| {
            const response = try self.client.call(.{ .dependency_operation = .{ .binding = .{
                .definition = p.Growth.current_definition,
                .connection = self.client.connection,
                .operation = self.operation(value, "retire-dependency", index).operation,
                .edge = .{ .source = binding.interpretation.interpretation, .dependent = .{ .kind = .managed, .interpretation = observed.storage }, .privileges = if (index == 0) c.TableAuthority.select else c.TableAuthority.insert | c.TableAuthority.delete },
                .action = .remove,
                .authority = .dependent,
            }, .command = .accept } });
            defer response.deinit();
            if (response.value.result.dependency_operation != .outcome or response.value.result.dependency_operation.outcome.phase != .applied) return error.ManagedTableCleanupPending;
        }
        var closed = observed.head;
        closed.retirement_complete = true;
        try self.put(value, observed.storage, observed.position, closed, self.operation(value, "retired", observed.position.next_lsn), .present);
        return null;
    }
    if (observed.head.control.state != .active or observed.head.blocked != .none) return null;
    const response = try self.client.call(.{ .lookup = .{ .namespace = value.namespace, .name = value.source.name.slice() } });
    defer response.deinit();
    const metadata = response.value.result.lookup orelse return error.TableNotFound;
    try value.source.check(self.client.connection, metadata);
    if (observed.head.source) |source| {
        if (observed.head.completed_refresh == observed.head.control.refresh and source.unchangedAt(metadata.position, metadata.changed_lsn)) return null;
    }
    var claimed = observed.head;
    claimed.attempt = try std.math.add(u64, claimed.attempt, 1);
    const token = self.workKey(value, claimed.attempt, "transit.managed.table.work.v1");
    claimed.pending = token;
    const declaration_reference = try self.store(account(), declaration_format, value);
    const work: Work = .{
        .definition = p.Growth.current_definition,
        .declaration = declaration_reference,
        .lease = .{ .target = try value.interpretation(self.client.allocator), .control = claimed.control, .owner = self.operation(value, "worker", claimed.attempt), .epoch = claimed.attempt },
        .previous = claimed,
        .transaction = self.workKey(value, claimed.attempt, "transit.managed.table.transaction.v1"),
        .phase = .acquiring,
        .pages = null,
        .page_count = 0,
        .rows = 0,
        .source = null,
        .next_page = null,
        .sequence = 0,
        .statement = null,
    };
    const reference = try self.store(token.account, work_format, work);
    claimed.pending_record = reference;
    try self.put(value, observed.storage, observed.position, claimed, self.operation(value, "claim", claimed.attempt), .any);
    return self.start(value);
}

fn privateClient(self: Self, transaction: c.DirectClientToken.Key) !c.DirectTableClient {
    const tx: Tx = .{ .catalog = self.client };
    var client = self.client;
    client.transaction = .{ .key = transaction, .revision = (try tx.inspect(transaction)).revision };
    return client;
}

/// Execute one recovery unit. Declaration/attempt counts live in paged catalog
/// directories. Hosts serialize a work token and pass a bounded scratch directory.
/// No unfinished result is published, including empty results and failed reads.
pub fn step(self: Self, token: c.DirectClientToken.Key, io: std.Io, directory: std.Io.Dir, cancellation: ?*const std.atomic.Value(bool)) !bool {
    return self.stepInner(token, io, directory, cancellation) catch |err| {
        const reason: flow.Blocked = switch (err) {
            error.ManagedTableResultBudget, error.RelationalOutputBudget, error.RelationalWorkBudget, error.RelationalResidentBudget, error.RelationalSpillBudget, error.TransactionMemoryLimit, error.TransactionStatementLimit, error.TransactionWorkLimit, error.KVBuildBudget => .budget,
            error.CatalogDenied, error.AccessDenied, error.Rejected => .authorization,
            error.TableDefinitionChanged, error.TableNotFound, error.DataflowSourceChanged => .source_changed,
            else => return err,
        };
        const progress = try c.DirectClientToken.inspect(self.client, token) orelse return err;
        const loaded = try self.load(Work, progress.record orelse progress.receipt.binding.intent.external.record, work_format);
        defer loaded.deinit();
        const declared = try self.load(Declaration, loaded.value.declaration, declaration_format);
        defer declared.deinit();
        return self.abort(declared.value, token, progress, loaded.value, reason);
    };
}
fn stepInner(self: Self, token: c.DirectClientToken.Key, io: std.Io, directory: std.Io.Dir, cancellation: ?*const std.atomic.Value(bool)) !bool {
    const progress = try c.DirectClientToken.inspect(self.client, token) orelse return error.ClientOperationMissing;
    const loaded = try self.load(Work, progress.record orelse progress.receipt.binding.intent.external.record, work_format);
    defer loaded.deinit();
    var work = loaded.value;
    if (work.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
    if (work.phase == .complete) return false;
    const declared = try self.load(Declaration, work.declaration, declaration_format);
    defer declared.deinit();
    const value = declared.value;
    try value.validate();
    try work.lease.validate();
    try work.transaction.validate();
    if (!std.meta.eql(work.lease.target, try value.interpretation(self.client.allocator)) or !std.meta.eql(work.transaction.connection, self.client.connection) or work.page_count != work.rows or work.sequence > work.rows + 2) return error.InvalidManagedTableRecord;
    const tx: Tx = .{ .catalog = self.client };
    const observed = try self.inspect(value);
    const current = std.meta.eql(observed.head.control, work.lease.control) and observed.head.pending != null and std.meta.eql(observed.head.pending.?, token) and observed.head.attempt == work.lease.epoch;
    if (!current and work.phase != .deciding) return self.abort(value, token, progress, work, .lease_fenced);
    switch (work.phase) {
        .acquiring => {
            var targets = [_]p.Transaction.Target{
                .{ .object = value.source.interpretation.interpretation.object, .kind = .table, .partition = null },
                .{ .object = value.output.interpretation.interpretation.object, .kind = .table, .partition = null },
                .{ .object = value.object, .kind = .kv, .partition = null },
            };
            std.mem.sort(p.Transaction.Target, &targets, {}, struct {
                fn less(_: void, left: p.Transaction.Target, right: p.Transaction.Target) bool {
                    return left.order(right) == .lt;
                }
            }.less);
            var limits = c.DirectTransaction.default_limits;
            limits.participants = targets.len;
            limits.savepoints = 1;
            limits.statements = try std.math.add(u64, value.options.budgets.output_rows, 2);
            limits.workspace_bytes = @max(limits.workspace_bytes, value.options.budgets.result_bytes);
            _ = try tx.begin(.{ .key = work.transaction, .fingerprint = work.declaration.content.sha256, .operation = self.operation(value, "begin", work.lease.epoch), .namespace = value.namespace, .mode = .serializable, .selection = .{ .explicit_objects = &targets }, .limits = limits, .budget = .{} });
            _ = try tx.acquire(work.transaction);
            work.phase = .evaluating;
        },
        .evaluating => try self.evaluate(value, &work, io, directory, cancellation),
        .staging => {
            if (work.statement) |statement| {
                const result = try tx.execute(work.transaction, statement);
                if (result == .rejected) return self.abort(value, token, progress, work, switch (result.rejected.reason) {
                    .work_limit => .budget,
                    .definition_changed => .source_changed,
                    .data_changed => .none,
                    else => .execution_failed,
                });
                work.statement = null;
                work.sequence += 1;
                if (work.sequence > 1) {
                    const page = try self.load(Page, work.next_page orelse return error.InvalidManagedTableRecord, page_format);
                    defer page.deinit();
                    work.next_page = page.value.previous;
                }
                if (work.sequence > 0 and work.next_page == null) work.phase = .checkpoint;
            } else {
                const client = try self.privateClient(work.transaction);
                const response = try client.call(.{ .lookup = .{ .namespace = value.namespace, .name = value.output.name.slice() } });
                defer response.deinit();
                const metadata = response.value.result.lookup orelse return error.TableNotFound;
                try value.output.check(client.connection, metadata);
                const bytes = try metadata.schema.decode(self.client.allocator, f.TableSchema.max_bytes);
                defer self.client.allocator.free(bytes);
                var schema = try f.TableSchema.decode(self.client.allocator, bytes);
                defer schema.deinit();
                var page: ?std.json.Parsed(Page) = null;
                defer if (page) |parsed| parsed.deinit();
                var row: ?f.TableRow.Owned = null;
                defer if (row) |*owned| owned.deinit();
                var rows: [1][]const f.Types.Values.Cell = undefined;
                var ordinal: u64 = 0;
                const action: f.TableDml.Action = if (work.sequence == 0) .delete else blk: {
                    page = try self.load(Page, work.next_page orelse return error.InvalidManagedTableRecord, page_format);
                    if (page.?.value.definition != p.Growth.current_definition or !std.meta.eql(page.?.value.transaction, work.transaction)) return error.InvalidManagedTableRecord;
                    if (page.?.value.ordinal != work.rows - work.sequence or (page.?.value.previous == null) != (page.?.value.ordinal == 0)) return error.IncompleteDataflowCoverage;
                    const encoded = try page.?.value.row.decode(self.client.allocator, f.TableRow.max_bytes);
                    defer self.client.allocator.free(encoded);
                    row = try f.TableRow.decode(self.client.allocator, schema.schema, encoded);
                    rows[0] = row.?.row().cells;
                    ordinal = page.?.value.ordinal;
                    break :blk .{ .insert = &rows };
                };
                const plan: f.TableDml.Plan = .{ .name = metadata.name.slice(), .schema = schema.schema, .action = action, .predicate = null };
                const identity = if (work.sequence == 0) self.operation(value, "delete", work.lease.epoch) else rowOperation(self, value, work.lease.epoch, ordinal);
                var intent = try c.DirectTableIntent.fromDml(self.client.allocator, client.connection, metadata, identity.operation, plan, .bulk);
                defer intent.deinit();
                work.statement = try tx.stage(work.transaction, client.transaction.?.revision, work.sequence + 1, intent.parsed.value.work);
            }
        },
        .checkpoint => {
            if (work.statement) |statement| {
                const result = try tx.execute(work.transaction, statement);
                if (result == .rejected) return self.abort(value, token, progress, work, switch (result.rejected.reason) {
                    .work_limit => .budget,
                    .definition_changed => .source_changed,
                    .data_changed => .none,
                    else => .execution_failed,
                });
                work.statement = null;
                work.sequence += 1;
                work.phase = .deciding;
            } else {
                const client = try self.privateClient(work.transaction);
                var arena: std.heap.ArenaAllocator = .init(self.client.allocator);
                defer arena.deinit();
                const read = (try KV.apply(&arena, client, .{ .get = .{ .object = value.object, .key = head_key } })).value;
                const head = try p.Json.parseFromSlice(Head, arena.allocator(), read.value.?.value.atom.bytes);
                defer head.deinit();
                var expected = head.value;
                expected.pending_record = null;
                if (!std.meta.eql(expected, work.previous)) return self.abort(value, token, progress, work, .lease_fenced);
                var next = head.value;
                next.revision = try std.math.add(u64, next.revision, 1);
                next.completed = work.transaction;
                next.source = work.source;
                next.rows = work.rows;
                next.completed_refresh = next.control.refresh;
                next.blocked = .none;
                const checkpoint_bytes = try p.Json.valueAllocBounded(arena.allocator(), next, max_definition_bytes);
                var revision_key: [24]u8 = undefined;
                @memcpy(revision_key[0..16], "\x00dataflow/rev/__");
                std.mem.writeInt(u64, revision_key[16..24], next.revision, .big);
                const mutation_ = try KV.prepareMutation(&arena, .{ .definition = p.Growth.current_definition, .identity = self.operation(value, "checkpoint", work.lease.epoch), .target = value.object, .action = .insert, .expected_definition = read.interpretation.interpretation, .expected_data = null, .intent = @splat(0) }, spec, &.{
                    .{ .put = .{ .key = head_key, .value = .{ .value = .{ .atom = .{ .bytes = checkpoint_bytes } } }, .expect = .present } },
                    .{ .put = .{ .key = &revision_key, .value = .{ .value = .{ .atom = .{ .bytes = checkpoint_bytes } } }, .expect = .absent } },
                });
                work.statement = try tx.stageKV(work.transaction, client.transaction.?.revision, work.sequence + 1, mutation_);
            }
        },
        .deciding => {
            const status = try tx.settle(work.transaction, self.operation(value, "commit", work.lease.epoch), .commit, 8);
            if (status.observation != .decided or !status.cleanup_complete) return true;
            if (status.observation.decided.outcome != .committed) return self.abort(value, token, progress, work, .none);
            work.phase = .complete;
        },
        .complete => unreachable,
    }
    try self.progressWork(progress, work);
    return work.phase != .complete;
}

fn rowOperation(self: Self, value: Declaration, attempt: u64, ordinal: u64) d.Operation {
    var bytes: [16]u8 = undefined;
    std.mem.writeInt(u64, bytes[0..8], attempt, .big);
    std.mem.writeInt(u64, bytes[8..16], ordinal, .big);
    return self.operation(value, &bytes, 0);
}

fn evaluate(self: Self, value: Declaration, work: *Work, io: std.Io, directory: std.Io.Dir, cancellation: ?*const std.atomic.Value(bool)) !void {
    const client = try self.privateClient(work.transaction);
    const response = try client.call(.{ .lookup = .{ .namespace = value.namespace, .name = value.source.name.slice() } });
    defer response.deinit();
    const metadata = response.value.result.lookup orelse return error.TableNotFound;
    try value.source.check(client.connection, metadata);
    const view = metadata.workspace orelse return error.InvalidTransactionRead;
    const snapshot: w.Snapshot = .{ .object = value.source.interpretation.interpretation.object, .handle = .{ .owner = view.cut.begin.identity.begin, .content = view.private } };
    var options = value.options;
    options.consistency = .transaction;
    var compiled = try q.DirectRelationalCompilation.fromRetained(self.client.allocator, client, value.namespace, value.sql, &.{value.source}, &.{snapshot}, options, null);
    defer compiled.deinit();
    var spill_name: [80]u8 = undefined;
    const executor = try q.DirectRelationalQuery.openPreparedRetained(self.client.allocator, io, directory, try std.fmt.bufPrint(&spill_name, "managed-{x}-{d}", .{ &work.transaction.token, work.lease.epoch }), client, compiled, &.{snapshot}, options, cancellation);
    defer executor.deinit();
    const output = try client.call(.{ .lookup = .{ .namespace = value.namespace, .name = value.output.name.slice() } });
    defer output.deinit();
    const output_metadata = output.value.result.lookup orelse return error.TableNotFound;
    try value.output.check(client.connection, output_metadata);
    const bytes = try output_metadata.schema.decode(self.client.allocator, f.TableSchema.max_bytes);
    defer self.client.allocator.free(bytes);
    var schema = try f.TableSchema.decode(self.client.allocator, bytes);
    defer schema.deinit();
    // One reusable batch arena; result cardinality only grows immutable pages.
    var scratch: std.heap.ArenaAllocator = .init(self.client.allocator);
    defer scratch.deinit();
    const buffer = try self.client.allocator.alloc(u8, f.TableRow.max_bytes);
    defer self.client.allocator.free(buffer);
    var previous: ?c.DirectRecord.Reference = null;
    var rows: u64 = 0;
    var retained_bytes: u64 = 0;
    while (try executor.next()) |returned| {
        var row = returned;
        defer row.deinit();
        if (rows >= value.options.budgets.output_rows or rows > std.math.maxInt(u32)) return error.ManagedTableResultBudget;
        const encoded = try (f.TableRow.Row{ .identity = .{ .origin = self.client.connection.principal + 1, .operation = work.lease.owner.operation, .ordinal = @intCast(rows) }, .cells = row.cells[0..row.len] }).encode(schema.schema, buffer);
        const page: Page = .{ .definition = p.Growth.current_definition, .transaction = work.transaction, .ordinal = rows, .previous = previous, .row = try w.Binary.encode(scratch.allocator(), encoded) };
        const page_bytes = try p.Json.valueAllocBounded(scratch.allocator(), page, c.DirectRecord.max_bytes);
        retained_bytes = try std.math.add(u64, retained_bytes, page_bytes.len);
        if (retained_bytes > value.options.budgets.result_bytes) return error.ManagedTableResultBudget;
        previous = try c.DirectRecord.stage(self.client, work.transaction.account, page_format, page_bytes);
        rows += 1;
        _ = scratch.reset(.retain_capacity);
    }
    if (!executor.complete) return error.IncompleteDataflowCoverage;
    work.pages = previous;
    work.next_page = previous;
    work.page_count = rows;
    work.rows = rows;
    work.source = metadata.position;
    work.phase = .staging;
}

fn abort(self: Self, value: Declaration, token: c.DirectClientToken.Key, progress: c.DirectClientToken.Progress, original: Work, reason: flow.Blocked) !bool {
    const tx: Tx = .{ .catalog = self.client };
    if (try c.DirectClientToken.lookup(self.client, original.transaction)) |_| {
        const before = try tx.inspect(original.transaction);
        const identity = if (before.attempt) |attempt| attempt.operation else self.operation(value, "abort", original.lease.epoch);
        const status = try tx.settle(original.transaction, identity, .abort, 8);
        if (status.observation != .decided or !status.cleanup_complete) return true;
        // A decision already accepted as committed must remain authoritative.
        if (status.observation.decided.outcome == .committed) {
            var completed = original;
            completed.phase = .complete;
            try self.progressWork(progress, completed);
            return false;
        }
    }
    const observed = try self.inspect(value);
    if (observed.head.pending) |pending| if (std.meta.eql(pending, token)) {
        var next = observed.head;
        next.blocked = reason;
        try self.put(value, observed.storage, observed.position, next, self.operation(value, "abandoned", observed.position.next_lsn), .present);
    };
    var completed = original;
    completed.phase = .complete;
    try self.progressWork(progress, completed);
    return false;
}

test {
    std.testing.refAllDecls(@This());
}
