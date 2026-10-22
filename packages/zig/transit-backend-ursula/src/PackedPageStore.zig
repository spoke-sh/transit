//! Immutable pages and blocks in privately prepared, accounted, closed segments.
//! A complete segment is verified before authority publication can reference it.
const std = @import("std");
const adapter = @import("root.zig");
const pages = @import("transit_core").pages;
const blocks = @import("transit_core").blocks;
const bulk = @import("transit_core").protocol.Blocks;
const observations = @import("transit_observability");
const Self = @This();
const Segment = adapter.Segment;
const Queue = adapter.AllocationQueue;
const max_record_bytes = 2 + std.base64.standard.Encoder.calcSize(pages.max_encoded_bytes);
const max_block_record_bytes = 2 + std.base64.standard.Encoder.calcSize(4 + bulk.max_block_bytes);
pub const max_resident_pages = 4096;
pub const Cached = struct { reference: pages.Reference, page: pages.Page, used: u64 };

allocator: std.mem.Allocator,
authority: adapter.Journal,
limits: Queue.Limits = .{},
candidate: ?Segment = null,
control: bool = false,
cache: []?Cached,
access: u64 = 0,
hits: u64 = 0,
misses: u64 = 0,
created: u64 = 0,
requests: u64 = 0,
create_payload_bytes_attempted: u64 = 0,
blocks_created: u64 = 0,
segments_created: u64 = 0,
block_payload_bytes_attempted: u64 = 0,

pub fn init(allocator: std.mem.Allocator, authority: adapter.Journal, resident_pages: usize) !Self {
    if (resident_pages > max_resident_pages) return error.InvalidPageCacheBudget;
    const cache = try allocator.alloc(?Cached, resident_pages);
    @memset(cache, null);
    return .{ .allocator = allocator, .authority = authority, .cache = cache };
}

pub fn deinit(self: *Self) void {
    self.discard();
    self.allocator.free(self.cache);
    self.* = undefined;
}
pub fn allocations(self: *Self) !Queue {
    return Queue.init(self.authority, self.limits);
}
/// Bootstrap-only creation. Loads never recreate missing history.
pub fn create(self: *Self) !void {
    var queue = try self.allocations();
    try queue.create();
    var collection = adapter.StorageCollection.init(self.authority);
    try collection.create();
}
pub fn begin(self: *Self, epoch: u64, control: bool) !void {
    var nonce: [16]u8 = undefined;
    try self.authority.client.http.io.randomSecure(&nonce);
    try self.beginIdentity(.{ .epoch = epoch, .nonce = nonce }, control);
}
fn beginIdentity(self: *Self, identity: Segment.Identity, control: bool) !void {
    if (self.candidate != null) return error.ActiveStorageCandidate;
    try self.limits.validate();
    self.candidate = try Segment.init(self.allocator, identity, self.limits.candidate_bytes);
    self.control = control;
}
pub fn discard(self: *Self) void {
    if (self.candidate) |*candidate| candidate.deinit();
    self.candidate = null;
}
fn stream(self: *Self, identity: Segment.Identity, name: *[45]u8) !adapter.ursula.Stream {
    name.* = try identity.name(self.authority.stream.bucket, self.authority.stream.name);
    return .{ .bucket = self.authority.stream.bucket, .name = name };
}
pub const Seal = struct {
    definition: @import("transit_core").protocol.Growth.Definition,
    identity: Segment.Identity,
    frames: u16,
    bytes: u32,
    digest: [32]u8,
};
/// Reserve the full encoded allocation before creation. The creator makes one
/// create attempt only. A conditional seal proves it progressed beyond the
/// create reply and verified every frame; a lost reply never triggers recreation.
pub fn finish(self: *Self) !void {
    const candidate = if (self.candidate) |*value| value else return error.NoStorageCandidate;
    defer self.discard();
    if (candidate.count == 0) return;
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(candidate.body[0..candidate.used], &digest, .{});
    const seal: Seal = .{ .definition = @import("transit_core").protocol.Growth.current_definition, .identity = candidate.identity, .frames = candidate.count, .bytes = candidate.used, .digest = digest };
    var seal_bytes: [2048]u8 = undefined;
    var out: std.Io.Writer = .fixed(&seal_bytes);
    try std.json.Stringify.value(seal, .{}, &out);
    var queue = try self.allocations();
    try queue.reserve(.{ .identity = candidate.identity, .bytes = candidate.used + out.buffered().len + 1, .frames = candidate.count, .data_bytes = candidate.used, .fenced = false, .digest = seal.digest, .control = false }, self.control);
    var name: [45]u8 = undefined;
    const target = try self.stream(candidate.identity, &name);
    // Ursula accepts one JSON value or an array on writes and returns NDJSON.
    // Frame offsets and the reserved size describe its normalized stored bytes.
    const payload = try self.allocator.alloc(u8, candidate.used + 1);
    defer self.allocator.free(payload);
    payload[0] = '[';
    for (candidate.body[0..candidate.used], 0..) |byte, i| payload[i + 1] = if (byte == '\n') ',' else byte;
    payload[candidate.used] = ']';
    self.requests +|= 1;
    var created = try self.authority.send(.{ .create_stream = .{ .stream = target, .options = .{ .content_type = "application/json", .body = payload } } });
    defer created.deinit();
    try created.head.requireSuccess();
    const metadata = try created.head.metadata();
    if (created.head.status != .created or metadata.closed == true or metadata.record_start != 0 or metadata.record_next != candidate.count) return error.InvalidSegmentReceipt;
    // Group exact known frames within the borrowed client's response ceiling.
    var first: u16 = 0;
    while (first < candidate.count) {
        var count: u16 = 0;
        var bytes: usize = 0;
        while (first + count < candidate.count) {
            const size = (try candidate.frame(first + count)).len + 1;
            if (bytes + size > 192 * 1024) break;
            bytes += size;
            count += 1;
        }
        if (count == 0) return error.InvalidStorageFrame;
        self.requests +|= 1;
        var read = try self.authority.send(.{ .read = .{ .stream = target, .options = .{ .position = .{ .record = first }, .max_records = count } } });
        defer read.deinit();
        try read.head.requireSuccess();
        const range = try read.head.metadata();
        if (range.record_start != first or range.record_next != first + count or read.body.len != bytes) return error.InvalidSegmentReceipt;
        var offset: usize = 0;
        for (first..first + count) |ordinal| {
            const frame = try candidate.frame(ordinal);
            if (!std.mem.eql(u8, read.body[offset..][0..frame.len], frame) or read.body[offset + frame.len] != '\n') return error.CorruptSegment;
            offset += frame.len + 1;
        }
        first += count;
    }
    self.requests +|= 1;
    var closed = try self.authority.send(.{ .append = .{ .stream = target, .body = out.buffered(), .options = .{ .content_type = "application/json", .closed = true, .record_match = candidate.count } } });
    defer closed.deinit();
    try closed.head.requireSuccess();
    const final = try closed.head.metadata();
    if (final.closed != true or final.record_start != candidate.count or final.record_next != @as(u64, candidate.count) + 1) return error.InvalidSegmentReceipt;
    self.segments_created +|= 1;
    self.rememberCandidate(candidate);
}

fn rememberCandidate(self: *Self, candidate: *const Segment) void {
    if (self.cache.len == 0 or candidate.count == 0) return;
    const start_ordinal: u16 = if (candidate.count > self.cache.len) @intCast(candidate.count - self.cache.len) else 0;
    for (start_ordinal..candidate.count) |ordinal| {
        const frame = candidate.frame(ordinal) catch continue;
        if (frame.len <= max_record_bytes and std.mem.startsWith(u8, frame, "\"VFBH")) {
            if (decodeRecord(self.allocator, frame)) |page| {
                if (page.reference()) |base_ref| {
                    var ref = base_ref;
                    ref.location = candidate.identity.locate(ordinal) catch continue;
                    self.remember(ref, page);
                } else |_| {}
            } else |_| {}
        }
    }
}
fn private(self: *Self, location: Segment.Location) !?[]const u8 {
    const address = try Segment.Address.decode(location);
    if (self.candidate) |*candidate| if (std.meta.eql(candidate.identity, address.identity)) return try candidate.frame(address.ordinal);
    return null;
}
pub fn clearCache(self: *Self) void {
    @memset(self.cache, null);
}
pub fn residentBytes(self: *const Self) usize {
    return self.cache.len * @sizeOf(?Cached) + if (self.candidate) |*candidate| candidate.residentBytes() else @as(usize, 0);
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
    const candidate = if (self.candidate) |*value| value else return error.NoStorageCandidate;
    const buffer = try self.allocator.alloc(u8, max_block_record_bytes);
    defer self.allocator.free(buffer);
    const body = try encodeBlock(bytes, buffer);
    const location = try candidate.append(body);
    self.block_payload_bytes_attempted +|= body.len;
    self.blocks_created +|= 1;
    return .{ .value = spec, .location = location };
}
pub fn loadBlock(self: *Self, reference: blocks.Reference, output: []u8) ![]const u8 {
    try reference.value.validate();
    if (output.len < reference.value.bytes) return error.BlockBufferTooSmall;
    if (try self.private(reference.location)) |body| return decodeBlock(body, reference.value, output);
    const address = try Segment.Address.decode(reference.location);
    var observation = observations.begin(self.authority.observer, .storage_operation, "block.load", self.authority.parent_context);
    defer observation.finish();
    return self.fetchBlock(reference, address, output) catch |err| {
        observation.fail(err);
        return err;
    };
}
fn fetchBlock(self: *Self, reference: blocks.Reference, address: Segment.Address, output: []u8) ![]const u8 {
    const position = address.ordinal;
    var name: [45]u8 = undefined;
    self.requests +|= 1;
    var response = try self.authority.send(.{ .read = .{ .stream = try self.stream(address.identity, &name), .options = .{
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
    if (try self.private(ref.location)) |body| {
        const page = try decodeRecord(self.allocator, body);
        try ref.verify(&page);
        return page;
    }
    const address = try Segment.Address.decode(ref.location);
    if (self.cached(ref)) |page| return page;
    self.misses +|= 1;
    var observation = observations.begin(self.authority.observer, .storage_operation, "page.load", self.authority.parent_context);
    defer observation.finish();
    const page = self.fetch(ref, address) catch |err| {
        observation.fail(err);
        return err;
    };
    self.remember(ref, page);
    return page;
}
fn fetch(self: *Self, ref: pages.Reference, address: Segment.Address) !pages.Page {
    const position = address.ordinal;
    var name: [45]u8 = undefined;
    self.requests +|= 1;
    // Record and byte limits are mutually exclusive upstream. One record plus
    // the borrowed client's response ceiling bounds transport allocation; the
    // page codec independently enforces its smaller encoded-size contract.
    var response = try self.authority.send(.{ .read = .{ .stream = try self.stream(address.identity, &name), .options = .{ .position = .{ .record = position }, .max_records = 1 } } });
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
    const candidate = if (self.candidate) |*value| value else return error.NoStorageCandidate;
    var bytes: [max_record_bytes]u8 = undefined;
    const body = try encodeRecord(page, &bytes);
    var result = ref;
    result.location = try candidate.append(body);
    self.create_payload_bytes_attempted +|= body.len;
    self.created +|= 1;
    return result;
}
/// This bound belongs to tree mutation work. The whole command's storage
/// candidate has its own frame/byte bounds and one verified closing seal.
pub fn stageMany(self: *Self, batch: []const pages.Page, output: []pages.Reference) !void {
    if (batch.len == 0 or batch.len > pages.mutation_batch or output.len != batch.len) return error.PageMutationBudget;
    var references: [pages.mutation_batch]pages.Reference = undefined;
    for (batch, 0..) |*page, i| references[i] = try self.stage(try page.reference(), page);
    @memcpy(output, references[0..batch.len]);
}
fn located(ref: pages.Reference, ordinal: u64) pages.Reference {
    var result = ref;
    result.location = (Segment.Identity{ .epoch = 1, .nonce = @splat(1) }).locate(ordinal) catch unreachable;
    return result;
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

    try store.beginIdentity(.{ .epoch = 1, .nonce = @splat(9) }, false);
    const staged_ref = try store.stage(ref, &page);
    store.rememberCandidate(&store.candidate.?);
    store.discard();
    try t.expect(store.cached(staged_ref) != null);
}
