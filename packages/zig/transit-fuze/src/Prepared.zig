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
sites: sql.ParameterSites,

pub const Bound = struct {
    arena: std.heap.ArenaAllocator,
    plan: m.Plan,
    pub fn deinit(self: *Bound) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

pub fn init(allocator: std.mem.Allocator, text: []const u8, source: m.Sql.Source) !Self {
    return initDiagnostic(allocator, text, source, null);
}
pub fn initDiagnostic(allocator: std.mem.Allocator, text: []const u8, source: m.Sql.Source, detail: ?*sql.Binding) !Self {
    if (detail) |value| value.* = .{};
    try validSource(source);
    var location: sql.Location = .{};
    var syntax = sql.parseTemplate(text, &location) catch |err| {
        if (detail) |value| value.location = location;
        return err;
    };
    // Only this construction pass replaces unresolved values with typed
    // witnesses. The public template AST remains rejected by ordinary lowering.
    syntax.ast.unbound_parameters = false;
    var names: [m.max_columns][]const u8 = undefined;
    for (source.schema.columns, 0..) |*column, i| names[i] = column.name.slice();
    var input: [m.max_columns]u8 = undefined;
    var output: [m.max_columns]u8 = undefined;
    const shape = try lowering.lowerDiagnostic(&syntax.ast, source.name.slice(), names[0..source.schema.columns.len], &input, &output, detail);
    var types: [max_parameters]m.Type = @splat(.int64);
    var present: [max_parameters]bool = @splat(false);
    var count: u8 = 0;
    if (syntax.parameters.comparison) |site| {
        if (shape.predicate != .compare) return error.InvalidParameterSite;
        const kind = source.schema.columns[shape.predicate.compare.column].type;
        try register(&types, &present, &count, site, kind, syntax.parameters, detail);
        syntax.ast.predicate.compare.literal = witness(kind);
    }
    if (syntax.parameters.limit) |site| try register(&types, &present, &count, site, .uint64, syntax.parameters, detail);
    if (syntax.parameters.input_limit) |site| try register(&types, &present, &count, site, .uint64, syntax.parameters, detail);
    for (present[0..count], 0..) |used, i| if (!used) {
        if (detail) |value| value.missing_parameter = @intCast(i + 1);
        return error.ParameterGap;
    };
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    if (detail) |value| value.* = .{};
    const plan = try m.Sql.compileDiagnostic(arena.allocator(), syntax.ast, source, detail);
    return .{
        .arena = arena,
        .prototype = plan,
        .source_name = source.name,
        .schema_fingerprint = try source.schema.fingerprint(),
        .types = types,
        .count = count,
        .comparison = if (syntax.parameters.comparison) |site| site.index else null,
        .limit = if (if (syntax.ast.input != null) syntax.parameters.input_limit else syntax.parameters.limit) |site| site.index else null,
        .sites = syntax.parameters,
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
    return self.bindDiagnostic(allocator, source, values, null);
}
pub fn bindDiagnostic(self: *const Self, allocator: std.mem.Allocator, source: m.Sql.Source, values: []const m.Scalar, detail: ?*sql.Binding) !Bound {
    if (detail) |value| value.* = .{};
    try validSource(source);
    const actual_schema = try source.schema.fingerprint();
    if (!std.meta.eql(source.name, self.source_name) or !std.mem.eql(u8, &actual_schema, &self.schema_fingerprint)) {
        if (detail) |value| {
            value.subject = try sql.Binding.Name.init(self.source_name.slice());
            value.expected_schema = self.schema_fingerprint;
            value.actual_schema = actual_schema;
        }
        return error.SourceChanged;
    }
    if (self.count > max_parameters or values.len != self.count) {
        if (detail) |value| {
            value.expected_count = self.count;
            value.actual_count = values.len;
        }
        return error.ParameterCountMismatch;
    }
    for (values, self.parameterTypes(), 0..) |value, kind, i| value.validate(kind) catch |err| {
        sql.Binding.parameterAt(detail, self.sites, @intCast(i + 1));
        if (detail) |context| {
            context.expected = @tagName(kind);
            context.actual = @tagName(value);
            sql.Binding.supplied(context, value);
        }
        return err;
    };
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

fn register(types: *[max_parameters]m.Type, present: *[max_parameters]bool, count: *u8, site: sql.Parameter, kind: m.Type, sites: sql.ParameterSites, detail: ?*sql.Binding) !void {
    const index = site.index;
    sql.Binding.parameterAt(detail, sites, index);
    if (detail) |value| value.location = .{ .offset = site.offset };
    if (index == 0) return error.InvalidParameterIndex;
    // More distinct ordinals than grammar sites necessarily leave a gap.
    if (index > max_parameters) {
        if (detail) |value| {
            var missing: u32 = 1;
            while (missing <= max_parameters) : (missing += 1) {
                var found = false;
                inline for (comptime std.meta.fieldNames(sql.ParameterSites)) |field| {
                    if (@field(sites, field)) |used| if (used.index == missing) {
                        found = true;
                    };
                }
                if (!found) break;
            }
            value.missing_parameter = missing;
        }
        return error.ParameterGap;
    }
    const offset = index - 1;
    if (present[offset] and types[offset] != kind) {
        if (detail) |value| {
            value.expected = @tagName(types[offset]);
            value.actual = @tagName(kind);
        }
        return error.ParameterTypeConflict;
    }
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
