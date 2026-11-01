//! Stable SQL owner used by Context leases. Primary and control transports have
//! separate existing SQL reserves; response slots are never shared concurrently.
const std = @import("std");
const sql = @import("transit_sql_client");
const Self = @This();
allocator: std.mem.Allocator,
arena: std.heap.ArenaAllocator,
client: sql.Client,
control: sql.Client,
executor: sql.Executor,
cancel: std.atomic.Value(u8) = .init(@backingInt(sql.Executor.Cancellation.Request.none)),

pub fn create(allocator: std.mem.Allocator, io: std.Io, config: sql.Client.Config, password: ?[]const u8) !*Self {
    var bytes: usize = if (password) |value| value.len else 0;
    inline for (.{ "endpoint", "account", "database", "source", "ca_file", "password_file" }) |field| {
        const value: ?[]const u8 = @field(config, field);
        if (value) |text| bytes = std.math.add(usize, bytes, text.len) catch return error.InvalidSqlClientConfiguration;
    }
    if (bytes > 64 * 1024) return error.InvalidSqlClientConfiguration;
    const self = try allocator.create(Self);
    errdefer allocator.destroy(self);
    var arena: std.heap.ArenaAllocator = .init(allocator);
    errdefer arena.deinit();
    const a = arena.allocator();
    var owned = config;
    inline for (.{ "endpoint", "account", "database" }) |field| @field(owned, field) = try a.dupe(u8, @field(config, field));
    inline for (.{ "source", "ca_file", "password_file" }) |field| if (@field(config, field)) |text| {
        @field(owned, field) = try a.dupe(u8, text);
    };
    const secret = if (password) |text| try a.dupe(u8, text) else null;
    errdefer if (secret) |text| std.crypto.secureZero(u8, text);
    var client = try sql.Client.init(allocator, io, owned);
    errdefer client.deinit();
    const control = try sql.Client.init(allocator, io, owned);
    self.* = .{ .allocator = allocator, .arena = arena, .client = client, .control = control, .executor = undefined };
    self.executor = .{
        .client = &self.client,
        .control = &self.control,
        .config = owned,
        .password = secret,
        .cancellation = .{ .context = self, .requested = requested, .acknowledge = acknowledge },
    };
    return self;
}

/// Negotiation is explicit and never replaces an already opened session.
pub fn connect(self: *Self) !void {
    if (self.client.session != null) return error.SqlSessionAlreadyOpen;
    try self.client.open(self.executor.config, self.executor.password);
    self.control.instance = self.client.instance;
    self.control.session = self.client.session;
    self.control.account = self.client.account;
}

fn requested(raw: *anyopaque) sql.Executor.Cancellation.Request {
    const self: *Self = @ptrCast(@alignCast(raw));
    return @fromBackingInt(@intCast(self.cancel.load(.acquire)));
}
fn acknowledge(raw: *anyopaque) void {
    const self: *Self = @ptrCast(@alignCast(raw));
    self.cancel.store(@backingInt(sql.Executor.Cancellation.Request.none), .release);
}
pub fn destroy(self: *Self) void {
    const allocator = self.allocator;
    self.control.deinit();
    self.client.deinit();
    if (self.executor.password) |secret| std.crypto.secureZero(u8, @constCast(secret));
    self.arena.deinit();
    allocator.destroy(self);
}

fn allocationFailures(allocator: std.mem.Allocator) !void {
    const session = try create(allocator, std.testing.io, .{ .endpoint = "http://127.0.0.1:1", .authentication = .trust }, "secret");
    defer session.destroy();
    try std.testing.expect(session.client.session == null);
    try std.testing.expect(session.executor.client == &session.client);
    try std.testing.expect(session.executor.control == &session.control);
}
test "SQL facet construction owns configuration and unwinds backing allocation failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, allocationFailures, .{});
}
