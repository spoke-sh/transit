//! Original workload selections and finite delivery positions. Shape validation
//! establishes neither current authorization nor retained history or cursor MAC
//! authenticity; the native owner rechecks those before disclosure/settlement.
const std = @import("std");
const p = @import("root.zig");

pub const Selection = union(enum) {
    append: p.StreamQueue.AppendReceipt,
    consume: p.StreamRead.Receipt,
    claim: p.StreamQueue.ClaimReceipt,
    renewal: p.StreamQueue.SettlementReceipt,

    pub fn validate(self: Selection) !void {
        switch (self) {
            .renewal => |value| _ = try renewedLease(value),
            inline else => |value| try value.validate(),
        }
    }
    pub fn binding(self: Selection, scratch: std.mem.Allocator) !p.LogWorkload.Binding {
        try self.validate();
        return switch (self) {
            .append => |value| if (value.append.kind == .stream)
                .{ .stream = try (p.LogWorkload.StreamRequest{ .append = value.append }).binding(scratch) }
            else
                .{ .queue = try (p.LogWorkload.QueueRequest{ .enqueue = value.append }).binding(scratch) },
            .consume => |value| .{ .stream = try (p.LogWorkload.StreamRequest{ .consume = value.request }).binding(scratch) },
            .claim => |value| .{ .queue = try (p.LogWorkload.QueueRequest{ .claim = value.claim }).binding(scratch) },
            .renewal => |value| .{ .queue = try (p.LogWorkload.QueueRequest{ .settle = value.settlement }).binding(scratch) },
        };
    }
};

pub const Position = union(enum) {
    append: u32,
    consume: p.StreamRead.Cursor,
    claim: p.QueueRead.Cursor,
    renewal: u32,
    pub fn validate(self: Position, selection: Selection) !void {
        try selection.validate();
        if (!std.mem.eql(u8, @tagName(self), @tagName(selection))) return error.WorkloadResultConflict;
        switch (self) {
            .append => |ordinal| if (ordinal > selection.append.append.rows) return error.WorkloadResultConflict,
            .consume => |cursor| try cursor.requireReceipt(selection.consume),
            .claim => |cursor| try cursor.requireReceipt(selection.claim),
            .renewal => |ordinal| if (ordinal > 1) return error.WorkloadResultConflict,
        }
    }
    pub fn complete(self: Position, selection: Selection) !bool {
        try self.validate(selection);
        return switch (self) {
            .append => |ordinal| ordinal == selection.append.append.rows,
            .consume => |cursor| cursor.coverage.complete,
            .claim => |cursor| cursor.complete(),
            .renewal => |ordinal| ordinal == 1,
        };
    }
};

/// Reconstruct the original renewal's descriptor, never the current lease.
/// Receipt validation establishes shape, not authenticity, rights or liveness.
pub fn renewedLease(receipt: p.StreamQueue.SettlementReceipt) !p.StreamQueue.Lease {
    try receipt.validate();
    if (receipt.settlement.action != .extend) return error.WorkloadResultUnavailable;
    var lease = receipt.settlement.lease;
    lease.expires_ms = receipt.settlement.action.extend.expires_ms;
    return lease;
}
