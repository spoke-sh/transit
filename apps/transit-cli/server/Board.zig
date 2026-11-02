//! Board owns browser ingress; the manager owns only its local lifecycle.
const std = @import("std");
const q = @import("transit_query");
const http = @import("transit_http_server");
const Installation = @import("Installation.zig");
const Files = @import("Files.zig");
const Provider = @import("Provider.zig");
const Sql = @import("Sql.zig");
const sql_client = @import("transit_sql_client");

const Workbench = struct {
    catalog: struct { seed_file: []const u8, connection: q.Values.DirectConnection },
    sql: sql_client.Client.Config,
};
pub const Configuration = struct { path: []const u8, awaiting_local: bool };

pub fn configuration(installation: *Installation, allocator: std.mem.Allocator, sql: ?*const Sql) !Configuration {
    const board = installation.config.board.?;
    // An explicit scope is complete: never fill a missing connection with the
    // local owner, including when that explicit connection fails or is denied.
    const use_local = board.local_data and board.workbench_file == null and installation.config.sql.native.local;
    const local = if (use_local and sql != null) try localConnection(installation, allocator, sql.?) else null;
    const path = try installation.path("board.json");
    _ = try Files.jsonIfChanged(installation.init.io, allocator, path, .{
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
        .workbench = local,
    });
    return .{ .path = path, .awaiting_local = use_local and local == null };
}

fn localConnection(installation: *Installation, allocator: std.mem.Allocator, sql: *const Sql) !?Workbench {
    const account = sql.localAccount() orelse return null;
    const location = sql.local orelse return null;
    const catalog = installation.directCatalog();
    if (account.binding.resource != catalog.scope.resource or account.binding.catalog != catalog.scope.catalog) return error.GatewayIdentityConflict;
    return .{
        .catalog = .{
            .seed_file = try @import("SqlEnrollment.zig").accountPath(installation, allocator, account.name, "table.seed"),
            .connection = try q.Values.DirectConnection.foreign(allocator, .{ .scope = catalog.scope, .branch = catalog.branch, .audience = catalog.audience, .principal = account.principals.table, .role = null }),
        },
        .sql = .{
            .endpoint = try std.fmt.allocPrint(allocator, "unix:{s}", .{location.socket}),
            .account = account.name,
            .database = account.database,
            .authentication = .peer,
            .instance = installation.record.installation,
            .request_timeout_ms = 2000,
        },
    };
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
