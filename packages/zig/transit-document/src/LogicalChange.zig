//! Borrowed, canonical causal map-tree changes. No allocator, storage or actor.
//! Field/value widths are request budgets, not inline scalar capacities.
const std = @import("std");
const wire = @import("codec.zig");
pub const magic = "DCHANGE1";
pub const Dot = struct {
    replica: [16]u8 = @splat(0),
    sequence: u64 = 0,
    ordinal: u16 = 0,
    pub const root: Dot = .{};
    pub fn eql(a: Dot, b: Dot) bool {
        return std.meta.eql(a, b);
    }
    pub fn validate(self: Dot, root_allowed: bool) !void {
        if (root_allowed and self.eql(.root)) return;
        if (self.sequence == 0 or std.mem.allEqual(u8, &self.replica, 0)) return error.InvalidLogicalDot;
    }
    pub fn bytes(self: Dot) [26]u8 {
        var out: [26]u8 = undefined;
        out[0..16].* = self.replica;
        std.mem.writeInt(u64, out[16..24], self.sequence, .big);
        std.mem.writeInt(u16, out[24..26], self.ordinal, .big);
        return out;
    }
    pub fn fromBytes(bytes_: *const [26]u8) Dot {
        return .{ .replica = bytes_[0..16].*, .sequence = std.mem.readInt(u64, bytes_[16..24], .big), .ordinal = std.mem.readInt(u16, bytes_[24..26], .big) };
    }
};
pub const Kind = enum(u8) { null_value, boolean, signed, unsigned, float, string, binary, map };
pub const Value = struct {
    kind: Kind,
    bytes: []const u8 = &.{},
    pub fn validate(self: Value) !void {
        switch (self.kind) {
            .null_value, .map => if (self.bytes.len != 0) return error.InvalidLogicalValue,
            .boolean => if (self.bytes.len != 1 or self.bytes[0] > 1) return error.InvalidLogicalValue,
            .signed, .unsigned => if (self.bytes.len != 8) return error.InvalidLogicalValue,
            .float => {
                if (self.bytes.len != 8) return error.InvalidLogicalValue;
                const number: f64 = @bitCast(std.mem.readInt(u64, self.bytes[0..8], .little));
                if (!std.math.isFinite(number)) return error.InvalidLogicalValue;
            },
            .string => if (!std.unicode.utf8ValidateSlice(self.bytes)) return error.InvalidLogicalValue,
            .binary => {},
        }
    }
};
pub const Operation = struct {
    object: Dot = .root,
    field: []const u8,
    /// Canonical ordered 26-byte dots, borrowed from the input frame.
    observed: []const u8 = &.{},
    /// null removes observed assignments; a null_value assigns explicit null.
    value: ?Value,
    pub fn validate(self: Operation) !void {
        try self.object.validate(true);
        if (self.field.len == 0 or !std.unicode.utf8ValidateSlice(self.field) or self.observed.len % 26 != 0 or self.observed.len / 26 > 65535) return error.InvalidLogicalOperation;
        var at: usize = 0;
        while (at < self.observed.len) : (at += 26) {
            try Dot.fromBytes(self.observed[at..][0..26]).validate(false);
            if (at != 0 and std.mem.order(u8, self.observed[at - 26 .. at], self.observed[at..][0..26]) != .lt) return error.InvalidLogicalOperation;
        }
        if (self.value) |v| try v.validate();
    }
};
pub const Header = struct {
    definition: [32]u8,
    document: [16]u8,
    epoch: u64,
    replica: [16]u8,
    sequence: u64,
    preceding_sequence: u64,
    operations: u16,
    pub fn validate(self: Header) !void {
        if (std.mem.allEqual(u8, &self.definition, 0) or std.mem.allEqual(u8, &self.document, 0) or std.mem.allEqual(u8, &self.replica, 0) or self.epoch == 0 or self.operations == 0 or self.sequence == 0 or self.preceding_sequence != self.sequence - 1) return error.InvalidLogicalChange;
    }
    pub fn dot(self: Header, ordinal: u16) Dot {
        return .{ .replica = self.replica, .sequence = self.sequence, .ordinal = ordinal };
    }
};
pub const Decoder = struct {
    reader: wire.Reader,
    header: Header,
    remaining: u16,
    pub fn init(bytes: []const u8) !Decoder {
        var r: wire.Reader = .{ .bytes = bytes };
        if (!std.mem.eql(u8, try r.read(8), magic)) return error.InvalidLogicalChange;
        const header: Header = .{ .definition = (try r.read(32))[0..32].*, .document = (try r.read(16))[0..16].*, .epoch = try r.int(u64), .replica = (try r.read(16))[0..16].*, .sequence = try r.int(u64), .preceding_sequence = try r.int(u64), .operations = try r.int(u16) };
        try header.validate();
        return .{ .reader = r, .header = header, .remaining = header.operations };
    }
    pub fn next(self: *Decoder) !?Operation {
        if (self.remaining == 0) {
            try self.reader.finish();
            return null;
        }
        const r = &self.reader;
        const object = Dot.fromBytes((try r.read(26))[0..26]);
        const field = try r.read(try r.int(u32));
        const observed = try r.read(@as(usize, try r.int(u16)) * 26);
        const tag = try r.int(u8);
        const value: ?Value = if (tag == 255) null else .{ .kind = std.enums.fromInt(Kind, tag) orelse return error.InvalidLogicalValue, .bytes = try r.read(try r.int(u32)) };
        const op: Operation = .{ .object = object, .field = field, .observed = observed, .value = value };
        try op.validate();
        self.remaining -= 1;
        return op;
    }
};
pub fn encode(header: Header, operations: []const Operation, output: []u8) ![]const u8 {
    try header.validate();
    if (operations.len != header.operations) return error.InvalidLogicalChange;
    var w: wire.Writer = .{ .bytes = output };
    try w.write(magic);
    try w.write(&header.definition);
    try w.write(&header.document);
    try w.int(u64, header.epoch);
    try w.write(&header.replica);
    try w.int(u64, header.sequence);
    try w.int(u64, header.preceding_sequence);
    try w.int(u16, header.operations);
    for (operations) |op| {
        try op.validate();
        if (op.field.len > std.math.maxInt(u32)) return error.InvalidLogicalOperation;
        try w.write(&op.object.bytes());
        try w.int(u32, @intCast(op.field.len));
        try w.write(op.field);
        try w.int(u16, @intCast(op.observed.len / 26));
        try w.write(op.observed);
        try w.int(u8, if (op.value) |v| @backingInt(v.kind) else 255);
        if (op.value) |v| {
            if (v.bytes.len > std.math.maxInt(u32)) return error.InvalidLogicalValue;
            try w.int(u32, @intCast(v.bytes.len));
            try w.write(v.bytes);
        }
    }
    return output[0..w.offset];
}
pub fn hash(bytes: []const u8) [32]u8 {
    var result: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &result, .{});
    return result;
}
