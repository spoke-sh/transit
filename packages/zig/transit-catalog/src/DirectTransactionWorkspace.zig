//! Catalog-owned private statement progress. Immutable records are reachable
//! only through an accepted transaction token; staging is never publication.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const s = c.storage;
const d = p.DataLifecycle;
const x = p.Transaction;
const pages = s.TreeStore.pages;
const Record = c.DirectRecord;

pub const max_bytes = 32 * 1024;
pub const head_format: u32 = 0x54585731;
pub const table_format: u32 = 0x54585431;
pub const statement_format: u32 = 0x54584f31;
pub fn reserved(format: u32) bool {
    return format == head_format or format == table_format or format == statement_format;
}

pub const Request = struct {
    statement: x.Statement,
    binding: d.Binding,
    intent: d.Content,

    pub fn validate(self: Request) !void {
        try self.statement.validate();
        try self.binding.validate();
        try self.intent.validate();
        const identity = self.statement.transaction;
        try identity.requireObject(self.binding.target);
        if (!std.meta.eql(identity.begin.scope, self.binding.identity.scope) or
            identity.begin.principal != self.binding.identity.principal or
            identity.begin.operation == self.binding.identity.operation or
            !std.mem.eql(u8, &self.statement.intent, &self.binding.intent) or self.binding.prerequisite != null)
            return error.TransactionIdentityConflict;
        switch (self.binding.action) {
            .insert, .update, .delete => {},
            else => return error.InvalidTransactionWorkspace,
        }
    }
};

pub const Completed = struct {
    request: Request,
    outcome: s.TableWorkspace.Outcome,
    pub fn validate(self: Completed) !void {
        try self.request.validate();
        const statement = switch (self.outcome) {
            inline else => |value| value.statement,
        };
        if (!std.meta.eql(statement, self.request.statement)) return error.InvalidTransactionWorkspace;
    }
};

pub const Head = struct {
    definition: p.Growth.Definition,
    acquired: c.DirectTransaction.Acquired,
    revision: d.Position,
    tables: ?pages.Reference,
    statements: ?pages.Reference,
    last_statement: u64,
    pending: ?Request,
    /// Conservative cumulative staged bytes in accepted workspace publications.
    /// Failed, unreachable staging is reclaimed separately by storage policy.
    charged_bytes: u64,

    pub fn initial(acquired: c.DirectTransaction.Acquired) Head {
        return .{ .definition = p.Growth.current_definition, .acquired = acquired, .revision = acquired.cut.acquired, .tables = null, .statements = null, .last_statement = 0, .pending = null, .charged_bytes = 0 };
    }
    pub fn validate(self: Head, progress: c.DirectClientToken.Progress) !void {
        try self.acquired.validate(progress.receipt);
        try self.revision.validate();
        const begin = self.acquired.cut.begin;
        if (!std.meta.eql(self.revision, progress.revision) or self.revision.next_lsn < self.acquired.cut.acquired.next_lsn or
            self.last_statement > begin.limits.statements or self.charged_bytes > begin.limits.workspace_bytes or
            !progress.pending or progress.cancel) return error.InvalidTransactionWorkspace;
        if (self.pending) |request| {
            try request.validate();
            if (!std.meta.eql(request.statement.transaction, begin.identity) or request.statement.sequence != self.last_statement)
                return error.InvalidTransactionWorkspace;
        }
    }
};

pub fn stage(objects: s.TransitObjectStore.ObjectStore, scope: Record.Scope, format: u32, value: anytype) !Record.Reference {
    var bytes: [max_bytes]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&bytes);
    var encoder: std.json.Stringify = .{ .writer = &writer };
    try p.Json.write(value, &encoder);
    return Record.store(objects, scope, format, writer.buffered());
}

pub fn load(comptime T: type, allocator: std.mem.Allocator, objects: s.TransitObjectStore.ObjectStore, reference: Record.Reference, scope: Record.Scope, format: u32) !T {
    if (reference.format != format or !std.meta.eql(reference.scope, scope) or reference.content.bytes > max_bytes)
        return error.InvalidTransactionWorkspace;
    const bytes = try Record.load(allocator, objects, reference);
    defer allocator.free(bytes);
    var scratch: [max_bytes]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&scratch);
    const value = try std.json.parseFromSliceLeaky(T, fixed.allocator(), bytes, .{});
    var canonical: [max_bytes]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&canonical);
    var encoder: std.json.Stringify = .{ .writer = &writer };
    try p.Json.write(value, &encoder);
    if (!std.mem.eql(u8, bytes, writer.buffered())) return error.InvalidTransactionWorkspace;
    // T has fixed-size fields only, with no slices into parse scratch.
    return value;
}

pub fn recover(allocator: std.mem.Allocator, objects: s.TransitObjectStore.ObjectStore, progress: c.DirectClientToken.Progress) !Head {
    const reference = progress.record orelse return error.TransactionCutNotAcquired;
    if (reference.format == c.DirectTransaction.Acquired.format)
        return Head.initial(try c.DirectTransaction.Acquired.load(allocator, objects, progress));
    const head = try load(Head, allocator, objects, reference, progress.receipt.binding.key.scope(), head_format);
    try head.validate(progress);
    return head;
}

pub fn idKey(id: u64) !pages.Key {
    if (id == 0) return error.InvalidTransactionWorkspace;
    var bytes: [8]u8 = undefined;
    std.mem.writeInt(u64, &bytes, id, .big);
    return pages.Key.init(&bytes);
}
pub fn referenceValue(content: d.Content) !pages.Value {
    var bytes: [40]u8 = undefined;
    std.mem.writeInt(u64, bytes[0..8], content.bytes, .little);
    bytes[8..40].* = content.sha256;
    return pages.Value.init(&bytes);
}
pub fn referenceOf(value: pages.Value, scope: Record.Scope, format: u32) !Record.Reference {
    if (value.len != 40) return error.InvalidTransactionWorkspace;
    const reference: Record.Reference = .{ .scope = scope, .format = format, .content = .{ .bytes = std.mem.readInt(u64, value.data[0..8], .little), .sha256 = value.data[8..40].* } };
    try reference.validate();
    return reference;
}
pub fn get(comptime T: type, allocator: std.mem.Allocator, index: *s.TreeStore, root: ?pages.Reference, id: u64, scope: Record.Scope, format: u32) !?T {
    var tree: pages.Tree(s.TreeStore) = .{ .store = index };
    const value = try tree.get(root, try idKey(id)) orelse return null;
    return try load(T, allocator, index.store, try referenceOf(value, scope, format), scope, format);
}
pub fn put(index: *s.TreeStore, root: ?pages.Reference, id: u64, reference: Record.Reference, work_bytes: usize) !pages.Reference {
    try index.begin(work_bytes);
    defer index.end();
    var tree: pages.Tree(s.TreeStore) = .{ .store = index };
    return tree.put(root, try idKey(id), try referenceValue(reference.content));
}

/// Meters every immutable staging call conservatively, including duplicates.
/// It cannot delete data or publish mutable objects. The owning catalog records
/// the resulting charge with the private root in the same acceptance.
pub const Staging = struct {
    underlying: s.TransitObjectStore.ObjectStore,
    used: u64,
    limit: u64,
    pub fn objects(self: *Staging) s.TransitObjectStore.ObjectStore {
        return .{ .context = self, .vtable = &.{ .putImmutable = putImmutable, .putConditional = putConditional, .getRange = getRange, .head = head, .delete = delete } };
    }
    fn cast(ctx: *anyopaque) *Staging {
        return @ptrCast(@alignCast(ctx));
    }
    fn putImmutable(ctx: *anyopaque, key: []const u8, bytes: []const u8, hash: [32]u8) !s.TransitObjectStore.ObjectMeta {
        const self = cast(ctx);
        const next = try std.math.add(u64, self.used, bytes.len);
        if (next > self.limit) return error.TransactionWorkspaceLimit;
        self.used = next;
        return self.underlying.putImmutable(key, bytes, hash);
    }
    fn putConditional(_: *anyopaque, _: []const u8, _: s.TransitObjectStore.Condition, _: []const u8) !bool {
        return error.InvalidTransactionWorkspace;
    }
    fn delete(_: *anyopaque, _: []const u8) !void {
        return error.InvalidTransactionWorkspace;
    }
    fn getRange(ctx: *anyopaque, key: []const u8, offset: u64, length: u32, output: []u8) ![]const u8 {
        return cast(ctx).underlying.getRange(key, offset, length, output);
    }
    fn head(ctx: *anyopaque, key: []const u8) !?s.TransitObjectStore.ObjectMeta {
        return cast(ctx).underlying.head(key);
    }
};
