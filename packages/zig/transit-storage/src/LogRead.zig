//! Immutable finite Stream read bases and owner-authenticated coverage. Only a
//! published live pin retains the basis; neither content nor a MAC grants access.
const std = @import("std");
const p = @import("transit_protocol");
const d = p.DataLifecycle;
const q = p.StreamQueue;
const read = p.StreamRead;
const Declaration = @import("LogDeclaration.zig");
const Objects = @import("TransitObjectStore.zig");
const pages = @import("TreeStore.zig").pages;
pub const max_bytes = 16 * 1024;
const header_bytes = 40;

pub const Basis = struct {
    request: read.Request,
    declared: Declaration.Stored,
    cut: q.Cut,
    until: u64,
    batches: ?pages.Reference,
    segments: ?pages.Reference,
    hidden: @import("BitmapDirectory.zig").Root,
    pub fn validate(self: Basis) !void {
        try self.request.validate();
        try self.declared.validate();
        try self.hidden.validate();
        if (self.hidden.cardinality > self.cut.next) return error.InvalidStreamRead;
        if (self.request.timestamp != null and (self.declared.declaration.configuration.policy != .stream or self.declared.declaration.configuration.policy.stream.timestamp_column == null)) return error.StreamTimestampNotDeclared;
        try self.request.target.requireSame(self.cut.target);
        try self.cut.requireOffset(self.request.from);
        try self.cut.requireOffset(self.until);
        if (self.declared.retired or self.declared.declaration.configuration.policy != .stream or
            self.cut.accepted.next_lsn == 0 or (self.cut.next != self.cut.retained_from) != (self.batches != null) or
            (self.cut.next == self.cut.retained_from and self.segments != null) or
            !std.meta.eql(self.declared.declaration.interpretation, self.cut.target.interpretation) or
            self.cut.target.partition >= self.declared.declaration.configuration.partitioning.count or
            self.until != (self.request.until orelse self.cut.next) or self.until < self.request.from) return error.InvalidStreamRead;
    }
    pub fn receipt(self: Basis, source: d.Content) !read.Receipt {
        try self.validate();
        const value: read.Receipt = .{ .request = self.request, .cut = self.cut, .until = self.until, .source = source, .accepted = .{ .partition = self.cut.accepted.partition, .next_lsn = std.math.add(u64, self.cut.accepted.next_lsn, 1) catch return error.InvalidStreamRead } };
        try value.validate();
        return value;
    }
};
pub fn hash(bytes: []const u8) [32]u8 {
    var result: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &result, .{});
    return result;
}
fn validateContent(content: d.Content) !void {
    try content.validate();
    if (content.bytes <= header_bytes or content.bytes > max_bytes) return error.InvalidStreamRead;
}
pub fn key(source: d.Content, output: *[96]u8) ![]const u8 {
    try validateContent(source);
    return std.fmt.bufPrint(output, "log-reads/{x}.data", .{&source.sha256});
}
pub fn encode(basis: Basis, output: []u8) ![]const u8 {
    try basis.validate();
    if (output.len < header_bytes) return error.StreamReadTooLarge;
    output[0..8].* = "LREAD001".*;
    output[8..40].* = p.Growth.definition_bytes;
    var writer: std.Io.Writer = .fixed(output[header_bytes..@min(output.len, max_bytes)]);
    var encoder: std.json.Stringify = .{ .writer = &writer };
    try p.Json.write(basis, &encoder);
    return output[0 .. header_bytes + writer.end];
}
pub fn stage(objects: Objects.ObjectStore, basis: Basis) !read.Receipt {
    var buffer: [max_bytes]u8 = undefined;
    const bytes = try encode(basis, &buffer);
    const source: d.Content = .{ .bytes = bytes.len, .sha256 = hash(bytes) };
    var name: [96]u8 = undefined;
    const stored = try objects.putImmutable(try key(source, &name), bytes, source.sha256);
    if (stored.size != source.bytes or !std.mem.eql(u8, &stored.sha256, &source.sha256)) return error.InvalidStreamRead;
    return basis.receipt(source);
}
pub fn load(allocator: std.mem.Allocator, objects: Objects.ObjectStore, handle: read.Handle) !Basis {
    try handle.validate();
    var name: [96]u8 = undefined;
    const object_key = try key(handle.source, &name);
    const metadata = try objects.head(object_key) orelse return error.StreamReadMissing;
    if (metadata.size != handle.source.bytes or !std.mem.eql(u8, &metadata.sha256, &handle.source.sha256)) return error.InvalidStreamRead;
    var buffer: [max_bytes]u8 = undefined;
    const bytes = try objects.getRange(object_key, 0, @intCast(handle.source.bytes), &buffer);
    if (bytes.len != handle.source.bytes or !std.mem.eql(u8, &hash(bytes), &handle.source.sha256) or !std.mem.eql(u8, bytes[0..8], "LREAD001")) return error.InvalidStreamRead;
    if (!std.mem.eql(u8, bytes[8..40], &p.Growth.definition_bytes)) return error.IncompatibleDefinition;
    const parsed = try p.Json.parseFromSlice(Basis, allocator, bytes[header_bytes..]);
    defer parsed.deinit();
    try parsed.value.validate();
    if (!std.meta.eql(parsed.value.request.operation, handle.owner)) return error.StreamReadConflict;
    return parsed.value;
}

pub const Pin = struct {
    source: d.Content,
    released: bool,
    pub fn encode(self: Pin) !pages.Value {
        try validateContent(self.source);
        var bytes: [41]u8 = undefined;
        bytes[0] = @intFromBool(self.released);
        std.mem.writeInt(u64, bytes[1..9], self.source.bytes, .big);
        bytes[9..41].* = self.source.sha256;
        return pages.Value.init(&bytes);
    }
    pub fn decode(value: pages.Value) !Pin {
        if (value.len != 41 or value.data[0] > 1) return error.InvalidStreamRead;
        const pin: Pin = .{ .released = value.data[0] == 1, .source = .{ .bytes = std.mem.readInt(u64, value.data[1..9], .big), .sha256 = value.data[9..41].* } };
        try validateContent(pin.source);
        return pin;
    }
};

/// The adapter supplies its private, stable per-service key outside transcripts
/// and public requests. Key rotation invalidates old cursors, not accepted reads:
/// the same live pin can restart traversal over its original cut with a new key.
pub const Authority = struct {
    secret: [32]u8,
    pub fn init(secret: [32]u8) !Authority {
        if (std.mem.allEqual(u8, &secret, 0)) return error.InvalidStreamReadAuthority;
        return .{ .secret = secret };
    }
    fn authentication(self: Authority, handle: read.Handle, coverage: q.Coverage) ![32]u8 {
        try handle.validate();
        try coverage.validate();
        try coverage.cut.target.requireOperation(handle.owner);
        if (std.mem.allEqual(u8, &self.secret, 0)) return error.InvalidStreamReadAuthority;
        var buffer: [4096]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&buffer);
        try writer.writeAll("transit.stream.read.coverage.v1\x00");
        try writer.writeAll(&p.Growth.definition_bytes);
        var encoder: std.json.Stringify = .{ .writer = &writer };
        try p.Json.write(.{ .read = handle, .coverage = coverage }, &encoder);
        var mac: [32]u8 = undefined;
        std.crypto.auth.hmac.sha2.HmacSha256.create(&mac, writer.buffered(), &self.secret);
        return mac;
    }
    /// Only the verified reader may issue progress. This function authenticates
    /// supplied semantics and cannot itself establish that traversal happened.
    pub fn issue(self: Authority, handle: read.Handle, coverage: q.Coverage) !read.Cursor {
        const cursor: read.Cursor = .{ .read = handle, .coverage = coverage, .authentication = try self.authentication(handle, coverage) };
        try cursor.validate();
        return cursor;
    }
    pub fn verify(self: Authority, cursor: read.Cursor) !void {
        try cursor.validate();
        const expected = try self.authentication(cursor.read, cursor.coverage);
        if (!std.crypto.timing_safe.eql([32]u8, expected, cursor.authentication)) return error.StreamCursorUnauthenticated;
    }
};
