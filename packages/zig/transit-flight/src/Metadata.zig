//! Finite standard Flight SQL metadata. No catalog I/O or authority lives here.
const std = @import("std");
const root = @import("root.zig");
const f = root.query.fuze;
const a = f.arrow;
const w = root.Wire;
const pb = root.grpc.protobuf;
pub const catalog = "transit";
pub const db_schema = "public";
pub const max_requests = 64;
pub const working_bytes = 8 * 1024 * 1024;
const text_type: a.DataType = .{ .string = {} };
const binary_type: a.DataType = .{ .binary = {} };
const i32_type: a.DataType = .{ .int32 = {} };
const i64_type: a.DataType = .{ .int64 = {} };
const u32_type: a.DataType = .{ .uint32 = {} };
const bool_type: a.DataType = .{ .bool = {} };
const string_item: a.Field = .{ .name = "string_data", .data_type = &text_type, .nullable = true };
const int_item: a.Field = .{ .name = "$data$", .data_type = &i32_type, .nullable = true };
const string_list: a.DataType = .{ .list = .{ .value_field = string_item } };
const int_list: a.DataType = .{ .list = .{ .value_field = int_item } };
const map_key: a.Field = .{ .name = "key", .data_type = &i32_type, .nullable = false };
const map_value: a.Field = .{ .name = "value", .data_type = &int_list, .nullable = true };
const map_type: a.DataType = .{ .map = .{ .key_field = map_key, .item_field = map_value, .keys_sorted = false } };
const union_fields = [_]a.Field{
    .{ .name = "string_value", .data_type = &text_type, .nullable = true },
    .{ .name = "bool_value", .data_type = &bool_type, .nullable = true },
    .{ .name = "bigint_value", .data_type = &i64_type, .nullable = true },
    .{ .name = "int32_bitmask", .data_type = &i32_type, .nullable = true },
    .{ .name = "string_list", .data_type = &string_list, .nullable = true },
    .{ .name = "int32_to_int32_list_map", .data_type = &map_type, .nullable = true },
};
const union_kind: a.UnionType = .{ .fields = &union_fields, .type_ids = &.{ 0, 1, 2, 3, 4, 5 }, .mode = .dense };
const union_type: a.DataType = .{ .dense_union = union_kind };
pub const known_info = [_]u32{ 0, 1, 2, 3, 4, 5, 8, 9, 10, 11, 100, 101, 500, 501, 502, 504, 508, 517, 541, 542, 543, 547, 548, 557, 559, 560, 563, 572, 573, 574 };
const Info = union(enum) { text: []const u8, boolean: bool, bigint: i64, bitmask: i32, strings, conversions };
fn info(id: u32) !Info {
    return switch (id) {
        0 => .{ .text = "Transit Fuze" },
        1 => .{ .text = "finite-table-v1" },
        2 => .{ .text = "IPC V5" },
        3, 4 => .{ .boolean = true },
        5, 9, 10, 11, 500, 501, 502, 563, 572, 573, 574 => .{ .boolean = false },
        8 => .{ .bitmask = 0 }, // no transactions or savepoints
        100 => .{ .bigint = 180 },
        101 => .{ .bigint = 0 },
        504 => .{ .text = "\"" },
        508 => .strings,
        517 => .conversions,
        541, 542 => .{ .bigint = (f.Types.Limits{}).value_bytes },
        543, 559 => .{ .bigint = 255 },
        547, 548 => .{ .bigint = f.TableSchema.max_columns },
        557 => .{ .bigint = f.Sql.max_statement_bytes },
        560 => .{ .bigint = 1 },
        else => error.UnsupportedFlightMetadata,
    };
}
/// SQL LIKE matching for the single bounded UTF-8 published name. Iterative
/// backtracking handles '%' without recursion or input-sized allocation.
fn matches(pattern: ?[]const u8, value: []const u8) !bool {
    const p = pattern orelse return true;
    if (p.len > 255 or !std.unicode.utf8ValidateSlice(p) or !std.unicode.utf8ValidateSlice(value)) return error.InvalidFlightMetadata;
    var pi: usize = 0;
    var vi: usize = 0;
    var star: ?usize = null;
    var retry: usize = 0;
    while (vi < value.len) {
        if (pi < p.len and p[pi] == '_') {
            pi += 1;
            vi += try std.unicode.utf8ByteSequenceLength(value[vi]);
        } else if (pi < p.len and p[pi] == value[vi]) {
            const width = try std.unicode.utf8ByteSequenceLength(value[vi]);
            if (pi + width <= p.len and std.mem.eql(u8, p[pi..][0..width], value[vi..][0..width])) {
                pi += width;
                vi += width;
            } else if (star) |index| {
                retry += try std.unicode.utf8ByteSequenceLength(value[retry]);
                vi = retry;
                pi = index + 1;
            } else return false;
        } else if (pi < p.len and p[pi] == '%') {
            star = pi;
            pi += 1;
            retry = vi;
        } else if (star) |index| {
            retry += try std.unicode.utf8ByteSequenceLength(value[retry]);
            vi = retry;
            pi = index + 1;
        } else return false;
    }
    while (pi < p.len and p[pi] == '%') pi += 1;
    return pi == p.len;
}
fn catalogMatches(value: ?[]const u8) bool {
    return if (value) |v| std.mem.eql(u8, v, catalog) else true;
}

/// Compile through the current query grammar and derive the same primitive
/// schema used when adapting verified captured rows. No admission or source I/O.
pub fn querySchema(name: []const u8, schema: f.Types.Type, sql: []const u8, output: []u8, workspace: []u8) ![]const u8 {
    return querySchemaDiagnostic(name, schema, sql, output, workspace, null);
}
pub fn querySchemaDiagnostic(name: []const u8, schema: f.Types.Type, sql: []const u8, output: []u8, workspace: []u8, diagnostic: ?*f.Sql.Binding) ![]const u8 {
    var fixed: std.heap.FixedBufferAllocator = .init(workspace);
    // Compile through the shared parser, with no invented catalog identity.
    // Copy layout names before the compile arena is released/reused by Arrow.
    const layout = layout: {
        var arena: std.heap.ArenaAllocator = .init(fixed.allocator());
        defer arena.deinit();
        const plan = try f.TableSelect.planDiagnostic(arena.allocator(), sql, name, schema, @splat(0), diagnostic);
        break :layout try root.TableResult.init(plan);
    };
    const bytes = try layout.encode(&.{}, output, workspace);
    return (try root.Ipc.parts(bytes, workspace)).schema_message;
}

pub fn encode(command: w.Any, name: []const u8, schema: f.Types.Type, output: []u8, workspace: []u8) ![]const u8 {
    try schema.validate(.{});
    _ = try f.Sql.Binding.Name.init(name);
    var fixed: std.heap.FixedBufferAllocator = .init(workspace);
    const allocator = fixed.allocator();
    if (!std.mem.startsWith(u8, command.type_url, root.command_prefix)) return error.UnsupportedFlightCommand;
    const kind = command.type_url[root.command_prefix.len..];
    if (std.mem.eql(u8, kind, "CommandGetSqlInfo")) {
        var decoded = try pb.decode(w.CommandGetSqlInfo, allocator, command.value, .{ .max_arena_bytes = 65536 });
        defer decoded.deinit();
        return encodeInfo(allocator, decoded.value.info, output);
    }
    const Column = struct { name: []const u8, value: []const u8, nullable: bool = false, binary: bool = false };
    var columns: [5]Column = undefined;
    var count: usize = 0;
    var present = true;
    var table_schema: [f.LogicalArrow.segment_bytes]u8 = undefined;
    if (std.mem.eql(u8, kind, "CommandGetCatalogs")) {
        var decoded = try pb.decode(w.CommandGetCatalogs, allocator, command.value, .{ .max_arena_bytes = 65536 });
        defer decoded.deinit();
        columns[0] = .{ .name = "catalog_name", .value = catalog };
        count = 1;
    } else if (std.mem.eql(u8, kind, "CommandGetTableTypes")) {
        var decoded = try pb.decode(w.CommandGetTableTypes, allocator, command.value, .{ .max_arena_bytes = 65536 });
        defer decoded.deinit();
        columns[0] = .{ .name = "table_type", .value = "TABLE" };
        count = 1;
    } else if (std.mem.eql(u8, kind, "CommandGetDbSchemas")) {
        var decoded = try pb.decode(w.CommandGetDbSchemas, allocator, command.value, .{ .max_arena_bytes = 65536 });
        defer decoded.deinit();
        present = catalogMatches(decoded.value.catalog) and try matches(decoded.value.db_schema_filter_pattern, db_schema);
        columns[0] = .{ .name = "catalog_name", .value = catalog, .nullable = true };
        columns[1] = .{ .name = "db_schema_name", .value = db_schema };
        count = 2;
    } else if (std.mem.eql(u8, kind, "CommandGetTables")) {
        var decoded = try pb.decode(w.CommandGetTables, allocator, command.value, .{ .max_arena_bytes = 65536 });
        defer decoded.deinit();
        const request = decoded.value;
        if (request.table_types.len > max_requests) return error.InvalidFlightMetadata;
        present = catalogMatches(request.catalog) and try matches(request.db_schema_filter_pattern, db_schema) and try matches(request.table_name_filter_pattern, name);
        if (request.table_types.len > 0) {
            var found = false;
            for (request.table_types) |value| found = found or std.mem.eql(u8, value, "TABLE");
            present = present and found;
        }
        columns[0] = .{ .name = "catalog_name", .value = catalog, .nullable = true };
        columns[1] = .{ .name = "db_schema_name", .value = db_schema, .nullable = true };
        columns[2] = .{ .name = "table_name", .value = name };
        columns[3] = .{ .name = "table_type", .value = "TABLE" };
        count = 4;
        if (request.include_schema) {
            // Use a separate bounded workspace: metadata decoding remains live.
            const scratch = try allocator.alloc(u8, f.LogicalArrow.working_bytes);
            defer allocator.free(scratch);
            var projection: [f.TableSchema.max_columns]u8 = undefined;
            if (schema != .structure or schema.structure.len > projection.len) return error.InvalidQuerySchema;
            for (projection[0..schema.structure.len], 0..) |*index, i| index.* = @intCast(i);
            const layout = try root.TableResult.init(.{ .schema = schema, .source_basis = @splat(0), .projection = projection[0..schema.structure.len] });
            const bytes = try layout.encode(&.{}, &table_schema, scratch);
            columns[4] = .{ .name = "table_schema", .value = (try root.Ipc.parts(bytes, scratch)).schema_message, .binary = true };
            count = 5;
        }
    } else return error.UnsupportedFlightCommand;
    var fields: [5]a.Field = undefined;
    var arrays: [5]a.ArrayRef = undefined;
    var initialized: usize = 0;
    defer for (arrays[0..initialized]) |*array| array.release();
    for (columns[0..count], 0..) |column, index| {
        fields[index] = .{ .name = column.name, .data_type = if (column.binary) &binary_type else &text_type, .nullable = column.nullable };
        if (column.binary) {
            var builder = try a.BinaryBuilder.init(allocator, 1, column.value.len);
            defer builder.deinit();
            if (present) try builder.append(column.value);
            arrays[index] = try builder.finish();
        } else {
            var builder = try a.StringBuilder.init(allocator, 1, column.value.len);
            defer builder.deinit();
            if (present) try builder.append(column.value);
            arrays[index] = try builder.finish();
        }
        initialized += 1;
    }
    var batch = try a.RecordBatch.initBorrowed(allocator, .{ .fields = fields[0..count] }, arrays[0..count]);
    defer batch.deinit();
    return f.encode(allocator, batch, output);
}
fn encodeInfo(allocator: std.mem.Allocator, requested: []const u32, output: []u8) ![]const u8 {
    const ids = if (requested.len == 0) &known_info else requested;
    if (ids.len > max_requests) return error.InvalidFlightMetadata;
    var names = try a.UInt32Builder.init(allocator, ids.len);
    defer names.deinit();
    var strings = try a.StringBuilder.init(allocator, ids.len, 2048);
    defer strings.deinit();
    var booleans = try a.BooleanBuilder.init(allocator, ids.len);
    defer booleans.deinit();
    var bigints = try a.Int64Builder.init(allocator, ids.len);
    defer bigints.deinit();
    var bitmasks = try a.Int32Builder.init(allocator, ids.len);
    defer bitmasks.deinit();
    var lists = try a.ListBuilder.init(allocator, ids.len, string_item);
    defer lists.deinit();
    var maps = try a.MapBuilder.init(allocator, ids.len, map_key, map_value, false);
    defer maps.deinit();
    var values = try a.DenseUnionBuilder.init(allocator, union_kind, ids.len);
    defer values.deinit();
    var offsets: [6]i32 = @splat(0);
    for (ids) |id| {
        const value = try info(id);
        const tag: i8 = switch (value) {
            .text => |v| blk: {
                try strings.append(v);
                break :blk 0;
            },
            .boolean => |v| blk: {
                try booleans.append(v);
                break :blk 1;
            },
            .bigint => |v| blk: {
                try bigints.append(v);
                break :blk 2;
            },
            .bitmask => |v| blk: {
                try bitmasks.append(v);
                break :blk 3;
            },
            .strings => blk: {
                try lists.appendLen(0);
                break :blk 4;
            },
            .conversions => blk: {
                try maps.appendLen(0);
                break :blk 5;
            },
        };
        const index: usize = @intCast(tag);
        try names.append(id);
        try values.append(tag, offsets[index]);
        offsets[index] += 1;
    }
    var empty_strings = try a.StringBuilder.init(allocator, 0, 0);
    defer empty_strings.deinit();
    var string_items = try empty_strings.finish();
    defer string_items.release();
    var empty_ints = try a.Int32Builder.init(allocator, 0);
    defer empty_ints.deinit();
    var int_items = try empty_ints.finish();
    defer int_items.release();
    var int_lists = try a.ListBuilder.init(allocator, 0, int_item);
    defer int_lists.deinit();
    var list_items = try int_lists.finish(int_items);
    defer list_items.release();
    var entries = a.StructBuilder.init(allocator, &.{ map_key, map_value });
    defer entries.deinit();
    var entry_items = try entries.finish(&.{ int_items, list_items });
    defer entry_items.release();
    var children: [6]a.ArrayRef = undefined;
    var initialized: usize = 0;
    defer for (children[0..initialized]) |*child| child.release();
    children[0] = try strings.finish();
    initialized += 1;
    children[1] = try booleans.finish();
    initialized += 1;
    children[2] = try bigints.finish();
    initialized += 1;
    children[3] = try bitmasks.finish();
    initialized += 1;
    children[4] = try lists.finish(string_items);
    initialized += 1;
    children[5] = try maps.finish(entry_items);
    initialized += 1;
    var union_array = try values.finish(&children);
    defer union_array.release();
    var name_array = try names.finish();
    defer name_array.release();
    const fields = [_]a.Field{ .{ .name = "info_name", .data_type = &u32_type, .nullable = false }, .{ .name = "value", .data_type = &union_type, .nullable = true } };
    var batch = try a.RecordBatch.initBorrowed(allocator, .{ .fields = &fields }, &.{ name_array, union_array });
    defer batch.deinit();
    return f.encode(allocator, batch, output);
}

test "bounded standard metadata schemas and exact optional filtering" {
    const t = std.testing;
    const workspace = try t.allocator.alloc(u8, 8 * 1024 * 1024);
    defer t.allocator.free(workspace);
    var output: [16384]u8 = undefined;
    const schema: f.Types.Type = .{ .structure = &.{ .{ .name = "id", .type = .int64 }, .{ .name = "count", .type = .int64, .nullable = true } } };
    inline for (.{ "CommandGetCatalogs", "CommandGetDbSchemas", "CommandGetTables", "CommandGetTableTypes", "CommandGetSqlInfo" }) |kind| {
        const bytes = try encode(.{ .type_url = root.command_prefix ++ kind }, "counter", schema, &output, workspace);
        const ipc = try root.Ipc.parts(bytes, workspace);
        try t.expectEqual(@as(u64, if (std.mem.eql(u8, kind, "CommandGetSqlInfo")) known_info.len else 1), ipc.rows);
    }
    const command = try pb.encodeAlloc(t.allocator, w.CommandGetTables{ .catalog = "", .include_schema = true }, .{});
    defer t.allocator.free(command);
    const bytes = try encode(.{ .type_url = root.command_prefix ++ "CommandGetTables", .value = command }, "counter", schema, &output, workspace);
    try t.expectEqual(@as(u64, 0), (try root.Ipc.parts(bytes, workspace)).rows);
    try t.expect(try matches("c%_er", "counter"));
    try t.expect(!try matches("c%_er", "count"));
    try t.expect(try matches("_京%", "東京🙂"));
    try t.expect(try matches("%_", "東京🙂"));
    try t.expect(!try matches("__", "東京🙂"));
    try t.expect(!try matches("_三%", "東京🙂"));
    try t.expectError(error.UnsupportedFlightMetadata, info(9999));
}
