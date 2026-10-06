//! Immutable typed Table records in captured/retained growing KV. Small records
//! cost one private write. Large records use resumable bounded Publication work.
const std = @import("std");
const p = @import("transit_client").protocol;
const f = @import("transit_fuze");
const Turn = @import("Turn.zig");
const Pub = @import("Publication.zig");
const Index = @import("ImmutableIndex.zig");
const Data = @import("TableData.zig");
const Self = @This();

resource: u64,
object: u64,
pub const schema_format: u32 = 0x54534301;
pub const inline_bytes = 246;
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
    var committed = turn.committed();
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
fn encode(spec: Pub.Spec, bytes: []const u8) !p.Value {
    if (bytes.len > inline_bytes) return error.InvalidTablePage;
    var buffer: [256]u8 = undefined;
    buffer[0..4].* = "STP1".*;
    std.mem.writeInt(u32, buffer[4..8], spec.format, .little);
    std.mem.writeInt(u16, buffer[8..10], @intCast(bytes.len), .little);
    @memcpy(buffer[10..][0..bytes.len], bytes);
    return p.Value.init(buffer[0 .. 10 + bytes.len]);
}
fn validateInline(value: p.Value, spec: Pub.Spec) !void {
    try value.validate();
    if (value.len < 10 or !std.mem.eql(u8, value.data[0..4], "STP1") or
        std.mem.readInt(u32, value.data[4..8], .little) != spec.format or
        std.mem.readInt(u16, value.data[8..10], .little) != spec.length or value.len != spec.length + 10) return error.InvalidTablePage;
}
/// Each call either makes the record readable or prepares one resumable staging
/// step. Ready small writes still belong to this private turn. The owner must
/// reserve IDs, keep input/source identity and publish its head/outcome atomically.
pub fn stage(self: Self, turn: *Turn, ref: Reference, bytes: []const u8) !Step {
    const before = turn.decision;
    errdefer turn.decision = before;
    const limit = try self.check(turn);
    try validate(ref);
    if (ref.spec.length > limit) return error.PublicationTooLarge;
    if (!std.meta.eql(try Pub.Digest.of(ref.spec.format, bytes), ref.spec)) return error.InvalidTablePage;
    const inline_key = key(self.object, 'i', ref.id);
    const small = try turn.read(inline_key);
    const large = try turn.read(key(self.object, 'r', ref.id));
    if (ref.spec.length <= inline_bytes) {
        if (large != null) return error.TablePageIdentityConflict;
        const expected = try encode(ref.spec, bytes);
        if (small) |value| {
            if (!value.eql(expected)) return error.TablePageIdentityConflict;
        } else try turn.write(inline_key, expected);
        return .ready;
    }
    if (small != null) return error.TablePageIdentityConflict;
    const pubn = self.publication();
    const descriptor = if (large) |value| try Pub.Descriptor.decode(value) else {
        _ = try pubn.begin(turn, ref.id, ref.spec);
        return .progress;
    };
    if (!std.meta.eql(descriptor.spec, ref.spec)) return error.TablePageIdentityConflict;
    switch (descriptor.state) {
        .abandoned, .retired => return error.TablePageClosed,
        .published => return .ready,
        .staging => {
            if (descriptor.written < ref.spec.chunks()) {
                const offset = @as(usize, descriptor.written) * Pub.chunk_bytes;
                _ = try pubn.append(turn, ref.id, descriptor.written, bytes[offset..][0..try ref.spec.size(descriptor.written)]);
            } else {
                _ = try pubn.publish(turn, ref.id);
                return .ready;
            }
            return .progress;
        },
    }
}
pub fn read(self: Self, source: anytype, ref: Reference, output: []u8) ![]const u8 {
    try prefetch(source, &.{ key(self.object, 'd', 0), key(self.object, if (ref.spec.length <= inline_bytes) 'i' else 'r', ref.id) });
    const limit = try self.check(source);
    try validate(ref);
    if (ref.spec.length > limit) return error.InvalidTablePage;
    if (ref.spec.length > output.len) return error.TablePageBufferTooSmall;
    const pubn = self.publication();
    if (ref.spec.length <= inline_bytes) {
        const value = (try source.read(key(self.object, 'i', ref.id))) orelse return error.TablePageNotFound;
        // Decode validates the header; copy directly from the owned local value.
        try validateInline(value, ref.spec);
        @memcpy(output[0..ref.spec.length], value.data[10..value.len]);
    } else {
        var cursor = try pubn.open(source, ref.id);
        if (!std.meta.eql(cursor.spec, ref.spec)) return error.InvalidTablePage;
        var offset: usize = 0;
        while (true) {
            if (cursor.index % p.Growth.page_size == 0) {
                var keys: [p.Growth.page_size]p.Value = undefined;
                const count = @min(keys.len, cursor.spec.chunks() - cursor.index);
                for (keys[0..count], 0..) |*address, i| address.* = Pub.key(.table, self.object, 'c', ref.id, cursor.index + @as(u32, @intCast(i)));
                try prefetch(source, keys[0..count]);
            }
            const part = try pubn.read(source, cursor);
            if (part.bytes.len > ref.spec.length - offset) return error.InvalidTablePage;
            @memcpy(output[offset..][0..part.bytes.len], part.bytes.slice());
            offset += part.bytes.len;
            cursor = part.next orelse break;
        }
        if (offset != ref.spec.length) return error.InvalidTablePage;
    }
    const bytes = output[0..ref.spec.length];
    if (!std.meta.eql(try Pub.Digest.of(ref.spec.format, bytes), ref.spec)) return error.InvalidTablePage;
    return bytes;
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
    const after = key(self.object, if (large) 'r' else 'i', at - 1);
    var committed = turn.committed();
    const page = try committed.page(after);
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
                if (entry.key.len != 27 or std.mem.readInt(u32, entry.key.data[23..27], .big) != 0) return error.InvalidTablePage;
                const id = std.mem.readInt(u64, entry.key.data[15..23], .big);
                if (id < at) return error.InvalidTablePage;
                if (result == null and id < end) result = id;
            }
        } else ended = true;
    }
    if (page.next) |next| if (previous.eql(after) or !previous.eql(next)) return error.InvalidTableStorage;
    return result;
}
/// The owner must prove this ID belongs exclusively to closed unpublished work.
/// Accepted/retained data must never be sent here. Descriptors and quota release
/// follow Publication's existing bounded retirement/collection rules.
pub fn collect(self: Self, turn: *Turn, id: u64, large: bool) !Step {
    const before = turn.decision;
    errdefer turn.decision = before;
    _ = try self.check(turn);
    if (id == 0) return error.InvalidTablePage;
    const small = try turn.read(key(self.object, 'i', id));
    const descriptor = try turn.read(key(self.object, 'r', id));
    if (small != null and descriptor != null) return error.TablePageIdentityConflict;
    if (!large) {
        if (descriptor != null) return error.TablePageIdentityConflict;
        const value = small orelse return .ready;
        if (value.len < 10) return error.InvalidTablePage;
        const spec = try Pub.Digest.of(std.mem.readInt(u32, value.data[4..8], .little), value.data[10..value.len]);
        try validate(.{ .id = id, .spec = spec });
        try validateInline(value, spec);
        try turn.write(key(self.object, 'i', id), null);
        return .ready;
    }
    if (small != null) return error.TablePageIdentityConflict;
    const record = try Pub.Descriptor.decode(descriptor orelse return error.TablePageNotFound);
    try validate(.{ .id = id, .spec = record.spec });
    if (record.spec.length <= inline_bytes) return error.InvalidTablePage;
    const pubn = self.publication();
    switch (record.state) {
        .staging => {
            _ = try pubn.abandon(turn, id);
            return .progress;
        },
        .published => {
            _ = try pubn.retire(turn, id);
            return .progress;
        },
        .abandoned, .retired => return if (try pubn.collect(turn, id)) .ready else .progress,
    }
}
pub fn Reader(comptime Source: type) type {
    return struct {
        pages: Self,
        source: Source,
        cache: ?*Index.Cache = null,
        local_cache: Index.Cache = .{},
        pub fn load(self: *@This(), ref: Index.Reference, output: []u8) ![]const u8 {
            try ref.validate();
            if (ref.spec.length <= inline_bytes) return self.pages.read(self.source, .{ .id = ref.id, .spec = ref.spec }, output);
            // Node bodies otherwise displace their own native chunks when a
            // row scan revisits the root. Keep only eight verified nodes;
            // Cache.load still opens each publication at this exact basis.
            try prefetch(self.source, &.{ key(self.pages.object, 'd', 0), key(self.pages.object, 'r', ref.id) });
            if (ref.spec.length > try self.pages.check(self.source)) return error.InvalidTablePage;
            return (self.cache orelse &self.local_cache).load(self.pages.publication(), self.source, ref, output);
        }
        pub fn loadBlob(self: *@This(), ref: Data.Blob, output: []u8) ![]const u8 {
            try ref.validate();
            return self.pages.read(self.source, .{ .id = ref.id, .spec = ref.spec }, output);
        }
        /// At most eight row headers and 32 chunk keys. Large rows fall back to
        /// normal incremental reads. No chunks are acquired until every header
        /// has passed the same manifest, spec and publication-lifecycle checks.
        pub fn prefetchBlobs(self: *@This(), refs: []const Data.Blob) !void {
            if (refs.len == 0 or refs.len > p.Growth.page_size) return error.InvalidTablePageSize;
            var headers: [1 + p.Growth.page_size]p.Value = undefined;
            headers[0] = key(self.pages.object, 'd', 0);
            for (refs, 0..) |ref, i| {
                try ref.validate();
                headers[i + 1] = key(self.pages.object, if (ref.spec.length <= inline_bytes) 'i' else 'r', ref.id);
            }
            var at: usize = 0;
            while (at < refs.len + 1) {
                const end = @min(at + p.Growth.page_size, refs.len + 1);
                try prefetch(self.source, headers[at..end]);
                at = end;
            }
            const limit = try self.pages.check(self.source);
            for (refs) |ref| {
                if (ref.spec.length > limit) return error.InvalidTablePage;
                if (ref.spec.length <= inline_bytes) {
                    const value = (try self.source.read(key(self.pages.object, 'i', ref.id))) orelse return error.TablePageNotFound;
                    try validateInline(value, ref.spec);
                } else {
                    const cursor = try self.pages.publication().open(self.source, ref.id);
                    if (!std.meta.eql(cursor.spec, ref.spec)) return error.InvalidTablePage;
                }
            }
            var chunks: [32]p.Value = undefined;
            var count: usize = 0;
            outer: for (refs) |ref| {
                if (ref.spec.length <= inline_bytes) continue;
                for (0..ref.spec.chunks()) |i| {
                    if (count == chunks.len) break :outer;
                    chunks[count] = Pub.key(.table, self.pages.object, 'c', ref.id, @intCast(i));
                    count += 1;
                }
            }
            at = 0;
            while (at < count) {
                const end = @min(at + p.Growth.page_size, count);
                try prefetch(self.source, chunks[at..end]);
                at = end;
            }
        }
    };
}
