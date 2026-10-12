//! Explicit-submit relational console adapter over the shared query owner.
const std = @import("std");
const q = @import("transit_query");
const c = @import("transit_catalog");
const Console = @import("Console.zig").Console;
const Signals = @import("Signals.zig");
const Output = @import("Output.zig");
const Results = @import("Results.zig");
pub fn run(console: *Console, catalog: *c.TableClient, statement: []const u8, start: usize, explain: bool, stream: *Output.Stream) !void {
    const options = console.relational orelse {
        console.diagnostic.sql = q.fuze.SqlDiagnostic.query(statement, error.UnsupportedConstruct, true);
        if (console.diagnostic.sql) |*detail| detail.hint = "Configure relational.consistency: per_resource_snapshot_vector and explicit relational budgets in this catalog connection.";
        return error.UnsupportedConstruct;
    };
    if (!console.interactive) return error.UnsupportedConstruct;
    console.query_running = true;
    defer console.query_running = false;
    Signals.cancellation.store(false, .release);
    if (Signals.interrupted()) return error.ConsoleInterrupted;
    var location: q.fuze.Sql.Location = .{};
    var syntax = q.fuze.RelationalSql.parse(console.init.gpa, statement[start..], &location) catch |err| return failed(console, catalog, statement, start, err, location);
    defer syntax.deinit();
    var nonces: [2][16]u8 = undefined;
    try console.init.io.randomSecure(std.mem.asBytes(&nonces));
    var name: [64]u8 = undefined;
    const filename = try std.fmt.bufPrint(&name, "transit-relational-{s}", .{std.fmt.bytesToHex(nonces[0], .lower)});
    const directory = try std.Io.Dir.cwd().openDir(console.init.io, console.init.environ_map.get("TMPDIR") orelse "/tmp", .{});
    defer directory.close(console.init.io);
    const clients = [_]*c.TableClient{ catalog, catalog };
    const query = q.RelationalQuery.open(console.init.gpa, console.init.io, directory, filename, clients[0..syntax.targets.len], statement[start..], nonces, options, &Signals.cancellation, &location) catch |err| return failed(console, catalog, statement, start, err, location);
    defer query.deinit();
    var fields: [q.fuze.Relational.max_outputs]q.fuze.Types.Field = undefined;
    const schema = try query.schema(&fields);
    const plan = query.execution.bound.plan;
    const prepared = std.fmt.bytesToHex(&try plan.fingerprint(), .lower);
    const bound = std.fmt.bytesToHex(&try query.execution.bound.fingerprint(), .lower);
    const out = &stream.interface;
    if (explain) {
        try query.close();
        if (console.session.format == .json) {
            try std.json.Stringify.value(.{ .explanation = .{
                .profile = "relational_snapshot_v1",
                .plan = &prepared,
                .basis = &bound,
                .consistency = "per_resource_snapshot_vector",
                .sources = plan.sources.len,
                .join = if (plan.join) |join| @tagName(join.kind) else "none",
                .scan = if (plan.join != null) "ordered_nested_loop" else "finite",
                .grouped = query.execution.grouped,
                .group_columns = plan.group_by.len,
                .group_storage = "private_disk_avl",
                .schema = q.fuze.LogicalJson.TypeEnvelope{ .definition = q.fuze.Types.definition, .type = schema },
                .executed = false,
            } }, .{}, out);
            try out.writeByte('\n');
        } else {
            try out.print("Proposed relational plan; {d} source aliases\nPer-resource snapshot vector\nOrdered {s} -> {s} -> projection\n", .{ plan.sources.len, if (plan.join) |join| @tagName(join.kind) else "scan", if (query.execution.grouped) "disk grouping" else "filter" });
            try out.writeAll("No rows executed. A later SELECT captures its own source basis.\n");
        }
        return stream.flush();
    }
    if (console.session.format == .json) {
        try std.json.Stringify.value(.{ .profile = "relational_snapshot_v1", .schema = q.fuze.LogicalJson.TypeEnvelope{ .definition = q.fuze.Types.definition, .type = schema }, .basis = &bound, .plan = &prepared, .consistency = "per_resource_snapshot_vector", .complete_coverage = false }, .{}, out);
        try out.writeByte('\n');
        try stream.flush();
    }
    var batch: [8]q.fuze.RelationalExecution.Output = undefined;
    var cells: [8][]const q.fuze.Types.Values.Cell = undefined;
    var count: usize = 0;
    var emitted: u64 = 0;
    while (true) {
        const next = query.next() catch |err| {
            console.diagnostic.envelope = try q.ApiDiagnostic.attempt("relational_select", .read, null, err, .{}, false, null);
            if (console.diagnostic.envelope) |*detail| try detail.fact(.emitted_rows, .execution, .{ .unsigned = .init(emitted) });
            return err;
        };
        if (next) |row| {
            batch[count] = row;
            cells[count] = batch[count].cells[0..row.len];
            count += 1;
        }
        if (count < batch.len and next != null and console.session.format == .table) continue;
        var arena: std.heap.ArenaAllocator = .init(console.init.gpa);
        defer arena.deinit();
        if (console.session.format == .table) {
            if (count != 0 or emitted == 0) try Results.logicalTable(arena.allocator(), out, schema, cells[0..count]);
        } else for (cells[0..count]) |row| try Results.logicalRow(arena.allocator(), out, schema, row);
        emitted += count;
        count = 0;
        if (next == null) {
            if (!query.complete) return error.IncompleteSource;
            try query.close();
            if (console.session.format == .table) {
                try out.print("{d} {s}\n", .{ emitted, if (emitted == 1) "row" else "rows" });
            } else {
                var rows: [20]u8 = undefined;
                try std.json.Stringify.value(.{ .complete = .{ .basis = &bound, .plan = &prepared, .rows = try std.fmt.bufPrint(&rows, "{d}", .{emitted}) }, .complete_coverage = true }, .{}, out);
                try out.writeByte('\n');
            }
        }
        if (Signals.interrupted()) return error.ConsoleInterrupted;
        try stream.flush();
        if (next == null) break;
    }
}
fn failed(console: *Console, catalog: *c.TableClient, statement: []const u8, start: usize, err: anyerror, location: q.fuze.Sql.Location) anyerror {
    var adjusted = location;
    adjusted.offset += start;
    console.diagnostic.sql = q.fuze.SqlDiagnostic.tableSelect(statement, err, adjusted);
    if (console.diagnostic.sql == null) console.diagnostic.envelope = q.ApiDiagnostic.attempt("relational_compile", .read, null, err, .{}, false, null) catch null;
    if (console.diagnostic.envelope) |*detail| if (catalog.transport.last_rejection) |native| detail.text(.native_cause, .authority, @tagName(native)) catch {};
    return err;
}
