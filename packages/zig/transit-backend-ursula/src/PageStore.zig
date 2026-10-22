//! Immutable page storage. Root publication remains a separate conditional
//! authority append. No deletion, root discovery, or authorization lives here.
const std = @import("std");
const adapter = @import("root.zig");
const observations = @import("transit_observability");
const pages = @import("transit_core").pages;
const Self = @This();
const Cached = struct { reference: pages.Reference, page: pages.Page };

allocator: std.mem.Allocator,
journal: adapter.Journal,
cache: []?Cached,
next: usize = 0,
hits: u64 = 0,
misses: u64 = 0,
created: u64 = 0,
requests: u64 = 0,
create_payload_bytes_attempted: u64 = 0,

pub fn init(allocator: std.mem.Allocator, journal: adapter.Journal, resident_pages: usize) !Self {
    // This is a working-set budget, unrelated to durable page cardinality.
    if (resident_pages > 4096) return error.InvalidPageCacheBudget;
    const cache = try allocator.alloc(?Cached, resident_pages);
    @memset(cache, null);
    return .{ .allocator = allocator, .journal = journal, .cache = cache };
}
pub fn deinit(self: *Self) void {
    self.allocator.free(self.cache);
    self.* = undefined;
}
pub fn clearCache(self: *Self) void {
    @memset(self.cache, null);
    self.next = 0;
}
pub fn residentBytes(self: *const Self) usize {
    return self.cache.len * @sizeOf(?Cached);
}
fn cached(self: *Self, ref: pages.Reference) ?pages.Page {
    for (self.cache) |*slot| {
        const entry = &(slot.* orelse break);
        if (std.meta.eql(ref, entry.reference)) {
            self.hits += 1;
            return entry.page;
        }
    }
    return null;
}
fn remember(self: *Self, ref: pages.Reference, page: pages.Page) void {
    if (self.cache.len == 0) return;
    self.cache[self.next] = .{ .reference = ref, .page = page };
    self.next = (self.next + 1) % self.cache.len;
}
fn stream(self: *Self, ref: pages.Reference, name: *[45]u8) adapter.ursula.Stream {
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.immutable.page.stream.v1\x00");
    hash.update(self.journal.stream.bucket);
    hash.update("\x00");
    hash.update(self.journal.stream.name);
    hash.update("\x00");
    hash.update(&ref.digest);
    const digest = hash.finalResult();
    name[0..2].* = "g-".*;
    _ = std.base64.url_safe_no_pad.Encoder.encode(name[2..], &digest);
    return .{ .bucket = self.journal.stream.bucket, .name = name };
}

pub fn load(self: *Self, ref: pages.Reference) !pages.Page {
    if (!std.mem.allEqual(u8, &ref.location, 0)) return error.UnsupportedPageLocation;
    if (self.cached(ref)) |page| return page;
    self.misses += 1;
    const page = try self.fetch(ref);
    self.remember(ref, page);
    return page;
}
fn fetch(self: *Self, ref: pages.Reference) !pages.Page {
    var observation = observations.begin(self.journal.observer, .storage_operation, "page.load", self.journal.parent_context);
    defer observation.finish();
    return self.fetchImpl(ref) catch |err| {
        observation.fail(err);
        return err;
    };
}
fn fetchImpl(self: *Self, ref: pages.Reference) !pages.Page {
    var name: [45]u8 = undefined;
    const location = self.stream(ref, &name);
    self.requests += 1;
    var head = try self.journal.send(.{ .head = .{ .stream = location } });
    defer head.deinit();
    if (head.head.status == .not_found) return error.PageUnavailable;
    try head.head.requireSuccess();
    if (!((try head.head.metadata()).closed orelse false)) return error.MutablePage;
    self.requests += 1;
    var body = try self.journal.send(.{ .read = .{ .stream = location, .options = .{ .max_bytes = pages.max_encoded_bytes + 1 } } });
    defer body.deinit();
    try body.head.requireSuccess();
    if (!((try body.head.metadata()).up_to_date orelse false)) return error.IncompletePage;
    const page = try pages.Page.decode(self.allocator, body.body);
    try ref.verify(&page);
    return page;
}

pub fn stage(self: *Self, ref: pages.Reference, page: *const pages.Page) !pages.Reference {
    if (!std.mem.allEqual(u8, &ref.location, 0)) return error.UnsupportedPageLocation;
    try ref.verify(page);
    if (self.cached(ref) != null) return ref;
    var observation = observations.begin(self.journal.observer, .storage_operation, "page.stage", self.journal.parent_context);
    defer observation.finish();
    const parent = self.journal.parent_context;
    self.journal.parent_context = observation.span.context;
    defer self.journal.parent_context = parent;
    self.stageImpl(ref, page) catch |err| {
        observation.fail(err);
        return err;
    };
    return ref;
}
fn stageImpl(self: *Self, ref: pages.Reference, page: *const pages.Page) !void {
    // Content identity makes a repeated staging attempt reconcilable. Verify
    // an existing immutable body; never overwrite it or recreate during load.
    // Absence is expected during staging, so it is not a failed page.load span.
    if (self.fetchImpl(ref)) |existing| {
        self.remember(ref, existing);
        return;
    } else |err| if (err != error.PageUnavailable) return err;

    var bytes: [pages.max_encoded_bytes]u8 = undefined;
    const body = try page.encode(&bytes);
    var name: [45]u8 = undefined;
    self.requests += 1;
    self.create_payload_bytes_attempted += body.len;
    var created = try self.journal.send(.{ .create_stream = .{
        .stream = self.stream(ref, &name),
        .options = .{ .body = body, .closed = true, .content_type = "application/octet-stream" },
    } });
    defer created.deinit();
    try created.head.requireSuccess();
    // A success status alone is not evidence of the intended immutable body.
    const verified = try self.fetch(ref);
    self.created += 1;
    self.remember(ref, verified);
}
