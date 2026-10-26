//! Canonical aligned Arrow value buffers inside qualified plain TCP1 pages.
//! State/detail streams retain the complete cell; Arrow validity alone does not.
const std = @import("std");
const t = @import("Types.zig");
const s = @import("TableSchema.zig");
const a = @import("zarrow");
pub const alignment = 64;
test {
    _ = @import("plain_column_buffers_test.zig");
}

pub fn supports(kind: t.Type) bool {
    return switch (kind) {
        .int64, .uint64, .float64, .boolean, .utf8, .binary, .json => true,
        else => false,
    };
}
fn variable(kind: t.Type) bool {
    return kind == .utf8 or kind == .binary or kind == .json;
}
fn valueBytes(value: t.Values.Value) []const u8 {
    return if (value == .json) value.json else value.atom.bytes;
}
fn round(size: usize) !usize {
    return (std.math.add(usize, size, alignment - 1) catch return error.InvalidColumnPage) & ~@as(usize, alignment - 1);
}
fn pad(writer: *std.Io.Writer) !void {
    const zeros: [alignment]u8 = @splat(0);
    const used = writer.buffered().len;
    try writer.writeAll(zeros[0 .. try round(used) - used]);
}
fn bit(bytes: []const u8, i: usize) bool {
    return bytes[i / 8] & (@as(u8, 1) << @intCast(i % 8)) != 0;
}
fn bitmap(writer: *std.Io.Writer, cells: []const t.Values.Cell, values: bool) !void {
    var index: usize = 0;
    while (index < cells.len) : (index += 8) {
        var byte: u8 = 0;
        for (cells[index..@min(index + 8, cells.len)], 0..) |cell, shift| {
            if (cell == .value and (!values or cell.value.atom.boolean)) byte |= @as(u8, 1) << @intCast(shift);
        }
        try writer.writeByte(byte);
    }
}

/// Writer starts at the containing page's byte zero. Every buffer and its final
/// padding is aligned relative to that page; the caller owns physical alignment.
pub fn encode(kind: t.Type, cells: []const t.Values.Cell, writer: *std.Io.Writer) !void {
    std.debug.assert(supports(kind));
    try pad(writer);
    try bitmap(writer, cells, false);
    try pad(writer);
    if (variable(kind)) {
        var offset: u32 = 0;
        try writer.writeInt(u32, 0, .little);
        for (cells) |cell| {
            if (cell == .value) offset = std.math.add(u32, offset, std.math.cast(u32, valueBytes(cell.value).len) orelse return error.ColumnPageTooLarge) catch return error.ColumnPageTooLarge;
            if (offset > std.math.maxInt(i32)) return error.ColumnPageTooLarge;
            try writer.writeInt(u32, offset, .little);
        }
        try pad(writer);
        for (cells) |cell| if (cell == .value) try writer.writeAll(valueBytes(cell.value));
    } else if (kind == .boolean) {
        try bitmap(writer, cells, true);
    } else for (cells) |cell| {
        const word: u64 = if (cell != .value) 0 else switch (kind) {
            .int64 => @bitCast(@as(i64, @intCast(cell.value.atom.signed))),
            .uint64 => @intCast(cell.value.atom.unsigned),
            .float64 => @bitCast(@as(f64, @floatCast(cell.value.atom.float))),
            else => unreachable,
        };
        try writer.writeInt(u64, word, .little);
    }
    try pad(writer);
}

pub const View = struct {
    kind: t.Type,
    tags: []const u8,
    validity: []const u8,
    offsets: ?[]const u8,
    values: []const u8,
    null_count: usize,

    pub fn value(self: View, row: usize) t.Values.Value {
        std.debug.assert(row < self.tags.len and self.tags[row] == 0);
        const atom: t.Values.Atom = if (self.offsets) |offsets| blk: {
            const start = std.mem.readInt(u32, offsets[row * 4 ..][0..4], .little);
            const end = std.mem.readInt(u32, offsets[(row + 1) * 4 ..][0..4], .little);
            if (self.kind == .json) return .{ .json = self.values[start..end] };
            break :blk .{ .bytes = self.values[start..end] };
        } else switch (self.kind) {
            .boolean => .{ .boolean = bit(self.values, row) },
            .int64 => .{ .signed = std.mem.readInt(i64, self.values[row * 8 ..][0..8], .little) },
            .uint64 => .{ .unsigned = std.mem.readInt(u64, self.values[row * 8 ..][0..8], .little) },
            .float64 => .{ .float = @as(f64, @bitCast(std.mem.readInt(u64, self.values[row * 8 ..][0..8], .little))) },
            else => unreachable,
        };
        return .{ .atom = atom };
    }

    /// Borrow just the nullable value child. All non-value states appear null
    /// here; the enclosing owner must retain tags and error/conflict details.
    /// Both the buffer directory and page must outlive every derived Arrow view.
    /// SharedBuffer.retain does not extend this borrowed page's lifetime.
    pub fn arrowValues(self: View, buffers: *[3]a.SharedBuffer) !a.ArrayData {
        if (@import("builtin").cpu.arch.endian() != .little) return error.UnsupportedArrowByteOrder;
        const slices = [_][]const u8{ self.validity, self.offsets orelse self.values, self.values };
        const count: usize = if (self.offsets != null) 3 else 2;
        for (slices[0..count], buffers[0..count]) |bytes, *buffer| {
            if (!std.mem.isAligned(@intFromPtr(bytes.ptr), alignment)) return error.UnalignedArrowBuffer;
            buffer.* = .fromSlice(bytes);
        }
        const result: a.ArrayData = .{
            .data_type = switch (self.kind) {
                .int64 => .{ .int64 = {} },
                .uint64 => .{ .uint64 = {} },
                .float64 => .{ .double = {} },
                .boolean => .{ .bool = {} },
                .utf8, .json => .{ .string = {} },
                .binary => .{ .binary = {} },
                else => unreachable,
            },
            .length = self.tags.len,
            .null_count = self.null_count,
            .buffers = buffers[0..count],
        };
        try result.validateFull();
        return result;
    }
};

fn take(bytes: []const u8, offset: *usize, length: usize) ![]const u8 {
    const end = std.math.add(usize, offset.*, length) catch return error.InvalidColumnPage;
    const padded = try round(end);
    if (padded > bytes.len) return error.InvalidColumnPage;
    if (!std.mem.allEqual(u8, bytes[end..padded], 0)) return error.InvalidColumnPage;
    const result = bytes[offset.*..end];
    offset.* = padded;
    return result;
}
/// Validates canonical bitmaps, offsets, unused lanes, padding and every scalar,
/// including unselected values. No allocation or row materialization is needed.
pub fn read(column: s.Column, bytes: []const u8, start: usize, tags: []const u8) !View {
    if (!supports(column.type) or column.encoding != .plain or start > bytes.len or tags.len > 65536) return error.InvalidColumnPage;
    var offset = start;
    _ = try take(bytes, &offset, 0);
    const validity = try take(bytes, &offset, (tags.len + 7) / 8);
    var null_count: usize = 0;
    for (tags, 0..) |tag, i| {
        if (tag > 4 or bit(validity, i) != (tag == 0)) return error.InvalidColumnPage;
        if (tag != 0) null_count += 1;
    }
    if (tags.len % 8 != 0 and validity[validity.len - 1] >> @as(u3, @intCast(tags.len % 8)) != 0) return error.InvalidColumnPage;
    const offsets = if (variable(column.type)) try take(bytes, &offset, (tags.len + 1) * 4) else null;
    var length: usize = if (column.type == .boolean) (tags.len + 7) / 8 else tags.len * 8;
    if (offsets) |indices| {
        var previous: u32 = 0;
        if (std.mem.readInt(u32, indices[0..4], .little) != 0) return error.InvalidColumnPage;
        for (tags, 0..) |tag, i| {
            const next = std.mem.readInt(u32, indices[(i + 1) * 4 ..][0..4], .little);
            if (next < previous or next > std.math.maxInt(i32) or (tag != 0 and next != previous)) return error.InvalidColumnPage;
            previous = next;
        }
        length = previous;
    }
    const values = try take(bytes, &offset, length);
    if (offset != bytes.len) return error.InvalidColumnPage;
    if (column.type == .boolean and tags.len % 8 != 0 and values[values.len - 1] >> @as(u3, @intCast(tags.len % 8)) != 0) return error.InvalidColumnPage;
    const result: View = .{ .kind = column.type, .tags = tags, .validity = validity, .offsets = offsets, .values = values, .null_count = null_count };
    for (tags, 0..) |tag, i| {
        if (tag == 0) {
            try (t.Values.Cell{ .value = result.value(i) }).validate(column.field(), .{});
        } else if (column.type == .boolean) {
            if (bit(values, i)) return error.InvalidColumnPage;
        } else if (offsets == null and !std.mem.allEqual(u8, values[i * 8 ..][0..8], 0)) return error.InvalidColumnPage;
    }
    return result;
}
