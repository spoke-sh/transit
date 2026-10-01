//! Current-authorized catalog inspection. One bounded page is resident; a
//! changed resource cut fails instead of combining definitions across revisions.
const std = @import("std");
const c = @import("transit_catalog");
const Console = @import("Console.zig").Console;
pub fn inspect(console: *Console, catalog: *c.Client, name: ?c.fuze.model.Name) !void {
    var cursor: ?c.Inspection.Cursor = null;
    const deadline = std.Io.Clock.boot.now(console.init.io).toMilliseconds() + 300000;
    while (true) {
        if (@import("Signals.zig").interrupted()) return error.ConsoleInterrupted;
        if (std.Io.Clock.boot.now(console.init.io).toMilliseconds() >= deadline) return error.CatalogInspectionTimedOut;
        var arena: std.heap.ArenaAllocator = .init(console.init.gpa);
        defer arena.deinit();
        var buffer: [16384]u8 = undefined;
        var out: std.Io.Writer = .fixed(&buffer);
        if (name) |selected| {
            const definition = (try catalog.lookup(selected)) orelse return error.CatalogNameNotFound;
            if (console.session.format == .json) {
                try std.json.Stringify.value(.{ .definition = try c.Bridge.Definition.fromNative(arena.allocator(), definition) }, .{}, &out);
                try out.writeByte('\n');
            } else {
                const schema = definition.source.table.schema;
                try out.print("Catalog Table: {s}\n{s}: int64 NOT NULL\n{s}: {s} NULL\n", .{ definition.name.slice(), schema.names[0].slice(), schema.names[1].slice(), @tagName(schema.value_type) });
            }
        } else {
            const page = try catalog.list(cursor);
            if (console.session.format == .json) {
                try std.json.Stringify.value(.{ .catalog_page = try c.Bridge.Page.fromNative(arena.allocator(), page) }, .{}, &out);
                try out.writeByte('\n');
            } else {
                try out.print("Catalog tables (revision {d}):\n", .{page.resource_revision});
                for (page.entries) |entry| if (entry) |definition| try out.print("{s}\n", .{definition.name.slice()});
            }
            cursor = page.next;
        }
        try @import("Output.zig").write(console.init, console.out, out.buffered());
        if (cursor == null) return;
    }
}
