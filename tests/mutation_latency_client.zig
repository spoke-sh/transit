//! Persistent public-client control for the owned mutation latency experiment.
//! Exact requests are checkpointed before submission. Only unavailable reads retry.
const std = @import("std");
const q = @import("transit_query");
const c = q.catalog;
const Config = struct { url: []const u8, seed_file: []const u8, connection: c.DirectTableProtocol.Connection };

fn checkpoint(init: std.process.Init, value: anytype) !void {
    const bytes = try std.json.Stringify.valueAlloc(init.gpa, value, .{});
    defer init.gpa.free(bytes);
    const directory = try std.Io.Dir.cwd().openDir(init.io, ".", .{ .iterate = true });
    defer directory.close(init.io);
    var file = try directory.createFileAtomic(init.io, "client-pending.json", .{ .replace = true, .permissions = .fromMode(0o600) });
    defer file.deinit(init.io);
    try file.file.writeStreamingAll(init.io, bytes);
    try file.file.sync(init.io);
    try file.replace(init.io);
    if (std.c.fsync(directory.handle) != 0) return error.CheckpointSyncFailed;
}

const Reads = struct {
    io: std.Io,
    deadline: i64,
    fn call(self: Reads, comptime read: anytype, args: std.meta.ArgsTuple(@TypeOf(read))) anyerror!@typeInfo(@typeInfo(@TypeOf(read)).@"fn".return_type.?).error_union.payload {
        while (true) {
            if (std.Io.Clock.boot.now(self.io).toMilliseconds() >= self.deadline) return error.OutcomeUnknown;
            return @call(.auto, read, args) catch |err| {
                if (!q.wire.Client.unavailable(err)) return err;
                try self.io.sleep(.fromMilliseconds(50), .awake);
                continue;
            };
        }
    }
};

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 2) return error.Usage;
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, args[1], init.arena.allocator(), .limited(8192));
    const config = try std.json.parseFromSliceLeaky(Config, init.arena.allocator(), bytes, .{});
    const seed_text = try std.Io.Dir.cwd().readFileAlloc(init.io, config.seed_file, init.arena.allocator(), .limited(128));
    var seed: [32]u8 = undefined;
    _ = try std.fmt.hexToBytes(&seed, std.mem.trim(u8, seed_text, "\r\n "));
    var wire = q.wire.Client.init(init.gpa, init.io, config.url);
    defer wire.deinit();
    const client: c.DirectTableClient = .{ .allocator = init.gpa, .authority = &wire, .service = &wire, .connection = config.connection, .key = try q.protocol.Ed25519.KeyPair.generateDeterministic(seed) };
    var session: c.DirectTableBridge.Session = .{ .allocator = init.gpa };
    defer session.deinit();
    std.crypto.secureZero(u8, &seed);
    var input_buffer: [8192]u8 = undefined;
    var input = std.Io.File.stdin().readerStreaming(init.io, &input_buffer);
    var output_buffer: [4096]u8 = undefined;
    var output = std.Io.File.stdout().writerStreaming(init.io, &output_buffer);
    while (try input.interface.takeDelimiter('\n')) |sql| {
        const started = std.Io.Clock.awake.now(init.io);
        errdefer {
            if (wire.last_rejection) |native| std.debug.print("NativeCause: {s}.\n", .{@tagName(native)});
            const elapsed = started.durationTo(std.Io.Clock.awake.now(init.io)).toMilliseconds();
            std.debug.print("Time: {d} ms (client {d} ms)\n", .{ elapsed, elapsed });
        }
        const reads: Reads = .{ .io = init.io, .deadline = std.Io.Clock.boot.now(init.io).toMilliseconds() + 300000 };
        var random: [8]u8 = undefined;
        try init.io.randomSecure(&random);
        var arena: std.heap.ArenaAllocator = .init(init.gpa);
        defer arena.deinit();
        const operation = try c.TableValues.decimal(arena.allocator(), std.mem.readInt(u64, &random, .little) | 1);
        const compile: c.DirectTableBridge.Action = .{ .compile = .{ .namespace = 1, .operation = operation, .create_object = null, .sql = sql, .dialect = .transit, .ingestion = .point } };
        const compiled = (try reads.call(c.DirectTableBridge.Session.apply, .{ &session, &arena, client, compile, null })).compiled;
        try checkpoint(init, .{ .intent = compiled.saved, .reference = @as(?c.DirectTableBridge.Recovery, null), .complete = false });
        const reference = (try session.apply(&arena, client, .{ .stage = compiled.summary.id }, null)).staged;
        try checkpoint(init, .{ .intent = compiled.saved, .reference = reference, .complete = false });
        var status = (try session.apply(&arena, client, .{ .admit = reference }, null)).observation;
        for (0..128) |_| {
            const pending = switch (status) {
                .rows => |value| value == .admitted,
                else => return error.ExpectedMutation,
            };
            if (!pending) break;
            if (std.Io.Clock.boot.now(init.io).toMilliseconds() >= reads.deadline) return error.OutcomeUnknown;
            status = (try session.apply(&arena, client, .{ .operation = .{ .reference = reference, .command = .execute, .steps = 32 } }, null)).observation;
        } else return error.CommandBudgetExceeded;
        // An unavailable mutation stops with the saved original intent on disk.
        // It is never replaced by a new operation or retried as a native send.
        try checkpoint(init, .{ .intent = compiled.saved, .reference = reference, .outcome = status, .complete = true });
        try std.json.Stringify.value(.{ .direct_table = status }, .{}, &output.interface);
        try output.interface.writeByte('\n');
        try output.interface.flush();
        std.debug.print("Time: {d} ms (client {d} ms)\n", .{ started.durationTo(std.Io.Clock.awake.now(init.io)).toMilliseconds(), started.durationTo(std.Io.Clock.awake.now(init.io)).toMilliseconds() });
    }
}
