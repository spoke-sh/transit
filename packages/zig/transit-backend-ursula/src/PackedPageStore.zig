//! Immutable pages packed into an append-only journal. Opaque locators carry
//! verified record coordinates; only a separate authority append publishes roots.
const std = @import("std");
const adapter = @import("root.zig");
const pages = @import("transit_core").pages;
const observations = @import("transit_observability");
const Self = @This();
const Cached = struct { reference: pages.Reference, page: pages.Page };

allocator: std.mem.Allocator,
authority: adapter.Journal,
name: [45]u8,
cache: []?Cached,
slot: usize = 0,
next_record: ?u64 = null,
hits: u64 = 0,
misses: u64 = 0,
created: u64 = 0,
requests: u64 = 0,
create_payload_bytes_attempted: u64 = 0,

pub fn init(allocator: std.mem.Allocator, authority: adapter.Journal, resident_pages: usize) !Self {
    if (resident_pages > 1024) return error.InvalidPageCacheBudget;
    const cache = try allocator.alloc(?Cached, resident_pages);
    @memset(cache, null);
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.packed.pages.v2\x00");
    hash.update(authority.stream.bucket);
    hash.update("\x00");
    hash.update(authority.stream.name);
    var name: [45]u8 = undefined;
    name[0..2].* = "q-".*;
    _ = std.base64.url_safe_no_pad.Encoder.encode(name[2..], &hash.finalResult());
    return .{ .allocator = allocator, .authority = authority, .name = name, .cache = cache };
}
pub fn deinit(self: *Self) void {
    self.allocator.free(self.cache);
    self.* = undefined;
}
fn journal(self: *Self) adapter.Journal {
    var result = self.authority;
    result.stream.name = &self.name;
    return result;
}
/// Bootstrap-only creation. Loads never recreate missing history.
pub fn create(self: *Self) !void {
    try self.journal().create();
    self.next_record = null;
}
pub fn clearCache(self: *Self) void {
    @memset(self.cache, null);
    self.next_record = null;
}
pub fn residentBytes(self: *const Self) usize {
    return self.cache.len * @sizeOf(?Cached);
}
fn cached(self: *Self, ref: pages.Reference) ?pages.Page {
    for (self.cache) |slot| if (slot) |entry| {
        if (std.meta.eql(ref, entry.reference)) {
            self.hits += 1;
            return entry.page;
        }
    };
    return null;
}
fn remember(self: *Self, ref: pages.Reference, page: pages.Page) void {
    if (self.cache.len == 0) return;
    self.cache[self.slot] = .{ .reference = ref, .page = page };
    self.slot = (self.slot + 1) % self.cache.len;
}
fn located(ref: pages.Reference, position: u64) pages.Reference {
    var result = ref;
    result.location[0] = 1;
    std.mem.writeInt(u64, result.location[8..16], position, .big);
    return result;
}
fn coordinate(ref: pages.Reference) !u64 {
    if (ref.location[0] != 1 or !std.mem.allEqual(u8, ref.location[1..8], 0)) return error.UnsupportedPageLocation;
    return std.mem.readInt(u64, ref.location[8..16], .big);
}
pub fn load(self: *Self, ref: pages.Reference) !pages.Page {
    const position = try coordinate(ref);
    if (self.cached(ref)) |page| return page;
    self.misses += 1;
    var observation = observations.begin(self.authority.observer, .storage_operation, "page.load", self.authority.parent_context);
    defer observation.finish();
    const page = self.fetch(ref, position) catch |err| {
        observation.fail(err);
        return err;
    };
    self.remember(ref, page);
    return page;
}
fn fetch(self: *Self, ref: pages.Reference, position: u64) !pages.Page {
    self.requests += 1;
    // Record and byte limits are mutually exclusive upstream. One record plus
    // the borrowed client's response ceiling bounds transport allocation; the
    // page codec independently enforces its smaller encoded-size contract.
    var response = try self.authority.client.send(.{ .read = .{ .stream = self.journal().stream, .options = .{ .position = .{ .record = position }, .max_records = 1 } } });
    defer response.deinit();
    if (response.head.status == .not_found or response.head.status == .gone) return error.PageUnavailable;
    try response.head.requireSuccess();
    const meta = try response.head.metadata();
    if (meta.record_start != position or meta.record_next != try std.math.add(u64, position, 1)) return error.PageUnavailable;
    const page = try pages.Page.decode(self.allocator, response.body);
    try ref.verify(&page);
    return page;
}
pub fn stage(self: *Self, ref: pages.Reference, page: *const pages.Page) !pages.Reference {
    if (!std.mem.allEqual(u8, &ref.location, 0)) return error.UnsupportedPageLocation;
    try ref.verify(page);
    var observation = observations.begin(self.authority.observer, .storage_operation, "page.stage", self.authority.parent_context);
    defer observation.finish();
    return self.append(ref, page) catch |err| {
        observation.fail(err);
        return err;
    };
}
fn append(self: *Self, ref: pages.Reference, page: *const pages.Page) !pages.Reference {
    // Do not silently retry CAS or lost acknowledgements. A failed candidate
    // may leave an unreachable immutable page, never a published resource root.
    errdefer self.next_record = null;
    if (self.next_record == null) {
        self.requests += 1;
        self.next_record = try self.journal().tail();
    }
    const position = self.next_record.?;
    var bytes: [pages.max_encoded_bytes]u8 = undefined;
    const body = try page.encode(&bytes);
    self.requests += 1;
    self.create_payload_bytes_attempted += body.len;
    if (!try self.journal().append(position, body)) return error.Conflict;
    self.next_record = try std.math.add(u64, position, 1);
    self.created += 1;
    const result = located(ref, position);
    self.remember(result, page.*);
    return result;
}

test "packed page locators remain opaque and reject a different storage mapping" {
    const ref: pages.Reference = .{ .digest = @splat(42) };
    try std.testing.expectError(error.UnsupportedPageLocation, coordinate(ref));
    var addressed = located(ref, 123456);
    try std.testing.expectEqual(@as(u64, 123456), try coordinate(addressed));
    addressed.location[1] = 1;
    try std.testing.expectError(error.UnsupportedPageLocation, coordinate(addressed));
}
