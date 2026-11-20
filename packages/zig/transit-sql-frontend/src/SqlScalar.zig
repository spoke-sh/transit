//! Bounded, schema-independent scalar syntax. Binding supplies exact column
//! semantics; names never trigger host locale, timezone or other I/O.
const std = @import("std");
const t = @import("Types.zig");
const Parser = @import("SqlTyped.zig");
const Reference = @import("SqlReference.zig");
const Program = @import("ScalarProgram.zig");
const Semantics = @import("ColumnSemantics.zig");
const Metric = @import("VectorMetric.zig").Metric;
const Rounding = @import("DecimalArithmetic.zig").RoundingMode;
const Fold = @import("PinnedTimezone.zig").Fold;
const Function = enum { decimal_add, decimal_subtract, decimal_multiply, decimal_divide, decimal_rescale, range_overlaps, range_contains, range_adjacent, range_compare, vector_distance, time_bucket, local_to_utc };
const Functions = @import("PerfectHash.zig").ComptimeMap(Function, true, .{
    .{ "DECIMAL_ADD", .decimal_add },           .{ "DECIMAL_SUBTRACT", .decimal_subtract },
    .{ "DECIMAL_MULTIPLY", .decimal_multiply }, .{ "DECIMAL_DIVIDE", .decimal_divide },
    .{ "DECIMAL_RESCALE", .decimal_rescale },   .{ "RANGE_OVERLAPS", .range_overlaps },
    .{ "RANGE_CONTAINS", .range_contains },     .{ "RANGE_ADJACENT", .range_adjacent },
    .{ "RANGE_COMPARE", .range_compare },       .{ "VECTOR_DISTANCE", .vector_distance },
    .{ "TIME_BUCKET", .time_bucket },           .{ "LOCAL_TO_UTC", .local_to_utc },
});
const Node = union(enum) {
    input: Reference,
    decimal_binary: @FieldType(Program.Instruction, "decimal_binary"),
    decimal_rescale: @FieldType(Program.Instruction, "decimal_rescale"),
    range_binary: @FieldType(Program.Instruction, "range_binary"),
    vector_distance: struct { left: u8, right: u8, metric: ?Metric },
    temporal: struct { value: u8, zone: []const u8, operation: enum { at_time_zone, time_bucket, local_to_utc }, width: i64 = 0, fold: Fold = .reject },
};
pub const Syntax = struct { nodes: []const Node };
const Parse = struct {
    nodes: [Program.max_instructions]Node = undefined,
    len: u8 = 0,
    fn append(self: *Parse, node: Node) !u8 {
        if (self.len == self.nodes.len) return error.ScalarProgramBudget;
        const index = self.len;
        self.nodes[index] = node;
        self.len += 1;
        return index;
    }
    fn expression(self: *Parse, parser: *Parser, depth: u8) anyerror!u8 {
        if (depth >= Program.max_instructions) return error.ScalarProgramBudget;
        return self.initial(parser, try Reference.parse(parser), depth);
    }
    fn initial(self: *Parse, parser: *Parser, first: Reference, depth: u8) anyerror!u8 {
        var result: u8 = undefined;
        if (try parser.take(.left)) {
            if (first.qualifier != null) return error.UnsupportedScalarFunction;
            const function = Functions.get(first.name) orelse return error.UnsupportedScalarFunction;
            const left = try self.expression(parser, depth + 1);
            try parser.require(.comma);
            result = switch (function) {
                .decimal_add, .decimal_subtract, .decimal_multiply, .decimal_divide => blk: {
                    const right = try self.expression(parser, depth + 1);
                    try parser.require(.comma);
                    const descriptor = try decimalResult(parser);
                    try parser.require(.comma);
                    const rounding = try enumeration(Rounding, parser);
                    break :blk try self.append(.{ .decimal_binary = .{ .left = left, .right = right, .operation = switch (function) {
                        .decimal_add => .add,
                        .decimal_subtract => .subtract,
                        .decimal_multiply => .multiply,
                        .decimal_divide => .divide,
                        else => unreachable,
                    }, .result = descriptor, .rounding = rounding } });
                },
                .decimal_rescale => blk: {
                    const descriptor = try decimalResult(parser);
                    try parser.require(.comma);
                    break :blk try self.append(.{ .decimal_rescale = .{ .value = left, .result = descriptor, .rounding = try enumeration(Rounding, parser) } });
                },
                .range_overlaps, .range_contains, .range_adjacent, .range_compare => blk: {
                    const right = try self.expression(parser, depth + 1);
                    break :blk try self.append(.{ .range_binary = .{ .left = left, .right = right, .operation = switch (function) {
                        .range_overlaps => .overlaps,
                        .range_contains => .contains,
                        .range_adjacent => .adjacent,
                        .range_compare => .compare,
                        else => unreachable,
                    } } });
                },
                .vector_distance => blk: {
                    const right = try self.expression(parser, depth + 1);
                    const metric = if (try parser.take(.comma)) try enumeration(Metric, parser) else null;
                    break :blk try self.append(.{ .vector_distance = .{ .left = left, .right = right, .metric = metric } });
                },
                .time_bucket => blk: {
                    const width = try number(i64, parser);
                    try parser.require(.comma);
                    break :blk try self.append(.{ .temporal = .{ .value = left, .zone = try zoneName(parser), .operation = .time_bucket, .width = width } });
                },
                .local_to_utc => blk: {
                    const zone = try zoneName(parser);
                    try parser.require(.comma);
                    break :blk try self.append(.{ .temporal = .{ .value = left, .zone = zone, .operation = .local_to_utc, .fold = try enumeration(Fold, parser) } });
                },
            };
            try parser.require(.right);
        } else result = try self.append(.{ .input = first });
        if (try parser.takeWord("AT")) {
            try parser.requireWord("TIME");
            try parser.requireWord("ZONE");
            result = try self.append(.{ .temporal = .{ .value = result, .zone = try zoneName(parser), .operation = .at_time_zone } });
        }
        return result;
    }
};
fn number(comptime T: type, parser: *Parser) !T {
    if (parser.token.tag != .integer) return error.InvalidSqlSyntax;
    const result = std.fmt.parseInt(T, parser.token.text, 10) catch return error.LiteralOutOfRange;
    parser.annotate(.number);
    try parser.advance();
    return result;
}
fn decimalResult(parser: *Parser) !t.Decimal {
    const precision = try number(u8, parser);
    try parser.require(.comma);
    const scale = try number(u8, parser);
    const result: t.Type = .{ .decimal = .{ .precision = precision, .scale = scale } };
    try result.validate(.{});
    return result.decimal;
}
fn enumeration(comptime E: type, parser: *Parser) !E {
    const Map = comptime blk: {
        const fields = @typeInfo(E).@"enum";
        var entries: [fields.field_names.len]struct { []const u8, E } = undefined;
        for (fields.field_names, fields.field_values, &entries) |name, value, *entry| entry.* = .{ name, @fromBackingInt(@intCast(value)) };
        break :blk @import("PerfectHash.zig").ComptimeMap(E, true, entries);
    };
    if (parser.token.tag != .word) return error.InvalidScalarOption;
    const result = Map.get(parser.token.text) orelse return error.InvalidScalarOption;
    parser.annotate(.keyword);
    try parser.advance();
    return result;
}
fn zoneName(parser: *Parser) ![]const u8 {
    const literal = try parser.literal(.utf8);
    if (literal.value != .string) return error.InvalidScalarOption;
    return literal.value.string;
}
/// The first reference has already been parsed for source-name discovery.
/// Ordinary column projections keep their existing representation and budgets.
pub fn parse(parser: *Parser, first: Reference) !?Syntax {
    if (parser.token.tag != .left and !parser.word("AT")) return null;
    var state: Parse = .{};
    _ = try state.initial(parser, first, 0);
    return .{ .nodes = try parser.allocator.dupe(Node, state.nodes[0..state.len]) };
}
pub const Builder = struct {
    instructions: [Program.max_instructions]Program.Instruction = undefined,
    len: u8 = 0,
    fn semantic(self: *const Builder, ordinal: u8, semantics: []const Semantics) !Semantics {
        const instruction = self.instructions[ordinal];
        return switch (instruction) {
            .input => |column| if (column < semantics.len) semantics[column] else error.MissingColumnSemantics,
            inline .at_time_zone, .time_bucket, .local_to_utc => |value| .{ .timezone = value.rules },
            else => error.MissingColumnSemantics,
        };
    }
    pub fn bind(self: *Builder, syntax: Syntax, allocator: std.mem.Allocator, fields: []const t.Field, qualifier: []const u8, semantics: []const Semantics, location: ?*@import("Sql.zig").Location) !u8 {
        const base = self.len;
        if (syntax.nodes.len == 0 or syntax.nodes.len > self.instructions.len - self.len) return error.ScalarProgramBudget;
        for (syntax.nodes) |node| {
            self.instructions[self.len] = switch (node) {
                .input => |column| .{ .input = @intCast(try column.resolve(qualifier, fields, location)) },
                inline .decimal_binary, .range_binary => |value, tag| blk: {
                    var copy = value;
                    copy.left += base;
                    copy.right += base;
                    break :blk @unionInit(Program.Instruction, @tagName(tag), copy);
                },
                .decimal_rescale => |value| blk: {
                    var copy = value;
                    copy.value += base;
                    break :blk .{ .decimal_rescale = copy };
                },
                .vector_distance => |value| blk: {
                    const left = base + value.left;
                    const right = base + value.right;
                    const metric = value.metric orelse selected: {
                        const a = (try self.semantic(left, semantics)).metric orelse return error.MissingColumnSemantics;
                        const b = (try self.semantic(right, semantics)).metric orelse return error.MissingColumnSemantics;
                        if (a != b) return error.IncompatibleVectorMetric;
                        break :selected a;
                    };
                    break :blk .{ .vector_distance = .{ .left = left, .right = right, .metric = metric } };
                },
                .temporal => |value| blk: {
                    const input = value.value + base;
                    const rules = (try self.semantic(input, semantics)).timezone orelse return error.MissingColumnSemantics;
                    if (!std.mem.eql(u8, rules.zone, value.zone)) return error.TimezoneDefinitionMismatch;
                    const owned = try rules.cloneInto(allocator);
                    break :blk switch (value.operation) {
                        .at_time_zone => .{ .at_time_zone = .{ .value = input, .rules = owned } },
                        .time_bucket => .{ .time_bucket = .{ .value = input, .rules = owned, .width_micros = value.width } },
                        .local_to_utc => .{ .local_to_utc = .{ .value = input, .rules = owned, .fold = value.fold } },
                    };
                },
            };
            self.len += 1;
        }
        return @intCast(fields.len + self.len - 1);
    }
    pub fn finish(self: Builder, allocator: std.mem.Allocator) !Program {
        return .{ .instructions = try allocator.dupe(Program.Instruction, self.instructions[0..self.len]) };
    }
};
