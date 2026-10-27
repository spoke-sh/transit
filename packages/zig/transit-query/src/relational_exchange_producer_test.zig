const std = @import("std");
const t = std.testing;
const q = @import("root.zig");
const f = q.fuze;
const r = q.RelationalExchangeRecords;
const codec = f.RelationalExchange;
const Producer = q.RelationalExchangeProducer;
const columns = [_]f.TableSchema.Column{ .{ .id = 1, .name = "k", .type = .int64 }, .{ .id = 2, .name = "v", .type = .int64 } };
const declarations = [_]f.Relational.Source{
    .{ .alias = "l", .realm = 1, .resource = 101, .catalog = 9, .owner = 7, .schema = .{ .object = 11, .revision = 1, .next_column = 3, .columns = &columns } },
    .{ .alias = "r", .realm = 1, .resource = 202, .catalog = 9, .owner = 8, .schema = .{ .object = 22, .revision = 1, .next_column = 3, .columns = &columns } },
};
const plan: f.Relational.Plan = .{ .sources = &declarations, .join = .{ .kind = .left, .left = .{ .source = 0, .id = 1 }, .right = .{ .source = 1, .id = 1 } }, .outputs = &.{.{ .name = "v", .expression = .{ .column = .{ .source = 1, .id = 2 } } }}, .lifetime = .captured, .budgets = .{ .resident_bytes = 16 * 1024 * 1024, .spill_bytes = 1024 * 1024, .result_bytes = 1024 * 1024, .output_rows = 10000, .work_steps = 1000000, .source_pins = 2 } };
fn cuts() ![2]f.Relational.Cut {
    var result: [2]f.Relational.Cut = undefined;
    for (declarations, 0..) |source, i| result[i] = .{ .domain = .native_resource, .resource = source.resource, .revision = 1, .commitment = @splat(1), .schema = try source.schema.fingerprint() };
    return result;
}
const Input = struct {
    reads: usize = 0,
    denied: bool = false,
    pub fn validate(self: *Input, bound: f.Relational.Bound) !void {
        try bound.validate();
        if (self.denied) return error.CatalogDenied;
    }
    fn row(source: u8, operation: u64) f.RelationalExecution.Row {
        var value: f.RelationalExecution.Row = .{ .identity = .{ .origin = @as(u64, source) + 1, .operation = operation, .ordinal = 0 } };
        value.values[0] = if (operation % 5 == 0) null else .{ .integer = @intCast(operation % 3) };
        value.values[1] = .{ .integer = @intCast(operation * 7) };
        return value;
    }
    pub fn next(self: *Input, source: u8, after: ?f.Relational.RowIdentity) !?f.RelationalExecution.Row {
        self.reads += 1;
        const operation = if (after) |identity| identity.operation + 1 else 1;
        return if (operation <= 41) row(source, operation) else null;
    }
};
test "producer cursor matches independent mandatory-definition bytes" {
    var schema_columns = columns;
    schema_columns[0].name = "key";
    schema_columns[1].name = "value";
    var declared = declarations;
    for (&declared) |*item| {
        item.owner = 7;
        item.schema.columns = &schema_columns;
    }
    var requested = plan;
    requested.sources = &declared;
    requested.group_by = &.{.{ .source = 0, .id = 1 }};
    requested.outputs = &.{
        .{ .name = "key", .expression = .{ .column = .{ .source = 0, .id = 1 } } },
        .{ .name = "rows", .expression = .count_all },
        .{ .name = "values", .expression = .{ .count = .{ .source = 1, .id = 2 } } },
        .{ .name = "total", .expression = .{ .sum = .{ .source = 1, .id = 2 } } },
    };
    requested.budgets = .{ .resident_bytes = 4096, .spill_bytes = 8192, .result_bytes = 16384, .output_rows = 1000, .work_steps = 10000, .source_pins = 2 };
    const basis = [_]f.Relational.Cut{
        .{ .domain = .native_resource, .resource = 101, .revision = 7, .commitment = @splat(17), .schema = try declared[0].schema.fingerprint() },
        .{ .domain = .native_resource, .resource = 202, .revision = 12, .commitment = @splat(34), .schema = try declared[1].schema.fingerprint() },
    };
    const bound: f.Relational.Bound = .{ .plan = requested, .cuts = &basis };
    const fixture = try std.json.parseFromSlice(struct { cursor: []const u8 }, t.allocator, @embedFile("fixtures/relational-exchange.json"), .{ .ignore_unknown_fields = true });
    defer fixture.deinit();
    var bytes: [256]u8 = undefined;
    const encoded = try std.fmt.hexToBytes(&bytes, fixture.value.cursor);
    const saved = try Producer.Cursor.decode(try q.protocol.Value.init(encoded), bound);
    try t.expectEqual(@as(u64, 99), saved.id);
    try t.expectEqual(@as(u64, 3), saved.after.?.operation);
    try t.expectEqualSlices(u8, encoded, (try saved.encode(bound)).slice());
}
test "durable producer cursor resumes bounded scans and pending segments across manual worker layouts" {
    const basis = try cuts();
    const bound: f.Relational.Bound = .{ .plan = plan, .cuts = &basis };
    for ([_]u64{ 1, 3 }) |workers| for ([_]u8{ 1, 4 }) |batch| {
        var seen: [2][41]bool = @splat(@splat(false));
        var complete: [2][7]bool = @splat(@splat(false));
        var sequence: [2][7]u64 = @splat(@splat(0));
        for (0..workers) |worker| {
            var store: q.testing.Store = .{ .pid = 20 + worker, .resource = 50 + worker };
            defer store.deinit();
            var source: Input = .{};
            var turn = try store.capture();
            try Producer.create(&turn, bound, &source, 99, .{ .receiver = .{ .owner = 77, .resource = 700 }, .partitions = 7, .workers = workers, .worker = worker, .batch = batch, .epoch = 3, .quota = plan.budgets.spill_bytes });
            try store.commit(turn);
            var finished = false;
            for (0..10000) |step| {
                turn = try store.capture();
                const original = try Producer.cursor(&turn, bound, 99);
                const reads = source.reads;
                const result = try Producer.step(t.allocator, &turn, bound, &source, 99);
                try t.expect(source.reads - reads <= Producer.scan_rows);
                if (step % 7 == 0) {
                    var retry = try store.capture();
                    try t.expectEqual(result, try Producer.step(t.allocator, &retry, bound, &source, 99));
                    try t.expectEqualDeep(turn.decision, retry.decision);
                }
                var notice: ?r.Pending = null;
                for (turn.decision.outputs) |slot| if (slot) |output| {
                    try t.expectEqual(@as(u64, 77), output.pid);
                    notice = try r.Pending.decode((try q.station.Frame.decode(output.value)).payload);
                };
                try store.commit(turn);
                turn = try store.capture();
                const current = try Producer.cursor(&turn, bound, 99);
                if (notice) |record| {
                    try t.expectEqual(.accepted, result);
                    var bytes: [codec.fixed_bytes]u8 = undefined;
                    var segment = try codec.Segment.decode(t.allocator, bound, try q.RelationalMaintenance.readBody(record.remote, &turn, &bytes));
                    defer segment.deinit();
                    try t.expectEqual(@as(u64, 3), segment.epoch);
                    try t.expectEqual(worker, (segment.partition * 2 + segment.source) % workers);
                    try t.expectEqual(sequence[segment.source][segment.partition], segment.sequence);
                    sequence[segment.source][segment.partition] += 1;
                    for (segment.rows[0..segment.len]) |row| {
                        try t.expectEqualDeep(Input.row(segment.source, row.identity.operation), row);
                        const selected = &seen[segment.source][row.identity.operation - 1];
                        try t.expect(!selected.*);
                        selected.* = true;
                    }
                    if (segment.terminal) {
                        try t.expect(!complete[segment.source][segment.partition]);
                        complete[segment.source][segment.partition] = true;
                    }
                    try t.expectEqual(original.record + 1, current.record);
                    // Current Table denial blocks resending data evidence but
                    // does not prevent receiving a valid own-resource ack.
                    source.denied = true;
                    try t.expectError(error.CatalogDenied, Producer.retry(&turn, bound, &source, 99, record));
                    turn.delivery.input.origin = .{ .process = .{ .pid = 77, .turn = 1, .output = 0 } };
                    turn.delivery.input.value = try (q.station.Frame{ .kind = .cast, .payload = try record.encode() }).encode();
                    try Producer.acknowledge(&turn, bound, 99, record);
                    try store.commit(turn);
                    turn = try store.capture();
                    _ = try record.remote.publication().retire(&turn, record.remote.record);
                    try store.commit(turn);
                    source.denied = false;
                    turn = try store.capture();
                    try Producer.retry(&turn, bound, &source, 99, record);
                    for (turn.decision.mutations) |mutation| try t.expect(mutation == null);
                    // Do not deliver this synthetic retry; the receiver's
                    // separate duplicate tests cover its durable acceptance.
                } else if (result != .complete) {
                    // A no-output scan may advance only when it did not start
                    // staging a segment; an offered sequence stays unchanged.
                    try t.expectEqual(original.record, current.record);
                    try t.expectEqual(original.sequence, current.sequence);
                }
                if (result == .complete) {
                    try t.expectEqual(@as(u64, 14), current.channel);
                    var encoded = try current.encode(bound);
                    for (0..encoded.len) |length| {
                        if (Producer.Cursor.decode(try q.protocol.Value.init(encoded.slice()[0..length]), bound)) |_| return error.AcceptedPartialCursor else |_| {}
                    }
                    encoded.data[4] ^= 1;
                    try t.expectError(error.IncompatibleDefinition, Producer.Cursor.decode(encoded, bound));
                    finished = true;
                    break;
                }
            }
            try t.expect(finished);
        }
        for (seen) |side| for (side) |present| try t.expect(present);
        for (complete) |side| for (side) |present| try t.expect(present);
    };
}
