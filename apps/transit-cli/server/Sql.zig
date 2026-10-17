//! Local SQL placement over public native enrollment, ledger and authorization owners.
const std = @import("std");
const g = @import("transit_sql_gateway");
const q = @import("transit_query");
const p = q.protocol;
const E = @import("SqlEnrollment.zig");
const Journal = @import("SqlJournal.zig");
const Trust = @import("SqlTrust.zig");
const Settings = @import("SqlSettings.zig");
const Installation = @import("Installation.zig");
const Files = @import("Files.zig");
const Process = @import("Process.zig");
const Provider = @import("Provider.zig");
const Self = @This();
installation: *Installation,
allocator: std.mem.Allocator,
executable: []const u8,
meta: E.Meta,
entries: std.ArrayList(Entry) = .empty,
bootstrap: Process = .{},
bootstrapping: ?usize = null,
service: Process = .{},
service_count: usize = 0,
service_started: ?std.Io.Timestamp = null,
trust: ?Trust.Paths = null,
trust_error: ?[]const u8 = null,
status: enum { awaiting_authorization, initializing, starting, accepting, recovery, unavailable } = .awaiting_authorization,
last: ?std.Io.Timestamp = null,
failures: u8 = 0,
last_error: ?[]const u8 = null,
setup_complete: bool = false,
provisioning: ?E.Account = null,
const Entry = struct { record: E.Account, desired: ?Settings.Account, state: E.AuthorizationState = .unavailable };

/// Resolve all frozen root operations before another supervisor uses its sequence.
pub fn recover(installation: *Installation) !void {
    var arena: std.heap.ArenaAllocator = .init(installation.init.gpa);
    defer arena.deinit();
    const allocator = arena.allocator();
    var meta = (try E.open(installation, allocator)) orelse return;
    meta.journal.flush(installation, try E.path(installation, allocator, "installation.json"), &meta) catch |err| {
        if (installation.failed or meta.journal.pending != null) return err;
    };
    var directory = try std.Io.Dir.cwd().openDir(installation.init.io, try E.path(installation, allocator, "accounts"), .{ .iterate = true });
    defer directory.close(installation.init.io);
    var iterator = directory.iterate();
    while (try iterator.next(installation.init.io)) |entry| {
        if (!Settings.safeName(entry.name) or entry.kind != .directory) continue;
        var page: std.heap.ArenaAllocator = .init(installation.init.gpa);
        defer page.deinit();
        var record = try E.loadAccount(installation, page.allocator(), entry.name);
        record.journal.flush(installation, try E.accountPath(installation, page.allocator(), record.name, "account.json"), &record) catch |err| {
            if (installation.failed or record.journal.pending != null) return err;
        };
    }
}
pub fn create(installation: *Installation, allocator: std.mem.Allocator, executable: []const u8) !?*Self {
    const meta = (try E.open(installation, allocator)) orelse return null;
    const self = try allocator.create(Self);
    self.* = .{ .installation = installation, .allocator = allocator, .executable = executable, .meta = meta };
    errdefer self.stop();
    try self.tick();
    return self;
}
fn prepare(self: *Self) !void {
    const installation = self.installation;
    const allocator = self.allocator;
    try E.administrator(installation, allocator, &self.meta);
    self.entries.clearRetainingCapacity();
    if (installation.config.sql.listening()) for (installation.config.sql.accounts) |desired| {
        if (!desired.enabled) continue;
        self.provisioning = try E.createAccount(installation, allocator, desired);
        try E.provision(installation, allocator, &self.provisioning.?);
        self.provisioning = null;
    };
    var directory = try std.Io.Dir.cwd().openDir(installation.init.io, try E.path(installation, allocator, "accounts"), .{ .iterate = true });
    defer directory.close(installation.init.io);
    var iterator = directory.iterate();
    while (try iterator.next(installation.init.io)) |entry| {
        if (!Settings.safeName(entry.name) or entry.kind != .directory) continue;
        // Retained account count does not determine resident memory. Each old
        // account is inspected separately; only active/recovering owners remain.
        var page: std.heap.ArenaAllocator = .init(installation.init.gpa);
        defer page.deinit();
        const record = try E.loadAccount(installation, page.allocator(), entry.name);
        if (record.initialized) try E.controlProfile(installation, page.allocator(), record);
        const desired = self.configuredAccount(record.name);
        if (desired) |value| {
            if (!std.mem.eql(u8, record.role, value.role) or !std.mem.eql(u8, record.database, value.database) or !std.mem.eql(u8, record.schema, value.schema)) return error.GatewayConfigurationChanged;
        }
        if (desired == null or !desired.?.enabled) {
            if (!record.initialized and record.initialization == null) continue;
            if (record.initialized) {
                const ledger: g.Ledger = .{ .configuration = try record.ledger(page.allocator(), installation.config.realm) };
                var reader: q.wire.ResourceReader = .{ .wire = installation.wire, .realm = installation.config.realm, .principal = 0, .key = installation.root };
                var source = try reader.open(ledger.configuration.resource);
                if ((try ledger.head(&source)).unsettled == 0) continue;
            }
        }
        if (self.entries.items.len == g.Limits.max_accounts) return error.GatewayConnectionCapacity;
        try self.entries.append(allocator, .{ .record = try E.loadAccount(installation, allocator, record.name), .desired = desired });
    }
    if (installation.config.sql.listening()) {
        self.trust = Trust.prepare(installation, allocator, &self.meta) catch |err| blk: {
            if (installation.failed) return err;
            self.trust_error = @errorName(err);
            break :blk null;
        };
    }
}
fn configuredAccount(self: *Self, name: []const u8) ?Settings.Account {
    for (self.installation.config.sql.accounts) |account| if (std.mem.eql(u8, account.name, name)) return account;
    return null;
}
pub fn stop(self: *Self) void {
    self.service.stopWithTimeout(self.installation.init.io, self.installation.config.sql.drain_ms + 1000);
    self.bootstrap.stop(self.installation.init.io);
}
fn runtimeAccount(self: *Self, allocator: std.mem.Allocator, entry: Entry) !g.Configuration.Account {
    const record = entry.record;
    var keys: g.Configuration.KeyFiles = undefined;
    inline for (@typeInfo(g.Configuration.KeyFiles).@"struct".field_names) |name| @field(keys, name) = try E.accountPath(self.installation, allocator, record.name, name ++ ".seed");
    const databases = try allocator.dupe(g.Configuration.Database, &.{.{ .name = record.database, .binding = record.binding }});
    return .{ .name = record.name, .enabled = entry.desired != null and entry.desired.?.enabled, .verifier_file = try E.accountPath(self.installation, allocator, record.name, "verifier.json"), .ledger = try record.ledger(allocator, self.installation.config.realm), .generation = record.journal.generation, .keys = keys, .databases = databases };
}
fn configuration(self: *Self, allocator: std.mem.Allocator, accounts: []const g.Configuration.Account, admission: bool) !g.Configuration {
    const sql = self.installation.config.sql;
    return .{ .version = 1, .definition = p.Growth.current_definition, .native_url = self.installation.wire.url, .certificate_file = if (self.trust) |trust| trust.certificate else "", .certificate_key_file = if (self.trust) |trust| trust.key else "", .activation_directory = try E.path(self.installation, allocator, "activations"), .spill_directory = try E.path(self.installation, allocator, "spill"), .postgres_port = if (admission and self.trust != null and sql.postgres != null) sql.postgres.?.port else null, .mysql_port = if (admission and self.trust != null and sql.mysql != null) sql.mysql.?.port else null, .health_port = if (admission) sql.health_port else null, .drain_ms = sql.drain_ms, .request_timeout_ms = sql.request_timeout_ms, .limits = .{ .connections = sql.connections, .connections_per_account = sql.connections_per_account, .authentications = sql.authentications, .command_ms = sql.command_ms, .idle_ms = sql.idle_ms }, .accounts = accounts, .settings = .{ .url = self.installation.record.endpoint, .binding = try Installation.settingsBinding(self.installation.record, self.installation.config.realm) } };
}
fn saveAccount(self: *Self, record: *E.Account) !void {
    try Journal.save(self.installation, try E.accountPath(self.installation, self.allocator, record.name, "account.json"), record);
}
fn activate(self: *Self, record: *E.Account) !void {
    const file = try E.accountPath(self.installation, self.allocator, record.name, "account.json");
    try record.journal.activate(self.installation, file, record, record.journal.receipts[0].?, record.principals.worker);
}
fn beginInitialization(self: *Self, index: usize, allocator: std.mem.Allocator) !void {
    const installation = self.installation;
    const entry = &self.entries.items[index];
    try self.activate(&entry.record);
    const accounts = [_]g.Configuration.Account{try self.runtimeAccount(allocator, entry.*)};
    const config = try self.configuration(allocator, &accounts, false);
    const file = try E.accountPath(installation, allocator, entry.record.name, "initialize.json");
    try Files.json(installation.init.io, allocator, file, config);
    var control_key = try q.wire.readKey(allocator, installation.init.io, try E.accountPath(installation, allocator, entry.record.name, "control.seed"));
    defer std.crypto.secureZero(u8, std.mem.asBytes(&control_key));
    var client: g.Client = .{ .transport = installation.wire, .ledger = .{ .configuration = config.accounts[0].ledger }, .principal = entry.record.principals.control, .key = control_key };
    if (entry.record.initialization == null) {
        var table_key = try q.wire.readKey(allocator, installation.init.io, config.accounts[0].keys.table);
        defer std.crypto.secureZero(u8, std.mem.asBytes(&table_key));
        const identity: q.wire.AuthorizationClient = .{ .transport = installation.wire, .realm = installation.config.realm, .principal = entry.record.principals.table, .key = table_key };
        const sequence = (try identity.read(.identity)).principal_sequence;
        const prepared = try client.prepare(.{ .initialize = sequence });
        entry.record.initialization = .{ .prepared = prepared };
        try self.saveAccount(&entry.record);
    }
    try self.bootstrap.start(installation.init, self.executable, try E.path(installation, allocator, "initialize.launch.json"), .{ .argv = &.{ installation.config.executables.sql_gateway, "--initialize", file } }, false);
    self.bootstrapping = index;
    if (entry.record.initialization.?.receipt == null) {
        const receipt = try client.submit(entry.record.initialization.?.prepared);
        entry.record.initialization.?.receipt = receipt;
        try self.saveAccount(&entry.record);
    }
    self.status = .initializing;
}
fn pollInitialization(self: *Self, allocator: std.mem.Allocator) !void {
    const entry = &self.entries.items[self.bootstrapping orelse return];
    const installation = self.installation;
    var key = try q.wire.readKey(allocator, installation.init.io, try E.accountPath(installation, allocator, entry.record.name, "control.seed"));
    defer std.crypto.secureZero(u8, std.mem.asBytes(&key));
    var client: g.Client = .{ .transport = installation.wire, .ledger = .{ .configuration = try entry.record.ledger(allocator, installation.config.realm) }, .principal = entry.record.principals.control, .key = key };
    if (entry.record.initialization == null) return error.UnresolvedProvisioning;
    if (entry.record.initialization.?.receipt == null) {
        const receipt = try client.submit(entry.record.initialization.?.prepared);
        entry.record.initialization.?.receipt = receipt;
        try self.saveAccount(&entry.record);
    }
    const pending = entry.record.initialization.?;
    const progress = try client.progress(pending.prepared, pending.receipt orelse return error.UnresolvedProvisioning);
    if (progress == .pending) {
        if (!self.bootstrap.alive()) return error.GatewayOwnerUnavailable;
        return;
    }
    if (progress.processed != null) return error.GatewayControlRejected;
    entry.record.initialized = true;
    try self.saveAccount(&entry.record);
    self.bootstrap.stop(installation.init.io);
    self.bootstrapping = null;
    try E.controlProfile(installation, allocator, entry.record);
}
fn startService(self: *Self, allocator: std.mem.Allocator) !void {
    const installation = self.installation;
    self.service.stopWithTimeout(installation.init.io, installation.config.sql.drain_ms + 1000);
    var accounts: std.ArrayList(g.Configuration.Account) = .empty;
    for (self.entries.items) |*entry| if (entry.record.initialized) {
        try self.activate(&entry.record);
        try accounts.append(allocator, try self.runtimeAccount(allocator, entry.*));
    };
    if (accounts.items.len == 0) return;
    const file = try E.path(installation, allocator, "gateway.json");
    try Files.json(installation.init.io, allocator, file, try self.configuration(allocator, accounts.items, true));
    try self.service.start(installation.init, self.executable, try E.path(installation, allocator, "gateway.launch.json"), .{ .argv = &.{ installation.config.executables.sql_gateway, file } }, false);
    self.service_count = accounts.items.len;
    self.service_started = std.Io.Clock.awake.now(installation.init.io);
    self.status = .starting;
}
pub fn tick(self: *Self) !void {
    if (self.installation.root_pending != null and !self.hasPending()) return;
    const now = std.Io.Clock.awake.now(self.installation.init.io);
    if (self.last) |last| if (last.durationTo(now).toMilliseconds() < 1000) return;
    self.last = now;
    var arena: std.heap.ArenaAllocator = .init(self.installation.init.gpa);
    defer arena.deinit();
    self.advance(arena.allocator()) catch |err| {
        if (self.installation.failed or err == error.AuthorityRollback) return err;
        if (q.wire.Client.unavailable(err)) {
            self.status = .unavailable;
            self.last_error = @errorName(err);
            try self.writeStatus(arena.allocator());
            return; // Preserve exact pending work; suspend other root writers.
        }
        if (self.hasPending()) return err;
        // SQL-specific failures do not take away the core administration path.
        // No retry here recreates a credential, grant or accepted operation.
        self.stop();
        self.bootstrapping = null;
        self.service_count = 0;
        self.status = .unavailable;
        self.last_error = if (self.installation.wire.last_rejection) |cause| @tagName(cause) else @errorName(err);
        self.failures += 1;
    };
    try self.writeStatus(arena.allocator());
}
pub fn hasPending(self: *Self) bool {
    if (self.meta.journal.pending != null) return true;
    if (self.provisioning) |record| if (record.journal.pending != null) return true;
    for (self.entries.items) |entry| if (entry.record.journal.pending != null) return true;
    return false;
}
fn advance(self: *Self, allocator: std.mem.Allocator) !void {
    if (self.failures >= 3) return;
    if (!self.setup_complete) {
        try self.prepare();
        self.setup_complete = true;
    }
    for (self.entries.items) |*entry| try entry.record.journal.flush(self.installation, try E.accountPath(self.installation, allocator, entry.record.name, "account.json"), &entry.record);
    try self.pollInitialization(allocator);
    for (self.entries.items, 0..) |*entry, index| {
        if (entry.desired) |desired_config| {
            entry.state = if (desired_config.enabled) try E.enrollment(self.installation, allocator, &entry.record, desired_config) else .unavailable;
        } else entry.state = .unavailable;
        if (!entry.record.initialized and self.bootstrapping == null and (entry.state == .bound or entry.record.initialization != null)) try self.beginInitialization(index, allocator);
    }
    var initialized: usize = 0;
    for (self.entries.items) |entry| if (entry.record.initialized) {
        initialized += 1;
    };
    if (self.entries.items.len == 0) self.status = if (self.installation.config.sql.listening()) .awaiting_authorization else .recovery;
    if (initialized != self.service_count) try self.startService(allocator);
    if (self.service.child != null) {
        if (!self.service.alive()) return error.GatewayOwnerUnavailable;
        const recovery = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}/recovery", .{self.installation.config.sql.health_port});
        if (Provider.health(self.installation.init, recovery)) {
            self.status = if (self.installation.config.sql.listening() and self.trust != null) .accepting else .recovery;
        } else if (self.service_started.?.durationTo(std.Io.Clock.awake.now(self.installation.init.io)).toMilliseconds() > 30000) return error.GatewayOwnerUnavailable;
    }
}
pub fn report(self: *Self, allocator: std.mem.Allocator) !Report {
    return .{ .state = @tagName(self.status), .host = "127.0.0.1", .postgres_port = if (self.status == .accepting and self.installation.config.sql.postgres != null) self.installation.config.sql.postgres.?.port else null, .mysql_port = if (self.status == .accepting and self.installation.config.sql.mysql != null) self.installation.config.sql.mysql.?.port else null, .ca_file = if (self.trust) |trust| trust.ca else null, .authorization_config = try E.path(self.installation, allocator, "authorization.yaml"), .catalog_config = try E.path(self.installation, allocator, "catalog.yaml"), .status_file = try E.path(self.installation, allocator, "status.json"), .tls_error = self.trust_error, .error_type = self.last_error };
}
pub const Report = struct { state: []const u8, host: []const u8, postgres_port: ?u16, mysql_port: ?u16, ca_file: ?[]const u8, authorization_config: []const u8, catalog_config: []const u8, status_file: []const u8, tls_error: ?[]const u8, error_type: ?[]const u8 };
fn writeStatus(self: *Self, allocator: std.mem.Allocator) !void {
    const AccountStatus = struct { name: []const u8, role: []const u8, database: []const u8, schema: []const u8, state: E.AuthorizationState, initialized: bool, enabled: bool, control_config: ?[]const u8 };
    var accounts: std.ArrayList(AccountStatus) = .empty;
    for (self.entries.items) |entry| try accounts.append(allocator, .{ .name = entry.record.name, .role = entry.record.role, .database = entry.record.database, .schema = entry.record.schema, .state = entry.state, .initialized = entry.record.initialized, .enabled = entry.desired != null and entry.desired.?.enabled, .control_config = if (entry.record.initialized) try E.accountPath(self.installation, allocator, entry.record.name, "control.json") else null });
    const status = .{ .service = try self.report(allocator), .accounts = accounts.items };
    _ = try Files.jsonIfChanged(self.installation.init.io, allocator, try E.path(self.installation, allocator, "status.json"), status);
}
