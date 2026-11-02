//! Immutable interpretation artifacts for views, property graphs and foreign
//! layouts. Publication, current authority and retention belong to DirectCatalog.
//! Loading an artifact performs no computation, connector call or name lookup.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const d = p.DataLifecycle;
const f = c.fuze;
const w = c.DirectTableProtocol;
const s = c.storage;
const r = @import("DirectCatalogRecords.zig");
pub const Kind = enum { view, property_graph, foreign };
pub const max_bytes = 384 * 1024;
pub const max_sources = 4;
pub const max_text_bytes = 16 * 1024;
pub const max_input_bytes = w.max_work_bytes;
const header_bytes = 40;

pub const Column = struct { source: u8, column: u64 };
pub const Property = struct { id: u64, name: c.TableAuthority.Name, value: Column };
pub const Vertex = struct {
    pub const json_schema_sequence_bounds = .{ .properties = f.TableSchema.max_columns };
    id: u64,
    label: c.TableAuthority.Name,
    key: Column,
    properties: []const Property,
};
pub const Edge = struct {
    pub const json_schema_sequence_bounds = .{ .properties = f.TableSchema.max_columns };
    id: u64,
    label: c.TableAuthority.Name,
    key: Column,
    source_vertex: u64,
    source_key: Column,
    target_vertex: u64,
    target_key: Column,
    properties: []const Property,
};
pub const Graph = struct {
    pub const json_schema_sequence_bounds = .{ .vertices = 16, .edges = 16 };
    next_mapping: u64,
    vertices: []const Vertex,
    edges: []const Edge,
};
pub const View = struct {
    /// Canonical FQP1 over the exact source schema, bound to its definition
    /// digest. SQL text is provenance only and is never reparsed on execution.
    plan: w.Binary,
    source_text: []const u8,
};
pub const Malformed = enum { reject, type_error };
pub const Field = struct { column: u64, offset: u32, bytes: u32, encoding: f.TableSchema.Encoding };
pub const Input = struct {
    content: d.Content,
    availability: enum { retained, unavailable },
    /// Descriptive provenance; this string is never a fetch instruction.
    provenance: []const u8,
    pub fn validate(self: Input) !void {
        try self.content.validate();
        if (self.content.bytes == 0 or self.content.bytes > max_input_bytes or self.provenance.len > 2048 or !std.unicode.utf8ValidateSlice(self.provenance)) return error.InvalidCatalogDescriptor;
    }
};
pub const Foreign = struct {
    pub const json_schema_sequence_bounds = .{ .fields = f.TableSchema.max_columns };
    record_bytes: u32,
    fields: []const Field,
    malformed: Malformed,
    input: Input,
};
pub const Source = struct {
    properties: r.Properties,
    declaration: s.TableDeclaration.Stored,
    /// Exact FTS1 copied at validation, so interpretation does not depend on a
    /// later name, schema cache or mutable foreign URI.
    schema: w.Binary,
};
pub const Definition = struct {
    pub const json_schema_sequence_bounds = .{ .sources = max_sources };
    definition: p.Growth.Definition,
    object: d.Object,
    revision: u64,
    properties: r.Properties,
    retired: bool,
    schema: w.Binary,
    sources: []const Source,
    body: union(Kind) { view: View, property_graph: Graph, foreign: Foreign },

    pub fn validate(self: Definition, allocator: std.mem.Allocator) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.object.validate();
        try self.properties.validate();
        if (self.object.branch != 1 or self.revision == 0 or self.sources.len > max_sources) return error.InvalidCatalogDescriptor;
        var schema = try decodeSchema(allocator, self.schema);
        defer schema.deinit();
        if (schema.schema.object != self.object.object or schema.schema.revision != self.revision) return error.InvalidCatalogDescriptor;
        for (self.sources, 0..) |source, i| {
            try source.properties.validate();
            try source.declaration.validate();
            const identity = source.declaration.interpretation.object;
            if (source.declaration.kind != .table or source.declaration.retired or !std.meta.eql(identity.scope, self.object.scope) or identity.branch != self.object.branch or identity.object == self.object.object) return error.InvalidCatalogDependency;
            for (self.sources[0..i]) |prior| if (std.meta.eql(prior.declaration.interpretation.object, identity)) return error.InvalidCatalogDependency;
            var source_schema = try decodeSchema(allocator, source.schema);
            defer source_schema.deinit();
            if (source_schema.schema.object != identity.object or !std.mem.eql(u8, &try source_schema.schema.fingerprint(), &source.declaration.schema_fingerprint)) return error.InvalidCatalogDescriptor;
        }
        switch (self.body) {
            .view => |view| try self.validateView(allocator, schema.schema, view),
            .property_graph => |graph| try self.validateGraph(allocator, graph),
            .foreign => |foreign| try validateForeign(schema.schema, foreign),
        }
    }
    fn validateView(self: Definition, allocator: std.mem.Allocator, output: f.TableSchema.Schema, view: View) !void {
        if (self.sources.len != 1 or view.source_text.len == 0 or view.source_text.len > max_text_bytes or !std.unicode.utf8ValidateSlice(view.source_text)) return error.InvalidCatalogDescriptor;
        var source = try decodeSchema(allocator, self.sources[0].schema);
        defer source.deinit();
        var fields: [f.TableSchema.max_columns]f.Types.Field = undefined;
        const row_type = try source.schema.rowType(&fields);
        const bytes = try view.plan.decode(allocator, f.LogicalPlanCodec.max_bytes);
        defer allocator.free(bytes);
        var accepted = try f.LogicalPlanCodec.decode(allocator, row_type, self.sources[0].declaration.interpretation.digest, bytes);
        defer accepted.deinit();
        const plan = accepted.plan;
        // First executable view profile: one exact Table, projection and a
        // finite predicate. Other operators reject before publication.
        if (plan.aggregate != .rows or plan.limit != null or plan.scalars.instructions.len != 0) return error.UnsupportedCatalogView;
        if (!std.meta.eql(plan.collations, f.QueryCollations.fromTable(source.schema)) or plan.projection.len != output.columns.len) return error.InvalidCatalogDescriptor;
        var output_fields: [f.TableSchema.max_columns]f.Types.Field = undefined;
        const selected_output = try plan.outputSchema(&output_fields);
        for (output.columns, plan.projection, 0..) |column, ordinal, i| {
            const input = source.schema.columns[ordinal];
            const field = selected_output.structure[i];
            if (!std.mem.eql(u8, field.name, column.name) or !try field.type.eql(column.type) or field.nullable != column.nullable or column.default != null or column.encoding != .plain or column.collation != input.collation or !column.semantics.eql(input.semantics)) return error.InvalidCatalogDescriptor;
        }
        var canonical: [f.LogicalPlanCodec.max_bytes]u8 = undefined;
        if (!std.mem.eql(u8, bytes, try f.LogicalPlanCodec.encode(plan, &canonical))) return error.InvalidCatalogDescriptor;
    }
    fn sourceColumn(schemas: []const f.TableSchema.Schema, selected: Column) !f.TableSchema.Column {
        if (selected.source >= schemas.len) return error.InvalidCatalogDependency;
        for (schemas[selected.source].columns) |column| if (column.id == selected.column) return column;
        return error.InvalidCatalogDependency;
    }
    fn validateProperties(schemas: []const f.TableSchema.Schema, properties: f.TableSchema.Schema, values: []const Property, source: u8) !void {
        if (values.len > f.TableSchema.max_columns) return error.InvalidCatalogDescriptor;
        for (values, 0..) |value, i| {
            try value.name.validate();
            if (value.id == 0 or value.value.source != source) return error.InvalidCatalogDescriptor;
            const input = try sourceColumn(schemas, value.value);
            const property = for (properties.columns) |column| {
                if (column.id == value.id) break column;
            } else return error.InvalidCatalogDescriptor;
            if (!std.mem.eql(u8, property.name, value.name.slice()) or !try property.type.eql(input.type) or property.nullable != input.nullable or property.collation != input.collation or !property.semantics.eql(input.semantics) or property.encoding != .plain or property.default != null) return error.InvalidCatalogDescriptor;
            for (values[0..i]) |prior| if (prior.id == value.id or std.meta.eql(prior.name, value.name)) return error.InvalidCatalogDescriptor;
        }
    }
    fn validateGraph(self: Definition, allocator: std.mem.Allocator, graph: Graph) !void {
        if (self.sources.len == 0 or graph.vertices.len == 0 or graph.vertices.len > 16 or graph.edges.len > 16 or graph.next_mapping == 0) return error.InvalidCatalogDescriptor;
        var scratch: std.heap.ArenaAllocator = .init(allocator);
        defer scratch.deinit();
        var schemas: [max_sources]f.TableSchema.Schema = undefined;
        for (self.sources, 0..) |source, i| {
            const decoded = try decodeSchema(scratch.allocator(), source.schema);
            schemas[i] = decoded.schema;
        }
        const selected_schemas = schemas[0..self.sources.len];
        const properties = try decodeSchema(scratch.allocator(), self.schema);
        for (graph.vertices, 0..) |vertex, i| {
            try vertex.label.validate();
            if (vertex.id == 0 or vertex.id >= graph.next_mapping) return error.InvalidCatalogDescriptor;
            const key_column = try sourceColumn(selected_schemas, vertex.key);
            if (key_column.nullable or !f.TableSchema.keyType(key_column.type)) return error.InvalidCatalogDescriptor;
            for (graph.vertices[0..i]) |prior| if (prior.id == vertex.id or std.meta.eql(prior.label, vertex.label)) return error.InvalidCatalogDescriptor;
            try validateProperties(selected_schemas, properties.schema, vertex.properties, vertex.key.source);
        }
        for (graph.edges, 0..) |edge, i| {
            try edge.label.validate();
            if (edge.id == 0 or edge.id >= graph.next_mapping or edge.source_key.source != edge.key.source or edge.target_key.source != edge.key.source) return error.InvalidCatalogDescriptor;
            for (graph.vertices) |vertex| if (vertex.id == edge.id) return error.InvalidCatalogDescriptor;
            for (graph.edges[0..i]) |prior| if (prior.id == edge.id or std.meta.eql(prior.label, edge.label)) return error.InvalidCatalogDescriptor;
            const key_column = try sourceColumn(selected_schemas, edge.key);
            if (key_column.nullable or !f.TableSchema.keyType(key_column.type)) return error.InvalidCatalogDescriptor;
            inline for (.{ .{ edge.source_vertex, edge.source_key }, .{ edge.target_vertex, edge.target_key } }) |endpoint| {
                const vertex = for (graph.vertices) |value| {
                    if (value.id == endpoint[0]) break value;
                } else return error.InvalidCatalogDescriptor;
                const target = try sourceColumn(selected_schemas, vertex.key);
                const actual = try sourceColumn(selected_schemas, endpoint[1]);
                if (actual.nullable or !try target.type.eql(actual.type) or target.collation != actual.collation or !target.semantics.eql(actual.semantics)) return error.InvalidCatalogDescriptor;
            }
            try validateProperties(selected_schemas, properties.schema, edge.properties, edge.key.source);
        }
    }
    pub fn stored(self: Definition, allocator: std.mem.Allocator) !Stored {
        const bytes = try encode(allocator, self);
        defer allocator.free(bytes);
        var schema = try decodeSchema(allocator, self.schema);
        defer schema.deinit();
        const content: d.Content = .{ .bytes = bytes.len, .sha256 = r.hash(bytes) };
        return .{ .kind = std.meta.activeTag(self.body), .interpretation = .{ .object = self.object, .revision = self.revision, .digest = content.sha256 }, .content = content, .properties = self.properties, .schema = try schema.schema.fingerprint(), .next_column = schema.schema.next_column, .retired = self.retired };
    }
};

pub const Stored = struct {
    kind: Kind,
    interpretation: d.Definition,
    content: d.Content,
    properties: r.Properties,
    schema: [32]u8,
    next_column: u64,
    retired: bool,
    pub fn validate(self: Stored) !void {
        try self.interpretation.validate();
        try self.content.validate();
        try self.properties.validate();
        if (self.content.bytes <= header_bytes or self.content.bytes > max_bytes or self.next_column == 0 or !std.mem.eql(u8, &self.interpretation.digest, &self.content.sha256)) return error.InvalidCatalogDescriptor;
    }
};
pub const Owned = std.json.Parsed(Definition);
pub fn decodeSchema(allocator: std.mem.Allocator, encoded: w.Binary) !f.TableSchema.Owned {
    const bytes = try encoded.decode(allocator, f.TableSchema.max_bytes);
    defer allocator.free(bytes);
    return f.TableSchema.decode(allocator, bytes);
}
fn validateForeign(schema: f.TableSchema.Schema, foreign: Foreign) !void {
    try foreign.input.validate();
    if (foreign.record_bytes == 0 or foreign.record_bytes > max_input_bytes or foreign.input.content.bytes % foreign.record_bytes != 0 or foreign.fields.len != schema.columns.len) return error.InvalidCatalogDescriptor;
    for (foreign.fields, schema.columns, 0..) |field, column, i| {
        if (field.column != column.id or field.bytes == 0 or @as(u64, field.offset) + field.bytes > foreign.record_bytes) return error.InvalidCatalogDescriptor;
        var physical = column;
        physical.encoding = field.encoding;
        try physical.validateEncodingAndCollation();
        switch (field.encoding) {
            .comp => if (field.bytes != 2 and field.bytes != 4 and field.bytes != 8) return error.InvalidCatalogDescriptor,
            .comp_3 => if (field.bytes > 16) return error.InvalidCatalogDescriptor,
            .zoned => if (field.bytes > 31) return error.InvalidCatalogDescriptor,
            .ibm_hfp => if (field.bytes != 4 and field.bytes != 8) return error.InvalidCatalogDescriptor,
            .ebcdic => {},
            .plain => if (column.type != .binary and column.type != .utf8) return error.InvalidCatalogDescriptor,
            else => return error.UnsupportedForeignLayout,
        }
        for (foreign.fields[0..i]) |prior| if (@as(u64, prior.offset) < @as(u64, field.offset) + field.bytes and @as(u64, field.offset) < @as(u64, prior.offset) + prior.bytes) return error.InvalidCatalogDescriptor;
    }
}
pub fn key(content: d.Content, output: *[96]u8) ![]const u8 {
    try content.validate();
    return std.fmt.bufPrint(output, "catalog-definitions/{x}.data", .{&content.sha256});
}
pub fn inputKey(content: d.Content, output: *[96]u8) ![]const u8 {
    try content.validate();
    return std.fmt.bufPrint(output, "catalog-foreign/{x}.data", .{&content.sha256});
}
pub fn stageInput(objects: s.TransitObjectStore.ObjectStore, bytes: []const u8) !d.Content {
    if (bytes.len == 0 or bytes.len > max_input_bytes) return error.InvalidCatalogDescriptor;
    const content: d.Content = .{ .bytes = bytes.len, .sha256 = r.hash(bytes) };
    var name: [96]u8 = undefined;
    const accepted = try objects.putImmutable(try inputKey(content, &name), bytes, content.sha256);
    if (accepted.size != content.bytes or !std.mem.eql(u8, &accepted.sha256, &content.sha256)) return error.InvalidCatalogDescriptor;
    return content;
}
/// Missing retained bytes and checksum failure remain durable failures. Neither
/// may become a declared foreign type_error cell.
pub fn loadInput(allocator: std.mem.Allocator, objects: s.TransitObjectStore.ObjectStore, input: Input) ![]u8 {
    try input.validate();
    if (input.availability == .unavailable) return error.HistoricalArtifactUnavailable;
    var name: [96]u8 = undefined;
    const path = try inputKey(input.content, &name);
    const meta = try objects.head(path) orelse return error.HistoricalArtifactUnavailable;
    if (meta.size != input.content.bytes or !std.mem.eql(u8, &meta.sha256, &input.content.sha256)) return error.InvalidCatalogDescriptor;
    const bytes = try allocator.alloc(u8, @intCast(meta.size));
    errdefer allocator.free(bytes);
    if ((try objects.getRange(path, 0, @intCast(bytes.len), bytes)).len != bytes.len or !std.mem.eql(u8, &r.hash(bytes), &input.content.sha256)) return error.InvalidCatalogDescriptor;
    return bytes;
}
pub fn encode(allocator: std.mem.Allocator, value: Definition) ![]u8 {
    try value.validate(allocator);
    const buffer = try allocator.alloc(u8, max_bytes);
    defer allocator.free(buffer);
    var writer: std.Io.Writer = .fixed(buffer);
    try writer.writeAll("TCDESC01");
    try writer.writeAll(&p.Growth.definition_bytes);
    var json: std.json.Stringify = .{ .writer = &writer };
    p.Json.write(value, &json) catch return error.CatalogRecordTooLarge;
    return allocator.dupe(u8, writer.buffered());
}
pub fn stage(allocator: std.mem.Allocator, objects: s.TransitObjectStore.ObjectStore, value: Definition) !Stored {
    const bytes = try encode(allocator, value);
    defer allocator.free(bytes);
    const stored = try value.stored(allocator);
    var name: [96]u8 = undefined;
    const accepted = try objects.putImmutable(try key(stored.content, &name), bytes, stored.content.sha256);
    if (accepted.size != stored.content.bytes or !std.mem.eql(u8, &accepted.sha256, &stored.content.sha256)) return error.InvalidCatalogDescriptor;
    return stored;
}
pub fn load(allocator: std.mem.Allocator, objects: s.TransitObjectStore.ObjectStore, stored: Stored) !Owned {
    try stored.validate();
    var name: [96]u8 = undefined;
    const path = try key(stored.content, &name);
    const meta = try objects.head(path) orelse return error.HistoricalArtifactUnavailable;
    if (meta.size != stored.content.bytes or !std.mem.eql(u8, &meta.sha256, &stored.content.sha256)) return error.InvalidCatalogDescriptor;
    const bytes = try allocator.alloc(u8, @intCast(meta.size));
    defer allocator.free(bytes);
    if ((try objects.getRange(path, 0, @intCast(bytes.len), bytes)).len != bytes.len or !std.mem.eql(u8, &r.hash(bytes), &stored.content.sha256) or !std.mem.eql(u8, bytes[0..8], "TCDESC01")) return error.InvalidCatalogDescriptor;
    if (!std.mem.eql(u8, bytes[8..40], &p.Growth.definition_bytes)) return error.IncompatibleDefinition;
    var parsed = try std.json.parseFromSlice(Definition, allocator, bytes[header_bytes..], .{ .allocate = .alloc_always });
    errdefer parsed.deinit();
    if (!std.meta.eql(try parsed.value.stored(allocator), stored)) return error.InvalidCatalogDescriptor;
    return parsed;
}

/// Decode one field from already verified captured bytes. The caller owns the
/// reusable UTF-8 output buffer. This is a codec operation, not a foreign scan.
pub fn decodeField(column: f.TableSchema.Column, layout: Field, malformed: Malformed, record: []const u8, utf8: []u8) !f.Types.Values.Cell {
    if (layout.column != column.id or @as(u64, layout.offset) + layout.bytes > record.len) return error.InvalidCatalogDescriptor;
    const bytes = record[layout.offset..][0..layout.bytes];
    const cell: f.Types.Values.Cell = switch (layout.encoding) {
        .comp => f.PhysicalCodecs.decodeComp4(bytes, column.type),
        .comp_3 => f.PhysicalCodecs.decodeComp3(bytes, column.type),
        .zoned => f.PhysicalCodecs.decodeZoned(bytes, column.type),
        .ibm_hfp => f.PhysicalCodecs.decodeIbmHfp(bytes, column.type),
        .ebcdic => .{ .value = .{ .atom = .{ .bytes = try f.PhysicalCodecs.decodeEbcdic037(bytes, utf8) } } },
        .plain => if (column.type == .binary or (column.type == .utf8 and std.unicode.utf8ValidateSlice(bytes))) .{ .value = .{ .atom = .{ .bytes = bytes } } } else .{ .type_error = f.Types.Kind.fromTag(column.type.tag()) },
        else => return error.UnsupportedForeignLayout,
    };
    if (cell == .type_error and malformed == .reject) return error.ForeignValueMalformed;
    return cell;
}
test {
    _ = @import("catalog_definition_test.zig");
}
