//! Authorized projections for psql's closed catalog-query profile. No storage,
//! synthetic permission store, SQL writes or durable admission are involved.
const std = @import("std");
const g = @import("root.zig");
const c = g.catalog;
const f = g.fuze;
const Sql = @import("PgCatalogSql.zig");
const Self = @This();
arena: std.heap.ArenaAllocator,
plan: Sql,
connection: c.DirectTableProtocol.Connection,
namespace: c.TableAuthority.Schema,
policy_revision: u64,
binding: ?c.DirectTableBinding = null,
rows: []const []const f.Types.Values.Cell = &.{},

pub fn prepare(host: *g.Session, sql: []const u8) !?Self {
    if (host.dialect == .mysql) return null;
    const borrowed = try Sql.parse(sql) orelse return null;
    if (host.source != null) return error.UnsupportedPostgresCatalogQuery;
    var arena: std.heap.ArenaAllocator = .init(host.allocator);
    errdefer arena.deinit();
    const a = arena.allocator();
    var plan = borrowed;
    if (plan.pattern) |value| plan.pattern = try a.dupe(u8, value);
    if (plan.schema) |value| plan.schema = try a.dupe(u8, value);
    const response = try host.table.call(.{ .namespace = host.namespace });
    defer response.deinit();
    const namespace = response.value.result.namespace orelse return error.CatalogIdentityConflict;
    var self: Self = .{ .arena = arena, .plan = plan, .connection = host.table.connection, .namespace = namespace, .policy_revision = response.value.policy_revision };
    if (plan.object) |object| {
        var after: ?u64 = null;
        var position: ?c.protocol.DataLifecycle.Position = null;
        var requests: u64 = 0;
        const name = find: while (true) {
            try request(host, &requests);
            const listed = try host.table.call(.{ .list = .{ .namespace = host.namespace, .after = after } });
            defer listed.deinit();
            const page = listed.value.result.list;
            try samePosition(&position, page.directory_position);
            for (page.entries) |slot| if (slot) |entry| {
                if (entry.interpretation.object.object == object) break :find entry;
            };
            after = page.next;
            if (after == null) return error.TableNotFound;
        };
        const found = try host.table.call(.{ .lookup = .{ .namespace = host.namespace, .name = name.name.slice() } });
        defer found.deinit();
        const metadata = found.value.result.lookup orelse return error.TableNotFound;
        if (!std.meta.eql(name.interpretation, metadata.interpretation.interpretation)) return error.TableDefinitionChanged;
        self.binding = try c.DirectTableBinding.init(host.table.connection, metadata);
        var schema = try f.TableSchema.decode(a, try metadata.schema.decode(a, f.TableSchema.max_bytes));
        defer schema.deinit();
        // Never describe a constrained Table as unconstrained when this profile
        // cannot yet render its integrity semantics.
        if (schema.schema.integrity.checks.len != 0 or schema.schema.integrity.foreign_keys.len != 0) return error.UnsupportedPostgresTableDescription;
        self.rows = try describe(a, plan.kind, self.binding.?.name.slice(), schema.schema);
    }
    self.arena = arena;
    return self;
}
pub fn validate(self: *const Self, host: *g.Session) !void {
    if (host.source != null or host.namespace != self.namespace.id or !std.meta.eql(self.connection, host.table.connection)) return error.CatalogIdentityConflict;
    const response = try host.table.call(.{ .namespace = self.namespace.id });
    defer response.deinit();
    if (response.value.result.namespace == null or !std.meta.eql(self.namespace, response.value.result.namespace.?)) return error.CatalogIdentityConflict;
    if (self.binding) |binding| _ = try binding.require(host.table, .inspect);
    // Also fence empty/repeated terminal metadata, which may have no row
    // subjects. A previous listing's count cannot survive a policy change.
    if (response.value.policy_revision != self.policy_revision) return error.PostgresCatalogChanged;
}
fn fields(comptime names: []const []const u8) []const f.Types.Field {
    const result = comptime blk: {
        var value: [names.len]f.Types.Field = undefined;
        for (names, &value) |name, *field| field.* = .{ .name = name, .type = .utf8, .nullable = true };
        break :blk value;
    };
    return &result;
}
pub fn output(self: Self) []const f.Types.Field {
    return switch (self.plan.kind) {
        .relations => fields(&.{ "Schema", "Name", "Type", "Owner" }),
        .schemas => fields(&.{ "Name", "Owner" }),
        .databases => fields(&.{ "Name", "Owner", "Encoding", "Locale Provider", "Collate", "Ctype", "Locale", "ICU Rules", "Access privileges" }),
        .schema_publications => fields(&.{"pubname"}),
        .resolve => fields(&.{ "oid", "nspname", "relname" }),
        .relation => fields(&.{ "relchecks", "relkind", "relhasindex", "relhasrules", "relhastriggers", "relrowsecurity", "relforcerowsecurity", "relhasoids", "relispartition", "reloptions", "reltablespace", "reloftype", "relpersistence", "relreplident", "amname" }),
        .columns => fields(&.{ "attname", "format_type", "pg_get_expr", "attnotnull", "attcollation", "attidentity", "attgenerated" }),
        .indexes => fields(&.{ "relname", "indisprimary", "indisunique", "indisclustered", "indisvalid", "pg_get_indexdef", "pg_get_constraintdef", "contype", "condeferrable", "condeferred", "indisreplident", "reltablespace", "conperiod" }),
        .foreign_keys => fields(&.{ "sametable", "conname", "condef", "ontable" }),
        .references => fields(&.{ "conname", "ontable", "condef" }),
        .policies => fields(&.{ "polname", "polpermissive", "roles", "pg_get_expr", "withcheck", "cmd" }),
        .statistics => fields(&.{ "oid", "stxrelid", "nsp", "stxname", "columns", "ndist_enabled", "deps_enabled", "mcv_enabled", "stxstattarget" }),
        .publications => fields(&.{ "pubname", "filter", "columns" }),
        .parents => fields(&.{"oid"}),
        .children => fields(&.{ "oid", "relkind", "inhdetachpending", "pg_get_expr" }),
    };
}
fn text(value: []const u8) f.Types.Values.Cell {
    return .{ .value = .{ .atom = .{ .bytes = value } } };
}
fn row(a: std.mem.Allocator, values: []const ?[]const u8) ![]const f.Types.Values.Cell {
    const cells = try a.alloc(f.Types.Values.Cell, values.len);
    for (cells, values) |*cell, value| cell.* = if (value) |bytes| text(bytes) else .null;
    return cells;
}
fn quote(writer: *std.Io.Writer, name: []const u8) !void {
    try writer.writeByte('"');
    for (name) |byte| {
        try writer.writeByte(byte);
        if (byte == '"') try writer.writeByte(byte);
    }
    try writer.writeByte('"');
}
fn describe(a: std.mem.Allocator, kind: Sql.Kind, name: []const u8, schema: f.TableSchema.Schema) ![]const []const f.Types.Values.Cell {
    const count: usize = switch (kind) {
        .relation => 1,
        .columns => schema.columns.len,
        .indexes => @intFromBool(schema.primary_key.len != 0),
        else => 0,
    };
    const rows = try a.alloc([]const f.Types.Values.Cell, count);
    switch (kind) {
        .relation => rows[0] = try row(a, &.{ "0", "r", if (schema.primary_key.len != 0) "t" else "f", "f", "f", "f", "f", "f", "f", "", "0", "", "p", "n", "transit" }),
        .columns => for (schema.columns, rows) |column, *out| {
            var type_text: std.Io.Writer.Allocating = .init(a);
            try f.LogicalDisplay.typeName(&type_text.writer, column.type);
            if (column.max_characters) |maximum| try type_text.writer.print("({d})", .{maximum});
            const default = if (column.default) |value| blk: {
                var rendered: std.Io.Writer.Allocating = .init(a);
                if (column.type == .utf8 and value == .value and value.value == .atom) {
                    try rendered.writer.writeByte('\'');
                    for (value.value.atom.bytes) |byte| {
                        try rendered.writer.writeByte(byte);
                        if (byte == '\'') try rendered.writer.writeByte(byte);
                    }
                    try rendered.writer.writeByte('\'');
                } else try f.LogicalDisplay.cell(&rendered.writer, value, column.type);
                break :blk rendered.written();
            } else null;
            out.* = try row(a, &.{ try a.dupe(u8, column.name), type_text.written(), default, if (column.nullable) "f" else "t", if (column.collation == .none) null else @tagName(column.collation), "", "" });
        },
        .indexes => if (count != 0) {
            var definition: std.Io.Writer.Allocating = .init(a);
            try definition.writer.writeAll("CREATE UNIQUE INDEX ");
            const label = try std.fmt.allocPrint(a, "{s}_pkey", .{name});
            try quote(&definition.writer, label);
            try definition.writer.writeAll(" ON ");
            try quote(&definition.writer, name);
            try definition.writer.writeAll(" USING transit (");
            for (schema.primary_key, 0..) |id, i| {
                if (i != 0) try definition.writer.writeAll(", ");
                try quote(&definition.writer, schema.columns[try schema.index(id)].name);
            }
            try definition.writer.writeByte(')');
            rows[0] = try row(a, &.{ label, "t", "t", "f", "t", definition.written(), null, "p", "f", "f", "f", "0", "f" });
        },
        else => {},
    }
    return rows;
}
fn request(host: *g.Session, count: *u64) !void {
    if (count.* == 10000) return error.PostgresCatalogBudget;
    count.* += 1;
    try host.deadline.check(host.io);
}
fn samePosition(previous: *?c.protocol.DataLifecycle.Position, value: c.protocol.DataLifecycle.Position) !void {
    if (previous.*) |prior| if (!std.meta.eql(prior, value)) return error.PostgresCatalogChanged;
    previous.* = value;
}

pub const Read = struct {
    host: *g.Session,
    prepared: *Self,
    scratch: std.heap.ArenaAllocator,
    last: ?c.TableAuthority.Name = null,
    index: usize = 0,
    requests: u64 = 0,
    position: ?c.protocol.DataLifecycle.Position = null,
    policy: ?u64 = null,
    done: bool = false,
    subject: ?g.BatchDisclosure.Subject = null,
    pub fn init(host: *g.Session, prepared: *Self) Read {
        return .{ .host = host, .prepared = prepared, .scratch = .init(host.allocator) };
    }
    pub fn deinit(self: *Read) void {
        self.scratch.deinit();
    }
    pub fn next(self: *Read) !?[]const f.Types.Values.Cell {
        self.subject = null;
        try self.prepared.validate(self.host);
        if (self.done) return null;
        _ = self.scratch.reset(.retain_capacity);
        if (self.prepared.plan.object != null) {
            if (self.index == self.prepared.rows.len) {
                self.done = true;
                return null;
            }
            defer self.index += 1;
            self.subject = .{ .table = self.prepared.binding.?.interpretation.interpretation };
            return self.prepared.rows[self.index];
        }
        const result = switch (self.prepared.plan.kind) {
            .relations, .resolve => try self.nextTable(),
            .schemas => try self.nextSchema(),
            .databases => try self.nextDatabase(),
            .schema_publications => null,
            else => unreachable,
        };
        if (result == null) self.done = true;
        return result;
    }
    fn candidate(self: *Read, name: []const u8, best: ?c.TableAuthority.Name) !bool {
        if (self.last) |last| if (std.mem.order(u8, name, last.slice()) != .gt) return false;
        if (best) |prior| if (std.mem.order(u8, name, prior.slice()) != .lt) return false;
        return Sql.Pattern.matchesEscaped(self.prepared.plan.pattern, self.prepared.plan.pattern_escaped, name);
    }
    fn observe(self: *Read, value: c.DirectTableProtocol.Response, position: c.protocol.DataLifecycle.Position) !void {
        try samePosition(&self.position, position);
        if (self.policy) |prior| if (prior != value.policy_revision) return error.PostgresCatalogChanged;
        self.policy = value.policy_revision;
    }
    // Catalog pages use stable IDs. Ordered output selects one successor with
    // repeated bounded scans, retaining one page and candidate, never the whole
    // catalog. Request/deadline budgets bound this deliberate O(n^2) tradeoff.
    fn nextTable(self: *Read) !?[]const f.Types.Values.Cell {
        const namespace_name = self.prepared.namespace.name.slice();
        if (self.prepared.plan.hide_system and (std.mem.eql(u8, namespace_name, "pg_catalog") or std.mem.eql(u8, namespace_name, "information_schema") or std.mem.startsWith(u8, namespace_name, "pg_toast"))) return null;
        if (!try Sql.Pattern.matchesEscaped(self.prepared.plan.schema, self.prepared.plan.schema_escaped, self.prepared.namespace.name.slice())) return null;
        var after: ?u64 = null;
        var best: ?c.DirectCatalog.Listed = null;
        while (true) {
            try request(self.host, &self.requests);
            const response = try self.host.table.call(.{ .list = .{ .namespace = self.host.namespace, .after = after } });
            defer response.deinit();
            const page = response.value.result.list;
            try self.observe(response.value, page.directory_position);
            for (page.entries) |slot| if (slot) |entry| {
                if (try self.candidate(entry.name.slice(), if (best) |prior| prior.name else null)) best = entry;
            };
            after = page.next;
            if (after == null) break;
        }
        const chosen = best orelse return null;
        self.last = chosen.name;
        self.subject = .{ .table = chosen.interpretation };
        const a = self.scratch.allocator();
        const name = try a.dupe(u8, chosen.name.slice());
        return if (self.prepared.plan.kind == .resolve)
            try row(a, &.{ try std.fmt.allocPrint(a, "{d}", .{chosen.interpretation.object.object}), self.prepared.namespace.name.slice(), name })
        else
            try row(a, &.{ self.prepared.namespace.name.slice(), name, "table", null });
    }
    fn nextSchema(self: *Read) !?[]const f.Types.Values.Cell {
        var after: ?u64 = null;
        var best: ?c.TableAuthority.Schema = null;
        while (true) {
            try request(self.host, &self.requests);
            const response = try self.host.table.call(.{ .namespaces = .{ .after = after } });
            defer response.deinit();
            const page = response.value.result.namespaces;
            try self.observe(response.value, page.directory_position);
            for (page.entries) |slot| if (slot) |entry| {
                if (self.prepared.plan.hide_system and (std.mem.startsWith(u8, entry.name.slice(), "pg_") or std.mem.eql(u8, entry.name.slice(), "information_schema"))) continue;
                if (try self.candidate(entry.name.slice(), if (best) |prior| prior.name else null)) best = entry;
            };
            after = page.next;
            if (after == null) break;
        }
        const chosen = best orelse return null;
        self.last = chosen.name;
        self.subject = .{ .namespace = chosen };
        const a = self.scratch.allocator();
        return try row(a, &.{ try a.dupe(u8, chosen.name.slice()), null });
    }
    fn nextDatabase(self: *Read) !?[]const f.Types.Values.Cell {
        var best: ?usize = null;
        for (self.host.account.databases, 0..) |database, i| {
            if (!try self.candidate(database.name, if (best) |j| try c.TableAuthority.Name.init(self.host.account.databases[j].name) else null)) continue;
            var table = self.host.table;
            table.connection.scope.resource = database.binding.resource;
            table.connection.scope.catalog = database.binding.catalog;
            table.connection.audience = database.binding.owner;
            table.connection.role = database.binding.role;
            try request(self.host, &self.requests);
            _ = table.require(.{ .namespace = null, .target = null, .access = .database }) catch |err| {
                if (err == error.AccessDenied or err == error.CatalogDenied) continue;
                return err;
            };
            best = i;
        }
        const chosen = self.host.account.databases[best orelse return null];
        self.last = try c.TableAuthority.Name.init(chosen.name);
        self.subject = .{ .database = chosen.binding };
        return try row(self.scratch.allocator(), &.{ chosen.name, null, "UTF8", null, null, null, null, null, null });
    }
};

test "psql metadata never invents PostgreSQL storage or owner identities" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const schema: f.TableSchema.Schema = .{ .object = 17, .revision = 1, .next_column = 3, .columns = &.{
        .{ .id = 1, .name = "id", .type = .int64, .nullable = false },
        .{ .id = 2, .name = "label", .type = .utf8, .default = .null },
    }, .primary_key = &.{1} };
    const columns = try describe(arena.allocator(), .columns, "items", schema);
    try std.testing.expectEqualStrings("id", columns[0][0].value.atom.bytes);
    try std.testing.expectEqualStrings("t", columns[0][3].value.atom.bytes);
    try std.testing.expectEqualStrings("NULL", columns[1][2].value.atom.bytes);
    const indexes = try describe(arena.allocator(), .indexes, "items", schema);
    try std.testing.expect(std.mem.indexOf(u8, indexes[0][5].value.atom.bytes, "USING transit") != null);
}
