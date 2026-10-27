//! An owned bounded view, independent of transport pages and display layout.
//! A limit leaves the next logical row unread; the caller can continue or close.
const std = @import("std");
const r = @import("root.zig");
const Self = @This();
pub const Limits = struct { rows: usize, bytes: usize };
parent: std.mem.Allocator,
memory: r.fuze.MemoryBudget,
arena: std.heap.ArenaAllocator,
rows: []const r.Row = &.{},
start: u64,
stop: enum { exhausted, row_limit, byte_limit } = .row_limit,
completion: ?r.Completion = null,

pub fn read(allocator: std.mem.Allocator, result: *r.ResultSet, limits: Limits) !*Self {
    if (limits.rows == 0 or limits.bytes == 0) return error.InvalidResultBudget;
    const self = try allocator.create(Self);
    self.* = .{ .parent = allocator, .memory = .{ .parent = allocator, .limit = limits.bytes }, .arena = undefined, .start = result.progress.delivered };
    self.arena = .init(self.memory.allocator());
    errdefer self.deinit();
    var rows: std.ArrayList(r.Row) = .empty;
    const a = self.arena.allocator();
    while (rows.items.len < limits.rows) {
        const row = try result.peekRow() orelse {
            self.stop = .exhausted;
            break;
        };
        const copy = r.copyRow(a, result.schema.structure, row) catch |err| {
            if (err == error.OutOfMemory and self.memory.exhausted) {
                self.stop = .byte_limit;
                break;
            }
            return err;
        };
        rows.append(a, copy) catch |err| {
            if (err == error.OutOfMemory and self.memory.exhausted) {
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
pub fn deinit(self: *Self) void {
    const allocator = self.parent;
    self.arena.deinit();
    std.debug.assert(self.memory.used == 0);
    allocator.destroy(self);
}
