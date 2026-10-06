//! Interactive general Table SELECT. Rows are typed, independently owned and
//! emitted as incomplete prefixes until the captured query verifies completion.
const std = @import("std");
const q = @import("transit_query");
const c = @import("transit_catalog");
const Console = @import("Console.zig").Console;
const Signals = @import("Signals.zig");
const Timing = @import("Timing.zig");
pub fn explain(console: *Console, catalog: *c.TableClient, statement: []const u8) !void {
    Signals.cancellation.store(false, .release);
    if (Signals.interrupted()) return error.ConsoleInterrupted;
    var nonce: [16]u8 = undefined;
    try console.init.io.randomSecure(&nonce);
    var location: q.fuze.Sql.Location = .{};
    var query = try q.TableQuery.open(console.init.gpa, catalog, statement, nonce, console.table_limits, &Signals.cancellation, &location);
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
    const buffer = try arena.allocator().alloc(u8, 1048576);
    var out: std.Io.Writer = .fixed(buffer);
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
        } }, .{}, &out);
        try out.writeByte('\n');
    } else {
        try out.print("Proposed Table plan; object: {d}\n{s} scan", .{ object, if (query.execution.scan.point != null) "Primary key" else "Finite" });
        if (plan.predicate != .all) try out.writeAll(" -> filter");
        if (plan.limit) |limit| try out.print(" -> limit {d}", .{limit});
        try out.print(" -> {s}\n", .{if (plan.aggregate == .rows) "projection" else @tagName(plan.aggregate)});
        try @import("Results.zig").logicalTable(arena.allocator(), &out, schema, &.{});
        try out.writeAll("No rows executed. A later SELECT captures its own source basis.\n");
    }
    try @import("Output.zig").write(console.init, console.out, out.buffered());
}
pub fn sql(console: *Console, catalog: *c.TableClient, request: @import("SqlInput.zig").Request) !void {
    if (request.parameters != null or !console.interactive) {
        console.diagnostic.sql = q.fuze.SqlDiagnostic.query(request.sql, error.UnsupportedConstruct, true);
        if (console.diagnostic.sql) |*detail| detail.hint = "General Table SELECT uses interactive execution and typed SQL constants. Select execution: interactive; parameterized and durable Table query paths require their own admission profile.";
        return error.UnsupportedConstruct;
    }
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
        console.diagnostic.sql = q.fuze.SqlDiagnostic.tableSelect(request.sql, err, location);
        if (console.diagnostic.sql == null) console.diagnostic.envelope = try q.ApiDiagnostic.attempt("table_select", .read, null, err, .{}, false, null);
        if (console.diagnostic.envelope) |*detail| if (catalog.transport.last_rejection) |native| try detail.text(.native_cause, .authority, @tagName(native));
        return err;
    };
    defer query.deinit();
    var fields: [q.fuze.TableSchema.max_columns]q.fuze.Types.Field = undefined;
    const schema = try query.schema(&fields);
    const source_basis = std.fmt.bytesToHex(query.compiled.plan.source_basis, .lower);
    const plan = std.fmt.bytesToHex(query.execution.fingerprint, .lower);
    const buffer = try console.init.gpa.alloc(u8, if (console.session.format == .json) 8 * 1024 * 1024 else 1048576);
    defer console.init.gpa.free(buffer);
    var out: std.Io.Writer = .fixed(buffer);
    if (console.session.format == .json) {
        try std.json.Stringify.value(.{ .profile = "table_snapshot_v1", .schema = q.fuze.LogicalJson.TypeEnvelope{ .definition = q.fuze.Types.definition, .type = schema }, .basis = &source_basis, .plan = &plan, .complete_coverage = false }, .{}, &out);
        try out.writeByte('\n');
        try @import("Output.zig").write(console.init, console.out, out.buffered());
        out.end = 0;
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
        out.end = 0;
        if (console.session.format == .table) {
            if (count != 0 or emitted == 0) try @import("Results.zig").logicalTable(arena.allocator(), &out, schema, cells[0..count]);
        } else for (cells[0..count]) |row| {
            try std.json.Stringify.value(.{ .row = try q.fuze.LogicalJson.foreignCell(arena.allocator(), .{ .value = .{ .structure = row } }, schema), .complete_coverage = false }, .{ .escape_unicode = true }, &out);
            try out.writeByte('\n');
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
                try std.json.Stringify.value(.{ .complete = .{ .basis = &source_basis, .plan = &plan, .rows = try std.fmt.bufPrint(&rows, "{d}", .{query.execution.emitted}), .scanned = try std.fmt.bufPrint(&scanned, "{d}", .{query.execution.scanned}) }, .complete_coverage = true }, .{}, &out);
                try out.writeByte('\n');
            }
        }
        if (Signals.interrupted()) return error.ConsoleInterrupted;
        try @import("Output.zig").write(console.init, console.out, out.buffered());
        emitted += count;
        for (batch[0..count]) |*row| row.deinit();
        count = 0;
        if (next == null) break;
    }
    if (console.writes) |writer| try writer.clearComplete();
    console.query_running = false;
}
