//! Coordinator records for captured relational jobs. One current definition;
//! compact native values reference immutable plans, operator roots and outputs.
const std = @import("std");
const q = @import("root.zig");
const p = q.protocol;
const Pub = q.station.Publication;
const Ref = q.station.PublicationReference;
pub const output_format: u32 = 0x314f5246;
pub const manifest_format: u32 = 0x314d5152;
pub fn key(tag: u8, first: u64, second: u64) p.Value {
    var bytes: [20]u8 = undefined;
    bytes[0..3].* = "\x00rq".*;
    bytes[3] = tag;
    std.mem.writeInt(u64, bytes[4..12], first, .big);
    std.mem.writeInt(u64, bytes[12..20], second, .big);
    return p.Value.init(&bytes) catch unreachable;
}
fn start(writer: *std.Io.Writer, magic: *const [4]u8) !void {
    try writer.writeAll(magic);
    try writer.writeAll(&q.catalog.TableMetadata.definition());
}
fn open(reader: *std.Io.Reader, magic: *const [4]u8) !void {
    if (!std.mem.eql(u8, try reader.take(4), magic)) return error.InvalidRelationalRecord;
    if (!std.mem.eql(u8, try reader.take(32), &q.catalog.TableMetadata.definition())) return error.IncompatibleDefinition;
}
fn boolean(reader: *std.Io.Reader) !bool {
    return switch (try reader.takeByte()) {
        0 => false,
        1 => true,
        else => error.InvalidRelationalRecord,
    };
}
pub const Policy = struct {
    peer: u64,
    requests: u64,
    principal: u64,
    revision: u64,
    request: [32]u8,
    allow: bool,
    pub fn encode(self: Policy) !p.Value {
        inline for (.{ "peer", "requests", "principal", "revision" }) |field| try q.UnifiedRecords.identity(@field(self, field));
        var bytes: [p.Value.max_bytes]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&bytes);
        try start(&writer, "RQA1");
        inline for (.{ "peer", "requests", "principal", "revision" }) |field| try writer.writeInt(u64, @field(self, field), .little);
        try writer.writeAll(&self.request);
        try writer.writeByte(@intFromBool(self.allow));
        return p.Value.init(writer.buffered());
    }
    pub fn decode(value: p.Value) !Policy {
        try value.validate();
        var reader: std.Io.Reader = .fixed(value.slice());
        try open(&reader, "RQA1");
        var result: Policy = undefined;
        inline for (.{ "peer", "requests", "principal", "revision" }) |field| @field(result, field) = try reader.takeInt(u64, .little);
        result.request = (try reader.takeArray(32)).*;
        result.allow = try boolean(&reader);
        if (reader.bufferedLen() != 0 or !(try result.encode()).eql(value)) return error.InvalidRelationalRecord;
        return result;
    }
};
pub fn initialChain() [32]u8 {
    @setEvalBranchQuota(10000);
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash("transit.query.relational.outputs.v1\x00", &digest, .{});
    return digest;
}
pub const Phase = enum(u8) { capturing = 1, complete = 2, failed = 3, cancelled = 4, denied = 5, retired = 6, admitted = 7, acquiring = 8 };
pub const Job = struct {
    id: u64,
    destination: u64,
    correlation: u64,
    policy_revision: u64,
    request: Ref,
    request_version: p.Growth.ReadVersionId,
    phase: Phase = .admitted,
    source_count: u8,
    acquired: u8 = 0,
    checkpoint: u64 = 0,
    next_record: u64 = 1,
    state_bytes: u64 = 0,
    continuation: u64,
    outputs: u64 = 0,
    output_bytes: u64 = 0,
    chain: [32]u8 = initialChain(),
    manifest: u64 = 0,
    cleanup: u64 = 0,
    released: bool = false,
    pub fn namespace(self: Job) u64 {
        return (@as(u64, 1) << 63) | self.id;
    }
    pub fn publication(self: Job, resource: u64) Pub {
        return .{ .domain = .query_result, .resource = resource, .namespace = self.namespace() };
    }
    const integers = .{ "id", "destination", "correlation", "policy_revision", "checkpoint", "next_record", "state_bytes", "continuation", "outputs", "output_bytes", "manifest", "cleanup" };
    pub fn encode(self: Job) !p.Value {
        inline for (.{ "id", "destination", "correlation", "policy_revision", "continuation" }) |field| try q.UnifiedRecords.identity(@field(self, field));
        try q.RelationalBundle.checkReference(self.request);
        try p.Growth.validateVersionId(self.request_version);
        if (self.request_version.input != self.id) return error.InvalidRelationalRecord;
        if (self.next_record == 0 or self.checkpoint >= self.next_record or self.manifest >= self.next_record or self.continuation < self.id) return error.InvalidRelationalRecord;
        if ((self.checkpoint == 0) != (self.state_bytes == 0) or (self.outputs == 0) != (self.output_bytes == 0)) return error.InvalidRelationalRecord;
        if (self.outputs == 0 and !std.mem.eql(u8, &self.chain, &initialChain())) return error.InvalidRelationalRecord;
        if (self.phase == .complete and (self.manifest == 0 or self.checkpoint == 0 or self.released)) return error.InvalidRelationalRecord;
        if (self.phase == .capturing and (self.manifest != 0 or self.released)) return error.InvalidRelationalRecord;
        if (self.source_count == 0 or self.source_count > q.fuze.Relational.max_sources or self.acquired > self.source_count) return error.InvalidRelationalRecord;
        if ((self.phase == .capturing or self.phase == .complete) and self.acquired != self.source_count) return error.InvalidRelationalRecord;
        if ((self.phase == .admitted or self.phase == .acquiring) and (self.released or self.checkpoint != 0 or self.manifest != 0 or self.outputs != 0)) return error.InvalidRelationalRecord;
        if (self.phase == .acquiring and self.acquired == self.source_count) return error.InvalidRelationalRecord;
        if (self.phase != .capturing and self.phase != .complete and self.phase != .admitted and self.phase != .acquiring and !self.released) return error.InvalidRelationalRecord;
        var bytes: [p.Value.max_bytes]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&bytes);
        try start(&writer, "RQJ1");
        inline for (integers) |field| try writer.writeInt(u64, @field(self, field), .little);
        try writer.writeAll((try self.request.encode()).slice());
        try writer.writeInt(u64, self.request_version.pid, .little);
        try writer.writeInt(u64, self.request_version.input, .little);
        try writer.writeByte(self.request_version.index);
        try writer.writeByte(@backingInt(self.phase));
        try writer.writeAll(&self.chain);
        try writer.writeByte(@intFromBool(self.released));
        try writer.writeByte(self.source_count | (self.acquired << 2));
        return p.Value.init(writer.buffered());
    }
    pub fn decode(value: p.Value) !Job {
        try value.validate();
        var reader: std.Io.Reader = .fixed(value.slice());
        try open(&reader, "RQJ1");
        var result: Job = undefined;
        inline for (integers) |field| @field(result, field) = try reader.takeInt(u64, .little);
        result.request = try Ref.decode(try p.Value.init(try reader.take(Ref.encoded_bytes)));
        result.request_version = .{ .pid = try reader.takeInt(u64, .little), .input = try reader.takeInt(u64, .little), .index = try reader.takeByte() };
        result.phase = std.enums.fromInt(Phase, try reader.takeByte()) orelse return error.InvalidRelationalRecord;
        result.chain = (try reader.takeArray(32)).*;
        result.released = try boolean(&reader);
        const capture = try reader.takeByte();
        if (capture & 0xf0 != 0) return error.InvalidRelationalRecord;
        result.source_count = capture & 3;
        result.acquired = (capture >> 2) & 3;
        if (reader.bufferedLen() != 0 or !(try result.encode()).eql(value)) return error.InvalidRelationalRecord;
        return result;
    }
};
pub const Output = struct {
    ordinal: u64,
    reference: Ref,
    pub fn encode(self: Output) !p.Value {
        try self.reference.validate();
        if (self.reference.domain != .query_result or self.reference.spec.format != output_format or self.reference.spec.length == 0 or self.reference.spec.length > q.fuze.RelationalOutput.max_bytes) return error.InvalidRelationalRecord;
        var bytes: [116]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&bytes);
        try start(&writer, "RQS1");
        try writer.writeInt(u64, self.ordinal, .little);
        try writer.writeAll((try self.reference.encode()).slice());
        return p.Value.init(writer.buffered());
    }
    pub fn decode(value: p.Value) !Output {
        try value.validate();
        var reader: std.Io.Reader = .fixed(value.slice());
        try open(&reader, "RQS1");
        const result: Output = .{ .ordinal = try reader.takeInt(u64, .little), .reference = try Ref.decode(try p.Value.init(try reader.take(Ref.encoded_bytes))) };
        if (reader.bufferedLen() != 0 or !(try result.encode()).eql(value)) return error.InvalidRelationalRecord;
        return result;
    }
    pub fn extend(self: Output, previous: [32]u8) ![32]u8 {
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        hash.update(&previous);
        hash.update((try self.encode()).slice());
        return hash.finalResult();
    }
};
pub const Manifest = struct {
    pub const max_bytes = 1024;
    job: Job,
    vector: p.Value,
    checkpoint: Ref,
    pub fn encode(self: Manifest, bytes: []u8) ![]const u8 {
        const job = try self.job.encode();
        if (self.job.phase != .complete) return error.IncompleteResult;
        const vector = try q.RelationalCaptured.Vector.decodeStored(self.vector);
        if (vector.count != self.job.source_count) return error.InvalidRelationalRecord;
        try self.checkpoint.validate();
        if (self.checkpoint.domain != .query_result or self.checkpoint.namespace != self.job.namespace() or self.checkpoint.record != self.job.checkpoint or self.checkpoint.spec.format != q.RelationalState.checkpoint_format or self.checkpoint.spec.length > q.fuze.RelationalCheckpoint.max_bytes) return error.InvalidRelationalRecord;
        var writer: std.Io.Writer = .fixed(bytes[0..@min(bytes.len, max_bytes)]);
        try start(&writer, "RQM1");
        try writer.writeInt(u16, job.len, .little);
        try writer.writeAll(job.slice());
        try writer.writeInt(u16, self.vector.len, .little);
        try writer.writeAll(self.vector.slice());
        try writer.writeAll((try self.checkpoint.encode()).slice());
        return writer.buffered();
    }
    pub fn decode(bytes: []const u8) !Manifest {
        if (bytes.len > max_bytes) return error.InvalidRelationalRecord;
        var reader: std.Io.Reader = .fixed(bytes);
        try open(&reader, "RQM1");
        const result: Manifest = .{ .job = try Job.decode(try p.Value.init(try reader.take(try reader.takeInt(u16, .little)))), .vector = try p.Value.init(try reader.take(try reader.takeInt(u16, .little))), .checkpoint = try Ref.decode(try p.Value.init(try reader.take(Ref.encoded_bytes))) };
        if (reader.bufferedLen() != 0) return error.InvalidRelationalRecord;
        var canonical: [max_bytes]u8 = undefined;
        if (!std.mem.eql(u8, bytes, try result.encode(&canonical))) return error.InvalidRelationalRecord;
        return result;
    }
};

/// Stable original cause and public classification, with the operator witness
/// in the failed checkpoint when available. Infrastructure failures without a
/// declared classification remain failed attempts, not fabricated job outcomes.
pub const Failure = struct {
    cause: p.Diagnostic.Code,
    code: p.Diagnostic.Code,
    category: p.Diagnostic.Category,
    pub fn fromError(err: anyerror) !?Failure {
        if (@import("ApiCodes.zig").fromError(err)) |entry| return .{ .cause = try .init(@errorName(err)), .code = try .init(entry.code), .category = entry.category };
        if (q.QueryFailure.fromError(err, .execution)) |failure| return .{ .cause = try .init(@errorName(err)), .code = try .init(switch (failure.code) {
            inline else => |code| "query." ++ @tagName(code),
        }), .category = failure.category() };
        return null;
    }
    pub fn denied(self: Failure) bool {
        return self.category == .access;
    }
    pub fn encode(self: Failure) !p.Value {
        try self.cause.validate();
        try self.code.validate();
        var bytes: [p.Value.max_bytes]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&bytes);
        try start(&writer, "RQF1");
        try writer.writeByte(@intCast(self.cause.len));
        try writer.writeAll(self.cause.slice());
        try writer.writeByte(@intCast(self.code.len));
        try writer.writeAll(self.code.slice());
        try writer.writeByte(@intCast(@backingInt(self.category)));
        return p.Value.init(writer.buffered());
    }
    pub fn decode(value: p.Value) !Failure {
        try value.validate();
        var reader: std.Io.Reader = .fixed(value.slice());
        try open(&reader, "RQF1");
        const result: Failure = .{ .cause = try .init(try reader.take(try reader.takeByte())), .code = try .init(try reader.take(try reader.takeByte())), .category = std.enums.fromInt(p.Diagnostic.Category, try reader.takeByte()) orelse return error.InvalidRelationalRecord };
        if (reader.bufferedLen() != 0 or !(try result.encode()).eql(value)) return error.InvalidRelationalRecord;
        return result;
    }
};
