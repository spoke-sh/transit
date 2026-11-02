//! Installed handler-turn baseline. Every pending native command is preserved
//! before dispatch; timed work ends only after the original commit receipt.
const std = @import("std");
const station = @import("transit_station");
const client = station.client;
const p = client.protocol;
const g = p.Growth;
const Server = station.GenServer;
const Probe = @import("transit_memory").AllocationProbe;
const Admin = @import("fixture_growing_support").Admin(43);
const t = std.testing;
const Config = struct { warmup: u32, repeat: u32 };
const Accepted = struct { input: u64, commit: u64 };
const State = struct { behavior: Admin.Provision, sink: u64, config: Config, accepted: []const Accepted };

fn value(index: u64) [128]u8 {
    var bytes: [128]u8 = undefined;
    for (&bytes, 0..) |*byte, i| byte.* = @intCast((index * 17 + i * 31 + 7) % 256);
    return bytes;
}
const Handler = struct {
    sink: u64,
    calls: u32 = 0,
    fn handle(self: *Handler, turn: *station.Turn) !void {
        const frame = try station.Frame.decode(turn.delivery.input.value);
        try t.expectEqual(.cast, frame.kind);
        const index: u64 = @intCast(try frame.payload.asInteger());
        const previous = try turn.read(try p.Value.init("value"));
        if (index == 0) {
            try t.expect(previous == null);
        } else {
            try t.expectEqualSlices(u8, &value(index - 1), previous.?.slice());
        }
        const bytes = try p.Value.init(&value(index));
        try turn.put(try p.Value.init("value"), bytes);
        try turn.cast(self.sink, bytes);
        self.calls += 1;
    }
};
fn save(init: std.process.Init, directory: []const u8, name: []const u8, data: anytype) !void {
    var path: [1024]u8 = undefined;
    const bytes = try p.Json.valueAlloc(init.gpa, data);
    defer init.gpa.free(bytes);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = try std.fmt.bufPrint(&path, "{s}/{s}", .{ directory, name }), .data = bytes });
}
fn load(comptime T: type, init: std.process.Init, directory: []const u8, name: []const u8) !std.json.Parsed(T) {
    var path: [1024]u8 = undefined;
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, try std.fmt.bufPrint(&path, "{s}/{s}", .{ directory, name }), init.gpa, .limited(1024 * 1024));
    defer init.gpa.free(bytes);
    return p.Json.parseFromSliceOwned(T, init.gpa, bytes);
}
fn emit(init: std.process.Init, out: *std.Io.Writer, data: anytype) !void {
    const bytes = try p.Json.valueAlloc(init.gpa, data);
    defer init.gpa.free(bytes);
    try out.writeAll(bytes);
    try out.writeByte('\n');
    try out.flush();
}
fn drive(init: std.process.Init, directory: []const u8, server: *Server, handler: *Handler) !Server.Confirmation {
    const deadline: u64 = @intCast(std.Io.Clock.real.now(init.io).toMilliseconds() + 30000);
    for (0..16) |_| {
        const result = if (server.pending) |pending| blk: {
            var name: [80]u8 = undefined;
            try save(init, directory, try std.fmt.bufPrint(&name, "pending-{d}.json", .{pending.signed.request.sequence}), pending.signed);
            const result = try server.dispatchPending();
            const confirmation = server.confirmation orelse return error.MissingTurnConfirmation;
            try save(init, directory, try std.fmt.bufPrint(&name, "receipt-{d}.json", .{pending.signed.request.sequence}), confirmation);
            break :blk result;
        } else try server.prepare(deadline);
        switch (result) {
            .ready => {
                try handler.handle(&server.ready.?);
                try server.finish(null);
            },
            .committed => return server.confirmation.?,
            .progress => {},
            .idle => return error.MissingAcceptedInput,
            .blocked => return error.HandlerBlocked,
        }
    }
    return error.TurnStepBudget;
}
fn checkState(admin: *Admin, state: State, count: usize) !p.Value {
    const observed = (try admin.query(.{ .process = state.behavior.pid })).body.process;
    try t.expect(observed.input == null);
    try t.expectEqual(count, observed.process.consumed);
    const resource = (try admin.query(.{ .resource = state.behavior.resource })).body.resource;
    const row = (try admin.query(.{ .entries = .{ .resource = resource.id, .revision = resource.revision, .key = try p.Value.init("value") } })).body.entries.page.entries[0] orelse return error.MissingState;
    try t.expectEqualSlices(u8, &value(count - 1), row.value.slice());
    return row.value;
}
fn observedState(init: std.process.Init, out: *std.Io.Writer, admin: *Admin, state: State, count: usize, recovery: bool) !void {
    const observed = try checkState(admin, state, count);
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(observed.slice(), &digest, .{});
    const hex = std.fmt.bytesToHex(digest, .lower);
    try emit(init, out, .{ .event = "state", .index = count - 1, .recovery = recovery, .sha256 = hex[0..] });
}
fn outputs(init: std.process.Init, out: *std.Io.Writer, admin: *Admin, state: State, recovery: bool) !void {
    const position = (try admin.query(.{ .capabilities = {} })).position;
    var after: ?u64 = null;
    var count: usize = 0;
    while (true) {
        const page = (try admin.query(.{ .outputs = .{ .after = after, .position = position } })).body.outputs;
        for (page.entries) |slot| if (slot) |entry| {
            if (count >= state.accepted.len) return error.ExtraOutput;
            try t.expectEqual(state.behavior.pid, entry.source);
            try t.expectEqual(state.sink, entry.destination);
            try t.expectEqual(state.accepted[count].commit, entry.turn);
            try t.expectEqual(@as(u8, 0), entry.index);
            try t.expectEqual(.pending, entry.phase);
            const frame = try station.Frame.decode(entry.value);
            try t.expectEqual(.cast, frame.kind);
            try t.expectEqualSlices(u8, &value(count), frame.payload.slice());
            var hash: [32]u8 = undefined;
            std.crypto.hash.sha2.Sha256.hash(frame.payload.slice(), &hash, .{});
            const hex = std.fmt.bytesToHex(hash, .lower);
            try emit(init, out, .{ .event = "output", .index = count, .recovery = recovery, .input = state.accepted[count].input, .commit = entry.turn, .sha256 = hex[0..] });
            count += 1;
        };
        after = page.next;
        if (after == null) break;
    }
    try t.expectEqual(state.accepted.len, count);
    if (recovery) try observedState(init, out, admin, state, count, true);
}
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    var buffer: [4096]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    const out = &stdout.interface;
    const root = try p.Ed25519.KeyPair.generateDeterministic(@splat(7));
    if (args.len == 2 and std.mem.eql(u8, args[1], "public")) {
        try std.json.Stringify.value(root.public_key.toBytes(), .{}, out);
        return out.flush();
    }
    if (args.len != 4) return error.Usage;
    const directory = args[3];
    var probe: Probe = .{ .parent = init.gpa };
    var wire = client.Client.init(probe.allocator(), init.io, args[1]);
    defer wire.deinit();
    wire.timeout_ms = 10000;
    var admin: Admin = .{ .wire = &wire, .key = root };
    admin.sequence = (try admin.query(.{ .capabilities = {} })).principal_sequence;
    const recovery = std.mem.eql(u8, args[2], "recover");
    if (recovery) {
        const saved = try load(State, init, directory, "state.json");
        defer saved.deinit();
        try outputs(init, out, &admin, saved.value, true);
    } else if (std.mem.eql(u8, args[2], "measure")) {
        const settings = try load(Config, init, directory, "settings.json");
        defer settings.deinit();
        const config = settings.value;
        if (config.warmup == 0 or config.warmup > 10 or config.repeat == 0 or config.repeat > 100) return error.InvalidBenchmarkProfile;
        const key = try p.Ed25519.KeyPair.generateDeterministic(@splat(8));
        const behavior = try admin.provision(65536, key);
        const sink = try admin.submit(.{ .spawn = .{} });
        var server = try Server.init(.{ .client = &wire, .realm = 43, .principal = 65536, .pid = behavior.pid, .generation = behavior.generation, .key = key }, "state");
        server.failure_policy = .stop;
        var handler: Handler = .{ .sink = sink };
        var accepted: [110]Accepted = undefined;
        const count = config.warmup + config.repeat;
        var state: State = .{ .behavior = behavior, .sink = sink, .config = config, .accepted = accepted[0..0] };
        try save(init, directory, "state.json", state);
        for (0..count) |index| {
            // Input admission is outside handler latency, but retains its exact
            // identity before even the first network attempt.
            const request = try g.sign(.{ .realm = 43, .principal = 0, .sequence = admin.sequence + 1, .command = .{ .send = .{ .pid = behavior.pid, .value = try (station.Frame{ .kind = .cast, .payload = p.Value.integer(@intCast(index)) }).encode() } } }, root);
            var name: [80]u8 = undefined;
            try save(init, directory, try std.fmt.bufPrint(&name, "input-{d}.json", .{index}), request);
            try emit(init, out, .{ .event = "input_attempt", .index = index });
            const input = try wire.submit(request);
            admin.sequence += 1;
            try save(init, directory, try std.fmt.bufPrint(&name, "input-receipt-{d}.json", .{index}), input);
            try emit(init, out, .{ .event = "input_accepted", .index = index, .input = input.position });
            const stage: enum { warmup, measured } = if (index < config.warmup) .warmup else .measured;
            try emit(init, out, .{ .event = "attempt", .index = index, .input = input.position, .stage = stage });
            probe.begin(false);
            const start = std.Io.Clock.awake.now(init.io);
            const confirmation = drive(init, directory, &server, &handler) catch |err| {
                try emit(init, out, .{ .event = "failure", .index = index, .cause = @errorName(err), .rejection = wire.last_rejection, .pending = server.pending != null });
                return err;
            };
            const elapsed = start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
            const allocations = probe.counts;
            const peak = probe.peak_bytes;
            try emit(init, out, .{ .event = "confirmed", .index = index, .input = confirmation.input, .commit = confirmation.receipt.position });
            try t.expectEqual(.commit, confirmation.kind);
            try t.expectEqual(input.position, confirmation.input);
            try t.expectEqual(index + 1, handler.calls);
            accepted[index] = .{ .input = input.position, .commit = confirmation.receipt.position };
            state.accepted = accepted[0 .. index + 1];
            try save(init, directory, "state.json", state);
            try observedState(init, out, &admin, state, index + 1, false);
            try emit(init, out, .{ .event = "sample", .index = index, .input = input.position, .commit = confirmation.receipt.position, .stage = stage, .ns = elapsed, .backing = allocations, .client_peak_live_bytes = peak });
        }
        try outputs(init, out, &admin, state, false);
    } else return error.Usage;
    try emit(init, out, .{ .event = "complete", .recovery = recovery, .definition = g.current_definition, .build_mode = @import("builtin").mode });
}
