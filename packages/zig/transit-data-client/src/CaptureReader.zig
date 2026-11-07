//! Bounded raw capture consumption with explicit terminal verification. Save
//! originals before dispatch; closing never invents another pin or release.
const std = @import("std");
const c = @import("transit_catalog");
const Catalog = @import("Catalog.zig");
const wire = c.DirectSourceRead;
const p = c.protocol;
const Self = @This();
pub const max_saved_bytes = 8192;
pub const scratch_bytes = 1024 * 1024;
pub const Saved = struct {
    definition: p.Growth.Definition,
    connection: c.DirectTableProtocol.Connection,
    open: wire.Open,
    release: p.DataLifecycle.Operation,
    pub fn validate(self: Saved) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try (wire.Request{ .open = self.open }).validate(self.connection);
        try self.connection.owner(self.release);
        if (std.meta.eql(self.open.operation, self.release)) return error.InvalidSourceCaptureReader;
    }
    pub fn save(self: Saved, allocator: std.mem.Allocator) ![]u8 {
        try self.validate();
        return p.Json.valueAllocBounded(allocator, self, max_saved_bytes);
    }
    pub fn load(allocator: std.mem.Allocator, bytes: []const u8) !Saved {
        if (bytes.len == 0 or bytes.len > max_saved_bytes) return error.InvalidSourceCaptureReader;
        const parsed = try p.Json.parseFromSlice(Saved, allocator, bytes);
        defer parsed.deinit();
        const canonical = try parsed.value.save(allocator);
        defer allocator.free(canonical);
        if (!std.mem.eql(u8, bytes, canonical)) return error.InvalidSourceCaptureReader;
        return parsed.value;
    }
};
pub const Transport = struct {
    context: *anyopaque,
    connection: c.DirectTableProtocol.Connection,
    call: *const fn (*anyopaque, *std.heap.ArenaAllocator, wire.Request) anyerror!Catalog.CaptureOutcome,
    pub fn native(catalog: *Catalog) Transport {
        return .{ .context = catalog, .connection = catalog.connection, .call = nativeCall };
    }
    fn nativeCall(context: *anyopaque, output: *std.heap.ArenaAllocator, request: wire.Request) !Catalog.CaptureOutcome {
        const catalog: *Catalog = @ptrCast(@alignCast(context));
        return catalog.callCapture(output, request);
    }
};
pub const Page = struct { offset: u64, bytes: []const u8, complete: bool };

saved: Saved,
transport: Transport,
memory: c.fuze.MemoryBudget,
scratch: std.heap.ArenaAllocator,
state: enum { unopened, active, complete, failed, closing, closed } = .unopened,
attempted: bool = false,
cursor: ?wire.Cursor = null,
handle: ?wire.Handle = null,
hash: std.crypto.hash.sha2.Sha256 = .init(.{}),
last_attempt: c.DirectTableClient.Attempt = .{},

/// Keep this owner at a stable address until deinit and join every call first.
pub fn init(self: *Self, allocator: std.mem.Allocator, saved: Saved, transport: Transport) !void {
    try saved.validate();
    if (!std.meta.eql(saved.connection, transport.connection)) return error.CatalogIdentityConflict;
    self.* = .{ .saved = saved, .transport = transport, .memory = .{ .parent = allocator, .limit = scratch_bytes }, .scratch = undefined };
    self.scratch = .init(self.memory.allocator());
}
/// Destruction releases local memory only. Unresolved remote originals remain
/// in Saved and must be observed or closed explicitly by their owner.
pub fn deinit(self: *Self) void {
    self.scratch.deinit();
    std.debug.assert(self.memory.used == 0);
    self.* = undefined;
}
fn call(self: *Self, request: wire.Request) !wire.Result {
    _ = self.scratch.reset(.retain_capacity);
    const outcome = try self.transport.call(self.transport.context, &self.scratch, request);
    self.last_attempt = outcome.attempt;
    const result = switch (outcome.value) {
        .result => |value| value,
        .failure => |failure| return failure.cause,
    };
    try wire.validateResult(self.scratch.allocator(), self.saved.connection, request, result);
    if (result == .recovering) return error.SourceCaptureReadRecovering;
    return result;
}
pub fn open(self: *Self) !wire.Publication {
    if (self.state != .unopened) return error.SourceCaptureReaderState;
    self.attempted = true;
    const result = try self.call(.{ .open = self.saved.open });
    if (result != .opened) return error.SourceCaptureReaderClosed;
    self.cursor = result.opened;
    self.handle = result.opened.handle;
    self.state = .active;
    return result.opened.handle.publication;
}
pub fn observe(self: *Self) !?wire.Handle {
    const result = try self.call(.{ .inspect_open = self.saved.open });
    if (result == .abandoned) return null;
    if (result != .original) return error.InvalidSourceCaptureReader;
    return result.original;
}
/// Output owns bytes independently of subsequent calls. Prefixes remain
/// provisional until both the server terminal and whole-body SHA-256 agree.
pub fn next(self: *Self, output: std.mem.Allocator) !Page {
    if (self.state != .active and self.state != .complete) return error.SourceCaptureReaderState;
    errdefer self.state = .failed;
    const cursor = self.cursor.?;
    const result = try self.call(.{ .next = cursor });
    if (result != .page) return error.InvalidSourceCaptureReader;
    const page = result.page;
    const bytes = try page.bytes.decode(output, p.SourceCapture.chunk_bytes);
    errdefer {
        @memset(@constCast(bytes), 0);
        output.free(bytes);
    }
    self.hash.update(bytes);
    if (page.complete) {
        var finished = self.hash;
        if (!std.mem.eql(u8, &finished.finalResult(), &cursor.handle.publication.evidence.body.sha256)) return error.SourceCaptureDigestMismatch;
    }
    self.cursor = page.next;
    self.state = if (page.complete) .complete else .active;
    return .{ .offset = page.offset, .bytes = bytes, .complete = page.complete };
}
/// Unknown acquisition is cancelled/observed under its original identity. If
/// it already accepted a pin, release that pin with the saved release operation.
pub fn close(self: *Self) !void {
    self.state = .closing;
    if (self.handle == null) {
        if (!self.attempted) {
            self.state = .closed;
            return;
        }
        const original = try self.call(.{ .cancel_open = self.saved.open });
        if (original == .abandoned) {
            self.state = .closed;
            return;
        }
        if (original != .original or original.original == null) return error.InvalidSourceCaptureReader;
        self.handle = original.original;
    }
    const result = try self.call(.{ .close = .{ .handle = self.handle.?, .operation = self.saved.release } });
    if (result != .closed) return error.InvalidSourceCaptureReader;
    self.state = .closed;
}
