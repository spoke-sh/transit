//! Explicit SQL account/catalog mappings and secret references. Configuration is
//! not native authority, provisioning, or evidence of an eligible activation.
const std = @import("std");
const g = @import("root.zig");
const p = g.catalog.protocol;
const Self = @This();
version: u8,
definition: p.Growth.Definition,
native_url: []const u8,
tls_mode: TlsMode = .required,
certificate_file: []const u8,
certificate_key_file: []const u8,
activation_directory: []const u8,
spill_directory: []const u8,
bind_address: []const u8 = "127.0.0.1",
postgres_port: ?u16 = null,
mysql_port: ?u16 = null,
native: ?Native = null,
health_address: []const u8 = "127.0.0.1",
health_port: ?u16 = null,
drain_ms: u32 = 30000,
limits: g.Limits = .{},
request_timeout_ms: u32 = 5000,
accounts: []const Account,
settings: ?struct { url: []const u8, binding: g.query.settings.Contract.Binding } = null,
pub const Native = struct {
    instance: g.session_protocol.Instance,
    socket: ?[]const u8 = null,
    address: []const u8 = "127.0.0.1",
    port: ?u16 = null,
    tls: ?struct { certificate_file: []const u8, key_file: []const u8 } = null,
};
pub const Database = struct { name: []const u8, binding: g.Ledger.Binding };
pub const KeyFiles = struct { worker: []const u8, ingress: []const u8, coordinator: []const u8, table: []const u8 };
pub const TlsMode = enum { disabled, optional, required };
pub const Authentication = enum { password, trust, peer };
pub const Source = struct {
    name: []const u8,
    database: []const u8,
    connection: g.query.UnifiedClient.Connection,
    key_file: []const u8,
    workspace: g.query.Workspace.Config,
};
pub const Account = struct {
    name: []const u8,
    authentication: Authentication = .password,
    peer_uid: ?u32 = null,
    enabled: bool = true,
    verifier_file: []const u8,
    ledger: g.Ledger.Configuration,
    generation: u64,
    association: []const u8 = "state",
    keys: KeyFiles,
    databases: []const Database,
    sources: []const Source = &.{},
    pub fn database(self: Account, name: []const u8) !g.Ledger.Binding {
        for (self.databases) |value| if (std.mem.eql(u8, value.name, name)) return value.binding;
        return error.GatewayDatabaseDenied;
    }
    pub fn source(self: Account, name: []const u8, selected_database: []const u8) !*const Source {
        for (self.sources) |*value| if (std.mem.eql(u8, value.name, name) and std.mem.eql(u8, value.database, selected_database)) return value;
        return error.UnknownSqlSource;
    }
};
pub fn account(self: Self, name: []const u8) !usize {
    for (self.accounts, 0..) |value, i| if (value.enabled and std.mem.eql(u8, value.name, name)) return i;
    return error.InvalidAuthentication;
}
/// Retained ledger workers may run without admitting any new SQL connections.
pub fn listening(self: Self) bool {
    return self.wireListening() or (if (self.native) |value| value.socket != null or value.port != null else false);
}
pub fn wireListening(self: Self) bool {
    return self.postgres_port != null or self.mysql_port != null;
}
fn validateName(value: []const u8) !void {
    if (value.len == 0 or value.len > g.Limits.max_name_bytes or !std.unicode.utf8ValidateSlice(value) or std.mem.indexOfScalar(u8, value, 0) != null) return error.InvalidGatewayConfiguration;
}
fn path(value: []const u8) !void {
    if (value.len == 0 or value.len > 4096 or std.mem.indexOfScalar(u8, value, 0) != null) return error.InvalidGatewayConfiguration;
}
pub fn validate(self: Self) !void {
    if (self.version != 1 or self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
    try self.limits.validate();
    if (self.settings) |settings| {
        try path(settings.url);
        try settings.binding.validate();
    }
    if (self.health_port == 0 or (self.health_port != null and (self.health_port == self.postgres_port or self.health_port == self.mysql_port)) or self.drain_ms == 0 or self.drain_ms > 270000) return error.InvalidGatewayConfiguration;
    try path(self.health_address);
    if (self.accounts.len == 0 or self.accounts.len > g.Limits.max_accounts or self.postgres_port == 0 or self.mysql_port == 0 or (self.postgres_port != null and self.postgres_port == self.mysql_port) or self.request_timeout_ms == 0 or self.request_timeout_ms > 60000) return error.InvalidGatewayConfiguration;
    for ([_][]const u8{ self.native_url, self.activation_directory, self.spill_directory, self.bind_address }) |value| try path(value);
    if (self.wireListening() and self.tls_mode != .disabled) {
        try path(self.certificate_file);
        try path(self.certificate_key_file);
    }
    if (self.native) |value| {
        if (std.mem.allEqual(u8, &value.instance, 0) or value.port == 0 or (value.port != null and (value.port == self.health_port or value.port == self.postgres_port or value.port == self.mysql_port))) return error.InvalidGatewayConfiguration;
        if (value.socket) |socket| {
            try path(socket);
            _ = try std.Io.net.UnixAddress.init(socket);
        }
        const address = try std.Io.net.IpAddress.parseIp4(value.address, value.port orelse 0);
        if (value.port != null and value.tls == null and address.ip4.bytes[0] != 127) return error.NativeSqlTlsRequired;
        if (value.tls) |selected| {
            try path(selected.certificate_file);
            try path(selected.key_file);
        }
    }
    for (self.accounts, 0..) |value, i| {
        if ((value.authentication == .peer) != (value.peer_uid != null)) return error.InvalidGatewayConfiguration;
        // Trust admits a claimed SQL identity only on an explicit loopback
        // listener. It never selects a native identity supplied by the client.
        if (value.authentication == .trust) {
            const address = std.Io.net.IpAddress.parseIp4(self.bind_address, 0) catch return error.InvalidGatewayConfiguration;
            if (address.ip4.bytes[0] != 127) return error.InvalidGatewayConfiguration;
        }
        // MySQL full caching_sha2_password must never request a clear password
        // on an unencrypted transport. Optional TLS rejects such a login there.
        if (self.mysql_port != null and self.tls_mode == .disabled and value.enabled and value.authentication == .password) return error.InvalidGatewayConfiguration;
        try validateName(value.name);
        try validateName(value.association);
        try path(value.verifier_file);
        inline for (@typeInfo(KeyFiles).@"struct".field_names) |field| try path(@field(value.keys, field));
        try value.ledger.validate();
        if (value.generation == 0 or value.generation > p.max_counter or value.databases.len != value.ledger.bindings.len) return error.InvalidGatewayConfiguration;
        for (self.accounts[0..i]) |other| {
            if (std.mem.eql(u8, value.name, other.name) or std.mem.eql(u8, &value.ledger.account, &other.ledger.account)) return error.InvalidGatewayConfiguration;
            if (value.ledger.realm != other.ledger.realm) continue;
            if (value.ledger.owner == other.ledger.owner or value.ledger.resource == other.ledger.resource) return error.InvalidGatewayConfiguration;
            // Separate runtime lanes cannot share any sequenced principal.
            const a = value.ledger;
            const b = other.ledger;
            for ([_]u64{ a.worker, a.ingress, a.control, a.coordinator, a.table_principal }) |principal| for ([_]u64{ b.worker, b.ingress, b.control, b.coordinator, b.table_principal }) |old| if (principal == old) return error.InvalidGatewayConfiguration;
        }
        for (value.databases, 0..) |database, j| {
            try validateName(database.name);
            if (!std.meta.eql(database.binding, value.ledger.bindings[j])) return error.InvalidGatewayConfiguration;
            for (value.databases[0..j]) |other| if (std.mem.eql(u8, database.name, other.name)) return error.InvalidGatewayConfiguration;
        }
        if (value.sources.len > 32) return error.InvalidGatewayConfiguration;
        for (value.sources, 0..) |source, j| {
            try validateName(source.name);
            try path(source.key_file);
            const binding = try value.database(source.database);
            if (source.connection.realm != value.ledger.realm or source.connection.role != binding.role) return error.InvalidGatewayConfiguration;
            if (source.workspace.source.source == .table) {
                const table = source.workspace.source.source.table;
                const scope = try table.scope.native();
                const executor = source.workspace.executor orelse return error.InvalidGatewayConfiguration;
                if (scope.realm != source.connection.realm or scope.resource != source.workspace.source.resource or executor == 0 or executor > p.max_counter) return error.InvalidGatewayConfiguration;
            } else if (source.workspace.source.resource != source.connection.resource) return error.InvalidGatewayConfiguration;
            inline for (.{ "realm", "principal", "source", "resource", "requester", "requests" }) |field| {
                const id = @field(source.connection, field);
                if (id == 0 or id > p.max_counter) return error.InvalidGatewayConfiguration;
            }
            for (value.sources[0..j]) |other| if (std.mem.eql(u8, source.name, other.name)) return error.InvalidGatewayConfiguration;
            // A source caller owns a separate durable submission sequence. It
            // cannot alias a Table coordinator, worker, or another source lane.
            for (self.accounts) |other| {
                if (other.ledger.realm != source.connection.realm) continue;
                const l = other.ledger;
                for ([_]u64{ l.worker, l.ingress, l.control, l.coordinator, l.table_principal }) |principal| if (principal == source.connection.principal) return error.InvalidGatewayConfiguration;
                for (other.sources) |*candidate| if (candidate != &value.sources[j] and candidate.connection.principal == source.connection.principal) return error.InvalidGatewayConfiguration;
            }
        }
    }
}
/// Replace this private file atomically to rotate or disable authentication.
/// Existing sessions compare the complete revision before each new request.
pub const Credential = struct {
    version: u8,
    definition: p.Growth.Definition,
    account: [32]u8,
    revision: u64,
    principal: u64,
    login_role: u64,
    credential_epoch: u64,
    enabled: bool,
    verifier: ?g.Authentication.Verifier,
    pub fn checkIdentity(self: Credential, principal: u64, login_role: u64, epoch: u64) !void {
        if (self.principal != principal or self.login_role != login_role or self.credential_epoch != epoch) return error.GatewayCredentialChanged;
    }
    pub fn validate(self: Credential, identity: [32]u8) !void {
        if (self.version != 1 or self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        if (self.principal == 0 or self.principal > p.max_counter or self.login_role > p.max_counter or self.credential_epoch == 0 or self.credential_epoch > p.max_counter or self.revision == 0 or !std.mem.eql(u8, &self.account, &identity)) return error.InvalidAuthentication;
        if (self.verifier) |verifier| try verifier.validate();
        if (!self.enabled) return error.InvalidAuthentication;
    }
};
test "credentials bind an explicit revision and account independently of SQL names" {
    const t = std.testing;
    var credential: Credential = .{ .version = 1, .definition = p.Growth.current_definition, .account = @splat(31), .revision = 1, .principal = 6, .login_role = 12, .credential_epoch = 2, .enabled = true, .verifier = try g.Authentication.Verifier.create("secret", @splat(17), 4096) };
    try credential.validate(@splat(31));
    try t.expectError(error.InvalidAuthentication, credential.validate(@splat(32)));
    try credential.checkIdentity(6, 12, 2);
    try t.expectError(error.GatewayCredentialChanged, credential.checkIdentity(7, 12, 2));
    try t.expectError(error.GatewayCredentialChanged, credential.checkIdentity(6, 13, 2));
    try t.expectError(error.GatewayCredentialChanged, credential.checkIdentity(6, 12, 3));
    credential.enabled = false;
    try t.expectError(error.InvalidAuthentication, credential.validate(@splat(31)));
    credential.version = 0;
    try t.expectError(error.IncompatibleDefinition, credential.validate(@splat(31)));
}
test "SQL mappings reject shared native sequence owners and mismatched catalogs" {
    const t = std.testing;
    const binding: g.Ledger.Binding = .{ .resource = 8, .catalog = 1, .owner = 9 };
    var accounts = [_]Account{.{ .name = "user", .verifier_file = "/private/verifier", .ledger = .{ .realm = 1, .resource = 7, .owner = 3, .worker = 2, .ingress = 4, .control = 5, .coordinator = 10, .table_principal = 6, .account = @splat(7), .bindings = &.{binding}, .intent_bytes = 4096, .operation_quota = 100, .byte_quota = 1024 * 1024 }, .generation = 1, .keys = .{ .worker = "/private/w", .ingress = "/private/i", .coordinator = "/private/c", .table = "/private/t" }, .databases = &.{.{ .name = "data", .binding = binding }} }};
    var config: Self = .{ .version = 1, .definition = p.Growth.current_definition, .native_url = "http://127.0.0.1:7700", .certificate_file = "/private/cert", .certificate_key_file = "/private/key", .activation_directory = "/private/activation", .spill_directory = "/private/spill", .postgres_port = 5432, .accounts = &accounts };
    try config.validate();
    try t.expectEqual(@as(usize, 0), try config.account("user"));
    try t.expectError(error.InvalidAuthentication, config.account("other"));
    try t.expectEqualDeep(binding, try accounts[0].database("data"));
    try t.expectError(error.GatewayDatabaseDenied, accounts[0].database("other"));
    var sources = [_]Source{.{
        .name = "events",
        .database = "data",
        .key_file = "/private/source",
        .connection = .{ .realm = 1, .principal = 12, .source = 13, .resource = 14, .requester = 15, .requests = 16, .role = null },
        .workspace = .{
            .name = "events",
            .executor = 17,
            .source = .{ .resource = 8, .source = .{ .table = .{
                .scope = .{ .realm = 1, .resource = 8, .catalog = "1" },
                .owner = 9,
                .branch = "1",
                .namespace = 1,
                .object = "1",
                .interpretation = .{ .revision = "1", .digest = @splat(1), .bytes = "1", .schema = @splat(2) },
                .row_type = .{ .structure = &.{.{ .name = "id", .type = .int64 }} },
                .collations = &.{.none},
            } } },
            .limits = .{ .pages = "100", .segments = "10", .result_bytes = "65536" },
        },
    }};
    accounts[0].sources = &sources;
    try config.validate(); // Table data and native progress have different IDs.
    sources[0].workspace.executor = null;
    try t.expectError(error.InvalidGatewayConfiguration, config.validate());
    sources[0].workspace.executor = 17;
    sources[0].workspace.source.resource = 14;
    try t.expectError(error.InvalidGatewayConfiguration, config.validate());
    accounts[0].sources = &.{};
    var duplicated = [_]Account{ accounts[0], accounts[0] };
    duplicated[1].name = "different";
    duplicated[1].ledger.account = @splat(8);
    duplicated[1].ledger.resource = 11;
    duplicated[1].ledger.owner = 12;
    config.accounts = &duplicated;
    try t.expectError(error.InvalidGatewayConfiguration, config.validate());
    config.accounts = &accounts;
    config.mysql_port = config.postgres_port;
    try t.expectError(error.InvalidGatewayConfiguration, config.validate());
    config.mysql_port = null;
    config.postgres_port = null;
    config.certificate_file = "";
    config.certificate_key_file = "";
    try config.validate();
    try t.expect(!config.listening());
    config.postgres_port = 5432;
    try t.expectError(error.InvalidGatewayConfiguration, config.validate());
    config.certificate_file = "/private/cert";
    config.certificate_key_file = "/private/key";
    config.tls_mode = .disabled;
    config.certificate_file = "";
    config.certificate_key_file = "";
    try config.validate(); // PostgreSQL SCRAM does not require encryption.
    config.mysql_port = 3306;
    try t.expectError(error.InvalidGatewayConfiguration, config.validate());
    accounts[0].authentication = .trust;
    try config.validate();
    config.bind_address = "0.0.0.0";
    try t.expectError(error.InvalidGatewayConfiguration, config.validate());
    config.bind_address = "192.0.2.1";
    try t.expectError(error.InvalidGatewayConfiguration, config.validate());
    config.bind_address = "127.0.0.2";
    try config.validate();
    config.tls_mode = .optional;
    try t.expectError(error.InvalidGatewayConfiguration, config.validate());
    config.certificate_file = "/private/cert";
    config.certificate_key_file = "/private/key";
    try config.validate();
    accounts[0].databases = &.{.{ .name = "data", .binding = .{ .resource = 10, .catalog = 1, .owner = 9 } }};
    try t.expectError(error.InvalidGatewayConfiguration, config.validate());
}
