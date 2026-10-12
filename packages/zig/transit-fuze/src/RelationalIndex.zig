//! Immutable AVL group state. A host stages bounded candidate records and
//! atomically publishes the returned root with operator/input progress.
//! No filesystem, allocator, retention policy or publication authority lives here.
const std = @import("std");
const r = @import("Relational.zig");
const e = @import("RelationalExecution.zig");
const native = @import("transit_protocol").Growth;
const Self = @This();
pub const max_height = 94;
pub const max_record_bytes = 4 + 32 + 32 + 2 * 54 + 2 + r.max_groups * 9 + r.max_outputs * 25;
pub const max_candidate_records = 3 * max_height + 1;
const Node = struct { left: ?Reference = null, right: ?Reference = null, group: e.Group };
pub const resident_bytes = @sizeOf(Self) + max_height * @sizeOf(Node) + 6 * @sizeOf(Node) + 2 * max_record_bytes;
pub const Reference = struct {
    id: u64,
    bytes: u32,
    digest: [32]u8,
    height: u8,
    entries: u64,
};
plan: r.Plan,
binding: [32]u8,
root: ?Reference = null,

pub fn init(bound: r.Bound, root: ?Reference) !Self {
    try bound.validate();
    if (bound.plan.budgets.resident_bytes < resident_bytes) return error.RelationalResidentBudget;
    if (root) |value| try validateReference(value);
    return .{ .plan = bound.plan, .binding = try bound.fingerprint(), .root = root };
}
/// Store.read(id, output) returns exact immutable bytes; Store.save(bytes)
/// reserves a fresh monotone ID and private candidate bytes. Neither callback
/// may expose a new accepted root. The host owns physical quotas and staging.
pub fn get(self: Self, store: anytype, key: e.Key) !?e.Group {
    try self.checkKey(key);
    var cursor = self.root;
    var depth: usize = 0;
    while (cursor) |reference| : (depth += 1) {
        if (depth == max_height) return error.InvalidRelationalIndex;
        const node = try self.load(store, reference);
        switch (key.order(node.group.key)) {
            .eq => return node.group,
            .lt => cursor = node.left,
            .gt => cursor = node.right,
        }
    }
    return null;
}
pub fn next(self: Self, store: anytype, after: ?e.Key) !?e.Group {
    if (after) |key| try self.checkKey(key);
    var cursor = self.root;
    var selected: ?e.Group = null;
    var depth: usize = 0;
    while (cursor) |reference| : (depth += 1) {
        if (depth == max_height) return error.InvalidRelationalIndex;
        const node = try self.load(store, reference);
        if (after == null or node.group.key.order(after.?) == .gt) {
            selected = node.group;
            cursor = node.left;
        } else cursor = node.right;
    }
    return selected;
}
pub fn put(self: *Self, store: anytype, group: e.Group) !void {
    try self.checkGroup(group);
    var parents: [max_height]Node = undefined;
    var left: [max_height]bool = undefined;
    var depth: usize = 0;
    var cursor = self.root;
    var replacement: Node = .{ .group = group };
    while (cursor) |reference| {
        if (depth == max_height) return error.InvalidRelationalIndex;
        const node = try self.load(store, reference);
        const order = group.key.order(node.group.key);
        if (order == .eq) {
            replacement.left = node.left;
            replacement.right = node.right;
            break;
        }
        parents[depth] = node;
        left[depth] = order == .lt;
        depth += 1;
        cursor = if (order == .lt) node.left else node.right;
    }
    var next_root = try self.save(store, replacement);
    while (depth != 0) {
        depth -= 1;
        var parent = parents[depth];
        if (left[depth]) parent.left = next_root else parent.right = next_root;
        next_root = try self.balance(store, parent);
    }
    // All failures leave the original root usable. Staged candidates remain
    // private; a host may retry them only with their exact reserved identity.
    self.root = next_root;
}
fn height(reference: ?Reference) i16 {
    return if (reference) |value| value.height else 0;
}
fn entries(reference: ?Reference) u64 {
    return if (reference) |value| value.entries else 0;
}
fn balance(self: Self, store: anytype, original: Node) !Reference {
    var node = original;
    const difference = height(node.left) - height(node.right);
    if (difference > 1) {
        const child = try self.load(store, node.left.?);
        if (height(child.left) < height(child.right)) node.left = try self.rotateLeft(store, child);
        return self.rotateRight(store, node);
    }
    if (difference < -1) {
        const child = try self.load(store, node.right.?);
        if (height(child.right) < height(child.left)) node.right = try self.rotateRight(store, child);
        return self.rotateLeft(store, node);
    }
    return self.save(store, node);
}
fn rotateLeft(self: Self, store: anytype, original: Node) !Reference {
    var node = original;
    var child = try self.load(store, node.right orelse return error.InvalidRelationalIndex);
    node.right = child.left;
    child.left = try self.save(store, node);
    return self.save(store, child);
}
fn rotateRight(self: Self, store: anytype, original: Node) !Reference {
    var node = original;
    var child = try self.load(store, node.left orelse return error.InvalidRelationalIndex);
    node.left = child.right;
    child.right = try self.save(store, node);
    return self.save(store, child);
}
fn definition() [32]u8 {
    var bytes: [32]u8 = undefined;
    _ = std.fmt.hexToBytes(&bytes, @tagName(native.current_definition)) catch unreachable;
    return bytes;
}
pub fn validateReference(reference: Reference) !void {
    if (reference.id == 0 or reference.bytes == 0 or reference.bytes > max_record_bytes or reference.height == 0 or reference.height >= max_height or reference.entries == 0) return error.InvalidRelationalIndex;
}
fn checkKey(self: Self, key: e.Key) !void {
    if (key.len != self.plan.group_by.len) return error.InvalidRelationalGroup;
}
fn checkGroup(self: Self, group: e.Group) !void {
    try self.checkKey(group.key);
    for (self.plan.outputs, group.states[0..self.plan.outputs.len]) |output, state| {
        if (state.values > state.rows) return error.InvalidRelationalGroup;
        switch (output.expression) {
            .column => if (state.rows != 0 or state.values != 0 or state.sum != null) return error.InvalidRelationalGroup,
            .count_all => if (state.values != 0 or state.sum != null) return error.InvalidRelationalGroup,
            .count => if (state.sum != null) return error.InvalidRelationalGroup,
            .sum => if ((state.values == 0) != (state.sum == null)) return error.InvalidRelationalGroup,
        }
    }
}
fn save(self: Self, store: anytype, node: Node) !Reference {
    try self.checkGroup(node.group);
    const h = 1 + @max(height(node.left), height(node.right));
    if (h >= max_height or @abs(height(node.left) - height(node.right)) > 1) return error.InvalidRelationalIndex;
    var bytes: [max_record_bytes]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&bytes);
    try writer.writeAll("FRN1");
    try writer.writeAll(&definition());
    try writer.writeAll(&self.binding);
    try writeReference(&writer, node.left);
    try writeReference(&writer, node.right);
    try writer.writeAll(&.{ node.group.key.len, @intCast(self.plan.outputs.len) });
    for (node.group.key.values[0..node.group.key.len]) |value| try writeOptional(&writer, value);
    for (node.group.states[0..self.plan.outputs.len]) |state| {
        try writer.writeInt(u64, state.rows, .little);
        try writer.writeInt(u64, state.values, .little);
        try writeOptional(&writer, state.sum);
    }
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(writer.buffered(), &digest, .{});
    const count = try std.math.add(u64, try std.math.add(u64, entries(node.left), entries(node.right)), 1);
    const id = try store.save(writer.buffered());
    if (id == 0 or (node.left != null and id <= node.left.?.id) or (node.right != null and id <= node.right.?.id)) return error.InvalidRelationalIndex;
    return .{ .id = id, .bytes = @intCast(writer.end), .digest = digest, .height = @intCast(h), .entries = count };
}
fn load(self: Self, store: anytype, reference: Reference) !Node {
    try validateReference(reference);
    var buffer: [max_record_bytes]u8 = undefined;
    const bytes = try store.read(reference.id, &buffer);
    if (bytes.len != reference.bytes) return error.IncompleteRelationalIndex;
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    if (!std.mem.eql(u8, &digest, &reference.digest)) return error.InvalidRelationalIndex;
    var reader: std.Io.Reader = .fixed(bytes);
    if (!std.mem.eql(u8, try reader.take(4), "FRN1")) return error.InvalidRelationalIndex;
    if (!std.mem.eql(u8, try reader.take(32), &definition())) return error.IncompatibleDefinition;
    if (!std.mem.eql(u8, try reader.take(32), &self.binding)) return error.RelationalSourceChanged;
    var node: Node = .{ .left = try readReference(&reader), .right = try readReference(&reader), .group = .{ .key = .{ .len = try reader.takeByte() } } };
    if (try reader.takeByte() != self.plan.outputs.len) return error.InvalidRelationalGroup;
    try self.checkKey(node.group.key);
    for (node.group.key.values[0..node.group.key.len]) |*value| value.* = try readOptional(&reader);
    for (node.group.states[0..self.plan.outputs.len]) |*state| state.* = .{ .rows = try reader.takeInt(u64, .little), .values = try reader.takeInt(u64, .little), .sum = try readOptional(&reader) };
    try self.checkGroup(node.group);
    if (reader.bufferedLen() != 0 or @abs(height(node.left) - height(node.right)) > 1 or reference.height != 1 + @max(height(node.left), height(node.right)) or reference.entries != try std.math.add(u64, try std.math.add(u64, entries(node.left), entries(node.right)), 1)) return error.InvalidRelationalIndex;
    for ([_]?Reference{ node.left, node.right }) |child| if (child) |value| if (value.id >= reference.id) return error.InvalidRelationalIndex;
    return node;
}
pub fn writeReference(writer: *std.Io.Writer, reference: ?Reference) !void {
    try writer.writeByte(@intFromBool(reference != null));
    if (reference) |value| {
        try validateReference(value);
        try writer.writeInt(u64, value.id, .little);
        try writer.writeInt(u32, value.bytes, .little);
        try writer.writeAll(&value.digest);
        try writer.writeByte(value.height);
        try writer.writeInt(u64, value.entries, .little);
    }
}
pub fn readReference(reader: *std.Io.Reader) !?Reference {
    switch (try reader.takeByte()) {
        0 => return null,
        1 => {},
        else => return error.InvalidRelationalIndex,
    }
    const value: Reference = .{ .id = try reader.takeInt(u64, .little), .bytes = try reader.takeInt(u32, .little), .digest = (try reader.takeArray(32)).*, .height = try reader.takeByte(), .entries = try reader.takeInt(u64, .little) };
    try validateReference(value);
    return value;
}
pub fn writeOptional(writer: *std.Io.Writer, value: ?i64) !void {
    try writer.writeByte(@intFromBool(value != null));
    try writer.writeInt(i64, value orelse 0, .little);
}
pub fn readOptional(reader: *std.Io.Reader) !?i64 {
    const present = try reader.takeByte();
    const value = try reader.takeInt(i64, .little);
    if (present > 1 or (present == 0 and value != 0)) return error.InvalidRelationalIndex;
    return if (present == 0) null else value;
}

test {
    _ = @import("relational_index_test.zig");
}
