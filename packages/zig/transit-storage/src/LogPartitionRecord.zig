//! Atomic log payload/index publication. Logical offsets are independent of the
//! WAL frontier; control records advance only the latter. All fields are required.
const std = @import("std");
const p = @import("transit_protocol");
const d = p.DataLifecycle;
const q = p.StreamQueue;
const Declaration = @import("LogDeclaration.zig");
const Initialization = @import("LogInitialization.zig");
const Evidence = @import("LogEvidence.zig");
const Log = @import("TransitLog.zig");
const pages = @import("TreeStore.zig").pages;
pub const header_bytes = 44;
pub const max_metadata_bytes = 32 * 1024;
pub const max_batch_bytes = Log.max_payload_bytes - header_bytes - max_metadata_bytes;

pub const Root = struct {
    initialization: Initialization.Request,
    declared: Declaration.Stored,
    next_lsn: u64,
    next_offset: u64,
    retained_from: u64,
    clock_ms: ?u64,
    batches: ?pages.Reference,
    segments: ?pages.Reference,
    sealed_through: u64,
    receipts: ?pages.Reference,
    producers: ?pages.Reference,
    producer_receipts: ?pages.Reference,
    groups: ?pages.Reference,
    pins: ?pages.Reference,
    archive: @import("LogHistory.zig").Coverage,
    recovery: ?@import("LogRecovery.zig").Reference,

    pub fn initial(request: Initialization.Request) !Root {
        try request.validate();
        return .{ .initialization = request, .declared = request.declared, .next_lsn = 1, .next_offset = 0, .retained_from = 0, .clock_ms = null, .batches = null, .segments = null, .sealed_through = 0, .receipts = null, .producers = null, .producer_receipts = null, .groups = null, .pins = null, .archive = .empty, .recovery = null };
    }
    pub fn validate(self: Root) !void {
        try self.initialization.validate();
        try self.requireDeclaration(self.declared);
        try self.archive.validate(self.next_lsn);
        if (self.recovery) |reference| try reference.validate(self.next_lsn);
        if (self.next_lsn == 0 or self.retained_from > self.next_offset or (self.next_offset != 0) != (self.batches != null) or (self.producers != null) != (self.producer_receipts != null) or self.sealed_through > self.next_offset or (self.sealed_through != 0) != (self.segments != null)) return error.InvalidLogRoot;
    }
    pub fn requireDeclaration(self: Root, declared: Declaration.Stored) !void {
        try declared.validate();
        const seed = self.initialization.declared.declaration;
        const value = declared.declaration;
        if (declared.retired or !std.meta.eql(value.interpretation.object, seed.interpretation.object) or
            value.interpretation.revision < self.declared.declaration.interpretation.revision or
            (value.interpretation.revision == self.declared.declaration.interpretation.revision and !std.meta.eql(declared, self.declared)) or
            !std.meta.eql(value.schema, seed.schema) or !std.meta.eql(value.configuration.partitioning, seed.configuration.partitioning) or
            std.meta.activeTag(value.configuration.policy) != std.meta.activeTag(seed.configuration.policy)) return error.LogDeclarationConflict;
        switch (value.configuration.policy) {
            .stream => |stream| if (stream.compact_key_column != seed.configuration.policy.stream.compact_key_column or stream.timestamp_column != seed.configuration.policy.stream.timestamp_column) return error.LogDeclarationConflict,
            .queue => |queue| if (queue.ordering != seed.configuration.policy.queue.ordering or queue.key_column != seed.configuration.policy.queue.key_column) return error.LogDeclarationConflict,
        }
    }
    pub fn cut(self: Root, declared: Declaration.Stored) !q.Cut {
        try self.requireDeclaration(declared);
        return .{ .target = .{ .definition = p.Growth.current_definition, .interpretation = declared.declaration.interpretation, .partition = self.initialization.ordinal }, .accepted = self.position(), .retained_from = self.retained_from, .next = self.next_offset };
    }
    pub fn position(self: Root) d.Position {
        return .{ .partition = self.initialization.partition, .next_lsn = self.next_lsn };
    }
};

pub const Record = struct {
    definition: p.Growth.Definition,
    previous: [32]u8,
    root: Root,
    action: union(enum) {
        operation: Evidence.Record,
        archive: struct { cut: d.Position, from_lsn: u64 },
        flush: struct { cut: d.Position, receipt: q.AppendReceipt, segment: @import("LogSegment.zig").Descriptor },
        checkpoint,
    },

    pub fn frameKind(self: Record) Log.FrameKind {
        return if (self.action == .operation and self.action.operation.outcome == .append) .row_delta else .manifest_checkpoint;
    }

    pub fn validate(self: Record, lsn: u64) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.root.validate();
        if (lsn == 0 or self.root.next_lsn != try std.math.add(u64, lsn, 1) or
            std.mem.allEqual(u8, &self.previous, 0)) return error.InvalidLogHistory;
        switch (self.action) {
            .operation => |evidence| {
                try evidence.validate();
                if (!std.meta.eql(evidence.declared, self.root.declared) or !std.meta.eql(evidence.accepted(), self.root.position()) or
                    evidence.target().partition != self.root.initialization.ordinal or self.root.receipts == null) return error.InvalidLogHistory;
                if (evidence.outcome == .append and (evidence.outcome.append.next != self.root.next_offset or evidence.outcome.append.observed_ms != self.root.clock_ms)) return error.InvalidLogHistory;
            },
            .archive => |value| {
                try value.cut.validate();
                if (value.cut.partition != self.root.initialization.partition or value.cut.next_lsn > lsn or value.from_lsn >= self.root.archive.through or self.root.archive.through > value.cut.next_lsn or self.root.archive.through - value.from_lsn > @import("TableArchive.zig").max_frames) return error.InvalidLogArchive;
            },
            .checkpoint => {
                const reference = self.root.recovery orelse return error.InvalidLogRecovery;
                if (reference.next_lsn != lsn) return error.InvalidLogRecovery;
            },
            .flush => |value| {
                try value.cut.validate();
                try value.receipt.validate();
                try value.segment.validate();
                if (value.cut.partition != self.root.initialization.partition or value.cut.next_lsn > lsn or value.receipt.accepted.partition != value.cut.partition or value.receipt.accepted.next_lsn > value.cut.next_lsn or value.receipt.next != self.root.sealed_through) return error.InvalidLogSegment;
            },
        }
    }
};

pub fn encode(record: Record, payload: []const u8, output: []u8) ![]const u8 {
    if (record.root.next_lsn < 2) return error.InvalidLogHistory;
    try record.validate(record.root.next_lsn - 1);
    try verifyPayload(record, payload);
    if (output.len < header_bytes) return error.LogRecordTooLarge;
    var writer: std.Io.Writer = .fixed(output[header_bytes..][0..@min(output.len - header_bytes, max_metadata_bytes)]);
    var encoder: std.json.Stringify = .{ .writer = &writer };
    try p.Json.write(record, &encoder);
    const length = writer.end;
    if (payload.len > output.len - header_bytes - length) return error.LogRecordTooLarge;
    output[0..8].* = "LOGPART1".*;
    output[8..40].* = p.Growth.definition_bytes;
    std.mem.writeInt(u32, output[40..44], @intCast(length), .big);
    @memcpy(output[header_bytes + length ..][0..payload.len], payload);
    return output[0 .. header_bytes + length + payload.len];
}
fn verifyPayload(record: Record, payload: []const u8) !void {
    if (payload.len > max_batch_bytes) return error.LogRecordTooLarge;
    if (record.action == .operation and record.action.operation.outcome == .append) {
        if (!std.meta.eql(record.action.operation.outcome.append.append.payload, @import("LogBatch.zig").content(payload))) return error.LogPayloadConflict;
    } else {
        if (payload.len != 0) return error.InvalidLogHistory;
    }
}
pub const Decoded = struct { record: Record, payload: []const u8 };
pub fn decode(allocator: std.mem.Allocator, frame: Log.Frame, partition: u64, lsn: u64) !Decoded {
    const bytes = frame.payload;
    if (bytes.len < header_bytes or !std.mem.eql(u8, bytes[0..8], "LOGPART1")) return error.InvalidLogHistory;
    if (!std.mem.eql(u8, bytes[8..40], &p.Growth.definition_bytes)) return error.IncompatibleDefinition;
    const length = std.mem.readInt(u32, bytes[40..44], .big);
    if (length == 0 or length > max_metadata_bytes or length > bytes.len - header_bytes) return error.InvalidLogHistory;
    const parsed = try p.Json.parseFromSlice(Record, allocator, bytes[header_bytes..][0..length]);
    defer parsed.deinit();
    const value = parsed.value;
    try value.validate(lsn);
    if (frame.header.partition_id != partition or frame.header.lsn != lsn or value.root.initialization.partition != partition or frame.header.writer_epoch == 0 or frame.header.policy_epoch == 0 or
        frame.header.kind != value.frameKind()) return error.InvalidLogHistory;
    const payload = bytes[header_bytes + length ..];
    try verifyPayload(value, payload);
    return .{ .record = value, .payload = payload };
}

pub fn integerKey(value: u64) !pages.Key {
    var bytes: [8]u8 = undefined;
    std.mem.writeInt(u64, &bytes, value, .big);
    return pages.Key.init(&bytes);
}
pub fn producerKey(append: q.Append, sequence: bool) !pages.Key {
    try append.validate();
    const producer = append.producer orelse return error.LogProducerRequired;
    var bytes: [40]u8 = undefined;
    std.mem.writeInt(u64, bytes[0..8], append.operation.principal, .big);
    bytes[8..24].* = producer.id;
    std.mem.writeInt(u64, bytes[24..32], producer.epoch, .big);
    std.mem.writeInt(u64, bytes[32..40], producer.sequence, .big);
    return pages.Key.init(bytes[0..@as(usize, if (sequence) 40 else 24)]);
}
pub fn valueEncode(value: anytype) !pages.Value {
    var bytes: [2048]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&bytes);
    var encoder: std.json.Stringify = .{ .writer = &writer };
    try p.Json.write(value, &encoder);
    return pages.Value.init(writer.buffered());
}
pub fn valueDecode(comptime T: type, allocator: std.mem.Allocator, value: pages.Value) !T {
    const parsed = try p.Json.parseFromSlice(T, allocator, value.data[0..value.len]);
    defer parsed.deinit();
    try parsed.value.validate();
    return parsed.value;
}
