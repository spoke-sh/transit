const std = @import("std");
const e = std.testing;
const s = @import("TableSchema.zig");
const evolution = @import("TableEvolution.zig");
const Cell = @import("Types.zig").Values.Cell;
const before: s.Schema = .{ .object = 1, .revision = 1, .next_column = 3, .columns = &.{
    .{ .id = 1, .name = "id", .type = .int64, .nullable = false },
    .{ .id = 2, .name = "amount", .type = .int64, .default = number(7) },
}, .primary_key = &.{1} };
fn number(value: i128) Cell {
    return .{ .value = .{ .atom = .{ .signed = value } } };
}
test "lazy schema evolution admits only independently projectable edits" {
    var columns: [s.max_columns]s.Column = undefined;
    for ([_]evolution.Change{
        .{ .rename = .{ .column = 2, .name = "renamed" } },
        .{ .default = .{ .column = 2, .value = number(9) } },
        .{ .drop = 2 },
        .{ .add = .{ .name = "optional", .type = .utf8 } },
        .{ .add = .{ .name = "filled", .type = .int64, .nullable = false, .default = number(7) } },
    }) |change| try e.expect(try (try evolution.apply(before, change, &columns)).canProject());
    for ([_]evolution.Change{
        .{ .rename = .{ .column = 1, .name = "new_key_name" } },
        .{ .type = .{ .column = 2, .type = .int32 } },
        .{ .physical = .{ .column = 2, .encoding = .rle } },
        .{ .nullable = .{ .column = 2, .value = false } },
        .{ .add = .{ .name = "required", .type = .int64, .nullable = false } },
    }) |change| try e.expect(!try (try evolution.apply(before, change, &columns)).canProject());
}
test "failed schema conversion identifies the actual stable column without rebinding names" {
    var columns: [s.max_columns]s.Column = undefined;
    var output: [3]Cell = undefined;
    var failed: ?s.ColumnId = null;
    const narrower = try evolution.apply(before, .{ .type = .{ .column = 2, .type = .int8 } }, &columns);
    try e.expectError(error.Overflow, narrower.rowDetailed(&.{ number(1), number(128) }, &output, &failed));
    try e.expectEqual(@as(?u64, 2), failed);
    _ = try narrower.rowDetailed(&.{ number(1), number(127) }, &output, &failed);
    try e.expectEqual(null, failed);
    const tightened = try evolution.apply(before, .{ .nullable = .{ .column = 2, .value = false } }, &columns);
    try e.expectError(error.NullNotAllowed, tightened.rowDetailed(&.{ number(1), .null }, &output, &failed));
    try e.expectEqual(@as(?u64, 2), failed);
    const added = try evolution.apply(before, .{ .add = .{ .name = "new", .type = .utf8, .nullable = false } }, &columns);
    try e.expectError(error.MissingRequiredField, added.rowDetailed(&.{ number(1), .null }, &output, &failed));
    try e.expectEqual(@as(?u64, 3), failed);
}
test "metadata defaults affect future inserts and never rewrite an existing value" {
    var columns: [s.max_columns]s.Column = undefined;
    const transition = try evolution.apply(before, .{ .default = .{ .column = 2, .value = number(9) } }, &columns);
    try e.expectEqual(evolution.Work.metadata, transition.work);
    var cells: [3]Cell = undefined;
    try e.expectEqualDeep(number(7), (try transition.row(&.{ number(1), number(7) }, &cells))[1]);
    try e.expectEqualDeep(number(9), (try transition.after.insert(&.{.{ .column = 1, .value = .{ .cell = number(2) } }}, &cells))[1]);
    const dropped = try evolution.apply(before, .{ .default = .{ .column = 2, .value = null } }, &columns);
    try e.expect((try dropped.after.insert(&.{.{ .column = 1, .value = .{ .cell = number(2) } }}, &cells))[1] == .null);
}
test "renames preserve identity and removed column IDs cannot be reused" {
    var first: [s.max_columns]s.Column = undefined;
    var second: [s.max_columns]s.Column = undefined;
    var third: [s.max_columns]s.Column = undefined;
    const renamed = try evolution.apply(before, .{ .rename = .{ .column = 2, .name = "balance" } }, &first);
    try e.expectEqual(evolution.Work.metadata, renamed.work);
    try e.expectEqual(@as(u64, 2), renamed.after.columns[1].id);
    const removed = try evolution.apply(renamed.after, .{ .drop = 2 }, &second);
    const added = try evolution.apply(removed.after, .{ .add = .{ .name = "balance", .type = .int64 } }, &third);
    try e.expectEqual(@as(u64, 3), added.after.columns[1].id);
    try e.expectEqual(@as(u64, 4), added.after.next_column);
    var output: [2]Cell = undefined;
    try e.expect((try added.row(&.{number(1)}, &output))[1] == .null);
    try e.expectError(error.PrimaryKeyColumnRequired, evolution.apply(before, .{ .drop = 1 }, &first));
    try e.expectError(error.DuplicateColumn, evolution.apply(before, .{ .rename = .{ .column = 2, .name = "id" } }, &first));
}
test "tightened nullability and added required columns validate old rows" {
    var columns: [s.max_columns]s.Column = undefined;
    var output: [3]Cell = undefined;
    const tightened = try evolution.apply(before, .{ .nullable = .{ .column = 2, .value = false } }, &columns);
    try e.expectEqual(evolution.Work.rewrite_rows, tightened.work);
    try e.expectError(error.NullNotAllowed, tightened.row(&.{ number(1), .null }, &output));
    _ = try tightened.row(&.{ number(1), number(0) }, &output);
    const required = try evolution.apply(before, .{ .add = .{ .name = "extra", .type = .boolean, .nullable = false } }, &columns);
    try e.expectError(error.MissingRequiredField, required.row(&.{ number(1), .null }, &output));
    const defaulted = try evolution.apply(before, .{ .add = .{ .name = "extra", .type = .int64, .nullable = false, .default = number(42) } }, &columns);
    try e.expectEqualDeep(number(42), (try defaulted.row(&.{ number(1), .null }, &output))[2]);
    try e.expectError(error.NullablePrimaryKey, evolution.apply(before, .{ .nullable = .{ .column = 1, .value = true } }, &columns));
}
test "type rewrites are exact and refuse overflow rounding and unqualified casts" {
    var columns: [s.max_columns]s.Column = undefined;
    var output: [2]Cell = undefined;
    const narrower = try evolution.apply(before, .{ .type = .{ .column = 2, .type = .int8 } }, &columns);
    try e.expectEqual(evolution.Work.rewrite_rows, narrower.work);
    try e.expectError(error.Overflow, narrower.row(&.{ number(1), number(128) }, &output));
    _ = try narrower.row(&.{ number(1), number(127) }, &output);
    const floating = try evolution.apply(before, .{ .type = .{ .column = 2, .type = .float64 } }, &columns);
    try e.expectError(error.Inexact, floating.row(&.{ number(1), number(9007199254740993) }, &output));
    try e.expectError(error.UnsupportedSchemaConversion, evolution.apply(before, .{ .type = .{ .column = 2, .type = .utf8 } }, &columns));
    const key = try evolution.apply(before, .{ .type = .{ .column = 1, .type = .int32 } }, &columns);
    try e.expect(key.rebuild_key);
    const decimal = try evolution.apply(before, .{ .type = .{ .column = 2, .type = .{ .decimal = .{ .precision = 8, .scale = 2 } } } }, &columns);
    try e.expectEqual(@as(i128, 700), decimal.after.columns[1].default.?.value.atom.decimal);
    try e.expectEqual(@as(i128, 1200), (try decimal.row(&.{ number(1), number(12) }, &output))[1].value.atom.decimal);
}
test "physical encoding and collation transitions classify rewrite and key rebuild requirements" {
    const keyed_text: s.Schema = .{
        .object = 1,
        .revision = 1,
        .next_column = 3,
        .columns = &.{
            .{ .id = 1, .name = "code", .type = .utf8, .nullable = false },
            .{ .id = 2, .name = "amount", .type = .int64, .nullable = false },
        },
        .primary_key = &.{1},
    };
    var columns: [s.max_columns]s.Column = undefined;
    const recoded = try evolution.apply(keyed_text, .{ .physical = .{ .column = 2, .encoding = .bitpacked, .collation = .none } }, &columns);
    try e.expectEqual(evolution.Work.rewrite_rows, recoded.work);
    try e.expect(!recoded.rebuild_key);

    const recollated = try evolution.apply(keyed_text, .{ .physical = .{ .column = 1, .encoding = .ebcdic, .collation = .ebcdic_cp037 } }, &columns);
    try e.expectEqual(evolution.Work.rewrite_rows, recollated.work);
    try e.expect(recollated.rebuild_key);

    try e.expectError(error.IncompatibleColumnCollation, evolution.apply(keyed_text, .{ .physical = .{ .column = 2, .encoding = .plain, .collation = .ascii_ci } }, &columns));
}
