//! Logical statement results. No SQL wire messages, transports, clocks or I/O.
const std = @import("std");
pub const fuze = @import("transit_fuze");
pub const protocol = @import("transit_protocol");
pub const Types = fuze.Types;
pub const Row = []const Types.Values.Cell;
pub const Batch = @import("Batch.zig");
pub const BatchBuilder = @import("BatchBuilder.zig");
pub const ResultSet = @import("ResultSet.zig");
pub const Window = @import("Window.zig");
pub const Progress = @import("Progress.zig");
pub const Transaction = @import("Transaction.zig");
pub const Observation = @import("Observation.zig");
pub const Command = enum { empty, select, insert, update, delete, create_table, alter_table, drop_table, create_schema, alter_schema, drop_schema, set, show, discard_all, reset, reload, capture, begin, commit, rollback, savepoint, release_savepoint, rollback_to_savepoint };
pub const Outcome = enum { provisional, applied, unchanged, rejected, cancelled, partial };
pub const Operation = struct { account: [32]u8, id: u64, kind: enum { table, configuration, captured, transaction } = .table };
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
    transaction: ?Transaction = null,
    pub fn validate(self: CommandCompletion) !void {
        if (self.counts) |counts| try counts.validate();
        if (self.transaction) |transaction| try transaction.validate(self.kind, self.outcome) else {
            if (self.outcome == .provisional) return error.InvalidCommandCompletion;
            switch (self.kind) {
                .begin, .commit, .rollback, .savepoint, .release_savepoint, .rollback_to_savepoint => return error.InvalidCommandCompletion,
                else => {},
            }
        }
        const counted = switch (self.kind) {
            .insert, .update, .delete, .create_table, .alter_table, .drop_table, .create_schema, .alter_schema, .drop_schema => true,
            .select, .show => return error.InvalidCommandCompletion,
            else => false,
        };
        if (counted != (self.counts != null)) return error.InvalidCommandCompletion;
        if (self.pending_restart and self.kind != .reload) return error.InvalidCommandCompletion;
        if (self.pending_restart and self.outcome != .applied) return error.InvalidCommandCompletion;
        if (self.outcome == .partial and self.kind != .reload) return error.InvalidCommandCompletion;
        if (self.counts) |counts| switch (self.kind) {
            .insert, .update, .delete => {},
            else => if (counts.matched != 0 or counts.changed != 0) return error.InvalidCommandCounts,
        };
        if (self.operation) |operation| {
            if (operation.id == 0) return error.InvalidCommandCompletion;
            const expected: @FieldType(Operation, "kind") = if (self.transaction != null) .transaction else if (counted) .table else if (self.kind == .reload) .configuration else if (self.kind == .capture) .captured else return error.InvalidCommandCompletion;
            if (operation.kind != expected) return error.InvalidCommandCompletion;
        } else if (self.transaction != null or counted or self.kind == .reload or self.kind == .capture) return error.InvalidCommandCompletion;
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
pub const Unresolved = struct {
    account: [32]u8,
    instance: [16]u8,
    token: [16]u8,
    operation: ?Operation,
    reason: enum { unavailable, interrupted, denied, identity_changed },
};
pub const StatementOutcome = union(enum) {
    command: CommandCompletion,
    rows: ResultSet,
    unresolved: Unresolved,
    failure: Failure,
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
    _ = @import("transaction_test.zig");
}
