//! Immutable AVL group state. A host stages bounded candidate records and
//! atomically publishes the returned root with operator/input progress.
//! Allocation uses the host's bounded workspace; storage and authority are external.
const std = @import("std");
const r = @import("Relational.zig");
const e = @import("RelationalExecution.zig");
const values = @import("RelationalValues.zig");
const native = @import("transit_protocol").Growth;
const Self = @This();
pub const max_height = 94;
const fixed_record_bytes = 4 + 32 + 32 + 2 * 54 + 2 + r.max_groups * 9 + r.max_outputs * 25;
pub const max_record_bytes = fixed_record_bytes + values.max_text_bytes;
pub const max_candidate_records = 3 * max_height + 1;
const Node = struct { left: ?Reference = null, right: ?Reference = null, group: e.Group };
pub const resident_bytes = @sizeOf(Self) + max_height * (@sizeOf(Reference) + @sizeOf(bool)) + 6 * @sizeOf(Node) + 2 * fixed_record_bytes;
pub const Reference = struct {
    id: u64,
    bytes: u32,
    digest: [32]u8,
    height: u8,
    entries: u64,
};
allocator: std.mem.Allocator,
plan: r.Plan,
binding: [32]u8,
root: ?Reference = null,

pub fn init(allocator: std.mem.Allocator, bound: r.Bound, root: ?Reference) !Self {
    try bound.validate();
    if (bound.plan.budgets.resident_bytes < resident_bytes) return error.RelationalResidentBudget;
    if (root) |value| try validateReference(value);
    return .{ .allocator = allocator, .plan = bound.plan, .binding = try bound.fingerprint(), .root = root };
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
        var node = try self.load(store, reference);
        errdefer node.group.deinit();
        switch (try key.order(node.group.key, self.plan)) {
            .eq => return node.group,
            .lt => cursor = node.left,
            .gt => cursor = node.right,
        }
        node.group.deinit();
    }
    return null;
}
pub fn next(self: Self, store: anytype, after: ?e.Key) !?e.Group {
    if (after) |key| try self.checkKey(key);
    var cursor = self.root;
    var selected: ?e.Group = null;
    errdefer if (selected) |*group| group.deinit();
    var depth: usize = 0;
    while (cursor) |reference| : (depth += 1) {
        if (depth == max_height) return error.InvalidRelationalIndex;
        var node = try self.load(store, reference);
        errdefer node.group.deinit();
        if (after == null or try node.group.key.order(after.?, self.plan) == .gt) {
            if (selected) |*group| group.deinit();
            selected = node.group;
            cursor = node.left;
        } else {
            cursor = node.right;
            node.group.deinit();
        }
    }
    return selected;
}
pub fn put(self: *Self, store: anytype, group: e.Group) !void {
    try self.checkGroup(group);
    // Immutable parents can be loaded again while unwinding. Retaining only
    // references keeps variable-width group payloads out of the depth stack.
    var parents: [max_height]Reference = undefined;
    var left: [max_height]bool = undefined;
    var depth: usize = 0;
    var cursor = self.root;
    var replacement: Node = .{ .group = group };
    while (cursor) |reference| {
        if (depth == max_height) return error.InvalidRelationalIndex;
        var node = try self.load(store, reference);
        defer node.group.deinit();
        const order = try group.key.order(node.group.key, self.plan);
        if (order == .eq) {
            replacement.left = node.left;
            replacement.right = node.right;
            break;
        }
        parents[depth] = reference;
        left[depth] = order == .lt;
        depth += 1;
        cursor = if (order == .lt) node.left else node.right;
    }
    var next_root = try self.save(store, replacement);
    while (depth != 0) {
        depth -= 1;
        var parent = try self.load(store, parents[depth]);
        defer parent.group.deinit();
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
        var child = try self.load(store, node.left.?);
        defer child.group.deinit();
        if (height(child.left) < height(child.right)) node.left = try self.rotateLeft(store, child);
        return self.rotateRight(store, node);
    }
    if (difference < -1) {
        var child = try self.load(store, node.right.?);
        defer child.group.deinit();
        if (height(child.right) < height(child.left)) node.right = try self.rotateRight(store, child);
        return self.rotateLeft(store, node);
    }
    return self.save(store, node);
}
fn rotateLeft(self: Self, store: anytype, original: Node) !Reference {
    var node = original;
    var child = try self.load(store, node.right orelse return error.InvalidRelationalIndex);
    defer child.group.deinit();
    node.right = child.left;
    child.left = try self.save(store, node);
    return self.save(store, child);
}
fn rotateRight(self: Self, store: anytype, original: Node) !Reference {
    var node = original;
    var child = try self.load(store, node.left orelse return error.InvalidRelationalIndex);
    defer child.group.deinit();
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
    var payload: usize = 0;
    for (key.values[0..key.len], self.plan.group_by) |value, reference| {
        var column = try self.plan.resolveColumn(reference);
        column.nullable = true;
        try values.validate(value, column);
        if (value) |present| if (present == .text) {
            if (present.text.len > values.max_text_bytes - payload) return error.RelationalResidentBudget;
            payload += present.text.len;
        };
    }
    for (key.values[key.len..]) |value| if (value != null) return error.InvalidRelationalGroup;
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
    var length: usize = 4 + 32 + 32 + 2 + @as(usize, if (node.left != null) 54 else 1) + @as(usize, if (node.right != null) 54 else 1) + self.plan.outputs.len * 25;
    for (node.group.key.values[0..node.group.key.len]) |value| length += if (value) |present| switch (present) {
        .integer => 9,
        .text => |bytes| 5 + bytes.len,
    } else 1;
    var fixed: [fixed_record_bytes]u8 = undefined;
    const bytes = if (length <= fixed.len) fixed[0..length] else try self.allocator.alloc(u8, length);
    defer if (length > fixed.len) self.allocator.free(bytes);
    var output: std.Io.Writer = .fixed(bytes);
    const writer = &output;
    try writer.writeAll("FRN1");
    try writer.writeAll(&definition());
    try writer.writeAll(&self.binding);
    try writeReference(writer, node.left);
    try writeReference(writer, node.right);
    try writer.writeAll(&.{ node.group.key.len, @intCast(self.plan.outputs.len) });
    for (node.group.key.values[0..node.group.key.len]) |value| try values.write(writer, value);
    for (node.group.states[0..self.plan.outputs.len]) |state| {
        try writer.writeInt(u64, state.rows, .little);
        try writer.writeInt(u64, state.values, .little);
        try writeOptional(writer, state.sum);
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
    var fixed: [fixed_record_bytes]u8 = undefined;
    const buffer = if (reference.bytes <= fixed.len) fixed[0..reference.bytes] else try self.allocator.alloc(u8, reference.bytes);
    defer if (reference.bytes > fixed.len) self.allocator.free(buffer);
    const bytes = try store.read(reference.id, buffer);
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
    if (node.group.key.len != self.plan.group_by.len) return error.InvalidRelationalGroup;
    for (node.group.key.values[0..node.group.key.len]) |*value| value.* = try values.read(&reader);
    for (node.group.states[0..self.plan.outputs.len]) |*state| state.* = .{ .rows = try reader.takeInt(u64, .little), .values = try reader.takeInt(u64, .little), .sum = try readOptional(&reader) };
    try self.checkGroup(node.group);
    if (reader.bufferedLen() != 0 or @abs(height(node.left) - height(node.right)) > 1 or reference.height != 1 + @max(height(node.left), height(node.right)) or reference.entries != try std.math.add(u64, try std.math.add(u64, entries(node.left), entries(node.right)), 1)) return error.InvalidRelationalIndex;
    for ([_]?Reference{ node.left, node.right }) |child| if (child) |value| if (value.id >= reference.id) return error.InvalidRelationalIndex;
    node.group.key = try node.group.key.clone(self.allocator);
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
