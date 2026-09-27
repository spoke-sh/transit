//! Canonical bounded Document encoding; never serializes native struct padding.
const std = @import("std");
const m = @import("Model.zig");
pub const Writer = struct {
    bytes: []u8,
    offset: usize = 0,
    pub fn write(self: *Writer, bytes: []const u8) !void {
        if (bytes.len > self.bytes.len - self.offset) return error.DocumentEncodingCapacity;
        @memcpy(self.bytes[self.offset..][0..bytes.len], bytes);
        self.offset += bytes.len;
    }
    pub fn int(self: *Writer, comptime T: type, v: T) !void {
        var bytes: [@sizeOf(T)]u8 = undefined;
        std.mem.writeInt(T, &bytes, v, .little);
        try self.write(&bytes);
    }
    pub fn dot(self: *Writer, v: m.Dot) !void {
        try self.int(u64, v.counter);
        try self.int(u64, v.replica);
    }
    pub fn string(self: *Writer, v: []const u8) !void {
        try self.int(u8, @intCast(v.len));
        try self.write(v);
    }
    pub fn observed(self: *Writer, v: m.Observed) !void {
        try self.int(u8, v.len);
        for (v.slice()) |d| try self.dot(d);
    }
    pub fn scalar(self: *Writer, v: m.Scalar) !void {
        try v.validate();
        try self.int(u8, @backingInt(v));
        switch (v) {
            .boolean => |b| try self.int(u8, @intFromBool(b)),
            .signed => |i| try self.int(i64, i),
            .unsigned => |i| try self.int(u64, i),
            .float => |f| try self.int(u64, @bitCast(f)),
            .string, .binary => |b| try self.string(b.slice()),
            .character => |c| try self.int(u32, c),
            else => {},
        }
    }
};
pub const Reader = struct {
    bytes: []const u8,
    offset: usize = 0,
    pub fn read(self: *Reader, length: usize) ![]const u8 {
        if (length > self.bytes.len - self.offset) return error.InvalidDocumentEncoding;
        const out = self.bytes[self.offset..][0..length];
        self.offset += length;
        return out;
    }
    pub fn int(self: *Reader, comptime T: type) !T {
        return std.mem.readInt(T, (try self.read(@sizeOf(T)))[0..@sizeOf(T)], .little);
    }
    pub fn dot(self: *Reader) !m.Dot {
        return .{ .counter = try self.int(u64), .replica = try self.int(u64) };
    }
    pub fn string(self: *Reader) ![]const u8 {
        return self.read(try self.int(u8));
    }
    pub fn observed(self: *Reader) !m.Observed {
        var v: m.Observed = .{ .len = try self.int(u8) };
        if (v.len > m.max_conflicts) return error.InvalidDocumentEncoding;
        for (v.dots[0..v.len]) |*d| d.* = try self.dot();
        return v;
    }
    pub fn scalar(self: *Reader) !m.Scalar {
        const tag = std.enums.fromInt(std.meta.Tag(m.Scalar), try self.int(u8)) orelse return error.InvalidDocumentEncoding;
        const v: m.Scalar = switch (tag) {
            .null_value => .null_value,
            .boolean => .{ .boolean = switch (try self.int(u8)) {
                0 => false,
                1 => true,
                else => return error.InvalidDocumentEncoding,
            } },
            .signed => .{ .signed = try self.int(i64) },
            .unsigned => .{ .unsigned = try self.int(u64) },
            .float => .{ .float = @bitCast(try self.int(u64)) },
            .string => .{ .string = try m.Bytes.init(try self.string()) },
            .binary => .{ .binary = try m.Bytes.init(try self.string()) },
            .map => .map,
            .list => .list,
            .text => .text,
            .character => .{ .character = try self.int(u32) },
        };
        try v.validate();
        return v;
    }
    pub fn finish(self: Reader) !void {
        if (self.offset != self.bytes.len) return error.InvalidDocumentEncoding;
    }
};
pub fn encode(change: m.Change, buffer: []u8) ![]const u8 {
    try change.validate();
    var w: Writer = .{ .bytes = buffer[0..@min(buffer.len, m.max_change_bytes)] };
    try w.write("SDC1");
    try w.int(u64, change.document);
    try w.int(u64, change.epoch);
    try w.int(u32, change.type_revision);
    try w.int(u64, change.replica);
    try w.int(u64, change.previous);
    try w.int(u64, change.first);
    try w.int(u8, change.len);
    for (change.operations[0..change.len]) |op| {
        try w.int(u8, @backingInt(op));
        switch (op) {
            inline else => |v| {
                try w.dot(v.object);
                if (@hasField(@TypeOf(v), "field")) try w.string(v.field.slice());
                if (@hasField(@TypeOf(v), "element")) try w.dot(v.element);
                if (@hasField(@TypeOf(v), "after")) try w.dot(v.after);
                if (@hasField(@TypeOf(v), "observed")) try w.observed(v.observed);
                if (@hasField(@TypeOf(v), "value")) try w.scalar(v.value);
            },
        }
    }
    return w.bytes[0..w.offset];
}
pub fn decode(bytes: []const u8) !m.Change {
    if (bytes.len > m.max_change_bytes) return error.InvalidDocumentEncoding;
    var r: Reader = .{ .bytes = bytes };
    if (!std.mem.eql(u8, try r.read(4), "SDC1")) return error.InvalidDocumentEncoding;
    var change: m.Change = .{ .document = try r.int(u64), .epoch = try r.int(u64), .type_revision = try r.int(u32), .replica = try r.int(u64), .previous = try r.int(u64), .first = try r.int(u64), .len = try r.int(u8) };
    if (change.len > m.max_operations) return error.InvalidDocumentEncoding;
    for (change.operations[0..change.len]) |*op| {
        const tag = std.enums.fromInt(std.meta.Tag(m.Operation), try r.int(u8)) orelse return error.InvalidDocumentEncoding;
        const object = try r.dot();
        op.* = switch (tag) {
            .assign => .{ .assign = .{ .object = object, .field = try m.Name.init(try r.string()), .observed = try r.observed(), .value = try r.scalar() } },
            .remove => .{ .remove = .{ .object = object, .field = try m.Name.init(try r.string()), .observed = try r.observed() } },
            .insert => .{ .insert = .{ .object = object, .after = try r.dot(), .value = try r.scalar() } },
            .set_element => .{ .set_element = .{ .object = object, .element = try r.dot(), .observed = try r.observed(), .value = try r.scalar() } },
            .delete_element => .{ .delete_element = .{ .object = object, .element = try r.dot() } },
        };
    }
    try r.finish();
    try change.validate();
    return change;
}
test "canonical change round trips and all truncated prefixes reject" {
    const t = std.testing;
    var change: m.Change = .{ .document = 12, .epoch = 1, .replica = 42, .first = 5, .len = 2 };
    change.operations[0] = .{ .assign = .{ .field = try m.Name.init("notes"), .value = .text } };
    change.operations[1] = .{ .insert = .{ .object = change.id(0), .value = .{ .character = 0x1f642 } } };
    var buffer: [m.max_change_bytes]u8 = undefined;
    const encoded = try encode(change, &buffer);
    const decoded = try decode(encoded);
    var copy: [m.max_change_bytes]u8 = undefined;
    try t.expectEqualSlices(u8, encoded, try encode(decoded, &copy));
    for (0..encoded.len) |i| {
        if (decode(encoded[0..i])) |_| return error.TruncatedChangeAccepted else |_| {}
    }
    buffer[encoded.len] = 0;
    try t.expectError(error.InvalidDocumentEncoding, decode(buffer[0 .. encoded.len + 1]));
}
