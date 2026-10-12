//! Interactive general Table SELECT. Rows are typed, independently owned and
//! emitted as incomplete prefixes until the captured query verifies completion.
const std = @import("std");
const q = @import("transit_query");
const c = @import("transit_catalog");
const Console = @import("Console.zig").Console;
const Signals = @import("Signals.zig");
const Timing = @import("Timing.zig");
const Output = @import("Output.zig");
pub fn explain(console: *Console, catalog: *c.TableClient, statement: []const u8, start: usize) !void {
    var bytes: [16384]u8 = undefined;
    var stream = Output.Stream.init(console.init.io, console.out, &bytes);
    explainTo(console, catalog, statement, start, &stream) catch |err| return stream.failure orelse err;
}
fn explainTo(console: *Console, catalog: *c.TableClient, statement: []const u8, start: usize, stream: *Output.Stream) !void {
    if (try q.fuze.RelationalSql.required(statement[start..])) return @import("ConsoleRelational.zig").run(console, catalog, statement, start, true, stream);
    Signals.cancellation.store(false, .release);
    if (Signals.interrupted()) return error.ConsoleInterrupted;
    var nonce: [16]u8 = undefined;
    try console.init.io.randomSecure(&nonce);
    var location: q.fuze.Sql.Location = .{};
    var query = q.TableQuery.open(console.init.gpa, catalog, statement[start..], nonce, console.table_limits, &Signals.cancellation, &location) catch |err| {
        location.offset += @intCast(start);
        try compilationFailure(console, catalog, statement, "table_explain", err, location);
        return err;
    };
    defer query.deinit();
    var fields: [q.fuze.TableSchema.max_columns]q.fuze.Types.Field = undefined;
    const schema = try query.schema(&fields);
    const plan = query.compiled.plan;
    const basis = std.fmt.bytesToHex(plan.source_basis, .lower);
    const fingerprint = std.fmt.bytesToHex(query.execution.fingerprint, .lower);
    const object = query.sourceObject();
    try query.close();
    var arena: std.heap.ArenaAllocator = .init(console.init.gpa);
    defer arena.deinit();
    const out = &stream.interface;
    if (console.session.format == .json) {
        try std.json.Stringify.value(.{ .explanation = .{
            .object = try std.fmt.allocPrint(arena.allocator(), "{d}", .{object}),
            .basis = &basis,
            .plan = &fingerprint,
            .scan = if (query.execution.scan.point != null) "primary_key" else "finite",
            .filter = plan.predicate != .all,
            .aggregate = @tagName(plan.aggregate),
            .limit = if (plan.limit) |limit| try std.fmt.allocPrint(arena.allocator(), "{d}", .{limit}) else null,
            .schema = q.fuze.LogicalJson.TypeEnvelope{ .definition = q.fuze.Types.definition, .type = schema },
            .executed = false,
        } }, .{}, out);
        try out.writeByte('\n');
    } else {
        try out.print("Proposed Table plan; object: {d}\n{s} scan", .{ object, if (query.execution.scan.point != null) "Primary key" else "Finite" });
        if (plan.predicate != .all) try out.writeAll(" -> filter");
        if (plan.limit) |limit| try out.print(" -> limit {d}", .{limit});
        try out.print(" -> {s}\n", .{if (plan.aggregate == .rows) "projection" else @tagName(plan.aggregate)});
        try @import("Results.zig").logicalTable(arena.allocator(), out, schema, &.{});
        try out.writeAll("No rows executed. A later SELECT captures its own source basis.\n");
    }
    try stream.flush();
}
pub fn sql(console: *Console, catalog: *c.TableClient, request: @import("SqlInput.zig").Request) !void {
    var bytes: [16384]u8 = undefined;
    var stream = Output.Stream.init(console.init.io, console.out, &bytes);
    sqlTo(console, catalog, request, &stream) catch |err| return stream.failure orelse err;
}
fn sqlTo(console: *Console, catalog: *c.TableClient, request: @import("SqlInput.zig").Request, stream: *Output.Stream) !void {
    if (request.parameters != null or !console.interactive) {
        console.diagnostic.sql = q.fuze.SqlDiagnostic.query(request.sql, error.UnsupportedConstruct, true);
        if (console.diagnostic.sql) |*detail| detail.hint = "General Table SELECT uses interactive execution and typed SQL constants. Select execution: interactive; parameterized and durable Table query paths require their own admission profile.";
        return error.UnsupportedConstruct;
    }
    if (try q.fuze.RelationalSql.required(request.sql)) return @import("ConsoleRelational.zig").run(console, catalog, request.sql, 0, false, stream);
    console.query_running = true;
    Signals.cancellation.store(false, .release);
    if (Signals.interrupted()) return error.ConsoleInterrupted;
    var timing = Timing.start(console.init, console.preferences.timing);
    timing.interactive = true;
    defer console.finishTiming(&timing);
    timing.enter(.open);
    var nonce: [16]u8 = undefined;
    try console.init.io.randomSecure(&nonce);
    var location: q.fuze.Sql.Location = .{};
    var query = q.TableQuery.open(console.init.gpa, catalog, request.sql, nonce, console.table_limits, &Signals.cancellation, &location) catch |err| {
        try compilationFailure(console, catalog, request.sql, "table_select", err, location);
        return err;
    };
    defer query.deinit();
    var fields: [q.fuze.TableSchema.max_columns]q.fuze.Types.Field = undefined;
    const schema = try query.schema(&fields);
    const source_basis = std.fmt.bytesToHex(query.compiled.plan.source_basis, .lower);
    const plan = std.fmt.bytesToHex(query.execution.fingerprint, .lower);
    const out = &stream.interface;
    if (console.session.format == .json) {
        try std.json.Stringify.value(.{ .profile = "table_snapshot_v1", .schema = q.fuze.LogicalJson.TypeEnvelope{ .definition = q.fuze.Types.definition, .type = schema }, .basis = &source_basis, .plan = &plan, .complete_coverage = false }, .{}, out);
        try out.writeByte('\n');
        try stream.flush();
    }
    var emitted: u64 = 0;
    var batch: [8]q.fuze.LogicalQuery.Row = undefined;
    var cells: [8][]const q.fuze.Types.Values.Cell = undefined;
    var count: usize = 0;
    defer for (batch[0..count]) |*row| row.deinit();
    while (true) {
        timing.enter(.fetch);
        const next = query.next() catch |err| {
            console.diagnostic.envelope = try q.ApiDiagnostic.attempt("table_select", .read, null, err, .{}, false, null);
            if (console.diagnostic.envelope) |*detail| {
                try detail.fact(.emitted_rows, .execution, .{ .unsigned = .init(emitted) });
                if (query.native_rejection) |native| try detail.text(.native_cause, .authority, @tagName(native));
            }
            return err;
        };
        if (next) |row| {
            batch[count] = row;
            cells[count] = row.cells;
            count += 1;
        }
        if (count < 8 and next != null and console.session.format == .table) continue;
        timing.enter(.render);
        var arena: std.heap.ArenaAllocator = .init(console.init.gpa);
        defer arena.deinit();
        if (console.session.format == .table) {
            if (count != 0 or emitted == 0) try @import("Results.zig").logicalTable(arena.allocator(), out, schema, cells[0..count]);
        } else for (cells[0..count]) |row| {
            try @import("Results.zig").logicalRow(arena.allocator(), out, schema, row);
        }
        if (next == null) {
            if (!query.complete) return error.IncompleteSource;
            timing.enter(.release);
            try query.close();
            timing.enter(.render);
            if (console.session.format == .table) {
                try out.print("{d} {s}\n", .{ query.execution.emitted, if (query.execution.emitted == 1) "row" else "rows" });
            } else {
                var rows: [20]u8 = undefined;
                var scanned: [20]u8 = undefined;
                try std.json.Stringify.value(.{ .complete = .{ .basis = &source_basis, .plan = &plan, .rows = try std.fmt.bufPrint(&rows, "{d}", .{query.execution.emitted}), .scanned = try std.fmt.bufPrint(&scanned, "{d}", .{query.execution.scanned}) }, .complete_coverage = true }, .{}, out);
                try out.writeByte('\n');
            }
        }
        if (Signals.interrupted()) return error.ConsoleInterrupted;
        try stream.flush();
        emitted += count;
        for (batch[0..count]) |*row| row.deinit();
        count = 0;
        if (next == null) break;
    }
    if (console.writes) |writer| try writer.clearComplete();
    console.query_running = false;
}
fn compilationFailure(console: *Console, catalog: *c.TableClient, statement: []const u8, operation: []const u8, err: anyerror, location: q.fuze.Sql.Location) !void {
    console.diagnostic.sql = q.fuze.SqlDiagnostic.tableSelect(statement, err, location);
    if (console.diagnostic.sql == null) console.diagnostic.envelope = try q.ApiDiagnostic.attempt(operation, .read, null, err, .{}, false, null);
    if (console.diagnostic.envelope) |*detail| if (catalog.transport.last_rejection) |native| try detail.text(.native_cause, .authority, @tagName(native));
}
