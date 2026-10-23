const std = @import("std");
const t = std.testing;
const r = @import("Relational.zig");
const e = @import("RelationalExecution.zig");
const Output = @import("RelationalOutput.zig");
const Delta = @import("RelationalDelta.zig");
const columns = [_]@import("TableSchema.zig").Column{.{ .id = 1, .name = "v", .type = .int64, .nullable = true }};
const sources = [_]r.Source{
    .{ .alias = "l", .realm = 1, .resource = 101, .catalog = 9, .owner = 7, .schema = .{ .object = 11, .revision = 1, .next_column = 2, .columns = &columns } },
    .{ .alias = "r", .realm = 1, .resource = 202, .catalog = 9, .owner = 7, .schema = .{ .object = 22, .revision = 1, .next_column = 2, .columns = &columns } },
};
const plan: r.Plan = .{ .sources = &sources, .join = .{ .kind = .left, .left = .{ .source = 0, .id = 1 }, .right = .{ .source = 1, .id = 1 } }, .outputs = &.{.{ .name = "v", .expression = .{ .column = .{ .source = 1, .id = 1 } } }}, .lifetime = .maintained, .budgets = .{ .resident_bytes = 4096, .spill_bytes = 8192, .result_bytes = 16384, .output_rows = 100, .work_steps = 10000, .source_pins = 2 } };
fn cuts(revision: u64) ![2]r.Cut {
    var result: [2]r.Cut = undefined;
    for (sources, 0..) |source, i| result[i] = .{ .domain = .native_resource, .resource = source.resource, .revision = revision, .commitment = @splat(@intCast(revision)), .schema = try source.schema.fingerprint() };
    return result;
}
fn row(bound: r.Bound, ordinal: u64, right: ?r.RowIdentity, value: ?i64) !Output {
    var result: Output = .{ .binding = try bound.fingerprint(), .ordinal = ordinal, .row = .{ .identity = .{ .pair = .{ .left = .{ .origin = 1, .operation = 2, .ordinal = 0 }, .right = right } }, .len = 1 } };
    result.row.cells[0] = if (value) |v| .{ .value = .{ .atom = .{ .signed = v } } } else .null;
    return result;
}
fn roundtrip(value: Delta, previous: ?r.Bound, next: r.Bound) !void {
    var bytes: [Delta.max_bytes + 1]u8 = undefined;
    const encoded = try value.encode(previous, next, &bytes);
    try t.expectEqualDeep(value, try Delta.decode(previous, next, encoded));
    for (0..encoded.len) |length| {
        if (Delta.decode(previous, next, encoded[0..length])) |_| return error.AcceptedIncompleteDelta else |_| {}
    }
    bytes[encoded.len] = 0;
    try t.expectError(error.InvalidRelationalDelta, Delta.decode(previous, next, bytes[0 .. encoded.len + 1]));
    bytes[4] ^= 1;
    try t.expectError(error.IncompatibleDefinition, Delta.decode(previous, next, encoded));
}
test "delta identity preserves outer-match transitions and duplicate projected values" {
    const old_cuts = try cuts(1);
    const next_cuts = try cuts(2);
    const old: r.Bound = .{ .plan = plan, .cuts = &old_cuts };
    const next: r.Bound = .{ .plan = plan, .cuts = &next_cuts };
    const unmatched = try row(old, 0, null, null);
    const first = try row(next, 0, .{ .origin = 3, .operation = 4, .ordinal = 0 }, 7);
    const second = try row(next, 1, .{ .origin = 3, .operation = 4, .ordinal = 1 }, 7);
    try t.expectEqual(.lt, try Delta.identityOrder(unmatched.row.identity, first.row.identity));
    try t.expectEqual(.lt, try Delta.identityOrder(first.row.identity, second.row.identity));
    try t.expect(Delta.sameValues(first.row, second.row));
    try roundtrip(.{ .ordinal = 0, .before = unmatched }, old, next);
    try roundtrip(.{ .ordinal = 1, .after = first }, old, next);
    try roundtrip(.{ .ordinal = 2, .after = second }, old, next);
    // An outer transition changes identities; it cannot be disguised as one
    // same-row update. The complete owner transaction binds both changes.
    var buffer: [Delta.max_bytes]u8 = undefined;
    try t.expectError(error.InvalidRelationalDelta, (Delta{ .ordinal = 0, .before = unmatched, .after = first }).encode(old, next, &buffer));
    try roundtrip(.{ .ordinal = 0, .before = first }, next, old);
    try roundtrip(.{ .ordinal = 1, .after = unmatched }, next, old);
    try roundtrip(.{ .ordinal = 0, .after = first }, null, next);
    try t.expectError(error.InvalidRelationalDelta, (Delta{ .ordinal = 0, .before = unmatched }).encode(null, next, &buffer));
    try t.expectError(error.InvalidRelationalDelta, (Delta{ .ordinal = 0 }).encode(old, next, &buffer));
}
test "paired update carries both complete bases and ignores changing output ordinals" {
    const old_cuts = try cuts(1);
    const next_cuts = try cuts(2);
    const old: r.Bound = .{ .plan = plan, .cuts = &old_cuts };
    const next: r.Bound = .{ .plan = plan, .cuts = &next_cuts };
    const identity: r.RowIdentity = .{ .origin = 3, .operation = 4, .ordinal = 0 };
    const before = try row(old, 8, identity, 7);
    var after = try row(next, 3, identity, 8);
    try roundtrip(.{ .ordinal = 0, .before = before, .after = after }, old, next);
    var bytes: [Delta.max_bytes]u8 = undefined;
    var invalid = before;
    invalid.row.len = 255;
    try t.expectError(error.InvalidRelationalOutput, (Delta{ .ordinal = 0, .before = invalid, .after = after }).encode(old, next, &bytes));
    after.row.cells = before.row.cells;
    try t.expectError(error.InvalidRelationalDelta, (Delta{ .ordinal = 0, .before = before, .after = after }).encode(old, next, &bytes));
    after = try row(next, 3, identity, 8);
    const encoded = try (Delta{ .ordinal = 0, .before = before, .after = after }).encode(old, next, &bytes);
    try t.expectError(error.RelationalSourceChanged, Delta.decode(next, next, encoded));
    const a: @FieldType(e.Output, "identity") = .{ .group = .{ .len = 1 } };
    var b = a;
    b.group.values[0] = -1;
    try t.expectEqual(.lt, try Delta.identityOrder(a, b));
    try t.expectError(error.InvalidRelationalDelta, Delta.identityOrder(a, before.row.identity));
}
