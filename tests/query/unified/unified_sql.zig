//! Independent SQL oracle reads IPC from this consumer of the public package.
const std = @import("std");
const f = @import("transit_fuze");
const m = f.Unified;
const Case = struct { sql: []const u8, expected_error: ?[]const u8 = null };
pub fn main(init: std.process.Init) !void {
    const a = init.arena.allocator();
    const args = try init.minimal.args.toSlice(a);
    const cases = try std.json.parseFromSlice([]const Case, a, try std.Io.Dir.cwd().readFileAlloc(init.io, args[1], a, .limited(65536)), .{});
    var columns: [8]m.Column = undefined;
    const types = [_]m.Type{ .int64, .uint64, .float64, .boolean, .utf8, .binary, .utf8, .utf8 };
    const names = [_][]const u8{ "id", "counter", "fraction", "flag", "value", "raw", "missing", "optional" };
    for (&columns, names, types) |*column, name, kind| column.* = .{ .name = try m.Name.init(name), .type = kind };
    const source: m.Sql.Source = .{ .name = try m.Name.init("items"), .schema = .{ .columns = &columns } };
    const workspace = try a.alloc(u8, m.Arrow.working_bytes);
    var output: [m.Arrow.segment_bytes]u8 = undefined;
    var buffer: [8192]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    for (cases.value, 0..) |case, index| {
        var arena = std.heap.ArenaAllocator.init(init.gpa);
        defer arena.deinit();
        const plan = m.Sql.plan(arena.allocator(), case.sql, source) catch |err| {
            try std.json.Stringify.value(.{ .index = index, .compile_error = @errorName(err) }, .{}, &stdout.interface);
            try stdout.interface.writeByte('\n');
            continue;
        };
        var bytes: [m.Codec.max_plan_bytes]u8 = undefined;
        const restored = try m.Codec.decode(try m.Codec.encode(plan, &bytes));
        inline for (.{ m.SourceKind.kv, m.SourceKind.table, m.SourceKind.document }) |kind| {
            const bound = try restored.bind(.{ .kind = kind, .resource = 9, .revision = 42, .contract = @splat(7), .schema = try source.schema.fingerprint() }, source.schema);
            for (1..9) |width| {
                var progress: m.Stream.Progress = .start(bound);
                var offset: usize = 0;
                const cancelled = f.execution.Cancellation.init(false);
                while (progress.finished == null) {
                    var cells: [8][8]m.Cell = undefined;
                    var rows: [8]m.Row = undefined;
                    // Empty nonterminal pages exercise cursor/progress ordering.
                    const count = if (progress.pages == 0) 0 else @min(width, 70 - offset);
                    for (0..count) |i| {
                        const n = offset + i;
                        cells[i] = .{
                            .{ .value = .{ .int64 = @as(i64, @intCast(n)) - 35 } },
                            .{ .value = .{ .uint64 = std.math.maxInt(u64) - n } },
                            .{ .value = .{ .float64 = if (n == 0) -0.0 else @as(f64, @floatFromInt(n)) + 0.5 } },
                            .{ .value = .{ .boolean = n % 2 == 0 } },
                            if (n % 5 == 0) .null else .{ .value = .{ .utf8 = if (n % 2 == 0) "it's 東京" else "a\\b" } },
                            .{ .value = .{ .binary = if (n % 2 == 0) &.{ 0, 255 } else "" } },
                            .missing,
                            switch (n % 4) {
                                0 => .null,
                                1 => .missing,
                                2 => .{ .type_error = .int64 },
                                else => .{ .conflict = &.{ .{ .counter = 1, .replica = 1, .value = .null }, .{ .counter = 2, .replica = std.math.maxInt(u64), .value = .{ .value = .{ .utf8 = "東京" } } } } },
                            },
                        };
                        rows[i] = .{ .cells = &cells[i] };
                    }
                    const next = m.Stream.step(bound, progress, .{ .basis = bound.basis, .ordinal = progress.pages, .rows = rows[0..count], .end = offset + count == 70 }, workspace, &output, &cancelled) catch |err| {
                        try std.json.Stringify.value(.{ .index = index, .kind = @tagName(kind), .width = width, .execution_error = @errorName(err) }, .{}, &stdout.interface);
                        try stdout.interface.writeByte('\n');
                        break;
                    };
                    if (next.segment) |segment| {
                        var path: [4096]u8 = undefined;
                        const name = try std.fmt.bufPrint(&path, "{s}/{d}-{s}-{d}-{d}.arrow", .{ args[2], index, @tagName(kind), width, progress.segments });
                        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = name, .data = segment.bytes });
                    }
                    progress = try m.Stream.Progress.decode(&try next.progress.encode());
                    offset += count;
                    if (progress.finished != null) {
                        try std.json.Stringify.value(.{ .index = index, .kind = @tagName(kind), .width = width, .segments = progress.segments, .scanned = progress.scanned }, .{}, &stdout.interface);
                        try stdout.interface.writeByte('\n');
                    }
                }
            }
        }
    }
    try stdout.interface.flush();
}
