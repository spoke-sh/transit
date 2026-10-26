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
