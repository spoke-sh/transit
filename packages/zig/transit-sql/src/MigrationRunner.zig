//! Reviewable, resumable application schema and data migration planner/executor.
//! Operates directly over DirectCatalog, DirectMigration and DatabaseRuntime
//! without Station actor turns.
const std = @import("std");
const g = @import("root.zig");
const c = g.catalog;
const f = g.fuze;
const p = g.wire.protocol;
const api = g.session_protocol;
const M = api.Migration;
const DM = c.DirectMigration;

pub const Context = struct {
    account_id: [32]u8,
    account_name: []const u8,
    database: []const u8,
    schema: []const u8,
    namespace: u64,
    dialect: f.Sql.Dialect = .transit,
};

pub const ParsedStep = struct {
    step_index: u16,
    owner: M.StepOwner,
    effect: M.StepEffect,
    object_name: []const u8,
    sql: []const u8,
    line: u32,
    column: u32,
    statement_digest: [32]u8,
};

/// Splits a multi-statement SQL file on top-level semicolons while preserving
/// comments, quoted strings, quoted identifiers and 1-based line/column positions.
pub fn splitStatements(allocator: std.mem.Allocator, sql_text: []const u8) ![]ParsedStep {
    try f.Sql.validateText(sql_text);
    var scan = try f.SqlInput.Scan.init(sql_text);
    var steps: std.ArrayList(ParsedStep) = .empty;
    var stmt_start: ?usize = null;
    var stmt_end: usize = 0;
    var first_word: ?f.SqlInput.Token = null;
    var second_word: ?f.SqlInput.Token = null;
    var third_word: ?f.SqlInput.Token = null;
    var depth: usize = 0;

    while (try scan.next()) |token| {
        if (token.kind == .space or token.kind == .comment) continue;
        if (token.kind == .symbol and std.mem.eql(u8, sql_text[token.start..token.end], "(")) {
            depth += 1;
        } else if (token.kind == .symbol and std.mem.eql(u8, sql_text[token.start..token.end], ")")) {
            if (depth > 0) depth -= 1;
        }
        if (token.kind == .symbol and depth == 0 and std.mem.eql(u8, sql_text[token.start..token.end], ";")) {
            if (stmt_start) |start| {
                const slice = std.mem.trim(u8, sql_text[start..stmt_end], " \t\r\n");
                if (slice.len != 0) {
                    if (steps.items.len >= M.max_steps_per_version) return error.InvalidMigrationStepCount;
                    const step = try classifyStatement(
                        allocator,
                        sql_text,
                        start,
                        slice,
                        @intCast(steps.items.len + 1),
                        first_word,
                        second_word,
                        third_word,
                    );
                    try steps.append(allocator, step);
                }
            }
            stmt_start = null;
            first_word = null;
            second_word = null;
            third_word = null;
            continue;
        }
        if (stmt_start == null) stmt_start = token.start;
        stmt_end = token.end;
        if (first_word == null) {
            first_word = token;
        } else if (second_word == null) {
            second_word = token;
        } else if (third_word == null) {
            third_word = token;
        }
    }
    if (stmt_start) |start| {
        const slice = std.mem.trim(u8, sql_text[start..stmt_end], " \t\r\n");
        if (slice.len != 0) {
            if (steps.items.len >= M.max_steps_per_version) return error.InvalidMigrationStepCount;
            const step = try classifyStatement(
                allocator,
                sql_text,
                start,
                slice,
                @intCast(steps.items.len + 1),
                first_word,
                second_word,
                third_word,
            );
            try steps.append(allocator, step);
        }
    }
    if (steps.items.len == 0) return error.InvalidMigrationStepCount;
    return steps.toOwnedSlice(allocator);
}

fn tokenWord(text: []const u8, token: ?f.SqlInput.Token, expected: []const u8) bool {
    const tok = token orelse return false;
    return tok.kind == .word and std.ascii.eqlIgnoreCase(text[tok.start..tok.end], expected);
}

fn lineAndColumn(full_text: []const u8, offset: usize) struct { line: u32, column: u32 } {
    var line: u32 = 1;
    var line_start: usize = 0;
    for (full_text[0..@min(offset, full_text.len)], 0..) |byte, index| {
        if (byte == '\n') {
            line += 1;
            line_start = index + 1;
        }
    }
    return .{
        .line = line,
        .column = @intCast((offset -| line_start) + 1),
    };
}

fn classifyStatement(
    allocator: std.mem.Allocator,
    full_text: []const u8,
    offset: usize,
    stmt_sql: []const u8,
    step_index: u16,
    first: ?f.SqlInput.Token,
    second: ?f.SqlInput.Token,
    third: ?f.SqlInput.Token,
) !ParsedStep {
    const pos = lineAndColumn(full_text, offset);
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(stmt_sql, &digest, .{});

    if (tokenWord(full_text, first, "BEGIN") or
        tokenWord(full_text, first, "START") or
        tokenWord(full_text, first, "COMMIT") or
        tokenWord(full_text, first, "ROLLBACK") or
        tokenWord(full_text, first, "SAVEPOINT") or
        tokenWord(full_text, first, "RELEASE"))
    {
        return error.InteractiveTransactionInMigration;
    }

    if ((tokenWord(full_text, first, "CREATE") or tokenWord(full_text, first, "ALTER") or tokenWord(full_text, first, "DROP")) and
        tokenWord(full_text, second, "TABLE"))
    {
        const target = try f.TableDdl.target(allocator, stmt_sql);
        return .{
            .step_index = step_index,
            .owner = .schema_ddl,
            .effect = switch (target.kind) {
                .create => .create_table,
                .alter => .alter_table,
                .drop => .drop_table,
            },
            .object_name = try allocator.dupe(u8, target.name),
            .sql = try allocator.dupe(u8, stmt_sql),
            .line = pos.line,
            .column = pos.column,
            .statement_digest = digest,
        };
    }

    if ((tokenWord(full_text, first, "CREATE") or tokenWord(full_text, first, "ALTER") or tokenWord(full_text, first, "DROP")) and
        tokenWord(full_text, second, "SCHEMA"))
    {
        const effect: M.StepEffect = if (tokenWord(full_text, first, "CREATE"))
            .create_schema
        else if (tokenWord(full_text, first, "ALTER"))
            .alter_schema
        else
            .drop_schema;
        const name_tok = third orelse return error.InvalidSqlSyntax;
        const raw_name = full_text[name_tok.start..name_tok.end];
        return .{
            .step_index = step_index,
            .owner = .schema_ddl,
            .effect = effect,
            .object_name = try allocator.dupe(u8, std.mem.trim(u8, raw_name, "\"")),
            .sql = try allocator.dupe(u8, stmt_sql),
            .line = pos.line,
            .column = pos.column,
            .statement_digest = digest,
        };
    }

    if (tokenWord(full_text, first, "INSERT") or tokenWord(full_text, first, "UPDATE") or tokenWord(full_text, first, "DELETE")) {
        const target = try f.TableDml.target(allocator, stmt_sql);
        return .{
            .step_index = step_index,
            .owner = .data_transform,
            .effect = switch (target.kind) {
                .insert => .insert_rows,
                .update => .update_rows,
                .delete => .delete_rows,
            },
            .object_name = try allocator.dupe(u8, target.name),
            .sql = try allocator.dupe(u8, stmt_sql),
            .line = pos.line,
            .column = pos.column,
            .statement_digest = digest,
        };
    }

    if (tokenWord(full_text, first, "GRANT") or tokenWord(full_text, first, "REVOKE") or
        ((tokenWord(full_text, first, "CREATE") or tokenWord(full_text, first, "ALTER") or tokenWord(full_text, first, "DROP")) and
            tokenWord(full_text, second, "ROLE")))
    {
        var compiled = try f.AuthorizationSql.compile(allocator, stmt_sql, null);
        defer compiled.deinit();
        return .{
            .step_index = step_index,
            .owner = .authorization_grant,
            .effect = .grant_privilege,
            .object_name = "authorization",
            .sql = try allocator.dupe(u8, stmt_sql),
            .line = pos.line,
            .column = pos.column,
            .statement_digest = digest,
        };
    }

    if (tokenWord(full_text, first, "CREATE") and
        (tokenWord(full_text, second, "CONNECTION") or tokenWord(full_text, second, "SOURCE") or tokenWord(full_text, second, "SINK")))
    {
        return .{
            .step_index = step_index,
            .owner = .publication,
            .effect = .publish_resource,
            .object_name = "publication",
            .sql = try allocator.dupe(u8, stmt_sql),
            .line = pos.line,
            .column = pos.column,
            .statement_digest = digest,
        };
    }

    if (tokenWord(full_text, first, "SELECT")) {
        const target_name = try f.TableSelect.target(allocator, stmt_sql);
        return .{
            .step_index = step_index,
            .owner = .verification,
            .effect = .verify_query,
            .object_name = try allocator.dupe(u8, target_name),
            .sql = try allocator.dupe(u8, stmt_sql),
            .line = pos.line,
            .column = pos.column,
            .statement_digest = digest,
        };
    }

    return error.UnsupportedMigrationStatement;
}

pub fn observedTarget(client: *const c.DirectTableClient, context: Context) M.ObservedTarget {
    return .{
        .realm = client.connection.scope.realm,
        .resource = client.connection.scope.resource,
        .catalog = client.connection.scope.catalog,
        .branch = client.connection.branch,
        .namespace = context.namespace,
        .database = context.database,
        .schema = context.schema,
        .account = context.account_name,
        .principal = client.connection.principal,
        .role = client.connection.role,
    };
}

pub fn checkTarget(assertion: M.TargetAssertion, actual: M.ObservedTarget) ?struct { field: []const u8, expected: []const u8, observed: []const u8 } {
    if (assertion.database) |expected| {
        if (!std.mem.eql(u8, expected, actual.database)) return .{ .field = "database", .expected = expected, .observed = actual.database };
    }
    if (assertion.schema) |expected| {
        if (!std.mem.eql(u8, expected, actual.schema)) return .{ .field = "schema", .expected = expected, .observed = actual.schema };
    }
    if (assertion.account) |expected| {
        if (!std.mem.eql(u8, expected, actual.account)) return .{ .field = "account", .expected = expected, .observed = actual.account };
    }
    if (assertion.branch) |expected| {
        if (expected != actual.branch) return .{ .field = "branch", .expected = "asserted", .observed = "different" };
    }
    return null;
}

fn lookupLiveSchema(allocator: std.mem.Allocator, client: *c.DirectTableClient, namespace: u64, name: []const u8) !?f.TableSchema.Schema {
    const response = try client.call(.{ .lookup = .{ .namespace = namespace, .name = name } });
    defer response.deinit();
    const metadata = response.value.result.lookup orelse return null;
    const raw = try metadata.schema.decode(allocator, f.TableSchema.max_bytes);
    const decoded = try f.TableSchema.decode(allocator, raw);
    return decoded.schema;
}

const WorkingSchemas = struct {
    allocator: std.mem.Allocator,
    client: *c.DirectTableClient,
    namespace: u64,
    entries: std.StringHashMapUnmanaged(?f.TableSchema.Schema) = .empty,

    fn get(self: *WorkingSchemas, name: []const u8) !?f.TableSchema.Schema {
        if (self.entries.get(name)) |cached| return cached;
        const live = try lookupLiveSchema(self.allocator, self.client, self.namespace, name);
        const owned_name = try self.allocator.dupe(u8, name);
        try self.entries.put(self.allocator, owned_name, live);
        return live;
    }

    fn put(self: *WorkingSchemas, name: []const u8, schema: ?f.TableSchema.Schema) !void {
        if (self.entries.getPtr(name)) |slot| {
            slot.* = schema;
            return;
        }
        const owned_name = try self.allocator.dupe(u8, name);
        try self.entries.put(self.allocator, owned_name, schema);
    }
};

pub fn computePlanDigest(target: M.ObservedTarget, versions: []const M.VersionReport) [32]u8 {
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.migration.plan.v1\x00");
    var bytes: [8]u8 = undefined;
    inline for (.{ target.realm, target.resource, target.catalog, target.branch, target.namespace }) |val| {
        std.mem.writeInt(u64, &bytes, val, .little);
        hash.update(&bytes);
    }
    hash.update(target.database);
    hash.update(&.{0});
    hash.update(target.schema);
    hash.update(&.{0});
    for (versions) |version| {
        hash.update(version.version_id);
        hash.update(&.{0});
        hash.update(&version.source_sha256);
        hash.update(&version.plan_digest);
    }
    return hash.finalResult();
}

fn computeVersionDigest(version_id: []const u8, source_sha256: [32]u8, steps: []const M.StepReport) [32]u8 {
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.migration.version-plan.v1\x00");
    hash.update(version_id);
    hash.update(&.{0});
    hash.update(&source_sha256);
    for (steps) |step| {
        hash.update(&step.statement_digest);
        hash.update(&step.step_token);
        if (step.expected_schema_sha256) |expected| hash.update(&expected);
    }
    return hash.finalResult();
}

pub fn execute(
    allocator: std.mem.Allocator,
    runtime: *g.DatabaseRuntime,
    observer: *g.Client,
    table: *c.DirectTableClient,
    context: Context,
    request: M.Request,
    deadline: g.DatabaseRuntime.Deadline,
) !M.Report {
    try request.validate();
    const target = observedTarget(table, context);
    if (checkTarget(request.target, target)) |mismatch| {
        const msg = try std.fmt.allocPrint(
            allocator,
            "Migration target mismatch on {s}: expected '{s}', observed '{s}'",
            .{ mismatch.field, mismatch.expected, mismatch.observed },
        );
        return .{
            .definition = p.Growth.current_definition,
            .action = request.kind,
            .outcome = .target_mismatch,
            .target = target,
            .plan_digest = @splat(0),
            .versions = &.{},
            .diagnostic_code = "migration.target_mismatch",
            .diagnostic_message = msg,
        };
    }

    return switch (request.kind) {
        .status => statusReport(allocator, runtime, observer, table, context, target, request),
        .@"resume" => resumeExecution(allocator, runtime, observer, table, context, target, request, deadline),
        .verify => verifyMigrations(allocator, table, context, target, request),
        .plan, .inspect => buildPlanReport(allocator, table, context, target, request),
        .apply => applyMigrations(allocator, runtime, observer, table, context, target, request, deadline),
    };
}

fn findRecordedVersion(recorded: []const DM.VersionEntry, version_id: []const u8) ?DM.VersionEntry {
    for (recorded) |entry| {
        if (std.mem.eql(u8, entry.version_id, version_id)) return entry;
    }
    return null;
}

fn buildPlanReport(
    allocator: std.mem.Allocator,
    table: *c.DirectTableClient,
    context: Context,
    target: M.ObservedTarget,
    request: M.Request,
) !M.Report {
    const recorded = try DM.listVersions(allocator, table.*, context.account_id, context.namespace);
    var schemas: WorkingSchemas = .{
        .allocator = allocator,
        .client = table,
        .namespace = context.namespace,
    };

    var version_reports: std.ArrayList(M.VersionReport) = .empty;
    var overall_outcome: M.OutcomeKind = if (request.kind == .plan) .planned else .inspected;
    var top_code: ?[]const u8 = null;
    var top_message: ?[]const u8 = null;
    var recovery_cmd: ?[]const u8 = null;

    // First verify that every already-recorded version is either present with matching SHA-256 or surfaced.
    for (recorded) |rec| {
        var matched_source: ?M.SourceFile = null;
        for (request.sources) |src| {
            if (std.mem.eql(u8, src.version_id, rec.version_id)) {
                matched_source = src;
                break;
            }
        }
        if (matched_source) |src| {
            if (!std.mem.eql(u8, &rec.source_sha256, &src.sha256)) {
                if (top_code == null) {
                    overall_outcome = .checksum_mismatch;
                    top_code = "migration.checksum_mismatch";
                    top_message = try std.fmt.allocPrint(
                        allocator,
                        "Migration {s} ({s}) checksum mismatch: recorded {x}, source file has {x}",
                        .{ rec.version_id, src.path, &rec.source_sha256, &src.sha256 },
                    );
                }
            }
        }
    }

    for (request.sources) |source| {
        const parsed_steps = try splitStatements(allocator, source.sql);
        const prior = findRecordedVersion(recorded, source.version_id);
        const checksum_conflict = if (prior) |rec| !std.mem.eql(u8, &rec.source_sha256, &source.sha256) else false;

        var step_reports = try allocator.alloc(M.StepReport, parsed_steps.len);
        var has_will_apply = false;
        var has_diverged = checksum_conflict;
        var has_failed = false;
        var has_uncertain = false;

        for (parsed_steps, 0..) |parsed, idx| {
            const token = DM.stepToken(
                table.connection.scope,
                table.connection.branch,
                context.namespace,
                source.version_id,
                source.sha256,
                parsed.step_index,
                parsed.statement_digest,
            );
            const prior_step: ?DM.StepReceipt = if (prior) |rec| (if (idx < rec.steps.len) rec.steps[idx] else null) else null;

            var report: M.StepReport = .{
                .step_index = parsed.step_index,
                .owner = parsed.owner,
                .effect = parsed.effect,
                .object_name = parsed.object_name,
                .sql = parsed.sql,
                .line = parsed.line,
                .column = parsed.column,
                .statement_digest = parsed.statement_digest,
                .step_token = token,
                .state = .will_apply,
                .operation_id = if (prior_step) |ps| ps.operation_id else null,
                .commit_lsn = if (prior_step) |ps| ps.commit_lsn else null,
                .affected_rows = if (prior_step) |ps| ps.affected_rows else null,
                .expected_schema_sha256 = if (prior_step) |ps| ps.expected_schema_sha256 else null,
                .observed_schema_sha256 = if (prior_step) |ps| ps.observed_schema_sha256 else null,
                .diagnostic_code = if (prior_step) |ps| ps.diagnostic_code else null,
                .diagnostic_message = if (prior_step) |ps| ps.diagnostic_message else null,
            };

            if (checksum_conflict) {
                report.state = .already_diverged;
                report.diagnostic_code = "migration.checksum_mismatch";
                report.diagnostic_message = "Recorded migration checksum does not match current file";
                step_reports[idx] = report;
                continue;
            }

            if (prior_step) |ps| {
                if (ps.state == .failed) {
                    report.state = .failed;
                    has_failed = true;
                    if (top_code == null) {
                        overall_outcome = .step_failed;
                        top_code = ps.diagnostic_code orelse "migration.step_failed";
                        top_message = ps.diagnostic_message orelse "A previous migration step failed";
                    }
                    // Still update working schema if earlier steps succeeded; failed step did not apply.
                    step_reports[idx] = report;
                    continue;
                }
                if (ps.state == .uncertain or ps.state == .applying or ps.state == .claimed) {
                    report.state = .uncertain;
                    has_uncertain = true;
                    if (top_code == null) {
                        overall_outcome = .outcome_unknown;
                        top_code = "migration.outcome_unknown";
                        top_message = try std.fmt.allocPrint(
                            allocator,
                            "Migration {s} step {d} has an unresolved outcome; run 'transit migrate resume' to reconcile its durable token",
                            .{ source.version_id, parsed.step_index },
                        );
                        recovery_cmd = "transit migrate resume";
                    }
                    step_reports[idx] = report;
                    continue;
                }
            }

            switch (parsed.owner) {
                .authorization_grant => {
                    if (!request.allow_grants) {
                        report.state = .blocked_by_policy;
                        report.diagnostic_code = "migration.grants_not_enabled";
                        report.diagnostic_message = "Authorization statements in migrations require --allow-grants";
                        has_diverged = true;
                        if (top_code == null) {
                            overall_outcome = .drift_detected;
                            top_code = report.diagnostic_code;
                            top_message = report.diagnostic_message;
                        }
                    } else if (prior_step != null and (prior_step.?.state == .applied or prior_step.?.state == .verified)) {
                        report.state = .already_satisfied;
                    } else {
                        report.state = .will_apply;
                        has_will_apply = true;
                    }
                },
                .publication => {
                    if (!request.allow_publication) {
                        report.state = .blocked_by_policy;
                        report.diagnostic_code = "migration.publication_unsupported";
                        report.diagnostic_message = "Publication definitions belong to application/connector manifests, not schema migrations";
                        has_diverged = true;
                        if (top_code == null) {
                            overall_outcome = .drift_detected;
                            top_code = report.diagnostic_code;
                            top_message = report.diagnostic_message;
                        }
                    }
                },
                .schema_ddl => {
                    switch (parsed.effect) {
                        .create_table => {
                            var compiled = try f.TableDdl.compileDialect(allocator, parsed.sql, null, null, context.dialect);
                            defer compiled.deinit();
                            const create = compiled.statement.create;
                            const desired_schema = try (try create.bind(1)).clone(allocator);
                            const expected_fp = try DM.logicalFingerprint(desired_schema.schema);
                            report.expected_schema_sha256 = expected_fp;

                            if (try schemas.get(parsed.object_name)) |existing| {
                                const observed_fp = try DM.logicalFingerprint(existing);
                                report.observed_schema_sha256 = observed_fp;
                                const recon = try DM.reconcileCreate(existing, create);
                                switch (recon) {
                                    .satisfied => {
                                        if (create.if_not_exists or (prior_step != null and (prior_step.?.state == .applied or prior_step.?.state == .verified or prior_step.?.state == .already_satisfied))) {
                                            report.state = .already_satisfied;
                                        } else {
                                            report.state = .already_diverged;
                                            report.diagnostic_code = "migration.table_already_exists";
                                            report.diagnostic_message = try std.fmt.allocPrint(
                                                allocator,
                                                "Table '{s}' already exists and CREATE TABLE does not specify IF NOT EXISTS",
                                                .{parsed.object_name},
                                            );
                                            has_diverged = true;
                                            if (top_code == null) {
                                                overall_outcome = .drift_detected;
                                                top_code = report.diagnostic_code;
                                                top_message = report.diagnostic_message;
                                            }
                                        }
                                    },
                                    .drift => |detail| {
                                        report.state = .already_diverged;
                                        report.drift = .{
                                            .aspect = @tagName(detail.aspect),
                                            .column = if (detail.column) |col| try allocator.dupe(u8, col) else null,
                                            .expected = if (detail.expected) |exp| try allocator.dupe(u8, exp) else null,
                                            .actual = if (detail.actual) |act| try allocator.dupe(u8, act) else null,
                                        };
                                        report.diagnostic_code = "migration.schema_drift";
                                        report.diagnostic_message = try std.fmt.allocPrint(
                                            allocator,
                                            "Existing table '{s}' diverges from migration {s} on {s}{s}{s}",
                                            .{
                                                parsed.object_name,
                                                source.version_id,
                                                @tagName(detail.aspect),
                                                if (detail.column != null) " column " else "",
                                                detail.column orelse "",
                                            },
                                        );
                                        has_diverged = true;
                                        if (top_code == null) {
                                            overall_outcome = .drift_detected;
                                            top_code = report.diagnostic_code;
                                            top_message = report.diagnostic_message;
                                        }
                                    },
                                }
                            } else {
                                report.state = .will_apply;
                                has_will_apply = true;
                                try schemas.put(parsed.object_name, desired_schema.schema);
                            }
                        },
                        .alter_table => {
                            const current = try schemas.get(parsed.object_name);
                            if (prior_step != null and (prior_step.?.state == .applied or prior_step.?.state == .verified or prior_step.?.state == .already_satisfied)) {
                                report.state = .already_satisfied;
                                if (current) |existing| {
                                    const observed_fp = try DM.logicalFingerprint(existing);
                                    report.observed_schema_sha256 = observed_fp;
                                    if (report.expected_schema_sha256) |expected_fp| {
                                        if (!std.mem.eql(u8, &expected_fp, &observed_fp)) {
                                            report.state = .already_diverged;
                                            report.diagnostic_code = "migration.schema_drift";
                                            report.diagnostic_message = try std.fmt.allocPrint(
                                                allocator,
                                                "Table '{s}' schema drifted from recorded post-step fingerprint in migration {s}",
                                                .{ parsed.object_name, source.version_id },
                                            );
                                            has_diverged = true;
                                            if (top_code == null) {
                                                overall_outcome = .drift_detected;
                                                top_code = report.diagnostic_code;
                                                top_message = report.diagnostic_message;
                                            }
                                        }
                                    }
                                }
                            } else if (current) |existing| {
                                report.observed_schema_sha256 = try DM.logicalFingerprint(existing);
                                var compiled = f.TableDdl.compileDialect(allocator, parsed.sql, existing, null, context.dialect) catch |err| {
                                    report.state = .already_diverged;
                                    report.diagnostic_code = "migration.alter_compile_failed";
                                    report.diagnostic_message = try std.fmt.allocPrint(
                                        allocator,
                                        "Cannot compile ALTER TABLE on '{s}' ({s})",
                                        .{ parsed.object_name, @errorName(err) },
                                    );
                                    has_diverged = true;
                                    if (top_code == null) {
                                        overall_outcome = .drift_detected;
                                        top_code = report.diagnostic_code;
                                        top_message = report.diagnostic_message;
                                    }
                                    step_reports[idx] = report;
                                    continue;
                                };
                                defer compiled.deinit();
                                switch (compiled.statement.alter.action) {
                                    .columns => |change| {
                                        var cols_buf: [f.TableSchema.max_columns]f.TableSchema.Column = undefined;
                                        const transition = try f.TableEvolution.apply(existing, change, &cols_buf);
                                        const next_owned = try transition.after.clone(allocator);
                                        report.expected_schema_sha256 = try DM.logicalFingerprint(next_owned.schema);
                                        try schemas.put(parsed.object_name, next_owned.schema);
                                    },
                                    .rename_table => |new_name| {
                                        report.expected_schema_sha256 = try DM.logicalFingerprint(existing);
                                        try schemas.put(parsed.object_name, null);
                                        try schemas.put(new_name, existing);
                                    },
                                }
                                report.state = .will_apply;
                                has_will_apply = true;
                            } else {
                                report.state = .already_diverged;
                                report.diagnostic_code = "migration.missing_table";
                                report.diagnostic_message = try std.fmt.allocPrint(
                                    allocator,
                                    "Table '{s}' does not exist for ALTER TABLE in migration {s}",
                                    .{ parsed.object_name, source.version_id },
                                );
                                has_diverged = true;
                                if (top_code == null) {
                                    overall_outcome = .drift_detected;
                                    top_code = report.diagnostic_code;
                                    top_message = report.diagnostic_message;
                                }
                            }
                        },
                        .drop_table => {
                            const current = try schemas.get(parsed.object_name);
                            var compiled = try f.TableDdl.compileDialect(allocator, parsed.sql, current, null, context.dialect);
                            defer compiled.deinit();
                            if (current == null) {
                                if (compiled.statement.drop.if_exists or (prior_step != null and (prior_step.?.state == .applied or prior_step.?.state == .verified or prior_step.?.state == .already_satisfied))) {
                                    report.state = .already_satisfied;
                                } else {
                                    report.state = .already_diverged;
                                    report.diagnostic_code = "migration.missing_table";
                                    report.diagnostic_message = try std.fmt.allocPrint(
                                        allocator,
                                        "Table '{s}' does not exist and DROP TABLE does not specify IF EXISTS",
                                        .{parsed.object_name},
                                    );
                                    has_diverged = true;
                                    if (top_code == null) {
                                        overall_outcome = .drift_detected;
                                        top_code = report.diagnostic_code;
                                        top_message = report.diagnostic_message;
                                    }
                                }
                            } else {
                                report.observed_schema_sha256 = try DM.logicalFingerprint(current.?);
                                report.state = .will_apply;
                                has_will_apply = true;
                                try schemas.put(parsed.object_name, null);
                            }
                        },
                        .create_schema, .alter_schema, .drop_schema => {
                            if (prior_step != null and (prior_step.?.state == .applied or prior_step.?.state == .verified or prior_step.?.state == .already_satisfied)) {
                                report.state = .already_satisfied;
                            } else {
                                report.state = .will_apply;
                                has_will_apply = true;
                            }
                        },
                        else => unreachable,
                    }
                },
                .data_transform => {
                    const current = try schemas.get(parsed.object_name);
                    if (current) |existing| {
                        report.observed_schema_sha256 = try DM.logicalFingerprint(existing);
                        report.expected_schema_sha256 = report.observed_schema_sha256;
                        var compiled = f.TableDml.compileDialect(allocator, parsed.sql, parsed.object_name, existing, null, context.dialect) catch |err| {
                            report.state = .already_diverged;
                            report.diagnostic_code = "migration.dml_compile_failed";
                            report.diagnostic_message = try std.fmt.allocPrint(
                                allocator,
                                "Cannot compile data transform step on '{s}' ({s})",
                                .{ parsed.object_name, @errorName(err) },
                            );
                            has_diverged = true;
                            if (top_code == null) {
                                overall_outcome = .drift_detected;
                                top_code = report.diagnostic_code;
                                top_message = report.diagnostic_message;
                            }
                            step_reports[idx] = report;
                            continue;
                        };
                        defer compiled.deinit();
                        if (prior_step != null and (prior_step.?.state == .applied or prior_step.?.state == .verified or prior_step.?.state == .already_satisfied)) {
                            report.state = .already_satisfied;
                        } else {
                            report.state = .will_apply;
                            has_will_apply = true;
                        }
                    } else {
                        report.state = .already_diverged;
                        report.diagnostic_code = "migration.missing_table";
                        report.diagnostic_message = try std.fmt.allocPrint(
                            allocator,
                            "Table '{s}' does not exist for data transform step in migration {s}",
                            .{ parsed.object_name, source.version_id },
                        );
                        has_diverged = true;
                        if (top_code == null) {
                            overall_outcome = .drift_detected;
                            top_code = report.diagnostic_code;
                            top_message = report.diagnostic_message;
                        }
                    }
                },
                .verification => {
                    const current = try schemas.get(parsed.object_name);
                    if (current) |existing| {
                        var fields: [f.TableSchema.max_columns]f.Types.Field = undefined;
                        const row_type = try existing.rowType(&fields);
                        const basis: [32]u8 = @splat(1);
                        var compiled = f.TableSelect.compile(allocator, parsed.sql, parsed.object_name, row_type, basis, null) catch |err| {
                            report.state = .already_diverged;
                            report.diagnostic_code = "migration.verify_compile_failed";
                            report.diagnostic_message = try std.fmt.allocPrint(
                                allocator,
                                "Cannot compile verification query on '{s}' ({s})",
                                .{ parsed.object_name, @errorName(err) },
                            );
                            has_diverged = true;
                            if (top_code == null) {
                                overall_outcome = .drift_detected;
                                top_code = report.diagnostic_code;
                                top_message = report.diagnostic_message;
                            }
                            step_reports[idx] = report;
                            continue;
                        };
                        defer compiled.deinit();
                        if (prior_step != null and (prior_step.?.state == .applied or prior_step.?.state == .verified or prior_step.?.state == .already_satisfied)) {
                            report.state = .already_satisfied;
                        } else {
                            report.state = .will_apply;
                            has_will_apply = true;
                        }
                    } else {
                        report.state = .already_diverged;
                        report.diagnostic_code = "migration.missing_table";
                        report.diagnostic_message = try std.fmt.allocPrint(
                            allocator,
                            "Table '{s}' does not exist for verification query in migration {s}",
                            .{ parsed.object_name, source.version_id },
                        );
                        has_diverged = true;
                        if (top_code == null) {
                            overall_outcome = .drift_detected;
                            top_code = report.diagnostic_code;
                            top_message = report.diagnostic_message;
                        }
                    }
                },
            }
            step_reports[idx] = report;
        }

        const version_state: M.VersionState = if (has_diverged)
            .already_diverged
        else if (has_uncertain)
            .uncertain
        else if (has_failed)
            .failed
        else if (has_will_apply)
            .will_apply
        else if (prior != null and prior.?.state == .verified)
            .verified
        else
            .already_satisfied;

        const ver_digest = computeVersionDigest(source.version_id, source.sha256, step_reports);
        try version_reports.append(allocator, .{
            .version_id = source.version_id,
            .name = source.name,
            .path = source.path,
            .source_sha256 = source.sha256,
            .plan_digest = ver_digest,
            .state = version_state,
            .active_attempt_id = if (prior) |rec| rec.active_attempt_id else null,
            .claimed_at_lsn = if (prior) |rec| (if (rec.claimed_at_lsn != 0) rec.claimed_at_lsn else null) else null,
            .applied_at_lsn = if (prior) |rec| rec.applied_at_lsn else null,
            .verified_at_lsn = if (prior) |rec| rec.verified_at_lsn else null,
            .steps = step_reports,
        });
    }

    const plan_digest = computePlanDigest(target, version_reports.items);
    return .{
        .definition = p.Growth.current_definition,
        .action = request.kind,
        .outcome = overall_outcome,
        .target = target,
        .plan_digest = plan_digest,
        .versions = try version_reports.toOwnedSlice(allocator),
        .diagnostic_code = top_code,
        .diagnostic_message = top_message,
        .recovery_command = recovery_cmd,
    };
}

fn toLedgerStep(step: M.StepReport) DM.StepReceipt {
    return .{
        .step_index = step.step_index,
        .owner = @fromBackingInt(@intCast(@backingInt(step.owner))),
        .effect = @fromBackingInt(@intCast(@backingInt(step.effect))),
        .object_name = step.object_name,
        .statement_digest = step.statement_digest,
        .step_token = step.step_token,
        .state = @fromBackingInt(@intCast(@backingInt(step.state))),
        .operation_id = step.operation_id,
        .commit_lsn = step.commit_lsn,
        .affected_rows = step.affected_rows,
        .expected_schema_sha256 = step.expected_schema_sha256,
        .observed_schema_sha256 = step.observed_schema_sha256,
        .diagnostic_code = step.diagnostic_code,
        .diagnostic_message = step.diagnostic_message,
    };
}

fn toLedgerVersion(namespace: u64, principal: u64, role: ?u64, report: M.VersionReport) !DM.VersionEntry {
    return .{
        .namespace = namespace,
        .version_id = report.version_id,
        .name = report.name,
        .source_sha256 = report.source_sha256,
        .plan_digest = report.plan_digest,
        .state = @fromBackingInt(@intCast(@backingInt(report.state))),
        .active_attempt_id = report.active_attempt_id,
        .claimed_by_principal = principal,
        .claimed_by_role = role,
        .claimed_at_lsn = report.claimed_at_lsn orelse 0,
        .applied_at_lsn = report.applied_at_lsn,
        .verified_at_lsn = report.verified_at_lsn,
        .steps = &.{},
    };
}

fn saveReportVersion(
    allocator: std.mem.Allocator,
    table: *c.DirectTableClient,
    context: Context,
    report: *M.VersionReport,
    expected_revision: ?p.DataLifecycle.Position,
) !c.DirectClientToken.Progress {
    var ledger_steps = try allocator.alloc(DM.StepReceipt, report.steps.len);
    for (report.steps, 0..) |step, i| ledger_steps[i] = toLedgerStep(step);
    var entry = try toLedgerVersion(context.namespace, table.connection.principal, table.connection.role, report.*);
    entry.steps = ledger_steps;
    const progress = try DM.saveVersion(allocator, table.*, context.account_id, entry, expected_revision);
    if (report.claimed_at_lsn == null) report.claimed_at_lsn = progress.revision.next_lsn;
    return progress;
}

fn executeStepStatement(
    allocator: std.mem.Allocator,
    runtime: *g.DatabaseRuntime,
    observer: *g.Client,
    table: *c.DirectTableClient,
    context: Context,
    step: *M.StepReport,
    deadline: g.DatabaseRuntime.Deadline,
) !void {
    if (step.owner == .verification) {
        // Verify that the target table exists and query compiles against live schema.
        const live = (try lookupLiveSchema(allocator, table, context.namespace, step.object_name)) orelse return error.TableNotFound;
        var fields: [f.TableSchema.max_columns]f.Types.Field = undefined;
        const row_type = try live.rowType(&fields);
        var compiled = try f.TableSelect.compile(allocator, step.sql, step.object_name, row_type, @splat(1), null);
        defer compiled.deinit();
        step.state = .applied;
        step.observed_schema_sha256 = try DM.logicalFingerprint(live);
        return;
    }

    if (step.owner == .authorization_grant) {
        var location: f.Sql.Location = .{};
        var plan = try c.DirectAuthorizationSql.prepare(allocator, table.*, context.namespace, step.sql, .{}, &location);
        defer plan.deinit();
        const change_id = try plan.apply(table.*);
        step.operation_id = change_id;
        step.commit_lsn = change_id;
        step.state = .applied;
        return;
    }

    const read_options: g.direct.DirectRelationalQuery.Options = .{ .dialect = context.dialect };
    var statement = try g.Statement.prepare(
        allocator,
        table,
        context.namespace,
        step.sql,
        context.dialect,
        .native,
        read_options,
    );
    defer statement.deinit();

    var op_id: ?u64 = null;
    const admitted = runtime.admit(
        allocator,
        observer,
        table,
        &statement,
        &.{},
        step.step_token,
        step.statement_digest,
        deadline,
        &op_id,
    ) catch |err| {
        if (op_id) |id| step.operation_id = id;
        if (g.wire.Client.unavailable(err) or err == error.GatewayDeadline or err == error.Timeout) {
            step.state = .uncertain;
            step.diagnostic_code = "migration.outcome_unknown";
            step.diagnostic_message = "Step submission outcome is uncertain; run 'transit migrate resume' to reconcile its durable token";
            return error.MigrationOutcomeUnknown;
        }
        step.state = .failed;
        step.diagnostic_code = @errorName(err);
        step.diagnostic_message = try std.fmt.allocPrint(allocator, "Migration step {d} failed during admission: {s}", .{ step.step_index, @errorName(err) });
        return err;
    };
    const id = op_id orelse admitted.identity.id;
    step.operation_id = id;

    while (true) {
        deadline.check(runtime.io) catch {
            step.state = .uncertain;
            step.diagnostic_code = "migration.outcome_unknown";
            step.diagnostic_message = "Step execution timed out after admission; run 'transit migrate resume' to reconcile its durable token";
            return error.MigrationOutcomeUnknown;
        };
        runtime.resumeOperation(observer, id) catch |err| {
            if (g.wire.Client.unavailable(err) or err == error.GatewayDeadline or err == error.Timeout) {
                step.state = .uncertain;
                step.diagnostic_code = "migration.outcome_unknown";
                step.diagnostic_message = "Step execution interrupted after admission; run 'transit migrate resume' to reconcile its durable token";
                return error.MigrationOutcomeUnknown;
            }
            step.state = .failed;
            step.diagnostic_code = @errorName(err);
            step.diagnostic_message = try std.fmt.allocPrint(allocator, "Migration step {d} failed: {s}", .{ step.step_index, @errorName(err) });
            return err;
        };
        const current = runtime.status(allocator, observer, table, context.namespace, id) catch |err| {
            if (g.wire.Client.unavailable(err) or err == error.GatewayDeadline or err == error.Timeout) {
                step.state = .uncertain;
                step.diagnostic_code = "migration.outcome_unknown";
                step.diagnostic_message = "Step status inspection interrupted; run 'transit migrate resume' to reconcile its durable token";
                return error.MigrationOutcomeUnknown;
            }
            step.state = .failed;
            step.diagnostic_code = @errorName(err);
            step.diagnostic_message = try std.fmt.allocPrint(allocator, "Migration step {d} status failed: {s}", .{ step.step_index, @errorName(err) });
            return err;
        };
        if (current.phase == .terminal) {
            step.commit_lsn = current.identity.id;
            step.affected_rows = current.changed;
            if (current.outcome == .succeeded) {
                step.state = .applied;
                return;
            }
            step.state = .failed;
            step.diagnostic_code = if (current.diagnostic) |diag| diag.code.slice() else "migration.step_failed";
            step.diagnostic_message = if (current.diagnostic) |diag| diag.summary.slice() else "Migration step execution failed";
            return error.MigrationStepFailed;
        }
        runtime.io.sleep(.fromMilliseconds(5), .awake) catch {};
    }
}

fn verifyVersionSteps(
    allocator: std.mem.Allocator,
    table: *c.DirectTableClient,
    context: Context,
    version: *M.VersionReport,
) !bool {
    // Only verify the final schema state of each table modified in this version.
    for (version.steps, 0..) |*step, idx| {
        if (step.owner == .schema_ddl and (step.effect == .create_table or step.effect == .alter_table or step.effect == .drop_table)) {
            // Check whether a later step in this same version also modifies or drops this table.
            var modified_later = false;
            for (version.steps[idx + 1 ..]) |later| {
                if (later.owner == .schema_ddl and std.mem.eql(u8, later.object_name, step.object_name)) {
                    modified_later = true;
                    break;
                }
            }
            if (modified_later) {
                step.state = .verified;
                continue;
            }
            const live = try lookupLiveSchema(allocator, table, context.namespace, step.object_name);
            if (step.effect == .drop_table) {
                if (live != null) {
                    step.state = .already_diverged;
                    step.diagnostic_code = "migration.verify_failed";
                    step.diagnostic_message = try std.fmt.allocPrint(allocator, "Table '{s}' still exists after DROP TABLE", .{step.object_name});
                    version.state = .already_diverged;
                    return false;
                }
                step.state = .verified;
                continue;
            }
            if (live) |schema| {
                const observed_fp = try DM.logicalFingerprint(schema);
                step.observed_schema_sha256 = observed_fp;
                if (step.expected_schema_sha256) |expected_fp| {
                    if (!std.mem.eql(u8, &expected_fp, &observed_fp)) {
                        step.state = .already_diverged;
                        step.diagnostic_code = "migration.schema_drift";
                        step.diagnostic_message = try std.fmt.allocPrint(allocator, "Postcondition schema fingerprint mismatch on table '{s}'", .{step.object_name});
                        version.state = .already_diverged;
                        return false;
                    }
                }
                step.state = .verified;
            } else {
                step.state = .already_diverged;
                step.diagnostic_code = "migration.verify_failed";
                step.diagnostic_message = try std.fmt.allocPrint(allocator, "Table '{s}' missing after migration step", .{step.object_name});
                version.state = .already_diverged;
                return false;
            }
        } else {
            step.state = .verified;
        }
    }
    return true;
}

fn applyMigrations(
    allocator: std.mem.Allocator,
    runtime: *g.DatabaseRuntime,
    observer: *g.Client,
    table: *c.DirectTableClient,
    context: Context,
    target: M.ObservedTarget,
    request: M.Request,
    deadline: g.DatabaseRuntime.Deadline,
) !M.Report {
    var plan = try buildPlanReport(allocator, table, context, target, request);
    plan.action = .apply;

    if (plan.outcome != .planned and plan.outcome != .inspected) {
        return plan;
    }

    if (request.expected_plan_digest) |expected_digest| {
        if (!std.mem.eql(u8, &expected_digest, &plan.plan_digest)) {
            plan.outcome = .drift_detected;
            plan.diagnostic_code = "migration.plan_digest_mismatch";
            plan.diagnostic_message = "Live catalog or source files changed since the migration plan was generated; re-run 'transit migrate plan'";
            return plan;
        }
    }

    var attempt_id: [16]u8 = undefined;
    if (request.attempt_id) |supplied| {
        attempt_id = supplied;
    } else {
        try runtime.io.randomSecure(&attempt_id);
    }
    plan.attempt_id = attempt_id;

    var any_applied = false;
    const versions_mut = @constCast(plan.versions);

    for (versions_mut) |*version| {
        const existing = try DM.readVersion(allocator, table.*, context.account_id, context.namespace, version.version_id);
        var expected_rev: ?p.DataLifecycle.Position = if (existing) |ex| ex.progress.revision else null;

        if (existing) |ex| {
            if (!std.mem.eql(u8, &ex.entry.source_sha256, &version.source_sha256)) {
                plan.outcome = .checksum_mismatch;
                plan.diagnostic_code = "migration.checksum_mismatch";
                plan.diagnostic_message = try std.fmt.allocPrint(allocator, "Migration {s} checksum mismatch against durable ledger", .{version.version_id});
                return plan;
            }
            if ((ex.entry.state == .claimed or ex.entry.state == .applying) and ex.entry.active_attempt_id != null and !std.mem.eql(u8, &ex.entry.active_attempt_id.?, &attempt_id)) {
                version.state = .claimed;
                version.active_attempt_id = ex.entry.active_attempt_id;
                plan.outcome = .claim_conflict;
                plan.diagnostic_code = "migration.claim_conflict";
                plan.diagnostic_message = try std.fmt.allocPrint(allocator, "Migration {s} is actively claimed by another runner attempt ({x})", .{ version.version_id, &ex.entry.active_attempt_id.? });
                plan.recovery_command = "transit migrate status";
                return plan;
            }
            if (ex.entry.state == .uncertain) {
                version.state = .uncertain;
                plan.outcome = .outcome_unknown;
                plan.diagnostic_code = "migration.outcome_unknown";
                plan.diagnostic_message = try std.fmt.allocPrint(allocator, "Migration {s} has an uncertain outcome; run 'transit migrate resume' before applying further migrations", .{version.version_id});
                plan.recovery_command = "transit migrate resume";
                return plan;
            }
            if (ex.entry.state == .failed) {
                version.state = .failed;
                plan.outcome = .step_failed;
                plan.diagnostic_code = "migration.previous_attempt_failed";
                plan.diagnostic_message = try std.fmt.allocPrint(allocator, "Migration {s} failed in a previous attempt; inspect with 'transit migrate status' or 'transit migrate resume'", .{version.version_id});
                plan.recovery_command = "transit migrate resume";
                return plan;
            }
            if (ex.entry.state == .verified) {
                version.state = .verified;
                continue;
            }
        }

        if (version.state == .already_satisfied) {
            if (existing == null or existing.?.entry.state != .verified) {
                if (try verifyVersionSteps(allocator, table, context, version)) {
                    version.state = .verified;
                    version.active_attempt_id = null;
                    const saved = saveReportVersion(allocator, table, context, version, expected_rev) catch |err| {
                        if (err == error.MigrationClaimConflict) {
                            plan.outcome = .claim_conflict;
                            plan.diagnostic_code = "migration.claim_conflict";
                            plan.diagnostic_message = "Concurrent migration runner claimed this version";
                            return plan;
                        }
                        return err;
                    };
                    version.verified_at_lsn = saved.revision.next_lsn;
                    _ = try saveReportVersion(allocator, table, context, version, saved.revision);
                } else {
                    plan.outcome = .drift_detected;
                    plan.diagnostic_code = "migration.schema_drift";
                    plan.diagnostic_message = "Postcondition verification detected schema drift";
                    return plan;
                }
            }
            continue;
        }

        // Claim the version before executing its steps.
        version.state = .claimed;
        version.active_attempt_id = attempt_id;
        var progress = saveReportVersion(allocator, table, context, version, expected_rev) catch |err| {
            if (err == error.MigrationClaimConflict) {
                plan.outcome = .claim_conflict;
                plan.diagnostic_code = "migration.claim_conflict";
                plan.diagnostic_message = try std.fmt.allocPrint(allocator, "Concurrent migration runner claimed version {s}", .{version.version_id});
                return plan;
            }
            return err;
        };
        expected_rev = progress.revision;

        version.state = .applying;
        const steps_mut = @constCast(version.steps);
        for (steps_mut) |*step| {
            if (step.state == .already_satisfied or step.state == .applied or step.state == .verified) continue;
            step.state = .applying;
            progress = try saveReportVersion(allocator, table, context, version, expected_rev);
            expected_rev = progress.revision;

            executeStepStatement(allocator, runtime, observer, table, context, step, deadline) catch |err| {
                if (err == error.MigrationOutcomeUnknown or step.state == .uncertain) {
                    version.state = .uncertain;
                    _ = saveReportVersion(allocator, table, context, version, expected_rev) catch {};
                    plan.outcome = .outcome_unknown;
                    plan.diagnostic_code = step.diagnostic_code orelse "migration.outcome_unknown";
                    plan.diagnostic_message = step.diagnostic_message orelse "Migration step outcome is uncertain";
                    plan.recovery_command = "transit migrate resume";
                    return plan;
                }
                version.state = .failed;
                version.active_attempt_id = null;
                _ = saveReportVersion(allocator, table, context, version, expected_rev) catch {};
                plan.outcome = .step_failed;
                plan.diagnostic_code = step.diagnostic_code orelse @errorName(err);
                plan.diagnostic_message = step.diagnostic_message orelse "Migration step failed";
                return plan;
            };

            any_applied = true;
            progress = try saveReportVersion(allocator, table, context, version, expected_rev);
            expected_rev = progress.revision;
        }

        version.state = .applied;
        version.applied_at_lsn = expected_rev.?.next_lsn;
        if (!try verifyVersionSteps(allocator, table, context, version)) {
            version.active_attempt_id = null;
            _ = saveReportVersion(allocator, table, context, version, expected_rev) catch {};
            plan.outcome = .drift_detected;
            plan.diagnostic_code = "migration.verify_failed";
            plan.diagnostic_message = "Post-apply catalog verification failed";
            return plan;
        }
        version.state = .verified;
        version.active_attempt_id = null;
        version.verified_at_lsn = expected_rev.?.next_lsn;
        progress = try saveReportVersion(allocator, table, context, version, expected_rev);
        version.verified_at_lsn = progress.revision.next_lsn;
    }

    plan.outcome = if (any_applied) .applied else .already_satisfied;
    return plan;
}

fn statusReport(
    allocator: std.mem.Allocator,
    runtime: *g.DatabaseRuntime,
    observer: *g.Client,
    table: *c.DirectTableClient,
    context: Context,
    target: M.ObservedTarget,
    request: M.Request,
) !M.Report {
    _ = runtime;
    _ = observer;
    if (request.sources.len != 0) {
        var report = try buildPlanReport(allocator, table, context, target, request);
        report.action = .status;
        return report;
    }
    const recorded = try DM.listVersions(allocator, table.*, context.account_id, context.namespace);
    var versions = try allocator.alloc(M.VersionReport, recorded.len);
    var outcome: M.OutcomeKind = .inspected;
    var code: ?[]const u8 = null;
    var message: ?[]const u8 = null;
    var recovery: ?[]const u8 = null;

    for (recorded, 0..) |rec, i| {
        var steps = try allocator.alloc(M.StepReport, rec.steps.len);
        for (rec.steps, 0..) |step, j| {
            steps[j] = .{
                .step_index = step.step_index,
                .owner = @fromBackingInt(@intCast(@backingInt(step.owner))),
                .effect = @fromBackingInt(@intCast(@backingInt(step.effect))),
                .object_name = step.object_name,
                .sql = "",
                .line = 1,
                .column = 1,
                .statement_digest = step.statement_digest,
                .step_token = step.step_token,
                .state = @fromBackingInt(@intCast(@backingInt(step.state))),
                .operation_id = step.operation_id,
                .commit_lsn = step.commit_lsn,
                .affected_rows = step.affected_rows,
                .expected_schema_sha256 = step.expected_schema_sha256,
                .observed_schema_sha256 = step.observed_schema_sha256,
                .diagnostic_code = step.diagnostic_code,
                .diagnostic_message = step.diagnostic_message,
            };
        }
        const vstate: M.VersionState = @fromBackingInt(@intCast(@backingInt(rec.state)));
        if (vstate == .uncertain or vstate == .claimed or vstate == .applying) {
            outcome = .outcome_unknown;
            code = "migration.outcome_unknown";
            message = "One or more migration versions have unresolved in-flight steps";
            recovery = "transit migrate resume";
        } else if (vstate == .failed and outcome == .inspected) {
            outcome = .step_failed;
            code = "migration.step_failed";
            message = "A recorded migration version is in failed state";
            recovery = "transit migrate resume";
        }
        versions[i] = .{
            .version_id = rec.version_id,
            .name = rec.name,
            .path = rec.version_id,
            .source_sha256 = rec.source_sha256,
            .plan_digest = rec.plan_digest,
            .state = vstate,
            .active_attempt_id = rec.active_attempt_id,
            .claimed_at_lsn = if (rec.claimed_at_lsn != 0) rec.claimed_at_lsn else null,
            .applied_at_lsn = rec.applied_at_lsn,
            .verified_at_lsn = rec.verified_at_lsn,
            .steps = steps,
        };
    }

    return .{
        .definition = p.Growth.current_definition,
        .action = .status,
        .outcome = outcome,
        .target = target,
        .plan_digest = computePlanDigest(target, versions),
        .versions = versions,
        .diagnostic_code = code,
        .diagnostic_message = message,
        .recovery_command = recovery,
    };
}

fn resumeExecution(
    allocator: std.mem.Allocator,
    runtime: *g.DatabaseRuntime,
    observer: *g.Client,
    table: *c.DirectTableClient,
    context: Context,
    target: M.ObservedTarget,
    request: M.Request,
    deadline: g.DatabaseRuntime.Deadline,
) !M.Report {
    const dir = try DM.readDirectory(allocator, table.*, context.account_id, context.namespace);
    for (dir.directory.versions) |version_id| {
        const inspected = (try DM.readVersion(allocator, table.*, context.account_id, context.namespace, version_id)) orelse continue;
        var entry = inspected.entry;
        var expected_rev = inspected.progress.revision;
        if (request.attempt_id) |req_attempt| {
            if (entry.active_attempt_id != null and !std.mem.eql(u8, &entry.active_attempt_id.?, &req_attempt)) continue;
        }
        if (entry.state != .claimed and entry.state != .applying and entry.state != .uncertain and entry.state != .failed) continue;

        const steps_mut = try allocator.dupe(DM.StepReceipt, entry.steps);
        var all_settled = true;
        var any_failed = false;

        for (steps_mut) |*step| {
            if (step.state == .applied or step.state == .verified or step.state == .already_satisfied) continue;
            // Reconcile the deterministic step token in DirectCatalog.
            if (try runtime.lookup(observer, step.step_token, step.statement_digest)) |op_record| {
                const op_id = op_record.identity.id;
                step.operation_id = op_id;
                try runtime.resumeOperation(observer, op_id);
                const status = try runtime.status(allocator, observer, table, context.namespace, op_id);
                if (status.phase == .terminal) {
                    step.commit_lsn = status.identity.id;
                    step.affected_rows = status.changed;
                    if (status.outcome == .succeeded) {
                        step.state = .applied;
                        step.diagnostic_code = null;
                        step.diagnostic_message = null;
                    } else {
                        step.state = .failed;
                        any_failed = true;
                    }
                } else {
                    step.state = .uncertain;
                    all_settled = false;
                }
            } else if (step.state == .applying or step.state == .uncertain or step.state == .claimed) {
                // Token was never bound before interruption; reset to pending so apply can run it cleanly.
                step.state = .pending;
                all_settled = false;
            } else {
                all_settled = false;
            }
        }

        entry.steps = steps_mut;
        if (any_failed) {
            entry.state = .failed;
            entry.active_attempt_id = null;
        } else if (all_settled) {
            entry.state = .verified;
            entry.active_attempt_id = null;
            entry.applied_at_lsn = expected_rev.next_lsn;
            entry.verified_at_lsn = expected_rev.next_lsn;
            for (steps_mut) |*step| step.state = .verified;
        } else {
            // Release stale claim so subsequent apply (below if sources supplied) can proceed with exact step tokens.
            entry.state = .pending;
            entry.active_attempt_id = null;
        }
        expected_rev = (try DM.saveVersion(allocator, table.*, context.account_id, entry, expected_rev)).revision;
    }

    if (request.sources.len != 0) {
        var apply_req = request;
        apply_req.kind = .apply;
        var report = try applyMigrations(allocator, runtime, observer, table, context, target, apply_req, deadline);
        report.action = .@"resume";
        return report;
    }

    var report = try statusReport(allocator, runtime, observer, table, context, target, request);
    report.action = .@"resume";
    if (report.outcome == .inspected) report.outcome = .verified;
    return report;
}

fn verifyMigrations(
    allocator: std.mem.Allocator,
    table: *c.DirectTableClient,
    context: Context,
    target: M.ObservedTarget,
    request: M.Request,
) !M.Report {
    if (request.sources.len != 0) {
        var plan = try buildPlanReport(allocator, table, context, target, request);
        plan.action = .verify;
        if (plan.outcome != .planned and plan.outcome != .inspected) return plan;
        for (plan.versions) |ver| {
            if (ver.state == .will_apply or ver.state == .pending) {
                plan.outcome = .drift_detected;
                plan.diagnostic_code = "migration.unapplied_version";
                plan.diagnostic_message = try std.fmt.allocPrint(allocator, "Migration {s} has not been applied to target schema '{s}'", .{ ver.version_id, context.schema });
                return plan;
            }
        }
        plan.outcome = .verified;
        return plan;
    }

    var status = try statusReport(allocator, undefined, undefined, table, context, target, request);
    status.action = .verify;
    if (status.outcome != .inspected) return status;

    const versions_mut = @constCast(status.versions);
    for (versions_mut) |*ver| {
        if (!try verifyVersionSteps(allocator, table, context, ver)) {
            status.outcome = .drift_detected;
            status.diagnostic_code = "migration.schema_drift";
            status.diagnostic_message = try std.fmt.allocPrint(allocator, "Live catalog schema drifted from recorded migration {s}", .{ver.version_id});
            return status;
        }
    }
    status.outcome = .verified;
    return status;
}

test "splitStatements separates multi-statement SQL while preserving comments, strings and line coordinates" {
    const t = std.testing;
    const sql_text =
        \\-- Initial schema comment; with semicolon
        \\CREATE TABLE IF NOT EXISTS accounts (
        \\    id INT64 PRIMARY KEY,
        \\    label TEXT DEFAULT 'a;b;c' NOT NULL
        \\);
        \\/* multi-line; comment */
        \\INSERT INTO accounts (id, label) VALUES (1, 'seed;value');
        \\SELECT id, label FROM accounts WHERE id = 1;
    ;
    const steps = try splitStatements(t.allocator, sql_text);
    defer {
        for (steps) |step| {
            t.allocator.free(step.object_name);
            t.allocator.free(step.sql);
        }
        t.allocator.free(steps);
    }
    try t.expectEqual(@as(usize, 3), steps.len);
    try t.expectEqual(M.StepOwner.schema_ddl, steps[0].owner);
    try t.expectEqual(M.StepEffect.create_table, steps[0].effect);
    try t.expectEqualStrings("accounts", steps[0].object_name);
    try t.expectEqual(@as(u32, 2), steps[0].line);

    try t.expectEqual(M.StepOwner.data_transform, steps[1].owner);
    try t.expectEqual(M.StepEffect.insert_rows, steps[1].effect);
    try t.expectEqualStrings("accounts", steps[1].object_name);
    try t.expectEqual(@as(u32, 7), steps[1].line);

    try t.expectEqual(M.StepOwner.verification, steps[2].owner);
    try t.expectEqual(M.StepEffect.verify_query, steps[2].effect);
    try t.expectEqualStrings("accounts", steps[2].object_name);
    try t.expectEqual(@as(u32, 8), steps[2].line);
}
