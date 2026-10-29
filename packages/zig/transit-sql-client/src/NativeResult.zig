//! Native-session realization of the semantic reader. Cursor bookkeeping and
//! recovery stay here; consumers receive only logical rows and terminal evidence.
const std = @import("std");
const sdk = @import("root.zig");
const api = sdk.protocol;
const r = sdk.results;
const Self = @This();
const Transport = struct {
    context: *anyopaque,
    fetch: *const fn (*anyopaque, std.mem.Allocator, api.Id, u64) anyerror!sdk.Response,
    close: *const fn (*anyopaque, api.Id) void,
};
parent: std.mem.Allocator,
memory: r.fuze.MemoryBudget,
header: std.heap.ArenaAllocator,
batch: std.heap.ArenaAllocator,
response: ?sdk.Response = null,
transport: Transport,
failure_value: ?r.Failure = null,
cursor: api.Id,
ordinal: u64 = 0,
schema: r.Types.Type,
schema_hash: [32]u8,
observation: r.Observation.Value,
observation_hash: [32]u8,
chunk: r.ResultSet.Chunk = .{ .values = .{}, .completion = null },
closed: bool = false,

/// Takes ownership of the first response on success. Column payloads borrow
/// its aligned body until the next pull or close; metadata has separate owners.
pub fn open(allocator: std.mem.Allocator, executor: *sdk.Executor, first: sdk.Response, resident_bytes: usize) !r.ResultSet {
    return openTransport(allocator, .{ .context = executor, .fetch = nativeFetch, .close = nativeClose }, first, resident_bytes);
}
fn openTransport(allocator: std.mem.Allocator, transport: Transport, first: sdk.Response, resident_bytes: usize) !r.ResultSet {
    if (resident_bytes == 0 or resident_bytes > 16 * 1024 * 1024) return error.InvalidResultBudget;
    if (first.value.result != .batch) return error.InvalidSqlResponse;
    const frame = first.value.result.batch;
    if (frame.ordinal != 0 or frame.description == null) return error.InvalidResultChunk;
    const self = try allocator.create(Self);
    self.* = .{ .parent = allocator, .memory = .{ .parent = allocator, .limit = resident_bytes }, .header = undefined, .batch = undefined, .transport = transport, .cursor = frame.cursor, .schema = undefined, .schema_hash = undefined, .observation = undefined, .observation_hash = undefined };
    self.header = .init(self.memory.allocator());
    self.batch = .init(self.memory.allocator());
    errdefer self.destroy();
    const a = self.header.allocator();
    self.schema = try r.Types.decodeInto(a, frame.description.?.schema);
    if (self.schema != .structure) return error.InvalidResultSchema;
    self.schema_hash = try self.schema.fingerprint();
    // Round-trip through the shared canonical value owner to copy all nested
    // observation slices. This is bounded metadata, never a retained source pin.
    const encoded = try api.Json.valueAlloc(a, frame.description.?.observation);
    const copied = try api.Json.parseFromSliceOwned(r.Observation.Value, a, encoded);
    self.observation = copied.value;
    self.observation_hash = try r.Observation.fingerprint(a, self.observation);
    try self.decode(frame);
    var result = try r.ResultSet.init(self.schema, self.observation, .{ .result = frame.cursor, .schema = self.schema_hash, .observation = self.observation_hash }, .{ .context = self, .next = next, .close = close, .deinit = deinit, .failure = failure, .validate_disclosure = validateDisclosure });
    try result.receive(self.chunk);
    self.response = first;
    return result;
}

fn decode(self: *Self, value: api.Batch) !void {
    if (!std.mem.eql(u8, &value.cursor, &self.cursor) or value.ordinal != self.ordinal or
        !std.mem.eql(u8, &value.schema, &self.schema_hash) or
        !std.mem.eql(u8, &value.observation, &self.observation_hash)) return error.ResultIdentityChanged;
    if (value.rows > api.max_rows or (value.rows == 0 and value.completion == null) or
        ((self.ordinal == 0) != (value.description != null))) return error.InvalidResultChunk;
    const a = self.batch.allocator();
    self.chunk = .{ .values = try api.ResultColumns.decode(self.memory.allocator(), a, self.schema.structure, value.columns, value.rows), .completion = value.completion };
}

fn next(context: *anyopaque) !r.ResultSet.Chunk {
    const self: *Self = @ptrCast(@alignCast(context));
    if (self.closed) return error.ResultClosed;
    if (self.chunk.completion != null) return error.InvalidResultTransition;
    _ = self.batch.reset(.free_all);
    self.releaseResponse();
    self.ordinal = try std.math.add(u64, self.ordinal, 1);
    const response = try self.transport.fetch(self.transport.context, self.memory.allocator(), self.cursor, self.ordinal);
    errdefer response.deinit();
    switch (response.value.result) {
        .batch => |value| {
            try self.decode(value);
            self.response = response;
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
fn nativeFetch(context: *anyopaque, allocator: std.mem.Allocator, cursor: api.Id, ordinal: u64) !sdk.Response {
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

fn validateDisclosure(context: *anyopaque) !void {
    const self: *Self = @ptrCast(@alignCast(context));
    if (self.closed) return error.ResultClosed;
    const response = try self.transport.fetch(self.transport.context, self.memory.allocator(), self.cursor, self.ordinal);
    defer response.deinit();
    if (response.value.result == .err) {
        const value = response.value.result.err;
        return if (std.mem.eql(u8, &value.sqlstate, "42501") or std.mem.eql(u8, &value.sqlstate, "28000")) error.SqlObservationDenied else error.SqlResultUnavailable;
    }
    if (response.value.result != .batch) return error.InvalidSqlResponse;
    const frame = response.value.result.batch;
    if (!std.mem.eql(u8, &frame.cursor, &self.cursor) or frame.ordinal != self.ordinal or
        !std.mem.eql(u8, &frame.schema, &self.schema_hash) or
        !std.mem.eql(u8, &frame.observation, &self.observation_hash) or
        frame.rows != self.chunk.values.len or !std.meta.eql(frame.completion, self.chunk.completion)) return error.ResultIdentityChanged;
    const original = self.response.?.value.result.batch;
    if (frame.columns.len != original.columns.len) return error.ResultIdentityChanged;
    for (frame.columns, original.columns) |received, held| if (!std.mem.eql(u8, received, held)) return error.ResultIdentityChanged;
}

fn close(context: *anyopaque) !void {
    const self: *Self = @ptrCast(@alignCast(context));
    if (self.closed) return;
    self.closed = true;
    _ = self.batch.reset(.free_all);
    self.releaseResponse();
    self.chunk = .{ .values = .{}, .completion = null };
    // Failure to observe remote cleanup cannot erase verified completion or
    // imply rollback. The service retains its bounded lease/recovery obligation.
    self.transport.close(self.transport.context, self.cursor);
}
fn destroy(self: *Self) void {
    self.batch.deinit();
    self.releaseResponse();
    self.header.deinit();
    std.debug.assert(self.memory.used == 0);
    self.parent.destroy(self);
}
fn releaseResponse(self: *Self) void {
    if (self.response) |response| response.deinit();
    self.response = null;
}
fn deinit(context: *anyopaque) void {
    const self: *Self = @ptrCast(@alignCast(context));
    self.destroy();
}

const t = std.testing;
const TestScript = struct {
    slots: [2]sdk.Response.Slot = .{ .{}, .{} },
    length: usize = 7,
    maximum: usize = 2,
    position: usize = 0,
    requests: usize = 0,
    disclosures: usize = 0,
    frame_start: usize = 0,
    closed: usize = 0,
    empty_terminal: bool = false,
    fault: enum { none, identity, ordinal, schema, observation, count, incomplete, disconnect, cancelled, duplicate, denied } = .none,
    fn frame(self: *TestScript, allocator: std.mem.Allocator, ordinal: u64) !api.Batch {
        const fields = [_]r.Types.Field{.{ .name = "n", .type = .uint128 }};
        const count = @min(self.maximum, self.length - self.position);
        const pages = try allocator.alloc([]const u8, if (count == 0) 0 else 1);
        if (count != 0) {
            const bytes = try allocator.alignedAlloc(u8, .fromByteUnits(64), 41 + count * 22);
            var writer: std.Io.Writer = .fixed(bytes);
            // Independent TCP1 fixture: plain uint128 cells, written from the
            // wire specification without the production column/cell encoder.
            try writer.writeAll("TCP1");
            try writer.writeAll(&api.native.definition_bytes);
            try writer.writeByte(0);
            try writer.writeInt(u32, @intCast(count), .little);
            try writer.splatByteAll(0, count);
            for (0..count) |i| {
                try writer.writeInt(u32, 17, .little);
                try writer.writeByte(3);
                const value = if (self.fault == .duplicate and ordinal != 0) 0 else (self.position + i) % 3;
                try writer.writeInt(u128, value, .little);
            }
            pages[0] = writer.buffered();
        }
        self.position += count;
        const complete = self.position == self.length and (!self.empty_terminal or count == 0);
        const schema: r.Types.Type = .{ .structure = &fields };
        const observation: r.Observation.Value = .{ .metadata = .{ .kind = .probe, .consistency = .session, .namespace = null, .definitions = &.{}, .configuration_revision = null, .session_settings = null } };
        var schema_buffer: [r.Types.max_encoding_bytes]u8 = undefined;
        var result: api.Batch = .{ .instance = @splat(2), .cursor = @splat(6), .ordinal = ordinal, .schema = try schema.fingerprint(), .observation = try r.Observation.fingerprint(allocator, observation), .description = if (ordinal == 0) .{ .schema = try allocator.dupe(u8, try schema.encode(&schema_buffer)), .observation = observation } else null, .rows = @intCast(count), .columns = pages, .completion = if (complete) .{ .rows = self.length } else null };
        if (ordinal != 0) switch (self.fault) {
            .identity => result.cursor[0] ^= 1,
            .ordinal => result.ordinal += 1,
            .schema => result.schema[0] ^= 1,
            .observation => result.observation[0] ^= 1,
            .count => if (result.completion) |*completion| {
                completion.rows += 1;
            },
            .incomplete => {
                result.rows = 0;
                result.columns = &.{};
                result.completion = null;
            },
            else => {},
        };
        return result;
    }
    fn fetch(context: *anyopaque, allocator: std.mem.Allocator, cursor: api.Id, ordinal: u64) !sdk.Response {
        const self: *TestScript = @ptrCast(@alignCast(context));
        try t.expectEqual(@as(api.Id, @splat(6)), cursor);
        const repeat = ordinal == self.requests;
        if (repeat) {
            self.disclosures += 1;
            self.position = self.frame_start;
        } else {
            self.requests += 1;
            try t.expectEqual(self.requests, ordinal);
        }
        if (self.fault == .denied) return error.SqlObservationDenied;
        if (self.fault == .disconnect) return error.ReadFailed;
        if (self.fault == .cancelled) return error.ResultCancelled;
        return self.response(allocator, ordinal);
    }
    fn response(self: *TestScript, allocator: std.mem.Allocator, ordinal: u64) !sdk.Response {
        const slot = for (&self.slots) |*slot| {
            if (!slot.active) break slot;
        } else return error.SqlResponseCapacity;
        const lease = try slot.acquire(allocator);
        errdefer lease.release() catch unreachable;
        const a = try lease.allocator();
        self.frame_start = self.position;
        const value = try self.frame(a, ordinal);
        // The incomplete-prefix case deliberately violates frame shape and
        // exercises reader admission, independently of the byte parser.
        if (self.fault == .incomplete and ordinal != 0) return .{ .lease = lease, .value = .{ .version = 1, .definition = api.native.current_definition, .instance = value.instance, .result = .{ .batch = value } } };
        const bytes = try api.ResultFrame.encode(a, value);
        return lease.decode(bytes, true);
    }
    fn close(context: *anyopaque, _: api.Id) void {
        const self: *TestScript = @ptrCast(@alignCast(context));
        self.closed += 1;
    }
    fn open(self: *TestScript, allocator: std.mem.Allocator) !r.ResultSet {
        const first = try self.response(allocator, 0);
        errdefer first.deinit();
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

test "repeated native results reuse reserved memory while retaining an independent reader" {
    const memory = @import("transit_memory");
    var probe: memory.AllocationProbe = .{ .parent = t.allocator };
    const storage = try @import("Storage.zig").create(probe.allocator(), "unix:/unused");
    defer storage.destroy();
    const a = storage.data.allocator();
    var retained_script: TestScript = .{ .length = 70, .maximum = 32 };
    var retained = try retained_script.open(a);
    defer retained.deinit();
    probe.begin(true);
    for (0..1000) |iteration| {
        var script: TestScript = .{ .length = ([_]usize{ 0, 1, 31, 32, 33, 70 })[iteration % 6], .maximum = 1 + iteration % 32, .empty_terminal = iteration % 2 == 0 };
        var result = try script.open(a);
        defer result.deinit();
        try requireStream(&result, script.length);
        try t.expectEqualStrings("n", retained.schema.structure[0].name);
    }
    try requireStream(&retained, 70);
    try probe.verify();
    try t.expectEqual(storage.reservedBytes(), probe.live_bytes);
}
fn requireStream(result: *r.ResultSet, length: usize) !void {
    var count: usize = 0;
    while (try result.nextRow()) |row| {
        try t.expectEqual(count % 3, row[0].value.atom.unsigned);
        count += 1;
    }
    try t.expectEqual(length, count);
    try t.expectEqual(length, result.completion().?.rows);
}
test "native projection rejects substituted evidence and missing or false terminals" {
    const memory = @import("transit_memory");
    var probe: memory.AllocationProbe = .{ .parent = t.allocator };
    const storage = try @import("Storage.zig").create(probe.allocator(), "unix:/unused");
    defer storage.destroy();
    probe.begin(true);
    const cases = .{
        .{ TestScript{ .fault = .identity }, error.ResultIdentityChanged },
        .{ TestScript{ .fault = .ordinal }, error.ResultIdentityChanged },
        .{ TestScript{ .fault = .schema }, error.ResultIdentityChanged },
        .{ TestScript{ .fault = .observation }, error.ResultIdentityChanged },
        .{ TestScript{ .fault = .count }, error.InvalidResultCount },
        .{ TestScript{ .fault = .incomplete }, error.InvalidResultChunk },
        .{ TestScript{ .fault = .disconnect }, error.ReadFailed },
        .{ TestScript{ .fault = .cancelled }, error.ResultCancelled },
    };
    inline for (cases) |case| {
        var script = case[0];
        var result = try script.open(storage.data.allocator());
        defer result.deinit();
        try t.expectError(case[1], @import("consumer_test.zig").consume(&result));
        try t.expect(result.completion() == null);
        try t.expectEqual(if (case[1] == error.ResultCancelled) .cancelled else .failed, std.meta.activeTag(result.progress.outcome));
        try t.expectEqual(1, script.closed);
    }
    try probe.verify();
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

test "held presentation revalidates empty and completed data without reopening" {
    for ([_]usize{ 0, 3, 7 }) |length| for ([_]bool{ false, true }) |empty_terminal| {
        var script: TestScript = .{ .length = length, .maximum = 3, .empty_terminal = empty_terminal };
        var result = try script.open(t.allocator);
        defer result.deinit();
        try result.holdDisclosure();
        try requireStream(&result, length);
        try t.expectEqual(0, script.closed);
        const requests = script.requests;
        try result.validateDisclosure();
        try result.validateDisclosure();
        try t.expectEqual(requests, script.requests);
        try t.expectEqual(2, script.disclosures);
        script.fault = .denied;
        try t.expectError(error.SqlObservationDenied, result.validateDisclosure());
        try result.close();
        try t.expectError(error.ResultClosed, result.validateDisclosure());
        try t.expectEqual(1, script.closed);
    };
}

test "interactive windows own rows and reject substituted disclosure evidence" {
    var script: TestScript = .{ .length = 7, .maximum = 3 };
    const outcome = try t.allocator.create(sdk.Executor.Outcome);
    outcome.* = .{ .parent = t.allocator, .memory = .{ .parent = t.allocator, .limit = 1024 * 1024 }, .arena = undefined, .value = undefined };
    outcome.arena = .init(outcome.memory.allocator());
    outcome.value = .{ .rows = try script.open(outcome.memory.allocator()) };
    var view: sdk.ReadView = undefined;
    try view.init(t.allocator, outcome);
    defer view.deinit();
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    for (0..3) |window| {
        try view.advance();
        const observed = try view.inspect(arena.allocator());
        try t.expectEqual(if (window == 2) @as(usize, 1) else 3, observed.rows.len);
        try t.expectEqualStrings("0", observed.rows[0][0].value.atom.unsigned);
        try t.expectEqual(@as(@TypeOf(observed.stopped), if (window == 2) .complete else .metadata_window), observed.stopped);
        try t.expectEqual(window * 3, try std.fmt.parseInt(u64, observed.start, 10));
        try t.expectEqual(window, script.requests);
    }
    script.fault = .schema;
    try t.expectError(error.ResultIdentityChanged, view.inspect(arena.allocator()));
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

test "native result residency stays bounded across a stream larger than its allocator" {
    var memory: r.fuze.MemoryBudget = .{ .parent = t.allocator, .limit = 128 * 1024 };
    var script: TestScript = .{ .length = 16384, .maximum = 32 };
    var result = try script.open(memory.allocator());
    var count: usize = 0;
    while (try result.nextBatch()) |batch| {
        try t.expectEqual(.columns, std.meta.activeTag(batch.layout));
        const column = try batch.columnAt(0);
        for (0..batch.len) |i| {
            try t.expectEqual(count % 3, column.cell(i).value.atom.unsigned);
            count += 1;
        }
    }
    try t.expectEqual(script.length, count);
    try t.expectEqual(script.length, result.completion().?.rows);
    try t.expect(count * 17 > memory.limit);
    try t.expect(memory.peak <= memory.limit);
    result.deinit();
    try t.expectEqual(0, memory.used);
    try t.expectEqual(1, script.closed);
}

test "row convenience over a received column batch allocates no row objects" {
    var allocator = t.FailingAllocator.init(t.allocator, .{});
    var script: TestScript = .{ .length = 32, .maximum = 32 };
    var result = try script.open(allocator.allocator());
    defer result.deinit();
    allocator.fail_index = allocator.alloc_index;
    var count: usize = 0;
    while (try result.nextRow()) |row| {
        try t.expectEqual(count % 3, row[0].value.atom.unsigned);
        count += 1;
    }
    try t.expectEqual(32, count);
    try t.expect(!allocator.has_induced_failure);
}
