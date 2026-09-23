const std = @import("std");
const t = std.testing;
const core = @import("transit_core");
const adapter = @import("transit_ursula");

const Engine = core.Engine(adapter.Store);
fn submit(e: *Engine, key: core.Ed25519.KeyPair, command: core.Command) !u64 {
    var current = command;
    if (current == .turn) current.turn.expected_revision = (try e.state.process(current.turn.pid)).revision;
    return e.submit(try core.sign(.{ .realm = e.state.realm, .principal = 0, .sequence = (try e.state.principal(0)).sequence + 1, .command = current }, key));
}
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 3) return error.ExpectedUrlAndPhase;
    const root = try core.Ed25519.KeyPair.generateDeterministic(@splat(21));
    const genesis: core.Genesis = .{ .realm = 54, .root_key = root.public_key.toBytes(), .retry_policy = .last_per_principal };
    var client = try adapter.ursula.Client.init(init.gpa, init.io, .{ .base_url = args[1], .max_response_bytes = 2 * 1024 * 1024 });
    defer client.deinit();
    var store: adapter.Store = .{ .journal = .{ .client = &client, .stream = .{ .bucket = "transit-deletion", .name = "authority" } } };
    const service = std.mem.eql(u8, args[2], "service_seed");
    const write = service or std.mem.eql(u8, args[2], "write");
    if (write) try store.journal.create();
    var e = if (write) try Engine.bootstrap(&store, genesis) else try Engine.open(&store, genesis);
    const remove: core.PayloadRef = .{ .pid = 1, .payload = 2 };
    const retain: core.PayloadRef = .{ .pid = 1, .payload = 3 };
    if (write) {
        const body = "immutable synthetic bytes; no application dependencies";
        var hash: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(body, &hash, .{});
        _ = try submit(&e, root, .{ .spawn = .{ .allow_trim = true } });
        _ = try submit(&e, root, .{ .declare_payload = .{ .pid = 1, .sha256 = hash, .bytes = body.len, .allow_delete = true } });
        const pending = (try e.state.payload(remove)).*;
        try t.expectError(error.InvalidPayload, store.createPayloadOnce(pending, "wrong"));
        try store.createPayloadOnce(pending, body);
        // Simulate losing publication acknowledgement. Recovery only reads it.
        _ = try submit(&e, root, .{ .declare_payload = .{ .pid = 1, .sha256 = hash, .bytes = body.len } });
        try store.createPayloadOnce((try e.state.payload(retain)).*, body);
        _ = try submit(&e, root, .{ .payload_ready = retain });
        if (service) {
            _ = try submit(&e, root, .{ .payload_ready = remove });
            _ = try submit(&e, root, .{ .terminate = 1 });
        }
    } else if (std.mem.eql(u8, args[2], "recover")) {
        try t.expectEqual(.creating, (try e.state.payload(remove)).phase);
        try store.verifyPayload((try e.state.payload(remove)).*);
        _ = try submit(&e, root, .{ .payload_ready = remove });
        try t.expectError(error.PayloadInUse, submit(&e, root, .{ .retire_payload = remove }));
        try t.expectError(error.PayloadPhase, store.reclaimPayload((try e.state.payload(remove)).*));
        _ = try submit(&e, root, .{ .terminate = 1 });
        try t.expectError(error.RetentionNotEnabled, submit(&e, root, .{ .retire_payload = retain }));
        _ = try submit(&e, root, .{ .retire_payload = remove });
        _ = try submit(&e, root, .{ .checkpoint = {} });
        try store.maintain(&(try core.Checkpoint.create(init.gpa, genesis, &e.state)));
        try store.reclaimPayload((try e.state.payload(remove)).*);
        // SIGKILL after DELETE/confirmed 404, before recording its outcome.
    } else if (std.mem.eql(u8, args[2], "checkpoint")) {
        try t.expectEqual(.retiring, (try e.state.payload(remove)).phase);
        try store.reclaimPayload((try e.state.payload(remove)).*);
        _ = try submit(&e, root, .{ .payload_deleted = remove });
        _ = try submit(&e, root, .{ .checkpoint = {} });
        try store.maintain(&(try core.Checkpoint.create(init.gpa, genesis, &e.state)));
    } else if (std.mem.eql(u8, args[2], "trim_recover") or std.mem.eql(u8, args[2], "service_verify")) {
        try t.expectEqual(.deleted, (try e.state.payload(remove)).phase);
        try t.expect((try e.state.payload(remove)).retired_at != null);
        try t.expect((try e.state.payload(remove)).deleted_at != null);
        try t.expectError(error.PayloadPhase, submit(&e, root, .{ .payload_ready = remove }));
        try t.expectError(error.PayloadUnavailable, store.verifyPayload((try e.state.payload(remove)).*));
        try t.expectEqual(.terminated, (try e.state.process(1)).lifecycle);
        try t.expectEqual(.ready, (try e.state.payload(retain)).phase);
        try store.verifyPayload((try e.state.payload(retain)).*);
    } else return error.UnknownPhase;
    std.debug.print("deletion {s}: passed\n", .{args[2]});
}
