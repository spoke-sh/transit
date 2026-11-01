//! One Table acceptance record. Index roots and receipt identity are published
//! together; optional row bytes belong to this record's accepted WAL position.
const std = @import("std");
const p = @import("transit_protocol");
const d = p.DataLifecycle;
const Declaration = @import("TableDeclaration.zig");
const pages = @import("TreeStore.zig").pages;
pub const max_metadata_bytes = 16 * 1024;
pub const header_bytes = 44;

pub const Root = struct {
    kind: Declaration.Kind,
    interpretation: d.Definition,
    declaration: d.Content,
    schema_fingerprint: [32]u8,
    retired: bool,
    next_segment: u64,
    partition: u64,
    next_lsn: u64 = 0,
    /// Last logical mutation's exclusive frontier; a physical flush is not a
    /// source change and cannot invalidate an otherwise current computation.
    changed_lsn: u64 = 0,
    rows: ?pages.Reference = null,
    scan_rows: ?pages.Reference = null,
    /// Stable row identity -> primary-key hash. Physical relocation leaves this
    /// index unchanged; accepted mutations publish it with the row locators.
    identities: ?pages.Reference,
    /// Complete collation-aware storage key -> primary-key hash. Required on
    /// disk; an older root cannot silently acquire an empty ordered directory.
    ordered_rows: ?pages.Reference,
    /// Required physical schema -> exact declaration and live locator count.
    /// Immutable historical roots retain their own mappings.
    physical_schemas: ?pages.Reference,
    /// Stable column ID -> immutable ADD-time declaration. Current insertion
    /// defaults never supply values for older physical rows.
    column_origins: ?pages.Reference,
    receipts: ?pages.Reference = null,
    pins: ?pages.Reference = null,
    /// Mandatory logical read boundary. Zero retains all accepted history.
    history_floor: u64,
    /// Live history leases ordered by their original exclusive frontier.
    history_pins: ?pages.Reference,
    /// Required on disk: older roots must not silently lose admitted work.
    operations: ?pages.Reference,
    pending: ?pages.Reference,
    live_rows: u64 = 0,
    /// Mandatory physical history coverage; absent persisted fields reject.
    archive: @import("TableArchive.zig").Coverage,
    /// Required even when null. Only a recovery publication may advance it.
    recovery: ?@import("TableRecovery.zig").Reference,
    /// Required accepted physical work; missing persisted state is incompatible.
    maintenance: @import("TableMaintenanceState.zig"),
    /// Required durable predecessor barrier. A staged object alone is not one.
    transaction: ?@import("TableTransaction.zig").Reference,

    pub fn declared(self: Root) Declaration.Stored {
        return .{ .kind = self.kind, .interpretation = self.interpretation, .content = self.declaration, .schema_fingerprint = self.schema_fingerprint, .retired = self.retired };
    }

    pub fn validate(self: Root) !void {
        try self.declared().validate();
        try self.archive.validate(self.next_lsn);
        try self.maintenance.validate(self);
        if (self.transaction) |reference| try reference.validate();
        if (self.recovery) |reference| try reference.validate(self.next_lsn);
        if (self.partition == 0 or self.next_segment == 0 or self.changed_lsn > self.next_lsn or self.history_floor > self.next_lsn or
            (self.history_pins != null and self.pins == null) or
            (self.live_rows == 0) != (self.rows == null) or
            (self.live_rows == 0) != (self.scan_rows == null) or
            (self.live_rows == 0) != (self.ordered_rows == null) or
            (self.live_rows == 0) != (self.physical_schemas == null) or
            (self.live_rows == 0) != (self.identities == null)) return error.InvalidTableRoot;
    }
};

pub const Outcome = struct {
    position: d.Position,
    matched: u64,
    affected: u64,
    live_rows: u64,
};

pub const Receipt = struct { binding: d.Binding, changes: [32]u8, outcome: Outcome, transaction: ?p.Transaction.Decision };

pub const Operation = struct {
    binding: d.Binding,
    intent: d.Content,
    basis: struct { interpretation: d.Definition, position: d.Position, changed_lsn: u64 },
    phase: enum { admitted, rejected, cancelled },
    reason: enum { none, definition_changed, data_changed, duplicate_key, missing_row, invalid_rows, work_limit, check_violation },

    pub fn validate(self: Operation) !void {
        try self.binding.validate();
        try self.intent.validate();
        try self.basis.interpretation.validate();
        try self.basis.position.validate();
        if (!std.meta.eql(self.binding.target, self.basis.interpretation.object) or
            self.basis.changed_lsn > self.basis.position.next_lsn or
            (self.phase == .rejected) != (self.reason != .none)) return error.InvalidTableOperation;
        switch (self.binding.action) {
            .insert, .update, .delete => {},
            else => return error.InvalidTableOperation,
        }
    }
};

pub const Record = struct {
    definition: p.Growth.Definition,
    previous: [32]u8,
    root: Root,
    action: union(enum) {
        mutation: struct {
            binding: d.Binding,
            changes: [32]u8,
            outcome: Outcome,
            ingestion: enum { point, bulk },
            transaction: ?struct { prepared: @import("TableTransaction.zig").Reference, decision: p.Transaction.Decision },
        },
        declaration: struct {
            binding: d.Binding,
            changes: [32]u8,
            outcome: Outcome,
        },
        operation: Operation,
        transaction_prepare,
        transaction_abort: struct { prepared: @import("TableTransaction.zig").Reference, decision: p.Transaction.Decision },
        checkpoint,
        compaction,
        maintenance: @import("TableMaintenanceState.zig").Action,
        archive,
        recovery,
        history_floor,
        pin: struct { owner: d.Operation, basis: d.Content },
        pin_copy: struct { owner: d.Operation, basis: d.Content, source: p.Transaction.Pin },
        release: struct { owner: d.Operation, basis: d.Content },
    },

    pub fn receipt(self: Record) !Receipt {
        return switch (self.action) {
            .mutation => |value| .{ .binding = value.binding, .changes = value.changes, .outcome = value.outcome, .transaction = if (value.transaction) |tx| tx.decision else null },
            .declaration => |value| .{ .binding = value.binding, .changes = value.changes, .outcome = value.outcome, .transaction = null },
            else => error.InvalidTableReceipt,
        };
    }

    pub fn validate(self: Record, lsn: u64) !void {
        try self.root.validate();
        if (self.root.next_lsn != try std.math.add(u64, lsn, 1)) return error.InvalidTableHistory;
        if (self.action == .declaration and self.root.changed_lsn != self.root.next_lsn) return error.InvalidTableHistory;
        if (self.action == .mutation) if (self.action.mutation.transaction) |tx| {
            try tx.prepared.validate();
            try tx.decision.validate();
            if (tx.decision.outcome != .committed or self.root.transaction != null or
                !std.meta.eql(tx.decision.attempt.operation, self.action.mutation.binding.identity)) return error.InvalidTableHistory;
        };
        switch (self.action) {
            inline .mutation, .declaration => |value| {
                try value.binding.validate();
                if (!std.meta.eql(value.binding.target, self.root.interpretation.object) or
                    value.outcome.position.partition != self.root.partition or
                    value.outcome.position.next_lsn != self.root.next_lsn or
                    value.outcome.live_rows != self.root.live_rows or
                    value.outcome.affected > value.outcome.matched or
                    (value.outcome.affected != 0 and self.root.changed_lsn != self.root.next_lsn)) return error.InvalidTableHistory;
            },
            inline .pin, .release => |value| {
                try value.owner.validate();
                try value.basis.validate();
                if (!std.meta.eql(value.owner.scope, self.root.interpretation.object.scope)) return error.InvalidTableHistory;
            },
            .pin_copy => |value| {
                try value.owner.validate();
                try value.basis.validate();
                try value.source.owner.validate();
                try value.source.content.validate();
                if (!std.meta.eql(value.owner.scope, self.root.interpretation.object.scope) or
                    !std.meta.eql(value.source.owner.scope, value.owner.scope) or std.meta.eql(value.source.owner, value.owner)) return error.InvalidTableHistory;
            },
            .operation => |value| {
                try value.validate();
                if (!std.meta.eql(value.binding.target, self.root.interpretation.object) or
                    value.basis.position.partition != self.root.partition or
                    value.basis.position.next_lsn >= self.root.next_lsn) return error.InvalidTableHistory;
            },
            .transaction_prepare => if (self.root.transaction == null) return error.InvalidTransactionPreparation,
            .transaction_abort => |value| {
                try value.prepared.validate();
                try value.decision.validate();
                if (self.root.transaction != null or value.decision.outcome != .aborted) return error.InvalidTransactionPreparation;
            },
            .checkpoint, .compaction, .maintenance, .archive, .recovery, .history_floor => {},
        }
    }
};

pub fn encode(record: Record, rows: []const u8, output: []u8) ![]const u8 {
    if (output.len < header_bytes) return error.RecordTooLarge;
    var writer: std.Io.Writer = .fixed(output[header_bytes..][0..@min(max_metadata_bytes, output.len - header_bytes)]);
    try std.json.Stringify.value(record, .{}, &writer);
    const length = writer.buffered().len;
    if (rows.len > output.len - header_bytes - length) return error.RecordTooLarge;
    output[0..8].* = "TACCEPT1".*;
    output[8..40].* = p.Growth.definition_bytes;
    std.mem.writeInt(u32, output[40..44], @intCast(length), .little);
    @memcpy(output[header_bytes + length ..][0..rows.len], rows);
    return output[0 .. header_bytes + length + rows.len];
}

pub const Decoded = struct { record: Record, rows: []const u8 };
pub fn decodeFrame(allocator: std.mem.Allocator, frame: @import("TransitLog.zig").Frame, partition: u64, lsn: u64) !Decoded {
    const decoded = try decode(allocator, frame.payload, lsn);
    if (frame.header.partition_id != partition or frame.header.lsn != lsn or
        frame.header.partition_id != decoded.record.root.partition or
        (frame.header.kind != .row_delta and frame.header.kind != .manifest_checkpoint) or
        (decoded.record.action == .mutation) != (frame.header.kind == .row_delta) or
        (decoded.record.action != .mutation and decoded.rows.len != 0)) return error.InvalidTableHistory;
    return decoded;
}
pub fn decode(allocator: std.mem.Allocator, bytes: []const u8, lsn: u64) !Decoded {
    if (bytes.len < header_bytes or !std.mem.eql(u8, bytes[0..8], "TACCEPT1")) return error.InvalidTableHistory;
    if (!std.mem.eql(u8, bytes[8..40], &p.Growth.definition_bytes)) return error.IncompatibleDefinition;
    const length = std.mem.readInt(u32, bytes[40..44], .little);
    if (length > max_metadata_bytes or length > bytes.len - header_bytes) return error.InvalidTableHistory;
    const parsed = try std.json.parseFromSlice(Record, allocator, bytes[header_bytes..][0..length], .{});
    defer parsed.deinit();
    try parsed.value.validate(lsn);
    return .{ .record = parsed.value, .rows = bytes[header_bytes + length ..] };
}

pub const Locator = struct {
    pub const encoded_bytes = 57;
    pub const scan_bytes = 32 + encoded_bytes;
    kind: enum(u8) { wal = 1, segment = 2 },
    schema_revision: u64,
    lsn: u64,
    offset: u32,
    length: u32,
    digest: [32]u8,

    pub fn encode(self: Locator) !pages.Value {
        if (self.schema_revision == 0) return error.InvalidTableRowReference;
        var bytes: [encoded_bytes]u8 = undefined;
        bytes[0] = @backingInt(self.kind);
        std.mem.writeInt(u64, bytes[1..9], self.lsn, .little);
        std.mem.writeInt(u32, bytes[9..13], self.offset, .little);
        std.mem.writeInt(u32, bytes[13..17], self.length, .little);
        bytes[17..49].* = self.digest;
        std.mem.writeInt(u64, bytes[49..57], self.schema_revision, .little);
        return pages.Value.init(&bytes);
    }
    pub fn decode(value: pages.Value) !Locator {
        if (value.len != encoded_bytes or std.mem.readInt(u64, value.data[49..57], .little) == 0) return error.InvalidTableRowReference;
        return .{
            .kind = std.enums.fromInt(@FieldType(Locator, "kind"), value.data[0]) orelse return error.InvalidTableRowReference,
            .lsn = std.mem.readInt(u64, value.data[1..9], .little),
            .offset = std.mem.readInt(u32, value.data[9..13], .little),
            .length = std.mem.readInt(u32, value.data[13..17], .little),
            .digest = value.data[17..49].*,
            .schema_revision = std.mem.readInt(u64, value.data[49..57], .little),
        };
    }
    pub fn scanKey(self: Locator) !pages.Key {
        var bytes: [13]u8 = undefined;
        bytes[0] = @backingInt(self.kind);
        std.mem.writeInt(u64, bytes[1..9], self.lsn, .big);
        std.mem.writeInt(u32, bytes[9..13], self.offset, .big);
        return pages.Key.init(&bytes);
    }
    pub fn scanValue(self: Locator, key: pages.Key) !pages.Value {
        if (key.len != 32) return error.InvalidTableKey;
        var bytes: [scan_bytes]u8 = undefined;
        bytes[0..32].* = key.data[0..32].*;
        bytes[32..scan_bytes].* = (try self.encode()).data[0..encoded_bytes].*;
        return pages.Value.init(&bytes);
    }
};

pub fn hash(bytes: []const u8) [32]u8 {
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    return digest;
}

pub fn operationKey(operation: d.Operation) !pages.Key {
    try operation.validate();
    var bytes: [16]u8 = undefined;
    std.mem.writeInt(u64, bytes[0..8], operation.principal, .big);
    std.mem.writeInt(u64, bytes[8..16], operation.operation, .big);
    return pages.Key.init(&bytes);
}

pub fn rowKey(storage_key: []const u8) !pages.Key {
    return pages.Key.init(&hash(storage_key));
}
