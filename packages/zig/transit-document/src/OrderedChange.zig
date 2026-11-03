//! Canonical ordered tree replacement/patch input. Borrowed bytes, no I/O.
const std = @import("std");
const wire = @import("codec.zig");
const logical = @import("LogicalChange.zig");
pub const magic = "DORDER01";
pub const Kind = enum(u8) {
    map,
    list,
    element,
    attribute,
    string,
    binary,
    number,
    boolean,
    signed,
    unsigned,
    float,
    null_value,
    missing,
    type_error,
    conflict,
    text,
    comment,
    processing_instruction,
    pub fn container(self: Kind) bool {
        return self == .map or self == .list or self == .element or self == .conflict;
    }
};
pub const Span = struct { part: u64, start: u64, end: u64 };
pub const Node = struct {
    depth: u32,
    kind: Kind,
    name: []const u8 = "",
    value: []const u8 = "",
    span: ?Span = null,
    pub fn validate(self: Node) !void {
        if (self.name.len > std.math.maxInt(u32) or self.value.len > std.math.maxInt(u32) or !std.unicode.utf8ValidateSlice(self.name)) return error.InvalidOrderedNode;
        if (self.span) |span| if (span.part == 0 or span.end < span.start) return error.InvalidOrderedSpan;
        switch (self.kind) {
            .map, .list, .element, .conflict, .null_value, .missing => if (self.value.len != 0) return error.InvalidOrderedNode,
            .attribute, .string, .text, .comment, .processing_instruction, .type_error => if (!std.unicode.utf8ValidateSlice(self.value)) return error.InvalidOrderedNode,
            .number => if (!number(self.value)) return error.InvalidOrderedNode,
            .boolean => if (self.value.len != 1 or self.value[0] > 1) return error.InvalidOrderedNode,
            .signed, .unsigned => if (self.value.len != 8) return error.InvalidOrderedNode,
            .float => {
                if (self.value.len != 8) return error.InvalidOrderedNode;
                const value: f64 = @bitCast(std.mem.readInt(u64, self.value[0..8], .little));
                if (!std.math.isFinite(value)) return error.InvalidOrderedNode;
            },
            .binary => {},
        }
    }
};
pub const Part = struct { id: u64, bytes: []const u8, digest: [32]u8 };
pub const Header = struct {
    definition: [32]u8,
    document: [16]u8,
    epoch: u64,
    expected_revision: u64,
    /// Child ordinals in the selected revision; empty replaces the root.
    path: []const u8 = "", // little-endian u32 ordinals
    nodes: u32,
    parts: u32,
    pub fn validate(self: Header) !void {
        if (std.mem.allEqual(u8, &self.definition, 0) or std.mem.allEqual(u8, &self.document, 0) or self.epoch == 0 or self.nodes == 0 or self.path.len % 4 != 0 or self.path.len / 4 > std.math.maxInt(u16)) return error.InvalidOrderedChange;
        if (self.expected_revision == 0 and self.path.len != 0) return error.InvalidOrderedChange;
    }
};
/// A bounded caller-owned depth stack; never grows with node count.
pub const Frame = struct { kind: Kind, children: u32 = 0 };
pub const Validator = struct {
    frames: []Frame,
    seen: u64 = 0,
    depth: u32 = 0,
    conflicts: u32 = 0,
    pub fn push(self: *Validator, node: Node) !void {
        try node.validate();
        try self.pushStructure(node.depth, node.kind);
    }
    pub fn pushStructure(self: *Validator, node_depth: u32, kind: Kind) !void {
        const node = .{ .depth = node_depth, .kind = kind };
        if (node.depth >= self.frames.len or self.seen == std.math.maxInt(u64)) return error.DocumentDepthLimitExceeded;
        if (self.seen == 0) {
            if (node.depth != 0) return error.InvalidOrderedTree;
        } else {
            if (node.depth == 0 or node.depth > self.depth + 1) return error.InvalidOrderedTree;
            while (self.depth >= node.depth) {
                try self.close();
                self.depth -= 1;
            }
            const parent = &self.frames[node.depth - 1];
            if (!parent.kind.container()) return error.InvalidOrderedTree;
            parent.children = std.math.add(u32, parent.children, 1) catch return error.InvalidOrderedTree;
        }
        self.frames[node.depth] = .{ .kind = node.kind };
        self.depth = node.depth;
        self.seen += 1;
    }
    fn close(self: *Validator) !void {
        const frame = self.frames[self.depth];
        if (frame.kind == .conflict) {
            if (frame.children < 2) return error.InvalidOrderedTree;
            self.conflicts = std.math.add(u32, self.conflicts, frame.children - 1) catch return error.DocumentConflictLimitExceeded;
        }
    }
    pub fn finish(self: *Validator) !void {
        if (self.seen == 0) return error.InvalidOrderedTree;
        while (true) {
            try self.close();
            if (self.depth == 0) break;
            self.depth -= 1;
        }
    }
};
pub const Decoder = struct {
    reader: wire.Reader,
    header: Header,
    remaining_parts: u32,
    remaining_nodes: u32,
    last_part: u64 = 0,
    pub fn init(bytes: []const u8) !Decoder {
        var r: wire.Reader = .{ .bytes = bytes };
        if (!std.mem.eql(u8, try r.read(8), magic)) return error.InvalidOrderedChange;
        const definition = (try r.read(32))[0..32].*;
        const document = (try r.read(16))[0..16].*;
        const epoch = try r.int(u64);
        const expected = try r.int(u64);
        const path = try r.read(@as(usize, try r.int(u16)) * 4);
        const header: Header = .{ .definition = definition, .document = document, .epoch = epoch, .expected_revision = expected, .path = path, .nodes = try r.int(u32), .parts = try r.int(u32) };
        try header.validate();
        return .{ .reader = r, .header = header, .remaining_parts = header.parts, .remaining_nodes = header.nodes };
    }
    pub fn nextPart(self: *Decoder) !?Part {
        if (self.remaining_parts == 0) return null;
        const id = try self.reader.int(u64);
        if (id <= self.last_part) return error.InvalidOrderedPart;
        const length = try self.reader.int(u32);
        const digest = (try self.reader.read(32))[0..32].*;
        const bytes = try self.reader.read(length);
        if (!std.mem.eql(u8, &digest, &logical.hash(bytes))) return error.InvalidOrderedPart;
        self.last_part = id;
        self.remaining_parts -= 1;
        return .{ .id = id, .bytes = bytes, .digest = digest };
    }
    pub fn next(self: *Decoder) !?Node {
        if (self.remaining_parts != 0) return error.InvalidOrderedChange;
        if (self.remaining_nodes == 0) {
            try self.reader.finish();
            return null;
        }
        const r = &self.reader;
        const depth = try r.int(u32);
        const kind = std.enums.fromInt(Kind, try r.int(u8)) orelse return error.InvalidOrderedNode;
        const name = try r.read(try r.int(u32));
        const value = try r.read(try r.int(u32));
        const span: ?Span = switch (try r.int(u8)) {
            0 => null,
            1 => .{ .part = try r.int(u64), .start = try r.int(u64), .end = try r.int(u64) },
            else => return error.InvalidOrderedSpan,
        };
        const node: Node = .{ .depth = depth, .kind = kind, .name = name, .value = value, .span = span };
        try node.validate();
        self.remaining_nodes -= 1;
        return node;
    }
};
pub fn writeHeader(w: *wire.Writer, header: Header) !void {
    try header.validate();
    try w.write(magic);
    try w.write(&header.definition);
    try w.write(&header.document);
    try w.int(u64, header.epoch);
    try w.int(u64, header.expected_revision);
    try w.int(u16, @intCast(header.path.len / 4));
    try w.write(header.path);
    try w.int(u32, header.nodes);
    try w.int(u32, header.parts);
}
pub fn writePart(w: *wire.Writer, part: Part) !void {
    if (part.id == 0 or part.bytes.len > std.math.maxInt(u32) or !std.mem.eql(u8, &part.digest, &logical.hash(part.bytes))) return error.InvalidOrderedPart;
    try w.int(u64, part.id);
    try w.int(u32, @intCast(part.bytes.len));
    try w.write(&part.digest);
    try w.write(part.bytes);
}
pub fn writeNode(w: *wire.Writer, node: Node) !void {
    try node.validate();
    try w.int(u32, node.depth);
    try w.int(u8, @backingInt(node.kind));
    try w.int(u32, @intCast(node.name.len));
    try w.write(node.name);
    try w.int(u32, @intCast(node.value.len));
    try w.write(node.value);
    try w.int(u8, @intFromBool(node.span != null));
    if (node.span) |span| {
        try w.int(u64, span.part);
        try w.int(u64, span.start);
        try w.int(u64, span.end);
    }
}
pub fn encode(header: Header, parts: []const Part, nodes: []const Node, output: []u8) ![]const u8 {
    if (header.nodes != nodes.len or header.parts != parts.len) return error.InvalidOrderedChange;
    var w: wire.Writer = .{ .bytes = output };
    try writeHeader(&w, header);
    var last: u64 = 0;
    for (parts) |part| {
        if (part.id <= last) return error.InvalidOrderedPart;
        try writePart(&w, part);
        last = part.id;
    }
    for (nodes) |node| try writeNode(&w, node);
    return output[0..w.offset];
}
fn number(bytes: []const u8) bool {
    if (bytes.len == 0) return false;
    var i: usize = @intFromBool(bytes[0] == '-');
    if (i == bytes.len) return false;
    if (bytes[i] == '0') i += 1 else {
        if (bytes[i] < '1' or bytes[i] > '9') return false;
        while (i < bytes.len and std.ascii.isDigit(bytes[i])) : (i += 1) {}
    }
    if (i < bytes.len and bytes[i] == '.') {
        i += 1;
        const start = i;
        while (i < bytes.len and std.ascii.isDigit(bytes[i])) : (i += 1) {}
        if (i == start) return false;
    }
    if (i < bytes.len and (bytes[i] == 'e' or bytes[i] == 'E')) {
        i += 1;
        if (i < bytes.len and (bytes[i] == '+' or bytes[i] == '-')) i += 1;
        const start = i;
        while (i < bytes.len and std.ascii.isDigit(bytes[i])) : (i += 1) {}
        if (i == start) return false;
    }
    return i == bytes.len;
}
