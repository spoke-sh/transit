//! SQL result columns reuse Fuze's current plain physical representation. These
//! transient buffers confer neither Table identity nor storage/retention rights.
const std = @import("std");
const api = @import("root.zig");
const r = api.results;
const p = api.fuze.PhysicalCodecs;
fn column(field: r.Types.Field, ordinal: usize) api.fuze.TableSchema.Column {
    return .{ .id = ordinal + 1, .name = field.name, .type = field.type, .nullable = field.nullable, .encoding = .plain };
}
fn countCell(value: r.Types.Values.Cell, field: r.Types.Field) !usize {
    var buffer: [256]u8 = undefined;
    var counter: std.Io.Writer.Discarding = .init(&buffer);
    try r.Types.Codec.writeBound(value, field, &counter.writer);
    return @intCast(counter.fullCount());
}

/// Output and its directory belong to arena, with scratch freed separately.
/// Each allocation scales with its actual values plus bounded column framing.
pub fn encode(scratch: std.mem.Allocator, arena: std.mem.Allocator, fields: []const r.Types.Field, batch: r.Batch) ![]const []const u8 {
    if (batch.len > api.max_rows or fields.len > api.ResultFrame.max_columns) return error.InvalidResultChunk;
    try batch.validate(fields);
    if (batch.len == 0) return &.{};
    const columns = try arena.alloc([]const u8, fields.len);
    var cells: [api.max_rows]r.Types.Values.Cell = undefined;
    var total: usize = 0;
    for (fields, columns, 0..) |field, *output, i| {
        var size: usize = 0;
        for (cells[0..batch.len], 0..) |*value, row| {
            value.* = batch.cell(row, i);
            size = try std.math.add(usize, size, try countCell(value.*, field));
        }
        total = try std.math.add(usize, total, size);
        if (total > api.max_batch_bytes) return error.SqlBatchTooLarge;
        // Plain cells add at most a length per value/alternative, a tag stream,
        // the page header and four alignment pads. Canonical alternative clocks
        // alone exceed their added length overhead, so twice the canonical bytes
        // plus this fixed per-column allowance bounds every supported layout.
        const capacity = try std.math.add(usize, try std.math.mul(usize, size, 2), 512 + batch.len * 8);
        const page = try arena.alignedAlloc(u8, .fromByteUnits(api.ResultFrame.alignment), capacity);
        output.* = try p.encodeColumnPage(scratch, column(field, i), cells[0..batch.len], page);
    }
    return columns;
}

/// Hot scalar columns borrow Arrow-compatible value buffers without a cell
/// matrix. Other types allocate descriptors/recursive metadata, borrowing payload
/// bytes. Input, arena and schema must all outlive the returned batch.
pub fn decode(scratch: std.mem.Allocator, arena: std.mem.Allocator, fields: []const r.Types.Field, pages: []const []const u8, rows: usize) !r.Batch {
    if (rows > api.max_rows or fields.len > api.ResultFrame.max_columns) return error.InvalidResultChunk;
    if (rows == 0) {
        if (pages.len != 0) return error.InvalidResultColumn;
        return .fromRows(&.{});
    }
    if (pages.len != fields.len) return error.InvalidResultColumn;
    const columns = try arena.alloc(r.Batch.Column, fields.len);
    var total: usize = 0;
    for (fields, pages, columns, 0..) |field, page, *out, i| {
        if (page.len < p.page_header_bytes or std.mem.readInt(u32, page[37..41], .little) != rows) return error.InvalidResultColumn;
        if (p.PlainBuffers.supports(field.type)) {
            out.* = .{ .plain = try p.borrowPlainColumn(scratch, arena, column(field, i), page) };
        } else {
            const decoded = try p.decodeColumnPageBorrowingBytes(scratch, arena, column(field, i), page, null);
            out.* = .{ .cells = decoded.cells };
        }
        if (out.len() != rows) return error.InvalidResultColumn;
        for (0..rows) |row| {
            total = try std.math.add(usize, total, try countCell(out.cell(row), field));
            if (total > api.max_batch_bytes) return error.SqlBatchTooLarge;
        }
    }
    return .fromColumns(columns, rows);
}

test "binary result columns preserve exact values while borrowing Arrow and nested bytes" {
    const t = std.testing;
    const child: r.Types.Field = .{ .name = "text", .type = .utf8 };
    const fields = [_]r.Types.Field{
        .{ .name = "id", .type = .uint64 },
        .{ .name = "body", .type = .utf8 },
        .{ .name = "wide", .type = .uint128 },
        .{ .name = "nested", .type = .{ .structure = &.{child} } },
    };
    const nested = [_]r.Types.Values.Cell{.{ .value = .{ .atom = .{ .bytes = "nested bytes" } } }};
    const cells = [_]r.Types.Values.Cell{
        .{ .value = .{ .atom = .{ .unsigned = 17 } } },
        .{ .value = .{ .atom = .{ .bytes = "hello" } } },
        .{ .value = .{ .atom = .{ .unsigned = std.math.maxInt(u128) } } },
        .{ .value = .{ .structure = &nested } },
    };
    var encoded: std.heap.ArenaAllocator = .init(t.allocator);
    defer encoded.deinit();
    const pages = try encode(t.allocator, encoded.allocator(), &fields, .fromRows(&.{&cells}));
    var decoded: std.heap.ArenaAllocator = .init(t.allocator);
    defer decoded.deinit();
    const batch = try decode(t.allocator, decoded.allocator(), &fields, pages, 1);
    try batch.validate(&fields);
    for (cells, 0..) |expected, i| try t.expectEqualDeep(expected, batch.cell(0, i));
    const pointer = batch.cell(0, 3).value.structure[0].value.atom.bytes.ptr;
    try t.expect(@intFromPtr(pointer) >= @intFromPtr(pages[3].ptr) and @intFromPtr(pointer) < @intFromPtr(pages[3].ptr) + pages[3].len);
    var buffers: [3]r.fuze.arrow.SharedBuffer = undefined;
    const arrow = try (try batch.columnAt(0)).arrowValues(&buffers);
    try t.expectEqual(17, try (r.fuze.arrow.PrimitiveArray(u64){ .data = &arrow }).value(0));
    try t.expectEqual(.plain, std.meta.activeTag(batch.layout.columns.values[0]));
    try t.expectError(error.InvalidResultColumn, decode(t.allocator, decoded.allocator(), &fields, pages, 2));
    const retained = try r.Types.Values.cloneValidated(decoded.allocator(), batch.cell(0, 3));
    @memset(@constCast(pages[3]), 'x');
    try t.expectEqualDeep(cells[3], retained);
    try t.expectEqualStrings("xxxxxxxxxxxx", batch.cell(0, 3).value.structure[0].value.atom.bytes);
}

test "column encoding capacity covers long conflicts and byte budget refuses oversized rows" {
    const t = std.testing;
    const field: r.Types.Field = .{ .name = "body", .type = .utf8, .nullable = true, .optional = true };
    const alternatives = [_]r.Types.Values.Alternative{
        .{ .counter = 1, .replica = 1, .value = .null },
        .{ .counter = 2, .replica = 1, .value = .{ .value = .{ .atom = .{ .bytes = "variable conflict" } } } },
    };
    const cells = [_][1]r.Types.Values.Cell{
        .{.missing}, .{.null}, .{.{ .type_error = .int64 }}, .{.{ .conflict = &alternatives }},
    };
    const rows = [_]r.Row{ &cells[0], &cells[1], &cells[2], &cells[3] };
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const pages = try encode(t.allocator, arena.allocator(), &.{field}, .fromRows(&rows));
    const batch = try decode(t.allocator, arena.allocator(), &.{field}, pages, rows.len);
    for (cells, 0..) |expected, row| try t.expectEqualDeep(expected[0], batch.cell(row, 0));
    const large = try t.allocator.alloc(u8, api.max_batch_bytes);
    defer t.allocator.free(large);
    @memset(large, 'x');
    const oversized = [_]r.Types.Values.Cell{.{ .value = .{ .atom = .{ .bytes = large } } }};
    try t.expectError(error.SqlBatchTooLarge, encode(t.allocator, arena.allocator(), &.{field}, .fromRows(&.{&oversized})));
}

test "independent binary peer fixture decodes wide missing and null columns" {
    const t = std.testing;
    const text = std.mem.trim(u8, @embedFile("fixtures/result-frame.hex"), "\n");
    const bytes = try t.allocator.alignedAlloc(u8, .fromByteUnits(64), text.len / 2);
    defer t.allocator.free(bytes);
    _ = try std.fmt.hexToBytes(bytes, text);
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const frame = try api.ResultFrame.parseBorrowed(arena.allocator(), bytes);
    const schema = try r.Types.decodeInto(arena.allocator(), frame.description.?.schema);
    try t.expectEqual(try schema.fingerprint(), frame.schema);
    try t.expectEqual(try r.Observation.fingerprint(arena.allocator(), frame.description.?.observation), frame.observation);
    const batch = try decode(t.allocator, arena.allocator(), schema.structure, frame.columns, frame.rows);
    try t.expectEqual(1, batch.len);
    try t.expectEqual(std.math.maxInt(u128), batch.cell(0, 0).value.atom.unsigned);
    try t.expectEqual(.missing, std.meta.activeTag(batch.cell(0, 1)));
    try t.expectEqual(.null, std.meta.activeTag(batch.cell(0, 2)));
    try t.expectEqual(1, frame.completion.?.rows);
}

test "compact Fuze string lanes cross SQL result encoding with detached raw bytes" {
    const t = std.testing;
    const fields = [_]r.Types.Field{
        .{ .name = "text", .type = .utf8 },
        .{ .name = "bytes", .type = .binary },
    };
    const texts = [_][]const u8{ "MiXeD  ", "MiXeD long original payload  " };
    const binaries = [_][]const u8{ "\xff\x00", "\xfflong binary payload\x00" };
    var encoded = std.heap.ArenaAllocator.init(t.allocator);
    defer encoded.deinit();
    const pages = block: {
        var plan: api.fuze.LogicalQuery.Plan = .{ .schema = .{ .structure = &fields }, .source_basis = @splat(14), .projection = &.{ 0, 1 } };
        plan.collations.columns[0] = .ascii_ci;
        var source = try api.fuze.Batch.init(t.allocator, plan, .{ .rows = 2, .bytes = 65536 });
        defer source.deinit();
        for (texts, binaries, 0..) |text, binary, i| try source.append(&.{
            .{ .value = .{ .atom = .{ .bytes = text } } },
            .{ .value = .{ .atom = .{ .bytes = binary } } },
        }, .{ .row = i + 1, .boundary = 1 });
        var columns = [_]r.Batch.Column{
            .{ .vector = source.columns[0].view(source.len) },
            .{ .vector = source.columns[1].view(source.len) },
        };
        const batch = r.Batch.fromColumns(&columns, source.len);
        const result = try encode(t.allocator, encoded.allocator(), &fields, batch);
        columns[0].vector.flat.data.strings = columns[0].vector.flat.data.strings[0..1];
        try t.expectError(error.InvalidResultColumn, batch.validate(&fields));
        source.reset(); // Encoded output must not borrow the vector's inline bytes.
        try source.append(&.{
            .{ .value = .{ .atom = .{ .bytes = "changed" } } },
            .{ .value = .{ .atom = .{ .bytes = "changed" } } },
        }, .{ .row = 1, .boundary = 1 });
        break :block result;
    };
    var decoded = std.heap.ArenaAllocator.init(t.allocator);
    defer decoded.deinit();
    const batch = try decode(t.allocator, decoded.allocator(), &fields, pages, 2);
    try batch.validate(&fields);
    for (texts, binaries, 0..) |text, binary, i| {
        try t.expectEqualStrings(text, batch.cell(i, 0).value.atom.bytes);
        try t.expectEqualSlices(u8, binary, batch.cell(i, 1).value.atom.bytes);
    }
}

test "independent workload frames preserve original selection and terminal coverage" {
    const t = std.testing;
    inline for (.{ "append", "consume", "claim", "consume-limit", "consume-zero" }) |kind| {
        const text = std.mem.trim(u8, @embedFile("fixtures/workload-" ++ kind ++ "-frame.hex"), "\n");
        const bytes = try t.allocator.alignedAlloc(u8, .fromByteUnits(64), text.len / 2);
        defer t.allocator.free(bytes);
        _ = try std.fmt.hexToBytes(bytes, text);
        var arena: std.heap.ArenaAllocator = .init(t.allocator);
        defer arena.deinit();
        const frame = try api.ResultFrame.parseBorrowed(arena.allocator(), bytes);
        const observation = frame.description.?.observation;
        const workload = observation.data.workload;
        const evidence: r.Workload.Evidence = .{
            .intent = workload.intent,
            .binding = try workload.selection.binding(arena.allocator()),
            .receipt = switch (workload.selection) {
                .append => |value| .{ .append = value },
                .consume => |value| .{ .consume = value },
                .claim => |value| .{ .claim = value },
            },
        };
        const command: r.Command = switch (workload.selection) {
            .append => .produce,
            .consume => .consume,
            .claim => .claim,
        };
        const counts = evidence.counts(command);
        var operation: api.Operation = .{
            .identity = .{ .account = @splat(9), .id = 99, .kind = .workload },
            .command = command,
            .token = @splat(8),
            .phase = .terminal,
            .outcome = .applied,
            .result_kind = .rows,
            .workload = evidence,
            .matched = if (counts) |value| value.matched else 0,
            .changed = if (counts) |value| value.changed else 0,
        };
        try operation.validate();
        try t.expectError(error.SqlRowsRequired, operation.completion());
        try evidence.requireObservation(workload);
        var foreign = workload;
        foreign.intent.sha256[0] ^= 1;
        try t.expectError(error.WorkloadResultConflict, evidence.requireObservation(foreign));
        operation.workload = null;
        try t.expectError(error.MissingWorkloadEvidence, operation.validate());
        operation.workload = evidence;
        operation.result_kind = .command;
        const settled = try operation.completion();
        try t.expectEqualDeep(evidence, settled.workload.?);
        operation.outcome = .cancelled;
        try t.expectError(error.InvalidCommandCompletion, operation.validate());
        operation.workload.?.receipt = .{ .closed = .{ .binding = evidence.binding, .recorded = .{ .partition = 1, .next_lsn = 2 }, .reason = .cancelled } };
        operation.matched = 0;
        operation.changed = 0;
        try operation.validate();
        operation.result_kind = .rows;
        try t.expectError(error.InvalidSqlOperation, operation.validate());
        try t.expectEqual(try r.Observation.fingerprint(arena.allocator(), observation), frame.observation);
        try frame.completion.?.validate(observation);
        const encoded = try api.ResultFrame.encode(t.allocator, frame);
        defer t.allocator.free(encoded);
        try t.expectEqualSlices(u8, bytes, encoded);
        var completion = frame.completion.?;
        completion.workload = null;
        try t.expectError(error.MissingWorkloadCoverage, completion.validate(observation));
        completion = frame.completion.?;
        completion.workload.?.intent.sha256[0] ^= 1;
        try t.expectError(error.WorkloadResultConflict, completion.validate(observation));
        completion = frame.completion.?;
        completion.rows += 10;
        try t.expectError(error.InvalidWorkloadResultCount, completion.validate(observation));
        completion = frame.completion.?;
        if (workload.limit != null) {
            var unlimited = observation;
            unlimited.data.workload.limit = null;
            try t.expectError(error.IncompleteWorkloadCoverage, completion.validate(unlimited));
            var unsatisfied = observation;
            unsatisfied.data.workload.limit.? += 1;
            try t.expectError(error.IncompleteWorkloadCoverage, completion.validate(unsatisfied));
        } else {
            switch (completion.workload.?.position) {
                .append => |*ordinal| ordinal.* -= 1,
                .consume => |*cursor| {
                    try t.expectEqual(1, completion.rows);
                    try t.expectEqual(2, cursor.coverage.rows);
                    cursor.coverage.through -= 1;
                    cursor.coverage.complete = false;
                },
                .claim => |*cursor| cursor.next -= 1,
            }
            try t.expectError(error.IncompleteWorkloadCoverage, completion.validate(observation));
        }
    }
}
