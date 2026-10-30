//! Hash-linked Document partition WAL records (`DOCPART1`). Binds the accepted
//! partition root, paged index roots, operation action, and immutable evidence
//! to the preceding record commitment.
const std = @import("std");
const p = @import("transit_protocol");
const d = p.DataLifecycle;
const doc = p.DocumentOperation;
const Declaration = @import("DocumentDeclaration.zig");
const Initialization = @import("DocumentInitialization.zig");
const Evidence = @import("DocumentEvidence.zig");
const History = @import("LogHistory.zig");
const Log = @import("TransitLog.zig");
const pages = @import("TreeStore.zig").pages;

pub const magic = "DOCPART1";
const header_bytes = 40;
pub const max_bytes = 32768;

pub const RecoveryReference = struct {
    next_lsn: u64,
    content: d.Content,

    pub fn validate(self: RecoveryReference, current_next_lsn: u64) !void {
        try self.content.validate();
        if (self.next_lsn == 0 or self.next_lsn >= current_next_lsn) {
            return error.InvalidDocumentPartitionRecord;
        }
    }
};

pub const Root = struct {
    definition: p.Growth.Definition,
    initialization: Initialization.Request,
    declared: Declaration.Stored,
    next_lsn: u64,
    documents_root: ?pages.Reference,
    revisions_root: ?pages.Reference,
    replicas_root: ?pages.Reference,
    operations_root: ?pages.Reference,
    reads_root: ?pages.Reference,
    archive: ?History.Coverage = null,
    recovery: ?RecoveryReference = null,

    pub fn position(self: Root) d.Position {
        return .{ .partition = self.initialization.partition, .next_lsn = self.next_lsn };
    }

    pub fn validate(self: Root) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.initialization.validate();
        try self.declared.validate();
        if (self.next_lsn <= 1) return error.InvalidDocumentPartitionRecord;
        if (!std.meta.eql(
            self.initialization.declared.declaration.interpretation.object,
            self.declared.declaration.interpretation.object,
        )) {
            return error.DocumentPartitionConflict;
        }
        inline for (.{
            self.documents_root,
            self.revisions_root,
            self.replicas_root,
            self.operations_root,
            self.reads_root,
        }) |maybe_root| {
            if (maybe_root) |r| {
                if (std.mem.allEqual(u8, &r.digest, 0) or std.mem.allEqual(u8, &r.location, 0)) {
                    return error.InvalidDocumentPartitionRecord;
                }
            }
        }
        if (self.archive) |cov| {
            try cov.validate(self.next_lsn);
        }
        if (self.recovery) |rec| {
            try rec.validate(self.next_lsn);
        }
    }
};

pub const Action = union(enum) {
    mutation: doc.MutationReceipt,
    checkpoint: doc.CheckpointReceipt,
    read: doc.Read.Receipt,
    read_release: doc.Read.ReleaseReceipt,
    declaration: Declaration.Stored,
    archive: History.Coverage,
    recovery_checkpoint: RecoveryReference,
};

pub const Record = struct {
    definition: p.Growth.Definition,
    previous_commitment: [32]u8,
    root: Root,
    action: Action,
    evidence: ?d.Content,

    pub fn validate(self: Record) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        if (std.mem.allEqual(u8, &self.previous_commitment, 0)) {
            return error.InvalidDocumentPartitionRecord;
        }
        try self.root.validate();
        switch (self.action) {
            .mutation => |v| {
                try v.validate();
                if (self.evidence == null or
                    v.accepted.partition != self.root.initialization.partition or
                    v.accepted.next_lsn != self.root.next_lsn)
                {
                    return error.InvalidDocumentPartitionRecord;
                }
            },
            .checkpoint => |v| {
                try v.validate();
                if (self.evidence == null or
                    v.cut.accepted.partition != self.root.initialization.partition or
                    v.cut.accepted.next_lsn != self.root.next_lsn)
                {
                    return error.InvalidDocumentPartitionRecord;
                }
            },
            .read => |v| {
                try v.validate();
                if (self.evidence == null or
                    v.accepted.partition != self.root.initialization.partition or
                    v.accepted.next_lsn != self.root.next_lsn)
                {
                    return error.InvalidDocumentPartitionRecord;
                }
            },
            .read_release => |v| {
                try v.validate();
                if (self.evidence == null or
                    v.accepted.partition != self.root.initialization.partition or
                    v.accepted.next_lsn != self.root.next_lsn)
                {
                    return error.InvalidDocumentPartitionRecord;
                }
            },
            .declaration => |v| {
                try v.validate();
                if (self.evidence != null or !std.meta.eql(v, self.root.declared)) {
                    return error.InvalidDocumentPartitionRecord;
                }
            },
            .archive => |v| {
                try v.validate(self.root.next_lsn);
                if (self.evidence != null or self.root.archive == null or !std.meta.eql(v, self.root.archive.?)) {
                    return error.InvalidDocumentPartitionRecord;
                }
            },
            .recovery_checkpoint => |v| {
                try v.validate(self.root.next_lsn);
                if (self.evidence != null or self.root.recovery == null or !std.meta.eql(v, self.root.recovery.?)) {
                    return error.InvalidDocumentPartitionRecord;
                }
            },
        }
        if (self.evidence) |ev| try ev.validate();
    }
};

pub const Decoded = struct {
    record: Record,
    commitment: [32]u8,
};

pub fn encode(record: Record, output: *[max_bytes]u8) ![]const u8 {
    try record.validate();
    output[0..8].* = magic.*;
    output[8..40].* = p.Growth.definition_bytes;
    var writer: std.Io.Writer = .fixed(output[header_bytes..]);
    var encoder: std.json.Stringify = .{ .writer = &writer };
    try p.Json.write(record, &encoder);
    return output[0 .. header_bytes + writer.buffered().len];
}

pub fn decode(
    allocator: std.mem.Allocator,
    frame: Log.Frame,
    partition: u64,
    expected_lsn: u64,
) !Decoded {
    const bytes = frame.payload;
    if (bytes.len <= header_bytes or bytes.len > max_bytes or !std.mem.eql(u8, bytes[0..8], magic)) {
        return error.InvalidDocumentPartitionRecord;
    }
    if (!std.mem.eql(u8, bytes[8..40], &p.Growth.definition_bytes)) {
        return error.IncompatibleDefinition;
    }
    const parsed = try p.Json.parseFromSlice(Record, allocator, bytes[header_bytes..]);
    defer parsed.deinit();
    try parsed.value.validate();
    var canonical: [max_bytes]u8 = undefined;
    if (!std.mem.eql(u8, bytes, try encode(parsed.value, &canonical))) {
        return error.InvalidDocumentPartitionRecord;
    }
    const expected_kind: Log.FrameKind = switch (parsed.value.action) {
        .mutation => .row_delta,
        .checkpoint, .read, .read_release, .declaration, .archive, .recovery_checkpoint => .manifest_checkpoint,
    };
    if (frame.header.kind != expected_kind or
        frame.header.partition_id != partition or
        frame.header.lsn != expected_lsn or
        parsed.value.root.initialization.partition != partition or
        parsed.value.root.next_lsn != expected_lsn + 1 or
        frame.header.writer_epoch == 0 or
        frame.header.policy_epoch == 0)
    {
        return error.InvalidDocumentPartitionRecord;
    }
    return .{
        .record = parsed.value,
        .commitment = Evidence.hash(bytes),
    };
}
