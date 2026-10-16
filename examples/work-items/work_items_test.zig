const std = @import("std");
const W = @import("WorkItems.zig");
const s = W.app.station;
const p = W.app.protocol;
const t = std.testing;
const Page = p.Growth.Batch(p.Growth.Entry, p.Value);
const Store = struct {
    entries: std.AutoHashMap(p.Value, p.Value) = .init(t.allocator),
    changed_at: std.AutoHashMap(p.Value, u64) = .init(t.allocator),
    authority: W.query.catalog.testing.Authority = .{},
    position: u64 = 0,
    pages: usize = 0,
    fail_read: bool = false,
    missing_table_binding: bool = false,
    fn deinit(self: *@This()) void {
        self.authority.deinit();
        self.entries.deinit();
        self.changed_at.deinit();
    }
    fn read(raw: *anyopaque, _: p.Growth.View, key: p.Value) anyerror!?p.Value {
        const self: *@This() = @ptrCast(@alignCast(raw));
        if (self.fail_read) return error.MigrationDenied;
        return self.entries.get(key);
    }
    fn page(raw: *anyopaque, _: p.Growth.View, after: ?p.Value) anyerror!Page {
        const self: *@This() = @ptrCast(@alignCast(raw));
        self.pages += 1;
        var keys: std.array_list.Managed(p.Value) = .init(t.allocator);
        defer keys.deinit();
        var iterator = self.entries.keyIterator();
        while (iterator.next()) |key| if (after == null or std.mem.order(u8, key.slice(), after.?.slice()) == .gt) {
            try keys.append(key.*);
        };
        std.mem.sort(p.Value, keys.items, {}, struct {
            fn less(_: void, a: p.Value, b: p.Value) bool {
                return std.mem.order(u8, a.slice(), b.slice()) == .lt;
            }
        }.less);
        var result: Page = .{};
        for (keys.items[0..@min(keys.items.len, p.Growth.page_size)], 0..) |key, i| result.entries[i] = .{ .key = key, .value = self.entries.get(key).?, .revision = self.changed_at.get(key) orelse self.position };
        if (keys.items.len > p.Growth.page_size) result.next = keys.items[p.Growth.page_size - 1];
        return result;
    }
    fn authorize(raw: *anyopaque, guard: p.Authorization.Guard) !?p.Authorization.Verified {
        const self: *@This() = @ptrCast(@alignCast(raw));
        return W.query.catalog.testing.Authority.authorize(&self.authority, guard);
    }
    fn binding(raw: *anyopaque, domain: u64, identity: [32]u8) !?p.Authorization.Object {
        const self: *@This() = @ptrCast(@alignCast(raw));
        if (self.missing_table_binding and domain == W.query.catalog.testing.Authority.profile.table_domain) return null;
        return W.query.catalog.testing.Authority.binding(&self.authority, domain, identity);
    }
    fn turn(self: *@This(), principal: u64) !s.Turn {
        self.position += 1;
        if (!self.authority.rights.contains(33)) try self.authority.setRights(.{ .principal = 33 });
        return s.Turn.init(.{ .realm = 49, .principal = 77, .pid = 2, .generation = 3, .sequence = 5, .revision = 0, .input = .{ .position = self.position, .ordinal = 1, .value = try p.Value.init("work"), .origin = .{ .external = .{ .principal = principal, .policy_revision = 1 } } }, .permit = null, .needs_permit = false }, .{ .id = self.position, .pid = 2, .principal = 77, .generation = 3, .input = self.position, .process_revision = 0, .resource = 7, .revision = self.position, .deadline_ms = 100000 }, .{ .context = self, .read = read, .page = page, .authorization = authorize, .authorization_binding = binding });
    }
    fn commit(self: *@This(), turn_value: *s.Turn) !void {
        try turn_value.validate();
        for (turn_value.decision.mutations) |slot| if (slot) |mutation| {
            if (mutation.value) |value| {
                try self.entries.put(mutation.key, value);
                try self.changed_at.put(mutation.key, self.position);
            } else {
                _ = self.entries.remove(mutation.key);
                _ = self.changed_at.remove(mutation.key);
            }
        };
    }
    fn execute(self: *@This(), principal: u64, command: W.Command) !usize {
        var turn_value = try self.turn(principal);
        try owner().execute(&turn_value, command);
        try self.commit(&turn_value);
        var maximum = mutations(turn_value);
        var queue: std.array_list.Managed(p.Value) = .init(t.allocator);
        defer queue.deinit();
        for (turn_value.decision.outputs) |slot| if (slot) |output| {
            try t.expectEqual(2, output.pid);
            try queue.append(output.value);
        };
        var offset: usize = 0;
        while (offset < queue.items.len) : (offset += 1) {
            if (offset > 10000) return error.UnfinishedWorkItems;
            var next = try self.turn(principal);
            next.delivery.input.origin = .{ .process = .{ .pid = 2, .turn = next.delivery.input.position - 1, .output = 0 } };
            next.delivery.input.value = queue.items[offset];
            var behavior: W.Behavior = .{ .owner = owner() };
            const handler = behavior.interface();
            try handler.handle(handler.context, &next, try s.Frame.decode(next.delivery.input.value));
            maximum = @max(maximum, mutations(next));
            try self.commit(&next);
            for (next.decision.outputs) |slot| if (slot) |output| {
                try t.expectEqual(2, output.pid);
                try queue.append(output.value);
            };
        }
        return maximum;
    }
};
fn mutations(turn: s.Turn) usize {
    var count: usize = 0;
    for (turn.decision.mutations) |slot| if (slot != null) {
        count += 1;
    };
    return count;
}
fn owner() W {
    return .{ .allocator = t.allocator, .configuration = .{ .owner = 2, .application = 9, .realm = 49, .administrator = 33, .writer = 55, .resource = 7 } };
}
test "independent WI1 commands retain full-width keys plans ordinals and cursors" {
    const Fixture = struct { version: u8, put: p.Value, cursor: p.Value, step: p.Value };
    const fixture = try p.Json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/commands-v1.json"));
    defer fixture.deinit();
    const value = fixture.value;
    try t.expectEqual(1, value.version);
    const put: W.Command = .{ .put = .{ .epoch = .{ .value = std.math.maxInt(u64) }, .id = std.math.minInt(i64), .state = 20 } };
    try t.expect(value.put.eql(try put.encode()));
    try t.expectEqualDeep(put, try W.Command.decode(value.put));
    const cursor: W.Cursor = .{ .phase = .verify, .has_after = true, .after = .{ .origin = 44, .operation = std.math.maxInt(u64), .ordinal = 2 }, .copied = 33, .verified = 2 };
    try t.expect(value.cursor.eql(try cursor.encode()));
    const step: W.Command = .{ .step = .{ .plan = .{ .value = std.math.maxInt(u32) }, .ordinal = .{ .value = std.math.maxInt(u64) }, .operation = 1, .arguments = value.cursor } };
    try t.expect(value.step.eql(try step.encode()));
    try t.expectEqualDeep(step, try W.Command.decode(value.step));
    var trailing = value.step;
    trailing.data[trailing.len] = 0;
    trailing.len += 1;
    try t.expectError(error.InvalidWorkItemCommand, W.Command.decode(trailing));
}
fn setup(store: *Store, rows: usize) !void {
    try store.authority.setRights(.{ .principal = 44, .create = false, .update = false, .delete = false, .alter = false, .drop = false });
    try store.authority.setRights(.{ .principal = 55, .create = false, .delete = false, .alter = false, .drop = false });
    try t.expectEqual(2, try store.execute(33, .initialize));
    _ = try store.execute(33, .{ .catalog_initialize = W.query.catalog.testing.Authority.profile });
    for ([_]u32{ 1, 2, 3 }) |table| _ = try store.execute(33, .{ .prepare_table = table });
    _ = try store.execute(33, .{ .policy = .{ .principal = 44, .expected = .{}, .next = .{ .revision = .{ .value = 1 }, .migrate = true } } });
    for (0..rows) |i| _ = try store.execute(55, .{ .put = .{ .epoch = .{ .value = 1 }, .id = @as(i64, @intCast(i)) - 20, .state = @intCast(i % 2) } });
}
fn finish(store: *Store, id: u32) !usize {
    var steps: usize = 0;
    while (true) {
        var read = try store.turn(44);
        const ledger = try owner().ledger();
        const progress = try ledger.progress(&read, .{ .value = id });
        const cursor = try W.Cursor.decode(progress.cursor);
        const step: W.app.Migration.Step = .{ .plan = .{ .value = id }, .ordinal = progress.next, .operation = if (cursor.phase == .ready) 2 else 1, .arguments = progress.cursor };
        const command: W.Command = .{ .step = step };
        try t.expectEqualDeep(command, try W.Command.decode(try command.encode()));
        const writes = try store.execute(44, command);
        try t.expect(writes <= 4);
        try t.expectEqual(0, try store.execute(44, command));
        steps += 1;
        if (cursor.phase == .ready) {
            try t.expectEqual(4, writes);
            break;
        }
        try t.expect(steps <= 100);
    }
    return steps;
}
test "real Table migration bounds batches, retains receipts and fences old writers" {
    var store: Store = .{};
    defer store.deinit();
    try setup(&store, 33);
    try t.expectEqual(3, try store.execute(44, .{ .begin = try owner().proposal(2) }));
    try t.expectError(error.WorkItemMigrationPaused, store.execute(55, .{ .put = .{ .epoch = .{ .value = 1 }, .id = 88, .state = 0 } }));
    try t.expectEqual(69, try finish(&store, 2));
    var turn = try store.turn(44);
    try t.expectEqual(2, try owner().selected(&turn));
    const head = try (try owner().ledger()).head(&turn);
    try t.expectEqual(2, head.epoch.value);
    try t.expectEqualSlices(u8, &try owner().contract(2), &head.contract);
    for (0..33) |i| {
        const id = @as(i64, @intCast(i)) - 20;
        try t.expectEqual(@as(i64, @intCast(i % 2)), (try W.Table.get(t.allocator, &turn, 1, id)).?.state);
        try t.expectEqual(@as(i64, if (i % 2 == 0) 10 else 20), (try W.Table.get(t.allocator, &turn, 2, id)).?.state);
    }
    try t.expectError(error.WorkItemEpochChanged, store.execute(55, .{ .put = .{ .epoch = .{ .value = 1 }, .id = 88, .state = 0 } }));
    try t.expectError(error.WorkItemPublicationPaused, store.execute(55, .{ .put = .{ .epoch = .{ .value = 2 }, .id = std.math.maxInt(i64), .state = 20 } }));
    const release_writes: W.Command = .{ .release_writes = .{ .epoch = .{ .value = 2 }, .contract = head.contract } };
    try t.expectError(error.WorkItemDenied, store.execute(44, release_writes));
    try t.expectEqual(1, try store.execute(33, release_writes));
    try t.expectEqual(0, try store.execute(33, release_writes));
    _ = try store.execute(55, .{ .put = .{ .epoch = .{ .value = 2 }, .id = std.math.maxInt(i64), .state = 20 } });
    try t.expectError(error.MigrationAlreadyApplied, store.execute(44, .{ .abandon = .{ .value = 2 } }));
    try t.expectEqual(0, try store.execute(44, .{ .begin = try owner().proposal(2) }));
}
test "empty migration and abandoned targets retain identities and verification is mandatory" {
    var store: Store = .{};
    defer store.deinit();
    try setup(&store, 0);
    _ = try store.execute(44, .{ .begin = try owner().proposal(2) });
    try t.expectError(error.WorkItemVerificationIncomplete, store.execute(44, .{ .step = .{ .plan = .{ .value = 2 }, .ordinal = .{ .value = 1 }, .operation = 2 } }));
    _ = try store.execute(44, .{ .abandon = .{ .value = 2 } });
    _ = try store.execute(55, .{ .put = .{ .epoch = .{ .value = 1 }, .id = std.math.minInt(i64), .state = 1 } });
    _ = try store.execute(44, .{ .begin = try owner().proposal(3) });
    try t.expectEqual(5, try finish(&store, 3));
    var read = try store.turn(44);
    try t.expect(try read.read(s.TableHead.key(2)) != null);
    var empty: Store = .{};
    defer empty.deinit();
    try setup(&empty, 0);
    _ = try empty.execute(44, .{ .begin = try owner().proposal(2) });
    try t.expectEqual(3, try finish(&empty, 2));
}
test "target corruption and current migration denial cannot activate or partly commit" {
    var store: Store = .{};
    defer store.deinit();
    try setup(&store, 1);
    _ = try store.execute(44, .{ .begin = try owner().proposal(2) });
    _ = try store.execute(44, .{ .step = .{ .plan = .{ .value = 2 }, .ordinal = .{ .value = 1 }, .operation = 1 } });
    var copied = try store.turn(44);
    const copy_progress = try (try owner().ledger()).progress(&copied, .{ .value = 2 });
    _ = try store.execute(44, .{ .step = .{ .plan = .{ .value = 2 }, .ordinal = copy_progress.next, .operation = 1, .arguments = copy_progress.cursor } });
    try corruptRow(&store, 2, -20);
    const ledger = try owner().ledger();
    var read = try store.turn(44);
    const progress = try ledger.progress(&read, .{ .value = 2 });
    const step: W.Command = .{ .step = .{ .plan = .{ .value = 2 }, .ordinal = progress.next, .operation = 1, .arguments = progress.cursor } };
    try t.expectError(error.WorkItemVerificationFailed, store.execute(44, step));
    _ = try store.execute(33, .{ .policy = .{ .principal = 44, .expected = .{ .value = 1 }, .next = .{ .revision = .{ .value = 2 }, .migrate = false } } });
    try t.expectError(error.MigrationDenied, store.execute(44, step));
    var final = try store.turn(44);
    try t.expectEqual(1, (try ledger.head(&final)).epoch.value);
    try t.expectEqualDeep(progress, try ledger.progress(&final, .{ .value = 2 }));
}

fn handleCommand(store: *Store, principal: u64, command: W.Command) !u64 {
    var turn = try store.turn(principal);
    const frame: s.Frame = .{ .kind = .cast, .payload = try command.encode() };
    turn.delivery.input.value = try frame.encode();
    var behavior: W.Behavior = .{ .owner = owner() };
    const handler = behavior.interface();
    try handler.handle(handler.context, &turn, frame);
    try store.commit(&turn);
    return turn.delivery.input.position;
}
fn failureAt(store: *Store, principal: u64, input: u64) !W.Failure.Disposition {
    const Reader = struct {
        store: *Store,
        pub fn read(self: *@This(), key: p.Value) !?p.Value {
            return self.store.entries.get(key);
        }
    };
    var reader: Reader = .{ .store = store };
    return (try W.Failure.read(owner().configuration, &reader, principal, input)) orelse error.MissingFailure;
}
test "work-item handler retains original cursor policy ordinal and state witnesses" {
    var store: Store = .{};
    defer store.deinit();
    try setup(&store, 3);
    const invalid_state = try handleCommand(&store, 55, .{ .put = .{ .epoch = .{ .value = 1 }, .id = 19, .state = 99 } });
    const bad_state = try failureAt(&store, 55, invalid_state);
    try t.expectEqual(@as(i64, 99), bad_state.witness.state.value);
    try t.expectEqual(@as(i64, 19), bad_state.witness.state.key);
    _ = try handleCommand(&store, 44, .{ .begin = try owner().proposal(2) });
    const future = try handleCommand(&store, 44, .{ .step = .{ .plan = .{ .value = 2 }, .ordinal = .{ .value = 3 }, .operation = 1 } });
    const future_failure = try failureAt(&store, 44, future);
    try t.expectEqual(@as(u64, 1), future_failure.witness.ledger.progress.next.value);
    try t.expectEqual(@as(u64, 3), future_failure.witness.ledger.progress.supplied.value);
    const mismatch = try handleCommand(&store, 44, .{ .step = .{ .plan = .{ .value = 2 }, .ordinal = .{ .value = 1 }, .operation = 1, .arguments = try p.Value.init("wrong cursor") } });
    const original_cursor = try failureAt(&store, 44, mismatch);
    try t.expectEqualStrings("work_items.cursor_changed", original_cursor.diagnostic.code.slice());
    try t.expectEqual(@as(u16, 0), original_cursor.witness.cursor.expected_bytes);
    try t.expectEqual(@as(u16, 12), original_cursor.witness.cursor.actual_bytes);
    const activation = try handleCommand(&store, 44, .{ .step = .{ .plan = .{ .value = 2 }, .ordinal = .{ .value = 1 }, .operation = 2 } });
    const premature = try failureAt(&store, 44, activation);
    try t.expectEqual(@as(u16, 2), premature.record.operation);
    try t.expectEqual(.copy, premature.witness.verification.phase);
    _ = try store.execute(33, .{ .policy = .{ .principal = 44, .expected = .{ .value = 1 }, .next = .{ .revision = .{ .value = 2 }, .migrate = false } } });
    const denial = try handleCommand(&store, 44, .{ .step = .{ .plan = .{ .value = 2 }, .ordinal = .{ .value = 1 }, .operation = 1 } });
    const denied = try failureAt(&store, 44, denial);
    try t.expectEqual(@as(u64, 2), denied.witness.ledger.policy.actual.value);
    try t.expect(!denied.witness.ledger.policy.migrate);
    _ = try store.execute(33, .{ .policy = .{ .principal = 44, .expected = .{ .value = 2 }, .next = .{ .revision = .{ .value = 3 }, .migrate = true } } });
    _ = try finish(&store, 2);
    try t.expectEqualDeep(denied, try failureAt(&store, 44, denial));
    try t.expectEqualDeep(original_cursor, try failureAt(&store, 44, mismatch));
    try t.expectEqualDeep(future_failure, try failureAt(&store, 44, future));
    for ([_]W.Failure.Disposition{ denied, original_cursor, future_failure, premature, bad_state }) |failure| {
        try t.expectEqual(p.Diagnostic.Outcome.input_rejected, failure.diagnostic.outcome);
        for (failure.diagnostic.actions) |slot| if (slot) |action| try t.expect(action.kind == .inspect_status or action.kind == .inspect_scope);
    }
    _ = store.entries.remove(W.witnessKey(9, 44, denial));
    try t.expectError(error.InvalidMigrationFailure, failureAt(&store, 44, denial));
    try store.entries.put(W.dispositionKey(9, 44, denial), try p.Value.init("MigrationDenied"));
    try t.expectError(error.InvalidApplicationRecord, failureAt(&store, 44, denial));
}

test "invalid stored values and failed reads never become caller rejections" {
    var store: Store = .{};
    defer store.deinit();
    try setup(&store, 2);
    try corruptRow(&store, 1, -20);
    _ = try store.execute(44, .{ .begin = try owner().proposal(2) });
    const command: W.Command = .{ .step = .{ .plan = .{ .value = 2 }, .ordinal = .{ .value = 1 }, .operation = 1 } };
    try t.expectError(error.WorkItemSourceInvalid, store.execute(44, command));
    try t.expect(!store.entries.contains(W.dispositionKey(9, 44, store.position)));
    var read = try store.turn(44);
    try t.expect((try W.Table.get(t.allocator, &read, 2, -20)) == null);
    try t.expectEqual(@as(u64, 1), (try (try owner().ledger()).progress(&read, .{ .value = 2 })).next.value);
    store.fail_read = true;
    try t.expectError(error.MigrationDenied, handleCommand(&store, 44, command));
    try t.expect(!store.entries.contains(W.dispositionKey(9, 44, store.position)));
}

fn corruptRow(store: *Store, object: u32, key: i64) !void {
    var read = try store.turn(44);
    var row = (try W.Table.get(t.allocator, &read, object, key)).?;
    row.state = 99;
    const operation = read.delivery.input.position;
    for (0..1000) |_| {
        var turn = try store.turn(44);
        const result = try W.Table.write(t.allocator, &turn, object, 44, operation, row, false, @splat(0), 0);
        try store.commit(&turn);
        if (result.state == .applied) return;
    }
    return error.UnfinishedCorruption;
}

test "accepted puts block migration until exact Table completion" {
    var store: Store = .{};
    defer store.deinit();
    try setup(&store, 0);
    const command: W.Command = .{ .put = .{ .epoch = .{ .value = 1 }, .id = -9, .state = 1 } };
    var admission = try store.turn(55);
    const input = admission.delivery.input.position;
    try owner().execute(&admission, command);
    try store.commit(&admission);
    var read = try store.turn(44);
    try t.expect(!try owner().completed(&read, command, input));
    try t.expectEqual(@as(?W.Table.Row, null), try W.Table.get(t.allocator, &read, 1, -9));
    var blocked = try store.turn(44);
    try t.expectError(error.WorkItemWritesPending, owner().execute(&blocked, .{ .begin = try owner().proposal(2) }));
    try t.expectEqual(0, mutations(blocked));
    // A later accepted put's wake also drains the older durable work first.
    _ = try store.execute(55, .{ .put = .{ .epoch = .{ .value = 1 }, .id = 12, .state = 0 } });
    read = try store.turn(44);
    try t.expect(try owner().completed(&read, command, input));
    try t.expectEqual(1, (try W.Table.get(t.allocator, &read, 1, -9)).?.state);
    try t.expectEqual(0, (try W.Table.get(t.allocator, &read, 1, 12)).?.state);
    _ = try store.execute(44, .{ .begin = try owner().proposal(2) });
}

test "catalog bootstrap requires its administrator and native grants govern reads" {
    var store: Store = .{};
    defer store.deinit();
    try setup(&store, 0);
    for ([_]W.Command{ .{ .catalog_initialize = W.query.catalog.testing.Authority.profile }, .{ .prepare_table = 4 } }) |command| {
        var turn = try store.turn(44);
        try t.expectError(error.WorkItemDenied, owner().execute(&turn, command));
        try t.expectEqual(0, mutations(turn));
    }
    try store.authority.setRights(.{ .principal = 55, .create = false, .insert = false, .update = false, .delete = false, .alter = false, .drop = false });
    var read = try store.turn(55);
    _ = try (try owner().catalog(&read)).authorizeObject(&read, 55, 1, .read);
    try t.expectError(error.CatalogDenied, (try owner().catalog(&read)).authorize(&read, 55, .create));
    var declaration = try owner().source(&read, 55, 1);
    defer declaration.deinit();
    try t.expectEqual(1, declaration.definition.source.table.object);
    try store.authority.setRights(.{ .principal = 55, .inspect = false, .read = false });
    read = try store.turn(55);
    try t.expectError(error.CatalogDenied, owner().source(&read, 55, 1));
}

test "queued work-item writes retain original authority across revocation" {
    var store: Store = .{};
    defer store.deinit();
    try setup(&store, 0);
    var admitted = try store.turn(55);
    try owner().execute(&admitted, .{ .put = .{ .epoch = .{ .value = 1 }, .id = 9, .state = 0 } });
    try store.commit(&admitted);
    const message = admitted.decision.outputs[0].?.value;
    try store.authority.setRights(.{ .principal = 55, .insert = false, .update = false });
    var denied = try store.turn(55);
    denied.delivery.input.origin = .{ .process = .{ .pid = 2, .turn = admitted.delivery.input.position, .output = 0 } };
    denied.delivery.input.value = message;
    var behavior: W.Behavior = .{ .owner = owner() };
    const handler = behavior.interface();
    try t.expectError(error.CatalogDenied, handler.handle(handler.context, &denied, try s.Frame.decode(message)));
    try t.expectEqual(0, mutations(denied));
    try t.expect(try W.putPending(&denied, admitted.delivery.input.position));
    try store.authority.setRights(.{ .principal = 55 });
    var restored = try store.turn(55);
    restored.delivery.input.origin = denied.delivery.input.origin;
    restored.delivery.input.value = message;
    try handler.handle(handler.context, &restored, try s.Frame.decode(message));
    const original = restored.decision.authorization.?.subject.accepted;
    try t.expectEqual(admitted.delivery.input.position, original.input);
    try t.expectEqual(55, original.principal);
    try t.expectEqual(2, original.pid);
    try store.commit(&restored);
    var current = try store.turn(55);
    try t.expect(try W.putPending(&current, admitted.delivery.input.position));
}

test "pending native Table registration cannot commit a failed application input" {
    var store: Store = .{};
    defer store.deinit();
    _ = try store.execute(33, .initialize);
    _ = try store.execute(33, .{ .catalog_initialize = W.query.catalog.testing.Authority.profile });
    store.missing_table_binding = true;
    var turn = try store.turn(33);
    const frame: s.Frame = .{ .kind = .cast, .payload = try W.Command.encode(.{ .prepare_table = 1 }) };
    turn.delivery.input.value = try frame.encode();
    var behavior: W.Behavior = .{ .owner = owner() };
    const handler = behavior.interface();
    try t.expectError(error.CatalogRegistrationRequired, handler.handle(handler.context, &turn, frame));
    try t.expectEqual(error.CatalogRegistrationRequired, turn.read_error.?);
    try t.expect(behavior.registration.? == .register_object);
    try t.expectEqual(0, mutations(turn));
    try t.expect(!turn.decision.failed);
}
