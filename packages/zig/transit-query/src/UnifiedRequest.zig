//! Bounded public upload commands. All parts fit the existing Station envelope;
//! request publication, query call admission and result completion are distinct.
const std = @import("std");
const q = @import("root.zig");
const p = q.protocol;
const Ref = q.station.PublicationReference;
pub const part_bytes = q.station.PublicationParts.part_bytes;
pub const Command = union(enum) {
    initialize,
    begin: Ref,
    part: struct { namespace: u64, ordinal: u32, second: bool, bytes: []const u8 },
    seal: u64,
    submit: u64,
    cancel: u64,
    collect: u64,
    retire: u64,
    draft_open: q.Draft.Open,
    draft_close: u64,
    draft_submit: q.Draft.Selection,
    pub fn encode(self: Command) !p.Value {
        var bytes: [q.station.Frame.max_payload]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&bytes);
        try writer.writeAll(switch (self) {
            .initialize => "UQI1",
            .begin => "UQB1",
            .part => "UQP1",
            .seal => "UQS1",
            .submit => "UQX1",
            .cancel => "UQK1",
            .collect => "UQG1",
            .retire => "UQR1",
            .draft_open => "UQD1",
            .draft_close => "UQH1",
            .draft_submit => "UQE1",
        });
        switch (self) {
            .initialize => {},
            .begin => |reference| {
                try q.Bundle.checkReference(reference);
                try writer.writeAll((try reference.encode()).slice());
            },
            .part => |part| {
                if (part.namespace == 0 or part.bytes.len == 0 or part.bytes.len > part_bytes) return error.InvalidQueryUpload;
                try writer.writeInt(u64, part.namespace, .little);
                try writer.writeInt(u32, part.ordinal, .little);
                try writer.writeByte(@intFromBool(part.second));
                try writer.writeAll(part.bytes);
            },
            .draft_open => |value| try value.write(&writer),
            .draft_submit => |value| {
                if (value.generation == 0 or value.namespace == 0) return error.InvalidQueryDraft;
                try writer.writeInt(u64, value.generation, .little);
                try writer.writeInt(u64, value.namespace, .little);
            },
            .seal, .submit, .cancel, .collect, .retire, .draft_close => |namespace| {
                if (namespace == 0) return error.InvalidQueryUpload;
                try writer.writeInt(u64, namespace, .little);
            },
        }
        return p.Value.init(writer.buffered());
    }
    /// Part bytes borrow the caller's frame storage.
    pub fn decode(value: *const p.Value) !Command {
        try value.validate();
        if (value.len < 4 or value.len > q.station.Frame.max_payload) return error.InvalidQueryUpload;
        var reader: std.Io.Reader = .fixed(value.slice());
        const tag = try reader.take(4);
        const result: Command = if (std.mem.eql(u8, tag, "UQI1")) .initialize else if (std.mem.eql(u8, tag, "UQB1")) .{ .begin = try Ref.decode(try p.Value.init(try reader.take(Ref.encoded_bytes))) } else if (std.mem.eql(u8, tag, "UQP1")) blk: {
            const namespace = try reader.takeInt(u64, .little);
            const ordinal = try reader.takeInt(u32, .little);
            const second = try reader.takeByte();
            if (second > 1) return error.InvalidQueryUpload;
            break :blk .{ .part = .{ .namespace = namespace, .ordinal = ordinal, .second = second == 1, .bytes = try reader.take(reader.bufferedLen()) } };
        } else if (std.mem.eql(u8, tag, "UQS1")) .{ .seal = try reader.takeInt(u64, .little) } else if (std.mem.eql(u8, tag, "UQX1")) .{ .submit = try reader.takeInt(u64, .little) } else if (std.mem.eql(u8, tag, "UQK1")) .{ .cancel = try reader.takeInt(u64, .little) } else if (std.mem.eql(u8, tag, "UQG1")) .{ .collect = try reader.takeInt(u64, .little) } else if (std.mem.eql(u8, tag, "UQR1")) .{ .retire = try reader.takeInt(u64, .little) } else if (std.mem.eql(u8, tag, "UQD1")) .{ .draft_open = try q.Draft.Open.read(&reader) } else if (std.mem.eql(u8, tag, "UQH1")) .{ .draft_close = try reader.takeInt(u64, .little) } else if (std.mem.eql(u8, tag, "UQE1")) .{ .draft_submit = .{ .generation = try reader.takeInt(u64, .little), .namespace = try reader.takeInt(u64, .little) } } else return error.InvalidQueryUpload;
        if (reader.bufferedLen() != 0 or !(try result.encode()).eql(value.*)) return error.InvalidQueryUpload;
        return result;
    }
};
pub const Phase = enum(u8) { uploading = 1, sealed = 2, admitted = 3, complete = 4, cancelled = 5, denied = 6, rejected = 7, retired = 8 };
pub const Status = struct {
    reference: Ref,
    phase: Phase = .uploading,
    correlation: u64 = 0,
    manifest: ?Ref = null,
    collected: bool = false,
    pub fn encode(self: Status) !p.Value {
        try q.Bundle.checkReference(self.reference);
        if (self.correlation > p.max_counter or (self.phase == .uploading or self.phase == .sealed) and self.correlation != 0) return error.InvalidQueryUpload;
        if ((self.phase == .admitted or self.phase == .complete or self.phase == .denied or self.phase == .rejected) and self.correlation == 0) return error.InvalidQueryUpload;
        if (self.phase == .complete and self.manifest == null) return error.InvalidQueryUpload;
        if (self.manifest) |reference| {
            if (self.phase != .complete and self.phase != .retired) return error.InvalidQueryUpload;
            try reference.validate();
            if (reference.record != q.UnifiedRecords.manifest_record or reference.spec.format != q.UnifiedRecords.manifest_format or reference.spec.length > q.UnifiedRecords.Manifest.max_bytes or reference.spec.length == 0) return error.InvalidQueryManifest;
        }
        if (self.collected and self.phase != .cancelled and self.phase != .retired) return error.InvalidQueryUpload;
        var bytes: [151]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&bytes);
        try writer.writeAll("UQU1");
        try writer.writeAll((try self.reference.encode()).slice());
        try writer.writeByte(@backingInt(self.phase));
        try writer.writeInt(u64, self.correlation, .little);
        try writer.writeByte(@intFromBool(self.manifest != null));
        if (self.manifest) |reference| try writer.writeAll((try reference.encode()).slice());
        try writer.writeByte(@intFromBool(self.collected));
        return p.Value.init(writer.buffered());
    }
    pub fn decode(value: p.Value) !Status {
        try value.validate();
        var reader: std.Io.Reader = .fixed(value.slice());
        if (!std.mem.eql(u8, try reader.take(4), "UQU1")) return error.InvalidQueryUpload;
        var out: Status = .{ .reference = try Ref.decode(try p.Value.init(try reader.take(Ref.encoded_bytes))), .phase = std.enums.fromInt(Phase, try reader.takeByte()) orelse return error.InvalidQueryUpload, .correlation = try reader.takeInt(u64, .little) };
        out.manifest = switch (try reader.takeByte()) {
            0 => null,
            1 => try Ref.decode(try p.Value.init(try reader.take(Ref.encoded_bytes))),
            else => return error.InvalidQueryUpload,
        };
        out.collected = switch (try reader.takeByte()) {
            0 => false,
            1 => true,
            else => return error.InvalidQueryUpload,
        };
        if (reader.bufferedLen() != 0 or !(try out.encode()).eql(value)) return error.InvalidQueryUpload;
        return out;
    }
};
