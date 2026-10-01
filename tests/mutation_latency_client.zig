//! Persistent public-client control for the owned mutation latency experiment.
//! Exact requests are checkpointed before submission. Failure exits without retry.
const std = @import("std");
const q = @import("transit_query");
const Config = struct { url: []const u8, seed_file: []const u8, connection: q.TableMutationClient.Connection };

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
    var client: q.TableMutationClient = .{ .wire = &wire, .connection = config.connection, .key = try q.protocol.Ed25519.KeyPair.generateDeterministic(seed) };
    std.crypto.secureZero(u8, &seed);
    var input_buffer: [8192]u8 = undefined;
    var input = std.Io.File.stdin().readerStreaming(init.io, &input_buffer);
    var output_buffer: [4096]u8 = undefined;
    var output = std.Io.File.stdout().writerStreaming(init.io, &output_buffer);
    while (try input.interface.takeDelimiter('\n')) |sql| {
        const started = std.Io.Clock.awake.now(init.io);
        const request = try client.compileSql(try .init("items"), sql);
        var random: [8]u8 = undefined;
        try init.io.randomSecure(&random);
        const namespace = std.mem.readInt(u64, &random, .little) | 1;
        const reference = try request.reference(namespace);
        var commands: u32 = 0;
        while (try client.prepareNext(namespace, request)) |pending| {
            commands += 1;
            if (commands > 32) return error.CommandBudgetExceeded;
            try checkpoint(init, .{ .request = request, .namespace = namespace, .pending = pending, .input = @as(?u64, null), .complete = false });
            const receipt = try client.submit(pending);
            try checkpoint(init, .{ .request = request, .namespace = namespace, .pending = pending, .input = receipt.position, .complete = false });
            while (try client.observe(pending, receipt.position) == .pending) {
                if (started.durationTo(std.Io.Clock.awake.now(init.io)).toMilliseconds() >= 300000) return error.OutcomeUnknown;
                try init.io.sleep(.fromMilliseconds(50), .awake);
            }
            if (try client.rejection(pending, receipt.position) != null) return error.MutationInputRejected;
        }
        const status = (try client.status(reference)) orelse return error.MissingOutcome;
        if (!status.terminal()) return error.MissingOutcome;
        try checkpoint(init, .{ .request = request, .namespace = namespace, .outcome = status, .complete = true });
        try std.json.Stringify.value(.{ .mutation = .{ .phase = @tagName(status.phase), .affected_rows = status.affected_rows } }, .{}, &output.interface);
        try output.interface.writeByte('\n');
        try output.interface.flush();
        std.debug.print("Time: {d} ms (client {d} ms)\n", .{ started.durationTo(std.Io.Clock.awake.now(init.io)).toMilliseconds(), started.durationTo(std.Io.Clock.awake.now(init.io)).toMilliseconds() });
    }
}
