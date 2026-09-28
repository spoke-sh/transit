//! One explicitly selected private recovery file. Never a history or result log.
const std = @import("std");
const q = @import("transit_query");
const Session = @import("Unified.zig").Session;
pub const max_bytes = 131072;
const Identity = struct {
    realm: u64,
    principal: u64,
    requester: u64,
    requests: u64,
    key: [32]u8,
    fn from(client: *q.UnifiedClient) Identity {
        const c = client.connection;
        return .{ .realm = c.realm, .principal = c.principal, .requester = c.requester, .requests = c.requests, .key = client.key.public_key.toBytes() };
    }
};
const Record = struct {
    version: u8 = 1,
    identity: Identity,
    namespace: ?u64,
    bundle: []const u8,
    pending: ?q.UnifiedClient.Prepared,
    input: ?u64,
    cursor: ?q.UnifiedResult.Cursor,
    complete: bool,
};
const Self = @This();
io: std.Io,
allocator: std.mem.Allocator,
path: []const u8,
identity: Identity,
lock: std.Io.File,
failed: bool = false,
pub fn open(init: std.process.Init, path: []const u8, client: *q.UnifiedClient, session: *Session) !Self {
    const lock_path = try std.fmt.allocPrint(init.gpa, "{s}.lock", .{path});
    defer init.gpa.free(lock_path);
    const lock = try std.Io.Dir.cwd().createFile(init.io, lock_path, .{ .truncate = false, .permissions = .fromMode(0o600) });
    errdefer lock.close(init.io);
    if (!try lock.tryLock(init.io, .exclusive)) return error.ConsoleRecoveryInUse;
    const self: Self = .{ .io = init.io, .allocator = init.gpa, .path = path, .identity = Identity.from(client), .lock = lock };
    const bytes = std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(max_bytes)) catch |err| {
        if (err == error.FileNotFound) return self;
        return err;
    };
    defer {
        std.crypto.secureZero(u8, bytes);
        init.gpa.free(bytes);
    }
    var arena: std.heap.ArenaAllocator = .init(init.gpa);
    defer arena.deinit();
    const record = (try std.json.parseFromSlice(Record, arena.allocator(), bytes, .{})).value;
    if (record.version != 1 or !std.meta.eql(record.identity, self.identity)) return error.ConsoleRecoveryIdentityMismatch;
    if (record.namespace == 0 or record.input == 0 or (record.pending != null and record.input != null)) return error.InvalidConsoleRecovery;
    if (record.pending) |pending| try client.validate(pending);
    const bundle = try q.Values.unhex(arena.allocator(), record.bundle, q.Bundle.max_bytes);
    if (bundle.len > 0) {
        if (record.namespace == null) return error.InvalidConsoleRecovery;
        _ = try q.Bundle.decode(arena.allocator(), bundle);
    }
    // Source bindings may change. Recovery itself never consults that binding;
    // every eventual native operation rechecks its own current authorization.
    session.namespace = record.namespace;
    @memcpy(session.bundle[0..bundle.len], bundle);
    session.length = bundle.len;
    session.pending = record.pending;
    session.input = record.input;
    session.cursor = record.cursor;
    session.complete = record.complete;
    return self;
}
pub fn close(self: *Self) void {
    self.lock.close(self.io);
}
pub fn checkpoint(context: *anyopaque, session: *const Session) !void {
    const self: *Self = @ptrCast(@alignCast(context));
    self.save(session) catch |err| {
        self.failed = true;
        return err;
    };
}
fn save(self: *Self, session: *const Session) !void {
    if (self.failed) return error.ConsoleRecoveryWriteFailed;
    var arena: std.heap.ArenaAllocator = .init(self.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const record: Record = .{ .identity = self.identity, .namespace = session.namespace, .bundle = try q.document.JsonValues.hex(allocator, session.bundle[0..session.length]), .pending = session.pending, .input = session.input, .cursor = session.cursor, .complete = session.complete };
    const bytes = try std.json.Stringify.valueAlloc(allocator, record, .{});
    defer std.crypto.secureZero(u8, bytes);
    if (bytes.len > max_bytes) return error.ConsoleRecoveryTooLarge;
    const parent = try std.Io.Dir.cwd().openDir(self.io, std.fs.path.dirname(self.path) orelse ".", .{ .iterate = true });
    defer parent.close(self.io);
    var file = try parent.createFileAtomic(self.io, std.fs.path.basename(self.path), .{ .replace = true, .permissions = .fromMode(0o600) });
    defer file.deinit(self.io);
    try file.file.writeStreamingAll(self.io, bytes);
    try file.file.sync(self.io);
    try file.replace(self.io);
    if (std.c.fsync(parent.handle) != 0) return error.ConsoleRecoverySyncFailed;
}
