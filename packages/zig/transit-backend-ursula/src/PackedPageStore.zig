//! Immutable pages packed into an append-only journal. Opaque locators carry
//! verified record coordinates; only a separate authority append publishes roots.
const std = @import("std");
const adapter = @import("root.zig");
const pages = @import("transit_core").pages;
const blocks = @import("transit_core").blocks;
const bulk = @import("transit_core").protocol.Blocks;
const observations = @import("transit_observability");
const Self = @This();
const max_record_bytes = 2 + std.base64.standard.Encoder.calcSize(pages.max_encoded_bytes);
const max_block_record_bytes = 2 + std.base64.standard.Encoder.calcSize(4 + bulk.max_block_bytes);
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
blocks_created: u64 = 0,
block_payload_bytes_attempted: u64 = 0,

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
    return coordinateLocation(ref.location);
}
fn coordinateLocation(location: [16]u8) !u64 {
    if (location[0] != 1 or !std.mem.allEqual(u8, location[1..8], 0)) return error.UnsupportedPageLocation;
    return std.mem.readInt(u64, location[8..16], .big);
}

/// Immutable bytes use their own domain and frame. Publication metadata owns
/// the reference; a successful append alone grants no resource visibility.
pub fn stageBlock(self: *Self, spec: bulk.Spec, bytes: []const u8) !blocks.Reference {
    try spec.verify(bytes);
    var observation = observations.begin(self.authority.observer, .storage_operation, "block.stage", self.authority.parent_context);
    defer observation.finish();
    return self.appendBlock(spec, bytes) catch |err| {
        observation.fail(err);
        return err;
    };
}
fn appendBlock(self: *Self, spec: bulk.Spec, bytes: []const u8) !blocks.Reference {
    const buffer = try self.allocator.alloc(u8, max_block_record_bytes);
    defer self.allocator.free(buffer);
    const body = try encodeBlock(bytes, buffer);
    self.requests +|= 1;
    self.block_payload_bytes_attempted +|= body.len;
    var response = try self.authority.send(.{ .append = .{
        .stream = self.journal().stream,
        .body = body,
        .options = .{ .content_type = "application/json" },
    } });
    defer response.deinit();
    try response.head.requireSuccess();
    const metadata = try response.head.metadata();
    const position = try appendedAt(metadata.record_start, metadata.record_next);
    const reference: blocks.Reference = .{ .value = spec, .location = located(.{ .digest = spec.digest }, position).location };
    // Establish complete immutable availability before returning a publishable
    // reference. Missing/corrupt readback never becomes an accepted empty block.
    const verified = try self.allocator.alloc(u8, spec.bytes);
    defer self.allocator.free(verified);
    _ = try self.loadBlock(reference, verified);
    self.blocks_created +|= 1;
    return reference;
}
pub fn loadBlock(self: *Self, reference: blocks.Reference, output: []u8) ![]const u8 {
    try reference.value.validate();
    if (output.len < reference.value.bytes) return error.BlockBufferTooSmall;
    const position = try coordinateLocation(reference.location);
    var observation = observations.begin(self.authority.observer, .storage_operation, "block.load", self.authority.parent_context);
    defer observation.finish();
    return self.fetchBlock(reference, position, output) catch |err| {
        observation.fail(err);
        return err;
    };
}
fn fetchBlock(self: *Self, reference: blocks.Reference, position: u64, output: []u8) ![]const u8 {
    self.requests +|= 1;
    var response = try self.authority.send(.{ .read = .{ .stream = self.journal().stream, .options = .{
        .position = .{ .record = position },
        .max_records = 1,
    } } });
    defer response.deinit();
    if (response.head.status == .not_found or response.head.status == .gone) return error.BlockUnavailable;
    try response.head.requireSuccess();
    const metadata = try response.head.metadata();
    if (metadata.record_start != position or metadata.record_next != try std.math.add(u64, position, 1)) return error.BlockUnavailable;
    const body = response.body;
    if (body.len == 0 or body[body.len - 1] != '\n') return error.CorruptBlock;
    return decodeBlock(body[0 .. body.len - 1], reference.value, output);
}
fn encodeBlock(bytes: []const u8, output: []u8) ![]const u8 {
    if (bytes.len > bulk.max_block_bytes) return error.BlockTooLarge;
    var binary: [4 + bulk.max_block_bytes]u8 = undefined;
    binary[0..4].* = "TBK1".*;
    @memcpy(binary[4..][0..bytes.len], bytes);
    const count = std.base64.standard.Encoder.calcSize(4 + bytes.len);
    if (output.len < count + 2) return error.BlockBufferTooSmall;
    output[0] = '"';
    _ = std.base64.standard.Encoder.encode(output[1..][0..count], binary[0 .. 4 + bytes.len]);
    output[count + 1] = '"';
    return output[0 .. count + 2];
}
fn decodeBlock(body: []const u8, spec: bulk.Spec, output: []u8) ![]const u8 {
    try spec.validate();
    if (output.len < spec.bytes) return error.BlockBufferTooSmall;
    if (body.len < 2 or body.len > max_block_record_bytes or body[0] != '"' or body[body.len - 1] != '"') return error.CorruptBlock;
    const encoded = body[1 .. body.len - 1];
    const size = std.base64.standard.Decoder.calcSizeForSlice(encoded) catch return error.CorruptBlock;
    if (size != 4 + spec.bytes) return error.CorruptBlock;
    var binary: [4 + bulk.max_block_bytes]u8 = undefined;
    std.base64.standard.Decoder.decode(binary[0..size], encoded) catch return error.CorruptBlock;
    if (!std.mem.eql(u8, binary[0..4], "TBK1")) return error.CorruptBlock;
    const bytes = binary[4..size];
    try spec.verify(bytes);
    var canonical: [max_block_record_bytes]u8 = undefined;
    if (!std.mem.eql(u8, body, try encodeBlock(bytes, &canonical))) return error.CorruptBlock;
    @memcpy(output[0..bytes.len], bytes);
    return output[0..bytes.len];
}

test "immutable block records separate page framing and verify complete bytes" {
    const t = std.testing;
    const bytes: [bulk.max_block_bytes]u8 = @splat(19);
    const spec = try bulk.Spec.of(&bytes);
    var encoded: [max_block_record_bytes]u8 = undefined;
    const record = try encodeBlock(&bytes, &encoded);
    var output: [bulk.max_block_bytes]u8 = undefined;
    try t.expectEqualSlices(u8, &bytes, try decodeBlock(record, spec, &output));
    var wrong = spec;
    wrong.digest[0] ^= 1;
    try t.expectError(error.CorruptBlock, decodeBlock(record, wrong, &output));
    try t.expectError(error.BlockBufferTooSmall, decodeBlock(record, spec, output[0..1]));
    const empty = try bulk.Spec.of("");
    const empty_record = try encodeBlock("", &encoded);
    try t.expectEqualStrings("", try decodeBlock(empty_record, empty, &output));
    for ([_][]const u8{ "{}", "\"\"", "\"VFBHMQ==\"", "\"VEJL\"", "\"VEJLMR==\"" }) |invalid| {
        try t.expectError(error.CorruptBlock, decodeBlock(invalid, empty, &output));
    }
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
    // Record reads use newline-delimited JSON framing. Remove exactly that
    // provider delimiter before checking our canonical record envelope.
    const body = response.body;
    if (body.len == 0 or body[body.len - 1] != '\n') return error.CorruptPage;
    const page = try decodeRecord(self.allocator, body[0 .. body.len - 1]);
    try ref.verify(&page);
    return page;
}
// Ursula's pinned record-coordinate profile addresses JSON records. The
// backend owns a canonical base64 JSON-string envelope around generic compact
// page bytes; no provider framing or base64 policy enters the core tree.
fn encodeRecord(page: *const pages.Page, output: []u8) ![]const u8 {
    var bytes: [pages.max_encoded_bytes]u8 = undefined;
    const binary = try page.encode(&bytes);
    const count = std.base64.standard.Encoder.calcSize(binary.len);
    if (count + 2 > output.len) return error.PageValueTooLarge;
    output[0] = '"';
    _ = std.base64.standard.Encoder.encode(output[1..][0..count], binary);
    output[count + 1] = '"';
    return output[0 .. count + 2];
}
fn decodeRecord(allocator: std.mem.Allocator, body: []const u8) !pages.Page {
    if (body.len < 2 or body.len > max_record_bytes or body[0] != '"' or body[body.len - 1] != '"') return error.CorruptPage;
    const encoded = body[1 .. body.len - 1];
    const size = std.base64.standard.Decoder.calcSizeForSlice(encoded) catch return error.CorruptPage;
    if (size > pages.max_encoded_bytes) return error.CorruptPage;
    var bytes: [pages.max_encoded_bytes]u8 = undefined;
    std.base64.standard.Decoder.decode(bytes[0..size], encoded) catch return error.CorruptPage;
    const page = try pages.Page.decode(allocator, bytes[0..size]);
    var canonical: [max_record_bytes]u8 = undefined;
    if (!std.mem.eql(u8, body, try encodeRecord(&page, &canonical))) return error.CorruptPage;
    return page;
}

test "packed records preserve compact pages and reject noncanonical or old records" {
    const t = std.testing;
    var page: pages.Page = .{ .count = 1, .body = .{ .leaf = @splat(null) } };
    page.body.leaf[0] = .{ .key = try .init("a"), .value = try .init("b") };
    var bytes: [max_record_bytes]u8 = undefined;
    const record = try encodeRecord(&page, &bytes);
    const decoded = try decodeRecord(t.allocator, record);
    try (try page.reference()).verify(&decoded);
    // The envelope is one JSON string, without escaping or whitespace. Its
    // canonical form is also checked after decoding the complete binary page.
    for ([_][]const u8{ "", "{}", "[]", "null", "\"!\"", "\"VFBH\"\n", " \"VFBH\"", "\"\\u0056FBH\"" }) |bad| {
        try t.expectError(error.CorruptPage, decodeRecord(t.allocator, bad));
    }
    const last = record.len - 3;
    bytes[last] = '!';
    try t.expectError(error.CorruptPage, decodeRecord(t.allocator, record));
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
    var bytes: [max_record_bytes]u8 = undefined;
    const body = try encodeRecord(page, &bytes);
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

/// Bounded immutable staging, with the same format-1 record locators as stage.
/// A complete acknowledgement is required before any references are returned.
/// Accepted but unacknowledged bytes are retained orphans; never retry here.
pub fn stageMany(self: *Self, batch: []const pages.Page, output: []pages.Reference) !void {
    if (batch.len == 0 or batch.len > pages.mutation_batch or output.len != batch.len) return error.PageMutationBudget;
    const encoded = try self.allocator.alloc([max_record_bytes]u8, batch.len);
    defer self.allocator.free(encoded);
    var frames: [pages.mutation_batch][]const u8 = undefined;
    var references: [pages.mutation_batch]pages.Reference = undefined;
    var bytes: u64 = 0;
    for (batch, 0..) |*page, i| {
        references[i] = try page.reference();
        frames[i] = try encodeRecord(page, &encoded[i]);
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
    var page: pages.Page = .{ .count = 1, .body = .{ .leaf = @splat(null) } };
    page.body.leaf[0] = .{ .key = try .init("a"), .value = try .init("b") };
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
