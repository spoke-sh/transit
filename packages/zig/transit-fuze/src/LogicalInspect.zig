//! Owned decoding of complete canonical logical Arrow segments. Exact schema
//! bytes are checked before the IPC reader interprets untrusted type metadata.
const std = @import("std");
const f = @import("root.zig");
const t = f.Types;
const v = t.Values;
const a = f.arrow;
const ipc = f.LogicalArrow;
pub const Batch = struct {
    descriptor: t.Decoded,
    rows: []const ipc.Row,
    pub fn deinit(self: *Batch) void {
        self.descriptor.deinit();
        self.* = undefined;
    }
};

/// Read only the fixed Arrow Message -> Schema -> two metadata entries. No
/// physical field tree is traversed before the canonical schema comparison.
/// Slots follow the pinned upstream Message.fbs, Schema.fbs and KeyValue tables.
const Metadata = struct {
    bytes: []const u8,
    fn slice(self: Metadata, at: usize, count: usize) ![]const u8 {
        if (at > self.bytes.len or count > self.bytes.len - at) return error.InvalidArrowResult;
        return self.bytes[at..][0..count];
    }
    fn integer(self: Metadata, comptime T: type, at: usize) !T {
        return std.mem.readInt(T, (try self.slice(at, @sizeOf(T)))[0..@sizeOf(T)], .little);
    }
    fn indirect(self: Metadata, at: usize) !usize {
        const offset = try self.integer(u32, at);
        if (offset == 0 or offset > self.bytes.len - at) return error.InvalidArrowResult;
        return at + offset;
    }
    fn field(self: Metadata, table: usize, slot: usize) !usize {
        const delta = try self.integer(i32, table);
        const location = std.math.cast(usize, @as(i64, @intCast(table)) - @as(i64, delta)) orelse return error.InvalidArrowResult;
        const size = try self.integer(u16, location);
        const object_bytes = try self.integer(u16, location + 2);
        if (size < 4 or size % 2 != 0 or object_bytes < 4 or 4 + slot * 2 + 2 > size) return error.InvalidArrowResult;
        _ = try self.slice(location, size);
        _ = try self.slice(table, object_bytes);
        const offset = try self.integer(u16, location + 4 + slot * 2);
        if (offset < 4 or offset >= object_bytes) return error.InvalidArrowResult;
        return table + offset;
    }
    fn string(self: Metadata, offset: usize) ![]const u8 {
        const at = try self.indirect(offset);
        const size = try self.integer(u32, at);
        const bytes = try self.slice(at + 4, size);
        if ((try self.slice(at + 4 + bytes.len, 1))[0] != 0) return error.InvalidArrowResult;
        return bytes;
    }
    fn descriptor(bytes: []const u8) ![]const u8 {
        if (bytes.len < 8 or bytes.len > ipc.segment_bytes) return error.InvalidArrowResult;
        if (std.mem.readInt(u32, bytes[0..4], .little) != 0xffffffff) return error.InvalidArrowResult;
        const length = std.mem.readInt(u32, bytes[4..8], .little);
        if (length == 0 or length > bytes.len - 8) return error.InvalidArrowResult;
        const view: Metadata = .{ .bytes = bytes[8..][0..length] };
        const message = try view.indirect(0);
        if (try view.integer(u8, try view.field(message, 1)) != 1) return error.InvalidArrowResult;
        const schema_table = try view.indirect(try view.field(message, 2));
        const entries = try view.indirect(try view.field(schema_table, 2));
        if (try view.integer(u32, entries) != 2) return error.InvalidArrowResult;
        var descriptor_hex: ?[]const u8 = null;
        inline for (.{ "transit.definition", "transit.logical_schema" }, 0..) |name, index| {
            const pair = try view.indirect(entries + 4 + index * 4);
            if (!std.mem.eql(u8, name, try view.string(try view.field(pair, 0)))) return error.InvalidArrowResult;
            const metadata_value = try view.string(try view.field(pair, 1));
            if (index == 0) {
                if (!std.mem.eql(u8, metadata_value, ipc.definition)) return error.InvalidArrowResult;
            } else descriptor_hex = metadata_value;
        }
        return descriptor_hex.?;
    }
};

pub const Inferred = struct {
    descriptor: t.Decoded,
    rows: u8,
    pub fn deinit(self: *Inferred) void {
        self.descriptor.deinit();
        self.* = undefined;
    }
};
/// Infer the embedded logical descriptor of one plain canonical segment. The
/// result owns its schema; cells still require decode/segment validation. Extra
/// metadata, foreign definitions and noncanonical physical schemas reject.
pub fn infer(allocator: std.mem.Allocator, bytes: []const u8, workspace: []u8) !Inferred {
    const hex = try Metadata.descriptor(bytes);
    if (hex.len == 0 or hex.len % 2 != 0 or hex.len / 2 > t.max_encoding_bytes) return error.InvalidArrowResult;
    var encoded: [t.max_encoding_bytes]u8 = undefined;
    const logical = std.fmt.hexToBytes(&encoded, hex) catch return error.InvalidArrowResult;
    var descriptor = try t.decode(allocator, logical);
    errdefer descriptor.deinit();
    if (descriptor.type != .structure or descriptor.type.structure.len > 128) return error.InvalidArrowResult;
    var prefix: [ipc.segment_bytes]u8 = undefined;
    const canonical = try ipc.messages(descriptor.type, &.{}, .{ .schema = true, .batch = false, .end = false }, workspace, &prefix);
    if (!std.mem.startsWith(u8, bytes, canonical)) return error.InvalidArrowResult;
    if (bytes.len < 8 or !std.mem.eql(u8, bytes[bytes.len - 8 ..], &.{ 255, 255, 255, 255, 0, 0, 0, 0 })) return error.InvalidArrowResult;
    var fixed: std.heap.FixedBufferAllocator = .init(workspace[0..@min(workspace.len, ipc.working_bytes)]);
    var input: std.Io.Reader = .fixed(bytes);
    var reader = a.IpcStreamReader(*std.Io.Reader).init(fixed.allocator(), &input);
    defer reader.deinit();
    _ = try reader.readSchema();
    var batch = (try reader.nextRecordBatch()) orelse return error.InvalidArrowResult;
    defer batch.deinit();
    if (batch.numRows() > ipc.max_rows) return error.InvalidArrowResult;
    return .{ .descriptor = descriptor, .rows = @intCast(batch.numRows()) };
}
/// Fully validate a self-describing segment before durable result sealing.
/// The schema fingerprint supplies consistency evidence, never authorization.
pub fn segment(allocator: std.mem.Allocator, bytes: []const u8, expected_rows: u8, workspace: []u8) ![32]u8 {
    var inferred = try infer(allocator, bytes, workspace);
    defer inferred.deinit();
    if (inferred.rows != expected_rows) return error.InvalidArrowResult;
    var batch = try decode(allocator, inferred.descriptor.type, bytes, expected_rows, workspace);
    defer batch.deinit();
    return inferred.descriptor.type.fingerprint();
}
const Budget = struct {
    allocator: std.mem.Allocator,
    limits: t.Limits = .{},
    children: usize = 1, // the logical root row cell
    bytes: usize = 0,
    fn child(self: *Budget, depth: usize) !void {
        if (depth >= self.limits.depth or self.children == self.limits.children) return error.ValueBudgetExceeded;
        self.children += 1;
    }
    fn count(self: *const Budget, size: usize) !void {
        if (size > self.limits.children - self.children) return error.ValueBudgetExceeded;
    }
    fn copy(self: *Budget, bytes: []const u8) ![]const u8 {
        if (bytes.len > self.limits.value_bytes - self.bytes) return error.ValueBudgetExceeded;
        self.bytes += bytes.len;
        return self.allocator.dupe(u8, bytes);
    }
};
fn primitive(comptime T: type, data: *const a.ArrayData, index: usize) !T {
    if (data.isNull(index)) return error.InvalidArrowResult;
    return (a.PrimitiveArray(T){ .data = data }).value(index);
}
fn field(data: *const a.ArrayData, index: usize) !a.ArrayRef {
    return (a.StructArray{ .data = data }).field(index);
}
fn atom(expected: t.Type, data: *const a.ArrayData, index: usize, budget: *Budget) !t.Semantics.Atom {
    if (data.isNull(index)) return error.InvalidArrowResult;
    return switch (expected) {
        .int8 => .{ .signed = try primitive(i8, data, index) },
        .int16 => .{ .signed = try primitive(i16, data, index) },
        .int32 => .{ .signed = try primitive(i32, data, index) },
        .int64 => .{ .signed = try primitive(i64, data, index) },
        .uint8 => .{ .unsigned = try primitive(u8, data, index) },
        .uint16 => .{ .unsigned = try primitive(u16, data, index) },
        .uint32 => .{ .unsigned = try primitive(u32, data, index) },
        .uint64 => .{ .unsigned = try primitive(u64, data, index) },
        .int128, .uint128, .uuid => blk: {
            const bytes = try (a.FixedSizeBinaryArray{ .data = data }).value(index);
            if (bytes.len != 16) return error.InvalidArrowResult;
            break :blk switch (expected) {
                .int128 => .{ .signed = std.mem.readInt(i128, bytes[0..16], .little) },
                .uint128 => .{ .unsigned = std.mem.readInt(u128, bytes[0..16], .little) },
                .uuid => .{ .uuid = bytes[0..16].* },
                else => unreachable,
            };
        },
        .float32 => .{ .float = try primitive(f32, data, index) },
        .float64 => .{ .float = try primitive(f64, data, index) },
        .decimal => .{ .decimal = try primitive(i128, data, index) },
        .boolean => .{ .boolean = try (a.BooleanArray{ .data = data }).value(index) },
        .utf8 => .{ .bytes = try budget.copy(try (a.StringArray{ .data = data }).value(index)) },
        .binary => .{ .bytes = try budget.copy(try (a.BinaryArray{ .data = data }).value(index)) },
        .date => .{ .date = try primitive(i32, data, index) },
        .time => .{ .time = std.math.cast(u64, try primitive(i64, data, index)) orelse return error.InvalidArrowResult },
        .timestamp => .{ .timestamp = try primitive(i64, data, index) },
        .interval => blk: {
            const bits: u128 = @bitCast(try primitive(i128, data, index));
            break :blk .{ .interval = .{ .months = @bitCast(@as(u32, @truncate(bits))), .days = @bitCast(@as(u32, @truncate(bits >> 32))), .nanos = @bitCast(@as(u64, @truncate(bits >> 64))) } };
        },
        else => error.InvalidArrowResult,
    };
}
fn value(expected: t.Type, data: *const a.ArrayData, index: usize, depth: usize, budget: *Budget) anyerror!v.Value {
    if (data.isNull(index)) return error.InvalidArrowResult;
    return switch (expected) {
        .structure => |fields| blk: {
            try budget.count(fields.len);
            const cells = try budget.allocator.alloc(v.Cell, fields.len);
            for (fields, cells, 0..) |logical, *out, i| {
                var column = try field(data, i);
                defer column.release();
                out.* = try cell(logical.type, column.data(), index, depth + 1, budget, false);
            }
            break :blk .{ .structure = cells };
        },
        .list, .array => blk: {
            var items = if (expected == .list) try (a.ListArray{ .data = data }).value(index) else try (a.FixedSizeListArray{ .data = data }).value(index);
            defer items.release();
            const length = items.data().length;
            try budget.count(length);
            if (expected == .array and length != expected.array.length) return error.InvalidArrowResult;
            const cells = try budget.allocator.alloc(v.Cell, length);
            const element = if (expected == .list) expected.list else expected.array.element;
            for (cells, 0..) |*out, i| out.* = try cell(element.type.*, items.data(), i, depth + 1, budget, false);
            break :blk if (expected == .list) .{ .list = cells } else .{ .array = cells };
        },
        .map => |map| blk: {
            var items = try (a.MapArray{ .data = data }).value(index);
            defer items.release();
            const length = items.data().length;
            if (length > (budget.limits.children - budget.children) / 2) return error.ValueBudgetExceeded;
            const entries = try budget.allocator.alloc(v.Entry, length);
            var keys = try field(items.data(), 0);
            defer keys.release();
            var values = try field(items.data(), 1);
            defer values.release();
            for (entries, 0..) |*entry, i| {
                if (items.data().isNull(i)) return error.InvalidArrowResult;
                try budget.child(depth + 1);
                entry.* = .{ .key = try atom(map.key.*, keys.data(), i, budget), .value = try cell(map.value.type.*, values.data(), i, depth + 1, budget, false) };
            }
            break :blk .{ .map = entries };
        },
        .tagged_union => |fields| blk: {
            var tags = try field(data, 0);
            defer tags.release();
            const tag = try primitive(u8, tags.data(), index);
            if (tag >= fields.len) return error.InvalidArrowResult;
            var variants = try field(data, 1);
            defer variants.release();
            if (variants.data().isNull(index)) return error.InvalidArrowResult;
            const selected = try budget.allocator.create(v.Cell);
            for (fields, 0..) |logical, i| {
                var column = try field(variants.data(), i);
                defer column.release();
                const result = try cell(logical.type, column.data(), index, depth + 1, budget, i != tag);
                if (i == tag) selected.* = result;
            }
            break :blk .{ .tagged_union = .{ .index = tag, .value = selected } };
        },
        .json => .{ .json = try budget.copy(try (a.StringArray{ .data = data }).value(index)) },
        else => .{ .atom = try atom(expected, data, index, budget) },
    };
}
fn ordinary(expected: t.Type, state: t.State, kind: u8, data: *const a.ArrayData, index: usize, depth: usize, budget: *Budget) !v.Cell {
    if (state != .value and !data.isNull(index)) return error.InvalidArrowResult;
    return switch (state) {
        .missing => if (kind == 0) .missing else error.InvalidArrowResult,
        .null => if (kind == 0) .null else error.InvalidArrowResult,
        .type_error => .{ .type_error = std.enums.fromInt(t.Kind, kind) orelse return error.InvalidArrowResult },
        .value => if (kind == @backingInt(std.meta.activeTag(expected))) .{ .value = try value(expected, data, index, depth, budget) } else error.InvalidArrowResult,
        .conflict => error.InvalidArrowResult,
    };
}
fn cell(expected: t.Type, data: *const a.ArrayData, index: usize, depth: usize, budget: *Budget, inactive: bool) anyerror!v.Cell {
    if (data.isNull(index)) return error.InvalidArrowResult;
    var states = try field(data, 0);
    defer states.release();
    var kinds = try field(data, 1);
    defer kinds.release();
    var content = try field(data, 2);
    defer content.release();
    var lists = try field(data, 3);
    defer lists.release();
    if (lists.data().isNull(index)) return error.InvalidArrowResult;
    const state = std.enums.fromInt(t.State, try primitive(u8, states.data(), index)) orelse return error.InvalidArrowResult;
    const kind = try primitive(u8, kinds.data(), index);
    if (inactive and state != .missing) return error.InvalidArrowResult;
    if (!inactive) try budget.child(depth);
    var entries = try (a.ListArray{ .data = lists.data() }).value(index);
    defer entries.release();
    const count = entries.data().length;
    if (state != .conflict) {
        if (count != 0) return error.InvalidArrowResult;
        return ordinary(expected, state, kind, content.data(), index, depth, budget);
    }
    if (kind != 0 or !content.data().isNull(index) or count < 2 or count > t.Query.max_conflicts) return error.InvalidArrowResult;
    try budget.count(count);
    const alternatives = try budget.allocator.alloc(v.Alternative, count);
    var counters = try field(entries.data(), 0);
    defer counters.release();
    var replicas = try field(entries.data(), 1);
    defer replicas.release();
    var alt_states = try field(entries.data(), 2);
    defer alt_states.release();
    var alt_kinds = try field(entries.data(), 3);
    defer alt_kinds.release();
    var values = try field(entries.data(), 4);
    defer values.release();
    for (alternatives, 0..) |*out, i| {
        if (entries.data().isNull(i)) return error.InvalidArrowResult;
        try budget.child(depth);
        const alt_state = std.enums.fromInt(t.State, try primitive(u8, alt_states.data(), i)) orelse return error.InvalidArrowResult;
        const alt = try ordinary(expected, alt_state, try primitive(u8, alt_kinds.data(), i), values.data(), i, depth, budget);
        out.* = .{ .counter = try primitive(u64, counters.data(), i), .replica = try primitive(u64, replicas.data(), i), .value = switch (alt) {
            .null => .null,
            .type_error => |actual| .{ .type_error = actual },
            .value => |payload| .{ .value = payload },
            else => return error.InvalidArrowResult,
        } };
    }
    return .{ .conflict = alternatives };
}
/// Accept exactly one complete plain segment emitted by LogicalArrow.encode.
/// Workspace must not alias input; result descriptors/values own all their bytes.
/// No publication, source-cut or authorization evidence is inferred from IPC.
pub fn decode(allocator: std.mem.Allocator, schema: t.Type, bytes: []const u8, expected_rows: u8, workspace: []u8) !Batch {
    try schema.validate(.{});
    if (schema != .structure or schema.structure.len > 128 or expected_rows > ipc.max_rows or bytes.len > ipc.segment_bytes or bytes.len < 8 or !std.mem.eql(u8, bytes[bytes.len - 8 ..], &.{ 255, 255, 255, 255, 0, 0, 0, 0 })) return error.InvalidArrowResult;
    var descriptor = try schema.clone(allocator);
    errdefer descriptor.deinit();
    var prefix: [ipc.segment_bytes]u8 = undefined;
    const expected = try ipc.messages(descriptor.type, &.{}, .{ .schema = true, .batch = false, .end = false }, workspace, &prefix);
    if (!std.mem.startsWith(u8, bytes, expected)) return error.InvalidArrowResult;
    var fixed: std.heap.FixedBufferAllocator = .init(workspace[0..@min(workspace.len, ipc.working_bytes)]);
    var input: std.Io.Reader = .fixed(bytes);
    var reader = a.IpcStreamReader(*std.Io.Reader).init(fixed.allocator(), &input);
    defer reader.deinit();
    _ = try reader.readSchema();
    var batch = (try reader.nextRecordBatch()) orelse return error.InvalidArrowResult;
    defer batch.deinit();
    if (batch.numRows() != expected_rows or batch.numColumns() != schema.structure.len) return error.InvalidArrowResult;
    for (0..batch.numColumns()) |index| try batch.column(index).data().validateFull();
    const owned = descriptor.arena.allocator();
    const rows = try owned.alloc(ipc.Row, expected_rows);
    for (rows, 0..) |*row, row_index| {
        var budget: Budget = .{ .allocator = owned };
        try budget.count(descriptor.type.structure.len);
        const cells = try owned.alloc(v.Cell, descriptor.type.structure.len);
        for (descriptor.type.structure, cells, 0..) |logical, *out, column| out.* = try cell(logical.type, batch.column(column).data(), row_index, 1, &budget, false);
        try (v.Cell{ .value = .{ .structure = cells } }).validate(.{ .name = "row", .type = descriptor.type }, .{});
        row.* = .{ .cells = cells };
    }
    if (try reader.nextRecordBatch()) |extra| {
        var unexpected = extra;
        unexpected.deinit();
        return error.InvalidArrowResult;
    }
    if (input.bufferedLen() != 0) return error.InvalidArrowResult;
    return .{ .descriptor = descriptor, .rows = rows };
}
