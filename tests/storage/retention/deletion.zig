const std = @import("std");
const t = std.testing;
const core = @import("transit_core");
const adapter = @import("transit_backend_ursula");

const disk = @import("fixture_native_disk");
const g = disk.g;
const Engine = disk.Engine;
fn submit(e: *Engine, key: core.Ed25519.KeyPair, command: core.Command) !u64 {
    var current = command;
    if (current == .turn) current.turn.expected_revision = (try e.process(current.turn.pid)).revision;
    return e.submit(try core.sign(.{ .realm = e.genesis.realm, .principal = 0, .sequence = (try e.principal(0)).sequence + 1, .command = current }, key));
}
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 3) return error.ExpectedUrlAndPhase;
    const root = try core.Ed25519.KeyPair.generateDeterministic(@splat(21));
    const genesis: core.Genesis = .{ .realm = 54, .root_key = root.public_key.toBytes(), .allow_history_trim = true };
    var client = try adapter.ursula.Client.init(init.gpa, init.io, .{ .base_url = args[1], .max_response_bytes = 2 * 1024 * 1024 });
    defer client.deinit();
    var store: adapter.Store = .{ .journal = .{ .client = &client, .stream = .{ .bucket = "transit-deletion", .name = "authority" } } };
    var pages = try adapter.PackedPageStore.init(init.gpa, store.journal, 8);
    defer pages.deinit();
    const service = std.mem.eql(u8, args[2], "service_seed");
    const write = service or std.mem.eql(u8, args[2], "write");
    if (write) {
        try store.journal.create();
        try pages.create();
    }
    var payloads: adapter.PayloadStore = .{ .journal = &store.journal };
    var e = if (write) try Engine.bootstrap(&store, &pages, genesis) else try Engine.open(&store, &pages, genesis);
    const remove: core.protocol.PayloadRef = .{ .pid = 1, .payload = 2 };
    const retain: core.protocol.PayloadRef = .{ .pid = 1, .payload = 3 };
    if (write) {
        const body = "immutable synthetic bytes; no application dependencies";
        var hash: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(body, &hash, .{});
        _ = try submit(&e, root, .{ .spawn = .{ .allow_collection = true } });
        _ = try submit(&e, root, .{ .declare_payload = .{ .pid = 1, .sha256 = hash, .bytes = body.len, .allow_delete = true } });
        const pending = (try disk.record(&e, g.Payload, .payload, remove.payload));
        try t.expectError(error.InvalidPayload, payloads.createPayloadOnce(pending, "wrong"));
        try payloads.createPayloadOnce(pending, body);
        // Simulate losing publication acknowledgement. Recovery only reads it.
        _ = try submit(&e, root, .{ .declare_payload = .{ .pid = 1, .sha256 = hash, .bytes = body.len } });
        try payloads.createPayloadOnce((try disk.record(&e, g.Payload, .payload, retain.payload)), body);
        _ = try submit(&e, root, .{ .payload_ready = retain });
        if (service) {
            _ = try submit(&e, root, .{ .payload_ready = remove });
            _ = try submit(&e, root, .{ .terminate = 1 });
        }
    } else if (std.mem.eql(u8, args[2], "recover")) {
        try t.expectEqual(.creating, (try disk.record(&e, g.Payload, .payload, remove.payload)).phase);
        try payloads.verifyPayload((try disk.record(&e, g.Payload, .payload, remove.payload)));
        _ = try submit(&e, root, .{ .payload_ready = remove });
        try t.expectError(error.PayloadInUse, submit(&e, root, .{ .retire_payload = remove }));
        try t.expectError(error.PayloadPhase, payloads.reclaimPayload((try disk.record(&e, g.Payload, .payload, remove.payload))));
        _ = try submit(&e, root, .{ .terminate = 1 });
        try t.expectError(error.RetentionNotEnabled, submit(&e, root, .{ .retire_payload = retain }));
        _ = try submit(&e, root, .{ .retire_payload = remove });
        _ = try submit(&e, root, .{ .checkpoint = {} });
        try store.maintain(e.head);
        try payloads.reclaimPayload((try disk.record(&e, g.Payload, .payload, remove.payload)));
        // SIGKILL after DELETE/confirmed 404, before recording its outcome.
    } else if (std.mem.eql(u8, args[2], "checkpoint")) {
        try t.expectEqual(.retiring, (try disk.record(&e, g.Payload, .payload, remove.payload)).phase);
        try payloads.reclaimPayload((try disk.record(&e, g.Payload, .payload, remove.payload)));
        _ = try submit(&e, root, .{ .payload_deleted = remove });
        _ = try submit(&e, root, .{ .checkpoint = {} });
        try store.maintain(e.head);
    } else if (std.mem.eql(u8, args[2], "trim_recover") or std.mem.eql(u8, args[2], "service_verify")) {
        try t.expectEqual(.deleted, (try disk.record(&e, g.Payload, .payload, remove.payload)).phase);
        try t.expect((try disk.record(&e, g.Payload, .payload, remove.payload)).retired_at != null);
        try t.expect((try disk.record(&e, g.Payload, .payload, remove.payload)).deleted_at != null);
        try t.expectError(error.PayloadPhase, submit(&e, root, .{ .payload_ready = remove }));
        try t.expectError(error.PayloadUnavailable, payloads.verifyPayload((try disk.record(&e, g.Payload, .payload, remove.payload))));
        try t.expectEqual(.terminated, (try e.process(1)).lifecycle);
        try t.expectEqual(.ready, (try disk.record(&e, g.Payload, .payload, retain.payload)).phase);
        try payloads.verifyPayload((try disk.record(&e, g.Payload, .payload, retain.payload)));
    } else return error.UnknownPhase;
    std.debug.print("deletion {s}: passed\n", .{args[2]});
}
