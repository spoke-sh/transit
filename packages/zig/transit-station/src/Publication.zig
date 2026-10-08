//! Bounded immutable publication over growing KV. Every write remains private
//! until the enclosing turn commits. See contracts/STATION_PUBLICATION_V1.md.
const std = @import("std");
const p = @import("transit_client").protocol;
const Turn = @import("Turn.zig");
const Publication = @This();
const Sha256 = std.crypto.hash.sha2.Sha256;

resource: u64,
domain: Domain,
namespace: u64,
/// Registry of publication owners, not an authorization or dispatch policy.
pub const Domain = enum(u32) { application = 1, query_request = 2, query_result = 3, table_mutation = 4, document = 5, exchange = 6, application_definition = 7, table = 8, catalog = 9, _ };
pub const chunk_bytes = 256;
pub const cleanup_chunks = 2;
pub const State = enum(u8) { staging = 1, published = 2, abandoned = 3, retired = 4 };
pub const Outcome = enum { changed, duplicate };
pub const Limits = struct {
    record_bytes: u32,
    staging_bytes: u64,
    staging_records: u32,
    pub fn validate(self: Limits) !void {
        if (self.record_bytes == 0 or self.staging_bytes < self.record_bytes or self.staging_records == 0) return error.InvalidPublicationLimits;
    }
};
pub const Spec = struct {
    format: u32,
    length: u32,
    digest: [32]u8,
    pub fn chunks(self: Spec) u32 {
        return self.length / chunk_bytes + @intFromBool(self.length % chunk_bytes != 0);
    }
    pub fn size(self: Spec, index: u32) !u16 {
        if (index >= self.chunks()) return error.InvalidPublicationOrdinal;
        return @intCast(@min(chunk_bytes, self.length - index * chunk_bytes));
    }
    pub fn validate(self: Spec) !void {
        if (self.format == 0) return error.InvalidPublicationFormat;
    }
};
/// A streaming chain, independent of chunk delivery or native hash state layout.
pub const Digest = struct {
    pub fn initial(format: u32, length: u32) [32]u8 {
        var hash = Sha256.init(.{});
        hash.update("transit.station.publication.v1\x00");
        var header: [8]u8 = undefined;
        std.mem.writeInt(u32, header[0..4], format, .little);
        std.mem.writeInt(u32, header[4..8], length, .little);
        hash.update(&header);
        return hash.finalResult();
    }
    pub fn next(chain: [32]u8, index: u32, bytes: []const u8) ![32]u8 {
        if (bytes.len == 0 or bytes.len > chunk_bytes) return error.InvalidPublicationChunk;
        var hash = Sha256.init(.{});
        hash.update(&.{1});
        hash.update(&chain);
        var header: [6]u8 = undefined;
        std.mem.writeInt(u32, header[0..4], index, .little);
        std.mem.writeInt(u16, header[4..6], @intCast(bytes.len), .little);
        hash.update(&header);
        hash.update(bytes);
        return hash.finalResult();
    }
    /// Convenience for already-owned finite input, never used to load a record.
    pub fn of(format: u32, bytes: []const u8) !Spec {
        if (bytes.len > std.math.maxInt(u32)) return error.PublicationTooLarge;
        var spec: Spec = .{ .format = format, .length = @intCast(bytes.len), .digest = initial(format, @intCast(bytes.len)) };
        try spec.validate();
        for (0..spec.chunks()) |i| {
            const offset = i * chunk_bytes;
            spec.digest = try next(spec.digest, @intCast(i), bytes[offset..][0..try spec.size(@intCast(i))]);
        }
        return spec;
    }
};
pub const Budget = struct {
    limits: Limits,
    bytes: u64 = 0,
    records: u32 = 0,
    pub fn encode(self: Budget) !p.Value {
        try self.validate();
        var bytes: [32]u8 = undefined;
        bytes[0..4].* = "SPB1".*;
        std.mem.writeInt(u32, bytes[4..8], self.limits.record_bytes, .little);
        std.mem.writeInt(u64, bytes[8..16], self.limits.staging_bytes, .little);
        std.mem.writeInt(u32, bytes[16..20], self.limits.staging_records, .little);
        std.mem.writeInt(u64, bytes[20..28], self.bytes, .little);
        std.mem.writeInt(u32, bytes[28..32], self.records, .little);
        return p.Value.init(&bytes);
    }
    pub fn decode(value: p.Value) !Budget {
        try value.validate();
        if (value.len != 32 or !std.mem.eql(u8, value.data[0..4], "SPB1")) return error.InvalidPublicationBudget;
        const result: Budget = .{ .limits = .{
            .record_bytes = std.mem.readInt(u32, value.data[4..8], .little),
            .staging_bytes = std.mem.readInt(u64, value.data[8..16], .little),
            .staging_records = std.mem.readInt(u32, value.data[16..20], .little),
        }, .bytes = std.mem.readInt(u64, value.data[20..28], .little), .records = std.mem.readInt(u32, value.data[28..32], .little) };
        try result.validate();
        return result;
    }
    fn validate(self: Budget) !void {
        try self.limits.validate();
        if (self.bytes > self.limits.staging_bytes or self.records > self.limits.staging_records or (self.records == 0 and self.bytes != 0)) return error.InvalidPublicationBudget;
    }
    fn release(self: *Budget, spec: Spec) !void {
        if (self.records == 0 or self.bytes < spec.length) return error.InvalidPublicationBudget;
        self.records -= 1;
        self.bytes -= spec.length;
    }
};
pub const Descriptor = struct {
    state: State = .staging,
    reserved: bool = true,
    spec: Spec,
    written: u32 = 0,
    collected: u32 = 0,
    chain: [32]u8,
    publisher: u64 = 0,
    input: u64 = 0,
    pub fn encode(self: Descriptor) !p.Value {
        try self.validate();
        var bytes: [104]u8 = @splat(0);
        bytes[0..4].* = "SPR1".*;
        bytes[4] = @backingInt(self.state);
        bytes[5] = @intFromBool(self.reserved);
        std.mem.writeInt(u32, bytes[8..12], self.spec.format, .little);
        std.mem.writeInt(u32, bytes[12..16], self.spec.length, .little);
        std.mem.writeInt(u32, bytes[16..20], self.written, .little);
        std.mem.writeInt(u32, bytes[20..24], self.collected, .little);
        bytes[24..56].* = self.spec.digest;
        bytes[56..88].* = self.chain;
        std.mem.writeInt(u64, bytes[88..96], self.publisher, .little);
        std.mem.writeInt(u64, bytes[96..104], self.input, .little);
        return p.Value.init(&bytes);
    }
    pub fn decode(value: p.Value) !Descriptor {
        try value.validate();
        if (value.len != 104 or !std.mem.eql(u8, value.data[0..4], "SPR1") or value.data[5] > 1 or value.data[6] != 0 or value.data[7] != 0) return error.InvalidPublicationDescriptor;
        const result: Descriptor = .{
            .state = std.enums.fromInt(State, value.data[4]) orelse return error.InvalidPublicationDescriptor,
            .reserved = value.data[5] == 1,
            .spec = .{ .format = std.mem.readInt(u32, value.data[8..12], .little), .length = std.mem.readInt(u32, value.data[12..16], .little), .digest = value.data[24..56].* },
            .written = std.mem.readInt(u32, value.data[16..20], .little),
            .collected = std.mem.readInt(u32, value.data[20..24], .little),
            .chain = value.data[56..88].*,
            .publisher = std.mem.readInt(u64, value.data[88..96], .little),
            .input = std.mem.readInt(u64, value.data[96..104], .little),
        };
        try result.validate();
        return result;
    }
    fn validate(self: Descriptor) !void {
        try self.spec.validate();
        if (self.written > self.spec.chunks() or self.collected > self.written) return error.InvalidPublicationDescriptor;
        if (self.written == 0 and !std.mem.eql(u8, &self.chain, &Digest.initial(self.spec.format, self.spec.length))) return error.InvalidPublicationDescriptor;
        switch (self.state) {
            .staging => if (!self.reserved or self.collected != 0 or self.publisher != 0 or self.input != 0) return error.InvalidPublicationDescriptor,
            .abandoned => if (self.publisher != 0 or self.input != 0 or (!self.reserved and self.collected != self.written)) return error.InvalidPublicationDescriptor,
            .published, .retired => {
                if (self.reserved or self.written != self.spec.chunks() or self.publisher == 0 or self.input == 0 or !std.mem.eql(u8, &self.chain, &self.spec.digest)) return error.InvalidPublicationDescriptor;
                if (self.state == .published and self.collected != 0) return error.InvalidPublicationDescriptor;
            },
        }
    }
};
/// Namespace/record IDs are caller-chosen nonzero u64s, scoped by resource/domain.
/// Fixed-width big-endian keys preserve lexical grouping without narrow IDs.
pub fn key(domain: Domain, namespace: u64, tag: u8, id: u64, index: u32) p.Value {
    var bytes: [27]u8 = undefined;
    bytes[0..2].* = "\x00P".*;
    std.mem.writeInt(u32, bytes[2..6], @backingInt(domain), .big);
    std.mem.writeInt(u64, bytes[6..14], namespace, .big);
    bytes[14] = tag;
    std.mem.writeInt(u64, bytes[15..23], id, .big);
    std.mem.writeInt(u32, bytes[23..27], index, .big);
    return p.Value.init(&bytes) catch unreachable;
}
pub fn create(turn: *Turn, domain: Domain, namespace: u64, limits: Limits) !Publication {
    if (@backingInt(domain) == 0 or namespace == 0) return error.InvalidPublicationIdentity;
    try limits.validate();
    const self: Publication = .{ .resource = turn.view.resource, .domain = domain, .namespace = namespace };
    if (try turn.read(key(domain, namespace, 'b', 0, 0))) |value| {
        if (!std.meta.eql((try Budget.decode(value)).limits, limits)) return error.PublicationLimitsChanged;
    } else try turn.write(key(domain, namespace, 'b', 0, 0), try (Budget{ .limits = limits }).encode());
    return self;
}
fn check(self: Publication, source: anytype) !void {
    if (@backingInt(self.domain) == 0 or self.namespace == 0) return error.InvalidPublicationIdentity;
    if (self.resource != source.view.resource) return error.CrossResourceTransaction;
}
pub fn budget(self: Publication, source: anytype) !Budget {
    try self.check(source);
    return Budget.decode((try source.read(key(self.domain, self.namespace, 'b', 0, 0))) orelse return error.PublicationNamespaceNotFound);
}
pub fn inspect(self: Publication, source: anytype, id: u64) !Descriptor {
    try self.check(source);
    if (id == 0) return error.InvalidPublicationIdentity;
    return Descriptor.decode((try source.read(key(self.domain, self.namespace, 'r', id, 0))) orelse return error.PublicationNotFound);
}
pub fn begin(self: Publication, turn: *Turn, id: u64, spec: Spec) !Outcome {
    const before = turn.decision;
    errdefer turn.decision = before;
    try self.check(turn);
    if (id == 0) return error.InvalidPublicationIdentity;
    try spec.validate();
    if (try turn.read(key(self.domain, self.namespace, 'r', id, 0))) |value| {
        const existing = try Descriptor.decode(value);
        if (existing.state == .abandoned or existing.state == .retired) return error.PublicationClosed;
        if (!std.meta.eql(existing.spec, spec)) return error.PublicationIdentityConflict;
        return .duplicate;
    }
    var quota = try self.budget(turn);
    if (spec.length > quota.limits.record_bytes) return error.PublicationTooLarge;
    if (quota.records == quota.limits.staging_records or spec.length > quota.limits.staging_bytes - quota.bytes) return error.PublicationQuotaExceeded;
    quota.records += 1;
    quota.bytes += spec.length;
    try turn.write(key(self.domain, self.namespace, 'b', 0, 0), try quota.encode());
    try turn.write(key(self.domain, self.namespace, 'r', id, 0), try (Descriptor{ .spec = spec, .chain = Digest.initial(spec.format, spec.length) }).encode());
    return .changed;
}
pub fn append(self: Publication, turn: *Turn, id: u64, index: u32, bytes: []const u8) !Outcome {
    const before = turn.decision;
    errdefer turn.decision = before;
    var record = try self.inspect(turn, id);
    if (record.state == .abandoned or record.state == .retired) return error.PublicationClosed;
    if (bytes.len != try record.spec.size(index)) return error.InvalidPublicationChunk;
    if (index > record.written) return error.PublicationGap;
    const location = key(self.domain, self.namespace, 'c', id, index);
    const previous = try turn.read(location);
    if (index < record.written) {
        const value = previous orelse return error.MissingPublicationChunk;
        if (!std.mem.eql(u8, value.slice(), bytes)) return error.PublicationIdentityConflict;
        return .duplicate;
    }
    if (record.state != .staging or previous != null) return error.InvalidPublicationDescriptor;
    record.chain = try Digest.next(record.chain, index, bytes);
    record.written += 1;
    try turn.write(location, try p.Value.init(bytes));
    try turn.write(key(self.domain, self.namespace, 'r', id, 0), try record.encode());
    return .changed;
}
/// Leaves two mutation slots for an application head/correlation, plus outputs.
/// Callers must discard the whole proposal if their later composition fails.
pub fn publish(self: Publication, turn: *Turn, id: u64) !Outcome {
    const before = turn.decision;
    errdefer turn.decision = before;
    var record = try self.inspect(turn, id);
    if (record.state == .published) return .duplicate;
    if (record.state != .staging) return error.PublicationClosed;
    if (record.written != record.spec.chunks()) return error.IncompletePublication;
    if (!std.mem.eql(u8, &record.chain, &record.spec.digest)) return error.InvalidPublicationDigest;
    var quota = try self.budget(turn);
    try quota.release(record.spec);
    record.state = .published;
    record.reserved = false;
    record.publisher = turn.delivery.pid;
    record.input = turn.delivery.input.position;
    try turn.write(key(self.domain, self.namespace, 'b', 0, 0), try quota.encode());
    try turn.write(key(self.domain, self.namespace, 'r', id, 0), try record.encode());
    return .changed;
}
/// Stage already-owned finite bytes using the remaining native mutation slots.
/// Repeated descriptor/quota writes coalesce in the private proposal. False
/// means bounded progress that must commit before resuming; true means private
/// publication, not a committed cursor or an application acceptance result.
/// A capacity failure with no progress and every other error restore this call.
pub fn stage(self: Publication, turn: *Turn, id: u64, spec: Spec, bytes: []const u8) !bool {
    const before = turn.decision;
    errdefer turn.decision = before;
    if (!std.meta.eql(try Digest.of(spec.format, bytes), spec)) return error.InvalidPublicationDigest;
    var progressed = false;
    while (true) {
        const record = self.inspect(turn, id) catch |err| blk: {
            if (err != error.PublicationNotFound) return err;
            _ = try self.begin(turn, id, spec);
            progressed = true;
            break :blk try self.inspect(turn, id);
        };
        if (!std.meta.eql(record.spec, spec)) return error.PublicationIdentityConflict;
        switch (record.state) {
            .abandoned, .retired => return error.PublicationClosed,
            .published => return true,
            .staging => {
                const result = if (record.written < spec.chunks()) append: {
                    const offset = @as(usize, record.written) * chunk_bytes;
                    break :append self.append(turn, id, record.written, bytes[offset..][0..try spec.size(record.written)]);
                } else self.publish(turn, id);
                _ = result catch |err| {
                    if (err != error.MutationBudgetExceeded or !progressed) return err;
                    return false;
                };
                progressed = true;
            },
        }
    }
}
/// Explicit disposition. Abandonment retains quota until collect completes.
pub fn abandon(self: Publication, turn: *Turn, id: u64) !Outcome {
    var record = try self.inspect(turn, id);
    if (record.state == .abandoned) return .duplicate;
    if (record.state != .staging) return error.PublicationClosed;
    record.state = .abandoned;
    try turn.write(key(self.domain, self.namespace, 'r', id, 0), try record.encode());
    return .changed;
}
pub fn retire(self: Publication, turn: *Turn, id: u64) !Outcome {
    var record = try self.inspect(turn, id);
    if (record.state == .retired) return .duplicate;
    if (record.state != .published) return error.PublicationNotPublished;
    record.state = .retired;
    try turn.write(key(self.domain, self.namespace, 'r', id, 0), try record.encode());
    return .changed;
}
/// Removes at most two current KV chunks. Protected older roots still own their
/// bytes. The permanent descriptor survives; no identity can be reused.
pub fn collect(self: Publication, turn: *Turn, id: u64) !bool {
    const before = turn.decision;
    errdefer turn.decision = before;
    var record = try self.inspect(turn, id);
    if (record.state != .abandoned and record.state != .retired) return error.PublicationNotClosed;
    const end = record.collected + @min(cleanup_chunks, record.written - record.collected);
    if (record.collected == end and !record.reserved) return true;
    for (record.collected..end) |i| {
        const location = key(self.domain, self.namespace, 'c', id, @intCast(i));
        const value = (try turn.read(location)) orelse return error.MissingPublicationChunk;
        if (value.len != try record.spec.size(@intCast(i))) return error.InvalidPublicationChunk;
        try turn.write(location, null);
    }
    record.collected = end;
    const complete = record.collected == record.written;
    if (complete and record.reserved) {
        var quota = try self.budget(turn);
        try quota.release(record.spec);
        record.reserved = false;
        try turn.write(key(self.domain, self.namespace, 'b', 0, 0), try quota.encode());
    }
    try turn.write(key(self.domain, self.namespace, 'r', id, 0), try record.encode());
    return complete;
}
pub const Basis = struct {
    resource: u64,
    revision: u64,
    source: union(enum) { view: u64, version: p.Growth.ReadVersionId },
};
pub const Cursor = struct {
    basis: Basis,
    domain: Domain,
    namespace: u64,
    id: u64,
    spec: Spec,
    index: u32 = 0,
    chain: [32]u8,
};
pub const Part = struct {
    bytes: p.Value,
    /// Only null proves completion. Earlier bytes are a provisional prefix.
    next: ?Cursor,
};
fn basis(source: anytype) !Basis {
    if (@hasField(@typeInfo(@TypeOf(source)).pointer.child, "decision")) {
        for (source.decision.mutations) |mutation| if (mutation != null) return error.PublicationReadAfterMutation;
    }
    return .{ .resource = source.view.resource, .revision = source.view.revision, .source = if (@TypeOf(source.view.id) == u64) .{ .view = source.view.id } else .{ .version = source.view.id } };
}
pub fn open(self: Publication, source: anytype, id: u64) !Cursor {
    const captured = try basis(source);
    const record = try self.inspect(source, id);
    if (record.state != .published) return error.PublicationNotPublished;
    return .{ .basis = captured, .domain = self.domain, .namespace = self.namespace, .id = id, .spec = record.spec, .chain = Digest.initial(record.spec.format, record.spec.length) };
}
pub fn read(self: Publication, source: anytype, cursor: Cursor) !Part {
    if (!std.meta.eql(cursor.basis, try basis(source)) or cursor.domain != self.domain or cursor.namespace != self.namespace or cursor.basis.resource != self.resource) return error.StalePublicationCursor;
    // Even an empty record's completion rechecks the authorized source. Native
    // cursors are owned continuation state, never bearer access capabilities.
    const record = try self.inspect(source, cursor.id);
    if (record.state != .published or !std.meta.eql(record.spec, cursor.spec)) return error.InvalidPublicationDescriptor;
    if (cursor.index > cursor.spec.chunks() or (cursor.index == cursor.spec.chunks() and cursor.spec.length != 0)) return error.InvalidPublicationOrdinal;
    var next = cursor;
    var bytes: p.Value = .{};
    if (cursor.spec.length != 0) {
        bytes = (try source.read(key(self.domain, self.namespace, 'c', cursor.id, cursor.index))) orelse return error.MissingPublicationChunk;
        try bytes.validate();
        if (bytes.len != try cursor.spec.size(cursor.index)) return error.InvalidPublicationChunk;
        next.chain = try Digest.next(cursor.chain, cursor.index, bytes.slice());
        next.index += 1;
    }
    if (next.index == cursor.spec.chunks()) {
        if (!std.mem.eql(u8, &next.chain, &cursor.spec.digest)) return error.InvalidPublicationDigest;
        return .{ .bytes = bytes, .next = null };
    }
    return .{ .bytes = bytes, .next = next };
}
