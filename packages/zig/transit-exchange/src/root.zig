//! Durable finite captures above Station. This package cannot dispatch I/O.
const std = @import("std");
pub const station = @import("transit_station");
pub const p = station.protocol;
pub const Publication = station.Publication;
pub const Failure = @import("Failure.zig");
pub const OutcomeDiagnostic = @import("OutcomeDiagnostic.zig");
pub const Exchange = @import("Exchange.zig");
pub const Client = @import("Client.zig");
pub const Caller = @import("Caller.zig").For;
pub const Worker = @import("Worker.zig").For;
pub const Service = @import("Service.zig").For;
pub const codec = @import("codec.zig");
pub const Phase = enum(u8) { preparing = 1, capturing = 2, complete = 3, unknown = 4, retired = 5, ready = 6 };
pub const Limits = struct {
    segment_bytes: u32,
    capture_bytes: u64,
    segments: u32,
    pub fn validate(self: Limits) !void {
        if (self.segment_bytes == 0 or self.capture_bytes < self.segment_bytes or self.segments == 0) return error.InvalidExchangeLimits;
    }
};
pub const Origin = struct { caller: u64, input: u64, parent: u64 = 0, protocol: u32 };
pub const Descriptor = struct {
    pub const magic = "EXD1";
    phase: Phase = .preparing,
    protocol: u32,
    caller: u64,
    input: u64,
    parent: u64,
    owner: u64,
    effect: u64 = 0,
    attempt: u64 = 0,
    executor: u64 = 0,
    reconcile_before_ms: u64,
    segment_bytes: u32,
    capture_bytes: u64,
    max_segments: u32,
    segments: u32 = 0,
    bytes: u64 = 0,
    pending_kind: u32 = 0,
    terminal_code: u32 = 0,
    collected: u32 = 0,
    chain: [32]u8 = Coverage.initial,
    pub fn validate(self: Descriptor) !void {
        try (Limits{ .segment_bytes = self.segment_bytes, .capture_bytes = self.capture_bytes, .segments = self.max_segments }).validate();
        if (self.protocol == 0 or self.caller == 0 or self.input == 0 or self.owner == 0 or self.reconcile_before_ms == 0) return error.InvalidExchangeRecord;
        if (self.segments > self.max_segments or self.bytes > self.capture_bytes or self.collected > self.segments + @as(u64, @intFromBool(self.pending_kind != 0))) return error.InvalidExchangeRecord;
        if (self.collected != 0 and self.phase != .retired) return error.InvalidExchangeRecord;
        if (self.segments == 0 and (self.bytes != 0 or !std.mem.eql(u8, &self.chain, &Coverage.initial))) return error.InvalidExchangeRecord;
        if (self.effect == 0 or self.attempt == 0 or self.executor == 0) {
            if (self.effect != 0 or self.attempt != 0 or self.executor != 0 or self.phase == .capturing or self.phase == .complete) return error.InvalidExchangeRecord;
        }
        if ((self.phase == .preparing or self.phase == .ready) and self.effect != 0) return error.InvalidExchangeRecord;
        if (self.phase == .ready and (self.pending_kind != 0 or self.segments == 0)) return error.InvalidExchangeRecord;
        if (self.phase == .complete and (self.pending_kind != 0 or self.terminal_code == 0)) return error.InvalidExchangeRecord;
        if (self.phase != .complete and self.phase != .retired and self.terminal_code != 0) return error.InvalidExchangeRecord;
    }
    pub fn encode(self: Descriptor) !p.Value {
        return codec.encode(self);
    }
    pub fn decode(value: p.Value) !Descriptor {
        return codec.decode(Descriptor, value);
    }
};
pub const Member = struct {
    pub const magic = "EXM1";
    ordinal: u32,
    kind: u32,
    format: u32,
    length: u32,
    digest: [32]u8,
    chain: [32]u8,
    pub fn validate(self: Member) !void {
        if (self.kind == 0 or self.format == 0) return error.InvalidExchangeRecord;
    }
    pub fn spec(self: Member) Publication.Spec {
        return .{ .format = self.format, .length = self.length, .digest = self.digest };
    }
    pub fn encode(self: Member) !p.Value {
        return codec.encode(self);
    }
    pub fn decode(value: p.Value) !Member {
        return codec.decode(Member, value);
    }
};
pub const Coverage = struct {
    pub const initial: [32]u8 = blk: {
        @setEvalBranchQuota(10000);
        var out: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash("transit.exchange.coverage.v1\x00", &out, .{});
        break :blk out;
    };
    pub fn next(chain: [32]u8, ordinal: u32, kind: u32, spec: Publication.Spec) [32]u8 {
        var h = std.crypto.hash.sha2.Sha256.init(.{});
        h.update(&chain);
        var bytes: [16]u8 = undefined;
        std.mem.writeInt(u32, bytes[0..4], ordinal, .little);
        std.mem.writeInt(u32, bytes[4..8], kind, .little);
        std.mem.writeInt(u32, bytes[8..12], spec.format, .little);
        std.mem.writeInt(u32, bytes[12..16], spec.length, .little);
        h.update(&bytes);
        h.update(&spec.digest);
        return h.finalResult();
    }
};
pub const Intent = struct {
    pub const magic = "EXI1";
    resource: u64,
    exchange: u64,
    segments: u32,
    bytes: u64,
    chain: [32]u8,
    pub fn validate(self: Intent) !void {
        if (self.resource == 0 or self.exchange == 0 or self.segments == 0) return error.InvalidExchangeRecord;
    }
    pub fn encode(self: Intent) !p.Value {
        return codec.encode(self);
    }
    pub fn decode(value: p.Value) !Intent {
        return codec.decode(Intent, value);
    }
};
test {
    _ = Failure;
    _ = @import("exchange_test.zig");
}
