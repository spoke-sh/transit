//! Stored finite managed-computation metadata shared by publication and read owners.
//! These codecs perform no query execution and grant no authority.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const d = p.DataLifecycle;
const f = c.fuze;
const flow = p.Dataflow;
const w = c.DirectTableProtocol;
pub const declaration_format: u32 = 0x44464431; // DFD1
pub const work_format: u32 = 0x44465731; // DFW1
pub const page_format: u32 = c.DirectRecord.guarded_bit | 0x44465031; // guarded DFP1
pub const revision_format: u32 = c.DirectRecord.guarded_bit | 0x44465231; // guarded DFR1
pub const head_key = "\x00dataflow/head";
pub const max_definition_bytes = 64 * 1024;
pub const spec: c.storage.KVDeclaration.Spec = .{ .value_type = .binary, .nullable = false };

pub const Consistency = enum { per_resource_snapshot_vector, independent_table_snapshots, transaction, atomic };
pub const Options = struct {
    dialect: f.Sql.Dialect = .transit,
    consistency: Consistency,
    budgets: f.Relational.Budgets,
    /// Physical access limits supplement the logical operation budget.
    requests: u64,
    spill_work: u64,
    pub fn requireClient(self: Options, client: c.DirectTableClient) !void {
        switch (self.consistency) {
            .independent_table_snapshots => if (client.transaction != null) return error.UnsupportedRelationalConsistency,
            .transaction => if (client.transaction == null) return error.UnsupportedRelationalConsistency,
            .per_resource_snapshot_vector, .atomic => return error.UnsupportedRelationalConsistency,
        }
    }
};
pub const Declaration = struct {
    definition: p.Growth.Definition,
    connection: w.Connection,
    namespace: u64,
    name: c.TableAuthority.Name,
    object: d.Object,
    operation: d.Operation,
    source: c.DirectTableBinding,
    output: c.DirectTableBinding,
    sql: []const u8,
    options: Options,

    pub fn validate(self: Declaration) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.connection.validate();
        try self.connection.object(self.object);
        try self.operation.validate();
        try self.name.validate();
        try self.source.validate();
        try self.output.validate();
        if (self.options.budgets.output_rows > std.math.maxInt(u64) - 2) return error.InvalidQueryBudget;
        if (self.namespace == 0 or self.sql.len == 0 or self.sql.len > f.Sql.max_statement_bytes or
            !std.meta.eql(self.operation.scope, self.connection.scope) or self.operation.principal != self.connection.principal or
            !std.meta.eql(self.source.connection, self.connection) or !std.meta.eql(self.output.connection, self.connection) or
            self.namespace != self.source.namespace or self.namespace != self.output.namespace or
            std.meta.eql(self.source.interpretation.interpretation.object, self.output.interpretation.interpretation.object) or
            std.meta.eql(self.object, self.source.interpretation.interpretation.object) or std.meta.eql(self.object, self.output.interpretation.interpretation.object) or
            self.options.consistency != .independent_table_snapshots) return error.UnsupportedManagedTable;
    }
    pub fn digest(self: Declaration, allocator: std.mem.Allocator) ![32]u8 {
        try self.validate();
        const bytes = try p.Json.valueAllocBounded(allocator, self, max_definition_bytes);
        defer allocator.free(bytes);
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        hash.update("transit.managed.table.definition.v1\x00");
        hash.update(bytes);
        return hash.finalResult();
    }
    pub fn interpretation(self: Declaration, allocator: std.mem.Allocator) !d.Definition {
        return .{ .object = self.object, .revision = 1, .digest = try self.digest(allocator) };
    }
};

/// The named computation's current head is a normal direct KV participant.
/// Complete revisions remain separate durable keys in that same paged object.
pub const Head = struct {
    definition: p.Growth.Definition,
    declaration: [32]u8,
    control: flow.Control,
    attempt: u64,
    revision: u64,
    completed_refresh: u64,
    source: ?d.Position,
    rows: u64,
    pending: ?c.DirectClientToken.Key,
    pending_record: ?c.DirectRecord.Reference,
    completed: ?c.DirectClientToken.Key,
    blocked: flow.Blocked,
    retirement_complete: bool,

    pub fn initial(digest: [32]u8) Head {
        return .{ .definition = p.Growth.current_definition, .declaration = digest, .control = .initial(), .attempt = 0, .revision = 0, .completed_refresh = 0, .source = null, .rows = 0, .pending = null, .pending_record = null, .completed = null, .blocked = .none, .retirement_complete = false };
    }
    pub fn validate(self: Head) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.control.validate();
        if (self.retirement_complete and self.control.state != .retired) return error.InvalidManagedTableHead;
        if ((self.revision == 0) != (self.completed == null) or (self.revision == 0) != (self.source == null) or
            self.completed_refresh > self.control.refresh or (self.pending != null and self.attempt == 0) or ((self.pending == null) != (self.pending_record == null))) return error.InvalidManagedTableHead;
        if (self.source) |source| try source.validate();
        if (self.pending) |key| try key.validate();
        if (self.completed) |key| try key.validate();
    }
};
pub const Observation = struct {
    head: Head,
    storage: d.Definition,
    position: d.Position,
    completion: ?p.Transaction.Decision,
};
pub const Revision = struct {
    metadata: flow.Revision,
    declaration: c.DirectRecord.Reference,
    transaction: c.DirectClientToken.Key,
    schema: w.Binary,
    pages: ?c.DirectRecord.Reference,

    pub fn validate(self: Revision) !void {
        try self.metadata.validate();
        try self.declaration.validate();
        try self.transaction.validate();
        if (self.declaration.format != declaration_format or
            !std.meta.eql(self.declaration.scope.connection, self.transaction.connection) or
            (self.pages == null) != (self.metadata.rows == 0)) return error.InvalidManagedTableRecord;
        if (self.pages) |page| {
            try page.validate();
            if (page.format != c.DirectTransactionRecord.format or !std.meta.eql(page.scope.connection, self.transaction.connection) or
                !std.mem.eql(u8, &page.scope.account, &self.transaction.account)) return error.InvalidManagedTableRecord;
        }
    }
};

pub fn revisionKey(revision: u64) ![24]u8 {
    if (revision == 0) return error.InvalidDataflowRevision;
    var key: [24]u8 = undefined;
    @memcpy(key[0..16], "\x00dataflow/rev/__");
    std.mem.writeInt(u64, key[16..24], revision, .big);
    return key;
}

pub fn account() [32]u8 {
    var result: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash("transit.managed.table.declarations.v1", &result, .{});
    return result;
}
/// Pending work remains discoverable while its transaction blocks head reads.
pub fn workAccount() [32]u8 {
    var result: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash("transit.managed.table.work.v1", &result, .{});
    return result;
}
pub fn nameKey(connection: w.Connection, namespace: u64, name: c.TableAuthority.Name) c.DirectClientToken.Key {
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    var bytes: [8]u8 = undefined;
    std.mem.writeInt(u64, &bytes, namespace, .big);
    hash.update(&bytes);
    hash.update(name.slice());
    const digest = hash.finalResult();
    return .{ .definition = p.Growth.current_definition, .connection = connection, .account = account(), .token = digest[0..16].* };
}
