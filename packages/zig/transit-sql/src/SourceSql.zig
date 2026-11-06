//! Explicit connector ingestion syntax. Parsing performs no publication or I/O.
const std = @import("std");
const g = @import("root.zig");
const f = g.fuze;
const s = g.catalog.protocol.Source;
const Name = g.catalog.TableAuthority.Name;
const Parser = f.SqlTyped;
pub const Create = struct { name: Name, connection: Name, destination: Name, http: s.Http };
pub const Statement = union(enum) {
    connection: struct { name: Name, endpoint: []const u8 },
    create: Create,
    control: struct { name: Name, command: s.Command },
    drop: struct { name: Name, kind: enum { source, connection } },
    inspect: struct { name: ?Name, describe: bool },
    explain: Create,
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
        } else if (parser.token.tag == .word and controls.get(parser.token.text) != null) {
            if (explain) return error.UnsupportedSourceStatement;
            const command = controls.get(parser.token.text).?;
            try parser.advance();
            if (try parser.takeWord("SOURCE")) break :blk .{ .control = .{ .name = try Name.init(try parser.name()), .command = command } };
        } else if (try parser.takeWord("DROP")) {
            if (explain) return error.UnsupportedSourceStatement;
            if (try parser.takeWord("SOURCE")) break :blk .{ .drop = .{ .name = try Name.init(try parser.name()), .kind = .source } };
            if (try parser.takeWord("CONNECTION")) break :blk .{ .drop = .{ .name = try Name.init(try parser.name()), .kind = .connection } };
        } else if (try parser.takeWord("SHOW")) {
            if (explain) return error.UnsupportedSourceStatement;
            if (try parser.takeWord("SOURCES")) break :blk .{ .inspect = .{ .name = null, .describe = false } };
            if (try parser.takeWord("SOURCE")) break :blk .{ .inspect = .{ .name = try Name.init(try parser.name()), .describe = false } };
        } else if (try parser.takeWord("DESCRIBE")) {
            if (explain) return error.UnsupportedSourceStatement;
            if (try parser.takeWord("SOURCE")) break :blk .{ .inspect = .{ .name = try Name.init(try parser.name()), .describe = true } };
        }
        arena.deinit();
        return null;
    };
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

const example = "CREATE SOURCE quake_feed FROM HTTP CONNECTION usgs INTO STREAM quake_captures WITH (method='GET', path='/earthquakes/feed/v1.0/summary/all_day.geojson', poll_interval='5m', request_timeout='10s', response_max_bytes=4194304)";

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
