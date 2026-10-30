//! Five-state cell algebra (`value`, `null_value`, `missing`, `type_error`,
//! `conflict`), raw-frame provenance anchors, deterministic three-way structural
//! tree merges (`versioned` merge profile), path evaluation, and `SuccinctTree`
//! topology lowering.
const std = @import("std");
const SuccinctTree = @import("SuccinctTree.zig").SuccinctTree;

pub const Error = error{
    InvalidProvenanceSpan,
    OutOfMemory,
    EmptySuccinctTree,
    InvalidSuccinctTree,
    NodeOutOfBounds,
    TreeTooLarge,
};

pub const CellState = enum(u8) {
    value = 1,
    null_value = 2,
    missing = 3,
    type_error = 4,
    conflict = 5,
};

pub const RawProvenance = struct {
    part_id: u32,
    byte_start: u32,
    byte_end: u32,

    pub fn validate(self: RawProvenance) Error!void {
        if (self.part_id == 0 or self.byte_end < self.byte_start) {
            return error.InvalidProvenanceSpan;
        }
    }
};

pub const Scalar = union(enum) {
    boolean: bool,
    int64: i64,
    float64: f64,
    string: []const u8,
    bytes: []const u8,

    pub fn eql(self: Scalar, other: Scalar) bool {
        if (std.meta.activeTag(self) != std.meta.activeTag(other)) return false;
        return switch (self) {
            .boolean => |v| v == other.boolean,
            .int64 => |v| v == other.int64,
            .float64 => |v| @as(u64, @bitCast(v)) == @as(u64, @bitCast(other.float64)),
            .string => |v| std.mem.eql(u8, v, other.string),
            .bytes => |v| std.mem.eql(u8, v, other.bytes),
        };
    }

    pub fn order(self: Scalar, other: Scalar) std.math.Order {
        const tag_a = @intFromEnum(std.meta.activeTag(self));
        const tag_b = @intFromEnum(std.meta.activeTag(other));
        if (tag_a != tag_b) return std.math.order(tag_a, tag_b);
        return switch (self) {
            .boolean => |v| std.math.order(@intFromBool(v), @intFromBool(other.boolean)),
            .int64 => |v| std.math.order(v, other.int64),
            .float64 => |v| std.math.order(@as(u64, @bitCast(v)), @as(u64, @bitCast(other.float64))),
            .string => |v| std.mem.order(u8, v, other.string),
            .bytes => |v| std.mem.order(u8, v, other.bytes),
        };
    }

    pub fn clone(self: Scalar, allocator: std.mem.Allocator) Error!Scalar {
        return switch (self) {
            .boolean => |v| .{ .boolean = v },
            .int64 => |v| .{ .int64 = v },
            .float64 => |v| .{ .float64 = v },
            .string => |v| .{ .string = try allocator.dupe(u8, v) },
            .bytes => |v| .{ .bytes = try allocator.dupe(u8, v) },
        };
    }

    pub fn deinit(self: Scalar, allocator: std.mem.Allocator) void {
        switch (self) {
            .string => |v| allocator.free(v),
            .bytes => |v| allocator.free(v),
            else => {},
        }
    }
};

pub const Cell = union(CellState) {
    value: Scalar,
    null_value: void,
    missing: void,
    type_error: []const u8,
    conflict: []const Scalar,
};

pub const Field = struct {
    name: []const u8,
    value: Node,
};

pub const Node = struct {
    kind: Kind,
    provenance: ?RawProvenance = null,

    pub const Kind = union(enum) {
        scalar: Scalar,
        null_value: void,
        type_error: []const u8,
        conflict: []Scalar,
        object: []Field,
        array: []Node,
    };

    pub fn deinit(self: *Node, allocator: std.mem.Allocator) void {
        switch (self.kind) {
            .scalar => |s| s.deinit(allocator),
            .null_value => {},
            .type_error => |msg| allocator.free(msg),
            .conflict => |items| {
                for (items) |s| s.deinit(allocator);
                allocator.free(items);
            },
            .object => |fields| {
                for (fields) |*f| {
                    allocator.free(f.name);
                    f.value.deinit(allocator);
                }
                allocator.free(fields);
            },
            .array => |elements| {
                for (elements) |*el| el.deinit(allocator);
                allocator.free(elements);
            },
        }
        self.* = undefined;
    }

    pub fn eql(self: *const Node, other: *const Node) bool {
        if (std.meta.activeTag(self.kind) != std.meta.activeTag(other.kind)) return false;
        return switch (self.kind) {
            .scalar => |s| s.eql(other.kind.scalar),
            .null_value => true,
            .type_error => |msg| std.mem.eql(u8, msg, other.kind.type_error),
            .conflict => |items| {
                const other_items = other.kind.conflict;
                if (items.len != other_items.len) return false;
                for (items, other_items) |a, b| {
                    if (!a.eql(b)) return false;
                }
                return true;
            },
            .object => |fields| {
                const other_fields = other.kind.object;
                if (fields.len != other_fields.len) return false;
                for (fields, other_fields) |a, b| {
                    if (!std.mem.eql(u8, a.name, b.name) or !a.value.eql(&b.value)) return false;
                }
                return true;
            },
            .array => |elements| {
                const other_elements = other.kind.array;
                if (elements.len != other_elements.len) return false;
                for (elements, other_elements) |*a, *b| {
                    if (!a.eql(b)) return false;
                }
                return true;
            },
        };
    }

    pub fn clone(self: *const Node, allocator: std.mem.Allocator) Error!Node {
        if (self.provenance) |prov| try prov.validate();
        const cloned_kind: Kind = switch (self.kind) {
            .scalar => |s| .{ .scalar = try s.clone(allocator) },
            .null_value => .null_value,
            .type_error => |msg| .{ .type_error = try allocator.dupe(u8, msg) },
            .conflict => |items| blk: {
                const out = try allocator.alloc(Scalar, items.len);
                var initialized: usize = 0;
                errdefer {
                    for (out[0..initialized]) |s| s.deinit(allocator);
                    allocator.free(out);
                }
                for (items, 0..) |item, i| {
                    out[i] = try item.clone(allocator);
                    initialized += 1;
                }
                break :blk .{ .conflict = out };
            },
            .object => |fields| blk: {
                const out = try allocator.alloc(Field, fields.len);
                var initialized: usize = 0;
                errdefer {
                    for (out[0..initialized]) |*f| {
                        allocator.free(f.name);
                        f.value.deinit(allocator);
                    }
                    allocator.free(out);
                }
                for (fields, 0..) |f, i| {
                    const name_copy = try allocator.dupe(u8, f.name);
                    errdefer allocator.free(name_copy);
                    const val_copy = try f.value.clone(allocator);
                    out[i] = .{ .name = name_copy, .value = val_copy };
                    initialized += 1;
                }
                std.mem.sort(Field, out, {}, struct {
                    fn lessThan(_: void, a: Field, b: Field) bool {
                        return std.mem.order(u8, a.name, b.name) == .lt;
                    }
                }.lessThan);
                break :blk .{ .object = out };
            },
            .array => |elements| blk: {
                const out = try allocator.alloc(Node, elements.len);
                var initialized: usize = 0;
                errdefer {
                    for (out[0..initialized]) |*el| el.deinit(allocator);
                    allocator.free(out);
                }
                for (elements, 0..) |*el, i| {
                    out[i] = try el.clone(allocator);
                    initialized += 1;
                }
                break :blk .{ .array = out };
            },
        };
        return .{
            .kind = cloned_kind,
            .provenance = self.provenance,
        };
    }

    pub fn countConflicts(self: *const Node) u32 {
        return switch (self.kind) {
            .scalar, .null_value, .type_error => 0,
            .conflict => 1,
            .object => |fields| blk: {
                var total: u32 = 0;
                for (fields) |*f| total += f.value.countConflicts();
                break :blk total;
            },
            .array => |elements| blk: {
                var total: u32 = 0;
                for (elements) |*el| total += el.countConflicts();
                break :blk total;
            },
        };
    }

    pub fn computeDigest(self: *const Node) [32]u8 {
        var hasher = std.crypto.hash.sha2.Sha256.init(.{});
        self.hashInto(&hasher);
        var digest: [32]u8 = undefined;
        hasher.final(&digest);
        return digest;
    }

    fn hashInto(self: *const Node, hasher: *std.crypto.hash.sha2.Sha256) void {
        if (self.provenance) |prov| {
            hasher.update(&.{1});
            var buf: [12]u8 = undefined;
            std.mem.writeInt(u32, buf[0..4], prov.part_id, .big);
            std.mem.writeInt(u32, buf[4..8], prov.byte_start, .big);
            std.mem.writeInt(u32, buf[8..12], prov.byte_end, .big);
            hasher.update(&buf);
        } else {
            hasher.update(&.{0});
        }
        switch (self.kind) {
            .scalar => |s| {
                hasher.update("S");
                hashScalar(hasher, s);
            },
            .null_value => hasher.update("N"),
            .type_error => |msg| {
                hasher.update("E");
                hashBytes(hasher, msg);
            },
            .conflict => |items| {
                hasher.update("C");
                var len_buf: [4]u8 = undefined;
                std.mem.writeInt(u32, &len_buf, @intCast(items.len), .big);
                hasher.update(&len_buf);
                for (items) |s| hashScalar(hasher, s);
            },
            .object => |fields| {
                hasher.update("O");
                var len_buf: [4]u8 = undefined;
                std.mem.writeInt(u32, &len_buf, @intCast(fields.len), .big);
                hasher.update(&len_buf);
                for (fields) |*f| {
                    hashBytes(hasher, f.name);
                    f.value.hashInto(hasher);
                }
            },
            .array => |elements| {
                hasher.update("A");
                var len_buf: [4]u8 = undefined;
                std.mem.writeInt(u32, &len_buf, @intCast(elements.len), .big);
                hasher.update(&len_buf);
                for (elements) |*el| el.hashInto(hasher);
            },
        }
    }
};

pub const MergeResult = struct {
    root: Node,
    unresolved_conflicts: u32,
    state_sha256: [32]u8,

    pub fn deinit(self: *MergeResult, allocator: std.mem.Allocator) void {
        self.root.deinit(allocator);
        self.* = undefined;
    }
};

/// Performs a deterministic three-way structural merge (`base`, `ours`, `theirs`),
/// using `scratch` for intermediate candidate lists and `output` for the retained
/// merged `Node`. Commutative across `ours` and `theirs`.
pub fn mergeThreeWay(
    output: std.mem.Allocator,
    scratch: std.mem.Allocator,
    base: ?*const Node,
    ours: *const Node,
    theirs: *const Node,
) Error!MergeResult {
    var root = try mergeNodes(output, scratch, base, ours, theirs);
    errdefer root.deinit(output);
    const conflicts = root.countConflicts();
    const digest = root.computeDigest();
    return .{
        .root = root,
        .unresolved_conflicts = conflicts,
        .state_sha256 = digest,
    };
}

/// Evaluates `path` over `root` under five-state semantics (`value`, `null_value`,
/// `missing`, `type_error`, `conflict`).
pub fn evaluatePath(root: *const Node, path: []const []const u8) Cell {
    var current: *const Node = root;
    for (path) |segment| {
        switch (current.kind) {
            .object => |fields| {
                var found: ?*const Node = null;
                for (fields) |*f| {
                    if (std.mem.eql(u8, f.name, segment)) {
                        found = &f.value;
                        break;
                    }
                }
                current = found orelse return .missing;
            },
            .type_error => |msg| return .{ .type_error = msg },
            else => return .{ .type_error = "not_an_object" },
        }
    }
    return switch (current.kind) {
        .scalar => |s| .{ .value = s },
        .null_value => .null_value,
        .type_error => |msg| .{ .type_error = msg },
        .conflict => |items| .{ .conflict = items },
        .object => .{ .type_error = "non_scalar_object" },
        .array => .{ .type_error = "non_scalar_array" },
    };
}

/// Lowers the structural topology of `root` into a `SuccinctTree` in preorder.
pub fn buildSuccinctTree(
    output: std.mem.Allocator,
    scratch: std.mem.Allocator,
    root: *const Node,
) Error!SuccinctTree {
    var parents: std.ArrayListUnmanaged(?u32) = .empty;
    try appendPreorderParents(scratch, &parents, root, null);
    return SuccinctTree.fromParentSlice(output, scratch, parents.items);
}

fn appendPreorderParents(
    scratch: std.mem.Allocator,
    parents: *std.ArrayListUnmanaged(?u32),
    node: *const Node,
    parent_idx: ?u32,
) Error!void {
    const my_idx: u32 = @intCast(parents.items.len);
    try parents.append(scratch, parent_idx);
    switch (node.kind) {
        .object => |fields| {
            for (fields) |*f| {
                try appendPreorderParents(scratch, parents, &f.value, my_idx);
            }
        },
        .array => |elements| {
            for (elements) |*el| {
                try appendPreorderParents(scratch, parents, el, my_idx);
            }
        },
        else => {},
    }
}

fn mergeNodes(
    output: std.mem.Allocator,
    scratch: std.mem.Allocator,
    base: ?*const Node,
    ours: *const Node,
    theirs: *const Node,
) Error!Node {
    if (ours.eql(theirs)) {
        return ours.clone(output);
    }
    if (base) |b| {
        if (ours.eql(b)) return theirs.clone(output);
        if (theirs.eql(b)) return ours.clone(output);
    }

    // Both branches diverged from `base` and from each other.
    if (ours.kind == .object and theirs.kind == .object) {
        const base_obj: ?[]const Field = if (base != null and base.?.kind == .object)
            base.?.kind.object
        else
            null;
        return mergeObjects(output, scratch, base_obj, ours.kind.object, theirs.kind.object);
    }

    // Conflicting leaf or incompatible structural kinds -> explicit conflict cell.
    var candidates: std.ArrayListUnmanaged(Scalar) = .empty;
    try collectConflictScalars(scratch, &candidates, ours);
    try collectConflictScalars(scratch, &candidates, theirs);

    std.mem.sort(Scalar, candidates.items, {}, struct {
        fn lessThan(_: void, a: Scalar, b: Scalar) bool {
            return a.order(b) == .lt;
        }
    }.lessThan);

    // Deduplicate equal scalars.
    var unique_count: usize = 0;
    for (candidates.items) |item| {
        if (unique_count == 0 or !candidates.items[unique_count - 1].eql(item)) {
            candidates.items[unique_count] = item;
            unique_count += 1;
        }
    }

    const out_conflicts = try output.alloc(Scalar, unique_count);
    var initialized: usize = 0;
    errdefer {
        for (out_conflicts[0..initialized]) |s| s.deinit(output);
        output.free(out_conflicts);
    }
    for (candidates.items[0..unique_count], 0..) |item, i| {
        out_conflicts[i] = try item.clone(output);
        initialized += 1;
    }
    return .{ .kind = .{ .conflict = out_conflicts } };
}

fn mergeObjects(
    output: std.mem.Allocator,
    scratch: std.mem.Allocator,
    base_fields: ?[]const Field,
    our_fields: []const Field,
    their_fields: []const Field,
) Error!Node {
    var names: std.ArrayListUnmanaged([]const u8) = .empty;
    if (base_fields) |bf| {
        for (bf) |f| try names.append(scratch, f.name);
    }
    for (our_fields) |f| try names.append(scratch, f.name);
    for (their_fields) |f| try names.append(scratch, f.name);

    std.mem.sort([]const u8, names.items, {}, struct {
        fn lessThan(_: void, a: []const u8, b: []const u8) bool {
            return std.mem.order(u8, a, b) == .lt;
        }
    }.lessThan);

    var merged_fields: std.ArrayListUnmanaged(Field) = .empty;
    errdefer {
        for (merged_fields.items) |*f| {
            output.free(f.name);
            f.value.deinit(output);
        }
        merged_fields.deinit(output);
    }

    var prev_name: ?[]const u8 = null;
    for (names.items) |name| {
        if (prev_name != null and std.mem.eql(u8, prev_name.?, name)) continue;
        prev_name = name;

        const b_node = if (base_fields) |bf| findField(bf, name) else null;
        const o_node = findField(our_fields, name);
        const t_node = findField(their_fields, name);

        if (o_node != null and t_node != null) {
            var child = try mergeNodes(output, scratch, b_node, o_node.?, t_node.?);
            errdefer child.deinit(output);
            const name_copy = try output.dupe(u8, name);
            errdefer output.free(name_copy);
            try merged_fields.append(output, .{ .name = name_copy, .value = child });
        } else if (o_node != null and t_node == null) {
            // `theirs` lacks `name`. If `base` had `name` and `ours` is unchanged,
            // `theirs` deleted it; if `base` lacked `name`, `ours` added it; if
            // `base` had `name` and `ours` modified it while `theirs` deleted it,
            // preserve `ours`'s modification as a conflict against `"<deleted>"`.
            if (b_node == null) {
                var child = try o_node.?.clone(output);
                errdefer child.deinit(output);
                const name_copy = try output.dupe(u8, name);
                errdefer output.free(name_copy);
                try merged_fields.append(output, .{ .name = name_copy, .value = child });
            } else if (!o_node.?.eql(b_node.?)) {
                const deleted_node: Node = .{ .kind = .{ .scalar = .{ .string = "<deleted>" } } };
                var child = try mergeNodes(output, scratch, b_node, o_node.?, &deleted_node);
                errdefer child.deinit(output);
                const name_copy = try output.dupe(u8, name);
                errdefer output.free(name_copy);
                try merged_fields.append(output, .{ .name = name_copy, .value = child });
            }
        } else if (o_node == null and t_node != null) {
            if (b_node == null) {
                var child = try t_node.?.clone(output);
                errdefer child.deinit(output);
                const name_copy = try output.dupe(u8, name);
                errdefer output.free(name_copy);
                try merged_fields.append(output, .{ .name = name_copy, .value = child });
            } else if (!t_node.?.eql(b_node.?)) {
                const deleted_node: Node = .{ .kind = .{ .scalar = .{ .string = "<deleted>" } } };
                var child = try mergeNodes(output, scratch, b_node, &deleted_node, t_node.?);
                errdefer child.deinit(output);
                const name_copy = try output.dupe(u8, name);
                errdefer output.free(name_copy);
                try merged_fields.append(output, .{ .name = name_copy, .value = child });
            }
        }
    }

    return .{ .kind = .{ .object = try merged_fields.toOwnedSlice(output) } };
}

fn findField(fields: []const Field, name: []const u8) ?*const Node {
    for (fields) |*f| {
        if (std.mem.eql(u8, f.name, name)) return &f.value;
    }
    return null;
}

fn collectConflictScalars(
    scratch: std.mem.Allocator,
    list: *std.ArrayListUnmanaged(Scalar),
    node: *const Node,
) Error!void {
    switch (node.kind) {
        .scalar => |s| try list.append(scratch, s),
        .null_value => try list.append(scratch, .{ .string = "null" }),
        .type_error => |msg| try list.append(scratch, .{ .string = msg }),
        .conflict => |items| try list.appendSlice(scratch, items),
        .object => try list.append(scratch, .{ .string = "<object>" }),
        .array => try list.append(scratch, .{ .string = "<array>" }),
    }
}

fn hashScalar(hasher: *std.crypto.hash.sha2.Sha256, s: Scalar) void {
    switch (s) {
        .boolean => |v| hasher.update(if (v) "B1" else "B0"),
        .int64 => |v| {
            hasher.update("I");
            var buf: [8]u8 = undefined;
            std.mem.writeInt(i64, &buf, v, .big);
            hasher.update(&buf);
        },
        .float64 => |v| {
            hasher.update("F");
            var buf: [8]u8 = undefined;
            std.mem.writeInt(u64, &buf, @bitCast(v), .big);
            hasher.update(&buf);
        },
        .string => |v| {
            hasher.update("T");
            hashBytes(hasher, v);
        },
        .bytes => |v| {
            hasher.update("Y");
            hashBytes(hasher, v);
        },
    }
}

fn hashBytes(hasher: *std.crypto.hash.sha2.Sha256, bytes: []const u8) void {
    var len_buf: [4]u8 = undefined;
    std.mem.writeInt(u32, &len_buf, @intCast(bytes.len), .big);
    hasher.update(&len_buf);
    hasher.update(bytes);
}
