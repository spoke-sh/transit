//! Provision and inspect the real worker through signed public operations only.
const std = @import("std");
const http = @import("transit_station_http");
const x = http.exchange;
const s = @import("transit_station");
const p = s.protocol;
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
    if (args.len != 4) return error.ExpectedAuthorityOperationState;
    var wire = s.client.Client.init(init.gpa, init.io, args[1]);
    defer wire.deinit();
    var admin: Admin = .{ .wire = &wire, .key = root };
    admin.sequence = (try admin.query(.{ .capabilities = {} })).principal_sequence;
    var saved: Saved = undefined;
    if (std.mem.eql(u8, args[2], "provision")) {
        const created = try admin.provision(65536, worker);
        saved = .{ .pid = created.pid, .resource = created.resource };
        _ = try admin.submit(.{ .grant = .{ .subject = 65536, .public_key = worker.public_key.toBytes(), .permissions = p.permission(.inspect) | p.permission(.execute) | p.permission(.publish) | p.permission(.send) | p.permission(.effect), .pid = saved.pid } });
        // Principal replacement invalidates previous resource grants by epoch.
        _ = try admin.submit(.{ .grant_resource = .{ .resource = saved.resource, .subject = 65536, .permissions = p.State.all_permissions } });
    } else {
        const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, args[3], init.arena.allocator(), .limited(4096));
        const parsed = try std.json.parseFromSlice(Saved, init.arena.allocator(), bytes, .{});
        saved = parsed.value;
        if (std.mem.eql(u8, args[2], "own")) {
            _ = try admin.submit(.{ .own = .{ .pid = saved.pid, .expected_generation = saved.generation, .worker = 65536 } });
            saved.generation += 1;
        } else if (std.mem.eql(u8, args[2], "revoke")) {
            _ = try admin.submit(.{ .grant_resource = .{ .resource = saved.resource, .subject = 65536, .permissions = 0 } });
        } else if (std.mem.eql(u8, args[2], "restore")) {
            _ = try admin.submit(.{ .grant_resource = .{ .resource = saved.resource, .subject = 65536, .permissions = p.State.all_permissions } });
        } else if (std.mem.eql(u8, args[2], "inspect") or std.mem.eql(u8, args[2], "replay")) {
            var reader: x.Client = .{ .wire = &wire, .realm = 47, .principal = 65536, .key = worker };
            const descriptor = try reader.inspect(saved.resource, 1);
            if (std.mem.eql(u8, args[2], "replay")) {
                const reference: x.Client.Reference = .{ .resource = saved.resource, .exchange = 1, .chain = descriptor.chain };
                var replay = try http.Replay.open(&reader, reference, .captured);
                var hash = std.crypto.hash.sha2.Sha256.init(.{});
                var count: usize = 0;
                var checked_revoke = false;
                while (true) {
                    const part = (try replay.read()) orelse break;
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
                        try std.testing.expectError(error.HttpReplayFailed, replay.read());
                        replay = try http.Replay.open(&reader, reference, .captured);
                        hash = .init(.{});
                        count = 0;
                    }
                }
                try std.testing.expect(checked_revoke);
                try std.testing.expect(replay.done);
                try std.testing.expectEqual(@as(u32, 1), replay.validator.omission.?.request_secrets);
                try output.interface.print("{{\"bytes\":{d},\"sha256\":\"{x}\"}}\n", .{ count, hash.finalResult() });
            } else {
                const effects = (try admin.query(.{ .effects = .{ .pid = saved.pid } })).body.effects;
                const effect = effects.entries[0] orelse return error.UnknownEffect;
                try output.interface.print("{{\"phase\":\"{s}\",\"effect\":\"{s}\",\"segments\":{d},\"collected\":{d}}}\n", .{ @tagName(descriptor.phase), @tagName(effect.phase), descriptor.segments, descriptor.collected });
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
