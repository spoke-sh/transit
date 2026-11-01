const std = @import("std");
const t = std.testing;
const s = @import("root.zig");
const p = @import("transit_protocol");
const f = @import("transit_fuze");
const K = s.KVPartition;
const d = p.DataLifecycle;
const object: d.Object = .{ .scope = .{ .realm = 1, .resource = 2, .catalog = 3 }, .branch = 1, .object = 7 };
const definition: s.KVDeclaration.Definition = .{ .object = object, .revision = 1, .spec = .{ .value_type = .binary, .nullable = true }, .properties = "kv-policy" };

const Access = struct {
    calls: usize = 0,
    deny_at: usize = std.math.maxInt(usize),
    fn acquire(raw: *anyopaque) !K.Guard.Fence {
        const self: *Access = @ptrCast(@alignCast(raw));
        self.calls += 1;
        if (self.calls >= self.deny_at) return error.PermissionDenied;
        return .{ .writer_epoch = 1, .policy_epoch = 1 };
    }
    fn release(_: *anyopaque) void {}
    fn guard(self: *Access) K.Guard {
        return .{ .context = self, .acquire = acquire, .release = release };
    }
};

fn open(wal: *s.LocalWal.LocalWal, objects: *s.LocalSegmentStore.LocalSegmentStore) !K {
    var result = try K.init(t.allocator, 17, definition, wal.log(), objects.objectStore(), .{ .resident_pages = 1 });
    errdefer result.deinit();
    try result.recover();
    return result;
}

fn binding(kv: *K, operation: u64) d.Binding {
    const root = kv.storage.root;
    return .{ .definition = p.Growth.current_definition, .identity = .{ .scope = object.scope, .principal = 4, .operation = operation }, .target = object, .action = if (root.next_lsn == 0) .create else .insert, .expected_definition = if (root.next_lsn == 0) null else root.interpretation, .expected_data = null, .intent = @splat(9) };
}

fn bytes(value: []const u8) f.Types.Values.Cell {
    return .{ .value = .{ .atom = .{ .bytes = value } } };
}

const KVTransactionVerification = struct {
    owner: *K,
    expected: p.Transaction.Prepared,
    fn participant(raw: *anyopaque, selected: p.Transaction.Participant) !void {
        const self: *@This() = @ptrCast(@alignCast(raw));
        if (selected != .state or selected.state.kind != .kv) return error.InvalidTransactionPreparation;
        const reference = self.owner.storage.root.transaction orelse return error.TransactionPreparationMissing;
        const preparation = try s.TableTransaction.load(t.allocator, self.owner.storage.objects, reference);
        try selected.state.guard.requireUnchanged(s.TableTransaction.tableGuard(preparation.predecessor));
        try t.expectEqualDeep(self.expected, try preparation.prepared(reference));
    }
    fn prepared(raw: *anyopaque, value: p.Transaction.Prepared) !void {
        const self: *@This() = @ptrCast(@alignCast(raw));
        try t.expectEqualDeep(self.expected, value);
        const reference = self.owner.storage.root.transaction orelse return error.TransactionPreparationMissing;
        const preparation = try s.TableTransaction.load(t.allocator, self.owner.storage.objects, reference);
        try s.TableTransaction.verifyWorkspace(t.allocator, &self.owner.storage.index, self.owner.storage.log, preparation.workspace.root, self.owner.storage.root.archive);
    }
    fn callbacks(self: *@This()) s.TransactionDecisionLog.Verification {
        return .{ .context = self, .participant = participant, .prepared = prepared };
    }
};

test "KV transaction private batches and common commit or abort survive replacement and reply loss" {
    for ([_]bool{ false, true }) |commit| {
        var tmp = t.tmpDir(.{});
        defer tmp.cleanup();
        var access: Access = .{};
        var frozen: s.TransactionDecisionLog.Binding = undefined;
        var state: s.TableWorkspace.State = undefined;
        var basis: p.Transaction.StateGuard = undefined;
        var expected: p.Transaction.Prepared = undefined;
        var accepted: p.Transaction.Decision = undefined;
        var payload: [1024]u8 = @splat(42);
        for (0..4) |restart| {
            var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
            defer wal.deinit();
            var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
            defer objects.deinit();
            if (restart == 1 or restart == 2) try t.expectError(error.TransactionPrepared, open(&wal, &objects));
            var kv = try K.init(t.allocator, 17, definition, wal.log(), objects.objectStore(), .{ .resident_pages = 1, .transaction_control = true });
            defer kv.deinit();
            try kv.recover();
            if (restart == 0) {
                _ = try kv.create(binding(&kv, 1), access.guard());
                _ = try kv.apply(binding(&kv, 2), &.{.{ .put = .{ .key = "old", .value = bytes("retained") } }}, access.guard());
                basis = s.TableTransaction.tableGuard(kv.storage.root);
                var begin = @import("transaction_test_support.zig").begin(undefined);
                begin.identity.begin.principal = 4;
                begin.limits.resident_bytes = 16 * 1024 * 1024;
                var selection = try s.TransactionDirectory.init(t.allocator, objects.objectStore(), begin.identity, .participants, 1000, 1, 1024 * 1024);
                defer selection.deinit();
                try selection.put(.{ .participant = .{ .state = .{ .kind = .kv, .guard = basis, .access = .read } } });
                begin.objects = try selection.seal();
                const pin = try kv.pin(begin.identity.begin, .{ .partition = 17, .next_lsn = kv.storage.root.next_lsn }, access.guard());
                var workspace = try s.TableWorkspace.init(t.allocator, &kv.storage, begin, pin, null, access.guard());
                defer workspace.deinit();
                const saved = workspace.state();
                const mutation = binding(&kv, 3);
                const statement: p.Transaction.Statement = .{ .transaction = begin.identity, .sequence = 1, .intent = mutation.intent };
                const changes = [_]K.Change{
                    .{ .put = .{ .key = "one", .value = bytes(&payload) } },
                    .{ .put = .{ .key = "two", .value = bytes(&payload), .expect = .absent } },
                    .{ .put = .{ .key = "three", .value = bytes(&payload) } },
                    .{ .put = .{ .key = "four", .value = bytes(&payload) } },
                    .{ .put = .{ .key = "five", .value = bytes(&payload) } },
                    .{ .put = .{ .key = "six", .value = bytes(&payload) } },
                    .{ .remove = "old" },
                };
                const public = kv.storage.root;
                const result = try workspace.executeKV(statement, mutation, &changes, access.guard());
                try t.expectEqual(@as(u64, 7), result.provisional.affected);
                try t.expectEqualDeep(public, kv.storage.root);
                try t.expectEqual(public.next_lsn, try wal.log().tail(17));
                try workspace.rollback(saved);
                try t.expectEqual(@as(u64, 1), workspace.table.root.live_rows);
                try t.expectError(error.TransactionStatementConflict, workspace.executeKV(statement, mutation, &changes, access.guard()));
                var replacement = mutation;
                replacement.identity.operation = 4;
                _ = try workspace.executeKV(.{ .transaction = begin.identity, .sequence = 2, .intent = replacement.intent }, replacement, &changes, access.guard());
                state = workspace.state();
                var writes = try s.TransactionDirectory.init(t.allocator, objects.objectStore(), begin.identity, .participants, 1000, 1, 1024 * 1024);
                defer writes.deinit();
                try writes.put(.{ .participant = .{ .state = .{ .kind = .kv, .guard = basis, .access = .write } } });
                frozen = .{ .begin = begin, .attempt = .{ .definition = p.Growth.current_definition, .transaction = begin.identity, .operation = .{ .scope = object.scope, .principal = 4, .operation = 101 }, .cut = begin.objects.content, .workspace = begin.objects.content, .participants = try writes.seal(), .writes = 1, .last_statement = 2 } };
                var journal = try s.TransactionDecisionLog.init(t.allocator, wal.log(), objects.objectStore(), 18, frozen);
                try journal.recover();
                try journal.freeze(access.guard());
                kv.storage.lose_reply = true;
                try t.expectError(error.LostAcknowledgement, kv.storage.prepareTransaction(frozen, 18, basis, state, access.guard()));
                const reference = kv.storage.root.transaction.?;
                expected = try (try s.TableTransaction.load(t.allocator, objects.objectStore(), reference)).prepared(reference);
                try t.expectEqual(.kv, expected.target.kind);
            } else if (restart == 1) {
                try t.expectEqualDeep(expected, try kv.storage.prepareTransaction(frozen, 18, basis, state, access.guard()));
                try t.expectError(error.TransactionPrepared, kv.get(t.allocator, "one", access.guard()));
                try t.expectError(error.TransactionPrepared, kv.storage.resolveTransaction(access.guard()));
                var journal = try s.TransactionDecisionLog.init(t.allocator, wal.log(), objects.objectStore(), 18, frozen);
                try journal.recover();
                var preparations = try s.TransactionDirectory.init(t.allocator, objects.objectStore(), frozen.begin.identity, .preparations, 1000, 1, 1024 * 1024);
                defer preparations.deinit();
                try preparations.put(.{ .prepared = expected });
                var verification: KVTransactionVerification = .{ .owner = &kv, .expected = expected };
                journal.lose_reply = true;
                if (commit) {
                    try t.expectError(error.LostAcknowledgement, journal.commit(try preparations.seal(), verification.callbacks(), access.guard()));
                } else try t.expectError(error.LostAcknowledgement, journal.abort(access.guard()));
                accepted = (try journal.observe(access.guard())).decided;
            } else if (restart == 2) {
                kv.storage.lose_reply = true;
                try t.expectError(error.LostAcknowledgement, kv.storage.resolveTransaction(access.guard()));
            } else {
                try t.expect(kv.storage.root.transaction == null);
                try t.expectEqual(@as(u64, if (commit) 6 else 1), kv.storage.root.live_rows);
                var value = try kv.get(t.allocator, "six", access.guard());
                defer if (value) |*v| v.deinit();
                try t.expectEqual(commit, value != null);
                if (value) |*v| try t.expectEqualSlices(u8, &payload, v.cell().value.atom.bytes);
                var retained = (try kv.readSnapshot(t.allocator, state.source, "old", access.guard())).?;
                defer retained.deinit();
                try t.expectEqualStrings("retained", retained.cell().value.atom.bytes);
                var journal = try s.TransactionDecisionLog.init(t.allocator, wal.log(), objects.objectStore(), 18, frozen);
                try journal.recover();
                try t.expectEqualDeep(accepted, (try journal.observe(access.guard())).decided);
            }
        }
    }
}

test "direct KV disk batches retain large values original receipts and pinned cuts through trim" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var access: Access = .{};
    var original: d.Binding = undefined;
    var accepted: K.Outcome = undefined;
    var pin: K.SnapshotHandle = undefined;
    var expected: K.Root = undefined;
    const payload = try t.allocator.alloc(u8, 128 * 1024);
    defer t.allocator.free(payload);
    for (payload, 0..) |*byte, i| byte.* = @truncate(i);
    var long_key: [300]u8 = @splat(0);
    long_key[299] = 255;
    const changes = [_]K.Change{
        .{ .put = .{ .key = &long_key, .value = bytes(payload) } },
        .{ .put = .{ .key = "second", .value = bytes("two") } },
        .{ .put = .{ .key = "third", .value = bytes("three") } },
        .{ .put = .{ .key = "fourth", .value = bytes("four") } },
        .{ .put = .{ .key = "fifth", .value = bytes("five") } },
        .{ .put = .{ .key = "nullable", .value = .null } },
    };
    {
        var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{ .segment_bytes = 4096 });
        defer wal.deinit();
        var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
        defer objects.deinit();
        var kv = try open(&wal, &objects);
        defer kv.deinit();
        _ = try kv.create(binding(&kv, 1), access.guard());
        original = binding(&kv, 2);
        const before = kv.storage.root.next_lsn;
        kv.storage.lose_reply = true;
        try t.expectError(error.LostAcknowledgement, kv.apply(original, &changes, access.guard()));
        kv.storage.lose_reply = false;
        accepted = (try kv.observe(original, access.guard())).?.outcome;
        try t.expectEqual(before + 1, accepted.position.next_lsn);
        try t.expectEqual(@as(u64, 6), accepted.affected);
        try t.expectEqualDeep(accepted, try kv.apply(original, &changes, access.guard()));
        pin = try kv.pin(.{ .scope = object.scope, .principal = 4, .operation = 1001 }, accepted.position, access.guard());
        var first = (try kv.get(t.allocator, &long_key, access.guard())).?;
        defer first.deinit();
        _ = try kv.apply(binding(&kv, 3), &.{ .{ .put = .{ .key = &long_key, .value = bytes("replacement") } }, .{ .remove = "second" } }, access.guard());
        // Durable cardinality exceeds the one-page resident cache; callers
        // still submit only bounded batches and never load all keys at reopen.
        for (0..4) |batch| {
            var keys: [16][32]u8 = undefined;
            var extra: [16]K.Change = undefined;
            for (&keys, &extra, 0..) |*key, *change, i| change.* = .{ .put = .{ .key = try std.fmt.bufPrint(key, "extra-{d}", .{batch * 16 + i}), .value = bytes("paged") } };
            _ = try kv.apply(binding(&kv, 10 + batch), &extra, access.guard());
        }
        // Outputs own their buffers across later reads, writes and sealing.
        _ = try kv.storage.flush(access.guard());
        try t.expectEqualSlices(u8, payload, first.cell().value.atom.bytes);
        const archive_cut: d.Position = .{ .partition = 17, .next_lsn = kv.storage.root.next_lsn };
        while (!(try kv.storage.archive(archive_cut, .{}, access.guard())).complete) {}
        _ = try kv.storage.trimArchived(access.guard());
        _ = try kv.storage.checkpoint(.{ .partition = 17, .next_lsn = kv.storage.root.next_lsn }, access.guard());
        expected = kv.storage.root;
    }
    var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{ .segment_bytes = 4096 });
    defer wal.deinit();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    var kv = try open(&wal, &objects);
    defer kv.deinit();
    try t.expectEqualDeep(expected, kv.storage.root);
    try t.expectEqual(@as(u64, 69), kv.storage.root.live_rows);
    for (0..64) |i| {
        var key: [32]u8 = undefined;
        var value = (try kv.get(t.allocator, try std.fmt.bufPrint(&key, "extra-{d}", .{i}), access.guard())).?;
        defer value.deinit();
        try t.expectEqualStrings("paged", value.cell().value.atom.bytes);
    }
    try t.expectEqualDeep(accepted, try kv.apply(original, &changes, access.guard()));
    try t.expectEqualDeep(expected, kv.storage.root);
    var current = (try kv.get(t.allocator, &long_key, access.guard())).?;
    defer current.deinit();
    try t.expectEqualStrings("replacement", current.cell().value.atom.bytes);
    try t.expectEqual(@as(?K.Value, null), try kv.get(t.allocator, "second", access.guard()));
    var retained = (try kv.readSnapshot(t.allocator, pin, &long_key, access.guard())).?;
    defer retained.deinit();
    try t.expectEqualSlices(u8, payload, retained.cell().value.atom.bytes);
    var nullable = (try kv.get(t.allocator, "nullable", access.guard())).?;
    defer nullable.deinit();
    try t.expect(nullable.cell() == .null);
    var changed = changes;
    changed[1].put.value = bytes("changed retry");
    try t.expectError(error.DataIdentityConflict, kv.apply(original, &changed, access.guard()));
    try kv.releaseSnapshot(pin, access.guard());
    try t.expectError(error.TableSnapshotReleased, kv.readSnapshot(t.allocator, pin, "nullable", access.guard()));
    // The latest checkpoint cannot turn a KV into a Table even if the caller
    // supplies an otherwise matching two-column schema and physical partition.
    var columns: [2]f.TableSchema.Column = undefined;
    var masquerade = definition.physical(&columns);
    try t.expectError(error.DataKindMismatch, s.TablePartition.init(t.allocator, 17, masquerade, wal.log(), objects.objectStore(), .{}));
    masquerade.kind = .table;
    var table = try s.TablePartition.init(t.allocator, 17, masquerade, wal.log(), objects.objectStore(), .{});
    defer table.deinit();
    try t.expectError(error.DataKindMismatch, table.recover());
    try t.expect(table.recovery_required);
}

test "direct KV logical guards authorization and value bounds precede publication" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var kv = try open(&wal, &objects);
    defer kv.deinit();
    var access: Access = .{};
    _ = try kv.create(binding(&kv, 1), access.guard());
    _ = try kv.apply(binding(&kv, 2), &.{.{ .put = .{ .key = "key", .value = bytes("before") } }}, access.guard());
    var guarded = binding(&kv, 3);
    guarded.expected_data = .{ .partition = 17, .next_lsn = kv.storage.root.next_lsn };
    const logical = kv.storage.root.changed_lsn;
    _ = try kv.storage.flush(access.guard());
    try t.expectEqual(logical, kv.storage.root.changed_lsn);
    _ = try kv.apply(guarded, &.{.{ .put = .{ .key = "key", .value = bytes("after") } }}, access.guard());
    var stale = guarded;
    stale.identity.operation = 4;
    const before = kv.storage.root;
    try t.expectError(error.TableDataChanged, kv.apply(stale, &.{.{ .remove = "missing" }}, access.guard()));
    access.deny_at = access.calls + 2; // Revoked after staging, before acceptance.
    try t.expectError(error.PermissionDenied, kv.apply(binding(&kv, 5), &.{.{ .remove = "key" }}, access.guard()));
    try t.expectError(error.PermissionDenied, kv.get(t.allocator, "key", access.guard()));
    try t.expectError(error.PermissionDenied, kv.observe(guarded, access.guard()));
    access.deny_at = std.math.maxInt(usize);
    try t.expectEqualDeep(before, kv.storage.root);
    const next = binding(&kv, 5);
    const budget = kv.storage.options.build_resident_bytes;
    kv.storage.options.build_resident_bytes = 1;
    try t.expectError(error.KVBuildBudget, kv.apply(next, &.{.{ .remove = "key" }}, access.guard()));
    kv.storage.options.build_resident_bytes = budget;
    try t.expectError(error.InvalidKVKey, kv.apply(next, &.{.{ .put = .{ .key = "", .value = .null } }}, access.guard()));
    var large_key: [K.max_key_bytes + 1]u8 = @splat(0);
    try t.expectError(error.InvalidKVKey, kv.apply(next, &.{.{ .remove = &large_key }}, access.guard()));
    try t.expectError(error.MissingRequiredField, kv.apply(next, &.{.{ .put = .{ .key = "key", .value = .missing } }}, access.guard()));
    const large = try t.allocator.alloc(u8, K.max_value_bytes + 1);
    defer t.allocator.free(large);
    @memset(large, 0);
    try t.expectError(error.KVValueTooLarge, kv.apply(next, &.{.{ .put = .{ .key = "key", .value = bytes(large) } }}, access.guard()));
    try t.expectError(error.DuplicateBatchKey, kv.apply(next, &.{ .{ .remove = "key" }, .{ .put = .{ .key = "key", .value = .null } } }, access.guard()));
    try t.expectEqualDeep(before, kv.storage.root);
    // Refused work has not consumed its original identity.
    _ = try kv.apply(next, &.{.{ .put = .{ .key = "key", .value = .null } }}, access.guard());
    // Both maximum lengths together remain within the shared value budget.
    _ = try kv.apply(binding(&kv, 6), &.{.{ .put = .{ .key = large_key[0..K.max_key_bytes], .value = bytes(large[0..K.max_value_bytes]) } }}, access.guard());
}

test "direct KV declaration preserves kind in physical interpretation mappings" {
    var declared = try s.KVDeclaration.prepare(t.allocator, definition);
    defer declared.deinit();
    const stored = try declared.stored();
    const encoded = try s.TableInterpretations.encode(stored);
    try t.expectEqualDeep(stored, try s.TableInterpretations.decode(encoded));
    try t.expectEqualDeep(definition, try s.KVDeclaration.fromPhysical(declared.definition));
    var malformed = declared.definition;
    malformed.kind = .table;
    try t.expectError(error.DataKindMismatch, s.KVDeclaration.fromPhysical(malformed));
    malformed.kind = .kv;
    malformed.schema.primary_key = &.{2};
    malformed.schema.columns = &.{
        .{ .id = 1, .name = "key", .type = .binary, .nullable = false },
        .{ .id = 2, .name = "value", .type = .binary, .nullable = false },
    };
    try t.expectError(error.InvalidKVDeclaration, s.KVDeclaration.fromPhysical(malformed));
    // Persisted descriptors must carry their kind explicitly. No current-kind
    // default is manufactured while reading an older saved root/declaration.
    const encoded_json = try p.Json.valueAlloc(t.allocator, stored);
    defer t.allocator.free(encoded_json);
    var json = try std.json.parseFromSlice(std.json.Value, t.allocator, encoded_json, .{});
    defer json.deinit();
    _ = json.value.object.swapRemove("kind");
    const missing = try std.json.Stringify.valueAlloc(t.allocator, json.value, .{});
    defer t.allocator.free(missing);
    try t.expectError(error.MissingField, p.Json.parseFromSlice(s.TableDeclaration.Stored, t.allocator, missing));
}

test "direct KV rename and retirement preserve original batch and retained read identities" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var kv = try open(&wal, &objects);
    defer kv.deinit();
    var access: Access = .{};
    _ = try kv.create(binding(&kv, 1), access.guard());
    const original = binding(&kv, 2);
    const changes = [_]K.Change{.{ .put = .{ .key = "original", .value = bytes("payload") } }};
    const outcome = try kv.apply(original, &changes, access.guard());
    const pin = try kv.pin(.{ .scope = object.scope, .principal = 4, .operation = 1001 }, outcome.position, access.guard());
    var rename = binding(&kv, 3);
    rename.action = .rename;
    _ = try kv.storage.changeDefinition(rename, .{ .rename = "renamed-policy" }, access.guard());
    try t.expectEqual(s.TableDeclaration.Kind.kv, kv.storage.root.kind);
    var drop = binding(&kv, 4);
    drop.action = .drop;
    _ = try kv.storage.changeDefinition(drop, .{ .drop = "retired-policy" }, access.guard());
    try kv.recover();
    try t.expectEqual(s.TableDeclaration.Kind.kv, kv.storage.root.kind);
    try t.expectEqualDeep(outcome, try kv.apply(original, &changes, access.guard()));
    try t.expectError(error.TableRetired, kv.get(t.allocator, "original", access.guard()));
    var retained = (try kv.readSnapshot(t.allocator, pin, "original", access.guard())).?;
    defer retained.deinit();
    try t.expectEqualStrings("payload", retained.cell().value.atom.bytes);
}
