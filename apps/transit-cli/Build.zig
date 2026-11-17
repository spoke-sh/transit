//! Offline compilation and atomic artifact publication. No SQL client is opened.
const std = @import("std");
const c = @import("transit_compiler");
const p = @import("transit_query").protocol;
const Sources = @import("BuildSources.zig");
const Options = @import("BuildOptions.zig");
const Diagnostic = @import("Diagnostic.zig");
const Migration = @import("BuildMigration.zig");
const BuildReport = @import("BuildReport.zig");
const Style = @import("Style.zig");
const version = @import("build_version");
const SourceIdentity = struct { package: []const u8, path: []const u8, digest: []const u8 };
pub fn run(init: std.process.Init, options: Options, diagnostic: *Diagnostic) !void {
    diagnostic.style = Style.resolve(init, options.color);
    var budget: @import("transit_memory").Budget = .{ .parent = init.gpa, .limit = 256 * 1024 * 1024 };
    var arena: std.heap.ArenaAllocator = .init(budget.allocator());
    defer arena.deinit();
    var compiler_report: c.SourceDiagnostic.Report = .{};
    var workspace: BuildReport.Workspace = .{ .overrides = options.overrides[0..options.overrides_len] };
    execute(init, arena.allocator(), budget.allocator(), options, diagnostic, &compiler_report, &workspace) catch |err| {
        const cause = if (err == error.OutOfMemory and budget.exhausted) error.BuildToolingMemoryLimit else err;
        if (diagnostic.envelope == null) diagnostic.envelope = c.SourceDiagnostic.input(cause, options.entry, "load build input", null);
        compiler_report.finalize(cause, .{});
        if (!options.json and !diagnostic.emitted) {
            emitHumanFailure(init.io, diagnostic.style, .build, options, workspace, diagnostic.envelope.?, &compiler_report);
            diagnostic.emitted = true;
        }
        return cause;
    };
}
fn execute(init: std.process.Init, a: std.mem.Allocator, scratch_parent: std.mem.Allocator, options: Options, diagnostic: *Diagnostic, compiler_report: *c.SourceDiagnostic.Report, workspace: *BuildReport.Workspace) !void {
    const cwd = try std.process.currentPathAlloc(init.io, a);
    workspace.cwd = cwd;
    const entry_path = try std.fs.path.resolve(a, &.{ cwd, options.entry });
    const root_path = std.fs.path.dirname(entry_path) orelse return error.InvalidSourcePath;
    workspace.root_path = root_path;
    const root = Sources.openRoot(init.io, root_path) catch |err| {
        const cause = if (err == error.FileNotFound) error.MissingBuildEntry else err;
        diagnostic.envelope = c.SourceDiagnostic.input(cause, entry_path, "open build entry directory", null);
        compiler_report.finalize(cause, .{});
        return cause;
    };
    defer root.close(init.io);
    var sources: Sources = .{ .a = a, .scratch_parent = scratch_parent, .io = init.io, .root = root, .root_path = root_path, .entry = std.fs.path.basename(entry_path), .environment = init.environ_map, .fetch = options.fetch, .diagnostic = &diagnostic.envelope, .report = compiler_report, .overrides = options.overrides[0..options.overrides_len] };
    defer {
        workspace.sources = sources.sources.items;
        workspace.resolutions = sources.resolutions.items;
    }
    const resolved = try sources.load();
    if (options.fetch) return report(init.io, a, options.json, .{ .ok = true, .action = "fetch", .dependencies = sources.resolutions.items.len }, "Dependencies verified; transit.lock published.\n");
    const executable = try executableDigest(init.io, a);
    var identity = std.crypto.hash.sha2.Sha256.init(.{});
    identity.update(&resolved);
    identity.update(&executable);
    const target = try std.ascii.allocLowerString(a, options.target);
    const product = try c.compile(init.gpa, sources.sources.items, .{ .entry = std.fs.path.basename(entry_path), .target = target, .compiler_revision = version.revision, .resolution_digest = identity.finalResult(), .report = compiler_report }, &diagnostic.envelope);
    defer product.deinit();
    const compiler_hex = std.fmt.bytesToHex(&executable, .lower);
    var migration_context: c.SourceDiagnostic.Context = .{};
    const migration: ?Migration.Prepared = if (product.migration != null) Migration.prepare(a, init.io, root, product, &compiler_hex, &migration_context) catch |err| {
        diagnostic.envelope = c.SourceDiagnostic.input(err, product.migration.?.basis orelse options.entry, "synthesize Table migration", null);
        migration_context.apply(&diagnostic.envelope.?);
        compiler_report.reset();
        compiler_report.finalize(err, migration_context);
        return err;
    } else null;
    const input_digest = if (migration) |value| value.input_digest else product.input_digest;
    const statement_count = if (migration) |value| value.result.steps else product.steps.len;
    const input_hex = std.fmt.bytesToHex(&input_digest, .lower);
    const sql_hex = std.fmt.bytesToHex(&product.sql_digest, .lower);
    if (options.check) return report(init.io, a, options.json, .{ .ok = true, .action = "check", .target = target, .input_digest = @as([]const u8, &input_hex), .sql_digest = @as([]const u8, &sql_hex), .statements = statement_count }, "Application checked; no artifact published.\n");
    var source_ids: std.ArrayList(SourceIdentity) = .empty;
    for (sources.sources.items) |source| {
        var hash: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(source.text, &hash, .{});
        try source_ids.append(a, .{ .package = source.package, .path = source.path, .digest = try a.dupe(u8, &std.fmt.bytesToHex(&hash, .lower)) });
    }
    std.mem.sort(SourceIdentity, source_ids.items, {}, struct {
        fn less(_: void, left: SourceIdentity, right: SourceIdentity) bool {
            const order = std.mem.order(u8, left.package, right.package);
            return order == .lt or order == .eq and std.mem.lessThan(u8, left.path, right.path);
        }
    }.less);
    const provenance = try p.Json.valueAlloc(a, .{ .format = c.Compiler.format, .definition = Sources.definition, .complete = true, .compiler_revision = version.revision, .compiler_digest = @as([]const u8, &compiler_hex), .entry = std.fs.path.basename(entry_path), .target = target, .input_digest = @as([]const u8, &input_hex), .sql_digest = @as([]const u8, &sql_hex), .limits = c.Compiler.Limits{}, .sources = source_ids.items, .dependencies = sources.resolutions.items, .steps = product.steps, .migration = if (migration) |value| .{ .basis_digest = c.CatalogDiff.hash(value.basis), .prior_digest = value.prior_digest, .database = value.result.basis.database, .schema = value.result.basis.schema, .steps = value.result.steps, .sql_digest = c.CatalogDiff.hash(value.result.sql) } else null });
    if (provenance.len > 64 * 1024 * 1024) return error.BuildProvenanceLimit;
    const out = if (options.out) |selected| try std.fs.path.resolve(a, &.{ cwd, selected }) else try std.fmt.allocPrint(a, "{s}/.transit/build/{s}/{s}", .{ root_path, target, input_hex });
    const reused = publish(init.io, a, out, product.sql, provenance, migration, options.out == null) catch |err| {
        diagnostic.envelope = c.SourceDiagnostic.output(err, out, "publish application SQL");
        compiler_report.reset();
        compiler_report.finalize(err, .{});
        return err;
    };
    const status = try std.fmt.allocPrint(a, "{s} {s}: {s}\n", .{ if (migration != null) "Migration artifacts" else "Application SQL", if (reused) "verified" else "published", out });
    try report(init.io, a, options.json, .{ .ok = true, .action = "build", .target = target, .directory = out, .input_digest = @as([]const u8, &input_hex), .sql_digest = @as([]const u8, &sql_hex), .statements = statement_count, .reused = reused }, status);
}
pub fn emitHumanFailure(io: std.Io, style: Style, mode: BuildReport.Mode, options: Options, workspace: BuildReport.Workspace, envelope: p.Diagnostic, compiler_report: ?*const c.SourceDiagnostic.Report) void {
    var buffer: [8192]u8 = undefined;
    var writer = std.Io.File.stderr().writerStreaming(io, &buffer);
    BuildReport.renderFailure(&writer.interface, style, mode, options, workspace, envelope, compiler_report) catch return;
    writer.interface.flush() catch {};
}
fn report(io: std.Io, a: std.mem.Allocator, json: bool, value: anytype, human: []const u8) !void {
    if (!json) return std.Io.File.stderr().writeStreamingAll(io, human);
    const bytes = try p.Json.valueAlloc(a, value);
    try std.Io.File.stdout().writeStreamingAll(io, bytes);
    try std.Io.File.stdout().writeStreamingAll(io, "\n");
}
pub fn emitFailure(io: std.Io, diagnostic: *Diagnostic, err: anyerror) !void {
    if (diagnostic.emitted) return;
    const envelope = diagnostic.envelope orelse c.Compiler.project(err, null, null, null);
    var buffer: [p.Diagnostic.max_json_bytes]u8 = undefined;
    const bytes = try envelope.encode(&buffer);
    try std.Io.File.stdout().writeStreamingAll(io, bytes);
    try std.Io.File.stdout().writeStreamingAll(io, "\n");
    diagnostic.emitted = true;
}
fn publish(io: std.Io, a: std.mem.Allocator, output: []const u8, sql: []const u8, provenance: []const u8, migration: ?Migration.Prepared, allow_existing: bool) !bool {
    const parent_path = std.fs.path.dirname(output) orelse return error.InvalidBuildOutput;
    // Create/open each component without following symlinks, including existing
    // .transit directories. Explicit absolute destinations are caller-selected.
    var parent = try std.Io.Dir.cwd().openDir(io, "/", .{ .iterate = true });
    defer parent.close(io);
    var components = std.mem.splitScalar(u8, parent_path, '/');
    while (components.next()) |component| {
        if (component.len == 0) continue;
        parent.createDir(io, component, .default_dir) catch |err| if (err != error.PathAlreadyExists) return err;
        const next = try parent.openDir(io, component, .{ .iterate = true, .follow_symlinks = false });
        parent.close(io);
        parent = next;
    }
    const name = std.fs.path.basename(output);
    const temporary = try Sources.temporaryDirectory(a, io, parent);
    defer parent.deleteTree(io, temporary) catch {};
    const directory = try parent.openDir(io, temporary, .{ .iterate = true });
    defer directory.close(io);
    const sql_name = if (migration != null) "desired.sql" else "application.sql";
    try Sources.writeFile(io, directory, sql_name, sql);
    if (migration) |value| {
        try Sources.writeFile(io, directory, "basis.json", value.basis);
        try directory.createDir(io, "migrations", .default_dir);
        const versions = try directory.openDir(io, "migrations", .{ .iterate = true });
        defer versions.close(io);
        for (value.result.files) |file| try Sources.writeFile(io, versions, file.path, file.sql);
        try Sources.syncDirectory(versions);
    }
    try Sources.writeFile(io, directory, "provenance.json", provenance);
    try Sources.syncDirectory(directory);
    parent.renamePreserve(temporary, parent, name, io) catch |err| {
        if (err != error.PathAlreadyExists or !allow_existing) return err;
        const existing = try parent.openDir(io, name, .{ .follow_symlinks = false });
        defer existing.close(io);
        const old_sql = try Sources.read(a, io, existing, sql_name, sql.len);
        const old_provenance = try Sources.read(a, io, existing, "provenance.json", provenance.len);
        if (!std.mem.eql(u8, old_sql, sql) or !std.mem.eql(u8, old_provenance, provenance)) return error.BuildArtifactMismatch;
        if (migration) |value| {
            const old_basis = try Sources.read(a, io, existing, "basis.json", value.basis.len);
            if (!std.mem.eql(u8, old_basis, value.basis)) return error.BuildArtifactMismatch;
            const versions = try existing.openDir(io, "migrations", .{ .iterate = true, .follow_symlinks = false });
            defer versions.close(io);
            for (value.result.files) |file| {
                const old = try Sources.read(a, io, versions, file.path, file.sql.len);
                if (!std.mem.eql(u8, old, file.sql)) return error.BuildArtifactMismatch;
            }
            var iterator = versions.iterate();
            var count: usize = 0;
            while (try iterator.next(io)) |_| count += 1;
            if (count != value.result.files.len) return error.BuildArtifactMismatch;
        }
        return true;
    };
    try Sources.syncDirectory(parent);
    return false;
}
pub fn executableDigest(io: std.Io, a: std.mem.Allocator) ![32]u8 {
    const path = try std.process.executablePathAlloc(io, a);
    const file = try std.Io.Dir.cwd().openFile(io, path, .{});
    defer file.close(io);
    const size = (try file.stat(io)).size;
    if (size > 1024 * 1024 * 1024) return error.CompilerArtifactLimit;
    var hash = try @import("server/ArtifactHash.zig").init();
    defer hash.deinit();
    var buffer: [65536]u8 = undefined;
    var offset: u64 = 0;
    while (offset < size) {
        const amount = try file.readPositionalAll(io, buffer[0..@min(buffer.len, size - offset)], offset);
        if (amount == 0) return error.CompilerArtifactChanged;
        try hash.update(buffer[0..amount]);
        offset += amount;
    }
    if ((try file.stat(io)).size != size) return error.CompilerArtifactChanged;
    return hash.final();
}
