const std = @import("std");
const t = std.testing;
const p = @import("transit_client").protocol;
const Turn = @import("Turn.zig").Growing;
const Pub = @import("Publication.zig");
const Map = std.AutoHashMapUnmanaged(p.Value, p.Value);
const Store = struct {
    state: Map = .empty,
    revision: u64 = 1,
    input: u64 = 1,
    reads: usize = 0,
    fail_read: bool = false,
    fn deinit(self: *Store) void {
        self.state.deinit(t.allocator);
    }
    fn capture(self: *Store) !Turn {
        self.input += 1;
        self.reads = 0;
        return Turn.init(.{ .realm = 1, .principal = 65536, .pid = 2, .generation = 3, .sequence = self.input, .revision = self.revision, .input = .{ .position = self.input, .ordinal = self.input, .value = .{}, .origin = .{ .external = .{ .principal = 0, .policy_revision = 0 } } }, .permit = null, .needs_permit = false }, .{ .id = self.input + 1000, .pid = 2, .principal = 65536, .generation = 3, .input = self.input, .process_revision = self.revision, .resource = 7, .revision = self.revision, .deadline_ms = 10000 }, .{ .context = self, .read = read });
    }
    fn read(raw: *anyopaque, _: p.Growth.View, key: p.Value) !?p.Value {
        const self: *Store = @ptrCast(@alignCast(raw));
        self.reads += 1;
        if (self.fail_read) return error.Unavailable;
        return self.state.get(key);
    }
    fn commit(self: *Store, turn: Turn) !void {
        try turn.validate();
        for (turn.decision.mutations) |slot| if (slot) |mutation| {
            if (mutation.value) |value| try self.state.put(t.allocator, mutation.key, value) else _ = self.state.remove(mutation.key);
        };
        self.revision += 1;
    }
    fn create(self: *Store, policy: Pub.Limits) !Pub {
        var turn = try self.capture();
        const pubn = try Pub.create(&turn, std.math.maxInt(u64), policy);
        try self.commit(turn);
        return pubn;
    }
    fn stage(self: *Store, pubn: Pub, id: u64, bytes: []const u8) !Pub.Spec {
        const spec = try Pub.Digest.of(7, bytes);
        var turn = try self.capture();
        try t.expectEqual(.changed, try pubn.begin(&turn, id, spec));
        try self.commit(turn);
        for (0..spec.chunks()) |i| {
            turn = try self.capture();
            const part = bytes[i * Pub.chunk_bytes ..][0..try spec.size(@intCast(i))];
            try t.expectEqual(.changed, try pubn.append(&turn, id, @intCast(i), part));
            try t.expectEqual(.duplicate, try pubn.append(&turn, id, @intCast(i), part));
            try t.expect(self.reads <= 3);
            try self.commit(turn);
        }
        return spec;
    }
};
const limits: Pub.Limits = .{ .record_bytes = 65536, .staging_bytes = 131072, .staging_records = 2 };
fn publish(store: *Store, pubn: Pub, id: u64) !void {
    var turn = try store.capture();
    try t.expectEqual(.changed, try pubn.publish(&turn, id));
    try turn.put(try p.Value.init("head"), p.Value.integer(@intCast(id)));
    try turn.cast(3, try p.Value.init("accepted"));
    try t.expectEqual(.duplicate, try pubn.publish(&turn, id));
    try store.commit(turn);
}
fn verify(pubn: Pub, source: anytype, id: u64, bytes: []const u8) !void {
    var cursor = try pubn.open(source, id);
    var offset: usize = 0;
    while (true) {
        const part = try pubn.read(source, cursor);
        try t.expectEqualSlices(u8, bytes[offset..][0..part.bytes.len], part.bytes.slice());
        offset += part.bytes.len;
        cursor = part.next orelse break;
    }
    try t.expectEqual(bytes.len, offset);
}

test "publication grows beyond snapshots, binds final head/output and streams 64 KiB with fixed work" {
    var store: Store = .{};
    defer store.deinit();
    const pubn = try store.create(limits);
    var bytes: [65536]u8 = undefined;
    for (&bytes, 0..) |*b, i| b.* = @truncate(i * 37 + 11);
    const spec = try store.stage(pubn, 1, &bytes);
    var turn = try store.capture();
    try t.expectError(error.PublicationNotPublished, pubn.open(&turn, 1));
    try t.expectEqual(.duplicate, try pubn.begin(&turn, 1, spec));
    try publish(&store, pubn, 1);
    turn = try store.capture();
    try verify(pubn, &turn, 1, &bytes);
    try t.expectEqual(@as(u64, 0), (try pubn.budget(&turn)).bytes);
    for (2..43) |id| {
        _ = try store.stage(pubn, id, "retained");
        try publish(&store, pubn, id);
    }
    try t.expect(store.state.count() > 256 + 32);
    turn = try store.capture();
    try verify(pubn, &turn, 1, &bytes);
    try t.expectEqual(@as(u32, 0), (try pubn.budget(&turn)).records);
    try t.expectEqualStrings("42", store.state.get(try p.Value.init("head")).?.slice());
}

test "strict layout, full-width keys, fixed independent digest fixtures and empty completion" {
    const Fixture = struct { format: u32, length: u32, digest: []const u8 };
    const parsed = try std.json.parseFromSlice([]Fixture, t.allocator, @embedFile("fixtures/publication.json"), .{});
    defer parsed.deinit();
    var body: [65536]u8 = undefined;
    for (&body, 0..) |*b, i| b.* = @truncate(i * 37 + 11);
    for (parsed.value) |fixture| {
        const spec = try Pub.Digest.of(fixture.format, body[0..fixture.length]);
        var expected: [32]u8 = undefined;
        _ = try std.fmt.hexToBytes(&expected, fixture.digest);
        try t.expectEqualSlices(u8, &expected, &spec.digest);
    }
    const key = Pub.key(std.math.maxInt(u64), 'c', std.math.maxInt(u64), std.math.maxInt(u32));
    try t.expectEqual(@as(u16, 23), key.len);
    try t.expectEqual(@as(u64, std.math.maxInt(u64)), std.mem.readInt(u64, key.data[2..10], .big));
    var store: Store = .{};
    defer store.deinit();
    const pubn = try store.create(limits);
    const spec = try store.stage(pubn, 1, "");
    try publish(&store, pubn, 1);
    var turn = try store.capture();
    try verify(pubn, &turn, 1, "");
    const descriptor = try pubn.inspect(&turn, 1);
    const encoded = try descriptor.encode();
    try t.expect(std.meta.eql(descriptor, try Pub.Descriptor.decode(encoded)));
    for (0..encoded.len) |len| try t.expectError(error.InvalidPublicationDescriptor, Pub.Descriptor.decode(try p.Value.init(encoded.slice()[0..len])));
    for ([_]usize{ 0, 4, 5, 6, 7, 16, 20, 56 }) |offset| {
        var bad = encoded;
        bad.data[offset] = 255;
        try t.expectError(error.InvalidPublicationDescriptor, Pub.Descriptor.decode(bad));
    }
    try t.expectError(error.InvalidPublicationIdentity, pubn.begin(&turn, 0, spec));
    try t.expectError(error.InvalidPublicationFormat, Pub.Digest.of(0, "hello"));
    try t.expectError(error.InvalidPublicationLimits, Pub.create(&turn, 3, .{ .record_bytes = 20, .staging_bytes = 10, .staging_records = 1 }));
    try t.expectError(error.PublicationLimitsChanged, Pub.create(&turn, pubn.namespace, .{ .record_bytes = 1, .staging_bytes = 1, .staging_records = 1 }));
}

test "staging reserves declared bytes and slots until publish or completed explicit abandonment" {
    var store: Store = .{};
    defer store.deinit();
    const pubn = try store.create(.{ .record_bytes = 512, .staging_bytes = 512, .staging_records = 2 });
    var turn = try store.capture();
    const spec = try Pub.Digest.of(1, &@as([512]u8, @splat(7)));
    const empty = try Pub.Digest.of(1, "");
    _ = try pubn.begin(&turn, 1, spec);
    try t.expectError(error.PublicationQuotaExceeded, pubn.begin(&turn, 2, try Pub.Digest.of(1, "x")));
    _ = try pubn.begin(&turn, 2, empty);
    try t.expectError(error.PublicationQuotaExceeded, pubn.begin(&turn, 3, empty));
    try t.expectError(error.PublicationTooLarge, pubn.begin(&turn, 3, try Pub.Digest.of(1, &@as([513]u8, @splat(0)))));
    try store.commit(turn);
    turn = try store.capture();
    _ = try pubn.append(&turn, 1, 0, &@as([256]u8, @splat(7)));
    _ = try pubn.abandon(&turn, 1);
    try t.expectError(error.PublicationQuotaExceeded, pubn.begin(&turn, 3, empty));
    try store.commit(turn);
    turn = try store.capture();
    try t.expect(try pubn.collect(&turn, 1));
    try store.commit(turn);
    turn = try store.capture();
    try t.expectEqual(@as(u64, 0), (try pubn.budget(&turn)).bytes);
    try t.expectEqual(@as(u32, 1), (try pubn.budget(&turn)).records);
    try t.expect(try pubn.collect(&turn, 1));
    try t.expectError(error.PublicationClosed, pubn.begin(&turn, 1, spec));
    try t.expectError(error.PublicationClosed, pubn.append(&turn, 1, 0, &@as([256]u8, @splat(7))));
    try t.expectError(error.PublicationClosed, pubn.publish(&turn, 1));
    try t.expectError(error.PublicationNotPublished, pubn.retire(&turn, 1));
    _ = try pubn.abandon(&turn, 2);
    try t.expect(try pubn.collect(&turn, 2));
    try store.commit(turn);
    turn = try store.capture();
    try t.expectEqual(@as(u32, 0), (try pubn.budget(&turn)).records);
}

fn fill(turn: *Turn, count: usize) !void {
    for (0..count) |i| try turn.put(p.Value.integer(@intCast(i)), .{});
}
test "failed multi-key operations roll back private decisions and keep read failures sticky" {
    var store: Store = .{};
    defer store.deinit();
    const pubn = try store.create(limits);
    const spec = try Pub.Digest.of(1, &@as([512]u8, @splat(1)));
    var turn = try store.capture();
    try fill(&turn, 3);
    const before = turn.decision;
    try t.expectError(error.MutationBudgetExceeded, pubn.begin(&turn, 1, spec));
    try t.expect(std.meta.eql(before, turn.decision));
    turn = try store.capture();
    _ = try pubn.begin(&turn, 1, spec);
    try store.commit(turn);
    turn = try store.capture();
    try fill(&turn, 3);
    const before_append = turn.decision;
    try t.expectError(error.MutationBudgetExceeded, pubn.append(&turn, 1, 0, &@as([256]u8, @splat(1))));
    try t.expect(std.meta.eql(before_append, turn.decision));
    turn = try store.capture();
    _ = try pubn.append(&turn, 1, 0, &@as([256]u8, @splat(1)));
    _ = try pubn.append(&turn, 1, 1, &@as([256]u8, @splat(1)));
    try store.commit(turn);
    turn = try store.capture();
    try fill(&turn, 3);
    const before_publish = turn.decision;
    try t.expectError(error.MutationBudgetExceeded, pubn.publish(&turn, 1));
    try t.expect(std.meta.eql(before_publish, turn.decision));
    turn = try store.capture();
    _ = try pubn.abandon(&turn, 1);
    try store.commit(turn);
    turn = try store.capture();
    try fill(&turn, 1);
    const before_collect = turn.decision;
    try t.expectError(error.MutationBudgetExceeded, pubn.collect(&turn, 1));
    try t.expect(std.meta.eql(before_collect, turn.decision));
    store.fail_read = true;
    try t.expectError(error.Unavailable, pubn.collect(&turn, 1));
    try t.expect(std.meta.eql(before_collect, turn.decision));
    try t.expectError(error.Unavailable, turn.validate());
}

test "incomplete, out of order and identity-conflicting content cannot publish" {
    var store: Store = .{};
    defer store.deinit();
    const pubn = try store.create(limits);
    const bytes: [513]u8 = @splat('x');
    const spec = try Pub.Digest.of(1, &bytes);
    var turn = try store.capture();
    _ = try pubn.begin(&turn, 1, spec);
    try store.commit(turn);
    turn = try store.capture();
    try t.expectError(error.IncompletePublication, pubn.publish(&turn, 1));
    try t.expectError(error.PublicationGap, pubn.append(&turn, 1, 1, bytes[256..512]));
    try t.expectError(error.InvalidPublicationChunk, pubn.append(&turn, 1, 0, "x"));
    try t.expectError(error.PublicationIdentityConflict, pubn.begin(&turn, 1, try Pub.Digest.of(2, &bytes)));
    try t.expectError(error.PublicationNotClosed, pubn.collect(&turn, 1));
    _ = try pubn.append(&turn, 1, 0, bytes[0..256]);
    try store.commit(turn);
    turn = try store.capture();
    try t.expectError(error.PublicationIdentityConflict, pubn.append(&turn, 1, 0, &@as([256]u8, @splat('y'))));
    _ = try pubn.append(&turn, 1, 1, bytes[256..512]);
    _ = try pubn.append(&turn, 1, 2, "z"); // Wrong commitment: explicitly abandonable, never published.
    try store.commit(turn);
    turn = try store.capture();
    try t.expectError(error.InvalidPublicationDigest, pubn.publish(&turn, 1));
    try t.expectError(error.PublicationNotPublished, pubn.open(&turn, 1));
    for (turn.decision.mutations) |slot| try t.expect(slot == null);
}

test "stream prefixes are provisional, reject corrupt/missing data and mixed source continuations" {
    var store: Store = .{};
    defer store.deinit();
    const pubn = try store.create(limits);
    _ = try store.stage(pubn, 1, &@as([257]u8, @splat(9)));
    try publish(&store, pubn, 1);
    var turn = try store.capture();
    const cursor = try pubn.open(&turn, 1);
    const first = try pubn.read(&turn, cursor);
    try t.expect(first.next != null);
    var other = try store.capture();
    try t.expectError(error.StalePublicationCursor, pubn.read(&other, first.next.?));
    var wrong = first.next.?;
    wrong.basis.revision += 1;
    try t.expectError(error.StalePublicationCursor, pubn.read(&turn, wrong));
    const location = Pub.key(pubn.namespace, 'c', 1, 1);
    const old = store.state.get(location).?;
    _ = store.state.remove(location);
    try t.expectError(error.MissingPublicationChunk, pubn.read(&turn, first.next.?));
    try store.state.put(t.allocator, location, try p.Value.init("x"));
    try t.expectError(error.InvalidPublicationDigest, pubn.read(&turn, first.next.?));
    try store.state.put(t.allocator, location, old);
    try t.expect((try pubn.read(&turn, first.next.?)).next == null);
    try fill(&turn, 1);
    try t.expectError(error.PublicationReadAfterMutation, pubn.open(&turn, 1));
    try t.expectError(error.PublicationReadAfterMutation, pubn.read(&turn, first.next.?));
    var foreign = pubn;
    foreign.resource += 1;
    try t.expectError(error.CrossResourceTransaction, foreign.inspect(&other, 1));
}

test "bounded cleanup retains permanent identities and a captured historical root still reads" {
    var store: Store = .{};
    defer store.deinit();
    const pubn = try store.create(limits);
    const bytes: [777]u8 = @splat(42);
    const spec = try store.stage(pubn, 1, &bytes);
    try publish(&store, pubn, 1);
    var historical: Store = .{};
    defer historical.deinit();
    var entries = store.state.iterator();
    while (entries.next()) |entry| try historical.state.put(t.allocator, entry.key_ptr.*, entry.value_ptr.*);
    var turn = try store.capture();
    _ = try pubn.retire(&turn, 1);
    try store.commit(turn);
    turn = try store.capture();
    try t.expectError(error.PublicationNotPublished, pubn.open(&turn, 1));
    try t.expect(!try pubn.collect(&turn, 1));
    try store.commit(turn);
    turn = try store.capture();
    try t.expectEqual(@as(u32, 2), (try pubn.inspect(&turn, 1)).collected);
    try t.expect(try pubn.collect(&turn, 1));
    try store.commit(turn);
    turn = try store.capture();
    try t.expect(try pubn.collect(&turn, 1));
    try t.expectError(error.PublicationClosed, pubn.begin(&turn, 1, spec));
    try t.expect(store.state.get(Pub.key(pubn.namespace, 'c', 1, 0)) == null);
    var captured = try historical.capture();
    try verify(pubn, &captured, 1, &bytes);
}

test "paired upload keeps partial publication separate from admission and rejects changed identities" {
    const Upload = @import("PublicationUpload.zig");
    var store: Store = .{};
    defer store.deinit();
    const body: [513]u8 = @splat(0x7d);
    const records = [_]Upload.Record{
        .{ .id = 1, .bytes = "metadata", .spec = try Pub.Digest.of(2, "metadata") },
        .{ .id = 2, .bytes = &body, .spec = try Pub.Digest.of(2, &body) },
    };
    const input: Upload.Input = .{ .namespace = std.math.maxInt(u64), .identity_key = try p.Value.init("upload"), .identity = try p.Value.init("bound-metadata-and-body-v1"), .limits = limits, .records = &records };
    var steps: usize = 0;
    while (steps < 20) : (steps += 1) {
        var turn = try store.capture();
        const before = turn.decision;
        const ready = try Upload.step(&turn, input);
        try t.expect(store.reads <= 8);
        if (ready) {
            try t.expectEqualDeep(before, turn.decision);
            break;
        }
        try store.commit(turn);
    }
    try t.expect(steps > 2 and steps < 20);
    var turn = try store.capture();
    const publication: Pub = .{ .resource = 7, .namespace = input.namespace };
    try verify(publication, &turn, 1, "metadata");
    try verify(publication, &turn, 2, &body);
    var changed = input;
    changed.identity = try p.Value.init("different-frozen-request");
    turn = try store.capture();
    const before = turn.decision;
    try t.expectError(error.PublicationUploadIdentityConflict, Upload.step(&turn, changed));
    try t.expectEqualDeep(before, turn.decision);
    var changed_records = records;
    changed_records[1].bytes = "altered";
    changed.records = &changed_records;
    try t.expectError(error.InvalidPublicationUpload, Upload.step(&turn, changed));
    try t.expectEqualDeep(before, turn.decision);
    // Removing only the adapter marker cannot silently adopt old history.
    _ = store.state.remove(input.identity_key);
    turn = try store.capture();
    const before_adoption = turn.decision;
    try t.expectError(error.PublicationUploadNamespaceInUse, Upload.step(&turn, input));
    try t.expectEqualDeep(before_adoption, turn.decision);
}

test "upload initialization failure restores an already populated private decision" {
    const Upload = @import("PublicationUpload.zig");
    var store: Store = .{};
    defer store.deinit();
    var turn = try store.capture();
    try fill(&turn, 3);
    const before = turn.decision;
    try t.expectError(error.MutationBudgetExceeded, Upload.step(&turn, .{
        .namespace = 1,
        .identity_key = try p.Value.init("upload"),
        .identity = try p.Value.init("frozen"),
        .limits = limits,
        .records = &.{.{ .id = 1, .bytes = "", .spec = try Pub.Digest.of(1, "") }},
    }));
    try t.expectEqualDeep(before, turn.decision);
}
