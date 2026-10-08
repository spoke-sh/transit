//! Bounded Arrow IPC export for logical values. The caller owns admission,
//! authority, publication and result completeness; this codec owns neither.
const std = @import("std");
const f = @import("root.zig");
const t = f.Types;
const v = t.Values;
const a = f.arrow;
pub const working_bytes = f.Unified.Arrow.working_bytes;
pub const segment_bytes = f.Unified.Arrow.segment_bytes;
pub const max_rows = f.Unified.max_rows;
pub const definition = "transit.fuze.logical-arrow.v1.2026-09-30";
const u8_type: a.DataType = .{ .uint8 = {} };
const u64_type: a.DataType = .{ .uint64 = {} };
const Layout = struct {
    logical: t.Type,
    value: a.DataType,
    cell: a.DataType,
    alternatives: a.DataType,
    list: a.DataType,
    children: []*Layout,
    fn create(allocator: std.mem.Allocator, logical: t.Type) anyerror!*Layout {
        const self = try allocator.create(Layout);
        self.logical = logical;
        const count: usize = switch (logical) {
            .structure, .tagged_union => |fields| fields.len,
            .list, .array => 1,
            .map => 2,
            else => 0,
        };
        self.children = try allocator.alloc(*Layout, count);
        switch (logical) {
            .structure, .tagged_union => |fields| for (fields, self.children) |field, *child| {
                child.* = try create(allocator, field.type);
            },
            .list => |element| self.children[0] = try create(allocator, element.type.*),
            .array => |array| self.children[0] = try create(allocator, array.element.type.*),
            .map => |map| {
                self.children[0] = try create(allocator, map.key.*);
                self.children[1] = try create(allocator, map.value.type.*);
            },
            else => {},
        }
        self.value = switch (logical) {
            .int8 => .{ .int8 = {} },
            .int16 => .{ .int16 = {} },
            .int32 => .{ .int32 = {} },
            .int64 => .{ .int64 = {} },
            .uint8 => .{ .uint8 = {} },
            .uint16 => .{ .uint16 = {} },
            .uint32 => .{ .uint32 = {} },
            .uint64 => .{ .uint64 = {} },
            .int128, .uint128, .uuid => .{ .fixed_size_binary = .{ .byte_width = 16 } },
            .float32 => .{ .float = {} },
            .float64 => .{ .double = {} },
            .boolean => .{ .bool = {} },
            .utf8, .json => .{ .string = {} },
            .binary => .{ .binary = {} },
            .decimal => |d| .{ .decimal128 = .{ .precision = d.precision, .scale = d.scale } },
            .date => .{ .date32 = {} },
            .time => .{ .time64 = .{ .unit = .nanosecond } },
            .timestamp => |zone| .{ .timestamp = .{ .unit = .microsecond, .timezone = if (zone == .utc) "UTC" else null } },
            .interval => .{ .interval_month_day_nano = .{ .unit = .month_day_nano } },
            .structure => |fields| blk: {
                const physical = try allocator.alloc(a.Field, fields.len);
                for (fields, physical, self.children) |field, *out, child| out.* = .{ .name = field.name, .data_type = &child.cell, .nullable = false };
                break :blk .{ .struct_ = .{ .fields = physical } };
            },
            .list => .{ .list = .{ .value_field = .{ .name = "item", .data_type = &self.children[0].cell, .nullable = false } } },
            .array => |array| .{ .fixed_size_list = .{ .list_size = std.math.cast(i32, array.length) orelse return error.ArrowShapeTooLarge, .value_field = .{ .name = "item", .data_type = &self.children[0].cell, .nullable = false } } },
            .map => .{ .map = .{ .key_field = .{ .name = "key", .data_type = &self.children[0].value, .nullable = false }, .item_field = .{ .name = "value", .data_type = &self.children[1].cell, .nullable = false }, .keys_sorted = false } },
            .tagged_union => |fields| blk: {
                const variants = try allocator.alloc(a.Field, fields.len);
                for (fields, variants, self.children) |field, *out, child| out.* = .{ .name = field.name, .data_type = &child.cell, .nullable = false };
                const variant_type = try allocator.create(a.DataType);
                variant_type.* = .{ .struct_ = .{ .fields = variants } };
                break :blk .{ .struct_ = .{ .fields = try allocator.dupe(a.Field, &.{ .{ .name = "tag", .data_type = &u8_type, .nullable = false }, .{ .name = "variants", .data_type = variant_type, .nullable = false } }) } };
            },
        };
        self.alternatives = .{ .struct_ = .{ .fields = try allocator.dupe(a.Field, &.{
            .{ .name = "counter", .data_type = &u64_type, .nullable = false }, .{ .name = "replica", .data_type = &u64_type, .nullable = false },
            .{ .name = "state", .data_type = &u8_type, .nullable = false },    .{ .name = "kind", .data_type = &u8_type, .nullable = false },
            .{ .name = "value", .data_type = &self.value, .nullable = true },
        }) } };
        self.list = .{ .list = .{ .value_field = .{ .name = "item", .data_type = &self.alternatives, .nullable = false } } };
        self.cell = .{ .struct_ = .{ .fields = try allocator.dupe(a.Field, &.{
            .{ .name = "state", .data_type = &u8_type, .nullable = false },   .{ .name = "kind", .data_type = &u8_type, .nullable = false },
            .{ .name = "value", .data_type = &self.value, .nullable = true }, .{ .name = "alternatives", .data_type = &self.list, .nullable = false },
        }) } };
        return self;
    }
};
fn integers(comptime Builder: type, allocator: std.mem.Allocator, data: anytype) !a.ArrayRef {
    var builder = try Builder.init(allocator, data.len);
    defer builder.deinit();
    for (data) |item| try builder.append(item);
    return builder.finish();
}
fn structure(allocator: std.mem.Allocator, fields: []const a.Field, children: []const a.ArrayRef, data: anytype) !a.ArrayRef {
    var builder = a.StructBuilder.init(allocator, fields);
    defer builder.deinit();
    for (data) |item| if (item != null) try builder.appendValid() else try builder.appendNull();
    return builder.finish(children);
}
fn primitive(comptime tag: t.Tag, allocator: std.mem.Allocator, layout: *const Layout, data: []const ?v.Value) !a.ArrayRef {
    if (comptime tag == .int128 or tag == .uint128 or tag == .uuid) {
        var builder = try a.FixedSizeBinaryBuilder.init(allocator, 16, data.len);
        defer builder.deinit();
        for (data) |item| {
            if (item) |value| {
                var bytes: [16]u8 = undefined;
                switch (tag) {
                    .int128 => std.mem.writeInt(i128, &bytes, value.atom.signed, .little),
                    .uint128 => std.mem.writeInt(u128, &bytes, value.atom.unsigned, .little),
                    .uuid => bytes = value.atom.uuid,
                    else => unreachable,
                }
                try builder.append(&bytes);
            } else try builder.appendNull();
        }
        return builder.finish();
    } else {
        const Interval = extern struct { months: i32, days: i32, nanos: i64 };
        const Builder = switch (tag) {
            .int8 => a.Int8Builder,
            .int16 => a.Int16Builder,
            .int32 => a.Int32Builder,
            .int64 => a.Int64Builder,
            .uint8 => a.UInt8Builder,
            .uint16 => a.UInt16Builder,
            .uint32 => a.UInt32Builder,
            .uint64 => a.UInt64Builder,
            .float32 => a.Float32Builder,
            .float64 => a.Float64Builder,
            .boolean => a.BooleanBuilder,
            .utf8, .json => a.StringBuilder,
            .binary => a.BinaryBuilder,
            .decimal => a.PrimitiveBuilder(i128, .{ .decimal128 = .{ .precision = 38, .scale = 0 } }),
            .date => a.Date32Builder,
            .time => a.PrimitiveBuilder(i64, .{ .time64 = .{ .unit = .nanosecond } }),
            .timestamp => a.PrimitiveBuilder(i64, .{ .timestamp = .{ .unit = .microsecond, .timezone = null } }),
            .interval => a.PrimitiveBuilder(Interval, .{ .interval_month_day_nano = .{ .unit = .month_day_nano } }),
            else => unreachable,
        };
        var builder = if (comptime tag == .utf8 or tag == .binary or tag == .json) try Builder.init(allocator, data.len, 0) else try Builder.init(allocator, data.len);
        defer builder.deinit();
        for (data) |item| {
            if (item) |value| {
                try builder.append(switch (tag) {
                    .int8, .int16, .int32, .int64 => @intCast(value.atom.signed),
                    .uint8, .uint16, .uint32, .uint64 => @intCast(value.atom.unsigned),
                    .float32, .float64 => @floatCast(value.atom.float),
                    .boolean => value.atom.boolean,
                    .utf8, .binary => value.atom.bytes,
                    .json => value.json,
                    .decimal => value.atom.decimal,
                    .date => value.atom.date,
                    .time => @intCast(value.atom.time),
                    .timestamp => value.atom.timestamp,
                    .interval => Interval{ .months = value.atom.interval.months, .days = value.atom.interval.days, .nanos = value.atom.interval.nanos },
                    else => unreachable,
                });
            } else try builder.appendNull();
        }
        var array = try builder.finish();
        defer array.release();
        // Decimal precision/scale and timestamp timezone alter metadata only;
        // the checked native coefficient/unit and physical byte layout agree.
        var physical = array.data().*;
        physical.data_type = layout.value;
        return a.ArrayRef.fromBorrowed(allocator, physical);
    }
}
fn payload(allocator: std.mem.Allocator, layout: *const Layout, data: []const ?v.Value) anyerror!a.ArrayRef {
    return switch (layout.logical) {
        .structure, .tagged_union => nested(allocator, layout, data),
        .list, .array, .map => collection(allocator, layout, data),
        inline else => |_, tag| primitive(tag, allocator, layout, data),
    };
}
fn nested(allocator: std.mem.Allocator, layout: *const Layout, data: []const ?v.Value) !a.ArrayRef {
    const children = try allocator.alloc(a.ArrayRef, layout.children.len);
    var made: usize = 0;
    defer for (children[0..made]) |*child| child.release();
    const cells = try allocator.alloc(v.Cell, data.len);
    for (layout.children, 0..) |child, index| {
        for (data, cells) |item, *cell| cell.* = if (item) |value| (if (layout.logical == .structure) value.structure[index] else if (value.tagged_union.index == index) value.tagged_union.value.* else .missing) else .missing;
        children[index] = try column(allocator, child, cells);
        made += 1;
    }
    if (layout.logical == .structure) return structure(allocator, layout.value.struct_.fields, children, data);
    var variants = try structure(allocator, layout.value.struct_.fields[1].data_type.struct_.fields, children, data);
    defer variants.release();
    const tags = try allocator.alloc(u8, data.len);
    for (data, tags) |item, *tag| tag.* = if (item) |value| value.tagged_union.index else 0;
    var tag_array = try integers(a.UInt8Builder, allocator, tags);
    defer tag_array.release();
    return structure(allocator, layout.value.struct_.fields, &.{ tag_array, variants }, data);
}
fn collection(allocator: std.mem.Allocator, layout: *const Layout, data: []const ?v.Value) !a.ArrayRef {
    var count: usize = 0;
    for (data) |item| {
        const length: usize = if (layout.logical == .array) layout.logical.array.length else if (item) |value| (if (layout.logical == .list) value.list.len else value.map.len) else 0;
        count = std.math.add(usize, count, length) catch return error.ArrowShapeTooLarge;
        if (count > 65536) return error.ArrowShapeTooLarge;
    }
    const cells = try allocator.alloc(v.Cell, count);
    const keys: []?v.Value = if (layout.logical == .map) try allocator.alloc(?v.Value, count) else &.{};
    var index: usize = 0;
    for (data) |item| {
        if (item) |value| {
            switch (value) {
                .list, .array => |items| {
                    @memcpy(cells[index..][0..items.len], items);
                    index += items.len;
                },
                .map => |entries| for (entries) |entry| {
                    keys[index] = .{ .atom = entry.key };
                    cells[index] = entry.value;
                    index += 1;
                },
                else => unreachable,
            }
        } else if (layout.logical == .array) {
            @memset(cells[index..][0..layout.logical.array.length], .missing);
            index += layout.logical.array.length;
        }
    }
    var values_array = try column(allocator, layout.children[if (layout.logical == .map) @as(usize, 1) else 0], cells);
    defer values_array.release();
    if (layout.logical == .list) {
        var builder = try a.ListBuilder.init(allocator, data.len, layout.value.list.value_field);
        defer builder.deinit();
        for (data) |item| if (item) |value| try builder.appendLen(value.list.len) else try builder.appendNull();
        return builder.finish(values_array);
    }
    if (layout.logical == .array) {
        var builder = try a.FixedSizeListBuilder.init(allocator, layout.value.fixed_size_list.value_field, layout.logical.array.length);
        defer builder.deinit();
        for (data) |item| if (item != null) try builder.appendValid() else try builder.appendNull();
        return builder.finish(values_array);
    }
    var key_array = try payload(allocator, layout.children[0], keys);
    defer key_array.release();
    const map = layout.value.map;
    const valid = try allocator.alloc(?u8, count);
    @memset(valid, 1);
    var entries = try structure(allocator, &.{ map.key_field, map.item_field }, &.{ key_array, values_array }, valid);
    defer entries.release();
    var builder = try a.MapBuilder.init(allocator, data.len, map.key_field, map.item_field, false);
    defer builder.deinit();
    for (data) |item| if (item) |value| try builder.appendLen(value.map.len) else try builder.appendNull();
    return builder.finish(entries);
}
fn kind(cell: v.Cell, logical: t.Type) u8 {
    return switch (cell) {
        .value => @backingInt(std.meta.activeTag(logical)),
        .type_error => |actual| @backingInt(actual),
        else => 0,
    };
}
fn column(allocator: std.mem.Allocator, layout: *const Layout, cells: []const v.Cell) anyerror!a.ArrayRef {
    const states = try allocator.alloc(u8, cells.len);
    const kinds = try allocator.alloc(u8, cells.len);
    const data = try allocator.alloc(?v.Value, cells.len);
    var count: usize = 0;
    for (cells, 0..) |cell, i| {
        states[i] = @backingInt(std.meta.activeTag(cell));
        kinds[i] = kind(cell, layout.logical);
        data[i] = if (cell == .value) cell.value else null;
        if (cell == .conflict) count += cell.conflict.len;
    }
    const counters = try allocator.alloc(u64, count);
    const replicas = try allocator.alloc(u64, count);
    const alt_states = try allocator.alloc(u8, count);
    const alt_kinds = try allocator.alloc(u8, count);
    const alt_data = try allocator.alloc(?v.Value, count);
    var at: usize = 0;
    for (cells) |cell| if (cell == .conflict) {
        for (cell.conflict) |alt| {
            const alternative: v.Cell = switch (alt.value) {
                .null => .null,
                .type_error => |actual| .{ .type_error = actual },
                .value => |value| .{ .value = value },
            };
            counters[at] = alt.counter;
            replicas[at] = alt.replica;
            alt_states[at] = @backingInt(std.meta.activeTag(alternative));
            alt_kinds[at] = kind(alternative, layout.logical);
            alt_data[at] = if (alternative == .value) alternative.value else null;
            at += 1;
        }
    };
    var state_array = try integers(a.UInt8Builder, allocator, states);
    defer state_array.release();
    var kind_array = try integers(a.UInt8Builder, allocator, kinds);
    defer kind_array.release();
    var value_array = try payload(allocator, layout, data);
    defer value_array.release();
    var counter_array = try integers(a.UInt64Builder, allocator, counters);
    defer counter_array.release();
    var replica_array = try integers(a.UInt64Builder, allocator, replicas);
    defer replica_array.release();
    var alt_state_array = try integers(a.UInt8Builder, allocator, alt_states);
    defer alt_state_array.release();
    var alt_kind_array = try integers(a.UInt8Builder, allocator, alt_kinds);
    defer alt_kind_array.release();
    var alt_value_array = try payload(allocator, layout, alt_data);
    defer alt_value_array.release();
    const valid = try allocator.alloc(?u8, @max(count, cells.len));
    @memset(valid, 1);
    var alternatives = try structure(allocator, layout.alternatives.struct_.fields, &.{ counter_array, replica_array, alt_state_array, alt_kind_array, alt_value_array }, valid[0..count]);
    defer alternatives.release();
    var builder = try a.ListBuilder.init(allocator, cells.len, layout.list.list.value_field);
    defer builder.deinit();
    for (cells) |cell| try builder.appendLen(if (cell == .conflict) cell.conflict.len else 0);
    var list = try builder.finish(alternatives);
    defer list.release();
    return structure(allocator, layout.cell.struct_.fields, &.{ state_array, kind_array, value_array, list }, valid[0..cells.len]);
}
pub const Row = struct { cells: []const v.Cell };
pub const Evidence = struct { binding: [32]u8, plan: [32]u8, records: u64, sampled_bytes: u64, complete: bool };
pub const Messages = struct { schema: bool = true, batch: bool = true, end: bool = true, evidence: ?Evidence = null };
/// All output borrows `output`, and all Arrow allocations are confined to at
/// most working_bytes of caller workspace. Discard output on any error. Hosts
/// can concatenate schema/batch/end messages, emitting end only after complete.
pub fn encode(schema: t.Type, rows: []const Row, workspace: []u8, output: []u8) ![]const u8 {
    return messages(schema, rows, .{}, workspace, output);
}
pub fn messages(schema: t.Type, rows: []const Row, parts: Messages, workspace: []u8, output: []u8) ![]const u8 {
    return messagesInner(schema, rows, parts, workspace, output) catch |err| switch (err) {
        // This encoder has no external allocator or I/O: every allocation uses
        // the explicit fixed workspace. Do not conflate this with host OOM.
        error.OutOfMemory => error.ArrowWorkspaceExceeded,
        else => err,
    };
}
fn messagesInner(schema: t.Type, rows: []const Row, parts: Messages, workspace: []u8, output: []u8) ![]const u8 {
    try schema.validate(.{});
    if (schema != .structure or schema.structure.len > 128 or rows.len > max_rows) return error.ArrowShapeTooLarge;
    for (rows) |row| try (v.Cell{ .value = .{ .structure = row.cells } }).validate(.{ .name = "row", .type = schema }, .{});
    var fixed = std.heap.FixedBufferAllocator.init(workspace[0..@min(workspace.len, working_bytes)]);
    const allocator = fixed.allocator();
    const fields = try allocator.alloc(a.Field, schema.structure.len);
    const arrays = try allocator.alloc(a.ArrayRef, schema.structure.len);
    var count: usize = 0;
    defer for (arrays[0..count]) |*array| array.release();
    for (schema.structure, fields, 0..) |field, *physical, index| {
        const layout = try Layout.create(allocator, field.type);
        physical.* = .{ .name = field.name, .data_type = &layout.cell, .nullable = false };
        if (parts.batch) {
            const cells = try allocator.alloc(v.Cell, rows.len);
            for (rows, cells) |row, *cell| cell.* = row.cells[index];
            arrays[index] = try column(allocator, layout, cells);
            count += 1;
        }
    }
    var descriptor_buffer: [t.max_encoding_bytes]u8 = undefined;
    const descriptor = try schema.encode(&descriptor_buffer);
    const hex = try allocator.alloc(u8, descriptor.len * 2);
    const alphabet = "0123456789abcdef";
    for (descriptor, 0..) |byte, i| {
        hex[2 * i] = alphabet[byte >> 4];
        hex[2 * i + 1] = alphabet[byte & 15];
    }
    var metadata: [7]a.KeyValue = undefined;
    metadata[0] = .{ .key = "transit.definition", .value = definition };
    metadata[1] = .{ .key = "transit.logical_schema", .value = hex };
    var binding_hex: [64]u8 = undefined;
    var plan_hex: [64]u8 = undefined;
    var records: [20]u8 = undefined;
    var sampled: [20]u8 = undefined;
    if (parts.evidence) |evidence| {
        binding_hex = std.fmt.bytesToHex(evidence.binding, .lower);
        plan_hex = std.fmt.bytesToHex(evidence.plan, .lower);
        metadata[2] = .{ .key = "transit.binding", .value = &binding_hex };
        metadata[3] = .{ .key = "transit.plan", .value = &plan_hex };
        metadata[4] = .{ .key = "transit.discovery_records", .value = try std.fmt.bufPrint(&records, "{d}", .{evidence.records}) };
        metadata[5] = .{ .key = "transit.discovery_bytes", .value = try std.fmt.bufPrint(&sampled, "{d}", .{evidence.sampled_bytes}) };
        metadata[6] = .{ .key = "transit.discovery_complete", .value = if (evidence.complete) "true" else "false" };
    }
    const physical: a.Schema = .{ .fields = fields, .metadata = metadata[0..if (parts.evidence != null) @as(usize, 7) else 2] };
    var buffer: std.Io.Writer = .fixed(output[0..@min(output.len, segment_bytes)]);
    var writer = a.IpcStreamWriter(*std.Io.Writer).init(allocator, &buffer);
    defer writer.deinit();
    if (parts.schema) try writer.writeSchema(physical);
    if (parts.batch) {
        var batch = try a.RecordBatch.initBorrowed(allocator, physical, arrays);
        defer batch.deinit();
        try writer.writeRecordBatch(batch);
    }
    if (parts.end) try writer.writeEnd();
    return buffer.buffered();
}

test "logical Arrow exports exact decimal and recursive states within independent budgets" {
    const allocator = std.testing.allocator;
    const workspace = try allocator.alloc(u8, working_bytes);
    defer allocator.free(workspace);
    var output: [segment_bytes]u8 = undefined;
    const schema: t.Type = .{ .structure = &.{ .{ .name = "n", .type = .{ .decimal = .{ .precision = 38, .scale = 2 } } }, .{ .name = "items", .type = .{ .list = .{ .type = &.uint128, .nullable = true } }, .optional = true } } };
    const rows = [_]Row{ .{ .cells = &.{ .{ .value = .{ .atom = .{ .decimal = 12345 } } }, .{ .value = .{ .list = &.{ .null, .{ .value = .{ .atom = .{ .unsigned = std.math.maxInt(u128) } } } } } } } }, .{ .cells = &.{ .{ .value = .{ .atom = .{ .decimal = -1 } } }, .missing } } };
    const bytes = try encode(schema, &rows, workspace, &output);
    var input: std.Io.Reader = .fixed(bytes);
    var reader = a.IpcStreamReader(*std.Io.Reader).init(allocator, &input);
    defer reader.deinit();
    const exported = try reader.readSchema();
    try std.testing.expectEqualStrings(definition, exported.metadata.?[0].value);
    var batch = (try reader.nextRecordBatch()).?;
    defer batch.deinit();
    try std.testing.expectEqual(@as(usize, 2), batch.numRows());
    try std.testing.expect((try reader.nextRecordBatch()) == null);
    try std.testing.expectError(error.ArrowWorkspaceExceeded, encode(schema, &rows, workspace[0..1], &output));
    try std.testing.expectError(error.WriteFailed, encode(schema, &rows, workspace, output[0..1]));
}
