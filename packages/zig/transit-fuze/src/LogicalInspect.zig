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
        .type_error => .{ .type_error = std.enums.fromInt(t.Tag, kind) orelse return error.InvalidArrowResult },
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
