//! Public Station/client quota behavior; no core or provider access.
const std = @import("std");
const station = @import("transit_station");
const client = station.client;
const p = client.protocol;
const g = p.Growth;
const t = std.testing;
const Admin = @import("growing_support.zig").Admin(45);
const Expected = struct { pid: u64, resource: u64, admitted: u64, pending: g.SignedRequest };

fn deadline(io: std.Io) u64 {
    return @as(u64, @intCast(std.Io.Clock.real.now(io).toMilliseconds())) + 30000;
}
fn verify(admin: *Admin, expected: Expected) !void {
    const response = try admin.query(.{ .process = expected.pid });
    try t.expectEqual(expected.admitted, response.body.process.process.admitted);
    try t.expectEqual(@as(u64, 1), response.body.process.process.consumed);
    try t.expectEqual(@as(u64, 0), response.body.process.process.cancelled);
    try t.expectEqual(.running, response.body.process.process.lifecycle);
    try t.expect(response.body.process.input != null);
    const resource = (try admin.query(.{ .resource = expected.resource })).body.resource;
    const entry = (try admin.query(.{ .entries = .{ .resource = expected.resource, .revision = resource.revision, .key = try p.Value.init("handled") } })).body.entries.page.entries[0].?;
    try t.expectEqual(@as(i64, 1), try entry.value.asInteger());
}
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const root_key = try p.Ed25519.KeyPair.generateDeterministic(@splat(7));
    var buffer: [2048]u8 = undefined;
    var output = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    if (args.len == 2 and std.mem.eql(u8, args[1], "public")) {
        try std.json.Stringify.value(root_key.public_key.toBytes(), .{}, &output.interface);
        return output.interface.flush();
    }
    if (args.len != 4) return error.Usage;
    var wire = client.Client.init(init.gpa, init.io, args[1]);
    defer wire.deinit();
    wire.timeout_ms = 10000;
    var admin: Admin = .{ .wire = &wire, .key = root_key };
    var response = try admin.query(.{ .capabilities = {} });
    admin.sequence = response.principal_sequence;
    try t.expectEqual(@as(?u64, 24), response.body.capabilities.admission_ceiling);
    try t.expectEqual(@as(u64, 4), response.body.capabilities.control_reserve);
    const expected = if (std.mem.eql(u8, args[2], "write")) blk: {
        const worker_key = try p.Ed25519.KeyPair.generateDeterministic(@splat(8));
        const process = try admin.provision(65536, worker_key);
        try admin.send(process.pid, 1);
        var server = try station.GrowingGenServer.init(.{ .client = &wire, .realm = 45, .principal = 65536, .pid = process.pid, .generation = 2, .key = worker_key }, "state");
        for (0..10) |_| {
            if (try server.poll(deadline(init.io)) == .ready) break;
        } else return error.NoReadyTurn;
        // Capture the view before closing admission, then commit bounded private
        // work from the reserve. A new view for the next input cannot be opened.
        try server.ready.?.put(try p.Value.init("handled"), p.Value.integer(1));
        while ((try admin.query(.{ .capabilities = {} })).position < 24) try admin.send(process.pid, 2);
        const before = (try admin.query(.{ .process = process.pid })).body.process.process;
        try t.expectEqual(@as(u64, 0), before.consumed);
        try server.finish(null);
        try t.expectEqual(.committed, try server.poll(deadline(init.io)));
        for (0..10) |_| {
            _ = server.poll(deadline(init.io)) catch |err| {
                try t.expectEqual(error.AuthorityUnavailable, err);
                try t.expectEqual(@as(?p.ErrorCode, .AdmissionClosed), wire.last_rejection);
                break;
            };
        } else return error.MissingQuotaRefusal;
        const pending = server.pending.?.signed;
        try t.expectEqual(.open_view, std.meta.activeTag(pending.request.command));
        try t.expectError(error.AuthorityUnavailable, server.poll(deadline(init.io)));
        try t.expectEqual(@as(?p.ErrorCode, .AdmissionClosed), wire.last_rejection);
        try t.expect(std.meta.eql(pending, server.pending.?.signed));
        const result: Expected = .{ .pid = process.pid, .resource = process.resource, .admitted = before.admitted, .pending = pending };
        const bytes = try std.json.Stringify.valueAlloc(init.gpa, result, .{});
        defer init.gpa.free(bytes);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = args[3], .data = bytes });
        break :blk result;
    } else if (std.mem.eql(u8, args[2], "recover")) blk: {
        const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, args[3], init.gpa, .limited(client.max_body));
        defer init.gpa.free(bytes);
        const parsed = try std.json.parseFromSlice(Expected, init.gpa, bytes, .{});
        defer parsed.deinit();
        try verify(&admin, parsed.value);
        try t.expectError(error.AuthorityUnavailable, wire.submitGrowing(parsed.value.pending));
        try t.expectEqual(@as(?p.ErrorCode, .AdmissionClosed), wire.last_rejection);
        while ((try admin.query(.{ .capabilities = {} })).position < 28) _ = try admin.submit(.{ .revoke = 65536 });
        try t.expectError(error.AuthorityUnavailable, admin.submit(.{ .own = .{ .pid = parsed.value.pid, .expected_generation = 2, .worker = 0 } }));
        try t.expectEqual(@as(?p.ErrorCode, .ControlCapacity), wire.last_rejection);
        try t.expectError(error.AccessDenied, wire.submitGrowing(parsed.value.pending));
        break :blk parsed.value;
    } else return error.UnknownPhase;
    try verify(&admin, expected);
    response = try admin.query(.{ .capabilities = {} });
    try output.interface.print("Growing Station quota {s}: position={d}, admitted={d}, consumed=1, cancelled=0\n", .{ args[2], response.position, expected.admitted });
    try output.interface.flush();
}
