//! `.tack` manifests bind four disjoint paged state sets to one queue segment.
//! Payload and lease/attempt records have independent durable owners. Neither
//! terminal bits nor this artifact authorize physical deletion or settlement.
const std = @import("std");
const p = @import("transit_protocol");
const B = @import("BitmapDirectory.zig");
const pages = @import("TreeStore.zig").pages;
const Self = @This();

pub const State = enum(u2) { available, acquired, acked, archived };
pub const Roots = [4]B.Root;
pub const encoded_bytes = 488;

target: p.StreamQueue.Partition,
segment: u64,
first: u64,
next: u64,
accepted: p.DataLifecycle.Position,
states: Roots,

pub fn validate(self: Self) !void {
    try self.target.validate();
    try self.accepted.validate();
    if (self.segment == 0 or self.next <= self.first or self.next - self.first > std.math.maxInt(u32) or self.accepted.next_lsn == 0) return error.InvalidQueueSidecar;
    var count: u64 = 0;
    for (self.states) |root| {
        try root.validate();
        if (root.cardinality > self.next - self.first - count) return error.InvalidQueueSidecar;
        count += root.cardinality;
    }
    if (count != self.next - self.first) return error.InvalidQueueSidecar;
}

pub fn requireBinding(self: Self, target: p.StreamQueue.Partition, segment: u64, first: u64, next: u64, accepted: p.DataLifecycle.Position) !void {
    try self.validate();
    try self.target.requireSame(target);
    if (self.segment != segment or self.first != first or self.next != next or !std.meta.eql(self.accepted, accepted)) return error.QueueSidecarConflict;
}

/// Constant-time eligibility hint only. Retained cuts, replay, receipts and
/// pending transactions may still keep every payload and state artifact alive.
pub fn terminal(self: Self) !bool {
    try self.validate();
    return self.states[@backingInt(State.acked)].cardinality + self.states[@backingInt(State.archived)].cardinality == self.next - self.first;
}

pub fn encode(self: Self, out: *[encoded_bytes]u8) ![]const u8 {
    try self.validate();
    var writer: std.Io.Writer = .fixed(out);
    try writer.writeAll("TACK0001");
    try writer.writeAll(&p.Growth.definition_bytes);
    const object = self.target.interpretation.object;
    for ([_]u64{ object.scope.realm, object.scope.resource, object.scope.catalog, object.branch, object.object, self.target.interpretation.revision }) |value| try writer.writeInt(u64, value, .big);
    try writer.writeAll(&self.target.interpretation.digest);
    try writer.writeInt(u32, self.target.partition, .big);
    for ([_]u64{ self.segment, self.first, self.next, self.accepted.partition, self.accepted.next_lsn }) |value| try writer.writeInt(u64, value, .big);
    for (self.states) |root| {
        try writer.writeByte(@intFromBool(root.containers != null));
        const ref = root.containers orelse pages.Reference{ .digest = @splat(0), .location = @splat(0) };
        try writer.writeAll(&ref.digest);
        try writer.writeAll(&ref.location);
        try writer.writeInt(u64, root.cardinality, .big);
    }
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(writer.buffered(), &digest, .{});
    try writer.writeAll(&digest);
    return writer.buffered();
}

pub fn decode(bytes: []const u8) !Self {
    if (bytes.len != encoded_bytes or !std.mem.eql(u8, bytes[0..8], "TACK0001")) return error.InvalidQueueSidecar;
    if (!std.mem.eql(u8, bytes[8..40], &p.Growth.definition_bytes)) return error.IncompatibleDefinition;
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes[0 .. encoded_bytes - 32], &digest, .{});
    if (!std.mem.eql(u8, &digest, bytes[encoded_bytes - 32 ..])) return error.CorruptQueueSidecar;
    var reader: std.Io.Reader = .fixed(bytes[40 .. encoded_bytes - 32]);
    var result: Self = .{
        .target = .{ .definition = p.Growth.current_definition, .interpretation = .{
            .object = .{ .scope = .{ .realm = try reader.takeInt(u64, .big), .resource = try reader.takeInt(u64, .big), .catalog = try reader.takeInt(u64, .big) }, .branch = try reader.takeInt(u64, .big), .object = try reader.takeInt(u64, .big) },
            .revision = try reader.takeInt(u64, .big),
            .digest = (try reader.takeArray(32)).*,
        }, .partition = try reader.takeInt(u32, .big) },
        .segment = try reader.takeInt(u64, .big),
        .first = try reader.takeInt(u64, .big),
        .next = try reader.takeInt(u64, .big),
        .accepted = .{ .partition = try reader.takeInt(u64, .big), .next_lsn = try reader.takeInt(u64, .big) },
        .states = undefined,
    };
    for (&result.states) |*root| {
        const present = try reader.takeByte();
        const ref: pages.Reference = .{ .digest = (try reader.takeArray(32)).*, .location = (try reader.takeArray(32)).* };
        const cardinality = try reader.takeInt(u64, .big);
        if (present > 1 or (present == 0 and (!std.mem.allEqual(u8, &ref.digest, 0) or !std.mem.allEqual(u8, &ref.location, 0)))) return error.InvalidQueueSidecar;
        root.* = .{ .containers = if (present == 1) ref else null, .cardinality = cardinality };
    }
    try result.validate();
    return result;
}

/// Bounded validation cursor for a frozen manifest. A page verifies at most
/// eight containers and their peers. Only completion proves disjoint, complete
/// range coverage; a valid envelope alone does not establish that fact.
pub const Audit = struct {
    manifest: Self,
    state: usize = 0,
    after: ?pages.Key = null,
    cardinality: u64 = 0,

    pub fn init(manifest: Self) !Audit {
        try manifest.validate();
        return .{ .manifest = manifest };
    }

    pub fn page(self: *Audit, directory: *B, scratch: *B.Container) !bool {
        if (self.state == 4) return true;
        const root = self.manifest.states[self.state];
        const entries = try directory.scan(root, self.after);
        var count = self.cardinality;
        for (entries.entries) |slot| if (slot) |entry| {
            const prefix = try B.prefixOf(entry.key);
            const ref = try B.Reference.decode(entry.value);
            try scratch.decode((try directory.read(prefix, ref)).bytes);
            var it = scratch.iterator();
            while (it.next()) |low| {
                const offset = (prefix << 16) | low;
                if (offset < self.manifest.first or offset >= self.manifest.next) return error.QueueSidecarOffsetOutOfRange;
            }
            for (self.manifest.states[self.state + 1 ..]) |other_root| {
                if (try directory.reference(other_root, prefix)) |other_ref| {
                    var other = (try directory.read(prefix, other_ref)).iterator();
                    while (other.next()) |low| if (scratch.contains(low)) return error.QueueSidecarOverlap;
                }
            }
            if (ref.cardinality > root.cardinality -| count) return error.InvalidQueueSidecar;
            count += ref.cardinality;
        };
        // Progress is changed only after the entire page validates.
        if (entries.next == null) {
            if (count != root.cardinality) return error.InvalidQueueSidecar;
            self.state += 1;
            self.cardinality = 0;
        } else self.cardinality = count;
        self.after = entries.next;
        return self.state == 4;
    }
};

/// Stage a transition under the caller's current authority/lease guard. The
/// returned roots remain private until the owner publishes its WAL decision.
/// Lease-holder, deadline, attempts and original receipts must commit with them.
pub fn transition(self: Self, directory: *B, offset: u64, from: State, to: State, scratch: *B.Container) !Roots {
    try self.validate();
    if (offset < self.first or offset >= self.next) return error.QueueSidecarOffsetOutOfRange;
    if (from == to or from == .acked or from == .archived or (from == .available and to == .acked)) return error.InvalidQueueStateTransition;
    if (!try directory.contains(self.states[@backingInt(from)], offset)) return error.QueueStateConflict;
    for (self.states, 0..) |root, index| if (index != @backingInt(from) and try directory.contains(root, offset)) return error.QueueSidecarOverlap;
    var states = self.states;
    states[@backingInt(from)] = try directory.edit(states[@backingInt(from)], offset >> 16, &.{.{ .offset = @truncate(offset), .present = false }}, scratch);
    states[@backingInt(to)] = try directory.edit(states[@backingInt(to)], offset >> 16, &.{.{ .offset = @truncate(offset), .present = true }}, scratch);
    return states;
}
