const std = @import("std");
const t = std.testing;
const q = @import("root.zig");
const s = q.station;
const p = q.protocol;
const m = q.fuze.Unified;
const r = q.UnifiedRecords;
const capture = q.UnifiedCapture;
const Store = @import("source_store_test.zig");
const Source = struct {
    store: *Store,
    other: ?*Store = null,
    opens: ?*usize = null,
    deny_at: ?usize = null,
    pub fn open(self: @This(), resource: u64) !s.Turn {
        if (self.opens) |opens| {
            opens.* += 1;
            if (self.deny_at == opens.*) return error.AccessDenied;
        }
        const store = if (resource == self.store.resource) self.store else self.other orelse return error.AccessDenied;
        if (store.denied or resource != store.resource) return error.AccessDenied;
        return store.capture();
    }
};
fn frame(store: *Store, peer: u64, message: s.Frame) !s.Turn {
    var turn = try store.capture();
    turn.delivery.input.origin = .{ .process = .{ .pid = peer, .turn = 1, .output = 0 } };
    turn.delivery.input.value = try message.encode();
    return turn;
}
fn request(store: *Store, bundle: q.Bundle) !s.PublicationReference {
    var bytes: [q.Bundle.max_bytes]u8 = undefined;
    const body = try bundle.encode(&bytes);
    const ref = try bundle.reference(store.resource, 1);
    for (0..100) |_| {
        var turn = try store.capture();
        if (try s.PublicationUpload.step(&turn, .{ .namespace = ref.namespace, .identity_key = r.key('u', 1, 0), .identity = try ref.encode(), .limits = .{ .record_bytes = q.Bundle.max_bytes, .staging_bytes = q.Bundle.max_bytes, .staging_records = 1 }, .records = &.{.{ .id = 1, .spec = ref.spec, .bytes = body }} })) return ref;
        try store.commit(turn);
    }
    return error.UploadDidNotFinish;
}
const limits: q.Bundle.Limits = .{ .pages = 1000, .segments = 100, .result_bytes = 1048576 };
fn start(store: *Store, requests: *Store, bundle: q.Bundle) !r.Job {
    var turn = try store.capture();
    try capture.setPolicy(&turn, .{ .peer = 9, .requests = requests.resource, .revision = 1, .allow = true, .limits = limits, .declaration = try q.Bundle.declaration(bundle.source) });
    try store.commit(turn);
    const ref = try request(requests, bundle);
    turn = try frame(store, 9, .{ .kind = .call, .correlation = 77, .payload = try ref.encode() });
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const stored = try capture.start(&turn, ref, Source{ .store = requests }, arena.allocator());
    try store.commit(turn);
    return stored;
}
fn advance(store: *Store, requests: *Store, id: u64, workspace: []u8) !struct { step: capture.Advance, turn: s.Turn } {
    var reader = try store.capture();
    const job = try capture.job(&reader, id);
    const continuation: r.Continuation = .{ .job = id, .input = job.continuation };
    var turn = try frame(store, 3, .{ .kind = .cast, .payload = try continuation.encode() });
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const cancellation = q.fuze.execution.Cancellation.init(false);
    const step = try capture.advance(&turn, continuation, Source{ .store = requests }, arena.allocator(), workspace, &cancellation);
    return .{ .step = step, .turn = turn };
}
fn seedKV(store: *Store, count: usize) !q.SourceDefinition {
    for (0..count) |index| {
        var turn = try store.capture();
        var key: [9]u8 = undefined;
        key[0] = 'k';
        std.mem.writeInt(u64, key[1..9], index, .big);
        var value: [8]u8 = undefined;
        std.mem.writeInt(i64, &value, @as(i64, @intCast(index)) - 20, .little);
        try turn.put(try p.Value.init(&key), try p.Value.init(&value));
        try store.commit(turn);
    }
    return .{ .resource = store.resource, .source = .{ .kv = .{ .prefix = try p.Value.init("k"), .key = .{ .type = .binary }, .value = .{ .type = .int64 } } } };
}
fn verifyComplete(store: *Store, requests: *Store, job: r.Job, expected: u64, workspace: []u8) !void {
    var reader = try store.capture();
    const complete = try capture.job(&reader, job.id);
    try t.expectEqual(.complete, complete.phase);
    const progress = try capture.checkpoint(&reader, job.id);
    try t.expectEqual(expected, progress.progress.rows);
    try t.expect(store.versions.get(job.source).?.view.released_at != null);
    const publication = job.publication(store.resource);
    const published = try publication.inspect(&reader, r.manifest_record);
    const ref: s.PublicationReference = .{ .resource = store.resource, .namespace = publication.namespace, .record = r.manifest_record, .spec = published.spec };
    var manifest_bytes: [r.Manifest.max_bytes]u8 = undefined;
    const manifest = try r.Manifest.decode(try ref.read(Source{ .store = store }, &manifest_bytes));
    try t.expectEqualDeep(complete, manifest.job);
    try t.expectEqualDeep(progress, manifest.checkpoint);
    var chain = r.initialChain();
    var rows: u64 = 0;
    var size: u64 = 0;
    for (0..progress.progress.segments) |ordinal| {
        const segment = try r.Segment.decode((try reader.read(r.key('s', job.id, ordinal))).?);
        try t.expectEqual(ordinal, segment.ordinal);
        try t.expectEqual(rows, segment.row_start);
        var output: [m.Arrow.segment_bytes]u8 = undefined;
        const bytes = try segment.reference.read(Source{ .store = store }, &output);
        var digest: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
        try t.expectEqualSlices(u8, &segment.arrow_digest, &digest);
        rows += segment.rows;
        size += bytes.len;
        chain = try segment.extend(chain);
    }
    try t.expectEqual(expected, rows);
    try t.expectEqual(progress.bytes, size);
    try t.expectEqualSlices(u8, &progress.chain, &chain);
    const authority: Source = .{ .store = store, .other = requests };
    const identity: q.UnifiedResult.Expected = .{ .resource = store.resource, .source = store.pid, .requester = 9, .correlation = 77, .request = job.request };
    var cursor: ?q.UnifiedResult.Cursor = null;
    var decoded: m.Inspect.Batch = undefined;
    var output: [m.Arrow.segment_bytes]u8 = undefined;
    var seen: usize = 0;
    while (true) {
        var arena = std.heap.ArenaAllocator.init(t.allocator);
        defer arena.deinit();
        const page = try q.UnifiedResult.page(ref, identity, cursor, authority, arena.allocator(), workspace, &output, &decoded);
        try t.expectEqualDeep(manifest, page.manifest);
        for (0..decoded.count) |index| {
            const row = try decoded.row(index);
            try t.expectEqual(page.schema.columns.len, row.cells.len);
            seen += 1;
        }
        cursor = page.next;
        if (seen == decoded.count and cursor != null) {
            store.denied = true;
            try t.expectError(error.AccessDenied, q.UnifiedResult.page(ref, identity, cursor, authority, arena.allocator(), workspace, &output, &decoded));
            store.denied = false;
            requests.denied = true;
            try t.expectError(error.AccessDenied, q.UnifiedResult.page(ref, identity, cursor, authority, arena.allocator(), workspace, &output, &decoded));
            requests.denied = false;
        }
        if (cursor == null) break;
    }
    try t.expectEqual(expected, seen);
}
test "finite capture resumes discarded proposals publishes complete coverage and releases exact cut" {
    var store: Store = .{};
    defer store.deinit();
    var requests: Store = .{ .resource = 8, .pid = 9 };
    defer requests.deinit();
    const source = try seedKV(&store, 37);
    const bundle: q.Bundle = .{ .source = source, .plan = .{ .projection = &.{ 0, 1 } }, .limits = limits };
    const job = try start(&store, &requests, bundle);
    const workspace = try t.allocator.alloc(u8, m.Arrow.working_bytes);
    defer t.allocator.free(workspace);
    // Mutate the live source after retention. Later pages still read the old cut.
    _ = try seedKV(&store, 40);
    var iterations: usize = 0;
    while (iterations < 1000) : (iterations += 1) {
        const pending = try advance(&store, &requests, job.id, workspace);
        // A lost, unsent proposal recomputes identically after a fresh host.
        const retried = try advance(&store, &requests, job.id, workspace);
        try t.expectEqualDeep(pending.turn.decision, retried.turn.decision);
        try store.commit(retried.turn);
        if (retried.step == .complete) {
            var replied = false;
            for (retried.turn.decision.outputs) |slot| if (slot) |output| {
                const message = try s.Frame.decode(output.value);
                if (message.kind == .reply) {
                    try t.expectEqual(@as(u64, 9), output.pid);
                    try t.expectEqual(@as(u64, 77), message.correlation);
                    replied = true;
                }
            };
            try t.expect(replied);
            break;
        }
    }
    try t.expect(iterations > 20 and iterations < 1000);
    try verifyComplete(&store, &requests, job, 37, workspace);
    const duplicate = try advance(&store, &requests, job.id, workspace);
    try t.expectEqual(.duplicate, duplicate.step);
    try t.expectEqual(@as(usize, 0), countMutations(duplicate.turn));
    // Explicit retirement cleans result bytes, retaining job/record identity.
    var turn = try store.capture();
    try capture.close(&turn, job.id, .retired);
    try store.commit(turn);
    try finishCleanup(&store, &requests, job, workspace);
}
fn countMutations(turn: s.Turn) usize {
    var count: usize = 0;
    for (turn.decision.mutations) |slot| if (slot != null) {
        count += 1;
    };
    return count;
}
fn finishCleanup(store: *Store, requests: *Store, job: r.Job, workspace: []u8) !void {
    for (0..1000) |_| {
        const next = try advance(store, requests, job.id, workspace);
        try store.commit(next.turn);
        var reader = try store.capture();
        if ((try capture.job(&reader, job.id)).cleanup == 0) {
            const quota = try job.publication(store.resource).budget(&reader);
            try t.expectEqual(@as(u64, 0), quota.bytes);
            try t.expectEqual(@as(u32, 0), quota.records);
            try t.expect(store.versions.get(job.source).?.view.released_at != null);
            const publication = job.publication(store.resource);
            var keys = store.state.keyIterator();
            while (keys.next()) |key| if (key.len == 23 and std.mem.eql(u8, key.data[0..2], "\x00P") and key.data[10] == 'c' and std.mem.readInt(u64, key.data[2..10], .big) == publication.namespace) return error.CleanupLeftChunk;
            return;
        }
    }
    return error.CleanupDidNotFinish;
}
test "revoked current policy closes staged capture and bounded cleanup does not depend on request access" {
    var store: Store = .{};
    defer store.deinit();
    var requests: Store = .{ .resource = 8, .pid = 9 };
    defer requests.deinit();
    const source = try seedKV(&store, 12);
    const job = try start(&store, &requests, .{ .source = source, .plan = .{ .projection = &.{1} }, .limits = limits });
    const workspace = try t.allocator.alloc(u8, m.Arrow.working_bytes);
    defer t.allocator.free(workspace);
    for (0..3) |_| {
        const next = try advance(&store, &requests, job.id, workspace);
        try store.commit(next.turn);
    }
    var turn = try store.capture();
    var grant = (try capture.policy(&turn, 9)).?;
    grant.revision += 1;
    grant.allow = false;
    try capture.setPolicy(&turn, grant);
    try store.commit(turn);
    requests.denied = true;
    const next = try advance(&store, &requests, job.id, workspace);
    try t.expectEqual(.closed, next.step);
    try store.commit(next.turn);
    try finishCleanup(&store, &requests, job, workspace);
    turn = try store.capture();
    try t.expectEqual(.denied, (try capture.job(&turn, job.id)).phase);
}

fn drive(store: *Store, requests: *Store, job: r.Job, workspace: []u8) !void {
    for (0..1000) |_| {
        const pending = try advance(store, requests, job.id, workspace);
        try store.commit(pending.turn);
        if (pending.step == .complete) return;
    }
    return error.CaptureDidNotFinish;
}
test "Table and accepted Document use the same retained capture manifest and cleanup" {
    const workspace = try t.allocator.alloc(u8, m.Arrow.working_bytes);
    defer t.allocator.free(workspace);
    for ([_]bool{ false, true }) |document| {
        var store: Store = .{};
        defer store.deinit();
        var requests: Store = .{ .resource = 8, .pid = 9 };
        defer requests.deinit();
        var definition: q.SourceDefinition = undefined;
        var projections = [_]q.SourceDefinition.Projection{
            .{ .column = .{ .name = try m.Name.init("item"), .type = .int64 }, .path = &.{}, .relative = true },
            .{ .column = .{ .name = try m.Name.init("replica"), .type = .uint64 }, .path = &.{}, .relative = true, .mode = .element_replica },
        };
        const path = [_]q.document.Model.Name{try .init("items")};
        if (document) {
            const service: q.document.Service = .{ .resource = 7, .document = 17 };
            var turn = try store.capture();
            try service.create(&turn, 1, .{ .record_bytes = 4096, .staging_bytes = 4096, .staging_records = 1 });
            try store.commit(turn);
            const change = @import("source_test.zig").changeDocument;
            try change(&store, service, 1, 1, 1, &.{.{ .assign = .{ .field = path[0], .value = .list } }});
            for (0..12) |index| try change(&store, service, index + 2, 1, index + 2, &.{.{ .insert = .{ .object = .{ .counter = 1, .replica = 1 }, .after = if (index == 0) .root else .{ .counter = index + 1, .replica = 1 }, .value = .{ .signed = @intCast(index) } } }});
            definition = .{ .resource = 7, .source = .{ .document = .{ .reference = .{ .resource = 7, .document = 17, .epoch = 1, .type_revision = 1, .revision = 13 }, .expand = &path, .projections = &projections } } };
        } else {
            var turn = try store.capture();
            const table = try s.Table.create(&turn, 1, .{ .names = .{ try .init("id"), try .init("value") }, .value_type = .int64 });
            try store.commit(turn);
            for (0..12) |index| {
                turn = try store.capture();
                try table.upsert(&turn, .{ .key = @intCast(index), .value = .{ .int64 = @intCast(index) } });
                try store.commit(turn);
            }
            definition = .{ .resource = 7, .source = .{ .table = .{ .id = table.id, .schema = table.schema } } };
        }
        const job = try start(&store, &requests, .{ .source = definition, .plan = .{ .projection = &.{ 0, 1 } }, .limits = limits });
        try drive(&store, &requests, job, workspace);
        try verifyComplete(&store, &requests, job, 12, workspace);
        var turn = try store.capture();
        try capture.close(&turn, job.id, .retired);
        try store.commit(turn);
        try finishCleanup(&store, &requests, job, workspace);
    }
}
test "query budgets and cancellation discard candidates without leaking source pins" {
    const workspace = try t.allocator.alloc(u8, m.Arrow.working_bytes);
    defer t.allocator.free(workspace);
    var store: Store = .{};
    defer store.deinit();
    var requests: Store = .{ .resource = 8, .pid = 9 };
    defer requests.deinit();
    const definition = try seedKV(&store, 12);
    const job = try start(&store, &requests, .{ .source = definition, .plan = .{ .projection = &.{1} }, .limits = .{ .pages = 100, .segments = 100, .result_bytes = 1 } });
    try t.expectError(error.QueryBudgetExceeded, advance(&store, &requests, job.id, workspace));
    var turn = try store.capture();
    try t.expectEqual(@as(u64, 0), (try capture.checkpoint(&turn, job.id)).progress.pages);
    try t.expect(store.versions.get(job.source).?.view.released_at == null);
    try capture.close(&turn, job.id, .failed);
    try store.commit(turn);
    try finishCleanup(&store, &requests, job, workspace);
}

test "explicit cancellation and duplicate continuation do not reopen a capture" {
    var store: Store = .{};
    defer store.deinit();
    var requests: Store = .{ .resource = 8, .pid = 9 };
    defer requests.deinit();
    const definition = try seedKV(&store, 9);
    const job = try start(&store, &requests, .{ .source = definition, .plan = .{ .projection = &.{1} }, .limits = limits });
    const workspace = try t.allocator.alloc(u8, m.Arrow.working_bytes);
    defer t.allocator.free(workspace);
    const pending = try advance(&store, &requests, job.id, workspace);
    try store.commit(pending.turn);
    const stale: r.Continuation = .{ .job = job.id, .input = job.continuation };
    var turn = try frame(&store, 3, .{ .kind = .cast, .payload = try stale.encode() });
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const cancellation = q.fuze.execution.Cancellation.init(false);
    try t.expectEqual(.duplicate, try capture.advance(&turn, stale, Source{ .store = &requests }, arena.allocator(), workspace, &cancellation));
    try t.expectEqual(@as(usize, 0), countMutations(turn));
    turn = try store.capture();
    try capture.close(&turn, job.id, .cancelled);
    try store.commit(turn);
    turn = try store.capture();
    try capture.close(&turn, job.id, .cancelled);
    try t.expectEqual(@as(usize, 0), countMutations(turn));
    requests.denied = true;
    try finishCleanup(&store, &requests, job, workspace);
    turn = try store.capture();
    try t.expectEqual(.cancelled, (try capture.job(&turn, job.id)).phase);
}

test "completed result pages enforce current authority and policy before during and after a prefix" {
    var store: Store = .{};
    defer store.deinit();
    var requests: Store = .{ .resource = 8, .pid = 9 };
    defer requests.deinit();
    const definition = try seedKV(&store, 20);
    const job = try start(&store, &requests, .{ .source = definition, .plan = .{ .projection = &.{1} }, .limits = limits });
    const workspace = try t.allocator.alloc(u8, m.Arrow.working_bytes);
    defer t.allocator.free(workspace);
    try drive(&store, &requests, job, workspace);
    var reader = try store.capture();
    const pubn = job.publication(store.resource);
    const descriptor = try pubn.inspect(&reader, r.manifest_record);
    const reference: s.PublicationReference = .{ .resource = store.resource, .namespace = pubn.namespace, .record = r.manifest_record, .spec = descriptor.spec };
    const identity: q.UnifiedResult.Expected = .{ .resource = 7, .source = 3, .requester = 9, .correlation = 77, .request = job.request };
    var count: usize = 0;
    var authority: Source = .{ .store = &store, .other = &requests, .opens = &count };
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    var decoded: m.Inspect.Batch = undefined;
    var output: [m.Arrow.segment_bytes]u8 = undefined;
    const first = try q.UnifiedResult.page(reference, identity, null, authority, arena.allocator(), workspace, &output, &decoded);
    try t.expect(first.next != null and decoded.count > 0);
    const reads = count;
    for ([_]usize{ 1, reads / 2, reads }) |denied| {
        count = 0;
        authority.deny_at = denied;
        try t.expectError(error.AccessDenied, q.UnifiedResult.page(reference, identity, null, authority, arena.allocator(), workspace, &output, &decoded));
    }
    authority.deny_at = null;
    store.denied = true;
    try t.expectError(error.AccessDenied, q.UnifiedResult.page(reference, identity, first.next, authority, arena.allocator(), workspace, &output, &decoded));
    store.denied = false;
    requests.denied = true;
    try t.expectError(error.AccessDenied, q.UnifiedResult.page(reference, identity, first.next, authority, arena.allocator(), workspace, &output, &decoded));
    requests.denied = false;
    var changed_identity = identity;
    changed_identity.correlation += 1;
    try t.expectError(error.QueryIdentityMismatch, q.UnifiedResult.page(reference, changed_identity, first.next, authority, arena.allocator(), workspace, &output, &decoded));
    var forged = first.next.?;
    forged.rows += 1;
    try t.expectError(error.InvalidResultSegment, q.UnifiedResult.page(reference, identity, forged, authority, arena.allocator(), workspace, &output, &decoded));
    var turn = try store.capture();
    var grant = (try capture.policy(&turn, 9)).?;
    grant.revision += 1;
    grant.allow = false;
    try capture.setPolicy(&turn, grant);
    try store.commit(turn);
    try t.expectError(error.QueryDenied, q.UnifiedResult.page(reference, identity, first.next, authority, arena.allocator(), workspace, &output, &decoded));
}

test "admission rejects a request published by another PID even in the declared resource" {
    var store: Store = .{};
    defer store.deinit();
    var requests: Store = .{ .resource = 8, .pid = 10 };
    defer requests.deinit();
    const definition = try seedKV(&store, 1);
    try t.expectError(error.UnexpectedQueryPublisher, start(&store, &requests, .{ .source = definition, .plan = .{ .projection = &.{1} }, .limits = limits }));
    try t.expectEqual(@as(usize, 0), store.versions.count());
}

test "source behavior closes denied accepted work with the original reply and reusable bounded memory" {
    var store: Store = .{};
    defer store.deinit();
    var requests: Store = .{ .resource = 8, .pid = 9 };
    defer requests.deinit();
    const definition = try seedKV(&store, 12);
    const workspace = try t.allocator.alloc(u8, m.Arrow.working_bytes);
    defer t.allocator.free(workspace);
    const adapter = try t.allocator.alloc(u8, q.UnifiedBehavior.adapter_bytes);
    defer t.allocator.free(adapter);
    const cancellation = q.fuze.execution.Cancellation.init(false);
    var behavior: q.UnifiedBehavior.Source = .{ .peer = 9, .initializer = 42, .resources = undefined, .workspace = workspace, .adapter = adapter, .cancellation = &cancellation };
    const handler = behavior.interface();
    var turn = try store.capture();
    try turn.write(s.GenServer.descriptor_key, s.GenServer.descriptor);
    try handler.initialize.?(handler.context, &turn);
    try capture.setPolicy(&turn, .{ .peer = 9, .requests = 8, .revision = 1, .allow = true, .limits = limits, .declaration = try q.Bundle.declaration(definition) });
    try store.commit(turn);
    const ref = try request(&requests, .{ .source = definition, .plan = .{ .projection = &.{1} }, .limits = limits });
    const call: s.Frame = .{ .kind = .call, .correlation = 77, .payload = try ref.encode() };
    turn = try frame(&store, 9, call);
    try q.UnifiedBehavior.dispatchSource(&turn, call, 9, 42, Source{ .store = &requests }, adapter, workspace, &cancellation);
    const id = turn.delivery.input.position;
    try store.commit(turn);
    requests.denied = true;
    var reader = try store.capture();
    const stored = try capture.job(&reader, id);
    const message: s.Frame = .{ .kind = .cast, .payload = try (r.Continuation{ .job = id, .input = stored.continuation }).encode() };
    turn = try frame(&store, 3, message);
    try q.UnifiedBehavior.dispatchSource(&turn, message, 9, 42, Source{ .store = &requests }, adapter, workspace, &cancellation);
    try t.expectEqual(.denied, (try capture.job(&turn, id)).phase);
    try store.commit(turn);
    try t.expect(store.versions.get(stored.source).?.view.released_at != null);
    var replied = false;
    for (turn.decision.outputs) |slot| if (slot) |output| {
        const result = try s.Frame.decode(output.value);
        if (result.kind == .reply) {
            try t.expectEqual(@as(u64, 9), output.pid);
            try t.expectEqual(@as(u64, 77), result.correlation);
            try t.expectEqualStrings("query.v1.denied", result.payload.slice());
            replied = true;
        }
    };
    try t.expect(replied);
}
