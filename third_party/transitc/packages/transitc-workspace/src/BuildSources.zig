//! Explicit repository resolution and immutable source capture; never called by evaluation.
const std = @import("std");
const c = @import("transit_compiler");
const p = @import("transit_protocol");
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
report: ?*c.SourceDiagnostic.Report = null,
overrides: []const Override,
sources: std.ArrayList(c.Source) = .empty,
resolutions: std.ArrayList(Resolution) = .empty,
pins: []const Pin = &.{},
source_bytes: usize = 0,
entries: usize = 0,
entry_default: ?[]const u8 = null,
links: std.ArrayList(struct { package: []const u8, path: []const u8 }) = .empty,

pub fn load(self: *Self) ![32]u8 {
    self.loadEntry() catch |err| {
        var buffer: [4096]u8 = undefined;
        const full = std.fmt.bufPrint(&buffer, "{s}/{s}", .{ self.root_path, self.entry }) catch self.entry;
        self.note(err, "root", full, "read selected build entry", null);
        return err;
    };
    try self.readTree(self.root, "root", "", 0);
    sortSlice(self.sources.items[1..]);
    self.loadLock() catch |err| {
        self.diagnostic.* = c.SourceDiagnostic.dependency(err, "transit.lock", "read frozen dependency lock");
        if (self.report) |r| r.finalize(err, .{});
        return err;
    };
    var visited: [256]u8 = @splat(0);
    try self.visitSource(0, &visited, 0);
    var index: usize = 0;
    while (index < self.sources.items.len) : (index += 1) {
        if (visited[index] == 0) try self.visitSource(index, &visited, 0);
    }
    return self.finish() catch |err| {
        if (self.report) |r| r.finalize(err, .{});
        self.note(err, "root", "transit.lock", if (self.fetch) "publish dependency lock" else "verify source graph", null);
        return err;
    };
}
fn sortSlice(slice: []c.Source) void {
    std.mem.sort(c.Source, slice, {}, struct {
        fn less(_: void, left: c.Source, right: c.Source) bool {
            const order = std.mem.order(u8, left.package, right.package);
            return order == .lt or order == .eq and std.mem.lessThan(u8, left.path, right.path);
        }
    }.less);
}
fn visitSource(self: *Self, index: usize, visited: *[256]u8, depth: usize) anyerror!void {
    if (visited[index] != 0) return;
    if (depth >= 64) return;
    visited[index] = 1;
    defer visited[index] = 2;
    // Dependency discovery shares the source parser, but never retains its AST.
    var scratch: std.heap.ArenaAllocator = .init(self.scratch_parent);
    defer scratch.deinit();
    var offset: usize = 0;
    const source = self.sources.items[index];
    const file = c.Syntax.parseReported(scratch.allocator(), source.text, &offset, index, self.report) catch |err| {
        var span: c.SourceDiagnostic.Span = .{ .start = @intCast(@min(offset, std.math.maxInt(u32))), .end = @intCast(@min(offset, std.math.maxInt(u32))) };
        if (self.report) |r| {
            if (r.has_span) span = r.span else r.setSpan(index, offset, offset);
            r.finalize(err, .{});
        }
        self.diagnostic.* = c.Compiler.project(err, c.Compiler.locationSpan(source, span), null, null);
        return err;
    };
    if (index == 0 and file.defaults.len == 1) {
        self.entry_default = try self.a.dupe(u8, file.defaults[0].name);
    }
    for (file.dependencies) |dep| self.resolve(dep) catch |err| {
        const dep_span: c.SourceDiagnostic.Span = .{ .start = dep.span.start, .end = dep.span.end };
        if (self.report) |r| {
            if (!r.has_span) r.setSpan(index, dep.span.start, dep.span.end);
            r.finalize(err, .{ .name = dep.name });
        }
        if (self.diagnostic.* == null) self.diagnostic.* = c.Compiler.project(err, c.Compiler.locationSpan(source, dep_span), null, null);
        self.diagnostic.*.?.text(.name, .caller, dep.name) catch {};
        if (self.diagnostic.*.?.location == null) self.diagnostic.*.?.location = c.Compiler.locationSpan(source, dep_span);
        return err;
    };
    for (file.imports) |import| {
        const target = self.checkImport(source, import) catch |err| {
            const imp_span: c.SourceDiagnostic.Span = .{ .start = import.span.start, .end = import.span.end };
            if (self.report) |r| {
                r.setSpan(index, import.span.start, import.span.end);
                if (err == error.MissingSource) {
                    r.setHeadline("cannot find imported file '{s}'", .{import.path});
                } else if (err == error.ExcludedSourcePath) {
                    r.setHeadline("import '{s}' enters an excluded directory", .{import.path});
                    r.addNote(null, null, "imports cannot traverse '.git', '.transit', '.direnv' or 'node_modules'", .{});
                }
                r.finalize(err, .{ .name = import.alias });
            }
            if (self.diagnostic.* == null) self.diagnostic.* = c.SourceDiagnostic.input(err, import.path, "resolve source import", null);
            self.diagnostic.*.?.location = c.Compiler.locationSpan(source, imp_span);
            self.diagnostic.*.?.text(.name, .caller, import.alias) catch {};
            return err;
        };
        if (self.report) |r| r.pushFrame(import.alias, index, .{ .start = import.span.start, .end = import.span.end });
        errdefer {}
        self.visitSource(target, visited, depth + 1) catch |err| return err;
        if (self.report) |r| r.popFrame();
    }
    try self.visitStatements(index, source, file.statements, visited, depth);
    for (file.definitions) |def| {
        if (def.suite_path) |suite_path| {
            try self.visitLocalPath(index, source, def.name, suite_path, def.span, visited, depth);
        }
        for (def.suites) |suite| switch (suite) {
            .path => |suite_path| try self.visitLocalPath(index, source, def.name, suite_path, def.span, visited, depth),
            .symbol => {},
        };
        try self.visitStatements(index, source, def.body, visited, depth);
    }
}
fn visitStatements(self: *Self, index: usize, source: c.Source, statements: []const c.Syntax.Statement, visited: *[256]u8, depth: usize) anyerror!void {
    if (depth >= 64) return;
    for (statements) |stmt| switch (stmt.value) {
        .declare_from => |raw_path| try self.visitLocalPath(index, source, raw_path, raw_path, stmt.span, visited, depth),
        .conditional => |cond| {
            try self.visitStatements(index, source, cond.yes, visited, depth + 1);
            try self.visitStatements(index, source, cond.no, visited, depth + 1);
        },
        .match => |m| for (m.arms) |arm| try self.visitStatements(index, source, arm.body, visited, depth + 1),
        .test_case => |tc| try self.visitStatements(index, source, tc.body, visited, depth + 1),
        else => {},
    };
}
fn visitLocalPath(self: *Self, index: usize, source: c.Source, label: []const u8, raw_path: []const u8, span: c.Syntax.Span, visited: *[256]u8, depth: usize) anyerror!void {
    const target = self.checkLocalPath(source, raw_path) catch |err| {
        const loc_span: c.SourceDiagnostic.Span = .{ .start = span.start, .end = span.end };
        if (self.report) |r| {
            r.setSpan(index, span.start, span.end);
            if (err == error.MissingSource) {
                r.setHeadline("cannot find source file '{s}'", .{raw_path});
            } else if (err == error.ExcludedSourcePath) {
                r.setHeadline("source path '{s}' enters an excluded directory", .{raw_path});
                r.addNote(null, null, "source paths cannot traverse '.git', '.transit', '.direnv' or 'node_modules'", .{});
            }
            r.finalize(err, .{ .name = label });
        }
        if (self.diagnostic.* == null) self.diagnostic.* = c.SourceDiagnostic.input(err, raw_path, "resolve source path", null);
        self.diagnostic.*.?.location = c.Compiler.locationSpan(source, loc_span);
        self.diagnostic.*.?.text(.name, .caller, label) catch {};
        return err;
    };
    if (self.report) |r| r.pushFrame(label, index, .{ .start = span.start, .end = span.end });
    errdefer {}
    self.visitSource(target, visited, depth + 1) catch |err| return err;
    if (self.report) |r| r.popFrame();
}
fn loadEntry(self: *Self) !void {
    try c.Graph.selectedPath(self.entry);
    if (!std.mem.endsWith(u8, self.entry, ".transit")) return error.InvalidSourcePath;
    const stat = self.root.statFile(self.io, self.entry, .{ .follow_symlinks = false }) catch |err| return if (err == error.FileNotFound) error.MissingBuildEntry else err;
    self.readEntry(self.root, "root", self.entry, .{ .name = self.entry, .kind = stat.kind, .inode = stat.inode }, 0) catch |err| {
        self.note(err, "root", self.entry, "read selected build entry", @tagName(stat.kind));
        return err;
    };
}
fn loadLock(self: *Self) !void {
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
}
fn checkRelativeLinks(self: *Self, package: []const u8, base_file: []const u8, raw_path: []const u8) !void {
    var stack: [64][]const u8 = undefined;
    var len: usize = 0;
    if (std.mem.lastIndexOfScalar(u8, base_file, '/')) |slash| {
        var base_parts = std.mem.splitScalar(u8, base_file[0..slash], '/');
        while (base_parts.next()) |part| {
            if (len < stack.len) {
                stack[len] = part;
                len += 1;
            }
        }
    }
    var parts = std.mem.splitScalar(u8, raw_path, '/');
    while (parts.next()) |part| {
        if (part.len == 0 or std.mem.eql(u8, part, ".")) continue;
        if (std.mem.eql(u8, part, "..")) {
            if (len > 0) len -= 1;
            continue;
        }
        if (len < stack.len) {
            stack[len] = part;
            len += 1;
        }
        var prefix_buf: [512]u8 = undefined;
        var pos: usize = 0;
        var ok = true;
        for (stack[0..len], 0..) |seg, idx| {
            if (idx != 0) {
                if (pos == prefix_buf.len) {
                    ok = false;
                    break;
                }
                prefix_buf[pos] = '/';
                pos += 1;
            }
            if (pos + seg.len > prefix_buf.len) {
                ok = false;
                break;
            }
            @memcpy(prefix_buf[pos..][0..seg.len], seg);
            pos += seg.len;
        }
        if (ok) {
            const candidate = prefix_buf[0..pos];
            for (self.links.items) |link| {
                if (!std.mem.eql(u8, link.package, package)) continue;
                if (std.mem.eql(u8, candidate, link.path) or (std.mem.startsWith(u8, candidate, link.path) and candidate.len > link.path.len and candidate[link.path.len] == '/')) {
                    self.note(error.UnsupportedSourceFileKind, package, link.path, "resolve source import", "sym_link");
                    return error.UnsupportedSourceFileKind;
                }
            }
        }
    }
}
fn checkLocalPath(self: *Self, source: c.Source, raw_path: []const u8) !usize {
    const path = try c.Graph.resolveSourcePath(self.a, source.path, raw_path);
    try self.checkRelativeLinks(source.package, source.path, raw_path);
    for (self.links.items) |link| {
        if (!std.mem.eql(u8, link.package, source.package)) continue;
        if (std.mem.eql(u8, path, link.path) or (std.mem.startsWith(u8, path, link.path) and path.len > link.path.len and path[link.path.len] == '/')) {
            self.note(error.UnsupportedSourceFileKind, source.package, link.path, "resolve source path", "sym_link");
            return error.UnsupportedSourceFileKind;
        }
    }
    for (self.sources.items, 0..) |candidate, idx| if (std.mem.eql(u8, candidate.package, source.package) and std.mem.eql(u8, candidate.path, path)) return idx;
    return error.MissingSource;
}
fn checkImport(self: *Self, source: c.Source, import: c.Syntax.Import) !usize {
    const package = import.package orelse source.package;
    const base_file = if (import.package != null) "" else source.path;
    const path = try c.Graph.importPath(self.a, source.path, import);
    try self.checkRelativeLinks(package, base_file, import.path);
    for (self.links.items) |link| {
        if (!std.mem.eql(u8, link.package, package)) continue;
        if (std.mem.eql(u8, path, link.path) or (std.mem.startsWith(u8, path, link.path) and path.len > link.path.len and path[link.path.len] == '/')) {
            self.note(error.UnsupportedSourceFileKind, package, link.path, "resolve source import", "sym_link");
            return error.UnsupportedSourceFileKind;
        }
    }
    for (self.sources.items, 0..) |candidate, idx| if (std.mem.eql(u8, candidate.package, package) and std.mem.eql(u8, candidate.path, path)) return idx;
    return error.MissingSource;
}
fn finish(self: *Self) ![32]u8 {
    std.mem.sort(c.Source, self.sources.items, {}, struct {
        fn less(_: void, left: c.Source, right: c.Source) bool {
            const order = std.mem.order(u8, left.package, right.package);
            return order == .lt or order == .eq and std.mem.lessThan(u8, left.path, right.path);
        }
    }.less);
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
        const absolute = try std.fs.path.resolve(self.a, &.{ try std.process.currentPathAlloc(self.io, self.a), path });
        const directory = openRoot(self.io, absolute) catch |err| {
            self.note(err, name, path, "open dependency override", null);
            return err;
        };
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
        self.loadCached(name, pin, path) catch |err| {
            if (self.diagnostic.* == null) self.diagnostic.* = c.SourceDiagnostic.dependency(err, path, "verify frozen dependency cache");
            return err;
        };
    }
    if (self.sources.items.len == first) return error.EmptySourcePackage;
    sortSlice(self.sources.items[first..]);
    const digest = try self.treeHex(name);
    if (self.fetch) try self.storeCache(name, digest);
    try self.resolutions.append(self.a, .{ .name = name, .repository = try self.a.dupe(u8, dependency.repository), .revision = try self.a.dupe(u8, dependency.revision), .subdirectory = try self.a.dupe(u8, dependency.subdirectory), .digest = digest, .override = override_path != null });
}
fn loadCached(self: *Self, name: []const u8, pin: Pin, path: []const u8) !void {
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
fn samePin(pin: anytype, dependency: c.Syntax.Dependency) bool {
    return std.mem.eql(u8, pin.repository, dependency.repository) and std.mem.eql(u8, pin.revision, dependency.revision) and std.mem.eql(u8, pin.subdirectory, dependency.subdirectory);
}
fn readTree(self: *Self, directory: std.Io.Dir, package: []const u8, prefix: []const u8, depth: usize) anyerror!void {
    return self.readDirectory(directory, package, prefix, depth) catch |err| {
        self.note(err, package, prefix, "scan source directory", null);
        return err;
    };
}
fn readDirectory(self: *Self, directory: std.Io.Dir, package: []const u8, prefix: []const u8, depth: usize) anyerror!void {
    if (depth >= 64) return error.SourceDepthLimit;
    var iterator = directory.iterate();
    while (try iterator.next(self.io)) |entry| {
        if (c.Graph.excludedComponent(entry.name)) continue;
        self.entries += 1;
        if (self.entries > 16384) return error.SourceTreeEntryLimit;
        if (std.mem.eql(u8, package, "root") and prefix.len == 0 and std.mem.eql(u8, entry.name, self.entry)) continue;
        const path = if (prefix.len == 0) try self.a.dupe(u8, entry.name) else try std.fmt.allocPrint(self.a, "{s}/{s}", .{ prefix, entry.name });
        if (entry.kind != .directory and !std.mem.endsWith(u8, entry.name, ".transit")) {
            if (entry.kind == .sym_link) try self.links.append(self.a, .{ .package = package, .path = path });
            continue;
        }
        self.readEntry(directory, package, path, entry, depth) catch |err| {
            self.note(err, package, path, "read source entry", @tagName(entry.kind));
            return err;
        };
    }
}
fn readEntry(self: *Self, directory: std.Io.Dir, package: []const u8, path: []const u8, entry: std.Io.Dir.Entry, depth: usize) anyerror!void {
    try c.Graph.validPath(path);
    switch (entry.kind) {
        .directory => {
            if (std.mem.eql(u8, package, "root") and std.mem.eql(u8, path, self.entry)) return error.UnsupportedSourceFileKind;
            const child = try directory.openDir(self.io, entry.name, .{ .iterate = true, .follow_symlinks = false });
            defer child.close(self.io);
            try self.readTree(child, package, path, depth + 1);
        },
        .file => if (std.mem.endsWith(u8, path, ".transit")) {
            var kind = entry.kind;
            const text = readWithKind(self.a, self.io, directory, entry.name, 1024 * 1024, &kind) catch |err| {
                self.note(err, package, path, "read source file", @tagName(kind));
                return err;
            };
            try self.add(package, path, text);
        },
        else => return error.UnsupportedSourceFileKind,
    }
}
fn note(self: *Self, err: anyerror, package: []const u8, path: []const u8, operation: []const u8, kind: ?[]const u8) void {
    if (self.diagnostic.* != null) return;
    self.diagnostic.* = c.SourceDiagnostic.input(err, path, operation, kind);
    self.diagnostic.*.?.text(.scope, .caller, package) catch {};
    const context: c.SourceDiagnostic.Context = switch (err) {
        error.SourceDepthLimit => .{ .budget = "source directory depth", .limit = 64 },
        error.SourceTreeEntryLimit => .{ .budget = "source tree entries", .limit = 16384, .required = self.entries },
        error.SourceFileLimit => .{ .budget = "source files", .limit = 256, .required = self.sources.items.len + 1 },
        error.SourceFileBytesLimit, error.SourceReadLimit => .{ .budget = "source file bytes", .limit = 1024 * 1024 },
        error.SourceBytesLimit => .{ .budget = "total source bytes", .limit = 16 * 1024 * 1024, .required = self.source_bytes },
        else => .{},
    };
    context.apply(&self.diagnostic.*.?);
    if (self.report) |r| r.finalize(err, context);
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
    try self.fetchDirectory(name, path, tree_spec, "", 0);
}
fn fetchDirectory(self: *Self, name: []const u8, repository: []const u8, tree: []const u8, prefix: []const u8, depth: usize) anyerror!void {
    if (depth >= 64) return error.SourceDepthLimit;
    // List one tree at a time: excluded subtrees consume neither traversal nor
    // descendant budgets, exactly as in local and cached discovery.
    const listing = try self.git(&.{ "--git-dir", repository, "ls-tree", "-z", tree }, 4 * 1024 * 1024);
    var entries = std.mem.splitScalar(u8, listing, 0);
    while (entries.next()) |entry| {
        if (entry.len == 0) continue;
        const tab = std.mem.indexOfScalar(u8, entry, '\t') orelse return error.InvalidRepositoryTree;
        const leaf = entry[tab + 1 ..];
        if (c.Graph.excludedComponent(leaf)) continue;
        self.entries += 1;
        if (self.entries > 16384) return error.SourceTreeEntryLimit;
        const relative = if (prefix.len == 0) try self.a.dupe(u8, leaf) else try std.fmt.allocPrint(self.a, "{s}/{s}", .{ prefix, leaf });
        self.fetchEntry(name, repository, entry[0..tab], relative, depth) catch |err| {
            self.note(err, name, relative, "read repository source entry", if (tab >= 6) entry[0..6] else null);
            return err;
        };
    }
}
fn fetchEntry(self: *Self, name: []const u8, repository: []const u8, header: []const u8, relative: []const u8, depth: usize) anyerror!void {
    if (std.mem.startsWith(u8, header, "040000 tree ")) {
        if (header.len != 52) return error.InvalidRepositoryTree;
        try c.Graph.selectedPath(relative);
        return self.fetchDirectory(name, repository, header[12..], relative, depth + 1);
    }
    if (!std.mem.endsWith(u8, relative, ".transit")) {
        if (std.mem.startsWith(u8, header, "120000 blob ")) try self.links.append(self.a, .{ .package = name, .path = relative });
        return;
    }
    try c.Graph.selectedPath(relative);
    if (!(std.mem.startsWith(u8, header, "100644 blob ") or std.mem.startsWith(u8, header, "100755 blob "))) return error.UnsupportedSourceFileKind;
    if (header.len != 52) return error.InvalidRepositoryTree;
    try self.add(name, relative, try self.git(&.{ "--git-dir", repository, "cat-file", "blob", header[12..] }, 1024 * 1024));
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
pub fn openRoot(io: std.Io, absolute: []const u8) !std.Io.Dir {
    var directory = try std.Io.Dir.cwd().openDir(io, "/", .{ .iterate = true });
    errdefer directory.close(io);
    var parts = std.mem.splitScalar(u8, absolute, '/');
    while (parts.next()) |part| {
        if (part.len == 0) continue;
        const next = try directory.openDir(io, part, .{ .iterate = true, .follow_symlinks = false });
        directory.close(io);
        directory = next;
    }
    return directory;
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
