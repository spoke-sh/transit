const std = @import("std");
const q = @import("root.zig");
const Spill = @import("RelationalSpill.zig");
const r = q.fuze.Relational;
const e = q.fuze.RelationalExecution;
const t = std.testing;
const columns = [_]q.fuze.TableSchema.Column{.{ .id = 1, .name = "key", .type = .int64 }};
const sources = [_]r.Source{.{ .alias = "t", .realm = 1, .resource = 2, .catalog = 3, .owner = 4, .schema = .{ .object = 5, .revision = 1, .next_column = 2, .columns = &columns } }};
fn plan() r.Plan {
    return .{ .sources = &sources, .group_by = &.{.{ .source = 0, .id = 1 }}, .outputs = &.{ .{ .name = "key", .expression = .{ .column = .{ .source = 0, .id = 1 } } }, .{ .name = "n", .expression = .count_all } }, .lifetime = .interactive, .budgets = .{ .resident_bytes = 1024 * 1024, .spill_bytes = 1024 * 1024, .result_bytes = 1024 * 1024, .output_rows = 10000, .work_steps = 1000000, .source_pins = 1 } };
}
fn cut() !r.Cut {
    return .{ .domain = .native_resource, .resource = 2, .revision = 9, .schema = try sources[0].schema.fingerprint(), .commitment = @splat(7) };
}
fn group(key: ?i64, count: u64) e.Group {
    var result: e.Group = .{ .key = .{ .len = 1 } };
    result.key.values[0] = if (key) |integer| .{ .integer = integer } else null;
    result.states[1].rows = count;
    return result;
}
test "private disk groups exceed resident records with ascending descending and interleaved keys" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    const cuts = [_]r.Cut{try cut()};
    const bound: r.Bound = .{ .plan = plan(), .cuts = &cuts };
    var spill = try Spill.open(t.allocator, t.io, tmp.dir, "groups", bound, 1000000, null);
    defer spill.deinit();
    const existing = try tmp.dir.createFile(t.io, "existing", .{ .exclusive = true });
    defer existing.close(t.io);
    try t.expectError(error.PathAlreadyExists, Spill.open(t.allocator, t.io, tmp.dir, "existing", bound, 100, null));
    // Three adversarial insertion orders exercise single and double rotations.
    for (0..300) |i| try spill.put(group(@intCast(i), i));
    for (0..300) |i| try spill.put(group(@intCast(899 - i), 899 - i));
    for (0..300) |i| {
        const key = 300 + (i * 137) % 300;
        try spill.put(group(@intCast(key), key));
    }
    try spill.put(group(null, 1000));
    for (0..900) |i| {
        const key: i64 = @intCast(i);
        try t.expectEqual(i, (try spill.get(group(key, 0).key)).?.states[1].rows);
        try spill.put(group(key, i + 1));
    }
    try t.expectEqual(@as(u64, 901), spill.count);
    try t.expectEqual(spill.count * spill.record_bytes, try spill.file.length(t.io));
    var after: ?e.Key = null;
    for (0..901) |i| {
        const value = (try spill.next(after)).?;
        try t.expectEqual(if (i == 0) @as(?i64, null) else @as(?i64, @intCast(i - 1)), if (value.key.values[0]) |present| @as(?i64, present.integer) else null);
        try t.expectEqual(if (i == 0) @as(u64, 1000) else @as(u64, @intCast(i)), value.states[1].rows);
        after = value.key;
    }
    try t.expect(try spill.next(after) == null);
    try t.expect(try spill.get(group(10000, 0).key) == null);
}
test "spill quota work cancellation and torn records poison the incomplete owner" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    const cuts = [_]r.Cut{try cut()};
    var definition = plan();
    definition.budgets.spill_bytes = 152; // One fixed record with one key and two outputs.
    var spill = try Spill.open(t.allocator, t.io, tmp.dir, "quota", .{ .plan = definition, .cuts = &cuts }, 1000, null);
    defer spill.deinit();
    try spill.put(group(1, 1));
    try t.expectError(error.RelationalSpillBudget, spill.put(group(2, 2)));
    try t.expectEqual(@as(u64, 1), spill.count);
    try t.expectError(error.FailedRelationalSpill, spill.get(group(1, 0).key));
    var limited = try Spill.open(t.allocator, t.io, tmp.dir, "work", .{ .plan = plan(), .cuts = &cuts }, 1, null);
    defer limited.deinit();
    try limited.put(group(1, 1));
    try t.expectError(error.RelationalSpillWorkBudget, limited.get(group(1, 0).key));
    var cancelled = std.atomic.Value(bool).init(false);
    var cancel = try Spill.open(t.allocator, t.io, tmp.dir, "cancel", .{ .plan = plan(), .cuts = &cuts }, 1000, &cancelled);
    defer cancel.deinit();
    try cancel.put(group(1, 1));
    cancelled.store(true, .release);
    try t.expectError(error.Cancelled, cancel.next(null));
    var torn = try Spill.open(t.allocator, t.io, tmp.dir, "torn", .{ .plan = plan(), .cuts = &cuts }, 1000, null);
    defer torn.deinit();
    try torn.put(group(1, 1));
    try torn.file.setLength(t.io, torn.record_bytes - 1);
    try t.expectError(error.IncompleteRelationalSpill, torn.next(null));
    var corrupt = try Spill.open(t.allocator, t.io, tmp.dir, "corrupt", .{ .plan = plan(), .cuts = &cuts }, 1000, null);
    defer corrupt.deinit();
    try corrupt.put(group(1, 1));
    try corrupt.file.writePositionalAll(t.io, &.{255}, 0);
    try t.expectError(error.InvalidRelationalSpill, corrupt.next(null));
}

const Source = struct {
    pub fn validate(_: *Source, _: r.Bound) !void {}
    pub fn next(_: *Source, _: u8, after: ?r.RowIdentity) !?e.Row {
        const ordinal = if (after) |id| id.operation else 0;
        if (ordinal == 600) return null;
        var row: e.Row = .{ .identity = .{ .origin = 1, .operation = ordinal + 1, .ordinal = 0 } };
        row.values[0] = .{ .integer = @intCast(ordinal % 300) };
        return row;
    }
};
test "finite execution groups through private disk state with fixed operator memory" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    const cuts = [_]r.Cut{try cut()};
    const bound: r.Bound = .{ .plan = plan(), .cuts = &cuts };
    var spill = try Spill.open(t.allocator, t.io, tmp.dir, "execution", bound, 1000000, null);
    defer spill.deinit();
    var source: Source = .{};
    var execution = try e.Execution(*Source, *Spill).init(t.allocator, bound, &source, &spill);
    var rows: u64 = 0;
    while (true) switch (try execution.step()) {
        .progress => {},
        .row => |row| {
            try t.expectEqual(@as(i128, rows), row.cells[0].value.atom.signed);
            try t.expectEqual(@as(u128, 2), row.cells[1].value.atom.unsigned);
            rows += 1;
        },
        .complete => break,
    };
    try t.expectEqual(@as(u64, 300), rows);
    try t.expectEqual(@as(u64, 300), spill.count);
}

test "input groups and complete output exceed the explicit resident budget without a cardinality array" {
    const Generated = struct {
        groups: u64,
        pub fn validate(_: *@This(), _: r.Bound) !void {}
        pub fn next(self: *@This(), _: u8, after: ?r.RowIdentity) !?e.Row {
            const ordinal = if (after) |id| id.operation else 0;
            if (ordinal == self.groups * 2) return null;
            var row: e.Row = .{ .identity = .{ .origin = 1, .operation = ordinal + 1, .ordinal = 0 } };
            // Interleave a second contributor to every group without retaining
            // either input relation or expected output in a resident collection.
            row.values[0] = .{ .integer = @intCast(ordinal % self.groups) };
            return row;
        }
    };
    const Run = e.Execution(*Generated, *Spill);
    const resident = Run.residentBytes + Spill.resident_bytes + @sizeOf(Generated);
    const groups: u64 = resident / @sizeOf(i64) + 1;
    var definition = plan();
    definition.budgets.resident_bytes = resident;
    definition.budgets.spill_bytes = 16 * 1024 * 1024;
    definition.budgets.result_bytes = 16 * 1024 * 1024;
    definition.budgets.output_rows = groups;
    definition.budgets.work_steps = groups * 16;
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    const cuts = [_]r.Cut{try cut()};
    const bound: r.Bound = .{ .plan = definition, .cuts = &cuts };
    var spill = try Spill.open(t.allocator, t.io, tmp.dir, "growth", bound, 100000000, null);
    defer spill.deinit();
    var source: Generated = .{ .groups = groups };
    var execution = try Run.init(t.allocator, bound, &source, &spill);
    var rows: u64 = 0;
    while (true) switch (try execution.step()) {
        .progress => {},
        .row => |row| {
            try t.expectEqual(@as(i128, rows), row.cells[0].value.atom.signed);
            try t.expectEqual(@as(u128, 2), row.cells[1].value.atom.unsigned);
            rows += 1;
        },
        .complete => break,
    };
    try t.expectEqual(groups, rows);
    try t.expectEqual(groups, spill.count);
    try t.expect(groups * 2 * @sizeOf(i64) > resident);
    try t.expect(spill.count * spill.record_bytes > resident);
    try t.expect(execution.result_bytes > resident);
    std.debug.print("Relational component growth: {d} input rows, {d} groups, {d} resident bound, {d} spill bytes, {d} result bytes, {d} steps\n", .{ groups * 2, groups, resident, spill.count * spill.record_bytes, execution.result_bytes, execution.work });
}

test "text spill exceeds resident bytes and preserves collated keys across scratch reuse" {
    const text_columns = [_]q.fuze.TableSchema.Column{.{ .id = 1, .name = "key", .type = .utf8, .collation = .ascii_ci }};
    var text_sources = sources;
    text_sources[0].schema.columns = &text_columns;
    var definition = plan();
    definition.sources = &text_sources;
    definition.budgets.resident_bytes = 256 * 1024;
    definition.budgets.spill_bytes = 2 * 1024 * 1024;
    var text_cut = try cut();
    text_cut.schema = try text_sources[0].schema.fingerprint();
    const cuts = [_]r.Cut{text_cut};
    const bound: r.Bound = .{ .plan = definition, .cuts = &cuts };
    var scratch: [16 * 1024]u8 = undefined;
    var memory: q.fuze.MemoryBudget = .{ .parent = t.allocator, .limit = definition.budgets.resident_bytes - Spill.resident_bytes - scratch.len };
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var spill = try Spill.open(memory.allocator(), t.io, tmp.dir, "text", bound, 1000000, null);
    defer spill.deinit();
    for (0..64) |i| {
        const prefix = try std.fmt.bufPrint(scratch[0..8], "K{d:0>3}:", .{i});
        @memset(scratch[prefix.len..], 'A');
        var value = group(null, i);
        value.key.values[0] = .{ .text = &scratch };
        try spill.put(value);
        @memset(&scratch, 'x');
        try t.expectEqual(@as(usize, 0), memory.used);
    }
    try t.expectEqual(@as(u64, 64 * scratch.len), try spill.text_file.length(t.io));
    try t.expect(try spill.text_file.length(t.io) > definition.budgets.resident_bytes);
    var after: ?e.Key = null;
    defer if (after) |*key| key.deinit();
    for (0..64) |i| {
        var value = (try spill.next(after)).?;
        defer value.deinit();
        const prefix = try std.fmt.bufPrint(scratch[0..8], "K{d:0>3}:", .{i});
        @memset(scratch[prefix.len..], 'A');
        try t.expectEqualStrings(&scratch, value.key.values[0].?.text);
        try t.expectEqual(i, value.states[1].rows);
        // Update using an equivalent new spelling. The original bytes remain.
        scratch[0] = 'k';
        @memset(scratch[prefix.len..], 'a');
        var update = group(null, i + 1);
        update.key.values[0] = .{ .text = &scratch };
        try spill.put(update);
        var retained = (try spill.get(update.key)).?;
        defer retained.deinit();
        try t.expectEqual(@as(u8, 'K'), retained.key.values[0].?.text[0]);
        try t.expectEqual(@as(u8, 'A'), retained.key.values[0].?.text[retained.key.values[0].?.text.len - 1]);
        if (after) |*key| key.deinit();
        after = try value.key.clone(memory.allocator());
    }
    try t.expect(try spill.next(after) == null);
    after.?.deinit();
    after = null;
    try t.expectEqual(@as(usize, 0), memory.used);
    try t.expect(memory.peak <= memory.limit);
    try t.expectEqual(@as(u64, 64 * scratch.len), try spill.text_file.length(t.io));
    try spill.text_file.writePositionalAll(t.io, &.{0}, 5);
    try t.expectError(error.InvalidRelationalSpill, spill.next(null));
    try t.expectEqual(@as(usize, 0), memory.used);
    try t.expectError(error.FailedRelationalSpill, spill.next(null));
}

test "text spill charges payload bytes and poisons allocation failures before disclosure" {
    const text_columns = [_]q.fuze.TableSchema.Column{.{ .id = 1, .name = "key", .type = .utf8, .collation = .utf8_binary }};
    var text_sources = sources;
    text_sources[0].schema.columns = &text_columns;
    var definition = plan();
    definition.sources = &text_sources;
    definition.budgets.spill_bytes = 152 + 8192;
    var text_cut = try cut();
    text_cut.schema = try text_sources[0].schema.fingerprint();
    const cuts = [_]r.Cut{text_cut};
    const bound: r.Bound = .{ .plan = definition, .cuts = &cuts };
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var scratch: [8192]u8 = @splat('a');
    var value = group(null, 1);
    value.key.values[0] = .{ .text = &scratch };
    var spill = try Spill.open(t.allocator, t.io, tmp.dir, "quota-text", bound, 1000, null);
    defer spill.deinit();
    try spill.put(value);
    try t.expectEqual(definition.budgets.spill_bytes, try spill.file.length(t.io) + try spill.text_file.length(t.io));
    scratch[0] = 'b';
    try t.expectError(error.RelationalSpillBudget, spill.put(value));
    try t.expectEqual(@as(u64, 1), spill.count);
    var memory: q.fuze.MemoryBudget = .{ .parent = t.allocator, .limit = 64 * 1024 };
    var limited = try Spill.open(memory.allocator(), t.io, tmp.dir, "memory-text", bound, 1000, null);
    defer limited.deinit();
    try limited.put(value);
    try t.expectEqual(@as(usize, 0), memory.used);
    memory.limit = 0;
    try t.expectError(error.OutOfMemory, limited.get(value.key));
    try t.expect(memory.exhausted);
    try t.expectEqual(@as(usize, 0), memory.used);
    try t.expectError(error.FailedRelationalSpill, limited.next(null));
}
