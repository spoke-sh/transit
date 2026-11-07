const std = @import("std");
const t = std.testing;
const runtime = @import("fixture_runtime.zig");
const root = @import("root.zig");
const x = root.http.exchange;
const p = x.p;
const Exchange = x.Exchange;
const Turn = x.station.Turn;
const Pub = x.Publication;
const Map = std.AutoHashMapUnmanaged(p.Value, p.Value);
pub const Store = struct {
    state: Map = .empty,
    revision: u64 = 1,
    input: u64 = 1,
    reads: usize = 0,
    fail_read: bool = false,
    wal: ?*root.data.catalog.storage.LocalWal.LocalWal = null,
    next_lsn: u64 = 0,
    const Record = struct { definition: p.Growth.Definition, revision: u64, input: u64, mutations: @FieldType(@FieldType(Turn, "decision"), "mutations") };
    pub fn reopen(wal: *root.data.catalog.storage.LocalWal.LocalWal) !Store {
        var self: Store = .{ .wal = wal };
        errdefer self.deinit();
        var scratch: std.heap.ArenaAllocator = .init(runtime.allocator());
        defer scratch.deinit();
        while (true) {
            _ = scratch.reset(.retain_capacity);
            var batch = try wal.log().read(runtime.allocator(), 1, self.next_lsn, 1);
            defer batch.deinit();
            if (batch.frames.len == 0) break;
            const frame = batch.frames[0];
            const record = (try p.Json.parseFromSlice(Record, scratch.allocator(), frame.payload)).value;
            if (record.definition != p.Growth.current_definition or record.revision != self.revision + 1 or frame.header.kind != .process_turn) return error.InvalidFixtureJournal;
            for (record.mutations) |slot| if (slot) |mutation| {
                if (mutation.value) |value| try self.state.put(runtime.allocator(), mutation.key, value) else _ = self.state.remove(mutation.key);
            };
            self.revision = record.revision;
            self.input = record.input;
            self.next_lsn = frame.header.lsn + 1;
        }
        return self;
    }
    pub fn deinit(self: *Store) void {
        self.state.deinit(runtime.allocator());
    }
    pub fn capture(self: *Store) !Turn {
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
    pub fn commit(self: *Store, turn: Turn) !void {
        try turn.validate();
        if (self.wal) |wal| {
            const bytes = try p.Json.valueAllocBounded(runtime.allocator(), Record{ .definition = p.Growth.current_definition, .revision = self.revision + 1, .input = self.input, .mutations = turn.decision.mutations }, 16 * 1024);
            defer runtime.allocator().free(bytes);
            const accepted = try wal.log().append(1, self.next_lsn, 1, 1, .process_turn, bytes);
            self.next_lsn = accepted.next_lsn;
        }
        for (turn.decision.mutations) |slot| if (slot) |mutation| {
            if (mutation.value) |value| try self.state.put(runtime.allocator(), mutation.key, value) else _ = self.state.remove(mutation.key);
        };
        self.revision += 1;
    }
    fn create(self: *Store, policy: Pub.Limits) !Pub {
        var turn = try self.capture();
        const pubn = try Pub.create(&turn, .exchange, std.math.maxInt(u64), policy);
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
pub fn segment(store: *Store, ex: Exchange, ordinal: u32, kind: u32, bytes: []const u8) !void {
    const spec = try Pub.Digest.of(1, bytes);
    var turn = try store.capture();
    _ = try ex.beginSegment(&turn, ordinal, kind, spec);
    try store.commit(turn);
    for (0..spec.chunks()) |i| {
        turn = try store.capture();
        _ = try ex.append(&turn, ordinal, @intCast(i), bytes[i * 256 ..][0..try spec.size(@intCast(i))]);
        try store.commit(turn);
    }
    turn = try store.capture();
    try t.expectEqual(.changed, try ex.sealSegment(&turn, ordinal));
    for (turn.decision.mutations) |slot| try t.expect(slot != null);
    try store.commit(turn);
}
