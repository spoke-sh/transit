const std = @import("std");
const t = std.testing;
const s = @import("root.zig");
const p = @import("transit_protocol");
const x = p.Transaction;
const D = s.TransactionDirectory;
const J = s.TransactionDecisionLog;
const f = @import("transaction_test_support.zig");

const Access = struct {
    allowed: bool = true,
    epoch: u64 = 1,
    policy: u64 = 1,
    locked: bool = false,
    conflict: bool = false,
    missing: bool = false,
    checked: usize = 0,
    verified: usize = 0,

    fn acquire(raw: *anyopaque) !J.Guard.Fence {
        const self: *@This() = @ptrCast(@alignCast(raw));
        if (!self.allowed) return error.AccessDenied;
        try t.expect(!self.locked);
        self.locked = true;
        return .{ .writer_epoch = self.epoch, .policy_epoch = self.policy };
    }
    fn release(raw: *anyopaque) void {
        const self: *@This() = @ptrCast(@alignCast(raw));
        self.locked = false;
    }
    fn guard(self: *@This()) J.Guard {
        return .{ .context = self, .acquire = acquire, .release = release };
    }
    fn participant(raw: *anyopaque, _: x.Participant) !void {
        const self: *@This() = @ptrCast(@alignCast(raw));
        try t.expect(self.locked);
        if (self.conflict) return error.TransactionConflict;
        self.checked += 1;
    }
    fn prepared(raw: *anyopaque, _: x.Prepared) !void {
        const self: *@This() = @ptrCast(@alignCast(raw));
        try t.expect(self.locked);
        if (self.missing) return error.ParticipantUnavailable;
        self.verified += 1;
    }
    fn verification(self: *@This()) J.Verification {
        return .{ .context = self, .participant = participant, .prepared = prepared };
    }
    fn beforeDecision(raw: *anyopaque) !void {
        const self: *@This() = @ptrCast(@alignCast(raw));
        try t.expect(self.locked);
    }
};

fn binding(objects: s.TransitObjectStore.ObjectStore) !J.Binding {
    var selected = try D.init(t.allocator, objects, f.identity, .participants, 1000, 1, 1024 * 1024);
    defer selected.deinit();
    for (1..4) |object| try selected.put(f.participant(object));
    const root = try selected.seal();
    return .{ .begin = f.begin(root), .attempt = f.attempt(root) };
}

fn preparations(objects: s.TransitObjectStore.ObjectStore, frozen: J.Binding, count: usize) !x.Directory {
    var directory = try D.init(t.allocator, objects, f.identity, .preparations, 1000, 1, 1024 * 1024);
    defer directory.deinit();
    for (1..count + 1) |object| try directory.put(f.preparation(object, frozen.attempt));
    return directory.seal();
}

fn queueGuard(object: u64) x.LogGuard {
    return .{ .kind = .queue, .source = .{
        .target = .{ .definition = p.Growth.current_definition, .interpretation = .{ .object = .{ .scope = f.scope, .branch = 1, .object = object }, .revision = 1, .digest = @splat(1) }, .partition = 0 },
        .accepted = .{ .partition = object + 10, .next_lsn = 5 },
        .retained_from = 0,
        .next = 1,
    }, .changed_lsn = 3 };
}

test "transaction decision requires one exact source destination transfer pair" {
    const Case = enum { valid, ordinary_append, wrong_statement, wrong_source, missing_destination, shared_destination };
    for (std.enums.values(Case)) |case| {
        var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
        defer objects.deinit();
        var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
        defer wal.deinit();
        var selected = try D.init(t.allocator, objects.objectStore(), f.identity, .participants, 4, 1, 1024 * 1024);
        defer selected.deinit();
        const payload = "paired transfer payload";
        const transfer: x.TerminalTransfer = .{
            .operation = .{ .scope = f.scope, .principal = 0, .operation = 201 },
            .source = .{ .exhausted = .{ .target = queueGuard(2).source.target, .offset = 0, .lease_epoch = 1, .attempt = 1, .not_before_ms = 100 } },
            .destination = .{ .target = queueGuard(3).source.target, .operation = .{ .scope = f.scope, .principal = 0, .operation = 202 }, .kind = .queue, .producer = null, .rows = 1, .payload = s.LogBatch.content(payload) },
        };
        const statement: x.Statement = .{ .transaction = f.identity, .sequence = 1, .intent = @splat(7) };
        var participants: [3]x.Participant = undefined;
        const count: usize = if (case == .shared_destination) 3 else if (case == .missing_destination) 1 else 2;
        for (participants[0..count], 0..) |*participant, i| {
            const basis = queueGuard(2 + i);
            var actions = try s.LogTransactionActions.init(t.allocator, objects.objectStore(), f.identity, basis, 2, 1024, 1, 1024 * 1024);
            defer actions.deinit();
            var action: x.LogAction = .{ .statement = statement, .ordinal = if (i == 1) 2 else 1, .action = if (i == 1) .{ .queue_transfer_append = transfer } else .{ .queue_terminal = transfer } };
            if (i == 2) {
                action.action.queue_terminal.source.exhausted.target = basis.source.target;
                action.action.queue_terminal.operation.operation = 203;
            }
            if (i == 1) switch (case) {
                .ordinary_append => action.action = .{ .append = transfer.destination },
                .wrong_statement => action.statement.sequence = 2,
                .wrong_source => action.action.queue_transfer_append.source.exhausted.lease_epoch = 2,
                else => {},
            };
            try actions.put(action, if (i == 1) payload else null);
            participant.* = .{ .log = .{ .guard = basis, .actions = try actions.seal() } };
            try selected.put(.{ .participant = participant.* });
        }
        const directory = try selected.seal();
        var frozen: J.Binding = .{ .begin = f.begin(directory), .attempt = f.attempt(directory) };
        frozen.begin.limits.resident_bytes = 8 * 1024 * 1024;
        if (case == .wrong_statement) frozen.attempt.last_statement = 2;
        var prepared = try D.init(t.allocator, objects.objectStore(), f.identity, .preparations, 4, 1, 1024 * 1024);
        defer prepared.deinit();
        for (participants[0..count]) |participant| {
            const guard = participant.guard();
            try prepared.put(.{ .prepared = .{ .attempt = frozen.attempt, .target = guard.target(), .predecessor = guard, .position = .{ .partition = guard.accepted().partition, .next_lsn = 6 }, .successor = f.content } });
        }
        var journal = try J.init(t.allocator, wal.log(), objects.objectStore(), 9, frozen);
        try journal.recover();
        var access: Access = .{};
        try journal.freeze(access.guard());
        var verification = access.verification();
        verification.before_decision = Access.beforeDecision;
        // Stub owner verification isolates neutral directory pairing. It does
        // not establish payload encoding, real preparation or source authority.
        if (case == .valid) {
            try t.expectEqual(.committed, (try journal.commit(try prepared.seal(), verification, access.guard())).outcome);
        } else {
            try t.expectError(error.InvalidTransactionTransfer, journal.commit(try prepared.seal(), verification, access.guard()));
            try t.expect(journal.decision == null);
            try t.expectEqual(@as(u64, 1), try wal.log().tail(9));
        }
    }
}

test "transaction decision log recovers lost freeze and commit replies from disk" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var access: Access = .{};
    var frozen: J.Binding = undefined;
    var prepared: x.Directory = undefined;
    var receipt: x.Decision = undefined;
    {
        var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
        defer objects.deinit();
        var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
        defer wal.deinit();
        frozen = try binding(objects.objectStore());
        var owner = try J.init(t.allocator, wal.log(), objects.objectStore(), 4, frozen);
        try owner.recover();
        try t.expect(try owner.observe(access.guard()) == .not_observed);
        owner.lose_reply = true;
        try t.expectError(error.LostAcknowledgement, owner.freeze(access.guard()));
        try t.expectEqual(@as(u64, 1), try wal.log().tail(4));
        // Exact freeze retry adds no record and cannot choose another attempt.
        try owner.freeze(access.guard());
        prepared = try preparations(objects.objectStore(), frozen, 3);
    }
    {
        var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
        defer objects.deinit();
        var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
        defer wal.deinit();
        var owner = try J.init(t.allocator, wal.log(), objects.objectStore(), 4, frozen);
        try owner.recover();
        try t.expect(try owner.observe(access.guard()) == .preparing);
        owner.lose_reply = true;
        try t.expectError(error.LostAcknowledgement, owner.commit(prepared, access.verification(), access.guard()));
        try t.expectEqual(@as(usize, 3), access.checked);
        try t.expectEqual(@as(usize, 3), access.verified);
        receipt = (try owner.observe(access.guard())).decided;
        try t.expect(receipt.outcome == .committed);
    }
    {
        var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
        defer objects.deinit();
        var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
        defer wal.deinit();
        var owner = try J.init(t.allocator, wal.log(), objects.objectStore(), 4, frozen);
        try owner.recover();
        access.conflict = true;
        access.missing = true;
        // Settlement of accepted work must not attempt its preparation again.
        try t.expectEqualDeep(receipt, try owner.abort(access.guard()));
        try t.expectEqualDeep(receipt, try owner.commit(prepared, access.verification(), access.guard()));
        try t.expectEqual(@as(usize, 3), access.verified);
        try t.expectEqual(@as(u64, 2), try wal.log().tail(4));
        access.allowed = false;
        try t.expectError(error.AccessDenied, owner.observe(access.guard()));
        try t.expectError(error.AccessDenied, owner.abort(access.guard()));
        access.allowed = true;
        try t.expectEqualDeep(receipt, (try owner.observe(access.guard())).decided);
    }
}

test "transaction decision requires complete preparations current guards and available participants" {
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    const frozen = try binding(objects.objectStore());
    const incomplete = try preparations(objects.objectStore(), frozen, 2);
    const complete = try preparations(objects.objectStore(), frozen, 3);
    var owner = try J.init(t.allocator, wal.log(), objects.objectStore(), 4, frozen);
    var access: Access = .{};
    try owner.recover();
    try t.expectError(error.TransactionNotFrozen, owner.commit(complete, access.verification(), access.guard()));
    try owner.freeze(access.guard());
    try t.expectError(error.InvalidTransactionDecision, owner.commit(incomplete, access.verification(), access.guard()));
    access.conflict = true;
    try t.expectError(error.TransactionConflict, owner.commit(complete, access.verification(), access.guard()));
    access.conflict = false;
    access.missing = true;
    try t.expectError(error.ParticipantUnavailable, owner.commit(complete, access.verification(), access.guard()));
    access.allowed = false;
    try t.expectError(error.AccessDenied, owner.commit(complete, access.verification(), access.guard()));
    access.allowed = true;
    try t.expect(try owner.observe(access.guard()) == .preparing);
    try t.expectEqual(@as(u64, 1), try wal.log().tail(4));
    const aborted = try owner.abort(access.guard());
    try t.expect(aborted.outcome == .aborted);
    try t.expectEqualDeep(aborted, try owner.commit(complete, access.verification(), access.guard()));
}

test "transaction decision former coordinators cannot publish or overwrite the winning abort" {
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    const frozen = try binding(objects.objectStore());
    const prepared = try preparations(objects.objectStore(), frozen, 3);
    var old = try J.init(t.allocator, wal.log(), objects.objectStore(), 4, frozen);
    var access: Access = .{};
    try old.recover();
    try old.freeze(access.guard());
    try wal.log().fence(4, 2, 2);
    try t.expectError(error.StaleWriterEpoch, old.commit(prepared, access.verification(), access.guard()));
    try t.expectError(error.TransactionRecoveryRequired, old.observe(access.guard()));
    var replacement = try J.init(t.allocator, wal.log(), objects.objectStore(), 4, frozen);
    try replacement.recover();
    access.epoch = 2;
    access.policy = 2;
    const receipt = try replacement.abort(access.guard());
    try old.recover();
    try t.expectEqualDeep(receipt, try old.commit(prepared, access.verification(), access.guard()));
    try t.expectEqual(@as(u64, 2), try wal.log().tail(4));
}

test "transaction decision recovery rejects missing evidence and changed accepted identity" {
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    const frozen = try binding(objects.objectStore());
    const prepared = try preparations(objects.objectStore(), frozen, 3);
    var owner = try J.init(t.allocator, wal.log(), objects.objectStore(), 4, frozen);
    var access: Access = .{};
    try owner.recover();
    try owner.freeze(access.guard());
    _ = try owner.commit(prepared, access.verification(), access.guard());
    var other = frozen;
    other.attempt.workspace.sha256[0] ^= 1;
    var wrong = try J.init(t.allocator, wal.log(), objects.objectStore(), 4, other);
    try t.expectError(error.TransactionIdentityConflict, wrong.recover());
    var name: [96]u8 = undefined;
    try objects.objectStore().delete(try D.objectKey(prepared.content, &name));
    try t.expectError(error.MissingTransactionDirectory, owner.recover());
    try t.expectError(error.TransactionRecoveryRequired, owner.observe(access.guard()));
    try t.expectEqual(@as(u64, 2), try wal.log().tail(4));
}

test "transaction decision memory refusal cannot accept work or change original recovery identity" {
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var frozen = try binding(objects.objectStore());
    frozen.begin.limits.resident_bytes = 1;
    var owner = try J.init(t.allocator, wal.log(), objects.objectStore(), 4, frozen);
    var access: Access = .{};
    try owner.recover();
    try t.expectError(error.TransactionMemoryLimit, owner.freeze(access.guard()));
    try t.expectEqual(@as(u64, 0), try wal.log().tail(4));
    try t.expect(try owner.observe(access.guard()) == .not_observed);
    // A parent OOM with adequate admitted capacity remains a different failure.
    frozen.begin.limits.resident_bytes = 65536;
    var failing = t.FailingAllocator.init(t.allocator, .{ .fail_index = 0 });
    owner = try J.init(failing.allocator(), wal.log(), objects.objectStore(), 4, frozen);
    try owner.recover();
    try t.expectError(error.OutOfMemory, owner.freeze(access.guard()));
    try t.expectEqual(@as(u64, 0), try wal.log().tail(4));
}

const FaultLog = struct {
    base: s.TransitLog.Log,
    fault: enum { none, before, after } = .none,

    fn log(self: *@This()) s.TransitLog.Log {
        return .{ .context = self, .vtable = &.{ .append = append, .read = read, .tail = tail, .trim = trim, .fence = fence } };
    }
    fn append(raw: *anyopaque, partition: u64, expected: ?u64, writer: u64, policy: u64, kind: s.TransitLog.FrameKind, bytes: []const u8) !s.TransitLog.AppendReceipt {
        const self: *@This() = @ptrCast(@alignCast(raw));
        if (self.fault == .before) return error.InjectedAppendFailure;
        const result = try self.base.append(partition, expected, writer, policy, kind, bytes);
        if (self.fault == .after) return error.InjectedAppendFailure;
        return result;
    }
    fn read(raw: *anyopaque, allocator: std.mem.Allocator, partition: u64, from: u64, count: usize) !s.TransitLog.Log.OwnedBatch {
        const self: *@This() = @ptrCast(@alignCast(raw));
        return self.base.read(allocator, partition, from, count);
    }
    fn tail(raw: *anyopaque, partition: u64) !u64 {
        const self: *@This() = @ptrCast(@alignCast(raw));
        return self.base.tail(partition);
    }
    fn trim(raw: *anyopaque, partition: u64, through: u64) !void {
        const self: *@This() = @ptrCast(@alignCast(raw));
        return self.base.trim(partition, through);
    }
    fn fence(raw: *anyopaque, partition: u64, writer: u64, policy: u64) !void {
        const self: *@This() = @ptrCast(@alignCast(raw));
        return self.base.fence(partition, writer, policy);
    }
};

test "transaction uncertain append preserves the original decision and never infers abort" {
    for ([_]@FieldType(FaultLog, "fault"){ .before, .after }) |fault| {
        var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
        defer objects.deinit();
        var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
        defer wal.deinit();
        var faulty: FaultLog = .{ .base = wal.log() };
        const frozen = try binding(objects.objectStore());
        const prepared = try preparations(objects.objectStore(), frozen, 3);
        var owner = try J.init(t.allocator, faulty.log(), objects.objectStore(), 4, frozen);
        var access: Access = .{};
        try owner.recover();
        try owner.freeze(access.guard());
        faulty.fault = fault;
        try t.expectError(error.InjectedAppendFailure, owner.commit(prepared, access.verification(), access.guard()));
        try t.expectError(error.TransactionRecoveryRequired, owner.abort(access.guard()));
        faulty.fault = .none;
        try owner.recover();
        const observed = try owner.observe(access.guard());
        if (fault == .after) {
            try t.expect(observed == .decided and observed.decided.outcome == .committed);
            try t.expectEqualDeep(observed.decided, try owner.abort(access.guard()));
        } else {
            try t.expect(observed == .preparing);
            try t.expect((try owner.abort(access.guard())).outcome == .aborted);
        }
        try t.expectEqual(@as(u64, 2), try wal.log().tail(4));
    }
}
