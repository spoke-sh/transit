const std = @import("std");
const t = std.testing;
const q = @import("root.zig");
const s = q.station;
const p = q.protocol;
const r = q.UnifiedRecords;
const request = q.UnifiedRequest;
const upload = q.UnifiedUpload;
const Store = @import("source_store_test.zig");
const Source = struct {
    store: *Store,
    pub fn open(self: @This(), resource: u64) !s.GrowingTurn {
        if (resource != self.store.resource or self.store.denied) return error.AccessDenied;
        return self.store.capture();
    }
};
fn fixture() q.Bundle {
    return .{ .source = .{ .resource = 7, .source = .{ .kv = .{ .prefix = p.Value.init("k") catch unreachable, .key = .{ .type = .binary }, .value = .{ .type = .utf8 } } } }, .plan = .{ .projection = &.{1}, .predicate = .{ .compare = .{ .column = 1, .op = .ne, .value = .{ .utf8 = &@as([4096]u8, @splat('x')) } } } }, .limits = .{ .pages = 100, .segments = 100, .result_bytes = 1048576 } };
}
fn stage(store: *Store, ref: s.PublicationReference, bytes: []const u8) !void {
    for (0..ref.spec.chunks()) |ordinal| {
        const chunk = bytes[ordinal * s.Publication.chunk_bytes ..][0..try ref.spec.size(@intCast(ordinal))];
        var offset: usize = 0;
        while (offset < chunk.len) : (offset += request.part_bytes) {
            const command: request.Command = .{ .part = .{ .namespace = ref.namespace, .ordinal = @intCast(ordinal), .second = offset != 0, .bytes = chunk[offset..@min(offset + request.part_bytes, chunk.len)] } };
            const encoded = try command.encode();
            try t.expect(encoded.len <= 145);
            const decoded = try request.Command.decode(&encoded);
            var turn = try store.capture();
            try upload.part(&turn, decoded.part);
            try store.commit(turn);
            turn = try store.capture();
            try upload.part(&turn, decoded.part);
            try t.expectEqual(@as(usize, 0), writes(turn));
            var changed = decoded.part;
            var altered: [request.part_bytes]u8 = undefined;
            @memcpy(altered[0..changed.bytes.len], changed.bytes);
            altered[0] ^= 1;
            changed.bytes = altered[0..changed.bytes.len];
            try t.expectError(error.QueryUploadIdentityConflict, upload.part(&turn, changed));
            try t.expectEqual(@as(usize, 0), writes(turn));
        }
    }
}
fn writes(turn: s.GrowingTurn) usize {
    var count: usize = 0;
    for (turn.decision.mutations) |slot| if (slot != null) {
        count += 1;
    };
    return count;
}
test "larger upload keeps ordinary frames frozen chunks and one original durable call" {
    var store: Store = .{ .resource = 8, .pid = 9 };
    defer store.deinit();
    const bundle = fixture();
    var buffer: [q.Bundle.max_bytes]u8 = undefined;
    const bytes = try bundle.encode(&buffer);
    try t.expect(bytes.len > 4096);
    const ref = try bundle.reference(8, std.math.maxInt(u64));
    var turn = try store.capture();
    try upload.begin(&turn, ref);
    try t.expectEqual(@as(usize, 4), writes(turn));
    try store.commit(turn);
    turn = try store.capture();
    try upload.begin(&turn, ref);
    try t.expectEqual(@as(usize, 0), writes(turn));
    var changed = ref;
    changed.spec.digest[0] ^= 1;
    try t.expectError(error.QueryUploadIdentityConflict, upload.begin(&turn, changed));
    changed = ref;
    changed.namespace = 2;
    try t.expectError(error.QueryBusy, upload.begin(&turn, changed));
    try t.expectError(error.IncompletePublication, upload.seal(&turn, ref.namespace));
    try t.expectEqual(@as(usize, 0), writes(turn));
    try stage(&store, ref, bytes);
    turn = try store.capture();
    try upload.seal(&turn, ref.namespace);
    try store.commit(turn);
    var restored: [q.Bundle.max_bytes]u8 = undefined;
    try t.expectEqualSlices(u8, bytes, try ref.read(Source{ .store = &store }, &restored));
    turn = try store.capture();
    const correlation = try upload.submit(&turn, ref.namespace, 3);
    try store.commit(turn);
    turn = try store.capture();
    try t.expectEqual(correlation, try upload.submit(&turn, ref.namespace, 3));
    try t.expectEqual(@as(usize, 0), writes(turn));
    const current = (try upload.status(&turn, ref.namespace)).?;
    try t.expectEqual(.admitted, current.phase);
    try t.expectEqualDeep(current, try request.Status.decode(try current.encode()));
    const manifest: s.PublicationReference = .{ .resource = 7, .namespace = 900, .record = r.manifest_record, .spec = try s.Publication.Digest.of(r.manifest_format, "manifest") };
    const frame: s.Frame = .{ .kind = .reply, .correlation = correlation, .payload = try manifest.encode() };
    turn.delivery.input.value = try frame.encode();
    turn.delivery.input.origin = .{ .process = .{ .pid = 3, .turn = 1, .output = 0 } };
    try t.expect(try turn.acceptReply() == .accepted);
    try upload.reply(&turn, frame, 3);
    try store.commit(turn);
    turn = try store.capture();
    const complete = (try upload.status(&turn, ref.namespace)).?;
    try t.expectEqual(.complete, complete.phase);
    try t.expectEqualDeep(manifest, complete.manifest.?);
    try t.expectEqual(@as(?u64, null), try upload.active(&turn));
    try upload.cancel(&turn, ref.namespace);
    try t.expectEqual(@as(usize, 0), writes(turn));
    try upload.retire(&turn, ref.namespace);
    try store.commit(turn);
    try cleanup(&store, ref);
    turn = try store.capture();
    try t.expectEqual(correlation, try upload.submit(&turn, ref.namespace, 3));
    try t.expectEqual(@as(usize, 0), writes(turn));
    try t.expectError(error.PublicationNotPublished, ref.check(Source{ .store = &store }));
}
fn cleanup(store: *Store, ref: s.PublicationReference) !void {
    for (0..100) |_| {
        var turn = try store.capture();
        const done = try upload.collect(&turn, ref.namespace);
        try store.commit(turn);
        if (done) {
            turn = try store.capture();
            try t.expect((try upload.status(&turn, ref.namespace)).?.collected);
            try t.expectEqual(@as(?u64, null), try upload.active(&turn));
            const budget = try ref.publication().budget(&turn);
            try t.expectEqual(@as(u64, 0), budget.bytes);
            try t.expectEqual(@as(u32, 0), budget.records);
            return;
        }
    }
    return error.CleanupIncomplete;
}
test "abandoning a partial upload holds admission until bounded cleanup releases reservation" {
    var store: Store = .{ .resource = 8, .pid = 9 };
    defer store.deinit();
    const bundle = fixture();
    const ref = try bundle.reference(8, 1);
    var turn = try store.capture();
    try upload.begin(&turn, ref);
    try store.commit(turn);
    turn = try store.capture();
    try upload.part(&turn, .{ .namespace = 1, .ordinal = 0, .second = false, .bytes = &@as([128]u8, @splat('x')) });
    try store.commit(turn);
    turn = try store.capture();
    try upload.cancel(&turn, 1);
    try store.commit(turn);
    turn = try store.capture();
    var next = ref;
    next.namespace = 2;
    try t.expectError(error.QueryBusy, upload.begin(&turn, next));
    try cleanup(&store, ref);
    turn = try store.capture();
    try t.expect((try turn.read(r.key('h', 1, 0))) == null);
    try upload.begin(&turn, next);
    try store.commit(turn);
}
test "upload command versions bounds and failed multi-key preparation are explicit" {
    const ref = try fixture().reference(8, 1);
    for ([_]request.Command{ .initialize, .{ .begin = ref }, .{ .seal = 1 }, .{ .submit = 1 }, .{ .cancel = 1 }, .{ .collect = 1 }, .{ .retire = 1 } }) |command| {
        const encoded = try command.encode();
        try t.expectEqualDeep(command, try request.Command.decode(&encoded));
        var bad = encoded;
        bad.data[3] = '9';
        try t.expectError(error.InvalidQueryUpload, request.Command.decode(&bad));
        for (0..encoded.len) |len| {
            const truncated = try p.Value.init(encoded.slice()[0..len]);
            if (request.Command.decode(&truncated)) |_| return error.AcceptedPartialCommand else |_| {}
        }
    }
    try t.expectError(error.InvalidQueryUpload, (request.Command{ .part = .{ .namespace = 1, .ordinal = 0, .second = false, .bytes = &@as([129]u8, @splat('x')) } }).encode());
    var store: Store = .{ .resource = 8, .pid = 9 };
    defer store.deinit();
    var turn = try store.capture();
    try turn.put(try p.Value.init("application"), .{});
    const before = turn.decision;
    try t.expectError(error.MutationBudgetExceeded, upload.begin(&turn, ref));
    try t.expectEqualDeep(before, turn.decision);
}

test "requester behavior authenticates ingress and records malformed command dispositions" {
    var store: Store = .{ .resource = 8, .pid = 9 };
    defer store.deinit();
    var requester: q.UnifiedBehavior.Requester = .{ .principal = 42, .source = 3 };
    const handler = requester.interface();
    var turn = try store.capture();
    try turn.write(s.GrowingGenServer.descriptor_key, s.GrowingGenServer.descriptor);
    try handler.initialize.?(handler.context, &turn);
    turn.delivery.input.origin = .{ .external = .{ .principal = 42, .policy_revision = 1 } };
    var frame: s.Frame = .{ .kind = .cast, .payload = try request.Command.encode(.initialize) };
    turn.delivery.input.value = try frame.encode();
    try handler.handle(handler.context, &turn, frame);
    try store.commit(turn);
    const ref = try fixture().reference(8, 1);
    turn = try store.capture();
    turn.delivery.input.origin = .{ .external = .{ .principal = 41, .policy_revision = 1 } };
    frame.payload = try (request.Command{ .begin = ref }).encode();
    turn.delivery.input.value = try frame.encode();
    try handler.handle(handler.context, &turn, frame);
    try t.expectEqualStrings("QueryPrincipalMismatch", (try turn.read(r.key('e', turn.delivery.input.position, 0))).?.slice());
    try t.expect((try upload.active(&turn)) == null);
    try store.commit(turn);
    turn = try store.capture();
    turn.delivery.input.origin = .{ .external = .{ .principal = 42, .policy_revision = 1 } };
    frame.payload = try p.Value.init("UQP2truncated");
    turn.delivery.input.value = try frame.encode();
    try handler.handle(handler.context, &turn, frame);
    try t.expectEqualStrings("InvalidQueryUpload", (try turn.read(r.key('e', turn.delivery.input.position, 0))).?.slice());
    try store.commit(turn);
    turn = try store.capture();
    turn.delivery.input.origin = .{ .external = .{ .principal = 42, .policy_revision = 1 } };
    frame.payload = try (request.Command{ .begin = ref }).encode();
    turn.delivery.input.value = try frame.encode();
    try handler.handle(handler.context, &turn, frame);
    try t.expectEqual(@as(usize, 4), writes(turn));
    try store.commit(turn);
    turn = try store.capture();
    requester.principal = 43;
    try t.expectError(error.QueryConfigurationChanged, handler.handle(handler.context, &turn, frame));
}

test "independent upload frames preserve full-width namespace and strict status bytes" {
    const Fixture = struct { commands: []const struct { kind: []const u8, wire_hex: []const u8 }, status_hex: []const u8 };
    const parsed = try std.json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/uploads.json"), .{});
    defer parsed.deinit();
    for (parsed.value.commands) |command| {
        var buffer: [s.Frame.max_payload]u8 = undefined;
        const encoded = try p.Value.init(try std.fmt.hexToBytes(&buffer, command.wire_hex));
        const decoded = try request.Command.decode(&encoded);
        try t.expectEqualStrings(command.kind, @tagName(decoded));
        try t.expect((try decoded.encode()).eql(encoded));
        _ = try (s.Frame{ .kind = .cast, .payload = encoded }).encode();
    }
    var buffer: [p.Value.max_bytes]u8 = undefined;
    const encoded = try p.Value.init(try std.fmt.hexToBytes(&buffer, parsed.value.status_hex));
    const decoded = try request.Status.decode(encoded);
    try t.expectEqual(std.math.maxInt(u64), decoded.reference.namespace);
    try t.expectEqual(.uploading, decoded.phase);
    try t.expectEqual(@as(u16, 83), encoded.len);
    try t.expect((try decoded.encode()).eql(encoded));
}

test "finite query waits bind the earliest lifetime and authenticated timeout releases admission" {
    for ([_][2]?u64{ .{ null, 150 }, .{ 100, 150 }, .{ 150, 100 }, .{ 100, null } }) |limits| {
        var store: Store = .{ .resource = 8, .pid = 9 };
        defer store.deinit();
        var bundle = fixture();
        bundle.plan.predicate = .all;
        var bytes: [q.Bundle.max_bytes]u8 = undefined;
        const encoded = try bundle.encode(&bytes);
        const ref = try bundle.reference(8, 1);
        var turn = try store.capture();
        try upload.begin(&turn, ref);
        try store.commit(turn);
        try stage(&store, ref, encoded);
        turn = try store.capture();
        try upload.seal(&turn, 1);
        try store.commit(turn);
        turn = try store.capture();
        turn.delivery.work_before_ms = limits[0];
        turn.resource_deadline_ms = limits[1];
        const before = turn.decision;
        try t.expectError(error.InvalidTimerObserver, upload.submit(&turn, 1, 3));
        try t.expectEqualDeep(before, turn.decision);
        const correlation = try upload.submitWithObserver(&turn, 1, 3, 42);
        const wait = (try turn.waiting(correlation)).?;
        try t.expectEqual(@as(?u64, if (limits[0] == null) 150 else 100), wait.deadline_ms);
        try t.expectEqual(@as(?u64, 42), wait.observer);
        try store.commit(turn);
        turn = try store.capture();
        const frame = try s.Waiting.observation(correlation, wait.deadline_ms.?);
        try t.expectError(error.UnexpectedTimerObserver, s.Waiting.dispatch(&turn, frame));
        turn.delivery.input.origin = .{ .external = .{ .principal = 42, .policy_revision = 1 } };
        try t.expect(!try s.Waiting.dispatch(&turn, frame));
        try t.expectEqual(@as(u64, 1), try upload.timeout(&turn, correlation));
        try store.commit(turn);
        turn = try store.capture();
        try t.expectEqual(.cancelled, (try upload.status(&turn, 1)).?.phase);
        turn.delivery.input.origin = .{ .external = .{ .principal = 42, .policy_revision = 1 } };
        try t.expect(try s.Waiting.dispatch(&turn, frame));
        try cleanup(&store, ref);
    }
}
