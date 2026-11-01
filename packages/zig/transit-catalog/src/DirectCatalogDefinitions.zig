//! Owned read-only interpretation metadata over the shared direct Catalog.
//! Full-width object, revision and column identities use decimal strings.
const std = @import("std");
const c = @import("root.zig");
const h = c.DirectTableValues;
const v = c.TableValues;
const A = std.mem.Allocator;
const D = c.CatalogDefinition;
pub const Properties = struct {
    namespace: u64,
    authorization: u64,
    name: []const u8,
    fn foreign(a: A, value: c.DirectCatalog.Properties) !Properties {
        return .{ .namespace = value.namespace, .authorization = value.authorization, .name = try a.dupe(u8, value.name.slice()) };
    }
};
pub const Stored = struct {
    kind: D.Kind,
    interpretation: h.Interpretation,
    content: h.Content,
    properties: Properties,
    schema_fingerprint: []const u8,
    next_column: []const u8,
    retired: bool,
    fn foreign(a: A, value: D.Stored) !Stored {
        return .{ .kind = value.kind, .interpretation = try h.Interpretation.foreign(a, value.interpretation), .content = try h.Content.foreign(a, value.content), .properties = try Properties.foreign(a, value.properties), .schema_fingerprint = try v.hex(a, &value.schema), .next_column = try v.decimal(a, value.next_column), .retired = value.retired };
    }
};
pub const Column = struct {
    source: u8,
    column: []const u8,
    fn foreign(a: A, value: D.Column) !Column {
        return .{ .source = value.source, .column = try v.decimal(a, value.column) };
    }
};
pub const Property = struct { id: []const u8, name: []const u8, value: Column };
pub const Vertex = struct {
    pub const json_schema_sequence_bounds = .{ .properties = c.fuze.TableSchema.max_columns };
    id: []const u8,
    label: []const u8,
    key: Column,
    properties: []const Property,
};
pub const Edge = struct {
    pub const json_schema_sequence_bounds = .{ .properties = c.fuze.TableSchema.max_columns };
    id: []const u8,
    label: []const u8,
    key: Column,
    source_vertex: []const u8,
    source_key: Column,
    target_vertex: []const u8,
    target_key: Column,
    properties: []const Property,
};
pub const Field = struct { column: []const u8, offset: u32, bytes: u32, encoding: c.fuze.TableSchema.Encoding };
pub const Source = struct { declaration: h.Stored, properties: Properties, schema: v.Schema };
pub const Body = union(enum) {
    view: D.View,
    property_graph: struct {
        pub const json_schema_sequence_bounds = .{ .vertices = 16, .edges = 16 };
        next_mapping: []const u8,
        vertices: []const Vertex,
        edges: []const Edge,
    },
    foreign: struct {
        pub const json_schema_sequence_bounds = .{ .fields = c.fuze.TableSchema.max_columns };
        record_bytes: u32,
        fields: []const Field,
        malformed: D.Malformed,
        input: struct { content: h.Content, availability: @FieldType(D.Input, "availability"), provenance: []const u8 },
    },
};
pub const Definition = struct {
    pub const json_schema_sequence_bounds = .{ .sources = D.max_sources };
    stored: Stored,
    schema: v.Schema,
    sources: []const Source,
    body: Body,
};
pub const Cursor = struct { definition: c.protocol.Growth.Definition, connection: h.Connection, namespace: u64, selector: ?[]const u8, after: []const u8 };
pub const Action = union(enum) {
    lookup: struct { namespace: u64, name: []const u8 },
    inspect: h.Interpretation,
    historical: struct { selector: []const u8, namespace: u64, name: []const u8 },
    list: struct { namespace: u64, selector: ?[]const u8, cursor: ?Cursor },
};
pub const Result = union(enum) {
    definition: ?Definition,
    historical: struct { snapshot: c.DirectCatalogHistory.Snapshot, catalog: ?h.Position, definition: ?Definition },
    page: struct { entries: [4]?Stored, next: ?Cursor, snapshot: ?c.DirectCatalogHistory.Snapshot, position: ?h.Position },
};
fn properties(a: A, values: []const D.Property) ![]const Property {
    const result = try a.alloc(Property, values.len);
    for (values, result) |value, *out| out.* = .{ .id = try v.decimal(a, value.id), .name = try a.dupe(u8, value.name.slice()), .value = try Column.foreign(a, value.value) };
    return result;
}
pub fn foreign(a: A, value: D.Definition) !Definition {
    const stored = try value.stored(a);
    var schema = try D.decodeSchema(a, value.schema);
    defer schema.deinit();
    const sources = try a.alloc(Source, value.sources.len);
    for (value.sources, sources) |source, *out| {
        var input = try D.decodeSchema(a, source.schema);
        defer input.deinit();
        out.* = .{ .declaration = try h.Stored.foreign(a, source.declaration), .properties = try Properties.foreign(a, source.properties), .schema = try c.fuze.TableSchemaJson.foreignInto(a, input.schema) };
    }
    const body: Body = switch (value.body) {
        .view => |view| .{ .view = .{ .plan = .{ .base64 = try a.dupe(u8, view.plan.base64) }, .source_text = try a.dupe(u8, view.source_text) } },
        .property_graph => |graph| blk: {
            const vertices = try a.alloc(Vertex, graph.vertices.len);
            for (graph.vertices, vertices) |vertex, *out| out.* = .{ .id = try v.decimal(a, vertex.id), .label = try a.dupe(u8, vertex.label.slice()), .key = try Column.foreign(a, vertex.key), .properties = try properties(a, vertex.properties) };
            const edges = try a.alloc(Edge, graph.edges.len);
            for (graph.edges, edges) |edge, *out| out.* = .{ .id = try v.decimal(a, edge.id), .label = try a.dupe(u8, edge.label.slice()), .key = try Column.foreign(a, edge.key), .source_vertex = try v.decimal(a, edge.source_vertex), .source_key = try Column.foreign(a, edge.source_key), .target_vertex = try v.decimal(a, edge.target_vertex), .target_key = try Column.foreign(a, edge.target_key), .properties = try properties(a, edge.properties) };
            break :blk .{ .property_graph = .{ .next_mapping = try v.decimal(a, graph.next_mapping), .vertices = vertices, .edges = edges } };
        },
        .foreign => |layout| blk: {
            const fields = try a.alloc(Field, layout.fields.len);
            for (layout.fields, fields) |field, *out| out.* = .{ .column = try v.decimal(a, field.column), .offset = field.offset, .bytes = field.bytes, .encoding = field.encoding };
            break :blk .{ .foreign = .{ .record_bytes = layout.record_bytes, .fields = fields, .malformed = layout.malformed, .input = .{ .content = try h.Content.foreign(a, layout.input.content), .availability = layout.input.availability, .provenance = try a.dupe(u8, layout.input.provenance) } } };
        },
    };
    return .{ .stored = try Stored.foreign(a, stored), .schema = try c.fuze.TableSchemaJson.foreignInto(a, schema.schema), .sources = sources, .body = body };
}
pub fn apply(a: A, client: c.DirectTableClient, action: Action) !Result {
    var snapshot: ?c.protocol.DataLifecycle.Snapshot = null;
    const request: c.DirectDefinition.Action = switch (action) {
        .lookup => |value| .{ .lookup = .{ .namespace = value.namespace, .name = try .init(value.name) } },
        .inspect => |value| .{ .inspect = try value.native() },
        .historical => |value| blk: {
            snapshot = try c.DirectHistory.Selector.decode(value.selector);
            break :blk .{ .historical = .{ .snapshot = snapshot.?, .namespace = value.namespace, .name = try .init(value.name), .rows = false } };
        },
        .list => |value| blk: {
            if (value.selector) |selector| snapshot = try c.DirectHistory.Selector.decode(selector);
            const after: ?u64 = if (value.cursor) |cursor| after: {
                if (cursor.definition != c.protocol.Growth.current_definition) return error.IncompatibleDefinition;
                if (!std.meta.eql(try cursor.connection.native(), client.connection) or cursor.namespace != value.namespace or (cursor.selector == null) != (value.selector == null)) return error.InvalidCatalogCursor;
                if (cursor.selector) |selector| if (!std.mem.eql(u8, selector, value.selector.?)) return error.InvalidCatalogCursor;
                break :after try v.unsigned(cursor.after);
            } else null;
            break :blk if (snapshot) |cut| .{ .historical_list = .{ .snapshot = cut, .namespace = value.namespace, .after = after } } else .{ .list = .{ .namespace = value.namespace, .after = after } };
        },
    };
    const response = try c.DirectDefinition.call(client, request);
    defer response.deinit();
    const result = response.value.result.descriptor;
    return switch (action) {
        .lookup, .inspect => .{ .definition = if (result.definition) |value| try foreign(a, value) else null },
        .historical => .{ .historical = .{ .snapshot = try c.DirectCatalogHistory.Snapshot.foreign(a, snapshot.?), .catalog = if (result.historical) |value| try h.Position.foreign(a, value.binding.catalog) else null, .definition = if (result.historical) |value| try foreign(a, value.value) else null } },
        .list => |value| blk: {
            var entries: [4]?Stored = @splat(null);
            const next = if (snapshot != null) result.historical_page.next else result.page.next;
            if (snapshot != null) {
                for (result.historical_page.entries, &entries) |entry, *out| if (entry) |item| {
                    out.* = try Stored.foreign(a, item.declaration);
                };
            } else for (result.page.entries, &entries) |entry, *out| if (entry) |item| {
                out.* = try Stored.foreign(a, item);
            };
            break :blk .{ .page = .{ .entries = entries, .next = if (next) |after| .{ .definition = c.protocol.Growth.current_definition, .connection = try h.Connection.foreign(a, client.connection), .namespace = value.namespace, .selector = if (value.selector) |selector| try a.dupe(u8, selector) else null, .after = try v.decimal(a, after) } else null, .snapshot = if (snapshot) |cut| try c.DirectCatalogHistory.Snapshot.foreign(a, cut) else null, .position = if (snapshot == null) try h.Position.foreign(a, result.page.position) else null } };
        },
    };
}
