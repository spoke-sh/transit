//! Versioned owned records for incremental result capture. No native pointers,
//! source capabilities or implicit physical deletion live in these values.
const std = @import("std");
const p = @import("transit_client").protocol;
const f = @import("transit_fuze");
const Frame = @import("Frame.zig");
pub const segment_bytes = 8192;
pub const fragment_bytes = Frame.max_payload - 22;
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
    pub fn encode(self: Job) !p.Value {
        var value: p.Value = .{};
        var writer: std.Io.Writer = .fixed(&value.data);
        try writer.writeAll("GQJ2");
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
        value.len = @intCast(writer.end);
        return value;
    }
    pub fn decode(value: p.Value) !Job {
        try value.validate();
        if (value.len != 108 or !std.mem.eql(u8, value.data[0..4], "GQJ2")) return error.InvalidQueryJob;
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
        try writer.writeAll("GQS2");
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
        if (value.len != 55 or !std.mem.eql(u8, value.data[0..4], "GQS2")) return error.InvalidResultSegment;
        var reader: std.Io.Reader = .fixed(value.slice()[4..]);
        const self: Segment = .{ .result = try reader.takeInt(u64, .little), .ordinal = try reader.takeInt(u64, .little), .bytes = try reader.takeInt(u16, .little), .rows = try reader.takeByte(), .digest = (try reader.takeArray(32)).* };
        if (self.result == 0 or self.result > p.max_counter or self.bytes < 8 or self.bytes > segment_bytes or self.rows > f.model.max_rows or !value.eql(try self.encode())) return error.InvalidResultSegment;
        return self;
    }
    pub fn extend(self: Segment, previous: [32]u8) ![32]u8 {
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        hash.update("transit.station.query.segments.v2\x00");
        hash.update(&previous);
        hash.update((try self.encode()).slice());
        return hash.finalResult();
    }
};
pub const Stage = struct {
    candidate: f.Stream.Progress,
    segment: Segment,
    written: u16 = 0,
    pub fn encode(self: Stage) !p.Value {
        var value: p.Value = .{};
        var writer: std.Io.Writer = .fixed(&value.data);
        try writer.writeAll("GQT2");
        try writer.writeAll(&try self.candidate.encode());
        try writer.writeAll((try self.segment.encode()).slice());
        try writer.writeInt(u16, self.written, .little);
        value.len = @intCast(writer.end);
        return value;
    }
    pub fn decode(value: p.Value) !Stage {
        try value.validate();
        if (value.len != 204 or !std.mem.eql(u8, value.data[0..4], "GQT2")) return error.InvalidQueryStage;
        const self: Stage = .{ .candidate = try f.Stream.Progress.decode(value.data[4..147]), .segment = try Segment.decode(try p.Value.init(value.data[147..202])), .written = std.mem.readInt(u16, value.data[202..204], .little) };
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
        bytes[0..4].* = "GQC2".*;
        std.mem.writeInt(u64, bytes[4..12], self.result, .little);
        std.mem.writeInt(u64, bytes[12..20], self.page, .little);
        std.mem.writeInt(u16, bytes[20..22], self.written, .little);
        return p.Value.init(&bytes);
    }
    pub fn decode(value: p.Value) !Continuation {
        try value.validate();
        if (value.len != 22 or !std.mem.eql(u8, value.data[0..4], "GQC2")) return error.InvalidQueryContinuation;
        const self: Continuation = .{ .result = std.mem.readInt(u64, value.data[4..12], .little), .page = std.mem.readInt(u64, value.data[12..20], .little), .written = std.mem.readInt(u16, value.data[20..22], .little) };
        if (self.result == 0 or self.result > p.max_counter or self.written > segment_bytes) return error.InvalidQueryContinuation;
        return self;
    }
};
