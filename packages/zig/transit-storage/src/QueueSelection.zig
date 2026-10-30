//! Original nonempty claim selections. The bounded artifact owns exact leases
//! and the payload placement cut; its returned views borrow caller memory.
//! Staging is private. Only the enclosing accepted WAL receipt publishes it.
const std = @import("std");
const p = @import("transit_protocol");
const q = p.StreamQueue;
const d = p.DataLifecycle;
const Declaration = @import("LogDeclaration.zig");
const Objects = @import("TransitObjectStore.zig");
const pages = @import("TreeStore.zig").pages;
const Time = @import("LogTime.zig");
pub const header_bytes = 48;
pub const item_bytes = 24;
pub const max_rows = 4096;
pub const max_metadata_bytes = 16 * 1024;
pub const max_bytes = header_bytes + max_metadata_bytes + item_bytes * max_rows;

pub const Metadata = struct {
    definition: p.Growth.Definition,
    declared: Declaration.Stored,
    claim: q.Claim,
    accepted: d.Position,
    observed: Time.Sample,
    expires_ms: u64,
    rows: u32,
    source: struct {
        accepted: d.Position,
        next_offset: u64,
        batches: ?pages.Reference,
        segments: ?pages.Reference,
    },

    pub fn validate(self: Metadata) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.declared.validate();
        try self.claim.validate();
        try self.accepted.validate();
        try self.source.accepted.validate();
        try self.observed.validate();
        if (self.declared.retired or self.declared.declaration.configuration.policy != .queue or
            !std.meta.eql(self.declared.declaration.interpretation, self.claim.target.interpretation) or
            self.claim.target.partition >= self.declared.declaration.configuration.partitioning.count or
            self.rows == 0 or self.rows > self.claim.maximum or self.claim.maximum > self.declared.declaration.limits.claim_rows or self.rows > max_rows or
            self.source.next_offset < self.rows or self.source.batches == null or self.source.accepted.next_lsn == 0 or
            self.accepted.partition != self.source.accepted.partition or self.accepted.next_lsn == 0 or
            self.accepted.next_lsn - 1 != self.source.accepted.next_lsn) return error.InvalidQueueSelection;
        if (self.expires_ms != try self.declared.declaration.configuration.policy.queue.deadline(self.observed.latest_ms, self.claim.lease_ms)) return error.InvalidQueueSelection;
    }
    pub fn receipt(self: Metadata, content: d.Content) !q.ClaimReceipt {
        try self.validate();
        try validateContent(content);
        const result: q.ClaimReceipt = .{ .claim = self.claim, .accepted = self.accepted, .observed_ms = self.observed.latest_ms, .expires_ms = self.expires_ms, .rows = self.rows, .leases = content };
        try result.validate();
        return result;
    }
};

fn validateContent(content: d.Content) !void {
    try content.validate();
    if (content.bytes <= header_bytes + item_bytes or content.bytes > max_bytes) return error.InvalidQueueSelection;
}
pub fn objectKey(content: d.Content, buffer: *[96]u8) ![]const u8 {
    try validateContent(content);
    return std.fmt.bufPrint(buffer, "queue-selections/{x}.data", .{&content.sha256});
}
fn requireLease(meta: Metadata, lease: q.Lease, previous: ?u64) !void {
    try lease.validate();
    if (!std.meta.eql(lease.target, meta.claim.target) or !std.meta.eql(lease.claim, meta.claim.operation) or
        lease.expires_ms != meta.expires_ms or lease.offset >= meta.source.next_offset or
        (previous != null and lease.offset <= previous.?)) return error.InvalidQueueSelection;
}

/// Selection order is canonical ascending logical offset, independent of the
/// eligibility index's scheduling order. Each offset occurs exactly once.
pub fn encode(meta: Metadata, leases: []const q.Lease, output: []u8) ![]const u8 {
    try meta.validate();
    if (leases.len != meta.rows or output.len < header_bytes + item_bytes * leases.len) return error.InvalidQueueSelection;
    var writer: std.Io.Writer = .fixed(output[header_bytes..][0..@min(max_metadata_bytes, output.len - header_bytes - item_bytes * leases.len)]);
    var encoder: std.json.Stringify = .{ .writer = &writer };
    try p.Json.write(meta, &encoder);
    const size = writer.end;
    output[0..8].* = "QCLAIM01".*;
    output[8..40].* = p.Growth.definition_bytes;
    std.mem.writeInt(u32, output[40..44], @intCast(size), .big);
    std.mem.writeInt(u32, output[44..48], meta.rows, .big);
    var at = header_bytes + size;
    var previous: ?u64 = null;
    for (leases) |lease| {
        try requireLease(meta, lease, previous);
        std.mem.writeInt(u64, output[at..][0..8], lease.offset, .big);
        std.mem.writeInt(u64, output[at + 8 ..][0..8], lease.epoch, .big);
        std.mem.writeInt(u64, output[at + 16 ..][0..8], lease.attempt, .big);
        at += item_bytes;
        previous = lease.offset;
    }
    return output[0..at];
}
pub const View = struct {
    metadata: Metadata,
    items: []const u8,
    content: d.Content,
    pub fn lease(self: View, index: u32) !q.Lease {
        if (index >= self.metadata.rows) return error.QueueSelectionOffsetOutOfRange;
        const bytes = self.items[@as(usize, index) * item_bytes ..][0..item_bytes];
        const result: q.Lease = .{ .target = self.metadata.claim.target, .claim = self.metadata.claim.operation, .expires_ms = self.metadata.expires_ms, .offset = std.mem.readInt(u64, bytes[0..8], .big), .epoch = std.mem.readInt(u64, bytes[8..16], .big), .attempt = std.mem.readInt(u64, bytes[16..24], .big) };
        try result.validate();
        return result;
    }
    pub fn requireReceipt(self: View, receipt: q.ClaimReceipt) !void {
        if (!std.meta.eql(try self.metadata.receipt(self.content), receipt)) return error.QueueClaimConflict;
    }
};

pub fn decode(allocator: std.mem.Allocator, bytes: []const u8) !View {
    if (bytes.len > max_bytes) return error.InvalidQueueSelection;
    return decodeVerified(allocator, bytes, @import("LogBatch.zig").content(bytes));
}
fn decodeVerified(allocator: std.mem.Allocator, bytes: []const u8, content: d.Content) !View {
    if (bytes.len < header_bytes or bytes.len > max_bytes or !std.mem.eql(u8, bytes[0..8], "QCLAIM01")) return error.InvalidQueueSelection;
    if (!std.mem.eql(u8, bytes[8..40], &p.Growth.definition_bytes)) return error.IncompatibleDefinition;
    const size = std.mem.readInt(u32, bytes[40..44], .big);
    const count = std.mem.readInt(u32, bytes[44..48], .big);
    if (size == 0 or size > max_metadata_bytes or count == 0 or count > max_rows or bytes.len != header_bytes + size + @as(usize, count) * item_bytes) return error.InvalidQueueSelection;
    // Stored metadata is canonical, unlike caller JSON. Decode directly into
    // fixed fields, then compare the public encoder's exact bytes. This rejects
    // alternative array/enum shapes without building a second dynamic JSON tree.
    const parsed = try std.json.parseFromSlice(Metadata, allocator, bytes[header_bytes..][0..size], .{});
    defer parsed.deinit();
    const meta = parsed.value;
    try meta.validate();
    var canonical: [max_metadata_bytes]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&canonical);
    var encoder: std.json.Stringify = .{ .writer = &writer };
    try p.Json.write(meta, &encoder);
    if (!std.mem.eql(u8, writer.buffered(), bytes[header_bytes..][0..size])) return error.InvalidQueueSelection;
    if (meta.rows != count) return error.InvalidQueueSelection;
    const view: View = .{ .metadata = meta, .items = bytes[header_bytes + size ..], .content = content };
    var previous: ?u64 = null;
    for (0..count) |index| {
        const lease = try view.lease(@intCast(index));
        try requireLease(meta, lease, previous);
        previous = lease.offset;
    }
    return view;
}

pub fn stage(objects: Objects.ObjectStore, metadata: Metadata, leases: []const q.Lease, output: []u8) !d.Content {
    const bytes = try encode(metadata, leases, output);
    const content = @import("LogBatch.zig").content(bytes);
    var name: [96]u8 = undefined;
    const stored = try objects.putImmutable(try objectKey(content, &name), bytes, content.sha256);
    if (stored.size != content.bytes or !std.mem.eql(u8, &stored.sha256, &content.sha256)) return error.InvalidQueueSelection;
    return content;
}
pub fn load(allocator: std.mem.Allocator, objects: Objects.ObjectStore, content: d.Content, output: []u8) !View {
    try validateContent(content);
    if (output.len < content.bytes) return error.QueueSelectionBudgetExceeded;
    var name: [96]u8 = undefined;
    const key = try objectKey(content, &name);
    const stored = try objects.head(key) orelse return error.QueueSelectionMissing;
    if (stored.size != content.bytes or !std.mem.eql(u8, &stored.sha256, &content.sha256)) return error.InvalidQueueSelection;
    const bytes = try objects.getRange(key, 0, @intCast(content.bytes), output[0..@intCast(content.bytes)]);
    if (!std.meta.eql(@import("LogBatch.zig").content(bytes), content)) return error.InvalidQueueSelection;
    return decodeVerified(allocator, bytes, content);
}
