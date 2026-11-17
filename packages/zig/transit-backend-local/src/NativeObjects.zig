//! Native immutable objects with optional single-owner remote tiering.
const std = @import("std");
const storage = @import("transit_storage");
const Objects = storage.TransitObjectStore;
const Local = storage.LocalSegmentStore.LocalSegmentStore;
pub const Tier = @import("ObjectTier.zig");
const Self = @This();
allocator: std.mem.Allocator,
local: *Local,
tier: ?*Tier = null,

pub fn open(allocator: std.mem.Allocator, io: std.Io, parent: std.Io.Dir, path: []const u8) !Self {
    const local = try allocator.create(Local);
    errdefer allocator.destroy(local);
    local.* = try Local.openDiskAt(allocator, io, parent, path);
    return .{ .allocator = allocator, .local = local };
}
pub fn configure(self: *Self, io: std.Io, directory: std.Io.Dir, options: ?Tier.Options, fresh: bool, control_bytes: u64) !void {
    if (options) |configured| {
        self.tier = try Tier.open(self.allocator, io, self.local, directory, configured, fresh, control_bytes);
    } else {
        var marker: [160]u8 = undefined;
        if (try @import("LocalFiles.zig").read(io, directory, ".object-tier", &marker) != null or try @import("LocalFiles.zig").read(io, directory, ".object-tier-ready", &marker) != null) return error.TierConfigurationRequired;
    }
}
pub fn deinit(self: *Self) void {
    if (self.tier) |tier| tier.deinit();
    self.local.deinit();
    self.allocator.destroy(self.local);
    self.* = undefined;
}
pub fn objectStore(self: *Self) Objects.ObjectStore {
    if (self.tier == null) return self.local.objectStore();
    return .{ .context = self, .vtable = &.{ .putImmutable = put, .putImmutableBatch = batch, .putConditional = conditional, .getRange = read, .getObject = whole, .head = head, .delete = delete } };
}
/// Preserve the owning native/direct control classification through tier admission.
pub fn putImmutableBatch(self: *Self, items: []const Objects.ImmutablePut, output: []Objects.ObjectMeta, control: bool) !void {
    try Objects.validateBatch(items, output);
    const tier = self.tier orelse return self.local.objectStore().putImmutableBatch(items, output);
    return tier.putBatch(items, output, control);
}
pub fn reclaimImmutableObject(self: *Self, key: []const u8, expected: Objects.ObjectMeta) !u64 {
    return if (self.tier) |tier| tier.reclaim(key, expected) else self.local.reclaimImmutableObject(key, expected);
}
pub fn confirmImmutableObject(self: *Self, key: []const u8, expected: Objects.ObjectMeta) !void {
    if (self.tier) |tier| return tier.confirm(key, expected);
    return self.local.confirmImmutableObject(key, expected);
}
pub fn headObject(self: *Self, key: []const u8) !?Objects.ObjectMeta {
    if (self.tier) |tier| try tier.check();
    return self.local.headObject(key);
}
pub fn deleteObject(self: *Self, key: []const u8) !void {
    // Generic deletion only unpublishes discovery. Physical remote deletion
    // always requires the retained-root collector's exact immutable identity.
    if (self.tier != null) return error.TierDeletionRequiresCollector;
    return self.local.deleteObject(key);
}
fn cast(raw: *anyopaque) *Self {
    return @ptrCast(@alignCast(raw));
}
fn put(raw: *anyopaque, key: []const u8, bytes: []const u8, digest: [32]u8) !Objects.ObjectMeta {
    return cast(raw).tier.?.put(key, bytes, digest);
}
fn batch(raw: *anyopaque, items: []const Objects.ImmutablePut, output: []Objects.ObjectMeta) !void {
    return cast(raw).tier.?.putBatch(items, output, false);
}
fn conditional(_: *anyopaque, _: []const u8, _: Objects.Condition, _: []const u8) !bool {
    return error.MutableDataObjectUnavailable;
}
fn read(raw: *anyopaque, key: []const u8, offset: u64, length: u32, out: []u8) ![]const u8 {
    return cast(raw).tier.?.read(key, offset, length, out);
}
fn whole(raw: *anyopaque, key: []const u8, out: []u8) !?Objects.ObjectMeta {
    const meta = (try cast(raw).headObject(key)) orelse return null;
    if (meta.size > out.len) return error.BufferTooSmall;
    _ = try read(raw, key, 0, @intCast(meta.size), out);
    return meta;
}
fn head(raw: *anyopaque, key: []const u8) !?Objects.ObjectMeta {
    return cast(raw).headObject(key);
}
fn delete(raw: *anyopaque, key: []const u8) !void {
    return cast(raw).deleteObject(key);
}
