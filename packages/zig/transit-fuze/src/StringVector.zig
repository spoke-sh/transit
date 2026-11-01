//! Lossless transient string lanes. Headers never cross a wire/storage boundary.
//! Short values retain their original bytes inline; long values borrow immutable
//! payloads from the batch or source owner and cache the declared sort prefix.
const std = @import("std");
const Collation = @import("Collation.zig");

pub const Value = extern struct {
    len: u32,
    payload: [12]u8,

    /// Input has passed the owning schema and collation validation boundary.
    /// Long payloads must remain immutable for the lifetime of this header.
    pub fn initValidated(input: []const u8, collation: Collation.Collation) Value {
        var result: Value = .{ .len = @intCast(input.len), .payload = @splat(0) };
        if (input.len <= 12) {
            @memcpy(result.payload[0..input.len], input);
        } else {
            result.payload[0..4].* = Collation.computeSortPrefix4B(input, collation) catch unreachable;
            std.mem.writeInt(u64, result.payload[4..12], @intFromPtr(input.ptr), .little);
        }
        return result;
    }

    /// The returned inline slice borrows this slot, so callers must not return a
    /// view into a temporary/by-value copy of the header.
    pub fn bytes(self: *const Value) []const u8 {
        if (self.len <= 12) return self.payload[0..self.len];
        const pointer: [*]const u8 = @ptrFromInt(std.mem.readInt(u64, self.payload[4..12], .little));
        return pointer[0..self.len];
    }

    pub fn prefix(self: *const Value, collation: Collation.Collation) [4]u8 {
        return if (self.len > 12) self.payload[0..4].* else Collation.computeSortPrefix4B(self.bytes(), collation) catch unreachable;
    }

    /// Both headers were created under this same immutable collation descriptor.
    pub fn order(left: *const Value, right: *const Value, collation: Collation.Collation) std.math.Order {
        const leading = Collation.compareSortPrefix4B(left.prefix(collation), right.prefix(collation));
        if (leading != .eq) return leading;
        return Collation.compareBytes(left.bytes(), right.bytes(), collation) catch unreachable;
    }
};

comptime {
    std.debug.assert(@sizeOf(Value) == 16);
}
