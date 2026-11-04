//! Shared bounded interactive read host. Presentation adapters serialize access;
//! source sessions, statement admission and results belong to the SQL client.
const std = @import("std");
const s = @import("root.zig");
const p = s.protocol;
const Diagnostic = s.results.protocol.Diagnostic;
const Self = @This();
pub const capacity = 4;
pub const lifetime_ms = 300000;
pub const max_request_bytes = 65536;
pub const Request = struct {
    definition: p.native.Definition,
    action: union(enum) {
        describe,
        run: struct { id: []const u8, sql: []const u8, expected_definition: ?[]const u8 = null },
        observe: []const u8,
        next: struct { id: []const u8, after: []const u8 },
        close: []const u8,
    },
};
pub const Response = union(enum) {
    description: struct { definition: p.native.Definition = p.native.current_definition, database: []const u8, source: ?[]const u8, readers: u8 = capacity, window_rows: u16 = s.ReadView.max_rows, window_bytes: u32 = s.ReadView.max_value_bytes, lifetime_ms: u32 = lifetime_ms },
    result: struct { id: []const u8, view: s.ReadView.View },
    closed,
};
allocator: std.mem.Allocator,
io: std.Io,
config: s.Client.Config,
slots: [capacity]?*Reader = @splat(null),
/// Owned evidence for the last apply call, surviving the failed reader's arena.
/// This is an observation, never permission to resubmit the statement.
rejection: ?struct { code: Diagnostic.Code, sqlstate: [5]u8, diagnostic: ?Diagnostic } = null,
pub fn deinit(self: *Self) void {
    for (&self.slots) |*slot| if (slot.*) |reader| {
        reader.destroy();
        slot.* = null;
    };
}
fn expire(self: *Self) void {
    const now = std.Io.Clock.awake.now(self.io);
    for (&self.slots) |*slot| if (slot.*) |reader| {
        if (reader.opened.durationTo(now).toMilliseconds() >= lifetime_ms) {
            reader.destroy();
            slot.* = null;
        }
    };
}
fn find(self: *Self, id: []const u8) !**Reader {
    for (&self.slots) |*slot| if (slot.*) |*reader| {
        if (std.mem.eql(u8, &reader.*.id, id)) return reader;
    };
    return error.ReadWorkspaceExpired;
}
fn validId(id: []const u8) !void {
    if (id.len != 32) return error.InvalidReadIdentity;
    for (id) |char| if (!std.ascii.isDigit(char) and !(char >= 'a' and char <= 'f')) return error.InvalidReadIdentity;
}
pub fn apply(self: *Self, allocator: std.mem.Allocator, request: Request) !Response {
    self.rejection = null;
    if (request.definition != p.native.current_definition) return error.IncompatibleSqlDefinition;
    self.expire();
    if (request.action == .describe) return .{ .description = .{ .database = self.config.database, .source = self.config.source } };
    const id = switch (request.action) {
        .describe => unreachable,
        .run => |v| v.id,
        .observe, .close => |v| v,
        .next => |v| v.id,
    };
    try validId(id);
    if (request.action == .close) {
        for (&self.slots) |*slot| if (slot.*) |reader| {
            if (std.mem.eql(u8, &reader.id, id)) {
                reader.destroy();
                slot.* = null;
            }
        };
        return .closed;
    }
    if (request.action == .run) {
        const input = request.action.run;
        if (input.sql.len == 0 or input.sql.len > 60000) return error.InvalidReadStatement;
        if (self.find(id)) |existing| {
            if (!std.mem.eql(u8, existing.*.sql, input.sql) or !optionalEqual(existing.*.expected, input.expected_definition)) return error.ReadIdentityConflict;
        } else |_| {
            const slot = for (&self.slots) |*slot| {
                if (slot.* == null) break slot;
            } else return error.ReadWorkspaceCapacity;
            slot.* = try Reader.create(self, id, input.sql, input.expected_definition);
        }
    }
    const reader = (try self.find(id)).*;
    // Once advancement has failed, an earlier window cannot become an answer
    // to the new request. Explicit closure is still available.
    if (reader.failed) return error.ReadWorkspaceIncomplete;
    errdefer reader.failed = true;
    if (request.action == .next) {
        const after = std.fmt.parseInt(u64, request.action.next.after, 10) catch return error.InvalidReadPosition;
        const result = &reader.view.outcome.value.rows;
        if (after == result.progress.delivered) try reader.view.advance() else if (after != reader.view.start) return error.InvalidReadPosition;
    }
    return .{ .result = .{ .id = &reader.id, .view = try reader.view.inspect(allocator) } };
}
const Reader = struct {
    allocator: std.mem.Allocator,
    opened: std.Io.Timestamp,
    id: [32]u8,
    sql: []const u8,
    expected: ?[]const u8,
    session: *s.ReadSession,
    view: s.ReadView,
    failed: bool = false,
    fn create(host: *Self, id: []const u8, sql: []const u8, expected: ?[]const u8) !*Reader {
        const self = try host.allocator.create(Reader);
        errdefer host.allocator.destroy(self);
        const statement = try host.allocator.dupe(u8, sql);
        errdefer host.allocator.free(statement);
        const expected_copy = if (expected) |value| try host.allocator.dupe(u8, value) else null;
        errdefer if (expected_copy) |value| host.allocator.free(value);
        self.* = .{ .allocator = host.allocator, .opened = std.Io.Clock.awake.now(host.io), .id = id[0..32].*, .sql = statement, .expected = expected_copy, .session = try s.ReadSession.open(host.allocator, host.io, host.config), .view = undefined };
        errdefer self.session.close();
        const outcome = try self.session.executor.read(sql, .{});
        errdefer outcome.deinit();
        if (outcome.value == .failure) {
            const failure = outcome.value.failure;
            const code: ?Diagnostic.Code = Diagnostic.Code.init(failure.code) catch null;
            if (code) |value| host.rejection = .{ .code = value, .sqlstate = failure.sqlstate, .diagnostic = failure.diagnostic };
            return if (failure.denied()) error.SqlObservationDenied else error.SqlReadRejected;
        }
        if (expected) |definition| {
            if (outcome.value != .rows or outcome.value.rows.observation != .data or outcome.value.rows.observation.data != .table) return error.ReadSourceChanged;
            const actual = try p.Json.valueAlloc(host.allocator, outcome.value.rows.observation.data.table.interpretation);
            defer host.allocator.free(actual);
            if (!std.mem.eql(u8, actual, definition)) return error.ReadSourceChanged;
        }
        try self.view.init(host.allocator, outcome);
        errdefer self.view.arena.deinit();
        try self.view.advance();
        return self;
    }
    fn destroy(self: *Reader) void {
        self.view.deinit();
        self.session.close();
        self.allocator.free(self.sql);
        if (self.expected) |value| self.allocator.free(value);
        self.allocator.destroy(self);
    }
};
fn optionalEqual(a: ?[]const u8, b: ?[]const u8) bool {
    if (a) |value| return if (b) |other| std.mem.eql(u8, value, other) else false;
    return b == null;
}
