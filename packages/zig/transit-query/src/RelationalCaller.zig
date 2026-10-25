//! Stable owner for configured relational clients and their one live session.
//! Borrows authority transport and I/O; owns its direct service, keys and local session.
const std = @import("std");
const q = @import("root.zig");
const b = q.RelationalBridge;
const Self = @This();
allocator: std.mem.Allocator,
io: std.Io,
directory: std.Io.Dir,
catalogs: [2]q.catalog.DirectTableClient,
service: q.wire.Client,
service_url: []u8,
count: usize,
session: b.Session,

pub fn create(allocator: std.mem.Allocator, io: std.Io, wire: *q.wire.Client, key: q.protocol.Ed25519.KeyPair, config: b.Config) !*Self {
    if (config.definition != q.protocol.Growth.current_definition) return error.IncompatibleDefinition;
    if (config.catalogs.len == 0 or config.catalogs.len > 2 or config.spill_directory.len == 0 or config.spill_directory.len > 4096) return error.InvalidRelationalSources;
    const options = try config.options.native();
    const first = try config.catalogs[0].native();
    for (config.catalogs) |connection| {
        const native = try connection.native();
        if (!std.meta.eql(native, first)) return error.RelationalCallerChanged;
    }
    const url = config.service_url orelse wire.url;
    const uri = std.Uri.parse(url) catch return error.InvalidRelationalSources;
    if (url.len == 0 or url.len > 2048 or (!std.mem.eql(u8, uri.scheme, "http") and !std.mem.eql(u8, uri.scheme, "https")) or uri.host == null or uri.user != null or uri.password != null or uri.query != null or uri.fragment != null) return error.InvalidRelationalSources;
    const endpoint = try allocator.dupe(u8, url);
    errdefer allocator.free(endpoint);
    const directory = try std.Io.Dir.cwd().openDir(io, config.spill_directory, .{});
    errdefer directory.close(io);
    const self = try allocator.create(Self);
    self.* = .{ .allocator = allocator, .io = io, .directory = directory, .catalogs = undefined, .service = q.wire.Client.init(allocator, io, endpoint), .service_url = endpoint, .count = config.catalogs.len, .session = undefined };
    self.service.timeout_ms = wire.timeout_ms;
    for (config.catalogs, 0..) |connection, i| {
        self.catalogs[i] = .{ .allocator = allocator, .authority = wire, .service = &self.service, .connection = connection.native() catch unreachable, .key = key };
    }
    self.session = .{ .allocator = allocator, .io = io, .directory = directory, .clients = self.catalogs[0..self.count], .options = options };
    return self;
}

pub fn destroy(self: *Self) void {
    self.session.deinit();
    self.directory.close(self.io);
    for (self.catalogs[0..self.count]) |*catalog| std.crypto.secureZero(u8, std.mem.asBytes(&catalog.key));
    self.service.deinit();
    self.allocator.free(self.service_url);
    self.allocator.destroy(self);
}

pub const Route = struct { connection: q.catalog.DirectTableValues.Connection, description: @FieldType(q.catalog.DirectCatalogInspection.Result, "description") };
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
        const value = try q.catalog.DirectCatalogInspection.apply(allocator, catalog.*, .describe);
        route.* = .{ .connection = try q.catalog.DirectTableValues.Connection.foreign(allocator, catalog.connection), .description = value.description };
    }
    return .{ .routes = routes, .active = try self.session.current(allocator) };
}

/// Responses and diagnostics borrow only the supplied response arena.
pub fn applyStructured(self: *Self, allocator: std.mem.Allocator, request: Request, out: *?q.protocol.Diagnostic) !Response {
    out.* = null;
    const wire = self.catalogs[0].authority;
    self.service.last_rejection = null;
    wire.last_rejection = null;
    var location: q.fuze.Sql.Location = .{};
    return self.apply(allocator, request, &location) catch |err| {
        const original_rejection = self.service.last_rejection orelse wire.last_rejection;
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
    const first: q.catalog.DirectTableValues.Connection = .{ .scope = .{ .realm = 1, .resource = 3, .catalog = "7" }, .branch = "1", .audience = 2, .principal = 9, .role = null };
    var other = first;
    other.scope.realm = 2;
    var config: b.Config = .{ .definition = q.protocol.Growth.current_definition, .catalogs = &.{ first, other }, .spill_directory = "/missing-relational-fixture-directory", .options = .{ .consistency = .independent_table_snapshots, .resident_bytes = "16777216", .spill_bytes = "16777216", .result_bytes = "8388608", .output_rows = "1000", .work_steps = "100000", .source_pins = 2, .requests = "100000", .spill_work = "100000" } };
    try t.expectError(error.RelationalCallerChanged, create(t.allocator, t.io, &wire, key, config));
    config.catalogs = &.{};
    try t.expectError(error.InvalidRelationalSources, create(t.allocator, t.io, &wire, key, config));
    config.catalogs = &.{first};
    const encoded = try q.protocol.Json.valueAlloc(t.allocator, config);
    defer t.allocator.free(encoded);
    const valid = try q.protocol.Json.parseFromSlice(b.Config, t.allocator, encoded);
    defer valid.deinit();
    const foreign = try std.mem.replaceOwned(u8, t.allocator, encoded, @tagName(q.protocol.Growth.current_definition), "foreign");
    defer t.allocator.free(foreign);
    try t.expectError(error.InvalidJsonShape, q.protocol.Json.parseFromSlice(b.Config, t.allocator, foreign));
    config.service_url = "http://user:secret@127.0.0.1:2";
    try t.expectError(error.InvalidRelationalSources, create(t.allocator, t.io, &wire, key, config));
    var endpoint = "http://127.0.0.1:2".*;
    config.service_url = &endpoint;
    config.spill_directory = ".";
    const owner = try create(t.allocator, t.io, &wire, key, config);
    @memset(&endpoint, 'x');
    try t.expectEqualStrings("http://127.0.0.1:2", owner.service_url);
    defer owner.destroy();
    try t.expect(owner.session.active == null);
    try t.expect(owner.session.clients[0].service == &owner.service);
}
