//! Durable browser challenges, external identities and revocable sessions in
//! ordinary Transit Tables. They confer no native/SQL permissions by themselves.
const std = @import("std");
const Security = @import("Security.zig");
const Sql = @import("Sql.zig");
const Self = @This();
sql: *Sql,
pub const Identity = struct { id: u64, subject: []const u8, provider: Security.Provider };
fn id(token: []const u8) !u64 {
    if (!Security.validToken(token)) return error.InvalidBrowserToken;
    return std.fmt.parseInt(u64, token[0..15], 16);
}
fn text(row: std.json.Value, field: []const u8) ![]const u8 {
    return @import("Oidc.zig").string(row, field);
}
fn number(row: std.json.Value, field: []const u8) !u64 {
    return std.fmt.parseInt(u64, try text(row, field), 10);
}
fn format(self: Self, comptime pattern: []const u8, args: anytype) ![]const u8 {
    return std.fmt.allocPrint(self.sql.a, pattern, args);
}
pub fn issue(self: Self, provider: Security.Provider, state: []const u8, browser: []const u8, now: i64) !void {
    const hash = Security.digest(state);
    const browser_hash = Security.digest(browser);
    const active = try self.sql.rows(try self.format("SELECT id FROM transit_browser_challenges WHERE expires_at > {d} AND consumed = 0 LIMIT 1025", .{now}), 1025);
    if (active.array.items.len >= 1024) return error.BrowserChallengeCapacity;
    if (try self.sql.command(try self.format("INSERT INTO transit_browser_challenges (id, state_hash, browser_hash, provider, expires_at, consumed) VALUES ({d}, '{s}', '{s}', '{s}', {d}, 0)", .{ try id(&hash), hash, browser_hash, @tagName(provider), now + 300 })) != 1) return error.BrowserStateUnavailable;
}
/// Claim before sending a one-use provider code. Exact count is mandatory;
/// uncertainty may burn this login but must never replay a token exchange.
pub fn consume(self: Self, provider: Security.Provider, state: []const u8, browser: []const u8, now: i64) !void {
    if (!Security.validToken(state) or !Security.validToken(browser)) return error.InvalidBrowserToken;
    const hash = Security.digest(state);
    const browser_hash = Security.digest(browser);
    const changed = try self.sql.command(try self.format("UPDATE transit_browser_challenges SET consumed = 1 WHERE id = {d} AND state_hash = '{s}' AND browser_hash = '{s}' AND provider = '{s}' AND expires_at > {d} AND consumed = 0", .{ try id(&hash), hash, browser_hash, @tagName(provider), now }));
    if (changed != 1) return error.BrowserChallengeRejected;
}
pub fn identify(self: Self, provider: Security.Provider, subject_hash: []const u8) !Identity {
    const identity_id = try id(subject_hash);
    const rows = try self.sql.rows(try self.format("SELECT id, subject_hash, provider, disabled FROM transit_browser_identities WHERE id = {d} LIMIT 2", .{identity_id}), 2);
    if (rows.array.items.len == 0) {
        if (try self.sql.command(try self.format("INSERT INTO transit_browser_identities (id, subject_hash, provider, disabled) VALUES ({d}, '{s}', '{s}', 0)", .{ identity_id, subject_hash, @tagName(provider) })) != 1) return error.BrowserStateUnavailable;
    } else {
        const row = rows.array.items[0];
        if (rows.array.items.len != 1 or !std.mem.eql(u8, try text(row, "subject_hash"), subject_hash) or !std.mem.eql(u8, try text(row, "provider"), @tagName(provider))) return error.BrowserIdentityCollision;
        if (try number(row, "disabled") != 0) return error.BrowserIdentityDisabled;
    }
    return .{ .id = identity_id, .subject = subject_hash, .provider = provider };
}
pub fn session(self: Self, identity: Identity, token: []const u8, now: i64) !void {
    const hash = Security.digest(token);
    if (try self.sql.command(try self.format("INSERT INTO transit_browser_sessions (id, token_hash, identity_id, expires_at, revoked) VALUES ({d}, '{s}', {d}, {d}, 0)", .{ try id(&hash), hash, identity.id, now + 28800 })) != 1) return error.BrowserStateUnavailable;
}
pub fn authenticate(self: Self, token: []const u8, now: i64) !Identity {
    if (!Security.validToken(token)) return error.InvalidBrowserToken;
    const hash = Security.digest(token);
    const sessions = try self.sql.rows(try self.format("SELECT identity_id FROM transit_browser_sessions WHERE id = {d} AND token_hash = '{s}' AND expires_at > {d} AND revoked = 0 LIMIT 2", .{ try id(&hash), hash, now }), 2);
    if (sessions.array.items.len != 1) return error.BrowserSessionRejected;
    const identity_id = try number(sessions.array.items[0], "identity_id");
    const identities = try self.sql.rows(try self.format("SELECT subject_hash, provider FROM transit_browser_identities WHERE id = {d} AND disabled = 0 LIMIT 2", .{identity_id}), 2);
    if (identities.array.items.len != 1) return error.BrowserSessionRejected;
    const row = identities.array.items[0];
    return .{ .id = identity_id, .subject = try text(row, "subject_hash"), .provider = std.meta.stringToEnum(Security.Provider, try text(row, "provider")) orelse return error.InvalidBrowserIdentity };
}
pub fn revoke(self: Self, token: []const u8) !void {
    if (!Security.validToken(token)) return error.InvalidBrowserToken;
    const hash = Security.digest(token);
    _ = try self.sql.command(try self.format("UPDATE transit_browser_sessions SET revoked = 1 WHERE id = {d} AND token_hash = '{s}' AND revoked = 0", .{ try id(&hash), hash }));
}
