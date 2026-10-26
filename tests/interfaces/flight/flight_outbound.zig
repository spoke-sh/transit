//! Actual adapter construction and captured Flight interpretation, no network peer.
const std = @import("std");
const f = @import("transit_station_flight");
const rpc = f.rpc;
const x = rpc.exchange;
const a = f.flight.query.fuze.arrow;
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 4) return error.Usage;
    if (std.mem.eql(u8, args[1], "prepare")) {
        const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, args[2], init.gpa, .limited(65536));
        defer init.gpa.free(bytes);
        var descriptor = try rpc.transport.Descriptor.parse(init.gpa, bytes);
        defer descriptor.deinit();
        var message: [16384]u8 = undefined;
        const call = try f.get(&descriptor, "finite-int64", &.{.{ .name = "authorization", .value = .{ .secret = .{ .binding = "peer", .version = 1 } } }}, &message);
        var metadata: [8192]u8 = undefined;
        var batch: [rpc.Batch.maximum_bytes]u8 = undefined;
        const prepared = try call.prepare(1, 1, 1, 300000, 1, &metadata, &batch);
        inline for (.{ "request.json", "batch.bin" }, .{ prepared.metadata, prepared.batch }) |name, content| {
            const path = try std.fmt.allocPrint(init.arena.allocator(), "{s}/{s}", .{ args[3], name });
            try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = content });
        }
        return;
    }
    const saved = try std.Io.Dir.cwd().readFileAlloc(init.io, args[3], init.gpa, .limited(4096));
    defer init.gpa.free(saved);
    const parsed = try std.json.parseFromSlice(struct { resource: u64 }, init.gpa, saved, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    var wire = x.station.client.Client.init(init.gpa, init.io, args[2]);
    defer wire.deinit();
    var client: x.Client = .{ .wire = &wire, .realm = 47, .principal = 65536, .key = try x.p.Ed25519.KeyPair.generateDeterministic(@splat(72)) };
    const record = try client.inspect(parsed.value.resource, 1);
    var replay = try f.Replay.open(&client, .{ .resource = parsed.value.resource, .exchange = 1, .chain = record.chain });
    const workspace = try init.gpa.alloc(u8, 8 * 1024 * 1024 + 65536);
    defer init.gpa.free(workspace);
    var rows: u64 = 0;
    var complete = false;
    while (try replay.next(workspace)) |event| switch (event) {
        .schema => {},
        .batch => |captured| {
            var fixed: std.heap.FixedBufferAllocator = .init(workspace);
            var input: std.Io.Reader = .fixed(captured.ipc);
            var reader = a.IpcStreamReader(*std.Io.Reader).init(fixed.allocator(), &input);
            defer reader.deinit();
            const schema = try reader.readSchema();
            try std.testing.expectEqual(@as(usize, 2), schema.fields.len);
            try std.testing.expectEqualStrings("id", schema.fields[0].name);
            try std.testing.expect(!schema.fields[0].nullable and schema.fields[1].nullable);
            var batch = (try reader.nextRecordBatch()).?;
            defer batch.deinit();
            const ids: a.Int64Array = .{ .data = batch.column(0).data() };
            const values: a.Int64Array = .{ .data = batch.column(1).data() };
            for (0..batch.numRows()) |index| {
                try std.testing.expectEqual(@as(i64, @intCast(rows)), try ids.value(index));
                try std.testing.expectEqual(rows % 5 == 0, values.data.isNull(index));
                if (rows % 5 != 0) try std.testing.expectEqual(@as(i64, @intCast(9007199254740993 + rows)), try values.value(index));
                rows += 1;
            }
        },
        .complete => |outcome| {
            try std.testing.expectEqual(@as(u32, 0), outcome.status);
            complete = true;
        },
    };
    try std.testing.expect(complete and rows == 41);
    var buffer: [512]u8 = undefined;
    var output = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    try output.interface.print("{{\"complete\":true,\"rows\":{d},\"batches\":{d}}}\n", .{ rows, replay.batches });
    try output.interface.flush();
}
