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
const Mode = enum { hot, sealed_segment, consumer_group, delayed_visibility, wait_wakeup, lease_expiry, concurrent_load };
const t = std.testing;

const Config = struct {
    id: u32,
    kind: Kind,
    batch: u32,
    keys: u32,
    claim: u32,
    mode: Mode = .hot,
    workers: u32 = 1,
    warmup: u32,
    repeat: u32,
    pub fn validate(self: Config) !void {
        if (self.id == 0 or self.id > 100 or (self.batch != 1 and self.batch != 2 and self.batch != 128) or
            (self.keys != 0 and self.keys != 1 and self.keys != 64) or
            (self.claim != 1 and self.claim != 16) or self.workers == 0 or self.workers > 8 or
            self.warmup > 10 or self.repeat == 0 or self.repeat > 100) return error.InvalidBenchmarkProfile;
        if ((self.mode == .concurrent_load) != (self.workers > 1)) return error.InvalidBenchmarkProfile;
    }
};
const PrepState = struct { target: sq.Partition, first_operation: u64, next_operation: u64 };
const State = struct { target: sq.Partition, first_operation: u64, next_operation: u64, expired_claim_end: u64 = 0 };
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

const WakeupProducer = struct {
    fn run(init: std.process.Init, url: []const u8, connection: c.DirectTableProtocol.Connection, append: sq.Append, payload: []const u8) !c.DirectQueue.Receipt {
        try init.io.sleep(.fromMilliseconds(5), .awake);
        var caller = try data.Catalog.init(init.gpa, init.io, .{ .url = url, .connection = connection, .timeout_ms = 30000 }, @splat(29));
        defer caller.deinit();
        var output: std.heap.ArenaAllocator = .init(init.gpa);
        defer output.deinit();
        const outcome = try caller.callQueue(&output, .{ .mutate = .{ .work = .{ .enqueue = append }, .payload = payload } });
        return switch (outcome.value) {
            .failure => |failure| failure.cause,
            .result => |result| result.operation orelse error.MissingOriginalReceipt,
        };
    }
};

const ConcurrentSample = struct {
    ns: i96,
    http_calls: u32,
    counts: Probe.Counts,
    peak: usize,
};
const ConcurrentWorkerResult = struct {
    claim_sample: ConcurrentSample,
    claim_receipt: c.DirectQueue.Receipt,
    page_sample: ConcurrentSample,
    offset: u64,
    sha256: [32]u8,
    ack_request: c.DirectQueueMutation.Request,
    ack_sample: ConcurrentSample,
    ack_receipt: c.DirectQueue.Receipt,
};
const ConcurrentConsumer = struct {
    fn run(init: std.process.Init, url: []const u8, connection: c.DirectTableProtocol.Connection, keys_modulus: u32, target: sq.Partition, claim_op: p.DataLifecycle.Operation, ack_op: p.DataLifecycle.Operation) !ConcurrentWorkerResult {
        var probe: Probe = .{ .parent = init.gpa };
        var caller = try data.Catalog.init(probe.allocator(), init.io, .{ .url = url, .connection = connection, .timeout_ms = 30000 }, @splat(29));
        defer caller.deinit();
        var output: std.heap.ArenaAllocator = .init(probe.allocator());
        defer output.deinit();

        const claim_req: sq.Claim = .{ .target = target, .operation = claim_op, .maximum = 1, .lease_ms = 60000, .predicate = null };
        _ = output.reset(.retain_capacity);
        probe.begin(false);
        const claim_start = std.Io.Clock.awake.now(init.io);
        const claim_out = try caller.callQueue(&output, .{ .mutate = .{ .work = .{ .claim = claim_req } } });
        const claim_sample: ConcurrentSample = .{
            .ns = claim_start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds(),
            .http_calls = 1,
            .counts = probe.counts,
            .peak = probe.peak_bytes,
        };
        const claim_receipt = switch (claim_out.value) {
            .failure => |failure| return failure.cause,
            .result => |result| result.operation orelse return error.MissingOriginalReceipt,
        };
        try t.expect(claim_receipt == .claim and claim_receipt.claim.rows == 1);

        _ = output.reset(.retain_capacity);
        probe.begin(false);
        const page_start = std.Io.Clock.awake.now(init.io);
        const page_out = try caller.callQueue(&output, .{ .page = .{ .cursor = .{ .receipt = claim_receipt.claim, .next = 0 }, .limits = .{ .rows = 1, .encoded_bytes = 1024 * 1024 } } });
        const page_sample: ConcurrentSample = .{
            .ns = page_start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds(),
            .http_calls = 1,
            .counts = probe.counts,
            .peak = probe.peak_bytes,
        };
        const page = switch (page_out.value) {
            .failure => |failure| return failure.cause,
            .result => |result| result.page,
        };
        try t.expect(page.rows.len == 1 and page.cursor.complete());
        const item = page.rows[0];
        const offset = item.lease.original.offset;
        const expected = payloadAt(offset);
        try t.expectEqual(@as(i64, @intCast(offset)), item.value.cells[0].value.atom.signed);
        try t.expectEqualSlices(u8, &expected, item.value.cells[1].value.atom.bytes);
        try t.expectEqual(@as(i64, @intCast(offset % @max(1, keys_modulus))), item.value.cells[2].value.atom.signed);
        var digest = std.crypto.hash.sha2.Sha256.init(.{});
        var integer: [8]u8 = undefined;
        std.mem.writeInt(u64, &integer, offset, .little);
        digest.update(&integer);
        digest.update(item.value.cells[1].value.atom.bytes);
        const lease = item.lease.original;

        const ack_req: c.DirectQueueMutation.Request = .{ .settle = .{ .operation = ack_op, .lease = lease, .action = .ack } };
        _ = output.reset(.retain_capacity);
        probe.begin(false);
        const ack_start = std.Io.Clock.awake.now(init.io);
        const ack_out = try caller.callQueue(&output, .{ .mutate = .{ .work = ack_req } });
        const ack_sample: ConcurrentSample = .{
            .ns = ack_start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds(),
            .http_calls = 1,
            .counts = probe.counts,
            .peak = probe.peak_bytes,
        };
        const ack_receipt = switch (ack_out.value) {
            .failure => |failure| return failure.cause,
            .result => |result| result.operation orelse return error.MissingOriginalReceipt,
        };

        return .{
            .claim_sample = claim_sample,
            .claim_receipt = claim_receipt,
            .page_sample = page_sample,
            .offset = offset,
            .sha256 = digest.finalResult(),
            .ack_request = ack_req,
            .ack_sample = ack_sample,
            .ack_receipt = ack_receipt,
        };
    }
};

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
        emit_events: bool = true,
        stage: enum { setup, warmup, measured, recovery } = .setup,

        fn path(self: *Self, operation_id: u64, suffix: []const u8, buffer: []u8) ![]const u8 {
            return std.fmt.bufPrint(buffer, "{s}/baseline-{d}-{d}.{s}", .{ self.directory, self.config.id, operation_id, suffix });
        }
        fn prepPath(self: *Self, base: []const u8, buffer: []u8) ![]const u8 {
            return std.fmt.bufPrint(buffer, "{s}.baseline-prep-{d}.json", .{ base, self.config.id });
        }
        fn operation(self: *Self) p.DataLifecycle.Operation {
            defer self.next_operation += 1;
            return .{ .scope = self.caller.connection.scope, .principal = self.caller.connection.principal, .operation = self.next_operation };
        }
        fn saveRequest(self: *Self, work: Mutation, bytes: ?[]const u8) !void {
            var buffer: [1024]u8 = undefined;
            const saved = try Client.save(self.init.gpa, self.caller.connection, .{ .work = work, .payload = bytes });
            defer self.init.gpa.free(saved);
            try std.Io.Dir.cwd().writeFile(self.init.io, .{ .sub_path = try self.path(work.identity().operation, "request", &buffer), .data = saved });
        }
        fn saveReceipt(self: *Self, operation_id: u64, receipt: Receipt) !void {
            var buffer: [1024]u8 = undefined;
            try write(self.init, try self.path(operation_id, "receipt", &buffer), receipt);
        }
        fn call(self: *Self, action: Client.Action) !Client.Result {
            _ = self.output.reset(.retain_capacity);
            self.serial += 1;
            const label = @tagName(action);
            const work = if (action == .mutate) @tagName(action.mutate.work) else label;
            if (self.emit_events) try emit(self.init, self.out, .{ .event = "attempt", .profile = self.config.id, .serial = self.serial, .stage = self.stage, .action = work });
            self.probe.begin(false);
            const start = std.Io.Clock.awake.now(self.init.io);
            var http_calls: u32 = 0;
            const outcome = while (true) {
                http_calls += 1;
                const observed = if (kind == .stream) try self.caller.callStream(self.output, action) else try self.caller.callQueue(self.output, action);
                if (observed.value == .result and observed.value.result == .recovering and action != .mutate and action != .wait) {
                    if (self.emit_events) try emit(self.init, self.out, .{ .event = "recovery_step", .profile = self.config.id, .serial = self.serial, .http_call = http_calls, .progress = observed.value.result.recovering });
                    if (start.durationTo(std.Io.Clock.awake.now(self.init.io)).toMilliseconds() >= 30000) {
                        if (self.emit_events) try emit(self.init, self.out, .{ .event = "failure", .profile = self.config.id, .serial = self.serial, .cause = "OwnerRecoveryBudget", .mutation_attempted = false });
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
                    if (self.emit_events) try emit(self.init, self.out, .{ .event = "failure", .profile = self.config.id, .serial = self.serial, .cause = @errorName(failure.cause), .mutation_attempted = outcome.mutationAttempted(), .diagnostic = failure.diagnostic });
                    return failure.cause;
                },
                .result => |value| {
                    if (value == .recovering) {
                        if (self.emit_events) try emit(self.init, self.out, .{ .event = "failure", .profile = self.config.id, .serial = self.serial, .cause = "OwnerStillRecovering", .mutation_attempted = outcome.mutationAttempted() });
                        return error.OwnerStillRecovering;
                    }
                    const known_outcome = value == .operation and value.operation != null;
                    if (known_outcome) {
                        if (action == .mutate) {
                            try self.saveReceipt(action.mutate.work.identity().operation, value.operation.?);
                        } else if (kind == .queue and action == .wait) {
                            try self.saveReceipt(action.wait.claim.operation.operation, value.operation.?);
                        }
                    }
                    if (ns >= 30 * std.time.ns_per_s) {
                        if (self.emit_events) try emit(self.init, self.out, .{ .event = "failure", .profile = self.config.id, .serial = self.serial, .cause = "CallBudget", .mutation_attempted = outcome.mutationAttempted(), .known_outcome = known_outcome, .http_calls = http_calls, .ns = ns });
                        return error.CallBudget;
                    }
                    if (self.emit_events) try emit(self.init, self.out, .{ .event = "sample", .profile = self.config.id, .serial = self.serial, .stage = self.stage, .action = work, .http_calls = http_calls, .ns = ns, .backing = counts, .client_peak_live_bytes = peak });
                    return value;
                },
            }
        }
        fn mutate(self: *Self, work: Mutation, bytes: ?[]const u8) !Receipt {
            try self.saveRequest(work, bytes);
            return (try self.call(.{ .mutate = .{ .work = work, .payload = bytes } })).operation orelse error.MissingOriginalReceipt;
        }
        fn waitClaim(self: *Self, claim_req: sq.Claim, milliseconds: u32) !sq.ClaimReceipt {
            if (kind != .queue) unreachable;
            try self.saveRequest(.{ .claim = claim_req }, null);
            const receipt = (try self.call(.{ .wait = .{ .claim = claim_req, .milliseconds = milliseconds } })).operation orelse return error.QueueWaitTimedOut;
            return receipt.claim;
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
        fn streamRead(self: *Self, receipt: p.StreamRead.Receipt) !p.StreamRead.Progress {
            const initial_cursor = (try self.call(.{ .cursor = .{ .target = receipt.request.target, .read = receipt.handle() } })).cursor;
            var cursor = initial_cursor;
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
            return p.StreamRead.Progress.between(initial_cursor, cursor);
        }
        fn queueReadWithAttempt(self: *Self, receipt: sq.ClaimReceipt, ack: bool, expected_attempt: ?u64, expected_visible_ms: ?u64) !void {
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
                    if (expected_attempt) |attempt_num| try t.expectEqual(attempt_num, item.lease.attempt);
                    if (expected_visible_ms) |vis_ms| try t.expectEqual(vis_ms, item.visible_ms);
                    offsets[index] = offset;
                    leases[index] = item.lease.original;
                }
                try t.expect(page.rows.len != 0);
                try self.verification(offsets[0..page.rows.len], &digest);
                const count = page.rows.len;
                cursor = page.cursor;
                if (ack) for (leases[0..count]) |lease| {
                    _ = try self.mutate(.{ .settle = .{ .operation = self.operation(), .lease = lease, .action = .ack } }, null);
                };
            }
        }
        fn queueRead(self: *Self, receipt: sq.ClaimReceipt, ack: bool) !void {
            return self.queueReadWithAttempt(receipt, ack, null, null);
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
                    .policy = if (kind == .stream) .{ .stream = .{ .compact_key_column = null, .timestamp_column = null } } else .{ .queue = .{ .ordering = if (self.config.keys == 0) .unordered else .key_fifo, .key_column = if (self.config.keys == 0) null else 3, .lease_ms = 60000, .maximum_lease_ms = 60000, .maximum_attempts = 5, .backoff = .{ .initial_ms = 0, .maximum_ms = 1000, .multiplier = 1 }, .dead_letter = null } },
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
        fn preparePhase(self: *Self, owner: u64, base_path: []const u8) !void {
            self.emit_events = false;
            const declared = try self.declare(owner);
            const first_operation = self.next_operation;
            var buffer: [1024 * 1024]u8 = undefined;
            var cells: [128][3]c.fuze.Types.Values.Cell = undefined;
            var bodies: [128][128]u8 = undefined;
            var rows: [128]c.storage.LogBatch.Row = undefined;
            var next: u64 = 0;
            const total_samples = self.config.warmup + self.config.repeat;
            for (0..total_samples) |_| {
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
            }
            if (kind == .queue and self.config.mode == .lease_expiry) {
                for (0..total_samples) |_| {
                    const claim = (try self.mutate(.{ .claim = .{ .target = declared.target, .operation = self.operation(), .maximum = 1, .lease_ms = 25, .predicate = null } }, null)).claim;
                    try t.expectEqual(@as(u32, 1), claim.rows);
                }
            }
            var path_buf: [1024]u8 = undefined;
            try write(self.init, try self.prepPath(base_path, &path_buf), PrepState{
                .target = declared.target,
                .first_operation = first_operation,
                .next_operation = self.next_operation,
            });
        }
        fn measure(self: *Self, owner: u64, base_path: []const u8) !State {
            if (self.config.mode == .sealed_segment) {
                if (kind != .stream) unreachable;
                var path_buf: [1024]u8 = undefined;
                const prep = try read(PrepState, self.init, try self.prepPath(base_path, &path_buf));
                defer prep.deinit();
                self.next_operation = prep.value.next_operation;
                var next: u64 = 0;
                for (0..self.config.warmup + self.config.repeat) |sample| {
                    self.stage = if (sample < self.config.warmup) .warmup else .measured;
                    const until = next + self.config.batch;
                    const read_receipt = (try self.mutate(.{ .consume = .{ .target = prep.value.target, .operation = self.operation(), .group = null, .from = next, .until = until, .timestamp = null } }, null)).consume;
                    _ = try self.streamRead(read_receipt);
                    next = until;
                }
                return .{ .target = prep.value.target, .first_operation = prep.value.first_operation, .next_operation = self.next_operation };
            }
            if (self.config.mode == .lease_expiry) {
                if (kind != .queue) unreachable;
                var path_buf: [1024]u8 = undefined;
                const prep = try read(PrepState, self.init, try self.prepPath(base_path, &path_buf));
                defer prep.deinit();
                self.next_operation = prep.value.next_operation;
                for (0..self.config.warmup + self.config.repeat) |sample| {
                    self.stage = if (sample < self.config.warmup) .warmup else .measured;
                    const claim = (try self.mutate(.{ .claim = .{ .target = prep.value.target, .operation = self.operation(), .maximum = 1, .lease_ms = 60000, .predicate = null } }, null)).claim;
                    try t.expectEqual(@as(u32, 1), claim.rows);
                    try self.queueReadWithAttempt(claim, true, 2, null);
                }
                return .{ .target = prep.value.target, .first_operation = prep.value.first_operation, .next_operation = self.next_operation, .expired_claim_end = prep.value.next_operation };
            }

            const declared = try self.declare(owner);
            const first_operation = self.next_operation;
            var buffer: [1024 * 1024]u8 = undefined;
            var cells: [128][3]c.fuze.Types.Values.Cell = undefined;
            var bodies: [128][128]u8 = undefined;
            var rows: [128]c.storage.LogBatch.Row = undefined;
            var next: u64 = 0;
            const group: sq.Group = .{ .id = 1, .generation = 1, .principal = self.caller.connection.principal };
            if (kind == .stream and self.config.mode == .consumer_group) {
                self.stage = .setup;
                const cut = (try self.call(.{ .observe = declared.target })).cut;
                _ = try self.mutate(.{ .assign = .{ .operation = self.operation(), .cut = cut, .expected = null, .group = group, .next = 0 } }, null);
            }

            for (0..self.config.warmup + self.config.repeat) |sample| {
                self.stage = if (sample < self.config.warmup) .warmup else .measured;
                if (kind == .queue and self.config.mode == .wait_wakeup) {
                    const enqueue_op = self.operation();
                    const claim_op = self.operation();
                    const offset = next;
                    bodies[0] = payloadAt(offset);
                    cells[0] = .{ .{ .value = .{ .atom = .{ .signed = @intCast(offset) } } }, .{ .value = .{ .atom = .{ .bytes = &bodies[0] } } }, .{ .value = .{ .atom = .{ .signed = 0 } } } };
                    rows[0] = .{ .cells = &cells[0] };
                    const payload = try c.storage.LogBatch.encode(declared.schema, enqueue_op, .queue, rows[0..1], &buffer);
                    const append: sq.Append = .{ .target = declared.target, .operation = enqueue_op, .kind = .queue, .producer = null, .rows = 1, .payload = c.storage.LogBatch.content(payload) };
                    try self.saveRequest(.{ .enqueue = append }, payload);
                    var producer = try self.init.io.concurrent(WakeupProducer.run, .{ self.init, self.caller.service_url, self.caller.connection, append, payload });
                    const claim = try self.waitClaim(.{ .target = declared.target, .operation = claim_op, .maximum = 1, .lease_ms = 60000, .predicate = null }, 1000);
                    const enqueue_receipt = try producer.await(self.init.io);
                    try self.saveReceipt(enqueue_op.operation, enqueue_receipt);
                    try t.expectEqual(next, enqueue_receipt.enqueue.first);
                    next += 1;
                    try t.expectEqual(next, enqueue_receipt.enqueue.next);
                    try t.expectEqual(@as(u32, 1), claim.rows);
                    try self.queueRead(claim, true);
                    continue;
                }

                var delayed_visible_ms: u64 = 0;
                if (kind == .queue and self.config.mode == .delayed_visibility) {
                    const now = (try self.call(.{ .current_time = declared.target })).current_time.time.earliest_ms;
                    delayed_visible_ms = now + 60;
                }

                const op = self.operation();
                for (0..self.config.batch) |index| {
                    const offset = next + index;
                    bodies[index] = payloadAt(offset);
                    cells[index] = .{ .{ .value = .{ .atom = .{ .signed = @intCast(offset) } } }, .{ .value = .{ .atom = .{ .bytes = &bodies[index] } } }, .{ .value = .{ .atom = .{ .signed = @intCast(offset % @max(1, self.config.keys)) } } } };
                    rows[index] = .{ .cells = &cells[index], .visible_ms = delayed_visible_ms };
                }
                const payload = try c.storage.LogBatch.encode(declared.schema, op, if (kind == .stream) .stream else .queue, rows[0..self.config.batch], &buffer);
                const append: sq.Append = .{ .target = declared.target, .operation = op, .kind = if (kind == .stream) .stream else .queue, .producer = null, .rows = self.config.batch, .payload = c.storage.LogBatch.content(payload) };
                const original = try self.mutate(if (kind == .stream) .{ .append = append } else .{ .enqueue = append }, payload);
                const receipt = if (kind == .stream) original.append else original.enqueue;
                try t.expectEqual(next, receipt.first);
                next += self.config.batch;
                try t.expectEqual(next, receipt.next);

                if (kind == .stream) {
                    const use_group: ?sq.Group = if (self.config.mode == .consumer_group) group else null;
                    const read_receipt = (try self.mutate(.{ .consume = .{ .target = declared.target, .operation = self.operation(), .group = use_group, .from = receipt.first, .until = receipt.next, .timestamp = null } }, null)).consume;
                    const progress = try self.streamRead(read_receipt);
                    if (self.config.mode == .consumer_group) {
                        _ = try self.mutate(.{ .offset = .{
                            .commit = .{ .operation = self.operation(), .group = group, .coverage = try progress.coverage(), .expected_next = receipt.first, .next = receipt.next },
                            .progress = progress,
                        } }, null);
                    }
                } else if (self.config.mode == .delayed_visibility) {
                    const claim = try self.waitClaim(.{ .target = declared.target, .operation = self.operation(), .maximum = 1, .lease_ms = 60000, .predicate = null }, 1000);
                    try t.expectEqual(@as(u32, 1), claim.rows);
                    try self.queueReadWithAttempt(claim, true, 1, delayed_visible_ms);
                } else if (self.config.mode == .concurrent_load) {
                    var claim_ops: [8]p.DataLifecycle.Operation = undefined;
                    var ack_ops: [8]p.DataLifecycle.Operation = undefined;
                    const worker_count: usize = self.config.workers;
                    for (0..worker_count) |w| {
                        claim_ops[w] = self.operation();
                        ack_ops[w] = self.operation();
                        try self.saveRequest(.{ .claim = .{ .target = declared.target, .operation = claim_ops[w], .maximum = 1, .lease_ms = 60000, .predicate = null } }, null);
                    }
                    var futures: [8]std.Io.Future(@typeInfo(@TypeOf(ConcurrentConsumer.run)).@"fn".return_type.?) = undefined;
                    for (0..worker_count) |w| {
                        futures[w] = try self.init.io.concurrent(ConcurrentConsumer.run, .{ self.init, self.caller.service_url, self.caller.connection, self.config.keys, declared.target, claim_ops[w], ack_ops[w] });
                    }
                    var results: [8]ConcurrentWorkerResult = undefined;
                    var worker_err: ?anyerror = null;
                    for (0..worker_count) |w| {
                        if (futures[w].await(self.init.io)) |res| {
                            results[w] = res;
                        } else |err| {
                            if (worker_err == null) worker_err = err;
                        }
                    }
                    if (worker_err) |err| return err;
                    for (0..worker_count) |w| {
                        const res = results[w];
                        try self.saveReceipt(claim_ops[w].operation, res.claim_receipt);
                        try self.saveRequest(res.ack_request, null);
                        try self.saveReceipt(ack_ops[w].operation, res.ack_receipt);
                        for ([_]struct { action: []const u8, sample: ConcurrentSample }{
                            .{ .action = "claim", .sample = res.claim_sample },
                            .{ .action = "page", .sample = res.page_sample },
                            .{ .action = "settle", .sample = res.ack_sample },
                        }) |entry| {
                            self.serial += 1;
                            try emit(self.init, self.out, .{ .event = "attempt", .profile = self.config.id, .serial = self.serial, .stage = self.stage, .action = entry.action });
                            try emit(self.init, self.out, .{ .event = "sample", .profile = self.config.id, .serial = self.serial, .stage = self.stage, .action = entry.action, .http_calls = entry.sample.http_calls, .ns = entry.sample.ns, .backing = entry.sample.counts, .client_peak_live_bytes = entry.sample.peak });
                        }
                        const hex = std.fmt.bytesToHex(res.sha256, .lower);
                        const single_offset = [_]u64{res.offset};
                        try emit(self.init, self.out, .{ .event = "readback", .profile = self.config.id, .stage = self.stage, .offsets = single_offset[0..], .sha256 = hex[0..] });
                    }
                } else {
                    var remaining = self.config.batch;
                    while (remaining != 0) {
                        const claim = (try self.mutate(.{ .claim = .{ .target = declared.target, .operation = self.operation(), .maximum = @min(remaining, self.config.claim), .lease_ms = 60000, .predicate = null } }, null)).claim;
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
                        _ = try self.streamRead(original.consume);
                        _ = try self.mutate(.{ .release = .{ .operation = self.operation(), .target = state.target, .read = original.consume.handle() } }, null);
                    }
                } else if (original == .claim) {
                    if (id < state.expired_claim_end) {
                        const page = (try self.call(.{ .page = .{ .cursor = .{ .receipt = original.claim, .next = 0 }, .limits = .{ .rows = 16, .encoded_bytes = 1024 * 1024 } } })).page;
                        try t.expectEqual(@as(usize, 1), page.rows.len);
                        try t.expectEqual(.acked, page.rows[0].lease.state);
                        try t.expectEqual(.fenced, page.rows[0].lease.liveness);
                        try t.expectEqual(@as(u64, 2), page.rows[0].lease.attempt);
                    } else {
                        try self.queueReadWithAttempt(original.claim, false, if (self.config.mode == .lease_expiry) 2 else null, null);
                    }
                    _ = try self.mutate(.{ .release = .{ .operation = self.operation(), .claim = original.claim } }, null);
                }
            }
            if (kind == .stream and self.config.mode == .consumer_group) {
                const total: u64 = (self.config.warmup + self.config.repeat) * self.config.batch;
                const group_obs = (try self.call(.{ .group = .{ .target = state.target, .id = 1 } })).group orelse return error.MissingConsumerGroup;
                try t.expectEqual(total, group_obs.next);
            }
        }
    };
}

fn emitOwnerBudgets(comptime kind: Kind, init: std.process.Init, config: Config, out: *std.Io.Writer) !void {
    const catalog_options: c.DirectCatalog.Options = .{};
    const limits = if (kind == .stream) catalog_options.logs.stream else catalog_options.logs.queue;
    try emit(init, out, .{ .event = "owner_budgets", .profile = config.id, .limits = .{
        .catalog_pages = catalog_options.resident_pages,
        .catalog_index_work_bytes = catalog_options.index_work_bytes,
        .partition_pages = limits.resident_pages,
        .partition_index_work_bytes = limits.index_work_bytes,
        .tail_slots = limits.tail.slots,
        .tail_borrow_slots = limits.tail.borrow_slots,
        .tail_slot_bytes = limits.tail.slot_bytes,
        .tail_resident_bytes = limits.tail.resident_bytes,
        .queue_candidate_objects = if (kind == .queue) limits.queue_candidate_objects else null,
        .queue_candidate_resident_bytes = if (kind == .queue) limits.queue_candidate_resident_bytes else null,
        .queue_deadline_rows = if (kind == .queue) limits.queue_deadline_rows else null,
        .queue_visibility_rows = if (kind == .queue) limits.queue_visibility_rows else null,
        .queue_affinity_rows = if (kind == .queue) limits.queue_affinity_rows else null,
    } });
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
        if (config.mode != .sealed_segment and config.mode != .lease_expiry) (try client.call(.initialize)).deinit();
        try write(init, state_path, try runner.measure(owner, path));
    }
    try emitOwnerBudgets(kind, init, config, out);
    try emit(init, out, .{ .event = "complete", .profile = config.id, .recovery = recover, .build_mode = @tagName(@import("builtin").mode) });
}

pub fn prepare(init: std.process.Init, client: c.DirectTableClient, owner: u64, path: []const u8, out: *std.Io.Writer) !void {
    var buffer: [1024]u8 = undefined;
    const config = try read(Config, init, try std.fmt.bufPrint(&buffer, "{s}.baseline.json", .{path}));
    defer config.deinit();
    try config.value.validate();
    (try client.call(.initialize)).deinit();
    var probe: Probe = .{ .parent = init.gpa };
    var caller = try data.Catalog.init(probe.allocator(), init.io, .{ .url = client.service.url, .connection = client.connection, .timeout_ms = 30000 }, @splat(29));
    defer caller.deinit();
    var output: std.heap.ArenaAllocator = .init(probe.allocator());
    defer output.deinit();
    switch (config.value.kind) {
        inline else => |kind| {
            var runner: Runner(kind) = .{ .init = init, .caller = &caller, .output = &output, .probe = &probe, .out = out, .directory = std.fs.path.dirname(path) orelse ".", .config = config.value, .next_operation = 800000 + @as(u64, config.value.id) * 100000 };
            try runner.preparePhase(owner, path);
        },
    }
}

pub fn expiryReady(init: std.process.Init, client: c.DirectTableClient, path: []const u8, out: *std.Io.Writer) !void {
    var buffer: [1024]u8 = undefined;
    const config = try read(Config, init, try std.fmt.bufPrint(&buffer, "{s}.baseline.json", .{path}));
    defer config.deinit();
    try config.value.validate();
    if (config.value.kind != .queue or config.value.mode != .lease_expiry) return error.InvalidBenchmarkProfile;
    var probe: Probe = .{ .parent = init.gpa };
    var caller = try data.Catalog.init(probe.allocator(), init.io, .{ .url = client.service.url, .connection = client.connection, .timeout_ms = 30000 }, @splat(29));
    defer caller.deinit();
    var output: std.heap.ArenaAllocator = .init(probe.allocator());
    defer output.deinit();
    var runner: Runner(.queue) = .{ .init = init, .caller = &caller, .output = &output, .probe = &probe, .out = out, .directory = std.fs.path.dirname(path) orelse ".", .config = config.value, .next_operation = 0, .emit_events = false };
    var prep_buf: [1024]u8 = undefined;
    const prep = try read(PrepState, init, try runner.prepPath(path, &prep_buf));
    defer prep.deinit();
    var ready = true;
    var id = prep.value.next_operation;
    while (id > prep.value.first_operation) {
        id -= 1;
        _ = output.reset(.retain_capacity);
        var req_buf: [1024]u8 = undefined;
        const saved = try read(c.DirectQueueClient.Saved, init, try runner.path(id, "request", &req_buf));
        defer saved.deinit();
        if (saved.value.work.work != .claim) continue;
        const observed = try caller.callQueue(&output, .{ .operation = saved.value.work.work });
        if (observed.value != .result or observed.value.result != .operation or observed.value.result.operation == null) {
            ready = false;
            break;
        }
        const claim = observed.value.result.operation.?.claim;
        const page_out = try caller.callQueue(&output, .{ .page = .{ .cursor = .{ .receipt = claim, .next = 0 }, .limits = .{ .rows = 1, .encoded_bytes = 8192 } } });
        if (page_out.value != .result or page_out.value.result != .page) {
            ready = false;
            break;
        }
        const row = page_out.value.result.page.rows[0];
        if (row.lease.state != .available or row.lease.liveness != .fenced) {
            ready = false;
            break;
        }
    }
    try emit(init, out, .{ .ready = ready });
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
