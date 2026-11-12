//! Source-only types and values. No native identity or authorization is minted.
const std = @import("std");
const f = @import("transit_fuze");
const s = @import("Syntax.zig");
const Graph = @import("Graph.zig");
pub const Scalar = struct {
    base: s.ScalarType,
    domain: ?Graph.Ref = null,
    pub fn eql(left: Scalar, right: Scalar) bool {
        return left.base == right.base and std.meta.eql(left.domain, right.domain);
    }
    pub fn label(self: Scalar, graph: Graph) []const u8 {
        if (self.domain) |ref| return graph.getDefinition(ref).domain.?.identity;
        return switch (self.base) {
            .bigint => "BIGINT",
            .text => "TEXT",
            .boolean => "BOOLEAN",
        };
    }
    pub fn physical(self: Scalar) f.Types.Type {
        return switch (self.base) {
            .bigint => .int64,
            .text => .utf8,
            .boolean => .boolean,
        };
    }
    pub fn hash(self: Scalar, graph: Graph, into: *std.crypto.hash.sha2.Sha256) void {
        Graph.hashPart(into, @tagName(self.base));
        if (self.domain) |ref| {
            Graph.hashPart(into, "domain");
            Graph.hashPart(into, graph.getDefinition(ref).domain.?.identity);
        } else Graph.hashPart(into, "scalar");
    }
};
pub const Primitive = union(enum) { integer: i64, text: []const u8, boolean: bool };
pub const ResourceKind = enum { table, stream, queue };
pub const Table = struct {
    name: []const u8,
    schema: f.TableSchema.Schema,
    domains: []const ?Graph.Ref,
    owner: usize,
    kind: ResourceKind = .table,
    log: ?f.LogDdl.Configured = null,
    pub fn value(self: *const Table) Value {
        return switch (self.kind) {
            .table => .{ .table = self },
            .stream => .{ .stream = self },
            .queue => .{ .queue = self },
        };
    }
};
pub const Export = struct { name: []const u8, value: Value };
pub const Variant = struct { definition: Graph.Ref, constructor: usize, fields: []const Value };
pub const Value = union(enum) {
    integer: i64,
    text: []const u8,
    boolean: bool,
    identifier: []const u8,
    type: Scalar,
    module: Graph.Ref,
    nominal: struct { type: Scalar, value: Primitive },
    variant: Variant,
    table: *const Table,
    stream: *const Table,
    queue: *const Table,
    instance: []const Export,
    symbolic: Scalar,
    pub fn scalar(self: Value) ?Scalar {
        return switch (self) {
            .integer => .{ .base = .bigint },
            .text => .{ .base = .text },
            .boolean => .{ .base = .boolean },
            .nominal => |v| v.type,
            .symbolic => |v| v,
            else => null,
        };
    }
    pub fn primitive(self: Value) !Primitive {
        return switch (self) {
            .integer => |v| .{ .integer = v },
            .text => |v| .{ .text = v },
            .boolean => |v| .{ .boolean = v },
            .nominal => |v| v.value,
            else => error.SourceTypeMismatch,
        };
    }
};
pub const Binding = struct { name: []const u8, value: Value };

pub fn resolve(graph: Graph, file: usize, kind: s.TypeRef) !Scalar {
    return switch (kind) {
        .scalar => |base| .{ .base = base },
        .named => |name| try domain(graph, try graph.resolve(file, name)),
    };
}
pub fn domain(graph: Graph, ref: Graph.Ref) !Scalar {
    const definition = graph.getDefinition(ref);
    if (definition.kind != .domain) return error.NotSourceDomain;
    return .{ .base = definition.domain.?.base, .domain = ref };
}
pub fn field(graph: Graph, file: usize, kind: s.Kind) !Scalar {
    return switch (kind) {
        .integer => .{ .base = .bigint },
        .text => .{ .base = .text },
        .boolean => .{ .base = .boolean },
        .named => |name| try domain(graph, try graph.resolve(file, name)),
        else => error.UnsupportedVariantField,
    };
}
pub fn constructor(graph: Graph, file: usize, name: s.Name) !struct { definition: Graph.Ref, index: usize } {
    const type_name: s.Name = if (name.constructor != null) .{ .qualifier = name.qualifier, .member = name.member } else .{ .member = name.qualifier orelse return error.InvalidVariantConstructor };
    const ref = try graph.resolve(file, type_name);
    const definition = graph.getDefinition(ref);
    if (definition.kind != .variant) return error.InvalidVariantConstructor;
    const selected = name.constructor orelse name.member;
    for (definition.constructors, 0..) |item, i| if (std.mem.eql(u8, item.name, selected)) return .{ .definition = ref, .index = i };
    return error.UnknownVariantConstructor;
}
pub fn validate(graph: Graph, a: std.mem.Allocator, file_at: *usize, offset: *usize, work: *usize, limit: usize) !void {
    var identities: std.StringHashMap(void) = .init(a);
    defer identities.deinit();
    for (graph.files, 0..) |file, i| for (file.definitions) |definition| {
        if (work.* == limit) return error.BuildWorkLimit;
        work.* += 1;
        file_at.* = i;
        offset.* = definition.span.start;
        if (definition.domain) |value| {
            if (!std.unicode.utf8ValidateSlice(value.identity)) return error.InvalidDomainIdentity;
            if ((try identities.getOrPut(value.identity)).found_existing) return error.DuplicateDomainIdentity;
        }
        for (definition.constructors) |item| for (item.fields) |parameter| {
            if (work.* == limit) return error.BuildWorkLimit;
            work.* += 1;
            _ = try field(graph, i, parameter.kind);
        };
    };
}
pub fn signature(graph: Graph, file: usize, columns: []const s.Column, table: *const Table, context: *@import("SourceDiagnostic.zig").Context) !void {
    if (columns.len != table.schema.columns.len or table.schema.integrity.checks.len != 0 or table.schema.integrity.foreign_keys.len != 0) return error.TableInterfaceMismatch;
    var key: usize = 0;
    for (columns, table.schema.columns, table.domains) |expected, actual, actual_domain| {
        const ty = try resolve(graph, file, expected.type);
        context.column = expected.name;
        context.expected = ty.label(graph);
        context.actual = if (actual_domain) |ref| graph.getDefinition(ref).domain.?.identity else @tagName(actual.type);
        if (!std.mem.eql(u8, expected.name, actual.name) or !try ty.physical().eql(actual.type) or !std.meta.eql(ty.domain, actual_domain) or
            expected.nullable != actual.nullable or !std.mem.eql(u8, expected.collation, @tagName(actual.collation)) or actual.default != null or actual.max_characters != null or
            actual.semantics.rounding != null or actual.semantics.metric != null or actual.semantics.timezone != null) return error.TableInterfaceMismatch;
        if (expected.primary) {
            if (key == table.schema.primary_key.len or table.schema.primary_key[key] != actual.id) return error.TableInterfaceMismatch;
            key += 1;
        }
    }
    if (key != table.schema.primary_key.len) return error.TableInterfaceMismatch;
}
pub fn hashValue(value: Value, graph: Graph, into: *std.crypto.hash.sha2.Sha256, depth: usize) !void {
    if (depth >= 64) return error.SourceDepthLimit;
    Graph.hashPart(into, @tagName(value));
    switch (value) {
        .integer => |v| {
            var bytes: [8]u8 = undefined;
            std.mem.writeInt(i64, &bytes, v, .little);
            into.update(&bytes);
        },
        .boolean => |v| into.update(&.{@intFromBool(v)}),
        .text, .identifier => |v| Graph.hashPart(into, v),
        .type, .symbolic => |v| v.hash(graph, into),
        .nominal => |v| {
            v.type.hash(graph, into);
            switch (v.value) {
                inline else => |payload, tag| try hashValue(@unionInit(Value, @tagName(tag), payload), graph, into, depth + 1),
            }
        },
        .module => |ref| {
            Graph.hashPart(into, graph.sources[ref.file].package);
            Graph.hashPart(into, graph.sources[ref.file].path);
            Graph.hashPart(into, graph.getDefinition(ref).name);
        },
        .variant => |v| {
            try hashValue(.{ .module = v.definition }, graph, into, depth + 1);
            Graph.hashPart(into, graph.getDefinition(v.definition).constructors[v.constructor].name);
            for (v.fields) |item| try hashValue(item, graph, into, depth + 1);
        },
        .table, .stream, .queue => |table| {
            Graph.hashPart(into, table.name);
            into.update(&try table.schema.fingerprint());
            for (table.schema.columns, table.domains) |column, ref| {
                Graph.hashPart(into, column.name);
                if (ref) |d| (try domain(graph, d)).hash(graph, into) else Graph.hashPart(into, "raw");
            }
        },
        .instance => |exports| for (exports) |item| {
            Graph.hashPart(into, item.name);
            try hashValue(item.value, graph, into, depth + 1);
        },
    }
}

/// Recursive checking may discharge only an already checked symbolic instance.
/// Concrete names, Tables, types and higher-order constructors remain relevant.
pub fn sameSpecialization(left: []const Binding, right: []const Binding) bool {
    if (left.len != right.len) return false;
    for (left, right) |l, r| if (!sameValue(l.value, r.value, 0)) return false;
    return true;
}
fn sameValue(left: Value, right: Value, depth: usize) bool {
    if (depth >= 64) return false;
    if (left.scalar()) |kind| return if (right.scalar()) |other| Scalar.eql(kind, other) else false;
    if (std.meta.activeTag(left) != std.meta.activeTag(right)) return false;
    return switch (left) {
        .identifier => |v| std.mem.eql(u8, v, right.identifier),
        .type => |v| Scalar.eql(v, right.type),
        .module => |v| std.meta.eql(v, right.module),
        inline .table, .stream, .queue => |v, tag| v == @field(right, @tagName(tag)),
        .variant => |v| blk: {
            if (!std.meta.eql(v.definition, right.variant.definition) or v.constructor != right.variant.constructor or v.fields.len != right.variant.fields.len) break :blk false;
            for (v.fields, right.variant.fields) |l, r| if (!sameValue(l, r, depth + 1)) break :blk false;
            break :blk true;
        },
        else => false,
    };
}
