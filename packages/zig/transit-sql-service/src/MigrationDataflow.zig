//! Read-only migration planning and original-definition guards for finite dataflows.
const std = @import("std");
const g = @import("root.zig");
const c = g.catalog;
const p = c.protocol;
const f = g.fuze;
const M = g.session_protocol.Migration;
const Evidence = p.Migration.Computation;

pub const Planner = struct {
    allocator: std.mem.Allocator,
    table: *c.DirectTableClient,
    namespace: u64,
    schemas: *g.MigrationRunner.WorkingSchemas,
    values: std.StringHashMapUnmanaged(Evidence) = .empty,

    fn reference(self: *Planner, name: []const u8) !p.Migration.TableReference {
        const schema = try self.schemas.get(name) orelse return error.TableNotFound;
        const producer = self.schemas.producers.get(name);
        const existing = if (producer == null) blk: {
            const response = try self.table.call(.{ .lookup = .{ .namespace = self.namespace, .name = name } });
            defer response.deinit();
            break :blk (response.value.result.lookup orelse return error.TableNotFound).interpretation.interpretation;
        } else null;
        return .{ .name = try self.allocator.dupe(u8, name), .schema_sha256 = try c.DirectMigration.logicalFingerprint(schema), .existing = existing, .producer = producer };
    }

    pub fn plan(self: *Planner, step: g.MigrationRunner.ParsedStep, report: *M.StepReport, identity: p.Migration.StepIdentity, options: g.direct.DirectRelationalQuery.Options) !void {
        var parsed = (try g.database.ManagedSql.parse(self.allocator, step.sql, options.dialect)) orelse return error.UnsupportedManagedTable;
        defer parsed.deinit();
        const value: Evidence = if (report.computation) |original| original else switch (parsed.statement) {
            .create => |create| blk: {
                if (self.values.contains(create.name.slice())) return error.ManagedTableNameConflict;
                const manager: g.direct.ManagedTable = .{ .client = self.table.* };
                if (try manager.find(self.namespace, create.name)) |found| {
                    found.deinit();
                    return error.ManagedTableNameConflict;
                }
                var syntax = try f.RelationalSql.parseDialect(self.allocator, create.sql, null, options.dialect);
                defer syntax.deinit();
                if (syntax.targets.len != 1 or std.mem.eql(u8, syntax.targets[0].name, create.output.slice())) return error.UnsupportedManagedTable;
                const source = try self.reference(syntax.targets[0].name);
                const output = try self.reference(create.output.slice());
                const connection = self.table.connection;
                const source_schema = (try self.schemas.get(source.name)).?;
                const plan_value = try syntax.bind(&.{.{ .alias = syntax.targets[0].alias, .realm = connection.scope.realm, .resource = connection.scope.resource, .catalog = connection.scope.catalog, .owner = connection.audience, .schema = source_schema }}, .maintained, options.budgets, null);
                try g.direct.ManagedTable.validateOutput(plan_value, (try self.schemas.get(output.name)).?);
                var digest: [32]u8 = undefined;
                std.crypto.hash.sha2.Sha256.hash(create.sql, &digest, .{});
                break :blk .{ .source = source, .output = output, .sql_sha256 = digest, .existing = null, .producer = identity, .before = null, .after = .initial() };
            },
            .control => |control| blk: {
                var current = self.values.get(control.name.slice()) orelse load: {
                    const manager: g.direct.ManagedTable = .{ .client = self.table.* };
                    const declared = try manager.find(self.namespace, control.name) orelse return error.CatalogNameNotFound;
                    defer declared.deinit();
                    const observed = try manager.inspect(declared.value);
                    var digest: [32]u8 = undefined;
                    std.crypto.hash.sha2.Sha256.hash(declared.value.sql, &digest, .{});
                    break :load Evidence{ .source = try self.reference(declared.value.source.name.slice()), .output = try self.reference(declared.value.output.name.slice()), .sql_sha256 = digest, .existing = try declared.value.interpretation(self.allocator), .producer = null, .before = null, .after = observed.head.control };
                };
                current.before = current.after;
                current.after = try current.after.apply(control.command);
                break :blk current;
            },
        };
        report.computation = value;
        try self.values.put(self.allocator, try self.allocator.dupe(u8, step.object_name), value);
    }
};

fn produced(allocator: std.mem.Allocator, table: c.DirectTableClient, account: [32]u8, namespace: u64, identity: p.Migration.StepIdentity) !p.DataLifecycle.Definition {
    const saved = try c.DirectMigration.readVersion(allocator, table, account, namespace, identity.version) orelse return error.MigrationDependencyUnapplied;
    if (identity.step == 0 or identity.step > saved.entry.steps.len) return error.InvalidMigrationDependency;
    const step = saved.entry.steps[identity.step - 1];
    if (step.state != .applied and step.state != .verified and step.state != .already_satisfied) return error.MigrationDependencyUnapplied;
    return step.object_definition orelse return error.MigrationDependencyUnapplied;
}

fn resolve(allocator: std.mem.Allocator, table: c.DirectTableClient, account: [32]u8, namespace: u64, reference: p.Migration.TableReference) !p.DataLifecycle.Definition {
    const expected = if (reference.producer) |identity| try produced(allocator, table, account, namespace, identity) else reference.existing orelse return error.InvalidMigrationDependency;
    const response = try table.call(.{ .lookup = .{ .namespace = namespace, .name = reference.name } });
    defer response.deinit();
    const actual = response.value.result.lookup orelse return error.TableNotFound;
    if (!std.meta.eql(expected, actual.interpretation.interpretation)) return error.DataflowSourceChanged;
    const bytes = try actual.schema.decode(allocator, f.TableSchema.max_bytes);
    defer allocator.free(bytes);
    var schema = try f.TableSchema.decode(allocator, bytes);
    defer schema.deinit();
    if (!std.mem.eql(u8, &reference.schema_sha256, &try c.DirectMigration.logicalFingerprint(schema.schema))) return error.DataflowSourceChanged;
    return expected;
}

pub fn guard(allocator: std.mem.Allocator, table: c.DirectTableClient, account: [32]u8, namespace: u64, value: Evidence) !g.ManagedOperations.Guard {
    return .{
        .source = try resolve(allocator, table, account, namespace, value.source),
        .output = try resolve(allocator, table, account, namespace, value.output),
        .definition = if (value.before == null) null else if (value.producer) |identity| try produced(allocator, table, account, namespace, identity) else value.existing,
        .control = value.before,
        .sql_sha256 = value.sql_sha256,
    };
}

pub fn verify(table: c.DirectTableClient, namespace: u64, step: M.StepReport) !void {
    const value = step.computation orelse return error.InvalidMigrationDependency;
    const response = try table.call(.{ .managed_inspection = .{ .namespace = namespace, .name = try .init(step.object_name), .expected = step.object_definition orelse return error.MigrationDependencyUnapplied, .revision = null } });
    defer response.deinit();
    const observed = response.value.result.managed_inspection;
    const observation = observed.observation orelse return error.MissingManagedTableObservation;
    if (!std.meta.eql(value.after, observation.head.control)) return error.DataflowControlChanged;
}
