//! Exact HTTP authorities for the local gateway; never resolve names through DNS.
const std = @import("std");
pub const max_additional = 8;
pub const max_bytes = 200;

pub fn validate(additional: []const []const u8) !void {
    if (additional.len > max_additional) return error.TooManyGatewayHosts;
    for (additional) |authority| try validateAuthority(authority);
}

fn validateAuthority(authority: []const u8) !void {
    if (authority.len == 0 or authority.len > max_bytes) return error.InvalidGatewayHost;
    const separator = std.mem.lastIndexOfScalar(u8, authority, ':') orelse return error.InvalidGatewayHost;
    const host = authority[0..separator];
    const port = authority[separator + 1 ..];
    if (host.len == 0 or port.len == 0 or port.len > 5 or port[0] == '0') return error.InvalidGatewayHost;
    for (port) |byte| if (!std.ascii.isDigit(byte)) return error.InvalidGatewayHost;
    _ = std.fmt.parseInt(u16, port, 10) catch return error.InvalidGatewayHost;
    if (host[0] == '[') {
        if (host[host.len - 1] != ']') return error.InvalidGatewayHost;
        _ = std.Io.net.IpAddress.parseIp6(host[1 .. host.len - 1], 0) catch return error.InvalidGatewayHost;
    } else {
        var labels = std.mem.splitScalar(u8, host, '.');
        while (labels.next()) |label| {
            if (label.len == 0 or label.len > 63 or label[0] == '-' or label[label.len - 1] == '-') return error.InvalidGatewayHost;
            for (label) |byte| if (!std.ascii.isAlphanumeric(byte) and byte != '-') return error.InvalidGatewayHost;
        }
    }
}

/// The returned list/default names use allocator; additional strings are borrowed.
pub fn list(allocator: std.mem.Allocator, port: u16, additional: []const []const u8) ![]const []const u8 {
    try validate(additional);
    const hosts = try allocator.alloc([]const u8, additional.len + 2);
    errdefer allocator.free(hosts);
    hosts[0] = try std.fmt.allocPrint(allocator, "127.0.0.1:{d}", .{port});
    errdefer allocator.free(hosts[0]);
    hosts[1] = try std.fmt.allocPrint(allocator, "localhost:{d}", .{port});
    @memcpy(hosts[2..], additional);
    return hosts;
}

pub fn allows(hosts: []const []const u8, authority: []const u8) bool {
    for (hosts) |host| if (std.ascii.eqlIgnoreCase(host, authority)) return true;
    return false;
}

test "local authority aliases are exact, case insensitive and port scoped" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const hosts = try list(arena.allocator(), 19905, &.{ "bank.local.test:19905", "localhost:29905", "[::1]:29905" });
    for ([_][]const u8{ "127.0.0.1:19905", "localhost:19905", "LOCALHOST:19905", "BANK.local.test:19905", "localhost:29905", "[::1]:29905" }) |host|
        try std.testing.expect(allows(hosts, host));
    for ([_][]const u8{ "localhost", "localhost:80", "localhost:019905", "127.0.0.1:29905", "localhost.attacker.test:19905", "127.0.0.1.attacker.test:19905", "bank.local.test.attacker.test:19905", "bank.local.test:29905", "[::1]:19905", "localhost.:19905" }) |host|
        try std.testing.expect(!allows(hosts, host));
}

test "configured authorities reject wildcard, ambiguous and unbounded input" {
    for ([_][]const u8{ "", "*", "*:19905", "*.localhost:19905", "localhost", "localhost:", ":19905", "localhost:0", "localhost:65536", "localhost:019905", "localhost:+19905", "localhost:19x05", "http://localhost:19905", "user@localhost:19905", "localhost:19905/path", "localhost:19905?x", "localhost:19905#x", "localhost:19905,other:19905", "localhost:19905\r\n", "localhost\x00:19905", "-host:19905", "host-:19905", "host..test:19905", "host.:19905", "local_host:19905", "\xc3\xa9.test:19905", "::1:19905", "[::1:19905", "[localhost]:19905", "[fe80::1%lo]:19905" }) |host|
        try std.testing.expectError(error.InvalidGatewayHost, validate(&.{host}));
    var long_label: [70]u8 = @splat('a');
    @memcpy(long_label[64..], ":19905");
    try std.testing.expectError(error.InvalidGatewayHost, validate(&.{&long_label}));
    var too_long: [201]u8 = undefined;
    for (too_long[0..195], 0..) |*byte, i| byte.* = if (i % 2 == 0) 'a' else '.';
    @memcpy(too_long[195..], ":19905");
    try std.testing.expectError(error.InvalidGatewayHost, validate(&.{&too_long}));
    const too_many: [max_additional + 1][]const u8 = @splat("localhost:19905");
    try std.testing.expectError(error.TooManyGatewayHosts, validate(&too_many));
    try validate(&.{ "example.test:1", "127.0.0.1:65535", "[2001:db8::1]:19905" });
}
