//! Real signed snapshot/tail reader; expected changes live in the Python driver.
const std = @import("std");
const q = @import("transit_query");
const f = q.fuze;
fn row(writer: *std.Io.Writer, value: f.TableRow.Owned) !void {
    try writer.writeByte('[');
    for (value.row().cells, 0..) |cell, i| {
        if (i != 0) try writer.writeByte(',');
        if (cell == .null) try writer.writeAll("null") else try writer.print("{d}", .{cell.value.atom.signed});
    }
    try writer.writeByte(']');
}
pub fn run(comptime Test: type, init: std.process.Init, client: *q.catalog.TableClient, directory: []const u8, args: anytype) !void {
    const snapshot = std.mem.startsWith(u8, args[2], "history-snapshot");
    var nonce: [16]u8 = undefined;
    try init.io.randomSecure(&nonce);
    var reader = if (snapshot)
        try q.TableChangeReader.open(init.gpa, client, try q.catalog.TableMetadata.Name.init(args[4]), nonce, 100000, null)
    else
        try q.TableChangeReader.openTail(init.gpa, client, try Test.load(q.TableChangeReader.Position, init, directory, "table-tail.json"), nonce, 100000, null);
    defer reader.deinit();
    if (std.mem.endsWith(u8, args[2], "-held")) {
        try Test.print(init, .{ .ready = true });
        var bytes: [16]u8 = undefined;
        var input = std.Io.File.stdin().readerStreaming(init.io, &bytes);
        _ = try input.interface.takeByte();
    }
    var buffer: [4096]u8 = undefined;
    var output = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    const out = &output.interface;
    if (snapshot) {
        try out.writeAll("{\"rows\":[");
        var count: usize = 0;
        while (try reader.snapshotNext()) |value| {
            var owned = value;
            defer owned.deinit();
            if (count != 0) try out.writeByte(',');
            try row(out, owned);
            count += 1;
        }
        try Test.save(init, directory, "table-tail.json", try reader.checkpoint());
        try out.writeAll("],\"complete\":true}\n");
    } else {
        try out.writeAll("{\"transactions\":[");
        var transactions: usize = 0;
        var changes: usize = 0;
        var open = false;
        for (0..100000) |_| {
            var event = try reader.next();
            if (event == .caught_up) break;
            if (!open) {
                if (transactions != 0) try out.writeByte(',');
                try out.writeAll("{\"changes\":[");
                open = true;
                changes = 0;
            }
            switch (event) {
                .progress => {},
                .change => |*change| {
                    defer change.deinit();
                    if (changes != 0) try out.writeByte(',');
                    try out.writeAll("{\"identity\":");
                    try std.json.Stringify.value(change.identity, .{}, out);
                    try out.writeAll(",\"before\":");
                    if (change.before) |before| try row(out, before) else try out.writeAll("null");
                    try out.writeAll(",\"after\":");
                    if (change.after) |after| try row(out, after) else try out.writeAll("null");
                    try out.writeByte('}');
                    changes += 1;
                },
                .transaction => |transaction| {
                    if (changes != transaction.changes) return error.IncompleteTableChanges;
                    const previous = try transaction.previous.validate();
                    const next = try transaction.next.validate();
                    try out.print("],\"previous\":{d},\"next\":{d},\"commit\":{d},\"retired\":{}}}", .{ previous.head.revision, next.head.revision, next.committed, next.head.retired });
                    transactions += 1;
                    open = false;
                },
                .caught_up => unreachable,
            }
        } else return error.TableTailNotCaughtUp;
        if (open) return error.IncompleteTableChanges;
        _ = try reader.checkpoint();
        try out.writeAll("],\"complete\":true}\n");
    }
    try reader.close();
    try out.flush();
}
