//! Domain-neutral, opt-in instrumentation. No globals, import-time I/O or exporter.
const std = @import("std");
pub const Context = @import("Context.zig");
pub const Http = @import("Http.zig");
const Atomic = std.atomic.Value(u64);
pub const Level = enum { debug, info, warn, err, off };
pub const Format = enum { text, json };
pub const Scope = enum { service, server, client, storage, maintenance, runtime, application };
pub const Outcome = enum { ok, rejected, conflict, failed, timeout, canceled, uncertain, idle };
pub const ProtocolOutcome = enum { none, read, receipt, rejected, uncertain };
pub const Config = struct {
    level: Level = .info,
    format: Format = .text,

    pub fn environment(env: *const std.process.Environ.Map) !Config {
        var config: Config = .{};
        if (env.get("LOG_LEVEL")) |value| config.level = if (std.mem.eql(u8, value, "error")) .err else std.meta.stringToEnum(Level, value) orelse return error.InvalidLogLevel;
        if (env.get("LOG_FORMAT")) |value| config.format = std.meta.stringToEnum(Format, value) orelse return error.InvalidLogFormat;
        return config;
    }
};

/// Only fixed vocabulary/static route templates and compiler error names belong
/// in string fields. Never pass request data, configuration, payloads or secrets.
pub const Event = struct {
    name: []const u8,
    operation: ?[]const u8 = null,
    level: Level = .info,
    outcome: Outcome = .ok,
    error_type: ?[]const u8 = null,
    route: ?[]const u8 = null,
    method: ?[]const u8 = null,
    status: ?u16 = null,
    response_written: ?bool = null,
    protocol_outcome: ProtocolOutcome = .none,
    realm: ?u64 = null,
    pid: ?u64 = null,
    generation: ?u64 = null,
    binding_revision: ?u64 = null,
    sequence: ?u64 = null,
    position: ?u64 = null,
};
pub const bucket_ns = [_]u64{ 1_000_000, 5_000_000, 10_000_000, 50_000_000, 100_000_000, 500_000_000, 1_000_000_000, 5_000_000_000, std.math.maxInt(u64) };
const scope_count = @typeInfo(Scope).@"enum".field_names.len;
const outcome_count = @typeInfo(Outcome).@"enum".field_names.len;
const Meter = struct {
    active: Atomic = .init(0),
    outcomes: [outcome_count]Atomic = @splat(.init(0)),
    buckets: [bucket_ns.len]Atomic = @splat(.init(0)),
    duration_ns: Atomic = .init(0),
};
pub const Snapshot = struct {
    active: u64,
    outcomes: [outcome_count]u64,
    buckets: [bucket_ns.len]u64,
    duration_seconds: f64,

    /// Keep fixed arrays for collection, but make every serialized count named.
    pub fn jsonStringify(self: Snapshot, out: anytype) !void {
        try out.beginObject();
        try out.objectField("active");
        try out.write(self.active);
        try out.objectField("outcomes");
        try out.beginObject();
        inline for (std.meta.tags(Outcome)) |outcome| {
            try out.objectField(@tagName(outcome));
            try out.write(self.outcomes[@backingInt(outcome)]);
        }
        try out.endObject();
        try out.objectField("buckets");
        try out.write(.{
            .le_1ms = self.buckets[0],
            .gt_1ms_le_5ms = self.buckets[1],
            .gt_5ms_le_10ms = self.buckets[2],
            .gt_10ms_le_50ms = self.buckets[3],
            .gt_50ms_le_100ms = self.buckets[4],
            .gt_100ms_le_500ms = self.buckets[5],
            .gt_500ms_le_1s = self.buckets[6],
            .gt_1s_le_5s = self.buckets[7],
            .gt_5s = self.buckets[8],
        });
        try out.objectField("duration_seconds");
        try out.write(self.duration_seconds);
        try out.endObject();
    }
};
const Record = struct { bytes: [2048]u8 = undefined, len: usize = 0 };

pub const Runtime = struct {
    io: std.Io,
    service: []const u8,
    config: Config,
    instance: [16]u8,
    serial: Atomic = .init(0),
    meters: [scope_count]Meter = @splat(.{}),
    dropped: Atomic = .init(0),
    suppressed: Atomic = .init(0),
    sink_errors: Atomic = .init(0),
    writer: ?std.Io.Future(void) = null,
    sink: std.Io.File = .stderr(),
    sink_failed: std.atomic.Value(bool) = .init(false),
    busy: std.atomic.Value(bool) = .init(false),
    mutex: std.Io.Mutex = .init,
    queue: [128]Record = undefined,
    head: usize = 0,
    len: usize = 0,
    rate_second: i64 = 0,
    normal_count: usize = 0,
    important_count: usize = 0,

    pub fn init(io: std.Io, comptime service: []const u8, config: Config) Runtime {
        var instance: [16]u8 = undefined;
        io.random(&instance);
        return .{ .io = io, .service = service, .config = config, .instance = instance };
    }

    /// Runtime must remain at the same address until stop; failure to obtain a
    /// writer is a telemetry failure, never an application startup dependency.
    pub fn start(self: *Runtime) void {
        if (self.config.level == .off) return;
        self.writer = self.io.concurrent(drain, .{self}) catch {
            self.sink_failed.store(true, .release);
            _ = self.sink_errors.fetchAdd(1, .monotonic);
            return;
        };
    }

    /// Stop producers first. At most 200ms is spent trying to flush before
    /// canceling/joining the writer; supported I/O must make writes cancelable.
    pub fn stop(self: *Runtime) void {
        if (self.writer) |*future| {
            const until = std.Io.Clock.awake.now(self.io).toMilliseconds() + 200;
            while (std.Io.Clock.awake.now(self.io).toMilliseconds() < until) {
                if (self.mutex.tryLock()) {
                    const empty = self.len == 0 and !self.busy.load(.acquire);
                    self.mutex.unlock(self.io);
                    if (empty) break;
                }
                self.io.sleep(.fromMilliseconds(5), .awake) catch break;
            }
            future.cancel(self.io);
            self.writer = null;
        }
    }

    pub fn snapshot(self: *const Runtime, scope: Scope) Snapshot {
        const meter = &self.meters[@backingInt(scope)];
        var result: Snapshot = .{ .active = meter.active.load(.monotonic), .outcomes = undefined, .buckets = undefined, .duration_seconds = @as(f64, @floatFromInt(meter.duration_ns.load(.monotonic))) / 1_000_000_000 };
        for (&result.outcomes, &meter.outcomes) |*dest, *source| dest.* = source.load(.monotonic);
        for (&result.buckets, &meter.buckets) |*dest, *source| dest.* = source.load(.monotonic);
        return result;
    }

    pub fn begin(self: *Runtime, scope: Scope, parent: ?Context) Span {
        const serial = self.serial.fetchAdd(1, .monotonic) +% 1;
        var hash: [32]u8 = undefined;
        var h = std.crypto.hash.sha2.Sha256.init(.{});
        h.update(&self.instance);
        h.update(&std.mem.toBytes(std.mem.nativeToBig(u64, serial)));
        h.final(&hash);
        var context: Context = .{ .trace_id = hash[0..16].*, .span_id = hash[16..24].*, .parent_span_id = null };
        if (std.mem.allEqual(u8, &context.trace_id, 0)) context.trace_id[15] = 1;
        if (std.mem.allEqual(u8, &context.span_id, 0)) context.span_id[7] = 1;
        if (parent) |p| {
            context.trace_id = p.trace_id;
            context.parent_span_id = p.span_id;
        }
        _ = self.meters[@backingInt(scope)].active.fetchAdd(1, .monotonic);
        return .{ .runtime = self, .scope = scope, .context = context, .started = std.Io.Clock.awake.now(self.io) };
    }

    pub fn event(self: *Runtime, value: Event) void {
        self.emit(.service, null, null, value);
    }

    fn enabled(self: *const Runtime, level: Level) bool {
        return self.config.level != .off and level != .off and @backingInt(level) >= @backingInt(self.config.level);
    }

    fn emit(self: *Runtime, scope: Scope, context: ?Context, duration_ns: ?u64, value: Event) void {
        if (!self.enabled(value.level)) return;
        var record: Record = .{};
        var output: std.Io.Writer = .fixed(&record.bytes);
        const now = std.Io.Clock.real.now(self.io).toMilliseconds();
        if (self.config.format == .text) output.print("[{s}] {s} {s} ", .{ self.service, @tagName(value.level), value.name }) catch {};
        const instance = std.fmt.bytesToHex(self.instance, .lower);
        const trace = if (context) |c| std.fmt.bytesToHex(c.trace_id, .lower) else @as([32]u8, @splat(0));
        const span = if (context) |c| std.fmt.bytesToHex(c.span_id, .lower) else @as([16]u8, @splat(0));
        const parent = if (context) |c| if (c.parent_span_id) |p| std.fmt.bytesToHex(p, .lower) else @as([16]u8, @splat(0)) else @as([16]u8, @splat(0));
        std.json.Stringify.value(.{
            .schema_version = 1,
            .service_name = self.service,
            .service_instance_id = instance[0..],
            .time_unix_ms = now,
            .scope = scope,
            .duration_ns = duration_ns,
            .trace_id = if (context != null) @as(?[]const u8, &trace) else null,
            .span_id = if (context != null) @as(?[]const u8, &span) else null,
            .parent_span_id = if (context != null and context.?.parent_span_id != null) @as(?[]const u8, &parent) else null,
            .event = value,
        }, .{ .emit_null_optional_fields = false }, &output) catch {
            _ = self.dropped.fetchAdd(1, .monotonic);
            return;
        };
        output.writeByte('\n') catch {
            _ = self.dropped.fetchAdd(1, .monotonic);
            return;
        };
        record.len = output.end;
        self.enqueue(record, @backingInt(value.level) >= @backingInt(Level.warn));
    }

    fn enqueue(self: *Runtime, record: Record, important: bool) void {
        if (self.sink_failed.load(.acquire) or !self.mutex.tryLock()) {
            _ = self.dropped.fetchAdd(1, .monotonic);
            return;
        }
        defer self.mutex.unlock(self.io);
        const second = @divFloor(std.Io.Clock.awake.now(self.io).toMilliseconds(), 1000);
        if (second != self.rate_second) {
            self.rate_second = second;
            self.normal_count = 0;
            self.important_count = 0;
        }
        const count = if (important) &self.important_count else &self.normal_count;
        if (count.* >= (if (important) @as(usize, 20) else 200)) {
            _ = self.suppressed.fetchAdd(1, .monotonic);
            return;
        }
        count.* += 1;
        if (self.len >= (if (important) @as(usize, 128) else 112)) {
            _ = self.dropped.fetchAdd(1, .monotonic);
            return;
        }
        self.queue[(self.head + self.len) % self.queue.len] = record;
        self.len += 1;
    }

    fn pop(self: *Runtime) ?Record {
        if (!self.mutex.tryLock()) return null;
        defer self.mutex.unlock(self.io);
        if (self.len == 0) return null;
        const result = self.queue[self.head];
        self.head = (self.head + 1) % self.queue.len;
        self.len -= 1;
        self.busy.store(true, .release);
        return result;
    }

    fn report(self: *Runtime, level: Level, comptime name: []const u8, value: anytype) !void {
        if (!self.enabled(level)) return;
        var buffer: [2048]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&buffer);
        const instance = std.fmt.bytesToHex(self.instance, .lower);
        if (self.config.format == .text) try writer.print("[{s}] {s} {s} ", .{ self.service, @tagName(level), name });
        try std.json.Stringify.value(.{ .schema_version = if (comptime std.mem.eql(u8, name, "telemetry.metrics")) @as(u8, 2) else @as(u8, 1), .service_name = self.service, .service_instance_id = instance[0..], .time_unix_ms = std.Io.Clock.real.now(self.io).toMilliseconds(), .level = level, .name = name, .measurement = value }, .{}, &writer);
        try writer.writeByte('\n');
        try self.sink.writeStreamingAll(self.io, writer.buffered());
    }

    fn reportMetrics(self: *Runtime) !void {
        if (!self.enabled(.debug)) return;
        inline for (0..scope_count) |index| {
            const scope: Scope = @fromBackingInt(@intCast(index));
            const value = self.snapshot(scope);
            var count: u64 = 0;
            for (value.outcomes) |n| count +%= n;
            if (count != 0 or value.active != 0) try self.report(.debug, "telemetry.metrics", .{ .scope = scope, .snapshot = value });
        }
    }

    fn drain(self: *Runtime) void {
        self.drainLoop() catch |err| {
            self.busy.store(false, .release);
            if (err != error.Canceled) {
                self.sink_failed.store(true, .release);
                _ = self.sink_errors.fetchAdd(1, .monotonic);
            }
        };
    }

    fn drainLoop(self: *Runtime) !void {
        var last_dropped: u64 = 0;
        var last_suppressed: u64 = 0;
        var reported_at = std.Io.Clock.awake.now(self.io).toMilliseconds();
        while (true) {
            if (self.pop()) |record| {
                try self.sink.writeStreamingAll(self.io, record.bytes[0..record.len]);
                self.busy.store(false, .release);
            } else try self.io.sleep(.fromMilliseconds(10), .awake);
            const dropped = self.dropped.load(.monotonic);
            const suppressed = self.suppressed.load(.monotonic);
            if (dropped != last_dropped or suppressed != last_suppressed) {
                try self.report(.warn, "telemetry.loss", .{ .dropped = dropped, .suppressed = suppressed });
                last_dropped = dropped;
                last_suppressed = suppressed;
            }
            const now = std.Io.Clock.awake.now(self.io).toMilliseconds();
            if (now - reported_at >= 30000) {
                try self.reportMetrics();
                reported_at = now;
            }
        }
    }
};

pub const Span = struct {
    runtime: ?*Runtime = null,
    scope: Scope = .service,
    context: ?Context = null,
    started: std.Io.Timestamp = undefined,
    finished: bool = false,

    pub fn finish(self: *Span, value: Event) void {
        if (self.finished) return;
        self.finished = true;
        const runtime = self.runtime orelse return;
        const elapsed: u64 = @intCast(@max(0, self.started.durationTo(std.Io.Clock.awake.now(runtime.io)).toNanoseconds()));
        const meter = &runtime.meters[@backingInt(self.scope)];
        _ = meter.active.fetchSub(1, .monotonic);
        _ = meter.outcomes[@backingInt(value.outcome)].fetchAdd(1, .monotonic);
        _ = meter.duration_ns.fetchAdd(elapsed, .monotonic);
        for (bucket_ns, 0..) |limit, index| if (elapsed <= limit) {
            _ = meter.buckets[index].fetchAdd(1, .monotonic);
            break;
        };
        runtime.emit(self.scope, self.context, elapsed, value);
    }
};

pub fn begin(runtime: ?*Runtime, scope: Scope, parent: ?Context) Span {
    return if (runtime) |r| r.begin(scope, parent) else .{};
}

test "bounded queue reserves errors; independent metrics survive drops and filtering" {
    var runtime = Runtime.init(std.testing.io, "test", .{ .format = .json });
    for (0..160) |_| {
        var span = runtime.begin(.server, null);
        span.finish(.{ .name = "http.request", .route = "/fixed", .outcome = .ok });
    }
    try std.testing.expectEqual(112, runtime.len);
    try std.testing.expect(runtime.dropped.load(.monotonic) > 0);
    runtime.event(.{ .name = "service.failure", .level = .err, .outcome = .failed });
    try std.testing.expectEqual(113, runtime.len);
    try std.testing.expectEqual(160, runtime.snapshot(.server).outcomes[@backingInt(Outcome.ok)]);
    runtime.config.level = .off;
    var span = runtime.begin(.client, null);
    span.finish(.{ .name = "client.request", .outcome = .timeout });
    span.finish(.{ .name = "ignored" });
    try std.testing.expectEqual(1, runtime.snapshot(.client).outcomes[@backingInt(Outcome.timeout)]);
    try std.testing.expectEqual(0, runtime.snapshot(.client).active);
}

test "completed spans correlate distinct operations and never borrow event buffers" {
    var runtime = Runtime.init(std.testing.io, "test", .{ .format = .json });
    var parent = runtime.begin(.server, null);
    var child = runtime.begin(.client, parent.context);
    try std.testing.expectEqual(parent.context.?.trace_id, child.context.?.trace_id);
    try std.testing.expectEqual(parent.context.?.span_id, child.context.?.parent_span_id.?);
    try std.testing.expect(!std.mem.eql(u8, &parent.context.?.span_id, &child.context.?.span_id));
    child.finish(.{ .name = "client.request", .error_type = "quote\"\n", .outcome = .failed });
    parent.finish(.{ .name = "http.request" });
    const record = runtime.pop().?;
    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, record.bytes[0..record.len], .{});
    defer parsed.deinit();
    try std.testing.expectEqualStrings("quote\"\n", parsed.value.object.get("event").?.object.get("error_type").?.string);
    _ = Context;
    _ = Http;
}

test "failed response write cannot erase known receipt; restart resets local counters" {
    var runtime = Runtime.init(std.testing.io, "test", .{ .format = .json });
    var request: Http = .{ .span = runtime.begin(.server, null), .status = 200, .protocol_outcome = .receipt, .position = 7 };
    request.finish("http.request", error.WriteFailed, false, false);
    const record = runtime.pop().?;
    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, record.bytes[0..record.len], .{});
    defer parsed.deinit();
    const event = parsed.value.object.get("event").?.object;
    try std.testing.expectEqualStrings("failed", event.get("outcome").?.string);
    try std.testing.expectEqualStrings("receipt", event.get("protocol_outcome").?.string);
    try std.testing.expectEqual(7, event.get("position").?.integer);
    try std.testing.expect(!event.get("response_written").?.bool);
    try std.testing.expectEqual(1, runtime.snapshot(.server).outcomes[@backingInt(Outcome.failed)]);
    const restarted = Runtime.init(std.testing.io, "test", .{ .format = .json });
    try std.testing.expect(!std.mem.eql(u8, &runtime.instance, &restarted.instance));
    try std.testing.expectEqual(0, restarted.snapshot(.server).outcomes[@backingInt(Outcome.failed)]);
}

test "periodic metrics honor log level while measurement continues" {
    const io = std.testing.io;
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    for ([_]Format{ .json, .text }) |format| {
        for (std.meta.tags(Level)) |level| {
            const file = try temporary.dir.createFile(io, "reports.log", .{});
            defer file.close(io);
            var runtime = Runtime.init(io, "test", .{ .level = level, .format = format });
            runtime.sink = file;
            var span = runtime.begin(.maintenance, null);
            span.finish(.{ .name = "maintenance.step", .outcome = .idle, .level = .debug });
            try runtime.reportMetrics();
            try runtime.report(.warn, "telemetry.loss", .{ .dropped = 1, .suppressed = 2 });
            const output = try temporary.dir.readFileAlloc(io, "reports.log", std.testing.allocator, .limited(4096));
            defer std.testing.allocator.free(output);
            try std.testing.expectEqual(1, runtime.snapshot(.maintenance).outcomes[@backingInt(Outcome.idle)]);
            try std.testing.expectEqual(level == .debug, std.mem.indexOf(u8, output, "telemetry.metrics") != null);
            try std.testing.expectEqual(level == .debug or level == .info or level == .warn, std.mem.indexOf(u8, output, "telemetry.loss") != null);
            if (level != .debug) continue;
            if (format == .text) try std.testing.expect(std.mem.startsWith(u8, output, "[test] debug telemetry.metrics "));
            const json_start = std.mem.indexOfScalar(u8, output, '{').?;
            const json_end = std.mem.indexOfScalar(u8, output, '\n').?;
            var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, output[json_start..json_end], .{});
            defer parsed.deinit();
            const report = parsed.value.object;
            try std.testing.expectEqual(2, report.get("schema_version").?.integer);
            try std.testing.expectEqualStrings("debug", report.get("level").?.string);
            const snapshot_value = report.get("measurement").?.object.get("snapshot").?.object;
            try std.testing.expectEqual(8, snapshot_value.get("outcomes").?.object.count());
            try std.testing.expectEqual(1, snapshot_value.get("outcomes").?.object.get("idle").?.integer);
            try std.testing.expectEqual(9, snapshot_value.get("buckets").?.object.count());
            try std.testing.expect(snapshot_value.get("buckets").?.object.contains("gt_1ms_le_5ms"));
        }
    }
}
