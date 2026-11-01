//! Original log outcomes live in immutable bounded metadata objects. Only an
//! accepted partition index publishes them; private staging grants no authority.
const std = @import("std");
const p = @import("transit_protocol");
const d = p.DataLifecycle;
const q = p.StreamQueue;
const Declaration = @import("LogDeclaration.zig");
const Objects = @import("TransitObjectStore.zig");
const pages = @import("TreeStore.zig").pages;
pub const header_bytes = 40;
pub const max_bytes = 16 * 1024;

pub const Record = struct {
    declared: Declaration.Stored,
    outcome: union(enum) {
        append: q.AppendReceipt,
        assignment: q.GroupAssignmentReceipt,
        offset: struct { receipt: q.OffsetReceipt, cursor: p.StreamRead.Cursor },
        read: p.StreamRead.Receipt,
        release: p.StreamRead.ReleaseReceipt,
        claim: struct { receipt: q.ClaimReceipt, observed: @import("LogTime.zig").Sample },
        settlement: struct { receipt: q.SettlementReceipt, observed: @import("LogTime.zig").Sample },
        terminal: struct { receipt: p.Transaction.TerminalReceipt, observed: @import("LogTime.zig").Sample },
        queue_release: p.QueueRead.ReleaseReceipt,
    },

    pub fn operation(self: Record) d.Operation {
        return switch (self.outcome) {
            .append => |value| value.append.operation,
            .assignment => |value| value.assignment.operation,
            .offset => |value| value.receipt.commit.operation,
            .read => |value| value.request.operation,
            .release => |value| value.release.operation,
            .claim => |value| value.receipt.claim.operation,
            .settlement => |value| value.receipt.settlement.operation,
            .terminal => |value| value.receipt.transfer.operation,
            .queue_release => |value| value.release.operation,
        };
    }
    pub fn target(self: Record) q.Partition {
        return switch (self.outcome) {
            .append => |value| value.append.target,
            .assignment => |value| value.assignment.cut.target,
            .offset => |value| value.receipt.commit.coverage.cut.target,
            .read => |value| value.request.target,
            .release => |value| value.release.target,
            .claim => |value| value.receipt.claim.target,
            .settlement => |value| value.receipt.settlement.lease.target,
            .terminal => |value| value.receipt.transfer.target(),
            .queue_release => |value| value.release.claim.claim.target,
        };
    }
    pub fn accepted(self: Record) d.Position {
        return switch (self.outcome) {
            inline .offset, .claim, .settlement, .terminal => |value| value.receipt.accepted,
            inline else => |value| value.accepted,
        };
    }
    pub fn validate(self: Record) !void {
        try self.declared.validate();
        switch (self.outcome) {
            .offset => |value| {
                try value.receipt.validate();
                try value.cursor.validate();
                if (!std.meta.eql(value.receipt.commit.coverage, value.cursor.coverage) or value.receipt.commit.operation.principal != value.cursor.read.owner.principal) return error.InvalidLogEvidence;
            },
            .claim => |value| {
                try value.receipt.validate();
                try value.observed.validate();
                if (value.receipt.observed_ms != value.observed.latest_ms) return error.InvalidLogEvidence;
            },
            .settlement => |value| {
                try value.receipt.validate();
                try value.observed.validate();
                if (value.observed.latest_ms >= value.receipt.settlement.lease.expires_ms) return error.InvalidLogEvidence;
            },
            .terminal => |value| {
                try value.receipt.validate();
                try value.observed.validate();
                switch (value.receipt.transfer.source) {
                    .nack => |lease| if (value.observed.latest_ms >= lease.expires_ms) return error.InvalidLogEvidence,
                    .exhausted => |item| if (value.observed.earliest_ms < item.not_before_ms) return error.InvalidLogEvidence,
                }
            },
            inline else => |value| try value.validate(),
        }
        const selected = self.target();
        const control = self.outcome == .offset or self.outcome == .release or self.outcome == .settlement or self.outcome == .terminal or self.outcome == .queue_release;
        if (selected.partition >= self.declared.declaration.configuration.partitioning.count) return error.InvalidLogEvidence;
        if (control) {
            if (!std.meta.eql(selected.interpretation.object, self.declared.declaration.interpretation.object) or
                selected.interpretation.revision > self.declared.declaration.interpretation.revision or
                (selected.interpretation.revision == self.declared.declaration.interpretation.revision and !std.meta.eql(selected.interpretation, self.declared.declaration.interpretation))) return error.InvalidLogEvidence;
        } else if (self.declared.retired or !std.meta.eql(selected.interpretation, self.declared.declaration.interpretation)) return error.InvalidLogEvidence;
        const kind = std.meta.activeTag(self.declared.declaration.configuration.policy);
        switch (self.outcome) {
            .append => |value| if (!std.mem.eql(u8, @tagName(value.append.kind), @tagName(kind)) or
                value.append.rows > self.declared.declaration.limits.append_rows or value.append.payload.bytes > self.declared.declaration.limits.append_bytes or
                (self.declared.declaration.configuration.retention.max_age_ms != null and value.observed_ms == null)) return error.InvalidLogEvidence,
            .assignment, .offset, .read, .release => if (kind != .stream) return error.InvalidLogEvidence,
            .claim => |value| {
                if (kind != .queue or value.receipt.claim.maximum > self.declared.declaration.limits.claim_rows or
                    value.receipt.rows > self.declared.declaration.limits.active_leases or
                    value.receipt.expires_ms != try self.declared.declaration.configuration.policy.queue.deadline(value.observed.latest_ms, value.receipt.claim.lease_ms)) return error.InvalidLogEvidence;
            },
            .settlement, .terminal, .queue_release => if (kind != .queue) return error.InvalidLogEvidence,
        }
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
pub fn key(content: d.Content, output: *[96]u8) ![]const u8 {
    try validateContent(content);
    return std.fmt.bufPrint(output, "log-evidence/{x}.data", .{&content.sha256});
}
fn validateContent(content: d.Content) !void {
    try content.validate();
    if (content.bytes <= header_bytes or content.bytes > max_bytes) return error.InvalidLogEvidence;
}
pub fn reference(content: d.Content) !pages.Value {
    try validateContent(content);
    var bytes: [40]u8 = undefined;
    std.mem.writeInt(u64, bytes[0..8], content.bytes, .big);
    bytes[8..40].* = content.sha256;
    return pages.Value.init(&bytes);
}
pub fn decodeReference(value: pages.Value) !d.Content {
    if (value.len != 40) return error.InvalidLogEvidence;
    const content: d.Content = .{ .bytes = std.mem.readInt(u64, value.data[0..8], .big), .sha256 = value.data[8..40].* };
    try validateContent(content);
    return content;
}
pub fn encode(record: Record, output: []u8) ![]const u8 {
    try record.validate();
    if (output.len < header_bytes) return error.LogEvidenceTooLarge;
    output[0..8].* = "LOGEVID1".*;
    output[8..40].* = p.Growth.definition_bytes;
    var writer: std.Io.Writer = .fixed(output[header_bytes..@min(output.len, max_bytes)]);
    var encoder: std.json.Stringify = .{ .writer = &writer };
    try p.Json.write(record, &encoder);
    return output[0 .. header_bytes + writer.end];
}
pub fn expectedReference(record: Record) !pages.Value {
    var bytes: [max_bytes]u8 = undefined;
    const encoded = try encode(record, &bytes);
    return reference(.{ .bytes = encoded.len, .sha256 = hash(encoded) });
}
pub fn stage(objects: Objects.ObjectStore, record: Record) !pages.Value {
    var bytes: [max_bytes]u8 = undefined;
    const encoded = try encode(record, &bytes);
    const content: d.Content = .{ .bytes = encoded.len, .sha256 = hash(encoded) };
    var name: [96]u8 = undefined;
    const stored = try objects.putImmutable(try key(content, &name), encoded, content.sha256);
    if (stored.size != content.bytes or !std.mem.eql(u8, &stored.sha256, &content.sha256)) return error.InvalidLogEvidence;
    return reference(content);
}
pub fn load(allocator: std.mem.Allocator, objects: Objects.ObjectStore, value: pages.Value) !Record {
    const content = try decodeReference(value);
    var name: [96]u8 = undefined;
    const object_key = try key(content, &name);
    const metadata = try objects.head(object_key) orelse return error.LogEvidenceMissing;
    if (metadata.size != content.bytes or !std.mem.eql(u8, &metadata.sha256, &content.sha256)) return error.InvalidLogEvidence;
    var buffer: [max_bytes]u8 = undefined;
    const bytes = try objects.getRange(object_key, 0, @intCast(content.bytes), &buffer);
    if (bytes.len != content.bytes or !std.mem.eql(u8, &hash(bytes), &content.sha256) or !std.mem.eql(u8, bytes[0..8], "LOGEVID1")) return error.InvalidLogEvidence;
    if (!std.mem.eql(u8, bytes[8..40], &p.Growth.definition_bytes)) return error.IncompatibleDefinition;
    const parsed = try p.Json.parseFromSlice(Record, allocator, bytes[header_bytes..]);
    defer parsed.deinit();
    try parsed.value.validate();
    return parsed.value;
}
