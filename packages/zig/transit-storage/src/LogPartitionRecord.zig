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
const Compaction = @import("StreamCompaction.zig");
const Maintenance = @import("StreamMaintenanceState.zig");
pub const header_bytes = 44;
pub const max_metadata_bytes = 32 * 1024;
pub const max_batch_bytes = Log.max_payload_bytes - header_bytes - max_metadata_bytes;

pub const Root = struct {
    initialization: Initialization.Request,
    declared: Declaration.Stored,
    next_lsn: u64,
    changed_lsn: u64,
    next_offset: u64,
    retained_from: u64,
    clock_ms: ?u64,
    batches: ?pages.Reference,
    segments: ?pages.Reference,
    sealed_through: u64,
    hidden: @import("BitmapDirectory.zig").Root,
    compaction: ?Compaction.State,
    compacted: ?d.Position,
    receipts: ?pages.Reference,
    producers: ?pages.Reference,
    producer_receipts: ?pages.Reference,
    groups: ?pages.Reference,
    group_offsets: ?pages.Reference,
    pins: ?pages.Reference,
    transaction_pins: ?pages.Reference,
    transaction: ?@import("LogTransaction.zig").Reference,
    archive: @import("LogHistory.zig").Coverage,
    recovery: ?@import("LogRecovery.zig").Reference,
    maintenance: Maintenance,
    queue: ?@import("QueueIndex.zig").Root,

    pub fn initial(request: Initialization.Request) !Root {
        try request.validate();
        return .{ .initialization = request, .declared = request.declared, .next_lsn = 1, .changed_lsn = 0, .next_offset = 0, .retained_from = 0, .clock_ms = null, .batches = null, .segments = null, .sealed_through = 0, .hidden = .empty, .compaction = null, .compacted = null, .receipts = null, .producers = null, .producer_receipts = null, .groups = null, .group_offsets = null, .pins = null, .transaction_pins = null, .transaction = null, .archive = .empty, .recovery = null, .maintenance = .empty, .queue = if (request.declared.declaration.configuration.policy == .queue) .empty else null };
    }
    pub fn validate(self: Root) !void {
        try self.initialization.validate();
        if (self.changed_lsn > self.next_lsn) return error.InvalidLogRoot;
        if (self.transaction) |reference| try reference.validate();
        try self.requireControlDeclaration(self.declared);
        try self.archive.validate(self.next_lsn);
        try self.maintenance.validate(self);
        if ((self.declared.declaration.configuration.policy == .queue) != (self.queue != null)) return error.InvalidQueueRoot;
        if (self.queue) |queue| {
            try queue.validate();
            if (queue.next_offset != self.next_offset or self.groups != null or self.group_offsets != null or self.pins != null or
                self.maintenance.compaction_source_lsn != 0 or self.maintenance.rewrite_source_lsn != 0 or self.maintenance.rewrite_target != null) return error.InvalidQueueRoot;
        }
        if (self.recovery) |reference| try reference.validate(self.next_lsn);
        try self.hidden.validate();
        if (self.hidden.cardinality > self.next_offset) return error.InvalidStreamCompaction;
        if ((self.hidden.cardinality != 0 or self.compaction != null or self.compacted != null) and
            (self.declared.declaration.configuration.policy != .stream or self.declared.declaration.configuration.policy.stream.compact_key_column == null)) return error.InvalidStreamCompaction;
        if (self.compacted) |cut_value| {
            try cut_value.validate();
            if (cut_value.partition != self.initialization.partition or cut_value.next_lsn >= self.next_lsn) return error.InvalidStreamCompaction;
        }
        if (self.compaction) |work| {
            try work.validate();
            if (work.source.cut.accepted.partition != self.initialization.partition or work.source.cut.accepted.next_lsn >= self.next_lsn or
                work.source.cut.retained_from != self.retained_from or work.source.cut.next > self.next_offset or
                !std.meta.eql(work.source.cut.target.interpretation.object, self.declared.declaration.interpretation.object) or
                work.source.cut.target.interpretation.revision > self.declared.declaration.interpretation.revision or
                !std.meta.eql(work.source.declared.declaration.schema, self.initialization.declared.declaration.schema) or
                !std.meta.eql(work.source.declared.declaration.configuration.policy.stream, self.declared.declaration.configuration.policy.stream) or
                work.source.cut.target.partition != self.initialization.ordinal or !std.meta.eql(work.source.hidden, self.hidden)) return error.InvalidStreamCompaction;
        }
        if (self.next_lsn == 0 or self.retained_from > self.next_offset or (self.next_offset != self.retained_from) != (self.batches != null) or (self.producers != null) != (self.producer_receipts != null) or self.sealed_through > self.next_offset or self.sealed_through < self.retained_from or (self.sealed_through != self.retained_from and self.segments == null) or (self.next_offset == self.retained_from and self.segments != null) or (self.groups != null) != (self.group_offsets != null)) return error.InvalidLogRoot;
    }
    pub fn requireDeclaration(self: Root, declared: Declaration.Stored) !void {
        try self.requireControlDeclaration(declared);
        if (declared.retired) return error.LogDeclarationConflict;
    }
    /// Closure and settlement preserve the interpretation of accepted reads.
    /// Their publication still records the current declaration, even after DROP.
    pub fn requireControlDeclaration(self: Root, declared: Declaration.Stored) !void {
        try declared.validate();
        const seed = self.initialization.declared.declaration;
        const value = declared.declaration;
        if ((self.declared.retired and !std.meta.eql(declared, self.declared)) or !std.meta.eql(value.interpretation.object, seed.interpretation.object) or
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
        return self.retainedCut(declared);
    }
    /// Retained data remains readable by physical maintenance after retirement.
    /// This descriptor grants no new append, claim or consume authority.
    pub fn retainedCut(self: Root, declared: Declaration.Stored) !q.Cut {
        try self.requireControlDeclaration(declared);
        return .{ .target = .{ .definition = p.Growth.current_definition, .interpretation = declared.declaration.interpretation, .partition = self.initialization.ordinal }, .accepted = self.position(), .retained_from = self.retained_from, .next = self.next_offset };
    }
    pub fn position(self: Root) d.Position {
        return .{ .partition = self.initialization.partition, .next_lsn = self.next_lsn };
    }
};

pub const Resolution = struct { prepared: @import("LogTransaction.zig").Reference, decision: p.Transaction.Decision };

pub const Record = struct {
    definition: p.Growth.Definition,
    previous: [32]u8,
    root: Root,
    action: union(enum) {
        operation: Evidence.Record,
        archive: struct { cut: d.Position, from_lsn: u64 },
        flush: struct { cut: d.Position, receipt: q.AppendReceipt, segment: @import("LogSegment.zig").Descriptor },
        rewrite: struct { receipt: q.AppendReceipt, segment: ?@import("LogSegment.zig").Descriptor },
        expire: struct { cut: d.Position, receipt: q.AppendReceipt, observed_ms: u64, clock_ms: u64, protected_next: u64 },
        queue_expire: struct { lease: q.Lease, observed: @import("LogTime.zig").Sample },
        queue_schedule: struct { kind: @import("QueueTimeRun.zig").Kind, steps: u16 },
        compaction_start,
        compaction_step: struct { from: u64, through: u64 },
        compaction_publish: d.Position,
        compaction_cancel: d.Position,
        checkpoint,
        transaction_pin: p.Transaction.Pin,
        transaction_release: p.Transaction.Pin,
        transaction_prepare,
        transaction_commit: Resolution,
        transaction_abort: Resolution,
        maintenance: Maintenance.Action,
    },

    pub fn frameKind(self: Record) Log.FrameKind {
        return if (self.action == .operation and self.action.operation.outcome == .append) .row_delta else .manifest_checkpoint;
    }

    pub fn changesData(self: Record) bool {
        return switch (self.action) {
            .operation => |value| switch (value.outcome) {
                .append, .assignment, .offset, .claim, .settlement, .terminal => true,
                .read, .release, .queue_release, .closed => false,
            },
            .expire, .queue_expire, .compaction_publish, .transaction_commit => true,
            else => false,
        };
    }

    pub fn validate(self: Record, lsn: u64) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.root.validate();
        if (self.changesData() and self.root.changed_lsn != self.root.next_lsn) return error.InvalidLogHistory;
        if (lsn == 0 or self.root.next_lsn != try std.math.add(u64, lsn, 1) or
            std.mem.allEqual(u8, &self.previous, 0)) return error.InvalidLogHistory;
        switch (self.action) {
            .operation => |evidence| {
                try evidence.validate();
                if (!std.meta.eql(evidence.declared, self.root.declared) or !std.meta.eql(evidence.accepted(), self.root.position()) or
                    evidence.target().partition != self.root.initialization.ordinal or self.root.receipts == null) return error.InvalidLogHistory;
                if (evidence.outcome == .append and (evidence.outcome.append.next != self.root.next_offset or evidence.outcome.append.observed_ms != self.root.clock_ms)) return error.InvalidLogHistory;
                if (evidence.outcome == .claim and evidence.outcome.claim.observed.latest_ms != self.root.clock_ms) return error.InvalidLogHistory;
                if (evidence.outcome == .settlement and evidence.outcome.settlement.observed.latest_ms != self.root.clock_ms) return error.InvalidLogHistory;
                if (evidence.outcome == .terminal and evidence.outcome.terminal.observed.latest_ms != self.root.clock_ms) return error.InvalidLogHistory;
            },
            .archive => |value| {
                try value.cut.validate();
                if (value.cut.partition != self.root.initialization.partition or value.cut.next_lsn > lsn or value.from_lsn >= self.root.archive.through or self.root.archive.through > value.cut.next_lsn or self.root.archive.through - value.from_lsn > @import("TableArchive.zig").max_frames) return error.InvalidLogArchive;
            },
            .checkpoint => {
                const reference = self.root.recovery orelse return error.InvalidLogRecovery;
                if (reference.next_lsn != lsn) return error.InvalidLogRecovery;
            },
            .maintenance => {},
            .transaction_prepare => {
                if (self.root.transaction == null) return error.InvalidLogPreparation;
            },
            .transaction_commit, .transaction_abort => |resolution| {
                try resolution.prepared.validate();
                try resolution.decision.validate();
                if (self.root.transaction != null or
                    (self.action == .transaction_commit) != (resolution.decision.outcome == .committed)) return error.InvalidLogPreparation;
                try resolution.decision.attempt.transaction.requireObject(self.root.declared.declaration.interpretation.object);
            },
            .transaction_pin, .transaction_release => |pin| {
                try pin.owner.validate();
                try (@import("LogTransaction.zig").Reference{ .content = pin.content }).validate();
                if (self.root.transaction_pins == null or !std.meta.eql(pin.owner.scope, self.root.declared.declaration.interpretation.object.scope)) return error.InvalidLogTransaction;
            },
            .flush => |value| {
                try value.cut.validate();
                try value.receipt.validate();
                try value.segment.validate();
                if (value.cut.partition != self.root.initialization.partition or value.cut.next_lsn > lsn or value.receipt.accepted.partition != value.cut.partition or value.receipt.accepted.next_lsn > value.cut.next_lsn or value.receipt.next != self.root.sealed_through) return error.InvalidLogSegment;
            },
            .rewrite => |value| {
                try value.receipt.validate();
                if (value.receipt.accepted.partition != self.root.initialization.partition or value.receipt.accepted.next_lsn > lsn or value.receipt.next > self.root.sealed_through) return error.InvalidLogSegment;
                if (value.segment) |segment| {
                    try segment.validate();
                    if (segment.layout != .sparse) return error.InvalidLogSegment;
                }
            },
            .expire => |value| {
                try value.cut.validate();
                try value.receipt.validate();
                if (value.cut.partition != self.root.initialization.partition or value.cut.next_lsn > lsn or value.receipt.accepted.partition != value.cut.partition or value.receipt.accepted.next_lsn > value.cut.next_lsn or value.receipt.next != self.root.retained_from or value.protected_next < value.receipt.next or value.protected_next > self.root.next_offset or self.root.clock_ms != value.clock_ms or value.observed_ms > value.clock_ms or self.root.declared.declaration.configuration.retention.max_age_ms == null) return error.InvalidLogExpiration;
            },
            .queue_expire => |value| {
                try value.lease.validate();
                try value.observed.validate();
                if (self.root.queue == null or self.root.clock_ms != value.observed.latest_ms or
                    value.observed.earliest_ms < value.lease.expires_ms or
                    value.lease.offset >= self.root.next_offset or value.lease.target.partition != self.root.initialization.ordinal or
                    !std.meta.eql(value.lease.target.interpretation.object, self.root.declared.declaration.interpretation.object)) return error.InvalidQueueExpiration;
            },
            .queue_schedule => |value| {
                if (self.root.queue == null or value.steps == 0 or value.steps > @import("QueueTimeRun.zig").max_rows or
                    value.steps > self.root.declared.declaration.limits.timer_steps or self.root.queue.?.timer_next == value.kind) return error.InvalidQueueSchedule;
            },
            .compaction_start => {
                const work = self.root.compaction orelse return error.InvalidStreamCompaction;
                if (work.source.cut.accepted.next_lsn != lsn or work.phase != .index or work.next != work.source.cut.retained_from or work.latest != null) return error.InvalidStreamCompaction;
            },
            .compaction_step => |step| {
                const work = self.root.compaction orelse return error.InvalidStreamCompaction;
                if (step.from < work.source.cut.retained_from or step.through <= step.from or step.through > work.source.cut.next or step.through - step.from > Compaction.max_rows) return error.InvalidStreamCompaction;
            },
            .compaction_publish, .compaction_cancel => |cut_value| {
                try cut_value.validate();
                if (self.root.compaction != null or cut_value.partition != self.root.initialization.partition or cut_value.next_lsn >= lsn) return error.InvalidStreamCompaction;
                if (self.action == .compaction_publish and !std.meta.eql(self.root.compacted, @as(?d.Position, cut_value))) return error.InvalidStreamCompaction;
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
pub fn groupOffsetKey(progress: q.GroupProgress) !pages.Key {
    try progress.validate();
    var bytes: [16]u8 = undefined;
    std.mem.writeInt(u64, bytes[0..8], progress.next, .big);
    std.mem.writeInt(u64, bytes[8..16], progress.group.id, .big);
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
