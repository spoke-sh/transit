//! Persistent public Zig SDK caller for the installed performance matrix.
const std = @import("std");
const data = @import("transit_data_client");
const c = @import("transit_catalog");
const q = @import("transit_query_direct");
const Config = struct { url: []const u8, service_url: []const u8, seed_file: []const u8, connection: c.DirectTableProtocol.Connection };
const Request = struct { operation: []const u8 = "", name: []const u8 = "", sql: []const u8 = "", id: []const u8 = "1", representation: enum { integer, text } = .integer, close: ?struct {} = null };
const Row = struct { id: i64, number: i64 = 0, text: []const u8 = "" };
const Result = struct {
    complete: bool = true,
    rows: ?u64 = null,
    columns: ?usize = null,
    changed: ?u64 = null,
    matched: ?u64 = null,
    digest: ?[]const u8 = null,
    first_row_ns: ?u64 = null,
    elapsed_ns: u64 = 0,
    import_ns: ?u64 = null,
    open_ns: ?u64 = null,
    runtime: ?[]const u8 = null,
    cpu_ns: ?u64 = null,
    peak_rss_bytes: ?u64 = null,
};

fn elapsed(io: std.Io, start: std.Io.Timestamp) u64 {
    return @intCast(@max(0, start.durationTo(std.Io.Clock.awake.now(io)).toNanoseconds()));
}
fn call(client: *data.Catalog, output: *std.heap.ArenaAllocator, action: c.DirectTableBridge.Action) !c.DirectTableBridge.Result {
    return switch ((try client.call(output, action)).value) {
        .result => |value| value,
        .failure => |failure| {
            std.debug.print("{{\"phase\":\"consumer_failure\",\"action\":\"{s}\",\"error_type\":\"{s}\",\"code\":\"{s}\"}}\n", .{ @tagName(action), @errorName(failure.cause), if (failure.protocol_error) |code| @tagName(code) else "none" });
            return failure.cause;
        },
    };
}

fn snapshotFailure(io: std.Io, client: *data.Catalog, output: *std.heap.ArenaAllocator, owner: c.DirectCatalogRetention.Owner, phase: []const u8) void {
    // Inspect only the original owner after failure. A later successful status
    // cannot turn this failed timing sample into success or select a new cut.
    const status = (call(client, output, .{ .retention = .{ .status = owner } }) catch return).retention.status;
    persist(io, output.allocator(), "snapshot-failure.json", status) catch return;
    std.debug.print("{{\"phase\":\"snapshot_failure\",\"operation\":\"{s}\",\"retained\":{},\"released\":{},\"retired\":{}}}\n", .{ phase, status.snapshot != null, status.released, status.retired });
}
fn persist(io: std.Io, allocator: std.mem.Allocator, name: []const u8, value: anytype) !void {
    const bytes = try c.protocol.Json.valueAlloc(allocator, value);
    const directory = try std.Io.Dir.cwd().openDir(io, ".", .{ .iterate = true });
    defer directory.close(io);
    var file = try directory.createFileAtomic(io, name, .{ .replace = true, .permissions = .fromMode(0o600) });
    defer file.deinit(io);
    try file.file.writeStreamingAll(io, bytes);
    try file.file.sync(io);
    try file.replace(io);
    if (std.c.fsync(directory.handle) != 0) return error.CheckpointSyncFailed;
}

fn execute(io: std.Io, client: *data.Catalog, query: *q.RelationalBridge.Session, output: *std.heap.ArenaAllocator, request: Request, started: std.Io.Timestamp) !Result {
    const allocator = output.allocator();
    if (std.mem.eql(u8, request.operation, "lookup")) {
        const value = (try call(client, output, .{ .lookup = .{ .namespace = 1, .name = request.name } })).metadata orelse return .{};
        return .{ .rows = try c.TableValues.unsigned(value.row_count), .columns = value.schema.columns.len };
    }
    if (std.mem.eql(u8, request.operation, "write")) {
        const work = (try call(client, output, .{ .compile = .{ .namespace = 1, .operation = request.id, .create_object = null, .sql = request.sql, .dialect = .transit, .ingestion = .point } })).compiled;
        try persist(io, allocator, "pending.json", work.saved);
        const original = (try call(client, output, .{ .stage = work.summary.id })).staged;
        try persist(io, allocator, "original.json", original);
        var observed = (try call(client, output, .{ .admit = original })).observation;
        for (0..128) |_| {
            if (observed != .rows) return error.ExpectedMutation;
            if (observed.rows != .admitted) break;
            observed = (try call(client, output, .{ .operation = .{ .reference = original, .command = .execute, .steps = 32 } })).observation;
        }
        if (observed != .rows or observed.rows != .committed) return error.IncompleteMutation;
        const committed = observed.rows.committed.outcome;
        return .{ .changed = try c.TableValues.unsigned(committed.affected), .matched = try c.TableValues.unsigned(committed.matched) };
    }
    if (!std.mem.eql(u8, request.operation, "query")) return error.UnsupportedBenchmarkOperation;
    const current = (try call(client, output, .{ .lookup = .{ .namespace = 1, .name = request.name } })).metadata orelse return error.MissingTable;
    const acquisition: c.DirectCatalogRetention.Acquisition = .{ .owner = .{
        .definition = c.protocol.Growth.current_definition,
        .connection = try c.DirectTableValues.Connection.foreign(allocator, client.connection),
        .object = current.binding.interpretation.interpretation.object,
        .operation = request.id,
    }, .expected = current.position };
    try persist(io, allocator, "pending.json", acquisition);
    const snapshot = (call(client, output, .{ .retention = .{ .acquire = acquisition } }) catch |err| {
        snapshotFailure(io, client, output, acquisition.owner, "acquire");
        return err;
    }).retention.acquired;
    try persist(io, allocator, "snapshot.json", snapshot);
    // On failure the saved acquisition/snapshot remains available to the driver.
    var release_attempted = false;
    errdefer if (!release_attempted) {
        _ = call(client, output, .{ .retention = .{ .release = snapshot } }) catch {
            snapshotFailure(io, client, output, acquisition.owner, "release");
        };
    };
    const identity = try std.fmt.allocPrint(allocator, "{x:0>32}", .{try c.TableValues.unsigned(request.id)});
    const opened = (try query.apply(allocator, .{ .open = .{ .id = identity, .statement = .{ .sql = request.sql, .routes = &.{0} }, .bindings = &.{current.binding}, .snapshots = &.{snapshot} } }, null)).opened;
    errdefer _ = query.apply(allocator, .{ .close = opened.reference }, null) catch {};
    var values: [1000]Row = undefined;
    var rows: u64 = 0;
    var first: ?u64 = null;
    var scratch: std.heap.ArenaAllocator = .init(client.allocator);
    defer scratch.deinit();
    while (rows <= 1000) {
        _ = scratch.reset(.retain_capacity);
        const page_allocator = scratch.allocator();
        const page = (try query.apply(page_allocator, .{ .page = .{ .reference = opened.reference, .ordinal = try c.TableValues.decimal(page_allocator, rows) } }, null)).page;
        if (page.row) |row| {
            if (first == null) first = elapsed(io, started);
            if (row.cells.len != 2) return error.UnexpectedSchema;
            if (rows == values.len) return error.ResultBudgetExceeded;
            const key = row.cells[0];
            const cell = row.cells[1];
            if (key != .value or key.value != .atom or key.value.atom != .signed or cell != .value or cell.value != .atom) return error.UnexpectedValue;
            var value: Row = .{ .id = try std.fmt.parseInt(i64, key.value.atom.signed, 10) };
            if (request.representation == .text) {
                if (cell.value.atom != .utf8 or cell.value.atom.utf8.len > 4096) return error.UnexpectedValue;
                // Pages borrow scratch; retain verified raw bytes before reset.
                value.text = try allocator.dupe(u8, cell.value.atom.utf8);
            } else {
                if (cell.value.atom != .signed) return error.UnexpectedValue;
                value.number = try std.fmt.parseInt(i64, cell.value.atom.signed, 10);
            }
            values[@intCast(rows)] = value;
            rows += 1;
        }
        if (page.complete_coverage) break;
        if (page.row == null) return error.IncompleteResult;
    } else return error.ResultBudgetExceeded;
    _ = try query.apply(allocator, .{ .close = opened.reference }, null);
    release_attempted = true;
    _ = call(client, output, .{ .retention = .{ .release = snapshot } }) catch |err| {
        snapshotFailure(io, client, output, acquisition.owner, "release");
        return err;
    };
    const ordered = values[0..@intCast(rows)];
    std.mem.sort(Row, ordered, request.representation == .text, struct {
        fn less(text: bool, a: Row, b: Row) bool {
            return a.id < b.id or (a.id == b.id and (if (text) std.mem.order(u8, a.text, b.text) == .lt else a.number < b.number));
        }
    }.less);
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    for (ordered) |value| {
        var bytes: [16]u8 = undefined;
        std.mem.writeInt(i64, bytes[0..8], value.id, .little);
        if (request.representation == .text) std.mem.writeInt(u64, bytes[8..16], value.text.len, .little) else std.mem.writeInt(i64, bytes[8..16], value.number, .little);
        hash.update(&bytes);
        if (request.representation == .text) hash.update(value.text);
    }
    return .{ .rows = rows, .digest = try allocator.dupe(u8, &std.fmt.bytesToHex(hash.finalResult(), .lower)), .first_row_ns = first };
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 2) return error.ExpectedConfiguration;
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, args[1], init.arena.allocator(), .limited(65536));
    const parsed_config = try c.protocol.Json.parseFromSliceOwned(Config, init.gpa, bytes);
    defer parsed_config.deinit();
    const config = parsed_config.value;
    const opening = std.Io.Clock.awake.now(init.io);
    var key = try c.client.readKey(init.gpa, init.io, config.seed_file);
    defer std.crypto.secureZero(u8, std.mem.asBytes(&key));
    var client = try data.Catalog.init(init.gpa, init.io, .{ .url = config.url, .service_url = config.service_url, .connection = config.connection, .timeout_ms = 10000 }, key.secret_key.seed());
    var client_closed = false;
    defer if (!client_closed) client.deinit();
    const direct: c.DirectTableClient = .{ .allocator = init.gpa, .authority = &client.authority, .service = &client.service, .connection = client.connection, .key = client.key };
    var query: q.RelationalBridge.Session = .{ .allocator = init.gpa, .io = init.io, .directory = .cwd(), .clients = &.{direct}, .options = .{ .consistency = .independent_table_snapshots, .budgets = .{ .resident_bytes = 16777216, .spill_bytes = 16777216, .result_bytes = 8388608, .output_rows = 1000, .work_steps = 100000, .source_pins = 2 }, .requests = 100000, .spill_work = 100000 } };
    defer query.deinit();
    const open_ns = elapsed(init.io, opening);
    var input_bytes: [8192]u8 = undefined;
    var input = std.Io.File.stdin().readerStreaming(init.io, &input_bytes);
    var output_bytes: [4096]u8 = undefined;
    var output = std.Io.File.stdout().writerStreaming(init.io, &output_bytes);
    try output.interface.writeAll("{\"ready\":true}\n");
    try output.interface.flush();
    var arena: std.heap.ArenaAllocator = .init(init.gpa);
    defer arena.deinit();
    while (try input.interface.takeDelimiter('\n')) |line| {
        _ = arena.reset(.retain_capacity);
        const request = try c.protocol.Json.parseFromSlice(Request, arena.allocator(), line);
        if (request.value.close != null) break;
        const started = std.Io.Clock.awake.now(init.io);
        var result = if (std.mem.eql(u8, request.value.operation, "info")) Result{ .open_ns = open_ns, .runtime = @import("builtin").zig_version_string } else try execute(init.io, &client, &query, &arena, request.value, started);
        result.elapsed_ns = elapsed(init.io, started);
        try std.json.Stringify.value(.{ .status = 0, .value = result }, .{}, &output.interface);
        try output.interface.writeByte('\n');
        try output.interface.flush();
    }
    // Explicitly finish through the owners before reporting joined close.
    query.deinit();
    client.deinit();
    client_closed = true;
    try output.interface.writeAll("{\"closed\":true}\n");
    try output.interface.flush();
}
