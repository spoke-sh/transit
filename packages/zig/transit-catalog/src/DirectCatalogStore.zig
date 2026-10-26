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

/// Process-local evidence from this owner's validated immutable log prefix.
/// This value owns all its fields. It is not a persisted checkpoint, a caller
/// snapshot, or authorization to skip initial recovery after owner replacement.
pub const RecoveryState = struct { root: r.Root, chain: [32]u8 };

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
    try self.recoverSince(null);
}

pub fn recoveryState(self: *Self) !RecoveryState {
    try self.ready();
    return .{ .root = self.root, .chain = self.chain };
}

pub fn recoverSince(self: *Self, prior: ?RecoveryState) !void {
    self.recovery_required = true;
    self.index.clearCache();
    const end = try self.log.tail(self.root.configuration.partition);
    if (end < self.root.next_lsn) return error.CatalogHistoryMissing;
    var next = try r.Root.empty(self.root.configuration);
    var chain: [32]u8 = @splat(0);
    if (prior) |known| {
        try known.root.validate();
        if (!std.meta.eql(known.root.configuration, self.root.configuration)) return error.InvalidDirectCatalogHistory;
        if (known.root.next_lsn > end) return error.CatalogHistoryMissing;
        if (known.root.next_lsn == 0) {
            if (!std.meta.eql(known.root, next) or !std.mem.eql(u8, &known.chain, &chain)) return error.InvalidDirectCatalogHistory;
        } else {
            // Recheck the accepted boundary before trusting this same-owner
            // prefix. A shortened log or a substituted boundary must fail.
            var anchor = try self.log.read(self.allocator, known.root.configuration.partition, known.root.next_lsn - 1, 1);
            defer anchor.deinit();
            if (anchor.frames.len != 1) return error.CatalogHistoryMissing;
            const frame = anchor.frames[0];
            if (frame.header.partition_id != known.root.configuration.partition or frame.header.lsn != known.root.next_lsn - 1 or frame.header.kind != .catalog_ddl) return error.InvalidDirectCatalogHistory;
            const record = try decode(self.allocator, frame.payload, frame.header.lsn);
            if (!std.meta.eql(record.root, known.root) or !std.mem.eql(u8, &r.hash(frame.payload), &known.chain)) return error.InvalidDirectCatalogHistory;
        }
        next = known.root;
        chain = known.chain;
    }
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
    for ([_]?pages.Reference{ next.schemas, next.schema_names, next.namespace_claims, next.namespace_pending, next.objects, next.names, next.operations, next.pending, next.native_allocations, next.dependents, next.dependencies }) |slot| if (slot) |reference| {
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
    if (record.action != .resource and !std.meta.eql(before.native_allocations, record.root.native_allocations)) return error.InvalidDirectCatalogTransition;
    if (record.action == .dependency) return self.dependencyTransition(before, record);
    if (!std.meta.eql(before.dependents, record.root.dependents) or !std.meta.eql(before.dependencies, record.root.dependencies)) return error.InvalidDirectCatalogTransition;
    if (record.action == .resource) return self.resourceTransition(before, record);
    if (record.action == .namespace) return self.namespaceTransition(before, record);
    if (record.action == .assertion) {
        const outcome = record.action.assertion;
        if (try self.assertionAt(before, outcome.binding) != null) return error.InvalidDirectCatalogTransition;
        var unchanged = record.root;
        unchanged.operations = before.operations;
        unchanged.next_lsn = before.next_lsn;
        if (!std.meta.eql(unchanged, before)) return error.InvalidDirectCatalogTransition;
        const result = try self.tree().get(record.root.operations, try r.operationKey(outcome.binding.identity())) orelse return error.InvalidDirectCatalogTransition;
        if (result.len != 8 or std.mem.readInt(u64, result.data[0..8], .little) != before.next_lsn) return error.InvalidDirectCatalogTransition;
        return;
    }
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
        if (target.resource != null) return error.InvalidDirectCatalogTransition;
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

pub fn resourceRecord(self: *Self, at: u64) !c.DirectResource.Operation {
    try self.ready();
    return self.resourceRecordAt(self.root, at);
}
fn resourceRecordAt(self: *Self, basis: r.Root, at: u64) !c.DirectResource.Operation {
    if (at == 0 or at >= basis.next_lsn) return error.InvalidDirectCatalogOperation;
    var batch = try self.log.read(self.allocator, basis.configuration.partition, at, 1);
    defer batch.deinit();
    if (batch.frames.len != 1 or batch.frames[0].header.lsn != at or batch.frames[0].header.partition_id != basis.configuration.partition or batch.frames[0].header.kind != .catalog_ddl) return error.CatalogHistoryMissing;
    const record = try decode(self.allocator, batch.frames[0].payload, at);
    if (record.action != .resource) return error.DataIdentityConflict;
    if (!std.meta.eql(record.root.configuration, basis.configuration)) return error.InvalidDirectCatalogOperation;
    return record.action.resource;
}
pub fn resourceOperation(self: *Self, binding: c.DirectResource.Binding) !?c.DirectResource.Operation {
    try self.ready();
    return self.resourceAt(self.root, binding);
}
fn resourceAt(self: *Self, basis: r.Root, binding: c.DirectResource.Binding) !?c.DirectResource.Operation {
    try binding.validate();
    if (!binding.connection.matches(basis.configuration)) return error.DataIdentityConflict;
    const value = try self.tree().get(basis.operations, try r.operationKey(binding.identity())) orelse return null;
    if (value.len != 8) return error.InvalidDirectCatalogOperation;
    const outcome = try self.resourceRecordAt(basis, std.mem.readInt(u64, value.data[0..8], .little));
    try outcome.binding.requireSame(binding);
    return outcome;
}
fn resourceTransition(self: *Self, before: r.Root, record: r.Record) !void {
    const next = record.action.resource;
    const previous = try self.resourceAt(before, next.binding);
    if (previous) |known| {
        if (!known.pending() or next.phase == .admitted) return error.InvalidDirectCatalogTransition;
        if (next.phase == .allocated and (known.phase != .prepared or next.binding.action != .create)) return error.InvalidDirectCatalogTransition;
        if (next.phase == .prepared and (known.phase != .admitted or next.binding.action != .create)) return error.InvalidDirectCatalogTransition;
        if (known.allocation != null and !std.meta.eql(known.allocation, next.allocation)) return error.InvalidDirectCatalogTransition;
        if (next.phase == .complete and next.binding.action == .create and known.phase != .allocated) return error.InvalidDirectCatalogTransition;
        if (known.resulting != null and next.phase != .complete and !std.meta.eql(known.resulting, next.resulting)) return error.InvalidDirectCatalogTransition;
        if (next.phase == .complete) {
            if (next.binding.action == .create) {
                if (!std.meta.eql(known.resulting, next.resulting)) return error.InvalidDirectCatalogTransition;
            } else {
                var expected = known.resulting orelse return error.InvalidDirectCatalogTransition;
                expected.revision = try std.math.add(u64, expected.revision, 1);
                if (next.binding.action == .rename) expected.name = next.binding.action.rename;
                if (!std.meta.eql(expected, next.resulting.?)) return error.InvalidDirectCatalogTransition;
            }
        }
    } else if (next.phase != .admitted and next.phase != .rejected and next.phase != .cancelled) return error.InvalidDirectCatalogTransition;
    if (previous == null and next.phase == .admitted and next.binding.action != .create) {
        const key = try r.idKey(next.binding.object.object);
        const entry = try r.fromValue(r.Entry, self.allocator, try self.tree().get(before.objects, key) orelse return error.InvalidDirectCatalogTransition);
        const at = entry.resource orelse return error.InvalidDirectCatalogTransition;
        const current = try self.resourceRecordAt(before, at);
        if (current.phase != .complete or current.retired or !std.meta.eql(current.resulting, next.resulting) or !std.meta.eql(try current.resulting.?.interpretation(self.allocator), next.binding.expected.?)) return error.InvalidDirectCatalogTransition;
    }
    var unchanged = record.root;
    unchanged.next_lsn = before.next_lsn;
    unchanged.operations = before.operations;
    unchanged.pending = before.pending;
    unchanged.objects = before.objects;
    unchanged.names = before.names;
    unchanged.native_allocations = before.native_allocations;
    if (!std.meta.eql(unchanged, before)) return error.InvalidDirectCatalogTransition;
    const allocation_key = try r.principalKey(next.binding.connection.principal);
    const before_allocation = try self.tree().get(before.native_allocations, allocation_key);
    const after_allocation = try self.tree().get(record.root.native_allocations, allocation_key);
    if (next.phase == .prepared) {
        if (before_allocation != null or !std.meta.eql(after_allocation, @as(?pages.Value, try r.pageValue(next.binding.identity())))) return error.InvalidDirectCatalogTransition;
    } else if (previous != null and previous.?.phase == .prepared) {
        if (!std.meta.eql(before_allocation, @as(?pages.Value, try r.pageValue(next.binding.identity()))) or after_allocation != null) return error.InvalidDirectCatalogTransition;
    } else if (!std.meta.eql(record.root.native_allocations, before.native_allocations)) return error.InvalidDirectCatalogTransition;
    const receipt_value = try self.tree().get(record.root.operations, try r.operationKey(next.binding.identity())) orelse return error.InvalidDirectCatalogTransition;
    if (receipt_value.len != 8 or std.mem.readInt(u64, receipt_value.data[0..8], .little) != before.next_lsn) return error.InvalidDirectCatalogTransition;
    const id = try r.idKey(next.binding.object.object);
    const after_pending = try self.tree().get(record.root.pending, id);
    if (next.pending()) {
        const identity = try r.fromValue(p.DataLifecycle.Operation, self.allocator, after_pending orelse return error.InvalidDirectCatalogTransition);
        if (!std.meta.eql(identity, next.binding.identity())) return error.InvalidDirectCatalogTransition;
    } else if (previous != null) {
        if (after_pending != null) return error.InvalidDirectCatalogTransition;
    } else if (!std.meta.eql(after_pending, try self.tree().get(before.pending, id))) return error.InvalidDirectCatalogTransition;
    const updates_object = if (next.binding.action == .create) next.phase == .admitted or previous != null else next.phase == .complete;
    if (updates_object) {
        const target = try r.fromValue(r.Entry, self.allocator, try self.tree().get(record.root.objects, id) orelse return error.InvalidDirectCatalogTransition);
        const expected: r.Entry = .{ .object = next.binding.object.object, .partition = 0, .seed = null, .resource = before.next_lsn };
        if (!std.meta.eql(expected, target)) return error.InvalidDirectCatalogTransition;
        if (previous == null and try self.tree().get(before.objects, id) != null) return error.InvalidDirectCatalogTransition;
    } else if (!std.meta.eql(before.objects, record.root.objects)) return error.InvalidDirectCatalogTransition;
    if (next.phase == .admitted and next.binding.action != .drop) {
        const namespace = if (next.binding.action == .create) next.binding.action.create.namespace else next.resulting.?.namespace;
        const name = if (next.binding.action == .create) next.binding.action.create.name else next.binding.action.rename;
        const expected: r.Name = .{ .namespace = namespace, .name = name, .object = next.binding.object.object, .reservation = next.binding.identity() };
        const found = try r.fromValue(r.Name, self.allocator, try self.tree().get(record.root.names, try r.nameKey(namespace, name)) orelse return error.InvalidDirectCatalogTransition);
        if (!std.meta.eql(expected, found)) return error.InvalidDirectCatalogTransition;
    } else if (!std.meta.eql(before.names, record.root.names)) return error.InvalidDirectCatalogTransition;
}

pub fn namespaceOperation(self: *Self, binding: c.DirectNamespace.Binding) !?c.DirectNamespace.Operation {
    try self.ready();
    return self.namespaceAt(self.root, binding);
}

pub fn dependency(self: *Self, binding: c.DirectDependency.Binding) !?c.DirectDependency.Outcome {
    try self.ready();
    return self.dependencyAt(self.root, binding);
}
fn dependencyAt(self: *Self, basis: r.Root, binding: c.DirectDependency.Binding) !?c.DirectDependency.Outcome {
    try binding.validate();
    if (!binding.connection.matches(basis.configuration)) return error.DataIdentityConflict;
    const value = try self.tree().get(basis.operations, try r.operationKey(binding.identity())) orelse return null;
    if (value.len != 8) return error.InvalidDirectCatalogOperation;
    const at = std.mem.readInt(u64, value.data[0..8], .little);
    if (at >= basis.next_lsn) return error.InvalidDirectCatalogOperation;
    var batch = try self.log.read(self.allocator, basis.configuration.partition, at, 1);
    defer batch.deinit();
    if (batch.frames.len != 1 or batch.frames[0].header.lsn != at or batch.frames[0].header.partition_id != basis.configuration.partition or batch.frames[0].header.kind != .catalog_ddl) return error.CatalogHistoryMissing;
    const record = try decode(self.allocator, batch.frames[0].payload, at);
    if (record.action != .dependency) return error.DataIdentityConflict;
    if (!std.meta.eql(record.root.configuration, basis.configuration)) return error.InvalidDirectCatalogOperation;
    try record.action.dependency.binding.requireSame(binding);
    return record.action.dependency;
}
fn dependencyTransition(self: *Self, before: r.Root, record: r.Record) !void {
    const outcome = record.action.dependency;
    if (try self.dependencyAt(before, outcome.binding) != null) return error.InvalidDirectCatalogTransition;
    var unchanged = record.root;
    unchanged.operations = before.operations;
    unchanged.dependents = before.dependents;
    unchanged.dependencies = before.dependencies;
    unchanged.next_lsn = before.next_lsn;
    if (!std.meta.eql(unchanged, before)) return error.InvalidDirectCatalogTransition;
    const receipt_value = try self.tree().get(record.root.operations, try r.operationKey(outcome.binding.identity())) orelse return error.InvalidDirectCatalogTransition;
    if (receipt_value.len != 8 or std.mem.readInt(u64, receipt_value.data[0..8], .little) != before.next_lsn) return error.InvalidDirectCatalogTransition;
    const edge = outcome.binding.edge;
    const forward = try edge.forwardKey();
    const reverse = try edge.reverseKey();
    const previous = try self.tree().get(before.dependents, forward);
    if (!std.meta.eql(previous, try self.tree().get(before.dependencies, reverse))) return error.InvalidDirectCatalogTransition;
    if (previous) |value| {
        if (!std.meta.eql(edge, try r.fromValue(c.DirectDependency.Edge, self.allocator, value))) return error.DataIdentityConflict;
    }
    const should_change = outcome.phase == .applied and ((outcome.binding.action == .register) == (previous == null));
    if (outcome.changed != should_change) return error.InvalidDirectCatalogTransition;
    if (!outcome.changed) {
        if (!std.meta.eql(record.root.dependents, before.dependents) or !std.meta.eql(record.root.dependencies, before.dependencies)) return error.InvalidDirectCatalogTransition;
    }
    const expected: ?pages.Value = if (outcome.changed)
        (if (outcome.binding.action == .register) try r.pageValue(edge) else null)
    else
        previous;
    if (!std.meta.eql(expected, try self.tree().get(record.root.dependents, forward)) or
        !std.meta.eql(expected, try self.tree().get(record.root.dependencies, reverse))) return error.InvalidDirectCatalogTransition;
}
fn namespaceAt(self: *Self, basis: r.Root, binding: c.DirectNamespace.Binding) !?c.DirectNamespace.Operation {
    try binding.validate();
    if (!binding.connection.matches(basis.configuration)) return error.DataIdentityConflict;
    const value = try self.tree().get(basis.operations, try r.operationKey(binding.identity())) orelse return null;
    if (value.len != 8) return error.InvalidDirectCatalogOperation;
    const at = std.mem.readInt(u64, value.data[0..8], .little);
    if (at >= basis.next_lsn) return error.InvalidDirectCatalogOperation;
    var batch = try self.log.read(self.allocator, basis.configuration.partition, at, 1);
    defer batch.deinit();
    if (batch.frames.len != 1 or batch.frames[0].header.lsn != at or batch.frames[0].header.partition_id != basis.configuration.partition or batch.frames[0].header.kind != .catalog_ddl) return error.CatalogHistoryMissing;
    const record = try decode(self.allocator, batch.frames[0].payload, at);
    if (record.action != .namespace) return error.DataIdentityConflict;
    if (!std.meta.eql(record.root.configuration, basis.configuration)) return error.InvalidDirectCatalogOperation;
    try binding.requireSame(record.action.namespace.binding);
    return record.action.namespace;
}
fn namespaceTransition(self: *Self, before: r.Root, record: r.Record) !void {
    const next = record.action.namespace;
    const previous = try self.namespaceAt(before, next.binding);
    if (previous) |known| {
        if (known.phase != .admitted) return error.InvalidDirectCatalogTransition;
        if (next.phase == .admitted and (next.after == null or next.after.? <= (known.after orelse 0))) return error.InvalidDirectCatalogTransition;
    } else if (next.phase == .applied or next.after != null) return error.InvalidDirectCatalogTransition;
    var unchanged = record.root;
    unchanged.next_lsn = before.next_lsn;
    unchanged.schemas = before.schemas;
    unchanged.schema_names = before.schema_names;
    unchanged.namespace_claims = before.namespace_claims;
    unchanged.namespace_pending = before.namespace_pending;
    unchanged.operations = before.operations;
    if (!std.meta.eql(unchanged, before)) return error.InvalidDirectCatalogTransition;
    const recorded = try self.tree().get(record.root.operations, try r.operationKey(next.binding.identity())) orelse return error.InvalidDirectCatalogTransition;
    if (recorded.len != 8 or std.mem.readInt(u64, recorded.data[0..8], .little) != before.next_lsn) return error.InvalidDirectCatalogTransition;
    const id = try r.idKey(next.binding.namespace);
    const pending = try self.tree().get(record.root.namespace_pending, id);
    if (next.phase == .admitted) {
        const identity = try r.fromValue(p.DataLifecycle.Operation, self.allocator, pending orelse return error.InvalidDirectCatalogTransition);
        if (!std.meta.eql(identity, next.binding.identity())) return error.InvalidDirectCatalogTransition;
    } else if (previous != null) {
        if (pending != null) return error.InvalidDirectCatalogTransition;
    } else if (!std.meta.eql(pending, try self.tree().get(before.namespace_pending, id))) return error.InvalidDirectCatalogTransition;
    if (next.resulting) |result| {
        const found = try r.fromValue(c.TableAuthority.Schema, self.allocator, try self.tree().get(record.root.schemas, id) orelse return error.InvalidDirectCatalogTransition);
        if (!std.meta.eql(found, result)) return error.InvalidDirectCatalogTransition;
    } else if (!std.meta.eql(record.root.schemas, before.schemas)) return error.InvalidDirectCatalogTransition;
    if (next.binding.action == .create and (next.phase == .admitted or previous != null)) {
        const claimed = try r.fromValue(p.DataLifecycle.Operation, self.allocator, try self.tree().get(record.root.namespace_claims, id) orelse return error.InvalidDirectCatalogTransition);
        if (!std.meta.eql(claimed, next.binding.identity())) return error.InvalidDirectCatalogTransition;
    }
}

/// Adds the exact log position to the candidate's operation directory. Its
/// existence in staged pages does not make the operation admitted or terminal.
pub fn receipt(self: *Self, next: *r.Root, binding: p.DataLifecycle.Binding) !void {
    return self.receiptIdentity(next, binding.identity);
}
pub fn receiptIdentity(self: *Self, next: *r.Root, identity: p.DataLifecycle.Operation) !void {
    var bytes: [8]u8 = undefined;
    std.mem.writeInt(u64, &bytes, self.root.next_lsn, .little);
    next.operations = try self.tree().put(next.operations, try r.operationKey(identity), try pages.Value.init(&bytes));
}

pub fn assertion(self: *Self, binding: c.NameAssertion.Binding) !?c.NameAssertion.Outcome {
    try self.ready();
    return self.assertionAt(self.root, binding);
}
fn assertionAt(self: *Self, basis: r.Root, binding: c.NameAssertion.Binding) !?c.NameAssertion.Outcome {
    try binding.validate();
    if (!binding.connection.matches(basis.configuration)) return error.DataIdentityConflict;
    const value = try self.tree().get(basis.operations, try r.operationKey(binding.identity())) orelse return null;
    if (value.len != 8) return error.InvalidDirectCatalogOperation;
    const at = std.mem.readInt(u64, value.data[0..8], .little);
    if (at >= basis.next_lsn) return error.InvalidDirectCatalogOperation;
    var batch = try self.log.read(self.allocator, basis.configuration.partition, at, 1);
    defer batch.deinit();
    if (batch.frames.len != 1 or batch.frames[0].header.lsn != at or batch.frames[0].header.partition_id != basis.configuration.partition or batch.frames[0].header.kind != .catalog_ddl) return error.CatalogHistoryMissing;
    const record = try decode(self.allocator, batch.frames[0].payload, at);
    if (record.action != .assertion) return error.DataIdentityConflict;
    if (!std.meta.eql(record.root.configuration, basis.configuration)) return error.InvalidDirectCatalogOperation;
    try record.action.assertion.binding.requireSame(binding);
    return record.action.assertion;
}
