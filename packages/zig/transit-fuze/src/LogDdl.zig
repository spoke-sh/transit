//! Pure Stream/Queue declaration syntax and policy binding. Catalog identities,
//! destination resolution, authorization and admission belong to the caller.
const std = @import("std");
const p = @import("transit_protocol");
const q = p.StreamQueueDeclaration;
const Sql = @import("Sql.zig");
const Parser = @import("SqlTyped.zig");
const TableDdl = @import("TableDdl.zig");
const Schema = @import("TableSchema.zig");
const PerfectHash = @import("PerfectHash.zig");

pub const default_limits: q.Limits = .{ .append_rows = 128, .append_bytes = 1024 * 1024, .claim_rows = 16, .read_rows = 128, .read_bytes = 1024 * 1024, .active_leases = 64, .waiters = 64, .timer_steps = 64 };
pub fn defaults(kind: q.Kind) q.Configuration {
    return .{ .partitioning = .{ .count = 1, .key_column = null, .hash = .sha256_64 }, .retention = .{ .max_age_ms = null }, .policy = switch (kind) {
        .stream => .{ .stream = .{ .compact_key_column = null, .timestamp_column = null } },
        .queue => .{ .queue = .{ .ordering = .unordered, .key_column = null, .lease_ms = 30000, .maximum_lease_ms = 30000, .maximum_attempts = 5, .backoff = .{ .initial_ms = 1000, .maximum_ms = 60000, .multiplier = 2 }, .dead_letter = null } },
    } };
}
const Tag = enum { retention, compaction, timestamp_column, key_column, mode, lease_duration, max_lease_duration, max_attempts, backoff_initial, backoff_maximum, backoff_multiplier, dead_letter_queue, append_rows, append_bytes, claim_rows, read_rows, read_bytes, active_leases, waiters, timer_steps };
const Options = PerfectHash.ComptimeMap(Tag, true, .{
    .{ "retention", .retention },             .{ "compaction", .compaction },           .{ "timestamp_column", .timestamp_column },     .{ "key_column", .key_column },
    .{ "mode", .mode },                       .{ "lease_duration", .lease_duration },   .{ "max_lease_duration", .max_lease_duration }, .{ "max_attempts", .max_attempts },
    .{ "backoff_initial", .backoff_initial }, .{ "backoff_maximum", .backoff_maximum }, .{ "backoff_multiplier", .backoff_multiplier }, .{ "dead_letter_queue", .dead_letter_queue },
    .{ "append_rows", .append_rows },         .{ "append_bytes", .append_bytes },       .{ "claim_rows", .claim_rows },                 .{ "read_rows", .read_rows },
    .{ "read_bytes", .read_bytes },           .{ "active_leases", .active_leases },     .{ "waiters", .waiters },                       .{ "timer_steps", .timer_steps },
});
const Option = struct { tag: Tag, value: Parser.Literal };
pub const Basis = struct { schema: Schema.Schema, configuration: q.Configuration, limits: q.Limits };
pub const Configured = struct { configuration: q.Configuration, limits: q.Limits, destination: union(enum) { unchanged, clear, name: []const u8 } = .unchanged };
pub const Statement = struct {
    kind: q.Kind,
    name: []const u8,
    action: union(enum) { create: TableDdl.Create, alter, rename: []const u8, drop },
    partition: ?struct { count: u32, key: ?[]const u8 } = null,
    options: []const Option = &.{},

    /// Bind column names to stable IDs and apply only explicitly supplied policy
    /// changes. The Catalog resolves a named destination to an exact definition.
    pub fn configure(self: Statement, basis: ?Basis, schema: Schema.Schema) !Configured {
        if (self.action != .create and self.action != .alter) return error.UnsupportedStatement;
        if ((self.action == .create) != (basis == null)) return error.InvalidLogCatalogIntent;
        if (schema.primary_key.len != 0) return error.UnsupportedLogPrimaryKey;
        var result: Configured = if (basis) |value| .{ .configuration = value.configuration, .limits = value.limits } else .{ .configuration = defaults(self.kind), .limits = default_limits };
        const config = &result.configuration;
        if (std.meta.activeTag(config.policy) != self.kind) return error.CatalogKindMismatch;
        if (self.partition) |partition| config.partitioning = .{ .count = partition.count, .key_column = if (partition.key) |name| try column(schema, name, true) else null, .hash = .sha256_64 };
        var key: ?u64 = null;
        var key_supplied = false;
        var compact: ?bool = null;
        for (self.options) |option| {
            const value = option.value;
            switch (option.tag) {
                .retention => config.retention.max_age_ms = if (value.value == .null or (value.value == .string and std.ascii.eqlIgnoreCase(value.value.string, "unlimited"))) null else try duration(try string(value)),
                .key_column => {
                    key = try column(schema, try string(value), true);
                    key_supplied = true;
                },
                .compaction => {
                    if (self.kind != .stream) return error.UnsupportedLogOption;
                    const text = try string(value);
                    compact = if (std.ascii.eqlIgnoreCase(text, "none")) false else if (std.ascii.eqlIgnoreCase(text, "key")) true else return error.UnsupportedLogOption;
                },
                .timestamp_column => {
                    if (self.kind != .stream) return error.UnsupportedLogOption;
                    const id = try column(schema, try string(value), false);
                    const found = schema.columns[try schema.index(id)];
                    if (found.nullable or found.type != .timestamp or found.type.timestamp != .utc) return error.InvalidStreamTimestampColumn;
                    config.policy.stream.timestamp_column = id;
                },
                .mode => {
                    if (self.kind != .queue) return error.UnsupportedLogOption;
                    const text = try string(value);
                    config.policy.queue.ordering = if (std.ascii.eqlIgnoreCase(text, "competing")) .unordered else if (std.ascii.eqlIgnoreCase(text, "key_fifo")) .key_fifo else return error.UnsupportedLogOption;
                },
                .lease_duration, .max_lease_duration, .backoff_initial, .backoff_maximum => {
                    if (self.kind != .queue) return error.UnsupportedLogOption;
                    const ms = try duration(try string(value));
                    switch (option.tag) {
                        .lease_duration => config.policy.queue.lease_ms = ms,
                        .max_lease_duration => config.policy.queue.maximum_lease_ms = ms,
                        .backoff_initial => config.policy.queue.backoff.initial_ms = ms,
                        .backoff_maximum => config.policy.queue.backoff.maximum_ms = ms,
                        else => unreachable,
                    }
                },
                .max_attempts, .backoff_multiplier => {
                    if (self.kind != .queue) return error.UnsupportedLogOption;
                    const n = try integer(value);
                    if (option.tag == .max_attempts) config.policy.queue.maximum_attempts = std.math.cast(u32, n) orelse return error.InvalidLogOption else config.policy.queue.backoff.multiplier = std.math.cast(u16, n) orelse return error.InvalidLogOption;
                },
                .dead_letter_queue => {
                    if (self.kind != .queue) return error.UnsupportedLogOption;
                    result.destination = if (value.value == .null) .clear else .{ .name = try string(value) };
                },
                inline .append_rows, .append_bytes, .claim_rows, .read_rows, .read_bytes, .active_leases, .waiters, .timer_steps => |tag| @field(result.limits, @tagName(tag)) = std.math.cast(u32, try integer(value)) orelse return error.InvalidLogOption,
            }
        }
        if (self.kind == .queue) {
            if (config.policy.queue.ordering == .key_fifo) {
                config.policy.queue.key_column = key orelse config.policy.queue.key_column orelse config.partitioning.key_column orelse return error.InvalidQueuePolicy;
            } else if (key_supplied) return error.InvalidQueuePolicy else config.policy.queue.key_column = null;
        } else {
            const enabled = compact orelse (config.policy.stream.compact_key_column != null);
            if (enabled) config.policy.stream.compact_key_column = key orelse config.policy.stream.compact_key_column orelse config.partitioning.key_column orelse return error.InvalidStreamPolicy else if (key_supplied) return error.InvalidStreamPolicy else config.policy.stream.compact_key_column = null;
        }
        try config.validate();
        try result.limits.validate();
        if (basis) |value| try value.configuration.requireEvolution(config.*);
        return result;
    }
};
pub const Owned = struct {
    arena: std.heap.ArenaAllocator,
    statement: Statement,
    pub fn deinit(self: *Owned) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

pub const Inspection = struct { kind: q.Kind, name: []const u8, describe: bool };

/// Pure named-log inspection syntax. The name belongs to the parser allocator;
/// definition lookup and current disclosure authority remain with the service.
pub fn inspection(parser: Parser) !?Inspection {
    var header = parser;
    const show = try header.takeWord("SHOW");
    const describe = if (!show) try header.takeWord("DESCRIBE") else false;
    if (!show and !describe) return null;
    const kind: q.Kind = if (try header.takeWord("STREAM")) .stream else if (try header.takeWord("QUEUE")) .queue else return null;
    // DESCRIBE stream/queue can still name a Table with that contextual name.
    if (header.token.tag == .eof or header.token.tag == .semi) return null;
    const name = try header.named(.source);
    try header.finish();
    return .{ .kind = kind, .name = name, .describe = describe };
}

test "log inspection preserves contextual Table names and the selected dialect" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    for ([_][]const u8{ "DESCRIBE stream", "DESCRIBE queue;", "SHOW STREAMS", "SELECT id FROM items" }) |text| {
        const parser = try Parser.init(arena.allocator(), text, null);
        try std.testing.expect(try inspection(parser) == null);
    }
    const parser = try Parser.initDialect(arena.allocator(), "DESCRIBE QUEUE `jobs with spaces`", null, false, .mysql);
    const value = (try inspection(parser)).?;
    try std.testing.expect(value.describe and value.kind == .queue);
    try std.testing.expectEqualStrings("jobs with spaces", value.name);
    const extra = try Parser.init(arena.allocator(), "SHOW STREAM events extra", null);
    try std.testing.expectError(error.UnsupportedConstruct, inspection(extra));
}

pub fn compile(allocator: std.mem.Allocator, text: []const u8, dialect: Sql.Dialect, location: ?*Sql.Location) !Owned {
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    var parser = try Parser.initDialect(arena.allocator(), text, location, false, dialect);
    const verb: enum { create, alter, drop } = if (try parser.takeWord("CREATE")) .create else if (try parser.takeWord("ALTER")) .alter else if (try parser.takeWord("DROP")) .drop else return error.UnsupportedStatement;
    const kind: q.Kind = if (try parser.takeWord("STREAM")) .stream else if (try parser.takeWord("QUEUE")) .queue else return error.UnsupportedStatement;
    if (parser.word("IF")) return error.UnsupportedConstruct;
    const name = try parser.named(if (verb == .create) .proposed else .source);
    var statement: Statement = .{ .kind = kind, .name = name, .action = .drop };
    switch (verb) {
        .create => {
            const shape = try TableDdl.columnDefinitions(&parser, name, false);
            if (shape.primary_key.len != 0) return error.UnsupportedLogPrimaryKey;
            statement.action = .{ .create = shape };
            if (try parser.takeWord("PARTITION")) {
                try parser.requireWord("BY");
                try parser.requireWord("HASH");
                try parser.require(.left);
                const key = try parser.named(.column);
                try parser.require(.right);
                try parser.requireWord("PARTITIONS");
                statement.partition = .{ .count = std.math.cast(u32, try integer(try parser.literal(.int64))) orelse return error.InvalidLogPartitioning, .key = key };
            } else if (try parser.takeWord("PARTITIONS")) statement.partition = .{ .count = std.math.cast(u32, try integer(try parser.literal(.int64))) orelse return error.InvalidLogPartitioning, .key = null };
            if (try parser.takeWord("WITH")) statement.options = try options(&parser);
            _ = try statement.configure(null, try shape.bind(1));
        },
        .alter => {
            if (try parser.takeWord("RENAME")) {
                try parser.requireWord("TO");
                statement.action = .{ .rename = try parser.named(.proposed) };
            } else {
                try parser.requireWord("SET");
                statement.action = .alter;
                statement.options = try options(&parser);
            }
        },
        .drop => {},
    }
    try parser.finish();
    return .{ .arena = arena, .statement = statement };
}
fn options(parser: *Parser) ![]const Option {
    try parser.require(.left);
    var seen: std.EnumSet(Tag) = .empty;
    var values: std.ArrayList(Option) = .empty;
    while (true) {
        if (parser.token.tag != .word) return error.InvalidLogOption;
        const tag = Options.get(parser.token.text) orelse return error.UnsupportedLogOption;
        if (seen.contains(tag)) return error.DuplicateLogOption;
        seen.insert(tag);
        try parser.advance();
        try parser.require(.eq);
        try values.append(parser.allocator, .{ .tag = tag, .value = try parser.literal(null) });
        if (!try parser.take(.comma)) break;
    }
    try parser.require(.right);
    return values.toOwnedSlice(parser.allocator);
}
fn string(value: Parser.Literal) ![]const u8 {
    if (value.value != .string or value.value.string.len == 0) return error.InvalidLogOption;
    return value.value.string;
}
fn integer(value: Parser.Literal) !u64 {
    if (value.value != .number) return error.InvalidLogOption;
    const text = value.value.number;
    for (text) |byte| if (byte < '0' or byte > '9') return error.InvalidLogOption;
    return std.fmt.parseInt(u64, text, 10) catch error.InvalidLogOption;
}
fn duration(text: []const u8) !u64 {
    var end: usize = 0;
    while (end < text.len and std.ascii.isDigit(text[end])) : (end += 1) {}
    const unit = PerfectHash.ComptimeMap(u64, true, .{ .{ "ms", 1 }, .{ "s", 1000 }, .{ "m", 60000 }, .{ "h", 3600000 }, .{ "d", 86400000 } }).get(text[end..]) orelse return error.InvalidLogOption;
    const n = std.fmt.parseInt(u64, text[0..end], 10) catch return error.InvalidLogOption;
    if (n == 0) return error.InvalidLogOption;
    return std.math.mul(u64, n, unit) catch error.InvalidLogOption;
}
fn column(schema: Schema.Schema, name: []const u8, key: bool) !u64 {
    for (schema.columns) |value| if (std.mem.eql(u8, value.name, name)) {
        if (key and (value.nullable or !Schema.keyType(value.type))) return error.InvalidLogKeyColumn;
        return value.id;
    };
    return error.UnknownColumn;
}

test "log DDL binds stream schema partitioning and finite retention" {
    const t = std.testing;
    var plan = try compile(t.allocator, "CREATE STREAM events (tenant TEXT COLLATE ASCII_CI NOT NULL, payload JSON) PARTITION BY HASH (tenant) PARTITIONS 16 WITH (retention = '7d', compaction = 'key', append_rows = 512)", .transit, null);
    defer plan.deinit();
    const schema = try plan.statement.action.create.bind(42);
    const bound = try plan.statement.configure(null, schema);
    try t.expectEqual(@as(u32, 16), bound.configuration.partitioning.count);
    try t.expectEqual(@as(?u64, 1), bound.configuration.policy.stream.compact_key_column);
    try t.expectEqual(@as(?u64, 604800000), bound.configuration.retention.max_age_ms);
    try t.expectEqual(@as(u32, 512), bound.limits.append_rows);
    try t.expectEqual(.ascii_ci, schema.columns[0].collation);
    try t.expectEqual(@as(usize, 0), schema.primary_key.len);
}
test "log DDL queue defaults and explicit FIFO policy retain stable routing" {
    const t = std.testing;
    var plan = try compile(t.allocator, "CREATE QUEUE work (entity BIGINT NOT NULL, payload TEXT) PARTITION BY HASH (entity) PARTITIONS 4 WITH (mode='key_fifo', dead_letter_queue='failed', lease_duration='5s', max_attempts=7)", .transit, null);
    defer plan.deinit();
    const bound = try plan.statement.configure(null, try plan.statement.action.create.bind(9));
    try t.expectEqual(.key_fifo, bound.configuration.policy.queue.ordering);
    try t.expectEqual(@as(?u64, 1), bound.configuration.policy.queue.key_column);
    try t.expectEqual(@as(u64, 5000), bound.configuration.policy.queue.lease_ms);
    try t.expectEqual(@as(u32, 7), bound.configuration.policy.queue.maximum_attempts);
    try t.expectEqualStrings("failed", bound.destination.name);
    try t.expect(bound.configuration.retention.max_age_ms == null);
}
test "log DDL rejects unsupported constraints options and unsafe budgets" {
    const t = std.testing;
    for ([_]struct { text: []const u8, failure: anyerror }{
        .{ .text = "CREATE STREAM s (id BIGINT PRIMARY KEY)", .failure = error.UnsupportedLogPrimaryKey },
        .{ .text = "CREATE STREAM s (id BIGINT) WITH (retention='0s')", .failure = error.InvalidLogOption },
        .{ .text = "CREATE STREAM s (id BIGINT) WITH (retention='1s', RETENTION='2s')", .failure = error.DuplicateLogOption },
        .{ .text = "CREATE STREAM s (id BIGINT) WITH (mode='competing')", .failure = error.UnsupportedLogOption },
        .{ .text = "CREATE STREAM s (id BIGINT) WITH (compaction='key')", .failure = error.InvalidStreamPolicy },
        .{ .text = "CREATE QUEUE q (id BIGINT) WITH (mode='key_fifo', key_column='id')", .failure = error.InvalidLogKeyColumn },
        .{ .text = "CREATE QUEUE q (id BIGINT) WITH (claim_rows=65)", .failure = error.InvalidLogLimits },
        .{ .text = "CREATE QUEUE q (id BIGINT) WITH (claim_rows=4294967296)", .failure = error.InvalidLogOption },
        .{ .text = "CREATE QUEUE q (id BIGINT) WITH (other=1)", .failure = error.UnsupportedLogOption },
        .{ .text = "CREATE STREAM IF NOT EXISTS s (id BIGINT)", .failure = error.UnsupportedConstruct },
        .{ .text = "CREATE STREAM s (id BIGINT); DROP STREAM s", .failure = error.UnsupportedConstruct },
    }) |case| try t.expectError(case.failure, compile(t.allocator, case.text, .transit, null));
}
test "log DDL ALTER retains unspecified policies and rejects routing changes" {
    const t = std.testing;
    var create = try compile(t.allocator, "CREATE QUEUE q (id BIGINT NOT NULL) WITH (mode='key_fifo', key_column='id')", .transit, null);
    defer create.deinit();
    const schema = try create.statement.action.create.bind(1);
    const initial = try create.statement.configure(null, schema);
    const basis: Basis = .{ .schema = schema, .configuration = initial.configuration, .limits = initial.limits };
    var alter = try compile(t.allocator, "ALTER QUEUE q SET (retention='2h', max_attempts=9)", .transit, null);
    defer alter.deinit();
    const changed = try alter.statement.configure(basis, schema);
    try t.expectEqual(.key_fifo, changed.configuration.policy.queue.ordering);
    try t.expectEqual(@as(u32, 9), changed.configuration.policy.queue.maximum_attempts);
    try t.expectEqual(@as(?u64, 7200000), changed.configuration.retention.max_age_ms);
    var invalid = try compile(t.allocator, "ALTER QUEUE q SET (mode='competing')", .transit, null);
    defer invalid.deinit();
    try t.expectError(error.UnsupportedLogKeyChange, invalid.statement.configure(basis, schema));
}
test "log DDL quoted contextual names and rename drop use dedicated syntax" {
    const t = std.testing;
    var create = try compile(t.allocator, "CREATE STREAM \"Queue\" (stream BIGINT)", .transit, null);
    defer create.deinit();
    try t.expectEqualStrings("Queue", create.statement.name);
    var rename = try compile(t.allocator, "ALTER STREAM \"Queue\" RENAME TO events", .transit, null);
    defer rename.deinit();
    try t.expectEqualStrings("events", rename.statement.action.rename);
    var drop = try compile(t.allocator, "DROP QUEUE work", .transit, null);
    defer drop.deinit();
    try t.expectEqual(.queue, drop.statement.kind);
    try t.expect(drop.statement.action == .drop);
}
