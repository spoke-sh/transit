//! Actual caller program used unchanged against local, Compose and Substrate nodes.
const std = @import("std");
const wire = @import("transit_client");
const p = wire.protocol;
const Config = struct { url: []const u8, realm: u64, principal: u8, seed_file: []const u8, anchor: u64, source: ?u64 = null, destination: ?u64 = null };
const Caller = struct {
    client: *wire.Client,
    config: Config,
    key: p.Ed25519.KeyPair,
    fn send(self: Caller, command: p.Command) !u64 {
        const view = try self.client.view(.{ .realm = self.config.realm, .principal = self.config.principal, .sequence = 0, .command = .{ .inspect = self.config.anchor } }, self.key);
        const pending: wire.Session.Pending = .{ .signed = try p.sign(.{ .realm = self.config.realm, .principal = self.config.principal, .sequence = view.principal_sequence + 1, .command = command }, self.key) };
        return (try self.submit(pending)).position;
    }
    fn submit(self: Caller, pending: wire.Session.Pending) !p.Receipt {
        for (0..100) |_| {
            return pending.submit(self.client) catch |err| {
                if (err == error.Rejected or err == error.AccessDenied) return err;
                try self.client.http.io.sleep(.fromMilliseconds(50), .awake);
                continue;
            };
        }
        return error.AuthorityTimeout;
    }
    fn session(self: Caller, pid: u64) wire.Session {
        return .{ .client = self.client, .realm = self.config.realm, .principal = self.config.principal, .pid = pid, .generation = 2, .key = self.key };
    }
};
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 3) return error.ExpectedPhaseAndConfig;
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, args[2], init.gpa, .limited(8192));
    defer init.gpa.free(bytes);
    const parsed = try std.json.parseFromSlice(Config, init.gpa, bytes, .{});
    defer parsed.deinit();
    const config = parsed.value;
    var client = wire.Client.init(init.gpa, init.io, config.url);
    defer client.deinit();
    const caller: Caller = .{ .client = &client, .config = config, .key = try wire.readKey(init.gpa, init.io, config.seed_file) };
    const value = try p.Value.init("correlation:1;reply");
    var output: [1024]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &output);
    if (std.mem.eql(u8, args[1], "prepare")) {
        const source = try caller.send(.{ .lifecycle = .{ .create = .{} } });
        const destination = try caller.send(.{ .lifecycle = .{ .create = .{} } });
        for ([_]u64{ source, destination }) |pid| {
            _ = try caller.send(.{ .lifecycle = .{ .initialize = .{ .pid = pid, .expected_generation = 0 } } });
            _ = try caller.send(.{ .own = .{ .pid = pid, .expected_generation = 1, .worker = config.principal } });
        }
        // Identical value, signed by the very same principal as the eventual
        // process reply. Only the authority's origin can distinguish these.
        _ = try caller.send(.{ .send = .{ .pid = destination, .value = value } });
        _ = try caller.send(.{ .send = .{ .pid = source, .value = value } });
        var session = caller.session(source);
        const input = (try session.receive()).?;
        _ = try caller.submit(try session.prepareCommit(input, .{ .state = try p.Value.init("sent"), .outputs = .{ .{ .pid = destination, .value = input.input.value }, null, null, null } }));
        try std.json.Stringify.value(.{ .source = source, .destination = destination }, .{}, &stdout.interface);
    } else if (std.mem.eql(u8, args[1], "finish")) {
        var session = caller.session(config.destination.?);
        var ignored: u32 = 0;
        var completed = false;
        for (0..200) |_| {
            if (try session.receive()) |input| {
                const origin = input.input.origin.source;
                const accepted = origin == .process and origin.process.pid == config.source.?;
                _ = try caller.submit(try session.prepareCommit(input, .{ .state = if (accepted) try p.Value.init("accepted") else input.state }));
                if (accepted) {
                    if (!input.input.value.eql(value) or ignored != 1) return error.InvalidReply;
                    completed = true;
                    break;
                }
                ignored += 1;
            } else try init.io.sleep(.fromMilliseconds(100), .awake);
        }
        if (!completed) return error.DeliveryTimeout;
        try std.json.Stringify.value(.{ .accepted = true, .ignored_external = ignored }, .{}, &stdout.interface);
    } else return error.UnknownPhase;
    try stdout.interface.writeByte('\n');
    try stdout.interface.flush();
}
