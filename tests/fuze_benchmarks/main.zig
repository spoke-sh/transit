//! Phase measurements over the real captured-file and Fuze implementations.
//! Retains at most eight rows; never materializes the source in resident memory.
const std = @import("std");
const f = @import("transit_fuze");
const Capture = @import("file_capture");
const Tracker = @import("Allocator.zig");
const Config = struct {
    paths: []const []const u8,
    options: f.FileSource.Options,
    schema_json: ?[]const u8 = null,
    gzip: bool = false,
    sql: []const u8 = "SELECT * FROM input",
    batch_rows: u8 = 8,
    export_iterations: u32 = 100,
    expected_rows: u64,
    expected_id_sum: ?i64 = null,
    expected_output_rows: u64,
};
const Counted = struct {
    capture: Capture,
    bytes: u64 = 0,
    reads: u64 = 0,
    fn read(ctx: *anyopaque, offset: u64, output: []u8) !usize {
        const self: *Counted = @ptrCast(@alignCast(ctx));
        const handle = self.capture.source();
        const n = try handle.read(handle.context, offset, output);
        self.bytes += n;
        self.reads += 1;
        return n;
    }
    fn source(self: *Counted) f.FileSource.Source {
        return .{ .context = self, .read = read, .check = Capture.check, .length = self.capture.length, .digest = self.capture.digest };
    }
};
const Meter = struct {
    io: std.Io,
    tracker: *Tracker,
    sources: []Counted,
    out: *std.Io.Writer,
    start: std.Io.Timestamp = undefined,
    cpu: i128 = 0,
    fn cpuTime() !i128 {
        var stamp: std.c.timespec = undefined;
        if (std.c.clock_gettime(.PROCESS_CPUTIME_ID, &stamp) != 0) return error.ClockFailed;
        return @as(i128, stamp.sec) * std.time.ns_per_s + stamp.nsec;
    }
    fn begin(self: *Meter) !void {
        self.tracker.reset();
        for (self.sources) |*source| {
            source.bytes = 0;
            source.reads = 0;
        }
        self.cpu = try cpuTime();
        self.start = std.Io.Clock.awake.now(self.io);
    }
    fn elapsed(self: Meter) i96 {
        return self.start.durationTo(std.Io.Clock.awake.now(self.io)).toNanoseconds();
    }
    fn end(self: *Meter, name: []const u8, rows: u64, export_bytes: u64, first_batch_ns: ?i96) !void {
        const ns = self.elapsed();
        const cpu_ns = try cpuTime() - self.cpu;
        var bytes: u64 = 0;
        var reads: u64 = 0;
        for (self.sources) |source| {
            bytes += source.bytes;
            reads += source.reads;
        }
        try emit(self.out, .{ .phase = name, .elapsed_ns = ns, .cpu_ns = cpu_ns, .rows = rows, .source_bytes_read = bytes, .source_read_calls = reads, .export_bytes = export_bytes, .first_batch_ns = first_batch_ns, .allocations = self.tracker.allocations, .resizes = self.tracker.resizes, .allocated_bytes = self.tracker.allocated_bytes, .peak_live_bytes = self.tracker.peak_bytes, .end_live_bytes = self.tracker.live_bytes });
    }
};
fn emit(out: *std.Io.Writer, value: anytype) !void {
    try std.json.Stringify.value(value, .{}, out);
    try out.writeByte('\n');
    try out.flush();
}
fn kernelFile(init: std.process.Init, path: []const u8) ![]const u8 {
    const file = try std.Io.Dir.cwd().openFile(init.io, path, .{});
    defer file.close(init.io);
    var buffer: [4096]u8 = undefined;
    var reader = file.readerStreaming(init.io, &buffer);
    return reader.interface.allocRemaining(init.arena.allocator(), .limited(4096));
}
fn cgroup(init: std.process.Init) !struct { path: []const u8, memory_max: []const u8, memory_swap_max: []const u8, memory_peak: []const u8, memory_events: []const u8, cpu_stat: []const u8 } {
    const a = init.arena.allocator();
    const membership = try kernelFile(init, "/proc/self/cgroup");
    if (!std.mem.startsWith(u8, membership, "0::/")) return error.ExpectedUnifiedCgroup;
    const path = std.mem.trim(u8, membership[3..], "\n");
    var values: [5][]const u8 = undefined;
    for ([_][]const u8{ "memory.max", "memory.peak", "memory.events", "cpu.stat", "memory.swap.max" }, &values) |name, *value| {
        const filename = try std.fmt.allocPrint(a, "/sys/fs/cgroup{s}/{s}", .{ path, name });
        value.* = std.mem.trim(u8, try kernelFile(init, filename), "\n");
    }
    return .{ .path = path, .memory_max = values[0], .memory_swap_max = values[4], .memory_peak = values[1], .memory_events = values[2], .cpu_stat = values[3] };
}
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 2) return error.ExpectedConfiguration;
    const config_bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, args[1], init.arena.allocator(), .limited(256 * 1024));
    const config = try std.json.parseFromSliceLeaky(Config, init.arena.allocator(), config_bytes, .{});
    if (config.paths.len == 0 or config.paths.len > 128 or config.batch_rows == 0 or config.batch_rows > 8 or config.export_iterations == 0 or config.export_iterations > 10000) return error.InvalidBenchmark;
    try config.options.validate();
    var tracker: Tracker = .{ .backing = init.gpa };
    defer std.debug.assert(tracker.live_bytes == 0);
    const a = tracker.allocator();
    var host = init;
    host.gpa = a;
    var stdout_buffer: [8192]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    var storage: [128]Counted = undefined;
    var count: usize = 0;
    defer for (storage[0..count]) |*capture| capture.capture.close();
    var meter: Meter = .{ .io = init.io, .tracker = &tracker, .sources = &.{}, .out = &stdout.interface };
    try meter.begin();
    var encoded_remaining = config.options.max_scan_bytes;
    var expanded_remaining = config.options.max_scan_bytes;
    for (config.paths) |path| {
        storage[count] = .{ .capture = try Capture.acquire(host, path, &encoded_remaining, &expanded_remaining, config.gzip) };
        count += 1;
    }
    try meter.end("capture", 0, 0, null);
    var sources: [128]f.FileSource.Source = undefined;
    for (storage[0..count], 0..) |*capture, i| {
        sources[i] = capture.source();
        try emit(meter.out, .{ .source = i, .length = capture.capture.length, .digest = std.fmt.bytesToHex(capture.capture.digest, .lower) });
    }
    meter.sources = storage[0..count];
    var declared: ?f.Types.Decoded = if (config.schema_json) |json| try f.LogicalJson.decodeType(a, json) else null;
    defer if (declared) |*owner| owner.deinit();
    const overrides = if (declared) |owner| owner.type.structure else &.{};
    try meter.begin();
    var binding = try f.FileSource.discover(a, sources[0..count], config.options, overrides);
    defer binding.deinit();
    try meter.end("discovery", binding.evidence.records, 0, null);
    const schema_json = try f.LogicalJson.encodeType(a, binding.schema.type);
    defer a.free(schema_json);
    try emit(meter.out, .{ .schema_json = schema_json, .binding = std.fmt.bytesToHex(binding.digest, .lower), .evidence = binding.evidence });
    try meter.begin();
    var plan = try f.FileQuery.compile(a, config.sql, "input", &binding);
    defer plan.deinit();
    try meter.end("compile", 0, 0, null);
    var retained: [8]f.FileSource.Row = undefined;
    var retained_count: usize = 0;
    defer for (retained[0..retained_count]) |*row| row.deinit();
    try meter.begin();
    var scan = try f.FileSource.Scan.init(a, &binding, sources[0..count]);
    defer scan.deinit();
    var rows: u64 = 0;
    var sum: i64 = 0;
    var id_column: ?usize = null;
    if (config.expected_id_sum != null) {
        for (binding.schema.type.structure, 0..) |field, i| if (std.mem.eql(u8, field.name, "id")) {
            id_column = i;
            break;
        };
        if (id_column == null) return error.MissingIdColumn;
    }
    while (try scan.next()) |input| {
        var row = input;
        errdefer row.deinit();
        rows += 1;
        if (id_column) |index| {
            const cell = row.cells[index];
            if (cell != .value or cell.value != .atom or cell.value.atom != .signed) return error.InvalidIdType;
            sum = try std.math.add(i64, sum, std.math.cast(i64, cell.value.atom.signed) orelse return error.Overflow);
        }
        if (retained_count < config.batch_rows) {
            retained[retained_count] = row;
            retained_count += 1;
        } else row.deinit();
    }
    if (!scan.complete or rows != config.expected_rows or (config.expected_id_sum != null and sum != config.expected_id_sum.?)) return error.IncorrectScanResult;
    try meter.end("scan_convert", rows, 0, null);
    // Export isolates the codec on one bounded predecoded batch. It does not
    // stand for end-to-end output throughput or a retained whole-source cache.
    var batch: [8]f.LogicalArrow.Row = undefined;
    for (retained[0..retained_count], batch[0..retained_count]) |row, *target| target.* = .{ .cells = row.cells };
    const workspace = try a.alloc(u8, f.LogicalArrow.working_bytes);
    defer a.free(workspace);
    const output = try a.alloc(u8, f.LogicalArrow.segment_bytes);
    defer a.free(output);
    try meter.begin();
    var exported: u64 = 0;
    for (0..config.export_iterations) |_| {
        const ipc = try f.LogicalArrow.encode(binding.schema.type, batch[0..retained_count], workspace, output);
        exported += ipc.len;
        std.mem.doNotOptimizeAway(ipc);
    }
    try meter.end("export_cached_batch", @as(u64, retained_count) * config.export_iterations, exported, null);
    for (retained[0..retained_count]) |*row| row.deinit();
    retained_count = 0;
    try meter.begin();
    var execution = try f.FileQuery.Execution.init(a, &binding, sources[0..count], plan.plan);
    defer execution.deinit();
    var first_batch: ?i96 = null;
    while (try execution.next()) |input| {
        var row = input;
        std.mem.doNotOptimizeAway(row.cells);
        row.deinit();
        if (first_batch == null and execution.emitted == config.batch_rows) first_batch = meter.elapsed();
    }
    if (first_batch == null) first_batch = meter.elapsed();
    if (!execution.complete or execution.scanned != rows or execution.emitted != config.expected_output_rows) return error.IncorrectQueryResult;
    try meter.end("scan_convert_execute", execution.emitted, 0, first_batch);
    try emit(meter.out, .{ .complete = true, .scanned = rows, .id_sum = if (id_column != null) @as(?i64, sum) else null, .encoded_bytes = config.options.max_scan_bytes - encoded_remaining, .expanded_bytes = config.options.max_scan_bytes - expanded_remaining, .build_mode = @tagName(@import("builtin").mode), .cgroup = try cgroup(init) });
}
