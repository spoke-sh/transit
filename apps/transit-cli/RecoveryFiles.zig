//! Private, non-replacing recovery artifacts shared by explicit caller commands.
const std = @import("std");
pub fn create(init: std.process.Init, path: []const u8, value: anytype) !void {
    const bytes = try std.json.Stringify.valueAlloc(init.arena.allocator(), value, .{ .escape_unicode = true });
    defer std.crypto.secureZero(u8, bytes);
    if (bytes.len > 65536) return error.ArtifactTooLarge;
    const directory = try std.Io.Dir.cwd().openDir(init.io, std.fs.path.dirname(path) orelse ".", .{ .iterate = true });
    defer directory.close(init.io);
    var file = try directory.createFileAtomic(init.io, std.fs.path.basename(path), .{ .replace = false, .permissions = .fromMode(0o600) });
    defer file.deinit(init.io);
    try file.file.writeStreamingAll(init.io, bytes);
    try file.file.sync(init.io);
    try file.link(init.io);
    if (std.c.fsync(directory.handle) != 0) return error.ArtifactSyncFailed;
}
