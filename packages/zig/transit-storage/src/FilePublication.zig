//! Nonreplacing regular-file publication, including filesystems without O_TMPFILE.
//! Callers sync the contents before linking and the destination directory before
//! acknowledgement. A failed link may have executed: retain the original intent
//! and reconcile its exact bytes; never infer absence from the syscall result.
const std = @import("std");

pub fn link(io: std.Io, file: *std.Io.File.Atomic) !void {
    if (file.file_exists) {
        // Zig's named Atomic.link branch uses RENAME_NOREPLACE, unsupported by
        // Linux NFS. A hard link provides exclusive regular-file publication.
        const temporary = std.fmt.hex(file.file_basename_hex);
        try file.dir.hardLink(&temporary, file.dir, file.dest_sub_path, io, .{ .follow_symlinks = false });
        if (file.file_open) {
            file.file.close(io);
            file.file_open = false;
        }
        // Remove the temporary name before the caller's directory barrier, so
        // successful publication does not leave persistent allocation debris.
        // A failure here is uncertain publication, never permission to retry
        // the caller's accepted work as a different operation.
        file.dir.deleteFile(io, &temporary) catch |err| {
            if (err != error.FileNotFound) return err;
        };
        file.file_exists = false;
    } else {
        try file.link(io);
    }
}

test "file publication uses hard links for named temporaries and refuses every occupied destination" {
    const t = std.testing;
    var temporary = t.tmpDir(.{});
    defer temporary.cleanup();
    var table = t.io.vtable.*;
    const NoRename = struct {
        fn rename(_: ?*anyopaque, _: std.Io.Dir, _: []const u8, _: std.Io.Dir, _: []const u8) std.Io.Dir.RenamePreserveError!void {
            return error.Unexpected;
        }
    };
    table.dirRenamePreserve = NoRename.rename;
    const io: std.Io = .{ .userdata = t.io.userdata, .vtable = &table };
    var staged = try temporary.dir.createFileAtomic(io, "value", .{ .replace = true });
    defer staged.deinit(io);
    try staged.file.writeStreamingAll(io, "original");
    try staged.file.sync(io);
    try link(io, &staged);
    const bytes = try temporary.dir.readFileAlloc(io, "value", t.allocator, .limited(32));
    defer t.allocator.free(bytes);
    try t.expectEqualStrings("original", bytes);
    try temporary.dir.createDir(io, "directory", .default_dir);
    try temporary.dir.symLink(io, "absent", "symlink", .{});
    for ([_][]const u8{ "value", "directory", "symlink" }) |name| {
        var collision = try temporary.dir.createFileAtomic(io, name, .{ .replace = true });
        defer collision.deinit(io);
        try collision.file.writeStreamingAll(io, "replacement");
        try t.expectError(error.PathAlreadyExists, link(io, &collision));
    }
    var unnamed = try temporary.dir.createFileAtomic(io, "other", .{});
    defer unnamed.deinit(io);
    try unnamed.file.writeStreamingAll(io, "other");
    try unnamed.file.sync(io);
    try link(io, &unnamed);
}

test "named file publication preserves uncertain links and cleanup failures" {
    const t = std.testing;
    const Fault = struct {
        var real: *const std.Io.VTable = undefined;
        var cleanup: bool = false;
        fn hardLink(context: ?*anyopaque, from: std.Io.Dir, source: []const u8, to: std.Io.Dir, target: []const u8, options: std.Io.Dir.HardLinkOptions) std.Io.Dir.HardLinkError!void {
            try real.dirHardLink(context, from, source, to, target, options);
            if (!cleanup) return error.Unexpected;
        }
        fn unlink(context: ?*anyopaque, dir: std.Io.Dir, path: []const u8) std.Io.Dir.DeleteFileError!void {
            if (cleanup) return error.Unexpected;
            try real.dirDeleteFile(context, dir, path);
        }
    };
    Fault.real = t.io.vtable;
    var table = t.io.vtable.*;
    table.dirHardLink = Fault.hardLink;
    table.dirDeleteFile = Fault.unlink;
    const io: std.Io = .{ .userdata = t.io.userdata, .vtable = &table };
    for ([_]bool{ false, true }) |cleanup| {
        Fault.cleanup = cleanup;
        var temporary = t.tmpDir(.{});
        defer temporary.cleanup();
        var staged = try temporary.dir.createFileAtomic(io, "value", .{ .replace = true });
        try staged.file.writeStreamingAll(io, "accepted original");
        try staged.file.sync(io);
        try t.expectError(error.Unexpected, link(io, &staged));
        staged.deinit(t.io);
        const bytes = try temporary.dir.readFileAlloc(t.io, "value", t.allocator, .limited(32));
        defer t.allocator.free(bytes);
        try t.expectEqualStrings("accepted original", bytes);
        var conflicting = try temporary.dir.createFileAtomic(t.io, "value", .{ .replace = true });
        defer conflicting.deinit(t.io);
        try conflicting.file.writeStreamingAll(t.io, "different attempt");
        try t.expectError(error.PathAlreadyExists, link(t.io, &conflicting));
    }
}
