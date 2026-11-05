//! Private directory assembly and explicit publication. The manager holds the
//! installation lock. No authority operation may use an uncommitted assembly.
//! Exclusive mkdir reserves the destination; immutable claim/commit records bind
//! it to one durable intent. Unmarked directories are never adopted on recovery.
const std = @import("std");
const q = @import("transit_query");
const Files = @import("Files.zig");
const cwd = std.Io.Dir.cwd;
const claim = ".transit-claim";
const committed = ".transit-published";
const assembly = ".transit-assembly";
pub const pending_prefix = ".publishing-";
const max_manifest = 256 * 1024;
const max_bytes = 1024 * 1024;
const Entry = struct { path: []const u8, kind: enum { directory, file }, size: u64 = 0, digest: [32]u8 = @splat(0) };
const Manifest = struct {
    definition: q.protocol.Growth.Definition,
    binding: [32]u8,
    destination: []const u8,
    source: []const u8,
    entries: []const Entry,
};

pub fn binding(allocator: std.mem.Allocator, value: anytype) ![32]u8 {
    const bytes = try q.protocol.Json.valueAlloc(allocator, value);
    defer allocator.free(bytes);
    return digest(bytes);
}
fn digest(bytes: []const u8) [32]u8 {
    var result: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &result, .{});
    return result;
}
fn sync(io: std.Io, dir: std.Io.Dir) !void {
    const file: std.Io.File = .{ .handle = dir.handle, .flags = .{ .nonblocking = false } };
    try file.sync(io);
}
fn privateDir(io: std.Io, parent: std.Io.Dir, name: []const u8) !std.Io.Dir {
    return parent.openDir(io, name, .{ .iterate = true, .follow_symlinks = false });
}
fn read(io: std.Io, allocator: std.mem.Allocator, dir: std.Io.Dir, name: []const u8, limit: usize) ![]u8 {
    const file = try dir.openFile(io, name, .{ .follow_symlinks = false });
    defer file.close(io);
    const stat = try file.stat(io);
    if (stat.kind != .file or stat.size > limit) return error.InvalidDirectoryPublication;
    const bytes = try allocator.alloc(u8, @intCast(stat.size));
    errdefer allocator.free(bytes);
    if (try file.readPositionalAll(io, bytes, 0) != bytes.len) return error.InvalidDirectoryPublication;
    return bytes;
}
fn same(io: std.Io, allocator: std.mem.Allocator, dir: std.Io.Dir, name: []const u8, expected: []const u8) !bool {
    const bytes = read(io, allocator, dir, name, max_manifest) catch |err| {
        if (err == error.FileNotFound) return false;
        return err;
    };
    defer allocator.free(bytes);
    if (!std.mem.eql(u8, bytes, expected)) return error.DirectoryPublicationConflict;
    return true;
}
fn safeName(name: []const u8) bool {
    return name.len != 0 and !std.mem.eql(u8, name, ".") and !std.mem.eql(u8, name, "..") and std.mem.indexOfAny(u8, name, "/\\\x00") == null;
}
fn validate(manifest: Manifest, destination: []const u8, expected: [32]u8) !void {
    if (manifest.definition != q.protocol.Growth.current_definition or !std.mem.eql(u8, &manifest.binding, &expected)) return error.InstallationIdentityMismatch;
    if (!safeName(manifest.destination) or !std.mem.eql(u8, manifest.destination, std.fs.path.basename(destination)) or
        !std.mem.startsWith(u8, manifest.source, ".creating-") or manifest.source.len != 42 or manifest.entries.len > 128) return error.InvalidDirectoryPublication;
    var nonce: [16]u8 = undefined;
    _ = std.fmt.hexToBytes(&nonce, manifest.source[10..]) catch return error.InvalidDirectoryPublication;
    var total: u64 = 0;
    for (manifest.entries, 0..) |entry, index| {
        if (entry.path.len > 512) return error.InvalidDirectoryPublication;
        var parts = std.mem.splitScalar(u8, entry.path, '/');
        var depth: usize = 0;
        while (parts.next()) |part| {
            if (!safeName(part) or std.mem.startsWith(u8, part, ".transit-")) return error.InvalidDirectoryPublication;
            depth += 1;
        }
        if (depth > 8) return error.InvalidDirectoryPublication;
        for (manifest.entries[0..index]) |previous| if (std.mem.eql(u8, previous.path, entry.path)) return error.InvalidDirectoryPublication;
        if (std.fs.path.dirname(entry.path)) |parent| {
            var found = false;
            for (manifest.entries[0..index]) |previous| if (previous.kind == .directory and std.mem.eql(u8, previous.path, parent)) {
                found = true;
            };
            if (!found) return error.InvalidDirectoryPublication;
        }
        total = std.math.add(u64, total, entry.size) catch return error.InvalidDirectoryPublication;
        if (total > max_bytes or (entry.kind == .directory and entry.size != 0)) return error.InvalidDirectoryPublication;
    }
}

/// Qualify the actual parent using synthetic data before generating credentials.
/// This establishes local syscall capabilities, not multi-client NFS durability.
pub fn probe(io: std.Io, allocator: std.mem.Allocator, parent: std.Io.Dir) !void {
    var nonce: [16]u8 = undefined;
    try io.randomSecure(&nonce);
    const name = try std.fmt.allocPrint(allocator, ".probe-{s}", .{std.fmt.bytesToHex(nonce, .lower)});
    defer allocator.free(name);
    try parent.createDir(io, name, .fromMode(0o700));
    const dir = try privateDir(io, parent, name);
    defer dir.close(io);
    defer parent.deleteTree(io, name) catch {};
    var file = try dir.createFileAtomic(io, "published", .{ .replace = true, .permissions = .fromMode(0o600) });
    defer file.deinit(io);
    try file.file.writeStreamingAll(io, "transit filesystem capability probe\n");
    try file.file.sync(io);
    q.storage.FilePublication.link(io, &file) catch |err| {
        if (err == error.OperationUnsupported) return error.FilesystemPublicationUnsupported;
        return err;
    };
    dir.hardLink("published", dir, "published", io, .{}) catch |err| {
        if (err == error.OperationUnsupported) return error.FilesystemPublicationUnsupported;
        if (err != error.PathAlreadyExists) return err;
        try sync(io, dir);
        try sync(io, parent);
        return;
    };
    return error.FilesystemPublicationUnsupported;
}

pub fn stage(io: std.Io, allocator: std.mem.Allocator, destination: []const u8) ![]const u8 {
    const parent_path = std.fs.path.dirname(destination) orelse return error.InvalidDirectoryPublication;
    const parent = try privateDir(io, cwd(), parent_path);
    defer parent.close(io);
    try probe(io, allocator, parent);
    var nonce: [16]u8 = undefined;
    try io.randomSecure(&nonce);
    const path = try std.fmt.allocPrint(allocator, "{s}/.creating-{s}", .{ parent_path, std.fmt.bytesToHex(nonce, .lower) });
    try cwd().createDir(io, path, .fromMode(0o700));
    return path;
}

fn inventory(io: std.Io, allocator: std.mem.Allocator, directory: std.Io.Dir, prefix: []const u8, entries: *std.ArrayList(Entry), total: *u64, depth: usize) !void {
    if (depth > 8) return error.DirectoryAssemblyTooLarge;
    var iterator = directory.iterate();
    while (try iterator.next(io)) |item| {
        if (!safeName(item.name) or std.mem.startsWith(u8, item.name, ".transit-")) return error.InvalidDirectoryPublication;
        if (entries.items.len == 128) return error.DirectoryAssemblyTooLarge;
        const path = if (prefix.len == 0) try allocator.dupe(u8, item.name) else try std.fs.path.join(allocator, &.{ prefix, item.name });
        if (path.len > 512) return error.DirectoryAssemblyTooLarge;
        switch (item.kind) {
            .directory => {
                try entries.append(allocator, .{ .path = path, .kind = .directory });
                const child = try privateDir(io, directory, item.name);
                defer child.close(io);
                try inventory(io, allocator, child, path, entries, total, depth + 1);
                try sync(io, child);
            },
            .file => {
                const bytes = try read(io, allocator, directory, item.name, max_bytes);
                defer {
                    std.crypto.secureZero(u8, bytes);
                    allocator.free(bytes);
                }
                total.* += bytes.len;
                if (total.* > max_bytes) return error.DirectoryAssemblyTooLarge;
                try entries.append(allocator, .{ .path = path, .kind = .file, .size = bytes.len, .digest = digest(bytes) });
                const file = try directory.openFile(io, item.name, .{ .follow_symlinks = false });
                defer file.close(io);
                try file.sync(io);
            },
            else => return error.InvalidDirectoryPublication,
        }
    }
}
fn parentOf(io: std.Io, root: std.Io.Dir, path: []const u8) !std.Io.Dir {
    var dir = try privateDir(io, root, ".");
    errdefer dir.close(io);
    if (std.fs.path.dirname(path)) |ancestors| {
        var parts = std.mem.splitScalar(u8, ancestors, '/');
        while (parts.next()) |part| {
            const next = try privateDir(io, dir, part);
            dir.close(io);
            dir = next;
        }
    }
    return dir;
}
fn verifyFile(io: std.Io, allocator: std.mem.Allocator, dir: std.Io.Dir, entry: Entry) !void {
    const bytes = try read(io, allocator, dir, std.fs.path.basename(entry.path), max_bytes);
    defer {
        std.crypto.secureZero(u8, bytes);
        allocator.free(bytes);
    }
    if (bytes.len != entry.size or !std.mem.eql(u8, &digest(bytes), &entry.digest)) return error.DirectoryPublicationConflict;
}
fn copy(io: std.Io, allocator: std.mem.Allocator, source: std.Io.Dir, target: std.Io.Dir, manifest: Manifest) !void {
    for (manifest.entries) |entry| {
        const from = try parentOf(io, source, entry.path);
        defer from.close(io);
        const to = try parentOf(io, target, entry.path);
        defer to.close(io);
        const name = std.fs.path.basename(entry.path);
        switch (entry.kind) {
            .directory => {
                to.createDir(io, name, .fromMode(0o700)) catch |err| {
                    if (err != error.PathAlreadyExists) return err;
                };
                const child = try privateDir(io, to, name);
                defer child.close(io);
                try sync(io, child);
            },
            .file => {
                try verifyFile(io, allocator, from, entry);
                from.hardLink(name, to, name, io, .{ .follow_symlinks = false }) catch |err| {
                    if (err != error.PathAlreadyExists) return err;
                };
                try verifyFile(io, allocator, to, entry);
                const file = try to.openFile(io, name, .{ .follow_symlinks = false });
                defer file.close(io);
                try file.sync(io);
            },
        }
        try sync(io, to);
    }
}
fn verifyTree(io: std.Io, allocator: std.mem.Allocator, directory: std.Io.Dir, prefix: []const u8, manifest: Manifest) !void {
    var iterator = directory.iterate();
    while (try iterator.next(io)) |item| {
        if (prefix.len == 0 and (std.mem.eql(u8, item.name, claim) or std.mem.eql(u8, item.name, committed))) continue;
        const path = if (prefix.len == 0) try allocator.dupe(u8, item.name) else try std.fs.path.join(allocator, &.{ prefix, item.name });
        defer allocator.free(path);
        var found = false;
        for (manifest.entries) |entry| {
            if (!std.mem.eql(u8, entry.path, path)) continue;
            if ((entry.kind == .directory and item.kind != .directory) or (entry.kind == .file and item.kind != .file)) return error.DirectoryPublicationConflict;
            found = true;
            break;
        }
        if (!found) return error.DirectoryPublicationConflict;
        if (item.kind == .directory) {
            const child = try privateDir(io, directory, item.name);
            defer child.close(io);
            try verifyTree(io, allocator, child, path, manifest);
        }
    }
}
fn finish(io: std.Io, allocator: std.mem.Allocator, parent: std.Io.Dir, pending: []const u8, bytes: []const u8, manifest: Manifest, fresh: bool) !void {
    // A commit may have succeeded even if its response or sync failed.
    // Committed directories contain mutable runtime state; never recopy them.
    const existing = privateDir(io, parent, manifest.destination) catch |err| value: {
        if (err != error.FileNotFound) return err;
        break :value null;
    };
    if (existing) |target| {
        defer target.close(io);
        if (try same(io, allocator, target, committed, bytes)) {
            if (!try same(io, allocator, target, claim, bytes)) return error.DirectoryPublicationConflict;
            try sync(io, target);
            try sync(io, parent);
            try cleanup(io, allocator, parent, pending, bytes, manifest);
            return;
        }
        // Recovery requires positive ownership. In particular, mkdir followed
        // by a crash before the claim is durable cannot authorize adoption.
        if (fresh) return error.PathAlreadyExists;
        if (!try same(io, allocator, target, claim, bytes)) return error.DirectoryPublicationOwnershipUnknown;
    } else {
        try parent.createDir(io, manifest.destination, .fromMode(0o700));
        const target = try privateDir(io, parent, manifest.destination);
        defer target.close(io);
        try parent.hardLink(pending, target, claim, io, .{ .follow_symlinks = false });
        try sync(io, target);
        try sync(io, parent);
    }
    const source = try privateDir(io, parent, manifest.source);
    defer source.close(io);
    const target = try privateDir(io, parent, manifest.destination);
    defer target.close(io);
    if (!try same(io, allocator, source, assembly, bytes) or !try same(io, allocator, target, claim, bytes)) return error.DirectoryPublicationConflict;
    try copy(io, allocator, source, target, manifest);
    try verifyTree(io, allocator, target, "", manifest);
    try parent.hardLink(pending, target, committed, io, .{ .follow_symlinks = false });
    try sync(io, target);
    try sync(io, parent);
    try cleanup(io, allocator, parent, pending, bytes, manifest);
}
fn cleanup(io: std.Io, allocator: std.mem.Allocator, parent: std.Io.Dir, pending: []const u8, bytes: []const u8, manifest: Manifest) !void {
    // Remove only the recorded synthetic assembly. Unknown extra children and
    // all old unjournaled assemblies remain intact. Cleanup never touches target.
    if (privateDir(io, parent, manifest.source)) |source| {
        defer source.close(io);
        // A missing assembly marker may be a lost cleanup observation or an
        // unrelated directory reusing the name. Preserve that directory in both
        // cases; the committed target can finish without adopting it.
        if (try same(io, allocator, source, assembly, bytes)) {
            var index = manifest.entries.len;
            while (index != 0) {
                index -= 1;
                const entry = manifest.entries[index];
                const dir = parentOf(io, source, entry.path) catch |err| {
                    if (err == error.FileNotFound) continue;
                    return err;
                };
                defer dir.close(io);
                if (entry.kind == .file) dir.deleteFile(io, std.fs.path.basename(entry.path)) catch |err| {
                    if (err != error.FileNotFound) return err;
                } else dir.deleteDir(io, std.fs.path.basename(entry.path)) catch |err| {
                    if (err != error.FileNotFound) return err;
                };
                try sync(io, dir);
            }
            source.deleteFile(io, assembly) catch |err| {
                if (err != error.FileNotFound) return err;
            };
            try parent.deleteDir(io, manifest.source);
            try sync(io, parent);
        }
    } else |err| if (err != error.FileNotFound) return err;
    try parent.deleteFile(io, pending);
    try sync(io, parent);
}

pub fn publish(io: std.Io, allocator: std.mem.Allocator, source_path: []const u8, destination: []const u8, expected: [32]u8) !void {
    var scratch: std.heap.ArenaAllocator = .init(allocator);
    defer scratch.deinit();
    const a = scratch.allocator();
    const parent_path = std.fs.path.dirname(destination).?;
    if (!std.mem.eql(u8, parent_path, std.fs.path.dirname(source_path).?)) return error.InvalidDirectoryPublication;
    const parent = try privateDir(io, cwd(), parent_path);
    defer parent.close(io);
    const source = try privateDir(io, parent, std.fs.path.basename(source_path));
    defer source.close(io);
    var entries: std.ArrayList(Entry) = .empty;
    var total: u64 = 0;
    try inventory(io, a, source, "", &entries, &total, 0);
    const manifest: Manifest = .{ .definition = q.protocol.Growth.current_definition, .binding = expected, .destination = std.fs.path.basename(destination), .source = std.fs.path.basename(source_path), .entries = entries.items };
    try validate(manifest, destination, expected);
    const bytes = try q.protocol.Json.valueAlloc(a, manifest);
    if (bytes.len > max_manifest) return error.DirectoryAssemblyTooLarge;
    try Files.write(io, try std.fs.path.join(a, &.{ source_path, assembly }), bytes);
    const pending = try std.fmt.allocPrint(a, "{s}{s}", .{ pending_prefix, manifest.destination });
    try source.hardLink(assembly, parent, pending, io, .{ .follow_symlinks = false });
    try sync(io, source);
    try sync(io, parent);
    try finish(io, a, parent, pending, bytes, manifest, true);
}

pub fn recover(io: std.Io, allocator: std.mem.Allocator, destination: []const u8, expected: [32]u8) !bool {
    var scratch: std.heap.ArenaAllocator = .init(allocator);
    defer scratch.deinit();
    const a = scratch.allocator();
    const parent = try privateDir(io, cwd(), std.fs.path.dirname(destination).?);
    defer parent.close(io);
    const pending = try std.fmt.allocPrint(a, "{s}{s}", .{ pending_prefix, std.fs.path.basename(destination) });
    const bytes = read(io, a, parent, pending, max_manifest) catch |err| {
        if (err == error.FileNotFound) return false;
        return err;
    };
    const parsed = try std.json.parseFromSlice(Manifest, a, bytes, .{ .allocate = .alloc_always });
    try validate(parsed.value, destination, expected);
    try finish(io, a, parent, pending, bytes, parsed.value, false);
    return true;
}

pub fn check(io: std.Io, allocator: std.mem.Allocator, destination: []const u8, expected: [32]u8) !void {
    const dir = try privateDir(io, cwd(), destination);
    defer dir.close(io);
    const bytes = read(io, allocator, dir, committed, max_manifest) catch |err| {
        if (err == error.FileNotFound) return error.DirectoryPublicationIncomplete;
        return err;
    };
    defer allocator.free(bytes);
    const parsed = try std.json.parseFromSlice(Manifest, allocator, bytes, .{ .allocate = .alloc_always });
    defer parsed.deinit();
    try validate(parsed.value, destination, expected);
    if (!try same(io, allocator, dir, claim, bytes)) return error.DirectoryPublicationConflict;
}

pub fn recoverChildren(io: std.Io, allocator: std.mem.Allocator, path: []const u8, expected: [32]u8) !void {
    const dir = try privateDir(io, cwd(), path);
    defer dir.close(io);
    var iterator = dir.iterate();
    while (try iterator.next(io)) |entry| {
        if (!std.mem.startsWith(u8, entry.name, pending_prefix)) continue;
        const name = entry.name[pending_prefix.len..];
        if (!safeName(name)) return error.InvalidDirectoryPublication;
        const destination = try std.fs.path.join(allocator, &.{ path, name });
        defer allocator.free(destination);
        _ = try recover(io, allocator, destination, expected);
    }
}

const Fault = struct {
    var real: *const std.Io.VTable = undefined;
    var count: usize = 0;
    var fail_at: usize = 0;
    var after: bool = false;
    fn before() bool {
        count += 1;
        return count == fail_at;
    }
    fn syncFile(context: ?*anyopaque, file: std.Io.File) std.Io.File.SyncError!void {
        const fail = before();
        if (fail and !after) return error.Unexpected;
        try real.fileSync(context, file);
        if (fail) return error.Unexpected;
    }
    fn mkdir(context: ?*anyopaque, dir: std.Io.Dir, path: []const u8, mode: std.Io.Dir.Permissions) std.Io.Dir.CreateDirError!void {
        const fail = before();
        if (fail and !after) return error.Unexpected;
        try real.dirCreateDir(context, dir, path, mode);
        if (fail) return error.Unexpected;
    }
    fn linkFile(context: ?*anyopaque, from: std.Io.Dir, source: []const u8, to: std.Io.Dir, target: []const u8, options: std.Io.Dir.HardLinkOptions) std.Io.Dir.HardLinkError!void {
        const fail = before();
        if (fail and !after) return error.Unexpected;
        try real.dirHardLink(context, from, source, to, target, options);
        if (fail) return error.Unexpected;
    }
    fn rename(context: ?*anyopaque, from: std.Io.Dir, source: []const u8, to: std.Io.Dir, target: []const u8) std.Io.Dir.RenameError!void {
        const fail = before();
        if (fail and !after) return error.Unexpected;
        try real.dirRename(context, from, source, to, target);
        if (fail) return error.Unexpected;
    }
    fn removeFile(context: ?*anyopaque, dir: std.Io.Dir, path: []const u8) std.Io.Dir.DeleteFileError!void {
        const fail = before();
        if (fail and !after) return error.Unexpected;
        try real.dirDeleteFile(context, dir, path);
        if (fail) return error.Unexpected;
    }
    fn removeDir(context: ?*anyopaque, dir: std.Io.Dir, path: []const u8) std.Io.Dir.DeleteDirError!void {
        const fail = before();
        if (fail and !after) return error.Unexpected;
        try real.dirDeleteDir(context, dir, path);
        if (fail) return error.Unexpected;
    }
};
fn sample(io: std.Io, allocator: std.mem.Allocator, destination: []const u8) ![]const u8 {
    const source = try stage(io, allocator, destination);
    try Files.write(io, try std.fs.path.join(allocator, &.{ source, "record" }), "original identity");
    const directory = try privateDir(io, cwd(), source);
    defer directory.close(io);
    try directory.createDir(io, "data", .fromMode(0o700));
    try Files.write(io, try std.fs.path.join(allocator, &.{ source, "data", "marker" }), "original data");
    return source;
}

test "directory publication reconciles every interrupted publication barrier with exact identities" {
    const t = std.testing;
    Fault.real = t.io.vtable;
    var table = t.io.vtable.*;
    table.fileSync = Fault.syncFile;
    table.dirCreateDir = Fault.mkdir;
    table.dirHardLink = Fault.linkFile;
    table.dirRename = Fault.rename;
    table.dirDeleteFile = Fault.removeFile;
    table.dirDeleteDir = Fault.removeDir;
    const io: std.Io = .{ .userdata = t.io.userdata, .vtable = &table };
    var barriers: usize = 0;
    var recovered: usize = 0;
    var refused: usize = 0;
    for ([_]bool{ false, true }) |after| {
        var index: usize = 0;
        while (index <= barriers) : (index += 1) {
            var temporary = t.tmpDir(.{});
            defer temporary.cleanup();
            var arena: std.heap.ArenaAllocator = .init(t.allocator);
            defer arena.deinit();
            const a = arena.allocator();
            const root = try temporary.dir.realPathFileAlloc(t.io, ".", a);
            const destination = try std.fs.path.join(a, &.{ root, "destination" });
            const source = try sample(t.io, a, destination);
            Fault.count = 0;
            Fault.fail_at = index;
            Fault.after = after;
            publish(io, a, source, destination, @splat(7)) catch |err| {
                try t.expectEqual(error.Unexpected, err);
            };
            if (index == 0) barriers = Fault.count;
            const outcome = recover(t.io, a, destination, @splat(7)) catch |err| {
                try t.expectEqual(error.DirectoryPublicationOwnershipUnknown, err);
                // Only the mkdir/claim gap is ambiguous. No contents are merged
                // into this unmarked directory, and the exact assembly remains.
                const target = try privateDir(t.io, cwd(), destination);
                defer target.close(t.io);
                var iterator = target.iterate();
                try t.expect(try iterator.next(t.io) == null);
                const original = try cwd().readFileAlloc(t.io, try std.fs.path.join(a, &.{ source, "record" }), a, .limited(64));
                try t.expectEqualStrings("original identity", original);
                refused += 1;
                continue;
            };
            if (outcome) recovered += 1;
            const committed_path = try std.fs.path.join(a, &.{ destination, committed });
            if (cwd().access(t.io, committed_path, .{})) |_| {
                try check(t.io, a, destination, @splat(7));
                try t.expectError(error.InstallationIdentityMismatch, check(t.io, a, destination, @splat(8)));
                const original = try cwd().readFileAlloc(t.io, try std.fs.path.join(a, &.{ destination, "record" }), a, .limited(64));
                try t.expectEqualStrings("original identity", original);
                const marker = try cwd().readFileAlloc(t.io, try std.fs.path.join(a, &.{ destination, "data", "marker" }), a, .limited(64));
                try t.expectEqualStrings("original data", marker);
            } else |err| {
                try t.expectEqual(error.FileNotFound, err);
                try t.expect(!outcome);
            }
        }
    }
    try t.expect(barriers > 20 and recovered > 20 and refused != 0);
}

test "directory publication refuses occupied paths and never adopts old staging" {
    const t = std.testing;
    for ([_]enum { empty, populated, file, symlink }{ .empty, .populated, .file, .symlink }) |kind| {
        var temporary = t.tmpDir(.{});
        defer temporary.cleanup();
        var arena: std.heap.ArenaAllocator = .init(t.allocator);
        defer arena.deinit();
        const a = arena.allocator();
        const root = try temporary.dir.realPathFileAlloc(t.io, ".", a);
        const destination = try std.fs.path.join(a, &.{ root, "destination" });
        const source = try sample(t.io, a, destination);
        try t.expect(!try recover(t.io, a, destination, @splat(7)));
        switch (kind) {
            .empty => try temporary.dir.createDir(t.io, "destination", .default_dir),
            .populated => {
                try temporary.dir.createDir(t.io, "destination", .default_dir);
                try Files.write(t.io, try std.fs.path.join(a, &.{ destination, "foreign" }), "preserve");
            },
            .file => try Files.write(t.io, destination, "preserve"),
            .symlink => try temporary.dir.symLink(t.io, "missing", "destination", .{}),
        }
        const before = try temporary.dir.statFile(t.io, "destination", .{ .follow_symlinks = false });
        try t.expectError(if (kind == .empty or kind == .populated) error.PathAlreadyExists else error.NotDir, publish(t.io, a, source, destination, @splat(7)));
        const after = try temporary.dir.statFile(t.io, "destination", .{ .follow_symlinks = false });
        try t.expectEqual(before.inode, after.inode);
        try t.expectEqual(before.kind, after.kind);
    }
}

test "committed publication cleanup never restores initial mutable contents" {
    const t = std.testing;
    var temporary = t.tmpDir(.{});
    defer temporary.cleanup();
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const root = try temporary.dir.realPathFileAlloc(t.io, ".", a);
    const destination = try std.fs.path.join(a, &.{ root, "destination" });
    const source = try sample(t.io, a, destination);
    try publish(t.io, a, source, destination, @splat(7));
    const target = try privateDir(t.io, temporary.dir, "destination");
    defer target.close(t.io);
    // Simulate a lost cleanup observation: the original intent is still present
    // after the committed application has already changed its mutable record.
    try target.hardLink(committed, temporary.dir, ".publishing-destination", t.io, .{});
    try Files.write(t.io, try std.fs.path.join(a, &.{ destination, "record" }), "accepted later progress");
    try cwd().createDir(t.io, source, .default_dir);
    const foreign = try std.fs.path.join(a, &.{ source, "record" });
    try Files.write(t.io, foreign, "foreign reused path");
    try t.expect(try recover(t.io, a, destination, @splat(7)));
    const current = try read(t.io, a, target, "record", 64);
    try t.expectEqualStrings("accepted later progress", current);
    const preserved = try cwd().readFileAlloc(t.io, foreign, a, .limited(64));
    try t.expectEqualStrings("foreign reused path", preserved);
    try check(t.io, a, destination, @splat(7));
    // Even a matching commit cannot excuse a missing ownership claim.
    try target.deleteFile(t.io, claim);
    try t.expectError(error.DirectoryPublicationConflict, check(t.io, a, destination, @splat(7)));
}
