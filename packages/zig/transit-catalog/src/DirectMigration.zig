//! Direct catalog migration ledger and live Table schema reconciliation.
//! Ledger entries are content-addressed in DirectRecord and updated atomically
//! through DirectClientToken compare-and-swap revisions without Station actors.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const f = c.fuze;

pub const definition = "transit.direct.migration.v1.2026-10-30";
pub const directory_format: u32 = 0x544d4431; // "TMD1"
pub const version_format: u32 = 0x544d5631; // "TMV1"
pub const max_versions = 256;
pub const max_steps = 64;
pub const max_version_id_bytes = 64;
pub const max_name_bytes = 128;

pub const DriftAspect = enum {
    column_count,
    missing_column,
    extra_column,
    column_order,
    column_type,
    max_characters,
    nullability,
    default_value,
    encoding,
    collation,
    primary_key,
};

pub const DriftDetail = struct {
    aspect: DriftAspect,
    column: ?[]const u8 = null,
    expected: ?[]const u8 = null,
    actual: ?[]const u8 = null,
};

pub const Reconciliation = union(enum) {
    satisfied,
    drift: DriftDetail,
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

pub const StepReceipt = struct {
    step_index: u16,
    owner: StepOwner,
    effect: StepEffect,
    object_name: []const u8,
    statement_digest: [32]u8,
    step_token: [16]u8,
    state: StepState,
    operation_id: ?u64 = null,
    commit_lsn: ?u64 = null,
    affected_rows: ?u64 = null,
    expected_schema_sha256: ?[32]u8 = null,
    observed_schema_sha256: ?[32]u8 = null,
    diagnostic_code: ?[]const u8 = null,
    diagnostic_message: ?[]const u8 = null,
};

pub const VersionEntry = struct {
    definition: []const u8 = definition,
    namespace: u64,
    version_id: []const u8,
    name: []const u8,
    source_sha256: [32]u8,
    plan_digest: [32]u8,
    state: VersionState,
    active_attempt_id: ?[16]u8 = null,
    claimed_by_principal: u64,
    claimed_by_role: ?u64 = null,
    claimed_at_lsn: u64 = 0,
    applied_at_lsn: ?u64 = null,
    verified_at_lsn: ?u64 = null,
    steps: []const StepReceipt,

    pub fn validate(self: VersionEntry) !void {
        if (!std.mem.eql(u8, self.definition, definition)) return error.IncompatibleDefinition;
        if (self.namespace == 0) return error.InvalidTableNamespace;
        if (self.version_id.len == 0 or self.version_id.len > max_version_id_bytes) return error.InvalidMigrationVersion;
        if (self.name.len == 0 or self.name.len > max_name_bytes) return error.InvalidMigrationVersion;
        if (self.steps.len == 0 or self.steps.len > max_steps) return error.InvalidMigrationStepCount;
        for (self.steps, 0..) |step, index| {
            if (step.step_index != index + 1) return error.InvalidMigrationStepIndex;
        }
    }
};

pub const Directory = struct {
    definition: []const u8 = definition,
    namespace: u64,
    versions: []const []const u8,

    pub fn validate(self: Directory) !void {
        if (!std.mem.eql(u8, self.definition, definition)) return error.IncompatibleDefinition;
        if (self.namespace == 0) return error.InvalidTableNamespace;
        if (self.versions.len > max_versions) return error.MigrationDirectoryCapacity;
        for (self.versions, 0..) |version, index| {
            if (version.len == 0 or version.len > max_version_id_bytes) return error.InvalidMigrationVersion;
            for (self.versions[0..index]) |earlier| {
                if (std.mem.eql(u8, earlier, version)) return error.DuplicateMigrationVersion;
            }
        }
    }
};

/// Canonical SHA-256 fingerprint of a Table's logical and physical column and
/// key shape, independent of catalog object ID, revision or internal ColumnId.
pub fn logicalFingerprint(schema: f.TableSchema.Schema) ![32]u8 {
    if (schema.columns.len == 0 or schema.columns.len > f.TableSchema.max_columns) return error.InvalidColumnCount;
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.migration.logical-schema.v1\x00");
    var count_bytes: [2]u8 = undefined;
    std.mem.writeInt(u16, &count_bytes, @intCast(schema.columns.len), .little);
    hash.update(&count_bytes);
    var descriptor: [f.Types.max_encoding_bytes]u8 = undefined;
    var default_bytes: [f.TableSchema.max_bytes]u8 = undefined;
    for (schema.columns) |column| {
        hash.update(&.{@intCast(column.name.len)});
        hash.update(column.name);
        const type_bytes = try column.type.encode(&descriptor);
        std.mem.writeInt(u16, &count_bytes, @intCast(type_bytes.len), .little);
        hash.update(&count_bytes);
        hash.update(type_bytes);
        var max_chars: [4]u8 = undefined;
        std.mem.writeInt(u32, &max_chars, column.max_characters orelse 0, .little);
        hash.update(&max_chars);
        hash.update(&.{
            @intFromBool(column.nullable),
            @backingInt(column.encoding),
            @backingInt(column.collation),
            @intFromBool(column.default != null),
        });
        if (column.default) |cell| {
            const encoded = try f.Types.Codec.encode(cell, column.field(), &default_bytes);
            var len_bytes: [4]u8 = undefined;
            std.mem.writeInt(u32, &len_bytes, @intCast(encoded.len), .little);
            hash.update(&len_bytes);
            hash.update(encoded);
        }
    }
    std.mem.writeInt(u16, &count_bytes, @intCast(schema.primary_key.len), .little);
    hash.update(&count_bytes);
    for (schema.primary_key) |pk_id| {
        const col_index = try schema.index(pk_id);
        const pk_name = schema.columns[col_index].name;
        hash.update(&.{@intCast(pk_name.len)});
        hash.update(pk_name);
    }
    return hash.finalResult();
}

/// Reconciles a live TableSchema against a desired CREATE TABLE declaration.
/// IF NOT EXISTS never masks column, type, nullability, default, encoding,
/// collation or primary-key differences.
pub fn reconcileCreate(existing: f.TableSchema.Schema, desired: f.TableDdl.Create) !Reconciliation {
    for (desired.columns) |expected| {
        var found = false;
        for (existing.columns) |actual| {
            if (std.mem.eql(u8, actual.name, expected.name)) {
                found = true;
                break;
            }
        }
        if (!found) return .{ .drift = .{ .aspect = .missing_column, .column = expected.name } };
    }
    for (existing.columns) |actual| {
        var found = false;
        for (desired.columns) |expected| {
            if (std.mem.eql(u8, actual.name, expected.name)) {
                found = true;
                break;
            }
        }
        if (!found) return .{ .drift = .{ .aspect = .extra_column, .column = actual.name } };
    }
    if (existing.columns.len != desired.columns.len) {
        return .{ .drift = .{ .aspect = .column_count } };
    }
    var actual_type_buf: [f.Types.max_encoding_bytes]u8 = undefined;
    var expected_type_buf: [f.Types.max_encoding_bytes]u8 = undefined;
    var actual_default_buf: [f.TableSchema.max_bytes]u8 = undefined;
    var expected_default_buf: [f.TableSchema.max_bytes]u8 = undefined;
    for (existing.columns, desired.columns) |actual, expected| {
        if (!std.mem.eql(u8, actual.name, expected.name)) {
            return .{ .drift = .{
                .aspect = .column_order,
                .column = expected.name,
                .expected = expected.name,
                .actual = actual.name,
            } };
        }
        const actual_type = try actual.type.encode(&actual_type_buf);
        const expected_type = try expected.type.encode(&expected_type_buf);
        if (!std.mem.eql(u8, actual_type, expected_type)) {
            return .{ .drift = .{
                .aspect = .column_type,
                .column = expected.name,
                .expected = @tagName(expected.type),
                .actual = @tagName(actual.type),
            } };
        }
        if (actual.max_characters != expected.max_characters) {
            return .{ .drift = .{
                .aspect = .max_characters,
                .column = expected.name,
            } };
        }
        if (actual.nullable != expected.nullable) {
            return .{ .drift = .{
                .aspect = .nullability,
                .column = expected.name,
                .expected = if (expected.nullable) "NULL" else "NOT NULL",
                .actual = if (actual.nullable) "NULL" else "NOT NULL",
            } };
        }
        if (actual.encoding != expected.encoding) {
            return .{ .drift = .{
                .aspect = .encoding,
                .column = expected.name,
                .expected = @tagName(expected.encoding),
                .actual = @tagName(actual.encoding),
            } };
        }
        if (actual.collation != expected.collation) {
            return .{ .drift = .{
                .aspect = .collation,
                .column = expected.name,
                .expected = @tagName(expected.collation),
                .actual = @tagName(actual.collation),
            } };
        }
        if ((actual.default == null) != (expected.default == null)) {
            return .{ .drift = .{
                .aspect = .default_value,
                .column = expected.name,
            } };
        }
        if (actual.default) |actual_cell| {
            const actual_encoded = try f.Types.Codec.encode(actual_cell, actual.field(), &actual_default_buf);
            const expected_encoded = try f.Types.Codec.encode(expected.default.?, expected.field(), &expected_default_buf);
            if (!std.mem.eql(u8, actual_encoded, expected_encoded)) {
                return .{ .drift = .{
                    .aspect = .default_value,
                    .column = expected.name,
                } };
            }
        }
    }
    if (existing.primary_key.len != desired.primary_key.len) {
        return .{ .drift = .{ .aspect = .primary_key } };
    }
    for (existing.primary_key, desired.primary_key) |actual_pk_id, expected_pk_id| {
        const actual_pk_name = existing.columns[try existing.index(actual_pk_id)].name;
        const expected_pk_name = for (desired.columns) |col| {
            if (col.id == expected_pk_id) break col.name;
        } else return error.InvalidPrimaryKey;
        if (!std.mem.eql(u8, actual_pk_name, expected_pk_name)) {
            return .{ .drift = .{
                .aspect = .primary_key,
                .column = expected_pk_name,
                .expected = expected_pk_name,
                .actual = actual_pk_name,
            } };
        }
    }
    return .satisfied;
}

pub fn reconcileSchemas(existing: f.TableSchema.Schema, desired: f.TableSchema.Schema) !Reconciliation {
    return reconcileCreate(existing, .{
        .name = "",
        .if_not_exists = true,
        .columns = desired.columns,
        .primary_key = desired.primary_key,
    });
}

pub fn ledgerAccount(connection: c.DirectTableProtocol.Connection, namespace: u64) [32]u8 {
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.migration.ledger-account.v1\x00");
    var bytes: [8]u8 = undefined;
    inline for (.{ connection.scope.realm, connection.scope.resource, connection.scope.catalog, connection.branch, namespace }) |value| {
        std.mem.writeInt(u64, &bytes, value, .little);
        hash.update(&bytes);
    }
    return hash.finalResult();
}

pub fn directoryKey(connection: c.DirectTableProtocol.Connection, account: [32]u8, namespace: u64) c.DirectClientToken.Key {
    _ = account;
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.migration.directory.v1\x00");
    var bytes: [8]u8 = undefined;
    inline for (.{ connection.scope.realm, connection.scope.resource, connection.scope.catalog, connection.branch, namespace }) |value| {
        std.mem.writeInt(u64, &bytes, value, .little);
        hash.update(&bytes);
    }
    const digest = hash.finalResult();
    return .{
        .definition = p.Growth.current_definition,
        .connection = connection,
        .account = ledgerAccount(connection, namespace),
        .token = digest[0..16].*,
    };
}

pub fn versionKey(connection: c.DirectTableProtocol.Connection, account: [32]u8, namespace: u64, version_id: []const u8) c.DirectClientToken.Key {
    _ = account;
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.migration.version.v1\x00");
    var bytes: [8]u8 = undefined;
    inline for (.{ connection.scope.realm, connection.scope.resource, connection.scope.catalog, connection.branch, namespace }) |value| {
        std.mem.writeInt(u64, &bytes, value, .little);
        hash.update(&bytes);
    }
    hash.update(version_id);
    const digest = hash.finalResult();
    return .{
        .definition = p.Growth.current_definition,
        .connection = connection,
        .account = ledgerAccount(connection, namespace),
        .token = digest[0..16].*,
    };
}

pub fn stepToken(scope: c.Model.Scope, branch: u64, namespace: u64, version_id: []const u8, source_sha256: [32]u8, step_index: u16, statement_digest: [32]u8) [16]u8 {
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.migration.step.v1\x00");
    var bytes: [8]u8 = undefined;
    inline for (.{ scope.realm, scope.resource, scope.catalog, branch, namespace }) |value| {
        std.mem.writeInt(u64, &bytes, value, .little);
        hash.update(&bytes);
    }
    var index_bytes: [2]u8 = undefined;
    std.mem.writeInt(u16, &index_bytes, step_index, .little);
    hash.update(&index_bytes);
    hash.update(version_id);
    hash.update(&.{0});
    hash.update(&source_sha256);
    hash.update(&statement_digest);
    const digest = hash.finalResult();
    return digest[0..16].*;
}

pub const InspectedDirectory = struct {
    directory: Directory,
    progress: ?c.DirectClientToken.Progress,
};

pub fn readDirectory(allocator: std.mem.Allocator, client: c.DirectTableClient, account: [32]u8, namespace: u64) !InspectedDirectory {
    const key = directoryKey(client.connection, account, namespace);
    const progress = try c.DirectClientToken.inspect(client, key) orelse return .{
        .directory = .{ .namespace = namespace, .versions = &.{} },
        .progress = null,
    };
    const reference = progress.record orelse progress.receipt.binding.intent.external.record;
    if (reference.format != directory_format) return error.InvalidMigrationLedger;
    const bytes = try c.DirectRecord.read(allocator, client, reference);
    defer allocator.free(bytes);
    const parsed = try p.Json.parseFromSlice(Directory, allocator, bytes);
    errdefer parsed.deinit();
    try parsed.value.validate();
    if (parsed.value.namespace != namespace) return error.DataIdentityConflict;
    const versions = try allocator.alloc([]const u8, parsed.value.versions.len);
    for (parsed.value.versions, versions) |item, *slot| slot.* = try allocator.dupe(u8, item);
    parsed.deinit();
    return .{
        .directory = .{ .namespace = namespace, .versions = versions },
        .progress = progress,
    };
}

pub fn ensureVersionListed(allocator: std.mem.Allocator, client: c.DirectTableClient, account: [32]u8, namespace: u64, version_id: []const u8) !void {
    const key = directoryKey(client.connection, account, namespace);
    var attempts: usize = 0;
    while (attempts < 4) : (attempts += 1) {
        const current = try readDirectory(allocator, client, account, namespace);
        for (current.directory.versions) |existing| {
            if (std.mem.eql(u8, existing, version_id)) return;
        }
        if (current.directory.versions.len >= max_versions) return error.MigrationDirectoryCapacity;
        const next_versions = try allocator.alloc([]const u8, current.directory.versions.len + 1);
        @memcpy(next_versions[0..current.directory.versions.len], current.directory.versions);
        next_versions[current.directory.versions.len] = version_id;
        std.mem.sort([]const u8, next_versions, {}, struct {
            fn lessThan(_: void, lhs: []const u8, rhs: []const u8) bool {
                return std.mem.order(u8, lhs, rhs) == .lt;
            }
        }.lessThan);
        const next_dir: Directory = .{ .namespace = namespace, .versions = next_versions };
        try next_dir.validate();
        const bytes = try p.Json.valueAlloc(allocator, next_dir);
        const record_ref = try c.DirectRecord.stage(client, key.account, directory_format, bytes);
        if (current.progress) |progress| {
            _ = c.DirectClientToken.update(client, .{
                .key = key,
                .expected = progress.revision,
                .pending = false,
                .cancel = false,
                .record = record_ref,
            }) catch |err| {
                if (err == error.Conflict) continue;
                return err;
            };
            return;
        } else {
            const fingerprint = try key.digest();
            const receipt = c.DirectClientToken.bind(client, .{
                .key = key,
                .fingerprint = fingerprint,
                .intent = .{ .external = .{
                    .connection = client.connection,
                    .namespace = namespace,
                    .operation = (std.mem.readInt(u64, fingerprint[0..8], .little) % p.max_counter) + 1,
                    .record = record_ref,
                } },
            }) catch |err| {
                if (err == error.ClientTokenConflict or err == error.Conflict) continue;
                return err;
            };
            _ = c.DirectClientToken.update(client, .{
                .key = key,
                .expected = receipt.position,
                .pending = false,
                .cancel = false,
                .record = record_ref,
            }) catch |err| {
                if (err == error.Conflict) continue;
                return err;
            };
            return;
        }
    }
    return error.MigrationClaimConflict;
}

pub const InspectedVersion = struct {
    entry: VersionEntry,
    progress: c.DirectClientToken.Progress,
};

pub fn readVersion(allocator: std.mem.Allocator, client: c.DirectTableClient, account: [32]u8, namespace: u64, version_id: []const u8) !?InspectedVersion {
    const key = versionKey(client.connection, account, namespace, version_id);
    const progress = try c.DirectClientToken.inspect(client, key) orelse return null;
    const reference = progress.record orelse progress.receipt.binding.intent.external.record;
    if (reference.format != version_format) return error.InvalidMigrationLedger;
    const bytes = try c.DirectRecord.read(allocator, client, reference);
    defer allocator.free(bytes);
    const parsed = try std.json.parseFromSliceLeaky(VersionEntry, allocator, bytes, .{ .allocate = .alloc_always });
    try parsed.validate();
    if (parsed.namespace != namespace or !std.mem.eql(u8, parsed.version_id, version_id)) return error.DataIdentityConflict;
    return .{ .entry = parsed, .progress = progress };
}

pub fn listVersions(allocator: std.mem.Allocator, client: c.DirectTableClient, account: [32]u8, namespace: u64) ![]VersionEntry {
    const dir = try readDirectory(allocator, client, account, namespace);
    var entries: std.ArrayList(VersionEntry) = .empty;
    for (dir.directory.versions) |version_id| {
        if (try readVersion(allocator, client, account, namespace, version_id)) |inspected| {
            try entries.append(allocator, inspected.entry);
        }
    }
    return entries.toOwnedSlice(allocator);
}

pub fn saveVersion(allocator: std.mem.Allocator, client: c.DirectTableClient, account: [32]u8, entry: VersionEntry, expected: ?p.DataLifecycle.Position) !c.DirectClientToken.Progress {
    try entry.validate();
    const key = versionKey(client.connection, account, entry.namespace, entry.version_id);
    const bytes = try p.Json.valueAlloc(allocator, entry);
    const record_ref = try c.DirectRecord.stage(client, key.account, version_format, bytes);
    if (expected) |revision| {
        return c.DirectClientToken.update(client, .{
            .key = key,
            .expected = revision,
            .pending = false,
            .cancel = false,
            .record = record_ref,
        }) catch |err| return if (err == error.Conflict) error.MigrationClaimConflict else err;
    }
    const fingerprint = try key.digest();
    const receipt = c.DirectClientToken.bind(client, .{
        .key = key,
        .fingerprint = fingerprint,
        .intent = .{ .external = .{
            .connection = client.connection,
            .namespace = entry.namespace,
            .operation = (std.mem.readInt(u64, fingerprint[0..8], .little) % p.max_counter) + 1,
            .record = record_ref,
        } },
    }) catch |err| return if (err == error.ClientTokenConflict or err == error.Conflict) error.MigrationClaimConflict else err;
    const updated = c.DirectClientToken.update(client, .{
        .key = key,
        .expected = receipt.position,
        .pending = false,
        .cancel = false,
        .record = record_ref,
    }) catch |err| return if (err == error.Conflict) error.MigrationClaimConflict else err;
    try ensureVersionListed(allocator, client, account, entry.namespace, entry.version_id);
    return updated;
}

test "reconcileCreate accepts matching schemas and reports exact column, type, nullability and key drift" {
    const t = std.testing;
    var base_ddl = try f.TableDdl.compile(
        t.allocator,
        "CREATE TABLE IF NOT EXISTS users (id INT64 PRIMARY KEY, email VARCHAR(120) NOT NULL COLLATE ASCII_CI, active BOOLEAN DEFAULT true)",
        null,
        null,
    );
    defer base_ddl.deinit();
    const existing = try base_ddl.statement.create.bind(42);

    // Exact match (even with different object ID) is satisfied.
    try t.expectEqual(.satisfied, try reconcileCreate(existing, base_ddl.statement.create));
    try t.expectEqualSlices(u8, &try logicalFingerprint(existing), &try logicalFingerprint(try base_ddl.statement.create.bind(99)));

    // Missing column in existing table -> missing_column.
    var extra_desired = try f.TableDdl.compile(
        t.allocator,
        "CREATE TABLE IF NOT EXISTS users (id INT64 PRIMARY KEY, email VARCHAR(120) NOT NULL COLLATE ASCII_CI, active BOOLEAN DEFAULT true, role TEXT)",
        null,
        null,
    );
    defer extra_desired.deinit();
    const missing_res = try reconcileCreate(existing, extra_desired.statement.create);
    try t.expectEqual(DriftAspect.missing_column, missing_res.drift.aspect);
    try t.expectEqualStrings("role", missing_res.drift.column.?);

    // Extra column in existing table -> extra_column.
    var fewer_desired = try f.TableDdl.compile(
        t.allocator,
        "CREATE TABLE IF NOT EXISTS users (id INT64 PRIMARY KEY, email VARCHAR(120) NOT NULL COLLATE ASCII_CI)",
        null,
        null,
    );
    defer fewer_desired.deinit();
    const extra_res = try reconcileCreate(existing, fewer_desired.statement.create);
    try t.expectEqual(DriftAspect.extra_column, extra_res.drift.aspect);
    try t.expectEqualStrings("active", extra_res.drift.column.?);

    // Type mismatch -> column_type.
    var type_desired = try f.TableDdl.compile(
        t.allocator,
        "CREATE TABLE IF NOT EXISTS users (id INT64 PRIMARY KEY, email INT64 NOT NULL, active BOOLEAN DEFAULT true)",
        null,
        null,
    );
    defer type_desired.deinit();
    const type_res = try reconcileCreate(existing, type_desired.statement.create);
    try t.expectEqual(DriftAspect.column_type, type_res.drift.aspect);
    try t.expectEqualStrings("email", type_res.drift.column.?);

    // Character limit mismatch -> max_characters.
    var char_desired = try f.TableDdl.compile(
        t.allocator,
        "CREATE TABLE IF NOT EXISTS users (id INT64 PRIMARY KEY, email VARCHAR(200) NOT NULL COLLATE ASCII_CI, active BOOLEAN DEFAULT true)",
        null,
        null,
    );
    defer char_desired.deinit();
    const char_res = try reconcileCreate(existing, char_desired.statement.create);
    try t.expectEqual(DriftAspect.max_characters, char_res.drift.aspect);
    try t.expectEqualStrings("email", char_res.drift.column.?);

    // Nullability mismatch -> nullability.
    var null_desired = try f.TableDdl.compile(
        t.allocator,
        "CREATE TABLE IF NOT EXISTS users (id INT64 PRIMARY KEY, email VARCHAR(120) COLLATE ASCII_CI, active BOOLEAN DEFAULT true)",
        null,
        null,
    );
    defer null_desired.deinit();
    const null_res = try reconcileCreate(existing, null_desired.statement.create);
    try t.expectEqual(DriftAspect.nullability, null_res.drift.aspect);
    try t.expectEqualStrings("email", null_res.drift.column.?);

    // Collation mismatch -> collation.
    var coll_desired = try f.TableDdl.compile(
        t.allocator,
        "CREATE TABLE IF NOT EXISTS users (id INT64 PRIMARY KEY, email VARCHAR(120) NOT NULL COLLATE UTF8_BINARY, active BOOLEAN DEFAULT true)",
        null,
        null,
    );
    defer coll_desired.deinit();
    const coll_res = try reconcileCreate(existing, coll_desired.statement.create);
    try t.expectEqual(DriftAspect.collation, coll_res.drift.aspect);
    try t.expectEqualStrings("email", coll_res.drift.column.?);

    // Default value mismatch -> default_value.
    var def_desired = try f.TableDdl.compile(
        t.allocator,
        "CREATE TABLE IF NOT EXISTS users (id INT64 PRIMARY KEY, email VARCHAR(120) NOT NULL COLLATE ASCII_CI, active BOOLEAN DEFAULT false)",
        null,
        null,
    );
    defer def_desired.deinit();
    const def_res = try reconcileCreate(existing, def_desired.statement.create);
    try t.expectEqual(DriftAspect.default_value, def_res.drift.aspect);
    try t.expectEqualStrings("active", def_res.drift.column.?);

    // Primary key mismatch -> primary_key.
    var pk_desired = try f.TableDdl.compile(
        t.allocator,
        "CREATE TABLE IF NOT EXISTS users (id INT64 NOT NULL, email VARCHAR(120) PRIMARY KEY COLLATE ASCII_CI, active BOOLEAN DEFAULT true)",
        null,
        null,
    );
    defer pk_desired.deinit();
    const pk_res = try reconcileCreate(existing, pk_desired.statement.create);
    try t.expectEqual(DriftAspect.primary_key, pk_res.drift.aspect);
}

test "migration step tokens and ledger keys bind scope, branch, namespace, version and statement digest" {
    const t = std.testing;
    const scope: c.Model.Scope = .{ .realm = 1, .resource = 5, .catalog = 1 };
    const digest_a: [32]u8 = @splat(0xaa);
    const digest_b: [32]u8 = @splat(0xbb);
    const tok1 = stepToken(scope, 1, 1, "0001", digest_a, 1, digest_b);
    const tok2 = stepToken(scope, 1, 1, "0001", digest_a, 1, digest_b);
    const tok_other_step = stepToken(scope, 1, 1, "0001", digest_a, 2, digest_b);
    const tok_other_branch = stepToken(scope, 2, 1, "0001", digest_a, 1, digest_b);
    try t.expectEqualSlices(u8, &tok1, &tok2);
    try t.expect(!std.mem.eql(u8, &tok1, &tok_other_step));
    try t.expect(!std.mem.eql(u8, &tok1, &tok_other_branch));
}
