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
    var definition: s.LogDeclaration.Definition = .{
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
    };
    var target_definition = definition;
    target_definition.object.object = 10;
    target_definition.schema.object = 10;
    var terminal_destination = try s.LogDeclaration.prepare(t.allocator, target_definition);
    defer terminal_destination.deinit();
    const terminal_stored = try s.LogDeclaration.stage(objects.objectStore(), &terminal_destination);
    target_definition.object.object = 9;
    target_definition.schema.object = 9;
    target_definition.configuration.policy.queue.dead_letter = terminal_stored.declaration.interpretation;
    var destination = try s.LogDeclaration.prepare(t.allocator, target_definition);
    defer destination.deinit();
    const destination_stored = try s.LogDeclaration.stage(objects.objectStore(), &destination);
    target_definition.revision = 2;
    target_definition.retired = true;
    target_definition.configuration.policy.queue.dead_letter = null;
    var replacement = try s.LogDeclaration.prepare(t.allocator, target_definition);
    defer replacement.deinit();
    const replacement_stored = try s.LogDeclaration.stage(objects.objectStore(), &replacement);
    target_definition.object.object = 11;
    target_definition.schema.object = 11;
    target_definition.revision = 1;
    target_definition.retired = false;
    target_definition.configuration.policy = .{ .stream = .{ .compact_key_column = null, .timestamp_column = null } };
    var stream_destination = try s.LogDeclaration.prepare(t.allocator, target_definition);
    defer stream_destination.deinit();
    const stream_stored = try s.LogDeclaration.stage(objects.objectStore(), &stream_destination);
    definition.configuration.policy.queue.maximum_attempts = 1;
    definition.configuration.policy.queue.dead_letter = destination_stored.declaration.interpretation;
    var declaration = try s.LogDeclaration.prepare(t.allocator, definition);
    defer declaration.deinit();
    const declared = try s.LogDeclaration.stage(objects.objectStore(), &declaration);
    const initial: s.LogInitialization.Request = .{ .definition = c.protocol.Growth.current_definition, .declared = declared, .operation = .{ .scope = scope_id, .principal = 1, .operation = 1 }, .ordinal = 0, .partition = 92 };
    _ = try s.LogInitialization.initialize(t.allocator, wal.log(), objects.objectStore(), initial, guard);
    const options: s.QueuePartition.Options = .{ .resident_pages = 1, .batch_bytes = 65536, .key_bytes = 1024, .clock = .{ .context = &context, .read = Fixture.clock }, .tail = .{ .slots = 1, .borrow_slots = 1, .slot_bytes = 65536, .resident_bytes = 131072 } };
    var owner = try s.QueuePartition.open(t.allocator, wal.log(), objects.objectStore(), initial, guard, options);
    defer owner.deinit() catch unreachable;
    _ = try owner.recoverStep(guard, 1);
    const operation: d.Operation = .{ .scope = scope_id, .principal = 1, .operation = 2 };
    var bytes: [65536]u8 = undefined;
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
    // Leave accepted scheduling with a pending chunk, an unfinished two-input
    // merge and a partial output directory. Its frozen item/bitmap basis must
    // remain reachable independently of the current Queue state.
    for (7..13) |id| {
        const identity: d.Operation = .{ .scope = scope_id, .principal = 1, .operation = id };
        encoder = try s.LogBatch.Encoder.init(declaration.definition.schema, identity, .queue, 128, &bytes);
        var key_bytes: [32]u8 = undefined;
        for (0..128) |i| {
            const key = try std.fmt.bufPrint(&key_bytes, "timer-{d}-{d}", .{ id, i });
            try encoder.append(.{ .cells = &.{.{ .value = .{ .atom = .{ .bytes = key } } }} });
        }
        const batch = try encoder.finish();
        _ = try owner.enqueue(declared, .{ .target = initial.target(), .operation = identity, .kind = .queue, .producer = null, .rows = 128, .payload = s.LogBatch.content(batch) }, batch, guard);
    }
    var merged = false;
    for (0..256) |_| {
        try t.expect(try owner.scheduleMaintenanceUnit(declared, 17, guard));
        if (owner.owner.root.queue.?.eligible.work) |pending| {
            if (pending.merge.sources[1].rows != 0 and pending.merge.output.rows != 0) {
                merged = true;
                break;
            }
        }
    }
    try t.expect(merged);
    // Current time still precedes this later claim's deadline. A NACK changes
    // the current basis after the timer merge froze it, without completing it.
    const next_claim = try owner.claim(declared, .{ .target = initial.target(), .operation = .{ .scope = scope_id, .principal = 1, .operation = 13 }, .maximum = 1, .lease_ms = 100 }, guard);
    var next_bytes: [s.QueueSelection.max_bytes]u8 = undefined;
    const next_selection = try s.QueueSelection.load(t.allocator, objects.objectStore(), next_claim.leases.?, &next_bytes);
    _ = try owner.settle(declared, .{ .operation = .{ .scope = scope_id, .principal = 1, .operation = 14 }, .lease = try next_selection.lease(0), .action = .{ .nack = .{ .visible_ms = 1000 } } }, guard);
    const cut = owner.owner.root.position();
    while (!(try owner.flush(cut, guard)).complete) {}
    while (!(try owner.archive(cut, .{ .frames = 2 }, guard)).complete) {}
    _ = try owner.checkpoint(cut, guard);
    _ = try owner.trimArchived(guard);
    const root = owner.owner.root;
    try t.expect(!std.meta.eql(frozen_batches, root.batches.?));
    {
        var isolated: Workspace = .{};
        defer isolated.deinit();
        const scheduling = root.queue.?.eligible;
        try t.expect(scheduling.pending != null and scheduling.work != null);
        const frozen = scheduling.work.?.merge;
        try t.expect(!std.meta.eql(frozen.basis.items, root.queue.?.items));
        try isolated.enqueue(.{ .queue_schedule = .{
            .context = .{ .log = .{ .interpretation = root.declared.declaration.interpretation, .partition = root.initialization.partition, .ordinal = root.initialization.ordinal, .next_lsn = root.next_lsn, .next_offset = root.next_offset, .segments = root.segments, .hidden = root.hidden, .queue_read_releases = root.queue.?.read_releases, .archive = root.archive }, .seed = initial.target(), .kind = .visible, .serial = scheduling.serial },
            .root = scheduling,
        } });
        var at_job: usize = 0;
        while (at_job < isolated.jobs.items.len) : (at_job += 1) {
            var work = isolated.jobs.items[at_job];
            while (!try Graph.step(t.allocator, &owner.owner.store, wal.log(), &work, &isolated)) {}
        }
        var key: [96]u8 = undefined;
        for ([_]?s.TreeStore.pages.Reference{ frozen.basis.items, frozen.basis.sidecars }) |reference| try t.expect(isolated.marks.contains(try s.TreeStore.key(reference.?.location, &key)));
        for (frozen.sources ++ [_]s.QueueTimeDirectory.Root{frozen.output}) |run| {
            try t.expect(isolated.marks.contains(try s.TreeStore.key(run.directory.?.location, &key)));
            const directory: s.QueueTimeDirectory = .{ .store = &owner.owner.store, .seed = initial.target(), .kind = .visible, .bucket = frozen.bucket };
            var audit: s.QueueTimeDirectory.Audit = .{ .basis = run };
            while (try directory.audit(&audit)) |entry| try t.expect(isolated.marks.contains(try s.QueueTimeRun.key(entry.chunk.content, &key)));
        }
    }
    // Isolate the accepted item directory: neither source declaration nor
    // catalog/history traversal may mask a missing blocked-destination edge.
    {
        var isolated: Workspace = .{};
        defer isolated.deinit();
        try isolated.enqueue(.{ .log_index = .{
            .context = .{ .interpretation = root.declared.declaration.interpretation, .partition = root.initialization.partition, .ordinal = root.initialization.ordinal, .next_lsn = root.next_lsn, .next_offset = root.next_offset, .segments = root.segments, .hidden = root.hidden, .queue_read_releases = root.queue.?.read_releases, .archive = root.archive },
            .reference = root.queue.?.items.?,
            .kind = .queue_items,
        } });
        var job: usize = 0;
        var steps: usize = 0;
        while (job < isolated.jobs.items.len) : (job += 1) {
            var work = isolated.jobs.items[job];
            while (true) {
                const queued = isolated.jobs.items.len;
                const complete = try Graph.step(t.allocator, &owner.owner.store, wal.log(), &work, &isolated);
                try t.expect(isolated.jobs.items.len - queued <= 3);
                steps += 1;
                if (steps > 10000) return error.FixtureBudget;
                if (complete) break;
            }
        }
        var name: [96]u8 = undefined;
        for ([_]s.LogDeclaration.Stored{ destination_stored, terminal_stored }) |stored| try t.expect(isolated.marks.contains(try s.LogDeclaration.key(stored.content, &name)));
        try t.expect(!isolated.marks.contains(try s.LogDeclaration.key(replacement_stored.content, &name)));
        var invalid: Graph.Work = .{ .queue_destination = replacement_stored.declaration.interpretation };
        try t.expectError(error.InvalidQueueDestination, Graph.step(t.allocator, &owner.owner.store, wal.log(), &invalid, &isolated));
        invalid = .{ .queue_destination = stream_stored.declaration.interpretation };
        try t.expectError(error.InvalidQueueDestination, Graph.step(t.allocator, &owner.owner.store, wal.log(), &invalid, &isolated));
        invalid = .{ .queue_destination = destination_stored.declaration.interpretation };
        invalid.queue_destination.revision += 1;
        try t.expectError(error.InvalidLogDeclaration, Graph.step(t.allocator, &owner.owner.store, wal.log(), &invalid, &isolated));
        invalid.queue_destination.digest = @splat(99);
        try t.expectError(error.LogDeclarationMissing, Graph.step(t.allocator, &owner.owner.store, wal.log(), &invalid, &isolated));
    }
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
            if (steps > 100000) return error.FixtureBudget;
            if (complete) break;
        }
    }
    var name: [96]u8 = undefined;
    try t.expect(workspace.marks.contains(try s.TreeStore.key(frozen_batches.location, &name)));
    try t.expect(workspace.marks.contains(try s.QueueSelection.objectKey(claimed.leases.?, &name)));
    for ([_]s.LogDeclaration.Stored{ destination_stored, terminal_stored }) |stored| try t.expect(workspace.marks.contains(try s.LogDeclaration.key(stored.content, &name)));
    try t.expect(!workspace.marks.contains(try s.LogDeclaration.key(replacement_stored.content, &name)));
    for ([_]?s.TreeStore.pages.Reference{ root.queue.?.items, root.queue.?.sidecars, root.queue.?.keys }) |reference| try t.expect(workspace.marks.contains(try s.TreeStore.key(reference.?.location, &name)));
    for ([_]s.QueueSchedule.Root{ root.queue.?.eligible, root.queue.?.deadlines }) |scheduled| try t.expect(workspace.marks.contains(try s.QueueTimeBuffer.key(scheduled.active.?, &name)));
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
    var payload_page = try owner.readClaimPage(declared, .{ .receipt = claimed, .next = 0 }, .{}, t.allocator, guard);
    defer payload_page.deinit();
    try t.expect(payload_page.cursor.complete() and payload_page.rows().len == 16);
    try t.expectEqual(c.protocol.QueueRead.State.acked, payload_page.rows()[0].lease.state);
    try t.expectEqual(c.protocol.QueueRead.Liveness.fenced, payload_page.rows()[1].lease.liveness);
    try t.expectEqualDeep(c.protocol.QueueRead.Blocked{ .dead_letter = destination_stored.declaration.interpretation }, payload_page.rows()[1].lease.blocked);
    try t.expectEqualDeep(c.protocol.QueueRead.Blocked{ .dead_letter = destination_stored.declaration.interpretation }, payload_page.rows()[2].lease.blocked);
    try t.expectEqual(c.protocol.QueueRead.Liveness.expired, payload_page.rows()[3].lease.liveness);
    var decoded_payload = try c.fuze.TableRow.decode(t.allocator, declaration.definition.schema, payload_page.rows()[0].encoded);
    defer decoded_payload.deinit();
    long_key[299] = 'A';
    try t.expectEqualSlices(u8, &long_key, decoded_payload.row().cells[0].value.atom.bytes);
    var bitmap: s.BitmapDirectory = .{ .store = &owner.owner.store, .objects = owner.owner.objects };
    const queue: s.QueueIndex = .{ .store = &owner.owner.store, .scratch = &owner.owner.scratch, .bitmap = &bitmap, .container = &owner.owner.queue_container, .key_buffer = owner.owner.key_buffer, .timer_workspace = owner.owner.queue_timers, .timer_seed = owner.owner.root.initialization.target(), .timer_read_work = owner.owner.options.queue_timer_read_work };
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
    var maintenance_units: usize = 0;
    while (try owner.scheduleMaintenanceUnit(declared, 17, guard)) : (maintenance_units += 1) {
        if (maintenance_units > 512) return error.FixtureBudget;
    }
    try t.expect(maintenance_units > 20);
    const before_release = owner.owner.root;
    const released = try owner.releaseClaimRead(declared, .{ .operation = .{ .scope = scope_id, .principal = 1, .operation = 1000 }, .claim = claimed }, guard);
    const after_release = owner.owner.root;
    // Isolate the selection edge. The current Queue still retains its live
    // payloads independently, and older recovery roots still retain their cuts.
    for ([_]s.QueuePartition.Root{ before_release, after_release }) |basis| {
        var isolated: Workspace = .{};
        defer isolated.deinit();
        try isolated.enqueue(.{ .queue_selection = .{
            .context = .{ .interpretation = basis.declared.declaration.interpretation, .partition = basis.initialization.partition, .ordinal = basis.initialization.ordinal, .next_lsn = basis.next_lsn, .next_offset = basis.next_offset, .segments = basis.segments, .hidden = basis.hidden, .queue_read_releases = basis.queue.?.read_releases, .archive = basis.archive },
            .receipt = claimed,
        } });
        var at_job: usize = 0;
        var traversed: usize = 0;
        while (at_job < isolated.jobs.items.len) : (at_job += 1) {
            var work = isolated.jobs.items[at_job];
            while (true) {
                const done = try Graph.step(t.allocator, &owner.owner.store, wal.log(), &work, &isolated);
                traversed += 1;
                if (traversed > 10000) return error.FixtureBudget;
                if (done) break;
            }
        }
        try t.expect(isolated.marks.contains(try s.QueueSelection.objectKey(claimed.leases.?, &name)));
        try t.expectEqual(basis.next_lsn < released.accepted.next_lsn, isolated.marks.contains(try s.TreeStore.key(frozen_batches.location, &name)));
        if (basis.queue.?.read_releases != null) {
            var impossible = isolated.jobs.items[0];
            impossible.queue_selection.context.next_lsn = before_release.next_lsn;
            try t.expectError(error.InvalidQueueReadRelease, Graph.step(t.allocator, &owner.owner.store, wal.log(), &impossible, &isolated));
        }
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
    var owner = try s.DocumentPartition.open(t.allocator, wal.log(), objects.objectStore(), init_req, guard, .{ .read_secret = @splat(7) });
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
    const logical = s.LogicalDocumentChange;
    const logical_header: logical.Header = .{ .definition = c.protocol.Growth.definition_bytes, .document = @splat(0x61), .replica = @splat(0x71), .epoch = 1, .sequence = 1, .preceding_sequence = 0, .operations = 1 };
    var logical_buffer: [2048]u8 = undefined;
    const large_value: [800]u8 = @splat('x');
    const logical_bytes = try logical.encode(logical_header, &.{.{ .field = "body", .value = .{ .kind = .string, .bytes = &large_value } }}, &logical_buffer);
    const logical_receipt = try owner.applyCausal(.{
        .target = .{ .partition = init_req.target(), .document = logical_header.document },
        .operation = .{ .scope = scope_id, .principal = 7, .operation = 6 },
        .lineage = .{ .profile = .causal_crdt, .merge_epoch = 1, .base_revision = 0, .parent_revision = null, .replica = .{ .id = logical_header.replica, .epoch = 1, .sequence = 1, .preceding_sequence = 0 }, .raw_span = null },
        .operations = 1,
        .payload = .{ .bytes = logical_bytes.len, .sha256 = DocFixture.hashBytes(logical_bytes) },
    }, logical_bytes, guard);
    const logical_state = try s.DocumentLogicalState.load(t.allocator, objects.objectStore(), logical_receipt.state);
    // Seal a private candidate without accepting it. Collection must distinguish
    // its segment from the accepted tree even though they share directory pages.
    var private = try owner.logical_store.begin(.{ .root = logical_state.index }, 1024 * 1024);
    private = try private.put(&owner.logical_store, try s.DocumentIndex.Key.init("private-orphan"), try s.DocumentIndex.Value.init("unaccepted"));
    private = try owner.logical_store.seal(private);
    const records: s.TreeStore.pages.Tree(s.TreeStore) = .{ .store = &owner.logical_store.tree };
    const locator = try s.DocumentIndex.Locator.decode((try records.get(private.root.?.records, try s.TreeStore.pages.Key.init(&DocFixture.hashBytes("private-orphan")))).?);
    var orphan_name: [96]u8 = undefined;
    const orphan_key = try s.DocumentIndex.segmentKey(locator.segment, &orphan_name);

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
    var accepted_segments: usize = 0;
    for (objects.objects.items) |object| {
        if (std.mem.startsWith(u8, object.key, "document-segment/")) {
            try t.expect(Graph.collectible(object.key));
            if (std.mem.eql(u8, object.key, orphan_key)) {
                try t.expect(!workspace.marks.contains(object.key));
            } else {
                try t.expect(workspace.marks.contains(object.key));
                accepted_segments += 1;
            }
        }
    }
    try t.expectEqual(@as(usize, 1), accepted_segments);
    try t.expect(workspace.marks.contains(try s.TreeStore.key(logical_state.index.records.location, &name)));
    try t.expect(workspace.marks.contains(try s.TreeStore.key(logical_state.index.ordered.location, &name)));
}

test "direct graph retains transaction log source payloads after archive trim until exact release" {
    const Fixture = struct {
        fn acquire(_: *anyopaque) !s.PublicationGuard.Fence {
            return .{ .writer_epoch = 1, .policy_epoch = 1 };
        }
        fn release(_: *anyopaque) void {}
        fn walk(owner: *s.StreamPartition, wal: s.TransitLog.Log, workspace: *Workspace) !void {
            // Isolate the pin edge; current data and WAL replay roots cannot
            // conceal a missing transaction dependency.
            const root = owner.root;
            try workspace.enqueue(.{ .log_index = .{
                .context = .{ .interpretation = root.declared.declaration.interpretation, .partition = root.initialization.partition, .ordinal = root.initialization.ordinal, .next_lsn = root.next_lsn, .next_offset = root.next_offset, .segments = root.segments, .hidden = root.hidden, .queue_read_releases = null, .archive = root.archive },
                .reference = root.transaction_pins.?,
                .kind = .transaction_pins,
            } });
            var at: usize = 0;
            var steps: usize = 0;
            while (at < workspace.jobs.items.len) : (at += 1) {
                var work = workspace.jobs.items[at];
                while (true) {
                    const queued = workspace.jobs.items.len;
                    const complete = try Graph.step(t.allocator, &owner.store, wal, &work, workspace);
                    try t.expect(workspace.jobs.items.len - queued <= 3);
                    steps += 1;
                    if (steps > 10000) return error.FixtureBudget;
                    if (complete) break;
                }
            }
        }
    };
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var context: u8 = 0;
    const guard: s.PublicationGuard = .{ .context = &context, .acquire = Fixture.acquire, .release = Fixture.release };
    const scope_id: d.Scope = .{ .realm = 1, .resource = 2, .catalog = 3 };
    const definition: s.LogDeclaration.Definition = .{
        .object = .{ .scope = scope_id, .branch = 1, .object = 8 },
        .revision = 1,
        .schema = .{ .object = 8, .revision = 1, .next_column = 2, .columns = &.{.{ .id = 1, .name = "value", .type = .utf8, .nullable = false, .collation = .utf8_binary }} },
        .configuration = .{ .partitioning = .{ .count = 1, .key_column = null, .hash = .sha256_64 }, .retention = .{ .max_age_ms = null }, .policy = .{ .stream = .{ .compact_key_column = null, .timestamp_column = null } } },
        .limits = .{ .append_rows = 256, .append_bytes = 1024 * 1024, .claim_rows = 16, .read_rows = 256, .read_bytes = 1024 * 1024, .active_leases = 64, .waiters = 64, .timer_steps = 64 },
        .properties = "transaction-source-graph",
    };
    var declaration = try s.LogDeclaration.prepare(t.allocator, definition);
    defer declaration.deinit();
    const declared = try s.LogDeclaration.stage(objects.objectStore(), &declaration);
    const initial: s.LogInitialization.Request = .{ .definition = c.protocol.Growth.current_definition, .declared = declared, .operation = .{ .scope = scope_id, .principal = 1, .operation = 1 }, .ordinal = 0, .partition = 92 };
    _ = try s.LogInitialization.initialize(t.allocator, wal.log(), objects.objectStore(), initial, guard);
    const options: s.StreamPartition.Options = .{ .resident_pages = 1, .batch_bytes = 8192, .key_bytes = 1024, .tail = .{ .slots = 1, .borrow_slots = 1, .slot_bytes = 8192, .resident_bytes = 16384 } };
    var owner = try s.StreamPartition.open(t.allocator, wal.log(), objects.objectStore(), initial, guard, options);
    defer owner.deinit() catch unreachable;
    _ = try owner.recoverStep(guard, 1);
    const operation: d.Operation = .{ .scope = scope_id, .principal = 1, .operation = 2 };
    var bytes: [8192]u8 = undefined;
    const payload = try s.LogBatch.encode(definition.schema, operation, .stream, &.{.{ .cells = &.{.{ .value = .{ .atom = .{ .bytes = "retained" } } }} }}, &bytes);
    _ = try owner.append(declared, .{ .target = initial.target(), .operation = operation, .kind = .stream, .producer = null, .rows = 1, .payload = s.LogBatch.content(payload) }, payload, guard);
    const source_root = owner.root;
    const identity: c.protocol.Transaction.Identity = .{ .begin = .{ .scope = scope_id, .principal = 1, .operation = 3 }, .branch = 1 };
    const pin = try owner.pinTransactionSource(declared, identity, source_root.position(), guard);
    const cut = owner.root.position();
    while (!(try owner.flush(cut, guard)).complete) {}
    while (!(try owner.archive(cut, .{ .frames = 2 }, guard)).complete) {}
    _ = try owner.checkpoint(cut, guard);
    _ = try owner.trimArchived(guard);
    try t.expect(source_root.segments == null and owner.root.segments != null);
    var retained: Workspace = .{};
    defer retained.deinit();
    try Fixture.walk(&owner, wal.log(), &retained);
    var name: [96]u8 = undefined;
    try t.expect(retained.marks.contains(try s.LogTransaction.sourceKey(pin.content, &name)));
    try t.expect(retained.marks.contains(try s.TreeStore.key(source_root.batches.?.location, &name)));
    try t.expect(retained.marks.contains(try s.LogDeclaration.key(declared.content, &name)));
    try owner.releaseTransactionSource(pin, guard);
    var released: Workspace = .{};
    defer released.deinit();
    try Fixture.walk(&owner, wal.log(), &released);
    try t.expect(!released.marks.contains(try s.LogTransaction.sourceKey(pin.content, &name)));
    try t.expect(!released.marks.contains(try s.TreeStore.key(source_root.batches.?.location, &name)));
    // Replay history can still retain its earlier live pin independently.
    try t.expectError(error.LogTransactionSourceReleased, owner.inspectTransactionSource(pin, guard));
}

test "direct graph retains prepared log successors actions and frozen decision directories" {
    const Fixture = struct {
        fn acquire(_: *anyopaque) !s.PublicationGuard.Fence {
            return .{ .writer_epoch = 1, .policy_epoch = 1 };
        }
        fn release(_: *anyopaque) void {}
        fn walk(owner: *s.StreamPartition, wal: s.TransitLog.Log, workspace: *Workspace) !void {
            // A barrier's public payload root cannot retain its private successor.
            try workspace.enqueue(.{ .log_root = .{ .root = owner.root, .archive = owner.root.archive } });
            var at: usize = 0;
            var steps: usize = 0;
            while (at < workspace.jobs.items.len) : (at += 1) {
                var work = workspace.jobs.items[at];
                while (true) {
                    const queued = workspace.jobs.items.len;
                    const complete = try Graph.step(t.allocator, &owner.store, wal, &work, workspace);
                    try t.expect(workspace.jobs.items.len - queued <= 3);
                    steps += 1;
                    if (steps > 20000) return error.FixtureBudget;
                    if (complete) break;
                }
            }
        }
    };
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var context: u8 = 0;
    const guard: s.PublicationGuard = .{ .context = &context, .acquire = Fixture.acquire, .release = Fixture.release };
    const scope_id: d.Scope = .{ .realm = 1, .resource = 2, .catalog = 3 };
    const definition: s.LogDeclaration.Definition = .{
        .object = .{ .scope = scope_id, .branch = 1, .object = 8 },
        .revision = 1,
        .schema = .{ .object = 8, .revision = 1, .next_column = 2, .columns = &.{.{ .id = 1, .name = "value", .type = .utf8, .nullable = false, .collation = .utf8_binary }} },
        .configuration = .{ .partitioning = .{ .count = 1, .key_column = null, .hash = .sha256_64 }, .retention = .{ .max_age_ms = null }, .policy = .{ .stream = .{ .compact_key_column = null, .timestamp_column = null } } },
        .limits = .{ .append_rows = 256, .append_bytes = 1024 * 1024, .claim_rows = 16, .read_rows = 256, .read_bytes = 1024 * 1024, .active_leases = 64, .waiters = 64, .timer_steps = 64 },
        .properties = "transaction-source-graph",
    };
    var declaration = try s.LogDeclaration.prepare(t.allocator, definition);
    defer declaration.deinit();
    const declared = try s.LogDeclaration.stage(objects.objectStore(), &declaration);
    const initial: s.LogInitialization.Request = .{ .definition = c.protocol.Growth.current_definition, .declared = declared, .operation = .{ .scope = scope_id, .principal = 1, .operation = 1 }, .ordinal = 0, .partition = 92 };
    _ = try s.LogInitialization.initialize(t.allocator, wal.log(), objects.objectStore(), initial, guard);
    const options: s.StreamPartition.Options = .{ .resident_pages = 1, .batch_bytes = 8192, .key_bytes = 1024, .tail = .{ .slots = 1, .borrow_slots = 1, .slot_bytes = 8192, .resident_bytes = 16384 } };
    var owner = try s.StreamPartition.open(t.allocator, wal.log(), objects.objectStore(), initial, guard, options);
    defer owner.deinit() catch unreachable;
    _ = try owner.recoverStep(guard, 1);
    const operation: d.Operation = .{ .scope = scope_id, .principal = 1, .operation = 2 };
    var bytes: [8192]u8 = undefined;
    const payload = try s.LogBatch.encode(definition.schema, operation, .stream, &.{.{ .cells = &.{.{ .value = .{ .atom = .{ .bytes = "retained" } } }} }}, &bytes);
    _ = try owner.append(declared, .{ .target = initial.target(), .operation = operation, .kind = .stream, .producer = null, .rows = 1, .payload = s.LogBatch.content(payload) }, payload, guard);

    const identity: c.protocol.Transaction.Identity = .{ .begin = .{ .scope = scope_id, .principal = 1, .operation = 100 }, .branch = 1 };
    const basis = try s.LogTransaction.logGuard(owner.root);
    const pin = try owner.pinTransactionSource(declared, identity, owner.root.position(), guard);
    var actions = try s.LogTransactionActions.init(t.allocator, objects.objectStore(), identity, basis, 20, 1024 * 1024, 1, 1024 * 1024);
    defer actions.deinit();
    for (10..13) |id| {
        const append_operation: d.Operation = .{ .scope = scope_id, .principal = 1, .operation = id };
        const batch = try s.LogBatch.encode(definition.schema, append_operation, .stream, &.{.{ .cells = &.{.{ .value = .{ .atom = .{ .bytes = "private" } } }} }}, &bytes);
        try actions.put(.{ .statement = .{ .transaction = identity, .sequence = 1, .intent = @splat(8) }, .ordinal = @intCast(id - 9), .action = .{ .append = .{ .target = initial.target(), .operation = append_operation, .kind = .stream, .producer = null, .rows = 1, .payload = s.LogBatch.content(batch) } } }, batch);
    }
    const actions_root = try actions.seal();
    var selected = try s.TransactionDirectory.init(t.allocator, objects.objectStore(), identity, .participants, 10, 1, 1024 * 1024);
    defer selected.deinit();
    try selected.put(.{ .participant = .{ .log = .{ .guard = basis, .actions = actions_root } } });
    const directory = try selected.seal();
    const binding: s.TransactionDecisionLog.Binding = .{
        .begin = .{ .definition = c.protocol.Growth.current_definition, .identity = identity, .mode = .serializable, .selection = .explicit_objects, .objects = directory, .catalog = .{ .partition = 1, .next_lsn = 1 }, .limits = .{ .resident_bytes = 16 * 1024 * 1024, .workspace_bytes = 1024 * 1024, .participants = 10, .statements = 20, .savepoints = 2 } },
        .attempt = .{ .definition = c.protocol.Growth.current_definition, .transaction = identity, .operation = .{ .scope = scope_id, .principal = 1, .operation = 101 }, .cut = directory.content, .workspace = directory.content, .participants = directory, .writes = 1, .last_statement = 1 },
    };
    var journal = try s.TransactionDecisionLog.init(t.allocator, wal.log(), objects.objectStore(), 99, binding);
    try journal.recover();
    try journal.freeze(guard);
    _ = try owner.prepareTransaction(binding, 99, basis, pin, actions_root, .{ .actions = 20, .payload_bytes = 1024 * 1024, .resident_bytes = 16 * 1024 * 1024, .last_statement = 1 }, null, guard);
    const reference = owner.root.transaction.?;
    const preparation = try s.LogTransaction.loadPreparation(objects.objectStore(), reference);
    var retained: Workspace = .{};
    defer retained.deinit();
    try Fixture.walk(&owner, wal.log(), &retained);
    var name: [96]u8 = undefined;
    try t.expect(retained.marks.contains(try s.LogTransaction.preparationKey(reference, &name)));
    try t.expect(retained.marks.contains(try s.TreeStore.key(preparation.successor.batches.?.location, &name)));
    try t.expect(retained.marks.contains(try s.TreeStore.key(preparation.successor.segments.?.location, &name)));
    try t.expect(retained.marks.contains(try s.TreeStore.key(selected.root.entries.?.location, &name)));
    try t.expect(retained.marks.contains(try s.LogTransactionActions.objectKey(actions_root.content, &name)));
    for (1..4) |ordinal| {
        const cursor: s.LogTransactionActions.Cursor = .{ .sequence = 1, .ordinal = @intCast(ordinal) };
        try t.expect(retained.marks.contains(try s.LogTransactionActions.objectKey(try actions.entryContent(cursor), &name)));
        const entry = (try actions.get(cursor)).?;
        try t.expect(retained.marks.contains(try s.LogTransactionActions.payloadKey(entry.work.action.append.payload, &name)));
    }
    // Missing accepted private bytes stop traversal before it can establish a
    // complete mark set. A cached page cannot disguise this missing payload.
    const missing = (try actions.get(.{ .sequence = 1, .ordinal = 2 })).?.work.action.append.payload;
    try objects.objectStore().delete(try s.LogTransactionActions.payloadKey(missing, &name));
    var incomplete: Workspace = .{};
    defer incomplete.deinit();
    try t.expectError(error.MissingTransactionPayload, Fixture.walk(&owner, wal.log(), &incomplete));
}
