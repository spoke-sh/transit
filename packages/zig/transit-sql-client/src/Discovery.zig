//! Nonsecret local rendezvous, outside the private installation. Discovery never
//! reads installation.json, a signing seed or an account recovery journal.
const std = @import("std");
const builtin = @import("builtin");
const api = @import("root.zig").protocol;
pub const Record = struct { version: u8, definition: api.native.Definition, instance: api.Instance, socket: []const u8, account: []const u8, database: []const u8 };
pub const Location = struct { directory: []const u8, socket: []const u8, rendezvous: []const u8 };
pub fn uid() !u32 {
    if (builtin.os.tag != .linux) return error.UnsupportedSqlPeerPlatform;
    return std.c.geteuid();
}
pub fn verify(io: std.Io, directory: []const u8) !void {
    if (builtin.os.tag != .linux) return error.UnsupportedSqlPeerPlatform;
    var opened = try std.Io.Dir.cwd().openDir(io, directory, .{ .follow_symlinks = false });
    defer opened.close(io);
    var info: std.os.linux.Statx = undefined;
    if (std.c.statx(opened.handle, "", std.c.AT.EMPTY_PATH, .BASIC_STATS, &info) != 0 or !info.mask.UID or !info.mask.MODE or info.uid != try uid() or info.mode & 0o077 != 0) return error.UnsafeSqlRuntimeDirectory;
}
fn ensureDirectory(io: std.Io, path: []const u8, create: bool) !void {
    if (!std.fs.path.isAbsolute(path)) return error.UnsafeSqlRuntimeDirectory;
    if (create) std.Io.Dir.cwd().createDir(io, path, .fromMode(0o700)) catch |err| if (err != error.PathAlreadyExists) return err;
    try verify(io, path);
}
pub fn locate(allocator: std.mem.Allocator, io: std.Io, runtime: ?[]const u8, installation: []const u8, create: bool) !Location {
    const base = if (runtime) |path| blk: {
        try verify(io, path);
        break :blk try std.fs.path.join(allocator, &.{ path, "transit" });
    } else try std.fmt.allocPrint(allocator, "/tmp/transit-{d}", .{try uid()});
    try ensureDirectory(io, base, create);
    const absolute = try std.fs.path.resolve(allocator, &.{installation});
    defer allocator.free(absolute);
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(absolute, &digest, .{});
    const key = std.fmt.bytesToHex(digest[0..16].*, .lower);
    const socket = try std.fmt.allocPrint(allocator, "{s}/{s}.sock", .{ base, key });
    _ = try std.Io.net.UnixAddress.init(socket);
    return .{ .directory = base, .socket = socket, .rendezvous = try std.fmt.allocPrint(allocator, "{s}/{s}.json", .{ base, key }) };
}
pub fn read(allocator: std.mem.Allocator, io: std.Io, location: Location) !std.json.Parsed(Record) {
    try verify(io, location.directory);
    const bytes = try std.Io.Dir.cwd().readFileAlloc(io, location.rendezvous, allocator, .limited(4096));
    defer allocator.free(bytes);
    const record = try std.json.parseFromSlice(Record, allocator, bytes, .{ .allocate = .alloc_always });
    errdefer record.deinit();
    if (record.value.version != 1 or record.value.definition != api.native.current_definition or !std.mem.eql(u8, record.value.socket, location.socket)) return error.InvalidSqlRendezvous;
    return record;
}
test "rendezvous cannot default a missing compatibility definition" {
    try std.testing.expectError(error.MissingField, std.json.parseFromSlice(Record, std.testing.allocator, "{\"version\":1,\"instance\":[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],\"socket\":\"/tmp/transit.sock\",\"account\":\"local\",\"database\":\"transit\"}", .{}));
}
/// The supervisor has already stopped and joined its previous child. Refuse
/// live sockets and foreign/non-socket paths; only a dead owned socket is removed.
pub fn cleanSocket(allocator: std.mem.Allocator, io: std.Io, socket: []const u8) !void {
    try verify(io, std.fs.path.dirname(socket) orelse return error.UnsafeSqlRuntimeDirectory);
    const name = try allocator.dupeSentinel(u8, socket, 0);
    defer allocator.free(name);
    var info: std.os.linux.Statx = undefined;
    if (std.c.statx(std.c.AT.FDCWD, name, std.c.AT.SYMLINK_NOFOLLOW, .BASIC_STATS, &info) != 0) {
        if (std.c.errno(-1) == .NOENT) return;
        return error.UnsafeSqlSocket;
    }
    if (!info.mask.UID or !info.mask.MODE or !info.mask.TYPE or info.uid != try uid() or info.mode & std.c.S.IFMT != std.c.S.IFSOCK) return error.UnsafeSqlSocket;
    if ((try std.Io.net.UnixAddress.init(socket)).connect(io)) |stream| {
        stream.close(io);
        return error.SqlSocketInUse;
    } else |err| {
        switch (err) {
            error.ConnectionRefused, error.FileNotFound => {},
            else => return err,
        }
    }
    try std.Io.Dir.cwd().deleteFile(io, socket);
}
/// Held by the service, never by a console. The private parent excludes other
/// UIDs; an existing link or foreign lock file fails before it is opened.
pub fn lockSocket(allocator: std.mem.Allocator, io: std.Io, socket: []const u8) !std.Io.File {
    try verify(io, std.fs.path.dirname(socket) orelse return error.UnsafeSqlRuntimeDirectory);
    const name = try std.fmt.allocPrintSentinel(allocator, "{s}.lock", .{socket}, 0);
    defer allocator.free(name);
    var info: std.os.linux.Statx = undefined;
    if (std.c.statx(std.c.AT.FDCWD, name, std.c.AT.SYMLINK_NOFOLLOW, .BASIC_STATS, &info) == 0) {
        if (!info.mask.UID or !info.mask.MODE or !info.mask.TYPE or info.uid != try uid() or info.mode & std.c.S.IFMT != std.c.S.IFREG or info.mode & 0o077 != 0) return error.UnsafeSqlSocket;
    } else if (std.c.errno(-1) != .NOENT) return error.UnsafeSqlSocket;
    const file = try std.Io.Dir.cwd().createFile(io, name, .{ .truncate = false, .permissions = .fromMode(0o600) });
    errdefer file.close(io);
    if (!try file.tryLock(io, .exclusive)) return error.SqlSocketInUse;
    try cleanSocket(allocator, io, socket);
    return file;
}
test "socket ownership rejects another service, live paths and unsafe parents" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;
    const t = std.testing;
    var temporary = t.tmpDir(.{ .iterate = true });
    defer temporary.cleanup();
    const directory = try temporary.dir.realPathFileAlloc(t.io, ".", t.allocator);
    defer t.allocator.free(directory);
    try temporary.dir.setPermissions(t.io, .fromMode(0o700));
    const socket = try std.fs.path.join(t.allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "session.sock" });
    defer t.allocator.free(socket);
    const owner = try lockSocket(t.allocator, t.io, socket);
    defer owner.close(t.io);
    try t.expectError(error.SqlSocketInUse, lockSocket(t.allocator, t.io, socket));
    var listener = try (try std.Io.net.UnixAddress.init(socket)).listen(t.io, .{});
    try t.expectError(error.SqlSocketInUse, cleanSocket(t.allocator, t.io, socket));
    listener.deinit(t.io);
    try cleanSocket(t.allocator, t.io, socket);
    try temporary.dir.setPermissions(t.io, .fromMode(0o755));
    try t.expectError(error.UnsafeSqlRuntimeDirectory, verify(t.io, directory));
}
