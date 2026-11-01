//! Paged observed-remove map trees. All retained records live in the supplied
//! immutable index; a candidate is private until its owner publishes it.
const std = @import("std");
const m = @import("LogicalChange.zig");
pub const chunk_bytes = 240;
pub fn CausalTree(comptime Index: type) type {
    return struct {
        const Self = @This();
        pub const Summary = struct { conflicts: u16 = 0 };
        pub const Limits = struct { depth: u16, conflicts: u16, steps: u32 };
        pub const Assignment = struct { object: m.Dot, field_hash: [32]u8, kind: m.Kind, bytes: u32, depth: u16 };
        pub const Field = struct { count: u32, name_bytes: u32 };
        index: Index = .{},
        summary: Summary = .{},
        work: u32 = 0,
        limits: Limits,

        fn tick(self: *Self) !void {
            if (self.work == self.limits.steps) return error.DocumentEvaluationBudget;
            self.work += 1;
        }
        fn get(self: *Self, store: anytype, key: Index.Key) !?Index.Value {
            try self.tick();
            return self.index.get(store, key);
        }
        fn put(self: *Self, store: anytype, key: Index.Key, value: []const u8) !void {
            try self.tick();
            self.index = try self.index.put(store, key, try Index.Value.init(value));
        }
        pub fn dotKey(tag: u8, dot: m.Dot) !Index.Key {
            var bytes: [27]u8 = undefined;
            bytes[0] = tag;
            bytes[1..].* = dot.bytes();
            return Index.Key.init(&bytes);
        }
        pub fn fieldKey(object: m.Dot, name: []const u8) !Index.Key {
            var bytes: [59]u8 = undefined;
            bytes[0] = 'F';
            bytes[1..27].* = object.bytes();
            bytes[27..59].* = m.hash(name);
            return Index.Key.init(&bytes);
        }
        pub fn partKey(tag: u8, base: Index.Key, offset: u32) !Index.Key {
            if (base.len > 123) return error.InvalidLogicalState;
            var bytes: [128]u8 = undefined;
            bytes[0] = tag;
            @memcpy(bytes[1..][0..base.len], base.slice());
            std.mem.writeInt(u32, bytes[1 + base.len ..][0..4], offset, .big);
            return Index.Key.init(bytes[0 .. 5 + base.len]);
        }
        fn chunks(self: *Self, store: anytype, tag: u8, base: Index.Key, bytes: []const u8) !void {
            var at: usize = 0;
            while (at < bytes.len) : (at += chunk_bytes) try self.put(store, try partKey(tag, base, @intCast(at / chunk_bytes)), bytes[at..@min(at + chunk_bytes, bytes.len)]);
        }
        fn sameChunks(self: *Self, store: anytype, tag: u8, base: Index.Key, bytes: []const u8) !void {
            var at: usize = 0;
            while (at < bytes.len) : (at += chunk_bytes) {
                const value = try self.get(store, try partKey(tag, base, @intCast(at / chunk_bytes))) orelse return error.InvalidLogicalState;
                if (!std.mem.eql(u8, value.slice(), bytes[at..@min(at + chunk_bytes, bytes.len)])) return error.DocumentKeyCollision;
            }
        }
        pub fn decodeField(value: Index.Value) !Field {
            if (value.len != 8) return error.InvalidLogicalState;
            return .{ .count = std.mem.readInt(u32, value.data[0..4], .big), .name_bytes = std.mem.readInt(u32, value.data[4..8], .big) };
        }
        pub fn decodeAssignment(value: Index.Value) !Assignment {
            if (value.len != 65) return error.InvalidLogicalState;
            return .{ .object = m.Dot.fromBytes(value.data[0..26]), .field_hash = value.data[26..58].*, .kind = std.enums.fromInt(m.Kind, value.data[58]) orelse return error.InvalidLogicalState, .bytes = std.mem.readInt(u32, value.data[59..63], .big), .depth = std.mem.readInt(u16, value.data[63..65], .big) };
        }
        fn assignment(self: *Self, store: anytype, dot: m.Dot) !Assignment {
            return decodeAssignment(try self.get(store, try dotKey('A', dot)) orelse return error.DocumentDependencyMissing);
        }
        fn active(self: *Self, store: anytype, field: Index.Key, ordinal: u32) !m.Dot {
            const value = try self.get(store, try partKey('R', field, ordinal)) orelse return error.InvalidLogicalState;
            if (value.len != 26) return error.InvalidLogicalState;
            return m.Dot.fromBytes(value.data[0..26]);
        }
        fn depth(self: *Self, store: anytype, object: m.Dot) !u16 {
            if (object.eql(.root)) return 0;
            const a = try self.assignment(store, object);
            if (a.kind != .map) return error.DocumentTypeError;
            return a.depth;
        }
        pub const Status = enum { value, null_value, missing, type_error, conflict };
        pub const View = struct { status: Status, slot: ?Index.Key = null, count: u32 = 0 };
        pub fn lookup(self: *Self, store: anytype, path: []const []const u8) !View {
            if (path.len == 0 or path.len > self.limits.depth) return error.DocumentPathCapacity;
            var object: m.Dot = .root;
            for (path, 0..) |name, i| {
                if (name.len == 0 or !std.unicode.utf8ValidateSlice(name)) return error.InvalidLogicalOperation;
                const slot = try fieldKey(object, name);
                const value = try self.get(store, slot) orelse return .{ .status = .missing };
                const metadata = try decodeField(value);
                if (metadata.name_bytes != name.len) return error.DocumentKeyCollision;
                try self.sameChunks(store, 'N', slot, name);
                if (metadata.count == 0) return .{ .status = .missing };
                if (metadata.count > 1) return .{ .status = .conflict, .slot = slot, .count = metadata.count };
                const dot = try self.active(store, slot, 0);
                const assigned = try self.assignment(store, dot);
                if (i + 1 == path.len) return .{ .status = if (assigned.kind == .null_value) .null_value else .value, .slot = slot, .count = 1 };
                if (assigned.kind != .map) return .{ .status = .type_error };
                object = dot;
            }
            unreachable;
        }
        pub fn assignmentAt(self: *Self, store: anytype, slot: Index.Key, ordinal: u32) !struct { dot: m.Dot, value: Assignment } {
            const dot = try self.active(store, slot, ordinal);
            return .{ .dot = dot, .value = try self.assignment(store, dot) };
        }
        pub fn valueChunk(self: *Self, store: anytype, dot: m.Dot, chunk: u32) !Index.Value {
            return try self.get(store, try partKey('V', try dotKey('A', dot), chunk)) orelse error.InvalidLogicalState;
        }
        fn observes(observed: []const u8, id: m.Dot) bool {
            var at: usize = 0;
            while (at < observed.len) : (at += 26) if (std.mem.eql(u8, observed[at..][0..26], &id.bytes())) return true;
            return false;
        }
        /// Keeps detached descendants and assignment evidence. Replacing a map
        /// creates a new object dot; old descendants cannot attach to it.
        pub fn applyOperation(self: *Self, store: anytype, id: m.Dot, op: m.Operation) !void {
            try op.validate();
            try id.validate(false);
            const next_depth = std.math.add(u16, try self.depth(store, op.object), 1) catch return error.DocumentPathCapacity;
            if (next_depth > self.limits.depth) return error.DocumentPathCapacity;
            const slot = try fieldKey(op.object, op.field);
            const old = if (try self.get(store, slot)) |v| try decodeField(v) else Field{ .count = 0, .name_bytes = 0 };
            if (old.name_bytes != 0) {
                if (old.name_bytes != op.field.len) return error.DocumentKeyCollision;
                try self.sameChunks(store, 'N', slot, op.field);
            } else try self.chunks(store, 'N', slot, op.field);
            var at: usize = 0;
            while (at < op.observed.len) : (at += 26) {
                const a = try self.assignment(store, m.Dot.fromBytes(op.observed[at..][0..26]));
                if (!a.object.eql(op.object) or !std.mem.eql(u8, &a.field_hash, slot.data[27..59])) return error.DocumentWrongDependency;
            }
            const before = self.index;
            var survivors: u32 = 0;
            // Read a stable candidate prefix while compacting active dots. This
            // work depends on concurrent assignments, never all removed history.
            for (0..old.count) |i| {
                const saved = self.index;
                self.index = before;
                const dot = try self.active(store, slot, @intCast(i));
                self.index = saved;
                if (!observes(op.observed, dot)) {
                    try self.put(store, try partKey('R', slot, survivors), &dot.bytes());
                    survivors += 1;
                }
            }
            const count = survivors + @as(u32, @intFromBool(op.value != null));
            const prior_conflicts = old.count -| 1;
            if (prior_conflicts > self.summary.conflicts) return error.InvalidLogicalState;
            const next_conflicts = @as(u32, self.summary.conflicts) - prior_conflicts + (count -| 1);
            if (next_conflicts > self.limits.conflicts) return error.DocumentConflictCapacity;
            if (op.value) |value| {
                if (try self.get(store, try dotKey('A', id)) != null) return error.DocumentIdentityConflict;
                // Insert into the active vector in full-dot lexical order.
                var pos = survivors;
                while (pos > 0) {
                    const preceding = try self.active(store, slot, pos - 1);
                    if (std.mem.order(u8, &preceding.bytes(), &id.bytes()) == .lt) break;
                    try self.put(store, try partKey('R', slot, pos), &preceding.bytes());
                    pos -= 1;
                }
                try self.put(store, try partKey('R', slot, pos), &id.bytes());
                var bytes: [65]u8 = undefined;
                bytes[0..26].* = op.object.bytes();
                bytes[26..58].* = slot.data[27..59].*;
                bytes[58] = @backingInt(value.kind);
                std.mem.writeInt(u32, bytes[59..63], @intCast(value.bytes.len), .big);
                std.mem.writeInt(u16, bytes[63..65], next_depth, .big);
                const key = try dotKey('A', id);
                try self.put(store, key, &bytes);
                try self.chunks(store, 'V', key, value.bytes);
            }
            var metadata: [8]u8 = undefined;
            std.mem.writeInt(u32, metadata[0..4], count, .big);
            std.mem.writeInt(u32, metadata[4..8], @intCast(op.field.len), .big);
            try self.put(store, slot, &metadata);
            self.summary.conflicts = @intCast(next_conflicts);
        }
    };
}
