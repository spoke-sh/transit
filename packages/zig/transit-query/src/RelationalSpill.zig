//! Private finite-query spill: a disk AVL map with bounded traversal and buffers.
//! Files are created exclusively and never reopened as recovery state. Any I/O,
//! quota or integrity failure poisons this owner and its incomplete execution.
const std = @import("std");
const q = @import("root.zig");
const r = q.fuze.Relational;
const e = q.fuze.RelationalExecution;
const Self = @This();
// An AVL tree containing at most u64 nodes cannot reach this height.
const max_height = 94;
const max_record = 17 + r.max_groups * 9 + r.max_outputs * 25 + 32;
const Node = struct { left: u64 = 0, right: u64 = 0, height: u8 = 1, group: e.Group };
pub const resident_bytes = @sizeOf(Self) + 8 * @sizeOf(Node) + 3 * max_record + max_height * 9;
io: std.Io,
file: std.Io.File,
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
pub fn open(io: std.Io, directory: std.Io.Dir, name: []const u8, bound: r.Bound, work_limit: u64, cancellation: ?*const std.atomic.Value(bool)) !Self {
    try bound.validate();
    if (bound.plan.lifetime != .interactive) return error.UnsupportedSpillLifetime;
    if (name.len == 0 or std.mem.indexOfAny(u8, name, "/\\") != null or std.mem.eql(u8, name, ".") or std.mem.eql(u8, name, "..")) return error.InvalidSpillName;
    if (work_limit == 0 or bound.plan.budgets.resident_bytes < resident_bytes) return error.RelationalResidentBudget;
    if (cancellation) |flag| if (flag.load(.acquire)) return error.Cancelled;
    const binding = try bound.fingerprint();
    const file = try directory.createFile(io, name, .{ .read = true, .exclusive = true, .truncate = false, .permissions = .fromMode(0o600) });
    errdefer file.close(io);
    try directory.deleteFile(io, name);
    return .{ .io = io, .file = file, .binding = binding, .key_count = @intCast(bound.plan.group_by.len), .output_count = @intCast(bound.plan.outputs.len), .record_bytes = 17 + 9 * bound.plan.group_by.len + 25 * bound.plan.outputs.len + 32, .quota = bound.plan.budgets.spill_bytes, .work_limit = work_limit, .cancellation = cancellation };
}
pub fn deinit(self: *Self) void {
    self.file.close(self.io);
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
        const node = try self.read(current);
        switch (key.order(node.group.key)) {
            .eq => return node.group,
            .lt => current = node.left,
            .gt => current = node.right,
        }
    }
    return null;
}
pub fn next(self: *Self, after: ?e.Key) !?e.Group {
    errdefer self.failed = true;
    if (self.failed) return error.FailedRelationalSpill;
    if (after) |key| try self.checkKey(key);
    var current = self.root;
    var selected: ?e.Group = null;
    var depth: usize = 0;
    while (current != 0) : (depth += 1) {
        if (depth == max_height) return error.InvalidRelationalSpill;
        const node = try self.read(current);
        if (after == null or node.group.key.order(after.?) == .gt) {
            selected = node.group;
            current = node.left;
        } else current = node.right;
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
        const order = group.key.order(node.group.key);
        if (order == .eq) {
            node.group = group;
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
    if (size > self.quota) return error.RelationalSpillBudget;
    current = count;
    try self.write(current, .{ .group = group });
    self.count = count;
    while (depth != 0) {
        depth -= 1;
        var node = try self.read(path[depth]);
        if (left[depth]) node.left = current else node.right = current;
        current = try self.balance(path[depth], node);
    }
    self.root = current;
}
fn checkKey(self: *Self, key: e.Key) !void {
    if (self.failed) return error.FailedRelationalSpill;
    if (key.len != self.key_count) return error.InvalidRelationalGroup;
}
fn height(self: *Self, id: u64) !u8 {
    return if (id == 0) 0 else (try self.read(id)).height;
}
fn updateHeight(self: *Self, node: *Node) !void {
    node.height = 1 + @max(try self.height(node.left), try self.height(node.right));
    if (node.height >= max_height) return error.InvalidRelationalSpill;
}
fn rotateLeft(self: *Self, id: u64, old: Node) !u64 {
    var node = old;
    const replacement = node.right;
    var right = try self.read(replacement);
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
        const left = try self.read(node.left);
        if (try self.height(left.left) < try self.height(left.right)) node.left = try self.rotateLeft(node.left, left);
        return self.rotateRight(id, node);
    }
    if (right_height - left_height > 1) {
        const right = try self.read(node.right);
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
fn read(self: *Self, id: u64) !Node {
    try self.charge();
    if (id == 0 or id > self.count) return error.InvalidRelationalSpill;
    var storage: [max_record]u8 = undefined;
    const bytes = storage[0..@intCast(self.record_bytes)];
    if (try self.file.readPositionalAll(self.io, bytes, (id - 1) * self.record_bytes) != bytes.len) return error.IncompleteRelationalSpill;
    const body = bytes[0 .. bytes.len - 32];
    if (!std.mem.eql(u8, bytes[body.len..], &self.checksum(id, body))) return error.InvalidRelationalSpill;
    var reader: std.Io.Reader = .fixed(body);
    var node: Node = .{ .left = try reader.takeInt(u64, .little), .right = try reader.takeInt(u64, .little), .height = try reader.takeByte(), .group = .{ .key = .{ .len = self.key_count } } };
    if (node.left > self.count or node.right > self.count or node.height == 0 or node.height >= max_height) return error.InvalidRelationalSpill;
    for (node.group.key.values[0..self.key_count]) |*value| value.* = try readOptional(&reader);
    for (node.group.states[0..self.output_count]) |*state| state.* = .{ .rows = try reader.takeInt(u64, .little), .values = try reader.takeInt(u64, .little), .sum = try readOptional(&reader) };
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
    for (node.group.key.values[0..self.key_count]) |value| try writeOptional(&writer, value);
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
