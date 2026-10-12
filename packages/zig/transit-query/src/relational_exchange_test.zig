const std = @import("std");
const t = std.testing;
const q = @import("root.zig");
const f = q.fuze;
const r = q.RelationalExchangeRecords;
const x = q.RelationalExchange;
const codec = f.RelationalExchange;
const s = q.station;
const Store = q.testing.Store;
const columns = [_]f.TableSchema.Column{ .{ .id = 1, .name = "k", .type = .int64, .nullable = true }, .{ .id = 2, .name = "v", .type = .int64, .nullable = true } };
const declarations = [_]f.Relational.Source{
    .{ .alias = "l", .realm = 1, .resource = 7, .catalog = 9, .owner = 3, .schema = .{ .object = 11, .revision = 1, .next_column = 3, .columns = &columns } },
    .{ .alias = "r", .realm = 1, .resource = 9, .catalog = 9, .owner = 4, .schema = .{ .object = 22, .revision = 1, .next_column = 3, .columns = &columns } },
};
const plan: f.Relational.Plan = .{ .sources = &declarations, .join = .{ .kind = .left, .left = .{ .source = 0, .id = 1 }, .right = .{ .source = 1, .id = 1 } }, .outputs = &.{.{ .name = "v", .expression = .{ .column = .{ .source = 1, .id = 2 } } }}, .lifetime = .captured, .budgets = .{ .resident_bytes = 16 * 1024 * 1024, .spill_bytes = 32 * 1024 * 1024, .result_bytes = 1024 * 1024, .output_rows = 10000, .work_steps = 1000000, .source_pins = 2 } };
test "exchange control codecs match independent fixed layouts and reject missing foreign definitions" {
    const WireFixture = struct { head: []const u8, channel: []const u8, pending: []const u8, accepted: []const u8, row: []const u8, producer: []const u8, key: []const u8, row_key: []const u8 };
    const fixture = try std.json.parseFromSlice(WireFixture, t.allocator, @embedFile("fixtures/relational-exchange.json"), .{ .ignore_unknown_fields = true });
    defer fixture.deinit();
    inline for (.{ "head", "channel", "pending", "accepted", "row", "producer" }, .{ r.Head, r.Channel, r.Pending, r.Accepted, r.Row, r.Producer }) |name, T| {
        var bytes: [256]u8 = undefined;
        const encoded = try std.fmt.hexToBytes(&bytes, @field(fixture.value, name));
        const result = try T.decode(try q.protocol.Value.init(encoded));
        try t.expectEqualSlices(u8, encoded, (try result.encode()).slice());
        for (0..encoded.len) |length| {
            if (T.decode(try q.protocol.Value.init(encoded[0..length]))) |_| return error.AcceptedTruncatedExchange else |_| {}
        }
        bytes[encoded.len] = 0;
        try t.expectError(error.InvalidRelationalExchange, T.decode(try q.protocol.Value.init(bytes[0 .. encoded.len + 1])));
        bytes[4] ^= 1;
        try t.expectError(error.IncompatibleDefinition, T.decode(try q.protocol.Value.init(encoded)));
    }
    var bytes: [256]u8 = undefined;
    const pending = try r.Pending.decode(try q.protocol.Value.init(try std.fmt.hexToBytes(&bytes, fixture.value.pending)));
    try t.expectEqualSlices(u8, try std.fmt.hexToBytes(&bytes, fixture.value.key), (try r.key('a', 88, 0, pending.partition, 0)).slice());
    try t.expectEqualSlices(u8, try std.fmt.hexToBytes(&bytes, fixture.value.row_key), (try r.rowKey(88, 1, .{ .origin = 1, .operation = 2, .ordinal = 0 })).slice());
}
fn cuts() ![2]f.Relational.Cut {
    var result: [2]f.Relational.Cut = undefined;
    for (declarations, 0..) |source, i| result[i] = .{ .resource = source.resource, .revision = 1, .commitment = @splat(1), .schema = try source.schema.fingerprint() };
    return result;
}
const Authority = struct {
    denied: bool = false,
    checks: usize = 0,
    pub fn validate(self: *Authority, bound: f.Relational.Bound) !void {
        try bound.validate();
        self.checks += 1;
        if (self.denied) return error.CatalogDenied;
    }
};
const Fixture = struct {
    receiver: Store = .{},
    producer: Store = .{ .resource = 8, .pid = 4 },
    authority: Authority = .{},
    denied_producer: bool = false,
    fn deinit(self: *Fixture) void {
        self.receiver.deinit();
        self.producer.deinit();
    }
    fn reader(self: *Fixture, resource: u64) !s.Turn.Reader {
        if (resource == self.receiver.resource) return (try self.receiver.capture()).reader;
        if (resource == self.producer.resource) {
            if (self.denied_producer) return error.AccessDenied;
            return (try self.producer.capture()).reader;
        }
        return error.InvalidStateView;
    }
    fn read(raw: *anyopaque, view: q.protocol.Growth.View, key: q.protocol.Value) !?q.protocol.Value {
        const self: *Fixture = @ptrCast(@alignCast(raw));
        const source = try self.reader(view.resource);
        return source.read(source.context, view, key);
    }
    fn page(raw: *anyopaque, view: q.protocol.Growth.View, after: ?q.protocol.Value) !s.Turn.Page {
        const self: *Fixture = @ptrCast(@alignCast(raw));
        const source = try self.reader(view.resource);
        return source.page.?(source.context, view, after);
    }
    fn capture(self: *Fixture) !s.Turn {
        var result = try self.receiver.capture();
        result.reader = .{ .context = self, .read = read, .page = page };
        return result;
    }
    fn advanceTurn(self: *Fixture) !s.Turn {
        var result = try self.capture();
        var view = result.view;
        view.id += 5000;
        view.resource = self.producer.resource;
        view.revision = self.producer.revision;
        try result.addView(view);
        return result;
    }
    fn noticeTurn(self: *Fixture, notice: r.Pending) !s.Turn {
        var result = try self.capture();
        result.delivery.input.origin = .{ .process = .{ .pid = self.producer.pid, .turn = 1, .output = 0 } };
        result.delivery.input.value = try (s.Frame{ .kind = .cast, .payload = try notice.encode() }).encode();
        return result;
    }
    fn setup(self: *Fixture, bound: f.Relational.Bound, id: u64, partitions: u64, credits: u64, quota: u64) !void {
        var turn = try self.capture();
        _ = try x.create(&turn, bound, &self.authority, id, partitions, .{ .retained_bytes = quota, .credit_bytes = 2 * codec.max_bytes, .credit_segments = credits });
        try self.receiver.commit(turn);
        for (0..partitions * bound.plan.sources.len) |_| {
            turn = try self.capture();
            try x.register(&turn, bound, &self.authority, id, self.producer.pid, self.producer.resource);
            try self.receiver.commit(turn);
        }
        turn = try self.producer.capture();
        _ = try x.createProducer(&turn, bound, &self.authority, id, plan.budgets.spill_bytes);
        try self.producer.commit(turn);
    }
    fn offer(self: *Fixture, bound: f.Relational.Bound, segment: codec.Segment, record: u64) !r.Pending {
        const pubn: s.Publication = .{ .resource = self.producer.resource, .domain = .query_exchange, .namespace = segment.exchange };
        for (0..100) |_| {
            var turn = try self.producer.capture();
            const result = try x.offer(&turn, bound, &self.authority, segment, pubn, record, self.receiver.pid);
            var notice: ?r.Pending = null;
            if (result == .accepted) {
                for (turn.decision.outputs) |slot| if (slot) |output| {
                    notice = try r.Pending.decode((try s.Frame.decode(output.value)).payload);
                };
            }
            try self.producer.commit(turn);
            if (notice) |value| return value;
        }
        return error.ProducerDidNotProgress;
    }
    fn accept(self: *Fixture, bound: f.Relational.Bound, id: u64, notice: r.Pending) !void {
        var turn = try self.noticeTurn(notice);
        try t.expectEqual(.progress, try x.receive(&turn, bound, &self.authority, id, notice));
        try self.receiver.commit(turn);
        for (0..100) |_| {
            turn = try self.advanceTurn();
            const result = try x.advance(&turn, bound, &self.authority, id);
            // An interrupted uncommitted step reconstructs identical bytes.
            var retry = try self.advanceTurn();
            try t.expectEqual(result, try x.advance(&retry, bound, &self.authority, id));
            try t.expectEqualDeep(turn.decision, retry.decision);
            try self.receiver.commit(turn);
            if (result == .accepted) return;
        }
        return error.ReceiverDidNotProgress;
    }
    fn consume(self: *Fixture, bound: f.Relational.Bound, id: u64, source: u8, partition: u64) !void {
        for (0..codec.max_rows + 1) |_| {
            var turn = try self.capture();
            const result = try x.consume(&turn, bound, &self.authority, id, source, partition);
            try self.receiver.commit(turn);
            if (result == .blocked or result == .complete) return;
        }
        return error.ConsumerDidNotProgress;
    }
};
const NoGroups = struct {
    pub fn get(_: *NoGroups, _: f.RelationalExecution.Key) !?f.RelationalExecution.Group {
        return error.UnexpectedGroupAccess;
    }
    pub fn put(_: *NoGroups, _: f.RelationalExecution.Group) !void {
        return error.UnexpectedGroupAccess;
    }
    pub fn next(_: *NoGroups, _: ?f.RelationalExecution.Key) !?f.RelationalExecution.Group {
        return error.UnexpectedGroupAccess;
    }
};
fn row(source: u8, index: u64) f.RelationalExecution.Row {
    var result: f.RelationalExecution.Row = .{ .identity = .{ .origin = 10 + @as(u64, source), .operation = 20 + index, .ordinal = 0 } };
    result.values[0] = if (index % 5 == 0) null else @intCast(index % 3);
    result.values[1] = @intCast(index * 7);
    return result;
}
test "durable exchange separates acceptance consumption credits and all-partition coverage" {
    const basis = try cuts();
    const bound: f.Relational.Bound = .{ .plan = plan, .cuts = &basis };
    for ([_]u64{ 1, 7, 31 }) |partitions| for ([_]u8{ 1, 2, 4 }) |batch| {
        var fixture: Fixture = .{};
        defer fixture.deinit();
        try fixture.setup(bound, 88, partitions, 2, plan.budgets.spill_bytes);
        var record: u64 = 1;
        // Physical scheduling reverses partitions and source order. Logical
        // result iteration below must still recover the original source order.
        for (0..partitions) |step| for ([_]u8{ 1, 0 }) |source| {
            const partition = partitions - step - 1;
            var segment: codec.Segment = .{ .exchange = 88, .source = source, .partitions = partitions, .partition = partition, .epoch = 3, .sequence = 0, .terminal = false };
            for (0..19) |index| {
                const value = row(source, index);
                if (try codec.route(plan, source, partitions, value) != partition) continue;
                segment.rows[segment.len] = value;
                segment.len += 1;
                if (segment.len == batch) {
                    const notice = try fixture.offer(bound, segment, record);
                    record += 1;
                    try fixture.accept(bound, 88, notice);
                    var turn = try fixture.capture();
                    const admitted = try x.head(&turn, 88);
                    try t.expectEqual(@as(u64, 1), admitted.inflight_segments);
                    var input: x.Sources(*s.Turn, *Authority) = .{ .reader = &turn, .authority = &fixture.authority, .bound = bound, .id = 88 };
                    try t.expectError(error.RelationalExchangePending, input.next(0, null));
                    // Lost acceptance ack repeats the exact identity without
                    // consuming rows or returning another unit of credit.
                    turn = try fixture.noticeTurn(notice);
                    try t.expectEqual(.duplicate, try x.receive(&turn, bound, &fixture.authority, 88, notice));
                    try fixture.receiver.commit(turn);
                    // Receiver ownership of accepted bytes outlives producer
                    // retirement and denial of that producer's live resource.
                    turn = try fixture.producer.capture();
                    _ = try notice.remote.publication().retire(&turn, notice.remote.record);
                    try fixture.producer.commit(turn);
                    fixture.denied_producer = true;
                    try fixture.consume(bound, 88, source, partition);
                    turn = try fixture.noticeTurn(notice);
                    try t.expectEqual(.duplicate, try x.receive(&turn, bound, &fixture.authority, 88, notice));
                    try fixture.receiver.commit(turn);
                    fixture.denied_producer = false;
                    segment.sequence += 1;
                    segment.len = 0;
                }
            }
            segment.terminal = true;
            const notice = try fixture.offer(bound, segment, record);
            record += 1;
            try fixture.accept(bound, 88, notice);
            try fixture.consume(bound, 88, source, partition);
        };
        var turn = try fixture.capture();
        const complete = try x.head(&turn, 88);
        try t.expectEqual(partitions * 2, complete.completed);
        try t.expectEqual(@as(u64, 0), complete.inflight_segments);
        var input: x.Sources(*s.Turn, *Authority) = .{ .reader = &turn, .authority = &fixture.authority, .bound = bound, .id = 88 };
        for (0..2) |source| {
            var after: ?f.Relational.RowIdentity = null;
            for (0..19) |index| {
                const value = (try input.next(@intCast(source), after)).?;
                try t.expectEqualDeep(row(@intCast(source), index), value);
                after = value.identity;
            }
            try t.expect(try input.next(@intCast(source), after) == null);
        }
        // Real production execution over the recovered row index; expected
        // pairs are enumerated directly from the independent fixture formula.
        var groups: NoGroups = .{};
        var engine = try f.RelationalExecution.Execution(@TypeOf(&input), *NoGroups).init(bound, &input, &groups);
        var left: u64 = 0;
        var right: u64 = 0;
        var matched = false;
        var emitted: usize = 0;
        while (true) {
            const event = try engine.step();
            if (event == .progress) continue;
            if (event == .complete) break;
            const output = event.row;
            var expected_right: ?u64 = null;
            search: while (left < 19) {
                const key = row(0, left).values[0];
                while (right < 19) {
                    const candidate = right;
                    right += 1;
                    if (key != null and row(1, candidate).values[0] != null and key.? == row(1, candidate).values[0].?) {
                        expected_right = candidate;
                        matched = true;
                        break :search;
                    }
                }
                if (!matched) break;
                left += 1;
                right = 0;
                matched = false;
            }
            try t.expect(left < 19);
            try t.expectEqualDeep(row(0, left).identity, output.identity.pair.left);
            if (expected_right) |index| {
                try t.expectEqualDeep(row(1, index).identity, output.identity.pair.right.?);
                try t.expectEqual(@as(i128, @intCast(index * 7)), output.cells[0].value.atom.signed);
            } else {
                try t.expect(output.identity.pair.right == null and output.cells[0] == .null);
                left += 1;
                right = 0;
                matched = false;
            }
            emitted += 1;
        }
        var expected_count: usize = 0;
        for (0..19) |i| {
            var matches: usize = 0;
            for (0..19) |j| if (row(0, i).values[0] != null and row(1, j).values[0] != null and row(0, i).values[0].? == row(1, j).values[0].?) {
                matches += 1;
            };
            expected_count += @max(1, matches);
        }
        try t.expectEqual(expected_count, emitted);
        fixture.authority.denied = true;
        try t.expectError(error.CatalogDenied, input.next(0, null));
        turn = try fixture.capture();
        try x.close(&turn, 88);
        try fixture.receiver.commit(turn);
        fixture.authority.denied = false;
        turn = try fixture.capture();
        input.reader = &turn;
        try t.expectError(error.RelationalExchangeClosed, input.next(0, null));
    };
}
test "reordered traffic and exhausted credits leave accepted work and control capacity intact" {
    const basis = try cuts();
    const bound: f.Relational.Bound = .{ .plan = plan, .cuts = &basis };
    var fixture: Fixture = .{};
    defer fixture.deinit();
    try fixture.setup(bound, 89, 1, 1, plan.budgets.spill_bytes);
    var first: codec.Segment = .{ .exchange = 89, .source = 0, .partitions = 1, .partition = 0, .epoch = 1, .sequence = 0, .terminal = false, .len = 1 };
    first.rows[0] = row(0, 0);
    var second = first;
    second.sequence = 1;
    second.terminal = true;
    second.rows[0] = row(0, 1);
    const notice0 = try fixture.offer(bound, first, 1);
    const notice1 = try fixture.offer(bound, second, 2);
    var turn = try fixture.noticeTurn(notice1);
    try t.expectEqual(.blocked, try x.receive(&turn, bound, &fixture.authority, 89, notice1));
    for (turn.decision.mutations) |mutation| try t.expect(mutation == null);
    try fixture.accept(bound, 89, notice0);
    turn = try fixture.noticeTurn(notice1);
    try t.expectEqual(.blocked, try x.receive(&turn, bound, &fixture.authority, 89, notice1));
    try fixture.consume(bound, 89, 0, 0);
    try fixture.accept(bound, 89, notice1);
    try fixture.consume(bound, 89, 0, 0);
    // An accepted identity cannot be silently rebound to another publication.
    var changed = notice0;
    changed.remote.record = 999;
    turn = try fixture.noticeTurn(changed);
    try t.expectError(error.RelationalExchangeConflict, x.receive(&turn, bound, &fixture.authority, 89, changed));
    for (turn.decision.mutations) |mutation| try t.expect(mutation == null);
    // Quota is cumulative and includes already consumed bytes/index records.
    turn = try fixture.capture();
    var stored = try x.head(&turn, 89);
    stored.limits.retained_bytes = @max(codec.max_bytes, stored.retained_bytes);
    try turn.write(try stored.address(), try stored.encode());
    try fixture.receiver.commit(turn);
    var right = first;
    right.source = 1;
    var exhausted = false;
    for (0..10) |index| {
        right.sequence = index;
        right.rows[0] = row(1, index);
        const next = try fixture.offer(bound, right, 3 + index);
        turn = try fixture.noticeTurn(next);
        _ = x.receive(&turn, bound, &fixture.authority, 89, next) catch |err| {
            try t.expectEqual(error.RelationalSpillBudget, err);
            for (turn.decision.mutations) |mutation| try t.expect(mutation == null);
            exhausted = true;
            break;
        };
        // The probe above was not committed; repeat the same reservation.
        try fixture.accept(bound, 89, next);
        try fixture.consume(bound, 89, 1, 0);
    }
    try t.expect(exhausted);
    fixture.authority.denied = true;
    turn = try fixture.capture();
    try x.close(&turn, 89);
    try fixture.receiver.commit(turn);
}
test "producer reserves cumulative quota before staging and cannot reinterpret pending bytes" {
    const basis = try cuts();
    const bound: f.Relational.Bound = .{ .plan = plan, .cuts = &basis };
    var fixture: Fixture = .{};
    defer fixture.deinit();
    try fixture.setup(bound, 90, 1, 1, plan.budgets.spill_bytes);
    var turn = try fixture.producer.capture();
    const budget_key = try r.key('b', 90, 0, 0, 0);
    var budget = try r.Producer.decode((try turn.read(budget_key)).?);
    budget.limit = codec.max_bytes;
    try turn.write(budget_key, try budget.encode());
    try fixture.producer.commit(turn);
    const publication: s.Publication = .{ .resource = fixture.producer.resource, .domain = .query_exchange, .namespace = 90 };
    var segment: codec.Segment = .{ .exchange = 90, .source = 0, .partitions = 1, .partition = 0, .epoch = 1, .sequence = 0, .terminal = false, .len = 1 };
    segment.rows[0] = row(0, 0);
    turn = try fixture.producer.capture();
    try t.expectEqual(.progress, try x.offer(&turn, bound, &fixture.authority, segment, publication, 1, fixture.receiver.pid));
    try fixture.producer.commit(turn);
    turn = try fixture.producer.capture();
    const reserved = try r.Producer.decode((try turn.read(budget_key)).?);
    try t.expect(reserved.pending != null and reserved.charged > budget.charged);
    var changed = segment;
    changed.rows[0].values[1] = 999;
    try t.expectError(error.RelationalExchangeConflict, x.offer(&turn, bound, &fixture.authority, changed, publication, 1, fixture.receiver.pid));
    for (turn.decision.mutations) |mutation| try t.expect(mutation == null);
    fixture.authority.denied = true;
    try t.expectError(error.CatalogDenied, x.offer(&turn, bound, &fixture.authority, segment, publication, 1, fixture.receiver.pid));
    fixture.authority.denied = false;
    _ = try fixture.offer(bound, segment, 1);
    var exhausted = false;
    for (1..30) |index| {
        segment.sequence = index;
        segment.rows[0] = row(0, index);
        turn = try fixture.producer.capture();
        _ = x.offer(&turn, bound, &fixture.authority, segment, publication, index + 1, fixture.receiver.pid) catch |err| {
            try t.expectEqual(error.RelationalSpillBudget, err);
            for (turn.decision.mutations) |mutation| try t.expect(mutation == null);
            exhausted = true;
            break;
        };
        _ = try fixture.offer(bound, segment, index + 1);
    }
    try t.expect(exhausted);
    turn = try fixture.producer.capture();
    const final = try r.Producer.decode((try turn.read(budget_key)).?);
    try t.expect(final.pending == null and final.charged <= final.limit and final.last > 1);
    // Every recorded source output remains eligible; quota did not erase it.
    for (0..final.last) |sequence| try t.expect(try turn.read(try r.key('p', 90, 0, 0, sequence)) != null);
}
