const std = @import("std");
const t = std.testing;
const c = @import("root.zig");
const s = c.storage;
const d = c.protocol.DataLifecycle;
const Graph = c.DirectStorageGraph;
const P = s.TablePartition;

pub const Workspace = struct {
    jobs: std.ArrayList(Graph.Work) = .empty,
    marks: std.StringHashMap(void) = .init(t.allocator),
    pub fn deinit(self: *@This()) void {
        var keys = self.marks.keyIterator();
        while (keys.next()) |key| t.allocator.free(key.*);
        self.marks.deinit();
        self.jobs.deinit(t.allocator);
    }
    pub fn enqueue(self: *@This(), work: Graph.Work) !void {
        try self.jobs.append(t.allocator, work);
    }
    pub fn mark(self: *@This(), key: []const u8, _: s.TransitObjectStore.ObjectMeta) !void {
        if (self.marks.contains(key)) return;
        const owned = try t.allocator.dupe(u8, key);
        errdefer t.allocator.free(owned);
        try self.marks.put(owned, {});
    }
    pub fn visited(_: *@This(), _: [32]u8) !bool {
        return false;
    }
};

test "direct graph retains Queue scheduling bitmaps and full FIFO keys after collecting private candidates" {
    const Fixture = struct {
        fn acquire(_: *anyopaque) !s.PublicationGuard.Fence {
            return .{ .writer_epoch = 1, .policy_epoch = 1 };
        }
        fn release(_: *anyopaque) void {}
        fn clock(raw: *anyopaque) !?s.LogTime.Sample {
            const phase: *u8 = @ptrCast(@alignCast(raw));
            return .exact(if (phase.* == 0) 100 else 500);
        }
    };
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var context: u8 = 0;
    const guard: s.PublicationGuard = .{ .context = &context, .acquire = Fixture.acquire, .release = Fixture.release };
    const scope_id: d.Scope = .{ .realm = 1, .resource = 2, .catalog = 3 };
    var declaration = try s.LogDeclaration.prepare(t.allocator, .{
        .object = .{ .scope = scope_id, .branch = 1, .object = 8 },
        .revision = 1,
        .schema = .{ .object = 8, .revision = 1, .next_column = 2, .columns = &.{.{ .id = 1, .name = "key", .type = .utf8, .nullable = false, .collation = .ascii_ci }} },
        .configuration = .{
            .partitioning = .{ .count = 1, .key_column = null, .hash = .sha256_64 },
            .retention = .{ .max_age_ms = null },
            .policy = .{ .queue = .{ .ordering = .key_fifo, .key_column = 1, .lease_ms = 100, .maximum_lease_ms = 1000, .maximum_attempts = 5, .backoff = .{ .initial_ms = 1, .maximum_ms = 100, .multiplier = 2 }, .dead_letter = null } },
        },
        .limits = .{ .append_rows = 256, .append_bytes = 1024 * 1024, .claim_rows = 16, .read_rows = 256, .read_bytes = 1024 * 1024, .active_leases = 64, .waiters = 64, .timer_steps = 64 },
        .properties = "queue-graph",
    });
    defer declaration.deinit();
    const declared = try s.LogDeclaration.stage(objects.objectStore(), &declaration);
    const initial: s.LogInitialization.Request = .{ .definition = c.protocol.Growth.current_definition, .declared = declared, .operation = .{ .scope = scope_id, .principal = 1, .operation = 1 }, .ordinal = 0, .partition = 92 };
    _ = try s.LogInitialization.initialize(t.allocator, wal.log(), objects.objectStore(), initial, guard);
    const options: s.QueuePartition.Options = .{ .resident_pages = 1, .batch_bytes = 16384, .key_bytes = 1024, .clock = .{ .context = &context, .read = Fixture.clock }, .tail = .{ .slots = 1, .borrow_slots = 1, .slot_bytes = 16384, .resident_bytes = 32768 } };
    var owner = try s.QueuePartition.open(t.allocator, wal.log(), objects.objectStore(), initial, guard, options);
    defer owner.deinit() catch unreachable;
    _ = try owner.recoverStep(guard, 1);
    const operation: d.Operation = .{ .scope = scope_id, .principal = 1, .operation = 2 };
    var bytes: [16384]u8 = undefined;
    var encoder = try s.LogBatch.Encoder.init(declaration.definition.schema, operation, .queue, 24, &bytes);
    var long_key: [300]u8 = @splat('a');
    for (0..24) |i| {
        long_key[299] = @intCast('A' + i);
        try encoder.append(.{ .cells = &.{.{ .value = .{ .atom = .{ .bytes = &long_key } } }}, .visible_ms = i });
    }
    const payload = try encoder.finish();
    const request: c.protocol.StreamQueue.Append = .{ .target = initial.target(), .operation = operation, .kind = .queue, .producer = null, .rows = 24, .payload = s.LogBatch.content(payload) };
    const receipt = try owner.enqueue(declared, request, payload, guard);
    const frozen_batches = owner.owner.root.batches.?;
    const claim: c.protocol.StreamQueue.Claim = .{ .target = initial.target(), .operation = .{ .scope = scope_id, .principal = 1, .operation = 3 }, .maximum = 16, .lease_ms = 100 };
    const claimed = try owner.claim(declared, claim, guard);
    try t.expectEqual(@as(u32, 16), claimed.rows);
    var original_bytes: [s.QueueSelection.max_bytes]u8 = undefined;
    const original_selection = try s.QueueSelection.load(t.allocator, objects.objectStore(), claimed.leases.?, &original_bytes);
    _ = try owner.settle(declared, .{ .operation = .{ .scope = scope_id, .principal = 1, .operation = 4 }, .lease = try original_selection.lease(0), .action = .ack }, guard);
    _ = try owner.settle(declared, .{ .operation = .{ .scope = scope_id, .principal = 1, .operation = 5 }, .lease = try original_selection.lease(2), .action = .{ .nack = .{ .visible_ms = 0 } } }, guard);
    context = 1;
    try t.expect(try owner.expireOne(declared, guard));
    const later: d.Operation = .{ .scope = scope_id, .principal = 1, .operation = 6 };
    encoder = try s.LogBatch.Encoder.init(declaration.definition.schema, later, .queue, 1, &bytes);
    long_key[299] = 'z';
    try encoder.append(.{ .cells = &.{.{ .value = .{ .atom = .{ .bytes = &long_key } } }} });
    const added = try encoder.finish();
    _ = try owner.enqueue(declared, .{ .target = initial.target(), .operation = later, .kind = .queue, .producer = null, .rows = 1, .payload = s.LogBatch.content(added) }, added, guard);
    const cut = owner.owner.root.position();
    while (!(try owner.flush(cut, guard)).complete) {}
    while (!(try owner.archive(cut, .{ .frames = 2 }, guard)).complete) {}
    _ = try owner.checkpoint(cut, guard);
    _ = try owner.trimArchived(guard);
    const root = owner.owner.root;
    try t.expect(!std.meta.eql(frozen_batches, root.batches.?));
    var latest = try wal.log().read(t.allocator, 92, root.next_lsn - 1, 1);
    defer latest.deinit();
    var workspace: Workspace = .{};
    defer workspace.deinit();
    try workspace.enqueue(try Graph.fromFrame(t.allocator, latest.frames[0]));
    var job: usize = 0;
    var steps: usize = 0;
    while (job < workspace.jobs.items.len) : (job += 1) {
        var work = workspace.jobs.items[job];
        while (true) {
            const queued = workspace.jobs.items.len;
            const complete = try Graph.step(t.allocator, &owner.owner.store, wal.log(), &work, &workspace);
            try t.expect(workspace.jobs.items.len - queued <= 3);
            steps += 1;
            if (steps > 10000) return error.FixtureBudget;
            if (complete) break;
        }
    }
    var name: [96]u8 = undefined;
    try t.expect(workspace.marks.contains(try s.TreeStore.key(frozen_batches.location, &name)));
    try t.expect(workspace.marks.contains(try s.QueueSelection.objectKey(claimed.leases.?, &name)));
    for ([_]?s.TreeStore.pages.Reference{ root.queue.?.items, root.queue.?.sidecars, root.queue.?.keys, root.queue.?.eligible }) |reference| try t.expect(workspace.marks.contains(try s.TreeStore.key(reference.?.location, &name)));
    var removed: usize = 0;
    var at: usize = 0;
    while (at < objects.objects.items.len) {
        const item = objects.objects.items[at];
        if (Graph.collectible(item.key) and !workspace.marks.contains(item.key)) {
            try objects.objectStore().delete(item.key);
            removed += 1;
        } else at += 1;
    }
    try t.expect(removed > 24);
    try owner.deinit();
    owner = try s.QueuePartition.open(t.allocator, wal.log(), objects.objectStore(), initial, guard, options);
    const puts = objects.puts;
    try t.expect((try owner.recoverStep(guard, 1)).complete);
    try t.expectEqual(puts, objects.puts);
    try t.expectEqualDeep(root, owner.owner.root);
    try t.expectEqualDeep(receipt, (try owner.operation(operation, guard)).?.outcome.append);
    try t.expectEqualDeep(claimed, try owner.claim(declared, claim, guard));
    var selection_buffer: [s.QueueSelection.max_bytes]u8 = undefined;
    const selection = try s.QueueSelection.load(t.allocator, objects.objectStore(), claimed.leases.?, &selection_buffer);
    try selection.requireReceipt(claimed);
    var bitmap: s.BitmapDirectory = .{ .store = &owner.owner.store, .objects = owner.owner.objects };
    const queue: s.QueueIndex = .{ .store = &owner.owner.store, .scratch = &owner.owner.scratch, .bitmap = &bitmap, .container = &owner.owner.queue_container, .key_buffer = owner.owner.key_buffer };
    var canonical: [1024]u8 = undefined;
    for (0..24) |i| {
        long_key[299] = @intCast('a' + i);
        const key = try c.fuze.Collation.encodeSortKey(.{ .value = .{ .atom = .{ .bytes = &long_key } } }, .utf8, .ascii_ci, &canonical);
        if (i == 0) {
            try t.expect(try queue.head(root.queue.?, key) == null);
        } else try t.expectEqualDeep(s.QueueIndex.Head{ .first = i, .last = i }, (try queue.head(root.queue.?, key)).?);
        const state: s.Tack.State = if (i == 0) .acked else if (i >= 3 and i < 16) .acquired else .available;
        try t.expectEqual(state, try queue.state(root.queue.?, try queue.item(root.queue.?, i)));
    }
}

test "direct graph retains physical and ADD interpretations without receipt or history roots" {
    const Fixture = struct {
        fn acquire(_: *anyopaque) !P.Guard.Fence {
            return .{ .writer_epoch = 1, .policy_epoch = 1 };
        }
        fn release(_: *anyopaque) void {}
        fn binding(table: *P, id: u64, action: d.Action) d.Binding {
            return .{ .definition = c.protocol.Growth.current_definition, .identity = .{ .scope = table.root.interpretation.object.scope, .principal = 4, .operation = id }, .target = table.root.interpretation.object, .action = action, .expected_definition = if (action == .create) null else table.root.interpretation, .expected_data = null, .intent = @splat(1) };
        }
    };
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    const object: d.Object = .{ .scope = .{ .realm = 1, .resource = 2, .catalog = 3 }, .branch = 1, .object = 7 };
    var table = try P.init(t.allocator, 17, .{ .object = object, .revision = 1, .schema = .{ .object = 7, .revision = 1, .next_column = 2, .columns = &.{.{ .id = 1, .name = "id", .type = .int64, .nullable = false }}, .primary_key = &.{1} }, .properties = "graph" }, wal.log(), objects.objectStore(), .{ .resident_pages = 1 });
    defer table.deinit();
    try table.recover();
    var context: u8 = 0;
    const guard: P.Guard = .{ .context = &context, .acquire = Fixture.acquire, .release = Fixture.release };
    _ = try table.apply(Fixture.binding(&table, 1, .create), &.{.{ .put = .{ .row = .{ .identity = .{ .origin = 7, .operation = 1, .ordinal = 0 }, .cells = &.{.{ .value = .{ .atom = .{ .signed = 1 } } }} } } }}, .point, guard);
    const physical = table.root.declared();
    _ = try table.changeDefinition(Fixture.binding(&table, 2, .alter), .{ .alter = .{ .change = .{ .add = .{ .name = "score", .type = .int64, .nullable = false, .default = .{ .value = .{ .atom = .{ .signed = 7 } } } } }, .properties = "graph" } }, guard);
    const origin = table.root.declared();
    _ = try table.changeDefinition(Fixture.binding(&table, 3, .alter), .{ .alter = .{ .change = .{ .default = .{ .column = 2, .value = .{ .value = .{ .atom = .{ .signed = 9 } } } } }, .properties = "graph" } }, guard);
    // A snapshot root owns rows and their interpretation, without retaining the
    // historical records or receipts that could accidentally mask a missed edge.
    var workspace: Workspace = .{};
    defer workspace.deinit();
    try workspace.enqueue(.{ .table_root = .{ .root = table.root, .archive = table.root.archive, .role = .snapshot } });
    var at: usize = 0;
    var steps: usize = 0;
    while (at < workspace.jobs.items.len) {
        var work = workspace.jobs.items[at];
        while (!try Graph.step(t.allocator, &table.index, wal.log(), &work, &workspace)) {
            steps += 1;
            if (steps == 1000) return error.FixtureBudget;
        }
        at += 1;
    }
    var name: [96]u8 = undefined;
    for ([_]s.TableDeclaration.Stored{ physical, origin, table.root.declared() }) |stored| try t.expect(workspace.marks.contains(try s.TableDeclaration.key(stored.content, &name)));
    // Receipt pages are intentionally absent from this isolated source graph.
    try t.expect(!workspace.marks.contains(try s.TreeStore.key(table.root.receipts.?.location, &name)));
}

test "direct graph retains document partition declarations states payloads evidence live reads and checkpoints" {
    const DocFixture = struct {
        fn acquire(_: *anyopaque) !s.PublicationGuard.Fence {
            return .{ .writer_epoch = 1, .policy_epoch = 1 };
        }
        fn release(_: *anyopaque) void {}
        fn hashBytes(bytes: []const u8) [32]u8 {
            var digest: [32]u8 = undefined;
            std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
            return digest;
        }
    };
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var context: u8 = 0;
    const guard: s.PublicationGuard = .{ .context = &context, .acquire = DocFixture.acquire, .release = DocFixture.release };
    const cols = [_]c.fuze.TableSchema.Column{
        .{ .id = 1, .name = "doc_key", .type = .utf8, .nullable = false, .collation = .utf8_binary },
    };
    const scope_id: d.Scope = .{ .realm = 1, .resource = 2, .catalog = 3 };
    var owned_decl = try s.DocumentDeclaration.prepare(t.allocator, .{
        .object = .{ .scope = scope_id, .branch = 1, .object = 808 },
        .revision = 1,
        .schema = .{ .object = 808, .revision = 1, .next_column = 2, .columns = &cols },
        .configuration = .{
            .partitioning = .{ .count = 4, .key_column = 1, .hash = .sha256_64 },
            .profile = .causal_crdt,
            .shredding = .{ .frequent_path_threshold = 64, .max_shredded_columns = 32, .default_collation = .utf8_binary },
            .retention = .{ .max_age_ms = null, .merge_window_revisions = 16 },
        },
        .limits = .{
            .change_bytes = 65_536,
            .operations_per_change = 64,
            .path_depth = 32,
            .read_steps = 4096,
            .read_bytes = 262_144,
            .unresolved_conflicts = 16,
        },
        .properties = "doc-graph-props",
    });
    defer owned_decl.deinit();
    const declared = try s.DocumentDeclaration.stage(objects.objectStore(), &owned_decl);
    const init_req: s.DocumentInitialization.Request = .{
        .definition = c.protocol.Growth.current_definition,
        .declared = declared,
        .operation = .{ .scope = scope_id, .principal = 7, .operation = 1 },
        .ordinal = 0,
        .partition = 141,
    };
    _ = try s.DocumentInitialization.initialize(t.allocator, wal.log(), objects.objectStore(), init_req, guard);
    var owner = try s.DocumentPartition.open(t.allocator, wal.log(), objects.objectStore(), init_req, guard, .{});
    defer owner.deinit();

    const doc = c.protocol.DocumentOperation;
    const target: doc.Target = .{ .partition = init_req.target(), .document = @splat(0x42) };
    const payload = "doc-delta-payload";
    const state = "{\"k\":\"v\"}";
    const mut_rec = try owner.applyMutation(.{
        .target = target,
        .operation = .{ .scope = scope_id, .principal = 7, .operation = 2 },
        .lineage = .{
            .profile = .causal_crdt,
            .merge_epoch = 1,
            .base_revision = 0,
            .parent_revision = null,
            .replica = .{ .id = @splat(0x52), .epoch = 1, .sequence = 1, .preceding_sequence = 0 },
            .raw_span = null,
        },
        .operations = 1,
        .payload = .{ .bytes = payload.len, .sha256 = DocFixture.hashBytes(payload) },
    }, payload, state, 0, guard);

    const live_read = try owner.beginRead(.{
        .target = target,
        .operation = .{ .scope = scope_id, .principal = 7, .operation = 3 },
        .from_revision = 1,
        .through_revision = 1,
        .max_steps = 16,
        .max_bytes = 4096,
    }, guard);
    const closed_read = try owner.beginRead(.{
        .target = target,
        .operation = .{ .scope = scope_id, .principal = 7, .operation = 4 },
        .from_revision = 1,
        .through_revision = 1,
        .max_steps = 16,
        .max_bytes = 4096,
    }, guard);
    _ = try owner.releaseRead(.{
        .target = target,
        .operation = .{ .scope = scope_id, .principal = 7, .operation = 5 },
        .read = closed_read.handle(),
    }, guard);
    _ = try owner.archive(owner.root.position(), .{}, guard);
    const recovery_ref = try owner.checkpointRecovery(owner.root.position(), guard);

    const tail = try wal.log().tail(init_req.partition);
    var latest_batch = try wal.log().read(t.allocator, init_req.partition, tail - 1, 1);
    defer latest_batch.deinit();

    var workspace: Workspace = .{};
    defer workspace.deinit();
    try workspace.enqueue(try Graph.fromFrame(t.allocator, latest_batch.frames[0]));
    var at: usize = 0;
    var steps: usize = 0;
    while (at < workspace.jobs.items.len) {
        var work = workspace.jobs.items[at];
        while (!try Graph.step(t.allocator, &owner.store, wal.log(), &work, &workspace)) {
            steps += 1;
            if (steps == 2000) return error.FixtureBudget;
        }
        at += 1;
    }

    var name: [96]u8 = undefined;
    try t.expect(Graph.collectible(try s.DocumentDeclaration.key(declared.content, &name)));
    try t.expect(workspace.marks.contains(try s.DocumentDeclaration.key(declared.content, &name)));
    try t.expect(workspace.marks.contains(try s.DocumentRecovery.key(recovery_ref.content, &name)));
    try t.expect(workspace.marks.contains(try s.DocumentRead.key(live_read.source, &name)));
    const state_key = try std.fmt.bufPrint(&name, "document-states/{x}.data", .{&mut_rec.state.sha256});
    try t.expect(workspace.marks.contains(state_key));
    const payload_key = try std.fmt.bufPrint(&name, "document-payloads/{x}.data", .{&mut_rec.mutation.payload.sha256});
    try t.expect(workspace.marks.contains(payload_key));
}
