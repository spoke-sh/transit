//! Bounded read-only managed computation evidence. Original publisher identity
//! remains attribution; the signed request's reader supplies disclosure authority.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const d = p.DataLifecycle;
const M = c.ManagedTableRecords;
pub const max_bytes = 256 * 1024;
pub const Request = struct {
    namespace: u64,
    name: c.TableAuthority.Name,
    expected: ?d.Definition,
    revision: ?u64,
    pub fn validate(self: Request, connection: c.DirectTableProtocol.Connection) !void {
        try c.Model.nativeId(self.namespace);
        try self.name.validate();
        if (self.revision == 0) return error.InvalidDataflowRevision;
        if (self.expected) |expected| {
            try expected.validate();
            try connection.object(expected.object);
        }
    }
};
pub const Completed = struct {
    manifest: c.DirectRecord.Reference,
    revision: M.Revision,
    decision: p.Transaction.Decision,
};
pub const Result = struct {
    declaration: M.Declaration,
    interpretation: d.Definition,
    observation: ?M.Observation,
    completed: ?Completed,
    pub fn validate(self: Result, allocator: std.mem.Allocator, request: Request) !void {
        try self.declaration.validate();
        if (self.declaration.namespace != request.namespace or !std.meta.eql(self.declaration.name, request.name) or
            !std.meta.eql(self.interpretation, try self.declaration.interpretation(allocator))) return error.DataflowIdentityConflict;
        if (request.expected) |expected| if (!std.meta.eql(expected, self.interpretation)) return error.DataflowIdentityConflict;
        if (request.revision != null) {
            if (self.observation != null or self.completed == null or self.completed.?.revision.metadata.revision != request.revision.?) return error.InvalidManagedTableRecord;
        } else {
            const observed = self.observation orelse return error.InvalidManagedTableRecord;
            try observed.head.validate();
            if (!std.mem.eql(u8, &observed.head.declaration, &self.interpretation.digest) or
                (observed.head.revision == 0) != (self.completed == null)) return error.InvalidManagedTableRecord;
            if (self.completed) |completed| {
                if (observed.head.revision != completed.revision.metadata.revision or
                    observed.head.rows != completed.revision.metadata.rows or
                    !std.meta.eql(observed.head.source, completed.revision.metadata.source_position) or
                    !std.meta.eql(observed.head.completed, completed.revision.transaction) or
                    !std.meta.eql(observed.completion, completed.decision)) return error.InvalidManagedTableRecord;
            }
        }
        if (self.completed) |completed| {
            var schema = try verifyRevision(allocator, self.declaration, completed);
            schema.deinit();
        }
    }
};

/// Shared metadata verification for inspection and the bounded retained row reader.
/// This verifies supplied evidence; the native owner separately authenticates the
/// manifest's publication and actual decision journal under current grants.
pub fn verifyRevision(allocator: std.mem.Allocator, declaration: M.Declaration, value: Completed) !c.fuze.TableSchema.Owned {
    const root = value.manifest;
    const revision = value.revision;
    try root.validate();
    try revision.validate();
    if (root.format != c.DirectTransactionRecord.format or
        !std.meta.eql(root.scope, revision.transaction.scope()) or
        !std.meta.eql(revision.metadata.computation, try declaration.interpretation(allocator)) or
        !std.meta.eql(revision.metadata.source, declaration.source.interpretation.interpretation) or
        !std.meta.eql(revision.metadata.output, declaration.output.interpretation.interpretation)) return error.DataflowIdentityConflict;
    try revision.metadata.requireDecision(value.decision);
    const encoded = try revision.schema.decode(allocator, c.fuze.TableSchema.max_bytes);
    defer allocator.free(encoded);
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(encoded, &digest, .{});
    if (encoded.len != revision.metadata.schema.bytes or !std.mem.eql(u8, &digest, &revision.metadata.schema.sha256)) return error.InvalidManagedTableRecord;
    var schema = try c.fuze.TableSchema.decode(allocator, encoded);
    errdefer schema.deinit();
    if (schema.schema.object != revision.metadata.output.object.object or schema.schema.revision != revision.metadata.output.revision) return error.DataflowIdentityConflict;
    return schema;
}
