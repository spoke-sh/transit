//! Explicit named-KV recovery over the shared context and existing saved-work
//! codec. One borrower per adapter; the store serializes independent adapters.
const std = @import("std");
const c = @import("transit_catalog");
const Context = @import("Context.zig");
const Catalog = @import("Catalog.zig");
const Store = @import("LocalRecoveryStore.zig");
const Client = c.DirectKVClient;
const d = c.protocol.DataLifecycle;
const Self = @This();
pub const Attempt = struct { key: Store.Key, revision: u64 };
pub const Config = struct { parse_bytes: usize = 4 * 1024 * 1024 };
pub const Receipt = c.storage.TablePartition.Evidence;
pub const Loaded = struct {
    original: std.json.Parsed(Client.Saved),
    receipt: ?Receipt,
    attempt: Attempt,
    pub fn deinit(self: *Loaded) void {
        self.original.deinit();
        self.* = undefined;
    }
};
pub const Execution = struct {
    outcome: Catalog.KVOutcome,
    attempt: Attempt,
    /// Never replaces a known remote outcome with a local storage error.
    persistence_failure: ?anyerror = null,
};
allocator: std.mem.Allocator,
store: *Store,
buffer: []u8,
scratch: []u8,

pub fn init(allocator: std.mem.Allocator, store: *Store, config: Config) !Self {
    if (config.parse_bytes == 0 or config.parse_bytes > 64 * 1024 * 1024) return error.RecoveryRecordCapacity;
    const buffer = try allocator.alloc(u8, store.buffer.len);
    errdefer allocator.free(buffer);
    const scratch = try allocator.alloc(u8, config.parse_bytes);
    return .{ .allocator = allocator, .store = store, .buffer = buffer, .scratch = scratch };
}
pub fn deinit(self: *Self) void {
    std.crypto.secureZero(u8, self.buffer);
    self.allocator.free(self.buffer);
    std.crypto.secureZero(u8, self.scratch);
    self.allocator.free(self.scratch);
    self.* = undefined;
}

/// Operation identity selects a record; different content or connection under
/// that identity conflicts with its immutable original instead of making a retry.
pub fn key(identity: d.Operation) !Store.Key {
    try identity.validate();
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.kv.mutation.v1\x00");
    hash.update(&c.protocol.Growth.definition_bytes);
    for ([_]u64{ identity.scope.realm, identity.scope.resource, identity.scope.catalog, identity.principal, identity.operation }) |value| {
        var bytes: [8]u8 = undefined;
        std.mem.writeInt(u64, &bytes, value, .little);
        hash.update(&bytes);
    }
    return hash.finalResult();
}
fn encode(self: *Self, value: anytype) ![]const u8 {
    var writer: std.Io.Writer = .fixed(self.buffer);
    var encoder: std.json.Stringify = .{ .writer = &writer };
    c.protocol.Json.write(value, &encoder) catch return error.RecoveryRecordCapacity;
    return writer.buffered();
}
pub fn save(self: *Self, connection: c.DirectTableProtocol.Connection, mutation: c.DirectKV.Mutation) !Attempt {
    const original: Client.Saved = .{ .definition = c.protocol.Growth.current_definition, .connection = connection, .mutation = mutation };
    var scratch: std.heap.FixedBufferAllocator = .init(self.scratch);
    try original.validate(scratch.allocator());
    const identity = try key(mutation.binding.identity);
    const bytes = try self.encode(original);
    if (bytes.len > c.DirectTableProtocol.max_request_bytes) return error.RecoveryRecordCapacity;
    return .{ .key = identity, .revision = try self.store.insert(identity, bytes) };
}

/// Saves and syncs exact prepared work before entering the dispatch path. Input
/// must stay immutable for the entire call. A pre-send failure sends no mutation;
/// a failure after dispatch leaves the original record for explicit observation.
pub fn execute(self: *Self, context: *Context, handle: Context.Handle, output: *std.heap.ArenaAllocator, mutation: c.DirectKV.Mutation, admission: Context.AdmissionOptions) !Execution {
    const attempt = try self.save(try context.catalogConnection(handle), mutation);
    const outcome = try context.callKVWithAdmission(handle, output, .{ .mutate = mutation }, admission);
    return self.finish(attempt, outcome);
}

/// Observes only the saved original. Absence is not rejection and never causes
/// redispatch. Current service authorization is still required, even if a local
/// receipt is present. Endpoints may change; the full signed scope may not.
pub fn observe(self: *Self, context: *Context, handle: Context.Handle, output: *std.heap.ArenaAllocator, identity: Store.Key, admission: Context.AdmissionOptions) !Execution {
    const observation = observed: {
        var scratch: std.heap.FixedBufferAllocator = .init(self.scratch);
        var loaded = try self.load(scratch.allocator(), identity);
        defer loaded.deinit();
        if (!std.meta.eql(loaded.original.value.connection, try context.catalogConnection(handle))) return error.RecoveryKeyConflict;
        const outcome = try context.callKVWithAdmission(handle, output, .{ .operation = loaded.original.value.mutation.binding }, admission);
        break :observed .{ .attempt = loaded.attempt, .outcome = outcome };
    };
    return self.finish(observation.attempt, observation.outcome);
}
fn finish(self: *Self, attempt: Attempt, outcome: Catalog.KVOutcome) Execution {
    var execution: Execution = .{ .outcome = outcome, .attempt = attempt };
    if (outcome.value == .result and outcome.value.result == .operation) if (outcome.value.result.operation) |receipt| {
        execution.attempt = self.saveReceipt(attempt, receipt) catch |err| {
            execution.persistence_failure = err;
            return execution;
        };
    };
    return execution;
}

/// Caller owns the parsed original independently of subsequent adapter calls.
pub fn load(self: *Self, output: std.mem.Allocator, identity: Store.Key) !Loaded {
    const record = try self.store.get(identity, self.buffer) orelse return error.RecoveryRecordMissing;
    const original = try Client.load(output, record.original);
    errdefer original.deinit();
    if (!std.mem.eql(u8, &identity, &try key(original.value.mutation.binding.identity))) return error.RecoveryKeyConflict;
    const receipt = if (record.evidence.len == 0) null else receipt: {
        const parsed = try c.protocol.Json.parseFromSliceOwned(Receipt, output, record.evidence);
        defer parsed.deinit();
        try validateReceipt(original.value.mutation, parsed.value);
        break :receipt parsed.value;
    };
    return .{ .original = original, .receipt = receipt, .attempt = .{ .key = identity, .revision = record.revision } };
}
fn validateReceipt(mutation: c.DirectKV.Mutation, receipt: Receipt) !void {
    if (!std.meta.eql(mutation.binding, receipt.binding)) return error.RecoveryKeyConflict;
    if (receipt.resulting.kind != .kv or receipt.transaction != null or receipt.outcome.matched > mutation.changes.len) return error.InvalidRecoveryReceipt;
    // Reuse storage's accepted-evidence validator for definition, counts,
    // interpretation, retirement and progress; this performs no storage I/O.
    const record: c.storage.TableEvidence.Record = .{
        .position = receipt.outcome.position,
        .evidence = .{ .receipt = .{
            .receipt = .{ .binding = receipt.binding, .changes = mutation.binding.intent, .outcome = receipt.outcome, .transaction = null },
            .resulting = receipt.resulting,
            .ingestion = .point,
        } },
    };
    try record.validate();
}
pub fn saveReceipt(self: *Self, attempt: Attempt, receipt: Receipt) !Attempt {
    var scratch: std.heap.FixedBufferAllocator = .init(self.scratch);
    var loaded = try self.load(scratch.allocator(), attempt.key);
    defer loaded.deinit();
    if (loaded.attempt.revision != attempt.revision) return error.RecoveryRevisionConflict;
    try validateReceipt(loaded.original.value.mutation, receipt);
    if (loaded.receipt) |prior| if (!std.meta.eql(prior, receipt)) return error.RecoveryOutcomeConflict;
    const bytes = try self.encode(receipt);
    return .{ .key = attempt.key, .revision = try self.store.update(attempt.key, attempt.revision, bytes) };
}

test "KV recovery preserves exact originals and validated receipts across store replacement" {
    const t = std.testing;
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var output: std.heap.ArenaAllocator = .init(t.allocator);
    defer output.deinit();
    const scope: d.Scope = .{ .realm = 1, .resource = 2, .catalog = 3 };
    const connection: c.DirectTableProtocol.Connection = .{ .scope = scope, .branch = 1, .audience = 4, .principal = 5, .role = null };
    const object: d.Object = .{ .scope = scope, .branch = 1, .object = 6 };
    const work = try Client.prepareMutation(&output, .{
        .definition = c.protocol.Growth.current_definition,
        .identity = .{ .scope = scope, .principal = 5, .operation = std.math.maxInt(u64) },
        .target = object,
        .action = .insert,
        .expected_definition = .{ .object = object, .revision = 1, .digest = @splat(7) },
        .expected_data = .{ .partition = 6, .next_lsn = 1 },
        .intent = undefined,
    }, .{ .value_type = .binary, .nullable = false }, &.{.{ .put = .{ .key = "key", .value = .{ .value = .{ .atom = .{ .bytes = "payload" } } }, .expect = .absent } }});
    const receipt: Receipt = .{
        .binding = work.binding,
        .resulting = .{ .kind = .kv, .interpretation = work.binding.expected_definition.?, .content = .{ .bytes = 128, .sha256 = @splat(7) }, .schema_fingerprint = @splat(8), .retired = false },
        .outcome = .{ .position = .{ .partition = 6, .next_lsn = 2 }, .matched = 1, .affected = 1, .live_rows = 1 },
        .transaction = null,
    };
    const identity = try key(work.binding.identity);
    {
        var failing: t.FailingAllocator = .init(t.allocator, .{});
        var store = try Store.open(failing.allocator(), t.io, tmp.dir, "kv", .{ .record_bytes = 8192 });
        defer store.deinit();
        var adapter = try Self.init(failing.allocator(), &store, .{});
        defer adapter.deinit();
        failing.fail_index = failing.alloc_index;
        const attempt = try adapter.save(connection, work);
        try t.expectEqualSlices(u8, &identity, &attempt.key);
        var changed = work;
        changed.binding.expected_data = null;
        try t.expectError(error.RecoveryKeyConflict, adapter.save(connection, changed));
        var changes = [_]c.DirectKV.Change{work.changes[0]};
        changes[0].put.expect = .present;
        changed = work;
        changed.changes = &changes;
        changed.binding.intent = try changed.digest(t.allocator);
        try t.expectError(error.RecoveryKeyConflict, adapter.save(connection, changed));
        const original_bytes = try Client.save(output.allocator(), connection, work);
        _ = try store.insert(@splat(0), original_bytes);
        try t.expectError(error.RecoveryKeyConflict, adapter.load(t.allocator, @splat(0)));
        const saved = try adapter.saveReceipt(attempt, receipt);
        try t.expectEqual(2, saved.revision);
        try t.expectError(error.RecoveryRevisionConflict, adapter.saveReceipt(attempt, receipt));
        var conflict = receipt;
        conflict.outcome.live_rows = 2;
        try t.expectError(error.RecoveryOutcomeConflict, adapter.saveReceipt(saved, conflict));
        conflict = receipt;
        conflict.binding.target.object += 1;
        try t.expectError(error.RecoveryKeyConflict, adapter.saveReceipt(saved, conflict));
        conflict = receipt;
        conflict.outcome.affected = 2;
        try t.expectError(error.InvalidTableEvidence, adapter.saveReceipt(saved, conflict));
        try t.expectEqual(saved.revision, (try adapter.save(connection, work)).revision);
        try t.expect(!failing.has_induced_failure);
    }
    {
        const encoded = try Client.save(output.allocator(), connection, work);
        var small = try Store.open(t.allocator, t.io, tmp.dir, "full", .{ .record_bytes = 116 + encoded.len });
        defer small.deinit();
        var adapter = try Self.init(t.allocator, &small, .{});
        defer adapter.deinit();
        const attempt = try adapter.save(connection, work);
        const execution = adapter.finish(attempt, .{
            .value = .{ .result = .{ .operation = receipt } },
            .attempt = .{ .mutation = .{ .action = .kv, .identity = work.binding.identity } },
        });
        try t.expectEqual(error.RecoveryRecordCapacity, execution.persistence_failure.?);
        try t.expectEqualDeep(receipt, execution.outcome.value.result.operation.?);
        try t.expect(execution.outcome.mutationAttempted());
        var pending = try adapter.load(t.allocator, identity);
        defer pending.deinit();
        try t.expect(pending.receipt == null);
        try t.expectEqualDeep(work, pending.original.value.mutation);
    }
    var store = try Store.open(t.allocator, t.io, tmp.dir, "kv", .{ .record_bytes = 8192 });
    defer store.deinit();
    var adapter = try Self.init(t.allocator, &store, .{});
    var live = true;
    defer if (live) adapter.deinit();
    var loaded = try adapter.load(t.allocator, identity);
    defer loaded.deinit();
    var context = try Context.init(t.allocator, t.io, .{ .catalogs = 2, .active = .{ .data = 1, .control = 1 } });
    defer context.deinit() catch unreachable;
    defer context.close(.none) catch unreachable;
    var foreign = connection;
    foreign.principal += 1;
    const handle = try context.openCatalog(.{ .url = "http://127.0.0.1:1", .connection = foreign }, @splat(10));
    try t.expectError(error.RecoveryKeyConflict, adapter.observe(&context, handle, &output, identity, .refuse));
    adapter.deinit();
    live = false;
    try t.expectEqualDeep(work, loaded.original.value.mutation);
    try t.expectEqualDeep(receipt, loaded.receipt.?);
}

test "KV recovery refuses missing definitions and invalid record identity" {
    const t = std.testing;
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var store = try Store.open(t.allocator, t.io, tmp.dir, "invalid", .{ .record_bytes = 8192 });
    defer store.deinit();
    var adapter = try Self.init(t.allocator, &store, .{});
    defer adapter.deinit();
    const identity: Store.Key = @splat(3);
    _ = try store.insert(identity, "{}");
    try t.expectError(error.MissingField, adapter.load(t.allocator, identity));
    try t.expectError(error.RecoveryRecordMissing, adapter.load(t.allocator, @splat(4)));
    try t.expectError(error.InvalidDataOperation, key(.{ .scope = .{ .realm = 1, .resource = 2, .catalog = 3 }, .principal = 1, .operation = 0 }));
}

test "KV recovery constructor unwinds every reserve allocation" {
    const t = std.testing;
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var store = try Store.open(t.allocator, t.io, tmp.dir, "allocations", .{ .record_bytes = 8192 });
    defer store.deinit();
    try t.checkAllAllocationFailures(t.allocator, struct {
        fn run(allocator: std.mem.Allocator, owner: *Store) !void {
            var adapter = try Self.init(allocator, owner, .{ .parse_bytes = 8192 });
            defer adapter.deinit();
        }
    }.run, .{&store});
}
