//! Resolved source buffers, explicit package paths and source visibility.
const std = @import("std");
const s = @import("Syntax.zig");
pub const Source = struct { package: []const u8 = "root", path: []const u8, text: []const u8 };
pub const Ref = struct { file: usize, definition: usize };
const Self = @This();
a: std.mem.Allocator,
sources: []const Source,
files: []const s.File,
max_depth: usize,

pub fn init(a: std.mem.Allocator, sources: []const Source, file_at: *usize, offset: *usize, max_depth: usize) !Self {
    if (sources.len == 0 or sources.len > 256) return error.SourceFileLimit;
    const files = try a.alloc(s.File, sources.len);
    var bytes: usize = 0;
    var dependency_count: usize = 0;
    for (sources, 0..) |source, i| {
        file_at.* = i;
        offset.* = 0;
        try validPath(source.path);
        try validPackage(source.package);
        bytes = std.math.add(usize, bytes, source.text.len) catch return error.SourceBytesLimit;
        if (bytes > 16 * 1024 * 1024) return error.SourceBytesLimit;
        for (sources[0..i]) |prior| if (std.mem.eql(u8, prior.package, source.package) and std.mem.eql(u8, prior.path, source.path)) return error.DuplicateSourceFile;
        files[i] = try s.parse(a, source.text, offset);
        dependency_count += files[i].dependencies.len;
        if (dependency_count > 256) return error.SourceDependencyLimit;
        for (files[i].definitions, 0..) |definition, j| {
            offset.* = definition.span.start;
            for (files[i].definitions[0..j]) |prior| if (std.mem.eql(u8, definition.name, prior.name)) return error.DuplicateSourceName;
            for (files[i].imports) |import| if (std.mem.eql(u8, definition.name, import.alias)) return error.DuplicateSourceName;
        }
        for (files[i].imports, 0..) |import, j| {
            offset.* = import.span.start;
            for (files[i].imports[0..j]) |prior| if (std.mem.eql(u8, import.alias, prior.alias)) return error.DuplicateSourceName;
        }
        for (files[i].dependencies, 0..) |dependency, j| {
            offset.* = dependency.span.start;
            try validateDependency(dependency);
            for (files[i].dependencies[0..j]) |prior| if (std.mem.eql(u8, dependency.name, prior.name)) return error.DuplicateDependency;
        }
    }
    for (files, 0..) |file, i| for (file.dependencies) |dependency| {
        for (files[0..i]) |prior_file| for (prior_file.dependencies) |prior| {
            if (std.mem.eql(u8, prior.name, dependency.name) and
                (!std.mem.eql(u8, prior.repository, dependency.repository) or
                    !std.mem.eql(u8, prior.revision, dependency.revision) or
                    !std.mem.eql(u8, prior.subdirectory, dependency.subdirectory))) return error.ConflictingDependency;
        };
    };
    var self: Self = .{ .a = a, .sources = sources, .files = files, .max_depth = max_depth };
    const visited = try a.alloc(u8, sources.len);
    const heights = try a.alloc(usize, sources.len);
    @memset(heights, 0);
    @memset(visited, 0);
    for (sources, 0..) |_, i| _ = try self.visit(i, visited, heights, 0, file_at, offset);
    @memset(visited, 0);
    @memset(heights, 0);
    for (sources, 0..) |_, i| _ = try self.visitPackage(i, visited, heights, 0, file_at, offset);
    return self;
}
pub fn validPackage(name: []const u8) !void {
    if (name.len == 0 or name.len > 63 or !(std.ascii.isAlphabetic(name[0]) or name[0] == '_')) return error.InvalidPackageName;
    for (name) |byte| if (!(std.ascii.isLower(byte) or std.ascii.isDigit(byte) or byte == '_')) return error.InvalidPackageName;
}
pub fn validPath(path: []const u8) !void {
    if (path.len == 0 or path.len > 512 or !std.unicode.utf8ValidateSlice(path) or std.mem.indexOfAny(u8, path, "\\\x00\r\n") != null) return error.InvalidSourcePath;
    var components = std.mem.splitScalar(u8, path, '/');
    while (components.next()) |part| if (part.len == 0 or std.mem.eql(u8, part, ".") or std.mem.eql(u8, part, "..")) return error.InvalidSourcePath;
}
pub fn validateDependency(value: s.Dependency) !void {
    if (value.repository.len == 0 or value.repository.len > 2048 or value.repository[0] == '-' or std.mem.indexOfAny(u8, value.repository, "\x00\r\n") != null) return error.InvalidRepository;
    if (std.mem.startsWith(u8, value.repository, "https://") or std.mem.startsWith(u8, value.repository, "file://")) {
        const uri = std.Uri.parse(value.repository) catch return error.InvalidRepository;
        if (uri.user != null or uri.password != null or uri.query != null or uri.fragment != null) return error.RepositoryCredentialsForbidden;
    } else if (!std.fs.path.isAbsolute(value.repository)) return error.UnsupportedRepositoryTransport;
    if (value.revision.len != 40) return error.InvalidRepositoryRevision;
    for (value.revision) |b| if (!std.ascii.isHex(b)) return error.InvalidRepositoryRevision;
    if (value.subdirectory.len > 0) try validPath(value.subdirectory);
}
pub fn importPath(a: std.mem.Allocator, source_path: []const u8, import: s.Import) ![]const u8 {
    try validPath(import.path);
    if (!std.mem.endsWith(u8, import.path, ".transit")) return error.InvalidSourcePath;
    if (import.package != null) return a.dupe(u8, import.path);
    if (std.mem.lastIndexOfScalar(u8, source_path, '/')) |slash| return std.fmt.allocPrint(a, "{s}/{s}", .{ source_path[0..slash], import.path });
    return a.dupe(u8, import.path);
}
pub fn imported(self: Self, file: usize, import: s.Import) !usize {
    const package = import.package orelse self.sources[file].package;
    if (import.package) |selected| {
        const declared = for (self.files[file].dependencies) |dependency| {
            if (std.mem.eql(u8, selected, dependency.name)) break true;
        } else false;
        if (!declared) return error.UndeclaredDependency;
    }
    const path = try importPath(self.a, self.sources[file].path, import);
    for (self.sources, 0..) |source, i| if (std.mem.eql(u8, package, source.package) and std.mem.eql(u8, path, source.path)) return i;
    return error.MissingSource;
}
fn visit(self: *Self, file: usize, visited: []u8, heights: []usize, depth: usize, file_at: *usize, offset: *usize) anyerror!usize {
    file_at.* = file;
    if (visited[file] == 1) return error.SourceImportCycle;
    if (visited[file] == 2) {
        if (depth + heights[file] > self.max_depth) return error.SourceDepthLimit;
        return heights[file];
    }
    if (depth >= self.max_depth) return error.SourceDepthLimit;
    visited[file] = 1;
    var height: usize = 1;
    for (self.files[file].imports) |import| {
        offset.* = import.span.start;
        const next = try self.imported(file, import);
        height = @max(height, 1 + try self.visit(next, visited, heights, depth + 1, file_at, offset));
    }
    visited[file] = 2;
    heights[file] = height;
    return height;
}
fn visitPackage(self: *Self, representative: usize, visited: []u8, heights: []usize, depth: usize, file_at: *usize, offset: *usize) anyerror!usize {
    const package = self.sources[representative].package;
    const index = for (self.sources, 0..) |source, i| {
        if (std.mem.eql(u8, source.package, package)) break i;
    } else unreachable;
    file_at.* = index;
    if (visited[index] == 1) return error.SourceDependencyCycle;
    if (visited[index] == 2) {
        if (depth + heights[index] > self.max_depth) return error.SourceDepthLimit;
        return heights[index];
    }
    if (depth >= self.max_depth) return error.SourceDepthLimit;
    visited[index] = 1;
    var height: usize = 1;
    for (self.sources, 0..) |source, i| {
        if (!std.mem.eql(u8, source.package, package)) continue;
        for (self.files[i].dependencies) |dependency| {
            file_at.* = i;
            offset.* = dependency.span.start;
            if (std.mem.eql(u8, dependency.name, "root")) return error.ReservedPackageName;
            const next = for (self.sources, 0..) |candidate, j| {
                if (std.mem.eql(u8, candidate.package, dependency.name)) break j;
            } else return error.MissingSource;
            height = @max(height, 1 + try self.visitPackage(next, visited, heights, depth + 1, file_at, offset));
        }
    }
    visited[index] = 2;
    heights[index] = height;
    return height;
}
pub fn resolve(self: Self, file: usize, name: s.Name) !Ref {
    if (name.constructor != null) return error.InvalidSourceName;
    var target = file;
    if (name.qualifier) |qualifier| {
        target = for (self.files[file].imports) |import| {
            if (std.mem.eql(u8, qualifier, import.alias)) break try self.imported(file, import);
        } else return error.UnknownImport;
    }
    for (self.files[target].definitions, 0..) |definition, i| if (std.mem.eql(u8, name.member, definition.name)) {
        if (name.qualifier != null and !definition.public) return error.PrivateSourceSymbol;
        return .{ .file = target, .definition = i };
    };
    return error.UnknownSourceSymbol;
}
pub fn getDefinition(self: Self, ref: Ref) s.Definition {
    return self.files[ref.file].definitions[ref.definition];
}

pub fn treeDigest(sources: []const Source, package: []const u8, a: std.mem.Allocator) ![32]u8 {
    var entries: std.ArrayList(Source) = .empty;
    defer entries.deinit(a);
    for (sources) |source| if (std.mem.eql(u8, package, source.package)) {
        try entries.append(a, source);
    };
    std.mem.sort(Source, entries.items, {}, struct {
        fn less(_: void, l: Source, r: Source) bool {
            return std.mem.lessThan(u8, l.path, r.path);
        }
    }.less);
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.source.tree.v1\x00");
    for (entries.items, 0..) |source, i| {
        try validPath(source.path);
        if (i > 0 and std.mem.eql(u8, source.path, entries.items[i - 1].path)) return error.DuplicateSourceFile;
        hashPart(&hash, source.path);
        hashPart(&hash, source.text);
    }
    return hash.finalResult();
}
pub fn hashPart(hash: *std.crypto.hash.sha2.Sha256, bytes: []const u8) void {
    var length: [8]u8 = undefined;
    std.mem.writeInt(u64, &length, bytes.len, .little);
    hash.update(&length);
    hash.update(bytes);
}
