//! Isolated configuration host for proofs against independently provisioned native authority.
const std = @import("std");
const q = @import("transit_query");
const Files = @import("server/Files.zig");
const Config = @import("server/Config.zig");
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 2) return error.InvalidProbeArguments;
    const Deployment = struct { source: []const u8, checkpoint: []const u8, gateway: []const u8, binding: q.settings.Contract.Binding, upstream: []const u8, port: u16 };
    const deployment = try Files.read(Deployment, init.io, init.arena.allocator(), args[1]);
    var diagnostic: @import("Diagnostic.zig") = .{};
    const loaded = try Config.capture(init, deployment.source, &diagnostic, true);
    const identity = try loaded.config.identities(init, try std.process.executablePathAlloc(init.io, init.arena.allocator()), &diagnostic);
    try @import("server/Configuration.zig").boot(init, deployment.checkpoint, deployment.binding, @splat(99), loaded, identity);
    try Files.json(init.io, init.gpa, deployment.gateway, @import("server/Gateway.zig").Config{ .port = deployment.port, .upstream = deployment.upstream, .configuration = .{ .path = deployment.checkpoint, .binding = deployment.binding } });
    try @import("server/Gateway.zig").run(init, deployment.gateway);
}
