//! Owned finite SELECT templates. Bind values into the ordinary typed plan;
//! source authorization, resource identity and admission belong to the caller.
const std = @import("std");
const sql = @import("Sql.zig");
const lowering = @import("SqlLowering.zig");
const m = @import("Unified.zig");
const Self = @This();

/// The grammar has one comparison and two limit positions. This bounds one
/// template's parameters, never the number of retained application templates.
pub const max_parameters = std.meta.fieldNames(sql.ParameterSites).len;

arena: std.heap.ArenaAllocator,
prototype: m.Plan,
source_name: m.Name,
schema_fingerprint: [32]u8,
types: [max_parameters]m.Type,
count: u8,
comparison: ?u32,
limit: ?u32,

pub const Bound = struct {
    arena: std.heap.ArenaAllocator,
    plan: m.Plan,
    pub fn deinit(self: *Bound) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

pub fn init(allocator: std.mem.Allocator, text: []const u8, source: m.Sql.Source) !Self {
    try validSource(source);
    var syntax = try sql.parseTemplate(text, null);
    // Only this construction pass replaces unresolved values with typed
    // witnesses. The public template AST remains rejected by ordinary lowering.
    syntax.ast.unbound_parameters = false;
    var names: [m.max_columns][]const u8 = undefined;
    for (source.schema.columns, 0..) |*column, i| names[i] = column.name.slice();
    var input: [m.max_columns]u8 = undefined;
    var output: [m.max_columns]u8 = undefined;
    const shape = try lowering.lower(&syntax.ast, source.name.slice(), names[0..source.schema.columns.len], &input, &output);
    var types: [max_parameters]m.Type = @splat(.int64);
    var present: [max_parameters]bool = @splat(false);
    var count: u8 = 0;
    if (syntax.parameters.comparison) |index| {
        if (shape.predicate != .compare) return error.InvalidParameterSite;
        const kind = source.schema.columns[shape.predicate.compare.column].type;
        try register(&types, &present, &count, index, kind);
        syntax.ast.predicate.compare.literal = witness(kind);
    }
    if (syntax.parameters.limit) |index| try register(&types, &present, &count, index, .uint64);
    if (syntax.parameters.input_limit) |index| try register(&types, &present, &count, index, .uint64);
    for (present[0..count]) |used| if (!used) return error.ParameterGap;
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const plan = try m.Sql.compile(arena.allocator(), syntax.ast, source);
    return .{
        .arena = arena,
        .prototype = plan,
        .source_name = source.name,
        .schema_fingerprint = try source.schema.fingerprint(),
        .types = types,
        .count = count,
        .comparison = syntax.parameters.comparison,
        .limit = if (syntax.ast.input != null) syntax.parameters.input_limit else syntax.parameters.limit,
    };
}

pub fn deinit(self: *Self) void {
    self.arena.deinit();
    self.* = undefined;
}

pub fn parameterTypes(self: *const Self) []const m.Type {
    return self.types[0..self.count];
}

/// The caller supplies a currently resolved source; equal names/types are not
/// permission or resource identity. Values and source schema may be released
/// after this call. The returned plan owns its projection and literal bytes.
pub fn bind(self: *const Self, allocator: std.mem.Allocator, source: m.Sql.Source, values: []const m.Scalar) !Bound {
    try validSource(source);
    if (!std.meta.eql(source.name, self.source_name) or !std.mem.eql(u8, &try source.schema.fingerprint(), &self.schema_fingerprint)) return error.SourceChanged;
    if (self.count > max_parameters or values.len != self.count) return error.ParameterCountMismatch;
    for (values, self.parameterTypes()) |value, kind| try value.validate(kind);
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const alloc = arena.allocator();
    var plan = self.prototype;
    plan.projection = try alloc.dupe(u8, plan.projection);
    if (self.comparison) |index| {
        if (index == 0 or index > values.len or plan.predicate != .compare) return error.InvalidParameterSite;
        plan.predicate.compare.value = values[index - 1];
    }
    if (plan.predicate == .compare) plan.predicate.compare.value = try copyScalar(alloc, plan.predicate.compare.value);
    if (self.limit) |index| {
        if (index == 0 or index > values.len or values[index - 1] != .uint64) return error.InvalidParameterSite;
        plan.limit = values[index - 1].uint64;
    }
    try plan.validate(source.schema);
    return .{ .arena = arena, .plan = plan };
}

fn register(types: *[max_parameters]m.Type, present: *[max_parameters]bool, count: *u8, index: u32, kind: m.Type) !void {
    if (index == 0) return error.InvalidParameterIndex;
    // More distinct ordinals than grammar sites necessarily leave a gap.
    if (index > max_parameters) return error.ParameterGap;
    const offset = index - 1;
    if (present[offset] and types[offset] != kind) return error.ParameterTypeConflict;
    types[offset] = kind;
    present[offset] = true;
    count.* = @max(count.*, @as(u8, @intCast(index)));
}

fn validSource(source: m.Sql.Source) !void {
    if (source.name.len > source.name.bytes.len or !std.meta.eql(source.name, try m.Name.init(source.name.slice()))) return error.InvalidColumnName;
    try source.schema.validate();
}

fn witness(kind: m.Type) sql.Literal {
    return switch (kind) {
        .int64 => .{ .int64 = 0 },
        .uint64 => .{ .uint64 = 0 },
        .float64 => .{ .float64 = 0 },
        .boolean => .{ .boolean = false },
        .utf8 => .{ .utf8 = .{} },
        .binary => blk: {
            var text: sql.Text = .{ .len = 2 };
            text.bytes[0..2].* = "\\x".*;
            break :blk .{ .binary = text };
        },
    };
}

fn copyScalar(allocator: std.mem.Allocator, value: m.Scalar) !m.Scalar {
    return switch (value) {
        .utf8 => |bytes| .{ .utf8 = try allocator.dupe(u8, bytes) },
        .binary => |bytes| .{ .binary = try allocator.dupe(u8, bytes) },
        else => value,
    };
}
