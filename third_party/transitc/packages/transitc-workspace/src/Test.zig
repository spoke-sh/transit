//! Offline source resolution, complete suite compilation, then isolated cases.
const std = @import("std");
const c = @import("transit_compiler");
const p = @import("transit_protocol");
const Wire = @import("TestHostProtocol.zig");
const Sources = @import("BuildSources.zig");
const Options = @import("BuildOptions.zig");
const Diagnostic = @import("Diagnostic.zig");
const BuildReport = @import("BuildReport.zig");
const Style = @import("Style.zig");
const CaseReport = struct {
    name: []const u8,
    identity: []const u8,
    sql_digest: []const u8,
    location: p.Diagnostic.Location,
    status: enum { passed, failed, not_run } = .not_run,
    error_code: ?[]const u8 = null,
    observation: Wire.Observation = .{},
    action_location: ?p.Diagnostic.Location = null,
};
pub fn run(init: std.process.Init, options: Options, diagnostic: anytype, compiler_revision: []const u8, host: anytype) !void {
    diagnostic.style = Style.resolve(init, options.color);
    var quota: @import("transit_memory").Quota = .{ .limit = 256 * 1024 * 1024 };
    var adapter: @import("transit_memory").Quota.Allocator = .{ .parent = init.gpa, .quota = &quota };
    var arena: std.heap.ArenaAllocator = .init(adapter.allocator());
    defer arena.deinit();
    var compiler_report: c.SourceDiagnostic.Report = .{};
    var workspace: BuildReport.Workspace = .{ .overrides = options.overrides[0..options.overrides_len] };
    execute(init, arena.allocator(), adapter.allocator(), options, diagnostic, &compiler_report, &workspace, compiler_revision, host) catch |err| {
        if (err == error.TestSuiteFailed) return err;
        const cause = if (err == error.OutOfMemory and quota.refusals.load(.acquire) != 0) error.TestToolingMemoryLimit else err;
        if (diagnostic.envelope == null) diagnostic.envelope = c.SourceDiagnostic.input(cause, options.entry, "load test input", null);
        compiler_report.finalize(cause, .{});
        if (!options.json and !diagnostic.emitted) {
            @import("Build.zig").emitHumanFailure(init.io, diagnostic.style, .test_suite, options, workspace, diagnostic.envelope.?, &compiler_report);
            diagnostic.emitted = true;
        }
        return cause;
    };
}
fn execute(init: std.process.Init, a: std.mem.Allocator, scratch: std.mem.Allocator, options: Options, diagnostic: anytype, compiler_report: *c.SourceDiagnostic.Report, workspace: *BuildReport.Workspace, compiler_revision: []const u8, host: anytype) !void {
    const Host = @typeInfo(@TypeOf(host)).pointer.child;
    const cwd = try std.process.currentPathAlloc(init.io, a);
    workspace.cwd = cwd;
    const entry = try std.fs.path.resolve(a, &.{ cwd, options.entry });
    const root_path = std.fs.path.dirname(entry) orelse return error.InvalidSourcePath;
    workspace.root_path = root_path;
    const root = Sources.openRoot(init.io, root_path) catch |err| {
        const cause = if (err == error.FileNotFound) error.MissingBuildEntry else err;
        diagnostic.envelope = c.SourceDiagnostic.input(cause, entry, "open test entry directory", null);
        compiler_report.finalize(cause, .{});
        return cause;
    };
    defer root.close(init.io);
    var sources: Sources = .{ .a = a, .scratch_parent = scratch, .io = init.io, .root = root, .root_path = root_path, .entry = std.fs.path.basename(entry), .environment = init.environ_map, .fetch = false, .diagnostic = &diagnostic.envelope, .report = compiler_report, .overrides = options.overrides[0..options.overrides_len] };
    defer {
        workspace.sources = sources.sources.items;
        workspace.resolutions = sources.resolutions.items;
    }
    const resolution = try sources.load();
    workspace.sources = sources.sources.items;
    workspace.resolutions = sources.resolutions.items;
    const executable = try @import("Build.zig").executableDigest(init.io, a);
    if (Host.embedded) host.identity = .{ .revision = compiler_revision, .executable_digest = executable };
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update(&resolution);
    hash.update(&executable);
    const requested_target = try std.ascii.allocLowerString(a, options.target);
    const product = try c.compile(scratch, sources.sources.items, .{ .entry = std.fs.path.basename(entry), .target = requested_target, .target_explicit = options.target_explicit, .mode = .test_suite, .compiler_revision = compiler_revision, .resolution_digest = hash.finalResult(), .report = compiler_report }, &diagnostic.envelope);
    defer product.deinit();
    const target = try a.dupe(u8, product.selected_target);
    workspace.selected_target = target;
    const reports = try a.alloc(CaseReport, product.cases.len);
    const details = try a.alloc(c.Test.Detail, product.cases.len);
    @memset(details, .{});
    for (product.cases, reports) |case, *report| report.* = .{ .name = case.name, .identity = try a.dupe(u8, &std.fmt.bytesToHex(&case.identity, .lower)), .sql_digest = try a.dupe(u8, &std.fmt.bytesToHex(&case.sql_digest, .lower)), .location = case.location };
    const suite_deadline = Host.Deadline.init(init.io, 300000, null);
    const temporary_path = init.environ_map.get("TMPDIR") orelse "/tmp";
    const temporary = try std.Io.Dir.cwd().openDir(init.io, temporary_path, .{ .iterate = true, .follow_symlinks = false });
    defer temporary.close(init.io);
    diagnostic.envelope = try p.Diagnostic.init("test.incomplete_report", .internal, .output, .unknown, .none, "Test execution did not produce a complete report");
    compiler_report.reset();
    var complete = true;
    var ok = true;
    for (product.cases, reports, details) |case, *report, *detail| {
        suite_deadline.check(init.io) catch {
            report.error_code = "TestSuiteDeadline";
            complete = false;
            ok = false;
            break;
        };
        const name = try Sources.temporaryDirectory(a, init.io, temporary);
        const path = std.fs.path.join(a, &.{ temporary_path, name }) catch |err| {
            try host.delete(init.io, temporary, name);
            return err;
        };
        const directory = temporary.openDir(init.io, name, .{ .iterate = true, .follow_symlinks = false }) catch |err| {
            try host.delete(init.io, temporary, name);
            return err;
        };
        const deadline = Host.Deadline.init(init.io, 30000, suite_deadline);
        const passed = host.runDetailed(init, directory, path, case, deadline, &report.observation, detail) catch |err| failed: {
            report.error_code = host.errorName(err);
            complete = false;
            break :failed false;
        };
        directory.close(init.io);
        // No borrowed local endpoint or SQL session survives Host.run. Deletion
        // is checked on both success and failure, never a best-effort defer.
        host.delete(init.io, temporary, name) catch |err| {
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
        const bytes = try p.Json.valueAllocBounded(a, .{ .format = "transit_test_v1", .definition = Sources.definition, .compiler_revision = compiler_revision, .compiler_digest = @as([]const u8, &std.fmt.bytesToHex(&executable, .lower)), .runtime = host.identity, .target = target, .input_digest = @as([]const u8, &input_hex), .sql_digest = @as([]const u8, &sql_hex), .complete = complete, .ok = ok and complete, .compiler_peak_bytes = product.budget.peak, .cases = reports, .sources = source_ids, .dependencies = dependencies, .limits = .{ .cases = c.Test.max_cases, .actions = c.Test.max_actions, .rows = c.Test.max_rows, .result_bytes = c.Test.max_result_bytes, .report_bytes = 1024 * 1024, .case_ms = 30000, .suite_ms = 300000, .cleanup_ms = Host.cleanup_ms, .host_bytes = 256 * 1024 * 1024, .storage_bytes = 256 * 1024 * 1024 } }, 1024 * 1024 - 1);
        try std.Io.File.stdout().writeStreamingAll(init.io, bytes);
        try std.Io.File.stdout().writeStreamingAll(init.io, "\n");
    } else {
        const buffer = try a.alloc(u8, 1024 * 1024);
        var writer: std.Io.Writer = .fixed(buffer);
        if (ok and complete) {
            const renderer = @import("EnvelopeDiagnostic.zig");
            for (reports) |report| {
                try diagnostic.style.text(&writer, .span, "passed:");
                try writer.writeByte(' ');
                try renderer.escaped(&writer, report.name);
                try writer.writeByte('\n');
            }
        } else {
            const views = try a.alloc(BuildReport.CaseView, reports.len);
            for (reports, details, views) |report, detail, *view| view.* = .{
                .name = report.name,
                .status = switch (report.status) {
                    .passed => .passed,
                    .failed => .failed,
                    .not_run => .not_run,
                },
                .location = report.location,
                .action_location = report.action_location,
                .error_code = report.error_code,
                .failure = report.observation.failure,
                .detail = detail,
            };
            try BuildReport.renderTestSuiteFailure(&writer, diagnostic.style, target, workspace.*, views);
        }
        try std.Io.File.stderr().writeStreamingAll(init.io, writer.buffered());
    }
    diagnostic.emitted = true;
    if (!ok or !complete) return error.TestSuiteFailed;
}
