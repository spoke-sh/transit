//! Private native test-host records and executable identity.
const std = @import("std");
pub fn read(a: std.mem.Allocator, io: std.Io, directory: std.Io.Dir, path: []const u8, limit: usize) ![]u8 {
    return readWithKind(a, io, directory, path, limit, null);
}
fn readWithKind(a: std.mem.Allocator, io: std.Io, directory: std.Io.Dir, path: []const u8, limit: usize, actual_kind: ?*std.Io.File.Kind) ![]u8 {
    // Every caller holds the containing directory. Do not follow intermediate
    // components or block if a discovered regular file is replaced by a FIFO.
    if (std.mem.indexOfScalar(u8, path, '/') != null) return error.InvalidSourcePath;
    const terminated = try a.dupeSentinel(u8, path, 0);
    defer a.free(terminated);
    const fd = while (true) {
        const opened = std.c.openat(directory.handle, terminated, .{ .ACCMODE = .RDONLY, .CLOEXEC = true, .NONBLOCK = true, .NOFOLLOW = true });
        if (opened >= 0) break opened;
        switch (@as(std.c.E, @fromBackingInt(@intCast(std.c._errno().*)))) {
            .INTR => continue,
            .NOENT => return error.FileNotFound,
            .ACCES, .PERM => return error.AccessDenied,
            .LOOP => {
                if (actual_kind) |kind| kind.* = .sym_link;
                return error.UnsupportedSourceFileKind;
            },
            .NOTDIR, .ISDIR => return error.UnsupportedSourceFileKind,
            else => return error.SourceReadFailed,
        }
    };
    const file: std.Io.File = .{ .handle = fd, .flags = .{ .nonblocking = true } };
    defer file.close(io);
    const stat = try file.stat(io);
    if (actual_kind) |kind| kind.* = stat.kind;
    if (stat.kind != .file) return error.UnsupportedSourceFileKind;
    var reader = file.reader(io, &.{});
    const bytes = reader.interface.allocRemaining(a, .limited(limit + 1)) catch |err| return if (err == error.ReadFailed) reader.err.? else err;
    if (bytes.len > limit) return error.SourceReadLimit;
    return bytes;
}
pub fn writeFile(io: std.Io, directory: std.Io.Dir, path: []const u8, bytes: []const u8) !void {
    const file = try directory.createFile(io, path, .{ .exclusive = true, .permissions = .fromMode(0o600) });
    defer file.close(io);
    try file.writeStreamingAll(io, bytes);
    try file.sync(io);
}
pub fn executableDigest(io: std.Io, a: std.mem.Allocator) ![32]u8 {
    const path = try std.process.executablePathAlloc(io, a);
    const file = try std.Io.Dir.cwd().openFile(io, path, .{});
    defer file.close(io);
    const size = (try file.stat(io)).size;
    if (size > 1024 * 1024 * 1024) return error.TestRuntimeArtifactLimit;
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    var buffer: [65536]u8 = undefined;
    var offset: u64 = 0;
    while (offset < size) {
        const amount = try file.readPositionalAll(io, buffer[0..@min(buffer.len, size - offset)], offset);
        if (amount == 0) return error.TestRuntimeArtifactChanged;
        hash.update(buffer[0..amount]);
        offset += amount;
    }
    if ((try file.stat(io)).size != size) return error.TestRuntimeArtifactChanged;
    return hash.finalResult();
}
