//! Private bounded installation records; rename and directory fsync are one checkpoint.
const std = @import("std");
pub fn write(io: std.Io, path: []const u8, bytes: []const u8) !void {
    const directory = try std.Io.Dir.cwd().openDir(io, std.fs.path.dirname(path) orelse ".", .{ .iterate = true });
    defer directory.close(io);
    var file = try directory.createFileAtomic(io, std.fs.path.basename(path), .{ .replace = true, .permissions = .fromMode(0o600) });
    defer file.deinit(io);
    try file.file.writeStreamingAll(io, bytes);
    try file.file.sync(io);
    try file.replace(io);
    if (std.c.fsync(directory.handle) != 0) return error.InstallationSyncFailed;
}
pub fn json(io: std.Io, allocator: std.mem.Allocator, path: []const u8, value: anytype) !void {
    const bytes = try std.json.Stringify.valueAlloc(allocator, value, .{});
    defer {
        std.crypto.secureZero(u8, bytes);
        allocator.free(bytes);
    }
    if (bytes.len > 65536) return error.InstallationRecordTooLarge;
    try write(io, path, bytes);
}
pub fn read(comptime T: type, io: std.Io, allocator: std.mem.Allocator, path: []const u8) !T {
    const bytes = try std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(65537));
    defer {
        std.crypto.secureZero(u8, bytes);
        allocator.free(bytes);
    }
    if (bytes.len > 65536) return error.InstallationRecordTooLarge;
    return (try std.json.parseFromSlice(T, allocator, bytes, .{ .allocate = .alloc_always })).value;
}
