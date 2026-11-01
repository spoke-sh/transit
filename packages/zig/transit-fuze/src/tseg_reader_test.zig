const std = @import("std");
const t = std.testing;
const TSeg = @import("TSeg.zig");
const Reader = @import("TSegReader.zig");
const Schema = @import("TableSchema.zig");
const Row = @import("TableRow.zig");
const Values = @import("Values.zig");
const Codecs = @import("PhysicalCodecs.zig");
const ColumnPredicate = @import("ColumnPredicate.zig");

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

test "TSeg filtered groups prune before payload and materialize only selected projections" {
    var buffer: [16384]u8 = undefined;
    var input: Input = .{ .bytes = try fixture(&buffer) };
    var reader = try Reader.open(t.allocator, input.source(), input.bytes.len, 8192);
    defer reader.deinit();
    var failure: ?Reader.FilterFailure = null;
    const filter: Reader.Filter = .{ .column = 0, .predicate = .{ .compare = .{ .op = .ge, .value = .{ .signed = 5 } } } };
    var retained: [4]Reader.Group = undefined;
    var initialized: usize = 0;
    defer for (retained[0..initialized]) |*group| group.deinit();
    var payload_bytes: usize = 0;
    for (&retained, 0..) |*group, index| {
        const before = input.calls;
        group.* = try reader.filteredGroup(t.allocator, input.source(), schema, index, &.{1}, filter, .{}, &failure);
        initialized += 1;
        try t.expect(failure == null);
        if (index < 2) {
            try t.expectEqual(before, input.calls);
            try t.expectEqual(@as(usize, 0), group.rows.?.len);
        } else {
            try t.expectEqual(before + 2, input.calls);
            for (reader.footer.row_groups[index].pages) |p| payload_bytes += p.length;
            try t.expectEqualSlices(u32, if (index == 2) &.{1} else &.{ 0, 1 }, group.rows.?);
        }
    }
    try t.expectEqual(@as(usize, 7), input.calls);
    try t.expectEqual(80 + reader.footer_bytes + payload_bytes, input.read_bytes);
    // Projected values own bytes, and sparse ordinals survive source release.
    @memset(input.bytes, 0xaa);
    try t.expectEqualStrings("five", retained[2].columns[0].cell(0).value.atom.bytes);
    try t.expectEqualStrings("six", retained[3].columns[0].cell(0).value.atom.bytes);
    try t.expectEqualStrings("seven", retained[3].columns[0].cell(1).value.atom.bytes);
    try t.expectEqual(@as(?usize, null), retained[2].rowIndex(0));
    try t.expectEqual(@as(?usize, 0), retained[2].rowIndex(1));
}

test "TSeg filtered groups retain schema budget integrity and projection validation on empty intervals" {
    var buffer: [16384]u8 = undefined;
    var input: Input = .{ .bytes = try fixture(&buffer) };
    var reader = try Reader.open(t.allocator, input.source(), input.bytes.len, 8192);
    defer reader.deinit();
    var failure: ?Reader.FilterFailure = null;
    const filter: Reader.Filter = .{ .column = 0, .predicate = .{ .compare = .{ .op = .gt, .value = .{ .signed = 999 } } } };
    const before = input.calls;
    var other = schema;
    other.object += 1;
    try t.expectError(error.TableSchemaChanged, reader.filteredGroup(t.allocator, input.source(), other, 0, &.{1}, filter, .{}, &failure));
    try t.expectError(error.InvalidSegmentCoordinate, reader.filteredGroup(t.allocator, input.source(), schema, 0, &.{2}, filter, .{}, &failure));
    try t.expectError(error.SegmentReadBudgetExceeded, reader.filteredGroup(t.allocator, input.source(), schema, 0, &.{1}, filter, .{ .decoded_bytes = 1 }, &failure));
    try t.expectEqual(before, input.calls);
    const matching: Reader.Filter = .{ .column = 0, .predicate = .{ .compare = .{ .op = .ge, .value = .{ .signed = 0 } } } };
    const pruned_code = [_]ColumnPredicate.Program.Instruction{.{ .atom = .{ .column = 0, .predicate = filter.predicate } }};
    var pruned = try reader.decisions(t.allocator, input.source(), schema, 0, .{ .instructions = &pruned_code }, .{});
    defer pruned.deinit();
    for (pruned.rows) |decision| try t.expect(!decision.selected and decision.failure == null);
    try t.expectError(error.SegmentReadBudgetExceeded, reader.filteredGroup(t.allocator, input.source(), schema, 0, &.{1}, matching, .{ .page_bytes = 1 }, &failure));
    try t.expectEqual(before, input.calls);
    input.bytes[@intCast(reader.footer.row_groups[0].pages[0].offset)] ^= 1;
    try t.expectError(error.CorruptSegmentPage, reader.filteredGroup(t.allocator, input.source(), schema, 0, &.{1}, matching, .{}, &failure));
    const code = [_]ColumnPredicate.Program.Instruction{.{ .atom = .{ .column = 0, .predicate = matching.predicate } }};
    try t.expectError(error.CorruptSegmentPage, reader.decisions(t.allocator, input.source(), schema, 0, .{ .instructions = &code }, .{}));
    try t.expectError(error.CorruptSegmentPage, reader.filteredCandidates(t.allocator, input.source(), schema, 0, &.{1}, .{ .instructions = &code }, .{ .rows = &.{ 1, 0 }, .matches = 1 }, .{}, &failure));
    try t.expect(failure == null);
}

test "TSeg filtered groups collated pruning agrees with independent unpruned masks" {
    const texts = [_][]const u8{ "A", "a", "0", "é", "\x00", "AA", "aA" };
    const cases = [_]struct { collation: Schema.Collation, mask: [texts.len]bool }{
        .{ .collation = .utf8_binary, .mask = .{ true, false, true, false, true, true, false } },
        .{ .collation = .ascii_ci, .mask = .{ false, false, true, false, true, false, false } },
        .{ .collation = .ebcdic_cp037, .mask = .{ false, false, false, true, true, false, false } },
    };
    for (cases) |case| {
        const fields = [_]Schema.Column{.{ .id = 1, .name = "v", .type = .utf8, .encoding = .dictionary, .collation = case.collation }};
        const definition: Schema.Schema = .{ .object = 2, .revision = 1, .next_column = 2, .columns = &fields };
        var cells: [texts.len][1]Values.Cell = undefined;
        var rows: [texts.len]Row.Row = undefined;
        for (&rows, &cells, texts, 0..) |*row, *cell, value, i| {
            cell.* = .{.{ .value = .{ .atom = .{ .bytes = value } } }};
            row.* = .{ .identity = .{ .origin = 1, .operation = 1, .ordinal = @intCast(i) }, .cells = cell };
        }
        var buffer: [16384]u8 = undefined;
        const encoded = try TSeg.writeSegment(t.allocator, definition, &rows, .{ .segment_id = 1, .rows_per_group = 1 }, &buffer);
        var input: Input = .{ .bytes = buffer[0..encoded.len] };
        var reader = try Reader.open(t.allocator, input.source(), input.bytes.len, 8192);
        defer reader.deinit();
        var failure: ?Reader.FilterFailure = null;
        const filter: Reader.Filter = .{ .column = 0, .predicate = .{ .compare = .{ .op = .lt, .value = .{ .bytes = "a" } } } };
        for (case.mask, 0..) |matches, index| {
            const before = input.calls;
            var group = try reader.filteredGroup(t.allocator, input.source(), definition, index, &.{0}, filter, .{}, &failure);
            defer group.deinit();
            try t.expectEqual(@as(usize, @intFromBool(matches)), group.rows.?.len);
            try t.expectEqual(before + (if (matches) @as(usize, 2) else 0), input.calls);
            var control = try reader.group(t.allocator, input.source(), definition, index, &.{0}, .{});
            defer control.deinit();
            try t.expectEqualStrings(texts[index], control.columns[0].cell(0).value.atom.bytes);
            if (matches) try t.expectEqualStrings(texts[index], group.columns[0].cell(0).value.atom.bytes);
        }
    }
}

test "TSeg membership selectivity measures distinct values and payload ranges" {
    // Equal row counts and page layouts isolate distinct-value pressure on the
    // current 64-bit, two-hash filter. All absent probes are inside min/max.
    const fields = [_]Schema.Column{.{ .id = 1, .name = "v", .type = .int64 }};
    const definition: Schema.Schema = .{ .object = 2, .revision = 1, .next_column = 2, .columns = &fields };
    const row_count = 256;
    const probes = 2048;
    for ([_]usize{ 4, 16, 64, 256 }) |distinct| {
        var cells: [row_count][1]Values.Cell = undefined;
        var rows: [row_count]Row.Row = undefined;
        for (&rows, &cells, 0..) |*row, *cell, i| {
            cell.* = .{.{ .value = .{ .atom = .{ .signed = @intCast((i % distinct) * 4096) } } }};
            row.* = .{ .identity = .{ .origin = 1, .operation = 1, .ordinal = @intCast(i) }, .cells = cell };
        }
        var buffer: [128 * 1024]u8 = undefined;
        const encoded = try TSeg.writeSegment(t.allocator, definition, &rows, .{ .segment_id = 1, .rows_per_group = row_count }, &buffer);
        var input: Input = .{ .bytes = buffer[0..encoded.len] };
        var reader = try Reader.open(t.allocator, input.source(), input.bytes.len, buffer.len);
        defer reader.deinit();
        const zone = @constCast(&reader.footer.row_groups[0].zone_maps[0]);
        const mask = zone.bloom_mask;
        const page_bytes = reader.footer.row_groups[0].pages[0].length;
        var failure: ?Reader.FilterFailure = null;
        // Exhaust every present value independently of the filter hash.
        for (0..distinct) |value| {
            const filter: Reader.Filter = .{ .column = 0, .predicate = .{ .compare = .{ .op = .eq, .value = .{ .signed = @intCast(value * 4096) } } } };
            var selected = try reader.filteredGroup(t.allocator, input.source(), definition, 0, &.{0}, filter, .{}, &failure);
            defer selected.deinit();
            try t.expect(failure == null);
            try t.expectEqual(row_count / distinct, selected.rows.?.len);
            for (0..selected.columns[0].len()) |i| try t.expectEqual(@as(i128, @intCast(value * 4096)), selected.columns[0].cell(i).value.atom.signed);
        }
        var ranges: [2]usize = @splat(0);
        var bytes: [2]usize = @splat(0);
        for (0..2) |arm| {
            // The control changes only the decoded filter to "maybe". Bounds,
            // page bytes, integrity, predicate execution and projection match.
            zone.bloom_mask = if (arm == 0) mask else std.math.maxInt(u64);
            const before_calls = input.calls;
            const before_bytes = input.read_bytes;
            for (0..probes) |probe| {
                const needle: i128 = @intCast(probe * 2 + 1);
                const filter: Reader.Filter = .{ .column = 0, .predicate = .{ .compare = .{ .op = .eq, .value = .{ .signed = needle } } } };
                var selected = try reader.filteredGroup(t.allocator, input.source(), definition, 0, &.{0}, filter, .{}, &failure);
                defer selected.deinit();
                try t.expect(failure == null);
                try t.expectEqual(@as(usize, 0), selected.rows.?.len);
            }
            ranges[arm] = input.calls - before_calls;
            bytes[arm] = input.read_bytes - before_bytes;
            try t.expectEqual(ranges[arm] * page_bytes, bytes[arm]);
        }
        try t.expectEqual(@as(usize, probes), ranges[1]);
        try t.expect(ranges[0] <= ranges[1]);
        if (distinct <= 16) try t.expect(ranges[0] < probes / 4);
        std.debug.print("membership: distinct={d}, rows={d}, bits_set={d}/64, false_positive={d}/{d}, payload_ranges={d}/{d}, payload_bytes={d}/{d}\n", .{ distinct, row_count, @popCount(mask), ranges[0], probes, ranges[0], ranges[1], bytes[0], bytes[1] });
    }
}

test "TSeg filtered groups cannot prune eager source failures or reorder their row attribution" {
    // A synthetic imported column owns five-state cells not admitted by Table
    // INSERT. Its independently supplied footer commits to the exact page.
    const fields = [_]Schema.Column{.{ .id = 1, .name = "v", .type = .int64 }};
    const definition: Schema.Schema = .{ .object = 2, .revision = 1, .next_column = 2, .columns = &fields };
    const cells = [_]Values.Cell{ .{ .conflict = &.{ .{ .counter = 9, .replica = 2, .value = .null }, .{ .counter = 10, .replica = 2, .value = .null } } }, .{ .type_error = .utf8 } };
    var buffer: [8192]u8 = undefined;
    const encoded = try Codecs.encodeColumnPage(t.allocator, fields[0], &cells, &buffer);
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(encoded, &digest, .{});
    const pages = [_]TSeg.PageSlice{.{ .offset = 0, .length = @intCast(encoded.len), .digest = digest }};
    const zones = [_]TSeg.ZoneMap{.{ .error_count = 1, .conflict_count = 1 }};
    const groups = [_]TSeg.RowGroupFooter{.{ .row_count = 2, .start_row_offset = 0, .pages = &pages, .zone_maps = &zones }};
    var reader: Reader = .{ .footer_bytes = 0, .footer = .{ .arena = .init(t.allocator), .segment_id = 1, .object_id = 2, .schema_revision = 1, .layout_fingerprint = try definition.layoutFingerprint(), .total_rows = 2, .min_pk_sort_key = "", .max_pk_sort_key = "", .row_groups = &groups, .pk_index = &.{} } };
    defer reader.deinit();
    var input: Input = .{ .bytes = buffer[0..encoded.len] };
    var failure: ?Reader.FilterFailure = null;
    const filter: Reader.Filter = .{ .column = 0, .predicate = .{ .compare = .{ .op = .eq, .value = .{ .signed = 999 } } } };
    try t.expectError(error.QueryConflict, reader.filteredGroup(t.allocator, input.source(), definition, 0, &.{0}, filter, .{}, &failure));
    try t.expectEqual(@as(u32, 0), failure.?.row);
    try t.expectEqual(@as(usize, 0), failure.?.column);
    try t.expectEqual(.conflict, failure.?.outcome);
    try t.expectEqual(@as(usize, 1), input.calls);
    var selected = try reader.filteredGroup(t.allocator, input.source(), definition, 0, &.{0}, .{ .column = 0, .predicate = .{ .state = .conflict } }, .{}, &failure);
    defer selected.deinit();
    try t.expect(failure == null);
    try t.expectEqualSlices(u32, &.{0}, selected.rows.?);
    try t.expectEqual(@as(u64, 9), selected.columns[0].cell(0).conflict[0].counter);
    try t.expectEqual(@as(u64, 2), selected.columns[0].cell(0).conflict[0].replica);
}

fn filteredAllocationCase(allocator: std.mem.Allocator, bytes: []u8) !void {
    var input: Input = .{ .bytes = bytes };
    var reader = try Reader.open(allocator, input.source(), bytes.len, 8192);
    defer reader.deinit();
    var failure: ?Reader.FilterFailure = null;
    const instructions = [_]ColumnPredicate.Program.Instruction{
        .{ .atom = .{ .column = 0, .predicate = .{ .compare = .{ .op = .ge, .value = .{ .signed = 6 } } } } },
        .{ .atom = .{ .column = 1, .predicate = .{ .compare = .{ .op = .ne, .value = .{ .bytes = "zzz" } } } } },
        .conjunction,
    };
    var group = try reader.filteredProgram(allocator, input.source(), schema, 3, &.{ 0, 1 }, .{ .instructions = &instructions }, .{}, &failure);
    defer group.deinit();
    try t.expectEqualStrings("seven", group.columns[1].cell(1).value.atom.bytes);
    var prefix = try reader.filteredCandidates(allocator, input.source(), schema, 3, &.{1}, .{ .instructions = &instructions }, .{ .rows = &.{ 1, 0 }, .matches = 1 }, .{}, &failure);
    defer prefix.deinit();
    try t.expectEqual(@as(usize, 1), prefix.examined);
    try t.expectEqualSlices(u32, &.{1}, prefix.group.rows.?);
    try t.expectEqualStrings("seven", prefix.group.columns[0].cell(0).value.atom.bytes);
    var decisions = try reader.decisions(allocator, input.source(), schema, 3, .{ .instructions = &instructions }, .{});
    defer decisions.deinit();
    try t.expect(decisions.rows[0].selected and decisions.rows[1].selected);
}

test "TSeg filtered groups allocation failures release every partial owner" {
    var buffer: [16384]u8 = undefined;
    const bytes = try fixture(&buffer);
    var no_resize = t.FailingAllocator.init(t.allocator, .{ .resize_fail_index = 0 });
    try t.checkAllAllocationFailures(no_resize.allocator(), filteredAllocationCase, .{bytes});
}

test "TSeg filtered groups bound output expansion below a full decoded group" {
    const text: [2048]u8 = @splat('x');
    var cells: [64][2]Values.Cell = undefined;
    var rows: [64]Row.Row = undefined;
    for (&rows, &cells, 0..) |*row, *cell, i| {
        cell.* = .{ .{ .value = .{ .atom = .{ .signed = @intCast(i) } } }, .{ .value = .{ .atom = .{ .bytes = &text } } } };
        row.* = .{ .identity = .{ .origin = 1, .operation = 1, .ordinal = @intCast(i) }, .cells = cell };
    }
    const buffer = try t.allocator.alloc(u8, 256 * 1024);
    defer t.allocator.free(buffer);
    const encoded = try TSeg.writeSegment(t.allocator, schema, &rows, .{ .segment_id = 1, .rows_per_group = 64 }, buffer);
    var input: Input = .{ .bytes = buffer[0..encoded.len] };
    var reader = try Reader.open(t.allocator, input.source(), input.bytes.len, 16384);
    defer reader.deinit();
    var failure: ?Reader.FilterFailure = null;
    const filter: Reader.Filter = .{ .column = 0, .predicate = .{ .compare = .{ .op = .eq, .value = .{ .signed = 63 } } } };
    var selected = try reader.filteredGroup(t.allocator, input.source(), schema, 0, &.{1}, filter, .{ .decoded_bytes = 16 * 1024 }, &failure);
    defer selected.deinit();
    try t.expectEqualSlices(u32, &.{63}, selected.rows.?);
    try t.expectEqualStrings(&text, selected.columns[0].cell(0).value.atom.bytes);
    try t.expect(selected.peakAllocatedBytes() <= 16 * 1024);
    try t.expectError(error.SegmentReadBudgetExceeded, reader.group(t.allocator, input.source(), schema, 0, &.{1}, .{ .decoded_bytes = 16 * 1024 }));
    var buffered = try reader.bufferedGroup(t.allocator, input.source(), schema, 0, &.{1}, 256 * 1024, 16 * 1024);
    defer buffered.deinit();
    try t.expectEqual(@as(usize, 64), buffered.decoded.columns[0].len());
    try t.expect(buffered.decoded.peakAllocatedBytes() <= 16 * 1024);
    try t.expect(buffered.encoded.allocatedBytes() > 128 * 1024);
    for (0..buffered.decoded.columns[0].len()) |i| try t.expectEqualStrings(&text, buffered.decoded.columns[0].cell(i).value.atom.bytes);
}

test "TSeg encoded programs preserve Boolean source order and prune with independent masks" {
    const Instruction = ColumnPredicate.Program.Instruction;
    const conjunction = [_]Instruction{
        .{ .atom = .{ .column = 0, .predicate = .{ .compare = .{ .op = .ge, .value = .{ .signed = 3 } } } } },
        .{ .atom = .{ .column = 1, .predicate = .{ .compare = .{ .op = .lt, .value = .{ .bytes = "seven" } } } } },
        .conjunction,
    };
    const disjunction = [_]Instruction{
        .{ .atom = .{ .column = 0, .predicate = .{ .compare = .{ .op = .lt, .value = .{ .signed = 1 } } } } },
        .{ .atom = .{ .column = 0, .predicate = .{ .compare = .{ .op = .gt, .value = .{ .signed = 6 } } } } },
        .disjunction,
        .{ .atom = .{ .column = 1, .predicate = .{ .compare = .{ .op = .eq, .value = .{ .bytes = "one" } } } } },
        .negate,
        .conjunction,
    };
    const cases = [_]struct { code: []const Instruction, mask: [8]bool, candidates: [4]bool }{
        .{ .code = &conjunction, .mask = .{ false, false, false, false, true, true, false, false }, .candidates = .{ false, false, true, false } },
        .{ .code = &disjunction, .mask = .{ true, false, false, false, false, false, false, true }, .candidates = .{ true, false, false, true } },
    };
    for (cases) |case| {
        var buffer: [16384]u8 = undefined;
        var input: Input = .{ .bytes = try fixture(&buffer) };
        var reader = try Reader.open(t.allocator, input.source(), input.bytes.len, 8192);
        defer reader.deinit();
        const program: ColumnPredicate.Program = .{ .instructions = case.code };
        var failure: ?Reader.FilterFailure = null;
        var matched: usize = 0;
        for (0..4) |index| {
            const before = input.calls;
            var selected = try reader.filteredProgram(t.allocator, input.source(), schema, index, &.{1}, program, .{}, &failure);
            defer selected.deinit();
            if (!case.candidates[index]) try t.expectEqual(before, input.calls) else try t.expect(input.calls > before);
            var control = try reader.group(t.allocator, input.source(), schema, index, &.{ 0, 1 }, .{});
            defer control.deinit();
            var count: usize = 0;
            for (0..2) |row| {
                var instruction: ?u8 = null;
                const cells = [_]Values.Cell{ control.columns[0].cell(row), control.columns[1].cell(row) };
                try t.expectEqual(case.mask[index * 2 + row], (try program.truth(schema, &cells, &instruction)).selects());
                if (!case.mask[index * 2 + row]) continue;
                try t.expectEqual(@as(u32, @intCast(row)), selected.rows.?[count]);
                try t.expectEqualStrings(names[index * 2 + row], selected.columns[0].cell(count).value.atom.bytes);
                count += 1;
            }
            try t.expectEqual(count, selected.rows.?.len);
            matched += count;
        }
        try t.expectEqual(@as(usize, 2), matched);
    }
}

test "TSeg encoded programs arbitrate eager failures by row then instruction" {
    const Instruction = ColumnPredicate.Program.Instruction;
    const fields = [_]Schema.Column{
        .{ .id = 1, .name = "a", .type = .int64 },
        .{ .id = 2, .name = "b", .type = .int64 },
    };
    const definition: Schema.Schema = .{ .object = 2, .revision = 1, .next_column = 3, .columns = &fields };
    const left = [_]Values.Cell{ .{ .value = .{ .atom = .{ .signed = 0 } } }, .{ .type_error = .utf8 } };
    const right = [_]Values.Cell{ .{ .conflict = &.{ .{ .counter = 1, .replica = 2, .value = .null }, .{ .counter = 2, .replica = 2, .value = .null } } }, .{ .type_error = .int64 } };
    var bytes: [8192]u8 = undefined;
    const first = try Codecs.encodeColumnPage(t.allocator, fields[0], &left, &bytes);
    const second = try Codecs.encodeColumnPage(t.allocator, fields[1], &right, bytes[first.len..]);
    var pages: [2]TSeg.PageSlice = undefined;
    for (&pages, [_][]const u8{ first, second }, 0..) |*coordinate, page_bytes, i| {
        coordinate.* = .{ .offset = if (i == 0) 0 else first.len, .length = @intCast(page_bytes.len), .digest = undefined };
        std.crypto.hash.sha2.Sha256.hash(page_bytes, &coordinate.digest, .{});
    }
    const zones = [_]TSeg.ZoneMap{ .{ .value_count = 1, .error_count = 1 }, .{ .conflict_count = 1, .error_count = 1 } };
    const groups = [_]TSeg.RowGroupFooter{.{ .row_count = 2, .start_row_offset = 0, .pages = &pages, .zone_maps = &zones }};
    var reader: Reader = .{ .footer_bytes = 0, .footer = .{ .arena = .init(t.allocator), .segment_id = 1, .object_id = 2, .schema_revision = 1, .layout_fingerprint = try definition.layoutFingerprint(), .total_rows = 2, .min_pk_sort_key = "", .max_pk_sort_key = "", .row_groups = &groups, .pk_index = &.{} } };
    defer reader.deinit();
    var input: Input = .{ .bytes = bytes[0 .. first.len + second.len] };
    var failure: ?Reader.FilterFailure = null;
    const predicate: ColumnPredicate.Predicate = .{ .compare = .{ .op = .eq, .value = .{ .signed = 999 } } };
    var code = [_]Instruction{
        .{ .atom = .{ .column = 0, .predicate = predicate } },
        .{ .atom = .{ .column = 1, .predicate = predicate } },
        .conjunction,
    };
    // The first column fails on row 1, but the second column fails on row 0.
    // Physical evaluation order must not choose the column-0 error first.
    const program: ColumnPredicate.Program = .{ .instructions = &code };
    var deferred = try reader.decisions(t.allocator, input.source(), definition, 0, program, .{});
    defer deferred.deinit();
    try t.expectEqual(.conflict, deferred.rows[0].failure.?.outcome);
    try t.expectEqual(@as(u8, 1), deferred.rows[0].failure.?.instruction);
    try t.expectEqual(.type_error, deferred.rows[1].failure.?.outcome);
    try t.expectEqual(@as(u8, 0), deferred.rows[1].failure.?.instruction);
    try t.expect(deferred.allocatedBytes() > 0);
    try t.expectError(error.QueryConflict, reader.filteredProgram(t.allocator, input.source(), definition, 0, &.{0}, program, .{}, &failure));
    try t.expectEqual(@as(u32, 0), failure.?.row);
    try t.expectEqual(@as(u8, 1), failure.?.instruction);
    // A true left side of OR still evaluates the failing right operand.
    code[0].atom.predicate = .all;
    code[2] = .disjunction;
    try t.expectError(error.QueryConflict, reader.filteredProgram(t.allocator, input.source(), definition, 0, &.{0}, program, .{}, &failure));
    try t.expectEqual(@as(u8, 1), failure.?.instruction);
    // Swap order so the same first source failure has instruction zero.
    code[0].atom = .{ .column = 1, .predicate = predicate };
    code[1].atom = .{ .column = 0, .predicate = predicate };
    try t.expectError(error.QueryConflict, reader.filteredProgram(t.allocator, input.source(), definition, 0, &.{0}, program, .{}, &failure));
    try t.expectEqual(@as(u8, 0), failure.?.instruction);

    // Logical identity order need not equal physical segment order. Only the
    // owner's visible candidate prefix participates in semantic failure order.
    code[0].atom = .{ .column = 0, .predicate = predicate };
    code[1].atom = .{ .column = 1, .predicate = predicate };
    try t.expectError(error.QueryTypeError, reader.filteredCandidates(t.allocator, input.source(), definition, 0, &.{0}, program, .{ .rows = &.{ 1, 0 } }, .{}, &failure));
    try t.expectEqual(@as(u32, 1), failure.?.row);
    try t.expectEqual(@as(u8, 0), failure.?.instruction);
    const single_code = [_]Instruction{.{ .atom = .{ .column = 0, .predicate = .{ .compare = .{ .op = .eq, .value = .{ .signed = 0 } } } } }};
    const single: ColumnPredicate.Program = .{ .instructions = &single_code };
    var visible = try reader.filteredCandidates(t.allocator, input.source(), definition, 0, &.{0}, single, .{ .rows = &.{0} }, .{}, &failure);
    defer visible.deinit();
    try t.expect(failure == null);
    try t.expectEqual(@as(usize, 1), visible.examined);
    try t.expectEqual(@as(i128, 0), visible.group.columns[0].cell(0).value.atom.signed);
    var prefix = try reader.filteredCandidates(t.allocator, input.source(), definition, 0, &.{0}, single, .{ .rows = &.{ 0, 1 }, .matches = 1 }, .{}, &failure);
    defer prefix.deinit();
    try t.expectEqual(@as(usize, 1), prefix.examined);
    try t.expectEqualSlices(u32, &.{0}, prefix.group.rows.?);
    try t.expect(prefix.group.rowIndex(1) == null);
    try t.expectError(error.QueryTypeError, reader.filteredCandidates(t.allocator, input.source(), definition, 0, &.{0}, single, .{ .rows = &.{ 0, 1 } }, .{}, &failure));
    try t.expectEqual(@as(u32, 1), failure.?.row);
    const no_read = input.calls;
    var empty = try reader.filteredCandidates(t.allocator, input.source(), definition, 0, &.{0}, single, .{ .rows = &.{ 0, 1 }, .matches = 0 }, .{}, &failure);
    defer empty.deinit();
    try t.expect(failure == null and empty.examined == 0 and empty.group.rows.?.len == 0);
    try t.expectError(error.InvalidColumnSelection, reader.filteredCandidates(t.allocator, input.source(), definition, 0, &.{0}, single, .{ .rows = &.{ 0, 0 } }, .{}, &failure));
    try t.expectError(error.InvalidColumnSelection, reader.filteredCandidates(t.allocator, input.source(), definition, 0, &.{0}, single, .{ .rows = &.{2}, .matches = 0 }, .{}, &failure));
    try t.expectEqual(no_read, input.calls);
    const all_code = [_]Instruction{.{ .atom = .{ .column = 0, .predicate = .all } }};
    var reversed = try reader.filteredCandidates(t.allocator, input.source(), definition, 0, &.{0}, .{ .instructions = &all_code }, .{ .rows = &.{ 1, 0 } }, .{}, &failure);
    defer reversed.deinit();
    try t.expectEqual(@as(usize, 2), reversed.examined);
    try t.expectEqualSlices(u32, &.{ 0, 1 }, reversed.group.rows.?);
    try t.expectEqual(.utf8, reversed.group.columns[0].cell(reversed.group.rowIndex(1).?).type_error);
}

test "TSeg encoded programs preserve NULL negation and reject malformed programs before I O" {
    var buffer: [16384]u8 = undefined;
    var input: Input = .{ .bytes = try fixture(&buffer) };
    var reader = try Reader.open(t.allocator, input.source(), input.bytes.len, 8192);
    defer reader.deinit();
    var failure: ?Reader.FilterFailure = null;
    const code = [_]ColumnPredicate.Program.Instruction{
        .{ .atom = .{ .column = 0, .predicate = .null_compare } },
        .negate,
    };
    const before = input.calls;
    var empty = try reader.filteredProgram(t.allocator, input.source(), schema, 0, &.{1}, .{ .instructions = &code }, .{}, &failure);
    defer empty.deinit();
    try t.expectEqual(@as(usize, 0), empty.rows.?.len);
    try t.expectEqual(before, input.calls);
    try t.expectError(error.InvalidPredicateProgram, reader.filteredProgram(t.allocator, input.source(), schema, 0, &.{1}, .{ .instructions = code[1..] }, .{}, &failure));
    try t.expectEqual(before, input.calls);
    var pruned = try reader.filteredCandidates(t.allocator, input.source(), schema, 0, &.{1}, .{ .instructions = &code }, .{ .rows = &.{ 1, 0 }, .matches = 1 }, .{}, &failure);
    defer pruned.deinit();
    try t.expectEqual(@as(usize, 2), pruned.examined);
    try t.expectEqual(@as(usize, 0), pruned.group.rows.?.len);
    try t.expectEqual(before, input.calls);
}

const Input = struct {
    bytes: []u8,
    calls: usize = 0,
    read_bytes: usize = 0,
    last_offset: u64 = 0,
    fail: bool = false,
    cancel_at: ?usize = null,
    fn source(self: *Input) Reader.Source {
        return .{ .context = self, .read = read };
    }
    fn read(context: *anyopaque, offset: u64, out: []u8) !void {
        const self: *Input = @ptrCast(@alignCast(context));
        self.calls += 1;
        self.last_offset = offset;
        if (self.fail) return error.TestReadFailed;
        if (offset > self.bytes.len or out.len > self.bytes.len - offset) return error.TestReadOutsideObject;
        if (self.cancel_at == self.calls) {
            // An interrupted source may have filled a prefix. None of that
            // pending range becomes a verified page or escapes its owner.
            @memcpy(out[0 .. out.len / 2], self.bytes[@intCast(offset)..][0 .. out.len / 2]);
            return error.Canceled;
        }
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
    try t.expectEqualStrings("seven", group.columns[0].cell(1).value.atom.bytes);
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
    try t.expectEqualStrings("zero", group.columns[0].cell(0).value.atom.bytes);
    var empty = try reader.group(t.allocator, input.source(), schema, 0, &.{}, .{});
    defer empty.deinit();
    try t.expectEqual(@as(?usize, 1), empty.rowIndex(1));
    try t.expectEqual(@as(?usize, null), empty.rowIndex(2));
}

fn selectedAllocationCase(allocator: std.mem.Allocator, bytes: []u8) !void {
    var input: Input = .{ .bytes = bytes };
    var reader = try Reader.open(allocator, input.source(), bytes.len, 8192);
    defer reader.deinit();
    var encoded = try reader.encodedGroup(allocator, input.source(), schema, 3, &.{1}, 8192);
    defer encoded.deinit();
    var group = try encoded.select(allocator, schema, &.{1}, 8192);
    defer group.deinit();
    try t.expectEqualStrings("seven", group.columns[0].cell(0).value.atom.bytes);
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
    try t.expectEqualStrings("six", first.columns[0].cell(0).value.atom.bytes);
    try t.expectEqualStrings("seven", second.columns[0].cell(0).value.atom.bytes);
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
    try t.expectError(error.CorruptSegmentPage, reader.bufferedGroup(t.allocator, input.source(), schema, 0, &.{1}, 8192, 8192));
    // A checksum-valid page with one row cannot establish the two-row group.
    const column = schema.columns[1];
    const page = try @import("PhysicalCodecs.zig").encodeColumnPage(t.allocator, column, &.{.{ .value = .{ .atom = .{ .bytes = "only" } } }}, bytes);
    coordinate.length = @intCast(page.len);
    std.crypto.hash.sha2.Sha256.hash(page, &coordinate.digest, .{});
    var encoded = try reader.encodedGroup(t.allocator, input.source(), schema, 0, &.{1}, 8192);
    defer encoded.deinit();
    try t.expectError(error.InvalidSegment, encoded.select(t.allocator, schema, &.{0}, 4096));
    try t.expectError(error.InvalidSegment, reader.bufferedGroup(t.allocator, input.source(), schema, 0, &.{1}, 8192, 8192));
}

fn bufferedAllocationCase(allocator: std.mem.Allocator, bytes: []u8) !void {
    var input: Input = .{ .bytes = bytes };
    var reader = try Reader.open(allocator, input.source(), bytes.len, 8192);
    defer reader.deinit();
    var group = try reader.bufferedGroup(allocator, input.source(), schema, 3, &.{ 1, 0 }, 8192, 8192);
    defer group.deinit();
    try t.expectEqualStrings("seven", group.decoded.columns[0].cell(1).value.atom.bytes);
    try t.expectEqual(@as(i128, 7), group.decoded.columns[1].cell(1).value.atom.signed);
}

test "TSeg buffered group allocation failures release encoded and decoded owners" {
    var buffer: [16384]u8 = undefined;
    const bytes = try fixture(&buffer);
    var no_resize = t.FailingAllocator.init(t.allocator, .{ .resize_fail_index = 0 });
    try t.checkAllAllocationFailures(no_resize.allocator(), bufferedAllocationCase, .{bytes});
}

test "TSeg buffered groups own verified pages and borrow payloads within separate budgets" {
    var buffer: [16384]u8 = undefined;
    var input: Input = .{ .bytes = try fixture(&buffer) };
    var reader = try Reader.open(t.allocator, input.source(), input.bytes.len, 8192);
    var reader_live = true;
    defer if (reader_live) reader.deinit();
    const before = input.calls;
    try t.expectError(error.SegmentReadBudgetExceeded, reader.bufferedGroup(t.allocator, input.source(), schema, 3, &.{ 1, 0 }, 1, 8192));
    try t.expectError(error.SegmentReadBudgetExceeded, reader.bufferedGroup(t.allocator, input.source(), schema, 3, &.{ 1, 0 }, 8192, 0));
    try t.expectError(error.InvalidSegmentCoordinate, reader.bufferedGroup(t.allocator, input.source(), schema, 3, &.{2}, 8192, 8192));
    var other = schema;
    other.revision += 1;
    try t.expectError(error.TableSchemaChanged, reader.bufferedGroup(t.allocator, input.source(), other, 3, &.{1}, 8192, 8192));
    try t.expectEqual(before, input.calls);
    var group = try reader.bufferedGroup(t.allocator, input.source(), schema, 3, &.{ 1, 0 }, 8192, 8192);
    var group_live = true;
    defer if (group_live) group.deinit();
    try t.expectEqual(before + 2, input.calls);
    try t.expect(group.encoded.allocatedBytes() <= 8192);
    try t.expect(group.decoded.peakAllocatedBytes() <= 8192);
    const payload = group.decoded.columns[0].cell(1).value.atom.bytes;
    const page = group.encoded.pages[0].bytes;
    try t.expect(@intFromPtr(payload.ptr) >= @intFromPtr(page.ptr));
    try t.expect(@intFromPtr(payload.ptr) + payload.len <= @intFromPtr(page.ptr) + page.len);
    try t.expectError(error.SegmentReadBudgetExceeded, reader.bufferedGroup(t.allocator, input.source(), schema, 3, &.{ 1, 0 }, 8192, 1));
    reader.deinit();
    reader_live = false;
    @memset(input.bytes, 0xaa);
    try t.expectEqualStrings("seven", payload);
    const arrow = @import("zarrow");
    var buffers: [3]arrow.SharedBuffer = undefined;
    const data = try group.decoded.columns[0].plain.buffers.arrowValues(&buffers);
    const strings: arrow.StringArray = .{ .data = &data };
    try t.expectEqualStrings("seven", try strings.value(1));
    try t.expectEqual(payload.ptr, (try strings.value(1)).ptr);
    try t.expectEqual(@as(usize, 0), group.decoded.columns[0].plain.details.len);
    try t.expectEqual(@as(i128, 7), group.decoded.columns[1].cell(1).value.atom.signed);
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const detached = try Values.cloneValidated(arena.allocator(), group.decoded.columns[0].cell(1));
    group.deinit();
    group_live = false;
    try t.expectEqualStrings("seven", detached.value.atom.bytes);
}

fn sharedArrowCase(allocator: std.mem.Allocator, bytes: []u8) !void {
    const arrow = @import("zarrow");
    var input: Input = .{ .bytes = bytes };
    var reader = try Reader.open(allocator, input.source(), bytes.len, 8192);
    var reader_live = true;
    defer if (reader_live) reader.deinit();
    var group = try reader.bufferedGroup(allocator, input.source(), schema, 3, &.{ 1, 0 }, 8192, 8192);
    var group_live = true;
    defer if (group_live) group.deinit();
    const shared = try Reader.SharedGroup.init(allocator, group);
    group_live = false;
    var shared_live = true;
    defer if (shared_live) shared.release();
    try t.expectError(error.InvalidSegmentCoordinate, shared.arrowValues(2));
    const payload = shared.group.decoded.columns[0].cell(1).value.atom.bytes;
    var strings = try shared.arrowValues(0);
    var strings_live = true;
    defer if (strings_live) strings.release();
    var sliced = try strings.slice(1, 1);
    defer sliced.release();
    try t.expectError(error.UnsupportedPlainColumn, shared.arrowValues(1));
    try t.expectEqual(@as(i128, 7), shared.group.decoded.columns[1].cell(1).value.atom.signed);
    var exported = try arrow.exportArrayToC(allocator, strings);
    defer if (exported.release) |release| release(&exported);
    strings.release();
    strings_live = false;
    shared.release();
    shared_live = false;
    reader.deinit();
    reader_live = false;

    const text_type: arrow.DataType = .{ .string = {} };
    var imported = try arrow.importArrayFromC(allocator, &text_type, &exported);
    defer imported.release();
    try t.expect(exported.release == null);
    try t.expectError(error.Released, arrow.importArrayFromC(allocator, &text_type, &exported));
    const text: arrow.StringArray = .{ .data = imported.data() };
    const slice: arrow.StringArray = .{ .data = sliced.data() };
    try t.expectEqualStrings("seven", try text.value(1));
    try t.expectEqualStrings("seven", try slice.value(0));
    try t.expectEqual(payload.ptr, (try text.value(1)).ptr);
    try t.expectEqual(payload.ptr, (try slice.value(0)).ptr);

    // IPC is a bounded serialization copy of the same retained value buffers.
    const fields = [_]arrow.Field{.{ .name = "value", .data_type = &text_type, .nullable = true }};
    var batch = try arrow.RecordBatch.initBorrowed(allocator, .{ .fields = &fields }, &.{imported});
    defer batch.deinit();
    var buffer: [4096]u8 = undefined;
    const encoded = try @import("root.zig").encode(allocator, batch, &buffer);
    var source = std.Io.Reader.fixed(encoded);
    // Keep partially unpacked FlatBuffer metadata under one decode owner,
    // including allocation failure.
    var decoding = std.heap.ArenaAllocator.init(allocator);
    defer decoding.deinit();
    var ipc = arrow.IpcStreamReader(*std.Io.Reader).init(decoding.allocator(), &source);
    defer ipc.deinit();
    _ = try ipc.readSchema();
    var recovered = (try ipc.nextRecordBatch()).?;
    defer recovered.deinit();
    const recovered_strings: arrow.StringArray = .{ .data = recovered.columns[0].data() };
    try t.expectEqualStrings("seven", try recovered_strings.value(1));
    try t.expect(try ipc.nextRecordBatch() == null);
}

test "TSeg shared Arrow values survive group reader and C handle release without payload copies" {
    var buffer: [16384]u8 = undefined;
    try sharedArrowCase(t.allocator, try fixture(&buffer));
}

test "TSeg canceled partial range releases pending pages and preserves retained Arrow values" {
    var buffer: [16384]u8 = undefined;
    var input: Input = .{ .bytes = try fixture(&buffer) };
    var reader = try Reader.open(t.allocator, input.source(), input.bytes.len, 8192);
    defer reader.deinit();
    var group = try reader.bufferedGroup(t.allocator, input.source(), schema, 3, &.{1}, 8192, 8192);
    const shared = Reader.SharedGroup.init(t.allocator, group) catch |err| {
        group.deinit();
        return err;
    };
    defer shared.release();
    var values = try shared.arrowValues(0);
    defer values.release();
    // Fail the second projected page after the first page was read and verified.
    input.cancel_at = input.calls + 2;
    try t.expectError(error.Canceled, reader.bufferedGroup(t.allocator, input.source(), schema, 0, &.{ 0, 1 }, 8192, 8192));
    const retained: @import("zarrow").StringArray = .{ .data = values.data() };
    try t.expectEqualStrings("seven", try retained.value(1));
    input.cancel_at = null;
    var resumed = try reader.bufferedGroup(t.allocator, input.source(), schema, 0, &.{ 0, 1 }, 8192, 8192);
    defer resumed.deinit();
    try t.expectEqualStrings("one", resumed.decoded.columns[1].cell(1).value.atom.bytes);
    try t.expectEqualStrings("seven", try retained.value(1));
}

test "TSeg shared Arrow allocation failures preserve transfer and release every retained owner" {
    var buffer: [16384]u8 = undefined;
    const bytes = try fixture(&buffer);
    var no_resize = t.FailingAllocator.init(t.allocator, .{ .resize_fail_index = 0 });
    try t.checkAllAllocationFailures(no_resize.allocator(), sharedArrowCase, .{bytes});
}

fn exportChildren(allocator: std.mem.Allocator, value: @import("zarrow").ArrayRef) !void {
    var exported = try @import("zarrow").exportArrayToC(allocator, value);
    const release = exported.release.?;
    defer release(&exported);
    try t.expectEqual(@as(i64, 2), exported.n_children);
    try t.expectEqual(@as(i64, 2), exported.children[0].?.length);
    release(&exported);
    try t.expect(exported.release == null);
}

test "TSeg Arrow C export releases completed children when later allocation fails" {
    const arrow = @import("zarrow");
    var integers = try arrow.Int64Builder.init(t.allocator, 2);
    defer integers.deinit();
    try integers.append(7);
    try integers.appendNull();
    var child = try integers.finish();
    defer child.release();
    const kind: arrow.DataType = .{ .int64 = {} };
    const fields = [_]arrow.Field{
        .{ .name = "first", .data_type = &kind, .nullable = true },
        .{ .name = "second", .data_type = &kind, .nullable = true },
    };
    var structure = arrow.StructBuilder.init(t.allocator, &fields);
    defer structure.deinit();
    try structure.appendValid();
    try structure.appendValid();
    var value = try structure.finish(&.{ child, child });
    defer value.release();
    try t.checkAllAllocationFailures(t.allocator, exportChildren, .{value});
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
    // Production predicate evaluation streams the large value within 4 KiB.
    // Selected projection still owns/charges decoded values and validation work.
    const instructions = [_]ColumnPredicate.Program.Instruction{.{ .atom = .{
        .column = 0,
        .predicate = .{ .compare = .{ .op = .gt, .value = .{ .bytes = "m" } } },
    } }};
    var decisions = try reader.decisions(t.allocator, input.source(), compressed_schema, 0, .{ .instructions = &instructions }, .{ .decoded_bytes = 4096 });
    defer decisions.deinit();
    try t.expect(decisions.rows[0].selected and decisions.rows[1].selected);
    try t.expect(decisions.allocatedBytes() <= 4096);
    try t.expectError(error.SegmentReadBudgetExceeded, encoded.select(t.allocator, compressed_schema, &.{0}, 4096));
    try t.expectError(error.SegmentReadBudgetExceeded, reader.bufferedGroup(t.allocator, input.source(), compressed_schema, 0, &.{0}, 32768, 4096));
    var selected = try encoded.select(t.allocator, compressed_schema, &.{0}, 32768);
    defer selected.deinit();
    try t.expectEqualStrings("small", selected.columns[0].cell(0).value.atom.bytes);
    try t.expect(selected.allocatedBytes() < 4096);
    try t.expect(selected.peakAllocatedBytes() >= large.len);
    try t.expect(selected.peakAllocatedBytes() <= 32768);
}
