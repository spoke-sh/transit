//! Shared migration ledger and SQL plan semantics. No execution authority.
const std = @import("std");
const p = @import("root.zig");
pub const StepOwner = enum {
    schema_ddl,
    data_transform,
    authorization_grant,
    verification,
    computation,
    service,
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
    verify_query,
    create_dataflow,
    control_dataflow,
    execute_statement,
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

pub const OperationKind = enum { table, transaction, workload, dataflow, configuration, captured };
pub const StepIdentity = struct {
    version: []const u8,
    step: u16,
    pub fn validate(self: StepIdentity) !void {
        if (self.version.len == 0 or self.version.len > 64 or self.step == 0 or self.step > 64) return error.InvalidMigrationDependency;
    }
};
pub const TableReference = struct {
    name: []const u8,
    schema_sha256: [32]u8,
    existing: ?p.DataLifecycle.Definition,
    producer: ?StepIdentity,
    pub fn validate(self: TableReference) !void {
        if (self.name.len == 0 or (self.existing == null) == (self.producer == null)) return error.InvalidMigrationDependency;
        if (self.existing) |definition| try definition.validate();
        if (self.producer) |identity| try identity.validate();
    }
};
pub const Computation = struct {
    source: TableReference,
    output: TableReference,
    sql_sha256: [32]u8,
    existing: ?p.DataLifecycle.Definition,
    producer: ?StepIdentity,
    before: ?p.Dataflow.Control,
    after: p.Dataflow.Control,
    pub fn validate(self: Computation) !void {
        try self.source.validate();
        try self.output.validate();
        if ((self.existing == null) == (self.producer == null)) return error.InvalidMigrationDependency;
        if (self.existing) |definition| try definition.validate();
        if (self.producer) |identity| try identity.validate();
        try self.after.validate();
        if (self.before) |before| {
            try before.validate();
            if (self.after.epoch != try std.math.add(u64, before.epoch, 1)) return error.InvalidMigrationDependency;
        } else if (!std.meta.eql(self.after, p.Dataflow.Control.initial())) return error.InvalidMigrationDependency;
    }
};
