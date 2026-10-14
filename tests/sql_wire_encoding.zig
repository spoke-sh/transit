//! Framed-row encoding cost, separate from TLS, authority and driver timings.
const std = @import("std");
const pg = @import("transit_postgres");
const my = @import("transit_mysql");
const rows = 10000;
fn columns(comptime Column: type) [7]Column {
    var result: [7]Column = undefined;
    for ([_]pg.gateway.Type.Kind{ .int64, .uint64, .float64, .boolean, .utf8, .binary, .int64 }, &result) |kind, *column| {
        column.* = .{ .name = @tagName(kind), .type = .{ .kind = kind, .nullable = true } };
    }
    return result;
}
pub fn main(init: std.process.Init) !void {
    var postgres: pg.Backend = .{ .allocator = init.gpa, .maximum = 8192 };
    defer postgres.deinit();
    var mysql: my.Backend = .{ .allocator = init.gpa, .maximum = 8192 };
    defer mysql.deinit();
    const pg_columns = columns(pg.Backend.Column);
    const my_columns = columns(my.Backend.Column);
    var binary: [256]u8 = undefined;
    for (&binary, 0..) |*byte, i| byte.* = @intCast(i);
    var cells = [_]pg.gateway.fuze.Types.Values.Cell{
        .{ .value = .{ .atom = .{ .signed = 0 } } },
        .{ .value = .{ .atom = .{ .unsigned = std.math.maxInt(u64) } } },
        .{ .value = .{ .atom = .{ .float = -1.25 } } },
        .{ .value = .{ .atom = .{ .boolean = true } } },
        .{ .value = .{ .atom = .{ .bytes = "snow ☃ and 列" } } },
        .{ .value = .{ .atom = .{ .bytes = &binary } } },
        .null,
    };
    const Sample = struct { path: []const u8, milliseconds: [5]f64, framed_bytes: u64 };
    var samples: [4]Sample = undefined;
    for ([_][]const u8{ "postgres_text", "postgres_binary", "mysql_text", "mysql_binary" }, 0..) |name, index| {
        var formats: pg.Frontend.Formats = .{ .count = 1 };
        formats.values[0] = if (index % 2 == 0) .text else .binary;
        samples[index] = .{ .path = name, .milliseconds = undefined, .framed_bytes = 0 };
        for (0..6) |iteration| {
            const started = std.Io.Clock.awake.now(init.io);
            var bytes: u64 = 0;
            for (0..rows) |row| {
                cells[0].value.atom.signed = @intCast(row);
                const encoded = if (index < 2) try postgres.row(&pg_columns, &formats, &cells) else try mysql.row(&my_columns, &cells, index % 2 == 1);
                std.mem.doNotOptimizeAway(encoded);
                bytes += encoded.len;
            }
            if (iteration != 0) samples[index].milliseconds[iteration - 1] = @as(f64, @floatFromInt(started.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds())) / 1e6;
            if (iteration == 0) samples[index].framed_bytes = bytes else if (bytes != samples[index].framed_bytes) return error.UnstableEncodingSize;
        }
    }
    const output = try std.json.Stringify.valueAlloc(init.gpa, .{ .profile = "database_wire_encoding", .rows_per_sample = rows, .columns = 7, .warmups = 1, .repetitions = 5, .optimize = @tagName(@import("builtin").mode), .samples = samples, .limits = "Six scalar types plus NULL; signed values vary by row, binary covers all 256 byte values. Includes scalar validation, formatting, framed-row construction and allocator work. Reuses each backend buffer; output escapes optimization. Excludes metadata, TLS, sockets, authority and storage. Framed bytes are database-protocol application bytes, not network traffic. Local observations, not a throughput or latency guarantee." }, .{});
    defer init.gpa.free(output);
    try std.Io.File.stdout().writeStreamingAll(init.io, output);
    try std.Io.File.stdout().writeStreamingAll(init.io, "\n");
}
