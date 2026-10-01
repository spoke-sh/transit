//! Protocol assertions and adversarial proposals, separate from application execution.
const std = @import("std");
const wire = @import("transit_client");
const p = wire.protocol;
const t = std.testing;
const Config = struct {
    url: []const u8,
    realm: u64,
    principal: u64,
    pid: u64,
    publish_to: u64,
    generation: u64,
    seed_file: []const u8,
    expected_state: p.Value,
    state_association: []const u8,
    consumed: u64,
};
fn submitForRejection(client: *wire.Client, signed: p.Growth.SignedRequest) !wire.Receipt {
    // Storage can become unavailable before the requested rejection is observed.
    // Retry only these transient outcomes, with the exact frozen operation and
    // at most three attempts inside the harness's existing 20-second limit.
    for (0..3) |attempt| {
        return client.submit(signed) catch |err| {
            if (attempt < 2 and (err == error.AuthorityUnavailable or err == error.AuthorityTimeout)) continue;
            return err;
        };
    }
    unreachable;
}
fn reject(client: *wire.Client, request: p.Request, key: p.Ed25519.KeyPair, code: p.ErrorCode) !void {
    try t.expectError(error.Rejected, submitForRejection(client, try p.sign(request, key)));
    try t.expectEqual(@as(?p.ErrorCode, code), client.last_rejection);
}
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 3) return error.ExpectedConfigAndPhase;
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, args[1], init.gpa, .limited(wire.max_body));
    defer init.gpa.free(bytes);
    var parsed = try std.json.parseFromSlice(Config, init.gpa, bytes, .{});
    defer parsed.deinit();
    const c = parsed.value;
    const key = try wire.readKey(init.gpa, init.io, c.seed_file);
    var client = wire.Client.init(init.gpa, init.io, c.url);
    defer client.deinit();
    var session: wire.Session = .{ .client = &client, .realm = c.realm, .principal = c.principal, .pid = c.pid, .generation = c.generation, .key = key };
    const read: p.Query = .{ .realm = c.realm, .principal = c.principal, .kind = .{ .process = c.pid } };
    if (std.mem.eql(u8, args[2], "stale")) {
        try t.expectError(error.StaleActivation, session.receive());
        const response = try client.query(read, key);
        const view = response.body.process;
        try reject(&client, .{ .realm = c.realm, .principal = c.principal, .sequence = response.principal_sequence + 1, .command = .{ .turn = .{
            .pid = c.pid,
            .generation = c.generation,
            .input = view.input.?.position,
            .expected_revision = view.process.revision,
        } } }, key, .StaleGeneration);
        return;
    }
    if (std.mem.eql(u8, args[2], "reject")) {
        const initial = (try session.receive()) orelse return error.ExpectedInput;
        const association = (try session.association(try p.Value.init(c.state_association))) orelse return error.MissingStateAssociation;
        const resource = (try client.query(.{ .realm = c.realm, .principal = c.principal, .kind = .{ .resource = association.resource } }, key)).body.resource;
        const opened = try (try session.prepareView(initial, resource, @intCast(std.Io.Clock.real.now(init.io).toMilliseconds() + 30_000))).submit(&client);
        const snapshot = try session.readView(opened.position, try p.Value.init("value"), null);
        const delivery = (try session.receive()).?;
        const pending = try session.prepareCommit(delivery, .{ .views = .{ snapshot.view.?, null, null, null }, .write_view = opened.position, .mutations = .{ .{ .key = try p.Value.init("value"), .value = c.expected_state }, null, null, null }, .outputs = .{ .{ .pid = c.publish_to, .value = c.expected_state }, null, null, null } });
        // Legal computation is the application's concern. Protocol boundaries
        // reject stale state, skipped input, and unauthorized effects atomically.
        var invalid = pending.signed.request;
        invalid.command.turn.expected_revision += 1;
        try reject(&client, invalid, key, .StaleState);
        invalid = pending.signed.request;
        invalid.command.turn.input += 1;
        try reject(&client, invalid, key, .InvalidInput);
        invalid = pending.signed.request;
        invalid.command.turn.effect = try p.Value.init("unauthorized effect");
        try t.expectError(error.AccessDenied, submitForRejection(&client, try p.sign(invalid, key)));
        const before = (try client.query(read, key)).body.process;
        try t.expectEqual(delivery.revision, before.process.revision);
        const unchanged = try session.readView(opened.position, try p.Value.init("value"), null);
        try t.expectEqualDeep(snapshot.page, unchanged.page);
        _ = try (try session.prepareCloseView((try session.receive()).?, opened.position)).submit(&client);
        return; // Valid turns are submitted only by the real example executables.
    } else if (!std.mem.eql(u8, args[2], "verify")) return error.UnknownPhase;
    const recovered = (try client.query(read, key)).body.process;
    const association = (try session.association(try p.Value.init(c.state_association))).?;
    const resource = (try client.query(.{ .realm = c.realm, .principal = c.principal, .kind = .{ .resource = association.resource } }, key)).body.resource;
    const entries = (try client.query(.{ .realm = c.realm, .principal = c.principal, .kind = .{ .entries = .{ .resource = resource.id, .revision = resource.revision, .key = try p.Value.init("value") } } }, key)).body.entries.page;
    try t.expect(entries.entries[0].?.value.eql(c.expected_state));
    try t.expectEqual(c.consumed, recovered.process.consumed);
    try t.expect((try session.receive()) == null);
    std.debug.print("caller {s}: PID {d} verified\n", .{ args[2], c.pid });
}
