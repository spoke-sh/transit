const std = @import("std");
const t = std.testing;
const s = @import("TableSchema.zig");
const Projection = @import("TableSchemaProjection.zig");
const Cell = @import("Types.zig").Values.Cell;
fn number(value: i128) Cell {
    return .{ .value = .{ .atom = .{ .signed = value } } };
}
const original: s.Schema = .{ .object = 1, .revision = 1, .next_column = 3, .columns = &.{
    .{ .id = 1, .name = "id", .type = .int64, .nullable = false },
    .{ .id = 2, .name = "amount", .type = .int64 },
}, .primary_key = &.{1} };

test "schema projection binds identity and frozen initial values across repeated edits" {
    // Independent eager oracle: original [1, NULL]; ADD score DEFAULT 7;
    // SET DEFAULT 9; rename score; DROP amount; ADD amount DEFAULT 42.
    // Neither name reuse nor the latest default may reinterpret the old row.
    const logical: s.Schema = .{ .object = 1, .revision = 6, .next_column = 5, .columns = &.{
        original.columns[0],
        .{ .id = 3, .name = "rating", .type = .int64, .default = number(9) },
        .{ .id = 4, .name = "amount", .type = .int64, .default = number(42) },
    }, .primary_key = &.{1} };
    const mapping = try Projection.init(original, logical, &.{
        .{ .column = 3, .value = number(7) },
        .{ .column = 4, .value = number(42) },
    });
    var output: [3]Cell = undefined;
    try t.expectEqualDeep(&[_]Cell{ number(1), number(7), number(42) }, try mapping.row(&.{ number(1), .null }, &output));
    try t.expectEqualDeep(&[_]Cell{ number(2), number(9), number(42) }, try logical.insert(&.{.{ .column = 1, .value = .{ .cell = number(2) } }}, &output));
    // An intermediate physical row already owns score=8; the frozen ADD value
    // only fills the new column. No chain of intermediate schemas is needed.
    const intermediate: s.Schema = .{ .object = 1, .revision = 2, .next_column = 4, .columns = &.{
        original.columns[0],                                                 original.columns[1],
        .{ .id = 3, .name = "score", .type = .int64, .default = number(7) },
    }, .primary_key = &.{1} };
    const partial = try Projection.init(intermediate, logical, &.{.{ .column = 4, .value = number(42) }});
    try t.expectEqualDeep(&[_]Cell{ number(1), number(8), number(42) }, try partial.row(&.{ number(1), number(99), number(8) }, &output));
    const normalized = try Projection.init(logical, logical, &.{});
    try t.expectEqualDeep(&[_]Cell{ number(1), number(8), number(42) }, try normalized.row(&.{ number(1), number(8), number(42) }, &output));
    try t.expectError(error.MissingSchemaInitialValue, Projection.init(original, logical, &.{}));
    try t.expectError(error.DuplicateSchemaInitialValue, Projection.init(original, logical, &.{
        .{ .column = 3, .value = number(7) }, .{ .column = 3, .value = number(7) },
    }));
    try t.expectError(error.UnexpectedSchemaInitialValue, Projection.init(logical, logical, &.{.{ .column = 3, .value = number(7) }}));
}

test "schema projection refuses incompatible layouts and reused identities" {
    var columns = [_]s.Column{ original.columns[0], original.columns[1] };
    var logical = original;
    logical.revision = 2;
    logical.columns = &columns;
    columns[1].type = .int32;
    try t.expectError(error.IncompatibleSchemaProjection, Projection.init(original, logical, &.{}));
    columns[1] = original.columns[1];
    columns[1].encoding = .rle;
    try t.expectError(error.IncompatibleSchemaProjection, Projection.init(original, logical, &.{}));
    columns[1] = original.columns[1];
    columns[1].nullable = false;
    try t.expectError(error.IncompatibleSchemaProjection, Projection.init(original, logical, &.{}));
    columns[1] = original.columns[1];
    logical.primary_key = &.{};
    try t.expectError(error.IncompatibleSchemaProjection, Projection.init(original, logical, &.{}));
    logical.primary_key = original.primary_key;
    logical.object = 2;
    try t.expectError(error.IncompatibleSchemaProjection, Projection.init(original, logical, &.{}));
    logical.object = original.object;
    logical.revision = original.revision;
    columns[1].name = "different";
    try t.expectError(error.IncompatibleSchemaProjection, Projection.init(original, logical, &.{}));
    var dropped = original;
    dropped.revision = 2;
    dropped.columns = original.columns[0..1];
    logical.revision = 3;
    try t.expectError(error.ReusedColumnIdentity, Projection.init(dropped, logical, &.{.{ .column = 2, .value = .null }}));
}

test "schema projection preserves null and validates even dropped physical values" {
    var renamed_columns = [_]s.Column{ original.columns[0], original.columns[1] };
    renamed_columns[1].name = "renamed";
    var renamed = original;
    renamed.revision = 2;
    renamed.columns = &renamed_columns;
    const mapping = try Projection.init(original, renamed, &.{});
    var output: [2]Cell = undefined;
    try t.expectEqualDeep(&[_]Cell{ number(1), .null }, try mapping.row(&.{ number(1), .null }, &output));
    try t.expectError(error.RowBufferTooSmall, mapping.row(&.{ number(1), .null }, output[0..1]));
    var dropped = renamed;
    dropped.revision = 3;
    dropped.columns = renamed.columns[0..1];
    const drop = try Projection.init(original, dropped, &.{});
    try t.expectError(error.InvalidRowWidth, drop.row(&.{number(1)}, &output));
    // The discarded cell remains subject to the original physical type.
    try t.expectError(error.TypeMismatch, drop.row(&.{ number(1), .{ .value = .{ .atom = .{ .bytes = "invalid" } } } }, &output));
    try t.expectError(error.MissingRequiredField, drop.row(&.{ number(1), .missing }, &output));
    try t.expectError(error.TableTypeError, drop.row(&.{ number(1), .{ .type_error = .utf8 } }, &output));
    try t.expectError(error.TableConflict, drop.row(&.{ number(1), .{ .conflict = &.{
        .{ .counter = 1, .replica = 1, .value = .{ .value = .{ .atom = .{ .signed = 1 } } } },
        .{ .counter = 2, .replica = 1, .value = .{ .value = .{ .atom = .{ .signed = 2 } } } },
    } } }, &output));
}

test "schema projection keeps nested missing distinct from SQL null" {
    const physical: s.Schema = .{ .object = 1, .revision = 1, .next_column = 2, .columns = &.{.{
        .id = 1,
        .name = "payload",
        .type = .{ .structure = &.{.{ .name = "n", .type = .int64, .optional = true }} },
    }} };
    var columns = [_]s.Column{physical.columns[0]};
    columns[0].name = "renamed";
    var logical = physical;
    logical.revision = 2;
    logical.columns = &columns;
    const mapping = try Projection.init(physical, logical, &.{});
    var output: [1]Cell = undefined;
    const row = try mapping.row(&.{.{ .value = .{ .structure = &.{.missing} } }}, &output);
    try t.expect(row[0].value.structure[0] == .missing);
    try t.expect((try mapping.row(&.{.null}, &output))[0] == .null);
}
