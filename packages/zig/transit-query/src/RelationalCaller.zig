//! Stable owner for configured relational clients and their one live session.
//! Borrows the transport and I/O; owns client key copies, directory and session.
const std = @import("std");
const q = @import("root.zig");
const b = q.RelationalBridge;
const Self = @This();
allocator: std.mem.Allocator,
io: std.Io,
directory: std.Io.Dir,
catalogs: [2]q.catalog.TableClient,
routes: [2]*q.catalog.TableClient,
count: usize,
session: b.Session,

pub fn create(allocator: std.mem.Allocator, io: std.Io, wire: *q.wire.Client, key: q.protocol.Ed25519.KeyPair, config: b.Config) !*Self {
    if (config.catalogs.len == 0 or config.catalogs.len > 2 or config.spill_directory.len == 0 or config.spill_directory.len > 4096) return error.InvalidRelationalSources;
    const options = try config.options.native();
    const first = try config.catalogs[0].native();
    for (config.catalogs) |connection| {
        const native = try connection.native();
        if (native.scope.realm != first.scope.realm or native.principal != first.principal) return error.RelationalCallerChanged;
    }
    const directory = try std.Io.Dir.cwd().openDir(io, config.spill_directory, .{});
    errdefer directory.close(io);
    const self = try allocator.create(Self);
    self.* = .{ .allocator = allocator, .io = io, .directory = directory, .catalogs = undefined, .routes = undefined, .count = config.catalogs.len, .session = undefined };
    for (config.catalogs, 0..) |connection, i| {
        self.catalogs[i] = .{ .transport = wire, .connection = connection.native() catch unreachable, .key = key };
        self.routes[i] = &self.catalogs[i];
    }
    self.session = .{ .allocator = allocator, .io = io, .directory = directory, .clients = self.routes[0..self.count], .options = options };
    return self;
}

pub fn destroy(self: *Self) void {
    self.session.deinit();
    self.directory.close(self.io);
    for (self.catalogs[0..self.count]) |*catalog| std.crypto.secureZero(u8, std.mem.asBytes(&catalog.key));
    self.allocator.destroy(self);
}

pub const Route = struct { connection: q.catalog.TableValues.Connection, resource_revision: u64, policy_revision: []const u8 };
pub const Profile = struct {
    capabilities: b.Capabilities = .{},
    routes: []const Route,
    active: ?b.Session.Progress,
    pub const json_schema_sequence_bounds = .{ .routes = 2 };
};
pub const Request = union(enum) { describe, query: b.Action };
pub const Response = union(enum) { description: Profile, query: b.Result };
pub const schema_options: q.protocol.Schema.Options = .{ .output = true, .safe_integers = true, .sequence_max_length = q.fuze.Relational.max_outputs, .text_max_length = 4096 };
pub const request_schema_options: q.protocol.Schema.Options = .{ .safe_integers = true, .sequence_max_length = q.fuze.Relational.max_outputs, .text_max_length = 4096 };
pub const max_request_bytes = 16384;

/// Metadata inspection checks every configured catalog; it never opens data cuts.
pub fn describe(self: *Self, allocator: std.mem.Allocator) !Profile {
    const routes = try allocator.alloc(Route, self.count);
    errdefer allocator.free(routes);
    for (routes, self.catalogs[0..self.count]) |*route, *catalog| {
        const value = try catalog.describe();
        const connection = catalog.connection;
        route.* = .{ .connection = .{ .scope = .{ .realm = connection.scope.realm, .resource = connection.scope.resource, .catalog = try std.fmt.allocPrint(allocator, "{d}", .{connection.scope.catalog}) }, .owner = connection.owner, .principal = connection.principal }, .resource_revision = value.resource_revision, .policy_revision = try std.fmt.allocPrint(allocator, "{d}", .{value.policy.revision}) };
    }
    return .{ .routes = routes, .active = try self.session.current(allocator) };
}

/// Responses and diagnostics borrow only the supplied response arena.
pub fn applyStructured(self: *Self, allocator: std.mem.Allocator, request: Request, out: *?q.protocol.Diagnostic) !Response {
    out.* = null;
    const wire = self.catalogs[0].transport;
    wire.last_rejection = null;
    var location: q.fuze.Sql.Location = .{};
    return self.apply(allocator, request, &location) catch |err| {
        const original_rejection = wire.last_rejection;
        const action: b.Action = switch (request) {
            .describe => .capabilities,
            .query => |value| value,
        };
        out.* = q.ApiDiagnostic.project(.{ .relational = action }, err, .{ .location = location }, false, null) catch null;
        if (request == .query) if (out.*) |*value| self.session.diagnostic(action, err, value);
        if (out.*) |*value| if (original_rejection) |native| value.text(.native_cause, .authority, @tagName(native)) catch {};
        wire.last_rejection = original_rejection;
        return err;
    };
}
fn apply(self: *Self, allocator: std.mem.Allocator, request: Request, location: *q.fuze.Sql.Location) !Response {
    return switch (request) {
        .describe => .{ .description = try self.describe(allocator) },
        .query => |action| .{ .query = try self.session.apply(allocator, action, location) },
    };
}

test "relational caller rejects mixed identities before directory acquisition" {
    const t = std.testing;
    var wire = q.wire.Client.init(t.allocator, t.io, "http://127.0.0.1:1");
    defer wire.deinit();
    const key = try q.protocol.Ed25519.KeyPair.generateDeterministic(@splat(1));
    const first: q.catalog.TableValues.Connection = .{ .scope = .{ .realm = 1, .resource = 3, .catalog = "7" }, .owner = 2, .principal = 9 };
    var other = first;
    other.scope.realm = 2;
    var config: b.Config = .{ .catalogs = &.{ first, other }, .spill_directory = "/missing-relational-fixture-directory", .options = .{ .consistency = .per_resource_snapshot_vector, .resident_bytes = "16777216", .spill_bytes = "16777216", .result_bytes = "8388608", .output_rows = "1000", .work_steps = "100000", .source_pins = 2, .requests = "100000", .spill_work = "100000" } };
    try t.expectError(error.RelationalCallerChanged, create(t.allocator, t.io, &wire, key, config));
    config.catalogs = &.{};
    try t.expectError(error.InvalidRelationalSources, create(t.allocator, t.io, &wire, key, config));
    config.catalogs = &.{first};
    config.spill_directory = ".";
    const owner = try create(t.allocator, t.io, &wire, key, config);
    defer owner.destroy();
    try t.expect(owner.session.active == null);
    try t.expect(owner.session.clients[0] == &owner.catalogs[0]);
}
