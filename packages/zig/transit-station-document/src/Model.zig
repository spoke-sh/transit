const std = @import("std");
const Index = @import("transit_station").ImmutableIndex;
pub const format: u32 = 1;
pub const max_operations = 8;
pub const max_conflicts = 8;
pub const max_change_bytes = 4096;
pub const Name = Index.Bytes(64);
pub const Bytes = Index.Bytes(96);
pub const Kind = enum(u8) { map = 1, list = 2, text = 3 };
pub const Dot = struct {
    counter: u64 = 0,
    replica: u64 = 0,
    pub const root: Dot = .{};
    pub fn eql(a: Dot, b: Dot) bool {
        return a.counter == b.counter and a.replica == b.replica;
    }
    pub fn order(a: Dot, b: Dot) std.math.Order {
        const counter_order = std.math.order(a.counter, b.counter);
        return if (counter_order == .eq) std.math.order(a.replica, b.replica) else counter_order;
    }
    pub fn validate(self: Dot, allow_root: bool) !void {
        if (allow_root and self.eql(.root)) return;
        if (self.counter == 0 or self.replica == 0) return error.InvalidDocumentIdentity;
    }
};
pub const Scalar = union(enum(u8)) {
    null_value = 0,
    boolean: bool,
    signed: i64,
    unsigned: u64,
    float: f64,
    string: Bytes,
    binary: Bytes,
    map,
    list,
    text,
    character: u32,
    pub fn kind(self: Scalar) ?Kind {
        return switch (self) {
            .map => .map,
            .list => .list,
            .text => .text,
            else => null,
        };
    }
    pub fn validate(self: Scalar) !void {
        switch (self) {
            .float => |v| if (!std.math.isFinite(v)) return error.InvalidDocumentScalar,
            .string => |v| {
                try v.validate(false);
                if (!std.unicode.utf8ValidateSlice(v.slice())) return error.InvalidDocumentUnicode;
            },
            .binary => |v| try v.validate(false),
            .character => |v| if (v > 0x10ffff or (v >= 0xd800 and v <= 0xdfff)) return error.InvalidDocumentUnicode,
            else => {},
        }
    }
};
pub const Observed = struct {
    len: u8 = 0,
    dots: [max_conflicts]Dot = @splat(.root),
    pub fn init(dots: []const Dot) !Observed {
        if (dots.len > max_conflicts) return error.DocumentConflictCapacity;
        var out: Observed = .{ .len = @intCast(dots.len) };
        @memcpy(out.dots[0..dots.len], dots);
        return out;
    }
    pub fn slice(self: *const Observed) []const Dot {
        return self.dots[0..self.len];
    }
    pub fn validate(self: Observed, before: Dot) !void {
        if (self.len > max_conflicts) return error.InvalidDocumentObserved;
        var previous: ?Dot = null;
        for (self.slice()) |dot| {
            try dependency(dot, before, false);
            if (previous) |p| if (p.order(dot) != .lt) return error.InvalidDocumentObserved;
            previous = dot;
        }
    }
    pub fn contains(self: *const Observed, dot: Dot) bool {
        for (self.slice()) |item| if (item.eql(dot)) return true;
        return false;
    }
};
pub const Operation = union(enum(u8)) {
    assign: struct { object: Dot = .root, field: Name, observed: Observed = .{}, value: Scalar },
    remove: struct { object: Dot = .root, field: Name, observed: Observed },
    insert: struct { object: Dot, after: Dot = .root, value: Scalar },
    set_element: struct { object: Dot, element: Dot, observed: Observed, value: Scalar },
    delete_element: struct { object: Dot, element: Dot },
    pub fn validate(self: Operation, id: Dot) !void {
        switch (self) {
            inline else => |op, tag| {
                try dependency(op.object, id, true);
                if (comptime tag == .assign or tag == .remove) {
                    try op.field.validate(true);
                    if (!std.unicode.utf8ValidateSlice(op.field.slice())) return error.InvalidDocumentUnicode;
                }
                if (@hasField(@TypeOf(op), "observed")) try op.observed.validate(id);
                if (@hasField(@TypeOf(op), "element")) try dependency(op.element, id, false);
                if (@hasField(@TypeOf(op), "after")) try dependency(op.after, id, true);
                if (@hasField(@TypeOf(op), "value")) try op.value.validate();
            },
        }
    }
};
fn dependency(dot: Dot, before: Dot, allow_root: bool) !void {
    try dot.validate(allow_root);
    if (dot.counter >= before.counter) return error.InvalidDocumentCausality;
}
pub const Change = struct {
    document: u64,
    epoch: u64,
    type_revision: u32 = 1,
    replica: u64,
    previous: u64 = 0,
    first: u64,
    len: u8,
    operations: [max_operations]Operation = undefined,
    pub fn id(self: Change, offset: usize) Dot {
        return .{ .replica = self.replica, .counter = self.first + offset };
    }
    pub fn last(self: Change) u64 {
        return self.first + self.len - 1;
    }
    pub fn validate(self: Change) !void {
        if (self.document == 0 or self.epoch == 0 or self.type_revision == 0 or self.replica == 0 or self.first == 0 or self.len == 0 or self.len > max_operations) return error.InvalidDocumentChange;
        if (self.first <= self.previous or self.first > std.math.maxInt(u64) - @as(u64, self.len - 1)) return error.InvalidDocumentCausality;
        for (self.operations[0..self.len], 0..) |op, i| try op.validate(self.id(i));
    }
};
test "Document Unicode and causal identities are explicit" {
    const t = std.testing;
    try (Scalar{ .character = 0x1f642 }).validate();
    try t.expectError(error.InvalidDocumentUnicode, (Scalar{ .character = 0xd800 }).validate());
    try t.expectError(error.InvalidDocumentUnicode, (Scalar{ .string = try Bytes.init("\xff") }).validate());
    try t.expectError(error.InvalidDocumentScalar, (Scalar{ .float = std.math.nan(f64) }).validate());
    const observed = try Observed.init(&.{ .{ .counter = 2, .replica = 1 }, .{ .counter = 1, .replica = 1 } });
    try t.expectError(error.InvalidDocumentObserved, observed.validate(.{ .counter = 3, .replica = 2 }));
}
