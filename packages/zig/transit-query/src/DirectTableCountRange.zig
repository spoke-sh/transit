//! Owned full-key bounds for order-independent finite COUNT(*) execution.
//! Qualification never changes the logical predicate or admits a new profile.
const std = @import("std");
const q = @import("root.zig");
const f = q.fuze;
const Range = q.storage.TablePartition.KeyRange;
const Self = @This();
const Bound = struct { key: Range.Key, inclusive: bool };

lower: ?Bound = null,
upper: ?Bound = null,

pub fn interval(self: *const Self) Range {
    return .{
        .lower = if (self.lower) |*bound| .{ .key = bound.key.slice(), .inclusive = bound.inclusive } else null,
        .upper = if (self.upper) |*bound| .{ .key = bound.key.slice(), .inclusive = bound.inclusive } else null,
    };
}

/// Only conjunctions of comparisons on one complete, scalar primary key.
/// Row order, LIMIT selection, SUM overflow and other predicate failures keep
/// their original identity traversal. Literals outside the stored key profile
/// remain valid query operands; inability to encode a bound means a full scan.
pub fn qualify(schema: f.TableSchema.Schema, plan: f.LogicalQuery.Plan) ?Self {
    if (plan.aggregate != .count or plan.limit != null or schema.primary_key.len != 1) return null;
    schema.validate() catch return null;
    plan.validate() catch return null;
    const column = schema.index(schema.primary_key[0]) catch return null;
    if (!std.meta.eql(plan.collations, f.QueryCollations.fromTable(schema))) {
        // NONE and UTF8_BINARY have the same comparison order.
        for (schema.columns, plan.collations.columns[0..schema.columns.len]) |field, declared| {
            if (field.collation == declared) continue;
            if ((field.collation == .none or field.collation == .utf8_binary) and (declared == .none or declared == .utf8_binary)) continue;
            return null;
        }
    }
    var single: [1]f.LogicalPredicate.Program.Instruction = undefined;
    const program: f.LogicalPredicate.Program = switch (plan.predicate) {
        .program => |value| value,
        .compare => |value| blk: {
            single[0] = .{ .atom = .{ .compare = value } };
            break :blk .{ .instructions = &single };
        },
        else => return null,
    };
    var result: Self = .{};
    for (program.instructions) |instruction| switch (instruction) {
        .conjunction => {},
        .negate, .disjunction => return null,
        .atom => |atom| {
            if (atom != .compare or atom.compare.column != column or atom.compare.op == .ne) return null;
            const cells = [_]f.Types.Values.Cell{.{ .value = .{ .atom = atom.compare.value } }};
            schema.validateKey(&cells) catch return null;
            var buffer: [f.Collation.max_sort_key_bytes]u8 = undefined;
            const encoded = f.Collation.encodePrimaryKeySortKey(schema, &cells, false, &buffer) catch return null;
            const bound: Bound = .{
                .key = Range.Key.init(encoded) catch return null,
                .inclusive = switch (atom.compare.op) {
                    .eq, .le, .ge => true,
                    else => false,
                },
            };
            switch (atom.compare.op) {
                .eq => {
                    tighten(&result.lower, bound, .gt);
                    tighten(&result.upper, bound, .lt);
                },
                .gt, .ge => tighten(&result.lower, bound, .gt),
                .lt, .le => tighten(&result.upper, bound, .lt),
                .ne => unreachable,
            }
        },
    };
    return if (result.lower == null and result.upper == null) null else result;
}

fn tighten(slot: *?Bound, candidate: Bound, direction: std.math.Order) void {
    if (slot.*) |*current| {
        const order = std.mem.order(u8, candidate.key.slice(), current.key.slice());
        if (order == .eq) {
            current.inclusive = current.inclusive and candidate.inclusive;
        } else if (order == direction) slot.* = candidate;
    } else slot.* = candidate;
}
