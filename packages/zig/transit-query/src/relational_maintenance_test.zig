const std = @import("std");
const t = std.testing;
const q = @import("root.zig");
const f = q.fuze;
const s = q.station;
const r = q.RelationalMaintenanceRecords;
const owner = q.RelationalMaintenance;
const tables = @import("catalog_store_test.zig");
const Store = q.testing.Store;
const budgets: f.Relational.Budgets = .{ .resident_bytes = owner.resident_base + 8 * 1024 * 1024, .spill_bytes = 32 * 1024 * 1024, .result_bytes = 1024 * 1024, .output_rows = 1000, .work_steps = 10000, .source_pins = 1 };
fn integer(value: i64) f.Types.Values.Cell {
    return .{ .value = .{ .atom = .{ .signed = value } } };
}
fn admit(store: *Store, bundle: q.RelationalBundle, workspace: []u8) !r.Head {
    return admitPhysical(store, bundle, workspace, false);
}
fn admitPhysical(store: *Store, bundle: q.RelationalBundle, workspace: []u8, exchanged: bool) !r.Head {
    var turn = try tables.turn(store);
    const old = try q.RelationalCapture.policy(&turn, 3);
    try q.RelationalCapture.setPolicy(&turn, .{ .peer = 3, .requests = store.resource, .principal = 17, .revision = if (old) |value| value.revision + 1 else 1, .request = try bundle.fingerprint(), .allow = true });
    try store.commit(turn);
    const reference = try bundle.reference(store.resource, store.input);
    var bytes: [q.RelationalBundle.max_bytes]u8 = undefined;
    const body = try bundle.encode(&bytes);
    var ready = false;
    for (0..1000) |_| {
        turn = try tables.turn(store);
        ready = try s.PublicationUpload.step(&turn, .{ .domain = .query_request, .namespace = reference.namespace, .identity_key = q.RelationalRecords.key('u', reference.namespace, 0), .identity = try reference.encode(), .limits = .{ .record_bytes = q.RelationalBundle.max_bytes, .staging_bytes = q.RelationalBundle.max_bytes, .staging_records = 1 }, .records = &.{.{ .id = 1, .spec = reference.spec, .bytes = body }} });
        try store.commit(turn);
        if (ready) break;
    }
    try t.expect(ready);
    if (exchanged) {
        turn = try tables.turn(store);
        try owner.selectExchanges(&turn, .{ .peer = 3, .correlation = reference.namespace }, reference);
        try store.commit(turn);
    }
    turn = try tables.turn(store);
    turn.delivery.input.origin = .{ .process = .{ .pid = 3, .turn = 1, .output = 0 } };
    turn.delivery.input.value = try (s.Frame{ .kind = .call, .correlation = reference.namespace, .payload = try reference.encode() }).encode();
    const stored = try owner.start(&turn, reference, workspace);
    var replied = false;
    for (turn.decision.outputs) |slot| if (slot) |output| {
        const frame = try s.Frame.decode(output.value);
        if (frame.kind == .reply) {
            try t.expect(!replied);
            try t.expectEqual(reference.namespace, frame.correlation);
            try t.expectEqualDeep(stored, try r.Head.decode(frame.payload));
            replied = true;
        }
    };
    try t.expect(replied);
    try store.commit(turn);
    return stored;
}
fn continuation(store: *Store, stored: r.Head) !s.Turn {
    var turn = try tables.turn(store);
    turn.delivery.input.origin = .{ .process = .{ .pid = 3, .turn = 1, .output = 0 } };
    turn.delivery.input.value = try (s.Frame{ .kind = .cast, .payload = try (r.Continuation{ .identity = stored.identity(), .input = stored.continuation }).encode() }).encode();
    return turn;
}
fn finish(store: *Store, bundle: q.RelationalBundle, identity: r.Identity, workspace: []u8) !r.Head {
    for (0..20000) |index| {
        var turn = try tables.turn(store);
        const old = try owner.head(&turn, identity);
        if (old.phase == .idle or old.phase == .failed) return old;
        const message: r.Continuation = .{ .identity = identity, .input = old.continuation };
        turn = try continuation(store, old);
        const result = try owner.advance(&turn, message, workspace);
        try turn.validate();
        // Losing the uncommitted proposal and rebuilding the host must produce
        // exactly the same decision, including every private staging write.
        if (index % 7 == 0) {
            var retry = try continuation(store, old);
            try t.expectEqual(result, try owner.advance(&retry, message, workspace));
            try t.expectEqualDeep(turn.decision, retry.decision);
        }
        try store.commit(turn);
        turn = try tables.turn(store);
        const current = try owner.head(&turn, identity);
        if (result != .complete) {
            try t.expectEqual(old.revision, current.revision);
            try t.expectEqual(old.manifest, current.manifest);
        }
        if (current.revision != 0) _ = (try owner.manifest(&turn, bundle, current)).?;
        // A stale accepted continuation never allocates another revision.
        if (index % 13 == 0) {
            turn = try continuation(store, old);
            try t.expectEqual(.duplicate, try owner.advance(&turn, message, workspace));
            for (turn.decision.mutations) |entry| try t.expect(entry == null);
        }
    }
    return error.MaintenanceDidNotFinish;
}
fn readResult(store: *Store, bundle: q.RelationalBundle, stored: r.Head) !struct { manifest: r.Manifest, output: f.RelationalOutput } {
    var turn = try tables.turn(store);
    const saved = (try owner.manifest(&turn, bundle, stored)).?;
    var cuts: [f.Relational.max_sources]f.Relational.Cut = undefined;
    try saved.vector.boundCuts(bundle, &cuts);
    const bound: f.Relational.Bound = .{ .plan = bundle.plan, .cuts = cuts[0..bundle.sources.len] };
    const output = try q.RelationalRecords.Output.decode((try turn.read(r.key('o', stored.id, stored.revision, 0))).?);
    var bytes: [f.RelationalOutput.max_bytes]u8 = undefined;
    return .{ .manifest = saved, .output = try f.RelationalOutput.decode(bound, try owner.readBody(output.reference, &turn, &bytes)) };
}
test "maintained revisions restart every bounded step and preserve last result after ordered overflow" {
    var store: Store = .{};
    defer store.deinit();
    try tables.create(&store, "CREATE TABLE items (k BIGINT, v BIGINT)");
    try tables.mutate(&store, 2, .{ .insert = &.{&.{ integer(1), integer(10) }} });
    var definition = try tables.definition(&store);
    defer definition.deinit();
    var source = try tables.source(&store);
    defer source.deinit();
    const declarations = [_]f.Relational.Source{.{ .alias = "i", .realm = 1, .resource = 7, .catalog = 9, .owner = 3, .schema = definition.schema.schema }};
    const sources = [_]q.TableSource{source.source};
    const bundle: q.RelationalBundle = .{ .sources = &sources, .plan = .{ .sources = &declarations, .outputs = &.{ .{ .name = "n", .expression = .count_all }, .{ .name = "v", .expression = .{ .sum = .{ .source = 0, .id = 2 } } } }, .lifetime = .maintained, .budgets = budgets } };
    const workspace = try t.allocator.alloc(u8, 4 * 1024 * 1024);
    defer t.allocator.free(workspace);
    const admitted = try admit(&store, bundle, workspace);
    // The activation's exact request remains available after its publisher
    // retires the live artifact; continuations never reopen or reinterpret it.
    var retired_request = try tables.turn(&store);
    _ = try admitted.request.publication().retire(&retired_request, admitted.request.record);
    try store.commit(retired_request);
    // Live input advances during a delayed backfill. The first publication is
    // still exactly the original result and later transactions remain pending.
    try tables.mutate(&store, 3, .{ .insert = &.{&.{ integer(2), integer(20) }} });
    var stored = try finish(&store, bundle, admitted.identity(), workspace);
    var first = try readResult(&store, bundle, stored);
    try t.expectEqual(@as(u64, 1), stored.revision);
    try t.expectEqual(@as(u128, 1), first.output.row.cells[0].value.atom.unsigned);
    try t.expectEqual(@as(i128, 10), first.output.row.cells[1].value.atom.signed);
    try t.expectEqual(@as(u64, 1), first.manifest.work.deltas);
    var changed: usize = 0;
    var noops: usize = 0;
    for (0..10) |_| {
        var turn = try tables.turn(&store);
        const wake = try owner.wake(&turn, admitted.identity(), workspace);
        if (wake == .idle) break;
        try t.expectEqual(.progress, wake);
        try store.commit(turn);
        const old = stored;
        const previous = first;
        stored = try finish(&store, bundle, admitted.identity(), workspace);
        first = try readResult(&store, bundle, stored);
        try t.expectEqual(old.revision + 1, stored.revision);
        try t.expectEqual(previous.manifest.vector.entries[0].record.head.revision + 1, first.manifest.vector.entries[0].record.head.revision);
        try t.expectEqual(old.manifest, first.manifest.previous.?.record);
        if (first.manifest.work.deltas == 0) {
            noops += 1;
            try t.expect(f.RelationalDelta.sameValues(previous.output.row, first.output.row));
        } else {
            changed += 1;
            try t.expectEqual(@as(u64, 1), first.manifest.work.deltas);
            var old_cuts: [f.Relational.max_sources]f.Relational.Cut = undefined;
            var next_cuts: [f.Relational.max_sources]f.Relational.Cut = undefined;
            try previous.manifest.vector.boundCuts(bundle, &old_cuts);
            try first.manifest.vector.boundCuts(bundle, &next_cuts);
            turn = try tables.turn(&store);
            const record = try r.Delta.decode((try turn.read(r.key('d', stored.id, stored.revision, 0))).?);
            var bytes: [f.RelationalDelta.max_bytes]u8 = undefined;
            const delta = try f.RelationalDelta.decode(.{ .plan = bundle.plan, .cuts = old_cuts[0..1] }, .{ .plan = bundle.plan, .cuts = next_cuts[0..1] }, try owner.readBody(record.reference, &turn, &bytes));
            try t.expectEqualDeep(previous.output, delta.before.?);
            try t.expectEqualDeep(first.output, delta.after.?);
            try t.expectEqualSlices(u8, &try record.extend(r.initialDeltaChain()), &first.manifest.work.delta_chain);
        }
    }
    try t.expectEqual(@as(usize, 1), changed);
    try t.expect(noops > 0);
    try t.expectEqual(@as(u128, 2), first.output.row.cells[0].value.atom.unsigned);
    try t.expectEqual(@as(i128, 30), first.output.row.cells[1].value.atom.signed);
    try tables.mutate(&store, 4, .{ .insert = &.{ &.{ integer(3), integer(std.math.maxInt(i64)) }, &.{ integer(4), integer(-std.math.maxInt(i64)) } } });
    for (0..10) |_| {
        var turn = try tables.turn(&store);
        try t.expectEqual(.progress, try owner.wake(&turn, admitted.identity(), workspace));
        try store.commit(turn);
        const old = stored;
        stored = try finish(&store, bundle, admitted.identity(), workspace);
        if (stored.phase == .failed) {
            try t.expectEqual(old.revision, stored.revision);
            try t.expectEqual(old.manifest, stored.manifest);
            break;
        }
    }
    try t.expectEqual(.failed, stored.phase);
    try t.expect(!stored.released);
    const last = try readResult(&store, bundle, stored);
    try t.expectEqual(@as(i128, 30), last.output.row.cells[1].value.atom.signed);
    var turn = try tables.turn(&store);
    const failure = try q.RelationalRecords.Failure.decode((try turn.read(r.key('f', stored.id, stored.revision + 1, 0))).?);
    try t.expectEqualStrings("Overflow", failure.cause.slice());
    const failed_work = try r.Work.decode((try turn.read(r.key('w', stored.id, stored.revision + 1, 0))).?);
    try t.expectEqual(.failed, failed_work.phase);
    var failed_vector: q.RelationalHistory.Vector = .{ .request = try bundle.fingerprint(), .count = stored.count };
    for (failed_vector.entries[0..stored.count], 0..) |*entry, index| entry.* = .{ .position = stored.positions[index], .record = try s.TableHistory.Record.decode((try turn.read(r.key('b', stored.id, stored.revision + 1, index))).?) };
    var failed_cuts: [f.Relational.max_sources]f.Relational.Cut = undefined;
    try failed_vector.boundCuts(bundle, &failed_cuts);
    const pages: q.RelationalState = .{ .publication = stored.publication(store.resource) };
    const checkpoint = try pages.checkpoint(&turn, failed_work.checkpoint, .{ .plan = bundle.plan, .cuts = failed_cuts[0..stored.count] });
    try t.expectEqual(.failed, checkpoint.phase);
    try t.expectEqual(@as(u64, 4), checkpoint.failure.?.pair.left.operation);
    try t.expectEqual(@as(u32, 0), checkpoint.failure.?.pair.left.ordinal);
    try t.expectEqual(@as(u8, 1), checkpoint.failure.?.output);
    _ = try turn.openVersion(stored.request_version);
    try owner.close(&turn, admitted.identity(), .retired, null);
    try store.commit(turn);
    turn = try tables.turn(&store);
    try t.expectError(error.InvalidReadVersion, turn.openVersion(stored.request_version));
}

test "a retained history gap fails the successor and restoration cannot silently resume it" {
    var store: Store = .{};
    defer store.deinit();
    try tables.create(&store, "CREATE TABLE items (k BIGINT, v BIGINT)");
    try tables.mutate(&store, 2, .{ .insert = &.{&.{ integer(1), integer(10) }} });
    var definition = try tables.definition(&store);
    defer definition.deinit();
    var source = try tables.source(&store);
    defer source.deinit();
    const declarations = [_]f.Relational.Source{.{ .alias = "i", .realm = 1, .resource = 7, .catalog = 9, .owner = 3, .schema = definition.schema.schema }};
    const sources = [_]q.TableSource{source.source};
    const bundle: q.RelationalBundle = .{ .sources = &sources, .plan = .{ .sources = &declarations, .outputs = &.{.{ .name = "n", .expression = .count_all }}, .lifetime = .maintained, .budgets = budgets } };
    const workspace = try t.allocator.alloc(u8, 4 * 1024 * 1024);
    defer t.allocator.free(workspace);
    const admitted = try admit(&store, bundle, workspace);
    const complete = try finish(&store, bundle, admitted.identity(), workspace);
    const original = try readResult(&store, bundle, complete);
    try tables.mutate(&store, 3, .{ .insert = &.{&.{ integer(2), integer(20) }} });
    // This reference-store corruption fixture removes required accepted history;
    // normal retention never performs this deletion. Preserve it for restoration.
    const address = s.TableHistory.key(100, original.manifest.vector.entries[0].record.head.revision);
    const history = store.state.get(address).?;
    try t.expect(store.state.remove(address));
    var turn = try tables.turn(&store);
    try t.expectEqual(.closed, try owner.wake(&turn, admitted.identity(), workspace));
    const failed_proposal = turn.decision;
    turn = try tables.turn(&store);
    try t.expectEqual(.closed, try owner.wake(&turn, admitted.identity(), workspace));
    try t.expectEqualDeep(failed_proposal, turn.decision);
    try store.commit(turn);
    turn = try tables.turn(&store);
    const failed = try owner.head(&turn, admitted.identity());
    try t.expectEqual(.failed, failed.phase);
    try t.expectEqual(complete.revision, failed.revision);
    try t.expectEqual(complete.manifest, failed.manifest);
    const failure = try q.RelationalRecords.Failure.decode((try turn.read(r.key('f', failed.id, try failed.successor(), 0))).?);
    try t.expectEqualStrings("TableHistoryGap", failure.cause.slice());
    try store.state.put(t.allocator, address, history);
    turn = try tables.turn(&store);
    try t.expectEqual(.duplicate, try owner.wake(&turn, admitted.identity(), workspace));
    for (turn.decision.mutations) |entry| try t.expect(entry == null);
    try t.expectEqualDeep(original, try readResult(&store, bundle, failed));
    try owner.close(&turn, admitted.identity(), .retired, null);
    try store.commit(turn);
    // Rebuild is a separately accepted identity with its own complete basis.
    const rebuilt = try admit(&store, bundle, workspace);
    try t.expect(rebuilt.id != admitted.id);
    const result = try readResult(&store, bundle, try finish(&store, bundle, rebuilt.identity(), workspace));
    try t.expectEqual(@as(u128, 2), result.output.row.cells[0].value.atom.unsigned);
}

test "maintained exchange attachment waits for exact complete coverage and every successor" {
    const Fixture = @import("relational_exchange_test.zig").Fixture;
    const codec = f.RelationalExchange;
    for ([_]u64{ 1, 7 }) |partitions| {
        var fixture: Fixture = .{};
        defer fixture.deinit();
        const store = &fixture.receiver;
        try tables.create(store, "CREATE TABLE items (k BIGINT, v BIGINT)");
        try tables.mutate(store, 2, .{ .insert = &.{ &.{ integer(1), integer(10) }, &.{ integer(1), integer(20) }, &.{ integer(2), integer(30) } } });
        var definition = try tables.definition(store);
        defer definition.deinit();
        var source = try tables.source(store);
        defer source.deinit();
        const declarations = [_]f.Relational.Source{.{ .alias = "i", .realm = 1, .resource = 7, .catalog = 9, .owner = 3, .schema = definition.schema.schema }};
        const sources = [_]q.TableSource{source.source};
        const bundle: q.RelationalBundle = .{ .sources = &sources, .plan = .{ .sources = &declarations, .outputs = &.{ .{ .name = "n", .expression = .count_all }, .{ .name = "v", .expression = .{ .sum = .{ .source = 0, .id = 2 } } } }, .lifetime = .maintained, .budgets = budgets } };
        const workspace = try t.allocator.alloc(u8, 4 * 1024 * 1024);
        defer t.allocator.free(workspace);
        const admitted = try admitPhysical(store, bundle, workspace, true);
        var turn = try continuation(store, admitted);
        try t.expectEqual(.idle, try owner.advance(&turn, .{ .identity = admitted.identity(), .input = admitted.continuation }, workspace));
        for (turn.decision.mutations) |slot| try t.expect(slot == null);
        var arena: std.heap.ArenaAllocator = .init(t.allocator);
        defer arena.deinit();
        var history = try q.RelationalHistory.open(&turn, arena.allocator(), bundle, 17, try owner.readBasis(&turn, bundle, admitted), 4);
        const bound = history.bound();
        var rows: [3]f.RelationalExecution.Row = undefined;
        var after: ?f.Relational.RowIdentity = null;
        for (&rows) |*row| {
            row.* = (try history.next(0, after)).?;
            after = row.identity;
        }
        try t.expect(try history.next(0, after) == null);
        // Backfill still uses the frozen basis after the live Table changes.
        try tables.mutate(store, 3, .{ .insert = &.{&.{ integer(3), integer(40) }} });
        try fixture.setup(bound, 88, partitions, 1, budgets.spill_bytes);
        turn = try tables.turn(store);
        try t.expectError(error.RelationalExchangePending, owner.attachExchange(&turn, admitted.identity(), 88, workspace));
        for (turn.decision.mutations) |slot| try t.expect(slot == null);
        var record: u64 = 1;
        for (0..partitions) |i| {
            const partition = partitions - i - 1;
            var segment: codec.Segment = .{ .exchange = 88, .source = 0, .partitions = partitions, .partition = partition, .epoch = 3, .sequence = 0, .terminal = true };
            for (rows) |row| {
                if (try codec.route(bundle.plan, 0, partitions, row) != partition) continue;
                segment.rows[segment.len] = row;
                segment.len += 1;
            }
            const notice = try fixture.offer(bound, segment, record);
            record += 1;
            try fixture.accept(bound, 88, notice);
            try fixture.consume(bound, 88, 0, partition);
        }
        turn = try tables.turn(store);
        try owner.attachExchange(&turn, admitted.identity(), 88, workspace);
        try store.commit(turn);
        const complete = try finish(store, bundle, admitted.identity(), workspace);
        const first = try readResult(store, bundle, complete);
        try t.expectEqual(@as(u64, 1), complete.revision);
        try t.expectEqual(@as(u128, 3), first.output.row.cells[0].value.atom.unsigned);
        try t.expectEqual(@as(i128, 60), first.output.row.cells[1].value.atom.signed);
        turn = try tables.turn(store);
        try t.expectEqual(.progress, try owner.wake(&turn, admitted.identity(), workspace));
        try store.commit(turn);
        turn = try tables.turn(store);
        const next = try owner.head(&turn, admitted.identity());
        turn = try continuation(store, next);
        try t.expectEqual(.idle, try owner.advance(&turn, .{ .identity = next.identity(), .input = next.continuation }, workspace));
        for (turn.decision.mutations) |slot| try t.expect(slot == null);
        // The previous exchange cannot satisfy this newly selected input cut.
        try t.expectError(error.RelationalSourceChanged, owner.attachExchange(&turn, admitted.identity(), 88, workspace));
        try t.expectEqual(@as(u64, 1), (try owner.head(&turn, admitted.identity())).revision);
    }
}
