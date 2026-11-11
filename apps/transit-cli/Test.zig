//! Offline source resolution, complete suite compilation, then isolated cases.
const std = @import("std");
const c = @import("transit_compiler");
const testlib = @import("transit_test");
const p = testlib.service.catalog.protocol;
const Sources = @import("BuildSources.zig");
const Options = @import("BuildOptions.zig");
const Diagnostic = @import("Diagnostic.zig");
const Host = @import("TestHost.zig");
const version = @import("build_version");
const CaseReport = struct {
    name: []const u8,
    identity: []const u8,
    sql_digest: []const u8,
    location: p.Diagnostic.Location,
    status: enum { passed, failed, not_run } = .not_run,
    error_code: ?[]const u8 = null,
    observation: Host.Observation = .{},
    action_location: ?p.Diagnostic.Location = null,
};
pub fn run(init: std.process.Init, options: Options, diagnostic: *Diagnostic) !void {
    var quota: @import("transit_memory").Quota = .{ .limit = 256 * 1024 * 1024 };
    var adapter: @import("transit_memory").Quota.Allocator = .{ .parent = init.gpa, .quota = &quota };
    var arena: std.heap.ArenaAllocator = .init(adapter.allocator());
    defer arena.deinit();
    execute(init, arena.allocator(), adapter.allocator(), options, diagnostic) catch |err| {
        if (err == error.TestSuiteFailed) return err;
        const cause = if (err == error.OutOfMemory and quota.refusals.load(.acquire) != 0) error.TestToolingMemoryLimit else err;
        if (diagnostic.envelope == null) diagnostic.envelope = c.Compiler.project(cause, null, null, null);
        return cause;
    };
}
fn execute(init: std.process.Init, a: std.mem.Allocator, scratch: std.mem.Allocator, options: Options, diagnostic: *Diagnostic) !void {
    const cwd = try std.process.currentPathAlloc(init.io, a);
    const entry = try std.fs.path.resolve(a, &.{ cwd, options.entry });
    const root_path = std.fs.path.dirname(entry) orelse return error.InvalidSourcePath;
    const root = try std.Io.Dir.cwd().openDir(init.io, root_path, .{ .iterate = true, .follow_symlinks = false });
    defer root.close(init.io);
    var sources: Sources = .{ .a = a, .scratch_parent = scratch, .io = init.io, .root = root, .root_path = root_path, .entry = std.fs.path.basename(entry), .environment = init.environ_map, .fetch = false, .diagnostic = &diagnostic.envelope, .overrides = options.overrides[0..options.overrides_len] };
    const resolution = try sources.load();
    const executable = try @import("Build.zig").executableDigest(init.io, a);
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update(&resolution);
    hash.update(&executable);
    const target = try std.ascii.allocLowerString(a, options.target);
    const product = try c.compile(scratch, sources.sources.items, .{ .entry = std.fs.path.basename(entry), .target = target, .mode = .test_suite, .compiler_revision = version.revision, .resolution_digest = hash.finalResult() }, &diagnostic.envelope);
    defer product.deinit();
    const reports = try a.alloc(CaseReport, product.cases.len);
    for (product.cases, reports) |case, *report| report.* = .{ .name = case.name, .identity = try a.dupe(u8, &std.fmt.bytesToHex(&case.identity, .lower)), .sql_digest = try a.dupe(u8, &std.fmt.bytesToHex(&case.sql_digest, .lower)), .location = case.location };
    const suite_deadline = testlib.service.wire.Deadline.init(init.io, 300000, null);
    const temporary_path = init.environ_map.get("TMPDIR") orelse "/tmp";
    const temporary = try std.Io.Dir.cwd().openDir(init.io, temporary_path, .{ .iterate = true, .follow_symlinks = false });
    defer temporary.close(init.io);
    diagnostic.envelope = try p.Diagnostic.init("test.incomplete_report", .internal, .output, .unknown, .none, "Test execution did not produce a complete report");
    var complete = true;
    var ok = true;
    for (product.cases, reports) |case, *report| {
        suite_deadline.check(init.io) catch {
            report.error_code = "TestSuiteDeadline";
            complete = false;
            ok = false;
            break;
        };
        const name = try Sources.temporaryDirectory(a, init.io, temporary);
        const path = std.fs.path.join(a, &.{ temporary_path, name }) catch |err| {
            try Host.delete(init.io, temporary, name);
            return err;
        };
        const directory = temporary.openDir(init.io, name, .{ .iterate = true, .follow_symlinks = false }) catch |err| {
            try Host.delete(init.io, temporary, name);
            return err;
        };
        const deadline = testlib.service.wire.Deadline.init(init.io, 30000, suite_deadline);
        const passed = Host.run(init, directory, path, case, deadline, &report.observation) catch |err| failed: {
            report.error_code = @errorName(err);
            complete = false;
            break :failed false;
        };
        directory.close(init.io);
        // No borrowed local endpoint or SQL session survives Host.run. Deletion
        // is checked on both success and failure, never a best-effort defer.
        Host.delete(init.io, temporary, name) catch |err| {
            report.error_code = @errorName(err);
            complete = false;
        };
        if (report.observation.actions != 0) report.action_location = case.actions[report.observation.actions - 1].location;
        report.status = if (passed and report.error_code == null) .passed else .failed;
        ok = ok and report.status == .passed;
        if (!complete) break;
    }
    const SourceIdentity = struct { package: []const u8, path: []const u8, digest: []const u8 };
    const source_ids = try a.alloc(SourceIdentity, sources.sources.items.len);
    for (sources.sources.items, source_ids) |source, *identity| {
        var digest: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(source.text, &digest, .{});
        identity.* = .{ .package = source.package, .path = source.path, .digest = try a.dupe(u8, &std.fmt.bytesToHex(&digest, .lower)) };
    }
    const Dependency = struct { name: []const u8, revision: []const u8, subdirectory: []const u8, digest: []const u8, override: bool };
    const dependencies = try a.alloc(Dependency, sources.resolutions.items.len);
    for (sources.resolutions.items, dependencies) |source, *identity| identity.* = .{ .name = source.name, .revision = source.revision, .subdirectory = source.subdirectory, .digest = source.digest, .override = source.override };
    const input_hex = std.fmt.bytesToHex(&product.input_digest, .lower);
    const sql_hex = std.fmt.bytesToHex(&product.sql_digest, .lower);
    if (options.json) {
        const bytes = try p.Json.valueAllocBounded(a, .{ .format = "transit_test_v1", .definition = Sources.definition, .compiler_revision = version.revision, .compiler_digest = @as([]const u8, &std.fmt.bytesToHex(&executable, .lower)), .target = target, .input_digest = @as([]const u8, &input_hex), .sql_digest = @as([]const u8, &sql_hex), .complete = complete, .ok = ok and complete, .compiler_peak_bytes = product.budget.peak, .cases = reports, .sources = source_ids, .dependencies = dependencies, .limits = .{ .cases = c.Test.max_cases, .actions = c.Test.max_actions, .rows = c.Test.max_rows, .result_bytes = c.Test.max_result_bytes, .report_bytes = 1024 * 1024, .case_ms = 30000, .suite_ms = 300000, .cleanup_ms = Host.cleanup_ms, .host_bytes = 256 * 1024 * 1024, .storage_bytes = 256 * 1024 * 1024 } }, 1024 * 1024 - 1);
        try std.Io.File.stdout().writeStreamingAll(init.io, bytes);
        try std.Io.File.stdout().writeStreamingAll(init.io, "\n");
    } else {
        const buffer = try a.alloc(u8, 1024 * 1024);
        var writer: std.Io.Writer = .fixed(buffer);
        for (reports) |report| {
            try writer.print("{s}: {s}", .{ @tagName(report.status), report.name });
            if (report.error_code) |code| {
                try writer.print(" ({s})", .{code});
            } else if (report.observation.failure) |failure| try writer.print(" ({s})", .{@tagName(failure)});
            try writer.writeByte('\n');
        }
        try std.Io.File.stderr().writeStreamingAll(init.io, writer.buffered());
    }
    diagnostic.emitted = true;
    if (!ok or !complete) return error.TestSuiteFailed;
}
