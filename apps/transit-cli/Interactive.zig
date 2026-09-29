//! One statement owns one leased snapshot and bounded native Arrow buffers.
const std = @import("std");
const q = @import("transit_query");
const Console = @import("Console.zig").Console;
const Signals = @import("Signals.zig");
const Timing = @import("Timing.zig");
const m = q.fuze.Unified;

pub fn sql(console: *Console, statement: []const u8) !void {
    var timing = Timing.start(console.init, console.preferences.timing);
    timing.interactive = true;
    defer timing.report();
    var arena: std.heap.ArenaAllocator = .init(console.init.gpa);
    defer arena.deinit();
    const allocator = arena.allocator();
    timing.enter(.compile);
    const source = try console.config.source.native(allocator);
    // Compilation uses the configured declaration. Opening validates it against
    // current authority before acquiring data; compilation itself performs no I/O.
    const bundle = try q.Bundle.fromSql(allocator, source, try .init(console.config.name), statement, try console.config.limits.native());
    try interrupted();
    timing.enter(.open);
    var nonce: [16]u8 = undefined;
    try console.init.io.randomSecure(&nonce);
    var query = try q.Interactive.open(console.client, bundle, nonce);
    defer query.close() catch {};
    const workspace = try allocator.alloc(u8, m.Arrow.working_bytes);
    const arrow = try allocator.alloc(u8, m.Arrow.segment_bytes);
    const presentation = try allocator.alloc(u8, 1048576);
    const adapter = try allocator.alloc(u8, q.UnifiedBehavior.adapter_bytes);
    var columns: [m.max_columns]m.Column = undefined;
    const schema = try query.schema(&columns);
    var ordinal: u64 = 0;
    while (!query.complete()) {
        timing.enter(.fetch);
        try interrupted();
        // Source strings, decoded cells and formatted output die per page.
        var page_arena: std.heap.ArenaAllocator = .init(console.init.gpa);
        defer page_arena.deinit();
        const page_allocator = page_arena.allocator();
        var source_memory: std.heap.FixedBufferAllocator = .init(adapter);
        const segment = query.next(console.client, source_memory.allocator(), workspace, arrow, &Signals.cancellation) catch |err| {
            try interrupted();
            return err;
        };
        try interrupted();
        timing.enter(.render);
        var out: std.Io.Writer = .fixed(presentation);
        const batch = try page_allocator.create(m.Inspect.Batch);
        batch.* = .{ .count = 0, .columns = @intCast(schema.columns.len) };
        if (segment) |part| try m.Inspect.decode(schema, part.bytes, part.rows, workspace, page_allocator, batch);
        if (segment == null and !query.complete()) continue;
        if (console.session.format == .table) {
            if (segment != null) try @import("Results.zig").table(page_allocator, &out, schema, batch);
        } else {
            const rows = try page_allocator.alloc([]q.Values.Cell, batch.count);
            for (rows, 0..) |*cells, i| {
                const native = try batch.row(i);
                cells.* = try page_allocator.alloc(q.Values.Cell, native.cells.len);
                for (cells.*, native.cells) |*cell, value| cell.* = try q.Values.Cell.fromNative(page_allocator, value);
            }
            try std.json.Stringify.value(.{ .profile = "interactive_v1", .session = query.source.snapshot.id, .basis = query.progress.basis, .ordinal = try q.document.JsonValues.decimal(page_allocator, ordinal), .columns = try q.Values.foreignColumns(page_allocator, schema), .cells = rows, .rows = try q.document.JsonValues.decimal(page_allocator, query.progress.rows), .complete_coverage = query.complete() }, .{ .escape_unicode = true }, &out);
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
    }
}
fn interrupted() !void {
    if (Signals.interrupted()) return error.ConsoleInterrupted;
}
