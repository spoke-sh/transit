//! Explicit recoverable closure of an accepted Queue claim's payload-read
//! dependency. Closing local arenas or acknowledging leases never substitutes
//! for this durable release; uncertain replies preserve the exact original ID.
const std = @import("std");
const c = @import("transit_catalog");
const Context = @import("Context.zig");
const Catalog = @import("Catalog.zig");
const Store = @import("LocalRecoveryStore.zig");
const Client = c.DirectQueueClient;
const d = c.protocol.DataLifecycle;
const q = c.protocol.StreamQueue;
const read = c.protocol.QueueRead;
const Self = @This();

pub const Attempt = struct { key: Store.Key, revision: u64 };
pub const Config = struct { parse_bytes: usize = 512 * 1024 };
pub const Receipt = c.DirectQueue.Receipt;
pub const Loaded = struct {
    original: std.json.Parsed(Client.Saved),
    receipt: ?Receipt,
    attempt: Attempt,

    pub fn release(self: Loaded) read.Release {
        return self.original.value.work.work.release;
    }
    pub fn deinit(self: *Loaded) void {
        self.original.deinit();
        self.* = undefined;
    }
};
pub const Execution = struct {
    outcome: Catalog.QueueOutcome,
    attempt: Attempt,
    /// Never replaces a known remote outcome with a local storage error.
    persistence_failure: ?anyerror = null,
};

allocator: std.mem.Allocator,
store: *Store,
buffer: []u8,
scratch: []u8,

pub fn init(allocator: std.mem.Allocator, store: *Store, config: Config) !Self {
    if (config.parse_bytes == 0 or config.parse_bytes > 16 * 1024 * 1024) return error.RecoveryRecordCapacity;
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

/// Operation identity selects a record; a different claim receipt or signed
/// connection under that identity conflicts instead of creating a new release.
pub fn key(identity: d.Operation) !Store.Key {
    try identity.validate();
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.queue.claim_release.v1\x00");
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

pub fn save(self: *Self, connection: c.DirectTableProtocol.Connection, release: read.Release) !Attempt {
    const original: Client.Saved = .{
        .definition = c.protocol.Growth.current_definition,
        .connection = connection,
        .work = .{ .work = .{ .release = release }, .payload = null },
    };
    var scratch: std.heap.FixedBufferAllocator = .init(self.scratch);
    try original.validate(scratch.allocator());
    const identity = try key(release.operation);
    const bytes = try self.encode(original);
    if (bytes.len > c.DirectTableProtocol.max_request_bytes) return error.RecoveryRecordCapacity;
    return .{ .key = identity, .revision = try self.store.insert(identity, bytes) };
}

/// Saves and syncs the exact claim-read release before entering dispatch. A
/// pre-send failure sends no mutation; an uncertain reply leaves the original
/// record for explicit observation or resume.
pub fn execute(self: *Self, context: *Context, handle: Context.Handle, output: *std.heap.ArenaAllocator, release: read.Release, admission: Context.AdmissionOptions) !Execution {
    const attempt = try self.save(try context.catalogConnection(handle), release);
    const outcome = try context.callQueueWithAdmission(handle, output, .{ .mutate = .{ .work = .{ .release = release } } }, admission);
    return self.finish(attempt, outcome);
}

/// Observes only the saved original under current rights. Absence never causes
/// implicit redispatch; use `resumeSaved` when finishing closure explicitly.
pub fn observe(self: *Self, context: *Context, handle: Context.Handle, output: *std.heap.ArenaAllocator, identity: Store.Key, admission: Context.AdmissionOptions) !Execution {
    const observation = observed: {
        var scratch: std.heap.FixedBufferAllocator = .init(self.scratch);
        var loaded = try self.load(scratch.allocator(), identity);
        defer loaded.deinit();
        if (!std.meta.eql(loaded.original.value.connection, try context.catalogConnection(handle))) return error.RecoveryKeyConflict;
        const outcome = try context.callQueueWithAdmission(handle, output, .{ .operation = .{ .release = loaded.release() } }, admission);
        break :observed .{ .attempt = loaded.attempt, .outcome = outcome };
    };
    return self.finish(observation.attempt, observation.outcome);
}

/// Observes the saved release first and re-submits the exact original mutation
/// only if the service reports `operation == null`. Never invents a fresh ID.
pub fn resumeSaved(self: *Self, context: *Context, handle: Context.Handle, output: *std.heap.ArenaAllocator, identity: Store.Key, admission: Context.AdmissionOptions) !Execution {
    const observed = try self.observe(context, handle, output, identity, admission);
    if (observed.outcome.value != .result or observed.outcome.value.result != .operation or observed.outcome.value.result.operation != null)
        return observed;
    const saved = loaded_release: {
        var scratch: std.heap.FixedBufferAllocator = .init(self.scratch);
        var loaded = try self.load(scratch.allocator(), identity);
        defer loaded.deinit();
        if (!std.meta.eql(loaded.original.value.connection, try context.catalogConnection(handle))) return error.RecoveryKeyConflict;
        break :loaded_release .{ .attempt = loaded.attempt, .release = loaded.release() };
    };
    const outcome = try context.callQueueWithAdmission(handle, output, .{ .mutate = .{ .work = .{ .release = saved.release } } }, admission);
    return self.finish(saved.attempt, outcome);
}

fn finish(self: *Self, attempt: Attempt, outcome: Catalog.QueueOutcome) Execution {
    var execution: Execution = .{ .outcome = outcome, .attempt = attempt };
    if (outcome.value == .result and outcome.value.result == .operation) if (outcome.value.result.operation) |receipt| {
        execution.attempt = self.saveReceipt(attempt, receipt) catch |err| {
            execution.persistence_failure = err;
            return execution;
        };
    };
    return execution;
}

pub fn load(self: *Self, output: std.mem.Allocator, identity: Store.Key) !Loaded {
    const record = try self.store.get(identity, self.buffer) orelse return error.RecoveryRecordMissing;
    const original = try Client.load(output, record.original);
    errdefer original.deinit();
    if (original.value.work.work != .release or original.value.work.payload != null) return error.InvalidQueueIntent;
    const release = original.value.work.work.release;
    if (!std.mem.eql(u8, &identity, &try key(release.operation))) return error.RecoveryKeyConflict;
    const receipt = if (record.evidence.len == 0) null else receipt: {
        const parsed = try c.protocol.Json.parseFromSliceOwned(Receipt, output, record.evidence);
        defer parsed.deinit();
        try validateReceipt(release, parsed.value);
        break :receipt parsed.value;
    };
    return .{ .original = original, .receipt = receipt, .attempt = .{ .key = identity, .revision = record.revision } };
}

fn validateReceipt(release: read.Release, receipt: Receipt) !void {
    switch (receipt) {
        .release, .closed => {},
        else => return error.InvalidRecoveryReceipt,
    }
    try c.DirectQueueResponse.requireReceipt(.{ .release = release }, receipt);
}

pub fn saveReceipt(self: *Self, attempt: Attempt, receipt: Receipt) !Attempt {
    var scratch: std.heap.FixedBufferAllocator = .init(self.scratch);
    var loaded = try self.load(scratch.allocator(), attempt.key);
    defer loaded.deinit();
    if (loaded.attempt.revision != attempt.revision) return error.RecoveryRevisionConflict;
    try validateReceipt(loaded.release(), receipt);
    if (loaded.receipt) |prior| if (!std.meta.eql(prior, receipt)) return error.RecoveryOutcomeConflict;
    const bytes = try self.encode(receipt);
    return .{ .key = attempt.key, .revision = try self.store.update(attempt.key, attempt.revision, bytes) };
}

test "Queue claim release recovery preserves exact originals and validated receipts across store replacement" {
    const t = std.testing;
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var output: std.heap.ArenaAllocator = .init(t.allocator);
    defer output.deinit();
    const scope: d.Scope = .{ .realm = 1, .resource = 2, .catalog = 3 };
    const connection: c.DirectTableProtocol.Connection = .{ .scope = scope, .branch = 1, .audience = 4, .principal = 5, .role = null };
    const object: d.Object = .{ .scope = scope, .branch = 1, .object = 8 };
    const target: q.Partition = .{
        .definition = c.protocol.Growth.current_definition,
        .interpretation = .{ .object = object, .revision = 1, .digest = @splat(9) },
        .partition = 0,
    };
    const claim: q.ClaimReceipt = .{
        .claim = .{
            .target = target,
            .operation = .{ .scope = scope, .principal = 5, .operation = 10 },
            .maximum = 1,
            .lease_ms = 5000,
            .predicate = null,
        },
        .accepted = .{ .partition = 8, .next_lsn = 3 },
        .observed_ms = 1000,
        .expires_ms = 6000,
        .rows = 1,
        .leases = .{ .bytes = 64, .sha256 = @splat(11) },
    };
    const release: read.Release = .{
        .operation = .{ .scope = scope, .principal = 5, .operation = 11 },
        .claim = claim,
    };
    const receipt: Receipt = .{ .release = .{
        .release = release,
        .accepted = .{ .partition = 8, .next_lsn = 5 },
    } };
    const identity = try key(release.operation);
    {
        var failing: t.FailingAllocator = .init(t.allocator, .{});
        var store = try Store.open(failing.allocator(), t.io, tmp.dir, "queue-release", .{ .record_bytes = 8192 });
        defer store.deinit();
        var adapter = try Self.init(failing.allocator(), &store, .{});
        defer adapter.deinit();
        failing.fail_index = failing.alloc_index;
        const attempt = try adapter.save(connection, release);
        try t.expectEqualSlices(u8, &identity, &attempt.key);
        var changed = release;
        changed.claim.observed_ms += 1;
        changed.claim.expires_ms += 1;
        try t.expectError(error.RecoveryKeyConflict, adapter.save(connection, changed));
        const original_bytes = try Client.save(output.allocator(), connection, .{ .work = .{ .release = release } });
        _ = try store.insert(@splat(0), original_bytes);
        try t.expectError(error.RecoveryKeyConflict, adapter.load(t.allocator, @splat(0)));
        const saved = try adapter.saveReceipt(attempt, receipt);
        try t.expectEqual(2, saved.revision);
        try t.expectError(error.RecoveryRevisionConflict, adapter.saveReceipt(attempt, receipt));
        var conflict = receipt;
        conflict.release.accepted.next_lsn = 6;
        try t.expectError(error.RecoveryOutcomeConflict, adapter.saveReceipt(saved, conflict));
        conflict = receipt;
        conflict.release.release.claim.observed_ms += 1;
        conflict.release.release.claim.expires_ms += 1;
        try t.expectError(error.QueueReadReleaseConflict, adapter.saveReceipt(saved, conflict));
        try t.expectEqual(saved.revision, (try adapter.save(connection, release)).revision);
        try t.expect(!failing.has_induced_failure);
    }
    {
        const encoded = try Client.save(output.allocator(), connection, .{ .work = .{ .release = release } });
        var small = try Store.open(t.allocator, t.io, tmp.dir, "full", .{ .record_bytes = 116 + encoded.len });
        defer small.deinit();
        var adapter = try Self.init(t.allocator, &small, .{});
        defer adapter.deinit();
        const attempt = try adapter.save(connection, release);
        const execution = adapter.finish(attempt, .{
            .value = .{ .result = .{ .operation = receipt } },
            .attempt = .{ .mutation = .{ .action = .queue, .identity = release.operation } },
        });
        try t.expectEqual(error.RecoveryRecordCapacity, execution.persistence_failure.?);
        try t.expectEqualDeep(receipt, execution.outcome.value.result.operation.?);
        try t.expect(execution.outcome.mutationAttempted());
        var pending = try adapter.load(t.allocator, identity);
        defer pending.deinit();
        try t.expect(pending.receipt == null);
        try t.expectEqualDeep(release, pending.release());
    }
    var store = try Store.open(t.allocator, t.io, tmp.dir, "queue-release", .{ .record_bytes = 8192 });
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
    try t.expectEqualDeep(release, loaded.release());
    try t.expectEqualDeep(receipt, loaded.receipt.?);
}

test "Queue claim release recovery refuses missing definitions and non-release mutations" {
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

test "Queue claim release constructor unwinds every reserve allocation" {
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
