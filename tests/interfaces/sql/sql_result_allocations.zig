//! Shared client against an independent finite-relation peer. This measures
//! client, transport and I/O ownership, not service computation or authority.
const std = @import("std");
const sql = @import("transit_sql_client");
const memory = @import("transit_memory");
const bounded_io = @import("transit_io");
extern "c" fn transit_allocation_begin() c_int;
extern "c" fn transit_allocation_end(*[4]u64) c_int;
extern "c" fn transit_allocation_negative() void;
fn negativeWorker() void {}

fn consume(executor: *sql.Executor, length: usize, wide: bool, retry: bool, prepared: bool) !void {
    var text: [80]u8 = undefined;
    const statement = try std.fmt.bufPrint(&text, "SELECT {d} {s} {s}", .{ length, if (wide) "wide" else "narrow", if (retry) "retry" else "once" });
    const bindings = [_]sql.results.fuze.LogicalJson.Atom{.{ .unsigned = "7" }};
    const outcome = try executor.execute(statement, if (prepared) &bindings else null, .{});
    defer outcome.deinit();
    if (outcome.value != .rows) return error.ExpectedRows;
    const result = &outcome.value.rows;
    if (result.schema != .structure or result.schema.structure.len != @as(usize, if (wide) 2 else 1)) return error.ChangedSchema;
    var count: usize = 0;
    while (try result.nextRow()) |row| {
        if (row.len != result.schema.structure.len or row[0] != .value or row[0].value.atom.unsigned != count) return error.ChangedValue;
        if (wide) {
            const bytes = row[1].value.atom.bytes;
            if (bytes.len != 24000 or !std.mem.allEqual(u8, bytes, 'a' + @as(u8, @intCast(count % 26)))) return error.ChangedValue;
        }
        count += 1;
    }
    if (count != length or result.completion() == null or result.completion().?.rows != length) return error.IncompleteRelation;
}
fn capacity(executor: *sql.Executor) !void {
    var retained: [4]sql.Response = undefined;
    var count: usize = 0;
    defer for (retained[0..count]) |response| response.deinit();
    for (&retained) |*response| {
        response.* = try executor.client.call(.touch);
        count += 1;
    }
    if (executor.execute("SET allocation_probe", null, .{})) |unexpected| {
        unexpected.deinit();
        return error.ExpectedCapacityRefusal;
    } else |err| if (err != error.SqlResponseCapacity) return err;
    for (retained) |response| {
        try response.validate();
        if (response.value.result != .closed) return error.ChangedRetainedResponse;
    }
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 3 and args.len != 4) return error.ExpectedEndpointAndCa;
    const negative = args.len == 4 and std.mem.eql(u8, args[3], "negative");
    var probe: memory.AllocationProbe = .{ .parent = init.gpa };
    const runtime = try bounded_io.Threaded.create(probe.allocator(), .{ .workers = 8, .task_bytes = 1024 * 1024, .environ = init.minimal.environ, .argv0 = .init(init.minimal.args) });
    defer runtime.destroy();
    const io = runtime.io();
    const config: sql.Client.Config = .{
        .endpoint = args[1],
        .authentication = if (std.mem.startsWith(u8, args[1], "unix:")) .peer else .trust,
        .ca_file = if (args[2].len == 0) null else args[2],
        .request_timeout_ms = 5000,
    };
    var client = try sql.Client.init(probe.allocator(), io, config);
    defer client.deinit();
    try client.open(config, null);
    var pinned = config;
    pinned.instance = client.instance;
    var control = try sql.Client.init(probe.allocator(), io, pinned);
    defer control.deinit();
    control.session = client.session;
    control.account = client.account;
    var executor: sql.Executor = .{ .client = &client, .control = &control, .config = config };
    // Handshake, first TLS connection and finite worker admission are setup.
    try consume(&executor, 1, false, false, false);
    try std.Io.File.stdout().writeStreamingAll(io, "allocation_begin\n");
    probe.begin(true);
    if (transit_allocation_begin() != 0) return error.UnsupportedAllocationObserver;
    const statements: usize = if (negative) 0 else 300;
    if (negative) {
        transit_allocation_negative();
        const page = try std.heap.page_allocator.alloc(u8, 2 * 1024 * 1024);
        @memset(page, 0xa5);
        std.mem.doNotOptimizeAway(page);
        std.heap.page_allocator.free(page);
        const worker = try std.Thread.spawn(.{}, negativeWorker, .{});
        worker.join();
    }
    const retained = if (negative) null else try executor.execute("SET allocation_probe", null, .{});
    defer if (retained) |outcome| outcome.deinit();
    if (!negative) try capacity(&executor);
    for (0..statements) |iteration| {
        if (iteration == 250) try io.sleep(.fromMilliseconds(600), .awake);
        const length = ([_]usize{ 0, 1, 31, 32, 33, 70 })[iteration % 6];
        try consume(&executor, length, iteration % 7 == 0, iteration == 299, iteration % 10 == 0);
        if (retained.?.value != .command or retained.?.value.command.kind != .set or
            retained.?.value.command.outcome != .applied or retained.?.value.command.counts != null)
            return error.ChangedRetainedCompletion;
    }
    var libc: [4]u64 = undefined;
    if (transit_allocation_end(&libc) != 0) return error.UnsupportedAllocationObserver;
    try std.Io.File.stdout().writeStreamingAll(io, "allocation_end\n");
    const report = try std.json.Stringify.valueAlloc(init.gpa, .{
        .profile = "shared_sql_client_allocations",
        .statements = statements,
        .negative_control = negative,
        .libc_attempts = libc,
        .backing = probe.counts,
        .reserved_bytes = probe.live_bytes,
        .requested_stack_bytes = runtime.workers * runtime.stack_bytes,
        .scope = "Independent peer; client, numeric-endpoint HTTP/TLS or Unix, typed binary decoding, changing schemas, same-ordinal retries, idle replacement and connection turnover. Includes bounded I/O tasks and interposable libc calls, paired with the driver mapping observer. Excludes service computation, authority and hostname resolution.",
    }, .{});
    defer init.gpa.free(report);
    try std.Io.File.stdout().writeStreamingAll(io, report);
    try std.Io.File.stdout().writeStreamingAll(io, "\n");
    try probe.verify();
    if (!negative and !std.mem.allEqual(u64, &libc, 0)) return error.UnexpectedLibcAllocation;
}
