const std = @import("std");
const t = std.testing;
const p = @import("transit_client").protocol;
const f = @import("transit_fuze");
const Turn = @import("Turn.zig");
const Pub = @import("Publication.zig");
const Index = @import("ImmutableIndex.zig");
const Data = @import("TableData.zig");
const Candidate = @import("TableCandidate.zig");
const Pages = @import("TablePages.zig");
const Head = @import("TableHead.zig");
const Store = struct {
    state: std.AutoHashMapUnmanaged(p.Value, p.Value) = .empty,
    revision: u64 = 1,
    input: u64 = 1,
    denied: bool = false,
    fn deinit(self: *Store) void {
        self.state.deinit(t.allocator);
    }
    fn capture(self: *Store) !Turn {
        self.input += 1;
        return Turn.init(.{ .realm = 1, .principal = 65536, .pid = 2, .generation = 3, .sequence = self.input, .revision = self.revision, .input = .{ .position = self.input, .ordinal = self.input, .value = .{}, .origin = .{ .external = .{ .principal = 0, .policy_revision = 0 } } }, .permit = null, .needs_permit = false }, .{ .id = self.input + 1000, .pid = 2, .principal = 65536, .generation = 3, .input = self.input, .process_revision = self.revision, .resource = 7, .revision = self.revision, .deadline_ms = 10000 }, .{ .context = self, .read = read, .page = page });
    }
    fn page(raw: *anyopaque, _: p.Growth.View, after: ?p.Value) !Turn.Page {
        const self: *Store = @ptrCast(@alignCast(raw));
        if (self.denied) return error.AccessDenied;
        var result: Turn.Page = .{};
        var cursor = after;
        for (&result.entries) |*slot| {
            var next: ?p.Growth.Entry = null;
            var entries = self.state.iterator();
            while (entries.next()) |entry| {
                const key = entry.key_ptr.*;
                if (cursor) |old| if (std.mem.order(u8, key.slice(), old.slice()) != .gt) continue;
                if (next) |found| if (std.mem.order(u8, key.slice(), found.key.slice()) != .lt) continue;
                next = .{ .key = key, .value = entry.value_ptr.*, .revision = self.revision };
            }
            slot.* = next;
            cursor = if (next) |found| found.key else return result;
        }
        result.next = cursor;
        return result;
    }
    fn read(raw: *anyopaque, _: p.Growth.View, key: p.Value) !?p.Value {
        const self: *Store = @ptrCast(@alignCast(raw));
        if (self.denied) return error.AccessDenied;
        return self.state.get(key);
    }
    fn commit(self: *Store, turn: Turn) !void {
        try turn.validate();
        for (turn.decision.mutations) |slot| if (slot) |mutation| {
            if (mutation.value) |value| try self.state.put(t.allocator, mutation.key, value) else _ = self.state.remove(mutation.key);
        };
        self.revision += 1;
    }
    fn create(self: *Store) !Pages {
        var turn = try self.capture();
        const pages = try Pages.create(&turn, 9, .{ .record_bytes = f.TableRow.max_bytes, .staging_bytes = f.TableRow.max_bytes * 2, .staging_records = 2 });
        try self.commit(turn);
        return pages;
    }
};
const schema: f.TableSchema.Schema = .{ .object = 9, .revision = 1, .next_column = 3, .columns = &.{
    .{ .id = 1, .name = "id", .type = .int64, .nullable = false },
    .{ .id = 2, .name = "value", .type = .utf8 },
}, .primary_key = &.{1} };
fn row(ordinal: u32, value: []const u8, cells: *[2]f.Types.Values.Cell) f.TableRow.Row {
    cells.* = .{ .{ .value = .{ .atom = .{ .signed = ordinal } } }, .{ .value = .{ .atom = .{ .bytes = value } } } };
    return .{ .identity = .{ .origin = 2, .operation = 20, .ordinal = ordinal }, .cells = cells };
}
fn writes(turn: Turn) usize {
    var count: usize = 0;
    for (turn.decision.mutations) |slot| count += @intFromBool(slot != null);
    return count;
}
fn flush(store: *Store, pages: Pages, overlay: anytype) !void {
    for (overlay.records.items) |record| if (record.reachable) {
        while (true) {
            var turn = try store.capture();
            const result = try pages.stage(&turn, .{ .id = record.id, .spec = record.spec }, record.bytes);
            try t.expect(writes(turn) <= 2);
            // A lost pre-commit turn must not advance immutable publication.
            var retry = try store.capture();
            const repeated = try pages.stage(&retry, .{ .id = record.id, .spec = record.spec }, record.bytes);
            try t.expectEqual(result, repeated);
            // The replacement input owns its own publication attribution.
            try t.expectEqual(writes(turn), writes(retry));
            try store.commit(retry);
            if (result == .ready) break;
        }
    };
}
test "small typed insert fits row, final index, head and outcome in one turn" {
    var store: Store = .{};
    defer store.deinit();
    const pages = try store.create();
    var turn = try store.capture();
    var reader: Pages.Reader(*Turn) = .{ .pages = pages, .source = &turn };
    var overlay = try Candidate.Overlay(*@TypeOf(reader)).init(t.allocator, &reader, 1, 1 + Candidate.max_records);
    defer overlay.deinit();
    var cells: [2]f.Types.Values.Cell = undefined;
    const data: Data = .{ .schema = schema };
    const changed = try data.insert(t.allocator, &overlay, row(1, "Ada", &cells));
    try t.expectEqual(@as(usize, 3), overlay.records.items.len);
    try t.expectEqual(@as(usize, 2), try overlay.finish(changed.data.index));
    for (overlay.records.items) |record| if (record.reachable) {
        try t.expect(record.bytes.len <= Pages.inline_bytes);
        try t.expectEqual(.ready, try pages.stage(&turn, .{ .id = record.id, .spec = record.spec }, record.bytes));
    };
    const head = try p.Value.init("test-head");
    const receipt = try p.Value.init("test-outcome");
    try turn.put(head, p.Value.integer(@intCast(changed.data.index.root.?.id)));
    try turn.put(receipt, p.Value.integer(1));
    try t.expectEqual(@as(usize, 4), writes(turn));
    try t.expectEqual(null, store.state.get(head));
    try store.commit(turn);
    turn = try store.capture();
    var found = (try changed.data.get(t.allocator, &reader, row(1, "Ada", &cells).identity)).?;
    defer found.deinit();
    try t.expectEqualStrings("Ada", found.row().cells[1].value.atom.bytes);
    try t.expectEqual(null, store.state.get(Pages.key(9, 'i', 2)));
    try t.expectEqualStrings("1", store.state.get(receipt).?.slice());
}
test "large records and multi-level candidates restart staging and retain old rows" {
    var store: Store = .{};
    defer store.deinit();
    const pages = try store.create();
    var data: Data = .{ .schema = schema };
    var next_id: u64 = 1;
    var first: ?Data = null;
    var large: [4096]u8 = @splat('x');
    for (0..40) |i| {
        var turn = try store.capture();
        var reader: Pages.Reader(*Turn) = .{ .pages = pages, .source = &turn };
        var overlay = try Candidate.Overlay(*@TypeOf(reader)).init(t.allocator, &reader, next_id, next_id + Candidate.max_records);
        defer overlay.deinit();
        var cells: [2]f.Types.Values.Cell = undefined;
        const inserted = row(@intCast(i), if (i == 0) &large else "short", &cells);
        const changed = try data.insert(t.allocator, &overlay, inserted);
        _ = try overlay.finish(changed.data.index);
        try flush(&store, pages, &overlay);
        turn = try store.capture();
        // Staging has not made the successor visible through the original root.
        try t.expectEqual(null, try data.get(t.allocator, &reader, inserted.identity));
        data = changed.data;
        next_id = overlay.nextId();
        if (i == 0) first = data;
        var actual = (try data.get(t.allocator, &reader, inserted.identity)).?;
        defer actual.deinit();
        try t.expectEqualStrings(inserted.cells[1].value.atom.bytes, actual.row().cells[1].value.atom.bytes);
    }
    try t.expect(data.index.root.?.level >= 2);
    var turn = try store.capture();
    var reader: Pages.Reader(*Turn) = .{ .pages = pages, .source = &turn };
    var cells: [2]f.Types.Values.Cell = undefined;
    var retained = (try first.?.get(t.allocator, &reader, row(0, "", &cells).identity)).?;
    defer retained.deinit();
    try t.expectEqualStrings(&large, retained.row().cells[1].value.atom.bytes);
    const pubn: Pub = .{ .resource = 7, .domain = .table, .namespace = 9 };
    try t.expectEqual(@as(u32, 0), (try pubn.budget(&turn)).records);
}
test "Table pages reject definition drift, identity conflicts, denial and cross-resource reads" {
    var store: Store = .{};
    defer store.deinit();
    const pages = try store.create();
    const bytes = "record";
    const ref: Pages.Reference = .{ .id = 1, .spec = try Pub.Digest.of(Pages.schema_format, bytes) };
    var turn = try store.capture();
    try t.expectEqual(.ready, try pages.stage(&turn, ref, bytes));
    try store.commit(turn);
    turn = try store.capture();
    try t.expectEqual(.ready, try pages.stage(&turn, ref, bytes));
    try t.expectEqual(@as(usize, 0), writes(turn));
    const other: Pages.Reference = .{ .id = 1, .spec = try Pub.Digest.of(Pages.schema_format, "changed") };
    try t.expectError(error.TablePageIdentityConflict, pages.stage(&turn, other, "changed"));
    try t.expectEqual(@as(usize, 0), writes(turn));
    var output: [256]u8 = undefined;
    try t.expectEqualStrings(bytes, try pages.read(&turn, ref, &output));
    turn.view.resource = 99;
    try t.expectError(error.CrossResourceTransaction, pages.read(&turn, ref, &output));
    turn = try store.capture();
    store.denied = true;
    try t.expectError(error.AccessDenied, pages.read(&turn, ref, &output));
    try t.expectError(error.AccessDenied, turn.validate());
    store.denied = false;
    const manifest_key = Pages.key(9, 'd', 0);
    const saved = store.state.get(manifest_key).?;
    var incompatible = saved;
    incompatible.data[4] ^= 1;
    try store.state.put(t.allocator, manifest_key, incompatible);
    turn = try store.capture();
    try t.expectError(error.IncompatibleTableStorage, pages.read(&turn, ref, &output));
    try t.expectError(error.IncompatibleTableStorage, Pages.create(&turn, 9, .{ .record_bytes = f.TableRow.max_bytes, .staging_bytes = f.TableRow.max_bytes * 2, .staging_records = 2 }));
    try t.expectEqual(@as(usize, 0), writes(turn));
    _ = store.state.remove(manifest_key);
    try t.expectError(error.TableStorageNotFound, pages.read(&turn, ref, &output));
    try t.expectError(error.IncompatibleTableStorage, Pages.create(&turn, 9, .{ .record_bytes = f.TableRow.max_bytes, .staging_bytes = f.TableRow.max_bytes * 2, .staging_records = 2 }));
    try store.state.put(t.allocator, manifest_key, saved);
    var broken = store.state.get(Pages.key(9, 'i', 1)).?;
    broken.data[broken.len - 1] ^= 1;
    try store.state.put(t.allocator, Pages.key(9, 'i', 1), broken);
    try t.expectError(error.InvalidTablePage, pages.read(&turn, ref, &output));
}
fn allocationCase(allocator: std.mem.Allocator) !void {
    var store: Store = .{};
    defer store.deinit();
    const pages = try store.create();
    var turn = try store.capture();
    var reader: Pages.Reader(*Turn) = .{ .pages = pages, .source = &turn };
    var overlay = try Candidate.Overlay(*@TypeOf(reader)).init(allocator, &reader, 1, 1 + Candidate.max_records);
    defer overlay.deinit();
    const data: Data = .{ .schema = schema };
    var cells: [2]f.Types.Values.Cell = undefined;
    const changed = try data.insert(allocator, &overlay, row(1, "Ada", &cells));
    _ = try overlay.finish(changed.data.index);
    try t.expectError(error.TableCandidateSealed, overlay.finish(changed.data.index));
    try t.expectEqual(@as(usize, 0), writes(turn));
}
test "private candidate allocations unwind without changing the captured turn" {
    try t.checkAllAllocationFailures(t.allocator, allocationCase, .{});
}

test "Table page bounds and failed turn composition preserve prior private writes" {
    var store: Store = .{};
    defer store.deinit();
    var turn = try store.capture();
    for (0..3) |i| try turn.put(p.Value.integer(@intCast(i)), p.Value.integer(1));
    const before = turn.decision;
    try t.expectError(error.MutationBudgetExceeded, Pages.create(&turn, 9, .{ .record_bytes = 4, .staging_bytes = 4, .staging_records = 1 }));
    try t.expectEqualDeep(before, turn.decision);
    turn = try store.capture();
    const pages = try Pages.create(&turn, 9, .{ .record_bytes = 4, .staging_bytes = 4, .staging_records = 1 });
    try store.commit(turn);
    turn = try store.capture();
    const too_big: Pages.Reference = .{ .id = 1, .spec = try Pub.Digest.of(Pages.schema_format, "large") };
    try t.expectError(error.PublicationTooLarge, pages.stage(&turn, too_big, "large"));
    try t.expectEqual(@as(usize, 0), writes(turn));
    const ref: Pages.Reference = .{ .id = 1, .spec = try Pub.Digest.of(Pages.schema_format, "data") };
    try t.expectEqual(.ready, try pages.stage(&turn, ref, "data"));
    try store.commit(turn);
    var output: [256]u8 = undefined;
    const saved = store.state.get(Pages.key(9, 'i', 1)).?;
    for (0..saved.len) |length| {
        try store.state.put(t.allocator, Pages.key(9, 'i', 1), try p.Value.init(saved.data[0..length]));
        turn = try store.capture();
        try t.expectError(error.InvalidTablePage, pages.read(&turn, ref, &output));
    }
    try store.state.put(t.allocator, Pages.key(9, 'i', 1), saved);
    turn = try store.capture();
    try t.expectError(error.TablePageBufferTooSmall, pages.read(&turn, ref, output[0..3]));
}

test "Table namespace initialization refuses orphan records without adopting their definition" {
    var store: Store = .{};
    defer store.deinit();
    const orphan = Pages.key(9, 'i', 7);
    try store.state.put(t.allocator, orphan, try p.Value.init("orphan"));
    var turn = try store.capture();
    const limits: Pub.Limits = .{ .record_bytes = 256, .staging_bytes = 256, .staging_records = 1 };
    try t.expectError(error.IncompatibleTableStorage, Pages.create(&turn, 9, limits));
    try t.expectEqual(@as(usize, 0), writes(turn));
    _ = store.state.remove(orphan);
    try turn.write(orphan, try p.Value.init("private orphan"));
    try t.expectError(error.InvalidTableStorage, Pages.create(&turn, 9, limits));
    try t.expectEqual(@as(usize, 1), writes(turn));
}

test "Table head binds schema and exact successor, retains retired data and rejects reset" {
    var store: Store = .{};
    defer store.deinit();
    const pages = try store.create();
    var bytes: [f.TableSchema.max_bytes]u8 = undefined;
    const encoded = try schema.encode(&bytes);
    const schema_ref: Pages.Reference = .{ .id = 1, .spec = try Pub.Digest.of(Pages.schema_format, encoded) };
    var turn = try store.capture();
    try t.expectEqual(.ready, try pages.stage(&turn, schema_ref, encoded));
    const head: Head = .{ .resource = 7, .object = 9, .revision = 1, .schema = schema_ref, .next_record = 2 };
    try head.create(t.allocator, &turn);
    try store.commit(turn);
    turn = try store.capture();
    try t.expectEqualDeep(head, try Head.load(&turn, 9));
    try t.expectError(error.TableExists, head.create(t.allocator, &turn));
    var owned = try head.readSchema(t.allocator, &turn);
    defer owned.deinit();
    try t.expectEqualDeep(try schema.fingerprint(), try owned.schema.fingerprint());

    var reader: Pages.Reader(*Turn) = .{ .pages = pages, .source = &turn };
    var overlay = try Candidate.Overlay(*@TypeOf(reader)).init(t.allocator, &reader, 2, 2 + Candidate.max_records);
    defer overlay.deinit();
    const data: Data = .{ .schema = owned.schema, .index = head.index };
    var cells: [2]f.Types.Values.Cell = undefined;
    const changed = try data.insert(t.allocator, &overlay, row(1, "Ada", &cells));
    _ = try overlay.finish(changed.data.index);
    for (overlay.records.items) |record| if (record.reachable) try t.expectEqual(.ready, try pages.stage(&turn, .{ .id = record.id, .spec = record.spec }, record.bytes));
    var after = head;
    after.revision += 1;
    after.index = changed.data.index;
    after.rows = 1;
    after.next_record = overlay.nextId();
    try head.replace(&turn, after);
    try turn.put(try p.Value.init("outcome"), p.Value.integer(1));
    try t.expectEqual(@as(usize, 4), writes(turn));
    try store.commit(turn);
    turn = try store.capture();
    try t.expectError(error.TableHeadChanged, head.replace(&turn, after));
    try t.expectEqual(@as(usize, 0), writes(turn));
    var retired = after;
    retired.revision += 1;
    retired.retired = true;
    try after.replace(&turn, retired);
    try store.commit(turn);
    turn = try store.capture();
    try t.expectEqualDeep(retired, try Head.load(&turn, 9));
    try t.expectError(error.TableRetired, retired.replace(&turn, after));
    try t.expectError(error.TableExists, head.create(t.allocator, &turn));
    var retained = (try changed.data.get(t.allocator, &reader, row(1, "", &cells).identity)).?;
    defer retained.deinit();
    try t.expectEqualStrings("Ada", retained.row().cells[1].value.atom.bytes);
    var retired_schema = try retired.readSchema(t.allocator, &turn);
    defer retired_schema.deinit();

    const head_bytes = try after.encode();
    try t.expectEqual(@as(u16, 245), head_bytes.len);
    try t.expectEqualDeep(after, try Head.decode(head_bytes));
    for (0..head_bytes.len) |length| try t.expectError(error.InvalidTableHead, Head.decode(try p.Value.init(head_bytes.data[0..length])));
    var bad = head_bytes;
    bad.data[4] ^= 1;
    try t.expectError(error.IncompatibleTableStorage, Head.decode(bad));
    bad = head_bytes;
    bad.data[bad.len] = 0;
    bad.len += 1;
    try t.expectError(error.InvalidTableHead, Head.decode(bad));
    var invalid = after;
    invalid.next_record = invalid.schema.id;
    try t.expectError(error.InvalidTableHead, invalid.encode());
    invalid = retired;
    invalid.pending = 1;
    try t.expectError(error.InvalidTableHead, invalid.encode());
    invalid = after;
    invalid.rows = 2;
    try t.expectError(error.InvalidTableHead, invalid.readSchema(t.allocator, &turn));
}

fn expectHex(hex: []const u8, bytes: []const u8) !void {
    var output: [512]u8 = undefined;
    try t.expectEqualSlices(u8, try std.fmt.hexToBytes(&output, hex), bytes);
}
test "typed Table head and page layouts match independent Python bytes" {
    const Fixture = struct { native_definition: []const u8, manifest_hex: []const u8, inline_hex: []const u8, head_hex: []const u8, head_key_hex: []const u8, page_key_hex: []const u8 };
    const fixture = try std.json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/table-storage.json"), .{});
    defer fixture.deinit();
    const expected = fixture.value;
    try t.expectEqualStrings(@tagName(p.Growth.current_definition), expected.native_definition);
    var minimum: [21]u8 = undefined;
    minimum[0] = 'R';
    minimum[1..].* = try (f.TableRow.Identity{ .origin = 2, .operation = 30, .ordinal = 0 }).encode();
    const head: Head = .{
        .resource = 7,
        .object = 9,
        .revision = 4,
        .schema = .{ .id = 7, .spec = .{ .format = Pages.schema_format, .length = 120, .digest = @splat(17) } },
        .index = .{ .root = .{ .id = 9, .spec = .{ .format = Index.format, .length = 180, .digest = @splat(34) }, .level = 0, .minimum = try Index.Key.init(&minimum), .entries = 3 } },
        .rows = 3,
        .next_record = 10,
    };
    const encoded = try head.encode();
    try expectHex(expected.head_hex, encoded.slice());
    try t.expectEqualDeep(head, try Head.decode(encoded));
    try expectHex(expected.head_key_hex, Head.key(9).slice());
    try expectHex(expected.page_key_hex, Pages.key(9, 'i', 7).slice());
    var store: Store = .{};
    defer store.deinit();
    var turn = try store.capture();
    const pages = try Pages.create(&turn, 9, .{ .record_bytes = 65536, .staging_bytes = 65536, .staging_records = 1 });
    try expectHex(expected.manifest_hex, (try turn.read(Pages.key(9, 'd', 0))).?.slice());
    const bytes = "typed page";
    try t.expectEqual(.ready, try pages.stage(&turn, .{ .id = 7, .spec = try Pub.Digest.of(Pages.schema_format, bytes) }, bytes));
    try expectHex(expected.inline_hex, (try turn.read(Pages.key(9, 'i', 7))).?.slice());
}
