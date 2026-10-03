//! Versioned durable v1 query records. No pointers or ambient authority persist.
const std = @import("std");
const q = @import("root.zig");
const p = q.protocol;
const m = q.fuze.Unified;
const Pub = q.station.Publication;
const Ref = q.station.PublicationReference;
pub const arrow_format: u32 = 0x31415155; // UQA1
pub const manifest_format: u32 = 0x314d5155; // UQM1
pub const manifest_record = std.math.maxInt(u64);
pub fn key(tag: u8, first: u64, second: u64) p.Value {
    var bytes: [19]u8 = undefined;
    bytes[0..2].* = "\x00U".*;
    bytes[2] = tag;
    std.mem.writeInt(u64, bytes[3..11], first, .big);
    std.mem.writeInt(u64, bytes[11..19], second, .big);
    return p.Value.init(&bytes) catch unreachable;
}
pub fn identity(value: u64) !void {
    if (value == 0 or value > p.max_counter) return error.InvalidQueryIdentity;
}
fn finish(reader: *std.Io.Reader) !void {
    if (reader.bufferedLen() != 0) return error.InvalidQueryRecord;
}
fn magic(reader: *std.Io.Reader, expected: []const u8) !void {
    if (!std.mem.eql(u8, try reader.take(expected.len), expected)) return error.InvalidQueryRecord;
}
pub const Policy = struct {
    peer: u64,
    requests: u64,
    revision: u64,
    declaration: [32]u8,
    allow: bool,
    limits: q.Bundle.Limits,
    pub fn encode(self: Policy) !p.Value {
        try identity(self.peer);
        try identity(self.requests);
        try identity(self.revision);
        try self.limits.validate();
        var bytes: [85]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&bytes);
        try writer.writeAll("UQA1");
        inline for (.{ "peer", "requests", "revision" }) |name| try writer.writeInt(u64, @field(self, name), .little);
        try writer.writeAll(&self.declaration);
        try writer.writeByte(@intFromBool(self.allow));
        inline for (.{ "pages", "segments", "result_bytes" }) |name| try writer.writeInt(u64, @field(self.limits, name), .little);
        return p.Value.init(writer.buffered());
    }
    pub fn decode(value: p.Value) !Policy {
        try value.validate();
        var reader: std.Io.Reader = .fixed(value.slice());
        try magic(&reader, "UQA1");
        var result: Policy = .{ .peer = try reader.takeInt(u64, .little), .requests = try reader.takeInt(u64, .little), .revision = try reader.takeInt(u64, .little), .declaration = (try reader.takeArray(32)).*, .allow = false, .limits = undefined };
        result.allow = switch (try reader.takeByte()) {
            0 => false,
            1 => true,
            else => return error.InvalidQueryRecord,
        };
        result.limits = .{ .pages = try reader.takeInt(u64, .little), .segments = try reader.takeInt(u64, .little), .result_bytes = try reader.takeInt(u64, .little) };
        try finish(&reader);
        _ = try result.encode();
        return result;
    }
};
pub const Phase = enum(u8) { capturing = 1, captured = 2, complete = 3, cancelled = 4, denied = 5, failed = 6, retired = 7 };
pub const Job = struct {
    id: u64,
    destination: u64,
    correlation: u64,
    policy_revision: u64,
    source: p.Growth.ReadVersionId,
    request: Ref,
    phase: Phase = .capturing,
    continuation: u64,
    cleanup: u64 = 1,
    failure: ?q.QueryFailure = null,
    pub fn namespace(self: Job) u64 {
        return (@as(u64, 1) << 63) | self.id;
    }
    pub fn publication(self: Job, resource: u64) Pub {
        return .{ .domain = .query_result, .resource = resource, .namespace = self.namespace() };
    }
    pub fn encode(self: Job) !p.Value {
        inline for (.{ "id", "destination", "correlation", "policy_revision" }) |name| try identity(@field(self, name));
        try p.Growth.validateVersionId(self.source);
        try q.Bundle.checkReference(self.request);
        if (self.source.input != self.id) return error.InvalidQueryRecord;
        try identity(self.continuation);
        if ((self.phase == .failed or self.phase == .denied) != (self.failure != null)) return error.InvalidQueryRecord;
        if (self.failure) |failure| if (failure.denied() != (self.phase == .denied)) return error.InvalidQueryRecord;
        var bytes: [167]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&bytes);
        try writer.writeAll("UQJ1");
        inline for (.{ "id", "destination", "correlation", "policy_revision" }) |name| try writer.writeInt(u64, @field(self, name), .little);
        try writer.writeInt(u64, self.source.pid, .little);
        try writer.writeInt(u64, self.source.input, .little);
        try writer.writeByte(self.source.index);
        try writer.writeAll((try self.request.encode()).slice());
        try writer.writeByte(@backingInt(self.phase));
        try writer.writeInt(u64, self.continuation, .little);
        try writer.writeInt(u64, self.cleanup, .little);
        try writer.writeByte(@intFromBool(self.failure != null));
        if (self.failure) |failure| try writer.writeAll((try failure.encode()).slice());
        return p.Value.init(writer.buffered());
    }
    pub fn decode(value: p.Value) !Job {
        try value.validate();
        var reader: std.Io.Reader = .fixed(value.slice());
        try magic(&reader, "UQJ1");
        var result: Job = .{ .id = try reader.takeInt(u64, .little), .destination = try reader.takeInt(u64, .little), .correlation = try reader.takeInt(u64, .little), .policy_revision = try reader.takeInt(u64, .little), .source = .{ .pid = try reader.takeInt(u64, .little), .input = try reader.takeInt(u64, .little), .index = try reader.takeByte() }, .request = try Ref.decode(try p.Value.init(try reader.take(Ref.encoded_bytes))), .phase = std.enums.fromInt(Phase, try reader.takeByte()) orelse return error.InvalidQueryRecord, .continuation = try reader.takeInt(u64, .little), .cleanup = try reader.takeInt(u64, .little) };
        result.failure = switch (try reader.takeByte()) {
            0 => null,
            1 => try q.QueryFailure.decode(try p.Value.init(try reader.take(q.QueryFailure.encoded_bytes))),
            else => return error.InvalidQueryRecord,
        };
        try finish(&reader);
        _ = try result.encode();
        return result;
    }
};
pub fn initialChain() [32]u8 {
    @setEvalBranchQuota(10000);
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash("transit.query.result.v1\x00", &digest, .{});
    return digest;
}
pub const Checkpoint = struct {
    progress: m.Stream.Progress,
    cursor: q.UnifiedSource.Cursor = .{},
    bytes: u64 = 0,
    chain: [32]u8 = initialChain(),
    pub fn encode(self: Checkpoint) !p.Value {
        if (self.cursor.ordinal != self.progress.pages) return error.InvalidQueryRecord;
        var bytes: [p.Value.max_bytes]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&bytes);
        try writer.writeAll("UQC1");
        try writer.writeAll(&try self.progress.encode());
        try writer.writeByte(@intFromBool(self.cursor.done));
        switch (self.progress.basis.kind) {
            .kv => {
                try writer.writeByte(@intFromBool(self.cursor.after != null));
                if (self.cursor.after) |after| {
                    try p.Growth.validateKey(after);
                    try writer.writeByte(@intCast(after.len));
                    try writer.writeAll(after.slice());
                }
                if (self.cursor.table_after != null or !std.meta.eql(self.cursor.traversal, q.document.Document.SequenceCursor{})) return error.InvalidQueryRecord;
            },
            .table => {
                try writer.writeByte(@intFromBool(self.cursor.table_after != null));
                try writer.writeInt(i64, self.cursor.table_after orelse 0, .little);
                if (self.cursor.after != null or !std.meta.eql(self.cursor.traversal, q.document.Document.SequenceCursor{})) return error.InvalidQueryRecord;
            },
            .document => {
                try self.cursor.traversal.current.validate(true);
                try writer.writeInt(u64, self.cursor.traversal.current.counter, .little);
                try writer.writeInt(u64, self.cursor.traversal.current.replica, .little);
                try writer.writeByte(@backingInt(self.cursor.traversal.phase));
                if (self.cursor.after != null or self.cursor.table_after != null) return error.InvalidQueryRecord;
            },
        }
        try writer.writeInt(u64, self.bytes, .little);
        try writer.writeAll(&self.chain);
        return p.Value.init(writer.buffered());
    }
    pub fn decode(value: p.Value) !Checkpoint {
        try value.validate();
        var reader: std.Io.Reader = .fixed(value.slice());
        try magic(&reader, "UQC1");
        var result: Checkpoint = .{ .progress = try m.Stream.Progress.decode(try reader.take(m.Stream.progress_bytes)) };
        result.cursor.ordinal = result.progress.pages;
        result.cursor.done = switch (try reader.takeByte()) {
            0 => false,
            1 => true,
            else => return error.InvalidQueryRecord,
        };
        switch (result.progress.basis.kind) {
            .kv => result.cursor.after = switch (try reader.takeByte()) {
                0 => null,
                1 => try p.Value.init(try reader.take(try reader.takeByte())),
                else => return error.InvalidQueryRecord,
            },
            .table => {
                const present = try reader.takeByte();
                const after = try reader.takeInt(i64, .little);
                if (present > 1 or (present == 0 and after != 0)) return error.InvalidQueryRecord;
                result.cursor.table_after = if (present == 1) after else null;
            },
            .document => result.cursor.traversal = .{ .current = .{ .counter = try reader.takeInt(u64, .little), .replica = try reader.takeInt(u64, .little) }, .phase = std.enums.fromInt(@FieldType(q.document.Document.SequenceCursor, "phase"), try reader.takeByte()) orelse return error.InvalidQueryRecord },
        }
        result.bytes = try reader.takeInt(u64, .little);
        result.chain = (try reader.takeArray(32)).*;
        try finish(&reader);
        _ = try result.encode();
        return result;
    }
};
pub const Segment = struct {
    ordinal: u64,
    row_start: u64,
    rows: u8,
    reference: Ref,
    arrow_digest: [32]u8,
    pub fn encode(self: Segment) !p.Value {
        try self.reference.validate();
        if (self.reference.domain != .query_result or self.ordinal >= manifest_record - 1 or self.reference.record != self.ordinal + 1 or self.rows > m.max_rows or self.reference.spec.format != arrow_format or self.reference.spec.length == 0 or self.reference.spec.length > m.Arrow.segment_bytes) return error.InvalidResultSegment;
        var bytes: [125]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&bytes);
        try writer.writeAll("UQS1");
        try writer.writeInt(u64, self.ordinal, .little);
        try writer.writeInt(u64, self.row_start, .little);
        try writer.writeByte(self.rows);
        try writer.writeAll((try self.reference.encode()).slice());
        try writer.writeAll(&self.arrow_digest);
        return p.Value.init(writer.buffered());
    }
    pub fn decode(value: p.Value) !Segment {
        try value.validate();
        var reader: std.Io.Reader = .fixed(value.slice());
        try magic(&reader, "UQS1");
        const result: Segment = .{ .ordinal = try reader.takeInt(u64, .little), .row_start = try reader.takeInt(u64, .little), .rows = try reader.takeByte(), .reference = try Ref.decode(try p.Value.init(try reader.take(Ref.encoded_bytes))), .arrow_digest = (try reader.takeArray(32)).* };
        try finish(&reader);
        _ = try result.encode();
        return result;
    }
    pub fn extend(self: Segment, previous: [32]u8) ![32]u8 {
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        hash.update(&previous);
        hash.update((try self.encode()).slice());
        return hash.finalResult();
    }
};
/// Original route plus exact source/plan/progress, all segment coverage and hash
/// chain. The finite manifest is itself a Publication, never an oversized value.
pub const Manifest = struct {
    pub const max_bytes = 512;
    job: Job,
    checkpoint: Checkpoint,
    pub fn encode(self: Manifest, output: []u8) ![]const u8 {
        if (self.job.phase != .complete or self.checkpoint.progress.finished == null or self.checkpoint.progress.segments == 0 or self.checkpoint.bytes == 0) return error.IncompleteResult;
        const job = try self.job.encode();
        const checkpoint = try self.checkpoint.encode();
        var writer: std.Io.Writer = .fixed(output);
        try writer.writeAll("UQM1");
        try writer.writeInt(u16, job.len, .little);
        try writer.writeInt(u16, checkpoint.len, .little);
        try writer.writeAll(job.slice());
        try writer.writeAll(checkpoint.slice());
        if (writer.end > max_bytes) return error.InvalidQueryManifest;
        return writer.buffered();
    }
    pub fn decode(bytes: []const u8) !Manifest {
        if (bytes.len > max_bytes) return error.InvalidQueryManifest;
        var reader: std.Io.Reader = .fixed(bytes);
        try magic(&reader, "UQM1");
        const job_length = try reader.takeInt(u16, .little);
        const checkpoint_length = try reader.takeInt(u16, .little);
        const result: Manifest = .{ .job = try Job.decode(try p.Value.init(try reader.take(job_length))), .checkpoint = try Checkpoint.decode(try p.Value.init(try reader.take(checkpoint_length))) };
        try finish(&reader);
        var canonical: [max_bytes]u8 = undefined;
        if (!std.mem.eql(u8, try result.encode(&canonical), bytes)) return error.InvalidQueryManifest;
        return result;
    }
};
/// Resumable self-input identity is a source job plus exactly one cursor. Actual
/// stage progress still comes from committed Publication descriptors.
pub const Continuation = struct {
    job: u64,
    input: u64,
    pub fn encode(self: Continuation) !p.Value {
        try identity(self.job);
        try identity(self.input);
        var bytes: [20]u8 = undefined;
        bytes[0..4].* = "UQN1".*;
        std.mem.writeInt(u64, bytes[4..12], self.job, .little);
        std.mem.writeInt(u64, bytes[12..20], self.input, .little);
        return p.Value.init(&bytes);
    }
    pub fn decode(value: p.Value) !Continuation {
        if (value.len != 20 or !std.mem.eql(u8, value.data[0..4], "UQN1")) return error.InvalidQueryContinuation;
        const out: Continuation = .{ .job = std.mem.readInt(u64, value.data[4..12], .little), .input = std.mem.readInt(u64, value.data[12..20], .little) };
        _ = try out.encode();
        return out;
    }
};

pub fn identityValue(value: u64) p.Value {
    var bytes: [8]u8 = undefined;
    std.mem.writeInt(u64, &bytes, value, .little);
    return p.Value.init(&bytes) catch unreachable;
}
pub fn readIdentity(value: p.Value) !u64 {
    if (value.len != 8) return error.InvalidQueryIdentity;
    const id = std.mem.readInt(u64, value.data[0..8], .little);
    if (id == 0 or id > p.max_counter) return error.InvalidQueryIdentity;
    return id;
}
