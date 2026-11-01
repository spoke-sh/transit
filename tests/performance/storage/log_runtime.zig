//! Installed Stream/Queue measurements through the public signed caller.
//! Fixture requests stay private and are saved before dispatch. Payload checks
//! are repeated from original retained selections after node replacement.
const std = @import("std");
const c = @import("transit_catalog");
const data = @import("transit_data_client");
const Probe = @import("transit_memory").AllocationProbe;
const p = c.protocol;
const sq = p.StreamQueue;
const Kind = enum { stream, queue };
const t = std.testing;

const Config = struct {
    id: u32,
    kind: Kind,
    batch: u32,
    keys: u32,
    claim: u32,
    warmup: u32,
    repeat: u32,
    pub fn validate(self: Config) !void {
        if (self.id == 0 or self.id > 100 or (self.batch != 1 and self.batch != 128) or
            (self.keys != 0 and self.keys != 1 and self.keys != 64) or
            (self.claim != 1 and self.claim != 16) or self.warmup > 10 or
            self.repeat == 0 or self.repeat > 100) return error.InvalidBenchmarkProfile;
    }
};
const State = struct { target: sq.Partition, first_operation: u64, next_operation: u64 };
const columns = [_]c.fuze.TableSchema.Column{
    .{ .id = 1, .name = "id", .type = .int64, .nullable = false },
    .{ .id = 2, .name = "payload", .type = .binary, .nullable = false },
    .{ .id = 3, .name = "entity", .type = .int64, .nullable = false },
};

fn read(comptime T: type, init: std.process.Init, path: []const u8) !std.json.Parsed(T) {
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(4 * 1024 * 1024));
    defer init.gpa.free(bytes);
    return p.Json.parseFromSliceOwned(T, init.gpa, bytes);
}
fn write(init: std.process.Init, path: []const u8, value: anytype) !void {
    const bytes = try p.Json.valueAlloc(init.gpa, value);
    defer init.gpa.free(bytes);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = bytes });
}
fn emit(init: std.process.Init, out: *std.Io.Writer, value: anytype) !void {
    const bytes = try p.Json.valueAlloc(init.gpa, value);
    defer init.gpa.free(bytes);
    try out.writeAll(bytes);
    try out.writeByte('\n');
    try out.flush();
}
fn payloadAt(offset: u64) [128]u8 {
    var bytes: [128]u8 = undefined;
    for (&bytes, 0..) |*byte, index| byte.* = @intCast((offset * 17 + index * 31 + 7) % 256);
    return bytes;
}

fn Runner(comptime kind: Kind) type {
    return struct {
        const Self = @This();
        const Client = if (kind == .stream) c.DirectStreamClient else c.DirectQueueClient;
        const Mutation = if (kind == .stream) c.DirectStreamMutation.Request else c.DirectQueueMutation.Request;
        const Receipt = if (kind == .stream) c.DirectStream.Receipt else c.DirectQueue.Receipt;
        init: std.process.Init,
        caller: *data.Catalog,
        output: *std.heap.ArenaAllocator,
        probe: *Probe,
        out: *std.Io.Writer,
        directory: []const u8,
        config: Config,
        next_operation: u64,
        serial: u64 = 0,
        stage: enum { setup, warmup, measured, recovery } = .setup,

        fn path(self: *Self, operation_id: u64, suffix: []const u8, buffer: []u8) ![]const u8 {
            return std.fmt.bufPrint(buffer, "{s}/baseline-{d}-{d}.{s}", .{ self.directory, self.config.id, operation_id, suffix });
        }
        fn operation(self: *Self) p.DataLifecycle.Operation {
            defer self.next_operation += 1;
            return .{ .scope = self.caller.connection.scope, .principal = self.caller.connection.principal, .operation = self.next_operation };
        }
        fn call(self: *Self, action: Client.Action) !Client.Result {
            _ = self.output.reset(.retain_capacity);
            self.serial += 1;
            const label = @tagName(action);
            const work = if (action == .mutate) @tagName(action.mutate.work) else label;
            try emit(self.init, self.out, .{ .event = "attempt", .profile = self.config.id, .serial = self.serial, .stage = self.stage, .action = work });
            self.probe.begin(false);
            const start = std.Io.Clock.awake.now(self.init.io);
            var http_calls: u32 = 0;
            const outcome = while (true) {
                http_calls += 1;
                const observed = if (kind == .stream) try self.caller.callStream(self.output, action) else try self.caller.callQueue(self.output, action);
                if (observed.value == .result and observed.value.result == .recovering and action != .mutate and action != .wait) {
                    // A cold owner resumes bounded replay on read-only calls.
                    // Keep the exact operation/cursor, expose every progress
                    // response and include all replay time in the logical call.
                    try emit(self.init, self.out, .{ .event = "recovery_step", .profile = self.config.id, .serial = self.serial, .http_call = http_calls });
                    if (start.durationTo(std.Io.Clock.awake.now(self.init.io)).toMilliseconds() >= 30000) {
                        try emit(self.init, self.out, .{ .event = "failure", .profile = self.config.id, .serial = self.serial, .cause = "OwnerRecoveryBudget", .mutation_attempted = false });
                        return error.OwnerRecoveryBudget;
                    }
                    _ = self.output.reset(.retain_capacity);
                    continue;
                }
                break observed;
            };
            const ns = start.durationTo(std.Io.Clock.awake.now(self.init.io)).toNanoseconds();
            const counts = self.probe.counts;
            const peak = self.probe.peak_bytes;
            switch (outcome.value) {
                .failure => |failure| {
                    try emit(self.init, self.out, .{ .event = "failure", .profile = self.config.id, .serial = self.serial, .cause = @errorName(failure.cause), .mutation_attempted = outcome.mutationAttempted(), .diagnostic = failure.diagnostic });
                    return failure.cause;
                },
                .result => |value| {
                    if (value == .recovering) {
                        try emit(self.init, self.out, .{ .event = "failure", .profile = self.config.id, .serial = self.serial, .cause = "OwnerStillRecovering", .mutation_attempted = outcome.mutationAttempted() });
                        return error.OwnerStillRecovering;
                    }
                    try emit(self.init, self.out, .{ .event = "sample", .profile = self.config.id, .serial = self.serial, .stage = self.stage, .action = work, .http_calls = http_calls, .ns = ns, .backing = counts, .client_peak_live_bytes = peak });
                    return value;
                },
            }
        }
        fn mutate(self: *Self, work: Mutation, bytes: ?[]const u8) !Receipt {
            var buffer: [1024]u8 = undefined;
            const saved = try Client.save(self.init.gpa, self.caller.connection, .{ .work = work, .payload = bytes });
            defer self.init.gpa.free(saved);
            // This durable caller fixture is outside the operation timing.
            try std.Io.Dir.cwd().writeFile(self.init.io, .{ .sub_path = try self.path(work.identity().operation, "request", &buffer), .data = saved });
            const receipt = (try self.call(.{ .mutate = .{ .work = work, .payload = bytes } })).operation orelse return error.MissingOriginalReceipt;
            try write(self.init, try self.path(work.identity().operation, "receipt", &buffer), receipt);
            return receipt;
        }
        fn row(self: *Self, offset: u64, value: c.fuze.TableRow.Row, digest: *std.crypto.hash.sha2.Sha256) !void {
            const expected = payloadAt(offset);
            try t.expectEqual(@as(i64, @intCast(offset)), value.cells[0].value.atom.signed);
            try t.expectEqualSlices(u8, &expected, value.cells[1].value.atom.bytes);
            try t.expectEqual(@as(i64, @intCast(offset % @max(1, self.config.keys))), value.cells[2].value.atom.signed);
            var integer: [8]u8 = undefined;
            std.mem.writeInt(u64, &integer, offset, .little);
            digest.update(&integer);
            digest.update(value.cells[1].value.atom.bytes);
        }
        fn verification(self: *Self, offsets: []const u64, digest: *std.crypto.hash.sha2.Sha256) !void {
            const bytes = digest.finalResult();
            const hex = std.fmt.bytesToHex(bytes, .lower);
            try emit(self.init, self.out, .{ .event = "readback", .profile = self.config.id, .stage = self.stage, .offsets = offsets, .sha256 = hex[0..] });
        }
        fn streamRead(self: *Self, receipt: p.StreamRead.Receipt) !void {
            var cursor = (try self.call(.{ .cursor = .{ .target = receipt.request.target, .read = receipt.handle() } })).cursor;
            var next = receipt.request.from;
            while (!cursor.coverage.complete) {
                const page = (try self.call(.{ .page = .{ .cursor = cursor, .limits = .{ .rows = 128, .encoded_bytes = 1024 * 1024, .scanned_rows = 128 } } })).page;
                var offsets: [128]u64 = undefined;
                var digest = std.crypto.hash.sha2.Sha256.init(.{});
                for (page.rows, 0..) |item, index| {
                    try t.expectEqual(next, item.offset);
                    try t.expect(!item.tombstone);
                    try self.row(item.offset, item.value, &digest);
                    offsets[index] = item.offset;
                    next += 1;
                }
                try t.expect(page.rows.len != 0 or page.cursor.coverage.complete);
                try self.verification(offsets[0..page.rows.len], &digest);
                cursor = page.cursor;
            }
            try t.expectEqual(receipt.until, next);
        }
        fn queueRead(self: *Self, receipt: sq.ClaimReceipt, ack: bool) !void {
            var cursor: p.QueueRead.Cursor = .{ .receipt = receipt, .next = 0 };
            while (!cursor.complete()) {
                const page = (try self.call(.{ .page = .{ .cursor = cursor, .limits = .{ .rows = 16, .encoded_bytes = 1024 * 1024 } } })).page;
                var offsets: [16]u64 = undefined;
                var leases: [16]sq.Lease = undefined;
                var digest = std.crypto.hash.sha2.Sha256.init(.{});
                for (page.rows, 0..) |item, index| {
                    const offset = item.lease.original.offset;
                    try self.row(offset, item.value, &digest);
                    if (!ack) try t.expectEqual(.acked, item.lease.state);
                    offsets[index] = offset;
                    leases[index] = item.lease.original;
                }
                try t.expect(page.rows.len != 0);
                try self.verification(offsets[0..page.rows.len], &digest);
                const count = page.rows.len;
                cursor = page.cursor;
                // Copy fixed lease evidence before the next call resets output.
                if (ack) for (leases[0..count]) |lease| {
                    _ = try self.mutate(.{ .settle = .{ .operation = self.operation(), .lease = lease, .action = .ack } }, null);
                };
            }
        }
        fn declare(self: *Self, owner: u64) !struct { target: sq.Partition, schema: c.fuze.TableSchema.Schema } {
            const op = self.operation();
            var name: [64]u8 = undefined;
            const schema: c.fuze.TableSchema.Schema = .{ .object = op.operation, .revision = 1, .next_column = 4, .columns = &columns, .primary_key = &.{} };
            const intent: c.DirectLog.Intent = .{ .kind = if (kind == .stream) .stream else .queue, .namespace = 1, .name = try .init(try std.fmt.bufPrint(&name, "baseline_{d}", .{self.config.id})), .action = .{ .create = .{
                .owner = owner,
                .schema = schema,
                .configuration = .{
                    .partitioning = .{ .count = 1, .key_column = null, .hash = .sha256_64 },
                    .retention = .{ .max_age_ms = null },
                    .policy = if (kind == .stream) .{ .stream = .{ .compact_key_column = null, .timestamp_column = null } } else .{ .queue = .{ .ordering = if (self.config.keys == 0) .unordered else .key_fifo, .key_column = if (self.config.keys == 0) null else 3, .lease_ms = 60000, .maximum_lease_ms = 60000, .maximum_attempts = 5, .backoff = .{ .initial_ms = 10, .maximum_ms = 1000, .multiplier = 2 }, .dead_letter = null } },
                },
                .limits = .{ .append_rows = 128, .append_bytes = 1024 * 1024, .claim_rows = 16, .read_rows = 128, .read_bytes = 1024 * 1024, .active_leases = 64, .waiters = 64, .timer_steps = 64 },
            } } };
            const request: c.DirectLog.Request = .{ .intent = intent, .binding = .{ .definition = p.Growth.current_definition, .identity = op, .target = .{ .scope = op.scope, .branch = 1, .object = op.operation }, .action = .create, .expected_definition = null, .expected_data = null, .intent = try intent.digest(self.init.gpa) } };
            var buffer: [1024]u8 = undefined;
            const saved = try c.DirectLogClient.save(self.init.gpa, self.caller.connection, request);
            defer self.init.gpa.free(saved);
            try std.Io.Dir.cwd().writeFile(self.init.io, .{ .sub_path = try self.path(op.operation, "declaration", &buffer), .data = saved });
            const admitted = try self.caller.callLog(self.output, .{ .admit = request });
            if (admitted.value == .failure) return admitted.value.failure.cause;
            for (0..32) |_| {
                _ = self.output.reset(.retain_capacity);
                const result = try self.caller.callLog(self.output, .{ .operation = .{ .binding = request.binding, .command = .execute, .steps = 32 } });
                if (result.value == .failure) return result.value.failure.cause;
                const original = result.value.result.operation.operation;
                if (original.phase == .complete) return .{ .target = .{ .definition = p.Growth.current_definition, .interpretation = original.resulting.?.stored.declaration.interpretation, .partition = 0 }, .schema = schema };
            }
            return error.DeclarationIncomplete;
        }
        fn measure(self: *Self, owner: u64) !State {
            const declared = try self.declare(owner);
            const first_operation = self.next_operation;
            var buffer: [1024 * 1024]u8 = undefined;
            var cells: [128][3]c.fuze.Types.Values.Cell = undefined;
            var bodies: [128][128]u8 = undefined;
            var rows: [128]c.storage.LogBatch.Row = undefined;
            var next: u64 = 0;
            for (0..self.config.warmup + self.config.repeat) |sample| {
                self.stage = if (sample < self.config.warmup) .warmup else .measured;
                const op = self.operation();
                for (0..self.config.batch) |index| {
                    const offset = next + index;
                    bodies[index] = payloadAt(offset);
                    cells[index] = .{ .{ .value = .{ .atom = .{ .signed = @intCast(offset) } } }, .{ .value = .{ .atom = .{ .bytes = &bodies[index] } } }, .{ .value = .{ .atom = .{ .signed = @intCast(offset % @max(1, self.config.keys)) } } } };
                    rows[index] = .{ .cells = &cells[index] };
                }
                const payload = try c.storage.LogBatch.encode(declared.schema, op, if (kind == .stream) .stream else .queue, rows[0..self.config.batch], &buffer);
                const append: sq.Append = .{ .target = declared.target, .operation = op, .kind = if (kind == .stream) .stream else .queue, .producer = null, .rows = self.config.batch, .payload = c.storage.LogBatch.content(payload) };
                const original = try self.mutate(if (kind == .stream) .{ .append = append } else .{ .enqueue = append }, payload);
                const receipt = if (kind == .stream) original.append else original.enqueue;
                try t.expectEqual(next, receipt.first);
                next += self.config.batch;
                try t.expectEqual(next, receipt.next);
                if (kind == .stream) {
                    const read_receipt = (try self.mutate(.{ .consume = .{ .target = declared.target, .operation = self.operation(), .group = null, .from = receipt.first, .until = receipt.next, .timestamp = null } }, null)).consume;
                    try self.streamRead(read_receipt);
                } else {
                    var remaining = self.config.batch;
                    while (remaining != 0) {
                        const claim = (try self.mutate(.{ .claim = .{ .target = declared.target, .operation = self.operation(), .maximum = @min(remaining, self.config.claim), .lease_ms = 60000 } }, null)).claim;
                        try t.expect(claim.rows > 0 and claim.rows <= remaining);
                        try self.queueRead(claim, true);
                        remaining -= claim.rows;
                    }
                }
            }
            return .{ .target = declared.target, .first_operation = first_operation, .next_operation = self.next_operation };
        }
        fn recover(self: *Self, state: State) !void {
            self.stage = .recovery;
            self.next_operation = state.next_operation;
            for (state.first_operation..state.next_operation) |id| {
                var buffer: [1024]u8 = undefined;
                const saved = try read(Client.Saved, self.init, try self.path(id, "request", &buffer));
                defer saved.deinit();
                try saved.value.validate(self.init.gpa);
                const expected = try read(Receipt, self.init, try self.path(id, "receipt", &buffer));
                defer expected.deinit();
                const original = (try self.call(.{ .operation = saved.value.work.work })).operation orelse return error.MissingOriginalReceipt;
                try t.expectEqualDeep(expected.value, original);
                if (kind == .stream) {
                    if (original == .consume) {
                        try self.streamRead(original.consume);
                        _ = try self.mutate(.{ .release = .{ .operation = self.operation(), .target = state.target, .read = original.consume.handle() } }, null);
                    }
                } else if (original == .claim) {
                    try self.queueRead(original.claim, false);
                    _ = try self.mutate(.{ .release = .{ .operation = self.operation(), .claim = original.claim } }, null);
                }
            }
        }
    };
}

fn run(comptime kind: Kind, init: std.process.Init, client: c.DirectTableClient, owner: u64, path: []const u8, config: Config, recover: bool, out: *std.Io.Writer) !void {
    var probe: Probe = .{ .parent = init.gpa };
    var caller = try data.Catalog.init(probe.allocator(), init.io, .{ .url = client.service.url, .connection = client.connection, .timeout_ms = 30000 }, @splat(29));
    defer caller.deinit();
    var output: std.heap.ArenaAllocator = .init(probe.allocator());
    defer output.deinit();
    var runner: Runner(kind) = .{ .init = init, .caller = &caller, .output = &output, .probe = &probe, .out = out, .directory = std.fs.path.dirname(path) orelse ".", .config = config, .next_operation = 800000 + @as(u64, config.id) * 100000 };
    var buffer: [1024]u8 = undefined;
    const state_path = try std.fmt.bufPrint(&buffer, "{s}.baseline-state-{d}.json", .{ path, config.id });
    if (recover) {
        const state = try read(State, init, state_path);
        defer state.deinit();
        try runner.recover(state.value);
    } else {
        (try client.call(.initialize)).deinit();
        try write(init, state_path, try runner.measure(owner));
    }
    try emit(init, out, .{ .event = "complete", .profile = config.id, .recovery = recover, .build_mode = @tagName(@import("builtin").mode) });
}
pub fn execute(init: std.process.Init, client: c.DirectTableClient, owner: u64, path: []const u8, recover: bool, out: *std.Io.Writer) !void {
    var buffer: [1024]u8 = undefined;
    const config = try read(Config, init, try std.fmt.bufPrint(&buffer, "{s}.baseline.json", .{path}));
    defer config.deinit();
    try config.value.validate();
    switch (config.value.kind) {
        .stream => try run(.stream, init, client, owner, path, config.value, recover, out),
        .queue => try run(.queue, init, client, owner, path, config.value, recover, out),
    }
}

fn inspect(comptime kind: Kind, init: std.process.Init, client: c.DirectTableClient, path: []const u8, config: Config, operation_id: u64, out: *std.Io.Writer) !void {
    const Client = if (kind == .stream) c.DirectStreamClient else c.DirectQueueClient;
    var probe: Probe = .{ .parent = init.gpa };
    var caller = try data.Catalog.init(probe.allocator(), init.io, .{ .url = client.service.url, .connection = client.connection, .timeout_ms = 30000 }, @splat(29));
    defer caller.deinit();
    var output: std.heap.ArenaAllocator = .init(probe.allocator());
    defer output.deinit();
    var runner: Runner(kind) = .{ .init = init, .caller = &caller, .output = &output, .probe = &probe, .out = out, .directory = std.fs.path.dirname(path) orelse ".", .config = config, .next_operation = 0, .stage = .recovery };
    var buffer: [1024]u8 = undefined;
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, try runner.path(operation_id, "request", &buffer), init.gpa, .limited(4 * 1024 * 1024));
    defer init.gpa.free(bytes);
    const saved = try Client.load(init.gpa, bytes);
    defer saved.deinit();
    if (!std.meta.eql(saved.value.connection, client.connection) or saved.value.work.work.identity().operation != operation_id) return error.OriginalOperationMismatch;
    // A missing receipt is only an observation, never rejection or permission to
    // submit a replacement. This mode cannot mutate, even without a final State.
    const receipt = (try runner.call(.{ .operation = saved.value.work.work })).operation;
    const observation = .{ .event = "inspection", .profile = config.id, .operation = operation_id, .receipt = receipt };
    try write(init, try runner.path(operation_id, "inspection", &buffer), observation);
    try emit(init, out, observation);
}

pub fn inspectOriginal(init: std.process.Init, client: c.DirectTableClient, path: []const u8, operation_id: u64, out: *std.Io.Writer) !void {
    var buffer: [1024]u8 = undefined;
    const config = try read(Config, init, try std.fmt.bufPrint(&buffer, "{s}.baseline.json", .{path}));
    defer config.deinit();
    try config.value.validate();
    switch (config.value.kind) {
        .stream => try inspect(.stream, init, client, path, config.value, operation_id, out),
        .queue => try inspect(.queue, init, client, path, config.value, operation_id, out),
    }
}
