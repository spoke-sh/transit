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
    receipts: ?pages.Reference = null,
    pins: ?pages.Reference = null,
    /// Required on disk: older roots must not silently lose admitted work.
    operations: ?pages.Reference,
    pending: ?pages.Reference,
    live_rows: u64 = 0,
    /// Mandatory physical history coverage; absent persisted fields reject.
    archive: @import("TableArchive.zig").Coverage,

    pub fn declared(self: Root) Declaration.Stored {
        return .{ .interpretation = self.interpretation, .content = self.declaration, .schema_fingerprint = self.schema_fingerprint, .retired = self.retired };
    }

    pub fn validate(self: Root) !void {
        try self.declared().validate();
        try self.archive.validate(self.next_lsn);
        if (self.partition == 0 or self.next_segment == 0 or self.changed_lsn > self.next_lsn or
            (self.live_rows == 0) != (self.rows == null) or
            (self.live_rows == 0) != (self.scan_rows == null) or
            (self.live_rows == 0) != (self.ordered_rows == null) or
            (self.live_rows == 0) != (self.identities == null)) return error.InvalidTableRoot;
    }
};

pub const Outcome = struct {
    position: d.Position,
    matched: u64,
    affected: u64,
    live_rows: u64,
};

pub const Receipt = struct { binding: d.Binding, changes: [32]u8, outcome: Outcome };

pub const Operation = struct {
    binding: d.Binding,
    intent: d.Content,
    basis: struct { interpretation: d.Definition, position: d.Position, changed_lsn: u64 },
    phase: enum { admitted, rejected, cancelled },
    reason: enum { none, definition_changed, data_changed, duplicate_key, missing_row, invalid_rows, work_limit },

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
        },
        declaration: struct {
            binding: d.Binding,
            changes: [32]u8,
            outcome: Outcome,
        },
        operation: Operation,
        checkpoint,
        archive,
        pin: struct { owner: d.Operation, basis: d.Content },
        release: struct { owner: d.Operation, basis: d.Content },
    },

    pub fn receipt(self: Record) !Receipt {
        return switch (self.action) {
            inline .mutation, .declaration => |value| .{ .binding = value.binding, .changes = value.changes, .outcome = value.outcome },
            else => error.InvalidTableReceipt,
        };
    }

    pub fn validate(self: Record, lsn: u64) !void {
        try self.root.validate();
        if (self.root.next_lsn != try std.math.add(u64, lsn, 1)) return error.InvalidTableHistory;
        if (self.action == .declaration and self.root.changed_lsn != self.root.next_lsn) return error.InvalidTableHistory;
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
            .operation => |value| {
                try value.validate();
                if (!std.meta.eql(value.binding.target, self.root.interpretation.object) or
                    value.basis.position.partition != self.root.partition or
                    value.basis.position.next_lsn >= self.root.next_lsn) return error.InvalidTableHistory;
            },
            .checkpoint, .archive => {},
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
    kind: enum(u8) { wal = 1, segment = 2 },
    lsn: u64,
    offset: u32,
    length: u32,
    digest: [32]u8,

    pub fn encode(self: Locator) !pages.Value {
        var bytes: [49]u8 = undefined;
        bytes[0] = @backingInt(self.kind);
        std.mem.writeInt(u64, bytes[1..9], self.lsn, .little);
        std.mem.writeInt(u32, bytes[9..13], self.offset, .little);
        std.mem.writeInt(u32, bytes[13..17], self.length, .little);
        bytes[17..49].* = self.digest;
        return pages.Value.init(&bytes);
    }
    pub fn decode(value: pages.Value) !Locator {
        if (value.len != 49) return error.InvalidTableRowReference;
        return .{
            .kind = std.enums.fromInt(@FieldType(Locator, "kind"), value.data[0]) orelse return error.InvalidTableRowReference,
            .lsn = std.mem.readInt(u64, value.data[1..9], .little),
            .offset = std.mem.readInt(u32, value.data[9..13], .little),
            .length = std.mem.readInt(u32, value.data[13..17], .little),
            .digest = value.data[17..49].*,
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
        var bytes: [81]u8 = undefined;
        bytes[0..32].* = key.data[0..32].*;
        bytes[32..81].* = (try self.encode()).data[0..49].*;
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
