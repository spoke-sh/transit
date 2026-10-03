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
    return requestBytes(store, body);
}
fn requestBytes(store: *Store, body: []const u8) !s.PublicationReference {
    const ref: s.PublicationReference = .{ .domain = .query_request, .resource = store.resource, .namespace = 1, .record = 1, .spec = try s.Publication.Digest.of(q.Bundle.format, body) };
    for (0..100) |_| {
        var turn = try store.capture();
        if (try s.PublicationUpload.step(&turn, .{ .domain = .query_request, .namespace = ref.namespace, .identity_key = r.key('u', 1, 0), .identity = try ref.encode(), .limits = .{ .record_bytes = q.Bundle.max_bytes, .staging_bytes = q.Bundle.max_bytes, .staging_records = 1 }, .records = &.{.{ .id = 1, .spec = ref.spec, .bytes = body }} })) return ref;
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
    const ref: s.PublicationReference = .{ .domain = .query_result, .resource = store.resource, .namespace = publication.namespace, .record = r.manifest_record, .spec = published.spec };
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
            while (keys.next()) |key| if (key.len == 27 and std.mem.eql(u8, key.data[0..2], "\x00P") and std.mem.readInt(u32, key.data[2..6], .big) == @backingInt(publication.domain) and key.data[14] == 'c' and std.mem.readInt(u64, key.data[6..14], .big) == publication.namespace) return error.CleanupLeftChunk;
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
    try capture.closeFailure(&turn, job.id, q.QueryFailure.fromError(error.QueryBudgetExceeded, .execution).?);
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
    const reference: s.PublicationReference = .{ .domain = .query_result, .resource = store.resource, .namespace = pubn.namespace, .record = r.manifest_record, .spec = descriptor.spec };
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
            try t.expectEqual(.access_denied, (try q.QueryFailure.decode(result.payload)).code);
            replied = true;
        }
    };
    try t.expect(replied);
}

test "source behavior rejects a published incompatible plan with an exact terminal reply" {
    var store: Store = .{};
    defer store.deinit();
    var requests: Store = .{ .resource = 8, .pid = 9 };
    defer requests.deinit();
    const definition = try seedKV(&store, 1);
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
    const bundle: q.Bundle = .{ .source = definition, .plan = .{ .projection = &.{1} }, .limits = limits };
    var bytes: [q.Bundle.max_bytes]u8 = undefined;
    const encoded = try bundle.encode(&bytes);
    const plan_start = 32 + @as(usize, std.mem.readInt(u16, bytes[4..6], .little));
    bytes[plan_start + 4] ^= 1;
    // Publication integrity is valid; rejection must come from plan compatibility.
    const ref = try requestBytes(&requests, encoded);
    const call: s.Frame = .{ .kind = .call, .correlation = 77, .payload = try ref.encode() };
    turn = try frame(&store, 9, call);
    try q.UnifiedBehavior.dispatchSource(&turn, call, 9, 42, Source{ .store = &requests }, adapter, workspace, &cancellation);
    try store.commit(turn);
    try t.expectEqual(0, store.versions.count());
    var replies: usize = 0;
    for (turn.decision.outputs) |slot| if (slot) |output| {
        const result = try s.Frame.decode(output.value);
        try t.expectEqual(.reply, result.kind);
        try t.expectEqual(@as(u64, 9), output.pid);
        try t.expectEqual(@as(u64, 77), result.correlation);
        try t.expectEqual(.plan_definition_mismatch, (try q.QueryFailure.decode(result.payload)).code);
        replies += 1;
    };
    try t.expectEqual(1, replies);
}

test "source closure retains the exact first budget dimension and measurements through replay" {
    const workspace = try t.allocator.alloc(u8, m.Arrow.working_bytes);
    defer t.allocator.free(workspace);
    const cancellation = q.fuze.execution.Cancellation.init(false);
    for ([_]q.QueryFailure.Dimension{ .pages, .segments, .result_bytes }) |dimension| {
        var store: Store = .{};
        defer store.deinit();
        var requests: Store = .{ .resource = 8, .pid = 9 };
        defer requests.deinit();
        const definition = try seedKV(&store, 24);
        var budget = limits;
        switch (dimension) {
            .pages => budget.pages = 1,
            .segments => budget.segments = 1,
            .result_bytes => budget.result_bytes = 1,
            else => unreachable,
        }
        const job = try start(&store, &requests, .{ .source = definition, .plan = .{ .projection = &.{1} }, .limits = budget });
        var observed: ?q.QueryFailure = null;
        for (0..200) |_| {
            var reader = try store.capture();
            const current = try capture.job(&reader, job.id);
            const continuation: r.Continuation = .{ .job = job.id, .input = current.continuation };
            var turn = try frame(&store, 3, .{ .kind = .cast, .payload = try continuation.encode() });
            var arena = std.heap.ArenaAllocator.init(t.allocator);
            defer arena.deinit();
            const step = capture.advanceDiagnostic(&turn, continuation, Source{ .store = &requests }, arena.allocator(), workspace, &cancellation, &observed) catch |err| {
                try t.expectEqual(error.QueryBudgetExceeded, err);
                try t.expectEqual(dimension, observed.?.dimension);
                try t.expectEqual(1, observed.?.limit);
                try t.expect(observed.?.observed > observed.?.limit);
                for (turn.decision.mutations) |mutation| try t.expect(mutation == null);
                try capture.closeFailure(&turn, job.id, observed.?);
                try store.commit(turn);
                break;
            };
            try t.expectEqual(.progress, step);
            try store.commit(turn);
        }
        try t.expect(observed != null);
        var turn = try store.capture();
        const failed = try capture.job(&turn, job.id);
        try t.expectEqual(.failed, failed.phase);
        try t.expectEqualDeep(observed, failed.failure);
        // A later error and repeated close cannot replace the original evidence.
        try capture.closeFailure(&turn, job.id, q.QueryFailure.fromError(error.Overflow, .execution).?);
        try t.expectEqualDeep(failed, try capture.job(&turn, job.id));
        try finishCleanup(&store, &requests, failed, workspace);
        turn = try store.capture();
        try t.expectEqualDeep(observed, (try capture.job(&turn, job.id)).failure);
    }
}

test "runtime failure commits its original frozen row witness atomically within one value" {
    var store: Store = .{};
    defer store.deinit();
    var requests: Store = .{ .resource = 8, .pid = 9 };
    defer requests.deinit();
    const source = try seedKV(&store, 2);
    var key = [_]u8{ 'k', 0, 0, 0, 0, 0, 0, 0, 0 };
    for ([_]i64{ std.math.maxInt(i64), 1 }, 0..) |number, index| {
        var turn = try store.capture();
        key[8] = @intCast(index);
        var bytes: [8]u8 = undefined;
        std.mem.writeInt(i64, &bytes, number, .little);
        try turn.put(try p.Value.init(&key), try p.Value.init(&bytes));
        try store.commit(turn);
    }
    const job = try start(&store, &requests, .{ .source = source, .plan = .{ .projection = &.{1}, .aggregate = .sum }, .limits = limits });
    // The live values now no longer overflow; the retained execution still does.
    _ = try seedKV(&store, 2);
    const cancellation = q.fuze.execution.Cancellation.init(false);
    const continuation: r.Continuation = .{ .job = job.id, .input = job.continuation };
    var observed: ?q.QueryFailure = null;
    for (0..2) |attempt| {
        var turn = try frame(&store, 3, .{ .kind = .cast, .payload = try continuation.encode() });
        var arena: std.heap.ArenaAllocator = .init(t.allocator);
        defer arena.deinit();
        const before = turn.decision;
        var failure: ?q.QueryFailure = null;
        try t.expectError(error.Overflow, capture.advanceDiagnostic(&turn, continuation, Source{ .store = &requests }, arena.allocator(), &.{}, &cancellation, &failure));
        try t.expectEqualDeep(before, turn.decision);
        try t.expectEqual(q.QueryFailure.Code.arithmetic_overflow, failure.?.code);
        try t.expectEqual(@as(u64, 2), failure.?.runtime.?.row);
        try t.expectEqualStrings("value", failure.?.runtime.?.columnName());
        if (observed) |previous| try t.expectEqualDeep(previous, failure.?) else observed = failure;
        if (attempt == 1) {
            try capture.closeFailure(&turn, job.id, failure.?);
            try turn.validate();
            try store.commit(turn);
        }
    }
    var reader = try store.capture();
    const failed = try capture.job(&reader, job.id);
    try t.expectEqualDeep(observed, failed.failure);
    try t.expectEqual(@as(usize, 255), (try failed.encode()).len);
    try t.expectEqualDeep(failed, try r.Job.decode(try failed.encode()));
    try t.expect(store.versions.get(job.source).?.view.released_at != null);
    var status: q.UnifiedRequest.Status = .{ .reference = job.request, .phase = .rejected, .correlation = 77, .failure = failed.failure };
    try t.expectEqual(@as(usize, 200), (try status.encode()).len);
    try t.expectEqualDeep(status, try q.UnifiedRequest.Status.decode(try status.encode()));
    status.phase = .retired;
    try t.expectEqualDeep(observed, (try q.UnifiedRequest.Status.decode(try status.encode())).failure);
}

test "policy changes retain observed metadata without reopening denied request publications" {
    for ([_]q.SourceWitness.Reason{ .policy_missing, .policy_disabled, .policy_revision }) |reason| {
        var store: Store = .{};
        defer store.deinit();
        var requests: Store = .{ .resource = 8, .pid = 9 };
        defer requests.deinit();
        const source = try seedKV(&store, 1);
        const job = try start(&store, &requests, .{ .source = source, .plan = .{ .projection = &.{1} }, .limits = limits });
        var turn = try store.capture();
        var grant = (try capture.policy(&turn, 9)).?;
        grant.revision = 2;
        grant.allow = reason != .policy_disabled;
        if (reason == .policy_missing) try turn.write(r.key('p', 9, 0), null) else try capture.setPolicy(&turn, grant);
        try store.commit(turn);
        requests.denied = true;
        const next = try advance(&store, &requests, job.id, &.{});
        try t.expectEqual(capture.Advance.closed, next.step);
        try store.commit(next.turn);
        turn = try store.capture();
        const rejected = try capture.job(&turn, job.id);
        const original = rejected.failure.?;
        try t.expectEqual(reason, original.source.?.reason);
        try t.expectEqual(@as(?u64, 1), original.source.?.expected);
        try t.expectEqual(if (reason == .policy_missing) @as(?u64, null) else @as(?u64, 2), original.source.?.actual);
        try t.expectEqualDeep(original, try q.QueryFailure.decode(try original.encode()));
        try t.expectEqual(@as(usize, 255), (try rejected.encode()).len);
        grant.revision = 3;
        grant.allow = true;
        try capture.setPolicy(&turn, grant);
        try store.commit(turn);
        turn = try store.capture();
        try capture.close(&turn, job.id, .retired);
        try store.commit(turn);
        turn = try store.capture();
        try t.expectEqualDeep(original, (try capture.job(&turn, job.id)).failure.?);
    }
}

test "changed Table schema failure owns both fingerprints across rollback repair and retirement" {
    var store: Store = .{};
    defer store.deinit();
    var requests: Store = .{ .resource = 8, .pid = 9 };
    defer requests.deinit();
    var turn = try store.capture();
    const table = try s.Table.create(&turn, 1, .{ .names = .{ try .init("id"), try .init("value") }, .value_type = .int64 });
    try store.commit(turn);
    const source: q.SourceDefinition = .{ .resource = 7, .source = .{ .table = .{ .id = 1, .schema = table.schema } } };
    const job = try start(&store, &requests, .{ .source = source, .plan = .{ .projection = &.{1} }, .limits = limits });
    var changed = table.schema;
    changed.value_type = .boolean;
    turn = try store.capture();
    try turn.write(s.Table.descriptorKey(1), try s.Table.encodeSchema(changed));
    try store.commit(turn);
    const continuation: r.Continuation = .{ .job = job.id, .input = job.continuation };
    const cancellation = q.fuze.execution.Cancellation.init(false);
    var observed: ?q.QueryFailure = null;
    for (0..2) |attempt| {
        turn = try frame(&store, 3, .{ .kind = .cast, .payload = try continuation.encode() });
        var arena: std.heap.ArenaAllocator = .init(t.allocator);
        defer arena.deinit();
        const before = turn.decision;
        var failure: ?q.QueryFailure = null;
        try t.expectError(error.TableSchemaChanged, capture.advanceDiagnostic(&turn, continuation, Source{ .store = &requests }, arena.allocator(), &.{}, &cancellation, &failure));
        try t.expectEqualDeep(before, turn.decision);
        try t.expectEqualDeep(try table.schema.fingerprint(), failure.?.source.?.expected_hash.?);
        try t.expectEqualDeep(try changed.fingerprint(), failure.?.source.?.actual_hash.?);
        if (observed) |first| try t.expectEqualDeep(first, failure.?) else observed = failure;
        if (attempt == 1) {
            try capture.closeFailure(&turn, job.id, failure.?);
            try store.commit(turn);
        }
    }
    turn = try store.capture();
    try turn.write(s.Table.descriptorKey(1), try s.Table.encodeSchema(table.schema));
    try store.commit(turn);
    turn = try store.capture();
    try capture.close(&turn, job.id, .retired);
    try store.commit(turn);
    turn = try store.capture();
    const final = try capture.job(&turn, job.id);
    try t.expectEqualDeep(observed, final.failure);
    try t.expect(store.versions.get(job.source).?.view.released_at != null);
    var status: q.UnifiedRequest.Status = .{ .reference = job.request, .phase = .retired, .correlation = 77, .failure = final.failure };
    status = try q.UnifiedRequest.Status.decode(try status.encode());
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const neutral = try q.Bridge.Status.fromNative(arena.allocator(), status);
    try t.expectEqualDeep(try changed.fingerprint(), neutral.diagnostic.?.facts[3].?.value.?.digest);
}
