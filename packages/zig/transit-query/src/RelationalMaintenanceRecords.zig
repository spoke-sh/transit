//! One-current-definition records for atomic maintained revisions. Mutable
//! control roots reference immutable operator, result and delta publications.
const std = @import("std");
const q = @import("root.zig");
const p = q.protocol;
const Pub = q.station.Publication;
const Ref = q.station.PublicationReference;
pub const vector_format: u32 = 0x31485152; // RQH1
pub const delta_format: u32 = 0x31445246; // FRD1
pub const revision_format: u32 = 0x31564d52; // RMV1
pub fn key(tag: u8, first: u64, second: u64, third: u64) p.Value {
    var bytes: [28]u8 = undefined;
    bytes[0..3].* = "\x00rm".*;
    bytes[3] = tag;
    std.mem.writeInt(u64, bytes[4..12], first, .big);
    std.mem.writeInt(u64, bytes[12..20], second, .big);
    std.mem.writeInt(u64, bytes[20..28], third, .big);
    return p.Value.init(&bytes) catch unreachable;
}
fn start(writer: *std.Io.Writer, magic: *const [4]u8) !void {
    try writer.writeAll(magic);
    try writer.writeAll(&q.catalog.TableMetadata.definition());
}
fn open(reader: *std.Io.Reader, magic: *const [4]u8) !void {
    if (!std.mem.eql(u8, try reader.take(4), magic)) return error.InvalidMaintainedRecord;
    if (!std.mem.eql(u8, try reader.take(32), &q.catalog.TableMetadata.definition())) return error.IncompatibleDefinition;
}
fn flag(reader: *std.Io.Reader) !bool {
    return switch (try reader.takeByte()) {
        0 => false,
        1 => true,
        else => error.InvalidMaintainedRecord,
    };
}
pub const Identity = struct {
    peer: u64,
    correlation: u64,
    pub fn validate(self: Identity) !void {
        try q.UnifiedRecords.identity(self.peer);
        try q.UnifiedRecords.identity(self.correlation);
    }
    pub fn address(self: Identity) p.Value {
        return key('h', self.peer, self.correlation, 0);
    }
};
pub const Phase = enum(u8) { admitted = 1, running = 2, idle = 3, failed = 4, cancelled = 5, retired = 6 };
pub const Head = struct {
    id: u64,
    peer: u64,
    correlation: u64,
    policy_revision: u64,
    request: Ref,
    request_version: p.Growth.ReadVersionId,
    revision: u64 = 0,
    manifest: u64 = 0,
    next_record: u64 = 1,
    state_bytes: u64 = 0,
    continuation: u64,
    positions: [q.fuze.Relational.max_sources]u64 = @splat(0),
    count: u8,
    preference: u8 = 0,
    phase: Phase = .admitted,
    released: bool = false,
    const integers = .{ "id", "peer", "correlation", "policy_revision", "revision", "manifest", "next_record", "state_bytes", "continuation" };
    pub fn identity(self: Head) Identity {
        return .{ .peer = self.peer, .correlation = self.correlation };
    }
    pub fn namespace(self: Head) u64 {
        return (@as(u64, 1) << 63) | self.id;
    }
    pub fn publication(self: Head, resource: u64) Pub {
        return .{ .resource = resource, .domain = .query_result, .namespace = self.namespace() };
    }
    pub fn successor(self: Head) !u64 {
        return std.math.add(u64, self.revision, 1) catch error.MaintainedRevisionExhausted;
    }
    pub fn encode(self: Head) !p.Value {
        try self.identity().validate();
        inline for (.{ "id", "policy_revision", "continuation" }) |field| try q.UnifiedRecords.identity(@field(self, field));
        try q.RelationalBundle.checkReference(self.request);
        try p.Growth.validateVersionId(self.request_version);
        if (self.request_version.input != self.id or self.continuation < self.id) return error.InvalidMaintainedRecord;
        if (self.count == 0 or self.count > self.positions.len or self.preference >= self.count) return error.InvalidMaintainedRecord;
        for (self.positions[0..self.count]) |position| if (position == 0 or position > p.max_counter) return error.InvalidMaintainedRecord;
        for (self.positions[self.count..]) |position| if (position != 0) return error.InvalidMaintainedRecord;
        if ((self.revision == 0) != (self.manifest == 0) or self.next_record == 0 or self.manifest >= self.next_record) return error.InvalidMaintainedRecord;
        if (self.phase == .idle and self.revision == 0) return error.InvalidMaintainedRecord;
        if (self.released != (self.phase == .retired)) return error.InvalidMaintainedRecord;
        var bytes: [p.Value.max_bytes]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&bytes);
        try start(&writer, "RMH1");
        inline for (integers) |field| try writer.writeInt(u64, @field(self, field), .little);
        try writer.writeAll((try self.request.encode()).slice());
        try writer.writeInt(u64, self.request_version.pid, .little);
        try writer.writeInt(u64, self.request_version.input, .little);
        try writer.writeByte(self.request_version.index);
        for (self.positions) |position| try writer.writeInt(u64, position, .little);
        try writer.writeByte(self.count);
        try writer.writeByte(self.preference);
        try writer.writeByte(@backingInt(self.phase));
        try writer.writeByte(@intFromBool(self.released));
        return p.Value.init(writer.buffered());
    }
    pub fn decode(value: p.Value) !Head {
        try value.validate();
        var reader: std.Io.Reader = .fixed(value.slice());
        try open(&reader, "RMH1");
        var result: Head = undefined;
        inline for (integers) |field| @field(result, field) = try reader.takeInt(u64, .little);
        result.request = try Ref.decode(try p.Value.init(try reader.take(Ref.encoded_bytes)));
        result.request_version = .{ .pid = try reader.takeInt(u64, .little), .input = try reader.takeInt(u64, .little), .index = try reader.takeByte() };
        for (&result.positions) |*position| position.* = try reader.takeInt(u64, .little);
        result.count = try reader.takeByte();
        result.preference = try reader.takeByte();
        result.phase = std.enums.fromInt(Phase, try reader.takeByte()) orelse return error.InvalidMaintainedRecord;
        result.released = try flag(&reader);
        if (reader.bufferedLen() != 0 or !(try result.encode()).eql(value)) return error.InvalidMaintainedRecord;
        return result;
    }
};
pub fn initialDeltaChain() [32]u8 {
    var result: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash("transit.relational.delta-transactions.v1\x00", &result, .{});
    return result;
}
pub const WorkPhase = enum(u8) { compute = 1, delta = 2, manifest = 3, complete = 4, failed = 5 };
pub const Work = struct {
    revision: u64,
    checkpoint: u64 = 0,
    outputs: u64 = 0,
    output_bytes: u64 = 0,
    chain: [32]u8 = q.RelationalRecords.initialChain(),
    old_cursor: u64 = 0,
    new_cursor: u64 = 0,
    deltas: u64 = 0,
    delta_bytes: u64 = 0,
    delta_chain: [32]u8 = initialDeltaChain(),
    next_record: u64,
    state_bytes: u64,
    manifest: u64 = 0,
    phase: WorkPhase = .compute,
    const integers = .{ "revision", "checkpoint", "outputs", "output_bytes", "old_cursor", "new_cursor", "deltas", "delta_bytes", "next_record", "state_bytes", "manifest" };
    pub fn encode(self: Work) !p.Value {
        if (self.revision == 0 or self.next_record == 0 or self.checkpoint >= self.next_record or self.manifest >= self.next_record or self.new_cursor > self.outputs) return error.InvalidMaintainedRecord;
        if ((self.outputs == 0) != (self.output_bytes == 0) or (self.deltas == 0) != (self.delta_bytes == 0)) return error.InvalidMaintainedRecord;
        if (self.outputs == 0 and !std.mem.eql(u8, &self.chain, &q.RelationalRecords.initialChain())) return error.InvalidMaintainedRecord;
        if (self.deltas == 0 and !std.mem.eql(u8, &self.delta_chain, &initialDeltaChain())) return error.InvalidMaintainedRecord;
        if (self.phase == .compute and (self.old_cursor != 0 or self.new_cursor != 0 or self.deltas != 0)) return error.InvalidMaintainedRecord;
        if (self.phase != .compute and self.checkpoint == 0) return error.InvalidMaintainedRecord;
        if ((self.phase == .complete) != (self.manifest != 0)) return error.InvalidMaintainedRecord;
        var bytes: [p.Value.max_bytes]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&bytes);
        try start(&writer, "RMW1");
        inline for (integers) |field| try writer.writeInt(u64, @field(self, field), .little);
        try writer.writeAll(&self.chain);
        try writer.writeAll(&self.delta_chain);
        try writer.writeByte(@backingInt(self.phase));
        return p.Value.init(writer.buffered());
    }
    pub fn decode(value: p.Value) !Work {
        try value.validate();
        var reader: std.Io.Reader = .fixed(value.slice());
        try open(&reader, "RMW1");
        var result: Work = undefined;
        inline for (integers) |field| @field(result, field) = try reader.takeInt(u64, .little);
        result.chain = (try reader.takeArray(32)).*;
        result.delta_chain = (try reader.takeArray(32)).*;
        result.phase = std.enums.fromInt(WorkPhase, try reader.takeByte()) orelse return error.InvalidMaintainedRecord;
        if (reader.bufferedLen() != 0 or !(try result.encode()).eql(value)) return error.InvalidMaintainedRecord;
        return result;
    }
};
/// The atomic publication unit. Pages and mutable build progress alone never
/// authorize a consumer to replace its last complete relation.
pub const Manifest = struct {
    pub const max_bytes = 1200;
    id: u64,
    work: Work,
    previous: ?Ref = null,
    vector: q.RelationalHistory.Vector,
    checkpoint: Ref,
    pub fn encode(self: Manifest, bundle: q.RelationalBundle, bytes: []u8) ![]const u8 {
        try q.UnifiedRecords.identity(self.id);
        const work = try self.work.encode();
        if (self.work.phase != .complete or self.work.next_record != self.work.manifest + 1 or self.work.new_cursor != self.work.outputs) return error.IncompleteResult;
        try self.checkpoint.validate();
        if (self.checkpoint.domain != .query_result or self.checkpoint.namespace != ((@as(u64, 1) << 63) | self.id) or self.checkpoint.record != self.work.checkpoint or self.checkpoint.spec.format != q.RelationalState.checkpoint_format or self.checkpoint.spec.length > q.fuze.RelationalCheckpoint.max_bytes) return error.InvalidMaintainedRecord;
        if ((self.work.revision == 1) != (self.previous == null)) return error.InvalidMaintainedRecord;
        if (self.previous) |old| {
            try old.validate();
            if (old.domain != .query_result or old.resource != self.checkpoint.resource or old.namespace != self.checkpoint.namespace or old.record >= self.checkpoint.record or old.spec.format != revision_format or old.spec.length > max_bytes) return error.InvalidMaintainedRecord;
        } else if (self.work.old_cursor != 0) return error.InvalidMaintainedRecord;
        var vector_bytes: [q.RelationalHistory.Vector.max_bytes]u8 = undefined;
        const vector = try self.vector.encode(bundle, &vector_bytes);
        var writer: std.Io.Writer = .fixed(bytes[0..@min(bytes.len, max_bytes)]);
        try start(&writer, "RMV1");
        try writer.writeInt(u64, self.id, .little);
        try writer.writeInt(u16, work.len, .little);
        try writer.writeAll(work.slice());
        try writer.writeByte(@intFromBool(self.previous != null));
        if (self.previous) |old| try writer.writeAll((try old.encode()).slice());
        try writer.writeInt(u16, @intCast(vector.len), .little);
        try writer.writeAll(vector);
        try writer.writeAll((try self.checkpoint.encode()).slice());
        return writer.buffered();
    }
    pub fn decode(bundle: q.RelationalBundle, bytes: []const u8) !Manifest {
        if (bytes.len > max_bytes) return error.InvalidMaintainedRecord;
        var reader: std.Io.Reader = .fixed(bytes);
        try open(&reader, "RMV1");
        const id = try reader.takeInt(u64, .little);
        const work = try Work.decode(try p.Value.init(try reader.take(try reader.takeInt(u16, .little))));
        const previous = if (try flag(&reader)) try Ref.decode(try p.Value.init(try reader.take(Ref.encoded_bytes))) else null;
        const vector = try q.RelationalHistory.Vector.decode(bundle, try reader.take(try reader.takeInt(u16, .little)));
        const result: Manifest = .{ .id = id, .work = work, .previous = previous, .vector = vector, .checkpoint = try Ref.decode(try p.Value.init(try reader.take(Ref.encoded_bytes))) };
        if (reader.bufferedLen() != 0) return error.InvalidMaintainedRecord;
        var canonical: [max_bytes]u8 = undefined;
        if (!std.mem.eql(u8, bytes, try result.encode(bundle, &canonical))) return error.InvalidMaintainedRecord;
        return result;
    }
};
pub const Delta = struct {
    ordinal: u64,
    reference: Ref,
    pub fn encode(self: Delta) !p.Value {
        try self.reference.validate();
        if (self.reference.domain != .query_result or self.reference.spec.format != delta_format or self.reference.spec.length == 0 or self.reference.spec.length > q.fuze.RelationalDelta.max_bytes) return error.InvalidMaintainedRecord;
        var bytes: [116]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&bytes);
        try start(&writer, "RMD1");
        try writer.writeInt(u64, self.ordinal, .little);
        try writer.writeAll((try self.reference.encode()).slice());
        return p.Value.init(writer.buffered());
    }
    pub fn decode(value: p.Value) !Delta {
        try value.validate();
        var reader: std.Io.Reader = .fixed(value.slice());
        try open(&reader, "RMD1");
        const result: Delta = .{ .ordinal = try reader.takeInt(u64, .little), .reference = try Ref.decode(try p.Value.init(try reader.take(Ref.encoded_bytes))) };
        if (reader.bufferedLen() != 0 or !(try result.encode()).eql(value)) return error.InvalidMaintainedRecord;
        return result;
    }
    pub fn extend(self: Delta, previous: [32]u8) ![32]u8 {
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        hash.update(&previous);
        hash.update((try self.encode()).slice());
        return hash.finalResult();
    }
};
pub const Continuation = struct {
    identity: Identity,
    input: u64,
    pub fn encode(self: Continuation) !p.Value {
        try self.identity.validate();
        try q.UnifiedRecords.identity(self.input);
        var bytes: [60]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&bytes);
        try start(&writer, "RMC1");
        try writer.writeInt(u64, self.identity.peer, .little);
        try writer.writeInt(u64, self.identity.correlation, .little);
        try writer.writeInt(u64, self.input, .little);
        return p.Value.init(writer.buffered());
    }
    pub fn decode(value: p.Value) !Continuation {
        try value.validate();
        var reader: std.Io.Reader = .fixed(value.slice());
        try open(&reader, "RMC1");
        const result: Continuation = .{ .identity = .{ .peer = try reader.takeInt(u64, .little), .correlation = try reader.takeInt(u64, .little) }, .input = try reader.takeInt(u64, .little) };
        if (reader.bufferedLen() != 0 or !(try result.encode()).eql(value)) return error.InvalidMaintainedRecord;
        return result;
    }
};
test {
    _ = @import("relational_maintenance_records_test.zig");
}
