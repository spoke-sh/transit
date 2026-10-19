//! Immutable typed Table records over native bulk blocks. The resource root
//! publishes complete blocks atomically with the owning Table head and receipt.
const std = @import("std");
const p = @import("transit_client").protocol;
const f = @import("transit_fuze");
const Turn = @import("Turn.zig");
const Pub = @import("Publication.zig");
const Index = @import("ImmutableIndex.zig");
const Data = @import("TableData.zig");
const Self = @This();
const Blocks = @import("BlockRecord.zig");

resource: u64,
object: u64,
pub const schema_format: u32 = 0x54534301;
pub const Reference = struct { id: u64, spec: Pub.Spec };
pub const Step = enum { ready, progress };

fn definition() [32]u8 {
    var bytes: [32]u8 = undefined;
    _ = std.fmt.hexToBytes(&bytes, @tagName(p.Growth.current_definition)) catch unreachable;
    return bytes;
}
pub fn key(object: u64, tag: u8, id: u64) p.Value {
    return Pub.key(.table, object, tag, id, 0);
}
fn manifest(record_bytes: u32) p.Value {
    var bytes: [40]u8 = undefined;
    bytes[0..4].* = "STM1".*;
    bytes[4..36].* = definition();
    std.mem.writeInt(u32, bytes[36..40], record_bytes, .little);
    return p.Value.init(&bytes) catch unreachable;
}
fn checkManifest(value: p.Value) !u32 {
    try value.validate();
    if (value.len != 40 or !std.mem.eql(u8, value.data[0..4], "STM1")) return error.InvalidTableStorage;
    if (!std.mem.eql(u8, value.data[4..36], &definition())) return error.IncompatibleTableStorage;
    const limit = std.mem.readInt(u32, value.data[36..40], .little);
    if (limit == 0) return error.InvalidTableStorage;
    return limit;
}
fn publication(self: Self) Pub {
    return .{ .resource = self.resource, .domain = .table, .namespace = self.object };
}
fn check(self: Self, source: anytype) !u32 {
    if (self.object == 0 or self.resource == 0 or self.resource > p.max_counter) return error.InvalidTableStorage;
    if (source.view.resource != self.resource) return error.CrossResourceTransaction;
    return checkManifest((try source.read(key(self.object, 'd', 0))) orelse return error.TableStorageNotFound);
}
fn validate(ref: Reference) !void {
    if (ref.id == 0) return error.InvalidTablePage;
    const limit: usize = switch (ref.spec.format) {
        Index.format => Index.node_bytes,
        Data.row_format => f.TableRow.max_bytes,
        schema_format => f.TableSchema.max_bytes,
        else => return error.InvalidTablePage,
    };
    if (ref.spec.length == 0 or ref.spec.length > limit) return error.InvalidTablePage;
}
fn emptyNamespace(turn: *Turn, object: u64) !void {
    const full = key(object, 0, 0);
    const prefix = try p.Value.init(full.data[0..14]);
    for (turn.decision.mutations) |slot| if (slot) |mutation| {
        if (std.mem.startsWith(u8, mutation.key.slice(), prefix.slice())) return error.InvalidTableStorage;
    };
    for (turn.decision.blocks.mutations) |slot| if (slot) |mutation| {
        if (std.mem.startsWith(u8, mutation.key.slice(), prefix.slice())) return error.InvalidTableStorage;
    };
    var committed = turn.committed();
    const allocated = try committed.blockPage(prefix);
    for (allocated.entries) |slot| if (slot) |entry| {
        if (std.mem.startsWith(u8, entry.key.slice(), prefix.slice())) return error.IncompatibleTableStorage;
    };
    const page = try committed.page(prefix);
    var previous = prefix;
    var ended = false;
    for (page.entries) |slot| {
        if (slot) |entry| {
            try p.State.key(entry.key);
            try entry.value.validate();
            if (ended or entry.revision > turn.view.revision or std.mem.order(u8, previous.slice(), entry.key.slice()) != .lt) return error.InvalidTableStorage;
            previous = entry.key;
            if (std.mem.startsWith(u8, entry.key.slice(), prefix.slice())) return error.IncompatibleTableStorage;
        } else ended = true;
    }
    if (page.next) |next| if (previous.eql(prefix) or !previous.eql(next)) return error.InvalidTableStorage;
}
/// Initialization does not publish a Table head or make an existing namespace
/// compatible. Missing/foreign manifests with prior records are never adopted.
pub fn create(turn: *Turn, object: u64, limits: Pub.Limits) !Self {
    const before = turn.decision;
    errdefer turn.decision = before;
    if (object == 0) return error.InvalidTableStorage;
    const self: Self = .{ .resource = turn.view.resource, .object = object };
    if (try turn.read(key(object, 'd', 0))) |value| {
        const limit = try checkManifest(value);
        const quota = try self.publication().budget(turn);
        if (!std.meta.eql(quota.limits, limits) or limit != limits.record_bytes) return error.PublicationLimitsChanged;
    } else {
        if (try turn.read(key(object, 'b', 0)) != null) return error.IncompatibleTableStorage;
        try emptyNamespace(turn, object);
        _ = try Pub.create(turn, .table, object, limits);
        try turn.write(key(object, 'd', 0), manifest(limits.record_bytes));
    }
    return self;
}
fn blocks(self: Self) Blocks {
    return .{ .publication = self.publication() };
}
/// Complete records are private native blocks; larger records make bounded,
/// quota-accounted progress. The final Table head remains the acceptance edge.
pub fn stage(self: Self, turn: *Turn, ref: Reference, bytes: []const u8) !Step {
    const before = turn.decision;
    errdefer turn.decision = before;
    const limit = try self.check(turn);
    try validate(ref);
    if (ref.spec.length > limit) return error.PublicationTooLarge;
    const ready = self.blocks().stage(turn, ref.id, ref.spec, bytes) catch |err| return switch (err) {
        error.PublicationIdentityConflict => error.TablePageIdentityConflict,
        error.PublicationClosed => error.TablePageClosed,
        else => err,
    };
    return if (ready) .ready else .progress;
}
pub fn read(self: Self, source: anytype, ref: Reference, output: []u8) ![]const u8 {
    try prefetch(source, &.{ key(self.object, 'd', 0), key(self.object, 'b', 0) });
    const limit = try self.check(source);
    try validate(ref);
    if (ref.spec.length > limit) return error.InvalidTablePage;
    if (ref.spec.length > output.len) return error.TablePageBufferTooSmall;
    return self.blocks().read(source, ref.id, ref.spec, output) catch |err| return switch (err) {
        error.MissingPublicationChunk => error.TablePageNotFound,
        error.InvalidPublicationDigest, error.InvalidPublicationChunk => error.InvalidTablePage,
        else => err,
    };
}
fn prefetch(source: anytype, keys: []const p.Value) !void {
    const Source = @typeInfo(@TypeOf(source)).pointer.child;
    if (comptime @hasDecl(Source, "prefetch")) try source.prefetch(keys);
}
/// Locate one allocated record in a closed reservation without walking unused
/// IDs. This reads one native page and never mixes private writes into the scan.
pub fn nextRecord(self: Self, turn: *Turn, large: bool, at: u64, end: u64) !?u64 {
    _ = try self.check(turn);
    if (at == 0 or end < at) return error.InvalidTableReservation;
    if (at == end) return null;
    var after = key(self.object, if (large) 'r' else 'c', at - 1);
    if (!large) std.mem.writeInt(u32, after.data[23..27], std.math.maxInt(u32), .big);
    var committed = turn.committed();
    const page = if (large) blk: {
        const metadata = try committed.page(after);
        var result: Turn.BlockPage = .{ .next = metadata.next };
        for (metadata.entries, &result.entries) |slot, *entry| if (slot) |value| {
            entry.* = .{ .key = value.key, .revision = value.revision, .value = try p.Blocks.Spec.of(value.value.slice()) };
        };
        break :blk result;
    } else try committed.blockPage(after);
    var previous = after;
    var ended = false;
    var result: ?u64 = null;
    for (page.entries) |slot| {
        if (slot) |entry| {
            try p.State.key(entry.key);
            try entry.value.validate();
            if (ended or entry.revision > turn.view.revision or std.mem.order(u8, previous.slice(), entry.key.slice()) != .lt) return error.InvalidTableStorage;
            previous = entry.key;
            if (std.mem.startsWith(u8, entry.key.slice(), after.data[0..15])) {
                if (entry.key.len != 27 or (large and std.mem.readInt(u32, entry.key.data[23..27], .big) != 0)) return error.InvalidTablePage;
                const id = std.mem.readInt(u64, entry.key.data[15..23], .big);
                if (id < at) return error.InvalidTablePage;
                if (result == null and id < end) result = id;
            }
        } else ended = true;
    }
    if (page.next) |next| if (previous.eql(after) or !previous.eql(next)) return error.InvalidTableStorage;
    return result;
}
/// The owner proves this record belongs exclusively to closed unpublished work.
pub fn collect(self: Self, turn: *Turn, id: u64, large: bool) !Step {
    _ = large;
    _ = try self.check(turn);
    return if (try self.blocks().collect(turn, id)) .ready else .progress;
}
/// Eight verified nodes at one immutable cut, never an authorization cache.
pub const Cache = struct {
    basis: ?Pub.Basis = null,
    object: u64 = 0,
    next: usize = 0,
    entries: [8]?struct { ref: Reference, bytes: [Index.node_bytes]u8 } = @splat(null),
};
pub fn Reader(comptime Source: type) type {
    return struct {
        pages: Self,
        source: Source,
        cache: ?*Cache = null,
        local_cache: Cache = .{},
        pub fn load(self: *@This(), ref: Index.Reference, output: []u8) ![]const u8 {
            try ref.validate();
            if (ref.spec.length > output.len) return error.TablePageBufferTooSmall;
            // Touch the authorized source before reusing immutable bytes. Query
            // hosts additionally recheck current policy at each disclosure.
            if (ref.spec.length > try self.pages.check(self.source)) return error.InvalidTablePage;
            const basis: Pub.Basis = .{ .resource = self.source.view.resource, .revision = self.source.view.revision, .source = if (@TypeOf(self.source.view.id) == u64) .{ .view = self.source.view.id } else .{ .version = self.source.view.id } };
            const cache = self.cache orelse &self.local_cache;
            if (cache.basis == null or !std.meta.eql(cache.basis.?, basis) or cache.object != self.pages.object) cache.* = .{ .basis = basis, .object = self.pages.object };
            const reference: Reference = .{ .id = ref.id, .spec = ref.spec };
            for (&cache.entries) |*slot| if (slot.*) |*entry| if (std.meta.eql(entry.ref, reference)) {
                @memcpy(output[0..ref.spec.length], entry.bytes[0..ref.spec.length]);
                return output[0..ref.spec.length];
            };
            const bytes = try self.pages.read(self.source, reference, output);
            var entry: @typeInfo(@TypeOf(cache.entries[0])).optional.child = .{ .ref = reference, .bytes = undefined };
            @memcpy(entry.bytes[0..bytes.len], bytes);
            cache.entries[cache.next] = entry;
            cache.next = (cache.next + 1) % cache.entries.len;
            return bytes;
        }
        pub fn loadBlob(self: *@This(), ref: Data.Blob, output: []u8) ![]const u8 {
            try ref.validate();
            return self.pages.read(self.source, .{ .id = ref.id, .spec = ref.spec }, output);
        }
        /// Prefetch at most eight complete single-block rows and 128 KiB. Larger
        /// records use their bounded block reader; bytes are never truncated.
        pub fn prefetchBlobs(self: *@This(), refs: []const Data.Blob) !void {
            if (refs.len == 0 or refs.len > p.Growth.page_size) return error.InvalidTablePageSize;
            const limit = try self.pages.check(self.source);
            var keys: [p.Growth.page_size]p.Value = undefined;
            var count: usize = 0;
            var size: usize = 0;
            for (refs) |ref| {
                try ref.validate();
                if (ref.spec.length > limit) return error.InvalidTablePage;
                if (ref.spec.length > Blocks.block_bytes) continue;
                const encoded = Blocks.encodedSize(ref.spec.length);
                if (size + encoded > p.Blocks.max_batch_bytes) break;
                keys[count] = self.pages.blocks().key(ref.id, 0);
                count += 1;
                size += encoded;
            }
            if (count != 0) try self.source.prefetchBlocks(keys[0..count]);
        }
    };
}
