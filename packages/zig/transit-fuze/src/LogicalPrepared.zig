//! Owned logical SELECT templates. Parameters bind to typed operands, never SQL
//! text. The source owner supplies and authorizes the immutable binding separately.
const std = @import("std");
const t = @import("Types.zig");
const sql = @import("Sql.zig");
const Parser = @import("SqlTyped.zig");
const Select = @import("TableSelect.zig");
const codec = @import("LogicalPlanCodec.zig");
const Self = @This();
pub const max_parameters = @import("LogicalPredicate.zig").Program.max_instructions + 1;
pub const Bound = codec.Owned;
arena: std.heap.ArenaAllocator,
descriptor: t.Decoded,
syntax: Select.Syntax,
name: []const u8,
basis: [32]u8,
types: [max_parameters]t.Type = undefined,
sites: [max_parameters]?sql.Parameter = @splat(null),
count: u8 = 0,

pub fn init(allocator: std.mem.Allocator, text: []const u8, name: []const u8, schema: t.Type, basis: [32]u8, diagnostic: ?*sql.Binding) !Self {
    return initInner(allocator, text, name, schema, basis, diagnostic) catch |err| {
        if (diagnostic) |detail| if (detail.location) |position| sql.Binding.nameFailure(detail, text, name, err, position);
        return err;
    };
}
fn initInner(allocator: std.mem.Allocator, text: []const u8, name: []const u8, schema: t.Type, basis: [32]u8, diagnostic: ?*sql.Binding) !Self {
    if (diagnostic) |detail| detail.* = .{};
    try sql.validateText(text);
    if (schema != .structure or schema.structure.len == 0 or schema.structure.len > 128) return error.InvalidQuerySchema;
    var descriptor = try schema.clone(allocator);
    errdefer descriptor.deinit();
    var arena: std.heap.ArenaAllocator = .init(allocator);
    errdefer arena.deinit();
    const alloc = arena.allocator();
    // Numeric literal tokens borrow lexer text; retain all text before parsing.
    const owned_text = try alloc.dupe(u8, text);
    var location: sql.Location = .{};
    errdefer if (diagnostic) |detail| {
        if (detail.location == null) detail.location = location;
    };
    var parser = try Parser.initTemplate(alloc, owned_text, &location);
    const syntax = try Select.syntax(&parser, descriptor.type);
    try parser.finish();
    var result: Self = .{ .arena = arena, .descriptor = descriptor, .syntax = syntax, .name = try alloc.dupe(u8, name), .basis = basis };
    if (syntax.predicate) |predicate| for (predicate.instructions) |instruction| {
        if (instruction != .atom or instruction.atom != .compare) continue;
        const compare = instruction.atom.compare;
        if (compare.value != .parameter) continue;
        const column = try compare.column.resolve(syntax.qualifier, descriptor.type.structure, &location);
        try result.register(compare.value.parameter, descriptor.type.structure[column].type, diagnostic);
    };
    if (syntax.limit_parameter) |site| try result.register(site, .uint64, diagnostic);
    for (result.sites[0..result.count], 0..) |site, i| if (site == null) {
        if (diagnostic) |detail| detail.missing_parameter = @intCast(i + 1);
        return error.ParameterGap;
    };
    var witnesses: [max_parameters]t.Values.Atom = undefined;
    if (diagnostic) |detail| detail.* = .{};
    for (result.parameterTypes(), witnesses[0..result.count], 0..) |kind, *value, i| value.* = witness(kind) catch |err| {
        result.at(@intCast(i + 1), diagnostic);
        if (diagnostic) |detail| detail.expected = @tagName(kind);
        return err;
    };
    _ = try syntax.bindParameters(alloc, name, descriptor.type, basis, &location, witnesses[0..result.count]);
    // Allocating the validation plan may grow arena after its earlier copy.
    // Transfer only its final state; Syntax retains no diagnostic pointer.
    result.arena = arena;
    return result;
}
pub fn deinit(self: *Self) void {
    self.arena.deinit();
    self.descriptor.deinit();
    self.* = undefined;
}
pub fn parameterTypes(self: *const Self) []const t.Type {
    return self.types[0..self.count];
}
fn at(self: *const Self, index: u32, diagnostic: ?*sql.Binding) void {
    const detail = diagnostic orelse return;
    detail.parameter = index;
    detail.parameter_sites = @splat(null);
    var count: usize = 0;
    if (self.syntax.predicate) |predicate| for (predicate.instructions) |instruction| {
        if (instruction != .atom or instruction.atom != .compare or instruction.atom.compare.value != .parameter) continue;
        const site = instruction.atom.compare.value.parameter;
        if (site.index == index and count < detail.parameter_sites.len) {
            detail.parameter_sites[count] = site.offset;
            count += 1;
        }
    };
    if (self.syntax.limit_parameter) |site| if (site.index == index and count < detail.parameter_sites.len) {
        detail.parameter_sites[count] = site.offset;
        count += 1;
    };
    if (count != 0) detail.location = .{ .offset = detail.parameter_sites[0].? };
}
fn register(self: *Self, site: sql.Parameter, kind: t.Type, diagnostic: ?*sql.Binding) !void {
    self.at(site.index, diagnostic);
    if (diagnostic) |detail| detail.location = .{ .offset = site.offset };
    if (site.index == 0) return error.InvalidParameterIndex;
    if (site.index > max_parameters) {
        if (diagnostic) |detail| {
            for (self.sites, 0..) |used, i| if (used == null) {
                detail.missing_parameter = @intCast(i + 1);
                break;
            };
        }
        return error.ParameterGap;
    }
    const index = site.index - 1;
    if (self.sites[index] != null and !try self.types[index].eql(kind)) {
        if (diagnostic) |detail| {
            detail.expected = @tagName(self.types[index]);
            detail.actual = @tagName(kind);
        }
        return error.ParameterTypeConflict;
    }
    self.sites[index] = self.sites[index] orelse site;
    self.types[index] = kind;
    self.count = @max(self.count, @as(u8, @intCast(site.index)));
}
/// Supplied schema/name/basis must match the template's exact immutable source.
/// Current rights and a new admission are still the source owner's responsibility.
/// All successful descriptors, names and values belong to the returned owner.
pub fn bind(self: *const Self, allocator: std.mem.Allocator, name: []const u8, schema: t.Type, basis: [32]u8, values: []const t.Values.Atom, diagnostic: ?*sql.Binding) !Bound {
    if (diagnostic) |detail| detail.* = .{};
    const expected = try self.descriptor.type.fingerprint();
    const observed = try schema.fingerprint();
    if (!std.mem.eql(u8, name, self.name) or !std.mem.eql(u8, &basis, &self.basis) or !std.mem.eql(u8, &expected, &observed)) {
        if (diagnostic) |detail| {
            detail.expected_schema = expected;
            detail.actual_schema = observed;
        }
        return error.SourceChanged;
    }
    if (values.len != self.count) {
        if (diagnostic) |detail| {
            detail.expected_count = self.count;
            detail.actual_count = values.len;
        }
        return error.ParameterCountMismatch;
    }
    for (values, self.parameterTypes(), 0..) |value, kind, i| {
        validate(value, kind) catch |err| {
            self.at(@intCast(i + 1), diagnostic);
            if (diagnostic) |detail| {
                detail.expected = @tagName(kind);
                detail.actual = @tagName(value);
            }
            return err;
        };
    }
    var arena: std.heap.ArenaAllocator = .init(allocator);
    defer arena.deinit();
    var location: sql.Location = .{};
    errdefer if (diagnostic) |detail| {
        if (detail.location == null) detail.location = location;
    };
    const plan = try self.syntax.bindParameters(arena.allocator(), name, schema, basis, &location, values);
    var bytes: [codec.max_bytes]u8 = undefined;
    return codec.decode(allocator, schema, basis, try codec.encode(plan, &bytes));
}
pub fn validate(value: t.Values.Atom, kind: t.Type) !void {
    try @import("SqlLogicalPredicate.zig").validateParameter(value, kind);
}

fn witness(kind: t.Type) !t.Values.Atom {
    return switch (kind) {
        .int8, .int16, .int32, .int64, .int128 => .{ .signed = 0 },
        .uint8, .uint16, .uint32, .uint64, .uint128 => .{ .unsigned = 0 },
        .float32, .float64 => .{ .float = 0 },
        .decimal => .{ .decimal = 0 },
        .boolean => .{ .boolean = false },
        .utf8, .binary => .{ .bytes = "" },
        .date => .{ .date = 0 },
        .time => .{ .time = 0 },
        .timestamp => .{ .timestamp = 0 },
        .uuid => .{ .uuid = @splat(0) },
        else => error.UnsupportedComparison,
    };
}
