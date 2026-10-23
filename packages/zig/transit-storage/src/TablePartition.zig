//! Single-owner Table acceptance and immutable row indexes. This owner is a
//! storage component: an adapter must provide current authorization and serialize
//! its use. No actor mailbox or native resource-block protocol carries row data.
const std = @import("std");
const p = @import("transit_protocol");
const d = p.DataLifecycle;
const f = @import("transit_fuze");
const Log = @import("TransitLog.zig");
const Objects = @import("TransitObjectStore.zig");
const TreeStore = @import("TreeStore.zig");
const pages = TreeStore.pages;
const r = @import("TablePartitionRecord.zig");
const Declaration = @import("TableDeclaration.zig");
const Snapshot = @import("TableSnapshot.zig");
const Self = @This();
pub const Root = r.Root;
pub const Outcome = r.Outcome;
pub const Evidence = struct {
    binding: d.Binding,
    resulting: Declaration.Stored,
    outcome: Outcome,
};
pub const max_changes = 1024;
pub const max_row_bytes = Log.max_payload_bytes - r.max_metadata_bytes - r.header_bytes;

/// The service acquires its authorization/retirement fence here and holds it
/// until release. This callback runs for observations and again after staging,
/// immediately before append. A lease supplied by a client is not a Guard.
pub const Guard = struct {
    context: *anyopaque,
    acquire: *const fn (*anyopaque) anyerror!Fence,
    release: *const fn (*anyopaque) void,
    pub const Fence = struct { writer_epoch: u64, policy_epoch: u64 };
};
pub const Options = struct { resident_pages: usize = 16, index_work_bytes: usize = 64 * 1024 * 1024, segment_cache_bytes: usize = f.TSeg.max_segment_bytes };
pub const Change = union(enum) {
    put: struct { row: f.TableRow.Row, expect: enum { absent, present, any } = .any },
    remove: []const u8,
};
pub const Ingestion = enum { point, bulk };
pub const SnapshotHandle = Snapshot.Handle;
pub const OwnedRow = union(enum) {
    wal: f.TableRow.Owned,
    segment: f.TSeg.OwnedRow,
    pub fn row(self: *const OwnedRow) f.TableRow.Row {
        return switch (self.*) {
            .wal => |*value| value.row(),
            .segment => |*value| value.row(),
        };
    }
    pub fn deinit(self: *OwnedRow) void {
        switch (self.*) {
            inline else => |*value| value.deinit(),
        }
    }
};

allocator: std.mem.Allocator,
log: Log.Log,
objects: Objects.ObjectStore,
index: TreeStore,
declaration: Declaration.Owned,
root: Root,
chain: [32]u8 = @splat(0),
options: Options,
segment_cache: ?CachedSegment = null,
segment_reads: u64 = 0,
row_groups_decoded: u64 = 0,
recovery_required: bool = true,
/// Failure injection at the durable append/reply boundary.
lose_reply: bool = false,

pub fn init(allocator: std.mem.Allocator, partition: u64, definition: Declaration.Definition, log: Log.Log, objects: Objects.ObjectStore, options: Options) !Self {
    try definition.validate();
    if (partition == 0 or options.index_work_bytes == 0) return error.InvalidTableIdentity;
    var owned = try Declaration.prepare(allocator, definition);
    errdefer owned.deinit();
    var index = try TreeStore.init(allocator, objects, options.resident_pages);
    errdefer index.deinit();
    return .{ .allocator = allocator, .log = log, .objects = objects, .index = index, .declaration = owned, .options = options, .root = emptyRoot(try owned.stored(), partition) };
}

fn emptyRoot(stored: Declaration.Stored, partition: u64) Root {
    return .{ .interpretation = stored.interpretation, .declaration = stored.content, .schema_fingerprint = stored.schema_fingerprint, .retired = stored.retired, .next_segment = 1, .partition = partition };
}

fn requireTransition(before: Root, record: r.Record) !void {
    const after = record.root;
    switch (record.action) {
        inline .mutation, .declaration => |value| {
            const binding = value.binding;
            if (!std.meta.eql(before.pins, after.pins)) return error.InvalidTableHistory;
            if (record.action == .mutation and after.changed_lsn != (if (value.outcome.affected != 0 or binding.action == .create) after.next_lsn else before.changed_lsn)) return error.InvalidTableHistory;
            if (before.next_lsn == 0) {
                if (record.action != .mutation or binding.action != .create or after.interpretation.revision != 1 or after.retired) return error.InvalidTableHistory;
            } else {
                if (before.retired or !std.meta.eql(binding.expected_definition, @as(?d.Definition, before.interpretation))) return error.InvalidTableHistory;
                if (record.action == .mutation) {
                    if (binding.action != .insert and binding.action != .update and binding.action != .delete) return error.InvalidTableHistory;
                    if (!std.meta.eql(before.declared(), after.declared())) return error.InvalidTableHistory;
                } else {
                    if (binding.action != .alter and binding.action != .rename and binding.action != .drop) return error.InvalidTableHistory;
                    if (after.interpretation.revision != try std.math.add(u64, before.interpretation.revision, 1) or after.retired != (binding.action == .drop) or after.live_rows != before.live_rows) return error.InvalidTableHistory;
                    if (binding.action != .alter and (!std.mem.eql(u8, &before.schema_fingerprint, &after.schema_fingerprint) or
                        !std.meta.eql(before.rows, after.rows) or !std.meta.eql(before.scan_rows, after.scan_rows) or before.next_segment != after.next_segment)) return error.InvalidTableHistory;
                }
            }
            if (binding.expected_data) |expected| if (expected.partition != before.partition or expected.next_lsn != before.next_lsn) return error.InvalidTableHistory;
        },
        else => {
            if (before.next_lsn == 0 or !std.meta.eql(before.declared(), after.declared()) or before.changed_lsn != after.changed_lsn or
                before.live_rows != after.live_rows or !std.meta.eql(before.receipts, after.receipts)) return error.InvalidTableHistory;
            if (record.action != .checkpoint and (!std.meta.eql(before.rows, after.rows) or !std.meta.eql(before.scan_rows, after.scan_rows) or before.next_segment != after.next_segment)) return error.InvalidTableHistory;
            if (record.action == .checkpoint and !std.meta.eql(before.pins, after.pins)) return error.InvalidTableHistory;
            if (before.retired and record.action != .release) return error.InvalidTableHistory;
        },
    }
}

pub fn deinit(self: *Self) void {
    if (self.segment_cache) |*cached| cached.deinit(self.allocator);
    self.index.deinit();
    self.declaration.deinit();
    self.* = undefined;
}

fn tree(self: *Self) pages.Tree(TreeStore) {
    return .{ .store = &self.index };
}

/// Replay uses one bounded frame at a time, retaining only the latest roots.
/// This profile retains its complete WAL; no trim authority is exposed here.
pub fn recover(self: *Self) !void {
    self.recovery_required = true;
    self.index.clearCache();
    if (self.segment_cache) |*cached| cached.deinit(self.allocator);
    self.segment_cache = null;
    const end = try self.log.tail(self.root.partition);
    if (end < self.root.next_lsn) return error.TableHistoryMissing;
    var next = emptyRoot(try self.declaration.stored(), self.root.partition);
    var chain: [32]u8 = @splat(0);
    while (next.next_lsn < end) {
        var batch = try self.log.read(self.allocator, next.partition, next.next_lsn, 1);
        defer batch.deinit();
        if (batch.frames.len != 1) return error.TableHistoryMissing;
        const frame = batch.frames[0];
        if (frame.header.lsn != next.next_lsn or frame.header.partition_id != next.partition or
            (frame.header.kind != .row_delta and frame.header.kind != .manifest_checkpoint)) return error.InvalidTableHistory;
        const decoded = try r.decode(self.allocator, frame.payload, frame.header.lsn);
        const record = decoded.record;
        if (!std.mem.eql(u8, &record.previous, &chain) or
            !std.meta.eql(record.root.interpretation.object, next.interpretation.object) or record.root.partition != next.partition or
            record.root.changed_lsn < next.changed_lsn or record.root.next_segment < next.next_segment) return error.InvalidTableHistory;
        if ((record.action == .mutation) != (frame.header.kind == .row_delta)) return error.InvalidTableHistory;
        if (record.action != .mutation and decoded.rows.len != 0) return error.InvalidTableHistory;
        try requireTransition(next, record);
        chain = r.hash(frame.payload);
        next = record.root;
    }
    // Verify all top-level roots before exposing the recovered state. Descendant
    // pages and row objects remain checked on access, never substituted by empty.
    for ([_]?pages.Reference{ next.rows, next.scan_rows, next.receipts, next.pins }) |reference| if (reference) |ref| {
        _ = try self.index.load(ref);
    };
    if (end != 0) {
        const declaration = try Declaration.load(self.allocator, self.objects, next.declared());
        self.declaration.deinit();
        self.declaration = declaration;
    }
    self.root = next;
    self.chain = chain;
    self.recovery_required = false;
}

fn ready(self: *Self) !void {
    if (self.recovery_required) return error.TableRecoveryRequired;
}

fn scope(self: *Self, operation: d.Operation) !void {
    try operation.validate();
    if (!std.meta.eql(operation.scope, self.root.interpretation.object.scope)) return error.DataIdentityConflict;
}

fn observed(self: *Self, binding: d.Binding) !?r.Record {
    try binding.validate();
    try self.scope(binding.identity);
    const value = try self.tree().get(self.root.receipts, try r.operationKey(binding.identity)) orelse return null;
    if (value.len != 8) return error.InvalidTableReceipt;
    const at = std.mem.readInt(u64, value.data[0..8], .little);
    if (at >= self.root.next_lsn) return error.InvalidTableReceipt;
    var batch = try self.log.read(self.allocator, self.root.partition, at, 1);
    defer batch.deinit();
    if (batch.frames.len != 1 or batch.frames[0].header.lsn != at) return error.TableHistoryMissing;
    const record = (try r.decode(self.allocator, batch.frames[0].payload, at)).record;
    try (try record.receipt()).binding.requireSame(binding);
    return record;
}

pub fn observe(self: *Self, binding: d.Binding, guard: Guard) !?Outcome {
    const evidence = try self.observeEvidence(binding, guard) orelse return null;
    return evidence.outcome;
}

/// Returns the original resulting definition, even after later DDL. A catalog
/// must not substitute the current head when finishing an earlier operation.
pub fn observeEvidence(self: *Self, binding: d.Binding, guard: Guard) !?Evidence {
    try self.ready();
    _ = try guard.acquire(guard.context);
    defer guard.release(guard.context);
    const record = try self.observed(binding) orelse return null;
    const receipt = try record.receipt();
    return .{ .binding = receipt.binding, .resulting = record.root.declared(), .outcome = receipt.outcome };
}

fn expectations(self: *Self, binding: d.Binding) !void {
    try binding.validate();
    if (self.root.retired) return error.TableRetired;
    if (self.root.next_lsn == 0 and binding.action != .create) return error.TableNotCreated;
    if (!std.meta.eql(binding.target, self.root.interpretation.object)) return error.DataIdentityConflict;
    if (binding.expected_definition) |expected| {
        if (!std.meta.eql(expected, self.root.interpretation)) return error.TableDefinitionChanged;
    } else if (self.root.next_lsn != 0 or binding.action != .create) return error.TableAlreadyExists;
    if (binding.action == .create and self.root.interpretation.revision != 1) return error.InvalidDataDefinition;
    if (binding.expected_data) |expected| {
        if (expected.partition != self.root.partition or expected.next_lsn != self.root.next_lsn) return error.TableDataChanged;
    }
}

/// The adapter lowers an exact frozen intent to these concrete changes. Retry
/// equality checks both that binding and the complete ordered mutation bytes.
pub fn apply(self: *Self, binding: d.Binding, changes: []const Change, ingestion: Ingestion, guard: Guard) !Outcome {
    try self.ready();
    if (changes.len > max_changes) return error.TableBatchTooLarge;
    if (binding.action != .create and binding.action != .insert and binding.action != .update and binding.action != .delete) return error.UnsupportedTableAction;
    var accepted: ?r.Record = null;
    {
        _ = try guard.acquire(guard.context);
        defer guard.release(guard.context);
        accepted = try self.observed(binding);
        if (accepted == null) try self.expectations(binding);
    }
    var original: ?Declaration.Owned = null;
    defer if (original) |*value| value.deinit();
    if (accepted) |record| original = try Declaration.load(self.allocator, self.objects, record.root.declared());
    const schema = if (original) |value| value.schema.schema else self.declaration.schema.schema;
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const bytes = try a.alloc(u8, max_row_bytes);
    var rows: std.Io.Writer = .fixed(bytes);
    const keys = try a.alloc([]const u8, changes.len);
    const locators = try a.alloc(r.Locator, changes.len);
    var digest = std.crypto.hash.sha2.Sha256.init(.{});
    digest.update("transit.table.changes.v1\x00");
    for (changes, 0..) |change, i| {
        var key_bytes: [f.Collation.max_sort_key_bytes]u8 = undefined;
        const key = switch (change) {
            .put => |value| try value.row.storageKey(schema, &key_bytes),
            .remove => |value| value,
        };
        if (key.len == 0 or key.len > f.Collation.max_sort_key_bytes) return error.InvalidTableKey;
        keys[i] = try a.dupe(u8, key);
        for (keys[0..i]) |previous| {
            if (std.mem.eql(u8, previous, key)) return error.DuplicateBatchKey;
            if (std.mem.eql(u8, &r.hash(previous), &r.hash(key))) return error.TableKeyHashCollision;
        }
        const tag: [1]u8 = .{switch (change) {
            .put => |value| @as(u8, @backingInt(value.expect)) + 1,
            .remove => 0,
        }};
        digest.update(&tag);
        var length: [8]u8 = undefined;
        std.mem.writeInt(u64, &length, key.len, .little);
        digest.update(&length);
        digest.update(key);
        switch (change) {
            .put => |value| {
                const offset = rows.end;
                const encoded = try value.row.encode(schema, bytes[offset..]);
                rows.end += encoded.len;
                std.mem.writeInt(u64, &length, encoded.len, .little);
                digest.update(&length);
                digest.update(encoded);
                locators[i] = .{ .kind = .wal, .lsn = self.root.next_lsn, .offset = @intCast(offset), .length = @intCast(encoded.len), .digest = r.hash(encoded) };
            },
            .remove => {},
        }
    }
    const changes_digest = digest.finalResult();
    if (accepted) |record| {
        _ = try guard.acquire(guard.context);
        defer guard.release(guard.context);
        const receipt = try record.receipt();
        if (!std.mem.eql(u8, &changes_digest, &receipt.changes)) return error.DataIdentityConflict;
        return receipt.outcome;
    }
    try self.index.begin(self.options.index_work_bytes);
    defer self.index.end();
    var next = self.root;
    next.next_lsn = try std.math.add(u64, next.next_lsn, 1);
    var affected: u64 = 0;
    // Validate every row/key constraint against the accepted root before staging.
    for (changes, keys) |change, key| {
        var existing = try self.getAt(self.allocator, self.root, key);
        defer if (existing) |*row| row.deinit();
        switch (change) {
            .put => |value| {
                if (value.expect == .absent and existing != null) return error.DuplicatePrimaryKey;
                if (value.expect == .present and existing == null) return error.TableRowMissing;
                if (existing == null) next.live_rows = try std.math.add(u64, next.live_rows, 1);
                affected += 1;
            },
            .remove => if (existing != null) {
                next.live_rows -= 1;
                affected += 1;
            },
        }
    }
    if (ingestion == .bulk) {
        var bulk: std.ArrayList(f.TableRow.Row) = .empty;
        for (changes) |change| if (change == .put) try bulk.append(a, change.put.row);
        if (bulk.items.len != 0) {
            const segment = try self.stageSegment(a, schema, next.next_segment, bulk.items);
            next.next_segment = try std.math.add(u64, next.next_segment, 1);
            for (changes, keys, 0..) |change, key, i| if (change == .put) {
                const entry = segment.footer.findPrimaryKeySortKey(key) orelse return error.InvalidSegmentIndex;
                locators[i] = .{ .kind = .segment, .lsn = segment.footer.segment_id, .offset = entry.global_row_offset, .length = @intCast(segment.content.bytes), .digest = segment.content.sha256 };
            };
        }
    }
    for (changes, keys, 0..) |change, key, i| {
        const index_key = try r.rowKey(key);
        if (try self.tree().get(next.rows, index_key)) |value| {
            next.scan_rows = try self.tree().remove(next.scan_rows, try (try r.Locator.decode(value)).scanKey());
        }
        next.rows = switch (change) {
            .put => try self.tree().put(next.rows, index_key, try locators[i].encode()),
            .remove => try self.tree().remove(next.rows, index_key),
        };
        if (change == .put) next.scan_rows = try self.tree().put(next.scan_rows, try locators[i].scanKey(), try locators[i].scanValue(index_key));
    }
    var receipt: [8]u8 = undefined;
    std.mem.writeInt(u64, &receipt, self.root.next_lsn, .little);
    next.receipts = try self.tree().put(next.receipts, try r.operationKey(binding.identity), try pages.Value.init(&receipt));
    if (affected != 0 or binding.action == .create) next.changed_lsn = next.next_lsn;
    const outcome: Outcome = .{ .position = .{ .partition = next.partition, .next_lsn = next.next_lsn }, .affected = affected, .live_rows = next.live_rows };
    const record: r.Record = .{ .definition = p.Growth.current_definition, .previous = self.chain, .root = next, .action = .{ .mutation = .{
        .binding = binding,
        .changes = changes_digest,
        .outcome = outcome,
        .ingestion = if (ingestion == .point) .point else .bulk,
    } } };
    try self.publish(record, if (ingestion == .point) rows.buffered() else &.{}, guard);
    try self.reply();
    return outcome;
}

pub const Edit = union(enum) {
    rename: []const u8,
    alter: struct { change: f.TableEvolution.Change, properties: []const u8 },
    drop: []const u8,
};

/// The catalog validates names, dependencies and its canonical properties before
/// calling this owner. All rewritten rows and the resulting definition become
/// visible at one Table log append. No independently writable manifest exists.
pub fn changeDefinition(self: *Self, binding: d.Binding, edit: Edit, guard: Guard) !Outcome {
    try self.ready();
    const action: d.Action = switch (edit) {
        .rename => .rename,
        .alter => .alter,
        .drop => .drop,
    };
    if (binding.action != action) return error.UnsupportedTableAction;
    const properties = switch (edit) {
        .alter => |value| value.properties,
        inline else => |value| value,
    };
    if (properties.len > Declaration.max_properties_bytes) return error.InvalidTableDeclaration;
    var accepted: ?r.Record = null;
    {
        _ = try guard.acquire(guard.context);
        defer guard.release(guard.context);
        accepted = try self.observed(binding);
        if (accepted == null) try self.expectations(binding);
    }
    const intent = try self.allocator.alloc(u8, Log.max_payload_bytes);
    defer self.allocator.free(intent);
    var writer: std.Io.Writer = .fixed(intent);
    try std.json.Stringify.value(edit, .{}, &writer);
    const digest = r.hash(writer.buffered());
    if (accepted) |record| {
        _ = try guard.acquire(guard.context);
        defer guard.release(guard.context);
        const receipt = try record.receipt();
        if (!std.mem.eql(u8, &digest, &receipt.changes)) return error.DataIdentityConflict;
        return receipt.outcome;
    }
    var columns: [f.TableSchema.max_columns]f.TableSchema.Column = undefined;
    var transition: ?f.TableEvolution.Transition = if (edit == .alter) try f.TableEvolution.apply(self.declaration.schema.schema, edit.alter.change, &columns) else null;
    var replacement = try Declaration.prepare(self.allocator, .{
        .object = self.root.interpretation.object,
        .revision = try std.math.add(u64, self.root.interpretation.revision, 1),
        .schema = if (transition) |value| value.after else self.declaration.schema.schema,
        .properties = properties,
        .retired = edit == .drop,
    });
    var moved = false;
    defer if (!moved) replacement.deinit();
    const stored = try Declaration.stage(self.objects, &replacement);
    var next = self.root;
    next.interpretation = stored.interpretation;
    next.declaration = stored.content;
    next.schema_fingerprint = stored.schema_fingerprint;
    next.retired = stored.retired;
    next.next_lsn = try std.math.add(u64, next.next_lsn, 1);
    next.changed_lsn = next.next_lsn;
    try self.index.begin(self.options.index_work_bytes);
    defer self.index.end();
    if (transition) |*value| {
        value.after = replacement.schema.schema;
        try self.rewrite(&next, value.*);
    }
    var receipt: [8]u8 = undefined;
    std.mem.writeInt(u64, &receipt, self.root.next_lsn, .little);
    next.receipts = try self.tree().put(next.receipts, try r.operationKey(binding.identity), try pages.Value.init(&receipt));
    const outcome: Outcome = .{ .position = .{ .partition = next.partition, .next_lsn = next.next_lsn }, .affected = 0, .live_rows = next.live_rows };
    try self.publish(.{ .definition = p.Growth.current_definition, .previous = self.chain, .root = next, .action = .{ .declaration = .{ .binding = binding, .changes = digest, .outcome = outcome } } }, &.{}, guard);
    // Both allocations were prepared before acceptance. Even a lost reply leaves
    // this live owner using exactly the schema selected by its accepted root.
    self.declaration.deinit();
    self.declaration = replacement;
    moved = true;
    try self.reply();
    return outcome;
}

fn rewrite(self: *Self, next: *Root, transition: f.TableEvolution.Transition) !void {
    next.rows = null;
    next.scan_rows = null;
    var cursor: ?pages.Key = null;
    var done = false;
    var count: u64 = 0;
    const encoded = try self.allocator.alloc(u8, max_row_bytes);
    defer self.allocator.free(encoded);
    while (!done) {
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();
        const a = arena.allocator();
        var rows: std.ArrayList(f.TableRow.Row) = .empty;
        var bytes: usize = 0;
        group: while (rows.items.len < max_changes) {
            const batch = try self.scan(self.root, cursor);
            for (batch.entries) |slot| if (slot) |entry| {
                const old = try self.readRow(a, self.root, entry.key, entry.value);
                const cells = try a.alloc(f.Types.Values.Cell, transition.after.columns.len);
                const row: f.TableRow.Row = .{ .identity = old.row().identity, .cells = try transition.row(old.row().cells, cells) };
                const length = (try row.encode(transition.after, encoded)).len;
                if (length > max_row_bytes - bytes or rows.items.len == max_changes) break :group;
                try rows.append(a, row);
                bytes += length;
                cursor = try (try r.Locator.decode(entry.value)).scanKey();
            };
            if (batch.next == null) {
                done = true;
                break;
            }
        }
        if (rows.items.len == 0) {
            if (!done) return error.TableBatchTooLarge;
            break;
        }
        const segment = try self.stageSegment(a, transition.after, next.next_segment, rows.items);
        next.next_segment = try std.math.add(u64, next.next_segment, 1);
        for (segment.footer.pk_index) |entry| {
            const index_key = try r.rowKey(entry.pk_sort_key);
            // Includes collisions across different bounded rewrite groups. A
            // hash collision rejects conservatively; it never merges two rows.
            if (try self.tree().get(next.rows, index_key) != null) return error.DuplicatePrimaryKey;
            const locator: r.Locator = .{ .kind = .segment, .lsn = segment.footer.segment_id, .offset = entry.global_row_offset, .length = @intCast(segment.content.bytes), .digest = segment.content.sha256 };
            next.rows = try self.tree().put(next.rows, index_key, try locator.encode());
            next.scan_rows = try self.tree().put(next.scan_rows, try locator.scanKey(), try locator.scanValue(index_key));
            count = try std.math.add(u64, count, 1);
        }
    }
    if (count != self.root.live_rows) return error.InvalidTableHistory;
}

fn publish(self: *Self, record: r.Record, row_bytes: []const u8, guard: Guard) !void {
    try record.validate(self.root.next_lsn);
    try requireTransition(self.root, record);
    if (self.root.next_lsn == 0) _ = try Declaration.stage(self.objects, &self.declaration);
    const buffer = try self.allocator.alloc(u8, Log.max_payload_bytes);
    defer self.allocator.free(buffer);
    const payload = try r.encode(record, row_bytes, buffer);
    const chain = r.hash(payload);
    const fence = try guard.acquire(guard.context);
    defer guard.release(guard.context);
    if (fence.writer_epoch == 0 or fence.policy_epoch == 0) return error.InvalidPartitionLease;
    _ = self.log.append(self.root.partition, self.root.next_lsn, fence.writer_epoch, fence.policy_epoch, if (record.action == .mutation) .row_delta else .manifest_checkpoint, payload) catch |err| {
        self.recovery_required = true;
        return err;
    };
    // No fallible allocation or publication remains after the acceptance record.
    self.root = record.root;
    self.chain = chain;
}

fn reply(self: *Self) !void {
    if (self.lose_reply) return error.LostAcknowledgement;
}

pub fn get(self: *Self, allocator: std.mem.Allocator, key: []const u8, guard: Guard) !?OwnedRow {
    try self.ready();
    _ = try guard.acquire(guard.context);
    defer guard.release(guard.context);
    if (self.root.retired) return error.TableRetired;
    return self.getAt(allocator, self.root, key);
}

/// Exact frozen roots are internal read bases; the public adapter must acquire
/// and verify a retained pin before allowing a basis to outlive its request.
pub fn getAt(self: *Self, allocator: std.mem.Allocator, basis: Root, key: []const u8) !?OwnedRow {
    try self.ready();
    try self.requireBasis(basis);
    const value = try self.tree().get(basis.rows, try r.rowKey(key)) orelse return null;
    var row = try self.readRow(allocator, basis, try r.rowKey(key), value);
    errdefer row.deinit();
    var actual: [f.Collation.max_sort_key_bytes]u8 = undefined;
    if (!std.mem.eql(u8, key, try row.row().storageKey(self.declaration.schema.schema, &actual))) return error.TableKeyHashCollision;
    return row;
}

fn requireBasis(self: *Self, basis: Root) !void {
    try basis.validate();
    if (!std.meta.eql(basis.interpretation.object, self.root.interpretation.object) or basis.partition != self.root.partition or
        basis.next_lsn > self.root.next_lsn) return error.InvalidTableBasis;
}

/// The opaque cursor follows physical WAL/segment order for locality. SQL
/// ordering belongs to its plan, never to this directory's traversal order.
pub fn scan(self: *Self, basis: Root, after: ?pages.Key) !pages.Slice {
    try self.ready();
    try self.requireBasis(basis);
    var batch = try self.tree().scan(basis.scan_rows, after);
    for (&batch.entries) |*slot| if (slot.*) |*entry| {
        if (entry.value.len != 81) return error.InvalidTableRowReference;
        const value = entry.value;
        const locator = try r.Locator.decode(try pages.Value.init(value.data[32..81]));
        if (!std.meta.eql(entry.key, try locator.scanKey())) return error.InvalidTableRowReference;
        entry.key = try pages.Key.init(value.data[0..32]);
        entry.value = try locator.encode();
    };
    return batch;
}

pub fn readRow(self: *Self, allocator: std.mem.Allocator, basis: Root, key: pages.Key, value: pages.Value) !OwnedRow {
    return self.readRowWithSchema(allocator, basis, self.declaration.schema.schema, key, value);
}

fn readRowWithSchema(self: *Self, allocator: std.mem.Allocator, basis: Root, schema: f.TableSchema.Schema, key: pages.Key, value: pages.Value) !OwnedRow {
    try self.ready();
    try self.requireBasis(basis);
    if (!std.mem.eql(u8, &try schema.fingerprint(), &basis.schema_fingerprint)) return error.InvalidTableBasis;
    const locator = try r.Locator.decode(value);
    var result: OwnedRow = switch (locator.kind) {
        .wal => blk: {
            if (locator.lsn >= basis.next_lsn or locator.length > f.TableRow.max_bytes) return error.InvalidTableRowReference;
            var batch = try self.log.read(self.allocator, basis.partition, locator.lsn, 1);
            defer batch.deinit();
            if (batch.frames.len != 1 or batch.frames[0].header.lsn != locator.lsn) return error.TableHistoryMissing;
            const decoded = try r.decode(self.allocator, batch.frames[0].payload, locator.lsn);
            if (decoded.record.action != .mutation or (!std.meta.eql(decoded.record.root.interpretation.object, basis.interpretation.object) or !std.mem.eql(u8, &decoded.record.root.schema_fingerprint, &basis.schema_fingerprint)) or
                locator.offset > decoded.rows.len or locator.length > decoded.rows.len - locator.offset) return error.InvalidTableRowReference;
            const bytes = decoded.rows[locator.offset..][0..locator.length];
            if (!std.mem.eql(u8, &r.hash(bytes), &locator.digest)) return error.InvalidTableRowReference;
            break :blk .{ .wal = try f.TableRow.decode(allocator, schema, bytes) };
        },
        .segment => blk: {
            var temporary: ?CachedSegment = null;
            defer if (temporary) |*segment| segment.deinit(self.allocator);
            const segment = try self.loadSegment(locator, &temporary);
            const footer = &segment.footer;
            if (footer.object_id != schema.object or footer.schema_revision != schema.revision or
                !std.mem.eql(u8, &footer.layout_fingerprint, &try schema.layoutFingerprint())) return error.TableSchemaChanged;
            if (footer.segment_id != locator.lsn or locator.offset >= footer.pk_index.len or footer.pk_index[locator.offset].global_row_offset != locator.offset) return error.InvalidTableRowReference;
            const entry = footer.pk_index[locator.offset];
            if (segment.decoded) |*group| if (group.index != entry.row_group) {
                group.arena.deinit();
                segment.decoded = null;
            };
            if (segment.decoded == null) {
                var arena = std.heap.ArenaAllocator.init(self.allocator);
                errdefer arena.deinit();
                const columns = try arena.allocator().alloc([]f.Types.Values.Cell, schema.columns.len);
                for (columns, 0..) |*column, i| column.* = try f.TSeg.decodeRowGroupColumn(arena.allocator(), schema, footer, segment.bytes, entry.row_group, i);
                segment.decoded = .{ .arena = arena, .index = entry.row_group, .columns = columns };
                self.row_groups_decoded +|= 1;
            }
            var arena = std.heap.ArenaAllocator.init(allocator);
            errdefer arena.deinit();
            const cells = try arena.allocator().alloc(f.Types.Values.Cell, schema.columns.len);
            for (segment.decoded.?.columns, cells) |column, *cell| {
                if (entry.row_in_group >= column.len) return error.InvalidTableRowReference;
                cell.* = try f.Types.Values.cloneValidated(arena.allocator(), column[entry.row_in_group]);
            }
            break :blk .{ .segment = .{ .arena = arena, .identity = entry.identity, .cells = cells } };
        },
    };
    errdefer result.deinit();
    var actual: [f.Collation.max_sort_key_bytes]u8 = undefined;
    if (!std.meta.eql(key, try r.rowKey(try result.row().storageKey(schema, &actual)))) return error.InvalidTableRowReference;
    return result;
}

fn segmentKey(digest: [32]u8, buffer: *[96]u8) ![]const u8 {
    return std.fmt.bufPrint(buffer, "table-segments/{x}.tseg", .{&digest});
}

const CachedSegment = struct {
    digest: [32]u8,
    bytes: []u8,
    footer: f.TSeg.Footer,
    decoded: ?struct { arena: std.heap.ArenaAllocator, index: u16, columns: [][]f.Types.Values.Cell } = null,
    fn deinit(self: *CachedSegment, allocator: std.mem.Allocator) void {
        if (self.decoded) |*group| group.arena.deinit();
        self.footer.deinit();
        allocator.free(self.bytes);
    }
};

fn loadSegment(self: *Self, locator: r.Locator, temporary: *?CachedSegment) !*CachedSegment {
    if (self.segment_cache) |*cached| {
        if (std.mem.eql(u8, &cached.digest, &locator.digest) and cached.bytes.len == locator.length) return cached;
        cached.deinit(self.allocator);
        self.segment_cache = null;
    }
    const bytes = try self.readSegment(self.allocator, locator);
    errdefer self.allocator.free(bytes);
    var footer = try f.TSeg.readFooter(self.allocator, bytes);
    errdefer footer.deinit();
    if (footer.total_rows > max_changes) return error.InvalidTableSegment;
    const segment: CachedSegment = .{ .digest = locator.digest, .bytes = bytes, .footer = footer };
    self.segment_reads +|= 1;
    if (bytes.len <= self.options.segment_cache_bytes) {
        self.segment_cache = segment;
        return &self.segment_cache.?;
    }
    temporary.* = segment;
    return &temporary.*.?;
}

fn readSegment(self: *Self, allocator: std.mem.Allocator, locator: r.Locator) ![]u8 {
    if (locator.length == 0 or locator.length > f.TSeg.max_segment_bytes) return error.InvalidTableRowReference;
    var name: [96]u8 = undefined;
    const key = try segmentKey(locator.digest, &name);
    const metadata = try self.objects.head(key) orelse return error.TableSegmentMissing;
    if (metadata.size != locator.length or !std.mem.eql(u8, &metadata.sha256, &locator.digest)) return error.InvalidTableRowReference;
    const bytes = try allocator.alloc(u8, locator.length);
    errdefer allocator.free(bytes);
    if ((try self.objects.getRange(key, 0, locator.length, bytes)).len != bytes.len or !std.mem.eql(u8, &r.hash(bytes), &locator.digest)) return error.InvalidTableRowReference;
    return bytes;
}

fn stageSegment(self: *Self, allocator: std.mem.Allocator, schema: f.TableSchema.Schema, segment_id: u64, rows: []const f.TableRow.Row) !struct { content: d.Content, footer: f.TSeg.Footer } {
    const buffer = try allocator.alloc(u8, f.TSeg.max_segment_bytes);
    defer allocator.free(buffer);
    const bytes = try f.TSeg.writeSegment(allocator, schema, rows, .{ .segment_id = segment_id }, buffer);
    const digest = r.hash(bytes);
    var name: [96]u8 = undefined;
    const metadata = try self.objects.putImmutable(try segmentKey(digest, &name), bytes, digest);
    if (metadata.size != bytes.len or !std.mem.eql(u8, &metadata.sha256, &digest)) return error.InvalidTableSegment;
    return .{ .content = .{ .bytes = bytes.len, .sha256 = digest }, .footer = try f.TSeg.readFooter(allocator, bytes) };
}

/// Flush at most one bounded group of accepted WAL rows. The accepted row index
/// itself is the paged manifest; replacing locators publishes no logical change.
pub fn flush(self: *Self, guard: Guard) !usize {
    try self.ready();
    if (self.root.retired) return error.TableRetired;
    {
        _ = try guard.acquire(guard.context);
        defer guard.release(guard.context);
    }
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var rows: std.ArrayList(f.TableRow.Row) = .empty;
    var bytes: usize = 0;
    var after: ?pages.Key = null;
    find: while (rows.items.len < max_changes) {
        const batch = try self.scan(self.root, after);
        for (batch.entries) |slot| if (slot) |entry| {
            const locator = try r.Locator.decode(entry.value);
            // WAL locators sort before segment locators. Once this boundary is
            // reached there is no unflushed work later in the durable directory.
            if (locator.kind != .wal) break :find;
            if (locator.length > max_row_bytes - bytes or rows.items.len == max_changes) break :find;
            const row = try self.readRow(a, self.root, entry.key, entry.value);
            try rows.append(a, row.row());
            bytes += locator.length;
        };
        after = batch.next orelse break;
    }
    if (rows.items.len == 0) return 0;
    try self.index.begin(self.options.index_work_bytes);
    defer self.index.end();
    var next = self.root;
    const segment = try self.stageSegment(a, self.declaration.schema.schema, next.next_segment, rows.items);
    next.next_segment = try std.math.add(u64, next.next_segment, 1);
    next.next_lsn = try std.math.add(u64, next.next_lsn, 1);
    for (segment.footer.pk_index) |entry| {
        const locator: r.Locator = .{ .kind = .segment, .lsn = segment.footer.segment_id, .offset = entry.global_row_offset, .length = @intCast(segment.content.bytes), .digest = segment.content.sha256 };
        const index_key = try r.rowKey(entry.pk_sort_key);
        const previous = try r.Locator.decode(try self.tree().get(next.rows, index_key) orelse return error.InvalidTableRowReference);
        next.scan_rows = try self.tree().remove(next.scan_rows, try previous.scanKey());
        next.rows = try self.tree().put(next.rows, index_key, try locator.encode());
        next.scan_rows = try self.tree().put(next.scan_rows, try locator.scanKey(), try locator.scanValue(index_key));
    }
    try self.publish(.{ .definition = p.Growth.current_definition, .previous = self.chain, .root = next, .action = .checkpoint }, &.{}, guard);
    try self.reply();
    return rows.items.len;
}

/// Capture exactly the requested accepted frontier, including unflushed rows.
/// The complete WAL and immutable object history remain retained by this owner;
/// this profile has no physical trim/GC operation. Pin ownership and release are
/// durable, and are a prerequisite for any future retained-root collector.
pub fn pin(self: *Self, owner: d.Operation, expected: d.Position, guard: Guard) !SnapshotHandle {
    try self.ready();
    try self.scope(owner);
    {
        _ = try guard.acquire(guard.context);
        defer guard.release(guard.context);
        if (try self.tree().get(self.root.pins, try r.operationKey(owner))) |value| {
            const existing = try Snapshot.Pin.decode(value);
            if (existing.released) return error.TableSnapshotReleased;
            const handle: SnapshotHandle = .{ .owner = owner, .content = existing.content };
            var frozen = try Snapshot.load(self.allocator, self.objects, handle);
            defer frozen.deinit();
            if (expected.partition != frozen.root.partition or expected.next_lsn != frozen.root.next_lsn) return error.DataIdentityConflict;
            return handle;
        }
        if (self.root.retired) return error.TableRetired;
        if (self.root.next_lsn == 0) return error.TableNotCreated;
        if (expected.partition != self.root.partition or expected.next_lsn != self.root.next_lsn) return error.TableDataChanged;
    }
    const handle = try Snapshot.stage(self.allocator, self.objects, owner, self.root, self.declaration.schema.schema);
    try self.index.begin(self.options.index_work_bytes);
    defer self.index.end();
    var next = self.root;
    next.next_lsn = try std.math.add(u64, next.next_lsn, 1);
    next.pins = try self.tree().put(next.pins, try r.operationKey(owner), try (Snapshot.Pin{ .content = handle.content }).encode());
    try self.publish(.{ .definition = p.Growth.current_definition, .previous = self.chain, .root = next, .action = .{ .pin = .{ .owner = owner, .basis = handle.content } } }, &.{}, guard);
    try self.reply();
    return handle;
}

fn requirePin(self: *Self, handle: SnapshotHandle) !Snapshot.Pin {
    try self.scope(handle.owner);
    const value = try self.tree().get(self.root.pins, try r.operationKey(handle.owner)) orelse return error.TableSnapshotNotPinned;
    const existing = try Snapshot.Pin.decode(value);
    if (!std.meta.eql(existing.content, handle.content)) return error.DataIdentityConflict;
    return existing;
}

pub fn releaseSnapshot(self: *Self, handle: SnapshotHandle, guard: Guard) !void {
    try self.ready();
    {
        _ = try guard.acquire(guard.context);
        defer guard.release(guard.context);
        if ((try self.requirePin(handle)).released) return;
    }
    try self.index.begin(self.options.index_work_bytes);
    defer self.index.end();
    var next = self.root;
    next.next_lsn = try std.math.add(u64, next.next_lsn, 1);
    next.pins = try self.tree().put(next.pins, try r.operationKey(handle.owner), try (Snapshot.Pin{ .content = handle.content, .released = true }).encode());
    try self.publish(.{ .definition = p.Growth.current_definition, .previous = self.chain, .root = next, .action = .{ .release = .{ .owner = handle.owner, .basis = handle.content } } }, &.{}, guard);
    try self.reply();
}

pub fn readSnapshot(self: *Self, allocator: std.mem.Allocator, handle: SnapshotHandle, key: []const u8, guard: Guard) !?OwnedRow {
    try self.ready();
    _ = try guard.acquire(guard.context);
    defer guard.release(guard.context);
    if ((try self.requirePin(handle)).released) return error.TableSnapshotReleased;
    var frozen = try Snapshot.load(self.allocator, self.objects, handle);
    defer frozen.deinit();
    try self.requireBasis(frozen.root);
    const index_key = try r.rowKey(key);
    const value = try self.tree().get(frozen.root.rows, index_key) orelse return null;
    var row = try self.readRowWithSchema(allocator, frozen.root, frozen.schema.schema, index_key, value);
    errdefer row.deinit();
    var actual: [f.Collation.max_sort_key_bytes]u8 = undefined;
    if (!std.mem.eql(u8, key, try row.row().storageKey(frozen.schema.schema, &actual))) return error.TableKeyHashCollision;
    return row;
}
