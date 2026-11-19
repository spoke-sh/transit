//! Pure migration synthesis over explicit immutable Table history. The caller
//! owns a bounded arena and verified input buffers; no filesystem or live catalog.
const std = @import("std");
const f = @import("transit_sql_frontend");
const p = @import("transit_protocol");
const Compiler = @import("Compiler.zig");
const Context = @import("SourceDiagnostic.zig").Context;
const Column = @import("TypedOperands.zig").Column;
const Schema = f.TableSchema.Schema;
pub const format = "transit_table_basis_v1";
pub const definition = @tagName(p.Growth.current_definition);
pub const max_file_bytes = f.SqlScript.max_source_bytes;
pub const max_history_bytes = 16 * 1024 * 1024;
pub const max_basis_bytes = 16 * 1024 * 1024;
pub const max_versions = 256;
pub const max_steps = 64;
pub const Table = struct {
    schema: []const u8 = "public",
    name: []const u8,
    sql: []const u8,
    columns: []const Column,
    definition_digest: [32]u8,
    logical_digest: [32]u8,
};
pub const History = struct { version: []const u8, name: []const u8, path: []const u8, sha256: [32]u8 };
pub const File = struct { path: []const u8, sql: []const u8 };
pub const Basis = struct {
    format: []const u8,
    definition: []const u8,
    compiler: []const u8,
    database: []const u8,
    schema: []const u8,
    schemas: []const []const u8 = &.{"public"},
    tables: []const Table,
    history: []const History,
};
pub const Result = struct { basis: Basis, files: []const File, sql: []const u8, steps: usize };
const Entry = struct { schema_name: []const u8 = "public", name: []const u8, schema: Schema };

fn fkParentDigest(schema_name: []const u8, name: []const u8) [32]u8 {
    var h = std.crypto.hash.sha2.Sha256.init(.{});
    h.update("transit.migration.fk-parent.v1\x00");
    h.update(schema_name);
    h.update(&.{0});
    h.update(name);
    return h.finalResult();
}

const FkResolver = struct {
    entries: []const Entry,
    default_schema: []const u8,
    fn lookup(ctx: *anyopaque, a: std.mem.Allocator, name: []const u8) !f.SqlForeignKey.Resolver.Parent {
        return lookupQualified(ctx, a, null, name);
    }
    fn lookupQualified(ctx: *anyopaque, _: std.mem.Allocator, parent_schema: ?[]const u8, name: []const u8) !f.SqlForeignKey.Resolver.Parent {
        const self: *const FkResolver = @ptrCast(@alignCast(ctx));
        const s_name = parent_schema orelse self.default_schema;
        const idx = index(self.entries, s_name, name) orelse return error.UnknownBuildTable;
        var norm = self.entries[idx].schema;
        norm.object = 1;
        norm.revision = 1;
        return .{
            .schema = norm,
            .definition = .{
                .object = .{ .scope = .{ .realm = 1, .resource = 1, .catalog = 1 }, .branch = 1, .object = 1 },
                .revision = 1,
                .digest = fkParentDigest(s_name, name),
            },
        };
    }
};

pub fn hash(bytes: []const u8) [32]u8 {
    var result: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &result, .{});
    return result;
}
pub fn fileName(a: std.mem.Allocator, version: []const u8, name: []const u8) ![]const u8 {
    if (version.len == 0 or version.len > 64 or name.len == 0 or name.len > 128) return error.InvalidMigrationVersion;
    // MigrationClient parses both '-' and '_' as filename separators. Keep
    // synthesized versions unambiguous so applying a file preserves its identity.
    for (version) |byte| if (!std.ascii.isAlphanumeric(byte) and byte != '.') return error.InvalidMigrationVersion;
    for (name) |byte| if (!std.ascii.isAlphanumeric(byte) and byte != '_' and byte != '-') return error.InvalidMigrationVersion;
    return std.fmt.allocPrint(a, "{s}-{s}.sql", .{ version, name });
}
fn compilerValid(value: []const u8) bool {
    if (value.len != 64) return false;
    for (value) |byte| if (!std.ascii.isDigit(byte) and !(byte >= 'a' and byte <= 'f')) return false;
    return true;
}
fn nameValid(name: []const u8) bool {
    return name.len > 0 and name.len <= 63 and std.unicode.utf8ValidateSlice(name) and std.mem.indexOfScalar(u8, name, 0) == null;
}
fn hasSchema(schemas: []const []const u8, name: []const u8) bool {
    for (schemas) |s_name| if (std.mem.eql(u8, s_name, name)) return true;
    return false;
}
fn parseCreateSchema(a: std.mem.Allocator, sql: []const u8) !?[]const u8 {
    var parser = f.SqlTyped.init(a, sql, null) catch |err| return if (err == error.OutOfMemory) err else null;
    if (!parser.word("CREATE")) return null;
    var header = parser;
    header.requireWord("CREATE") catch return null;
    if (!header.word("SCHEMA")) return null;
    var auth = f.AuthorizationSql.compile(a, sql, null) catch |err| return if (err == error.OutOfMemory) err else error.UnsupportedMigrationDefinition;
    defer auth.deinit();
    if (auth.statement != .create_schema or auth.statement.create_schema.owner != .current_role) return error.UnsupportedMigrationDefinition;
    return try a.dupe(u8, auth.statement.create_schema.name);
}
fn statement(a: std.mem.Allocator, sql: []const u8, basis: ?Schema, entries: []const Entry, default_schema: []const u8) !f.TableDdl.Statement {
    var parser = try f.SqlTyped.init(a, sql, null);
    const parsed = try f.TableDdl.syntax(&parser, basis);
    try parser.finish();
    var fk_ctx: FkResolver = .{ .entries = entries, .default_schema = default_schema };
    return parsed.bindWithForeignKeys(a, basis, null, .{
        .context = &fk_ctx,
        .lookup = FkResolver.lookup,
        .lookup_qualified = FkResolver.lookupQualified,
    });
}
fn create(a: std.mem.Allocator, sql: []const u8, entries: []const Entry) !f.TableDdl.Create {
    const header = f.TableDdl.target(a, sql) catch |err| return if (err == error.OutOfMemory) err else error.UnsupportedMigrationDefinition;
    const default_schema = header.schema_name orelse "public";
    const parsed = statement(a, sql, null, entries, default_schema) catch |err| return if (err == error.OutOfMemory) err else error.UnsupportedMigrationDefinition;
    if (parsed != .create or parsed.create.if_not_exists or parsed.create.native_binding != null) return error.UnsupportedMigrationDefinition;
    return parsed.create;
}
fn index(entries: []const Entry, schema_name: []const u8, name: []const u8) ?usize {
    for (entries, 0..) |entry, i| if (std.mem.eql(u8, entry.schema_name, schema_name) and std.mem.eql(u8, entry.name, name)) return i;
    return null;
}
fn equivalent(left: Schema, right: Schema) !bool {
    return std.mem.eql(u8, &try f.TableDefinition.fingerprint(left), &try f.TableDefinition.fingerprint(right));
}
fn replay(a: std.mem.Allocator, schemas: *std.ArrayList([]const u8), entries: *std.ArrayList(Entry), sql: []const u8, context: *Context) !usize {
    var script = try f.SqlScript.init(sql);
    var count: usize = 0;
    while (try script.next()) |frame| {
        count += 1;
        if (count > max_steps) return error.MigrationStepLimit;
        const text = sql[frame.start..frame.end];
        if (parseCreateSchema(a, text) catch |err| return if (err == error.OutOfMemory) err else error.UnsupportedMigrationHistory) |schema_name| {
            context.* = .{ .name = schema_name };
            if (!nameValid(schema_name) or hasSchema(schemas.items, schema_name)) return error.UnsupportedMigrationHistory;
            try schemas.append(a, schema_name);
            continue;
        }
        const target = f.TableDdl.target(a, text) catch |err| return if (err == error.OutOfMemory) err else error.UnsupportedMigrationHistory;
        const t_schema = target.schema_name orelse "public";
        context.* = .{ .name = target.name };
        if (!hasSchema(schemas.items, t_schema)) return error.MigrationBasisMismatch;
        const at = index(entries.items, t_schema, target.name);
        const parsed = statement(a, text, if (at) |i| entries.items[i].schema else null, entries.items, t_schema) catch |err| return if (err == error.OutOfMemory) err else error.UnsupportedMigrationHistory;
        switch (parsed) {
            .create => |value| {
                if (at != null or value.if_not_exists or value.native_binding != null) return error.UnsupportedMigrationHistory;
                try entries.append(a, .{ .schema_name = t_schema, .name = value.name, .schema = try value.bind(1) });
            },
            .alter => |value| {
                const i = at orelse return error.MigrationBasisMismatch;
                if (value.action != .columns or value.action.columns != .add) return error.UnsupportedMigrationHistory;
                const columns = try a.create([f.TableSchema.max_columns]f.TableSchema.Column);
                const change = try f.TableEvolution.apply(entries.items[i].schema, value.action.columns, columns);
                if (!try change.canProject()) return error.MigrationTransformRequired;
                entries.items[i].schema = change.after;
            },
            .drop => return error.MigrationTransformRequired,
        }
    }
    if (count == 0) return error.UnsupportedMigrationHistory;
    return count;
}
fn table(a: std.mem.Allocator, value: Table, entries: []const Entry) !Schema {
    const parsed = try create(a, value.sql, entries);
    const parsed_schema = parsed.schema_name orelse "public";
    const schema = try parsed.bind(1);
    if (!std.mem.eql(u8, value.schema, parsed_schema) or !std.mem.eql(u8, value.name, parsed.name) or value.columns.len != schema.columns.len or
        !std.mem.eql(u8, &try f.TableDefinition.fingerprint(schema), &value.definition_digest) or
        !std.mem.eql(u8, &try f.TableDefinition.logicalFingerprint(schema), &value.logical_digest)) return error.MigrationBasisMismatch;
    for (value.columns, schema.columns) |annotation, col| {
        if (!std.mem.eql(u8, annotation.name, col.name)) return error.MigrationBasisMismatch;
        if (annotation.domain) |domain| if (domain.len == 0 or domain.len > 128 or !std.unicode.utf8ValidateSlice(domain)) return error.MigrationBasisMismatch;
    }
    return schema;
}
fn writeQuotedIdent(w: *std.Io.Writer, text: []const u8) !void {
    try w.writeByte('"');
    for (text) |byte| {
        try w.writeByte(byte);
        if (byte == '"') try w.writeByte(byte);
    }
    try w.writeByte('"');
}
/// New and unchanged Tables, or trailing columns whose existing-row projection
/// the ordinary TableEvolution owner admits. Everything else requires a reviewed
/// transform outside this profile. All historical bytes are preserved verbatim.
pub fn build(a: std.mem.Allocator, product: *const Compiler.Product, prior: ?Basis, files: []const File, compiler: []const u8, context: *Context) !Result {
    const target = product.migration orelse return error.MissingMigrationTarget;
    const new_path = try fileName(a, target.version, target.name);
    if (!nameValid(target.database) or !nameValid(target.schema) or !compilerValid(compiler)) return error.InvalidMigrationBasis;
    if ((target.basis == null) != (prior == null)) return error.MissingMigrationBasis;
    var replayed_schemas: std.ArrayList([]const u8) = .empty;
    try replayed_schemas.append(a, "public");
    var entries: std.ArrayList(Entry) = .empty;
    var history: std.ArrayList(History) = .empty;
    var output_files: std.ArrayList(File) = .empty;
    var historical_bytes: usize = 0;
    if (prior) |basis| {
        if (!std.mem.eql(u8, basis.format, format) or !std.mem.eql(u8, basis.definition, definition)) return error.IncompatibleMigrationBasis;
        if (!std.mem.eql(u8, basis.database, target.database) or !std.mem.eql(u8, basis.schema, target.schema)) return error.MigrationNamespaceMismatch;
        if (!compilerValid(basis.compiler) or basis.history.len > max_versions or files.len != basis.history.len) return error.InvalidMigrationBasis;
        for (basis.schemas, 0..) |s_name, idx| {
            if (!nameValid(s_name)) return error.InvalidMigrationBasis;
            for (basis.schemas[0..idx]) |prev| if (std.mem.eql(u8, prev, s_name)) return error.DuplicateMigrationBinding;
        }
        for (basis.history, files, 0..) |version, file, i| {
            const path = try fileName(a, version.version, version.name);
            if (!std.mem.eql(u8, version.path, path) or !std.mem.eql(u8, file.path, path)) return error.MigrationBasisMismatch;
            if ((i > 0 and !std.mem.lessThan(u8, basis.history[i - 1].version, version.version)) or !std.mem.lessThan(u8, version.version, target.version)) return error.MigrationVersionOrder;
            if (!std.mem.eql(u8, &hash(file.sql), &version.sha256)) return error.MigrationHistoryChanged;
            historical_bytes = std.math.add(usize, historical_bytes, file.sql.len) catch return error.MigrationHistoryLimit;
            if (historical_bytes > max_history_bytes) return error.MigrationHistoryLimit;
            _ = try replay(a, &replayed_schemas, &entries, file.sql, context);
            try history.append(a, version);
            try output_files.append(a, file);
        }
        if (replayed_schemas.items.len != basis.schemas.len) return error.MigrationBasisMismatch;
        for (basis.schemas) |s_name| if (!hasSchema(replayed_schemas.items, s_name)) return error.MigrationBasisMismatch;
        if (entries.items.len != basis.tables.len) return error.MigrationBasisMismatch;
        for (basis.tables, 0..) |value, i| {
            context.* = .{ .name = value.name };
            for (basis.tables[0..i]) |other| if (std.mem.eql(u8, other.schema, value.schema) and std.mem.eql(u8, other.name, value.name)) return error.DuplicateMigrationBinding;
            const at = index(entries.items, value.schema, value.name) orelse return error.MigrationBasisMismatch;
            if (!try equivalent(entries.items[at].schema, try table(a, value, entries.items))) return error.MigrationBasisMismatch;
        }
    } else if (files.len != 0) return error.InvalidMigrationBasis;
    var desired_schemas: std.ArrayList([]const u8) = .empty;
    try desired_schemas.append(a, "public");
    var desired_entries: std.ArrayList(Entry) = .empty;
    var tables: std.ArrayList(Table) = .empty;
    var sql: std.Io.Writer.Allocating = .init(a);
    var steps: usize = 0;
    for (product.steps) |step| {
        if (try parseCreateSchema(a, step.sql)) |schema_name| {
            context.* = .{ .name = schema_name };
            if (!nameValid(schema_name) or hasSchema(desired_schemas.items, schema_name)) return error.DuplicateMigrationBinding;
            try desired_schemas.append(a, schema_name);
            if (!hasSchema(replayed_schemas.items, schema_name)) {
                try sql.writer.print("{s};\n", .{step.sql});
                steps += 1;
                if (steps > max_steps or sql.written().len > f.SqlScript.max_source_bytes) return error.MigrationStepLimit;
            }
            continue;
        }
        const desired = try create(a, step.sql, desired_entries.items);
        const desired_schema_name = desired.schema_name orelse "public";
        context.* = .{ .name = desired.name };
        if (!hasSchema(desired_schemas.items, desired_schema_name)) return error.InvalidMigrationBasis;
        const schema = try desired.bind(1);
        for (tables.items) |other| if (std.mem.eql(u8, other.schema, desired_schema_name) and std.mem.eql(u8, other.name, desired.name)) return error.DuplicateMigrationBinding;
        const at = index(entries.items, desired_schema_name, desired.name);
        if (at) |i| {
            var before = entries.items[i].schema;
            if (before.columns.len > schema.columns.len) return error.MigrationTransformRequired;
            const old = for (prior.?.tables) |value| {
                if (std.mem.eql(u8, value.schema, desired_schema_name) and std.mem.eql(u8, value.name, desired.name)) break value;
            } else return error.MigrationBasisMismatch;
            if (step.checked.columns.len != schema.columns.len) return error.MigrationBasisMismatch;
            for (old.columns, step.checked.columns[0..old.columns.len]) |left, right| {
                if (!std.mem.eql(u8, left.name, right.name) or (left.domain == null) != (right.domain == null) or
                    (left.domain != null and !std.mem.eql(u8, left.domain.?, right.domain.?))) return error.MigrationTransformRequired;
            }
            for (schema.columns[before.columns.len..], desired.column_spans[before.columns.len..]) |col, span| {
                // Column spans come from the shared DDL parser, including nested
                // type/default syntax; never split SQL by commas or rewrite names.
                var name: std.Io.Writer.Allocating = .init(a);
                if (!std.mem.eql(u8, desired_schema_name, "public")) {
                    try writeQuotedIdent(&name.writer, desired_schema_name);
                    try name.writer.writeByte('.');
                }
                try writeQuotedIdent(&name.writer, desired.name);
                const alter = try std.fmt.allocPrint(a, "ALTER TABLE {s} ADD COLUMN {s}", .{ name.written(), step.sql[span.start..span.end] });
                const parsed = try statement(a, alter, before, desired_entries.items, desired_schema_name);
                if (parsed != .alter or parsed.alter.action != .columns or parsed.alter.action.columns != .add or !std.mem.eql(u8, parsed.alter.action.columns.add.name, col.name)) return error.MigrationBasisMismatch;
                const columns = try a.create([f.TableSchema.max_columns]f.TableSchema.Column);
                const change = try f.TableEvolution.apply(before, parsed.alter.action.columns, columns);
                if (!try change.canProject()) return error.MigrationTransformRequired;
                before = change.after;
                try sql.writer.print("{s};\n", .{alter});
                steps += 1;
                if (steps > max_steps or sql.written().len > f.SqlScript.max_source_bytes) return error.MigrationStepLimit;
            }
            if (!try equivalent(before, schema)) return error.MigrationTransformRequired;
        } else {
            try sql.writer.print("{s};\n", .{step.sql});
            steps += 1;
            if (steps > max_steps or sql.written().len > f.SqlScript.max_source_bytes) return error.MigrationStepLimit;
        }
        try desired_entries.append(a, .{ .schema_name = desired_schema_name, .name = desired.name, .schema = schema });
        try tables.append(a, .{ .schema = desired_schema_name, .name = desired.name, .sql = step.sql, .columns = step.checked.columns, .definition_digest = try f.TableDefinition.fingerprint(schema), .logical_digest = try f.TableDefinition.logicalFingerprint(schema) });
    }
    for (replayed_schemas.items) |s_name| {
        if (!hasSchema(desired_schemas.items, s_name)) {
            context.* = .{ .name = s_name };
            return error.MigrationTransformRequired;
        }
    }
    for (entries.items) |entry| {
        const exists = for (tables.items) |value| {
            if (std.mem.eql(u8, value.schema, entry.schema_name) and std.mem.eql(u8, value.name, entry.name)) break true;
        } else false;
        if (!exists) {
            context.* = .{ .name = entry.name };
            return error.MigrationTransformRequired;
        }
    }
    if (steps != 0) {
        if (history.items.len == max_versions) return error.MigrationHistoryLimit;
        const bytes = sql.written();
        if (historical_bytes + bytes.len > max_history_bytes) return error.MigrationHistoryLimit;
        // Reparse/replay emission separately and compare all final definitions.
        if (try replay(a, &replayed_schemas, &entries, bytes, context) != steps) return error.MigrationBasisMismatch;
        try history.append(a, .{ .version = target.version, .name = target.name, .path = new_path, .sha256 = hash(bytes) });
        try output_files.append(a, .{ .path = new_path, .sql = bytes });
    }
    if (replayed_schemas.items.len != desired_schemas.items.len) return error.MigrationBasisMismatch;
    for (desired_schemas.items) |s_name| if (!hasSchema(replayed_schemas.items, s_name)) return error.MigrationBasisMismatch;
    if (entries.items.len != tables.items.len) return error.MigrationBasisMismatch;
    for (tables.items) |value| {
        const i = index(entries.items, value.schema, value.name) orelse return error.MigrationBasisMismatch;
        if (!try equivalent(entries.items[i].schema, try table(a, value, entries.items))) return error.MigrationBasisMismatch;
    }
    return .{ .basis = .{ .format = format, .definition = definition, .compiler = compiler, .database = target.database, .schema = target.schema, .schemas = desired_schemas.items, .tables = tables.items, .history = history.items }, .files = output_files.items, .sql = sql.written(), .steps = steps };
}
