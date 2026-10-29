//! Immutable participant preparation. Only the Table WAL can accept its
//! reference; only the matching coordination decision can resolve its barrier.
const std = @import("std");
const p = @import("transit_protocol");
const d = p.DataLifecycle;
const x = p.Transaction;
const r = @import("TablePartitionRecord.zig");
const Objects = @import("TransitObjectStore.zig");
const Journal = @import("TransactionDecisionLog.zig");
pub const max_bytes = 64 * 1024;

pub const Reference = struct {
    content: d.Content,
    pub fn validate(self: Reference) !void {
        try self.content.validate();
        if (self.content.bytes <= 40 or self.content.bytes > max_bytes) return error.InvalidTransactionPreparation;
    }
};

pub const Record = struct {
    definition: p.Growth.Definition,
    coordination: u64,
    binding: Journal.Binding,
    guard: x.TableGuard,
    predecessor: r.Root,
    workspace: @import("TableWorkspace.zig").State,

    pub fn validate(self: Record) !void {
        try self.binding.validate();
        try self.guard.validate();
        try self.predecessor.validate();
        try self.workspace.validate();
        try self.binding.begin.requireSame(self.workspace.begin);
        try self.guard.requireUnchanged(tableGuard(self.predecessor));
        if (self.coordination == 0 or self.coordination == self.predecessor.partition or self.coordination == self.binding.begin.catalog.partition or
            self.predecessor.transaction != null or self.predecessor.retired or
            !std.meta.eql(self.predecessor.declared(), self.workspace.root.declared()) or
            self.predecessor.partition != self.workspace.root.partition or
            self.workspace.last_statement > self.binding.attempt.last_statement) return error.InvalidTransactionPreparation;
    }

    pub fn prepared(self: Record, reference: Reference) !x.Prepared {
        try self.validate();
        try reference.validate();
        return .{ .attempt = self.binding.attempt, .object = self.predecessor.interpretation.object, .predecessor = self.guard, .position = .{ .partition = self.predecessor.partition, .next_lsn = try std.math.add(u64, self.predecessor.next_lsn, 1) }, .successor = reference.content };
    }

    /// One aggregate Table acceptance belongs to the original commit operation.
    /// Private statement receipts remain owned by the transaction workspace.
    pub fn commitBinding(self: Record) d.Binding {
        return .{ .definition = p.Growth.current_definition, .identity = self.binding.attempt.operation, .target = self.predecessor.interpretation.object, .action = .update, .expected_definition = self.predecessor.interpretation, .expected_data = self.guard.source.accepted, .intent = self.binding.attempt.workspace.sha256 };
    }
};

pub fn tableGuard(root: r.Root) x.TableGuard {
    return .{ .source = .{ .interpretation = root.interpretation, .accepted = .{ .partition = root.partition, .next_lsn = root.next_lsn } }, .changed_lsn = root.changed_lsn };
}

pub fn key(reference: Reference, output: *[96]u8) ![]const u8 {
    try reference.validate();
    return std.fmt.bufPrint(output, "table-preparations/{x}.data", .{&reference.content.sha256});
}

fn encode(record: Record, output: *[max_bytes]u8) ![]const u8 {
    try record.validate();
    output[0..8].* = "TPREP1\x00\x00".*;
    output[8..40].* = p.Growth.definition_bytes;
    var writer: std.Io.Writer = .fixed(output[40..]);
    var encoder: std.json.Stringify = .{ .writer = &writer };
    try p.Json.write(record, &encoder);
    return output[0 .. 40 + writer.end];
}

pub fn stage(objects: Objects.ObjectStore, record: Record) !Reference {
    var buffer: [max_bytes]u8 = undefined;
    const bytes = try encode(record, &buffer);
    const reference: Reference = .{ .content = .{ .bytes = bytes.len, .sha256 = r.hash(bytes) } };
    var name: [96]u8 = undefined;
    const metadata = try objects.putImmutable(try key(reference, &name), bytes, reference.content.sha256);
    if (metadata.size != bytes.len or !std.mem.eql(u8, &metadata.sha256, &reference.content.sha256)) return error.InvalidTransactionPreparation;
    return reference;
}

pub fn load(allocator: std.mem.Allocator, objects: Objects.ObjectStore, reference: Reference) !Record {
    var name: [96]u8 = undefined;
    const path = try key(reference, &name);
    const metadata = try objects.head(path) orelse return error.TransactionPreparationMissing;
    if (metadata.size != reference.content.bytes or !std.mem.eql(u8, &metadata.sha256, &reference.content.sha256)) return error.InvalidTransactionPreparation;
    const bytes = try allocator.alloc(u8, @intCast(reference.content.bytes));
    defer allocator.free(bytes);
    const read = try objects.getRange(path, 0, @intCast(bytes.len), bytes);
    if (read.len != bytes.len or !std.mem.eql(u8, &r.hash(bytes), &reference.content.sha256) or !std.mem.eql(u8, bytes[0..8], "TPREP1\x00\x00")) return error.InvalidTransactionPreparation;
    if (!std.mem.eql(u8, bytes[8..40], &p.Growth.definition_bytes)) return error.IncompatibleDefinition;
    const parsed = try std.json.parseFromSlice(Record, allocator, bytes[40..], .{});
    defer parsed.deinit();
    var canonical: [max_bytes]u8 = undefined;
    if (!std.mem.eql(u8, bytes, try encode(parsed.value, &canonical))) return error.InvalidTransactionPreparation;
    return parsed.value;
}

/// Reopen the actual journal, never trust a supplied decision descriptor.
pub fn decision(allocator: std.mem.Allocator, log: @import("TransitLog.zig").Log, objects: Objects.ObjectStore, record: Record, reference: Reference) !?x.Decision {
    var journal = try Journal.init(allocator, log, objects, record.coordination, record.binding);
    try journal.recover();
    const result = journal.decision orelse return null;
    if (result.outcome == .committed) {
        var directory = try @import("TransactionDirectory.zig").init(allocator, objects, record.binding.begin.identity, .preparations, record.binding.begin.limits.participants, 1, 1024 * 1024);
        defer directory.deinit();
        try directory.restore(result.prepared);
        const entry = try directory.get(record.predecessor.interpretation.object.object) orelse return error.InvalidTransactionPreparation;
        if (!std.meta.eql(entry.prepared, try record.prepared(reference))) return error.InvalidTransactionPreparation;
    }
    return result;
}

/// Validate the immutable data graph before the common decision. This uses a
/// bounded page cache, fixed streaming hash buffer and ordered-key depth bound;
/// neither row count nor durable participant count is a resident array bound.
pub fn verifyWorkspace(allocator: std.mem.Allocator, index: *@import("TreeStore.zig"), log: @import("TransitLog.zig").Log, root: r.Root, archive: @import("TableArchive.zig").Coverage) !void {
    const Walk = @import("TableStorageWalk.zig");
    const context = try Walk.Context.fromRoot(root);
    const roots = [_]struct { reference: ?@import("TreeStore.zig").pages.Reference, kind: Walk.Kind }{
        .{ .reference = root.rows, .kind = .rows },
        .{ .reference = root.scan_rows, .kind = .scan_rows },
        .{ .reference = root.identities, .kind = .pages_only },
        .{ .reference = root.ordered_rows, .kind = .ordered_rows },
        .{ .reference = root.physical_schemas, .kind = .physical_schemas },
        .{ .reference = root.column_origins, .kind = .column_origins },
    };
    for (roots) |entry| if (entry.reference) |reference| try verifyDirectory(allocator, index, log, context, .{ .reference = reference, .kind = entry.kind }, archive);
}

fn verifyDirectory(allocator: std.mem.Allocator, index: *@import("TreeStore.zig"), log: @import("TransitLog.zig").Log, context: @import("TableStorageWalk.zig").Context, root: @import("TableStorageWalk.zig").Root, archive: @import("TableArchive.zig").Coverage) anyerror!void {
    const Walk = @import("TableStorageWalk.zig");
    var walk = try Walk.init(context, root);
    while (try walk.next(index)) |edge| switch (edge) {
        .page => {}, // Walk loaded and verified this immutable page.
        .index => |child| try verifyDirectory(allocator, index, log, context, child, archive),
        .declaration => |stored| {
            var declaration = try @import("TableDeclaration.zig").load(allocator, index.store, stored);
            declaration.deinit();
        },
        .wal => |position| {
            var batch = if (position.next_lsn - 1 < archive.through)
                try @import("TableArchive.zig").read(allocator, index, archive, position.partition, position.next_lsn - 1)
            else
                try log.read(allocator, position.partition, position.next_lsn - 1, 1);
            defer batch.deinit();
            if (batch.frames.len != 1) return error.TableHistoryMissing;
            _ = try r.decodeFrame(allocator, batch.frames[0], position.partition, position.next_lsn - 1);
        },
        .segment => |content| {
            var name: [96]u8 = undefined;
            const path = try std.fmt.bufPrint(&name, "table-segments/{x}.tseg", .{&content.sha256});
            const meta = try index.store.head(path) orelse return error.TableSegmentMissing;
            if (meta.size != content.bytes or !std.mem.eql(u8, &meta.sha256, &content.sha256)) return error.InvalidTransactionPreparation;
            try verifySegment(index.store, path, content);
        },
        else => return error.InvalidTransactionPreparation,
    };
}

fn verifySegment(objects: Objects.ObjectStore, path: []const u8, content: d.Content) !void {
    var buffer: [64 * 1024]u8 = undefined;
    var digest = std.crypto.hash.sha2.Sha256.init(.{});
    var offset: u64 = 0;
    while (offset < content.bytes) {
        const length: u32 = @intCast(@min(buffer.len, content.bytes - offset));
        const bytes = try objects.getRange(path, offset, length, &buffer);
        if (bytes.len != length) return error.InvalidTransactionPreparation;
        digest.update(bytes);
        offset += length;
    }
    if (!std.mem.eql(u8, &digest.finalResult(), &content.sha256)) return error.InvalidTransactionPreparation;
}
