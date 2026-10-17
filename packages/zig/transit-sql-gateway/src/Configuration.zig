//! Explicit SQL account/catalog mappings and secret references. Configuration is
//! not native authority, provisioning, or evidence of an eligible activation.
const std = @import("std");
const g = @import("root.zig");
const p = g.catalog.protocol;
const Self = @This();
version: u8,
definition: p.Growth.Definition,
native_url: []const u8,
certificate_file: []const u8,
certificate_key_file: []const u8,
activation_directory: []const u8,
spill_directory: []const u8,
bind_address: []const u8 = "127.0.0.1",
postgres_port: ?u16 = null,
mysql_port: ?u16 = null,
health_address: []const u8 = "127.0.0.1",
health_port: ?u16 = null,
drain_ms: u32 = 30000,
limits: g.Limits = .{},
request_timeout_ms: u32 = 5000,
accounts: []const Account,
settings: ?struct { url: []const u8, binding: g.query.settings.Contract.Binding } = null,
pub const Database = struct { name: []const u8, binding: g.Ledger.Binding };
pub const KeyFiles = struct { worker: []const u8, ingress: []const u8, coordinator: []const u8, table: []const u8, reader: []const u8 };
pub const Account = struct {
    name: []const u8,
    enabled: bool = true,
    verifier_file: []const u8,
    ledger: g.Ledger.Configuration,
    generation: u64,
    association: []const u8 = "state",
    keys: KeyFiles,
    databases: []const Database,
    pub fn database(self: Account, name: []const u8) !g.Ledger.Binding {
        for (self.databases) |value| if (std.mem.eql(u8, value.name, name)) return value.binding;
        return error.GatewayDatabaseDenied;
    }
};
pub fn account(self: Self, name: []const u8) !usize {
    for (self.accounts, 0..) |value, i| if (value.enabled and std.mem.eql(u8, value.name, name)) return i;
    return error.InvalidAuthentication;
}
/// Retained ledger workers may run without admitting any new SQL connections.
pub fn listening(self: Self) bool {
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
    if (self.listening()) {
        try path(self.certificate_file);
        try path(self.certificate_key_file);
    }
    for (self.accounts, 0..) |value, i| {
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
            for ([_]u64{ a.worker, a.ingress, a.control, a.coordinator, a.table_principal, a.reader }) |principal| for ([_]u64{ b.worker, b.ingress, b.control, b.coordinator, b.table_principal, b.reader }) |old| if (principal == old) return error.InvalidGatewayConfiguration;
        }
        for (value.databases, 0..) |database, j| {
            try validateName(database.name);
            if (!std.meta.eql(database.binding, value.ledger.bindings[j])) return error.InvalidGatewayConfiguration;
            for (value.databases[0..j]) |other| if (std.mem.eql(u8, database.name, other.name)) return error.InvalidGatewayConfiguration;
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
    verifier: g.Authentication.Verifier,
    pub fn checkIdentity(self: Credential, principal: u64, login_role: u64, epoch: u64) !void {
        if (self.principal != principal or self.login_role != login_role or self.credential_epoch != epoch) return error.GatewayCredentialChanged;
    }
    pub fn validate(self: Credential, identity: [32]u8) !void {
        if (self.version != 1 or self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        if (self.principal == 0 or self.principal > p.max_counter or self.login_role > p.max_counter or self.credential_epoch == 0 or self.credential_epoch > p.max_counter or self.revision == 0 or !std.mem.eql(u8, &self.account, &identity)) return error.InvalidAuthentication;
        try self.verifier.validate();
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
    var accounts = [_]Account{.{ .name = "user", .verifier_file = "/private/verifier", .ledger = .{ .realm = 1, .resource = 7, .owner = 3, .worker = 2, .ingress = 4, .control = 5, .coordinator = 10, .table_principal = 6, .reader = 11, .account = @splat(7), .bindings = &.{binding}, .intent_bytes = 4096, .operation_quota = 100, .byte_quota = 1024 * 1024 }, .generation = 1, .keys = .{ .worker = "/private/w", .ingress = "/private/i", .coordinator = "/private/c", .table = "/private/t", .reader = "/private/r" }, .databases = &.{.{ .name = "data", .binding = binding }} }};
    var config: Self = .{ .version = 1, .definition = p.Growth.current_definition, .native_url = "http://127.0.0.1:7700", .certificate_file = "/private/cert", .certificate_key_file = "/private/key", .activation_directory = "/private/activation", .spill_directory = "/private/spill", .postgres_port = 5432, .accounts = &accounts };
    try config.validate();
    try t.expectEqual(@as(usize, 0), try config.account("user"));
    try t.expectError(error.InvalidAuthentication, config.account("other"));
    try t.expectEqualDeep(binding, try accounts[0].database("data"));
    try t.expectError(error.GatewayDatabaseDenied, accounts[0].database("other"));
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
    accounts[0].databases = &.{.{ .name = "data", .binding = .{ .resource = 10, .catalog = 1, .owner = 9 } }};
    try t.expectError(error.InvalidGatewayConfiguration, config.validate());
}
