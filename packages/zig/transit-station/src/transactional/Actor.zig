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
pub const max_mailboxes = 4;
pub const max_targets = 5 + 1 + max_mailboxes;
pub const Protocol = enum { raw_cast, envelope };

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
    protocol: Protocol = .raw_cast,
    mailboxes: []const p.StreamQueue.Partition = &.{},
    timers: ?p.StreamQueue.Partition = null,
    max_conflict_retries: u8 = 8,

    pub fn validate(self: Declaration) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.connection.validate();
        try (p.Transaction.Execution{ .realm = self.connection.scope.realm, .pid = self.pid, .principal = self.connection.principal, .generation = 1, .code = self.code, .workload = self.workload, .input = null }).validate();
        if (std.mem.allEqual(u8, &self.behavior, 0) or self.namespace == 0 or self.lease_ms == 0 or self.predicate.len == 0 or self.mailboxes.len > max_mailboxes)
            return error.InvalidActorDeclaration;
        try self.predicate.validate();
        try self.transaction.validate();
        try self.limits.validate();
        const objects = [_]d.Definition{ self.control, self.state, self.table, self.inbox.interpretation, self.journal.interpretation, self.outbox.interpretation };
        for (objects, 0..) |object, i| {
            try object.validate();
            try self.connection.object(object.object);
            for (objects[0..i]) |prior| if (std.meta.eql(object.object, prior.object)) return error.InvalidActorDeclaration;
        }
        try self.inbox.validate();
        try self.journal.validate();
        try self.outbox.validate();
        if (self.timers) |tmr| {
            try tmr.validate();
            try self.connection.object(tmr.interpretation.object);
        }
        for (self.mailboxes, 0..) |mailbox, i| {
            try mailbox.validate();
            try self.connection.object(mailbox.interpretation.object);
            for (self.mailboxes[0..i]) |prior| if (std.meta.eql(mailbox, prior)) return error.InvalidActorDeclaration;
        }
        var target_buf: [max_targets]p.Transaction.Target = undefined;
        const selected = self.targetsInto(&target_buf);
        if (self.transaction.participants < selected.len or self.transaction.statements < @as(u64, self.limits.writes) + self.limits.outputs + 4)
            return error.InvalidActorDeclaration;
    }

    pub fn canDeliverTo(self: Declaration, target: p.StreamQueue.Partition) bool {
        if (std.meta.eql(target, self.inbox)) return true;
        for (self.mailboxes) |mailbox| if (std.meta.eql(target, mailbox)) return true;
        return false;
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

    pub fn targetsInto(self: Declaration, buffer: *[max_targets]p.Transaction.Target) []const p.Transaction.Target {
        var count: usize = 5;
        buffer[0] = .{ .object = self.state.object, .kind = .kv, .partition = null };
        buffer[1] = .{ .object = self.table.object, .kind = .table, .partition = null };
        buffer[2] = .{ .object = self.inbox.interpretation.object, .kind = .queue, .partition = self.inbox.partition };
        buffer[3] = .{ .object = self.journal.interpretation.object, .kind = .stream, .partition = self.journal.partition };
        buffer[4] = .{ .object = self.outbox.interpretation.object, .kind = .queue, .partition = self.outbox.partition };
        const addQueue = struct {
            fn push(buf: *[max_targets]p.Transaction.Target, len: *usize, part: p.StreamQueue.Partition) void {
                const candidate: p.Transaction.Target = .{ .object = part.interpretation.object, .kind = .queue, .partition = part.partition };
                for (buf[0..len.*]) |existing| if (std.meta.eql(existing, candidate)) return;
                buf[len.*] = candidate;
                len.* += 1;
            }
        }.push;
        if (self.timers) |tmr| addQueue(buffer, &count, tmr);
        for (self.mailboxes) |mailbox| addQueue(buffer, &count, mailbox);
        const slice = buffer[0..count];
        std.mem.sort(p.Transaction.Target, slice, {}, struct {
            fn less(_: void, left: p.Transaction.Target, right: p.Transaction.Target) bool {
                return left.order(right) == .lt;
            }
        }.less);
        return slice;
    }
};

pub const HeldInput = struct {
    claim_turn: u64,
    claim: p.StreamQueue.ClaimReceipt,
    source: p.StreamQueue.RecordIdentity,
    execution_origin: ?p.Transaction.Origin = null,
    lease: p.StreamQueue.Lease,
    input: Turn.Binary,
};

pub const Pending = struct {
    begin: c.DirectTransactionRequest.Begin,
    commit: d.Operation,
    phase: enum { beginning, claiming, reading, acquiring, handling, dispatched, staging, executing, committing, aborting, recovering },
    claim: ?p.StreamQueue.ClaimReceipt,
    source: ?p.StreamQueue.RecordIdentity,
    execution_origin: ?p.Transaction.Origin = null,
    lease: ?p.StreamQueue.Lease,
    input: ?Turn.Binary,
    draft: ?Turn.Draft,
    next_statement: u16,
    statement: ?c.DirectTransactionWorkspace.StatementWork,
    batch: ?c.DirectTransactionRequest.StagedBatch = null,
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
    failure: u64 = 0,
    blocked_generation: u64 = 0,
    conflict_retries: u8 = 0,
    held_input: ?HeldInput = null,
    pending: ?Pending,
    claim_release: ?p.QueueRead.Release = null,

    pub fn initial(digest: [32]u8) Head {
        return .{
            .definition = p.Growth.current_definition,
            .actor = digest,
            .initialized = false,
            .next_turn = 1,
            .completed = 0,
            .blocked = false,
            .retired = false,
            .failure = 0,
            .blocked_generation = 0,
            .conflict_retries = 0,
            .held_input = null,
            .pending = null,
            .claim_release = null,
        };
    }

    pub fn validate(self: Head, actor: Declaration, allocator: std.mem.Allocator) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        if (!std.mem.eql(u8, &self.actor, &try actor.digest(allocator)) or self.next_turn == 0 or self.completed >= self.next_turn)
            return error.ActorIdentityConflict;
        if (self.blocked and self.held_input != null) return error.ActorIdentityConflict;
        if (self.claim_release) |release| {
            try release.validate();
            if (self.pending != null or !std.meta.eql(release.claim.claim.target, actor.inbox) or
                !std.meta.eql(release.operation.scope, actor.connection.scope))
                return error.ActorIdentityConflict;
        }
        if (self.held_input) |held| {
            try held.claim.validate();
            try held.source.validate();
            try held.lease.validate();
            if (held.execution_origin) |orig| try orig.validate();
            if (self.retired or held.claim_turn == 0 or held.claim_turn > self.next_turn or
                !std.meta.eql(held.source.target, actor.inbox) or !std.meta.eql(held.lease.target, actor.inbox) or
                !std.meta.eql(held.lease.claim, held.claim.claim.operation))
                return error.ActorIdentityConflict;
        }
        if (self.pending) |work| {
            try work.begin.validate();
            try work.commit.validate();
            if (work.execution_origin) |orig| try orig.validate();
            const execution = work.begin.execution orelse return error.ActorIdentityConflict;
            const claim = execution.input orelse return error.ActorIdentityConflict;
            const predicate_ok = std.meta.eql(claim.predicate, @as(?p.QueuePredicate, actor.predicate)) or
                (self.held_input != null and claim.predicate == null);
            const lease_ok = claim.lease_ms == actor.lease_ms or
                (self.held_input != null and claim.lease_ms == self.held_input.?.claim.claim.lease_ms);
            if (execution.realm != actor.connection.scope.realm or execution.pid != actor.pid or execution.code != actor.code or
                !std.meta.eql(execution.workload, actor.workload) or !std.meta.eql(claim.target, actor.inbox) or
                claim.maximum != 1 or !lease_ok or !predicate_ok or
                !std.meta.eql(work.commit.scope, actor.connection.scope) or work.commit.principal != execution.principal or work.begin.selection != .explicit_objects)
                return error.ActorIdentityConflict;
            var expected_buf: [max_targets]p.Transaction.Target = undefined;
            const expected = actor.targetsInto(&expected_buf);
            if (work.begin.selection.explicit_objects.len != expected.len) return error.ActorIdentityConflict;
            for (work.begin.selection.explicit_objects, expected) |actual, target| if (!std.meta.eql(actual, target)) return error.ActorIdentityConflict;
            const turn = self.next_turn - 1;
            const connection = work.begin.key.connection;
            try work.begin.key.requireSame(token(connection, self.actor, turn));
            const expected_claim_turn = if (self.held_input) |held| held.claim_turn else turn;
            const expected_claim_op = if (self.held_input) |held| held.claim.claim.operation else operation(connection, self.actor, expected_claim_turn, "claim", 0);
            if (!std.meta.eql(work.begin.operation, operation(connection, self.actor, turn, "begin", 0)) or
                !std.meta.eql(work.commit, operation(connection, self.actor, turn, "commit", 0)) or
                !std.meta.eql(claim.operation, expected_claim_op)) return error.ActorIdentityConflict;
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
            if (work.statement != null and work.batch != null) return error.ActorIdentityConflict;
            if (work.statement) |statement| {
                try statement.validate();
                if (!std.meta.eql(statement.statement().transaction.begin, work.begin.operation) or statement.statement().sequence != work.next_statement + 1)
                    return error.ActorIdentityConflict;
            }
            if (work.batch) |*batch| {
                batch.validate(connection) catch return error.ActorIdentityConflict;
                if (!std.meta.eql(batch.entries[0].?.statement().transaction.begin, work.begin.operation) or
                    batch.firstSequence() != work.next_statement + 1 or batch.lastSequence() > actor.transaction.statements)
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
