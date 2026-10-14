const std = @import("std");
const t = std.testing;
const q = @import("root.zig");
const f = q.fuze;
const r = f.Relational;
const tables = @import("catalog_store_test.zig");
const Store = q.testing.Store;
const Captured = q.RelationalCaptured;
const Bundle = q.RelationalBundle;
const budgets: r.Budgets = .{ .resident_bytes = q.RelationalCapture.resident_base + 8 * 1024 * 1024, .spill_bytes = 8 * 1024 * 1024, .result_bytes = 1024 * 1024, .output_rows = 1000, .work_steps = 10000, .source_pins = 1 };
fn integer(value: i64) f.Types.Values.Cell {
    return .{ .value = .{ .atom = .{ .signed = value } } };
}
fn roundtrip(allocator: std.mem.Allocator, bytes: []const u8) !void {
    var owned = try Bundle.decode(allocator, bytes);
    defer owned.deinit();
    var output: [Bundle.max_bytes]u8 = undefined;
    try t.expectEqualSlices(u8, bytes, try owned.bundle.encode(&output));
}
test "captured self join retains one exact guarded cut and rejects schema identity substitution" {
    var store: Store = .{};
    defer store.deinit();
    try tables.create(&store, "CREATE TABLE items (k BIGINT, v BIGINT)");
    try tables.mutate(&store, 2, .{ .insert = &.{ &.{ integer(1), integer(10) }, &.{ integer(1), integer(20) }, &.{ .null, integer(7) } } });
    var found = try tables.definition(&store);
    defer found.deinit();
    var source = try q.TableSource.from(t.allocator, tables.configuration, found);
    defer source.deinit();
    var declarations = [_]r.Source{
        .{ .alias = "l", .realm = 1, .resource = 7, .catalog = 9, .owner = 3, .schema = found.schema.schema },
        .{ .alias = "r", .realm = 1, .resource = 7, .catalog = 9, .owner = 3, .schema = found.schema.schema },
    };
    const sources = [_]q.TableSource{ source.source, source.source };
    const plan: r.Plan = .{ .sources = &declarations, .join = .{ .kind = .left, .left = .{ .source = 0, .id = 1 }, .right = .{ .source = 1, .id = 1 } }, .outputs = &.{ .{ .name = "n", .expression = .count_all }, .{ .name = "v", .expression = .{ .sum = .{ .source = 1, .id = 2 } } } }, .lifetime = .captured, .budgets = budgets };
    const bundle: Bundle = .{ .plan = plan, .sources = &sources };
    var bytes: [Bundle.max_bytes]u8 = undefined;
    const encoded = try bundle.encode(&bytes);
    try roundtrip(t.allocator, encoded);
    var no_resize = t.FailingAllocator.init(t.allocator, .{ .resize_fail_index = 0 });
    try t.checkAllAllocationFailures(no_resize.allocator(), roundtrip, .{encoded});
    for (0..encoded.len) |size| {
        if (Bundle.decode(t.allocator, encoded[0..size])) |value| {
            var unexpected = value;
            unexpected.deinit();
            return error.AcceptedIncompleteBundle;
        } else |_| {}
    }
    bytes[4] ^= 1;
    try t.expectError(error.IncompatibleDefinition, Bundle.decode(t.allocator, encoded));
    bytes[4] ^= 1;
    bytes[36] = 0;
    try t.expectError(error.UnsupportedRelationalConsistency, Bundle.decode(t.allocator, encoded));
    bytes[36] = 1;
    var turn = try tables.turn(&store);
    // Same row types with a different schema revision must not reinterpret rows.
    declarations[0].schema.revision += 1;
    declarations[1].schema.revision += 1;
    try bundle.validate();
    try t.expectError(error.RelationalSourceChanged, Captured.capture(&turn, t.allocator, bundle, 17));
    for (turn.decision.retain) |retained| try t.expect(retained == null);
    declarations[0].schema.revision -= 1;
    declarations[1].schema.revision -= 1;
    const vector = try Captured.capture(&turn, t.allocator, bundle, 17);
    try t.expect(std.meta.eql(vector.entries[0].version, vector.entries[1].version));
    try t.expectEqual(turn.view.id, turn.decision.current_views[0].?);
    try t.expect(turn.decision.retain[0] != null and turn.decision.retain[1] == null);
    const value = try vector.encode(bundle);
    const recovered = try Captured.Vector.decode(bundle, value);
    try t.expectEqualSlices(Captured.Entry, vector.entries[0..2], recovered.entries[0..2]);
    try store.commit(turn);
    try tables.mutate(&store, 3, .{ .insert = &.{&.{ integer(1), integer(99) }} });
    turn = try tables.turn(&store);
    var data = try Captured.open(&turn, t.allocator, bundle, 17, vector, 20);
    const bound = data.bound();
    try t.expectEqual(bound.cuts[0].revision, bound.cuts[1].revision);
    try t.expectEqualSlices(u8, &bound.cuts[0].commitment, &bound.cuts[1].commitment);
    for (0..2) |side| {
        var after: ?r.RowIdentity = null;
        for ([_]i64{ 10, 20, 7 }) |expected| {
            const row = (try data.next(@intCast(side), after)).?;
            try t.expectEqual(expected, row.values[1].?);
            after = row.identity;
        }
        try t.expect(try data.next(@intCast(side), after) == null);
    }
    try admission(&store, bundle, null);
    var limited = bundle;
    limited.plan.budgets.work_steps = 1;
    try admission(&store, limited, error.RelationalWorkBudget);
    limited = bundle;
    limited.plan.budgets.spill_bytes = 0;
    try admission(&store, limited, error.RelationalSpillBudget);
    try tables.mutate(&store, 4, .{ .insert = &.{&.{ integer(1), integer(std.math.maxInt(i64)) }} });
    try admission(&store, bundle, error.Overflow);
    // Revoke catalog reads; retaining the cut does not preserve permission.
    try store.setRights(.{ .principal = 17, .revision = 2, .inspect = true, .create = false, .read = false, .insert = false, .update = false, .delete = false, .alter = false, .drop = false });
    turn = try tables.turn(&store);
    try t.expectError(error.CatalogDenied, Captured.open(&turn, t.allocator, bundle, 17, vector, 20));
    // Closure needs no source read; both aliases release exactly one retained ID.
    turn = try tables.turn(&store);
    try vector.release(bundle, &turn);
    try t.expect(turn.decision.release[0] != null and turn.decision.release[1] == null);
    try store.commit(turn);
    turn = try tables.turn(&store);
    try t.expectError(error.InvalidReadVersion, turn.openVersion(vector.entries[0].version));
}

fn admission(store: *Store, bundle: Bundle, expected_failure: ?anyerror) !void {
    const records = q.RelationalRecords;
    const capture = q.RelationalCapture;
    var turn = try tables.turn(store);
    const old_policy = try capture.policy(&turn, 3);
    const grant: records.Policy = .{ .peer = 3, .requests = store.resource, .principal = 17, .revision = if (old_policy) |old| old.revision + 1 else 1, .request = try bundle.fingerprint(), .allow = true };
    try t.expectEqualDeep(grant, try records.Policy.decode(try grant.encode()));
    try capture.setPolicy(&turn, grant);
    try store.commit(turn);
    const reference = try bundle.reference(store.resource, store.input);
    var bytes: [Bundle.max_bytes]u8 = undefined;
    const body = try bundle.encode(&bytes);
    var ready = false;
    for (0..1000) |_| {
        turn = try tables.turn(store);
        if (try q.station.PublicationUpload.step(&turn, .{ .domain = .query_request, .namespace = reference.namespace, .identity_key = records.key('u', reference.namespace, 0), .identity = try reference.encode(), .limits = .{ .record_bytes = Bundle.max_bytes, .staging_bytes = Bundle.max_bytes, .staging_records = 1 }, .records = &.{.{ .id = 1, .spec = reference.spec, .bytes = body }} })) {
            ready = true;
            break;
        }
        try store.commit(turn);
    }
    try t.expect(ready);
    turn = try tables.turn(store);
    turn.delivery.input.origin = .{ .process = .{ .pid = 3, .turn = 1, .output = 0 } };
    turn.delivery.input.value = try (q.station.Frame{ .kind = .call, .correlation = reference.namespace, .payload = try reference.encode() }).encode();
    const workspace = try t.allocator.alloc(u8, 4 * 1024 * 1024);
    defer t.allocator.free(workspace);
    const stored = try capture.start(&turn, reference, workspace);
    const encoded = try stored.encode();
    try t.expectEqual(@as(u16, 255), encoded.len);
    try t.expectEqualDeep(stored, try records.Job.decode(encoded));
    var mutations: usize = 0;
    for (turn.decision.mutations) |entry| if (entry != null) {
        mutations += 1;
    };
    try t.expectEqual(@as(usize, 4), mutations);
    try t.expect(turn.decision.retain[0] != null and turn.decision.retain[1] == null);
    try store.commit(turn);
    // The publisher can retire its current request. Recovery must still read
    // the exact retained publication, not reopen the live descriptor or SQL.
    turn = try tables.turn(store);
    _ = try reference.publication().retire(&turn, reference.record);
    try store.commit(turn);
    // Admission evidence and the frozen plan survive independently of host memory.
    turn = try tables.turn(store);
    try t.expectEqualDeep(stored, try capture.job(&turn, stored.id));
    var retained = try turn.openVersion(stored.request_version);
    const descriptor = try reference.publication().inspect(&retained, 1);
    try t.expectEqualDeep(reference.spec, descriptor.spec);
    var complete = false;
    for (0..10000) |_| {
        turn = try tables.turn(store);
        const current = try capture.job(&turn, stored.id);
        const continuation: q.UnifiedRecords.Continuation = .{ .job = stored.id, .input = current.continuation };
        turn.delivery.input.origin = .{ .process = .{ .pid = 3, .turn = 1, .output = 0 } };
        turn.delivery.input.value = try (q.station.Frame{ .kind = .cast, .payload = try continuation.encode() }).encode();
        const result = try capture.advance(&turn, continuation, workspace);
        try store.commit(turn);
        if (result == .complete or result == .closed) {
            complete = true;
            break;
        }
        try t.expectEqual(.progress, result);
    }
    try t.expect(complete);
    turn = try tables.turn(store);
    const finished = try capture.job(&turn, stored.id);
    if (expected_failure) |cause| {
        try t.expectEqual(.failed, finished.phase);
        try t.expect(finished.released and finished.manifest == 0);
        const failure = try records.Failure.decode((try turn.read(records.key('f', stored.id, 0))).?);
        try t.expectEqualStrings(@errorName(cause), failure.cause.slice());
        if (cause == error.Overflow) {
            const failure_vector = try Captured.Vector.decode(bundle, (try turn.read(records.key('v', stored.id, 0))).?);
            var failure_cuts: [r.max_sources]r.Cut = undefined;
            try failure_vector.boundCuts(bundle, &failure_cuts);
            const failure_pages: q.RelationalState = .{ .publication = finished.publication(store.resource) };
            const failed_checkpoint = try failure_pages.checkpoint(&turn, finished.checkpoint, .{ .plan = bundle.plan, .cuts = failure_cuts[0..failure_vector.count] });
            try t.expectEqual(.failed, failed_checkpoint.phase);
            try t.expectEqual(@as(u8, 1), failed_checkpoint.failure.?.output);
            try t.expectEqual(@as(u64, 4), failed_checkpoint.failure.?.pair.right.?.operation);
        }
        try t.expectError(error.InvalidReadVersion, turn.openVersion(stored.request_version));
        try collected(store, stored.id);
        if (finished.checkpoint != 0) {
            turn = try tables.turn(store);
            try t.expectEqual(.published, (try finished.publication(store.resource).inspect(&turn, finished.checkpoint)).state);
        }
        return;
    }
    try t.expectEqual(.complete, finished.phase);
    try t.expectEqual(@as(u64, 1), finished.outputs);
    const saved_vector = try Captured.Vector.decode(bundle, (try turn.read(records.key('v', stored.id, 0))).?);
    var cuts: [r.max_sources]r.Cut = undefined;
    try saved_vector.boundCuts(bundle, &cuts);
    const bound: r.Bound = .{ .plan = bundle.plan, .cuts = cuts[0..saved_vector.count] };
    const pages: q.RelationalState = .{ .publication = finished.publication(store.resource) };
    const saved_progress = try pages.checkpoint(&turn, finished.checkpoint, bound);
    try t.expectEqual(.complete, saved_progress.phase);
    const output = try records.Output.decode((try turn.read(records.key('o', stored.id, 0))).?);
    var row_bytes: [f.RelationalOutput.max_bytes]u8 = undefined;
    const row = try f.RelationalOutput.decode(bound, try pages.read(&turn, output.reference.record, records.output_format, &row_bytes));
    try t.expectEqual(@as(u128, 10), row.row.cells[0].value.atom.unsigned);
    try t.expectEqual(@as(i128, 387), row.row.cells[1].value.atom.signed);
    var manifest_bytes: [records.Manifest.max_bytes]u8 = undefined;
    const manifest = try records.Manifest.decode(try pages.read(&turn, finished.manifest, records.manifest_format, &manifest_bytes));
    try t.expectEqualDeep(finished, manifest.job);
    var foreign = saved_vector;
    for (foreign.entries[0..foreign.count]) |*entry| entry.version.pid += 1;
    var wrong_manifest = manifest;
    wrong_manifest.vector = try foreign.encode(bundle);
    try t.expectError(error.InvalidRelationalRecord, wrong_manifest.encode(&manifest_bytes));
    try t.expectEqualSlices(u8, &try output.extend(records.initialChain()), &finished.chain);
    const cause = (try records.Failure.fromError(error.RelationalSpillBudget)).?;
    try t.expectEqualDeep(cause, try records.Failure.decode(try cause.encode()));
    turn = try tables.turn(store);
    try capture.close(&turn, stored.id, .retired, null);
    try t.expect(turn.decision.release[0] != null and turn.decision.release[1] == null);
    try store.commit(turn);
    turn = try tables.turn(store);
    const closed = try capture.job(&turn, stored.id);
    try t.expectEqual(.retired, closed.phase);
    try t.expect(closed.released);
    try t.expectError(error.InvalidReadVersion, turn.openVersion(stored.request_version));
    try collected(store, stored.id);
    turn = try tables.turn(store);
    for (1..finished.next_record) |id| {
        const record = try finished.publication(store.resource).inspect(&turn, id);
        try t.expectEqual(.retired, record.state);
        try t.expectEqual(record.written, record.collected);
    }
}
fn collected(store: *Store, id: u64) !void {
    for (0..10000) |_| {
        var turn = try tables.turn(store);
        const complete = try q.RelationalCapture.collect(&turn, id);
        try turn.validate();
        try store.commit(turn);
        if (complete) {
            turn = try tables.turn(store);
            try t.expect(try q.RelationalCapture.collect(&turn, id));
            for (turn.decision.mutations) |mutation| try t.expect(mutation == null);
            return;
        }
    }
    return error.CollectionDidNotComplete;
}
