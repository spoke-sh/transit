//! Framed-row encoding cost, separate from TLS, authority and driver timings.
const std = @import("std");
const pg = @import("transit_postgres");
const my = @import("transit_mysql");
const Probe = @import("transit_memory").AllocationProbe;
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
    try nativeResults(init, cells);
}

fn nativeResults(init: std.process.Init, values: [7]pg.gateway.fuze.Types.Values.Cell) !void {
    const api = pg.gateway.session_protocol;
    const r = api.results;
    const fields = [_]r.Types.Field{
        .{ .name = "signed", .type = .int64 },
        .{ .name = "unsigned", .type = .uint64 },
        .{ .name = "float", .type = .float64 },
        .{ .name = "boolean", .type = .boolean },
        .{ .name = "text", .type = .utf8 },
        .{ .name = "bytes", .type = .binary },
        .{ .name = "nullable", .type = .int64, .nullable = true },
    };
    const schema: r.Types.Type = .{ .structure = &fields };
    var schema_buffer: [r.Types.max_encoding_bytes]u8 = undefined;
    const schema_bytes = try schema.encode(&schema_buffer);
    const schema_hash = try schema.fingerprint();
    const observation: r.Observation.Value = .{ .metadata = .{ .kind = .probe, .consistency = .session, .namespace = null, .definitions = &.{}, .configuration_revision = null, .session_settings = null } };
    const observation_hash = try r.Observation.fingerprint(init.gpa, observation);
    const Cost = struct {
        batch_rows: usize,
        batches: usize = 0,
        framed_bytes: usize = 0,
        maximum_frame_bytes: usize = 0,
        encode_ms: [5]f64 = undefined,
        decode_ms: [5]f64 = undefined,
        encode_allocations: [5]usize = undefined,
        encode_backing: [5]Probe.Counts = undefined,
        decode_backing: [5]Probe.Counts = undefined,
        decode_allocations: [5]usize = undefined,
        encoder_peak_bytes: [5]usize = undefined,
        decoder_peak_bytes: [5]usize = undefined,
    };
    var samples: [2]Cost = undefined;
    for ([_]usize{ 1, api.max_rows }, &samples) |maximum, *sample| {
        sample.* = .{ .batch_rows = maximum };
        for (0..6) |iteration| {
            var encode_counter = Probe{ .parent = init.gpa };
            var decode_counter = Probe{ .parent = init.gpa };
            var encode_memory: r.fuze.MemoryBudget = .{ .parent = encode_counter.allocator(), .limit = 16 * 1024 * 1024 };
            var decode_memory: r.fuze.MemoryBudget = .{ .parent = decode_counter.allocator(), .limit = 16 * 1024 * 1024 };
            var encoded: std.heap.ArenaAllocator = .init(encode_memory.allocator());
            defer encoded.deinit();
            var decoded: std.heap.ArenaAllocator = .init(decode_memory.allocator());
            defer decoded.deinit();
            var cells: [api.max_rows][7]r.Types.Values.Cell = undefined;
            var views: [api.max_rows]r.Row = undefined;
            var offset: usize = 0;
            var batches: usize = 0;
            var bytes: usize = 0;
            var peak_frame: usize = 0;
            var encode_ns: u64 = 0;
            var decode_ns: u64 = 0;
            while (offset < rows) : (batches += 1) {
                const count = @min(maximum, rows - offset);
                for (cells[0..count], views[0..count], 0..) |*row, *view, i| {
                    row.* = values;
                    row[0].value.atom.signed = @intCast(offset + i);
                    view.* = row;
                }
                const encode_start = std.Io.Clock.awake.now(init.io);
                const pages = try api.ResultColumns.encode(encode_memory.allocator(), encoded.allocator(), &fields, .fromRows(views[0..count]));
                const frame = try api.ResultFrame.encode(encode_memory.allocator(), .{
                    .instance = @splat(1),
                    .cursor = @splat(2),
                    .ordinal = batches,
                    .rows = @intCast(count),
                    .schema = schema_hash,
                    .observation = observation_hash,
                    .description = if (batches == 0) .{ .schema = schema_bytes, .observation = observation } else null,
                    .columns = pages,
                    .completion = if (offset + count == rows) .{ .rows = rows } else null,
                });
                encode_ns += @intCast(encode_start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds());
                const decode_start = std.Io.Clock.awake.now(init.io);
                const parsed = try api.ResultFrame.parseBorrowed(decoded.allocator(), frame);
                if (parsed.description) |description| {
                    const logical = try r.Types.decodeInto(decoded.allocator(), description.schema);
                    if (!std.mem.eql(u8, &try logical.fingerprint(), &schema_hash) or !std.mem.eql(u8, &try r.Observation.fingerprint(decoded.allocator(), description.observation), &observation_hash)) return error.InvalidResultIdentity;
                }
                const batch = try api.ResultColumns.decode(decode_memory.allocator(), decoded.allocator(), &fields, parsed.columns, parsed.rows);
                decode_ns += @intCast(decode_start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds());
                // Independent per-occurrence expectations, outside the timing.
                // All scalar bytes must borrow the encoded frame, not a row matrix.
                for (0..count) |i| {
                    if (batch.cell(i, 0).value.atom.signed != offset + i or
                        batch.cell(i, 1).value.atom.unsigned != std.math.maxInt(u64) or
                        batch.cell(i, 2).value.atom.float != -1.25 or !batch.cell(i, 3).value.atom.boolean or
                        !std.mem.eql(u8, batch.cell(i, 4).value.atom.bytes, "snow ☃ and 列") or batch.cell(i, 6) != .null) return error.ChangedResultValue;
                    const binary = batch.cell(i, 5).value.atom.bytes;
                    if (binary.len != 256) return error.ChangedResultValue;
                    for (binary, 0..) |byte, j| if (byte != j) return error.ChangedResultValue;
                    if (@intFromPtr(binary.ptr) < @intFromPtr(frame.ptr) or @intFromPtr(binary.ptr) + binary.len > @intFromPtr(frame.ptr) + frame.len) return error.ResultNotBorrowed;
                }
                if ((offset + count == rows) != (parsed.completion != null)) return error.InvalidResultCompletion;
                if (parsed.completion) |complete| if (complete.rows != rows) return error.InvalidResultCompletion;
                bytes += frame.len;
                peak_frame = @max(peak_frame, frame.len);
                encode_memory.allocator().free(frame);
                _ = decoded.reset(.free_all);
                _ = encoded.reset(.free_all);
                if (encode_memory.used != 0 or decode_memory.used != 0) return error.RetainedResultAllocation;
                offset += count;
            }
            if (batches != (rows + maximum - 1) / maximum) return error.UnexpectedResultAmplification;
            if (iteration != 0) {
                sample.encode_ms[iteration - 1] = @as(f64, @floatFromInt(encode_ns)) / 1e6;
                sample.decode_ms[iteration - 1] = @as(f64, @floatFromInt(decode_ns)) / 1e6;
                if (sample.framed_bytes != bytes) return error.UnstableEncodingSize;
                sample.encode_allocations[iteration - 1] = encode_counter.counts.alloc_successes;
                sample.decode_allocations[iteration - 1] = decode_counter.counts.alloc_successes;
                sample.encode_backing[iteration - 1] = encode_counter.counts;
                sample.decode_backing[iteration - 1] = decode_counter.counts;
                sample.encoder_peak_bytes[iteration - 1] = encode_memory.peak;
                sample.decoder_peak_bytes[iteration - 1] = decode_memory.peak;
            }
            sample.batches = batches;
            sample.framed_bytes = bytes;
            sample.maximum_frame_bytes = peak_frame;
        }
    }
    if (samples[0].batches <= samples[1].batches or samples[0].framed_bytes <= samples[1].framed_bytes or std.mem.min(usize, &samples[0].encode_allocations) <= std.mem.max(usize, &samples[1].encode_allocations)) return error.AmplificationControlNotDetected;
    const output = try std.json.Stringify.valueAlloc(init.gpa, .{
        .profile = "native_result_encoding",
        .rows_per_sample = rows,
        .columns = fields.len,
        .warmups = 1,
        .repetitions = 5,
        .optimize = @tagName(@import("builtin").mode),
        .samples = samples,
        .limits = "Actual TSR1/TCP1 encode/decode with independent scalar checks; one-row control versus full batches, initial schema/observation and verified terminal count. Counts backing allocation, resize and remap attempts and successes, frees and bytes. Encoder peak includes columns, scratch and frame; decoder peak excludes the borrowed input frame and stack/schema buffers. Each batch releases all accounted allocations. Timings exclude fixture generation and independent verification; include codec validation and initial metadata. No socket, service, query or storage work; no network throughput guarantee.",
    }, .{});
    defer init.gpa.free(output);
    try std.Io.File.stdout().writeStreamingAll(init.io, output);
    try std.Io.File.stdout().writeStreamingAll(init.io, "\n");
}
