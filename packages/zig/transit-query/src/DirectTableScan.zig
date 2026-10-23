//! Fuze source over an existing direct Table pin. The caller retains ownership
//! of that durable pin; closing this local scan does not release it.
const std = @import("std");
const q = @import("root.zig");
const c = q.catalog;
const f = q.fuze;
const Self = @This();
allocator: std.mem.Allocator,
client: c.DirectTableClient,
reader: c.DirectTableReader,
request_limit: u64,
requests: u64 = 2,
cancellation: ?*const std.atomic.Value(bool),
page: ?c.DirectTableReader.Batch = null,
index: usize = 0,
after: ?f.TableRow.Identity = null,
complete: bool = false,
closed: bool = false,
rejection: ?q.protocol.ErrorCode = null,

pub fn open(allocator: std.mem.Allocator, client: c.DirectTableClient, snapshot: c.DirectTableProtocol.Snapshot, request_limit: u64, cancellation: ?*const std.atomic.Value(bool)) !Self {
    if (request_limit < 2) return error.InvalidQueryBudget;
    if (cancellation) |flag| if (flag.load(.acquire)) return error.Cancelled;
    return .{ .allocator = allocator, .client = client, .reader = try c.DirectTableReader.open(allocator, client, snapshot), .request_limit = request_limit, .cancellation = cancellation };
}
pub fn deinit(self: *Self) void {
    if (self.page) |*page| page.deinit();
    self.reader.deinit();
    self.* = undefined;
}
pub fn checkCancellation(self: *const Self) !void {
    if (self.closed) return error.QueryClosed;
    if (self.cancellation) |flag| if (flag.load(.acquire)) return error.Cancelled;
}
fn charge(self: *Self) !void {
    try self.checkCancellation();
    self.rejection = null;
    // A direct call acquires current native credentials, then invokes its Table
    // action. Charge both exchanges before starting either; no implicit retries.
    if (self.requests > self.request_limit or self.request_limit - self.requests < 2) return error.QueryPageBudget;
    self.requests += 2;
}
fn rejected(self: *Self, err: anyerror) anyerror {
    self.rejection = self.client.authority.last_rejection orelse self.client.service.last_rejection;
    return err;
}
pub fn validateCurrent(self: *Self) !void {
    try self.charge();
    self.reader.check(self.client) catch |err| return self.rejected(err);
    try self.checkCancellation();
}
pub fn fingerprint(self: *const Self) ![32]u8 {
    return self.reader.basis.fingerprint();
}
pub fn next(self: *Self) !?f.LogicalQuery.Row {
    try self.checkCancellation();
    if (self.complete) return null;
    if (self.page == null or self.index == self.page.?.count) {
        if (self.page) |*page| page.deinit();
        self.page = null;
        self.index = 0;
        if (self.reader.complete) {
            self.complete = true;
            return null;
        }
        try self.charge();
        self.page = (self.reader.next(self.client, .{}) catch |err| return self.rejected(err)) orelse return error.IncompleteSource;
        if (self.page.?.count == 0) {
            if (!self.reader.complete) return error.IncompleteSource;
            self.complete = true;
            return null;
        }
    }
    const row = self.page.?.rows[self.index].?;
    self.page.?.rows[self.index] = null;
    self.index += 1;
    self.after = row.identity;
    // TableRow owns its value and descriptor in one arena. Transfer that arena
    // to Fuze; the source page can be freed independently of the returned row.
    return .{ .arena = row.value.descriptor.arena, .cells = row.row().cells };
}
pub fn batchIdentity(self: *const Self) ?f.TableRow.Identity {
    return self.after;
}
/// Rewinds traverse the same retained identity index. The common sequential
/// call uses the already buffered page; no new snapshot or name lookup occurs.
pub fn nextAfter(self: *Self, after: ?f.TableRow.Identity) !?f.LogicalQuery.Row {
    try self.checkCancellation();
    if (std.meta.eql(after, self.after)) return self.next();
    if (self.page) |*page| page.deinit();
    self.page = null;
    self.index = 0;
    self.after = null;
    self.complete = false;
    self.reader.after = null;
    self.reader.consumed = 0;
    self.reader.complete = false;
    while (try self.next()) |value| {
        var row = value;
        if (after == null or f.RelationalExecution.identityOrder(self.after.?, after.?) == .gt) return row;
        row.deinit();
    }
    return null;
}
pub fn close(self: *Self) void {
    self.closed = true;
}
