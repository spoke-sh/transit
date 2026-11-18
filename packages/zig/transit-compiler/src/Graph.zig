//! Resolved source buffers, explicit package paths and source visibility.
const std = @import("std");
const s = @import("Syntax.zig");
const SourceDiagnostic = @import("SourceDiagnostic.zig");
pub const Source = struct { package: []const u8 = "root", path: []const u8, text: []const u8 };
pub const Ref = struct { file: usize, definition: usize };
const Self = @This();
a: std.mem.Allocator,
sources: []const Source,
files: []const s.File,
max_depth: usize,

pub fn init(a: std.mem.Allocator, sources: []const Source, file_at: *usize, offset: *usize, max_depth: usize) !Self {
    return initReported(a, sources, file_at, offset, max_depth, null);
}
pub fn initReported(a: std.mem.Allocator, sources: []const Source, file_at: *usize, offset: *usize, max_depth: usize, report: ?*SourceDiagnostic.Report) !Self {
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
        files[i] = try s.parseReported(a, source.text, offset, i, report);
        dependency_count += files[i].dependencies.len;
        if (dependency_count > 256) return error.SourceDependencyLimit;
        for (files[i].definitions, 0..) |definition, j| {
            offset.* = definition.span.start;
            for (files[i].definitions[0..j]) |prior| if (std.mem.eql(u8, definition.name, prior.name)) {
                if (report) |r| {
                    r.setSpan(i, definition.span.start, definition.span.end);
                    r.setHeadline("duplicate declaration of '{s}'", .{definition.name});
                    r.addNote(i, .{ .start = prior.span.start, .end = prior.span.end }, "'{s}' first declared here", .{prior.name});
                }
                return error.DuplicateSourceName;
            };
            for (files[i].imports) |import| if (std.mem.eql(u8, definition.name, import.alias)) {
                if (report) |r| {
                    r.setSpan(i, definition.span.start, definition.span.end);
                    r.setHeadline("declaration '{s}' conflicts with import alias", .{definition.name});
                    r.addNote(i, .{ .start = import.span.start, .end = import.span.end }, "import alias '{s}' declared here", .{import.alias});
                }
                return error.DuplicateSourceName;
            };
        }
        for (files[i].imports, 0..) |import, j| {
            offset.* = import.span.start;
            for (files[i].imports[0..j]) |prior| if (std.mem.eql(u8, import.alias, prior.alias)) {
                if (report) |r| {
                    r.setSpan(i, import.span.start, import.span.end);
                    r.setHeadline("duplicate import alias '{s}'", .{import.alias});
                    r.addNote(i, .{ .start = prior.span.start, .end = prior.span.end }, "'{s}' first imported here", .{prior.alias});
                }
                return error.DuplicateSourceName;
            };
        }
        for (files[i].dependencies, 0..) |dependency, j| {
            offset.* = dependency.span.start;
            validateDependency(dependency) catch |err| {
                if (report) |r| r.setSpan(i, dependency.span.start, dependency.span.end);
                return err;
            };
            for (files[i].dependencies[0..j]) |prior| if (std.mem.eql(u8, dependency.name, prior.name)) {
                if (report) |r| {
                    r.setSpan(i, dependency.span.start, dependency.span.end);
                    r.setHeadline("duplicate dependency '{s}'", .{dependency.name});
                    r.addNote(i, .{ .start = prior.span.start, .end = prior.span.end }, "'{s}' first declared here", .{prior.name});
                }
                return error.DuplicateDependency;
            };
        }
    }
    for (files, 0..) |file, i| for (file.dependencies) |dependency| {
        for (files[0..i], 0..i) |prior_file, prior_i| for (prior_file.dependencies) |prior| {
            if (std.mem.eql(u8, prior.name, dependency.name) and
                (!std.mem.eql(u8, prior.repository, dependency.repository) or
                    !std.mem.eql(u8, prior.revision, dependency.revision) or
                    !std.mem.eql(u8, prior.subdirectory, dependency.subdirectory)))
            {
                file_at.* = i;
                offset.* = dependency.span.start;
                if (report) |r| {
                    r.setSpan(i, dependency.span.start, dependency.span.end);
                    r.setHeadline("conflicting dependency declaration for '{s}'", .{dependency.name});
                    r.addNote(prior_i, .{ .start = prior.span.start, .end = prior.span.end }, "'{s}' declared with different revision or path here", .{prior.name});
                }
                return error.ConflictingDependency;
            }
        };
    };
    var self: Self = .{ .a = a, .sources = sources, .files = files, .max_depth = max_depth };
    const visited = try a.alloc(u8, sources.len);
    const heights = try a.alloc(usize, sources.len);
    @memset(heights, 0);
    @memset(visited, 0);
    for (sources, 0..) |_, i| _ = try self.visit(i, visited, heights, 0, file_at, offset, report);
    @memset(visited, 0);
    @memset(heights, 0);
    for (sources, 0..) |_, i| _ = try self.visitPackage(i, visited, heights, 0, file_at, offset, report);
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
/// Selection is shared by local, fetched and cached source packages. Hash its
/// exact rules into dependency trees so a frozen old cache cannot be reinterpreted.
pub const selection = "regular .transit files; no links; prune .git,.transit,.direnv,node_modules";
pub fn excludedComponent(part: []const u8) bool {
    return std.StaticStringMap(void).initComptime(.{ .{".git"}, .{".transit"}, .{".direnv"}, .{"node_modules"} }).has(part);
}
pub fn selectedPath(path: []const u8) !void {
    try validPath(path);
    var components = std.mem.splitScalar(u8, path, '/');
    while (components.next()) |part| if (excludedComponent(part)) return error.ExcludedSourcePath;
}
/// Resolve a relative subpath against `base_file`'s directory within the same
/// package root. `.` and intra-package `..` normalize; escaping the package
/// root, leading `/`, empty segments or traversing an excluded component fails.
pub fn resolvePackageSubpath(a: std.mem.Allocator, base_file: []const u8, raw_path: []const u8) ![]const u8 {
    if (raw_path.len == 0 or raw_path.len > 512 or !std.unicode.utf8ValidateSlice(raw_path) or std.mem.indexOfAny(u8, raw_path, "\\\x00\r\n") != null or raw_path[0] == '/') return error.InvalidSourcePath;
    var stack: [64][]const u8 = undefined;
    var len: usize = 0;
    if (std.mem.lastIndexOfScalar(u8, base_file, '/')) |slash| {
        var base_parts = std.mem.splitScalar(u8, base_file[0..slash], '/');
        while (base_parts.next()) |part| {
            if (part.len == 0) return error.InvalidSourcePath;
            if (excludedComponent(part)) return error.ExcludedSourcePath;
            if (len == stack.len) return error.SourceDepthLimit;
            stack[len] = part;
            len += 1;
        }
    }
    var parts = std.mem.splitScalar(u8, raw_path, '/');
    while (parts.next()) |part| {
        if (part.len == 0) return error.InvalidSourcePath;
        if (excludedComponent(part)) return error.ExcludedSourcePath;
        if (std.mem.eql(u8, part, ".")) continue;
        if (std.mem.eql(u8, part, "..")) {
            if (len == 0) return error.InvalidSourcePath;
            len -= 1;
            continue;
        }
        if (len == stack.len) return error.SourceDepthLimit;
        stack[len] = part;
        len += 1;
    }
    if (len == 0) return error.InvalidSourcePath;
    var total: usize = len - 1;
    for (stack[0..len]) |part| total += part.len;
    if (total > 512) return error.InvalidSourcePath;
    const out = try a.alloc(u8, total);
    var pos: usize = 0;
    for (stack[0..len], 0..) |part, idx| {
        if (idx != 0) {
            out[pos] = '/';
            pos += 1;
        }
        @memcpy(out[pos..][0..part.len], part);
        pos += part.len;
    }
    try selectedPath(out);
    return out;
}
pub fn resolveSourcePath(a: std.mem.Allocator, base_file: []const u8, raw_path: []const u8) ![]const u8 {
    const resolved = try resolvePackageSubpath(a, base_file, raw_path);
    if (!std.mem.endsWith(u8, resolved, ".transit")) return error.InvalidSourcePath;
    return resolved;
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
    return resolveSourcePath(a, if (import.package != null) "" else source_path, import.path);
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
fn visit(self: *Self, file: usize, visited: []u8, heights: []usize, depth: usize, file_at: *usize, offset: *usize, report: ?*SourceDiagnostic.Report) anyerror!usize {
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
        const next = self.imported(file, import) catch |err| {
            if (report) |r| {
                r.setSpan(file, import.span.start, import.span.end);
                if (err == error.UndeclaredDependency) {
                    r.setHeadline("import '{s}' references undeclared dependency package '{s}'", .{ import.alias, import.package.? });
                } else if (err == error.MissingSource) {
                    r.setHeadline("cannot find imported file '{s}'", .{import.path});
                }
            }
            return err;
        };
        const sub = self.visit(next, visited, heights, depth + 1, file_at, offset, report) catch |err| {
            if (err == error.SourceImportCycle) if (report) |r| if (!r.has_span) {
                file_at.* = file;
                offset.* = import.span.start;
                r.setSpan(file, import.span.start, import.span.end);
            };
            return err;
        };
        height = @max(height, 1 + sub);
    }
    visited[file] = 2;
    heights[file] = height;
    return height;
}
fn visitPackage(self: *Self, representative: usize, visited: []u8, heights: []usize, depth: usize, file_at: *usize, offset: *usize, report: ?*SourceDiagnostic.Report) anyerror!usize {
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
            if (std.mem.eql(u8, dependency.name, "root")) {
                if (report) |r| {
                    r.setSpan(i, dependency.span.start, dependency.span.end);
                    r.setHeadline("dependency name 'root' is reserved for the root package", .{});
                }
                return error.ReservedPackageName;
            }
            const next = for (self.sources, 0..) |candidate, j| {
                if (std.mem.eql(u8, candidate.package, dependency.name)) break j;
            } else {
                if (report) |r| {
                    r.setSpan(i, dependency.span.start, dependency.span.end);
                    r.setHeadline("dependency package '{s}' has not been fetched", .{dependency.name});
                    r.addNote(null, null, "run 'transit build --fetch' to fetch pinned repository dependencies", .{});
                }
                return error.MissingSource;
            };
            const sub = self.visitPackage(next, visited, heights, depth + 1, file_at, offset, report) catch |err| {
                if (err == error.SourceDependencyCycle) if (report) |r| if (!r.has_span) {
                    file_at.* = i;
                    offset.* = dependency.span.start;
                    r.setSpan(i, dependency.span.start, dependency.span.end);
                };
                return err;
            };
            height = @max(height, 1 + sub);
        }
    }
    visited[index] = 2;
    heights[index] = height;
    return height;
}
pub fn resolve(self: Self, file: usize, name: s.Name) !Ref {
    return self.resolveReported(file, name, null);
}
pub fn resolveReported(self: Self, file: usize, name: s.Name, report: ?*SourceDiagnostic.Report) !Ref {
    if (name.constructor != null) return error.InvalidSourceName;
    var target = file;
    if (name.qualifier) |qualifier| {
        target = for (self.files[file].imports) |import| {
            if (std.mem.eql(u8, qualifier, import.alias)) break try self.imported(file, import);
        } else {
            if (report) |r| r.setHeadline("unknown import alias '{s}'", .{qualifier});
            return error.UnknownImport;
        };
    }
    for (self.files[target].definitions, 0..) |definition, i| if (std.mem.eql(u8, name.member, definition.name)) {
        if (name.qualifier != null and !definition.public) {
            if (report) |r| {
                r.setHeadline("symbol '{s}' in '{s}' is private", .{ name.member, name.qualifier.? });
                r.addNote(target, .{ .start = definition.span.start, .end = definition.span.end }, "'{s}' declared without 'PUBLIC' here", .{definition.name});
            }
            return error.PrivateSourceSymbol;
        }
        return .{ .file = target, .definition = i };
    };
    if (report) |r| r.setHeadline("unknown symbol '{s}'", .{name.member});
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
    hashPart(&hash, selection);
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
