//! Dynamic-map fixture shared by framework integration tests. It deliberately
//! uses no production index/store code and provides no durability evidence.
const std = @import("std");
const p = @import("transit_client").protocol;
const g = p.Growth;
const Self = @This();
const Record = struct { bytes: []u8, revision: u64 };
views: std.AutoHashMapUnmanaged(u64, g.View) = .empty,
records: std.AutoHashMapUnmanaged(p.Value, Record) = .empty,
pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    var values = self.records.valueIterator();
    while (values.next()) |value| allocator.free(value.bytes);
    self.records.deinit(allocator);
    self.views.deinit(allocator);
}
pub fn clone(self: *Self, allocator: std.mem.Allocator) !Self {
    var result: Self = .{};
    errdefer result.deinit(allocator);
    var entries = self.records.iterator();
    while (entries.next()) |entry| try result.put(allocator, entry.key_ptr.*, entry.value_ptr.bytes, entry.value_ptr.revision);
    return result;
}
pub fn put(self: *Self, allocator: std.mem.Allocator, key: p.Value, bytes: []const u8, revision: u64) !void {
    const owned = try allocator.dupe(u8, bytes);
    errdefer allocator.free(owned);
    const slot = try self.records.getOrPut(allocator, key);
    if (slot.found_existing) allocator.free(slot.value_ptr.bytes);
    slot.value_ptr.* = .{ .bytes = owned, .revision = revision };
}
pub fn apply(self: *Self, allocator: std.mem.Allocator, batch: *const p.Blocks.Batch, revision: u64) !void {
    try p.Blocks.verify(batch.mutations, &batch.body);
    var offset: usize = 0;
    for (batch.mutations) |slot| if (slot) |mutation| {
        if (mutation.value) |spec| {
            try self.put(allocator, mutation.key, batch.body.slice()[offset..][0..spec.bytes], revision);
            offset += spec.bytes;
        } else if (self.records.fetchRemove(mutation.key)) |entry| allocator.free(entry.value.bytes);
    };
}
pub fn read(self: *Self, query: g.BlockRead.Query, body: *p.Blocks.Body, view: g.View) !g.BlockRead.Result {
    try g.BlockRead.validate(query);
    body.* = .{};
    errdefer body.* = .{};
    if (query.source != .view or query.source.view != view.id) return error.InvalidRead;
    var result: g.BlockRead.Result = .{ .resource = .{ .id = view.resource, .revision = view.revision, .writer = view.pid, .owner = null, .deadline_ms = null }, .view = view, .entries = @splat(null) };
    if (query.keys[0] != null) {
        for (query.keys, &result.entries) |key, *slot| if (key) |requested| {
            const value = self.records.get(requested) orelse continue;
            if (body.len + value.bytes.len > body.data.len) return error.BlockBatchTooLarge;
            slot.* = .{ .key = requested, .value = try p.Blocks.Spec.of(value.bytes), .revision = value.revision };
            @memcpy(body.data[body.len..][0..value.bytes.len], value.bytes);
            body.len += @intCast(value.bytes.len);
        };
    } else {
        var cursor = query.after;
        for (0..g.page_size + 1) |i| {
            var next: ?p.Value = null;
            var keys = self.records.keyIterator();
            while (keys.next()) |key| {
                if (cursor) |previous| if (std.mem.order(u8, key.slice(), previous.slice()) != .gt) continue;
                if (next == null or std.mem.order(u8, key.slice(), next.?.slice()) == .lt) next = key.*;
            }
            const key = next orelse break;
            if (i == g.page_size) {
                result.next = cursor;
                break;
            }
            const value = self.records.get(key).?;
            result.entries[i] = .{ .key = key, .value = try p.Blocks.Spec.of(value.bytes), .revision = value.revision };
            cursor = key;
        }
    }
    return result;
}
