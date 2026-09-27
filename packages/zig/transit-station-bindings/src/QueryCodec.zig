//! Versioned foreign values around the shared v2 source/plan/Arrow model.
//! Integers wider than the protocol counter and float bits never pass as JSON
//! numbers. All returned byte strings belong to the supplied result allocator.
const std = @import("std");
pub const query = @import("transit_query");
const q = query;
const m = q.fuze.Unified;
const d = @import("DocumentCodec.zig");
const a = @import("Actions.zig");
const base = @import("Abi.zig");
const Allocator = std.mem.Allocator;
pub const maximum_json_bytes = q.protocol.max_body;
pub const unsigned = d.unsigned;
pub const unhex = d.unhex;
pub const Column = struct {
    name: []const u8,
    type: m.Type,
    pub fn native(self: Column) !m.Column {
        return .{ .name = try m.Name.init(self.name), .type = self.type };
    }
    pub fn fromNative(alloc: Allocator, value: m.Column) !Column {
        return .{ .name = try alloc.dupe(u8, value.name.slice()), .type = value.type };
    }
};
pub fn columns(alloc: Allocator, values: []const Column) !m.Schema {
    if (values.len == 0 or values.len > m.max_columns) return error.InvalidColumnCount;
    const items = try alloc.alloc(m.Column, values.len);
    for (items, values) |*out, in| out.* = try in.native();
    const schema: m.Schema = .{ .columns = items };
    try schema.validate();
    return schema;
}
pub fn foreignColumns(alloc: Allocator, schema: m.Schema) ![]const Column {
    try schema.validate();
    const items = try alloc.alloc(Column, schema.columns.len);
    for (items, schema.columns) |*out, in| out.* = try Column.fromNative(alloc, in);
    return items;
}
pub const Scalar = union(enum) {
    int64: []const u8,
    uint64: []const u8,
    float_bits: []const u8,
    boolean: bool,
    utf8: []const u8,
    binary: []const u8,
    pub fn native(self: Scalar, alloc: Allocator) !m.Scalar {
        const out: m.Scalar = switch (self) {
            .int64 => |text| blk: {
                const negative = std.mem.startsWith(u8, text, "-");
                const magnitude = try unsigned(if (negative) text[1..] else text);
                if (negative and magnitude == 0) return error.InvalidQueryInteger;
                break :blk .{ .int64 = try std.fmt.parseInt(i64, text, 10) };
            },
            .uint64 => |text| .{ .uint64 = try unsigned(text) },
            .float_bits => |text| blk: {
                if (text.len != 16) return error.InvalidQueryScalar;
                const bytes = try unhex(alloc, text, 8);
                break :blk .{ .float64 = @bitCast(std.mem.readInt(u64, bytes[0..8], .little)) };
            },
            .boolean => |v| .{ .boolean = v },
            .utf8 => |v| .{ .utf8 = v },
            .binary => |v| .{ .binary = try unhex(alloc, v, m.max_cell_bytes) },
        };
        try out.validate(std.meta.activeTag(out));
        return out;
    }
    pub fn fromNative(alloc: Allocator, value: m.Scalar) !Scalar {
        try value.validate(std.meta.activeTag(value));
        return switch (value) {
            .int64 => |v| .{ .int64 = try a.decimal(alloc, v) },
            .uint64 => |v| .{ .uint64 = try a.decimal(alloc, v) },
            .float64 => |v| blk: {
                var bytes: [8]u8 = undefined;
                std.mem.writeInt(u64, &bytes, @bitCast(v), .little);
                break :blk .{ .float_bits = try a.hex(alloc, &bytes) };
            },
            .boolean => |v| .{ .boolean = v },
            .utf8 => |v| .{ .utf8 = try alloc.dupe(u8, v) },
            .binary => |v| .{ .binary = try a.hex(alloc, v) },
        };
    }
};
pub const Projection = struct {
    column: Column,
    path: []const []const u8,
    relative: bool = false,
    mode: @FieldType(q.SourceDefinition.Projection, "mode") = .scalar,
    text_bytes: u16 = m.max_cell_bytes,
    text_steps: u16 = 4096,
};
fn path(alloc: Allocator, names: []const []const u8) ![]const q.document.Model.Name {
    if (names.len > 8) return error.InvalidQueryPath;
    const result = try alloc.alloc(q.document.Model.Name, names.len);
    for (result, names) |*out, in| out.* = try q.document.Model.Name.init(in);
    return result;
}
fn foreignPath(alloc: Allocator, names: []const q.document.Model.Name) ![]const []const u8 {
    const result = try alloc.alloc([]const u8, names.len);
    for (result, names) |*out, in| out.* = try alloc.dupe(u8, in.slice());
    return result;
}
pub const Source = struct {
    version: u8 = 2,
    resource: u64,
    source: union(enum) {
        kv: struct { prefix: []const u8, key: q.SourceDefinition.Decoder, value: q.SourceDefinition.Decoder },
        table: struct { id: u32, names: [2][]const u8, value_type: q.fuze.model.Type },
        document: struct { reference: d.Reference, change_format: u32 = 1, expand: ?[]const []const u8 = null, projections: []const Projection },
    },
    pub fn native(self: Source, alloc: Allocator) !q.SourceDefinition {
        const source: @FieldType(q.SourceDefinition, "source") = switch (self.source) {
            .kv => |v| .{ .kv = .{ .prefix = try q.protocol.Value.init(try unhex(alloc, v.prefix, q.protocol.Growth.key_bytes)), .key = v.key, .value = v.value } },
            .table => |v| .{ .table = .{ .id = v.id, .schema = .{ .names = .{ try .init(v.names[0]), try .init(v.names[1]) }, .value_type = v.value_type } } },
            .document => |v| blk: {
                if (v.projections.len == 0 or v.projections.len > m.max_columns) return error.InvalidProjection;
                const projections = try alloc.alloc(q.SourceDefinition.Projection, v.projections.len);
                for (projections, v.projections) |*out, in| out.* = .{ .column = try in.column.native(), .path = try path(alloc, in.path), .relative = in.relative, .mode = in.mode, .text_bytes = in.text_bytes, .text_steps = in.text_steps };
                break :blk .{ .document = .{ .reference = try v.reference.native(), .change_format = v.change_format, .expand = if (v.expand) |names| try path(alloc, names) else null, .projections = projections } };
            },
        };
        const result: q.SourceDefinition = .{ .version = self.version, .resource = self.resource, .source = source };
        var storage: [m.max_columns]m.Column = undefined;
        _ = try result.schema(&storage);
        return result;
    }
    pub fn fromNative(alloc: Allocator, value: q.SourceDefinition) !Source {
        return .{ .version = value.version, .resource = value.resource, .source = switch (value.source) {
            .kv => |v| .{ .kv = .{ .prefix = try a.hex(alloc, v.prefix.slice()), .key = v.key, .value = v.value } },
            .table => |v| .{ .table = .{ .id = v.id, .names = .{ try alloc.dupe(u8, v.schema.names[0].slice()), try alloc.dupe(u8, v.schema.names[1].slice()) }, .value_type = v.schema.value_type } },
            .document => |v| blk: {
                const projections = try alloc.alloc(Projection, v.projections.len);
                for (projections, v.projections) |*out, in| out.* = .{ .column = try Column.fromNative(alloc, in.column), .path = try foreignPath(alloc, in.path), .relative = in.relative, .mode = in.mode, .text_bytes = in.text_bytes, .text_steps = in.text_steps };
                break :blk .{ .document = .{ .reference = try d.Reference.fromNative(alloc, v.reference), .change_format = v.change_format, .expand = if (v.expand) |names| try foreignPath(alloc, names) else null, .projections = projections } };
            },
        } };
    }
};
pub const Plan = struct {
    version: u8 = 2,
    projection: []const u32,
    limit: ?[]const u8 = null,
    aggregate: m.Plan.Aggregate = .rows,
    predicate: union(enum) { all, state: struct { column: u8, value: m.State }, compare: struct { column: u8, op: m.Plan.Comparison, value: Scalar } } = .all,
    pub fn native(self: Plan, alloc: Allocator) !m.Plan {
        if (self.projection.len == 0 or self.projection.len > m.max_columns) return error.InvalidProjection;
        const selected = try alloc.alloc(u8, self.projection.len);
        for (selected, self.projection) |*out, in| {
            if (in >= m.max_columns) return error.UnknownColumn;
            out.* = @intCast(in);
        }
        return .{ .version = self.version, .projection = selected, .limit = if (self.limit) |v| try unsigned(v) else null, .aggregate = self.aggregate, .predicate = switch (self.predicate) {
            .all => .all,
            .state => |v| .{ .state = .{ .column = v.column, .value = v.value } },
            .compare => |v| .{ .compare = .{ .column = v.column, .op = v.op, .value = try v.value.native(alloc) } },
        } };
    }
    pub fn fromNative(alloc: Allocator, value: m.Plan) !Plan {
        const selected = try alloc.alloc(u32, value.projection.len);
        for (selected, value.projection) |*out, in| out.* = in;
        return .{ .version = value.version, .projection = selected, .limit = if (value.limit) |v| try a.decimal(alloc, v) else null, .aggregate = value.aggregate, .predicate = switch (value.predicate) {
            .all => .all,
            .state => |v| .{ .state = .{ .column = v.column, .value = v.value } },
            .compare => |v| .{ .compare = .{ .column = v.column, .op = v.op, .value = try Scalar.fromNative(alloc, v.value) } },
        } };
    }
};
pub const Limits = struct {
    pages: []const u8,
    segments: []const u8,
    result_bytes: []const u8,
    pub fn native(self: Limits) !q.Bundle.Limits {
        const result: q.Bundle.Limits = .{ .pages = try unsigned(self.pages), .segments = try unsigned(self.segments), .result_bytes = try unsigned(self.result_bytes) };
        try result.validate();
        return result;
    }
    pub fn fromNative(alloc: Allocator, value: q.Bundle.Limits) !Limits {
        return .{ .pages = try a.decimal(alloc, value.pages), .segments = try a.decimal(alloc, value.segments), .result_bytes = try a.decimal(alloc, value.result_bytes) };
    }
};
pub const Bundle = struct {
    source: Source,
    plan: Plan,
    limits: Limits,
    pub fn native(self: Bundle, alloc: Allocator) !q.Bundle {
        const result: q.Bundle = .{ .source = try self.source.native(alloc), .plan = try self.plan.native(alloc), .limits = try self.limits.native() };
        try result.validate();
        return result;
    }
    pub fn fromNative(alloc: Allocator, value: q.Bundle) !Bundle {
        return .{ .source = try Source.fromNative(alloc, value.source), .plan = try Plan.fromNative(alloc, value.plan), .limits = try Limits.fromNative(alloc, value.limits) };
    }
};
pub const Alternative = struct {
    counter: []const u8,
    replica: []const u8,
    value: union(enum) { null, type_error: m.Kind, value: Scalar },
};
pub const Cell = union(enum) {
    missing,
    null,
    type_error: m.Kind,
    value: Scalar,
    conflict: []const Alternative,
    pub fn fromNative(alloc: Allocator, value: m.Cell) !Cell {
        return switch (value) {
            .missing => .missing,
            .null => .null,
            .type_error => |v| .{ .type_error = v },
            .value => |v| .{ .value = try Scalar.fromNative(alloc, v) },
            .conflict => |values| blk: {
                const items = try alloc.alloc(Alternative, values.len);
                for (items, values) |*out, in| out.* = .{ .counter = try a.decimal(alloc, in.counter), .replica = try a.decimal(alloc, in.replica), .value = switch (in.value) {
                    .null => .null,
                    .type_error => |v| .{ .type_error = v },
                    .value => |v| .{ .value = try Scalar.fromNative(alloc, v) },
                } };
                break :blk .{ .conflict = items };
            },
        };
    }
};
pub fn rows(alloc: Allocator, decoded: *const m.Inspect.Batch) ![]const []const Cell {
    const result = try alloc.alloc([]const Cell, decoded.count);
    for (result, 0..) |*out, index| {
        const row = try decoded.row(index);
        const cells = try alloc.alloc(Cell, row.cells.len);
        for (cells, row.cells) |*cell, value| cell.* = try Cell.fromNative(alloc, value);
        out.* = cells;
    }
    return result;
}
pub const Action = union(enum) {
    prepare: Bundle,
    decode: []const u8,
    source: Source,
    inspect_arrow: struct { columns: []const Column, rows: u8, ipc: []const u8 },
};
pub const Result = union(enum) {
    prepared: struct { bytes: []const u8, spec: q.station.Publication.Spec },
    bundle: Bundle,
    source: struct { bytes: []const u8, digest: [32]u8, declaration: [32]u8, columns: []const Column },
    rows: []const []const Cell,
};
pub fn apply(alloc: Allocator, action: Action) !Result {
    switch (action) {
        .prepare => |v| {
            var buffer: [q.Bundle.max_bytes]u8 = undefined;
            const bytes = try (try v.native(alloc)).encode(&buffer);
            return .{ .prepared = .{ .bytes = try a.hex(alloc, bytes), .spec = try q.station.Publication.Digest.of(q.Bundle.format, bytes) } };
        },
        .decode => |v| return .{ .bundle = try Bundle.fromNative(alloc, try q.Bundle.decode(alloc, try unhex(alloc, v, q.Bundle.max_bytes))) },
        .source => |v| {
            const native = try v.native(alloc);
            var storage: [m.max_columns]m.Column = undefined;
            var buffer: [q.SourceDefinition.max_bytes]u8 = undefined;
            return .{ .source = .{ .bytes = try a.hex(alloc, try native.encode(&buffer)), .digest = try native.fingerprint(), .declaration = try q.Bundle.declaration(native), .columns = try foreignColumns(alloc, try native.schema(&storage)) } };
        },
        .inspect_arrow => |v| {
            const workspace = try alloc.alloc(u8, m.Arrow.working_bytes);
            var decoded: m.Inspect.Batch = undefined;
            try m.Inspect.decode(try columns(alloc, v.columns), try unhex(alloc, v.ipc, m.Arrow.segment_bytes), v.rows, workspace, alloc, &decoded);
            return .{ .rows = try rows(alloc, &decoded) };
        },
    }
}
pub fn codec(json: [*]const u8, len: usize, out: *?*base.Buffer) callconv(.c) base.Status {
    out.* = null;
    if (len == 0 or len > maximum_json_bytes) return .invalid_argument;
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const parsed = std.json.parseFromSlice(Action, alloc, json[0..len], .{}) catch |err| return base.failure(err, out);
    const result = apply(alloc, parsed.value) catch |err| return base.failure(err, out);
    base.output(result, out) catch |err| return base.status(err);
    return .ok;
}
test "unified foreign bundles preserve every source and full-width scalar through owned JSON" {
    const t = std.testing;
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const sources = [_]Source{
        .{ .resource = 7, .source = .{ .kv = .{ .prefix = "646174612f", .key = .{ .type = .binary }, .value = .{ .type = .uint64 } } } },
        .{ .resource = 7, .source = .{ .table = .{ .id = 9, .names = .{ "id", "label" }, .value_type = .utf8 } } },
        .{ .resource = 7, .source = .{ .document = .{ .reference = .{ .resource = 7, .document = "18446744073709551615", .epoch = "3", .type_revision = 1, .revision = "42" }, .projections = &.{.{ .column = .{ .name = "body", .type = .utf8 }, .path = &.{"東京🙂"}, .mode = .text }} } } },
    };
    for (sources) |source| {
        const input: Bundle = .{ .source = source, .plan = .{ .projection = &.{0}, .limit = "18446744073709551615" }, .limits = .{ .pages = "1000", .segments = "500", .result_bytes = "1048576" } };
        const prepared = (try apply(alloc, .{ .prepare = input })).prepared;
        const decoded = (try apply(alloc, .{ .decode = prepared.bytes })).bundle;
        try t.expectEqualStrings(input.plan.limit.?, decoded.plan.limit.?);
        const json = try std.json.Stringify.valueAlloc(alloc, Action{ .prepare = decoded }, .{});
        try t.expect(std.mem.indexOf(u8, json, "\"projection\":[0]") != null);
        var buffer: ?*base.Buffer = null;
        try t.expectEqual(.ok, codec(json.ptr, json.len, &buffer));
        defer base.Api.station_buffer_destroy(buffer);
        const output = try std.json.parseFromSlice(Result, alloc, base.Api.station_buffer_data(buffer.?)[0..base.Api.station_buffer_size(buffer.?)], .{});
        try t.expectEqualStrings(prepared.bytes, output.value.prepared.bytes);
        try t.expectEqualDeep(prepared.spec, output.value.prepared.spec);
    }
    const scalars = [_]Scalar{ .{ .int64 = "-9223372036854775808" }, .{ .uint64 = "18446744073709551615" }, .{ .float_bits = "0000000000000080" }, .{ .boolean = false }, .{ .utf8 = "é 東京🙂" }, .{ .binary = "00ff80" } };
    for (scalars) |scalar| {
        const restored = try Scalar.fromNative(alloc, try scalar.native(alloc));
        try t.expectEqualStrings(try std.json.Stringify.valueAlloc(alloc, scalar, .{}), try std.json.Stringify.valueAlloc(alloc, restored, .{}));
    }
    try t.expectError(error.InvalidQueryInteger, (Scalar{ .int64 = "-0" }).native(alloc));
    try t.expectError(error.InvalidDocumentInteger, (Scalar{ .uint64 = "01" }).native(alloc));
    try t.expectError(error.NonFiniteValue, (Scalar{ .float_bits = "000000000000f07f" }).native(alloc));
    var invalid = sources[0];
    invalid.source.kv.value.version = 2;
    try t.expectError(error.UnsupportedDecoder, invalid.native(alloc));
}
