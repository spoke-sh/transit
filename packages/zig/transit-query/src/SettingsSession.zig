//! A connection captures new-session defaults. Overrides never mutate the host.
const std = @import("std");
const q = @import("root.zig");
const Self = @This();
default_timeout: u64 = 0,
ceiling: u64 = 0,
override_timeout: ?u64 = null,
generation: u64 = 0,
pub fn capture(client: q.SettingsClient) !Self {
    for (0..4) |_| {
        const defaults = try client.read(.{ .settings = .{ .name = "query.statement_timeout" } });
        defer defaults.deinit();
        const ceiling = try client.read(.{ .settings = .{ .name = "query.statement_timeout_ceiling" } });
        defer ceiling.deinit();
        const d = defaults.value.result.settings;
        const c = ceiling.value.result.settings;
        if (d.generation != c.generation) continue;
        if (d.rows.len != 1 or c.rows.len != 1) return error.InvalidConfigurationResponse;
        return .{ .default_timeout = try std.fmt.parseInt(u64, d.rows[0].value orelse return error.InvalidConfigurationResponse, 10), .ceiling = try std.fmt.parseInt(u64, c.rows[0].value orelse return error.InvalidConfigurationResponse, 10), .generation = d.generation };
    }
    return error.ConfigurationSnapshotChanged;
}
pub fn timeout(self: Self) u64 {
    return self.override_timeout orelse self.default_timeout;
}
pub fn set(self: *Self, duration: ?u64) !void {
    const value = duration orelse self.default_timeout;
    if (value > 86400000 or (self.ceiling != 0 and (value == 0 or value > self.ceiling))) return error.SettingOutOfRange;
    self.override_timeout = duration;
}
pub fn reset(self: *Self) void {
    self.override_timeout = null;
}
pub fn overlay(self: Self, a: std.mem.Allocator, row: q.settings.Contract.Row) !q.settings.Contract.Row {
    var result = row;
    const timeout_setting = std.mem.eql(u8, row.name, "query.statement_timeout");
    if (timeout_setting or std.mem.eql(u8, row.name, "query.statement_timeout_ceiling")) {
        result.session_generation = self.generation;
        result.value = try std.fmt.allocPrint(a, "{d}", .{if (timeout_setting) self.timeout() else self.ceiling});
        if ((timeout_setting and self.override_timeout != null) or row.generation != self.generation) {
            result.source = .session;
            result.source_name = null;
            result.source_line = null;
            result.source_column = null;
        }
    }
    return result;
}
test "session deadlines enforce unlimited semantics and reset to captured defaults" {
    const t = std.testing;
    var session: Self = .{ .default_timeout = 20, .ceiling = 100 };
    try session.set(50);
    try t.expectEqual(@as(u64, 50), session.timeout());
    try t.expectError(error.SettingOutOfRange, session.set(0));
    try t.expectError(error.SettingOutOfRange, session.set(101));
    try t.expectEqual(@as(u64, 50), session.timeout());
    session.reset();
    try t.expectEqual(@as(u64, 20), session.timeout());
}
