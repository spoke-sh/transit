//! Declarative application schema migration protocol and plan/result contracts.
const std = @import("std");
const api = @import("root.zig");

pub const plan_format = "transit_migration_plan_v1";
pub const result_format = "migration_result_v1";
pub const max_sources = 256;
pub const max_steps_per_version = 64;
pub const max_version_id_bytes = 64;
pub const max_name_bytes = 128;
pub const max_path_bytes = 512;

pub const SourceFile = struct {
    version_id: []const u8,
    name: []const u8,
    path: []const u8,
    sql: []const u8,
    sha256: [32]u8,

    pub fn validate(self: SourceFile) !void {
        if (self.version_id.len == 0 or self.version_id.len > max_version_id_bytes) return error.InvalidMigrationVersion;
        if (self.name.len == 0 or self.name.len > max_name_bytes) return error.InvalidMigrationVersion;
        if (self.path.len == 0 or self.path.len > max_path_bytes) return error.InvalidMigrationVersion;
        if (self.sql.len == 0 or self.sql.len > api.max_sql_bytes) return error.InvalidSqlText;
        try api.fuze.Sql.validateText(self.sql);
        var computed: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(self.sql, &computed, .{});
        if (!std.mem.eql(u8, &computed, &self.sha256)) return error.MigrationChecksumMismatch;
    }
};

pub const TargetAssertion = struct {
    database: ?[]const u8 = null,
    schema: ?[]const u8 = null,
    branch: ?u64 = null,
    account: ?[]const u8 = null,
    role: ?[]const u8 = null,

    pub fn validate(self: TargetAssertion) !void {
        if (self.database) |value| if (value.len == 0 or value.len > 63) return error.InvalidSqlName;
        if (self.schema) |value| if (value.len == 0 or value.len > 63) return error.InvalidSqlName;
        if (self.account) |value| if (value.len == 0 or value.len > 63) return error.InvalidSqlName;
        if (self.role) |value| if (value.len == 0 or value.len > 63) return error.InvalidSqlName;
        if (self.branch) |value| if (value == 0) return error.InvalidMigrationTarget;
    }
};

pub const StepOwner = enum {
    schema_ddl,
    data_transform,
    authorization_grant,
    publication,
    verification,
};

pub const StepEffect = enum {
    create_table,
    alter_table,
    drop_table,
    create_schema,
    alter_schema,
    drop_schema,
    insert_rows,
    update_rows,
    delete_rows,
    grant_privilege,
    publish_resource,
    verify_query,
};

pub const StepState = enum {
    pending,
    will_apply,
    already_satisfied,
    already_diverged,
    blocked_by_policy,
    claimed,
    applying,
    applied,
    verified,
    failed,
    uncertain,
};

pub const VersionState = enum {
    pending,
    will_apply,
    already_satisfied,
    already_diverged,
    claimed,
    applying,
    applied,
    verified,
    failed,
    uncertain,
};

pub const Drift = struct {
    aspect: []const u8,
    column: ?[]const u8 = null,
    expected: ?[]const u8 = null,
    actual: ?[]const u8 = null,
};

pub const StepReport = struct {
    step_index: u16,
    owner: StepOwner,
    effect: StepEffect,
    object_name: []const u8,
    sql: []const u8,
    line: u32,
    column: u32,
    statement_digest: [32]u8,
    step_token: [16]u8,
    state: StepState,
    operation_id: ?u64 = null,
    commit_lsn: ?u64 = null,
    affected_rows: ?u64 = null,
    expected_schema_sha256: ?[32]u8 = null,
    observed_schema_sha256: ?[32]u8 = null,
    drift: ?Drift = null,
    diagnostic_code: ?[]const u8 = null,
    diagnostic_message: ?[]const u8 = null,
};

pub const VersionReport = struct {
    version_id: []const u8,
    name: []const u8,
    path: []const u8,
    source_sha256: [32]u8,
    plan_digest: [32]u8,
    state: VersionState,
    active_attempt_id: ?[16]u8 = null,
    claimed_at_lsn: ?u64 = null,
    applied_at_lsn: ?u64 = null,
    verified_at_lsn: ?u64 = null,
    steps: []const StepReport,
};

pub const ObservedTarget = struct {
    realm: u64,
    resource: u64,
    catalog: u64,
    branch: u64,
    namespace: u64,
    database: []const u8,
    schema: []const u8,
    account: []const u8,
    principal: u64,
    role: ?u64 = null,
};

pub const ActionKind = enum {
    plan,
    inspect,
    apply,
    status,
    @"resume",
    verify,
};

pub const OutcomeKind = enum {
    planned,
    inspected,
    applied,
    already_satisfied,
    verified,
    drift_detected,
    checksum_mismatch,
    target_mismatch,
    claim_conflict,
    step_failed,
    outcome_unknown,
};

pub const Request = struct {
    kind: ActionKind,
    target: TargetAssertion = .{},
    sources: []const SourceFile = &.{},
    expected_plan_digest: ?[32]u8 = null,
    attempt_id: ?[16]u8 = null,
    allow_grants: bool = false,
    allow_publication: bool = false,

    pub fn validate(self: Request) !void {
        try self.target.validate();
        if (self.sources.len > max_sources) return error.TooManyMigrationSources;
        switch (self.kind) {
            .plan, .inspect, .apply => if (self.sources.len == 0) return error.MigrationSourcesRequired,
            .status, .@"resume", .verify => {},
        }
        for (self.sources, 0..) |source, index| {
            try source.validate();
            for (self.sources[0..index]) |earlier| {
                if (std.mem.eql(u8, earlier.version_id, source.version_id)) return error.DuplicateMigrationVersion;
                if (std.mem.order(u8, earlier.version_id, source.version_id) != .lt) return error.UnsortedMigrationSources;
            }
        }
    }
};

pub const Report = struct {
    format: []const u8 = result_format,
    definition: api.native.Definition,
    action: ActionKind,
    outcome: OutcomeKind,
    target: ObservedTarget,
    plan_digest: [32]u8,
    attempt_id: ?[16]u8 = null,
    versions: []const VersionReport,
    diagnostic_code: ?[]const u8 = null,
    diagnostic_message: ?[]const u8 = null,
    recovery_command: ?[]const u8 = null,

    pub fn validate(self: Report) !void {
        if (!std.mem.eql(u8, self.format, result_format) or self.definition != api.native.current_definition) return error.IncompatibleSqlDefinition;
        if (self.versions.len > max_sources) return error.TooManyMigrationSources;
    }
};

pub const SavedPlan = struct {
    format: []const u8 = plan_format,
    definition: api.native.Definition,
    target: ObservedTarget,
    plan_digest: [32]u8,
    allow_grants: bool = false,
    allow_publication: bool = false,
    sources: []const SourceFile,
    versions: []const VersionReport,

    pub fn validate(self: SavedPlan) !void {
        if (!std.mem.eql(u8, self.format, plan_format) or self.definition != api.native.current_definition) return error.IncompatibleSqlDefinition;
        if (self.sources.len == 0 or self.sources.len > max_sources) return error.TooManyMigrationSources;
        for (self.sources) |source| try source.validate();
    }
};

test "migration request validates sorted version ordering and source SHA-256 digests" {
    const t = std.testing;
    const sql_a = "CREATE TABLE items (id INT64 PRIMARY KEY);";
    var sha_a: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(sql_a, &sha_a, .{});
    const req: Request = .{
        .kind = .plan,
        .sources = &.{.{
            .version_id = "0001",
            .name = "init",
            .path = "0001-init.sql",
            .sql = sql_a,
            .sha256 = sha_a,
        }},
    };
    try req.validate();
    var bad_sha = req;
    var corrupted = sha_a;
    corrupted[0] ^= 1;
    bad_sha.sources = &.{.{
        .version_id = "0001",
        .name = "init",
        .path = "0001-init.sql",
        .sql = sql_a,
        .sha256 = corrupted,
    }};
    try t.expectError(error.MigrationChecksumMismatch, bad_sha.validate());
}
