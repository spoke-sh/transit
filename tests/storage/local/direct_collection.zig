//! Physical collection through real local native fences and database roots.
const std = @import("std");
const t = std.testing;
const c = @import("transit_catalog");
const s = c.storage;
const p = c.protocol;
const f = c.fuze;
const core = @import("transit_core");
const local = @import("transit_backend_local");
const Engine = core.growing.Engine(local.Store, local.PageStore);
const Collection = local.DataCollection.Collector(c.DirectStorageGraph);
const P = s.TablePartition;
const columns = [_]f.TableSchema.Column{.{ .id = 1, .name = "id", .type = .int64, .nullable = false }};
const schema: f.TableSchema.Schema = .{ .object = 7, .revision = 1, .next_column = 2, .columns = &columns, .primary_key = &.{1} };
const object: p.DataLifecycle.Object = .{ .scope = .{ .realm = 42, .resource = 2, .catalog = 3 }, .branch = 1, .object = 7 };

const Fixture = struct {
    owner: local.Backend = undefined,
    pages: local.PageStore = undefined,
    journal: local.Store = undefined,
    data: local.DataStore = undefined,
    engine: Engine = undefined,
    table: P = undefined,
    now: u64 = 100,
    denied: bool = false,

    fn keyPair() !p.Ed25519.KeyPair {
        return p.Ed25519.KeyPair.generateDeterministic(@splat(17));
    }
    fn clock(raw: *anyopaque) !core.Time.Sample {
        return .{ .unix_ms = @as(*Fixture, @ptrCast(@alignCast(raw))).now };
    }
    fn logClock(raw: *anyopaque) !?u64 {
        return @as(*Fixture, @ptrCast(@alignCast(raw))).now;
    }
    fn open(self: *Fixture, directory: std.Io.Dir, fresh: bool) !void {
        self.owner = try local.Backend.open(t.allocator, t.io, directory, "native", .{});
        self.pages = try local.PageStore.init(&self.owner, 1);
        self.journal = .{ .backend = &self.owner };
        self.data = .{ .backend = &self.owner };
        const genesis: core.growing.Genesis = .{ .realm = 42, .root_key = (try keyPair()).public_key.toBytes(), .max_clock_error_ms = 5 };
        self.engine = if (fresh) try Engine.bootstrap(&self.journal, &self.pages, genesis) else try Engine.open(&self.journal, &self.pages, genesis);
        self.engine.clock = .{ .context = self, .read = clock };
        self.table = try P.init(t.allocator, 17, .{ .object = object, .revision = 1, .schema = schema, .properties = "" }, self.data.log(), self.data.objects(), .{ .resident_pages = 1 });
        try self.table.recover();
    }
    fn close(self: *Fixture) void {
        self.table.deinit();
        self.pages.deinit();
        self.owner.deinit();
    }
    fn fence(self: *Fixture) !u64 {
        return self.engine.submit(try p.Growth.sign(.{ .realm = 42, .principal = 0, .sequence = (try self.engine.principal(0)).sequence + 1, .command = .{ .storage_fence = {} } }, try keyPair()));
    }
    // This component fixture supplies an explicit trusted guard. Signed policy
    // and revocation at collection boundaries are covered by test-local-catalog.
    fn acquire(raw: *anyopaque) !P.Guard.Fence {
        const self: *Fixture = @ptrCast(@alignCast(raw));
        if (self.denied) return error.PermissionDenied;
        return .{ .writer_epoch = self.engine.head.storage_epoch, .policy_epoch = self.engine.head.authorization.revision + 1 };
    }
    fn release(_: *anyopaque) void {}
    fn guard(self: *Fixture) P.Guard {
        return .{ .context = self, .acquire = acquire, .release = release };
    }
    fn collect(self: *Fixture) !Collection.State {
        var collector: Collection = .{ .backend = &self.owner };
        try collector.start(&self.engine, try self.fence());
        var steps: usize = 0;
        while ((try collector.current()).?.phase != .wait) : (steps += 1) {
            if (steps == 100_000) return error.FixtureBudget;
            try t.expect(try collector.step(&self.engine, .{ .unix_ms = self.now }));
        }
        self.now = (try collector.current()).?.grace_until_ms + 1;
        _ = try self.fence();
        while ((try collector.current()).?.phase != .complete) : (steps += 1) {
            if (steps == 200_000) return error.FixtureBudget;
            try t.expect(try collector.step(&self.engine, .{ .unix_ms = self.now }));
        }
        const state = (try collector.current()).?;
        try t.expect(!state.aborted and state.reclaimed_objects > 0);
        std.debug.print("direct Table collection: {d} steps, {d} allocations reclaimed\n", .{ steps, state.reclaimed_objects });
        return state;
    }
    fn expire(self: *Fixture, through: ?u64) !void {
        const cut: p.DataLifecycle.Position = .{ .partition = 17, .next_lsn = through orelse self.table.root.next_lsn };
        while (!(try self.table.archive(cut, .{}, self.guard())).complete) {}
        _ = try self.table.trimArchived(self.guard());
        _ = try self.table.checkpoint(.{ .partition = 17, .next_lsn = self.table.root.next_lsn }, self.guard());
        _ = try self.table.expireHistory(cut, self.guard());
    }
};

fn binding(table: *P, operation: u64) p.DataLifecycle.Binding {
    return .{ .definition = p.Growth.current_definition, .identity = .{ .scope = object.scope, .principal = 4, .operation = operation }, .target = object, .action = if (table.root.next_lsn == 0) .create else .insert, .expected_definition = if (table.root.next_lsn == 0) null else table.root.interpretation, .expected_data = null, .intent = @splat(7) };
}
fn change(value: *const f.Types.Values.Cell, operation: u64) P.Change {
    return .{ .put = .{ .row = .{ .identity = .{ .origin = 7, .operation = operation, .ordinal = 0 }, .cells = @as(*const [1]f.Types.Values.Cell, @ptrCast(value)) }, .expect = .absent } };
}
fn key(value: i128, buffer: []u8) ![]const u8 {
    return f.Collation.encodePrimaryKeySortKey(schema, &.{.{ .value = .{ .atom = .{ .signed = value } } }}, false, buffer);
}
fn archived(table: *P, lsn: u64) !p.DataLifecycle.Content {
    const tree: s.TreeStore.pages.Tree(s.TreeStore) = .{ .store = &table.index };
    const value = (try tree.get(table.root.archive.directory, try s.TableArchive.key(lsn))).?;
    return s.TableArchive.decodeReference(value);
}
fn segment(table: *P) !p.DataLifecycle.Content {
    var walk = try s.TableStorageWalk.init(try .fromRoot(table.root), .{ .kind = .rows, .reference = table.root.rows.? });
    while (try walk.next(&table.index)) |edge| if (edge == .segment) return edge.segment;
    return error.MissingSegment;
}
fn expectSegment(fixture: *Fixture, content: p.DataLifecycle.Content, present: bool) !void {
    var name: [96]u8 = undefined;
    try t.expectEqual(present, try fixture.owner.objects.objectStore().head(try std.fmt.bufPrint(&name, "table-segments/{x}.tseg", .{&content.sha256})) != null);
}
fn expectArchive(fixture: *Fixture, content: p.DataLifecycle.Content, present: bool) !void {
    var name: [96]u8 = undefined;
    try t.expectEqual(present, try fixture.owner.objects.objectStore().head(try s.TableArchive.objectKey(content.sha256, &name)) != null);
}

fn streamDefinition(compact_key: ?u64) !s.LogDeclaration.Owned {
    return s.LogDeclaration.prepare(t.allocator, .{
        .object = .{ .scope = object.scope, .branch = 1, .object = 8 },
        .revision = 1,
        .schema = .{ .object = 8, .revision = 1, .next_column = 2, .columns = &columns },
        .configuration = .{
            .partitioning = .{ .count = 1, .key_column = null, .hash = .sha256_64 },
            .retention = .{ .max_age_ms = null },
            .policy = .{ .stream = .{ .compact_key_column = compact_key, .timestamp_column = null } },
        },
        .limits = .{ .append_rows = 128, .append_bytes = 8192, .claim_rows = 16, .read_rows = 128, .read_bytes = 8192, .active_leases = 64, .waiters = 64, .timer_steps = 64 },
        .properties = "",
    });
}

test "direct Stream collection preserves pinned cuts and original receipts through native trim and restart" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var fixture: Fixture = .{};
    try fixture.open(tmp.dir, true);
    defer fixture.close();
    var definition = try streamDefinition(null);
    defer definition.deinit();
    const initialized: s.LogInitialization.Request = .{
        .definition = p.Growth.current_definition,
        .declared = try s.LogDeclaration.stage(fixture.data.objects(), &definition),
        .operation = .{ .scope = object.scope, .principal = 0, .operation = 100 },
        .ordinal = 0,
        .partition = 23,
    };
    _ = try s.LogInitialization.initialize(t.allocator, fixture.data.log(), fixture.data.objects(), initialized, fixture.guard());
    const stream_options: s.StreamPartition.Options = .{ .resident_pages = 1, .clock = .{ .context = &fixture, .read = Fixture.logClock } };
    var stream = try s.StreamPartition.open(t.allocator, fixture.data.log(), fixture.data.objects(), initialized, fixture.guard(), stream_options);
    defer stream.deinit() catch unreachable;
    try t.expect((try stream.recoverStep(fixture.guard(), 1)).complete);
    const op: p.DataLifecycle.Operation = .{ .scope = object.scope, .principal = 0, .operation = 101 };
    const cell: f.Types.Values.Cell = .{ .value = .{ .atom = .{ .signed = 42 } } };
    var buffer: [8192]u8 = undefined;
    const payload = try s.LogBatch.encode(definition.definition.schema, op, .stream, &.{.{ .cells = &.{cell} }}, &buffer);
    const request: p.StreamQueue.Append = .{ .target = initialized.target(), .operation = op, .kind = .stream, .producer = null, .rows = 1, .payload = s.LogBatch.content(payload) };
    const accepted = try stream.append(initialized.declared, request, payload, fixture.guard());
    const read = try stream.beginRead(initialized.declared, .{ .target = initialized.target(), .operation = .{ .scope = object.scope, .principal = 0, .operation = 102 }, .group = null, .from = 0, .until = null, .timestamp = null }, fixture.guard());
    const authority = try s.LogRead.Authority.init(@splat(7));
    const cursor = try stream.readCursor(read.handle(), authority, fixture.guard());
    try t.expect((try stream.flush(stream.root.position(), fixture.guard())).complete);
    const tree: s.TreeStore.pages.Tree(s.TreeStore) = .{ .store = &stream.store };
    const segment_reference = try s.LogSegment.Descriptor.decode((try tree.get(stream.root.segments, try s.LogPartitionRecord.integerKey(1))).?);
    const cut = stream.root.position();
    while (!(try stream.archive(cut, .{ .frames = 1 }, fixture.guard())).complete) {}
    const checkpoint = try stream.checkpoint(cut, fixture.guard());
    const payload_archive = try s.TableArchive.decodeReference((try tree.get(stream.root.archive.directory, try s.TableArchive.key(accepted.accepted.next_lsn - 1))).?);
    try t.expectEqual(cut.next_lsn, try stream.trimArchived(fixture.guard()));
    try t.expectError(error.WalHistoryTrimmed, fixture.data.log().read(t.allocator, 23, 0, 1));
    // A post-checkpoint archive transition needs its copied frames during replay,
    // independently of whether any payload locator refers to those controls.
    const replay_cut = stream.root.position();
    while (!(try stream.archive(replay_cut, .{ .frames = 1 }, fixture.guard())).complete) {}
    const orphan = try s.LogRead.stage(fixture.data.objects(), .{
        .request = .{ .target = initialized.target(), .operation = .{ .scope = object.scope, .principal = 0, .operation = 999 }, .group = null, .from = 0, .until = null, .timestamp = null },
        .declared = initialized.declared,
        .cut = try stream.observe(initialized.declared, fixture.guard()),
        .until = 1,
        .batches = stream.root.batches,
        .segments = stream.root.segments,
        .hidden = stream.root.hidden,
    });
    const orphan_checkpoint = try s.LogRecovery.stage(fixture.data.objects(), .{ .root = stream.root, .commitment = stream.commitment });
    _ = try fixture.collect();
    var name: [96]u8 = undefined;
    try t.expect(try fixture.data.objects().head(try s.LogRead.key(orphan.source, &name)) == null);
    try t.expect(try fixture.data.objects().head(try s.LogRecovery.key(orphan_checkpoint.content, &name)) == null);
    try t.expect(try fixture.data.objects().head(try s.LogRead.key(read.source, &name)) != null);
    try t.expect(try fixture.data.objects().head(try s.LogRecovery.key(checkpoint.content, &name)) != null);
    try expectArchive(&fixture, payload_archive, true);
    try t.expect(try fixture.data.objects().head(try s.LogSegment.segmentKey(segment_reference.segment, &name)) != null);
    try stream.deinit();
    fixture.close();
    try fixture.open(tmp.dir, false);
    stream = try s.StreamPartition.open(t.allocator, fixture.data.log(), fixture.data.objects(), initialized, fixture.guard(), stream_options);
    while (!(try stream.recoverStep(fixture.guard(), 1)).complete) {}
    var page = try stream.readPage(cursor, authority, .{ .rows = 1, .encoded_bytes = 8192 }, t.allocator, fixture.guard());
    defer page.deinit();
    try t.expectEqual(@as(u32, 1), page.count);
    try t.expect(page.cursor.coverage.complete);
    try t.expectEqualDeep(accepted, try stream.append(initialized.declared, request, payload, fixture.guard()));
    _ = try stream.releaseRead(initialized.declared, .{ .target = initialized.target(), .operation = .{ .scope = object.scope, .principal = 0, .operation = 103 }, .read = read.handle() }, fixture.guard());
    _ = try fixture.collect();
    try t.expect(try fixture.data.objects().head(try s.LogRead.key(read.source, &name)) != null);
    try stream.deinit();
    stream = try s.StreamPartition.open(t.allocator, fixture.data.log(), fixture.data.objects(), initialized, fixture.guard(), stream_options);
    while (!(try stream.recoverStep(fixture.guard(), 1)).complete) {}
    try t.expectError(error.StreamReadReleased, stream.readCursor(read.handle(), authority, fixture.guard()));
    _ = try stream.checkpoint(stream.root.position(), fixture.guard());
    _ = try fixture.collect();
    try t.expect(try fixture.data.objects().head(try s.LogRead.key(read.source, &name)) == null);
    try t.expect(try fixture.data.objects().head(try s.LogRecovery.key(checkpoint.content, &name)) == null);
    try expectArchive(&fixture, payload_archive, false);
    try t.expect(try fixture.data.objects().head(try s.LogSegment.segmentKey(segment_reference.segment, &name)) != null);
    try t.expect(try fixture.data.objects().head(try s.LogSegment.metadataKey(segment_reference.metadata, &name)) != null);
    try t.expectEqualDeep(read, (try stream.operation(read.request.operation, fixture.guard())).?.outcome.read);
    try t.expectError(error.StreamReadReleased, stream.readCursor(read.handle(), authority, fixture.guard()));
    try stream.deinit();
    fixture.close();
    try fixture.open(tmp.dir, false);
    stream = try s.StreamPartition.open(t.allocator, fixture.data.log(), fixture.data.objects(), initialized, fixture.guard(), stream_options);
    try t.expect((try stream.recoverStep(fixture.guard(), 1)).complete);
    try t.expectEqualDeep(accepted, (try stream.operation(op, fixture.guard())).?.outcome.append);
    try t.expectError(error.StreamReadReleased, stream.readCursor(read.handle(), authority, fixture.guard()));

    // Explicit policy opt-in may expire the timed prefix. Only a later accepted
    // recovery baseline closes its replay dependencies for physical collection.
    var revised = definition.definition;
    revised.revision = 2;
    revised.configuration.retention.max_age_ms = 100;
    var revised_definition = try s.LogDeclaration.prepare(t.allocator, revised);
    defer revised_definition.deinit();
    const revised_stored = try s.LogDeclaration.stage(fixture.data.objects(), &revised_definition);
    const expired = try stream.expireHistory(revised_stored, stream.root.position(), fixture.guard());
    try t.expectEqual(s.StreamPartition.ExpirationStatus.complete, expired.status);
    try t.expectEqual(@as(u64, 1), expired.retained_from);
    _ = try stream.checkpoint(stream.root.position(), fixture.guard());
    _ = try fixture.collect();
    try t.expect(try fixture.data.objects().head(try s.LogSegment.segmentKey(segment_reference.segment, &name)) == null);
    try t.expect(try fixture.data.objects().head(try s.LogSegment.metadataKey(segment_reference.metadata, &name)) == null);
    try stream.deinit();
    fixture.close();
    try fixture.open(tmp.dir, false);
    stream = try s.StreamPartition.open(t.allocator, fixture.data.log(), fixture.data.objects(), initialized, fixture.guard(), stream_options);
    try t.expect((try stream.recoverStep(fixture.guard(), 1)).complete);
    const expired_cut = try stream.observe(revised_stored, fixture.guard());
    try t.expectEqual(@as(u64, 1), expired_cut.retained_from);
    try t.expectEqual(@as(u64, 1), expired_cut.next);
    try t.expectEqualDeep(accepted, try stream.append(revised_stored, request, payload, fixture.guard()));
    try t.expectError(error.LogHistoryUnavailable, stream.beginRead(revised_stored, .{ .target = .{ .definition = p.Growth.current_definition, .interpretation = revised_stored.declaration.interpretation, .partition = 0 }, .operation = .{ .scope = object.scope, .principal = 0, .operation = 104 }, .group = null, .from = 0, .until = null, .timestamp = null }, fixture.guard()));
}

test "direct Stream collection retains pending compaction and pinned visibility after checkpoint" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var fixture: Fixture = .{};
    try fixture.open(tmp.dir, true);
    defer fixture.close();
    var definition = try streamDefinition(1);
    defer definition.deinit();
    const initial: s.LogInitialization.Request = .{
        .definition = p.Growth.current_definition,
        .declared = try s.LogDeclaration.stage(fixture.data.objects(), &definition),
        .operation = .{ .scope = object.scope, .principal = 0, .operation = 100 },
        .ordinal = 0,
        .partition = 23,
    };
    _ = try s.LogInitialization.initialize(t.allocator, fixture.data.log(), fixture.data.objects(), initial, fixture.guard());
    var stream = try s.StreamPartition.open(t.allocator, fixture.data.log(), fixture.data.objects(), initial, fixture.guard(), .{ .resident_pages = 1 });
    defer stream.deinit() catch unreachable;
    _ = try stream.recoverStep(fixture.guard(), 1);
    const op: p.DataLifecycle.Operation = .{ .scope = object.scope, .principal = 0, .operation = 101 };
    const cell: f.Types.Values.Cell = .{ .value = .{ .atom = .{ .signed = 42 } } };
    var buffer: [8192]u8 = undefined;
    const payload = try s.LogBatch.encode(definition.definition.schema, op, .stream, &.{ .{ .cells = &.{cell} }, .{ .cells = &.{cell} }, .{ .cells = &.{cell} } }, &buffer);
    const request: p.StreamQueue.Append = .{ .target = initial.target(), .operation = op, .kind = .stream, .producer = null, .rows = 3, .payload = s.LogBatch.content(payload) };
    const receipt = try stream.append(initial.declared, request, payload, fixture.guard());
    const before = try stream.beginRead(initial.declared, .{ .target = initial.target(), .operation = .{ .scope = object.scope, .principal = 0, .operation = 102 }, .group = null, .from = 0, .until = null, .timestamp = null }, fixture.guard());
    _ = try stream.flush(stream.root.position(), fixture.guard());
    const cut = stream.root.position();
    _ = try stream.compactStep(initial.declared, cut, 1, fixture.guard());
    while (stream.root.compaction.?.phase != .mark or stream.root.compaction.?.next == 0) _ = try stream.compactStep(initial.declared, cut, 1, fixture.guard());
    const work = stream.root.compaction.?;
    try t.expectEqual(@as(u64, 1), work.candidate.cardinality);
    var directory: s.BitmapDirectory = .{ .store = &stream.store, .objects = fixture.data.objects() };
    const mask = (try directory.reference(work.candidate, 0)).?;
    _ = try stream.checkpoint(stream.root.position(), fixture.guard());
    _ = try fixture.collect();
    var name: [96]u8 = undefined;
    try t.expect(try fixture.data.objects().head(try s.BitmapDirectory.objectKey(mask, &name)) != null);
    try stream.deinit();
    fixture.close();
    try fixture.open(tmp.dir, false);
    stream = try s.StreamPartition.open(t.allocator, fixture.data.log(), fixture.data.objects(), initial, fixture.guard(), .{ .resident_pages = 1 });
    while (!(try stream.recoverStep(fixture.guard(), 1)).complete) {}
    while ((try stream.compactStep(initial.declared, cut, 1, fixture.guard())).status != .complete) {}
    const after = try stream.beginRead(initial.declared, .{ .target = initial.target(), .operation = .{ .scope = object.scope, .principal = 0, .operation = 103 }, .group = null, .from = 0, .until = null, .timestamp = null }, fixture.guard());
    const authority = try s.LogRead.Authority.init(@splat(7));
    _ = try stream.checkpoint(stream.root.position(), fixture.guard());
    _ = try fixture.collect();
    try t.expect(try fixture.data.objects().head(try s.BitmapDirectory.objectKey(mask, &name)) == null);
    try stream.deinit();
    fixture.close();
    try fixture.open(tmp.dir, false);
    stream = try s.StreamPartition.open(t.allocator, fixture.data.log(), fixture.data.objects(), initial, fixture.guard(), .{ .resident_pages = 1 });
    while (!(try stream.recoverStep(fixture.guard(), 1)).complete) {}
    var original = try stream.readPage(try stream.readCursor(before.handle(), authority, fixture.guard()), authority, .{ .rows = 3, .encoded_bytes = 8192 }, t.allocator, fixture.guard());
    defer original.deinit();
    var compacted = try stream.readPage(try stream.readCursor(after.handle(), authority, fixture.guard()), authority, .{ .rows = 3, .encoded_bytes = 8192 }, t.allocator, fixture.guard());
    defer compacted.deinit();
    try t.expect(original.count == 3 and original.cursor.coverage.complete);
    try t.expect(compacted.count == 1 and compacted.rows()[0].offset == 2 and compacted.cursor.coverage.complete and compacted.cursor.coverage.through == 3);
    try t.expectEqualDeep(receipt, (try stream.operation(op, fixture.guard())).?.outcome.append);
}

test "direct Table collection expires old graph while preserving pins, pending work and original receipts" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var fixture: Fixture = .{};
    try fixture.open(tmp.dir, true);
    defer fixture.close();
    const one: f.Types.Values.Cell = .{ .value = .{ .atom = .{ .signed = 1 } } };
    const two: f.Types.Values.Cell = .{ .value = .{ .atom = .{ .signed = 2 } } };
    const three: f.Types.Values.Cell = .{ .value = .{ .atom = .{ .signed = 3 } } };
    const original = binding(&fixture.table, 1);
    const outcome = try fixture.table.apply(original, &.{change(&one, 1)}, .point, fixture.guard());
    const wal_pin = try fixture.table.pin(.{ .scope = object.scope, .principal = 4, .operation = 100 }, .{ .partition = 17, .next_lsn = fixture.table.root.next_lsn }, fixture.guard());
    _ = try fixture.table.flush(fixture.guard());
    const pinned_segment = try segment(&fixture.table);
    const segment_pin = try fixture.table.pin(.{ .scope = object.scope, .principal = 4, .operation = 101 }, .{ .partition = 17, .next_lsn = fixture.table.root.next_lsn }, fixture.guard());
    _ = try fixture.table.apply(binding(&fixture.table, 2), &.{change(&two, 2)}, .bulk, fixture.guard());
    var first_key: [4096]u8 = undefined;
    var deletion = binding(&fixture.table, 3);
    deletion.action = .delete;
    _ = try fixture.table.apply(deletion, &.{.{ .remove = try key(1, &first_key) }}, .point, fixture.guard());
    _ = try fixture.table.compact(fixture.table.root.next_segment, .{}, fixture.guard());
    const pending = binding(&fixture.table, 4);
    var pending_change = change(&three, 4);
    pending_change.put.row.identity = try s.TableDmlIntent.insertIdentity(pending.identity, 0);
    _ = try fixture.table.admit(.{ .binding = pending, .interpretation = fixture.table.root.declared(), .changes = &.{pending_change}, .ingestion = .point }, fixture.guard());
    const history_frontier = fixture.table.root.next_lsn;
    const history_pin = try fixture.table.retainHistory(.{ .scope = object.scope, .principal = 4, .operation = 102 }, .{ .partition = 17, .next_lsn = history_frontier }, fixture.guard());
    try fixture.expire(history_frontier);
    const pinned_frame = try archived(&fixture.table, 0);
    const history_anchor = try archived(&fixture.table, history_frontier - 1);
    const deletion_position = (try fixture.table.observe(deletion, fixture.guard())).?.position;
    const obsolete_frame = try archived(&fixture.table, deletion_position.next_lsn - 1);
    _ = try fixture.collect();
    try expectArchive(&fixture, pinned_frame, true);
    try expectArchive(&fixture, history_anchor, true);
    try expectArchive(&fixture, obsolete_frame, false);
    try expectSegment(&fixture, pinned_segment, true);
    fixture.close();
    try fixture.open(tmp.dir, false);
    for ([_]P.SnapshotHandle{ wal_pin, segment_pin }) |pin| {
        var row = (try fixture.table.readSnapshot(t.allocator, pin, try key(1, &first_key), fixture.guard())).?;
        defer row.deinit();
        try t.expectEqual(@as(i128, 1), row.row().cells[0].value.atom.signed);
    }
    try t.expectEqualDeep(outcome, (try fixture.table.observe(original, fixture.guard())).?);
    try t.expect((try fixture.table.operationState(pending, fixture.guard())) == .admitted);
    fixture.denied = true;
    try t.expectError(error.PermissionDenied, fixture.table.readSnapshot(t.allocator, wal_pin, try key(1, &first_key), fixture.guard()));
    try t.expectError(error.PermissionDenied, fixture.table.observe(original, fixture.guard()));
    fixture.denied = false;
    try fixture.table.releaseSnapshot(wal_pin, fixture.guard());
    try fixture.table.releaseSnapshot(segment_pin, fixture.guard());
    try fixture.table.releaseSnapshot(history_pin, fixture.guard());
    try fixture.expire(null);
    _ = try fixture.collect();
    try expectArchive(&fixture, pinned_frame, false);
    try expectArchive(&fixture, history_anchor, false);
    try expectSegment(&fixture, pinned_segment, false);
    fixture.close();
    try fixture.open(tmp.dir, false);
    try t.expectEqualDeep(outcome, try fixture.table.apply(original, &.{change(&one, 1)}, .point, fixture.guard()));
    const performed = (try fixture.table.perform(pending, fixture.guard())).committed;
    try t.expectEqual(@as(u64, 1), performed.outcome.affected);
    try t.expectEqual(@as(u64, 2), performed.outcome.live_rows);
    var second_key: [4096]u8 = undefined;
    var row = (try fixture.table.get(t.allocator, try key(2, &second_key), fixture.guard())).?;
    defer row.deinit();
    try t.expectEqual(@as(i128, 2), row.row().cells[0].value.atom.signed);
    try t.expect(try fixture.table.get(t.allocator, try key(1, &first_key), fixture.guard()) == null);
}
