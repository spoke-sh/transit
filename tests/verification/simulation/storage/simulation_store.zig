//! Test-only atomic journal, immutable blocks and a two-page volatile cache.
//! A trace injects one failure at a numbered I/O boundary; no real disk claim.
const std = @import("std");
const core = @import("transit_core");
const Self = @This();
pub const Fault = enum { none, before_append, after_append, stage_before, stage_after, load, trim_before, trim_after };
pub const Counts = struct { stages: u32 = 0, loads: u32 = 0, appends: u32 = 0, trims: u32 = 0, fired: bool = false };
allocator: std.mem.Allocator,
entries: std.ArrayList(?core.Entry) = .empty,
pages: std.AutoHashMapUnmanaged(core.pages.Reference, core.pages.Page) = .empty,
blocks: @import("simulation_blocks") = .{},
cache: [2]?struct { reference: core.pages.Reference, page: core.pages.Page } = @splat(null),
next_cache: u1 = 0,
fault: Fault = .none,
fault_at: u16 = 1,
counts: Counts = .{},
staged: u64 = 0,
trimmed: u64 = 0,

pub fn beginFault(self: *Self, fault: Fault, at: u16) void {
    self.fault = fault;
    self.fault_at = at;
    self.counts = .{};
}
fn fail(self: *Self, fault: Fault, at: u32) bool {
    if (self.fault != fault or self.fault_at != at) return false;
    self.counts.fired = true;
    return true;
}
pub fn clearCache(self: *Self) void {
    self.cache = @splat(null);
}
pub fn stage(self: *Self, reference: core.pages.Reference, page: *const core.pages.Page) !core.pages.Reference {
    self.counts.stages += 1;
    if (self.fail(.stage_before, self.counts.stages)) return error.StorageUnavailable;
    try self.pages.put(self.allocator, reference, page.*);
    self.staged += 1;
    if (self.fail(.stage_after, self.counts.stages)) return error.LostStageAcknowledgement;
    return reference;
}
pub fn stageMany(self: *Self, batch: []const core.pages.Page, output: []core.pages.Reference) !void {
    for (batch, output) |page, *reference| reference.* = try self.stage(try page.reference(), &page);
}
pub fn load(self: *Self, reference: core.pages.Reference) !core.pages.Page {
    self.counts.loads += 1;
    if (self.fail(.load, self.counts.loads)) return error.PageUnavailable;
    for (self.cache) |slot| if (slot) |value| {
        if (std.meta.eql(value.reference, reference)) return value.page;
    };
    const page = self.pages.get(reference) orelse return error.PageUnavailable;
    self.cache[self.next_cache] = .{ .reference = reference, .page = page };
    self.next_cache +%= 1;
    return page;
}
pub fn stageBlock(self: *Self, spec: core.protocol.Blocks.Spec, bytes: []const u8) !core.blocks.Reference {
    self.counts.stages += 1;
    if (self.fail(.stage_before, self.counts.stages)) return error.StorageUnavailable;
    const reference = try self.blocks.stage(self.allocator, spec, bytes);
    self.staged += 1;
    if (self.fail(.stage_after, self.counts.stages)) return error.LostStageAcknowledgement;
    return reference;
}
pub fn loadBlock(self: *Self, reference: core.blocks.Reference, output: []u8) ![]const u8 {
    self.counts.loads += 1;
    if (self.fail(.load, self.counts.loads)) return error.BlockUnavailable;
    return self.blocks.load(reference, output);
}
pub fn tail(self: *Self) !u64 {
    return self.entries.items.len;
}
pub fn read(self: *Self, at: u64) !?core.Entry {
    if (at < self.trimmed) return error.HistoryReclaimed;
    return if (at < self.entries.items.len) self.entries.items[@intCast(at)] else null;
}
pub fn append(self: *Self, expected: u64, entry: core.Entry) !bool {
    self.counts.appends += 1;
    if (self.fail(.before_append, self.counts.appends)) return error.StorageUnavailable;
    if (expected != self.entries.items.len) return false;
    try self.entries.append(self.allocator, entry);
    if (self.fail(.after_append, self.counts.appends)) return error.LostAcknowledgement;
    return true;
}
pub fn trim(self: *Self, floor: u64) !void {
    if (floor == 0 or floor >= self.entries.items.len) return error.NoCheckpointIntent;
    const latest = self.entries.items[self.entries.items.len - 1].?;
    if (latest != .operation or floor > latest.operation.next.history_floor) return error.NoCheckpointIntent;
    while (self.trimmed < floor) {
        self.counts.trims += 1;
        if (self.fail(.trim_before, self.counts.trims)) return error.StorageUnavailable;
        self.entries.items[@intCast(self.trimmed)] = null;
        self.trimmed += 1;
        if (self.fail(.trim_after, self.counts.trims)) return error.LostTrimAcknowledgement;
    }
}
