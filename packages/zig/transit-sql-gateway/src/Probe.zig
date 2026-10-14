//! Explicit constant health/settings grammar for database clients. These probes
//! do not emulate system catalogs or select application data. Unknown SQL stays
//! with the owning compiler and unknown settings remain unsupported.
const std = @import("std");
const g = @import("root.zig");
const Self = @This();
kind: enum { empty, one, version, database, version_comment, server_version, server_version_num, encoding, strings, collation, mode, autocommit, mysql_settings, set },
dialect: g.fuze.Sql.Dialect,
fn token(input: *[]const u8) []const u8 {
    input.* = std.mem.trimStart(u8, input.*, " \t\r\n");
    const bytes = input.*;
    if (bytes.len == 0) return "";
    var length: usize = 1;
    if (std.ascii.isAlphanumeric(bytes[0]) or bytes[0] == '_') {
        while (length < bytes.len and (std.ascii.isAlphanumeric(bytes[length]) or bytes[length] == '_')) : (length += 1) {}
    } else if (bytes[0] == '\'' or bytes[0] == '"') {
        while (length < bytes.len) : (length += 1) if (bytes[length] == bytes[0]) {
            length += 1;
            break;
        };
    }
    input.* = bytes[length..];
    return bytes[0..length];
}
fn matches(input: []const u8, pattern: []const u8) bool {
    var actual = input;
    var expected = pattern;
    while (true) {
        const a = token(&actual);
        const b = token(&expected);
        if (!std.ascii.eqlIgnoreCase(a, b)) return false;
        if (a.len == 0) return true;
    }
}
pub fn parse(sql: []const u8, dialect: g.fuze.Sql.Dialect) !?Self {
    try g.fuze.Sql.validateText(sql);
    var input = std.mem.trim(u8, sql, " \t\r\n");
    if (input.len != 0 and input[input.len - 1] == ';') input = std.mem.trimEnd(u8, input[0 .. input.len - 1], " \t\r\n");
    const common = .{ .{ "", .empty }, .{ "SELECT 1", .one }, .{ "SELECT version()", .version } };
    inline for (common) |entry| if (matches(input, entry[0])) return .{ .kind = entry[1], .dialect = dialect };
    if (dialect == .mysql) {
        const mysql = .{
            .{ "SELECT database()", .database },                                                         .{ "SELECT schema()", .database },
            .{ "SELECT @@version_comment LIMIT 1", .version_comment },                                   .{ "SELECT @@character_set_connection", .encoding },
            .{ "SELECT @@collation_connection", .collation },                                            .{ "SELECT @@sql_mode", .mode },
            .{ "SELECT @@autocommit", .autocommit },                                                     .{ "SELECT @@session.autocommit", .autocommit },
            .{ "SELECT @@character_set_connection,@@collation_connection,@@sql_mode", .mysql_settings }, .{ "SET @@session.autocommit=on", .set },
            .{ "SET @@session.autocommit=1", .set },                                                     .{ "SET autocommit=on", .set },
            .{ "SET autocommit=1", .set },                                                               .{ "SET @@session.sql_mode='ansi_quotes,no_backslash_escapes'", .set },
            .{ "SET sql_mode='ansi_quotes,no_backslash_escapes'", .set },                                .{ "SET NAMES 'utf8mb4' COLLATE 'utf8mb4_0900_bin'", .set },
            .{ "SET NAMES utf8mb4 COLLATE utf8mb4_0900_bin", .set },
        };
        inline for (mysql) |entry| if (matches(input, entry[0])) return .{ .kind = entry[1], .dialect = dialect };
    } else {
        const postgres = .{
            .{ "SELECT current_database()", .database },         .{ "SHOW server_version", .server_version },
            .{ "SHOW server_version_num", .server_version_num }, .{ "SHOW client_encoding", .encoding },
            .{ "SHOW standard_conforming_strings", .strings },   .{ "SET client_encoding TO 'utf8'", .set },
            .{ "SET client_encoding = 'utf8'", .set },           .{ "SET standard_conforming_strings = ON", .set },
            .{ "SET standard_conforming_strings TO ON", .set },
        };
        inline for (postgres) |entry| if (matches(input, entry[0])) return .{ .kind = entry[1], .dialect = dialect };
    }
    return null;
}
pub fn fields(self: Self) []const g.fuze.Types.Field {
    return switch (self.kind) {
        .empty, .set => &.{},
        .one => &.{.{ .name = "?column?", .type = .int64, .nullable = false }},
        .autocommit => &.{.{ .name = "@@autocommit", .type = .uint64, .nullable = false }},
        .mysql_settings => &.{ .{ .name = "@@character_set_connection", .type = .utf8, .nullable = false }, .{ .name = "@@collation_connection", .type = .utf8, .nullable = false }, .{ .name = "@@sql_mode", .type = .utf8, .nullable = false } },
        inline else => |tag| &.{.{ .name = @tagName(tag), .type = .utf8, .nullable = false }},
    };
}
pub fn value(self: Self, database: []const u8, index: usize) !g.fuze.Types.Values.Cell {
    if (index >= self.fields().len) return error.InvalidWireColumns;
    const atom: g.fuze.Types.Values.Atom = switch (self.kind) {
        .empty, .set => unreachable,
        .one => .{ .signed = 1 },
        .autocommit => .{ .unsigned = 1 },
        else => .{ .bytes = switch (self.kind) {
            .version => if (self.dialect == .mysql) "8.4.0-Transit" else "Transit PostgreSQL protocol 3.0 adapter",
            .database => database,
            .version_comment => "Transit SQL gateway",
            .server_version => "18.0-Transit",
            .server_version_num => "180000",
            .encoding => if (self.dialect == .mysql) "utf8mb4" else "UTF8",
            .strings => "on",
            .collation => "utf8mb4_0900_bin",
            .mode => "ANSI_QUOTES,NO_BACKSLASH_ESCAPES",
            .mysql_settings => switch (index) {
                0 => "utf8mb4",
                1 => "utf8mb4_0900_bin",
                2 => "ANSI_QUOTES,NO_BACKSLASH_ESCAPES",
                else => unreachable,
            },
            else => unreachable,
        } },
    };
    return .{ .value = .{ .atom = atom } };
}
test "client probes reject transactions, incompatible settings and concatenated statements" {
    const t = std.testing;
    for ([_][]const u8{ "BEGIN", "SELECT1", "SEL ECT 1", "SET auto commit=ON", "SET autocommit=0", "SET NAMES utf8mb4", "SET sql_mode=''", "SELECT 1; INSERT INTO t VALUES (1)", "SET application_name='ignored'" }) |sql| try t.expectEqual(@as(?Self, null), try parse(sql, .mysql));
    try t.expectEqual(.set, (try parse("SET NAMES 'utf8mb4' COLLATE 'utf8mb4_0900_bin'", .mysql)).?.kind);
    const probe = (try parse("SELECT @@character_set_connection, @@collation_connection, @@sql_mode", .mysql)).?;
    try t.expectEqual(@as(usize, 3), probe.fields().len);
    try t.expectEqualStrings("utf8mb4_0900_bin", (try probe.value("data", 1)).value.atom.bytes);
}
