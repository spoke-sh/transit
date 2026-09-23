//! Protocol assertions and adversarial proposals, separate from application execution.
const std = @import("std");
const wire = @import("transit_client");
const p = wire.protocol;
const t = std.testing;
const Config = struct {
    url: []const u8,
    realm: u64,
    principal: u8,
    pid: u64,
    publish_to: u64,
    generation: u64,
    seed_file: []const u8,
    expected_state: p.Value,
    consumed: u64,
};
fn reject(client: *wire.Client, request: p.Request, key: p.Ed25519.KeyPair, code: p.ErrorCode) !void {
    try t.expectError(error.Rejected, client.submit(try p.sign(request, key)));
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
    const read: p.Request = .{ .realm = c.realm, .principal = c.principal, .sequence = 0, .command = .{ .inspect = c.pid } };
    if (std.mem.eql(u8, args[2], "stale")) {
        try t.expectError(error.StaleActivation, session.receive());
        const view = try client.view(read, key);
        try reject(&client, .{ .realm = c.realm, .principal = c.principal, .sequence = view.principal_sequence + 1, .command = .{ .turn = .{
            .pid = c.pid,
            .generation = c.generation,
            .input = view.input.?.position,
            .expected_revision = view.process.revision,
            .result = c.expected_state,
        } } }, key, .StaleGeneration);
        return;
    }
    if (std.mem.eql(u8, args[2], "reject")) {
        const delivery = (try session.receive()) orelse return error.ExpectedInput;
        const result = c.expected_state;
        const pending = try session.prepareCommit(delivery, .{ .state = result, .outputs = .{ .{ .pid = c.publish_to, .value = result }, null, null, null } });
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
        try t.expectError(error.AccessDenied, client.submit(try p.sign(invalid, key)));
        const before = try client.view(read, key);
        try t.expectEqual(delivery.revision, before.process.revision);
        try t.expect(delivery.state.eql(before.process.state));
        return; // Valid turns are submitted only by the real example executables.
    } else if (!std.mem.eql(u8, args[2], "verify")) return error.UnknownPhase;
    const recovered = try client.view(read, key);
    try t.expect(recovered.process.state.eql(c.expected_state));
    try t.expectEqual(c.consumed, recovered.process.consumed);
    try t.expect((try session.receive()) == null);
    std.debug.print("caller {s}: PID {d} verified\n", .{ args[2], c.pid });
}
