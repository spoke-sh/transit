const std = @import("std");
const t = std.testing;
const core = @import("transit_core");
const storage = @import("transit_storage");
const backend = @import("root.zig");
const p = core.protocol;
const g = p.Growth;
const a = p.Authorization;
const Engine = backend.DataAuthority.Engine;

fn rootKey() !p.Ed25519.KeyPair {
    return p.Ed25519.KeyPair.generateDeterministic(@splat(17));
}
fn userKey() !p.Ed25519.KeyPair {
    return p.Ed25519.KeyPair.generateDeterministic(@splat(29));
}
fn genesis() !core.growing.Genesis {
    return .{ .realm = 42, .root_key = (try rootKey()).public_key.toBytes(), .max_clock_error_ms = 5 };
}
fn clock(_: *anyopaque) !core.Time.Sample {
    return .{ .unix_ms = 100 };
}
fn submit(engine: *Engine, command: g.Command) !u64 {
    return engine.submit(try g.sign(.{ .realm = 42, .principal = 0, .sequence = (try engine.principal(0)).sequence + 1, .command = command }, try rootKey()));
}
fn provision(engine: *Engine) !struct { pid: u64, resource: u64, guard: a.Guard } {
    const pid = try submit(engine, .{ .spawn = .{} });
    const resource = try submit(engine, .{ .create_resource = .{ .writer = pid, .owned = false } });
    _ = try submit(engine, .{ .grant = .{ .subject = 1, .public_key = (try userKey()).public_key.toBytes(), .permissions = p.permission(.inspect) } });
    _ = try submit(engine, .{ .grant_resource = .{ .resource = resource, .subject = 1, .permissions = p.State.all_permissions } });
    var guard: a.Guard = .{ .subject = .{ .signed = try a.Proof.sign(.{
        .definition = g.current_definition,
        .realm = 42,
        .principal = 1,
        .credential_epoch = (try engine.principal(1)).credential_epoch,
        .role = null,
        .audience = 100,
        .context = @splat(5),
    }, try userKey()) }, .requirements = @splat(null) };
    guard.requirements[0] = .{ .object = .{ .kind = .resource, .id = resource }, .privileges = p.State.permission(.write) };
    return .{ .pid = pid, .resource = resource, .guard = guard };
}

test "direct data inventory records newer content reuse before publication and recounts quota on reopen" {
    const Allocations = @import("DataAllocations.zig");
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    const key = "segments/reused.data";
    const bytes = "shared immutable bytes";
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    const first = try Allocations.Allocation.init(1, key, .{ .size = bytes.len, .sha256 = digest });
    var reserved: u64 = 0;
    {
        var owner = try backend.Backend.open(t.allocator, t.io, tmp.dir, "native", .{});
        defer owner.deinit();
        var pages = try backend.PageStore.init(&owner, 1);
        defer pages.deinit();
        var journal: backend.Store = .{ .backend = &owner };
        var engine = try Engine.bootstrap(&journal, &pages, try genesis());
        try owner.put(key, bytes, false);
        try t.expectEqualDeep(first, (try owner.data_allocations.latest(first.name())).?);
        const allocated = owner.allocated;
        const original_queue = try owner.data_allocations.current();
        try owner.put(key, bytes, false);
        try t.expectEqual(allocated, owner.allocated);
        try t.expectEqualDeep(original_queue, try owner.data_allocations.current());
        try t.expectError(error.ImmutableObjectConflict, owner.put(key, "conflicting bytes", false));
        try t.expectEqual(allocated, owner.allocated);
        var clock_context: u8 = 0;
        engine.clock = .{ .context = &clock_context, .read = clock };
        _ = try submit(&engine, .{ .storage_fence = {} });
        owner.limits.bytes = owner.allocated;
        // Deduplication still needs durable inventory capacity in the new epoch.
        try t.expectError(error.StorageQuota, owner.put(key, bytes, false));
        try t.expectEqualDeep(first, (try owner.data_allocations.latest(first.name())).?);
        try owner.put(key, bytes, true);
        const latest = (try owner.data_allocations.latest(first.name())).?;
        try t.expectEqual(engine.head.storage_epoch, latest.epoch);
        try t.expectEqualDeep(first.meta, latest.meta);
        try t.expectEqual(original_queue.tail + 1, (try owner.data_allocations.current()).tail);
        try t.expectError(error.AllocationConflict, owner.data_allocations.remove(first));
        reserved = owner.allocated;
    }
    var owner = try backend.Backend.open(t.allocator, t.io, tmp.dir, "native", .{});
    defer owner.deinit();
    try t.expect(owner.allocated < reserved);
    var actual: u64 = 0;
    var walker = try owner.directory.walk(t.allocator);
    defer walker.deinit();
    while (try walker.next(t.io)) |entry| {
        if (entry.kind != .file) continue;
        const file = try entry.dir.openFile(t.io, entry.basename, .{});
        defer file.close(t.io);
        actual += try file.length(t.io);
    }
    try t.expectEqual(actual, owner.allocated);
    try t.expectEqual(@as(u64, 2), (try owner.data_allocations.latest(first.name())).?.epoch);
    var output: [64]u8 = undefined;
    try t.expectEqualStrings(bytes, try owner.read(key, &output));
}

test "direct data creation sync failures never publish an object without durable inventory" {
    const Allocations = @import("DataAllocations.zig");
    const Fault = struct {
        var real: *const std.Io.VTable = undefined;
        var calls: usize = 0;
        var remaining: usize = 0;
        fn sync(context: ?*anyopaque, file: std.Io.File) std.Io.File.SyncError!void {
            calls += 1;
            if (remaining != 0) {
                remaining -= 1;
                if (remaining == 0) return error.InputOutput;
            }
            return real.fileSync(context, file);
        }
    };
    Fault.real = t.io.vtable;
    var vtable = t.io.vtable.*;
    vtable.fileSync = Fault.sync;
    var io = t.io;
    io.vtable = &vtable;
    const key = "segments/uncertain.data";
    const bytes = "private staged bytes";
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    const wanted = try Allocations.Allocation.init(1, key, .{ .size = bytes.len, .sha256 = digest });
    var schedules: usize = 0;
    var failure: usize = 0;
    while (failure <= schedules) : (failure += 1) {
        var tmp = t.tmpDir(.{});
        defer tmp.cleanup();
        {
            var owner = try backend.Backend.open(t.allocator, io, tmp.dir, "native", .{});
            defer owner.deinit();
            Fault.calls = 0;
            Fault.remaining = failure;
            if (failure == 0) {
                try owner.put(key, bytes, false);
                schedules = Fault.calls;
                try t.expect(schedules > 0 and schedules < 32);
            } else {
                try t.expectError(error.InputOutput, owner.put(key, bytes, false));
                try t.expectEqual(@as(usize, 0), Fault.remaining);
            }
        }
        var owner = try backend.Backend.open(t.allocator, t.io, tmp.dir, "native", .{});
        defer owner.deinit();
        if (try owner.objects.objectStore().head(key) != null) {
            try t.expectEqualDeep(wanted, (try owner.data_allocations.latest(wanted.name())).?);
            const head = try owner.data_allocations.current();
            try t.expect(head.tail > 0);
            try t.expectEqualDeep(wanted, (try owner.data_allocations.at(head.tail - 1)).item.?);
        }
        try owner.put(key, bytes, false);
        try t.expectEqualDeep(wanted, (try owner.data_allocations.latest(wanted.name())).?);
        var output: [64]u8 = undefined;
        try t.expectEqualStrings(bytes, try owner.read(key, &output));
    }
}

test "direct data owner refuses a missing mandatory inventory directory" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var owner = try backend.Backend.open(t.allocator, t.io, tmp.dir, "native", .{});
    owner.deinit();
    try tmp.dir.deleteTree(t.io, "native/data-allocations");
    try t.expectError(error.FileNotFound, backend.Backend.open(t.allocator, t.io, tmp.dir, "native", .{}));
    try t.expectError(error.FileNotFound, tmp.dir.openDir(t.io, "native/data-allocations", .{}));
}

test "direct data acceptance fences native policy and storage epochs without a native progress CAS" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var owner = try backend.Backend.open(t.allocator, t.io, tmp.dir, "native", .{});
    defer owner.deinit();
    var pages = try backend.PageStore.init(&owner, 1);
    defer pages.deinit();
    var journal: backend.Store = .{ .backend = &owner };
    var engine = try Engine.bootstrap(&journal, &pages, try genesis());
    const setup = try provision(&engine);
    var authority: backend.DataAuthority = .{ .engine = &engine, .request = setup.guard, .audience = 100, .resource = setup.resource };
    const guard = authority.guard();
    const original = try guard.acquire(guard.context);
    try t.expect(!owner.authority.tryLock(t.io));
    guard.release(guard.context);
    var data: backend.DataStore = .{ .backend = &owner };
    const allocated = owner.allocated;
    try t.expectError(error.ObjectDigestMismatch, data.objects().putImmutable("data/wrong-digest.data", "data", @splat(0)));
    try t.expectEqual(allocated, owner.allocated);
    try t.expect(try data.objects().head("data/wrong-digest.data") == null);
    const before_native = engine.head.position;
    _ = try submit(&engine, .{ .send = .{ .pid = setup.pid, .value = try p.Value.init("unrelated input") } });
    try t.expect(engine.head.position > before_native);
    try t.expectEqual(original.policy_epoch, engine.head.authorization.revision + 1);
    _ = try data.log().append(17, 0, original.writer_epoch, original.policy_epoch, .row_delta, "accepted data");
    _ = try data.log().append(18, 0, original.writer_epoch, original.policy_epoch, .row_delta, "independent partition");
    _ = try submit(&engine, .{ .grant_resource = .{ .resource = setup.resource, .subject = 1, .permissions = 0 } });
    try t.expectError(error.AuthorizationChanged, data.log().append(17, 1, original.writer_epoch, original.policy_epoch, .row_delta, "stale policy"));
    try t.expectError(error.Forbidden, guard.acquire(guard.context));
    try t.expectEqual(@as(u64, 1), try data.log().tail(17));
    _ = try submit(&engine, .{ .grant_resource = .{ .resource = setup.resource, .subject = 1, .permissions = p.State.all_permissions } });
    const refreshed = try guard.acquire(guard.context);
    guard.release(guard.context);
    var clock_context: u8 = 0;
    engine.clock = .{ .context = &clock_context, .read = clock };
    _ = try submit(&engine, .{ .storage_fence = {} });
    try t.expectError(error.StaleStorageEpoch, data.log().append(17, 1, refreshed.writer_epoch, refreshed.policy_epoch, .row_delta, "stale storage"));
    const reacquired = try guard.acquire(guard.context);
    guard.release(guard.context);
    try t.expectEqual(original.writer_epoch, reacquired.writer_epoch);
    try t.expectEqual(engine.head.authorization.revision + 1, reacquired.policy_epoch);
    try t.expectError(error.StaleStorageEpoch, data.log().append(17, 1, reacquired.writer_epoch, reacquired.policy_epoch, .row_delta, "renewed old candidate"));
    try t.expectError(error.NativePartitionReserved, data.log().tail(0));
    try t.expectError(error.NoCheckpointIntent, data.log().trim(17, 1));
    try t.expect(data.observe.metrics.failures >= 3);
}

test "direct data candidates share physical quota and reserve control space without expiry" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var owner = try backend.Backend.open(t.allocator, t.io, tmp.dir, "native", .{});
    defer owner.deinit();
    var pages = try backend.PageStore.init(&owner, 1);
    defer pages.deinit();
    var journal: backend.Store = .{ .backend = &owner };
    var engine = try Engine.bootstrap(&journal, &pages, try genesis());
    const setup = try provision(&engine);
    var authority: backend.DataAuthority = .{ .engine = &engine, .request = setup.guard, .audience = 100, .resource = setup.resource };
    const guard = authority.guard();
    const fence = try guard.acquire(guard.context);
    defer guard.release(guard.context);
    var data: backend.DataStore = .{ .backend = &owner };
    owner.limits.bytes = owner.allocated;
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash("data", &digest, .{});
    try t.expectError(error.StorageQuota, data.objects().putImmutable("data/test.data", "data", digest));
    try t.expectError(error.StorageQuota, data.log().append(17, 0, fence.writer_epoch, fence.policy_epoch, .row_delta, "not accepted"));
    try t.expectEqual(@as(u64, 0), try data.log().tail(17));
    data.control = true;
    _ = try data.log().append(17, 0, fence.writer_epoch, fence.policy_epoch, .manifest_checkpoint, "explicit owner control");
    try t.expectEqual(@as(u64, 1), try data.log().tail(17));
}

test "direct Table archive uses control reserve and trims only accepted coverage under current authority" {
    const f = @import("transit_fuze");
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var owner = try backend.Backend.open(t.allocator, t.io, tmp.dir, "native", .{});
    defer owner.deinit();
    var pages = try backend.PageStore.init(&owner, 1);
    defer pages.deinit();
    var journal: backend.Store = .{ .backend = &owner };
    var engine = try Engine.bootstrap(&journal, &pages, try genesis());
    const setup = try provision(&engine);
    var authority: backend.DataAuthority = .{ .engine = &engine, .request = setup.guard, .audience = 100, .resource = setup.resource };
    var data: backend.DataStore = .{ .backend = &owner };
    var control: backend.DataStore = .{ .backend = &owner, .control = true };
    const object: p.DataLifecycle.Object = .{ .scope = .{ .realm = 42, .resource = setup.resource, .catalog = 3 }, .branch = 1, .object = 7 };
    const columns = [_]f.TableSchema.Column{.{ .id = 1, .name = "id", .type = .int64, .nullable = false }};
    const schema: f.TableSchema.Schema = .{ .object = 7, .revision = 1, .next_column = 2, .columns = &columns, .primary_key = &.{1} };
    var table = try storage.TablePartition.init(t.allocator, 17, .{ .object = object, .revision = 1, .schema = schema, .properties = "" }, data.log(), data.objects(), .{ .resident_pages = 1, .control = .{ .log = control.log(), .objects = control.objects() } });
    defer table.deinit();
    try table.recover();
    const exact: p.DataLifecycle.Binding = .{ .definition = g.current_definition, .identity = .{ .scope = object.scope, .principal = 1, .operation = 1 }, .target = object, .action = .create, .expected_definition = null, .expected_data = null, .intent = @splat(5) };
    const accepted = try table.apply(exact, &.{}, .point, authority.guard());
    var insertion = exact;
    insertion.identity.operation = 2;
    insertion.action = .insert;
    insertion.expected_definition = table.root.interpretation;
    _ = try table.apply(insertion, &.{.{ .put = .{ .row = .{ .identity = .{ .origin = 7, .operation = 2, .ordinal = 0 }, .cells = &.{.{ .value = .{ .atom = .{ .signed = 42 } } }} } } }}, .bulk, authority.guard());
    // An ordinary physical caller cannot substitute the WAL tail for coverage.
    try t.expectError(error.NoCheckpointIntent, data.log().trim(17, 1));
    owner.limits.bytes = owner.allocated;
    try t.expectEqual(@as(usize, 1), (try table.compact(table.root.next_segment, .{}, authority.guard())).rows);
    try t.expect((try table.archive(accepted.position, .{}, authority.guard())).complete);
    _ = try table.checkpoint(.{ .partition = 17, .next_lsn = table.root.next_lsn }, authority.guard());
    try t.expectEqualDeep(accepted.position, try table.expireHistory(accepted.position, authority.guard()));
    owner.limits = .{};
    try t.expectError(error.NoCheckpointIntent, data.log().trim(17, table.root.next_lsn));
    _ = try submit(&engine, .{ .grant_resource = .{ .resource = setup.resource, .subject = 1, .permissions = 0 } });
    try t.expectError(error.Forbidden, table.trimArchived(authority.guard()));
    var untrimmed = try data.log().read(t.allocator, 17, 0, 1);
    untrimmed.deinit();
    _ = try submit(&engine, .{ .grant_resource = .{ .resource = setup.resource, .subject = 1, .permissions = p.State.all_permissions } });
    try t.expectEqual(@as(u64, 1), try table.trimArchived(authority.guard()));
    try t.expectError(error.WalHistoryTrimmed, data.log().read(t.allocator, 17, 0, 1));
    try table.recover();
    try t.expectEqualDeep(accepted, (try table.observe(exact, authority.guard())).?);
}

test "native policy revocation after Table staging denies the whole batch and exact observation" {
    try revocationAfterStaging(false);
    try revocationAfterStaging(true);
}

test "native storage fence after Table staging requires a fresh candidate without losing receipts" {
    try storageFenceAfterStaging(.point);
    try storageFenceAfterStaging(.bulk);
}

fn storageFenceAfterStaging(ingestion: storage.TablePartition.Ingestion) !void {
    const f = @import("transit_fuze");
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var owner = try backend.Backend.open(t.allocator, t.io, tmp.dir, "native", .{});
    defer owner.deinit();
    var pages = try backend.PageStore.init(&owner, 1);
    defer pages.deinit();
    var journal: backend.Store = .{ .backend = &owner };
    var engine = try Engine.bootstrap(&journal, &pages, try genesis());
    const setup = try provision(&engine);
    var clock_context: u8 = 0;
    engine.clock = .{ .context = &clock_context, .read = clock };
    var authority: backend.DataAuthority = .{ .engine = &engine, .request = setup.guard, .audience = 100, .resource = setup.resource };
    var data: backend.DataStore = .{ .backend = &owner };
    const object: p.DataLifecycle.Object = .{ .scope = .{ .realm = 42, .resource = setup.resource, .catalog = 3 }, .branch = 1, .object = 7 };
    const columns = [_]f.TableSchema.Column{.{ .id = 1, .name = "id", .type = .int64, .nullable = false }};
    const schema: f.TableSchema.Schema = .{ .object = 7, .revision = 1, .next_column = 2, .columns = &columns, .primary_key = &.{1} };
    var table = try storage.TablePartition.init(t.allocator, 17, .{ .object = object, .revision = 1, .schema = schema, .properties = "" }, data.log(), data.objects(), .{ .resident_pages = 1 });
    defer table.deinit();
    try table.recover();
    const creation: p.DataLifecycle.Binding = .{ .definition = g.current_definition, .identity = .{ .scope = object.scope, .principal = 1, .operation = 1 }, .target = object, .action = .create, .expected_definition = null, .expected_data = null, .intent = @splat(5) };
    const created = try table.apply(creation, &.{}, .point, authority.guard());
    var binding = creation;
    binding.identity.operation = 2;
    binding.action = .insert;
    binding.expected_definition = table.root.interpretation;
    const changes = [_]storage.TablePartition.Change{.{ .put = .{ .row = .{
        .identity = .{ .origin = 7, .operation = 2, .ordinal = 0 },
        .cells = &.{.{ .value = .{ .atom = .{ .signed = 42 } } }},
    } } }};
    const Race = struct {
        authority: *backend.DataAuthority,
        engine: *Engine,
        calls: usize = 0,
        fn acquire(context: *anyopaque) !storage.TablePartition.Guard.Fence {
            const self: *@This() = @ptrCast(@alignCast(context));
            self.calls += 1;
            if (self.calls == 2) _ = try submit(self.engine, .{ .storage_fence = {} });
            const guard = self.authority.guard();
            return guard.acquire(guard.context);
        }
        fn release(context: *anyopaque) void {
            const self: *@This() = @ptrCast(@alignCast(context));
            const guard = self.authority.guard();
            guard.release(guard.context);
        }
    };
    var race: Race = .{ .authority = &authority, .engine = &engine };
    const allocated = owner.allocated;
    const before = table.root;
    try t.expectError(error.StaleStorageEpoch, table.apply(binding, &changes, ingestion, .{ .context = &race, .acquire = Race.acquire, .release = Race.release }));
    try t.expectEqual(@as(usize, 2), race.calls);
    try t.expect(owner.allocated > allocated);
    try t.expectEqual(before.next_lsn, try data.log().tail(17));
    try t.expectEqualDeep(before, table.root);
    try table.recover();
    // Read authorization remains current; a stale candidate is not a revoked
    // reader. Both acceptance observations remain exact across the fence.
    try t.expectEqualDeep(created, (try table.observe(creation, authority.guard())).?);
    try t.expect(try table.observe(binding, authority.guard()) == null);
    try t.expectError(error.StaleStorageEpoch, table.apply(binding, &changes, ingestion, authority.guard()));
    try table.recover();
    var fresh: backend.DataAuthority = .{ .engine = &engine, .request = setup.guard, .audience = 100, .resource = setup.resource };
    const accepted = try table.apply(binding, &changes, ingestion, fresh.guard());
    try t.expectEqual(@as(u64, 1), accepted.affected);
    try table.recover();
    try t.expectEqualDeep(accepted, (try table.observe(binding, authority.guard())).?);
    try t.expectEqualDeep(accepted, try table.apply(binding, &changes, ingestion, fresh.guard()));
    try t.expectEqual(@as(u64, 1), table.root.live_rows);
    try t.expectEqual(created.position.next_lsn + 1, table.root.next_lsn);
}

fn revocationAfterStaging(prerequisite: bool) !void {
    const f = @import("transit_fuze");
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var owner = try backend.Backend.open(t.allocator, t.io, tmp.dir, "native", .{});
    defer owner.deinit();
    var pages = try backend.PageStore.init(&owner, 1);
    defer pages.deinit();
    var journal: backend.Store = .{ .backend = &owner };
    var engine = try Engine.bootstrap(&journal, &pages, try genesis());
    const setup = try provision(&engine);
    var authority: backend.DataAuthority = .{ .engine = &engine, .request = setup.guard, .audience = 100, .resource = setup.resource };
    const revoking: u64 = if (prerequisite) 2 else 1;
    if (prerequisite) {
        const original_key = try p.Ed25519.KeyPair.generateDeterministic(@splat(41));
        _ = try submit(&engine, .{ .grant = .{ .subject = 2, .public_key = original_key.public_key.toBytes(), .permissions = p.permission(.inspect) } });
        _ = try submit(&engine, .{ .grant_resource = .{ .resource = setup.resource, .subject = 2, .permissions = p.State.all_permissions } });
        var condition = setup.guard;
        condition.subject = .{ .signed = try a.Proof.sign(.{ .definition = g.current_definition, .realm = 42, .principal = 2, .credential_epoch = (try engine.principal(2)).credential_epoch, .role = null, .audience = 200, .context = @splat(7) }, original_key) };
        authority.prerequisite = condition;
    }
    var data: backend.DataStore = .{ .backend = &owner };
    const object: p.DataLifecycle.Object = .{ .scope = .{ .realm = 42, .resource = setup.resource, .catalog = 3 }, .branch = 1, .object = 7 };
    const columns = [_]f.TableSchema.Column{.{ .id = 1, .name = "id", .type = .int64, .nullable = false }};
    const schema: f.TableSchema.Schema = .{ .object = 7, .revision = 1, .next_column = 2, .columns = &columns, .primary_key = &.{1} };
    var table = try storage.TablePartition.init(t.allocator, 17, .{ .object = object, .revision = 1, .schema = schema, .properties = "" }, data.log(), data.objects(), .{ .resident_pages = 1 });
    defer table.deinit();
    try table.recover();
    const binding: p.DataLifecycle.Binding = .{ .definition = g.current_definition, .identity = .{ .scope = object.scope, .principal = 1, .operation = 1 }, .target = object, .action = .create, .expected_definition = null, .expected_data = null, .intent = @splat(5), .prerequisite = authority.prerequisite };
    const changes = [_]storage.TablePartition.Change{.{ .put = .{ .row = .{
        .identity = .{ .origin = 7, .operation = 1, .ordinal = 0 },
        .cells = &.{.{ .value = .{ .atom = .{ .signed = 42 } } }},
    } } }};
    const Race = struct {
        authority: *backend.DataAuthority,
        engine: *Engine,
        resource: u64,
        principal: u64,
        calls: usize = 0,
        fn acquire(context: *anyopaque) !storage.TablePartition.Guard.Fence {
            const self: *@This() = @ptrCast(@alignCast(context));
            self.calls += 1;
            if (self.calls == 2) _ = try submit(self.engine, .{ .grant_resource = .{ .resource = self.resource, .subject = self.principal, .permissions = 0 } });
            const guard = self.authority.guard();
            return guard.acquire(guard.context);
        }
        fn release(context: *anyopaque) void {
            const self: *@This() = @ptrCast(@alignCast(context));
            const guard = self.authority.guard();
            guard.release(guard.context);
        }
    };
    var race: Race = .{ .authority = &authority, .engine = &engine, .resource = setup.resource, .principal = revoking };
    const before = owner.allocated;
    try t.expectError(error.Forbidden, table.apply(binding, &changes, .bulk, .{ .context = &race, .acquire = Race.acquire, .release = Race.release }));
    try t.expect(owner.allocated > before);
    try t.expectEqual(@as(u64, 0), try data.log().tail(17));
    try t.expectEqual(@as(u64, 0), table.root.live_rows);
    try t.expectError(error.Forbidden, table.observe(binding, authority.guard()));
    _ = try submit(&engine, .{ .grant_resource = .{ .resource = setup.resource, .subject = revoking, .permissions = p.State.all_permissions } });
    try t.expectEqual(@as(u64, 1), (try table.apply(binding, &changes, .bulk, authority.guard())).affected);
    try table.recover();
    try t.expectEqual(@as(u64, 1), (try table.observe(binding, authority.guard())).?.affected);
    _ = try submit(&engine, .{ .retire_resource = setup.resource });
    try t.expectError(error.StateResourceExpired, table.observe(binding, authority.guard()));
}
