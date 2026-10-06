//! One statement owns one leased snapshot and bounded native Arrow buffers.
const std = @import("std");
const q = @import("transit_query");
const Console = @import("Console.zig").Console;
const Signals = @import("Signals.zig");
const Timing = @import("Timing.zig");
const f = q.fuze;

pub fn sql(console: *Console, request: @import("SqlInput.zig").Request) !void {
    const statement = request.sql;
    console.query_running = true;
    // A previous Ctrl-C may have been coalesced while cleanup was finishing.
    Signals.cancellation.store(false, .release);
    try interrupted();
    var timing = Timing.start(console.init, console.preferences.timing);
    timing.interactive = true;
    defer console.finishTiming(&timing);
    var arena: std.heap.ArenaAllocator = .init(console.init.gpa);
    defer arena.deinit();
    const allocator = arena.allocator();
    timing.enter(.compile);
    const source = try console.config.?.source.native(allocator);
    // Ordinary SQL keeps its pure compile path. Explicit bindings use the
    // shared compiler's current-access checks; opening still validates authority
    // independently before acquiring any data.
    var binding: q.fuze.Sql.Binding = .{};
    const bundle = if (request.parameters != null) compiled: {
        const result = (q.Workspace.applyDiagnostic(allocator, console.client.?, console.config.?, .{ .compile = request }, &binding) catch |err| {
            console.diagnostic.sql = q.fuze.SqlDiagnostic.bound(statement, err, true, binding);
            return err;
        }).compiled;
        break :compiled try q.Bundle.decode(allocator, try q.Values.unhex(allocator, result.bundle, q.Bundle.max_bytes));
    } else q.Bundle.fromSqlDiagnostic(allocator, source, console.config.?.name, statement, try console.config.?.limits.native(), &binding) catch |err| {
        console.diagnostic.sql = q.fuze.SqlDiagnostic.bound(statement, err, true, binding);
        return err;
    };
    try interrupted();
    timing.enter(.open);
    var nonce: [16]u8 = undefined;
    try console.init.io.randomSecure(&nonce);
    var query = try q.Interactive.open(console.client.?, bundle, nonce, allocator);
    defer query.close() catch {};
    const workspace = try allocator.alloc(u8, f.LogicalArrow.working_bytes);
    const arrow = try allocator.alloc(u8, f.LogicalArrow.segment_bytes);
    const presentation = try allocator.alloc(u8, 1048576);
    const adapter = try allocator.alloc(u8, q.UnifiedBehavior.adapter_bytes);
    var columns: [q.SourceDefinition.max_columns]f.Types.Field = undefined;
    const schema = try query.schema(&columns);
    var ordinal: u64 = 0;
    var emitted_rows: u64 = 0;
    while (!query.complete()) {
        timing.enter(.fetch);
        try interrupted();
        // Source strings, decoded cells and formatted output die per page.
        var page_arena: std.heap.ArenaAllocator = .init(console.init.gpa);
        defer page_arena.deinit();
        const page_allocator = page_arena.allocator();
        var source_memory: std.heap.FixedBufferAllocator = .init(adapter);
        const segment = query.next(console.client.?, source_memory.allocator(), workspace, arrow, &Signals.cancellation) catch |err| {
            try interrupted();
            console.diagnostic.envelope = query.diagnostic;
            if (console.diagnostic.envelope) |*detail| {
                detail.fact(.emitted_rows, .execution, .{ .unsigned = .init(emitted_rows) }) catch {};
                detail.fact(.emitted_segments, .execution, .{ .unsigned = .init(ordinal) }) catch {};
            }
            return err;
        };
        try interrupted();
        timing.enter(.render);
        var out: std.Io.Writer = .fixed(presentation);
        var batch: ?f.LogicalInspect.Batch = null;
        defer if (batch) |*decoded| decoded.deinit();
        if (segment) |part| batch = try f.LogicalInspect.decode(page_allocator, schema, part.bytes, part.rows, workspace);
        if (segment == null and !query.complete()) continue;
        const count = if (batch) |decoded| decoded.rows.len else 0;
        if (console.session.format == .table) {
            if (batch) |*decoded| try @import("Results.zig").table(page_allocator, &out, schema, decoded);
        } else {
            const rows = if (batch) |*decoded| try q.Values.rows(page_allocator, decoded) else &.{};
            try std.json.Stringify.value(.{ .profile = "interactive_v1", .session = query.source.snapshot.id, .basis = query.basis, .ordinal = try q.document.JsonValues.decimal(page_allocator, ordinal), .columns = try q.Values.foreignColumns(page_allocator, schema), .cells = rows, .rows = try q.document.JsonValues.decimal(page_allocator, query.progress.rows), .complete_coverage = query.complete() }, .{ .escape_unicode = true }, &out);
            try out.writeByte('\n');
        }
        if (query.complete()) {
            timing.enter(.release);
            try query.close();
            timing.enter(.render);
            if (console.session.format == .table) try out.print("{d} {s}\n", .{ query.progress.rows, if (query.progress.rows == 1) "row" else "rows" });
        }
        try interrupted();
        try @import("Output.zig").write(console.init, console.out, out.buffered());
        ordinal += 1;
        emitted_rows += count;
    }
    console.query_running = false;
}
fn interrupted() !void {
    if (Signals.interrupted()) return error.ConsoleInterrupted;
}
