//! Explicit application provisioning through public, recoverable authorization.
//! The operator names an existing direct catalog and namespace. Worker
//! activation reads the retained binding; it never provisions another catalog.
const std = @import("std");
const W = @import("work_items");
const c = W.query.catalog;
const wire = W.app.station.client;
const p = wire.protocol;
const A = wire.Application;
const Change = wire.AuthorizationChange;
const Admin = struct { version: u8, connection: wire.AuthorizationBridge.Connection, url: []const u8, seed_file: []const u8, request_timeout_ms: u32 = 5000 };
/// Explicit deployment choice, including the worker's existing login role.
/// This is not a credential and does not create a data service or namespace.
pub const Target = struct {
    definition: p.Growth.Definition,
    connection: c.DirectTableProtocol.Connection,
    seed_file: []const u8,
    namespace: u64,
    first_object: u64,
    worker_login_role: u64,
};
const Journal = struct {
    init: std.process.Init,
    directory: std.Io.Dir,
    client: Change.Client,
    index: u8 = 0,

    fn save(self: *@This(), name: []const u8, record: Change.Record, replace: bool) !void {
        const bytes = try record.save(self.init.gpa);
        defer self.init.gpa.free(bytes);
        var file = try self.directory.createFileAtomic(self.init.io, name, .{ .replace = replace, .permissions = .fromMode(0o600) });
        defer file.deinit(self.init.io);
        try file.file.writeStreamingAll(self.init.io, bytes);
        try file.file.sync(self.init.io);
        if (replace) try file.replace(self.init.io) else try file.link(self.init.io);
        if (std.c.fsync(self.directory.handle) != 0) return error.RecoverySyncFailed;
    }
    fn apply(self: *@This(), action: p.Authorization.Action) !?u64 {
        var buffer: [32]u8 = undefined;
        const name = try std.fmt.bufPrint(&buffer, "authorization-{d}.json", .{self.index});
        self.index += 1;
        var record = value: {
            const bytes = self.directory.readFileAlloc(self.init.io, name, self.init.gpa, .limited(Change.Record.max_bytes)) catch |err| {
                if (err != error.FileNotFound) return err;
                const revision = (try self.client.authority.read(.identity)).body.authorization.revision;
                const prepared = try self.client.prepare(revision, action);
                try self.save(name, prepared.record, false);
                break :value prepared.record;
            };
            defer self.init.gpa.free(bytes);
            break :value try Change.Record.restore(self.init.gpa, bytes);
        };
        const request = record.begin.signed.request;
        if (request.realm != self.client.authority.realm or request.principal != self.client.authority.principal or !std.meta.eql(request.command.authorization.begin.action, action)) return error.RecoveryIdentityMismatch;
        // A bounded invocation can stop with a saved pending change. Repeating
        // it recovers exact receipts before attempting those same signed bytes.
        for (0..128) |_| {
            if (record.pending != null) {
                if (try self.client.recoverPending(record)) |recovered| {
                    record = recovered;
                } else record = try record.received(try self.client.submit(record));
                try self.save(name, record, true);
            }
            switch (try self.client.next(record)) {
                .terminal => |outcome| {
                    if (outcome.status != .published) return error.AuthorizationChangeAbandoned;
                    return outcome.created_id;
                },
                .pending => |next| {
                    record = next;
                    try self.save(name, record, true);
                },
            }
        }
        return error.AuthorizationStillPending;
    }
};
fn read(comptime T: type, init: std.process.Init, path: []const u8) !T {
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.arena.allocator(), .limited(16384));
    return (try p.Json.parseFromSlice(T, init.arena.allocator(), bytes)).value;
}
fn login(init: std.process.Init, transport: *wire.Client, connection: A.Connection) !u64 {
    var key = try wire.readKey(init.gpa, init.io, connection.seed_file);
    defer std.crypto.secureZero(u8, std.mem.asBytes(&key));
    const client: wire.AuthorizationClient = .{ .transport = transport, .realm = connection.realm, .principal = connection.principal, .key = key };
    return (try client.read(.identity)).body.authorization.body.identity.login_role;
}
fn sameBindings(left: []const A.Binding, right: []const A.Binding) bool {
    if (left.len != right.len) return false;
    for (left, right) |a, b| if (a.id != b.id or !std.mem.eql(u8, a.name, b.name)) return false;
    return true;
}
/// Arguments: admin configuration, operator/writer/inspector exports, an existing
/// private recovery directory and explicit Target file. The caller saves the
/// resulting application binding before initializing the worker.
pub fn run(init: std.process.Init, args: []const []const u8) !W.Data.Binding {
    if (args.len != 6) return error.InvalidInvocation;
    const admin = try read(Admin, init, args[0]);
    try admin.connection.validate();
    if (admin.version != 1 or admin.connection.principal != 0 or admin.connection.role != null or admin.request_timeout_ms == 0 or admin.request_timeout_ms > 60000) return error.InvalidAuthorizationConnection;
    var connections: [3]A.Connection = undefined;
    for (&connections, args[1..4], [_][]const u8{ "operator", "writer", "inspector" }) |*connection, path, name| {
        connection.* = try read(A.Connection, init, path);
        try connection.validate();
        if (connection.realm != admin.connection.realm or !std.mem.eql(u8, connection.url, admin.url) or connection.principal != try A.binding(connection.callers, name)) return error.RecoveryIdentityMismatch;
    }
    const operator = connections[0];
    for (connections[1..]) |connection| {
        if (!std.mem.eql(u8, connection.application, operator.application) or !sameBindings(connection.roles, operator.roles) or !sameBindings(connection.resources, operator.resources) or !sameBindings(connection.callers, operator.callers)) return error.RecoveryIdentityMismatch;
    }
    const owner_pid = try A.binding(operator.roles, "data");
    const target = try read(Target, init, args[5]);
    if (target.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
    try target.connection.validate();
    if (target.connection.scope.realm != operator.realm or target.first_object == 0) return error.RecoveryIdentityMismatch;
    const scope = target.connection.scope;
    var transport = wire.Client.init(init.gpa, init.io, admin.url);
    defer transport.deinit();
    transport.timeout_ms = admin.request_timeout_ms;
    var key = try wire.readKey(init.gpa, init.io, admin.seed_file);
    defer std.crypto.secureZero(u8, std.mem.asBytes(&key));
    const authority: wire.AuthorizationClient = .{ .transport = &transport, .realm = scope.realm, .principal = 0, .key = key };
    const process = (try transport.query(.{ .realm = scope.realm, .principal = 0, .kind = .{ .process = owner_pid } }, key)).body.process.process;
    if (process.lifecycle != .running or process.owner == null or process.owner == 0) return error.WorkerUnavailable;
    const worker_role = (try authority.read(.{ .role = target.worker_login_role })).body.authorization.body.role;
    if (!worker_role.login or !worker_role.enabled or worker_role.retired) return error.WorkerUnavailable;
    var catalog_key = try wire.readKey(init.gpa, init.io, target.seed_file);
    defer std.crypto.secureZero(u8, std.mem.asBytes(&catalog_key));
    const direct: c.DirectTableClient = .{ .allocator = init.gpa, .authority = &transport, .service = &transport, .connection = target.connection, .key = catalog_key };
    const described = try direct.call(.describe);
    defer described.deinit();
    const profile = described.value.result.description.authority;
    const namespace_response = try direct.call(.{ .namespace = target.namespace });
    defer namespace_response.deinit();
    const namespace = namespace_response.value.result.namespace orelse return error.UnknownCatalogSchema;
    var roles: [3]u64 = undefined;
    for (connections, &roles) |connection, *role| role.* = try login(init, &transport, connection);
    const directory = try std.Io.Dir.cwd().openDir(init.io, args[4], .{ .iterate = true });
    defer directory.close(init.io);
    const lock = try directory.createFile(init.io, "authorization.lock", .{ .truncate = false, .permissions = .fromMode(0o600) });
    defer lock.close(init.io);
    if (!try lock.tryLock(init.io, .exclusive)) return error.CallerInUse;
    var journal: Journal = .{ .init = init, .directory = directory, .client = .{ .authority = authority } };
    var name: [63]u8 = undefined;
    const owner = (try journal.apply(.{ .create_role = .{ .name = try p.Value.init(try std.fmt.bufPrint(&name, "work_items/{d}/{d}", .{ scope.realm, owner_pid })), .login = false } })).?;
    _ = try journal.apply(.{ .membership = .{ .member = roles[0], .role = owner, .inherit = true, .set = true } });
    _ = try journal.apply(.{ .grant = .{ .object = .{ .kind = .process, .id = owner_pid }, .grantee = owner, .privileges = p.permission(.send) } });
    _ = try journal.apply(.{ .membership = .{ .member = worker_role.id, .role = owner, .inherit = false, .set = true } });
    _ = try journal.apply(.{ .grant = .{ .object = c.TableAuthority.reference(profile.database), .grantee = owner, .privileges = c.TableAuthority.connect } });
    _ = try journal.apply(.{ .grant = .{ .object = c.TableAuthority.reference(namespace.authorization), .grantee = owner, .privileges = c.TableAuthority.usage | c.TableAuthority.create } });
    for (roles[1..], [_]u64{ c.TableAuthority.select | c.TableAuthority.insert | c.TableAuthority.update, c.TableAuthority.select }) |role, privileges| {
        _ = try journal.apply(.{ .grant = .{ .object = c.TableAuthority.reference(profile.database), .grantee = role, .privileges = c.TableAuthority.connect } });
        _ = try journal.apply(.{ .grant = .{ .object = c.TableAuthority.reference(namespace.authorization), .grantee = role, .privileges = c.TableAuthority.usage } });
        _ = try journal.apply(.{ .default_grant = .{ .creator = owner, .schema = c.TableAuthority.reference(namespace.authorization), .domain = profile.table_domain, .grantee = role, .privileges = privileges } });
    }
    return .{ .definition = p.Growth.definition_bytes, .scope = scope, .branch = target.connection.branch, .audience = target.connection.audience, .namespace = target.namespace, .first_object = target.first_object, .owner_role = owner };
}
