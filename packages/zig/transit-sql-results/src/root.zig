//! Logical statement results. No SQL wire messages, transports, clocks or I/O.
const std = @import("std");
pub const fuze = @import("transit_fuze");
pub const protocol = @import("transit_protocol");
pub const Types = fuze.Types;
pub const Row = []const Types.Values.Cell;
pub const BatchBuilder = @import("BatchBuilder.zig");
pub const ResultSet = @import("ResultSet.zig");
pub const Window = @import("Window.zig");
pub const Progress = @import("Progress.zig");
pub const Observation = @import("Observation.zig");
pub const Command = enum { select, insert, update, delete, create_table, alter_table, drop_table, create_schema, alter_schema, drop_schema, set, show, discard_all, reset, reload, capture };
pub const Outcome = enum { applied, unchanged, rejected, cancelled, partial };
pub const Operation = struct { account: [32]u8, id: u64, kind: enum { table, configuration, captured } = .table };
pub const Counts = struct {
    matched: u64,
    changed: u64,
    pub fn validate(self: Counts) !void {
        if (self.changed > self.matched) return error.InvalidCommandCounts;
    }
};
pub const CommandCompletion = struct {
    kind: Command,
    outcome: Outcome,
    /// Null means row counts do not apply, not an unknown count disguised as zero.
    counts: ?Counts,
    operation: ?Operation,
    pending_restart: bool,
    diagnostic: ?protocol.Diagnostic,
    pub fn validate(self: CommandCompletion) !void {
        if (self.counts) |counts| try counts.validate();
        if (self.pending_restart and self.kind != .reload) return error.InvalidCommandCompletion;
        if (self.operation) |operation| if (operation.id == 0) return error.InvalidCommandCompletion;
    }
};
/// Only a verified terminal outcome supplies this count. It is not a scan count.
pub const Completion = struct { rows: u64 };
/// Immutable attribution checked by the deterministic progress owner. Hashes
/// identify content; they do not grant authorization or retain a source pin.
pub const Identity = struct { result: [32]u8, schema: [32]u8, observation: [32]u8 };
pub const Failure = struct {
    code: []const u8,
    sqlstate: [5]u8,
    message: []const u8,
    diagnostic: ?protocol.Diagnostic = null,
    pub fn denied(self: Failure) bool {
        return std.mem.eql(u8, &self.sqlstate, "42501") or std.mem.eql(u8, &self.sqlstate, "28000");
    }
};
/// A bounded logical copy retains variable-width and nested cell ownership.
/// The caller owns the arena/budget and resets it when the retained view ends.
pub fn copyRow(arena: std.mem.Allocator, fields: []const Types.Field, row: Row) !Row {
    if (fields.len != row.len) return error.InvalidResultRow;
    const copy = try arena.alloc(Types.Values.Cell, row.len);
    for (fields, row, copy) |field, cell, *out| {
        try cell.validate(field, .{});
        out.* = try Types.Values.cloneValidated(arena, cell);
    }
    return copy;
}
test {
    std.testing.refAllDecls(@This());
    _ = @import("model_test.zig");
    _ = @import("reader_test.zig");
}
