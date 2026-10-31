//! Admission gate for the selected autocommit extended-query profile. Never
//! dispatch a write from Execute; only a validated Sync may release it.
const std = @import("std");
const Limits = @import("root.zig").wire.Limits;
const Self = @This();
pub const Action = enum { handle, ignore, flush, sync_empty, sync_write, terminate };
limits: Limits,
state: enum { idle, extended, failed } = .idle,
bytes: u32 = 0,
messages: u16 = 0,
read_portal: ?u64 = null,
suspended: bool = false,
write: bool = false,
pub fn init(limits: Limits) !Self {
    try limits.validate();
    return .{ .limits = limits };
}
fn reset(self: *Self) void {
    const limits = self.limits;
    self.* = .{ .limits = limits };
}
pub fn fail(self: *Self) void {
    self.state = .failed;
    self.write = false;
}
/// The caller validates each payload before acting on handle/Sync. All failures
/// call fail; framing errors close the connection instead of resynchronizing.
pub fn accept(self: *Self, tag: u8, bytes: usize) !Action {
    if (tag == 'X') return .terminate;
    if (tag == 'S') {
        const dispatch = self.state != .failed and self.write;
        self.reset();
        return if (dispatch) .sync_write else .sync_empty;
    }
    if (self.state == .failed) return .ignore;
    errdefer self.fail();
    if (self.write) return error.UnsupportedExecutionCycle;
    if (tag == 'Q') {
        if (self.state != .idle) return error.UnsupportedExecutionCycle;
        return .handle;
    }
    if (tag != 'P' and tag != 'B' and tag != 'D' and tag != 'E' and tag != 'C' and tag != 'H') return error.UnsupportedProtocolMessage;
    if (bytes > self.limits.cycle_bytes - self.bytes or self.messages == self.limits.cycle_messages) return error.ExecutionCycleTooLarge;
    self.bytes += @intCast(bytes);
    self.messages += 1;
    self.state = .extended;
    return if (tag == 'H') .flush else .handle;
}
pub fn execute(self: *Self, portal: u64, mutation: bool, max_rows: u32) !void {
    errdefer self.fail();
    if (self.state != .extended or self.write or portal == 0) return error.UnsupportedExecutionCycle;
    if (mutation) {
        if (self.read_portal != null or max_rows != 0) return error.UnsupportedExecutionCycle;
        self.write = true;
    } else {
        if (self.read_portal) |previous| {
            if (previous != portal or !self.suspended) return error.UnsupportedExecutionCycle;
        }
        self.read_portal = portal;
        self.suspended = false;
    }
}
pub fn suspendRead(self: *Self) !void {
    if (self.state != .extended or self.read_portal == null or self.write) return error.UnsupportedExecutionCycle;
    self.suspended = true;
}
test "writes require one complete valid Sync cycle" {
    const t = std.testing;
    var cycle = try init(.{});
    for ("PBDE") |tag| _ = try cycle.accept(tag, 16);
    try cycle.execute(1, true, 0);
    try t.expectEqual(Action.sync_write, try cycle.accept('S', 5));
    for ("HEPBQCD") |forbidden| {
        _ = try cycle.accept('E', 16);
        try cycle.execute(1, true, 0);
        try t.expectError(error.UnsupportedExecutionCycle, cycle.accept(forbidden, 5));
        try t.expectEqual(Action.ignore, try cycle.accept('E', 16));
        try t.expectEqual(Action.sync_empty, try cycle.accept('S', 5));
    }
}
test "read suspension keeps one portal and failed cycles recover only at Sync" {
    const t = std.testing;
    var cycle = try init(.{});
    _ = try cycle.accept('E', 16);
    try cycle.execute(7, false, 1);
    try cycle.suspendRead();
    try t.expectEqual(Action.flush, try cycle.accept('H', 5));
    _ = try cycle.accept('E', 16);
    try cycle.execute(7, false, 1);
    try t.expectError(error.UnsupportedExecutionCycle, cycle.execute(8, false, 1));
    try t.expectEqual(Action.ignore, try cycle.accept('Q', 10));
    try t.expectEqual(Action.sync_empty, try cycle.accept('S', 5));
    try t.expectEqual(Action.handle, try cycle.accept('Q', 10));
    _ = try cycle.accept('P', 10);
    try t.expectError(error.ExecutionCycleTooLarge, cycle.accept('B', Limits.max_frame_bytes));
    try t.expectEqual(Action.sync_empty, try cycle.accept('S', 5));
}
