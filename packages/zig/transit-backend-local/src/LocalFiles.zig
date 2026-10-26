//! Durable bounded private metadata. Publication never grants native authority.
const std = @import("std");

pub fn sync(io: std.Io, directory: std.Io.Dir) !void {
    const opened = try directory.openDir(io, ".", .{ .iterate = true });
    defer opened.close(io);
    const file: std.Io.File = .{ .handle = opened.handle, .flags = .{ .nonblocking = false } };
    try file.sync(io);
}

pub fn save(io: std.Io, directory: std.Io.Dir, name: []const u8, bytes: []const u8, replace: bool) !void {
    var temporary = try directory.createFileAtomic(io, name, .{ .replace = replace, .permissions = .fromMode(0o600) });
    defer temporary.deinit(io);
    try temporary.file.writeStreamingAll(io, bytes);
    try temporary.file.sync(io);
    if (replace) try temporary.replace(io) else try temporary.link(io);
    try sync(io, directory);
}

pub fn read(io: std.Io, directory: std.Io.Dir, name: []const u8, output: []u8) !?[]const u8 {
    const file = directory.openFile(io, name, .{ .follow_symlinks = false }) catch |err| switch (err) {
        error.FileNotFound => return null,
        else => return err,
    };
    defer file.close(io);
    const size = try file.length(io);
    if (size > output.len) return error.InvalidStorageMetadata;
    const bytes = output[0..@intCast(size)];
    if (try file.readPositionalAll(io, bytes, 0) != bytes.len) return error.InvalidStorageMetadata;
    return bytes;
}

pub fn remove(io: std.Io, directory: std.Io.Dir, name: []const u8) !void {
    directory.deleteFile(io, name) catch |err| switch (err) {
        error.FileNotFound => {},
        else => return err,
    };
    try sync(io, directory);
}
