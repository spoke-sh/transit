const std = @import("std");
const t = std.testing;
const p = @import("transit_client").protocol;
const Turn = @import("Turn.zig");
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
        const pubn = try Pub.create(&turn, .application, std.math.maxInt(u64), policy);
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
    const key = Pub.key(.application, std.math.maxInt(u64), 'c', std.math.maxInt(u64), std.math.maxInt(u32));
    try t.expectEqual(@as(u16, 27), key.len);
    try t.expectEqual(@as(u64, std.math.maxInt(u64)), std.mem.readInt(u64, key.data[6..14], .big));
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
    try t.expectError(error.InvalidPublicationLimits, Pub.create(&turn, .application, 3, .{ .record_bytes = 20, .staging_bytes = 10, .staging_records = 1 }));
    try t.expectError(error.PublicationLimitsChanged, Pub.create(&turn, .application, pubn.namespace, .{ .record_bytes = 1, .staging_bytes = 1, .staging_records = 1 }));
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
    const location = Pub.key(pubn.domain, pubn.namespace, 'c', 1, 1);
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
    try t.expect(store.state.get(Pub.key(pubn.domain, pubn.namespace, 'c', 1, 0)) == null);
    var captured = try historical.capture();
    try verify(pubn, &captured, 1, &bytes);
}

test "upload marker encodes the current domain namespace and frozen digest" {
    const Upload = @import("PublicationUpload.zig");
    const frozen = try p.Value.init("abc");
    const actual = try Upload.marker(.application, 0x0102030405060708, frozen);
    // Independent little-endian coordinates and the SHA-256 abc test vector.
    var bytes: [48]u8 = undefined;
    _ = try std.fmt.hexToBytes(&bytes, "53505531010000000807060504030201ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
    try t.expectEqualSlices(u8, &bytes, actual.slice());
    try t.expectError(error.InvalidPublicationUpload, Upload.marker(@fromBackingInt(@intCast(0)), 1, frozen));
    try t.expectError(error.InvalidPublicationUpload, Upload.marker(.application, 0, frozen));
    try t.expectError(error.InvalidPublicationUpload, Upload.marker(.application, 1, try p.Value.init("")));
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
    const input: Upload.Input = .{ .domain = .application, .namespace = std.math.maxInt(u64), .identity_key = try p.Value.init("upload"), .identity = try p.Value.init("bound-metadata-and-body-v1"), .limits = limits, .records = &records };
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
    try t.expect(store.state.get(input.identity_key).?.eql(try Upload.marker(input.domain, input.namespace, input.identity)));
    var turn = try store.capture();
    const publication: Pub = .{ .domain = .application, .resource = 7, .namespace = input.namespace };
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
        .domain = .application,
        .namespace = 1,
        .identity_key = try p.Value.init("upload"),
        .identity = try p.Value.init("frozen"),
        .limits = limits,
        .records = &.{.{ .id = 1, .bytes = "", .spec = try Pub.Digest.of(1, "") }},
    }));
    try t.expectEqualDeep(before, turn.decision);
}

const ReferenceSource = struct {
    store: *Store,
    opens: usize = 0,
    deny_at: ?usize = null,
    pub fn open(self: *@This(), resource: u64) !Turn {
        if (resource != 7) return error.AccessDenied;
        self.opens += 1;
        if (self.deny_at == self.opens) return error.AccessDenied;
        // Fresh current cuts can change while immutable content remains stable.
        self.store.revision += 1;
        return self.store.capture();
    }
};
test "publication references verify finite bodies across current cuts and deny before during and after copy" {
    const Ref = @import("PublicationReference.zig");
    var store: Store = .{};
    defer store.deinit();
    const pubn = try store.create(limits);
    var body: [657]u8 = undefined;
    for (&body, 0..) |*byte, i| byte.* = @truncate(i * 19);
    const reference: Ref = .{ .domain = .application, .resource = 7, .namespace = pubn.namespace, .record = 17, .spec = try store.stage(pubn, 17, &body) };
    try publish(&store, pubn, 17);
    const encoded = try reference.encode();
    try t.expectEqualDeep(reference, try Ref.decode(encoded));
    for (0..encoded.len) |len| try t.expectError(error.InvalidPublicationReference, Ref.decode(try p.Value.init(encoded.slice()[0..len])));
    var source: ReferenceSource = .{ .store = &store };
    var output: [657]u8 = undefined;
    try t.expectEqualSlices(u8, &body, try reference.read(&source, &output));
    try t.expectEqual(@as(usize, 4), source.opens);
    for (1..5) |denied| {
        source = .{ .store = &store, .deny_at = denied };
        try t.expectError(error.AccessDenied, reference.read(&source, &output));
    }
    source = .{ .store = &store };
    try t.expectError(error.PublicationBufferTooSmall, reference.read(&source, output[0..656]));
    try t.expectEqual(@as(usize, 0), source.opens);
    var wrong = reference;
    wrong.spec.digest[0] ^= 1;
    try t.expectError(error.PublicationReferenceChanged, wrong.read(&source, &output));
    const chunk = Pub.key(pubn.domain, pubn.namespace, 'c', 17, 1);
    const original = store.state.get(chunk).?;
    var corrupt = original;
    corrupt.data[1] ^= 1;
    try store.state.put(t.allocator, chunk, corrupt);
    try t.expectError(error.InvalidPublicationDigest, reference.read(&source, &output));
    try store.state.put(t.allocator, chunk, original);
    var turn = try store.capture();
    _ = try pubn.retire(&turn, 17);
    try store.commit(turn);
    try t.expectError(error.PublicationNotPublished, reference.read(&source, &output));
    const empty: Ref = .{ .domain = .application, .resource = 7, .namespace = pubn.namespace, .record = 18, .spec = try store.stage(pubn, 18, "") };
    try publish(&store, pubn, 18);
    source = .{ .store = &store, .deny_at = 2 };
    try t.expectError(error.AccessDenied, empty.read(&source, &.{}));
}

const BatchedReferenceSource = struct {
    base: ReferenceSource,
    unavailable: bool = false,
    largest: usize = 0,
    const Batch = struct {
        view: struct { id: u64 = 0, resource: u64, revision: u64 },
        keys: [p.Growth.page_size]?p.Value = @splat(null),
        values: [p.Growth.page_size]?p.Value = @splat(null),
        pub fn read(self: *@This(), address: p.Value) !?p.Value {
            for (self.keys, self.values) |key, value| if (key) |present| {
                if (present.eql(address)) return value;
            };
            return error.UnrequestedResourceKey;
        }
    };
    pub fn open(self: *@This(), resource: u64) !Turn {
        return self.base.open(resource);
    }
    pub fn readBatch(self: *@This(), resource: u64, revision: ?u64, keys: []const p.Value) !Batch {
        if (self.unavailable) return error.ResourceReadBatchUnavailable;
        try t.expect(revision == null);
        try t.expect(keys.len <= p.Growth.page_size);
        self.largest = @max(self.largest, keys.len);
        var reader = try self.open(resource);
        var result: Batch = .{ .view = .{ .resource = resource, .revision = reader.view.revision } };
        for (keys, 0..) |key, i| {
            result.keys[i] = key;
            result.values[i] = try reader.read(key);
        }
        return result;
    }
};
test "batched immutable reads preserve point-read commitments, current denial and final authorization" {
    const Ref = @import("PublicationReference.zig");
    var store: Store = .{};
    defer store.deinit();
    const pubn = try store.create(limits);
    var body: [4097]u8 = undefined;
    for (&body, 0..) |*byte, i| byte.* = @truncate(i * 19);
    const reference: Ref = .{ .domain = .application, .resource = 7, .namespace = pubn.namespace, .record = 17, .spec = try store.stage(pubn, 17, &body) };
    try publish(&store, pubn, 17);
    var source: BatchedReferenceSource = .{ .base = .{ .store = &store } };
    var output: [body.len]u8 = undefined;
    try t.expectEqualSlices(u8, &body, try reference.read(&source, &output));
    try t.expectEqual(@as(usize, 4), source.base.opens); // three groups and final access
    try t.expectEqual(@as(usize, 8), source.largest);
    for (1..5) |denied| {
        source = .{ .base = .{ .store = &store, .deny_at = denied } };
        try t.expectError(error.AccessDenied, reference.read(&source, &output));
    }
    source = .{ .base = .{ .store = &store }, .unavailable = true };
    try t.expectEqualSlices(u8, &body, try reference.read(&source, &output));
    try t.expectEqual(@as(usize, 18), source.base.opens); // unchanged older-host path
    source = .{ .base = .{ .store = &store } };
    const chunk = Pub.key(pubn.domain, pubn.namespace, 'c', 17, 8);
    const original = store.state.get(chunk).?;
    _ = store.state.remove(chunk);
    try t.expectError(error.MissingPublicationChunk, reference.read(&source, &output));
    var corrupt = original;
    corrupt.data[0] ^= 1;
    try store.state.put(t.allocator, chunk, corrupt);
    try t.expectError(error.InvalidPublicationDigest, reference.read(&source, &output));
    try store.state.put(t.allocator, chunk, original);
    var wrong = reference;
    wrong.spec.digest[0] ^= 1;
    try t.expectError(error.PublicationReferenceChanged, wrong.read(&source, &output));
    var turn = try store.capture();
    _ = try pubn.retire(&turn, 17);
    try store.commit(turn);
    try t.expectError(error.PublicationNotPublished, reference.read(&source, &output));
    const empty: Ref = .{ .domain = .application, .resource = 7, .namespace = pubn.namespace, .record = 18, .spec = try store.stage(pubn, 18, "") };
    try publish(&store, pubn, 18);
    source = .{ .base = .{ .store = &store, .deny_at = 2 } };
    try t.expectError(error.AccessDenied, empty.read(&source, &.{}));
}

test "domains isolate equal full-width identities, budgets, cleanup and cursors" {
    const Ref = @import("PublicationReference.zig");
    var store: Store = .{};
    defer store.deinit();
    var turn = try store.capture();
    const mutations = try Pub.create(&turn, .table_mutation, std.math.maxInt(u64), .{ .record_bytes = 5, .staging_bytes = 5, .staging_records = 1 });
    const results = try Pub.create(&turn, .query_result, std.math.maxInt(u64), .{ .record_bytes = 6, .staging_bytes = 6, .staging_records = 1 });
    try store.commit(turn);
    const mutation_spec = try store.stage(mutations, 1, "write");
    _ = try store.stage(results, 1, "result");
    try publish(&store, results, 1);
    turn = try store.capture();
    try t.expectEqual(@as(u64, 5), (try mutations.budget(&turn)).bytes);
    try t.expectEqual(@as(u64, 0), (try results.budget(&turn)).bytes);
    try t.expectError(error.PublicationQuotaExceeded, mutations.begin(&turn, 2, try Pub.Digest.of(7, "x")));
    try publish(&store, mutations, 1);
    turn = try store.capture();
    const cursor = try mutations.open(&turn, 1);
    try t.expectError(error.StalePublicationCursor, results.read(&turn, cursor));
    try verify(mutations, &turn, 1, "write");
    try verify(results, &turn, 1, "result");
    _ = try mutations.retire(&turn, 1);
    try store.commit(turn);
    turn = try store.capture();
    try t.expect(try mutations.collect(&turn, 1));
    try store.commit(turn);
    turn = try store.capture();
    try verify(results, &turn, 1, "result");
    try t.expectError(error.PublicationClosed, mutations.begin(&turn, 1, mutation_spec));
    try t.expectError(error.InvalidPublicationIdentity, Pub.create(&turn, @fromBackingInt(0), 1, limits));
    const reference: Ref = .{ .resource = 7, .domain = .table_mutation, .namespace = mutations.namespace, .record = 1, .spec = mutation_spec };
    var encoded = try reference.encode();
    try t.expectEqual(@as(u16, 72), encoded.len);
    try t.expectEqualSlices(u8, &.{ 4, 0, 0, 0 }, encoded.data[12..16]);
    try t.expectEqualSlices(u8, &.{ 0, 0, 0, 4 }, Pub.key(.table_mutation, 1, 'r', 1, 0).data[2..6]);
    var old: [68]u8 = undefined;
    @memcpy(old[0..12], encoded.data[0..12]);
    @memcpy(old[12..], encoded.data[16..72]);
    try t.expectError(error.InvalidPublicationReference, Ref.decode(try p.Value.init(&old)));
    @memset(encoded.data[12..16], 0);
    try t.expectError(error.InvalidPublicationReference, Ref.decode(encoded));
}

test "upload identity rejects changing domains or namespaces before staging" {
    const Upload = @import("PublicationUpload.zig");
    var store: Store = .{};
    defer store.deinit();
    const records = [_]Upload.Record{.{ .id = 1, .bytes = "body", .spec = try Pub.Digest.of(7, "body") }};
    var input: Upload.Input = .{ .domain = .application, .namespace = 1, .identity_key = try p.Value.init("owner"), .identity = try p.Value.init("frozen"), .limits = limits, .records = &records };
    var turn = try store.capture();
    try t.expect(!try Upload.step(&turn, input));
    try store.commit(turn);
    turn = try store.capture();
    input.domain = .query_result;
    try t.expectError(error.PublicationUploadIdentityConflict, Upload.step(&turn, input));
    input.domain = .application;
    input.namespace = 2;
    try t.expectError(error.PublicationUploadIdentityConflict, Upload.step(&turn, input));
    for (turn.decision.mutations) |slot| try t.expectEqual(null, slot);
}
