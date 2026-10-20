//! Public signed fixture producer; the independent Python peer owns scheduling.
const std = @import("std");
const wire = @import("transit_client");
const p = wire.protocol;
const g = p.Growth;

pub fn main(init: std.process.Init) !void {
    const root = try p.Ed25519.KeyPair.generateDeterministic(@splat(71));
    const reader = try p.Ed25519.KeyPair.generateDeterministic(@splat(72));
    const setup = [_]g.Command{
        .{ .grant = .{ .subject = 1, .public_key = reader.public_key.toBytes(), .permissions = p.permission(.inspect) } },
        .{ .spawn = .{} },
        .{ .create_resource = .{ .writer = 2 } },
        .{ .grant_resource = .{ .resource = 3, .subject = 1, .permissions = p.State.permission(.read) | p.State.permission(.inspect) } },
    };
    var commands: [setup.len]g.SignedRequest = undefined;
    for (setup, 0..) |command, i| commands[i] = try g.sign(.{ .realm = 42, .principal = 0, .sequence = i + 1, .command = command }, root);
    const fixtures = .{
        .root_key = root.public_key.toBytes(),
        .setup = commands,
        .read = try g.signQuery(.{ .realm = 42, .principal = 0, .kind = .{ .capabilities = {} } }, root),
        .snapshot = try g.signQuery(.{ .realm = 42, .principal = 1, .kind = .{ .snapshot_read = .{ .snapshot = .{ .open = .{ .resource = 3, .nonce = @splat(1) } } } } }, reader),
        .write = try g.sign(.{ .realm = 42, .principal = 0, .sequence = 5, .command = .{ .spawn = .{} } }, root),
        .competing = try g.sign(.{ .realm = 42, .principal = 0, .sequence = 5, .command = .{ .spawn = .{ .code = 2 } } }, root),
        .revoke = try g.sign(.{ .realm = 42, .principal = 0, .sequence = 6, .command = .{ .revoke = 1 } }, root),
        .lost = try g.sign(.{ .realm = 42, .principal = 0, .sequence = 7, .command = .{ .spawn = .{} } }, root),
    };
    var buffer: [8192]u8 = undefined;
    var output = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    try std.json.Stringify.value(fixtures, .{}, &output.interface);
    try output.interface.flush();
}
