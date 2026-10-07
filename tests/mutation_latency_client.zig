//! Persistent public-client control for the owned mutation latency experiment.
//! Exact requests are checkpointed before submission. Only unavailable reads retry.
const std = @import("std");
const q = @import("transit_query");
const c = q.catalog;
const Config = struct { url: []const u8, seed_file: []const u8, connection: c.TableClient.Connection };

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
    var client: c.TableClient = .{ .transport = &wire, .connection = config.connection, .key = try q.protocol.Ed25519.KeyPair.generateDeterministic(seed) };
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
        const namespace = std.mem.readInt(u64, &random, .little) | 1;
        var intent = try reads.call(c.TableClient.compile, .{ &client, init.gpa, sql, c.TableClient.CompileIdentity{ .operation = namespace, .namespace = namespace }, null });
        defer intent.deinit();
        if (intent.identity != .dml) return error.ExpectedMutation;
        const saved: c.TableBridge.Saved = .{ .definition = q.protocol.Growth.current_definition, .bytes = try c.TableValues.hex(init.gpa, intent.bytes) };
        defer init.gpa.free(saved.bytes);
        var commands: u32 = 0;
        const status = mutation: while (true) {
            const pending = switch (try reads.call(c.TableClient.next, .{ &client, &intent })) {
                .send => |value| value,
                .terminal => |value| break :mutation value,
                .upload_cancelled => return error.MutationUploadCancelled,
                .running => {
                    try reads.call(c.TableClient.waitForChange, .{ &client, &intent });
                    continue;
                },
            };
            commands += 1;
            if (commands > 32) return error.CommandBudgetExceeded;
            try checkpoint(init, .{ .intent = saved, .pending = pending, .input = @as(?u64, null), .complete = false });
            const receipt = try client.submit(pending);
            try checkpoint(init, .{ .intent = saved, .pending = pending, .input = receipt.position, .complete = false });
            const outcome = observation: while (true) {
                const progress = try reads.call(c.TableClient.waitProgress, .{ &client, &intent, pending, receipt.position });
                switch (progress) {
                    .processed => |value| break :observation value,
                    .pending => {},
                }
            };
            if (outcome.disposition != null) return error.MutationInputRejected;
            if (outcome.outcome) |value| if (value.terminal()) break :mutation value;
        };
        try checkpoint(init, .{ .intent = saved, .outcome = status, .complete = true });
        var arena: std.heap.ArenaAllocator = .init(init.gpa);
        defer arena.deinit();
        try std.json.Stringify.value(.{ .table_operation = try c.TableValues.Outcome.foreign(arena.allocator(), &intent, status) }, .{}, &output.interface);
        try output.interface.writeByte('\n');
        try output.interface.flush();
        std.debug.print("Time: {d} ms (client {d} ms)\n", .{ started.durationTo(std.Io.Clock.awake.now(init.io)).toMilliseconds(), started.durationTo(std.Io.Clock.awake.now(init.io)).toMilliseconds() });
    }
}
