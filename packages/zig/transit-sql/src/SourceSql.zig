//! Explicit connector declarations. Parsing performs no publication or I/O.
const std = @import("std");
const g = @import("root.zig");
const f = g.fuze;
const s = g.catalog.protocol.Source;
const Name = g.catalog.TableAuthority.Name;
const Parser = f.SqlTyped;
pub const Create = struct { name: Name, connection: Name, destination: Name, http: s.Http };
pub const Sink = struct { name: Name, connection: Name, http: s.Sink };
pub const Statement = union(enum) {
    connection: struct { name: Name, endpoint: []const u8 },
    create: Create,
    sink: Sink,
    control: struct { name: Name, kind: g.catalog.SourceDeclaration.Kind, command: s.Command, executor_role: ?f.AuthorizationSql.Role },
    drop: struct { name: Name, kind: g.catalog.SourceDeclaration.Kind },
    inspect: struct { name: ?Name, describe: bool, kind: g.catalog.SourceDeclaration.Kind },
    explain: Create,
    explain_sink: Sink,
};
pub const Prepared = struct {
    arena: std.heap.ArenaAllocator,
    statement: Statement,
    pub fn deinit(self: *Prepared) void {
        self.arena.deinit();
    }
};
const Option = enum { method, path, poll_interval, request_timeout, response_max_bytes };
const options = f.PerfectHash.ComptimeMap(Option, true, .{
    .{ "method", .method },                   .{ "path", .path },                             .{ "poll_interval", .poll_interval },
    .{ "request_timeout", .request_timeout }, .{ "response_max_bytes", .response_max_bytes },
});
const controls = f.PerfectHash.ComptimeMap(s.Command, true, .{
    .{ "AUTHORIZE", .authorize },  .{ "ACTIVATE", .activate }, .{ "SUSPEND", .suspend_source },
    .{ "RESUME", .resume_source }, .{ "RETIRE", .retire },
});

pub fn parse(allocator: std.mem.Allocator, sql: []const u8, dialect: f.Sql.Dialect) !?Prepared {
    var arena: std.heap.ArenaAllocator = .init(allocator);
    errdefer arena.deinit();
    const a = arena.allocator();
    var parser = try Parser.initDialect(a, try a.dupe(u8, sql), null, false, dialect);
    const explain = try parser.takeWord("EXPLAIN");
    const result: Statement = blk: {
        if (try parser.takeWord("CREATE")) {
            if (try parser.takeWord("CONNECTION")) {
                if (explain) return error.UnsupportedSourceStatement;
                const name = try Name.init(try parser.name());
                try parser.requireWord("TO");
                if (!try parser.takeWord("HTTP")) return error.UnsupportedSourceConnector;
                try parser.require(.left);
                const option = try parser.name();
                if (!std.mem.eql(u8, option, "endpoint")) return error.InvalidSourceOption;
                try parser.require(.eq);
                const endpoint = try string(&parser);
                try s.validateEndpoint(endpoint);
                try parser.require(.right);
                break :blk .{ .connection = .{ .name = name, .endpoint = endpoint } };
            }
            if (try parser.takeWord("SOURCE")) {
                const name = try Name.init(try parser.name());
                try parser.requireWord("FROM");
                if (!try parser.takeWord("HTTP")) return error.UnsupportedSourceConnector;
                try parser.requireWord("CONNECTION");
                const connection = try Name.init(try parser.name());
                try parser.requireWord("INTO");
                try parser.requireWord("STREAM");
                const destination = try Name.init(try parser.name());
                try parser.requireWord("WITH");
                const value: Create = .{ .name = name, .connection = connection, .destination = destination, .http = try http(&parser) };
                break :blk if (explain) .{ .explain = value } else .{ .create = value };
            }
            if (try parser.takeWord("SINK")) {
                const name = try Name.init(try parser.name());
                try parser.requireWord("INTO");
                if (!try parser.takeWord("HTTP")) return error.UnsupportedSourceConnector;
                try parser.requireWord("CONNECTION");
                const connection = try Name.init(try parser.name());
                try parser.requireWord("WITH");
                const value: Sink = .{ .name = name, .connection = connection, .http = try sink(&parser) };
                break :blk if (explain) .{ .explain_sink = value } else .{ .sink = value };
            }
        } else if (parser.token.tag == .word and controls.get(parser.token.text) != null) {
            if (explain) return error.UnsupportedSourceStatement;
            const command = controls.get(parser.token.text).?;
            try parser.advance();
            if (try parser.takeWord("SOURCE")) break :blk .{ .control = .{ .name = try Name.init(try parser.name()), .kind = .source, .command = command, .executor_role = null } };
            if (try parser.takeWord("SINK")) {
                const name = try Name.init(try parser.name());
                const selected = if (command == .authorize) role: {
                    try parser.requireWord("AS");
                    try parser.requireWord("ROLE");
                    break :role try f.AuthorizationSql.role(&parser, false);
                } else null;
                break :blk .{ .control = .{ .name = name, .kind = .sink, .command = command, .executor_role = selected } };
            }
        } else if (try parser.takeWord("DROP")) {
            if (explain) return error.UnsupportedSourceStatement;
            if (try parser.takeWord("SOURCE")) break :blk .{ .drop = .{ .name = try Name.init(try parser.name()), .kind = .source } };
            if (try parser.takeWord("CONNECTION")) break :blk .{ .drop = .{ .name = try Name.init(try parser.name()), .kind = .connection } };
            if (try parser.takeWord("SINK")) break :blk .{ .drop = .{ .name = try Name.init(try parser.name()), .kind = .sink } };
        } else if (try parser.takeWord("SHOW")) {
            if (explain) return error.UnsupportedSourceStatement;
            if (try parser.takeWord("CONNECTIONS")) break :blk .{ .inspect = .{ .name = null, .describe = false, .kind = .connection } };
            if (try parser.takeWord("CONNECTION")) break :blk .{ .inspect = .{ .name = try Name.init(try parser.name()), .describe = false, .kind = .connection } };
            if (try parser.takeWord("SOURCES")) break :blk .{ .inspect = .{ .name = null, .describe = false, .kind = .source } };
            if (try parser.takeWord("SOURCE")) break :blk .{ .inspect = .{ .name = try Name.init(try parser.name()), .describe = false, .kind = .source } };
            if (try parser.takeWord("SINKS")) break :blk .{ .inspect = .{ .name = null, .describe = false, .kind = .sink } };
            if (try parser.takeWord("SINK")) break :blk .{ .inspect = .{ .name = try Name.init(try parser.name()), .describe = false, .kind = .sink } };
        } else if (try parser.takeWord("DESCRIBE")) {
            if (explain) return error.UnsupportedSourceStatement;
            if (try parser.takeWord("CONNECTION")) break :blk .{ .inspect = .{ .name = try Name.init(try parser.name()), .describe = true, .kind = .connection } };
            if (try parser.takeWord("SOURCE")) break :blk .{ .inspect = .{ .name = try Name.init(try parser.name()), .describe = true, .kind = .source } };
            if (try parser.takeWord("SINK")) break :blk .{ .inspect = .{ .name = try Name.init(try parser.name()), .describe = true, .kind = .sink } };
        }
        arena.deinit();
        return null;
    };
    if (result == .drop) _ = try parser.takeWord("RESTRICT");
    try parser.finish();
    return .{ .arena = arena, .statement = result };
}

fn string(parser: *Parser) ![]const u8 {
    const value = try parser.literal(null);
    if (value.value != .string) return error.InvalidSourceOption;
    return value.value.string;
}

fn duration(parser: *Parser) !u64 {
    const text = try string(parser);
    var end: usize = 0;
    while (end < text.len and std.ascii.isDigit(text[end])) : (end += 1) {}
    const multiplier = f.PerfectHash.ComptimeMap(u64, true, .{ .{ "ms", 1 }, .{ "s", 1000 }, .{ "m", 60000 }, .{ "h", 3600000 }, .{ "d", 86400000 } }).get(text[end..]) orelse return error.InvalidSourceDuration;
    const n = std.fmt.parseInt(u64, text[0..end], 10) catch return error.InvalidSourceDuration;
    if (n == 0) return error.InvalidSourceDuration;
    return std.math.mul(u64, n, multiplier) catch error.InvalidSourceDuration;
}

fn http(parser: *Parser) !s.Http {
    try parser.require(.left);
    var seen: std.EnumSet(Option) = .empty;
    var result: s.Http = undefined;
    while (true) {
        const option = options.get(try parser.name()) orelse return error.InvalidSourceOption;
        if (seen.contains(option)) return error.DuplicateSourceOption;
        seen.insert(option);
        try parser.require(.eq);
        switch (option) {
            .method => {
                if (!std.mem.eql(u8, try string(parser), "GET")) return error.UnsupportedSourceMethod;
                result.method = .GET;
            },
            .path => result.path = try string(parser),
            .poll_interval => result.poll_interval_ms = try duration(parser),
            .request_timeout => result.request_timeout_ms = try duration(parser),
            .response_max_bytes => {
                if (parser.token.tag != .integer) return error.InvalidSourceOption;
                result.response_max_bytes = std.fmt.parseInt(u64, parser.token.text, 10) catch return error.InvalidSourceOption;
                try parser.advance();
            },
        }
        if (!try parser.take(.comma)) break;
    }
    try parser.require(.right);
    if (seen.count() != std.EnumSet(Option).len) return error.MissingSourceOption;
    try result.validate();
    return result;
}

const SinkOption = enum { method, path, request_encoding, accept, user_agent, response, capture, request_timeout, response_max_bytes, follow_redirects, max_attempts, unknown_outcome };
fn choice(comptime T: type, parser: *Parser) !T {
    return std.meta.stringToEnum(T, try string(parser)) orelse error.InvalidSourceOption;
}
fn unsigned(comptime T: type, parser: *Parser) !T {
    if (parser.token.tag != .integer) return error.InvalidSourceOption;
    const value = std.fmt.parseInt(T, parser.token.text, 10) catch return error.InvalidSourceOption;
    try parser.advance();
    return value;
}
fn sink(parser: *Parser) !s.Sink {
    try parser.require(.left);
    var seen: std.EnumSet(SinkOption) = .empty;
    var result: s.Sink = undefined;
    result.user_agent = null;
    result.request_encoding = .none;
    while (true) {
        const option = std.meta.stringToEnum(SinkOption, try parser.name()) orelse return error.InvalidSourceOption;
        if (seen.contains(option)) return error.DuplicateSourceOption;
        seen.insert(option);
        try parser.require(.eq);
        switch (option) {
            .method => result.method = try choice(@FieldType(s.Sink, "method"), parser),
            .path => result.path = try string(parser),
            .request_encoding => result.request_encoding = try choice(@FieldType(s.Sink, "request_encoding"), parser),
            .accept => result.accept = try string(parser),
            .user_agent => result.user_agent = try string(parser),
            .response => result.response = try choice(@FieldType(s.Sink, "response"), parser),
            .capture => result.capture = try choice(@FieldType(s.Sink, "capture"), parser),
            .request_timeout => result.request_timeout_ms = try duration(parser),
            .response_max_bytes => result.response_max_bytes = try unsigned(u64, parser),
            .follow_redirects => {
                const literal = try parser.literal(null);
                if (literal.value != .boolean) return error.InvalidSourceOption;
                result.follow_redirects = literal.value.boolean;
            },
            .max_attempts => result.max_attempts = try unsigned(u8, parser),
            .unknown_outcome => result.unknown_outcome = try choice(@FieldType(s.Sink, "unknown_outcome"), parser),
        }
        if (!try parser.take(.comma)) break;
    }
    try parser.require(.right);
    for (std.enums.values(SinkOption)) |option| {
        if (option != .user_agent and option != .request_encoding and !seen.contains(option))
            return error.MissingSourceOption;
    }
    try result.validate();
    return result;
}

const example = "CREATE SOURCE quake_feed FROM HTTP CONNECTION usgs INTO STREAM quake_captures WITH (method='GET', path='/earthquakes/feed/v1.0/summary/all_day.geojson', poll_interval='5m', request_timeout='10s', response_max_bytes=4194304)";
const sink_options = "method='POST', path='/login/oauth/access_token', request_encoding='form', accept='application/json', response='protected_json', capture='redacted_metadata', request_timeout='5s', response_max_bytes=65536, follow_redirects=FALSE, max_attempts=1, unknown_outcome='retain'";
const sink_example = "CREATE SINK github_token INTO HTTP CONNECTION github_oauth WITH (" ++ sink_options ++ ")";

test "source SQL binds exact application sink profiles without source destination or executor" {
    const t = std.testing;
    var token = (try parse(t.allocator, sink_example, .transit)).?;
    defer token.deinit();
    try t.expectEqualStrings("github_token", token.statement.sink.name.slice());
    try t.expectEqualStrings("github_oauth", token.statement.sink.connection.slice());
    try t.expectEqual(.POST, token.statement.sink.http.method);
    try t.expectEqual(.form, token.statement.sink.http.request_encoding);
    try t.expectEqual(5000, token.statement.sink.http.request_timeout_ms);
    try t.expectEqual(65536, token.statement.sink.http.response_max_bytes);
    try t.expectEqual(null, token.statement.sink.http.user_agent);
    var profile = (try parse(t.allocator, "CREATE SINK github_profile INTO HTTP CONNECTION github_api WITH (method='GET', path='/user', accept='application/vnd.github+json', user_agent='Spoke', response='protected_json', capture='redacted_metadata', request_timeout='5s', response_max_bytes=65536, follow_redirects=FALSE, max_attempts=1, unknown_outcome='retain')", .transit)).?;
    defer profile.deinit();
    try t.expectEqual(.none, profile.statement.sink.http.request_encoding);
    try t.expectEqualStrings("Spoke", profile.statement.sink.http.user_agent.?);
    var explain = (try parse(t.allocator, "EXPLAIN " ++ sink_example, .transit)).?;
    defer explain.deinit();
    try t.expectEqualDeep(token.statement.sink, explain.statement.explain_sink);
    for ([_][]const u8{ "SHOW SINKS", "SHOW SINK github_token", "DESCRIBE SINK github_token" }) |sql| {
        var prepared = (try parse(t.allocator, sql, .transit)).?;
        defer prepared.deinit();
        try t.expectEqual(.sink, prepared.statement.inspect.kind);
    }
    var retire = (try parse(t.allocator, "RETIRE SINK github_token", .transit)).?;
    defer retire.deinit();
    try t.expectEqual(.sink, retire.statement.control.kind);
    try t.expectEqual(.retire, retire.statement.control.command);
    var drop = (try parse(t.allocator, "DROP SINK github_token RESTRICT", .transit)).?;
    defer drop.deinit();
    try t.expectEqual(.sink, drop.statement.drop.kind);
}

test "sink authorization uses explicit shared SQL role selection" {
    const t = std.testing;
    var named = (try parse(t.allocator, "AUTHORIZE SINK github_token AS ROLE \"Signin Effects\"", .transit)).?;
    defer named.deinit();
    try t.expectEqualStrings("Signin Effects", named.statement.control.executor_role.?.named);
    var current = (try parse(t.allocator, "AUTHORIZE SINK github_token AS ROLE CURRENT_ROLE", .transit)).?;
    defer current.deinit();
    try t.expectEqual(.current_role, current.statement.control.executor_role.?);
    for ([_][]const u8{ "ACTIVATE", "SUSPEND", "RESUME", "RETIRE" }) |verb| {
        const sql = try std.fmt.allocPrint(t.allocator, "{s} SINK github_token", .{verb});
        defer t.allocator.free(sql);
        var selected = (try parse(t.allocator, sql, .transit)).?;
        defer selected.deinit();
        try t.expectEqual(.sink, selected.statement.control.kind);
        try t.expectEqual(null, selected.statement.control.executor_role);
    }
    try t.expectError(error.InvalidSqlSyntax, parse(t.allocator, "AUTHORIZE SINK github_token", .transit));
    try t.expectError(error.InvalidSqlRole, parse(t.allocator, "AUTHORIZE SINK github_token AS ROLE PUBLIC", .transit));
    try t.expectError(error.UnsupportedConstruct, parse(t.allocator, "RESUME SINK github_token AS ROLE other", .transit));
}

test "source SQL refuses unsafe or ambiguous application sink options" {
    const t = std.testing;
    const prefix = "CREATE SINK token INTO HTTP CONNECTION upstream WITH (";
    try t.expectError(error.MissingSourceOption, parse(t.allocator, prefix ++ "method='GET')", .transit));
    try t.expectError(error.DuplicateSourceOption, parse(t.allocator, prefix ++ sink_options ++ ", path='/replacement')", .transit));
    try t.expectError(error.InvalidSourceOption, parse(t.allocator, prefix ++ "follow_redirects='false')", .transit));
    try t.expectError(error.InvalidSourceOption, parse(t.allocator, prefix ++ "response='json')", .transit));
    try t.expectError(error.InvalidSourceOption, parse(t.allocator, prefix ++ "capture='body')", .transit));
    try t.expectError(error.InvalidSourceOption, parse(t.allocator, prefix ++ "max_attempts=256)", .transit));
    try t.expectError(error.InvalidSourceOption, parse(t.allocator, prefix ++ "unknown_outcome='retry')", .transit));
    try t.expectError(error.UnsupportedSourceConnector, parse(t.allocator, "CREATE SINK token INTO GRPC CONNECTION upstream WITH ()", .transit));
    inline for (.{ .{ "follow_redirects=FALSE", "follow_redirects=TRUE", error.InvalidSinkRetryPolicy }, .{ "max_attempts=1", "max_attempts=2", error.InvalidSinkRetryPolicy }, .{ "request_encoding='form'", "request_encoding='none'", error.InvalidSinkEncoding }, .{ "response_max_bytes=65536", "response_max_bytes=65537", error.InvalidSinkBudget } }) |case| {
        const sql = try std.mem.replaceOwned(u8, t.allocator, sink_example, case[0], case[1]);
        defer t.allocator.free(sql);
        try t.expectError(case[2], parse(t.allocator, sql, .transit));
    }
}

test "explicit source parses typed options and retains owned names" {
    const t = std.testing;
    var parsed = (try parse(t.allocator, example, .transit)).?;
    defer parsed.deinit();
    const create = parsed.statement.create;
    try t.expectEqualStrings("quake_captures", create.destination.slice());
    try t.expectEqualStrings("usgs", create.connection.slice());
    try t.expectEqual(@as(u64, 300000), create.http.poll_interval_ms);
    try t.expectEqual(@as(u64, 10000), create.http.request_timeout_ms);
    try t.expectEqual(@as(u64, 4194304), create.http.response_max_bytes);
    var conn = (try parse(t.allocator, "CREATE CONNECTION usgs TO HTTP (endpoint='https://earthquake.usgs.gov')", .transit)).?;
    defer conn.deinit();
    try t.expectEqualStrings("https://earthquake.usgs.gov", conn.statement.connection.endpoint);
    var control = (try parse(t.allocator, "SUSPEND SOURCE \"Quake Feed\";", .transit)).?;
    defer control.deinit();
    try t.expectEqualStrings("Quake Feed", control.statement.control.name.slice());
    try t.expectEqual(s.Command.suspend_source, control.statement.control.command);
    try t.expect(try parse(t.allocator, "ACTIVATE DATAFLOW computation", .transit) == null);
    var explain = (try parse(t.allocator, "EXPLAIN " ++ example, .transit)).?;
    defer explain.deinit();
    try t.expectEqualStrings(create.http.path, explain.statement.explain.http.path);
    var show = (try parse(t.allocator, "SHOW SOURCES", .transit)).?;
    defer show.deinit();
    try t.expectEqual(@as(?Name, null), show.statement.inspect.name);
    var describe = (try parse(t.allocator, "DESCRIBE SOURCE q", .transit)).?;
    defer describe.deinit();
    try t.expect(describe.statement.inspect.describe);
}

test "source rejects old destination options and malformed budgets before binding" {
    const t = std.testing;
    try t.expectError(error.InvalidSqlSyntax, parse(t.allocator, "CREATE SOURCE q FROM HTTP CONNECTION usgs WITH (capture_stream='raw')", .transit));
    const prefix = "CREATE SOURCE q FROM HTTP CONNECTION usgs INTO STREAM raw WITH (";
    try t.expectError(error.InvalidSourceOption, parse(t.allocator, prefix ++ "capture_stream='raw')", .transit));
    try t.expectError(error.MissingSourceOption, parse(t.allocator, prefix ++ "method='GET')", .transit));
    try t.expectError(error.DuplicateSourceOption, parse(t.allocator, prefix ++ "method='GET', method='GET')", .transit));
    try t.expectError(error.InvalidSourceOption, parse(t.allocator, prefix ++ "response_max_bytes='4194304')", .transit));
    try t.expectError(error.InvalidSourceDuration, parse(t.allocator, prefix ++ "poll_interval='18446744073709551615d')", .transit));
    try t.expectError(error.InvalidSourceDuration, parse(t.allocator, prefix ++ "poll_interval='0s')", .transit));
    try t.expectError(error.UnsupportedSourceMethod, parse(t.allocator, prefix ++ "method='POST')", .transit));
    try t.expectError(error.UnsupportedSourceConnector, parse(t.allocator, "CREATE SOURCE q FROM GRPC CONNECTION api INTO STREAM raw WITH (method='GET')", .transit));
    try t.expectError(error.UnsupportedConstruct, parse(t.allocator, "ACTIVATE SOURCE q trailing", .transit));
    try t.expectError(error.InvalidSourceOption, parse(t.allocator, prefix ++ "request_timeout=10)", .transit));
    try t.expectError(error.InvalidSourceBudget, parse(t.allocator, prefix ++ "method='GET', path='/feed', poll_interval='1s', request_timeout='1s', response_max_bytes=0)", .transit));
    try t.expectError(error.InvalidSourcePath, parse(t.allocator, prefix ++ "method='GET', path='//other/feed', poll_interval='1s', request_timeout='1s', response_max_bytes=1)", .transit));
    try t.expectError(error.InvalidSqlSyntax, parse(t.allocator, "CREATE CONNECTION api TO HTTP (endpoint='https://example.test', endpoint='https://other.test')", .transit));
}

test "source metadata includes connections and DROP accepts only RESTRICT" {
    const t = std.testing;
    for ([_][]const u8{ "SHOW CONNECTIONS", "SHOW CONNECTION upstream", "DESCRIBE CONNECTION upstream" }) |sql| {
        var prepared = (try parse(t.allocator, sql, .transit)).?;
        defer prepared.deinit();
        try t.expectEqual(.connection, prepared.statement.inspect.kind);
    }
    for ([_][]const u8{ "DROP SOURCE feed RESTRICT", "DROP CONNECTION upstream RESTRICT", "DROP SOURCE feed" }) |sql| {
        var prepared = (try parse(t.allocator, sql, .transit)).?;
        defer prepared.deinit();
        try t.expectEqual(.drop, std.meta.activeTag(prepared.statement));
    }
    try t.expectError(error.UnsupportedConstruct, parse(t.allocator, "DROP SOURCE feed CASCADE", .transit));
}
