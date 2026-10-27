//! Native-session realization of the semantic reader. Cursor bookkeeping and
//! recovery stay here; consumers receive only logical rows and terminal evidence.
const std = @import("std");
const sdk = @import("root.zig");
const api = sdk.protocol;
const r = sdk.results;
const Self = @This();
const Transport = struct {
    context: *anyopaque,
    fetch: *const fn (*anyopaque, std.mem.Allocator, api.Id, u64) anyerror!std.json.Parsed(api.Response),
    close: *const fn (*anyopaque, api.Id) void,
};
parent: std.mem.Allocator,
memory: r.fuze.MemoryBudget,
header: std.heap.ArenaAllocator,
batch: std.heap.ArenaAllocator,
transport: Transport,
failure_value: ?r.Failure = null,
cursor: api.Id,
ordinal: u64 = 0,
schema: r.Types.Type,
schema_bytes: []const u8,
observation: r.Observation.Value,
observation_hash: [32]u8,
chunk: r.ResultSet.Chunk = .{ .rows = &.{}, .completion = null },
closed: bool = false,

/// The first response is borrowed only for this call. The returned reader owns
/// schema/observation and one decoded batch under its independent resident cap.
pub fn open(allocator: std.mem.Allocator, executor: *sdk.Executor, first: api.Batch, resident_bytes: usize) !r.ResultSet {
    return openTransport(allocator, .{ .context = executor, .fetch = nativeFetch, .close = nativeClose }, first, resident_bytes);
}
fn openTransport(allocator: std.mem.Allocator, transport: Transport, first: api.Batch, resident_bytes: usize) !r.ResultSet {
    if (resident_bytes == 0 or resident_bytes > 16 * 1024 * 1024 or first.batch != 0) return error.InvalidResultBudget;
    const self = try allocator.create(Self);
    self.* = .{ .parent = allocator, .memory = .{ .parent = allocator, .limit = resident_bytes }, .header = undefined, .batch = undefined, .transport = transport, .cursor = first.cursor, .schema = undefined, .schema_bytes = undefined, .observation = undefined, .observation_hash = undefined };
    self.header = .init(self.memory.allocator());
    self.batch = .init(self.memory.allocator());
    errdefer self.destroy();
    const a = self.header.allocator();
    self.schema_bytes = try a.dupe(u8, first.schema);
    self.schema = try api.Codec.decodeSchema(a, first.schema);
    // Round-trip through the shared canonical value owner to copy all nested
    // observation slices. This is bounded metadata, never a retained source pin.
    const encoded = try api.Json.valueAlloc(a, first.observation);
    const copied = try api.Json.parseFromSliceOwned(r.Observation.Value, a, encoded);
    self.observation = copied.value;
    self.observation_hash = try r.Observation.fingerprint(a, self.observation);
    try self.decode(first);
    var result = try r.ResultSet.init(self.schema, self.observation, .{ .result = first.cursor, .schema = try self.schema.fingerprint(), .observation = self.observation_hash }, .{ .context = self, .next = next, .close = close, .deinit = deinit, .failure = failure });
    try result.receive(self.chunk);
    return result;
}

fn decode(self: *Self, value: api.Batch) !void {
    if (!std.mem.eql(u8, &value.cursor, &self.cursor) or value.batch != self.ordinal or
        !std.mem.eql(u8, value.schema, self.schema_bytes)) return error.ResultIdentityChanged;
    if (value.rows.len > api.max_rows or (value.complete != (value.completion != null)) or
        (value.rows.len == 0 and !value.complete)) return error.InvalidResultChunk;
    const a = self.batch.allocator();
    const observation_hash = try r.Observation.fingerprint(a, value.observation);
    if (!std.mem.eql(u8, &observation_hash, &self.observation_hash)) return error.ResultIdentityChanged;
    const rows = try a.alloc(r.Row, value.rows.len);
    var bytes: usize = 0;
    for (value.rows, rows) |encoded, *row| {
        if (encoded.len != self.schema.structure.len) return error.InvalidResultRow;
        const cells = try a.alloc(r.Types.Values.Cell, encoded.len);
        for (encoded, self.schema.structure, cells) |text, field, *cell| {
            bytes = try std.math.add(usize, bytes, text.len / 2);
            if (bytes > api.max_batch_bytes) return error.SqlBatchTooLarge;
            cell.* = try api.Codec.decodeCell(a, field, text);
        }
        row.* = cells;
    }
    self.chunk = .{ .rows = rows, .completion = value.completion };
}

fn next(context: *anyopaque) !r.ResultSet.Chunk {
    const self: *Self = @ptrCast(@alignCast(context));
    if (self.closed) return error.ResultClosed;
    if (self.chunk.completion != null) return error.InvalidResultTransition;
    _ = self.batch.reset(.free_all);
    self.ordinal = try std.math.add(u64, self.ordinal, 1);
    const response = try self.transport.fetch(self.transport.context, self.memory.allocator(), self.cursor, self.ordinal);
    defer response.deinit();
    switch (response.value.result) {
        .batch => |value| {
            try self.decode(value);
            return self.chunk;
        },
        .err => |value| {
            const a = self.header.allocator();
            self.failure_value = .{ .code = try a.dupe(u8, value.code), .sqlstate = value.sqlstate, .message = try a.dupe(u8, value.message), .diagnostic = value.diagnostic };
            if (self.failure_value.?.denied()) return error.SqlObservationDenied;
            if (std.mem.eql(u8, &value.sqlstate, "57014")) return error.ResultCancelled;
            return error.SqlResultIncomplete;
        },
        else => return error.InvalidSqlResponse,
    }
}
fn nativeFetch(context: *anyopaque, allocator: std.mem.Allocator, cursor: api.Id, ordinal: u64) !std.json.Parsed(api.Response) {
    const executor: *sdk.Executor = @ptrCast(@alignCast(context));
    executor.enter(.fetch);
    const client = executor.client;
    const started = std.Io.Clock.awake.now(client.io);
    const timeout = client.timeout_ms;
    defer client.timeout_ms = timeout;
    // A retry repeats this exact ordinal in the original session. No new SELECT,
    // cursor, snapshot or session is created, and the deadline never restarts.
    var attempts: usize = 0;
    while (attempts < 3) : (attempts += 1) {
        const elapsed = started.durationTo(std.Io.Clock.awake.now(client.io)).toMilliseconds();
        if (elapsed >= timeout) return error.SqlRequestTimeout;
        client.timeout_ms = timeout - @as(u32, @intCast(@max(0, elapsed)));
        const response = executor.call(.{ .fetch = .{ .cursor = cursor, .batch = ordinal } }, allocator) catch |err| switch (err) {
            error.SqlRequestTimeout, error.EndOfStream, error.ReadFailed, error.WriteFailed, error.ConnectionResetByPeer, error.ConnectionTimedOut, error.ConnectionRefused, error.ConnectionAborted, error.BrokenPipe, error.HttpConnectionClosing, error.HttpRequestTruncated, error.HttpChunkTruncated => {
                if (attempts == 2) return err;
                continue;
            },
            else => return err,
        };
        if (response.value.result == .err) {
            const value = response.value.result.err;
            executor.access_lost = executor.access_lost or std.mem.eql(u8, &value.sqlstate, "42501") or std.mem.eql(u8, &value.sqlstate, "28000");
            executor.session_lost = executor.session_lost or std.mem.eql(u8, value.code, "SqlSessionExpired");
            if (value.retry == .same_batch and attempts != 2) {
                response.deinit();
                continue;
            }
        }
        return response;
    }
    unreachable;
}
fn nativeClose(context: *anyopaque, cursor: api.Id) void {
    const executor: *sdk.Executor = @ptrCast(@alignCast(context));
    executor.release(.{ .close_result = cursor });
}
fn failure(context: *anyopaque) ?r.Failure {
    const self: *Self = @ptrCast(@alignCast(context));
    return self.failure_value;
}

fn close(context: *anyopaque) !void {
    const self: *Self = @ptrCast(@alignCast(context));
    if (self.closed) return;
    self.closed = true;
    _ = self.batch.reset(.free_all);
    self.chunk = .{ .rows = &.{}, .completion = null };
    // Failure to observe remote cleanup cannot erase verified completion or
    // imply rollback. The service retains its bounded lease/recovery obligation.
    self.transport.close(self.transport.context, self.cursor);
}
fn destroy(self: *Self) void {
    self.batch.deinit();
    self.header.deinit();
    std.debug.assert(self.memory.used == 0);
    self.parent.destroy(self);
}
fn deinit(context: *anyopaque) void {
    const self: *Self = @ptrCast(@alignCast(context));
    self.destroy();
}

const t = std.testing;
const TestScript = struct {
    length: usize = 7,
    maximum: usize = 2,
    position: usize = 0,
    requests: usize = 0,
    closed: usize = 0,
    empty_terminal: bool = false,
    fault: enum { none, identity, ordinal, schema, observation, count, incomplete, disconnect, duplicate } = .none,
    fn frame(self: *TestScript, allocator: std.mem.Allocator, ordinal: u64) !api.Batch {
        const fields = [_]r.Types.Field{.{ .name = "n", .type = .uint128 }};
        const count = @min(self.maximum, self.length - self.position);
        const rows = try allocator.alloc([]const []const u8, count);
        for (rows, 0..) |*row, i| {
            var bytes: [17]u8 = undefined;
            bytes[0] = 3;
            // Encode the independent scalar fixture directly, without the
            // production cell encoder; SQL duplicate values remain distinct.
            const value = if (self.fault == .duplicate and ordinal != 0) 0 else (self.position + i) % 3;
            std.mem.writeInt(u128, bytes[1..], value, .little);
            const hex = std.fmt.bytesToHex(bytes, .lower);
            row.* = try allocator.dupe([]const u8, &.{try allocator.dupe(u8, &hex)});
        }
        self.position += count;
        const complete = self.position == self.length and (!self.empty_terminal or count == 0);
        var result: api.Batch = .{ .cursor = @splat(6), .batch = ordinal, .schema = try api.Codec.schema(allocator, &fields), .rows = rows, .complete = complete, .completion = if (complete) .{ .rows = self.length } else null, .observation = .{ .metadata = .{ .kind = .probe, .consistency = .session, .namespace = null, .definitions = &.{}, .configuration_revision = null, .session_settings = null } } };
        if (ordinal != 0) switch (self.fault) {
            .identity => result.cursor[0] ^= 1,
            .ordinal => result.batch += 1,
            .schema => result.schema = try api.Codec.schema(allocator, &.{.{ .name = "other", .type = .uint128 }}),
            .observation => result.observation.metadata.namespace = 7,
            .count => if (result.completion) |*completion| {
                completion.rows += 1;
            },
            .incomplete => {
                result.rows = &.{};
                result.complete = false;
                result.completion = null;
            },
            else => {},
        };
        return result;
    }
    fn fetch(context: *anyopaque, allocator: std.mem.Allocator, cursor: api.Id, ordinal: u64) !std.json.Parsed(api.Response) {
        const self: *TestScript = @ptrCast(@alignCast(context));
        try t.expectEqual(@as(api.Id, @splat(6)), cursor);
        self.requests += 1;
        try t.expectEqual(self.requests, ordinal);
        if (self.fault == .disconnect) return error.ReadFailed;
        var arena: std.heap.ArenaAllocator = .init(allocator);
        defer arena.deinit();
        const value: api.Response = .{ .version = 1, .definition = api.native.current_definition, .instance = @splat(2), .result = .{ .batch = try self.frame(arena.allocator(), ordinal) } };
        const encoded = try api.Json.valueAlloc(arena.allocator(), value);
        return api.parse(api.Response, allocator, encoded);
    }
    fn close(context: *anyopaque, _: api.Id) void {
        const self: *TestScript = @ptrCast(@alignCast(context));
        self.closed += 1;
    }
    fn open(self: *TestScript, allocator: std.mem.Allocator) !r.ResultSet {
        var arena: std.heap.ArenaAllocator = .init(allocator);
        defer arena.deinit();
        const first = try self.frame(arena.allocator(), 0);
        return openTransport(allocator, .{ .context = self, .fetch = TestScript.fetch, .close = TestScript.close }, first, 1024 * 1024);
    }
};

test "public semantic consumer is independent of native frame size and terminal shape" {
    const consumer = @import("consumer_test.zig");
    for (0..9) |length| for (1..9) |maximum| for ([_]bool{ false, true }) |empty_terminal| {
        var script: TestScript = .{ .length = length, .maximum = maximum, .empty_terminal = empty_terminal };
        var result = try script.open(t.allocator);
        defer result.deinit();
        const observed = try consumer.consume(&result);
        try consumer.requireRelation(observed, length);
        try t.expectEqual(1, script.closed);
        try t.expectEqual(length, result.progress.received);
        try t.expectEqual(length, result.progress.delivered);
    };
}
test "native projection rejects substituted evidence and missing or false terminals" {
    const cases = .{
        .{ TestScript{ .fault = .identity }, error.ResultIdentityChanged },
        .{ TestScript{ .fault = .ordinal }, error.ResultIdentityChanged },
        .{ TestScript{ .fault = .schema }, error.ResultIdentityChanged },
        .{ TestScript{ .fault = .observation }, error.ResultIdentityChanged },
        .{ TestScript{ .fault = .count }, error.InvalidResultCount },
        .{ TestScript{ .fault = .incomplete }, error.InvalidResultChunk },
        .{ TestScript{ .fault = .disconnect }, error.ReadFailed },
    };
    inline for (cases) |case| {
        var script = case[0];
        var result = try script.open(t.allocator);
        defer result.deinit();
        try t.expectError(case[1], @import("consumer_test.zig").consume(&result));
        try t.expect(result.completion() == null);
        try t.expectEqual(.failed, result.progress.outcome);
        try t.expectEqual(1, script.closed);
    }
}
test "oracle negative control catches an adapter emitting duplicate occurrences" {
    var script: TestScript = .{ .fault = .duplicate };
    var result = try script.open(t.allocator);
    defer result.deinit();
    const consumer = @import("consumer_test.zig");
    const observed = try consumer.consume(&result);
    try t.expectError(error.OracleMismatch, consumer.requireRelation(observed, script.length));
}
test "received completion survives early closure without claiming full delivery" {
    var script: TestScript = .{ .length = 3, .maximum = 8 };
    var result = try script.open(t.allocator);
    defer result.deinit();
    try t.expectEqual(3, result.completion().?.rows);
    try t.expectEqual(0, result.progress.delivered);
    try result.close();
    try t.expectEqual(.stopped, result.progress.consumption);
    try t.expectEqual(3, result.completion().?.rows);
    try t.expectEqual(1, script.closed);
}
fn allocationSchedule(allocator: std.mem.Allocator) !void {
    var script: TestScript = .{};
    var result = try script.open(allocator);
    defer result.deinit();
    _ = try @import("consumer_test.zig").consume(&result);
}
test "all reader allocation failures release schema rows and transport ownership" {
    try t.checkAllAllocationFailures(t.allocator, allocationSchedule, .{});
}
