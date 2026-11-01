//! Immutable paged transaction participants and preparation evidence. A sealed
//! directory is private data until its owning coordination log publishes it.
const std = @import("std");
const p = @import("transit_protocol");
const x = p.Transaction;
const d = p.DataLifecycle;
const TreeStore = @import("TreeStore.zig");
const Objects = @import("TransitObjectStore.zig");
const pages = TreeStore.pages;
const Self = @This();
pub const max_object_bytes = 16 * 1024;
const header_bytes = 40;

pub const Entry = union(enum) {
    participant: x.Participant,
    prepared: x.Prepared,
    source: struct { guard: x.Guard, pin: x.Pin },

    pub fn target(self: Entry) x.Target {
        return switch (self) {
            .participant => |participant| participant.guard().target(),
            .prepared => |prepared| prepared.target,
            .source => |source| source.guard.target(),
        };
    }

    pub fn object(self: Entry) d.Object {
        return self.target().object;
    }

    pub fn cursor(self: Entry) Cursor {
        return cursorOf(self.target());
    }

    fn validate(self: Entry, identity: x.Identity) !void {
        try identity.requireObject(self.object());
        switch (self) {
            .participant => |participant| try participant.validate(identity),
            .prepared => |prepared| {
                try prepared.validate();
                if (!std.meta.eql(identity, prepared.attempt.transaction)) return error.TransactionIdentityConflict;
            },
            .source => |source| {
                try source.guard.validate();
                try source.pin.content.validate();
                if (!std.meta.eql(source.pin.owner, identity.begin)) return error.TransactionIdentityConflict;
            },
        }
    }

    fn writes(self: Entry) bool {
        return switch (self) {
            .participant => |participant| participant.writes(),
            .prepared => true,
            .source => false,
        };
    }
};

pub const Kind = enum { participants, preparations, sources };
pub const Root = struct {
    definition: p.Growth.Definition,
    identity: x.Identity,
    kind: Kind,
    entries: ?pages.Reference,
    count: u64,
    writes: u64,

    pub fn validate(self: Root) !void {
        try self.identity.validate();
        if ((self.entries == null) != (self.count == 0) or self.writes > self.count or
            (self.kind == .preparations and self.writes != self.count) or
            (self.kind == .sources and self.writes != 0)) return error.InvalidTransactionDirectory;
    }
};

pub const Page = struct {
    entries: [pages.page_entries]?Entry = @splat(null),
    next: ?Cursor = null,
};

/// Kind is checked against the entry, not included in the key: one stable
/// object cannot acquire two different owner kinds under the same ordinal.
pub const Cursor = struct { object: u64, partition: ?u32 };

objects: Objects.ObjectStore,
index: TreeStore,
root: Root,
entry_limit: u64,
index_work_bytes: usize,

pub fn init(allocator: std.mem.Allocator, objects: Objects.ObjectStore, identity: x.Identity, kind: Kind, entry_limit: u64, resident_pages: usize, index_work_bytes: usize) !Self {
    try identity.validate();
    if (entry_limit == 0 or index_work_bytes == 0) return error.InvalidTransactionLimits;
    return .{
        .objects = objects,
        .index = try TreeStore.init(allocator, objects, resident_pages),
        .root = .{ .definition = p.Growth.current_definition, .identity = identity, .kind = kind, .entries = null, .count = 0, .writes = 0 },
        .entry_limit = entry_limit,
        .index_work_bytes = index_work_bytes,
    };
}

pub fn deinit(self: *Self) void {
    self.index.deinit();
    self.* = undefined;
}

fn tree(self: *Self) pages.Tree(TreeStore) {
    return .{ .store = &self.index };
}

fn entryKey(cursor: Cursor) !pages.Key {
    if (cursor.object == 0) return error.InvalidTransactionDirectory;
    var bytes: [13]u8 = @splat(0);
    std.mem.writeInt(u64, bytes[0..8], cursor.object, .big);
    bytes[8] = @intFromBool(cursor.partition != null);
    if (cursor.partition) |partition| std.mem.writeInt(u32, bytes[9..13], partition, .big);
    return pages.Key.init(&bytes);
}

fn keyCursor(key: pages.Key) !Cursor {
    if (key.len != 13 or key.data[8] > 1) return error.InvalidTransactionDirectory;
    const object = std.mem.readInt(u64, key.data[0..8], .big);
    if (object == 0) return error.InvalidTransactionDirectory;
    const partition = std.mem.readInt(u32, key.data[9..13], .big);
    if (key.data[8] == 0 and partition != 0) return error.InvalidTransactionDirectory;
    return .{ .object = object, .partition = if (key.data[8] == 1) partition else null };
}

fn cursorOf(target: x.Target) Cursor {
    return .{ .object = target.object.object, .partition = target.partition };
}

pub fn objectKey(content: d.Content, output: *[96]u8) ![]const u8 {
    try content.validate();
    if (content.bytes <= header_bytes or content.bytes > max_object_bytes) return error.InvalidTransactionDirectory;
    return std.fmt.bufPrint(output, "transaction-directory/{x}.data", .{&content.sha256});
}

fn encode(value: anytype, output: []u8) ![]const u8 {
    if (output.len < header_bytes) return error.InvalidTransactionDirectory;
    output[0..8].* = "TXDIR1\x00\x00".*;
    output[8..40].* = p.Growth.definition_bytes;
    var writer: std.Io.Writer = .fixed(output[header_bytes..@min(output.len, max_object_bytes)]);
    var encoder: std.json.Stringify = .{ .writer = &writer };
    try p.Json.write(value, &encoder);
    return output[0 .. header_bytes + writer.end];
}

fn stage(self: *Self, value: anytype) !d.Content {
    var bytes: [max_object_bytes]u8 = undefined;
    const encoded = try encode(value, &bytes);
    const content: d.Content = .{ .bytes = encoded.len, .sha256 = hash(encoded) };
    var name: [96]u8 = undefined;
    const stored = try self.objects.putImmutable(try objectKey(content, &name), encoded, content.sha256);
    if (stored.size != content.bytes or !std.mem.eql(u8, &stored.sha256, &content.sha256)) return error.InvalidTransactionDirectory;
    return content;
}

fn load(self: *Self, comptime T: type, content: d.Content) !T {
    var name: [96]u8 = undefined;
    const key = try objectKey(content, &name);
    const metadata = try self.objects.head(key) orelse return error.MissingTransactionDirectory;
    if (metadata.size != content.bytes or !std.mem.eql(u8, &metadata.sha256, &content.sha256)) return error.InvalidTransactionDirectory;
    var bytes: [max_object_bytes]u8 = undefined;
    const encoded = try self.objects.getRange(key, 0, @intCast(content.bytes), &bytes);
    if (encoded.len != content.bytes or !std.mem.eql(u8, &hash(encoded), &content.sha256) or
        !std.mem.eql(u8, encoded[0..8], "TXDIR1\x00\x00")) return error.InvalidTransactionDirectory;
    if (!std.mem.eql(u8, encoded[8..40], &p.Growth.definition_bytes)) return error.IncompatibleDefinition;
    var scratch: [max_object_bytes]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&scratch);
    const parsed = std.json.parseFromSliceLeaky(T, fixed.allocator(), encoded[40..], .{}) catch |err|
        return if (err == error.OutOfMemory) error.TransactionDecodeLimit else err;
    var canonical: [max_object_bytes]u8 = undefined;
    if (!std.mem.eql(u8, encoded, try encode(parsed, &canonical))) return error.InvalidTransactionDirectory;
    // All directory types are fixed-size values and own no parsed slices.
    return parsed;
}

fn reference(content: d.Content) !pages.Value {
    var bytes: [40]u8 = undefined;
    std.mem.writeInt(u64, bytes[0..8], content.bytes, .little);
    bytes[8..40].* = content.sha256;
    return pages.Value.init(&bytes);
}

pub fn contentOf(value: pages.Value) !d.Content {
    if (value.len != 40) return error.InvalidTransactionDirectory;
    const content: d.Content = .{ .bytes = std.mem.readInt(u64, value.data[0..8], .little), .sha256 = value.data[8..40].* };
    try content.validate();
    if (content.bytes <= header_bytes or content.bytes > max_object_bytes) return error.InvalidTransactionDirectory;
    return content;
}

fn loadEntry(self: *Self, key: pages.Key, value: pages.Value) !Entry {
    const entry = try self.load(Entry, try contentOf(value));
    try self.requireEntry(entry);
    if (!std.meta.eql(cursorOf(entry.target()), try keyCursor(key))) return error.InvalidTransactionDirectory;
    return entry;
}

fn requireEntry(self: *Self, entry: Entry) !void {
    try entry.validate(self.root.identity);
    const kind: Kind = switch (entry) {
        .participant => .participants,
        .prepared => .preparations,
        .source => .sources,
    };
    if (self.root.kind != kind) return error.InvalidTransactionDirectory;
}

pub fn get(self: *Self, target: x.Target) !?Entry {
    try target.validate();
    try self.root.identity.requireObject(target.object);
    const key = try entryKey(cursorOf(target));
    const value = try self.tree().get(self.root.entries, key) orelse return null;
    const entry = try self.loadEntry(key, value);
    if (!std.meta.eql(entry.target(), target)) return error.TransactionIdentityConflict;
    return entry;
}

pub fn getTable(self: *Self, object: u64) !?Entry {
    return self.get(.{ .object = .{ .scope = self.root.identity.begin.scope, .branch = self.root.identity.branch, .object = object }, .kind = .table, .partition = null });
}

/// Exact repeats are idempotent; replacement is forbidden. A failed stage or
/// quota check leaves this private root unchanged and cannot publish anything.
pub fn put(self: *Self, entry: Entry) !void {
    try self.requireEntry(entry);
    if (try self.get(entry.target())) |prior| {
        if (!std.meta.eql(prior, entry)) return error.TransactionIdentityConflict;
        return;
    }
    // The short prefix sorts before every ordinal of this object. Inspect one
    // bounded page to reject mixed kinds across different partition ordinals.
    var prefix: [8]u8 = undefined;
    std.mem.writeInt(u64, &prefix, entry.object().object, .big);
    const siblings = try self.tree().scan(self.root.entries, try pages.Key.init(&prefix));
    if (siblings.entries[0]) |first| {
        const sibling = try self.loadEntry(first.key, first.value);
        if (sibling.object().object == entry.object().object and sibling.target().kind != entry.target().kind)
            return error.TransactionIdentityConflict;
    }
    if (self.root.count >= self.entry_limit) return error.TransactionParticipantLimit;
    const content = try self.stage(entry);
    try self.index.begin(self.index_work_bytes);
    defer self.index.end();
    const next = try self.tree().put(self.root.entries, try entryKey(cursorOf(entry.target())), try reference(content));
    self.root.entries = next;
    self.root.count += 1;
    self.root.writes += @intFromBool(entry.writes());
}

/// Advance a private log workspace without changing its source or identity.
/// The caller has evaluated the complete new action directory. Previously
/// sealed roots remain immutable and usable by savepoints and frozen attempts.
pub fn advanceLog(self: *Self, guard: x.LogGuard, expected: ?x.Directory, next: x.Directory) !void {
    const entry: Entry = .{ .participant = .{ .log = .{ .guard = guard, .actions = next } } };
    try self.requireEntry(entry);
    const prior = try self.get(entry.target());
    if (prior == null) {
        if (expected != null) return error.TransactionIdentityConflict;
        return self.put(entry);
    }
    if (prior.? != .participant or prior.?.participant != .log or
        !std.meta.eql(prior.?.participant.log.guard, guard) or
        !std.meta.eql(prior.?.participant.log.actions, expected) or expected == null or
        next.count <= expected.?.count) return error.TransactionIdentityConflict;
    const content = try self.stage(entry);
    try self.index.begin(self.index_work_bytes);
    defer self.index.end();
    self.root.entries = try self.tree().put(self.root.entries, try entryKey(entry.cursor()), try reference(content));
}

pub fn page(self: *Self, after: ?Cursor) !Page {
    const entries = try self.tree().scan(self.root.entries, if (after) |id| try entryKey(id) else null);
    var result: Page = .{};
    for (entries.entries, &result.entries) |slot, *output| if (slot) |entry| {
        output.* = try self.loadEntry(entry.key, entry.value);
    };
    if (entries.next) |key| result.next = try keyCursor(key);
    return result;
}

pub fn seal(self: *Self) !x.Directory {
    try self.root.validate();
    return .{ .content = try self.stage(self.root), .count = self.root.count };
}

pub fn commitment(self: *const Self) !x.Directory {
    try self.root.validate();
    var bytes: [max_object_bytes]u8 = undefined;
    const encoded = try encode(self.root, &bytes);
    return .{ .content = .{ .bytes = encoded.len, .sha256 = hash(encoded) }, .count = self.root.count };
}

/// Reopens one fixed root. This is not a retention pin or an acceptance check.
pub fn restore(self: *Self, directory: x.Directory) !void {
    try directory.validate();
    const root = try self.load(Root, directory.content);
    try root.validate();
    if (!std.meta.eql(root.identity, self.root.identity) or root.kind != self.root.kind or
        root.count != directory.count) return error.InvalidTransactionDirectory;
    if (root.count > self.entry_limit) return error.TransactionParticipantLimit;
    if (root.entries) |ref| _ = try self.index.load(ref);
    self.root = root;
}

/// Checks exact complete write membership with bounded pages. Availability of
/// actual participant WAL records/successor objects remains the storage owner's
/// separate commit gate. Read guards must stay held through that decision.
pub fn requireComplete(self: *Self, prepared: *Self, begin: x.Begin, attempt: x.Attempt) !void {
    try begin.validate();
    try attempt.validate();
    if (self.root.kind != .participants or prepared.root.kind != .preparations or
        !std.meta.eql(self.root.identity, begin.identity) or !std.meta.eql(begin.identity, attempt.transaction) or
        !std.meta.eql(prepared.root.identity, begin.identity) or !std.meta.eql(try self.commitment(), attempt.participants) or
        self.root.writes != attempt.writes or prepared.root.count != self.root.writes)
        return error.IncompleteTransactionPreparation;
    var after: ?Cursor = null;
    var count: u64 = 0;
    var writes: u64 = 0;
    while (true) {
        const batch = try self.page(after);
        for (batch.entries) |entry| if (entry) |value| {
            count = try std.math.add(u64, count, 1);
            if (count > self.root.count) return error.InvalidTransactionDirectory;
            const participant = value.participant;
            try participant.validate(begin.identity);
            if (begin.mode == .read_only and participant.writes()) return error.ReadOnlyTransaction;
            if (!participant.writes()) continue;
            const preparation = (try prepared.get(value.target()) orelse return error.IncompleteTransactionPreparation).prepared;
            try attempt.requireSame(preparation.attempt);
            if (!std.meta.eql(participant.guard(), preparation.predecessor)) return error.TransactionIdentityConflict;
            writes = try std.math.add(u64, writes, 1);
        };
        after = batch.next orelse break;
    }
    if (count != self.root.count or writes != self.root.writes) return error.InvalidTransactionDirectory;
    // Count is also checked against actual prepared entries, not only a root's
    // claimed cardinality. Extra entries cannot hide behind a forged count.
    after = null;
    count = 0;
    while (true) {
        const batch = try prepared.page(after);
        for (batch.entries) |entry| if (entry != null) {
            count = try std.math.add(u64, count, 1);
            if (count > writes) return error.InvalidTransactionDirectory;
        };
        after = batch.next orelse break;
    }
    if (count != writes) return error.InvalidTransactionDirectory;
}

fn hash(bytes: []const u8) [32]u8 {
    var result: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &result, .{});
    return result;
}
