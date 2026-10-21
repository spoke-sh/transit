//! Public local SQL placement settings. Paths are references, never credentials.
const std = @import("std");
const Gateway = @import("transit_sql").Configuration;
const Self = @This();
postgres: ?PostgresListener = null,
mysql: ?MysqlListener = null,
accounts: []const Account = &.{},
tls: Tls = .{},
health_port: u16 = 19108,
drain_ms: u32 = 30000,
request_timeout_ms: u32 = 5000,
command_ms: u32 = 30000,
idle_ms: u32 = 30000,
connections: u16 = 64,
connections_per_account: u8 = 8,
authentications: u8 = 4,
operation_quota: u64 = 1000000,
byte_quota: u64 = 1073741824,
pending_quota: u32 = 16,
pub const PostgresListener = struct { port: u16 = 15432 };
pub const MysqlListener = struct { port: u16 = 13306 };
pub const Tls = struct { mode: Gateway.TlsMode = .required, certificate_file: ?[]const u8 = null, key_file: ?[]const u8 = null, ca_file: ?[]const u8 = null };
pub const Account = struct {
    name: []const u8,
    role: []const u8,
    authentication: Gateway.Authentication = .password,
    password_file: ?[]const u8 = null,
    bootstrap_owner: bool = false,
    enabled: bool = true,
    database: []const u8 = "transit",
    schema: []const u8 = "public",
    pub const json_schema_text_bounds = .{ .name = 63, .role = 63, .password_file = 4096, .database = 63, .schema = 63 };
};
pub fn listening(self: Self) bool {
    return self.postgres != null or self.mysql != null;
}
pub fn resolve(self: *Self, allocator: std.mem.Allocator, base: []const u8, diagnostic: anytype) !void {
    if (self.connections_per_account > self.connections or self.authentications > self.connections) return diagnostic.invalidField("sql.connections", "must admit the configured per-account and authentication bounds", null);
    const supplied = @intFromBool(self.tls.certificate_file != null) + @as(u8, @intFromBool(self.tls.key_file != null)) + @intFromBool(self.tls.ca_file != null);
    if (supplied != 0 and supplied != 3) return diagnostic.invalidField("sql.tls", "requires certificate_file, key_file and ca_file together", null);
    if (self.tls.mode == .disabled and supplied != 0) return diagnostic.invalidField("sql.tls", "disabled TLS does not use certificate files", null);
    inline for (.{ "certificate_file", "key_file", "ca_file" }) |name| if (@field(self.tls, name)) |path| {
        @field(self.tls, name) = try resolvePath(allocator, base, path, "sql.tls." ++ name, diagnostic);
    };
    const accounts = try allocator.dupe(Account, self.accounts);
    var enabled: usize = 0;
    for (accounts, 0..) |*account, i| {
        if (account.enabled) enabled += 1;
        if (!safeName(account.name) or account.role.len == 0 or account.role.len > 63 or !std.unicode.utf8ValidateSlice(account.role) or std.mem.indexOfScalar(u8, account.role, 0) != null) return diagnostic.invalidField("sql.accounts", "requires unique account names and valid role names of at most 63 bytes", null);
        for (accounts[0..i]) |other| if (std.mem.eql(u8, account.name, other.name)) return diagnostic.invalidField("sql.accounts", "contains a duplicate account name", null);
        if (!std.mem.eql(u8, account.database, "transit") or !std.mem.eql(u8, account.schema, "public")) return diagnostic.invalidField("sql.accounts", "uses the local transit database and public schema", null);
        if (account.bootstrap_owner and !std.mem.eql(u8, account.role, "local_owner")) return diagnostic.invalidField("sql.accounts", "bootstrap_owner binds only the installation's local_owner role", null);
        if ((account.authentication == .password) != (account.password_file != null)) return diagnostic.invalidField("sql.accounts", "password authentication requires password_file; trust does not use a password", null);
        if (self.mysql != null and self.tls.mode == .disabled and account.enabled and account.authentication == .password) return diagnostic.invalidField("sql.tls.mode", "MySQL password authentication requires optional or required TLS", null);
        if (account.password_file) |path| account.password_file = try resolvePath(allocator, base, path, "sql.accounts.password_file", diagnostic);
    }
    self.accounts = accounts;
    if (self.listening() and enabled == 0) return diagnostic.invalidField("sql.accounts", "a configured SQL listener requires an enabled account; select trust or password authentication", null);
}
fn resolvePath(allocator: std.mem.Allocator, base: []const u8, path: []const u8, field: []const u8, diagnostic: anytype) ![]const u8 {
    if (path.len == 0 or path.len > 4096 or std.mem.indexOfScalar(u8, path, 0) != null) return diagnostic.invalidField(field, "must reference a file", null);
    return std.fs.path.resolve(allocator, &.{ base, path });
}
pub fn safeName(name: []const u8) bool {
    if (name.len == 0 or name.len > 63) return false;
    for (name) |c| if (!std.ascii.isAlphanumeric(c) and c != '_' and c != '-') return false;
    return true;
}
