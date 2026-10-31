//! Browser control records over the public direct catalog's conditional progress
//! owner. Each key has its own immutable history; no resident directory grows
//! with retained identities, challenges or sessions.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const Self = @This();

pub const format: u32 = 0x42524331; // BRC1
pub const Kind = enum { provider, secret, binding, publication, identity, challenge, session };
pub const Revision = p.DataLifecycle.Position;
pub const Record = struct {
    definition: p.Growth.Definition,
    namespace: u64,
    kind: Kind,
    key: [32]u8,
    mutation: [16]u8,
    previous: ?c.DirectRecord.Reference,
    payload: []const u8,

    pub fn validate(self: Record) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        if (self.namespace == 0 or std.mem.allEqual(u8, &self.key, 0) or std.mem.allEqual(u8, &self.mutation, 0)) return error.InvalidBrowserRecord;
        if (self.payload.len == 0 or self.payload.len > 64 * 1024) return error.BrowserRecordCapacity;
        if (self.previous) |previous| {
            try previous.validate();
            if (previous.format != format) return error.InvalidBrowserRecord;
        }
    }
};
pub const Read = struct {
    parsed: std.json.Parsed(Record),
    reference: c.DirectRecord.Reference,
    revision: Revision,
    pending: bool,
    pub fn deinit(self: *Read) void {
        self.parsed.deinit();
        self.* = undefined;
    }
    pub fn value(self: Read) Record {
        return self.parsed.value;
    }
};
pub const Accepted = struct {
    reference: c.DirectRecord.Reference,
    revision: Revision,
    /// False means the same mutation was already observed. In particular this
    /// is never a new dispatch permit for a previously claimed external effect.
    changed: bool,
};

client: c.DirectTableClient,
namespace: u64,
limits: c.DirectClientToken.Limits = .{},

pub fn account(self: Self, kind: Kind) [32]u8 {
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.browser.records.v1\x00");
    var bytes: [8]u8 = undefined;
    std.mem.writeInt(u64, &bytes, self.namespace, .little);
    hash.update(&bytes);
    hash.update(@tagName(kind));
    return hash.finalResult();
}
pub fn digest(name: []const u8) [32]u8 {
    var result: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(name, &result, .{});
    return result;
}
pub fn key(self: Self, kind: Kind, identity: [32]u8) c.DirectClientToken.Key {
    return .{ .definition = p.Growth.current_definition, .connection = self.client.connection, .account = self.account(kind), .token = identity[0..16].* };
}
pub fn operation(self: Self, kind: Kind, identity: [32]u8) u64 {
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.browser.operation.v1\x00");
    hash.update(&self.account(kind));
    hash.update(&identity);
    const bytes = hash.finalResult();
    return std.mem.readInt(u64, bytes[0..8], .little) | 1;
}
pub fn read(self: Self, kind: Kind, identity: [32]u8) !?Read {
    const progress = try c.DirectClientToken.inspect(self.client, self.key(kind, identity)) orelse return null;
    return try self.readProgress(kind, identity, progress);
}
pub fn readProgress(self: Self, kind: Kind, identity: [32]u8, progress: c.DirectClientToken.Progress) !Read {
    try self.key(kind, identity).requireSame(progress.receipt.binding.key);
    if (progress.receipt.binding.intent != .external) return error.InvalidBrowserRecord;
    const reference = progress.record orelse progress.receipt.binding.intent.external.record;
    const parsed = try self.load(reference);
    errdefer parsed.deinit();
    // Keep the full digest in the record so a truncated token collision cannot
    // turn one browser identity or declaration into another.
    if (parsed.value.kind != kind or !std.mem.eql(u8, &parsed.value.key, &identity)) return error.BrowserRecordKeyConflict;
    return .{ .parsed = parsed, .reference = reference, .revision = progress.revision, .pending = progress.pending };
}
pub fn load(self: Self, reference: c.DirectRecord.Reference) !std.json.Parsed(Record) {
    if (reference.format != format or !std.meta.eql(reference.scope.connection, self.client.connection)) return error.InvalidBrowserRecord;
    const bytes = try c.DirectRecord.read(self.client.allocator, self.client, reference);
    defer self.client.allocator.free(bytes);
    const parsed = try std.json.parseFromSlice(Record, self.client.allocator, bytes, .{ .allocate = .alloc_always, .duplicate_field_behavior = .@"error" });
    errdefer parsed.deinit();
    try parsed.value.validate();
    if (parsed.value.namespace != self.namespace or !std.mem.eql(u8, &reference.scope.account, &self.account(parsed.value.kind))) return error.InvalidBrowserRecord;
    return parsed;
}
/// One bounded page, including terminal/disabled records. Expiry is not deletion.
pub fn page(self: Self, kind: Kind, after: ?u64) !c.DirectClientToken.Page {
    return c.DirectClientToken.list(self.client, self.account(kind), after, false);
}

/// Repair pending admission bookkeeping after interruption. This changes no
/// domain state and never grants permission to dispatch an external exchange.
/// Hosts sweep bounded pages on activation; no retained directory is materialized.
pub fn reconcilePage(self: Self, kind: Kind, after: ?u64) !?u64 {
    const entries = try c.DirectClientToken.list(self.client, self.account(kind), after, true);
    for (entries.entries) |slot| if (slot) |entry| {
        if (entry.receipt.binding.intent != .external) return error.InvalidBrowserRecord;
        _ = try c.DirectClientToken.update(self.client, .{ .key = entry.receipt.binding.key, .expected = entry.revision, .pending = false, .cancel = entry.cancel, .record = entry.record });
    };
    return entries.next;
}

/// The caller freezes mutation, payload and expected revision before dispatch.
/// A lost response requires read/history inspection; this method never retries.
/// Acceptance and settling the generic token's pending quota are separate: a
/// crash between them leaves an inspectable accepted initial record.
pub fn put(self: Self, kind: Kind, identity: [32]u8, mutation: [16]u8, expected: ?Revision, payload: []const u8) !Accepted {
    var current = try self.read(kind, identity);
    defer if (current) |*value| value.deinit();
    if (current) |value| {
        if (std.mem.eql(u8, &value.value().mutation, &mutation)) {
            if (!std.mem.eql(u8, value.value().payload, payload)) return error.BrowserMutationConflict;
            const revision = if (value.pending)
                (try c.DirectClientToken.update(self.client, .{ .key = self.key(kind, identity), .expected = value.revision, .pending = false, .cancel = false, .record = value.reference })).revision
            else
                value.revision;
            return .{ .reference = value.reference, .revision = revision, .changed = false };
        }
        if (expected == null or !std.meta.eql(value.revision, expected.?)) return error.BrowserRevisionConflict;
    } else if (expected != null) return error.BrowserRevisionConflict;
    const record: Record = .{
        .definition = p.Growth.current_definition,
        .namespace = self.namespace,
        .kind = kind,
        .key = identity,
        .mutation = mutation,
        .previous = if (current) |value| value.reference else null,
        .payload = payload,
    };
    try record.validate();
    const bytes = try p.Json.valueAlloc(self.client.allocator, record);
    defer self.client.allocator.free(bytes);
    const token = self.key(kind, identity);
    const reference = try c.DirectRecord.stage(self.client, token.account, format, bytes);
    if (current) |value| {
        const updated = try c.DirectClientToken.update(self.client, .{ .key = token, .expected = value.revision, .pending = false, .cancel = false, .record = reference });
        return .{ .reference = reference, .revision = updated.revision, .changed = true };
    }
    const receipt = try c.DirectClientToken.bind(self.client, .{
        .key = token,
        .fingerprint = reference.content.sha256,
        .intent = .{ .external = .{ .connection = self.client.connection, .namespace = self.namespace, .operation = self.operation(kind, identity), .record = reference } },
        .budget = .{ .limits = self.limits, .bytes = @max(4608, bytes.len) },
    });
    try receipt.binding.intent.external.record.requireSame(reference);
    const updated = try c.DirectClientToken.update(self.client, .{ .key = token, .expected = receipt.position, .pending = false, .cancel = false, .record = reference });
    return .{ .reference = reference, .revision = updated.revision, .changed = true };
}

test "browser durable records require an explicit definition and separate key from mutation identity" {
    const t = std.testing;
    const record: Record = .{ .definition = p.Growth.current_definition, .namespace = 1, .kind = .challenge, .key = digest("browser challenge"), .mutation = @splat(7), .previous = null, .payload = "{}" };
    try record.validate();
    var invalid = record;
    invalid.mutation = @splat(0);
    try t.expectError(error.InvalidBrowserRecord, invalid.validate());
    try t.expectError(error.MissingField, std.json.parseFromSlice(Record, t.allocator, "{\"namespace\":1,\"kind\":\"challenge\",\"payload\":\"{}\"}", .{}));
}

test "browser record kinds and namespaces do not alias native external operation identities" {
    const store: Self = .{ .client = undefined, .namespace = 1 };
    const other: Self = .{ .client = undefined, .namespace = 2 };
    const identity = digest("same external identity");
    try std.testing.expect(store.operation(.identity, identity) != store.operation(.binding, identity));
    try std.testing.expect(store.operation(.identity, identity) != other.operation(.identity, identity));
}
