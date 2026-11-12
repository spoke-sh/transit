//! Internal declared actor and its discoverable progress. KV rows retain data,
//! not native ownership. Every turn binds the native execution condition.
const std = @import("std");
const c = @import("transit_catalog");
const p = c.protocol;
const d = p.DataLifecycle;
const Turn = @import("Turn.zig");
pub const max_bytes = 128 * 1024;
pub const original_format: u32 = 0x53544131; // private STA1
pub const spec: c.storage.KVDeclaration.Spec = .{ .value_type = .binary, .nullable = false };

pub const Declaration = struct {
    definition: p.Growth.Definition,
    connection: c.DirectTableProtocol.Connection,
    namespace: u64,
    pid: u64,
    code: u32,
    workload: ?[32]u8,
    behavior: [32]u8,
    control: d.Definition,
    state: d.Definition,
    table: d.Definition,
    table_name: c.TableAuthority.Name,
    inbox: p.StreamQueue.Partition,
    journal: p.StreamQueue.Partition,
    outbox: p.StreamQueue.Partition,
    predicate: p.QueuePredicate,
    lease_ms: u64,
    limits: Turn.Limits,
    transaction: p.Transaction.Limits,

    pub fn validate(self: Declaration) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.connection.validate();
        try (p.Transaction.Execution{ .realm = self.connection.scope.realm, .pid = self.pid, .principal = self.connection.principal, .generation = 1, .code = self.code, .workload = self.workload, .input = null }).validate();
        if (std.mem.allEqual(u8, &self.behavior, 0) or self.namespace == 0 or self.lease_ms == 0 or self.predicate.len == 0) return error.InvalidActorDeclaration;
        try self.predicate.validate();
        try self.transaction.validate();
        try self.limits.validate();
        if (self.transaction.participants < 5 or self.transaction.statements < @as(u64, self.limits.writes) + self.limits.outputs + 2)
            return error.InvalidActorDeclaration;
        const objects = [_]d.Definition{ self.control, self.state, self.table, self.inbox.interpretation, self.journal.interpretation, self.outbox.interpretation };
        for (objects, 0..) |object, i| {
            try object.validate();
            try self.connection.object(object.object);
            for (objects[0..i]) |prior| if (std.meta.eql(object.object, prior.object)) return error.InvalidActorDeclaration;
        }
        try self.inbox.validate();
        try self.journal.validate();
        try self.outbox.validate();
    }

    pub fn digest(self: Declaration, allocator: std.mem.Allocator) ![32]u8 {
        try self.validate();
        const bytes = try p.Json.valueAllocBounded(allocator, self, 32 * 1024);
        defer allocator.free(bytes);
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        hash.update("transit.station.private.actor.v1\x00");
        hash.update(bytes);
        return hash.finalResult();
    }

    pub fn targets(self: Declaration) [5]p.Transaction.Target {
        var result = [_]p.Transaction.Target{
            .{ .object = self.state.object, .kind = .kv, .partition = null },
            .{ .object = self.table.object, .kind = .table, .partition = null },
            .{ .object = self.inbox.interpretation.object, .kind = .queue, .partition = self.inbox.partition },
            .{ .object = self.journal.interpretation.object, .kind = .stream, .partition = self.journal.partition },
            .{ .object = self.outbox.interpretation.object, .kind = .queue, .partition = self.outbox.partition },
        };
        std.mem.sort(p.Transaction.Target, &result, {}, struct {
            fn less(_: void, left: p.Transaction.Target, right: p.Transaction.Target) bool {
                return left.order(right) == .lt;
            }
        }.less);
        return result;
    }
};

pub const Pending = struct {
    begin: c.DirectTransactionRequest.Begin,
    commit: d.Operation,
    phase: enum { beginning, claiming, reading, acquiring, handling, dispatched, staging, executing, committing, recovering },
    claim: ?p.StreamQueue.ClaimReceipt,
    source: ?p.StreamQueue.RecordIdentity,
    lease: ?p.StreamQueue.Lease,
    input: ?Turn.Binary,
    draft: ?Turn.Draft,
    next_statement: u16,
    statement: ?c.DirectTransactionWorkspace.StatementWork,
    failed: bool,
};
pub const Head = struct {
    definition: p.Growth.Definition,
    actor: [32]u8,
    initialized: bool,
    next_turn: u64,
    completed: u64,
    blocked: bool,
    retired: bool,
    pending: ?Pending,

    pub fn initial(digest: [32]u8) Head {
        return .{ .definition = p.Growth.current_definition, .actor = digest, .initialized = false, .next_turn = 1, .completed = 0, .blocked = false, .retired = false, .pending = null };
    }
    pub fn validate(self: Head, actor: Declaration, allocator: std.mem.Allocator) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        if (!std.mem.eql(u8, &self.actor, &try actor.digest(allocator)) or self.next_turn == 0 or self.completed >= self.next_turn) return error.ActorIdentityConflict;
        if (self.pending) |work| {
            try work.begin.validate();
            try work.commit.validate();
            const execution = work.begin.execution orelse return error.ActorIdentityConflict;
            const claim = execution.input orelse return error.ActorIdentityConflict;
            if (execution.realm != actor.connection.scope.realm or execution.pid != actor.pid or execution.code != actor.code or
                !std.meta.eql(execution.workload, actor.workload) or !std.meta.eql(claim.target, actor.inbox) or
                claim.maximum != 1 or claim.lease_ms != actor.lease_ms or !std.meta.eql(claim.predicate, @as(?p.QueuePredicate, actor.predicate)) or
                !std.meta.eql(work.commit.scope, actor.connection.scope) or work.commit.principal != execution.principal or work.begin.selection != .explicit_objects)
                return error.ActorIdentityConflict;
            const expected = actor.targets();
            if (work.begin.selection.explicit_objects.len != expected.len) return error.ActorIdentityConflict;
            for (work.begin.selection.explicit_objects, expected) |actual, target| if (!std.meta.eql(actual, target)) return error.ActorIdentityConflict;
            const turn = self.next_turn - 1;
            const connection = work.begin.key.connection;
            try work.begin.key.requireSame(token(connection, self.actor, turn));
            if (!std.meta.eql(work.begin.operation, operation(connection, self.actor, turn, "begin", 0)) or
                !std.meta.eql(work.commit, operation(connection, self.actor, turn, "commit", 0)) or
                !std.meta.eql(claim.operation, operation(connection, self.actor, turn, "claim", 0))) return error.ActorIdentityConflict;
            const fingerprint = try p.Json.hashBounded("transit.station.private.turn.v1\x00", .{ .actor = self.actor, .turn = turn, .execution = execution }, 32 * 1024);
            if (!std.mem.eql(u8, &fingerprint, &work.begin.fingerprint)) return error.ActorIdentityConflict;
            if ((work.source != null) != (work.input != null) or (work.source != null) != (work.lease != null) or
                (work.draft != null and work.source == null) or (work.phase == .committing and work.draft == null)) return error.ActorIdentityConflict;
            if (work.claim) |receipt| try receipt.requireClaim(claim);
            if (work.lease) |lease| {
                try lease.validate();
                if (!std.meta.eql(lease.claim, claim.operation) or !std.meta.eql(lease.target, claim.target)) return error.ActorIdentityConflict;
            }
            if (work.source) |source| {
                try source.validate();
                if (!std.meta.eql(source.target, actor.inbox)) return error.ActorIdentityConflict;
            }
            if (work.statement) |statement| {
                try statement.validate();
                if (!std.meta.eql(statement.statement().transaction.begin, work.begin.operation) or statement.statement().sequence != work.next_statement + 1)
                    return error.ActorIdentityConflict;
            }
            if (work.next_statement > actor.transaction.statements) return error.TurnCapacity;
        }
    }
};

pub fn key(pid: u64) [14]u8 {
    var result: [14]u8 = undefined;
    result[0..6].* = "actor/".*;
    std.mem.writeInt(u64, result[6..14], pid, .big);
    return result;
}

/// Exact identities derive from an immutable actor and saved turn ordinal.
/// This is preparation, never authority or permission to replay unknown work.
pub fn operation(connection: c.DirectTableProtocol.Connection, digest: [32]u8, turn: u64, label: []const u8, ordinal: u64) d.Operation {
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.station.private.operation.v1\x00");
    hash.update(&digest);
    hash.update(label);
    var bytes: [24]u8 = undefined;
    std.mem.writeInt(u64, bytes[0..8], connection.principal, .big);
    std.mem.writeInt(u64, bytes[8..16], turn, .big);
    std.mem.writeInt(u64, bytes[16..24], ordinal, .big);
    hash.update(&bytes);
    const value = hash.finalResult();
    return .{ .scope = connection.scope, .principal = connection.principal, .operation = std.mem.readInt(u64, value[0..8], .big) | 1 };
}

pub fn token(connection: c.DirectTableProtocol.Connection, digest: [32]u8, turn: u64) c.DirectClientToken.Key {
    var bytes: [16]u8 = @splat(0);
    std.mem.writeInt(u64, bytes[8..16], turn, .big);
    return .{ .definition = p.Growth.current_definition, .connection = connection, .account = digest, .token = bytes };
}
