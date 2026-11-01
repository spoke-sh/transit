//! Typed deterministic scalar instructions for finite query projections.
//! Programs borrow immutable definitions. Execution borrows input cells and
//! uses caller-owned workspace; timezone artifacts are loaded once per reader.
const std = @import("std");
const t = @import("Types.zig");
const decimal = @import("DecimalArithmetic.zig");
const timezone = @import("PinnedTimezone.zig");
const Self = @This();
pub const max_instructions = 32;
pub const DecimalOperation = enum { add, subtract, multiply, divide };
pub const Instruction = union(enum) {
    input: u8,
    decimal_binary: struct { left: u8, right: u8, operation: DecimalOperation, result: t.Decimal, rounding: decimal.RoundingMode },
    decimal_rescale: struct { value: u8, result: t.Decimal, rounding: decimal.RoundingMode },
    at_time_zone: struct { value: u8, rules: timezone.Descriptor },
    time_bucket: struct { value: u8, rules: timezone.Descriptor, width_micros: i64 },
};
pub const json_schema_sequence_bounds = .{ .instructions = max_instructions };
instructions: []const Instruction,

pub const Workspace = struct {
    fields: [max_instructions]t.Field = undefined,
    cells: [max_instructions]t.Values.Cell = undefined,
    zones: [max_instructions]?timezone.Loaded = @splat(null),
};
fn prior(fields: []const t.Field, index: u8) !t.Field {
    if (index >= fields.len) return error.InvalidScalarReference;
    return fields[index];
}
fn decimalField(fields: []const t.Field, index: u8) !t.Field {
    const field = try prior(fields, index);
    if (field.type != .decimal) return error.TypeMismatch;
    return field;
}
fn timestampField(fields: []const t.Field, index: u8) !t.Field {
    const field = try prior(fields, index);
    if (field.type != .timestamp or field.type.timestamp != .utc) return error.TypeMismatch;
    return field;
}
/// The supplied field buffer is retained by the reader and contains the exact
/// result type of every instruction. Instruction references must point backward.
pub fn validate(self: Self, inputs: []const t.Field, output: *[max_instructions]t.Field) ![]const t.Field {
    if (self.instructions.len == 0 or self.instructions.len > max_instructions) return error.ScalarProgramBudget;
    for (self.instructions, 0..) |instruction, i| {
        const fields = output[0..i];
        output[i] = switch (instruction) {
            .input => |index| blk: {
                if (index >= inputs.len) return error.InvalidScalarReference;
                break :blk inputs[index];
            },
            .decimal_binary => |binary| blk: {
                const left = try decimalField(fields, binary.left);
                const right = try decimalField(fields, binary.right);
                const result: t.Type = .{ .decimal = binary.result };
                try result.validate(.{});
                break :blk .{ .name = "decimal", .type = result, .nullable = left.nullable or right.nullable, .optional = left.optional or right.optional };
            },
            .decimal_rescale => |rescale| blk: {
                const source = try decimalField(fields, rescale.value);
                const result: t.Type = .{ .decimal = rescale.result };
                try result.validate(.{});
                break :blk .{ .name = "decimal", .type = result, .nullable = source.nullable, .optional = source.optional };
            },
            inline .at_time_zone, .time_bucket => |temporal, tag| blk: {
                const source = try timestampField(fields, temporal.value);
                try temporal.rules.validate();
                if (comptime tag == .time_bucket) if (temporal.width_micros <= 0) return error.InvalidTimeBucket;
                break :blk .{ .name = "local_time", .type = .{ .timestamp = .civil }, .nullable = source.nullable, .optional = source.optional };
            },
        };
    }
    return output[0..self.instructions.len];
}
pub fn prepare(self: Self, inputs: []const t.Field, work: *Workspace) !void {
    _ = try self.validate(inputs, &work.fields);
    for (self.instructions, 0..) |instruction, i| work.zones[i] = switch (instruction) {
        .at_time_zone => |temporal| try temporal.rules.load(),
        .time_bucket => |temporal| try temporal.rules.load(),
        else => null,
    };
}
/// Called only after prepare, with inputs validated against the original schema.
/// No allocation, schema loading, hashing, clocks or effects occur per row.
pub fn evaluate(self: Self, inputs: []const t.Values.Cell, work: *Workspace) ![]const t.Values.Cell {
    for (self.instructions, 0..) |instruction, i| {
        work.cells[i] = switch (instruction) {
            .input => |index| inputs[index],
            .decimal_binary => |binary| blk: {
                const left = work.cells[binary.left];
                const right = work.cells[binary.right];
                if (try absent(left, right)) |cell| break :blk cell;
                const a = decimalValue(work.fields[binary.left].type.decimal, left);
                const b = decimalValue(work.fields[binary.right].type.decimal, right);
                const result = switch (binary.operation) {
                    .add => try decimal.rescale(try decimal.add(a, b), binary.result.precision, binary.result.scale, binary.rounding),
                    .subtract => try decimal.rescale(try decimal.sub(a, b), binary.result.precision, binary.result.scale, binary.rounding),
                    .multiply => try decimal.mul(a, b, binary.result.precision, binary.result.scale, binary.rounding),
                    .divide => try decimal.div(a, b, binary.result.precision, binary.result.scale, binary.rounding),
                };
                break :blk .{ .value = .{ .atom = .{ .decimal = result.coefficient } } };
            },
            .decimal_rescale => |rescale| blk: {
                const source = work.cells[rescale.value];
                if (try absent(source, source)) |cell| break :blk cell;
                const result = try decimal.rescale(decimalValue(work.fields[rescale.value].type.decimal, source), rescale.result.precision, rescale.result.scale, rescale.rounding);
                break :blk .{ .value = .{ .atom = .{ .decimal = result.coefficient } } };
            },
            inline .at_time_zone, .time_bucket => |temporal, tag| blk: {
                const source = work.cells[temporal.value];
                if (try absent(source, source)) |cell| break :blk cell;
                const timestamp = source.value.atom.timestamp;
                const result = if (comptime tag == .at_time_zone) try work.zones[i].?.utcToLocal(timestamp) else try work.zones[i].?.bucketLocal(timestamp, temporal.width_micros);
                break :blk .{ .value = .{ .atom = .{ .timestamp = result } } };
            },
        };
    }
    return work.cells[0..self.instructions.len];
}
fn decimalValue(descriptor: t.Decimal, cell: t.Values.Cell) decimal.DecimalValue {
    return .{ .coefficient = cell.value.atom.decimal, .precision = descriptor.precision, .scale = descriptor.scale };
}
fn absent(left: t.Values.Cell, right: t.Values.Cell) !?t.Values.Cell {
    // Eager numeric operations examine both operands. A NULL cannot hide an
    // evaluated error/conflict. Missing remains distinct from SQL NULL.
    for ([_]t.Values.Cell{ left, right }) |cell| switch (cell) {
        .type_error => return error.QueryTypeError,
        .conflict => return error.QueryConflict,
        else => {},
    };
    if (left == .missing or right == .missing) return .missing;
    if (left == .null or right == .null) return .null;
    return null;
}

test "scalar programs apply explicit decimal rounding and immutable timezone rules without row allocation" {
    const testing = std.testing;
    const fields = [_]t.Field{
        .{ .name = "a", .type = .{ .decimal = .{ .precision = 8, .scale = 2 } }, .nullable = true, .optional = true },
        .{ .name = "b", .type = .{ .decimal = .{ .precision = 8, .scale = 2 } } },
        .{ .name = "ts", .type = .{ .timestamp = .utc } },
    };
    const rules = try timezone.Descriptor.init("iana-2025b", "Etc/UTC", @embedFile("timezone-fixtures/utc.tzif"));
    const program: Self = .{ .instructions = &.{
        .{ .input = 0 },
        .{ .input = 1 },
        .{ .decimal_binary = .{ .left = 0, .right = 1, .operation = .divide, .result = .{ .precision = 8, .scale = 2 }, .rounding = .half_even } },
        .{ .input = 2 },
        .{ .time_bucket = .{ .value = 3, .rules = rules, .width_micros = 1000000 } },
    } };
    var work: Workspace = .{};
    try program.prepare(&fields, &work);
    var inputs = [_]t.Values.Cell{
        .{ .value = .{ .atom = .{ .decimal = 100 } } },
        .{ .value = .{ .atom = .{ .decimal = 600 } } },
        .{ .value = .{ .atom = .{ .timestamp = -1 } } },
    };
    for (0..1000) |_| {
        const output = try program.evaluate(&inputs, &work);
        try testing.expectEqual(@as(i128, 17), output[2].value.atom.decimal);
        try testing.expectEqual(@as(i64, -1000000), output[4].value.atom.timestamp);
    }
    inputs[0] = .null;
    try testing.expect((try program.evaluate(&inputs, &work))[2] == .null);
    inputs[0] = .missing;
    try testing.expect((try program.evaluate(&inputs, &work))[2] == .missing);
    inputs[1] = .{ .type_error = .utf8 };
    try testing.expectError(error.QueryTypeError, program.evaluate(&inputs, &work));
}
