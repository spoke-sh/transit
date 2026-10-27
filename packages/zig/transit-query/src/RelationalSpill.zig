//! Private finite-query spill: a disk AVL map with bounded traversal and buffers.
//! Files are created exclusively and never reopened as recovery state. Any I/O,
//! quota or integrity failure poisons this owner and its incomplete execution.
const std = @import("std");
const q = @import("root.zig");
const r = q.fuze.Relational;
const e = q.fuze.RelationalExecution;
const values = q.fuze.RelationalValues;
const Self = @This();
// An AVL tree containing at most u64 nodes cannot reach this height.
const max_height = 94;
const max_record = 61 + r.max_groups * 9 + r.max_outputs * 25 + 32;
const Text = struct { offset: u64 = 0, length: u32 = 0, digest: [32]u8 = @splat(0) };
const Node = struct { left: u64 = 0, right: u64 = 0, height: u8 = 1, text: Text = .{}, group: e.Group };
pub const resident_bytes = @sizeOf(Self) + 8 * @sizeOf(Node) + 3 * max_record + max_height * 9;
io: std.Io,
allocator: std.mem.Allocator,
file: std.Io.File,
text_file: std.Io.File,
text_bytes: u64 = 0,
plan: r.Plan,
binding: [32]u8,
key_count: u8,
output_count: u8,
record_bytes: u64,
quota: u64,
work_limit: u64,
work: u64 = 0,
count: u64 = 0,
root: u64 = 0,
failed: bool = false,
cancellation: ?*const std.atomic.Value(bool),

/// The exclusively created file is unlinked immediately; process termination
/// releases it without leaving row-bearing temporary paths behind.
/// Work counts every positional record read/write, separately from operator work.
pub fn open(allocator: std.mem.Allocator, io: std.Io, directory: std.Io.Dir, name: []const u8, bound: r.Bound, work_limit: u64, cancellation: ?*const std.atomic.Value(bool)) !Self {
    try bound.validate();
    if (bound.plan.lifetime != .interactive) return error.UnsupportedSpillLifetime;
    if (name.len == 0 or std.mem.indexOfAny(u8, name, "/\\") != null or std.mem.eql(u8, name, ".") or std.mem.eql(u8, name, "..")) return error.InvalidSpillName;
    if (work_limit == 0 or bound.plan.budgets.resident_bytes < resident_bytes) return error.RelationalResidentBudget;
    if (cancellation) |flag| if (flag.load(.acquire)) return error.Cancelled;
    const binding = try bound.fingerprint();
    const file = try directory.createFile(io, name, .{ .read = true, .exclusive = true, .truncate = false, .permissions = .fromMode(0o600) });
    errdefer file.close(io);
    try directory.deleteFile(io, name);
    const text_name = try std.fmt.allocPrint(allocator, "{s}.values", .{name});
    defer allocator.free(text_name);
    const text_file = try directory.createFile(io, text_name, .{ .read = true, .exclusive = true, .truncate = false, .permissions = .fromMode(0o600) });
    errdefer text_file.close(io);
    try directory.deleteFile(io, text_name);
    return .{ .allocator = allocator, .io = io, .file = file, .text_file = text_file, .plan = bound.plan, .binding = binding, .key_count = @intCast(bound.plan.group_by.len), .output_count = @intCast(bound.plan.outputs.len), .record_bytes = 61 + 9 * bound.plan.group_by.len + 25 * bound.plan.outputs.len + 32, .quota = bound.plan.budgets.spill_bytes, .work_limit = work_limit, .cancellation = cancellation };
}
pub fn deinit(self: *Self) void {
    self.file.close(self.io);
    self.text_file.close(self.io);
    self.* = undefined;
}
fn charge(self: *Self) !void {
    if (self.failed) return error.FailedRelationalSpill;
    if (self.cancellation) |flag| if (flag.load(.acquire)) return error.Cancelled;
    if (self.work == self.work_limit) return error.RelationalSpillWorkBudget;
    self.work += 1;
}
pub fn get(self: *Self, key: e.Key) !?e.Group {
    errdefer self.failed = true;
    try self.checkKey(key);
    var current = self.root;
    var depth: usize = 0;
    while (current != 0) : (depth += 1) {
        if (depth == max_height) return error.InvalidRelationalSpill;
        var node = try self.read(current);
        errdefer node.group.deinit();
        switch (try key.order(node.group.key, self.plan)) {
            .eq => return node.group,
            .lt => current = node.left,
            .gt => current = node.right,
        }
        node.group.deinit();
    }
    return null;
}
pub fn next(self: *Self, after: ?e.Key) !?e.Group {
    errdefer self.failed = true;
    if (self.failed) return error.FailedRelationalSpill;
    if (after) |key| try self.checkKey(key);
    var current = self.root;
    var selected: ?e.Group = null;
    errdefer if (selected) |*group| group.deinit();
    var depth: usize = 0;
    while (current != 0) : (depth += 1) {
        if (depth == max_height) return error.InvalidRelationalSpill;
        var node = try self.read(current);
        errdefer node.group.deinit();
        if (after == null or try node.group.key.order(after.?, self.plan) == .gt) {
            if (selected) |*group| group.deinit();
            selected = node.group;
            current = node.left;
        } else {
            current = node.right;
            node.group.deinit();
        }
    }
    return selected;
}
pub fn put(self: *Self, group: e.Group) !void {
    errdefer self.failed = true;
    try self.checkKey(group.key);
    var path: [max_height]u64 = undefined;
    var left: [max_height]bool = undefined;
    var depth: usize = 0;
    var current = self.root;
    while (current != 0) {
        if (depth == max_height) return error.InvalidRelationalSpill;
        var node = try self.read(current);
        defer node.group.deinit();
        const order = try group.key.order(node.group.key, self.plan);
        if (order == .eq) {
            // Equal keys retain their original spelling and immutable text.
            node.group.states = group.states;
            try self.write(current, node);
            return;
        }
        path[depth] = current;
        left[depth] = order == .lt;
        depth += 1;
        current = if (order == .lt) node.left else node.right;
    }
    const count = std.math.add(u64, self.count, 1) catch return error.RelationalSpillBudget;
    const size = std.math.mul(u64, count, self.record_bytes) catch return error.RelationalSpillBudget;
    const payload = try values.payloadLength(group.key.values[0..group.key.len]);
    if (size > self.quota or self.text_bytes > self.quota - size or payload > self.quota - size - self.text_bytes) return error.RelationalSpillBudget;
    current = count;
    const text = try self.appendText(group.key);
    try self.write(current, .{ .group = group, .text = text });
    self.count = count;
    while (depth != 0) {
        depth -= 1;
        var node = try self.read(path[depth]);
        defer node.group.deinit();
        if (left[depth]) node.left = current else node.right = current;
        current = try self.balance(path[depth], node);
    }
    self.root = current;
}
fn checkKey(self: *Self, key: e.Key) !void {
    if (self.failed) return error.FailedRelationalSpill;
    if (key.len != self.key_count) return error.InvalidRelationalGroup;
    _ = try values.payloadLength(key.values[0..key.len]);
    for (key.values[0..key.len], self.plan.group_by) |value, reference| {
        var column = try self.plan.resolveColumn(reference);
        column.nullable = true;
        try values.validate(value, column);
    }
}
fn height(self: *Self, id: u64) !u8 {
    if (id == 0) return 0;
    var storage: [max_record]u8 = undefined;
    return (try self.readRecord(id, &storage))[16];
}
fn updateHeight(self: *Self, node: *Node) !void {
    node.height = 1 + @max(try self.height(node.left), try self.height(node.right));
    if (node.height >= max_height) return error.InvalidRelationalSpill;
}
fn rotateLeft(self: *Self, id: u64, old: Node) !u64 {
    var node = old;
    const replacement = node.right;
    var right = try self.read(replacement);
    defer right.group.deinit();
    node.right = right.left;
    right.left = id;
    try self.updateHeight(&node);
    try self.write(id, node);
    try self.updateHeight(&right);
    try self.write(replacement, right);
    return replacement;
}
fn rotateRight(self: *Self, id: u64, old: Node) !u64 {
    var node = old;
    const replacement = node.left;
    var left = try self.read(replacement);
    defer left.group.deinit();
    node.left = left.right;
    left.right = id;
    try self.updateHeight(&node);
    try self.write(id, node);
    try self.updateHeight(&left);
    try self.write(replacement, left);
    return replacement;
}
fn balance(self: *Self, id: u64, old: Node) !u64 {
    var node = old;
    const left_height: i16 = try self.height(node.left);
    const right_height: i16 = try self.height(node.right);
    if (left_height - right_height > 1) {
        var left = try self.read(node.left);
        defer left.group.deinit();
        if (try self.height(left.left) < try self.height(left.right)) node.left = try self.rotateLeft(node.left, left);
        return self.rotateRight(id, node);
    }
    if (right_height - left_height > 1) {
        var right = try self.read(node.right);
        defer right.group.deinit();
        if (try self.height(right.right) < try self.height(right.left)) node.right = try self.rotateRight(node.right, right);
        return self.rotateLeft(id, node);
    }
    try self.updateHeight(&node);
    try self.write(id, node);
    return id;
}
fn checksum(self: *const Self, id: u64, bytes: []const u8) [32]u8 {
    var hash: std.crypto.hash.sha2.Sha256 = .init(.{});
    hash.update("transit.relational.private-spill.v1\x00");
    hash.update(&self.binding);
    var identity: [8]u8 = undefined;
    std.mem.writeInt(u64, &identity, id, .little);
    hash.update(&identity);
    hash.update(bytes);
    return hash.finalResult();
}
fn appendText(self: *Self, key: e.Key) !Text {
    var owned = try key.clone(self.allocator);
    defer owned.deinit();
    if (owned.buffer.bytes.len == 0) return .{};
    const end = std.math.add(u64, self.text_bytes, owned.buffer.bytes.len) catch return error.RelationalSpillBudget;
    var result: Text = .{ .offset = self.text_bytes, .length = @intCast(owned.buffer.bytes.len) };
    std.crypto.hash.sha2.Sha256.hash(owned.buffer.bytes, &result.digest, .{});
    try self.charge();
    try self.text_file.writePositionalAll(self.io, owned.buffer.bytes, self.text_bytes);
    self.text_bytes = end;
    return result;
}
fn readRecord(self: *Self, id: u64, storage: *[max_record]u8) ![]const u8 {
    try self.charge();
    if (id == 0 or id > self.count) return error.InvalidRelationalSpill;
    const bytes = storage[0..@intCast(self.record_bytes)];
    if (try self.file.readPositionalAll(self.io, bytes, (id - 1) * self.record_bytes) != bytes.len) return error.IncompleteRelationalSpill;
    const body = bytes[0 .. bytes.len - 32];
    if (!std.mem.eql(u8, bytes[body.len..], &self.checksum(id, body))) return error.InvalidRelationalSpill;
    if (std.mem.readInt(u64, body[0..8], .little) > self.count or std.mem.readInt(u64, body[8..16], .little) > self.count or body[16] == 0 or body[16] >= max_height) return error.InvalidRelationalSpill;
    return body;
}
fn read(self: *Self, id: u64) !Node {
    var storage: [max_record]u8 = undefined;
    const body = try self.readRecord(id, &storage);
    var reader: std.Io.Reader = .fixed(body);
    var node: Node = .{ .left = try reader.takeInt(u64, .little), .right = try reader.takeInt(u64, .little), .height = try reader.takeByte(), .text = .{ .offset = try reader.takeInt(u64, .little), .length = try reader.takeInt(u32, .little), .digest = (try reader.takeArray(32)).* }, .group = .{ .key = .{ .len = self.key_count } } };
    if (node.text.length > values.max_text_bytes or node.text.offset > self.text_bytes or node.text.length > self.text_bytes - node.text.offset) return error.InvalidRelationalSpill;
    if (node.text.length == 0 and (node.text.offset != 0 or !std.mem.allEqual(u8, &node.text.digest, 0))) return error.InvalidRelationalSpill;
    var spans: [r.max_groups]struct { offset: u32, length: u32 } = undefined;
    var text_at: u32 = 0;
    for (node.group.key.values[0..self.key_count], 0..) |*value, i| switch (try reader.takeByte()) {
        0 => {
            if (try reader.takeInt(u64, .little) != 0) return error.InvalidRelationalSpill;
            value.* = null;
        },
        1 => value.* = .{ .integer = try reader.takeInt(i64, .little) },
        2 => {
            const offset = try reader.takeInt(u32, .little);
            const length = try reader.takeInt(u32, .little);
            if (offset != text_at or length > node.text.length - text_at) return error.InvalidRelationalSpill;
            spans[i] = .{ .offset = offset, .length = length };
            text_at += length;
            value.* = .{ .text = "" };
        },
        else => return error.InvalidRelationalSpill,
    };
    if (text_at != node.text.length) return error.InvalidRelationalSpill;
    for (node.group.states[0..self.output_count]) |*state| state.* = .{ .rows = try reader.takeInt(u64, .little), .values = try reader.takeInt(u64, .little), .sum = try readOptional(&reader) };
    if (reader.bufferedLen() != 0) return error.InvalidRelationalSpill;
    errdefer node.group.deinit();
    if (node.text.length != 0) {
        const bytes = try self.allocator.alloc(u8, node.text.length);
        node.group.key.buffer = .{ .allocator = self.allocator, .bytes = bytes };
        try self.charge();
        if (try self.text_file.readPositionalAll(self.io, bytes, node.text.offset) != bytes.len) return error.IncompleteRelationalSpill;
        var digest: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
        if (!std.mem.eql(u8, &digest, &node.text.digest)) return error.InvalidRelationalSpill;
        for (node.group.key.values[0..self.key_count], 0..) |*value, i| if (value.* != null and value.*.? == .text) {
            value.* = .{ .text = bytes[spans[i].offset..][0..spans[i].length] };
        };
    }
    try self.checkKey(node.group.key);
    return node;
}
fn write(self: *Self, id: u64, node: Node) !void {
    try self.charge();
    var storage: [max_record]u8 = undefined;
    const bytes = storage[0..@intCast(self.record_bytes)];
    var writer: std.Io.Writer = .fixed(bytes[0 .. bytes.len - 32]);
    try writer.writeInt(u64, node.left, .little);
    try writer.writeInt(u64, node.right, .little);
    try writer.writeByte(node.height);
    try writer.writeInt(u64, node.text.offset, .little);
    try writer.writeInt(u32, node.text.length, .little);
    try writer.writeAll(&node.text.digest);
    var text_at: u32 = 0;
    for (node.group.key.values[0..self.key_count]) |value| {
        if (value) |present| switch (present) {
            .integer => |integer| {
                try writer.writeByte(1);
                try writer.writeInt(i64, integer, .little);
            },
            .text => |text| {
                if (text.len > node.text.length - text_at) return error.InvalidRelationalSpill;
                try writer.writeByte(2);
                try writer.writeInt(u32, text_at, .little);
                try writer.writeInt(u32, @intCast(text.len), .little);
                text_at += @intCast(text.len);
            },
        } else {
            try writer.writeByte(0);
            try writer.writeInt(u64, 0, .little);
        }
    }
    if (text_at != node.text.length) return error.InvalidRelationalSpill;
    for (node.group.states[0..self.output_count]) |state| {
        try writer.writeInt(u64, state.rows, .little);
        try writer.writeInt(u64, state.values, .little);
        try writeOptional(&writer, state.sum);
    }
    @memcpy(bytes[writer.end..], &self.checksum(id, writer.buffered()));
    try self.file.writePositionalAll(self.io, bytes, (id - 1) * self.record_bytes);
}
fn writeOptional(writer: *std.Io.Writer, value: ?i64) !void {
    try writer.writeByte(@intFromBool(value != null));
    try writer.writeInt(i64, value orelse 0, .little);
}
fn readOptional(reader: *std.Io.Reader) !?i64 {
    const present = try reader.takeByte();
    const value = try reader.takeInt(i64, .little);
    if (present > 1 or (present == 0 and value != 0)) return error.InvalidRelationalSpill;
    return if (present == 0) null else value;
}

test {
    _ = @import("relational_spill_test.zig");
}
