//! Compact original outcomes and operation controls. Only an accepted Table
//! index root publishes these objects; staging never accepts work. Evidence has
//! no row, archive, recovery or pin roots and cannot retain their object graphs.
const std = @import("std");
const p = @import("transit_protocol");
const d = p.DataLifecycle;
const r = @import("TablePartitionRecord.zig");
const Declaration = @import("TableDeclaration.zig");
const Objects = @import("TransitObjectStore.zig");
const pages = @import("TreeStore.zig").pages;
const header_bytes = 40;
pub const max_bytes = header_bytes + r.max_metadata_bytes;

pub const Accepted = struct {
    receipt: r.Receipt,
    resulting: Declaration.Stored,
    ingestion: enum { point, bulk, declaration },
};

pub const Record = struct {
    position: d.Position,
    evidence: union(enum) { receipt: Accepted, operation: r.Operation },

    pub fn binding(self: Record) d.Binding {
        return switch (self.evidence) {
            .receipt => |value| value.receipt.binding,
            .operation => |value| value.binding,
        };
    }

    pub fn validate(self: Record) !void {
        const owner = self.binding();
        if (owner.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try owner.validate();
        try self.position.validate();
        if (self.position.next_lsn == 0) return error.InvalidTableEvidence;
        switch (self.evidence) {
            .receipt => |value| {
                try value.resulting.validate();
                const outcome = value.receipt.outcome;
                if (value.receipt.transaction) |decision| {
                    try decision.validate();
                    if (decision.outcome != .committed or owner.action != .update or value.ingestion != .bulk or
                        !std.meta.eql(decision.attempt.operation, owner.identity) or
                        !std.mem.eql(u8, &decision.attempt.workspace.sha256, &owner.intent)) return error.InvalidTableEvidence;
                }
                if (!std.meta.eql(self.position, outcome.position) or outcome.affected > outcome.matched or
                    !std.meta.eql(owner.target, value.resulting.interpretation.object) or
                    value.resulting.retired != (owner.action == .drop)) return error.InvalidTableEvidence;
                switch (owner.action) {
                    .create => if (value.ingestion == .declaration or value.resulting.interpretation.revision != 1) return error.InvalidTableEvidence,
                    .insert, .update, .delete => if (value.ingestion == .declaration or
                        !std.meta.eql(owner.expected_definition.?, value.resulting.interpretation)) return error.InvalidTableEvidence,
                    .alter, .rename, .drop => if (value.ingestion != .declaration or
                        value.resulting.interpretation.revision != try std.math.add(u64, owner.expected_definition.?.revision, 1)) return error.InvalidTableEvidence,
                }
                if (owner.expected_data) |expected| if (expected.partition != self.position.partition or expected.next_lsn >= self.position.next_lsn) return error.InvalidTableEvidence;
            },
            .operation => |value| {
                try value.validate();
                if (value.basis.position.partition != self.position.partition or value.basis.position.next_lsn >= self.position.next_lsn) return error.InvalidTableEvidence;
            },
        }
    }

    pub fn fromAcceptance(record: r.Record) !Record {
        const result: Record = .{
            .position = .{ .partition = record.root.partition, .next_lsn = record.root.next_lsn },
            .evidence = switch (record.action) {
                .mutation => |value| .{ .receipt = .{ .receipt = try record.receipt(), .resulting = record.root.declared(), .ingestion = if (value.ingestion == .point) .point else .bulk } },
                .declaration => .{ .receipt = .{ .receipt = try record.receipt(), .resulting = record.root.declared(), .ingestion = .declaration } },
                .operation => |value| .{ .operation = value },
                else => return error.InvalidTableEvidence,
            },
        };
        try result.validate();
        return result;
    }
};

pub fn key(content: d.Content, output: *[96]u8) ![]const u8 {
    try validateContent(content);
    return std.fmt.bufPrint(output, "table-evidence/{x}.data", .{&content.sha256});
}

fn validateContent(content: d.Content) !void {
    try content.validate();
    if (content.bytes <= header_bytes or content.bytes > max_bytes) return error.InvalidTableEvidence;
}

pub fn reference(content: d.Content) !pages.Value {
    try validateContent(content);
    var bytes: [40]u8 = undefined;
    std.mem.writeInt(u64, bytes[0..8], content.bytes, .little);
    bytes[8..40].* = content.sha256;
    return pages.Value.init(&bytes);
}

pub fn decodeReference(value: pages.Value) !d.Content {
    if (value.len != 40) return error.InvalidTableEvidence;
    const result: d.Content = .{ .bytes = std.mem.readInt(u64, value.data[0..8], .little), .sha256 = value.data[8..40].* };
    try validateContent(result);
    return result;
}

pub fn encode(record: Record, output: []u8) ![]const u8 {
    try record.validate();
    if (output.len < header_bytes) return error.InvalidTableEvidence;
    output[0..8].* = "TEVID1\x00\x00".*;
    output[8..40].* = p.Growth.definition_bytes;
    var writer: std.Io.Writer = .fixed(output[header_bytes..@min(output.len, max_bytes)]);
    try std.json.Stringify.value(record, .{}, &writer);
    return output[0 .. header_bytes + writer.end];
}

pub fn decode(allocator: std.mem.Allocator, bytes: []const u8) !Record {
    if (bytes.len <= header_bytes or bytes.len > max_bytes or !std.mem.eql(u8, bytes[0..8], "TEVID1\x00\x00")) return error.InvalidTableEvidence;
    if (!std.mem.eql(u8, bytes[8..40], &p.Growth.definition_bytes)) return error.IncompatibleDefinition;
    const parsed = try std.json.parseFromSlice(Record, allocator, bytes[header_bytes..], .{});
    defer parsed.deinit();
    try parsed.value.validate();
    return parsed.value;
}

/// Used by recovery to bind the published index entry to its exact acceptance.
/// This hashes bounded metadata, without reading row payloads or another object.
pub fn expectedReference(record: Record) !pages.Value {
    var buffer: [max_bytes]u8 = undefined;
    const bytes = try encode(record, &buffer);
    return reference(.{ .bytes = bytes.len, .sha256 = r.hash(bytes) });
}

pub fn stage(objects: Objects.ObjectStore, record: Record) !pages.Value {
    var buffer: [max_bytes]u8 = undefined;
    const bytes = try encode(record, &buffer);
    const address: d.Content = .{ .bytes = bytes.len, .sha256 = r.hash(bytes) };
    var name: [96]u8 = undefined;
    const stored = try objects.putImmutable(try key(address, &name), bytes, address.sha256);
    if (stored.size != address.bytes or !std.mem.eql(u8, &stored.sha256, &address.sha256)) return error.InvalidTableEvidence;
    return reference(address);
}

pub fn stageInTree(tree: *@import("TreeStore.zig"), record: Record) !pages.Value {
    var buffer: [max_bytes]u8 = undefined;
    const bytes = try encode(record, &buffer);
    const address: d.Content = .{ .bytes = bytes.len, .sha256 = r.hash(bytes) };
    var name: [96]u8 = undefined;
    const stored = try tree.stageObject(try key(address, &name), bytes, address.sha256);
    if (stored.size != address.bytes or !std.mem.eql(u8, &stored.sha256, &address.sha256)) return error.InvalidTableEvidence;
    return reference(address);
}

pub fn load(allocator: std.mem.Allocator, objects: Objects.ObjectStore, value: pages.Value) !Record {
    const address = try decodeReference(value);
    var name: [96]u8 = undefined;
    const object_key = try key(address, &name);
    const metadata = try objects.head(object_key) orelse return error.TableEvidenceMissing;
    if (metadata.size != address.bytes or !std.mem.eql(u8, &metadata.sha256, &address.sha256)) return error.InvalidTableEvidence;
    const buffer = try allocator.alloc(u8, @intCast(address.bytes));
    defer allocator.free(buffer);
    const bytes = try objects.getRange(object_key, 0, @intCast(buffer.len), buffer);
    if (bytes.len != buffer.len or !std.mem.eql(u8, &r.hash(bytes), &address.sha256)) return error.InvalidTableEvidence;
    return decode(allocator, bytes);
}
