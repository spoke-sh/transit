//! Bounded immutable catalog directories whose roots are accepted by one control
//! partition. The Table partition remains its data/definition visibility owner.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const s = c.storage;
const r = @import("DirectCatalogRecords.zig");
const pages = s.TreeStore.pages;
const Self = @This();
const header_bytes = 40;

allocator: std.mem.Allocator,
log: s.TransitLog.Log,
objects: s.TransitObjectStore.ObjectStore,
index: s.TreeStore,
root: r.Root,
chain: [32]u8 = @splat(0),
recovery_required: bool = true,
lose_reply: bool = false,

pub fn init(allocator: std.mem.Allocator, configuration: r.Configuration, log: s.TransitLog.Log, objects: s.TransitObjectStore.ObjectStore, resident_pages: usize) !Self {
    const root = try r.Root.empty(configuration);
    return .{ .allocator = allocator, .log = log, .objects = objects, .index = try s.TreeStore.init(allocator, objects, resident_pages), .root = root };
}

pub fn deinit(self: *Self) void {
    self.index.deinit();
    self.* = undefined;
}

pub fn tree(self: *Self) pages.Tree(s.TreeStore) {
    return .{ .store = &self.index };
}

pub fn ready(self: *Self) !void {
    if (self.recovery_required) return error.CatalogRecoveryRequired;
}

pub fn recover(self: *Self) !void {
    self.recovery_required = true;
    self.index.clearCache();
    const end = try self.log.tail(self.root.configuration.partition);
    if (end < self.root.next_lsn) return error.CatalogHistoryMissing;
    var next = try r.Root.empty(self.root.configuration);
    var chain: [32]u8 = @splat(0);
    while (next.next_lsn < end) {
        var batch = try self.log.read(self.allocator, next.configuration.partition, next.next_lsn, 1);
        defer batch.deinit();
        if (batch.frames.len != 1) return error.CatalogHistoryMissing;
        const frame = batch.frames[0];
        if (frame.header.partition_id != next.configuration.partition or frame.header.lsn != next.next_lsn or frame.header.kind != .catalog_ddl) return error.InvalidDirectCatalogHistory;
        const record = try decode(self.allocator, frame.payload, frame.header.lsn);
        try successor(next, record.root);
        try self.operationTransition(next, record);
        if (!std.mem.eql(u8, &record.previous, &chain)) return error.InvalidDirectCatalogHistory;
        next = record.root;
        chain = r.hash(frame.payload);
    }
    for ([_]?pages.Reference{ next.schemas, next.schema_names, next.objects, next.names, next.operations, next.pending }) |slot| if (slot) |reference| {
        _ = try self.index.load(reference);
    };
    self.root = next;
    self.chain = chain;
    self.recovery_required = false;
}

pub fn refresh(self: *Self) !void {
    try self.ready();
    if (try self.log.tail(self.root.configuration.partition) != self.root.next_lsn) try self.recover();
}

fn successor(before: r.Root, after: r.Root) !void {
    try after.validate();
    if (!std.meta.eql(before.configuration, after.configuration) or after.next_lsn != try std.math.add(u64, before.next_lsn, 1) or
        after.next_partition < before.next_partition) return error.InvalidDirectCatalogHistory;
}

fn encode(record: r.Record, output: []u8) ![]const u8 {
    if (output.len < header_bytes) return error.CatalogRecordTooLarge;
    output[0..8].* = "TCATLOG1".*;
    output[8..40].* = p.Growth.definition_bytes;
    var writer: std.Io.Writer = .fixed(output[header_bytes..]);
    try std.json.Stringify.value(record, .{}, &writer);
    return output[0 .. header_bytes + writer.end];
}

fn decode(allocator: std.mem.Allocator, bytes: []const u8, position: u64) !r.Record {
    if (bytes.len < header_bytes or bytes.len > r.max_record_bytes or !std.mem.eql(u8, bytes[0..8], "TCATLOG1")) return error.InvalidDirectCatalogHistory;
    if (!std.mem.eql(u8, bytes[8..40], &p.Growth.definition_bytes)) return error.IncompatibleDefinition;
    const parsed = try std.json.parseFromSlice(r.Record, allocator, bytes[header_bytes..], .{});
    defer parsed.deinit();
    try parsed.value.validate(position);
    return parsed.value;
}

/// Caller stages all directories and supplies the final current authorization
/// fence. An uncertain append cannot be classified as rejected without recovery.
pub fn publish(self: *Self, next: r.Root, action: @FieldType(r.Record, "action"), guard: s.TablePartition.Guard) !void {
    try self.ready();
    try successor(self.root, next);
    const record: r.Record = .{ .definition = p.Growth.current_definition, .previous = self.chain, .root = next, .action = action };
    try record.validate(self.root.next_lsn);
    try self.operationTransition(self.root, record);
    var bytes: [r.max_record_bytes]u8 = undefined;
    const encoded = try encode(record, &bytes);
    const chain = r.hash(encoded);
    const fence = try guard.acquire(guard.context);
    defer guard.release(guard.context);
    if (fence.writer_epoch == 0 or fence.policy_epoch == 0) return error.InvalidPartitionLease;
    _ = self.log.append(next.configuration.partition, self.root.next_lsn, fence.writer_epoch, fence.policy_epoch, .catalog_ddl, encoded) catch |err| {
        self.recovery_required = true;
        return err;
    };
    self.root = next;
    self.chain = chain;
    if (self.lose_reply) return error.LostAcknowledgement;
}

pub fn operation(self: *Self, binding: p.DataLifecycle.Binding) !?r.Operation {
    try self.ready();
    return self.operationAt(self.root, binding);
}

fn operationAt(self: *Self, basis: r.Root, binding: p.DataLifecycle.Binding) !?r.Operation {
    try binding.validate();
    if (!std.meta.eql(binding.identity.scope, basis.configuration.scope)) return error.DataIdentityConflict;
    const value = try self.tree().get(basis.operations, try r.operationKey(binding.identity)) orelse return null;
    if (value.len != 8) return error.InvalidDirectCatalogOperation;
    const at = std.mem.readInt(u64, value.data[0..8], .little);
    if (at >= basis.next_lsn) return error.InvalidDirectCatalogOperation;
    var batch = try self.log.read(self.allocator, basis.configuration.partition, at, 1);
    defer batch.deinit();
    if (batch.frames.len != 1 or batch.frames[0].header.lsn != at or batch.frames[0].header.partition_id != basis.configuration.partition or batch.frames[0].header.kind != .catalog_ddl) return error.CatalogHistoryMissing;
    const record = try decode(self.allocator, batch.frames[0].payload, at);
    if (record.action != .operation or !std.meta.eql(record.root.configuration, basis.configuration)) return error.InvalidDirectCatalogOperation;
    try record.action.operation.binding.requireSame(binding);
    return record.action.operation;
}

fn operationTransition(self: *Self, before: r.Root, record: r.Record) !void {
    if (record.action != .operation) return;
    const next = record.action.operation;
    const previous = try self.operationAt(before, next.binding);
    if (previous) |known| {
        if (!known.pending() or next.phase == .admitted or (next.phase == .ready and known.phase != .admitted) or !std.meta.eql(known.intent, next.intent)) return error.InvalidDirectCatalogTransition;
    } else if (next.phase != .admitted and next.phase != .rejected) return error.InvalidDirectCatalogTransition;
    const result = try self.tree().get(record.root.operations, try r.operationKey(next.binding.identity)) orelse return error.InvalidDirectCatalogTransition;
    if (result.len != 8 or std.mem.readInt(u64, result.data[0..8], .little) != before.next_lsn) return error.InvalidDirectCatalogTransition;
    const object_key = try r.idKey(next.binding.target.object);
    const after_pending = try self.tree().get(record.root.pending, object_key);
    if (next.pending()) {
        const pending_identity = try r.fromValue(p.DataLifecycle.Operation, self.allocator, after_pending orelse return error.InvalidDirectCatalogTransition);
        if (!std.meta.eql(pending_identity, next.binding.identity)) return error.InvalidDirectCatalogTransition;
        const value = try self.tree().get(record.root.objects, object_key) orelse return error.InvalidDirectCatalogTransition;
        const target = try r.fromValue(r.Entry, self.allocator, value);
        try target.validate(before.configuration);
        if (next.binding.action == .create) {
            if ((next.phase == .ready) != (target.seed != null)) return error.InvalidDirectCatalogTransition;
            if (next.phase == .ready) {
                const earlier = try self.tree().get(before.objects, object_key) orelse return error.InvalidDirectCatalogTransition;
                const allocated = try r.fromValue(r.Entry, self.allocator, earlier);
                if (allocated.seed != null or allocated.object != target.object or allocated.partition != target.partition) return error.InvalidDirectCatalogTransition;
            }
        }
    } else {
        const before_pending = try self.tree().get(before.pending, object_key);
        const owns = if (before_pending) |value| std.meta.eql(try r.fromValue(p.DataLifecycle.Operation, self.allocator, value), next.binding.identity) else false;
        if (owns) {
            if (after_pending != null) return error.InvalidDirectCatalogTransition;
        } else if (!std.meta.eql(before_pending, after_pending)) return error.InvalidDirectCatalogTransition;
    }
}

/// Adds the exact log position to the candidate's operation directory. Its
/// existence in staged pages does not make the operation admitted or terminal.
pub fn receipt(self: *Self, next: *r.Root, binding: p.DataLifecycle.Binding) !void {
    var bytes: [8]u8 = undefined;
    std.mem.writeInt(u64, &bytes, self.root.next_lsn, .little);
    next.operations = try self.tree().put(next.operations, try r.operationKey(binding.identity), try pages.Value.init(&bytes));
}
