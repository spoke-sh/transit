//! Independent Arrow consumers read these actual Fuze-produced IPC fixtures.
const std = @import("std");
const fuze = @import("transit_fuze");
const a = fuze.arrow;
pub const std_options: std.Options = .{ .log_level = .info };

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 3) return error.Usage;
    if (std.mem.startsWith(u8, args[1], "stream-")) return stream(init, args[1][7..], args[2]);
    if (std.mem.startsWith(u8, args[1], "unified-")) return unified(init, args[1][8..], args[2]);
    const empty = std.mem.eql(u8, args[1], "empty");
    if (std.mem.startsWith(u8, args[1], "query-")) return query(init, args[1][6..], args[2]);
    const types = [_]a.DataType{ .{ .int64 = {} }, .{ .string = {} } };
    const fields = [_]a.Field{
        .{ .name = "id", .data_type = &types[0], .nullable = false },
        .{ .name = "label", .data_type = &types[1], .nullable = true },
    };
    var ids = try a.Int64Builder.init(allocator, 3);
    defer ids.deinit();
    var labels = try a.StringBuilder.init(allocator, 3, 32);
    defer labels.deinit();
    if (!empty) {
        try ids.append(1);
        try ids.append(9007199254740993);
        try ids.append(std.math.maxInt(i64));
        try labels.append("ready");
        try labels.appendNull();
        try labels.append("東京");
    }
    var id_column = try ids.finish();
    defer id_column.release();
    var label_column = try labels.finish();
    defer label_column.release();
    var batch = try a.RecordBatch.initBorrowed(allocator, .{ .fields = &fields }, &.{ id_column, label_column });
    defer batch.deinit();
    var buffer: [4096]u8 = undefined;
    const encoded = try fuze.encode(allocator, batch, &buffer);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = args[2], .data = encoded });
}

fn stream(init: std.process.Init, name: []const u8, path: []const u8) !void {
    const m = fuze.model;
    const s = fuze.Stream;
    const data_type: m.Type = if (std.mem.eql(u8, name, "bool")) .boolean else if (std.mem.eql(u8, name, "text")) .utf8 else if (std.mem.eql(u8, name, "binary")) .binary else .int64;
    const schema: m.Schema = .{ .names = .{ try m.Name.init("id"), try m.Name.init("value") }, .value_type = data_type };
    var rows: [70]m.Row = undefined;
    const text: [m.max_cell_bytes]u8 = @splat('x');
    for (&rows, 0..) |*row, index| {
        const value: m.Cell = switch (data_type) {
            .int64 => .{ .int64 = 9007199254740993 + @as(i64, @intCast(index)) },
            .boolean => .{ .boolean = index % 2 == 0 },
            .utf8 => .{ .utf8 = try m.Bytes.init(&text) },
            .binary => .{ .binary = try m.Bytes.init(&.{ 0, 255, @intCast(index) }) },
        };
        row.* = .{ .key = @intCast(index), .value = if (index % 5 == 0) .null else value };
    }
    var plan: s.Plan = .{};
    if (std.mem.eql(u8, name, "sum")) {
        plan.aggregate = .sum;
        plan.projection = .{ 1, null };
    }
    if (std.mem.eql(u8, name, "count")) plan.aggregate = .count;
    if (std.mem.eql(u8, name, "null")) plan.predicate = .{ .is_null = 1 };
    if (std.mem.eql(u8, name, "empty")) plan.limit = 0;
    if (std.mem.eql(u8, name, "limit")) {
        plan.limit = 37;
        plan.predicate = .{ .compare = .{ .column = 0, .op = .ge, .value = .{ .int64 = 3 } } };
    }
    const physical = try plan.bind(.{ .resource = 7, .revision = 9, .schema = try schema.fingerprint() }, schema);
    var progress = physical.start();
    var workspace: [fuze.execution.working_bytes]u8 = undefined;
    var output: [8192]u8 = undefined;
    const cancel = fuze.execution.Cancellation.init(false);
    const Segment = struct { ordinal: u64, bytes: usize, rows: u8, digest: [32]u8 };
    var segments: [16]Segment = undefined;
    var count: usize = 0;
    var offset: usize = 0;
    var total_bytes: usize = 0;
    while (progress.finished == null) {
        // Include an empty nonterminal batch and changing partition sizes.
        const take: usize = if (progress.pages == 0) 0 else if (progress.pages % 2 == 0) 8 else 13;
        const end = @min(rows.len, offset + take);
        const next = try s.step(physical, progress, .{ .ordinal = progress.pages, .source = .{ .basis = physical.basis, .schema = schema, .rows = rows[offset..end] }, .end = end == rows.len }, &workspace, &output, &cancel);
        if (next.segment) |segment| {
            var path_buffer: [4096]u8 = undefined;
            const segment_path = try std.fmt.bufPrint(&path_buffer, "{s}.{d}.arrow", .{ path, count });
            try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = segment_path, .data = segment.bytes });
            segments[count] = .{ .ordinal = count, .bytes = segment.bytes.len, .rows = segment.rows, .digest = segment.digest };
            count += 1;
            total_bytes += segment.bytes.len;
        }
        // No Arrow allocation or borrowed native progress survives a step.
        progress = try s.Progress.decode(&try next.progress.encode());
        offset = end;
    }
    var manifest_buffer: [8192]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&manifest_buffer);
    try std.json.Stringify.value(.{ .representation = "arrow-ipc-segments-v1", .plan = plan, .progress = progress, .bytes = total_bytes, .segments = segments[0..count] }, .{}, &writer);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = writer.buffered() });
    var path_buffer: [4096]u8 = undefined;
    const progress_path = try std.fmt.bufPrint(&path_buffer, "{s}.progress", .{path});
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = progress_path, .data = &try progress.encode() });
}

fn query(init: std.process.Init, name: []const u8, path: []const u8) !void {
    const m = fuze.model;
    const data_type: m.Type = if (std.mem.eql(u8, name, "bool")) .boolean else if (std.mem.eql(u8, name, "text")) .utf8 else if (std.mem.eql(u8, name, "binary")) .binary else .int64;
    const schema: m.Schema = .{ .names = .{ try m.Name.init("id"), try m.Name.init("value") }, .value_type = data_type };
    const value: m.Cell = switch (data_type) {
        .int64 => .{ .int64 = 9007199254740993 },
        .boolean => .{ .boolean = true },
        .utf8 => .{ .utf8 = try m.Bytes.init("東京") },
        .binary => .{ .binary = try m.Bytes.init(&.{ 0, 255 }) },
    };
    const rows = [_]m.Row{ .{ .key = -1, .value = value }, .{ .key = 2, .value = .null } };
    const source: m.Source = .{ .basis = .{ .resource = 7, .revision = 3, .schema = try schema.fingerprint() }, .schema = schema, .rows = &rows };
    var plan: fuze.Plan = .{};
    if (std.mem.eql(u8, name, "sum")) {
        plan.aggregate = .sum;
        plan.projection = .{ 1, null };
    }
    if (std.mem.eql(u8, name, "count")) plan.aggregate = .count;
    if (std.mem.eql(u8, name, "null")) plan.predicate = .{ .is_null = 1 };
    if (std.mem.eql(u8, name, "empty")) plan.limit = 0;
    var workspace: [fuze.execution.working_bytes]u8 = undefined;
    var output: [672]u8 = undefined;
    const cancel = fuze.execution.Cancellation.init(false);
    const result = try fuze.execution.run(try plan.bind(source), source, &workspace, &output, &cancel);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = result.bytes });
}

fn unified(init: std.process.Init, name: []const u8, path: []const u8) !void {
    const m = fuze.Unified;
    if (std.mem.startsWith(u8, name, "stream-")) return unifiedStream(init, name[7..], path);
    const types = [_]m.Type{ .int64, .uint64, .float64, .boolean, .utf8, .binary };
    const values = [_]m.Scalar{
        .{ .int64 = std.math.minInt(i64) }, .{ .uint64 = std.math.maxInt(u64) },
        .{ .float64 = -0.0 },               .{ .boolean = false },
        .{ .utf8 = "café é 🙂" },
        .{ .binary = &.{ 0, 255, 128 } },
    };
    var columns: [6]m.Column = undefined;
    var cells: [5][6]m.Cell = undefined;
    var conflicts: [6][3]m.Alternative = undefined;
    for (types, 0..) |tag, index| {
        columns[index] = .{ .name = try m.Name.init(@tagName(tag)), .type = tag };
        conflicts[index] = .{
            .{ .counter = std.math.maxInt(u64), .replica = 1, .value = .{ .value = values[index] } },
            .{ .counter = std.math.maxInt(u64), .replica = 2, .value = .null },
            .{ .counter = std.math.maxInt(u64), .replica = 3, .value = .{ .type_error = .list } },
        };
        cells[0][index] = .missing;
        cells[1][index] = .null;
        cells[2][index] = .{ .type_error = .map };
        cells[3][index] = .{ .value = values[index] };
        cells[4][index] = .{ .conflict = &conflicts[index] };
    }
    var rows: [5]m.Row = undefined;
    for (&rows, &cells) |*row, *items| row.* = .{ .cells = items };
    const workspace = try init.arena.allocator().alloc(u8, m.Arrow.working_bytes);
    var output: [m.Arrow.segment_bytes]u8 = undefined;
    const selected = if (std.mem.eql(u8, name, "empty") or std.mem.eql(u8, name, "validate-empty")) rows[0..0] else &rows;
    if (std.mem.startsWith(u8, name, "validate-")) {
        const data = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.arena.allocator(), .limited(m.Arrow.segment_bytes));
        var decoded: m.Inspect.Batch = undefined;
        try m.Inspect.decode(.{ .columns = &columns }, data, @intCast(selected.len), workspace, init.arena.allocator(), &decoded);
        @memset(workspace, 0xcc);
        for (selected, 0..) |row, index| try std.testing.expectEqualDeep(row, try decoded.row(index));
        if (selected.len != 0) try std.testing.expectEqual(@as(u64, 1 << 63), @as(u64, @bitCast(decoded.cells[3][2].value.float64)));
        return;
    }
    const bytes = try m.Arrow.encode(.{ .columns = &columns }, selected, workspace, &output);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = bytes });
}

fn unifiedStream(init: std.process.Init, name: []const u8, path: []const u8) !void {
    const m = fuze.Unified;
    const aggregate = std.meta.stringToEnum(m.Plan.Aggregate, name) orelse return error.Usage;
    const schema: m.Schema = .{ .columns = &.{.{ .name = try m.Name.init("value"), .type = .int64 }} };
    const basis: m.Basis = .{ .kind = .kv, .resource = 17, .revision = 29, .contract = @splat(7), .schema = try schema.fingerprint() };
    const bound = try (m.Plan{ .projection = &.{0}, .aggregate = aggregate, .limit = 37, .predicate = .{ .compare = .{ .column = 0, .op = .ge, .value = .{ .int64 = 3 } } } }).bind(basis, schema);
    const workspace = try init.arena.allocator().alloc(u8, m.Arrow.working_bytes);
    var output: [m.Arrow.segment_bytes]u8 = undefined;
    var cells: [70][1]m.Cell = undefined;
    var rows: [70]m.Row = undefined;
    for (&cells, &rows, 0..) |*cell, *row, index| {
        cell[0] = if (index % 5 == 0) .null else .{ .value = .{ .int64 = @intCast(index) } };
        row.* = .{ .cells = cell };
    }
    const cancellation = fuze.execution.Cancellation.init(false);
    for (1..m.max_rows + 1) |width| {
        var progress = m.Stream.Progress.start(bound);
        var after: usize = 0;
        while (progress.finished == null) {
            const end = @min(rows.len, after + width);
            const next = try m.Stream.step(bound, progress, .{ .basis = basis, .ordinal = progress.pages, .rows = rows[after..end], .end = end == rows.len }, workspace, &output, &cancellation);
            if (next.segment) |part| {
                const filename = try std.fmt.allocPrint(init.arena.allocator(), "{s}-{d}-{d}.arrow", .{ path, width, progress.segments });
                try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = filename, .data = part.bytes });
            }
            progress = try m.Stream.Progress.decode(&try next.progress.encode());
            after = end;
        }
        const filename = try std.fmt.allocPrint(init.arena.allocator(), "{s}-{d}.json", .{ path, width });
        const encoded = try std.json.Stringify.valueAlloc(init.arena.allocator(), progress, .{});
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = filename, .data = encoded });
        const checkpoint = try std.fmt.allocPrint(init.arena.allocator(), "{s}-{d}.progress", .{ path, width });
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = checkpoint, .data = &try progress.encode() });
    }
}
