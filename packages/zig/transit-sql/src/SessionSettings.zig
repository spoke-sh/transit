//! Wire adapter for the same settings plans used by the Transit console.
const std = @import("std");
const g = @import("root.zig");
const q = g.query;
const f = g.fuze;
const Host = @import("Session.zig");
const C = q.settings.Contract;
pub const Prepared = struct {
    plan: q.SettingsSql.Owned,
    output: ?f.Types.Decoded,
    pub fn deinit(self: *Prepared) void {
        if (self.output) |*output| output.deinit();
        self.plan.deinit();
    }
};
pub fn client(host: *Host) !q.SettingsClient {
    const configured = host.config.settings orelse return error.ConfigurationServiceRequired;
    if (configured.binding.realm != host.table.connection.scope.realm) return error.ConfigurationDenied;
    return .{ .allocator = host.allocator, .transport = &host.settings_wire.?, .binding = configured.binding, .principal = host.table.connection.principal, .role = host.table.connection.role, .key = host.table.key };
}
pub fn prepare(host: *Host, sql: []const u8) !?Prepared {
    var plan = (try q.SettingsSql.parse(host.allocator, sql, host.dialect)) orelse return null;
    errdefer plan.deinit();
    if (plan.statement != .catalog and plan.statement != .set and plan.statement != .reset) {
        const selected = try client(host);
        // Read-only authorization during preparation; reload never dispatches.
        var id: [16]u8 = undefined;
        try host.io.randomSecure(&id);
        const signed = try selected.prepare(if (plan.statement == .reload) .{ .reload = .{ .expected_generation = 1 } } else .{ .settings = .{} }, id);
        _ = try selected.transport.call(q.protocol.Growth.Response, "/v1/query", signed.authority);
    }
    return .{ .plan = plan, .output = if (plan.statement == .set or plan.statement == .reset) null else try plan.output(host.allocator) };
}
pub fn mutate(host: *Host, prepared: *Prepared) !void {
    switch (prepared.plan.statement) {
        .set => |setting| try host.settings_session.set(setting.value),
        .reset => host.settings_session.reset(),
        else => return error.ExpectedGatewayWrite,
    }
}
pub const Read = struct {
    host: *Host,
    plan: *const q.SettingsSql.Owned,
    settings: ?q.SettingsReader = null,
    arena: std.heap.ArenaAllocator,
    operation: ?[16]u8 = null,
    emitted: bool = false,
    started: bool = false,
    index: usize = 0,
    tables: ?q.catalog.TableCatalog.Page = null,
    schemas: ?q.catalog.SchemaCatalog.Page = null,
    pages: u64 = 0,
    pub fn init(host: *Host, prepared: *Prepared) !Read {
        var self: Read = .{ .host = host, .plan = &prepared.plan, .arena = .init(host.allocator) };
        errdefer self.deinit();
        switch (prepared.plan.statement) {
            .show, .relation => self.settings = q.SettingsReader.init(host.allocator, try client(host), &prepared.plan, host.settings_session),
            .reload => self.operation = try reload(host),
            .catalog => {},
            else => return error.ExpectedGatewayRead,
        }
        return self;
    }
    pub fn deinit(self: *Read) void {
        if (self.settings) |*settings| settings.deinit();
        self.arena.deinit();
    }
    pub fn next(self: *Read) !?[]const f.Types.Values.Cell {
        try self.host.deadline.check(self.host.io);
        if (self.settings) |*settings| return settings.next();
        _ = self.arena.reset(.retain_capacity);
        const a = self.arena.allocator();
        if (self.operation) |id| {
            if (self.emitted) return null;
            self.emitted = true;
            return try q.SettingsSql.cells(a, .{ .operation = id });
        }
        switch (self.plan.statement.catalog) {
            .databases => {
                while (self.index < self.host.account.databases.len) {
                    const database = self.host.account.databases[self.index];
                    self.index += 1;
                    var table = self.host.table;
                    table.connection.scope.resource = database.binding.resource;
                    table.connection.scope.catalog = database.binding.catalog;
                    table.connection.owner = database.binding.owner;
                    table.connection.namespace = database.binding.namespace;
                    table.connection.role = database.binding.role;
                    _ = table.describeDatabase() catch |err| {
                        if (err == error.AccessDenied or err == error.CatalogDenied) continue;
                        return err;
                    };
                    return try q.SettingsSql.cells(a, .{ .name = database.name });
                }
                return null;
            },
            .tables, .schemas => |kind| while (true) {
                if (kind == .tables) {
                    if (self.tables) |page| while (self.index < page.entries.len) {
                        const slot = page.entries[self.index];
                        self.index += 1;
                        if (slot) |entry| return try q.SettingsSql.cells(a, .{ .name = try a.dupe(u8, entry.metadata.name.slice()) });
                    };
                    if (self.started and self.tables.?.next == null) return null;
                } else {
                    if (self.schemas) |page| while (self.index < page.schemas.len) {
                        const slot = page.schemas[self.index];
                        self.index += 1;
                        if (slot) |entry| return try q.SettingsSql.cells(a, .{ .name = try a.dupe(u8, entry.name.slice()) });
                    };
                    if (self.started and self.schemas.?.next == null) return null;
                }
                if (self.pages == 10000) return error.ConfigurationReadBudgetExceeded;
                if (kind == .tables) self.tables = try self.host.table.list(if (self.tables) |page| page.next else null) else self.schemas = try self.host.table.schemas(if (self.schemas) |page| page.next else null);
                self.started = true;
                self.index = 0;
                self.pages += 1;
            },
        }
    }
};
fn reload(host: *Host) ![16]u8 {
    const selected = try client(host);
    // This lane is separate from accepted Table mutations; a timeout never
    // rewrites or cancels those operations. The retained request survives loss
    // of a native reply and is retried with its exact operation/generation.
    try host.runtime.settings_mutex.lock(host.io);
    defer host.runtime.settings_mutex.unlock(host.io);
    const path = try std.fmt.allocPrint(host.allocator, "{s}/configuration-{s}.json", .{ host.config.activation_directory, std.fmt.bytesToHex(host.account.ledger.account, .lower) });
    defer host.allocator.free(path);
    var saved = try q.SettingsJournal.read(host.allocator, host.io, path, selected);
    if (saved == null or saved.?.complete) {
        const current = try selected.read(.{ .settings = .{ .name = "version" } });
        defer current.deinit();
        var id: [16]u8 = undefined;
        try host.io.randomSecure(&id);
        const signed = try selected.prepare(.{ .reload = .{ .expected_generation = current.value.result.settings.generation } }, id);
        saved = .{ .definition = q.protocol.Growth.current_definition, .request = signed.configuration, .principal = selected.principal, .role = selected.role, .complete = false };
        try q.SettingsJournal.write(host.allocator, host.io, path, saved.?);
    }
    const signed = try selected.prepare(saved.?.request.action, saved.?.request.operation);
    const response = try selected.submit(signed);
    defer response.deinit();
    saved.?.complete = true;
    try q.SettingsJournal.write(host.allocator, host.io, path, saved.?);
    if (response.value.result.reload.phase == .rejected) return error.ConfigurationReloadRejected;
    return saved.?.request.operation;
}
