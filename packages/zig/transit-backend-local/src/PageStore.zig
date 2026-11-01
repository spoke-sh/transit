//! Bounded page cache and operation staging over immutable local objects.
//! Private pages are buffered in bounded groups; finish seals all dependencies
//! durably before the native WAL can publish their candidate root.
const std = @import("std");
const core = @import("transit_core");
const p = core.protocol;
const pages = core.pages;
const Backend = @import("Backend.zig");
const Self = @This();
const envelope_bytes = 40;
pub const max_resident_pages = 4096;
pub const Cached = struct { reference: pages.Reference, page: pages.Page, used: u64 };
const Staged = struct { reference: pages.Reference, page: pages.Page };

backend: *Backend,
observe: @import("Diagnostics.zig") = .{},
cache: []?Cached,
pending: []Staged,
pending_count: usize = 0,
access: u64 = 0,
hits: u64 = 0,
misses: u64 = 0,
created: u64 = 0,
create_payload_bytes_attempted: u64 = 0,
blocks_created: u64 = 0,
block_payload_bytes_attempted: u64 = 0,
control: bool = false,
/// Private collection marks/fences are inventoried but do not trigger a new pass.
track_activity: bool = true,
candidate: ?struct { epoch: u64, nonce: [16]u8, ordinal: u64 = 0, bytes: usize = 0 } = null,

pub fn init(backend: *Backend, resident_pages: usize) !Self {
    if (resident_pages > max_resident_pages) return error.InvalidPageCacheBudget;
    const cache = try backend.allocator.alloc(?Cached, resident_pages);
    errdefer backend.allocator.free(cache);
    @memset(cache, null);
    return .{ .backend = backend, .cache = cache, .pending = try backend.allocator.alloc(Staged, pages.mutation_batch) };
}

pub fn deinit(self: *Self) void {
    self.backend.allocator.free(self.cache);
    self.backend.allocator.free(self.pending);
    self.* = undefined;
}

pub fn begin(self: *Self, epoch: u64, control: bool) !void {
    if (self.candidate != null) return error.ActiveStorageCandidate;
    if (epoch == 0) return error.InvalidStorageEpoch;
    var nonce: [16]u8 = undefined;
    try self.backend.io.randomSecure(&nonce);
    self.control = control;
    self.candidate = .{ .epoch = epoch, .nonce = nonce };
}

pub fn discard(self: *Self) void {
    self.pending_count = 0;
    self.candidate = null;
}

pub fn finish(self: *Self) !void {
    if (self.candidate == null) return error.NoStorageCandidate;
    // Preparing a root may read its own unflushed children. No candidate may
    // escape preparation until every buffered page has crossed all barriers.
    try self.flush();
    self.discard();
}

fn location(self: *Self, kind: u8, digest: [32]u8, size: usize) ![32]u8 {
    const candidate = if (self.candidate) |*value| value else return error.NoStorageCandidate;
    if (size > self.backend.limits.candidate_bytes or candidate.bytes > self.backend.limits.candidate_bytes - size) return error.StorageCandidateTooLarge;
    candidate.bytes += size;
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.local.native.object.v1\x00");
    hash.update(&p.Growth.definition_bytes);
    hash.update(&.{kind});
    var coordinates: [16]u8 = undefined;
    std.mem.writeInt(u64, coordinates[0..8], candidate.epoch, .little);
    std.mem.writeInt(u64, coordinates[8..16], candidate.ordinal, .little);
    candidate.ordinal = try std.math.add(u64, candidate.ordinal, 1);
    hash.update(&coordinates);
    hash.update(&candidate.nonce);
    hash.update(&digest);
    return hash.finalResult();
}

fn key(kind: u8, address: [32]u8, out: *[96]u8) ![]const u8 {
    if (std.mem.allEqual(u8, &address, 0)) return error.UnsupportedPageLocation;
    return std.fmt.bufPrint(out, "native/{c}/{x}", .{ kind, &address });
}

fn envelope(kind: u8, output: []u8) void {
    output[0..8].* = "TNAT\x01\x00\x00\x00".*;
    output[5] = kind;
    output[8..40].* = p.Growth.definition_bytes;
}

fn unwrap(kind: u8, bytes: []const u8) ![]const u8 {
    if (bytes.len < envelope_bytes or !std.mem.eql(u8, bytes[0..5], "TNAT\x01") or bytes[5] != kind or !std.mem.allEqual(u8, bytes[6..8], 0)) return error.InvalidStorageObject;
    if (!std.mem.eql(u8, bytes[8..40], &p.Growth.definition_bytes)) return error.IncompatibleDefinition;
    return bytes[envelope_bytes..];
}

pub fn stage(self: *Self, reference: pages.Reference, page: *const pages.Page) !pages.Reference {
    return self.observe.run(self.backend.io, "page.stage", stageImpl, .{ self, reference, page });
}

fn stageImpl(self: *Self, reference: pages.Reference, page: *const pages.Page) !pages.Reference {
    if (!std.mem.allEqual(u8, &reference.location, 0)) return error.UnsupportedPageLocation;
    try reference.verify(page);
    if (self.pending_count == self.pending.len) try self.flush();
    var bytes: [envelope_bytes + pages.max_encoded_bytes]u8 = undefined;
    envelope('p', &bytes);
    const body = try page.encode(bytes[envelope_bytes..]);
    const encoded = bytes[0 .. envelope_bytes + body.len];
    var result = reference;
    result.location = try self.location('p', reference.digest, encoded.len);
    self.pending[self.pending_count] = .{ .reference = result, .page = page.* };
    self.pending_count += 1;
    return result;
}

pub fn stageMany(self: *Self, batch: []const pages.Page, output: []pages.Reference) !void {
    if (batch.len != output.len or batch.len > pages.mutation_batch) return error.InvalidPageBatch;
    var references: [pages.mutation_batch]pages.Reference = undefined;
    for (batch, references[0..batch.len]) |*page, *reference| reference.* = try self.stage(try page.reference(), page);
    @memcpy(output, references[0..batch.len]);
}

/// Coalesce single-page tree/path mutations across one native candidate. The
/// directory never grows with history and also works with a zero-page cache.
noinline fn flush(self: *Self) !void {
    const batch = self.pending[0..self.pending_count];
    if (batch.len == 0) return;
    var buffers: [pages.mutation_batch][envelope_bytes + pages.max_encoded_bytes]u8 = undefined;
    var puts: [pages.mutation_batch]Backend.NativePut = undefined;
    for (batch, buffers[0..batch.len], puts[0..batch.len]) |*staged, *bytes, *put| {
        envelope('p', bytes);
        const body = try staged.page.encode(bytes[envelope_bytes..]);
        const encoded = bytes[0 .. envelope_bytes + body.len];
        self.create_payload_bytes_attempted +|= encoded.len;
        self.observe.metrics.request_payload_bytes +|= encoded.len;
        put.* = .{ .address = staged.reference.location, .bytes = encoded };
    }
    try self.observe.run(self.backend.io, "page.stage_batch", Backend.putNativePages, .{ self.backend, self.candidate.?.epoch, puts[0..batch.len], self.control, self.track_activity });
    for (batch) |*staged| {
        self.created +|= 1;
        self.remember(staged.reference, staged.page);
    }
    self.pending_count = 0;
}

pub fn load(self: *Self, reference: pages.Reference) !pages.Page {
    for (self.pending[0..self.pending_count]) |*staged| if (std.meta.eql(staged.reference, reference)) {
        self.hits +|= 1;
        return staged.page;
    };
    for (self.cache) |*slot| if (slot.*) |*cached| {
        if (std.meta.eql(cached.reference, reference)) {
            self.hits +|= 1;
            cached.used = self.touch();
            return cached.page;
        }
    };
    self.misses +|= 1;
    return self.observe.run(self.backend.io, "page.load", loadImpl, .{ self, reference });
}

fn loadImpl(self: *Self, reference: pages.Reference) !pages.Page {
    var name: [96]u8 = undefined;
    var bytes: [envelope_bytes + pages.max_encoded_bytes]u8 = undefined;
    const encoded = try self.backend.read(try key('p', reference.location, &name), &bytes);
    self.observe.metrics.response_bytes +|= encoded.len;
    const page = try pages.Page.decode(self.backend.allocator, try unwrap('p', encoded));
    try reference.verify(&page);
    self.remember(reference, page);
    return page;
}

pub fn stageBlock(self: *Self, spec: p.Blocks.Spec, body: []const u8) !core.blocks.Reference {
    return self.observe.run(self.backend.io, "block.stage", stageBlockImpl, .{ self, spec, body });
}

fn stageBlockImpl(self: *Self, spec: p.Blocks.Spec, body: []const u8) !core.blocks.Reference {
    try spec.verify(body);
    var bytes: [envelope_bytes + p.Blocks.max_block_bytes]u8 = undefined;
    envelope('b', &bytes);
    @memcpy(bytes[envelope_bytes..][0..body.len], body);
    const encoded = bytes[0 .. envelope_bytes + body.len];
    const address = try self.location('b', spec.digest, encoded.len);
    self.block_payload_bytes_attempted +|= encoded.len;
    self.observe.metrics.request_payload_bytes +|= encoded.len;
    try self.backend.putNativeTracked(self.candidate.?.epoch, .block, address, encoded, self.control, self.track_activity);
    self.blocks_created +|= 1;
    return .{ .value = spec, .location = address };
}

pub fn loadBlock(self: *Self, reference: core.blocks.Reference, output: []u8) ![]const u8 {
    return self.observe.run(self.backend.io, "block.load", loadBlockImpl, .{ self, reference, output });
}

fn loadBlockImpl(self: *Self, reference: core.blocks.Reference, output: []u8) ![]const u8 {
    try reference.value.validate();
    if (output.len < reference.value.bytes) return error.BlockBufferTooSmall;
    var name: [96]u8 = undefined;
    var bytes: [envelope_bytes + p.Blocks.max_block_bytes]u8 = undefined;
    const encoded = try self.backend.read(try key('b', reference.location, &name), &bytes);
    self.observe.metrics.response_bytes +|= encoded.len;
    const body = try unwrap('b', encoded);
    try reference.value.verify(body);
    @memcpy(output[0..body.len], body);
    return output[0..body.len];
}

pub fn clearCache(self: *Self) void {
    @memset(self.cache, null);
}

pub fn residentBytes(self: *const Self) usize {
    return self.cache.len * @sizeOf(?Cached) + self.pending.len * @sizeOf(Staged);
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

fn remember(self: *Self, reference: pages.Reference, page: pages.Page) void {
    if (self.cache.len == 0) return;
    var selected: usize = 0;
    var oldest: u64 = std.math.maxInt(u64);
    for (self.cache, 0..) |slot, i| {
        const cached = slot orelse {
            selected = i;
            break;
        };
        if (cached.used < oldest) {
            selected = i;
            oldest = cached.used;
        }
    }
    self.cache[selected] = .{ .reference = reference, .page = page, .used = self.touch() };
}
