//! An independent bounded copy. Its lease pins reusable storage until deinit;
//! a limit leaves the next logical row unread and does not establish completion.
const std = @import("std");
const r = @import("root.zig");
const memory = @import("transit_memory");
const Self = @This();
pub const Limits = struct { rows: usize, bytes: usize };
parent: ?std.mem.Allocator = null,
lease: memory.Workspace.Lease,
rows: []const r.Row = &.{},
start: u64,
stop: enum { exhausted, row_limit, byte_limit } = .row_limit,
completion: ?r.Completion = null,

/// Explicit owned-copy convenience. A bounded parent such as a slab reuses the
/// backing reserve across calls. The returned value is one owner, not copyable.
pub fn read(allocator: std.mem.Allocator, result: *r.ResultSet, limits: Limits) !Self {
    if (limits.rows == 0 or limits.bytes == 0) return error.InvalidResultBudget;
    const workspace = try allocator.create(memory.Workspace);
    errdefer allocator.destroy(workspace);
    workspace.* = try .init(allocator, limits.bytes);
    errdefer workspace.deinit();
    var self = try readInto(workspace, result, limits.rows);
    self.parent = allocator;
    return self;
}
/// Storage must have a stable address and outlive this window. Its entire
/// capacity remains charged, even when the view is empty or hits a row limit.
/// A retained window prevents reuse; independent windows need separate leases.
pub fn readInto(workspace: *memory.Workspace, result: *r.ResultSet, row_limit: usize) !Self {
    if (row_limit == 0 or workspace.buffer.len == 0) return error.InvalidResultBudget;
    var self: Self = .{ .lease = try workspace.acquire(), .start = result.progress.delivered };
    errdefer self.deinit();
    var rows: std.ArrayList(r.Row) = .empty;
    const a = try self.lease.allocator();
    while (rows.items.len < row_limit) {
        const row = try result.peekRow() orelse {
            self.stop = .exhausted;
            break;
        };
        const mark = try self.lease.mark();
        const previous = rows;
        append(a, &rows, result.schema.structure, row) catch |err| {
            // Both the directory growth and a partially cloned recursive row
            // roll back. Previously copied rows remain valid, with no delivery.
            rows = previous;
            const exhausted = workspace.exhausted;
            try self.lease.rewind(mark);
            if (err == error.OutOfMemory and exhausted) {
                self.stop = .byte_limit;
                break;
            }
            return err;
        };
        _ = try result.nextRow();
    }
    if (result.progress.consumption == .exhausted) self.stop = .exhausted;
    self.rows = rows.items;
    self.completion = result.completion();
    return self;
}
fn append(a: std.mem.Allocator, rows: *std.ArrayList(r.Row), fields: []const r.Types.Field, row: r.Row) !void {
    try rows.ensureUnusedCapacity(a, 1);
    const copy = try r.copyRow(a, fields, row);
    rows.appendAssumeCapacity(copy);
}
pub fn validate(self: Self) !void {
    try self.lease.validate();
}
pub fn deinit(self: Self) void {
    self.lease.release(false) catch unreachable;
    if (self.parent) |allocator| {
        const workspace = self.lease.owner;
        workspace.deinit();
        allocator.destroy(workspace);
    }
}
