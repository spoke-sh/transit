const std = @import("std");
const t = std.testing;
const TSeg = @import("TSeg.zig");
const Reader = @import("TSegReader.zig");
const Schema = @import("TableSchema.zig");
const Row = @import("TableRow.zig");
const Values = @import("Values.zig");

const columns = [_]Schema.Column{
    .{ .id = 1, .name = "id", .type = .int64, .nullable = false, .encoding = .bitpacked },
    .{ .id = 2, .name = "text", .type = .utf8, .nullable = false },
};
const schema: Schema.Schema = .{ .object = 1, .revision = 1, .next_column = 3, .columns = &columns, .primary_key = &.{1} };
const names = [_][]const u8{ "zero", "one", "two", "three", "four", "five", "six", "seven" };

fn fixture(out: []u8) ![]u8 {
    var rows: [8]Row.Row = undefined;
    var cells: [8][2]Values.Cell = undefined;
    for (&rows, &cells, 0..) |*row, *cell, i| {
        cell.* = .{ .{ .value = .{ .atom = .{ .signed = @intCast(i) } } }, .{ .value = .{ .atom = .{ .bytes = names[i] } } } };
        row.* = .{ .identity = .{ .origin = 1, .operation = 1, .ordinal = @intCast(i) }, .cells = cell };
    }
    const bytes = try TSeg.writeSegment(t.allocator, schema, &rows, .{ .segment_id = 1, .rows_per_group = 2 }, out);
    return out[0..bytes.len];
}

const Input = struct {
    bytes: []u8,
    calls: usize = 0,
    read_bytes: usize = 0,
    last_offset: u64 = 0,
    fail: bool = false,
    fn source(self: *Input) Reader.Source {
        return .{ .context = self, .read = read };
    }
    fn read(context: *anyopaque, offset: u64, out: []u8) !void {
        const self: *Input = @ptrCast(@alignCast(context));
        self.calls += 1;
        self.last_offset = offset;
        if (self.fail) return error.TestReadFailed;
        if (offset > self.bytes.len or out.len > self.bytes.len - offset) return error.TestReadOutsideObject;
        @memcpy(out, self.bytes[@intCast(offset)..][0..out.len]);
        self.read_bytes += out.len;
    }
};

test "TSeg ranges read only metadata and selected column with independently owned values" {
    var buffer: [16384]u8 = undefined;
    var input: Input = .{ .bytes = try fixture(&buffer) };
    var reader = try Reader.open(t.allocator, input.source(), input.bytes.len, 8192);
    var values = std.heap.ArenaAllocator.init(t.allocator);
    defer values.deinit();
    try t.expectEqual(@as(usize, 3), input.calls);
    try t.expectEqual(@as(usize, 80 + reader.footer_bytes), input.read_bytes);
    const page = reader.footer.row_groups[2].pages[1];
    const cells = try reader.column(t.allocator, values.allocator(), input.source(), schema, 2, 1, 8192);
    try t.expectEqual(@as(usize, 4), input.calls);
    try t.expectEqual(page.offset, input.last_offset);
    try t.expectEqual(@as(usize, 80 + reader.footer_bytes + page.length), input.read_bytes);
    try t.expect(input.read_bytes < input.bytes.len);
    reader.deinit();
    @memset(input.bytes, 0xaa);
    try t.expectEqual(@as(usize, 2), cells.len);
    try t.expectEqualStrings("four", cells[0].value.atom.bytes);
    try t.expectEqualStrings("five", cells[1].value.atom.bytes);
}

test "TSeg ranges enforce budgets interpretation and integrity before disclosure" {
    var buffer: [16384]u8 = undefined;
    var input: Input = .{ .bytes = try fixture(&buffer) };
    try t.expectError(error.SegmentReadBudgetExceeded, Reader.open(t.allocator, input.source(), input.bytes.len, 1));
    try t.expectEqual(@as(usize, 2), input.calls);
    var reader = try Reader.open(t.allocator, input.source(), input.bytes.len, 8192);
    defer reader.deinit();
    var values = std.heap.ArenaAllocator.init(t.allocator);
    defer values.deinit();
    const before = input.calls;
    try t.expectError(error.SegmentReadBudgetExceeded, reader.column(t.allocator, values.allocator(), input.source(), schema, 0, 0, 1));
    var other = schema;
    other.revision += 1;
    try t.expectError(error.TableSchemaChanged, reader.column(t.allocator, values.allocator(), input.source(), other, 0, 0, 8192));
    try t.expectError(error.InvalidSegmentCoordinate, reader.column(t.allocator, values.allocator(), input.source(), schema, 4, 0, 8192));
    try t.expectEqual(before, input.calls);
    input.fail = true;
    try t.expectError(error.TestReadFailed, reader.column(t.allocator, values.allocator(), input.source(), schema, 0, 0, 8192));
    input.fail = false;
    input.bytes[@intCast(reader.footer.row_groups[0].pages[0].offset)] ^= 1;
    try t.expectError(error.CorruptSegmentPage, reader.column(t.allocator, values.allocator(), input.source(), schema, 0, 0, 8192));
}

fn resign(bytes: []u8) void {
    const start: usize = @intCast(std.mem.readInt(u64, bytes[40..48], .little));
    const length = std.mem.readInt(u32, bytes[48..52], .little);
    std.crypto.hash.sha2.Sha256.hash(bytes[start..][0 .. length - 32], bytes[start + length - 32 ..][0..32], .{});
}

test "TSeg footer rejects overflow forged counts and invalid coordinates before allocation" {
    var buffer: [16384]u8 = undefined;
    var bytes = try fixture(&buffer);
    std.mem.writeInt(u64, bytes[bytes.len - 16 ..][0..8], std.math.maxInt(u64), .little);
    try t.expectError(error.InvalidSegment, TSeg.readFooter(t.allocator, bytes));
    bytes = try fixture(&buffer);
    bytes[4] = 2;
    try t.expectError(error.InvalidSegment, TSeg.readFooter(t.allocator, bytes));
    bytes = try fixture(&buffer);
    const start: usize = @intCast(std.mem.readInt(u64, bytes[40..48], .little));
    bytes[start + 40] ^= 1;
    try t.expectError(error.CorruptSegmentFooter, TSeg.readFooter(t.allocator, bytes));
    bytes = try fixture(&buffer);
    std.mem.writeInt(u32, bytes[32..36], std.math.maxInt(u32), .little);
    std.mem.writeInt(u32, bytes[start + 92 ..][0..4], std.math.maxInt(u32), .little);
    resign(bytes);
    var small: [8192]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&small);
    try t.expectError(error.InvalidSegment, TSeg.readFooter(fixed.allocator(), bytes));
    // Metadata is checksum-valid but the first column points into the footer.
    bytes = try fixture(&buffer);
    const min_len = std.mem.readInt(u16, bytes[start + 100 ..][0..2], .little);
    const max_pos = start + 102 + min_len;
    const max_len = std.mem.readInt(u16, bytes[max_pos..][0..2], .little);
    const first_page = max_pos + 2 + max_len + 8;
    std.mem.writeInt(u64, bytes[first_page..][0..8], start, .little);
    resign(bytes);
    try t.expectError(error.InvalidSegment, TSeg.readFooter(t.allocator, bytes));
}

fn allocationCase(allocator: std.mem.Allocator, bytes: []u8) !void {
    var input: Input = .{ .bytes = bytes };
    var reader = try Reader.open(allocator, input.source(), bytes.len, 8192);
    defer reader.deinit();
    var group = try reader.group(allocator, input.source(), schema, 3, &.{1}, .{});
    defer group.deinit();
    try t.expectEqualStrings("seven", group.columns[0][1].value.atom.bytes);
}

test "TSeg range allocation failures release metadata pages and decoded cells" {
    var buffer: [16384]u8 = undefined;
    const bytes = try fixture(&buffer);
    // Force arena growth through allocations so backing-page placement cannot
    // change the failure enumeration by making a resize succeed on one run.
    var no_resize = t.FailingAllocator.init(t.allocator, .{ .resize_fail_index = 0 });
    try t.checkAllAllocationFailures(no_resize.allocator(), allocationCase, .{bytes});
}

test "TSeg projected decoding enforces actual resident arena bytes" {
    var buffer: [16384]u8 = undefined;
    var input: Input = .{ .bytes = try fixture(&buffer) };
    var reader = try Reader.open(t.allocator, input.source(), input.bytes.len, 8192);
    defer reader.deinit();
    try t.expectError(error.SegmentReadBudgetExceeded, reader.group(t.allocator, input.source(), schema, 0, &.{ 0, 1 }, .{ .decoded_bytes = 1 }));
    const before = input.calls;
    var group = try reader.group(t.allocator, input.source(), schema, 0, &.{1}, .{ .decoded_bytes = 4096 });
    defer group.deinit();
    try t.expectEqual(before + 1, input.calls);
    try t.expect(group.allocatedBytes() <= 4096);
    try t.expectEqualStrings("zero", group.columns[0][0].value.atom.bytes);
}

fn selectedAllocationCase(allocator: std.mem.Allocator, bytes: []u8) !void {
    var input: Input = .{ .bytes = bytes };
    var reader = try Reader.open(allocator, input.source(), bytes.len, 8192);
    defer reader.deinit();
    var encoded = try reader.encodedGroup(allocator, input.source(), schema, 3, &.{1}, 8192);
    defer encoded.deinit();
    var group = try encoded.select(allocator, schema, &.{1}, 8192);
    defer group.deinit();
    try t.expectEqualStrings("seven", group.columns[0][0].value.atom.bytes);
    try t.expectEqual(@as(?usize, 0), group.rowIndex(1));
    try t.expectEqual(@as(?usize, null), group.rowIndex(0));
}

test "TSeg selected decoding owns encoded and selected values through allocation failures" {
    var buffer: [16384]u8 = undefined;
    const bytes = try fixture(&buffer);
    var no_resize = t.FailingAllocator.init(t.allocator, .{ .resize_fail_index = 0 });
    try t.checkAllAllocationFailures(no_resize.allocator(), selectedAllocationCase, .{bytes});
}

test "TSeg selected decoding preserves projection budgets and lifetimes across repeated point reads" {
    var buffer: [16384]u8 = undefined;
    var input: Input = .{ .bytes = try fixture(&buffer) };
    var reader = try Reader.open(t.allocator, input.source(), input.bytes.len, 8192);
    var reader_live = true;
    defer if (reader_live) reader.deinit();
    const before = input.calls;
    try t.expectError(error.SegmentReadBudgetExceeded, reader.encodedGroup(t.allocator, input.source(), schema, 3, &.{1}, 1));
    try t.expectError(error.InvalidSegmentCoordinate, reader.encodedGroup(t.allocator, input.source(), schema, 3, &.{2}, 8192));
    try t.expectEqual(before, input.calls);
    var encoded = try reader.encodedGroup(t.allocator, input.source(), schema, 3, &.{1}, 8192);
    var encoded_live = true;
    defer if (encoded_live) encoded.deinit();
    try t.expectEqual(before + 1, input.calls);
    try t.expect(encoded.allocatedBytes() < 8192);
    reader.deinit();
    reader_live = false;
    @memset(input.bytes, 0xaa);
    // Reading the original source would now fail. Both singleton selections
    // use the cache, and the first output survives the second selection.
    var first = try encoded.select(t.allocator, schema, &.{0}, 4096);
    defer first.deinit();
    var second = try encoded.select(t.allocator, schema, &.{1}, 4096);
    defer second.deinit();
    try t.expect(first.peakAllocatedBytes() <= 4096);
    try t.expectError(error.SegmentReadBudgetExceeded, encoded.select(t.allocator, schema, &.{0}, 1));
    try t.expectError(error.InvalidColumnSelection, encoded.select(t.allocator, schema, &.{2}, 4096));
    var other = schema;
    other.revision += 1;
    try t.expectError(error.TableSchemaChanged, encoded.select(t.allocator, other, &.{0}, 4096));
    try t.expectEqual(before + 1, input.calls);
    encoded.deinit();
    encoded_live = false;
    try t.expectEqualStrings("six", first.columns[0][0].value.atom.bytes);
    try t.expectEqualStrings("seven", second.columns[0][0].value.atom.bytes);
}

test "TSeg selected decoding rejects corrupt pages and mismatched logical row counts" {
    var buffer: [16384]u8 = undefined;
    var input: Input = .{ .bytes = try fixture(&buffer) };
    var reader = try Reader.open(t.allocator, input.source(), input.bytes.len, 8192);
    defer reader.deinit();
    const coordinate = @constCast(&reader.footer.row_groups[0].pages[1]);
    const bytes = input.bytes[@intCast(coordinate.offset)..][0..coordinate.length];
    bytes[0] ^= 1;
    try t.expectError(error.CorruptSegmentPage, reader.encodedGroup(t.allocator, input.source(), schema, 0, &.{1}, 8192));
    // A checksum-valid page with one row cannot establish the two-row group.
    const column = schema.columns[1];
    const page = try @import("PhysicalCodecs.zig").encodeColumnPage(t.allocator, column, &.{.{ .value = .{ .atom = .{ .bytes = "only" } } }}, bytes);
    coordinate.length = @intCast(page.len);
    std.crypto.hash.sha2.Sha256.hash(page, &coordinate.digest, .{});
    var encoded = try reader.encodedGroup(t.allocator, input.source(), schema, 0, &.{1}, 8192);
    defer encoded.deinit();
    try t.expectError(error.InvalidSegment, encoded.select(t.allocator, schema, &.{0}, 4096));
}

test "TSeg selected decoding charges skipped string validation to the shared memory budget" {
    const compressed_columns = [_]Schema.Column{.{ .id = 1, .name = "v", .type = .utf8, .encoding = .fsst }};
    const compressed_schema: Schema.Schema = .{ .object = 1, .revision = 1, .next_column = 2, .columns = &compressed_columns, .primary_key = &.{} };
    const large: [16384]u8 = @splat('q');
    const cells = [_][1]Values.Cell{
        .{.{ .value = .{ .atom = .{ .bytes = "small" } } }},
        .{.{ .value = .{ .atom = .{ .bytes = &large } } }},
    };
    const rows = [_]Row.Row{
        .{ .identity = .{ .origin = 1, .operation = 1, .ordinal = 0 }, .cells = &cells[0] },
        .{ .identity = .{ .origin = 1, .operation = 1, .ordinal = 1 }, .cells = &cells[1] },
    };
    var buffer: [65536]u8 = undefined;
    const bytes = try TSeg.writeSegment(t.allocator, compressed_schema, &rows, .{ .segment_id = 1 }, &buffer);
    var input: Input = .{ .bytes = buffer[0..bytes.len] };
    var reader = try Reader.open(t.allocator, input.source(), bytes.len, 8192);
    defer reader.deinit();
    var encoded = try reader.encodedGroup(t.allocator, input.source(), compressed_schema, 0, &.{0}, 32768);
    defer encoded.deinit();
    try t.expectError(error.SegmentReadBudgetExceeded, encoded.select(t.allocator, compressed_schema, &.{0}, 4096));
    var selected = try encoded.select(t.allocator, compressed_schema, &.{0}, 32768);
    defer selected.deinit();
    try t.expectEqualStrings("small", selected.columns[0][0].value.atom.bytes);
    try t.expect(selected.allocatedBytes() < 4096);
    try t.expect(selected.peakAllocatedBytes() >= large.len);
    try t.expect(selected.peakAllocatedBytes() <= 32768);
}
