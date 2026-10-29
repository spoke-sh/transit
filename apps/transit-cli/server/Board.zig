//! Board owns browser ingress; the manager owns only its local lifecycle.
const std = @import("std");
const q = @import("transit_query");
const http = @import("transit_http_server");
const Installation = @import("Installation.zig");
const Files = @import("Files.zig");
const Provider = @import("Provider.zig");

pub fn configuration(installation: *Installation, allocator: std.mem.Allocator) ![]const u8 {
    const board = installation.config.board.?;
    const path = try installation.path("board.json");
    try Files.json(installation.init.io, allocator, path, .{
        .profile = "native_v1",
        .upstream = installation.wire.url,
        .realm = installation.config.realm,
        .principal = Installation.board,
        .seed_file = try installation.path("board.seed"),
        .listen = "127.0.0.1",
        .port = board.port,
        .public_origin = board.public_origin.?,
        .localhost_alias = true,
        .request_timeout_ms = 3000,
        .upstream_timeout_ms = 2000,
        .read_interval_ms = 100,
        .workbench_file = board.workbench_file,
    });
    return path;
}

/// This check uses Board's actual key, independently of the manager's root.
/// Resource revocation filters the atlas; it must not restore any grant.
pub fn check(installation: *Installation) !void {
    const init = installation.init;
    const seed_path = try std.fs.path.join(init.gpa, &.{ installation.config.installation, "board.seed" });
    defer init.gpa.free(seed_path);
    var key = try q.wire.readKey(init.gpa, init.io, seed_path);
    defer std.crypto.secureZero(u8, std.mem.asBytes(&key));
    const response = try installation.wire.query(.{ .realm = installation.config.realm, .principal = Installation.board, .kind = .identity }, key);
    const identity = response.body.identity;
    if (identity.principal != Installation.board or identity.pid != null or identity.permissions != q.protocol.permission(.inspect)) return error.UnsafeBoardPrincipal;
    const address = try std.fmt.allocPrint(init.gpa, "{s}/health", .{installation.config.board.?.public_origin.?});
    defer init.gpa.free(address);
    if (!Provider.health(init, address)) return error.BoardUnavailable;
}

/// Startup additionally traverses Board's public authorized atlas route, not
/// just its listener health. Parsing is bounded and no credentials are emitted.
pub fn ready(installation: *Installation) !void {
    try check(installation);
    var probe: Probe = .{ .installation = installation };
    try http.deadline(installation.init.io, 4000, Probe.run, .{&probe});
}
const Probe = struct {
    installation: *Installation,
    fn run(self: *Probe) anyerror!void {
        const installation = self.installation;
        var arena = std.heap.ArenaAllocator.init(installation.init.gpa);
        defer arena.deinit();
        const allocator = arena.allocator();
        var client: std.http.Client = .{ .io = installation.init.io, .allocator = allocator };
        defer client.deinit();
        var writer: std.Io.Writer = .fixed(try allocator.alloc(u8, 256 * 1024));
        const result = try client.fetch(.{ .location = .{ .url = try std.fmt.allocPrint(allocator, "{s}/api/v1/atlas", .{installation.config.board.?.public_origin.?}) }, .keep_alive = false, .redirect_behavior = .not_allowed, .response_writer = &writer });
        if (result.status == .forbidden) return error.AccessDenied;
        if (result.status != .ok) return error.BoardUnavailable;
        const Atlas = struct { realm: u64, identity: q.protocol.Growth.Identity, processes: q.protocol.Growth.Batch(q.protocol.Growth.Process, u64), resources: q.protocol.Growth.Batch(q.protocol.Growth.Resource, u64) };
        const parsed = std.json.parseFromSlice(Atlas, allocator, writer.buffered(), .{ .ignore_unknown_fields = true }) catch return error.InvalidBoardResponse;
        const atlas = parsed.value;
        if (atlas.realm != installation.config.realm or atlas.identity.principal != Installation.board or atlas.identity.permissions != q.protocol.permission(.inspect) or atlas.identity.pid != null) return error.UnsafeBoardPrincipal;
    }
};
