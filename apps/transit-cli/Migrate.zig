//! Non-interactive application schema and data migration CLI command.
//! Never reads .transitrc startup files.
const std = @import("std");
const sdk = @import("transit_sql_client");
const api = sdk.protocol;
const M = api.Migration;
const MC = sdk.MigrationClient;
const Options = @import("Options.zig");
const Diagnostic = @import("Diagnostic.zig");
const Console = @import("Console.zig");

pub fn run(original: std.process.Init, options: Options.Options, diagnostic: *Diagnostic) !void {
    const runtime = try @import("transit_io").Threaded.create(original.gpa, .{
        .workers = 4,
        .task_bytes = 1024 * 1024,
        .environ = original.minimal.environ,
        .argv0 = .init(original.minimal.args),
    });
    defer runtime.destroy();
    var init = original;
    init.io = runtime.io();
    diagnostic.style = @import("Style.zig").detect(init);

    var arena: std.heap.ArenaAllocator = .init(init.gpa);
    defer arena.deinit();
    const a = arena.allocator();

    const config = try Console.loadConnectionConfig(init, a, options.path, diagnostic);
    diagnostic.file = null;
    diagnostic.field = null;

    // Load or discover SQL sources / saved plan before opening network connections
    // so local file/syntax errors fail fast without network side effects.
    var expected_plan_digest: ?[32]u8 = null;
    var target: M.TargetAssertion = .{
        .database = options.migrate_database,
        .schema = options.migrate_schema,
        .branch = options.migrate_branch,
        .account = options.migrate_account,
    };
    var allow_grants = options.allow_grants;
    var allow_publication = false;

    const sources: []const M.SourceFile = if (options.migrate_plan) |plan_file| blk: {
        diagnostic.atFile(plan_file);
        const bytes = std.Io.Dir.cwd().readFileAlloc(init.io, plan_file, a, .limited(api.max_message_bytes)) catch |err| {
            diagnostic.configurationFailure(err);
            return error.InvalidConfiguration;
        };
        const parsed = MC.decodeSavedPlan(a, bytes) catch |err| {
            return diagnostic.invalidFieldCause(err, "plan", "invalid migration plan file", null);
        };
        expected_plan_digest = parsed.value.plan_digest;
        if (target.database == null) target.database = parsed.value.target.database;
        if (target.schema == null) target.schema = parsed.value.target.schema;
        if (target.branch == null) target.branch = parsed.value.target.branch;
        if (target.account == null) target.account = parsed.value.target.account;
        allow_grants = allow_grants or parsed.value.allow_grants;
        allow_publication = parsed.value.allow_publication;
        break :blk parsed.value.sources;
    } else if (options.migrate_dir != null or options.migrate_files_len > 0) blk: {
        const discovered = MC.discoverSources(
            a,
            init.io,
            options.migrate_dir,
            options.migrate_files[0..options.migrate_files_len],
        ) catch |err| {
            if (options.migrate_dir) |dir| diagnostic.atFile(dir) else if (options.migrate_files_len > 0) diagnostic.atFile(options.migrate_files[0]);
            return diagnostic.fail(err, "cannot load migration SQL sources", "Ensure migration files end with .sql, follow <version>-<name>.sql naming and contain valid UTF-8 SQL.");
        };
        if (discovered.len == 0 and (options.migrate_action == .plan or options.migrate_action == .inspect or options.migrate_action == .apply)) {
            if (options.migrate_dir) |dir| diagnostic.atFile(dir);
            return diagnostic.fail(error.InvalidConfiguration, "no .sql migration files found", "Add ordered <version>-<name>.sql files to the migration directory.");
        }
        break :blk discovered;
    } else &.{};

    diagnostic.file = null;
    diagnostic.field = null;

    var client = sdk.Client.init(init.gpa, init.io, config.native()) catch |err| return diagnostic.invalidFieldCause(
        err,
        if (err == error.InvalidSqlEndpoint) "endpoint / authentication" else "ca_file",
        if (err == error.InvalidSqlEndpoint) "invalid SQL endpoint or authentication policy" else if (err == error.FileNotFound) "cannot load CA certificates: file not found" else "cannot load CA certificates",
        null,
    );
    defer client.deinit();

    const password = if (config.password_file) |file| std.Io.Dir.cwd().readFileAlloc(init.io, file, init.gpa, .limited(129)) catch |err| return diagnostic.invalidFieldCause(err, "password_file", "cannot read SQL password", null) else null;
    defer if (password) |bytes| {
        std.crypto.secureZero(u8, bytes);
        init.gpa.free(bytes);
    };

    try client.open(config.native(), if (password) |bytes| std.mem.trimEnd(u8, bytes, "\r\n") else null);
    defer {
        client.timeout_ms = @min(client.timeout_ms, 1000);
        if (client.call(.close)) |reply| reply.deinit() else |_| {}
    }

    diagnostic.field = null;
    diagnostic.file = null;

    const action = options.migrate_action.?;
    const request: M.Request = .{
        .kind = action,
        .target = target,
        .sources = sources,
        .expected_plan_digest = expected_plan_digest,
        .attempt_id = options.migrate_attempt,
        .allow_grants = allow_grants,
        .allow_publication = allow_publication,
    };

    const reply = try client.migrate(request, a);
    defer reply.deinit();

    if (reply.value.result == .err) {
        const failure = reply.value.result.err;
        diagnostic.envelope = failure.diagnostic;
        diagnostic.sqlServiceSummary(failure.code, failure.sqlstate);
        diagnostic.next = null;
        return error.SqlServiceError;
    }
    if (reply.value.result != .migration) return error.InvalidSqlResponse;
    const report = reply.value.result.migration;

    if (options.migrate_out) |out_file| {
        if (report.outcome == .planned or report.outcome == .already_satisfied) {
            const saved = MC.toSavedPlan(report, sources, allow_grants, allow_publication);
            const encoded = try MC.encodeSavedPlan(a, saved);
            diagnostic.atFile(out_file);
            std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = out_file, .data = encoded }) catch |err| {
                return diagnostic.fail(err, "cannot write migration plan file", null);
            };
            diagnostic.file = null;
        }
    }

    const format = options.format orelse config.format;
    var output_buffer: [8192]u8 = undefined;
    var output = std.Io.File.stdout().writerStreaming(init.io, &output_buffer);
    if (format == .json) {
        var encoder: std.json.Stringify = .{ .writer = &output.interface, .options = .{ .escape_unicode = true } };
        try api.Json.write(report, &encoder);
        try output.interface.writeByte('\n');
    } else {
        try renderTable(&output.interface, report);
    }
    try output.interface.flush();

    switch (report.outcome) {
        .planned, .inspected, .applied, .already_satisfied, .verified => return,
        .target_mismatch => return failOwnedSummary(
            diagnostic,
            error.MigrationTargetMismatch,
            report.diagnostic_message,
            "migration target does not match the connected database or schema",
            "Verify --database, --schema, --branch and --account match the target environment.",
        ),
        .drift_detected => return failOwnedSummary(
            diagnostic,
            error.MigrationDriftDetected,
            report.diagnostic_message,
            "live schema diverges from the declared migration",
            "Inspect the reported drift with 'transit migrate inspect' or 'transit migrate verify'.",
        ),
        .checksum_mismatch => return failOwnedSummary(
            diagnostic,
            error.MigrationChecksumMismatch,
            report.diagnostic_message,
            "recorded migration checksum does not match the current source file",
            "Restore the applied migration file to its original contents and create a new migration version for further changes.",
        ),
        .claim_conflict => return failOwnedSummary(
            diagnostic,
            error.MigrationClaimConflict,
            report.diagnostic_message,
            "another migration runner holds an active claim on this version",
            "Inspect active migration claims with 'transit migrate status' or reconcile an interrupted runner with 'transit migrate resume'.",
        ),
        .outcome_unknown => return failOwnedSummary(
            diagnostic,
            error.MigrationOutcomeUnknown,
            report.diagnostic_message,
            "a migration step has an unresolved durable outcome",
            "Run 'transit migrate resume' to reconcile durable step tokens before starting new migrations.",
        ),
        .step_failed => {
            if (action == .verify) {
                return failOwnedSummary(
                    diagnostic,
                    error.MigrationVerificationFailed,
                    report.diagnostic_message,
                    "post-migration schema verification failed",
                    "Inspect the failed verification step and live catalog state with 'transit migrate status'.",
                );
            }
            return failOwnedSummary(
                diagnostic,
                error.MigrationStepFailed,
                report.diagnostic_message,
                "a migration step failed during execution",
                "Inspect the recorded step failure with 'transit migrate status', resolve the cause, and run 'transit migrate resume'.",
            );
        },
    }
}

fn failOwnedSummary(
    diagnostic: *Diagnostic,
    err: anyerror,
    message: ?[]const u8,
    fallback: []const u8,
    next: ?[]const u8,
) anyerror {
    const owned = if (message) |text|
        (std.fmt.bufPrint(&diagnostic.summary_storage, "{s}", .{text}) catch fallback)
    else
        fallback;
    return diagnostic.fail(err, owned, next);
}

pub fn renderTable(out: *std.Io.Writer, report: M.Report) !void {
    try out.print(
        "Migration {s}: {s} (database={s} schema={s} branch={d} account={s})\n",
        .{
            @tagName(report.action),
            @tagName(report.outcome),
            report.target.database,
            report.target.schema,
            report.target.branch,
            report.target.account,
        },
    );
    if (report.versions.len == 0) {
        try out.writeAll("No migrations recorded.\n");
    } else {
        for (report.versions) |version| {
            try out.print(
                "  {s}-{s} [{s}] sha256={x}\n",
                .{
                    version.version_id,
                    version.name,
                    @tagName(version.state),
                    version.source_sha256[0..8],
                },
            );
            for (version.steps) |step| {
                try out.print(
                    "    step {d} ({s}:{d}:{d}) {s} {s} -> {s}",
                    .{
                        step.step_index,
                        version.path,
                        step.line,
                        step.column,
                        @tagName(step.effect),
                        step.object_name,
                        @tagName(step.state),
                    },
                );
                if (step.affected_rows) |rows| try out.print(" (rows={d})", .{rows});
                if (step.drift) |drift| {
                    try out.print(" [drift: {s}", .{drift.aspect});
                    if (drift.column) |col| try out.print(" column={s}", .{col});
                    if (drift.expected) |exp| try out.print(" expected={s}", .{exp});
                    if (drift.actual) |act| try out.print(" actual={s}", .{act});
                    try out.writeByte(']');
                }
                if (step.diagnostic_message) |msg| try out.print(" - {s}", .{msg});
                try out.writeByte('\n');
            }
        }
    }
    if (report.recovery_command) |recovery| {
        try out.print("Recovery: {s}\n", .{recovery});
    }
}
