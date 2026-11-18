//! Confined offline basis loading. CatalogDiff owns validation and synthesis.
const std = @import("std");
const c = @import("transit_compiler");
const d = c.CatalogDiff;
const p = @import("transit_query").protocol;
const Sources = @import("BuildSources.zig");
pub const Prepared = struct { result: d.Result, basis: []const u8, prior_digest: ?[32]u8, input_digest: [32]u8 };
pub fn prepare(a: std.mem.Allocator, io: std.Io, root: std.Io.Dir, product: *const c.Product, compiler: []const u8, context: *c.SourceDiagnostic.Context) !Prepared {
    const target = product.migration.?;
    var prior: ?d.Basis = null;
    var prior_digest: ?[32]u8 = null;
    var files: std.ArrayList(d.File) = .empty;
    if (product.migration_basis_path orelse target.basis) |path| {
        if (path.len == 0 or path.len > 512 or std.fs.path.isAbsolute(path) or std.mem.indexOfScalar(u8, path, 0) != null or std.mem.indexOfScalar(u8, path, '\\') != null) return error.InvalidMigrationBasisPath;
        var directory = try root.openDir(io, ".", .{ .iterate = true, .follow_symlinks = false });
        defer directory.close(io);
        var parts = std.mem.splitScalar(u8, path, '/');
        var leaf = parts.next().?;
        var depth: usize = 0;
        while (parts.next()) |next_part| {
            try component(leaf);
            depth += 1;
            if (depth > 64) return error.InvalidMigrationBasisPath;
            const next = try directory.openDir(io, leaf, .{ .iterate = true, .follow_symlinks = false });
            directory.close(io);
            directory = next;
            leaf = next_part;
        }
        try component(leaf);
        const bytes = try Sources.read(a, io, directory, leaf, d.max_basis_bytes);
        prior_digest = d.hash(bytes);
        const parsed = std.json.parseFromSlice(d.Basis, a, bytes, .{ .allocate = .alloc_always }) catch |err| return if (err == error.OutOfMemory) err else error.InvalidMigrationBasis;
        prior = parsed.value;
        if (!std.mem.eql(u8, prior.?.format, d.format) or !std.mem.eql(u8, prior.?.definition, d.definition)) return error.IncompatibleMigrationBasis;
        if (prior.?.history.len > d.max_versions) return error.MigrationHistoryLimit;
        const migrations = try directory.openDir(io, "migrations", .{ .iterate = true, .follow_symlinks = false });
        defer migrations.close(io);
        var total: usize = 0;
        for (prior.?.history) |version| {
            const filename = try d.fileName(a, version.version, version.name);
            if (!std.mem.eql(u8, filename, version.path)) return error.MigrationBasisMismatch;
            const sql = try Sources.read(a, io, migrations, filename, @min(d.max_file_bytes, d.max_history_bytes - total));
            total += sql.len;
            try files.append(a, .{ .path = filename, .sql = sql });
        }
        // An unlisted migration must not disappear silently from copied history.
        var iterator = migrations.iterate();
        var count: usize = 0;
        while (try iterator.next(io)) |entry| {
            count += 1;
            if (entry.kind != .file or count > files.items.len) return error.MigrationBasisMismatch;
            const found = for (files.items) |file| {
                if (std.mem.eql(u8, entry.name, file.path)) break true;
            } else false;
            if (!found) return error.MigrationBasisMismatch;
        }
        if (count != files.items.len) return error.MigrationBasisMismatch;
    }
    const result = try d.build(a, product, prior, files.items, compiler, context);
    const basis = try p.Json.valueAlloc(a, result.basis);
    if (basis.len > d.max_basis_bytes) return error.MigrationHistoryLimit;
    var identity = std.crypto.hash.sha2.Sha256.init(.{});
    identity.update("transit.source.migration.v1\x00");
    identity.update(&product.input_digest);
    if (prior_digest) |digest| identity.update(&digest);
    // Covers verified immutable history and the complete desired definition basis.
    identity.update(&d.hash(basis));
    return .{ .result = result, .basis = basis, .prior_digest = prior_digest, .input_digest = identity.finalResult() };
}
fn component(value: []const u8) !void {
    if (value.len == 0 or std.mem.eql(u8, value, ".") or std.mem.eql(u8, value, "..")) return error.InvalidMigrationBasisPath;
}
