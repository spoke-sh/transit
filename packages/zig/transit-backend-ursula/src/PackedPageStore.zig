//! Immutable pages packed into an append-only journal. Opaque locators carry
//! verified record coordinates; only a separate authority append publishes roots.
const std = @import("std");
const adapter = @import("root.zig");
const pages = @import("transit_core").pages;
const observations = @import("transit_observability");
const Self = @This();
const Cached = struct { reference: pages.Reference, page: pages.Page, used: u64 };

allocator: std.mem.Allocator,
authority: adapter.Journal,
name: [45]u8,
cache: []?Cached,
access: u64 = 0,
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
    hash.update("transit.packed.pages.v1\x00");
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
}
pub fn clearCache(self: *Self) void {
    @memset(self.cache, null);
}
pub fn residentBytes(self: *const Self) usize {
    return self.cache.len * @sizeOf(?Cached);
}
fn cached(self: *Self, ref: pages.Reference) ?pages.Page {
    for (self.cache) |*slot| if (slot.*) |*entry| {
        if (std.meta.eql(ref, entry.reference)) {
            self.hits +|= 1;
            entry.used = self.touch();
            return entry.page;
        }
    };
    return null;
}
fn touch(self: *Self) u64 {
    if (self.access == std.math.maxInt(u64)) {
        for (self.cache) |*slot| if (slot.*) |*entry| {
            entry.used = 0;
        };
        self.access = 0;
    }
    self.access += 1;
    return self.access;
}
fn remember(self: *Self, ref: pages.Reference, page: pages.Page) void {
    if (self.cache.len == 0) return;
    var selected: usize = 0;
    var oldest: u64 = std.math.maxInt(u64);
    for (self.cache, 0..) |slot, i| {
        const entry = slot orelse {
            selected = i;
            break;
        };
        if (entry.used < oldest) {
            oldest = entry.used;
            selected = i;
        }
    }
    self.cache[selected] = .{ .reference = ref, .page = page, .used = self.touch() };
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
    self.misses +|= 1;
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
    self.requests +|= 1;
    // Record and byte limits are mutually exclusive upstream. One record plus
    // the borrowed client's response ceiling bounds transport allocation; the
    // page codec independently enforces its smaller encoded-size contract.
    var response = try self.authority.send(.{ .read = .{ .stream = self.journal().stream, .options = .{ .position = .{ .record = position }, .max_records = 1 } } });
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
    // Page order carries no execution authority. Let storage assign this
    // immutable record's coordinate so independent candidates can interleave.
    // Only the separate authority journal needs conditional successor fencing.
    // Never retry a lost/malformed acknowledgement here: no usable locator was
    // established, and the unpublished bytes may have become an orphan.
    var bytes: [pages.max_encoded_bytes]u8 = undefined;
    const body = try page.encode(&bytes);
    self.requests +|= 1;
    self.create_payload_bytes_attempted +|= body.len;
    var response = try self.authority.send(.{ .append = .{
        .stream = self.journal().stream,
        .body = body,
        .options = .{ .content_type = "application/json" },
    } });
    defer response.deinit();
    try response.head.requireSuccess();
    const metadata = try response.head.metadata();
    const position = try appendedAt(metadata.record_start, metadata.record_next);
    self.created +|= 1;
    const result = located(ref, position);
    self.remember(result, page.*);
    return result;
}

/// Bounded immutable staging, with the same format-2 record locators as stage.
/// A complete acknowledgement is required before any references are returned.
/// Accepted but unacknowledged bytes are retained orphans; never retry here.
pub fn stageMany(self: *Self, batch: []const pages.Page, output: []pages.Reference) !void {
    if (batch.len == 0 or batch.len > pages.mutation_batch or output.len != batch.len) return error.PageMutationBudget;
    const encoded = try self.allocator.alloc([pages.max_encoded_bytes]u8, batch.len);
    defer self.allocator.free(encoded);
    var frames: [pages.mutation_batch][]const u8 = undefined;
    var references: [pages.mutation_batch]pages.Reference = undefined;
    var bytes: u64 = 0;
    for (batch, 0..) |*page, i| {
        references[i] = try page.reference();
        frames[i] = try page.encode(&encoded[i]);
        bytes += frames[i].len;
    }
    var observation = observations.begin(self.authority.observer, .storage_operation, "page.stage_batch", self.authority.parent_context);
    defer observation.finish();
    self.create_payload_bytes_attempted +|= bytes;
    self.appendMany(frames[0..batch.len], references[0..batch.len]) catch |err| {
        observation.fail(err);
        return err;
    };
    self.created +|= batch.len;
    for (batch, references[0..batch.len]) |page, ref| self.remember(ref, page);
    @memcpy(output, references[0..batch.len]);
}
fn appendMany(self: *Self, frames: []const []const u8, references: []pages.Reference) !void {
    self.requests +|= 1;
    var response = try self.authority.send(.{ .append_batch = .{
        .stream = self.journal().stream,
        .frames = frames,
        .content_type = "application/json",
    } });
    defer response.deinit();
    try response.head.requireSuccess();
    try batchReceipts(self.allocator, response.body, references);
}
fn batchReceipts(allocator: std.mem.Allocator, body: []const u8, references: []pages.Reference) !void {
    if (references.len == 0 or references.len > pages.mutation_batch or body.len > pages.mutation_batch * 256) return error.InvalidAppendReceipt;
    const Ack = struct { status: u16, stream_record_start: ?u64 = null, stream_record_next: ?u64 = null };
    const parsed = std.json.parseFromSlice([]const Ack, allocator, body, .{}) catch return error.InvalidAppendReceipt;
    defer parsed.deinit();
    if (parsed.value.len != references.len) return error.InvalidAppendReceipt;
    var after: ?u64 = null;
    for (parsed.value) |ack| {
        if (ack.status < 200 or ack.status >= 300) return error.InvalidAppendReceipt;
        const at = try appendedAt(ack.stream_record_start, ack.stream_record_next);
        if (after) |minimum| if (at < minimum) return error.InvalidAppendReceipt;
        after = ack.stream_record_next;
    }
    // Independent append acknowledgements may have gaps from other writers.
    // Validate every status/coordinate before modifying any caller references.
    for (parsed.value, references) |ack, *ref| ref.* = located(ref.*, ack.stream_record_start.?);
}

test "batch staging checks every independent acknowledgement before returning locators" {
    const t = std.testing;
    const sentinel: pages.Reference = .{ .digest = @splat(42) };
    var references: [2]pages.Reference = @splat(sentinel);
    try batchReceipts(t.allocator, "[{\"status\":204,\"stream_record_start\":7,\"stream_record_next\":8},{\"status\":204,\"stream_record_start\":19,\"stream_record_next\":20}]", &references);
    try t.expectEqual(@as(u64, 7), try coordinate(references[0]));
    try t.expectEqual(@as(u64, 19), try coordinate(references[1]));
    for ([_][]const u8{
        "[]",
        "[{\"status\":204,\"stream_record_start\":7,\"stream_record_next\":8}]",
        "[{\"status\":204,\"stream_record_start\":7,\"stream_record_next\":8},{\"status\":500}]",
        "[{\"status\":204,\"stream_record_start\":7,\"stream_record_next\":8},{\"status\":204,\"stream_record_start\":7,\"stream_record_next\":8}]",
        "[{\"status\":204,\"stream_record_start\":7,\"stream_record_next\":8},{\"status\":204,\"stream_record_start\":9}]",
        "[{\"status\":204,\"stream_record_start\":7,\"stream_record_next\":8},{\"status\":204,\"stream_record_start\":9,\"stream_record_next\":11}]",
    }) |body| {
        references = @splat(sentinel);
        try t.expectError(error.InvalidAppendReceipt, batchReceipts(t.allocator, body, &references));
        for (references) |ref| try t.expectEqualDeep(sentinel, ref);
    }
}

fn appendedAt(start: ?u64, next: ?u64) !u64 {
    const position = start orelse return error.InvalidAppendReceipt;
    const expected = std.math.add(u64, position, 1) catch return error.InvalidAppendReceipt;
    if (next != expected) return error.InvalidAppendReceipt;
    return position;
}

test "packed staging requires a complete single-record coordinate acknowledgement" {
    try std.testing.expectEqual(@as(u64, 0), try appendedAt(0, 1));
    try std.testing.expectEqual(@as(u64, 65536), try appendedAt(65536, 65537));
    try std.testing.expectError(error.InvalidAppendReceipt, appendedAt(null, 1));
    try std.testing.expectError(error.InvalidAppendReceipt, appendedAt(0, null));
    try std.testing.expectError(error.InvalidAppendReceipt, appendedAt(0, 0));
    try std.testing.expectError(error.InvalidAppendReceipt, appendedAt(0, 2));
    try std.testing.expectError(error.InvalidAppendReceipt, appendedAt(std.math.maxInt(u64), 0));
}

test "packed page locators remain opaque and reject a different storage mapping" {
    const ref: pages.Reference = .{ .digest = @splat(42) };
    try std.testing.expectError(error.UnsupportedPageLocation, coordinate(ref));
    var addressed = located(ref, 123456);
    try std.testing.expectEqual(@as(u64, 123456), try coordinate(addressed));
    addressed.location[1] = 1;
    try std.testing.expectError(error.UnsupportedPageLocation, coordinate(addressed));
}

test "verified page cache retains recently read roots within its resident bound" {
    const t = std.testing;
    var store = try Self.init(t.allocator, .{ .client = undefined, .stream = .{ .bucket = "test", .name = "test" } }, 2);
    defer store.deinit();
    const page: pages.Page = .{ .count = 1, .body = .{ .leaf = .{ .{ .key = try .init("a"), .value = try .init("b") }, null, null, null } } };
    const ref = try page.reference();
    store.remember(located(ref, 0), page);
    store.remember(located(ref, 1), page);
    try t.expect(store.cached(located(ref, 0)) != null);
    store.remember(located(ref, 2), page);
    try t.expect(store.cached(located(ref, 1)) == null);
    try t.expect(store.cached(located(ref, 0)) != null);
    try t.expect(store.cached(located(ref, 2)) != null);
    try t.expectEqual(@as(usize, 2), store.cache.len);
    store.access = std.math.maxInt(u64);
    try t.expect(store.cached(located(ref, 0)) != null);
    store.clearCache();
    try t.expect(store.cached(located(ref, 0)) == null);
}
