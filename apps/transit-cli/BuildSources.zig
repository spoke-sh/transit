//! Explicit repository resolution and immutable source capture; never called by evaluation.
const std = @import("std");
const c = @import("transit_compiler");
const p = @import("transit_query").protocol;
const Self = @This();
pub const Override = @import("BuildOptions.zig").Override;
pub const Pin = struct { name: []const u8, repository: []const u8, revision: []const u8, subdirectory: []const u8, digest: []const u8 };
pub const Lock = struct { format: []const u8, definition: []const u8, dependencies: []const Pin };
pub const Manifest = struct { format: []const u8, definition: []const u8, digest: []const u8 };
pub const Resolution = struct { name: []const u8, repository: []const u8, revision: []const u8, subdirectory: []const u8, digest: []const u8, override: bool };
pub const definition = @tagName(p.Growth.current_definition);
a: std.mem.Allocator,
scratch_parent: std.mem.Allocator,
io: std.Io,
root: std.Io.Dir,
root_path: []const u8,
entry: []const u8,
environment: *const std.process.Environ.Map,
fetch: bool,
diagnostic: *?p.Diagnostic,
overrides: []const Override,
sources: std.ArrayList(c.Source) = .empty,
resolutions: std.ArrayList(Resolution) = .empty,
pins: []const Pin = &.{},
source_bytes: usize = 0,
entries: usize = 0,

pub fn load(self: *Self) ![32]u8 {
    try self.readTree(self.root, "root", "", 0);
    const has_entry = for (self.sources.items) |source| {
        if (std.mem.eql(u8, source.path, self.entry)) break true;
    } else false;
    if (!has_entry) return error.MissingBuildEntry;
    const lock_bytes = read(self.a, self.io, self.root, "transit.lock", 65536) catch |err| if (err == error.FileNotFound) null else return err;
    if (lock_bytes) |bytes| {
        const lock = (try std.json.parseFromSlice(Lock, self.a, bytes, .{ .allocate = .alloc_always })).value;
        try identities(lock.format, lock.definition);
        if (lock.dependencies.len > 255) return error.DependencyLimit;
        for (lock.dependencies, 0..) |pin, i| {
            try c.Graph.validPackage(pin.name);
            try digestBytes(pin.digest);
            if (i > 0 and !std.mem.lessThan(u8, lock.dependencies[i - 1].name, pin.name)) return error.InvalidSourceLock;
        }
        self.pins = lock.dependencies;
    }
    var index: usize = 0;
    while (index < self.sources.items.len) : (index += 1) {
        // Dependency discovery shares the source parser, but never retains its AST.
        var scratch: std.heap.ArenaAllocator = .init(self.scratch_parent);
        defer scratch.deinit();
        var offset: usize = 0;
        const file = c.Syntax.parse(scratch.allocator(), self.sources.items[index].text, &offset) catch |err| {
            self.diagnostic.* = c.Compiler.project(err, c.Compiler.location(self.sources.items[index], offset), null, null);
            return err;
        };
        for (file.dependencies) |dep| try self.resolve(dep);
    }
    for (self.overrides) |override| {
        const used = for (self.resolutions.items) |resolution| {
            if (std.mem.eql(u8, resolution.name, override.name)) break true;
        } else false;
        if (!used) return error.UndeclaredOverride;
    }
    std.mem.sort(Resolution, self.resolutions.items, {}, struct {
        fn less(_: void, left: Resolution, right: Resolution) bool {
            return std.mem.lessThan(u8, left.name, right.name);
        }
    }.less);
    if (!self.fetch) {
        for (self.pins) |pin| {
            const used = for (self.resolutions.items) |resolution| {
                if (std.mem.eql(u8, resolution.name, pin.name)) break true;
            } else false;
            if (!used) return error.StaleSourceLock;
        }
    }
    // Reject import cycles and incomplete source before publishing a new lock.
    var scratch: std.heap.ArenaAllocator = .init(self.scratch_parent);
    defer scratch.deinit();
    var at: usize = 0;
    var offset: usize = 0;
    _ = c.Graph.init(scratch.allocator(), self.sources.items, &at, &offset, 64) catch |err| {
        self.diagnostic.* = c.Compiler.project(err, if (at < self.sources.items.len) c.Compiler.location(self.sources.items[at], offset) else null, null, null);
        return err;
    };
    if (self.fetch) {
        var pins: std.ArrayList(Pin) = .empty;
        for (self.resolutions.items) |resolution| {
            if (resolution.override) return error.FetchWithOverride;
            try pins.append(self.a, .{ .name = resolution.name, .repository = resolution.repository, .revision = resolution.revision, .subdirectory = resolution.subdirectory, .digest = resolution.digest });
        }
        const bytes = try p.Json.valueAlloc(self.a, Lock{ .format = c.Compiler.format, .definition = definition, .dependencies = pins.items });
        if (bytes.len > 65536) return error.SourceLockLimit;
        try atomicFile(self.io, self.root, "transit.lock", bytes);
    }
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.source.resolution.v1\x00");
    c.Graph.hashPart(&hash, c.Compiler.format);
    c.Graph.hashPart(&hash, definition);
    for (self.resolutions.items) |resolution| {
        inline for (.{ "name", "repository", "revision", "subdirectory", "digest" }) |field| c.Graph.hashPart(&hash, @field(resolution, field));
        hash.update(&.{@intFromBool(resolution.override)});
    }
    return hash.finalResult();
}
fn resolve(self: *Self, dependency: c.Syntax.Dependency) !void {
    try c.Graph.validateDependency(dependency);
    try c.Graph.validPackage(dependency.name);
    if (std.mem.eql(u8, dependency.name, "root")) return error.ReservedPackageName;
    for (self.resolutions.items) |prior| if (std.mem.eql(u8, prior.name, dependency.name)) {
        if (!samePin(prior, dependency)) return error.ConflictingDependency;
        return;
    };
    if (self.resolutions.items.len == 255) return error.DependencyLimit;
    const name = try self.a.dupe(u8, dependency.name);
    const override_path = for (self.overrides) |override| {
        if (std.mem.eql(u8, override.name, name)) break override.directory;
    } else null;
    const first = self.sources.items.len;
    if (override_path) |path| {
        const directory = try std.Io.Dir.cwd().openDir(self.io, path, .{ .iterate = true, .follow_symlinks = false });
        defer directory.close(self.io);
        try self.readTree(directory, name, "", 0);
    } else if (self.fetch) {
        try self.fetchTree(name, dependency);
    } else {
        const pin = for (self.pins) |pin| {
            if (std.mem.eql(u8, pin.name, name)) break pin;
        } else return error.MissingSourceLock;
        if (!samePin(pin, dependency)) return error.StaleSourceLock;
        const path = try std.fmt.allocPrint(self.a, ".transit/packages/{s}", .{pin.digest});
        const cache = try self.openCache(path);
        defer cache.close(self.io);
        const manifest = (try std.json.parseFromSlice(Manifest, self.a, try read(self.a, self.io, cache, "manifest.json", 4096), .{ .allocate = .alloc_always })).value;
        try identities(manifest.format, manifest.definition);
        if (!std.mem.eql(u8, pin.digest, manifest.digest)) return error.SourceDigestMismatch;
        const tree = try cache.openDir(self.io, "tree", .{ .iterate = true, .follow_symlinks = false });
        defer tree.close(self.io);
        try self.readTree(tree, name, "", 0);
        const actual = try self.treeHex(name);
        if (!std.mem.eql(u8, pin.digest, actual)) return error.SourceDigestMismatch;
    }
    if (self.sources.items.len == first) return error.EmptySourcePackage;
    const digest = try self.treeHex(name);
    if (self.fetch) try self.storeCache(name, digest);
    try self.resolutions.append(self.a, .{ .name = name, .repository = try self.a.dupe(u8, dependency.repository), .revision = try self.a.dupe(u8, dependency.revision), .subdirectory = try self.a.dupe(u8, dependency.subdirectory), .digest = digest, .override = override_path != null });
}
fn samePin(pin: anytype, dependency: c.Syntax.Dependency) bool {
    return std.mem.eql(u8, pin.repository, dependency.repository) and std.mem.eql(u8, pin.revision, dependency.revision) and std.mem.eql(u8, pin.subdirectory, dependency.subdirectory);
}
fn readTree(self: *Self, directory: std.Io.Dir, package: []const u8, prefix: []const u8, depth: usize) anyerror!void {
    if (depth >= 64) return error.SourceDepthLimit;
    var iterator = directory.iterate();
    while (try iterator.next(self.io)) |entry| {
        self.entries += 1;
        if (self.entries > 16384) return error.SourceTreeEntryLimit;
        if (std.mem.eql(u8, entry.name, ".git") or std.mem.eql(u8, entry.name, ".transit")) continue;
        const path = if (prefix.len == 0) try self.a.dupe(u8, entry.name) else try std.fmt.allocPrint(self.a, "{s}/{s}", .{ prefix, entry.name });
        try c.Graph.validPath(path);
        switch (entry.kind) {
            .directory => {
                const child = try directory.openDir(self.io, entry.name, .{ .iterate = true, .follow_symlinks = false });
                defer child.close(self.io);
                try self.readTree(child, package, path, depth + 1);
            },
            .file => if (std.mem.endsWith(u8, path, ".transit")) {
                try self.add(package, path, try read(self.a, self.io, directory, entry.name, 1024 * 1024));
            },
            else => return error.UnsupportedSourceFileKind,
        }
    }
}
fn add(self: *Self, package: []const u8, path: []const u8, text: []const u8) !void {
    if (self.sources.items.len == 256) return error.SourceFileLimit;
    if (text.len > 1024 * 1024) return error.SourceFileBytesLimit;
    if (!std.unicode.utf8ValidateSlice(text)) return error.InvalidSourceEncoding;
    self.source_bytes += text.len;
    if (self.source_bytes > 16 * 1024 * 1024) return error.SourceBytesLimit;
    try self.sources.append(self.a, .{ .package = package, .path = path, .text = text });
}
fn treeHex(self: *Self, name: []const u8) ![]const u8 {
    const digest = try c.Graph.treeDigest(self.sources.items, name, self.a);
    return self.a.dupe(u8, &std.fmt.bytesToHex(&digest, .lower));
}
fn openCache(self: *Self, path: []const u8) !std.Io.Dir {
    // Traverse one component at a time so intermediate links cannot escape.
    var directory = try self.root.openDir(self.io, ".", .{});
    errdefer directory.close(self.io);
    var components = std.mem.splitScalar(u8, path, '/');
    while (components.next()) |component| {
        const next = try directory.openDir(self.io, component, .{ .iterate = true, .follow_symlinks = false });
        directory.close(self.io);
        directory = next;
    }
    return directory;
}
fn cacheBase(self: *Self) !std.Io.Dir {
    self.root.createDir(self.io, ".transit", .default_dir) catch |err| if (err != error.PathAlreadyExists) return err;
    const base = try self.root.openDir(self.io, ".transit", .{ .follow_symlinks = false });
    defer base.close(self.io);
    base.createDir(self.io, "packages", .default_dir) catch |err| if (err != error.PathAlreadyExists) return err;
    return base.openDir(self.io, "packages", .{ .iterate = true, .follow_symlinks = false });
}
fn storeCache(self: *Self, name: []const u8, digest: []const u8) !void {
    const base = try self.cacheBase();
    defer base.close(self.io);
    const temporary = try temporaryDirectory(self.a, self.io, base);
    defer base.deleteTree(self.io, temporary) catch {};
    const directory = try base.openDir(self.io, temporary, .{ .iterate = true });
    defer directory.close(self.io);
    try directory.createDir(self.io, "tree", .default_dir);
    const tree = try directory.openDir(self.io, "tree", .{});
    defer tree.close(self.io);
    for (self.sources.items) |source| if (std.mem.eql(u8, source.package, name)) {
        if (std.fs.path.dirname(source.path)) |parent| try tree.createDirPath(self.io, parent);
        try writeFile(self.io, tree, source.path, source.text);
    };
    const manifest = try p.Json.valueAlloc(self.a, Manifest{ .format = c.Compiler.format, .definition = definition, .digest = digest });
    try writeFile(self.io, directory, "manifest.json", manifest);
    try syncDirectory(directory);
    base.renamePreserve(temporary, base, digest, self.io) catch |err| {
        if (err != error.PathAlreadyExists) return err;
        const existing = try base.openDir(self.io, digest, .{ .follow_symlinks = false });
        defer existing.close(self.io);
        const old_manifest = try read(self.a, self.io, existing, "manifest.json", 4096);
        if (!std.mem.eql(u8, manifest, old_manifest)) return error.SourceDigestMismatch;
        const old_tree = try existing.openDir(self.io, "tree", .{ .iterate = true, .follow_symlinks = false });
        defer old_tree.close(self.io);
        var verifier = self.*;
        verifier.sources = .empty;
        verifier.source_bytes = 0;
        try verifier.readTree(old_tree, name, "", 0);
        if (!std.mem.eql(u8, digest, try verifier.treeHex(name))) return error.SourceDigestMismatch;
    };
    try syncDirectory(base);
}
fn fetchTree(self: *Self, name: []const u8, dependency: c.Syntax.Dependency) !void {
    if (!(std.mem.startsWith(u8, dependency.repository, "https://") or std.mem.startsWith(u8, dependency.repository, "file://") or std.fs.path.isAbsolute(dependency.repository))) return error.UnsupportedRepositoryTransport;
    const base = try self.cacheBase();
    defer base.close(self.io);
    const temporary = try temporaryDirectory(self.a, self.io, base);
    defer base.deleteTree(self.io, temporary) catch {};
    const path = try std.fs.path.resolve(self.a, &.{ self.root_path, ".transit/packages", temporary });
    _ = try self.git(&.{ "init", "--bare", "--template=", path }, 4096);
    _ = try self.git(&.{ "--git-dir", path, "fetch", "--no-tags", "--no-recurse-submodules", "--depth=1", "--filter=blob:none", "--", dependency.repository, dependency.revision }, 4096);
    const commit = try self.git(&.{ "--git-dir", path, "rev-parse", "FETCH_HEAD^{commit}" }, 128);
    if (!std.ascii.eqlIgnoreCase(std.mem.trim(u8, commit, "\r\n"), dependency.revision)) return error.RepositoryRevisionMismatch;
    const tree_spec = try std.fmt.allocPrint(self.a, "{s}:{s}", .{ dependency.revision, dependency.subdirectory });
    const listing = try self.git(&.{ "--git-dir", path, "ls-tree", "-rz", tree_spec }, 4 * 1024 * 1024);
    var entries = std.mem.splitScalar(u8, listing, 0);
    while (entries.next()) |entry| {
        if (entry.len == 0) continue;
        self.entries += 1;
        if (self.entries > 16384) return error.SourceTreeEntryLimit;
        const tab = std.mem.indexOfScalar(u8, entry, '\t') orelse return error.InvalidRepositoryTree;
        const relative = entry[tab + 1 ..];
        try c.Graph.validPath(relative);
        var components = std.mem.splitScalar(u8, relative, '/');
        const excluded = while (components.next()) |component| {
            if (std.mem.eql(u8, component, ".git") or std.mem.eql(u8, component, ".transit")) break true;
        } else false;
        if (excluded) continue;
        if (!(std.mem.startsWith(u8, entry, "100644 blob ") or std.mem.startsWith(u8, entry, "100755 blob "))) return error.UnsupportedSourceFileKind;
        if (!std.mem.endsWith(u8, relative, ".transit")) continue;
        const blob = entry[12..tab];
        try self.add(name, try self.a.dupe(u8, relative), try self.git(&.{ "--git-dir", path, "cat-file", "blob", blob }, 1024 * 1024));
    }
}
fn git(self: *Self, arguments: []const []const u8, limit: usize) ![]const u8 {
    var env: std.process.Environ.Map = .init(self.a);
    defer env.deinit();
    inline for (.{ "PATH", "SSL_CERT_FILE", "SSL_CERT_DIR" }) |key| if (self.environment.get(key)) |value| try env.put(key, value);
    try env.put("GIT_CONFIG_NOSYSTEM", "1");
    try env.put("GIT_CONFIG_GLOBAL", "/dev/null");
    try env.put("GIT_TERMINAL_PROMPT", "0");
    try env.put("GIT_NO_REPLACE_OBJECTS", "1");
    var argv: std.ArrayList([]const u8) = .empty;
    try argv.appendSlice(self.a, &.{ "git", "-c", "core.hooksPath=/dev/null", "-c", "core.fsmonitor=false", "-c", "credential.helper=", "-c", "protocol.allow=never", "-c", "protocol.https.allow=always", "-c", "protocol.file.allow=always" });
    try argv.appendSlice(self.a, arguments);
    const result = try std.process.run(self.a, self.io, .{ .argv = argv.items, .environ_map = &env, .stdout_limit = .limited(limit), .stderr_limit = .limited(65536), .timeout = (std.Io.Timeout{ .duration = .{ .raw = .fromSeconds(120), .clock = .awake } }).toDeadline(self.io) });
    if (result.term != .exited or result.term.exited != 0) return error.RepositoryFetchFailed;
    if (result.stdout.len > limit) return error.RepositoryOutputLimit;
    return result.stdout;
}
pub fn identities(format: []const u8, native: []const u8) !void {
    if (!std.mem.eql(u8, format, c.Compiler.format) or !std.mem.eql(u8, native, definition)) return error.IncompatibleSourceDefinition;
}
fn digestBytes(text: []const u8) !void {
    if (text.len != 64) return error.InvalidSourceDigest;
    for (text) |byte| if (!std.ascii.isDigit(byte) and !(byte >= 'a' and byte <= 'f')) return error.InvalidSourceDigest;
}
pub fn read(a: std.mem.Allocator, io: std.Io, directory: std.Io.Dir, path: []const u8, limit: usize) ![]u8 {
    const file = try directory.openFile(io, path, .{ .follow_symlinks = false, .resolve_beneath = true });
    defer file.close(io);
    if ((try file.stat(io)).kind != .file) return error.UnsupportedSourceFileKind;
    var reader = file.reader(io, &.{});
    const bytes = reader.interface.allocRemaining(a, .limited(limit + 1)) catch |err| return if (err == error.ReadFailed) reader.err.? else err;
    if (bytes.len > limit) return error.SourceReadLimit;
    return bytes;
}
pub fn temporaryDirectory(a: std.mem.Allocator, io: std.Io, parent: std.Io.Dir) ![]const u8 {
    var random: [16]u8 = undefined;
    io.random(&random);
    const path = try std.fmt.allocPrint(a, ".pending-{s}", .{std.fmt.bytesToHex(&random, .lower)});
    try parent.createDir(io, path, .fromMode(0o700));
    return path;
}
pub fn writeFile(io: std.Io, directory: std.Io.Dir, path: []const u8, bytes: []const u8) !void {
    const file = try directory.createFile(io, path, .{ .exclusive = true, .permissions = .fromMode(0o600) });
    defer file.close(io);
    try file.writeStreamingAll(io, bytes);
    try file.sync(io);
}
pub fn atomicFile(io: std.Io, directory: std.Io.Dir, path: []const u8, bytes: []const u8) !void {
    var file = try directory.createFileAtomic(io, path, .{ .replace = true, .permissions = .fromMode(0o600) });
    defer file.deinit(io);
    try file.file.writeStreamingAll(io, bytes);
    try file.file.sync(io);
    try file.replace(io);
    try syncDirectory(directory);
}
pub fn syncDirectory(directory: std.Io.Dir) !void {
    if (std.c.fsync(directory.handle) != 0) return error.BuildSyncFailed;
}
