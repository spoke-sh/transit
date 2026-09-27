//! Signed public provisioning/inspection for the real finite RPC worker.
const std = @import("std");
const rpc = @import("transit_station_grpc");
const x = rpc.exchange;
const s = x.station;
const p = x.p;
const Admin = @import("growing_support.zig").Admin(47);
const Saved = struct { pid: u64, resource: u64, generation: u64 = 2 };
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const root = try p.Ed25519.KeyPair.generateDeterministic(@splat(71));
    const worker = try p.Ed25519.KeyPair.generateDeterministic(@splat(72));
    var output_buffer: [4096]u8 = undefined;
    var output = std.Io.File.stdout().writerStreaming(init.io, &output_buffer);
    if (args.len == 2 and std.mem.eql(u8, args[1], "public")) {
        try std.json.Stringify.value(root.public_key.toBytes(), .{}, &output.interface);
        return output.interface.flush();
    }
    if (args.len != 4 and args.len != 5) return error.ExpectedAuthorityOperationState;
    var wire = s.client.Client.init(init.gpa, init.io, args[1]);
    defer wire.deinit();
    var admin: Admin = .{ .wire = &wire, .key = root };
    admin.sequence = (try admin.query(.{ .capabilities = {} })).principal_sequence;
    var saved: Saved = undefined;
    if (std.mem.eql(u8, args[2], "provision")) {
        const pid = try admin.submit(.{ .spawn = .{} });
        const resource = try admin.submit(.{ .create_resource = .{ .writer = pid, .owned = false } });
        saved = .{ .pid = pid, .resource = resource };
        _ = try admin.submit(.{ .grant = .{ .subject = 65536, .public_key = worker.public_key.toBytes(), .permissions = p.permission(.inspect) | p.permission(.execute) | p.permission(.publish) | p.permission(.send) | p.permission(.effect), .pid = saved.pid } });
        _ = try admin.submit(.{ .grant_resource = .{ .resource = saved.resource, .subject = 65536, .permissions = p.State.all_permissions } });
        _ = try admin.submit(.{ .grant_resource = .{ .resource = saved.resource, .subject = 0, .permissions = p.State.all_permissions } });
        _ = try admin.submit(.{ .associate = .{ .pid = pid, .name = try p.Value.init("state"), .resource = resource } });
        _ = try admin.submit(.{ .own = .{ .pid = pid, .expected_generation = 1, .worker = 65536 } });
    } else {
        const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, args[3], init.arena.allocator(), .limited(4096));
        saved = (try std.json.parseFromSlice(Saved, init.arena.allocator(), bytes, .{})).value;
        if (std.mem.eql(u8, args[2], "own")) {
            _ = try admin.submit(.{ .own = .{ .pid = saved.pid, .expected_generation = saved.generation, .worker = 65536 } });
            saved.generation += 1;
        } else if (std.mem.eql(u8, args[2], "revoke") or std.mem.eql(u8, args[2], "restore")) {
            _ = try admin.submit(.{ .grant_resource = .{ .resource = saved.resource, .subject = 65536, .permissions = if (std.mem.eql(u8, args[2], "revoke")) 0 else p.State.all_permissions } });
        } else if (std.mem.eql(u8, args[2], "inspect") or std.mem.eql(u8, args[2], "replay")) {
            const id = if (args.len == 5) try std.fmt.parseInt(u64, args[4], 10) else 1;
            var reader: x.Client = .{ .wire = &wire, .realm = 47, .principal = 65536, .key = worker };
            const descriptor = try reader.inspect(saved.resource, id);
            if (std.mem.eql(u8, args[2], "replay")) {
                const reference: x.Client.Reference = .{ .resource = saved.resource, .exchange = id, .chain = descriptor.chain };
                var replay = try rpc.Replay.open(&reader, reference, .captured);
                var hash = std.crypto.hash.sha2.Sha256.init(.{});
                var count: usize = 0;
                var checked_revoke = false;
                while (try replay.read()) |part| {
                    if (part.kind == .response_body) {
                        hash.update(part.bytes.slice());
                        count += part.bytes.len;
                    }
                    if (part.complete) break;
                    if (!checked_revoke) {
                        _ = try admin.submit(.{ .grant_resource = .{ .resource = saved.resource, .subject = 65536, .permissions = 0 } });
                        try std.testing.expectError(error.AccessDenied, replay.read());
                        _ = try admin.submit(.{ .grant_resource = .{ .resource = saved.resource, .subject = 65536, .permissions = p.State.all_permissions } });
                        checked_revoke = true;
                        try std.testing.expectError(error.GrpcReplayFailed, replay.read());
                        replay = try rpc.Replay.open(&reader, reference, .captured);
                        hash = .init(.{});
                        count = 0;
                    }
                }
                try std.testing.expect(checked_revoke and replay.done);
                const complete = try replay.validator.finish();
                try output.interface.print("{{\"bytes\":{d},\"sha256\":\"{x}\",\"status\":{d},\"messages\":{d}}}\n", .{ count, hash.finalResult(), complete.status, complete.received_messages });
            } else {
                var source = try reader.reader(saved.resource);
                const intent = try source.read(x.Exchange.key(id, 'i', 0));
                var phase: []const u8 = "not_committed";
                if (intent) |value| {
                    const page = try admin.query(.{ .entries = .{ .resource = saved.resource, .revision = source.view.revision, .key = x.Exchange.key(id, 'i', 0) } });
                    const entry = page.body.entries.page.entries[0].?;
                    const effect = (try admin.query(.{ .effects = .{ .pid = saved.pid, .after = entry.revision - 1, .position = page.position } })).body.effects.entries[0].?;
                    try std.testing.expect(effect.id == entry.revision and effect.payload.eql(value));
                    phase = @tagName(effect.phase);
                }
                try output.interface.print("{{\"phase\":\"{s}\",\"effect\":\"{s}\",\"segments\":{d},\"collected\":{d},\"bytes\":{d},\"pending\":{}}}\n", .{ @tagName(descriptor.phase), phase, descriptor.segments, descriptor.collected, descriptor.bytes, descriptor.pending_kind != 0 });
            }
            return output.interface.flush();
        } else return error.UnknownOperation;
    }
    const bytes = try std.json.Stringify.valueAlloc(init.arena.allocator(), saved, .{});
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = args[3], .data = bytes });
    try output.interface.writeAll(bytes);
    try output.interface.writeByte('\n');
    try output.interface.flush();
}
