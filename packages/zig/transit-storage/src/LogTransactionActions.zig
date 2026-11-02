//! Paged private log work, ordered by statement and action ordinal. These
//! immutable objects reserve no offsets, settle no input and grant no rights.
//! The transaction owner must retain the sealed root and validate each payload
//! and participant under its publication guards before a common decision.
const std = @import("std");
const p = @import("transit_protocol");
const x = p.Transaction;
const d = p.DataLifecycle;
const Objects = @import("TransitObjectStore.zig");
const TreeStore = @import("TreeStore.zig");
const pages = TreeStore.pages;
const Self = @This();
pub const max_object_bytes = 16 * 1024;
pub const max_payload_bytes = @import("LogPartitionRecord.zig").max_batch_bytes;
pub const Cursor = struct { sequence: u64, ordinal: u32 };
pub const Root = struct {
    definition: p.Growth.Definition,
    identity: x.Identity,
    guard: x.LogGuard,
    entries: ?pages.Reference,
    operations: ?pages.Reference,
    count: u64,
    payload_bytes: u64,
    last: ?struct { cursor: Cursor, intent: [32]u8 },

    pub fn validate(self: Root) !void {
        try self.identity.validate();
        try self.guard.validate();
        try self.identity.requireObject(self.guard.source.target.interpretation.object);
        if ((self.entries == null) != (self.count == 0) or
            (self.operations == null) != (self.count == 0) or
            (self.last == null) != (self.count == 0) or
            (self.count == 0 and self.payload_bytes != 0)) return error.InvalidTransactionActions;
        if (self.last) |last| _ = try entryKey(last.cursor);
    }
};
pub const Entry = struct {
    work: x.LogAction,
    /// Preserve the exact owner-issued coverage; shape validation here does not
    /// authenticate it. The partition owner verifies it before preparation.
    offset_progress: ?p.StreamRead.Progress,
};
pub const Page = struct { entries: [pages.page_entries]?Entry = @splat(null), next: ?Cursor = null };

objects: Objects.ObjectStore,
index: TreeStore,
root: Root,
entry_limit: u64,
payload_limit: u64,
index_work_bytes: usize,

pub fn init(allocator: std.mem.Allocator, objects: Objects.ObjectStore, identity: x.Identity, guard: x.LogGuard, entry_limit: u64, payload_limit: u64, resident_pages: usize, index_work_bytes: usize) !Self {
    const root: Root = .{ .definition = p.Growth.current_definition, .identity = identity, .guard = guard, .entries = null, .operations = null, .count = 0, .payload_bytes = 0, .last = null };
    try root.validate();
    if (entry_limit == 0 or payload_limit == 0 or index_work_bytes == 0) return error.InvalidTransactionLimits;
    return .{ .objects = objects, .index = try TreeStore.init(allocator, objects, resident_pages), .root = root, .entry_limit = entry_limit, .payload_limit = payload_limit, .index_work_bytes = index_work_bytes };
}
pub fn deinit(self: *Self) void {
    self.index.deinit();
    self.* = undefined;
}
fn tree(self: *Self) pages.Tree(TreeStore) {
    return .{ .store = &self.index };
}
pub fn cursor(action: x.LogAction) Cursor {
    return .{ .sequence = action.statement.sequence, .ordinal = action.ordinal };
}
pub fn operation(action: x.LogAction) d.Operation {
    return switch (action.action) {
        .queue_transfer_append => |value| value.destination.operation,
        inline else => |value| value.operation,
    };
}
pub fn append(action: x.LogAction) ?p.StreamQueue.Append {
    return switch (action.action) {
        .append => |value| value,
        .queue_transfer_append => |value| value.destination,
        else => null,
    };
}
fn entryKey(value: Cursor) !pages.Key {
    if (value.sequence == 0 or value.ordinal == 0) return error.InvalidTransactionActions;
    var bytes: [12]u8 = undefined;
    std.mem.writeInt(u64, bytes[0..8], value.sequence, .big);
    std.mem.writeInt(u32, bytes[8..12], value.ordinal, .big);
    return pages.Key.init(&bytes);
}
fn keyCursor(key: pages.Key) !Cursor {
    if (key.len != 12) return error.InvalidTransactionActions;
    const value: Cursor = .{ .sequence = std.mem.readInt(u64, key.data[0..8], .big), .ordinal = std.mem.readInt(u32, key.data[8..12], .big) };
    _ = try entryKey(value);
    return value;
}
fn operationKey(action: x.LogAction) !pages.Key {
    var bytes: [8]u8 = undefined;
    std.mem.writeInt(u64, &bytes, operation(action).operation, .big);
    return pages.Key.init(&bytes);
}
fn reference(content: d.Content) !pages.Value {
    var bytes: [40]u8 = undefined;
    std.mem.writeInt(u64, bytes[0..8], content.bytes, .little);
    bytes[8..40].* = content.sha256;
    return pages.Value.init(&bytes);
}
pub fn contentOf(value: pages.Value) !d.Content {
    if (value.len != 40) return error.InvalidTransactionActions;
    const content: d.Content = .{ .bytes = std.mem.readInt(u64, value.data[0..8], .little), .sha256 = value.data[8..40].* };
    try content.validate();
    if (content.bytes <= 40 or content.bytes > max_object_bytes) return error.InvalidTransactionActions;
    return content;
}
pub fn objectKey(content: d.Content, output: *[96]u8) ![]const u8 {
    try content.validate();
    if (content.bytes <= 40 or content.bytes > max_object_bytes) return error.InvalidTransactionActions;
    return std.fmt.bufPrint(output, "transaction-log-actions/{x}.data", .{&content.sha256});
}
pub fn payloadKey(content: d.Content, output: *[96]u8) ![]const u8 {
    try content.validate();
    if (content.bytes > max_payload_bytes) return error.LogBatchTooLarge;
    return std.fmt.bufPrint(output, "transaction-log-payload/{x}.data", .{&content.sha256});
}
fn encode(value: anytype, output: *[max_object_bytes]u8) ![]const u8 {
    output[0..8].* = "TXLACT1\x00".*;
    output[8..40].* = p.Growth.definition_bytes;
    var writer: std.Io.Writer = .fixed(output[40..]);
    var encoder: std.json.Stringify = .{ .writer = &writer };
    try p.Json.write(value, &encoder);
    return output[0 .. 40 + writer.end];
}
fn stage(self: *Self, value: anytype) !d.Content {
    var buffer: [max_object_bytes]u8 = undefined;
    const bytes = try encode(value, &buffer);
    const content = @import("LogBatch.zig").content(bytes);
    var name: [96]u8 = undefined;
    const stored = try self.objects.putImmutable(try objectKey(content, &name), bytes, content.sha256);
    if (stored.size != content.bytes or !std.mem.eql(u8, &stored.sha256, &content.sha256)) return error.InvalidTransactionActions;
    return content;
}
fn load(self: *Self, comptime T: type, content: d.Content) !T {
    var name: [96]u8 = undefined;
    const path = try objectKey(content, &name);
    const metadata = try self.objects.head(path) orelse return error.MissingTransactionActions;
    if (metadata.size != content.bytes or !std.mem.eql(u8, &metadata.sha256, &content.sha256)) return error.InvalidTransactionActions;
    var buffer: [max_object_bytes]u8 = undefined;
    const bytes = try self.objects.getRange(path, 0, @intCast(content.bytes), &buffer);
    if (!std.meta.eql(@import("LogBatch.zig").content(bytes), content) or !std.mem.eql(u8, bytes[0..8], "TXLACT1\x00")) return error.InvalidTransactionActions;
    if (!std.mem.eql(u8, bytes[8..40], &p.Growth.definition_bytes)) return error.IncompatibleDefinition;
    var scratch: [max_object_bytes]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&scratch);
    const value = std.json.parseFromSliceLeaky(T, fixed.allocator(), bytes[40..], .{}) catch |err| return if (err == error.OutOfMemory) error.TransactionDecodeLimit else err;
    var canonical: [max_object_bytes]u8 = undefined;
    if (!std.mem.eql(u8, bytes, try encode(value, &canonical))) return error.InvalidTransactionActions;
    return value; // Root and Entry own fixed-size fields, never parsed slices.
}
fn requireAction(self: *const Self, action: x.LogAction) !void {
    try action.validate(self.root.guard);
    if (!std.meta.eql(action.statement.transaction, self.root.identity)) return error.TransactionIdentityConflict;
}
fn requireEntry(self: *const Self, entry: Entry) !void {
    try self.requireAction(entry.work);
    if ((entry.work.action == .stream_offset) != (entry.offset_progress != null)) return error.InvalidTransactionCoverage;
    if (entry.offset_progress) |issued| {
        try issued.validate();
        if (!std.meta.eql(try issued.coverage(), entry.work.action.stream_offset.coverage) or issued.end().read.owner.principal != operation(entry.work).principal) return error.InvalidTransactionCoverage;
    }
}
fn loadEntry(self: *Self, key: pages.Key, value: pages.Value) !Entry {
    const entry = try self.load(Entry, try contentOf(value));
    try self.requireEntry(entry);
    const action = entry.work;
    if (!std.meta.eql(cursor(action), try keyCursor(key))) return error.InvalidTransactionActions;
    const indexed = try self.tree().get(self.root.operations, try operationKey(action)) orelse return error.InvalidTransactionActions;
    if (!std.mem.eql(u8, indexed.slice(), key.slice())) return error.InvalidTransactionActions;
    return entry;
}
/// Exact immutable entry reference for bounded retention traversal.
pub fn entryContent(self: *Self, at: Cursor) !d.Content {
    return contentOf(try self.tree().get(self.root.entries, try entryKey(at)) orelse return error.MissingTransactionActions);
}
pub fn get(self: *Self, at: Cursor) !?Entry {
    const key = try entryKey(at);
    return try self.loadEntry(key, try self.tree().get(self.root.entries, key) orelse return null);
}
/// One exact operation lookup in the immutable owner's directory. No resident
/// set grows with the number of statements or transfer participants.
pub fn byOperation(self: *Self, identity: d.Operation) !?Entry {
    try identity.validate();
    var bytes: [8]u8 = undefined;
    std.mem.writeInt(u64, &bytes, identity.operation, .big);
    const at = try self.tree().get(self.root.operations, try pages.Key.init(&bytes)) orelse return null;
    const key = try pages.Key.init(at.slice());
    const entry = try self.loadEntry(key, try self.tree().get(self.root.entries, key) orelse return error.InvalidTransactionActions);
    if (!std.meta.eql(operation(entry.work), identity)) return error.TransactionIdentityConflict;
    return entry;
}
/// Append in statement order. Exact repeats may name any earlier entry; they
/// cannot change its bytes or reuse an operation at another private sequence.
/// The embedding statement owner proves completeness across partition owners.
pub fn put(self: *Self, action: x.LogAction, payload: ?[]const u8) !void {
    return self.putEntry(.{ .work = action, .offset_progress = null }, payload);
}
pub fn putOffset(self: *Self, action: x.LogAction, issued: p.StreamRead.Progress) !void {
    return self.putEntry(.{ .work = action, .offset_progress = issued }, null);
}
fn putEntry(self: *Self, entry: Entry, payload: ?[]const u8) !void {
    try self.requireEntry(entry);
    const action = entry.work;
    const appended = append(action);
    if ((appended != null) != (payload != null)) return error.InvalidStreamPayload;
    if (payload) |bytes| if (!std.meta.eql(@import("LogBatch.zig").content(bytes), appended.?.payload)) return error.LogPayloadConflict;
    const key = try entryKey(cursor(action));
    if (try self.get(cursor(action))) |original| {
        if (!std.meta.eql(original, entry)) return error.TransactionIdentityConflict;
        return;
    }
    if (self.root.last) |last| {
        if (action.statement.sequence < last.cursor.sequence or
            (action.statement.sequence == last.cursor.sequence and (action.ordinal <= last.cursor.ordinal or !std.mem.eql(u8, &action.statement.intent, &last.intent)))) return error.InvalidTransactionStatement;
    }
    const operation_key = try operationKey(action);
    if (try self.tree().get(self.root.operations, operation_key) != null) return error.TransactionIdentityConflict;
    if (self.root.count >= self.entry_limit) return error.TransactionActionLimit;
    const payload_bytes = try std.math.add(u64, self.root.payload_bytes, if (payload) |bytes| bytes.len else 0);
    if (payload_bytes > self.payload_limit) return error.TransactionWorkspaceLimit;
    if (payload) |bytes| {
        const content = appended.?.payload;
        var name: [96]u8 = undefined;
        const stored = try self.objects.putImmutable(try payloadKey(content, &name), bytes, content.sha256);
        if (stored.size != content.bytes or !std.mem.eql(u8, &stored.sha256, &content.sha256)) return error.LogPayloadConflict;
    }
    const content = try self.stage(entry);
    var batch: TreeStore.Batch = .{};
    try self.index.beginBatch(self.index_work_bytes, &batch);
    defer self.index.end();
    var next = self.root;
    next.entries = try self.tree().put(next.entries, key, try reference(content));
    next.operations = try self.tree().put(next.operations, operation_key, try pages.Value.init(key.slice()));
    next.count += 1;
    next.payload_bytes = payload_bytes;
    next.last = .{ .cursor = cursor(action), .intent = action.statement.intent };
    try next.validate();
    try self.index.flush();
    self.root = next;
}
pub fn page(self: *Self, after: ?Cursor) !Page {
    const entries = try self.tree().scan(self.root.entries, if (after) |at| try entryKey(at) else null);
    var result: Page = .{};
    for (entries.entries, &result.entries) |slot, *output| if (slot) |entry| {
        output.* = try self.loadEntry(entry.key, entry.value);
    };
    if (entries.next) |key| result.next = try keyCursor(key);
    return result;
}
pub fn readPayload(self: *Self, action: x.LogAction, output: []u8) ![]const u8 {
    try self.requireAction(action);
    const content = (append(action) orelse return error.InvalidStreamPayload).payload;
    var name: [96]u8 = undefined;
    const path = try payloadKey(content, &name);
    if (output.len < content.bytes) return error.TransactionMemoryLimit;
    const metadata = try self.objects.head(path) orelse return error.MissingTransactionPayload;
    if (metadata.size != content.bytes or !std.mem.eql(u8, &metadata.sha256, &content.sha256)) return error.LogPayloadConflict;
    const bytes = try self.objects.getRange(path, 0, @intCast(content.bytes), output);
    if (!std.meta.eql(@import("LogBatch.zig").content(bytes), content)) return error.LogPayloadConflict;
    return bytes;
}
pub fn seal(self: *Self) !x.Directory {
    try self.root.validate();
    return .{ .content = try self.stage(self.root), .count = self.root.count };
}
/// Check complete ordered membership using bounded pages. Payload availability,
/// schema/semantic validation and current lease/offset guards are separate gates.
pub fn verify(self: *Self) !void {
    var after: ?Cursor = null;
    var count: u64 = 0;
    var payload_bytes: u64 = 0;
    var last: @FieldType(Root, "last") = null;
    while (true) {
        const batch = try self.page(after);
        for (batch.entries) |slot| if (slot) |entry| {
            const action = entry.work;
            count = try std.math.add(u64, count, 1);
            if (count > self.root.count) return error.InvalidTransactionActions;
            if (last) |previous| {
                if (action.statement.sequence < previous.cursor.sequence or
                    (action.statement.sequence == previous.cursor.sequence and
                        (action.ordinal <= previous.cursor.ordinal or !std.mem.eql(u8, &action.statement.intent, &previous.intent)))) return error.InvalidTransactionActions;
            }
            last = .{ .cursor = cursor(action), .intent = action.statement.intent };
            if (append(action)) |value| payload_bytes = try std.math.add(u64, payload_bytes, value.payload.bytes);
        };
        after = batch.next orelse break;
    }
    if (count != self.root.count or payload_bytes != self.root.payload_bytes or !std.meta.eql(last, self.root.last)) return error.InvalidTransactionActions;
    var operation_after: ?pages.Key = null;
    count = 0;
    while (true) {
        const batch = try self.tree().scan(self.root.operations, operation_after);
        for (batch.entries) |slot| if (slot != null) {
            count = try std.math.add(u64, count, 1);
            if (count > self.root.count) return error.InvalidTransactionActions;
        };
        operation_after = batch.next orelse break;
    }
    if (count != self.root.count) return error.InvalidTransactionActions;
}
/// Restoration supplies no retention pin or admission evidence. In particular,
/// restoring an earlier savepoint does not release global operation identities.
pub fn restore(self: *Self, directory: x.Directory) !void {
    try directory.validate();
    const root = try self.load(Root, directory.content);
    try root.validate();
    if (!std.meta.eql(root.identity, self.root.identity) or !std.meta.eql(root.guard, self.root.guard) or root.count != directory.count) return error.InvalidTransactionActions;
    if (root.count > self.entry_limit) return error.TransactionActionLimit;
    if (root.payload_bytes > self.payload_limit) return error.TransactionWorkspaceLimit;
    if (root.entries) |ref| _ = try self.index.load(ref);
    if (root.operations) |ref| _ = try self.index.load(ref);
    self.root = root;
}
