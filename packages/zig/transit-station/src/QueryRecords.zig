//! Versioned owned records for incremental result capture. No native pointers,
//! source capabilities or implicit physical deletion live in these values.
const std = @import("std");
const p = @import("transit_client").protocol;
const f = @import("transit_fuze");
const m = f.Unified;
const Frame = @import("Frame.zig");
pub const segment_bytes = 8192;
pub const fragment_bytes = Frame.max_payload - 22;
/// A sender may not start a segment more than this many ordinals past the
/// last credit it has observed. Fixed, not adaptive; matches Delivery.tla's
/// checked `Window` constant. See docs/reference/streams.md#flow-control.
pub const credit_window: u64 = 2;
pub const Phase = enum(u8) { capturing = 1, captured = 2, published = 3, acknowledged = 4, cancelled = 5, denied = 6 };

pub fn key(tag: u8, result: u64, ordinal: u64, fragment: u16) p.Value {
    var bytes: [21]u8 = undefined;
    bytes[0..3].* = .{ 0, 'Q', tag };
    std.mem.writeInt(u64, bytes[3..11], result, .big);
    std.mem.writeInt(u64, bytes[11..19], ordinal, .big);
    std.mem.writeInt(u16, bytes[19..21], fragment, .big);
    return p.Value.init(&bytes) catch unreachable;
}
pub const Job = struct {
    result: u64,
    destination: u64,
    correlation: u64,
    table: u32,
    source: p.Growth.ReadVersionId,
    policy_revision: u64,
    phase: Phase = .capturing,
    bytes: u64 = 0,
    chain: [32]u8 = @splat(0),
    send_segment: u64 = 0,
    send_offset: u16 = 0,
    table_after: ?i64 = null,
    pub fn encode(self: Job) !p.Value {
        var value: p.Value = .{};
        var writer: std.Io.Writer = .fixed(&value.data);
        try writer.writeAll("GQJ1");
        inline for (.{ "result", "destination", "correlation" }) |field| try writer.writeInt(u64, @field(self, field), .little);
        try writer.writeInt(u32, self.table, .little);
        try writer.writeInt(u64, self.source.pid, .little);
        try writer.writeInt(u64, self.source.input, .little);
        try writer.writeByte(self.source.index);
        try writer.writeInt(u64, self.policy_revision, .little);
        try writer.writeByte(@backingInt(self.phase));
        try writer.writeInt(u64, self.bytes, .little);
        try writer.writeAll(&self.chain);
        try writer.writeInt(u64, self.send_segment, .little);
        try writer.writeInt(u16, self.send_offset, .little);
        try writer.writeByte(@intFromBool(self.table_after != null));
        try writer.writeInt(i64, self.table_after orelse 0, .little);
        value.len = @intCast(writer.end);
        return value;
    }
    pub fn decode(value: p.Value) !Job {
        try value.validate();
        if (value.len != 117 or !std.mem.eql(u8, value.data[0..4], "GQJ1")) return error.InvalidQueryJob;
        var reader: std.Io.Reader = .fixed(value.slice()[4..]);
        var self: Job = .{ .result = undefined, .destination = undefined, .correlation = undefined, .table = undefined, .source = undefined, .policy_revision = undefined };
        inline for (.{ "result", "destination", "correlation" }) |field| @field(self, field) = try reader.takeInt(u64, .little);
        self.table = try reader.takeInt(u32, .little);
        self.source = .{ .pid = try reader.takeInt(u64, .little), .input = try reader.takeInt(u64, .little), .index = try reader.takeByte() };
        self.policy_revision = try reader.takeInt(u64, .little);
        self.phase = std.enums.fromInt(Phase, try reader.takeByte()) orelse return error.InvalidQueryJob;
        self.bytes = try reader.takeInt(u64, .little);
        self.chain = (try reader.takeArray(32)).*;
        self.send_segment = try reader.takeInt(u64, .little);
        self.send_offset = try reader.takeInt(u16, .little);
        const present = try reader.takeByte();
        const after = try reader.takeInt(i64, .little);
        if (present > 1 or (present == 0 and after != 0)) return error.InvalidQueryJob;
        self.table_after = if (present == 1) after else null;
        if (self.result == 0 or self.result > p.max_counter or self.destination == 0 or self.destination > p.max_counter or self.correlation == 0 or self.table == 0 or self.policy_revision == 0 or
            self.source.pid == 0 or self.source.pid > p.max_counter or self.source.input != self.result or self.source.index >= p.Growth.version_changes or self.send_offset > segment_bytes or
            !value.eql(try self.encode())) return error.InvalidQueryJob;
        return self;
    }
};
pub const Segment = struct {
    result: u64,
    ordinal: u64,
    bytes: u16,
    rows: u8,
    digest: [32]u8,
    pub fn encode(self: Segment) !p.Value {
        var value: p.Value = .{};
        var writer: std.Io.Writer = .fixed(&value.data);
        try writer.writeAll("GQS1");
        try writer.writeInt(u64, self.result, .little);
        try writer.writeInt(u64, self.ordinal, .little);
        try writer.writeInt(u16, self.bytes, .little);
        try writer.writeByte(self.rows);
        try writer.writeAll(&self.digest);
        value.len = @intCast(writer.end);
        return value;
    }
    pub fn decode(value: p.Value) !Segment {
        try value.validate();
        if (value.len != 55 or !std.mem.eql(u8, value.data[0..4], "GQS1")) return error.InvalidResultSegment;
        var reader: std.Io.Reader = .fixed(value.slice()[4..]);
        const self: Segment = .{ .result = try reader.takeInt(u64, .little), .ordinal = try reader.takeInt(u64, .little), .bytes = try reader.takeInt(u16, .little), .rows = try reader.takeByte(), .digest = (try reader.takeArray(32)).* };
        if (self.result == 0 or self.result > p.max_counter or self.bytes < 8 or self.bytes > segment_bytes or self.rows > m.max_rows or !value.eql(try self.encode())) return error.InvalidResultSegment;
        return self;
    }
    pub fn extend(self: Segment, previous: [32]u8) ![32]u8 {
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        hash.update("transit.station.query.segments.v1\x00");
        hash.update(&previous);
        hash.update((try self.encode()).slice());
        return hash.finalResult();
    }
};
pub const Stage = struct {
    candidate: m.Stream.Progress,
    segment: Segment,
    written: u16 = 0,
    pub fn encode(self: Stage) !p.Value {
        var value: p.Value = .{};
        var writer: std.Io.Writer = .fixed(&value.data);
        try writer.writeAll("GQT1");
        try writer.writeAll(&try self.candidate.encode());
        try writer.writeAll((try self.segment.encode()).slice());
        try writer.writeInt(u16, self.written, .little);
        value.len = @intCast(writer.end);
        return value;
    }
    pub fn decode(value: p.Value) !Stage {
        try value.validate();
        if (value.len != 228 or !std.mem.eql(u8, value.data[0..4], "GQT1")) return error.InvalidQueryStage;
        const self: Stage = .{ .candidate = try m.Stream.Progress.decode(value.data[4..171]), .segment = try Segment.decode(try p.Value.init(value.data[171..226])), .written = std.mem.readInt(u16, value.data[226..228], .little) };
        if (self.written > self.segment.bytes or (self.written != self.segment.bytes and self.written % fragment_bytes != 0) or !value.eql(try self.encode())) return error.InvalidQueryStage;
        return self;
    }
};
pub const Continuation = struct {
    result: u64,
    page: u64,
    written: u16 = 0,
    pub fn encode(self: Continuation) !p.Value {
        var bytes: [22]u8 = undefined;
        bytes[0..4].* = "GQC1".*;
        std.mem.writeInt(u64, bytes[4..12], self.result, .little);
        std.mem.writeInt(u64, bytes[12..20], self.page, .little);
        std.mem.writeInt(u16, bytes[20..22], self.written, .little);
        return p.Value.init(&bytes);
    }
    pub fn decode(value: p.Value) !Continuation {
        try value.validate();
        if (value.len != 22 or !std.mem.eql(u8, value.data[0..4], "GQC1")) return error.InvalidQueryContinuation;
        const self: Continuation = .{ .result = std.mem.readInt(u64, value.data[4..12], .little), .page = std.mem.readInt(u64, value.data[12..20], .little), .written = std.mem.readInt(u16, value.data[20..22], .little) };
        if (self.result == 0 or self.result > p.max_counter or self.written > segment_bytes) return error.InvalidQueryContinuation;
        return self;
    }
};

pub const Transfer = struct {
    result: u64,
    source: u64,
    segments: u64 = 0,
    bytes: u64 = 0,
    rows: u64 = 0,
    chain: [32]u8 = @splat(0),
    pending: u16 = 0,
    schema: [32]u8 = @splat(0),
    pub fn encode(self: Transfer) !p.Value {
        var value: p.Value = .{};
        var writer: std.Io.Writer = .fixed(&value.data);
        try writer.writeAll("GQX1");
        inline for (.{ "result", "source", "segments", "bytes", "rows" }) |field| try writer.writeInt(u64, @field(self, field), .little);
        try writer.writeAll(&self.chain);
        try writer.writeInt(u16, self.pending, .little);
        try writer.writeAll(&self.schema);
        value.len = @intCast(writer.end);
        return value;
    }
    pub fn decode(value: p.Value) !Transfer {
        try value.validate();
        if (value.len != 110 or !std.mem.eql(u8, value.data[0..4], "GQX1")) return error.InvalidResultTransfer;
        var reader: std.Io.Reader = .fixed(value.slice()[4..]);
        var self: Transfer = .{ .result = undefined, .source = undefined };
        inline for (.{ "result", "source", "segments", "bytes", "rows" }) |field| @field(self, field) = try reader.takeInt(u64, .little);
        self.chain = (try reader.takeArray(32)).*;
        self.pending = try reader.takeInt(u16, .little);
        self.schema = (try reader.takeArray(32)).*;
        if (self.result == 0 or self.result > p.max_counter or self.source == 0 or self.source > p.max_counter or self.pending > segment_bytes or
            self.rows / m.max_rows + @intFromBool(self.rows % m.max_rows != 0) > self.segments or
            (self.segments == 0 and (self.bytes != 0 or self.rows != 0 or !std.mem.allEqual(u8, &self.chain, 0) or !std.mem.allEqual(u8, &self.schema, 0))) or
            !value.eql(try self.encode())) return error.InvalidResultTransfer;
        return self;
    }
    pub fn seal(self: *Transfer, manifest: Segment, schema: [32]u8) !void {
        if (manifest.result != self.result or manifest.ordinal != self.segments or self.pending != manifest.bytes) return error.IncompleteResultSegment;
        if (self.segments != 0 and !std.mem.eql(u8, &self.schema, &schema)) return error.ResultSchemaChanged;
        var next = self.*;
        next.segments = try std.math.add(u64, self.segments, 1);
        next.bytes = try std.math.add(u64, self.bytes, manifest.bytes);
        next.rows = try std.math.add(u64, self.rows, manifest.rows);
        next.chain = try manifest.extend(self.chain);
        next.schema = schema;
        next.pending = 0;
        self.* = next;
    }
};
pub const Manifest = struct {
    result: u64,
    destination: u64,
    correlation: u64,
    table: u32,
    policy_revision: u64,
    basis: m.Basis,
    plan: [32]u8,
    segments: u64,
    bytes: u64,
    rows: u64,
    chain: [32]u8,
    schema: [32]u8,
    pub fn encode(self: Manifest) !p.Value {
        var value: p.Value = .{};
        var writer: std.Io.Writer = .fixed(&value.data);
        try writer.writeAll("GQM1");
        inline for (.{ "result", "destination", "correlation" }) |field| try writer.writeInt(u64, @field(self, field), .little);
        try writer.writeInt(u32, self.table, .little);
        try writer.writeInt(u64, self.policy_revision, .little);
        try writer.writeByte(@backingInt(self.basis.kind));
        try writer.writeInt(u64, self.basis.resource, .little);
        try writer.writeInt(u64, self.basis.revision, .little);
        try writer.writeAll(&self.basis.contract);
        try writer.writeAll(&self.basis.schema);
        try writer.writeAll(&self.plan);
        inline for (.{ "segments", "bytes", "rows" }) |field| try writer.writeInt(u64, @field(self, field), .little);
        try writer.writeAll(&self.chain);
        try writer.writeAll(&self.schema);
        value.len = @intCast(writer.end);
        return value;
    }
    pub fn decode(value: p.Value) !Manifest {
        try value.validate();
        if (value.len != 241 or !std.mem.eql(u8, value.data[0..4], "GQM1")) return error.InvalidResultManifest;
        var reader: std.Io.Reader = .fixed(value.slice()[4..]);
        var self: Manifest = undefined;
        inline for (.{ "result", "destination", "correlation" }) |field| @field(self, field) = try reader.takeInt(u64, .little);
        self.table = try reader.takeInt(u32, .little);
        self.policy_revision = try reader.takeInt(u64, .little);
        self.basis = .{ .kind = std.enums.fromInt(m.SourceKind, try reader.takeByte()) orelse return error.InvalidResultManifest, .resource = try reader.takeInt(u64, .little), .revision = try reader.takeInt(u64, .little), .contract = (try reader.takeArray(32)).*, .schema = (try reader.takeArray(32)).* };
        self.plan = (try reader.takeArray(32)).*;
        inline for (.{ "segments", "bytes", "rows" }) |field| @field(self, field) = try reader.takeInt(u64, .little);
        self.chain = (try reader.takeArray(32)).*;
        self.schema = (try reader.takeArray(32)).*;
        if (self.result == 0 or self.result > p.max_counter or self.destination == 0 or self.destination > p.max_counter or self.correlation == 0 or self.table == 0 or self.policy_revision == 0 or
            self.basis.kind != .table or self.basis.resource == 0 or self.basis.resource > p.max_counter or self.segments == 0 or self.bytes < 8 or
            self.rows / m.max_rows + @intFromBool(self.rows % m.max_rows != 0) > self.segments or !value.eql(try self.encode())) return error.InvalidResultManifest;
        return self;
    }
    pub fn check(self: Manifest, transfer: Transfer) !void {
        if (transfer.pending != 0 or transfer.result != self.result or transfer.segments != self.segments or transfer.bytes != self.bytes or transfer.rows != self.rows or
            !std.mem.eql(u8, &self.chain, &transfer.chain) or !std.mem.eql(u8, &self.schema, &transfer.schema)) return error.IncompleteResult;
    }
};
pub const Fragment = struct {
    result: u64,
    segment: u64,
    offset: u16,
    bytes: []const u8,
    pub fn encode(self: Fragment) !p.Value {
        var value: p.Value = .{};
        var writer: std.Io.Writer = .fixed(&value.data);
        try writer.writeAll("GQF1");
        try writer.writeInt(u64, self.result, .little);
        try writer.writeInt(u64, self.segment, .little);
        try writer.writeInt(u16, self.offset, .little);
        try writer.writeAll(self.bytes);
        value.len = @intCast(writer.end);
        _ = try decode(&value);
        return value;
    }
    /// The returned byte slice borrows the supplied value.
    pub fn decode(value: *const p.Value) !Fragment {
        try value.validate();
        if (value.len <= 22 or value.len > Frame.max_payload or !std.mem.eql(u8, value.data[0..4], "GQF1")) return error.InvalidResultFragment;
        const self: Fragment = .{ .result = std.mem.readInt(u64, value.data[4..12], .little), .segment = std.mem.readInt(u64, value.data[12..20], .little), .offset = std.mem.readInt(u16, value.data[20..22], .little), .bytes = value.slice()[22..] };
        if (self.result == 0 or self.result > p.max_counter or self.offset % fragment_bytes != 0 or @as(usize, self.offset) + self.bytes.len > segment_bytes) return error.InvalidResultFragment;
        return self;
    }
};
pub const Publication = struct {
    result: u64,
    segment: u64,
    offset: u16 = 0,
    pub fn encode(self: Publication) !p.Value {
        var value = try (Continuation{ .result = self.result, .page = self.segment, .written = self.offset }).encode();
        value.data[0..4].* = "GQP1".*;
        return value;
    }
    pub fn decode(value: p.Value) !Publication {
        try value.validate();
        if (value.len != 22 or !std.mem.eql(u8, value.data[0..4], "GQP1")) return error.InvalidQueryContinuation;
        var normalized = value;
        normalized.data[0..4].* = "GQC1".*;
        const decoded = try Continuation.decode(normalized);
        return .{ .result = decoded.result, .segment = decoded.page, .offset = decoded.written };
    }
};
/// Receiver-issued application admission credit (docs/reference/streams.md#flow-control): the
/// destination durably grants credit only for segments it has itself sealed.
/// `granted` is monotonically non-decreasing; the sender retains the last
/// value it observed under key tag `g`, independent of its own send cursor.
pub const Credit = struct {
    result: u64,
    granted: u64,
    pub fn encode(self: Credit) !p.Value {
        var bytes: [20]u8 = undefined;
        bytes[0..4].* = "GQG1".*;
        std.mem.writeInt(u64, bytes[4..12], self.result, .little);
        std.mem.writeInt(u64, bytes[12..20], self.granted, .little);
        return p.Value.init(&bytes);
    }
    pub fn decode(value: p.Value) !Credit {
        try value.validate();
        if (value.len != 20 or !std.mem.eql(u8, value.data[0..4], "GQG1")) return error.InvalidResultCredit;
        const self: Credit = .{ .result = std.mem.readInt(u64, value.data[4..12], .little), .granted = std.mem.readInt(u64, value.data[12..20], .little) };
        if (self.result == 0 or self.result > p.max_counter) return error.InvalidResultCredit;
        return self;
    }
};
