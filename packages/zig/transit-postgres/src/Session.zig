//! Authenticated sans-I/O command continuation. Host work and output are values;
//! no runtime callbacks execute here. Input lives through the matching done event.
const std = @import("std");
const pg = @import("root.zig");
const g = pg.wire;
const s = g.Session;
const f = g.fuze;
const Self = @This();
const Name = struct {
    bytes: [g.Limits.max_name_bytes]u8 = undefined,
    len: u8,
    fn init(value: []const u8) !Name {
        if (value.len > g.Limits.max_name_bytes) return error.InvalidWireName;
        var result: Name = .{ .len = @intCast(value.len) };
        @memcpy(result.bytes[0..value.len], value);
        return result;
    }
    fn matches(self: *const Name, value: []const u8) bool {
        return std.mem.eql(u8, self.bytes[0..self.len], value);
    }
};
const Prepared = struct { name: Name, value: s.Prepared, oids: [g.Limits.max_parameters]u32 = undefined, count: u16 };
const Portal = struct {
    name: Name,
    id: u64,
    statement: usize,
    values: s.Values,
    formats: pg.Frontend.Formats,
    read: ?s.Handle = null,
    rows: u64 = 0,
    complete: bool = false,
};
const Release = struct { request: s.Request, binding: ?usize = null };
const Stage = enum {
    idle,
    command,
    admitted,
    dispatch,
    parse_request,
    parsed,
    parse_output,
    bind_validate,
    bind_values,
    bound,
    bind_output,
    describe,
    describe_fields,
    simple_bind,
    simple_describe,
    simple_execute,
    simple_finish,
    execute_validate,
    execute_start,
    written,
    opened,
    pull,
    batch,
    row,
    batch_end,
    execute_finish,
    sync_finish,
    end,
    ready,
    error_request,
    error_output,
    error_finish,
};
pub const Poll = union(enum) { request: s.Event, done: bool };
allocator: std.mem.Allocator,
continuation: s.Continuation,
backend: pg.Backend,
cycle: pg.Cycle,
statements: [64]?Prepared = @splat(null),
portals: [8]?Portal = @splat(null),
bindings: [8]std.heap.ArenaAllocator,
next_portal: u64 = 1,
deferred: ?usize = null,
stage: Stage = .idle,
result: s.Result = .ok,
keep_open: bool = true,
tag: u8 = 0,
payload: []const u8 = "",
message: pg.Frontend.Message = undefined,
valid_sync: bool = false,
handling_error: bool = false,
failure: anyerror = error.InvalidWireCommand,
releases: [72]Release = undefined,
release_count: usize = 0,
releasing: bool = false,
deferred_request: ?s.Request = null,
provisional: ?s.Prepared = null,
parse_input: pg.Frontend.Parse = undefined,
parse_index: usize = 0,
after_parse: Stage = .idle,
bind_input: pg.Frontend.Bind = undefined,
bind_index: usize = 0,
bind_statement: usize = 0,
after_bind: Stage = .idle,
describe_index: usize = 0,
describe_formats: pg.Frontend.Formats = .{},
describe_statement: bool = false,
after_describe: Stage = .idle,
exec_index: usize = 0,
exec_maximum: u32 = 0,
exec_emitted: u32 = 0,
after_execute: Stage = .idle,
batch: g.ReadBatch = .{},
batch_index: usize = 0,
requested: u8 = 0,
transaction: g.results.Transaction.SessionState = .idle,

pub fn init(allocator: std.mem.Allocator, limits: g.Limits, generation: u64) !Self {
    var result: Self = .{ .allocator = allocator, .continuation = try .init(generation), .backend = .{ .allocator = allocator, .maximum = limits.frame_bytes }, .cycle = try .init(limits), .bindings = undefined };
    for (&result.bindings) |*arena| arena.* = .init(allocator);
    return result;
}
/// The host first joins requests and closes its reads/preparations. This method
/// releases only codec memory; it never performs execution or cleanup I/O.
pub fn deinit(self: *Self) void {
    for (&self.bindings) |*arena| arena.deinit();
    self.backend.deinit();
    self.* = undefined;
}
pub fn abort(self: *Self, err: anyerror) void {
    self.continuation.abort(err);
}
pub fn complete(self: *Self, token: s.Token, result: s.Result) !void {
    try self.continuation.complete(token, result);
}
pub fn start(self: *Self, tag: u8, payload: []const u8) !void {
    if (self.continuation.closed) |err| return err;
    if (self.stage != .idle or self.continuation.pending != null or self.release_count != 0) return error.WireCommandPending;
    if (!self.keep_open) return error.WireSessionClosed;
    self.tag = tag;
    self.payload = payload;
    self.valid_sync = false;
    self.handling_error = false;
    self.stage = .command;
}
pub fn poll(self: *Self) !Poll {
    while (true) {
        if (try self.continuation.event()) |event| return .{ .request = event };
        if (self.continuation.result != null) {
            self.result = self.continuation.take() catch |err| {
                if (self.releasing) {
                    self.abort(err);
                    return err;
                }
                try self.reject(err);
                continue;
            };
            if (self.releasing) {
                if (self.releases[0].binding) |index| _ = self.bindings[index].reset(.retain_capacity);
                self.release_count -= 1;
                std.mem.copyForwards(Release, self.releases[0..self.release_count], self.releases[1..][0..self.release_count]);
                self.releasing = false;
            }
        }
        if (self.release_count != 0) {
            self.releasing = true;
            try self.continuation.issue(self.releases[0].request);
            continue;
        }
        if (self.deferred_request) |value| {
            self.deferred_request = null;
            try self.continuation.issue(value);
            continue;
        }
        if (self.stage == .idle) {
            self.payload = "";
            self.result = .ok;
            return .{ .done = self.keep_open };
        }
        self.step() catch |err| try self.reject(err);
    }
}
fn request(self: *Self, value: s.Request, next: Stage) !void {
    if (self.release_count != 0) {
        std.debug.assert(self.deferred_request == null);
        self.deferred_request = value;
    } else try self.continuation.issue(value);
    self.stage = next;
}
fn output(self: *Self, bytes: []const u8, guard: s.Guard, next: Stage) !void {
    try self.request(.{ .output = .{ .bytes = bytes, .guard = guard } }, next);
}
fn release(self: *Self, value: Release) void {
    std.debug.assert(self.release_count < self.releases.len);
    self.releases[self.release_count] = value;
    self.release_count += 1;
}
fn statementIndex(self: *Self, name: []const u8) ?usize {
    for (&self.statements, 0..) |*slot, i| if (slot.*) |*value| if (value.name.matches(name)) return i;
    return null;
}
fn portalIndex(self: *Self, name: []const u8) ?usize {
    for (&self.portals, 0..) |*slot, i| if (slot.*) |*value| if (value.name.matches(name)) return i;
    return null;
}
fn closePortal(self: *Self, index: usize) void {
    if (self.portals[index]) |*portal| {
        if (portal.read) |read| self.release(.{ .request = .{ .close_read = read }, .binding = index }) else _ = self.bindings[index].reset(.retain_capacity);
        self.portals[index] = null;
    }
    if (self.deferred == index) self.deferred = null;
}
fn clearPortals(self: *Self) void {
    for (0..self.portals.len) |i| self.closePortal(i);
}
fn closeStatement(self: *Self, index: usize) void {
    for (self.portals, 0..) |slot, i| if (slot) |portal| if (portal.statement == index) self.closePortal(i);
    if (self.statements[index]) |value| self.release(.{ .request = .{ .destroy = value.value.handle } });
    self.statements[index] = null;
}
fn parse(self: *Self, input: pg.Frontend.Parse, next: Stage) !void {
    if (self.statementIndex(input.name)) |i| {
        if (input.name.len != 0) return error.DuplicateWireStatement;
        self.closeStatement(i);
    }
    self.parse_index = for (self.statements[0..self.cycle.limits.prepared_statements], 0..) |slot, i| {
        if (slot == null) break i;
    } else return error.TooManyWireStatements;
    self.parse_input = input;
    self.after_parse = next;
    self.stage = .parse_request;
}
fn bind(self: *Self, input: pg.Frontend.Bind, validated: bool, next: Stage) !void {
    if (self.portalIndex(input.portal)) |i| {
        if (input.portal.len != 0) return error.DuplicateWirePortal;
        self.closePortal(i);
    }
    self.bind_index = for (self.portals[0..self.cycle.limits.portals], 0..) |slot, i| {
        if (slot == null) break i;
    } else return error.TooManyWirePortals;
    self.bind_statement = self.statementIndex(input.statement) orelse return error.UnknownWireStatement;
    const prepared = self.statements[self.bind_statement].?.value;
    if (input.count != prepared.parameters.len) return error.WireParameterCountMismatch;
    try input.results.validate(prepared.fields.len);
    self.bind_input = input;
    self.after_bind = next;
    self.stage = if (validated) .bind_values else .bind_validate;
}
fn columns(value: s.Prepared, buffer: []pg.Backend.Column) ![]const pg.Backend.Column {
    if (value.fields.len > buffer.len) return error.InvalidWireColumns;
    for (value.fields, buffer[0..value.fields.len]) |field, *column| column.* = .{ .name = field.name, .type = try g.Type.from(field) };
    return buffer[0..value.fields.len];
}
fn describe(self: *Self, target: pg.Frontend.Target, next: Stage) !void {
    self.describe_formats = .{};
    self.describe_index = switch (target.kind) {
        .statement => self.statementIndex(target.name) orelse return error.UnknownWireStatement,
        .portal => blk: {
            const portal = self.portals[self.portalIndex(target.name) orelse return error.UnknownWirePortal].?;
            self.describe_formats = portal.formats;
            break :blk portal.statement;
        },
    };
    self.describe_statement = target.kind == .statement;
    self.after_describe = next;
    self.stage = .describe;
}
fn execute(self: *Self, index: usize, maximum: u32, validated: bool, next: Stage) void {
    self.exec_index = index;
    self.exec_maximum = maximum;
    self.exec_emitted = 0;
    self.after_execute = next;
    self.stage = if (validated) .execute_start else .execute_validate;
}
fn reject(self: *Self, err: anyerror) !void {
    if (self.handling_error or self.continuation.closed != null) {
        self.abort(err);
        return err;
    }
    self.handling_error = true;
    self.clearPortals();
    if (self.provisional) |value| self.release(.{ .request = .{ .destroy = value.handle } });
    self.provisional = null;
    self.failure = err;
    self.stage = .error_request;
}
fn step(self: *Self) !void {
    switch (self.stage) {
        .idle => unreachable,
        .command => {
            if (self.cycle.state == .failed and self.tag != 'S' and self.tag != 'X') {
                self.stage = .idle;
                return;
            }
            self.message = try pg.Frontend.decode(self.tag, self.payload);
            self.valid_sync = self.message == .sync;
            if (self.cycle.state == .idle and self.tag != 'S' and self.tag != 'X') try self.request(.begin, .admitted) else self.stage = .dispatch;
        },
        .admitted => {
            self.transaction = self.result.status;
            self.stage = .dispatch;
        },
        .dispatch => {
            const action = try self.cycle.accept(self.tag, self.payload.len + 5);
            switch (action) {
                .terminate => {
                    self.keep_open = false;
                    self.stage = .idle;
                    return;
                },
                .ignore, .flush => {
                    self.stage = .idle;
                    return;
                },
                .sync_empty => {
                    self.stage = .sync_finish;
                    return;
                },
                .sync_write => {
                    self.execute(self.deferred orelse return error.UnknownWirePortal, 0, false, .sync_finish);
                    return;
                },
                .handle => {},
            }
            switch (self.message) {
                .query => |sql| {
                    if (self.statementIndex("")) |i| self.closeStatement(i);
                    if (self.portalIndex("")) |i| self.closePortal(i);
                    if (std.mem.trim(u8, sql, " \t\r\n;").len == 0) try self.output(try self.backend.empty(.empty_query), .none, .end) else try self.parse(.{ .name = "", .sql = sql, .count = 0 }, .simple_bind);
                },
                .parse => |input| try self.parse(input, .parse_output),
                .bind => |input| try self.bind(input, false, .bind_output),
                .describe => |target| try self.describe(target, .idle),
                .close => |target| {
                    switch (target.kind) {
                        .statement => if (self.statementIndex(target.name)) |i| self.closeStatement(i),
                        .portal => if (self.portalIndex(target.name)) |i| self.closePortal(i),
                    }
                    try self.output(try self.backend.empty(.close_complete), .none, .idle);
                },
                .execute => |input| {
                    const index = self.portalIndex(input.portal) orelse return error.UnknownWirePortal;
                    const portal = self.portals[index].?;
                    const mutation = self.statements[portal.statement].?.value.mutation;
                    try self.cycle.execute(portal.id, mutation, input.rows);
                    if (mutation) {
                        self.deferred = index;
                        self.stage = .idle;
                    } else self.execute(index, input.rows, false, .idle);
                },
                else => unreachable,
            }
        },
        .parse_request => try self.request(.{ .prepare = self.parse_input.sql }, .parsed),
        .parsed => {
            const value = self.result.prepared;
            self.provisional = value;
            const input = self.parse_input;
            if (value.parameters.len > g.Limits.max_parameters or input.count > value.parameters.len) return error.WireParameterCountMismatch;
            var prepared: Prepared = .{ .name = try Name.init(input.name), .value = value, .count = @intCast(value.parameters.len) };
            for (value.parameters, 0..) |logical, i| {
                const kind = (try g.Type.from(.{ .name = "", .type = logical, .nullable = true })).kind;
                prepared.oids[i] = try pg.Scalar.resolve(kind, if (i < input.count) input.oids[i] else 0);
            }
            self.statements[self.parse_index] = prepared;
            self.provisional = null;
            self.stage = self.after_parse;
        },
        .parse_output => try self.output(try self.backend.empty(.parse_complete), .none, .idle),
        .bind_validate => try self.request(.{ .validate = self.statements[self.bind_statement].?.value.handle }, .bind_values),
        .bind_values => {
            const prepared = self.statements[self.bind_statement].?;
            const input = self.bind_input;
            const arena = &self.bindings[self.bind_index];
            errdefer _ = arena.reset(.retain_capacity);
            const allocator = arena.allocator();
            const values = try allocator.alloc(?f.Types.Values.Atom, prepared.value.parameters.len);
            for (prepared.value.parameters, values, 0..) |logical, *value, i| {
                const kind = (try g.Type.from(.{ .name = "", .type = logical, .nullable = true })).kind;
                const bytes = if (input.values[i]) |raw| try allocator.dupe(u8, raw) else null;
                value.* = try pg.Scalar.decode(allocator, kind, prepared.oids[i], input.formats.at(i), bytes);
            }
            if (self.next_portal == std.math.maxInt(u64)) return error.WireSessionExhausted;
            const name = try Name.init(input.portal);
            // Ownership moves only after every fallible local operation. A host
            // bind refusal then releases this portal through the normal path.
            try self.request(.{ .bind = .{ .prepared = prepared.value.handle, .values = values } }, .bound);
            self.portals[self.bind_index] = .{ .name = name, .id = self.next_portal, .statement = self.bind_statement, .values = values, .formats = input.results };
            self.next_portal += 1;
        },
        .bound => self.stage = self.after_bind,
        .bind_output => try self.output(try self.backend.empty(.bind_complete), .none, .idle),
        .describe => {
            const prepared = self.statements[self.describe_index].?;
            if (self.describe_statement) try self.output(try self.backend.parameters(prepared.oids[0..prepared.count]), .{ .prepared = prepared.value.handle }, .describe_fields) else self.stage = .describe_fields;
        },
        .describe_fields => {
            const prepared = self.statements[self.describe_index].?.value;
            var buffer: [g.Limits.max_parameters]pg.Backend.Column = undefined;
            const fields = try columns(prepared, &buffer);
            const bytes = if (fields.len == 0) try self.backend.empty(.no_data) else try self.backend.describe(fields, &self.describe_formats);
            try self.output(bytes, .{ .prepared = prepared.handle }, self.after_describe);
        },
        .simple_bind => try self.bind(.{ .portal = "", .statement = "", .count = 0, .formats = .{}, .results = .{} }, true, .simple_describe),
        .simple_describe => {
            if (self.statements[self.portals[self.bind_index].?.statement].?.value.fields.len != 0) try self.describe(.{ .kind = .portal, .name = "" }, .simple_execute) else self.stage = .simple_execute;
        },
        .simple_execute => self.execute(self.bind_index, 0, true, .simple_finish),
        .simple_finish => {
            self.closePortal(self.exec_index);
            self.stage = .end;
        },
        .execute_validate => {
            const portal = self.portals[self.exec_index].?;
            if (portal.complete) return error.CompletedWirePortal;
            try self.request(.{ .validate = self.statements[portal.statement].?.value.handle }, .execute_start);
        },
        .execute_start => {
            const portal = &self.portals[self.exec_index].?;
            if (portal.complete) return error.CompletedWirePortal;
            const prepared = self.statements[portal.statement].?.value;
            if (prepared.empty) {
                portal.complete = true;
                try self.output(try self.backend.empty(.empty_query), .none, .execute_finish);
            } else if (prepared.mutation and prepared.fields.len == 0) try self.request(.{ .write = .{ .prepared = prepared.handle, .values = portal.values } }, .written) else if (portal.read == null) try self.request(.{ .open_read = .{ .prepared = prepared.handle, .values = portal.values } }, .opened) else self.stage = .pull;
        },
        .written => {
            const result = self.result.completion;
            try result.validate();
            if (result.outcome != .applied and result.outcome != .unchanged and result.outcome != .provisional) return error.InvalidWireCompletion;
            self.portals[self.exec_index].?.complete = true;
            try self.output(try self.backend.complete(result.kind, if (result.counts) |counts| counts.matched else 0), .{ .completion = self.statements[self.portals[self.exec_index].?.statement].?.value.handle }, .execute_finish);
        },
        .opened => {
            self.portals[self.exec_index].?.read = self.result.read;
            self.stage = .pull;
        },
        .pull => {
            self.requested = @intCast(if (self.exec_maximum == 0) g.ReadBatch.max_rows else @min(g.ReadBatch.max_rows, self.exec_maximum - self.exec_emitted));
            try self.request(.{ .next_batch = .{ .read = self.portals[self.exec_index].?.read.?, .maximum = self.requested } }, .batch);
        },
        .batch => {
            self.batch = self.result.batch;
            try self.batch.validate(self.requested);
            self.batch_index = 0;
            self.stage = .row;
        },
        .row => {
            const portal = &self.portals[self.exec_index].?;
            if (self.batch_index == self.batch.len) {
                self.stage = .batch_end;
                return;
            }
            var buffer: [g.Limits.max_parameters]pg.Backend.Column = undefined;
            const fields = try columns(self.statements[portal.statement].?.value, &buffer);
            const bytes = try self.backend.row(fields, &portal.formats, self.batch.rows[self.batch_index].?);
            try self.output(bytes, .{ .read = portal.read.? }, .row);
            self.batch_index += 1;
            portal.rows += 1;
        },
        .batch_end => {
            const portal = &self.portals[self.exec_index].?;
            if (self.batch.complete) {
                portal.complete = true;
                try self.output(try self.backend.complete(self.statements[portal.statement].?.value.row_command, portal.rows), .{ .read = portal.read.? }, .execute_finish);
            } else {
                if (self.exec_maximum != 0) self.exec_emitted += self.batch.len;
                if (self.exec_maximum != 0 and self.exec_emitted >= self.exec_maximum) {
                    try self.cycle.suspendRead();
                    self.batch = .{};
                    try self.output(try self.backend.empty(.suspended), .none, .execute_finish);
                } else self.stage = .pull;
            }
        },
        .execute_finish => {
            const portal = &self.portals[self.exec_index].?;
            if (portal.complete) if (portal.read) |read| {
                self.release(.{ .request = .{ .close_read = read } });
                portal.read = null;
            };
            self.batch = .{};
            self.stage = self.after_execute;
        },
        .sync_finish => {
            self.clearPortals();
            self.stage = .end;
        },
        .end => try self.request(.end, .ready),
        .ready => try self.output(try self.backend.ready(self.result.status), .none, .idle),
        .error_request => try self.request(.{ .diagnostic = self.failure }, .error_output),
        .error_output => {
            const diagnostic = self.result.diagnostic;
            try self.output(try self.backend.failure(false, diagnostic.state, diagnostic.message, diagnostic.detail), .none, .error_finish);
        },
        .error_finish => {
            if (self.tag == 'Q' and self.cycle.state == .idle or self.valid_sync) self.stage = .end else {
                self.cycle.fail();
                self.stage = .idle;
            }
        },
    }
}
