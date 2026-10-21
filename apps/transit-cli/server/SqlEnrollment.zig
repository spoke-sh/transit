//! Recoverable local SQL identities and reviewable public authorization inputs.
//! Configuration selects exposure; explicit authorization publishes login/data rights.
const std = @import("std");
const g = @import("transit_sql");
const q = @import("transit_query");
const p = q.protocol;
const n = p.Growth;
const Installation = @import("Installation.zig");
const Files = @import("Files.zig");
const Journal = @import("SqlJournal.zig");
const Settings = @import("SqlSettings.zig");
pub const Meta = struct {
    definition: n.Definition,
    installation: [16]u8,
    administrator: u64,
    journal: Journal = .{},
    managed_trust: bool = false,
};
pub const Account = struct {
    definition: n.Definition,
    installation: [16]u8,
    name: []const u8,
    role: []const u8,
    database: []const u8,
    schema: []const u8,
    bootstrap_owner: bool,
    identity: [32]u8,
    principals: Principals,
    binding: g.Ledger.Binding,
    operation_quota: u64,
    byte_quota: u64,
    pending_quota: u32,
    journal: Journal = .{},
    initialization: ?struct { prepared: g.Client.Prepared, receipt: ?p.Receipt = null } = null,
    initialized: bool = false,
    credential_written: bool = false,
    login_role: ?u64 = null,
    pub fn ledger(self: Account, allocator: std.mem.Allocator, realm: u64) !g.Ledger.Configuration {
        const bindings = try allocator.dupe(g.Ledger.Binding, &.{self.binding});
        return .{ .realm = realm, .owner = self.journal.receipts[0] orelse return error.UnresolvedProvisioning, .resource = self.journal.receipts[1] orelse return error.UnresolvedProvisioning, .worker = self.principals.worker, .ingress = self.principals.ingress, .control = self.principals.control, .coordinator = self.principals.coordinator, .table_principal = self.principals.table, .reader = self.principals.reader, .account = self.identity, .bindings = bindings, .operation_quota = self.operation_quota, .byte_quota = self.byte_quota, .pending_quota = self.pending_quota };
    }
};
pub const Principals = struct { worker: u64, ingress: u64, control: u64, coordinator: u64, table: u64, reader: u64 };
pub fn path(installation: *Installation, allocator: std.mem.Allocator, name: []const u8) ![]const u8 {
    return std.fs.path.join(allocator, &.{ installation.config.installation, "sql", name });
}
pub fn accountPath(installation: *Installation, allocator: std.mem.Allocator, name: []const u8, file: []const u8) ![]const u8 {
    if (!Settings.safeName(name)) return error.InvalidGatewayConfiguration;
    return std.fs.path.join(allocator, &.{ installation.config.installation, "sql", "accounts", name, file });
}
fn number(io: std.Io) !u64 {
    var bytes: [8]u8 = undefined;
    try io.randomSecure(&bytes);
    return (std.mem.readInt(u64, &bytes, .little) & (p.max_counter - 1023)) | 1024;
}
fn seed(installation: *Installation, allocator: std.mem.Allocator, directory: []const u8, name: []const u8) !void {
    var bytes: [32]u8 = undefined;
    defer std.crypto.secureZero(u8, &bytes);
    try installation.init.io.randomSecure(&bytes);
    var encoded = std.fmt.bytesToHex(bytes, .lower);
    defer std.crypto.secureZero(u8, &encoded);
    try Files.write(installation.init.io, try std.fmt.allocPrint(allocator, "{s}/{s}.seed", .{ directory, name }), &encoded);
}
fn temporary(installation: *Installation, allocator: std.mem.Allocator, destination: []const u8) ![]const u8 {
    var random: [16]u8 = undefined;
    try installation.init.io.randomSecure(&random);
    const result = try std.fmt.allocPrint(allocator, "{s}.creating-{s}", .{ destination, std.fmt.bytesToHex(random, .lower) });
    try std.Io.Dir.cwd().createDir(installation.init.io, result, .fromMode(0o700));
    return result;
}
fn publish(installation: *Installation, source: []const u8, destination: []const u8) !void {
    const directory = try std.Io.Dir.cwd().openDir(installation.init.io, source, .{ .iterate = true });
    defer directory.close(installation.init.io);
    if (std.c.fsync(directory.handle) != 0) return error.InstallationSyncFailed;
    try std.Io.Dir.cwd().renamePreserve(source, std.Io.Dir.cwd(), destination, installation.init.io);
    const parent = try std.Io.Dir.cwd().openDir(installation.init.io, std.fs.path.dirname(destination).?, .{ .iterate = true });
    defer parent.close(installation.init.io);
    if (std.c.fsync(parent.handle) != 0) return error.InstallationSyncFailed;
}
pub fn open(installation: *Installation, allocator: std.mem.Allocator) !?Meta {
    const directory = try path(installation, allocator, "");
    const file = try path(installation, allocator, "installation.json");
    if (std.Io.Dir.cwd().access(installation.init.io, directory, .{})) |_| {} else |err| {
        if (err != error.FileNotFound) return err;
        if (!installation.config.sql.listening()) return null;
        const pending = try temporary(installation, allocator, directory);
        for ([_][]const u8{ "accounts", "activations", "spill", "tls" }) |name| try std.Io.Dir.cwd().createDir(installation.init.io, try std.fs.path.join(allocator, &.{ pending, name }), .fromMode(0o700));
        try seed(installation, allocator, pending, "administrator");
        try Files.json(installation.init.io, allocator, try std.fs.path.join(allocator, &.{ pending, "installation.json" }), Meta{ .definition = n.current_definition, .installation = installation.record.installation, .administrator = try number(installation.init.io) });
        try publish(installation, pending, directory);
    }
    const record = try Files.read(Meta, installation.init.io, allocator, file);
    if (record.definition != n.current_definition or !std.mem.eql(u8, &record.installation, &installation.record.installation)) return error.InstallationIdentityMismatch;
    return record;
}
pub fn administrator(installation: *Installation, allocator: std.mem.Allocator, record: *Meta) !void {
    const file = try path(installation, allocator, "installation.json");
    try record.journal.flush(installation, file, record);
    const key_path = try path(installation, allocator, "administrator.seed");
    var key = try q.wire.readKey(allocator, installation.init.io, key_path);
    defer std.crypto.secureZero(u8, std.mem.asBytes(&key));
    // The operator has its own durable sequence; supervisor bootstrap uses its
    // separately journaled root requests, never this operator credential.
    try record.journal.authorize(installation, file, record, 0, .{ .create_role = .{ .name = try .init("local_sql_administrator"), .login = true } });
    try record.journal.authorize(installation, file, record, 1, .{ .bind_credential = .{ .principal = record.administrator, .role = record.journal.receipts[0].?, .public_key = key.public_key.toBytes() } });
    try record.journal.authorize(installation, file, record, 2, .{ .membership = .{ .member = record.journal.receipts[0].?, .role = p.Authorization.root_role, .inherit = true, .set = true } });
    try Files.json(installation.init.io, allocator, try path(installation, allocator, "authorization.yaml"), @import("../Authorization.zig").Config{ .version = 1, .url = installation.wire.url, .seed_file = key_path, .connection = .{ .definition = n.current_definition, .realm = installation.config.realm, .principal = record.administrator, .role = 0 } });
    const connection = installation.connection();
    try Files.json(installation.init.io, allocator, try path(installation, allocator, "catalog.yaml"), .{ .version = 1, .url = installation.wire.url, .seed_file = key_path, .connection = try q.catalog.TableValues.Connection.foreign(allocator, .{ .scope = .{ .realm = connection.realm, .resource = connection.resource, .catalog = 1 }, .owner = connection.source, .principal = record.administrator, .role = 0 }) });
}
pub fn createAccount(installation: *Installation, allocator: std.mem.Allocator, desired: Settings.Account) !Account {
    const directory = try accountPath(installation, allocator, desired.name, "");
    if (std.Io.Dir.cwd().access(installation.init.io, directory, .{})) |_| {} else |err| {
        if (err != error.FileNotFound) return err;
        const pending = try temporary(installation, allocator, directory);
        var principals: Principals = std.mem.zeroes(Principals);
        inline for (@typeInfo(Principals).@"struct".field_names) |name| {
            var attempts: u8 = 0;
            unique: while (true) {
                if (attempts == 8) return error.GatewayIdentityConflict;
                attempts += 1;
                const candidate = try number(installation.init.io);
                inline for (@typeInfo(Principals).@"struct".field_names) |other| if (@field(principals, other) == candidate) continue :unique;
                @field(principals, name) = candidate;
                break;
            }
            try seed(installation, allocator, pending, name);
        }
        var identity: [32]u8 = undefined;
        try installation.init.io.randomSecure(&identity);
        const connection = installation.connection();
        try Files.json(installation.init.io, allocator, try std.fs.path.join(allocator, &.{ pending, "account.json" }), Account{ .definition = n.current_definition, .installation = installation.record.installation, .name = desired.name, .role = desired.role, .database = desired.database, .schema = desired.schema, .bootstrap_owner = desired.bootstrap_owner, .identity = identity, .principals = principals, .binding = .{ .resource = connection.resource, .catalog = 1, .owner = connection.source }, .operation_quota = installation.config.sql.operation_quota, .byte_quota = installation.config.sql.byte_quota, .pending_quota = installation.config.sql.pending_quota });
        try publish(installation, pending, directory);
    }
    const record = try loadAccount(installation, allocator, desired.name);
    if (record.bootstrap_owner != desired.bootstrap_owner or !std.mem.eql(u8, record.role, desired.role) or !std.mem.eql(u8, record.database, desired.database) or !std.mem.eql(u8, record.schema, desired.schema)) return error.GatewayConfigurationChanged;
    return record;
}

/// Policy administration does not imply data-plane CONNECT/USAGE. Publish a
/// proposal for catalog discovery; only an explicit operator apply grants it.
pub fn catalogAccess(installation: *Installation, allocator: std.mem.Allocator) !void {
    const revision = (try installation.query(.{ .authorization = .{ .kind = .identity } })).body.authorization.revision;
    const catalog = Installation.catalogFor(installation.connection(), installation.record);
    const objects = [_]p.Authorization.ObjectRef{ .{ .kind = .domain, .id = catalog.authority.database }, .{ .kind = .domain, .id = catalog.authority.initial_schema_authority } };
    const intents = [_]q.wire.AuthorizationSet.Intent{
        .{ .grant = .{ .object = objects[0], .grantee = p.Authorization.root_role, .privileges = q.catalog.TableAuthority.connect } },
        .{ .grant = .{ .object = objects[1], .grantee = p.Authorization.root_role, .privileges = q.catalog.TableAuthority.usage } },
    };
    const document: q.wire.AuthorizationSet.Document = .{ .definition = n.current_definition, .realm = installation.config.realm, .base_revision = revision, .managed_scope = .{ .objects = &objects }, .intents = &intents };
    _ = try Files.jsonIfChanged(installation.init.io, allocator, try path(installation, allocator, "catalog-access.json"), document);
}
pub fn loadAccount(installation: *Installation, allocator: std.mem.Allocator, name: []const u8) !Account {
    const record = try Files.read(Account, installation.init.io, allocator, try accountPath(installation, allocator, name, "account.json"));
    if (record.definition != n.current_definition or !std.mem.eql(u8, &record.installation, &installation.record.installation) or !std.mem.eql(u8, record.name, name)) return error.InstallationIdentityMismatch;
    return record;
}
pub fn provision(installation: *Installation, allocator: std.mem.Allocator, record: *Account) !void {
    const file = try accountPath(installation, allocator, record.name, "account.json");
    try record.journal.flush(installation, file, record);
    for (0..14) |i| {
        if (record.journal.receipts[i] != null) continue;
        const done = record.journal.receipts;
        const lane: ?[]const u8 = switch (i) {
            4 => "worker",
            6 => "ingress",
            8 => "control",
            10 => "coordinator",
            12 => "reader",
            else => null,
        };
        var key: p.Ed25519.KeyPair = undefined;
        defer if (lane != null) std.crypto.secureZero(u8, std.mem.asBytes(&key));
        if (lane) |name| key = try q.wire.readKey(allocator, installation.init.io, try accountPath(installation, allocator, record.name, try std.fmt.allocPrint(allocator, "{s}.seed", .{name})));
        const command: n.Command = switch (i) {
            0 => .{ .spawn = .{} },
            1 => .{ .create_resource = .{ .writer = done[0].? } },
            2 => .{ .grant_resource = .{ .resource = done[1].?, .subject = 0, .permissions = p.State.all_permissions } },
            3 => .{ .associate = .{ .pid = done[0].?, .name = try .init("state"), .resource = done[1].? } },
            4 => .{ .create_principal = .{ .subject = record.principals.worker, .public_key = key.public_key.toBytes(), .permissions = p.permission(.inspect) | p.permission(.execute) | p.permission(.publish), .pid = done[0].? } },
            5 => .{ .grant_resource = .{ .resource = done[1].?, .subject = record.principals.worker, .permissions = p.State.all_permissions } },
            6, 8, 10 => .{ .create_principal = .{ .subject = switch (i) {
                6 => record.principals.ingress,
                8 => record.principals.control,
                else => record.principals.coordinator,
            }, .public_key = key.public_key.toBytes(), .permissions = p.permission(.inspect) | p.permission(.send), .pid = done[0].? } },
            7, 9, 11 => .{ .grant_resource = .{ .resource = done[1].?, .subject = switch (i) {
                7 => record.principals.ingress,
                9 => record.principals.control,
                else => record.principals.coordinator,
            }, .permissions = Installation.read_permissions } },
            12 => .{ .create_principal = .{ .subject = record.principals.reader, .public_key = key.public_key.toBytes(), .permissions = p.permission(.inspect), .pid = record.binding.owner } },
            13 => .{ .grant_resource = .{ .resource = record.binding.resource, .subject = record.principals.reader, .permissions = Installation.read_permissions } },
            else => unreachable,
        };
        try record.journal.submit(installation, file, record, @intCast(i), command);
    }
}
pub const AuthorizationState = enum { awaiting_role, awaiting_binding, bound, unavailable };
pub fn enrollment(installation: *Installation, allocator: std.mem.Allocator, record: *Account, desired: Settings.Account) !AuthorizationState {
    const policy = (try installation.query(.{ .authorization = .{ .kind = .identity } })).body.authorization;
    const role = installation.query(.{ .authorization = .{ .kind = .{ .resolve = try .init(record.role) } } }) catch |err| {
        if (installation.wire.last_rejection != .UnknownAuthorizationRole and installation.wire.last_rejection != .Forbidden and installation.wire.last_rejection != .AccessDenied) return err;
        if (record.login_role != null) return .unavailable;
        _ = try Files.jsonIfChanged(installation.init.io, allocator, try accountPath(installation, allocator, record.name, "create-role.json"), .{ .expected_revision = policy.revision, .action = p.Authorization.Action{ .create_role = .{ .name = try .init(record.role), .login = true } } });
        return .awaiting_role;
    };
    const resolved = role.body.authorization.body.resolve;
    if (!resolved.login or !resolved.enabled or resolved.retired or resolved.native or (record.login_role != null and record.login_role.? != resolved.id)) return .unavailable;
    var key = try q.wire.readKey(allocator, installation.init.io, try accountPath(installation, allocator, record.name, "table.seed"));
    defer std.crypto.secureZero(u8, std.mem.asBytes(&key));
    if (record.bootstrap_owner) {
        // Bind only the original installation owner, never a recreated role
        // with the same name. A recorded publication is never repeated after
        // credential disable/rotation, even if its observation was interrupted.
        if (resolved.id != installation.record.authorization_steps[0].?) return .unavailable;
        try record.journal.authorize(installation, try accountPath(installation, allocator, record.name, "account.json"), record, 14, .{ .bind_credential = .{ .principal = record.principals.table, .role = resolved.id, .public_key = key.public_key.toBytes() } });
    }
    const caller: q.wire.AuthorizationClient = .{ .transport = installation.wire, .realm = installation.config.realm, .principal = record.principals.table, .key = key };
    const observed = caller.read(.identity) catch |err| {
        if (installation.wire.last_rejection != .Unauthorized and installation.wire.last_rejection != .Forbidden and installation.wire.last_rejection != .AccessDenied) return err;
        // Once observed, loss of authority is never an instruction to rebind.
        if (record.login_role != null or record.bootstrap_owner) return .unavailable;
        _ = try Files.jsonIfChanged(installation.init.io, allocator, try accountPath(installation, allocator, record.name, "bind-credential.json"), .{ .expected_revision = role.body.authorization.revision, .action = p.Authorization.Action{ .bind_credential = .{ .principal = record.principals.table, .role = resolved.id, .public_key = key.public_key.toBytes() } } });
        return .awaiting_binding;
    };
    const identity = observed.body.authorization.body.identity;
    if (identity.login_role != resolved.id) return error.GatewayIdentityConflict;
    if (record.login_role == null) {
        record.login_role = identity.login_role;
        try Journal.save(installation, try accountPath(installation, allocator, record.name, "account.json"), record);
    }
    const binding = try Installation.settingsBinding(installation.record, installation.config.realm);
    const catalog = Installation.catalogFor(installation.connection(), installation.record);
    const objects = [_]p.Authorization.ObjectRef{ .{ .kind = .process, .id = record.binding.owner }, binding.object, .{ .kind = .domain, .id = catalog.authority.database }, .{ .kind = .domain, .id = catalog.authority.initial_schema_authority } };
    const privileges = [_]u64{ p.permission(.inspect) | p.permission(.send), q.settings.Contract.inspect, q.catalog.TableAuthority.connect, q.catalog.TableAuthority.usage };
    var intents: [objects.len]q.wire.AuthorizationSet.Intent = undefined;
    for (objects, privileges, &intents) |object, rights, *intent| intent.* = .{ .grant = .{ .object = object, .grantee = identity.login_role, .privileges = rights } };
    const document: q.wire.AuthorizationSet.Document = .{ .definition = n.current_definition, .realm = installation.config.realm, .base_revision = observed.body.authorization.revision, .managed_scope = .{ .objects = &objects }, .intents = &intents };
    _ = try Files.jsonIfChanged(installation.init.io, allocator, try accountPath(installation, allocator, record.name, "access.json"), document);
    if (!record.credential_written) {
        const verifier_path = try accountPath(installation, allocator, record.name, "verifier.json");
        var existing = Files.read(g.Configuration.Credential, installation.init.io, allocator, verifier_path) catch |err| blk: {
            if (err != error.FileNotFound) return err;
            break :blk null;
        };
        if (existing) |*credential| {
            defer std.crypto.secureZero(u8, std.mem.asBytes(credential));
            try credential.validate(record.identity);
            try credential.checkIdentity(record.principals.table, identity.login_role, identity.credential_epoch);
            record.credential_written = true;
            try Journal.save(installation, try accountPath(installation, allocator, record.name, "account.json"), record);
            return .bound;
        }
        var credential: g.Configuration.Credential = .{ .version = 1, .definition = n.current_definition, .account = record.identity, .revision = 1, .principal = record.principals.table, .login_role = identity.login_role, .credential_epoch = identity.credential_epoch, .enabled = true, .verifier = null };
        defer std.crypto.secureZero(u8, std.mem.asBytes(&credential));
        if (desired.password_file) |password_file| {
            const password = try std.Io.Dir.cwd().readFileAlloc(installation.init.io, password_file, allocator, .limited(g.Authentication.max_password_bytes + 1));
            defer {
                std.crypto.secureZero(u8, password);
                allocator.free(password);
            }
            var salt: [16]u8 = undefined;
            try installation.init.io.randomSecure(&salt);
            credential.verifier = try g.Authentication.Verifier.create(password, salt, g.Authentication.default_iterations);
        }
        try Files.json(installation.init.io, allocator, verifier_path, credential);
        record.credential_written = true;
        try Journal.save(installation, try accountPath(installation, allocator, record.name, "account.json"), record);
    }
    return .bound;
}

pub fn controlProfile(installation: *Installation, allocator: std.mem.Allocator, record: Account) !void {
    const profile: g.OperatorConfiguration = .{ .version = 1, .definition = p.Growth.current_definition, .native_url = installation.wire.url, .ledger = try record.ledger(allocator, installation.config.realm), .control_key_file = try accountPath(installation, allocator, record.name, "control.seed"), .table_key_file = try accountPath(installation, allocator, record.name, "table.seed"), .reader_key_file = try accountPath(installation, allocator, record.name, "reader.seed"), .pending_file = try accountPath(installation, allocator, record.name, "control-pending.json"), .timeout_ms = installation.config.sql.command_ms };
    _ = try Files.jsonIfChanged(installation.init.io, allocator, try accountPath(installation, allocator, record.name, "control.json"), profile);
}
