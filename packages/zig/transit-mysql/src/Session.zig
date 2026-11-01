//! Authenticated classic commands as bounded host requests and borrowed output.
const std = @import("std");
const m = @import("root.zig");
const g = m.wire;
const s = g.Session;
const Self = @This();
const Statement = struct { id: u32, prepared: s.Prepared, parameters: m.Command.Parameters = .{} };
const Stage = enum {
    idle,
    command,
    admitted,
    dispatch,
    query_prepared,
    prepare_received,
    prepare_header,
    prepare_parameters,
    prepare_fields,
    prepare_install,
    metadata_eof,
    bind,
    bound,
    execute,
    written,
    write_output,
    opened,
    columns,
    field,
    pull,
    batch,
    row,
    result_status,
    result_output,
    finish,
    end,
    ended,
    reset_output,
    clear_output,
    error_request,
    error_output,
};
pub const Poll = union(enum) { request: s.Event, done: bool };
allocator: std.mem.Allocator,
limits: g.Limits,
flags: u32,
continuation: s.Continuation,
backend: m.Backend,
statements: [64]?Statement = @splat(null),
next_id: u32 = 1,
stage: Stage = .idle,
result: s.Result = .ok,
payload: []const u8 = "",
command: m.Command.Message = undefined,
keep_open: bool = true,
handling_error: bool = false,
failure: anyerror = error.InvalidWireCommand,
releases: [66]s.Request = undefined,
release_count: usize = 0,
releasing: bool = false,
deferred_request: ?s.Request = null,
temporary: ?s.Prepared = null,
prepared: s.Prepared = undefined,
values: s.Values = &.{},
bound_values: m.Command.Parameters.Bound = undefined,
binary: bool = false,
validated: bool = false,
read: ?s.Handle = null,
free: usize = 0,
prepared_id: u32 = 0,
metadata_index: usize = 0,
metadata_next: Stage = .idle,
batch: g.ReadBatch = .{},
batch_index: usize = 0,
affected: u64 = 0,

pub fn init(allocator: std.mem.Allocator, limits: g.Limits, flags: u32, generation: u64) !Self {
    try limits.validate();
    if (flags & ~m.Handshake.capabilities != 0 or flags & m.Handshake.required != m.Handshake.required) return error.UnsupportedWireCapabilities;
    return .{ .allocator = allocator, .limits = limits, .flags = flags, .continuation = try .init(generation), .backend = .{ .allocator = allocator, .maximum = limits.frame_bytes } };
}
pub fn deinit(self: *Self) void {
    self.backend.deinit();
    self.* = undefined;
}
pub fn abort(self: *Self, err: anyerror) void {
    self.continuation.abort(err);
}
pub fn complete(self: *Self, token: s.Token, result: s.Result) !void {
    // Encoding reserves a packet sequence. A refused first write sent none of
    // that packet, so an ERR must use its sequence. Partial refusal closes.
    const unsent = result == .refused and self.continuation.offset == 0;
    try self.continuation.complete(token, result);
    if (unsent) self.backend.sequence -%= 1;
}
pub fn start(self: *Self, payload: []const u8) !void {
    if (self.continuation.closed) |err| return err;
    if (self.stage != .idle or self.continuation.pending != null or self.release_count != 0) return error.WireCommandPending;
    if (!self.keep_open) return error.WireSessionClosed;
    self.payload = payload;
    self.backend.sequence = 1;
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
                self.release_count -= 1;
                std.mem.copyForwards(s.Request, self.releases[0..self.release_count], self.releases[1..][0..self.release_count]);
                self.releasing = false;
            }
        }
        if (self.release_count != 0) {
            self.releasing = true;
            try self.continuation.issue(self.releases[0]);
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
            self.values = &.{};
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
fn release(self: *Self, value: s.Request) void {
    std.debug.assert(self.release_count < self.releases.len);
    self.releases[self.release_count] = value;
    self.release_count += 1;
}
fn clear(self: *Self) void {
    for (&self.statements) |*slot| if (slot.*) |value| {
        self.release(.{ .destroy = value.prepared.handle });
        slot.* = null;
    };
}
fn index(self: *Self, id: u32) ?usize {
    for (self.statements, 0..) |slot, i| if (slot) |value| if (value.id == id) return i;
    return null;
}
fn columns(prepared: s.Prepared, buffer: []m.Backend.Column) ![]const m.Backend.Column {
    if (prepared.fields.len > buffer.len) return error.InvalidWireColumns;
    for (prepared.fields, buffer[0..prepared.fields.len]) |field, *column| column.* = .{ .name = field.name, .type = try g.Type.from(field) };
    return buffer[0..prepared.fields.len];
}
fn metadataEnd(self: *Self, next: Stage) !void {
    if (self.flags & m.Handshake.deprecate_eof != 0) {
        self.stage = next;
        return;
    }
    self.metadata_next = next;
    try self.request(.status, .metadata_eof);
}
fn cleanup(self: *Self) void {
    if (self.read) |read_handle| self.release(.{ .close_read = read_handle });
    self.read = null;
    self.batch = .{};
    if (self.temporary) |value| self.release(.{ .destroy = value.handle });
    self.temporary = null;
}
fn reject(self: *Self, err: anyerror) !void {
    // CLOSE/long-data have no reply; a malformed no-response command must not
    // leave an unsolicited ERR to be mistaken for the following SQL response.
    if (self.handling_error or self.continuation.closed != null or (self.payload.len > 0 and (self.payload[0] == 0x19 or self.payload[0] == 0x18))) {
        self.abort(err);
        return err;
    }
    self.handling_error = true;
    self.cleanup();
    self.failure = err;
    self.stage = .error_request;
}
fn step(self: *Self) !void {
    switch (self.stage) {
        .idle => unreachable,
        .command => {
            self.command = try m.Command.decode(self.payload);
            if (self.command == .quit) {
                self.keep_open = false;
                self.stage = .end;
            } else try self.request(.begin, .admitted);
        },
        .admitted => {
            self.backend.transaction = self.result.status != .idle;
            self.stage = .dispatch;
        },
        .dispatch => switch (self.command) {
            .query => |sql| try self.request(.{ .prepare = sql }, .query_prepared),
            .prepare => |sql| {
                self.free = for (self.statements[0..self.limits.prepared_statements], 0..) |slot, i| {
                    if (slot == null) break i;
                } else return error.TooManyWireStatements;
                if (self.next_id == std.math.maxInt(u32)) return error.WireSessionExhausted;
                try self.request(.{ .prepare = sql }, .prepare_received);
            },
            .execute => |body| {
                const id = try m.Command.statementId(body);
                const slot = &self.statements[self.index(id) orelse return error.UnknownWireStatement].?;
                var kinds: [g.Limits.max_parameters]g.Type.Kind = undefined;
                const types = slot.prepared.parameters;
                if (types.len > kinds.len) return error.TooManyWireParameters;
                for (types, kinds[0..types.len]) |logical, *kind| kind.* = (try g.Type.from(.{ .name = "?", .type = logical, .nullable = true })).kind;
                self.bound_values = try slot.parameters.execute(body, id, kinds[0..types.len]);
                self.prepared = slot.prepared;
                self.values = self.bound_values.values[0..self.bound_values.count];
                self.binary = true;
                self.validated = false;
                self.stage = .bind;
            },
            .close => |id| {
                if (self.index(id)) |i| {
                    self.release(.{ .destroy = self.statements[i].?.prepared.handle });
                    self.statements[i] = null;
                }
                self.stage = .end;
            },
            .reset => |id| try self.request(.{ .validate = self.statements[self.index(id) orelse return error.UnknownWireStatement].?.prepared.handle }, .reset_output),
            .database => |name| try self.request(.{ .select_database = name }, .clear_output),
            .reset_connection => try self.request(.reset, .clear_output),
            .ping => self.stage = .reset_output,
            .quit => unreachable,
        },
        .query_prepared => {
            self.temporary = self.result.prepared;
            self.prepared = self.result.prepared;
            self.values = &.{};
            self.binary = false;
            self.validated = true;
            self.stage = .bind;
        },
        .prepare_received => {
            self.temporary = self.result.prepared;
            self.prepared = self.result.prepared;
            if (self.prepared.empty) return error.EmptyWireQuery;
            if (self.prepared.parameters.len > g.Limits.max_parameters) return error.TooManyWireParameters;
            var buffer: [g.Limits.max_parameters]m.Backend.Column = undefined;
            _ = try columns(self.prepared, &buffer);
            self.prepared_id = self.next_id;
            self.next_id += 1;
            self.stage = .prepare_header;
        },
        .prepare_header => {
            self.metadata_index = 0;
            try self.output(try self.backend.prepared(self.prepared_id, self.prepared.fields.len, self.prepared.parameters.len), .{ .prepared = self.prepared.handle }, .prepare_parameters);
        },
        .prepare_parameters => {
            if (self.metadata_index == self.prepared.parameters.len) {
                self.metadata_index = 0;
                if (self.prepared.parameters.len == 0) self.stage = .prepare_fields else try self.metadataEnd(.prepare_fields);
            } else {
                const logical = self.prepared.parameters[self.metadata_index];
                self.metadata_index += 1;
                try self.output(try self.backend.describe(.{ .name = "?", .type = try g.Type.from(.{ .name = "?", .type = logical, .nullable = true }) }), .{ .prepared = self.prepared.handle }, .prepare_parameters);
            }
        },
        .prepare_fields => {
            if (self.metadata_index == self.prepared.fields.len) {
                if (self.prepared.fields.len == 0) self.stage = .prepare_install else try self.metadataEnd(.prepare_install);
            } else {
                const field = self.prepared.fields[self.metadata_index];
                self.metadata_index += 1;
                try self.output(try self.backend.describe(.{ .name = field.name, .type = try g.Type.from(field) }), .{ .prepared = self.prepared.handle }, .prepare_fields);
            }
        },
        .prepare_install => {
            self.statements[self.free] = .{ .id = self.prepared_id, .prepared = self.prepared };
            self.temporary = null;
            self.stage = .end;
        },
        .metadata_eof => {
            self.backend.transaction = self.result.status != .idle;
            try self.output(try self.backend.eof(), .{ .prepared = self.prepared.handle }, self.metadata_next);
        },
        .bind => {
            if (self.prepared.empty) return error.EmptyWireQuery;
            try self.request(.{ .bind = .{ .prepared = self.prepared.handle, .values = self.values } }, .bound);
        },
        .bound => {
            if (self.validated) self.stage = .execute else try self.request(.{ .validate = self.prepared.handle }, .execute);
        },
        .execute => {
            const bound: s.Bound = .{ .prepared = self.prepared.handle, .values = self.values };
            if (self.prepared.mutation and self.prepared.fields.len == 0) try self.request(.{ .write = bound }, .written) else try self.request(.{ .open_read = bound }, .opened);
        },
        .written => {
            const result = self.result.completion;
            try result.validate();
            if (result.outcome != .applied and result.outcome != .unchanged and result.outcome != .provisional) return error.InvalidWireCompletion;
            self.affected = if (result.counts) |counts| if (result.kind == .update and self.flags & m.Handshake.found_rows == 0) counts.changed else counts.matched else 0;
            try self.request(.status, .write_output);
        },
        .write_output => {
            self.backend.transaction = self.result.status != .idle;
            try self.output(try self.backend.ok(self.affected, false), .{ .completion = self.prepared.handle }, .finish);
        },
        .opened => {
            self.read = self.result.read;
            self.stage = .columns;
        },
        .columns => {
            var buffer: [g.Limits.max_parameters]m.Backend.Column = undefined;
            _ = try columns(self.prepared, &buffer);
            self.metadata_index = 0;
            try self.output(try self.backend.columns(self.prepared.fields.len), .{ .prepared = self.prepared.handle }, .field);
        },
        .field => {
            if (self.metadata_index == self.prepared.fields.len) try self.metadataEnd(.pull) else {
                const field = self.prepared.fields[self.metadata_index];
                self.metadata_index += 1;
                try self.output(try self.backend.describe(.{ .name = field.name, .type = try g.Type.from(field) }), .{ .prepared = self.prepared.handle }, .field);
            }
        },
        .pull => try self.request(.{ .next_batch = .{ .read = self.read.?, .maximum = g.ReadBatch.max_rows } }, .batch),
        .batch => {
            self.batch = self.result.batch;
            try self.batch.validate(g.ReadBatch.max_rows);
            self.batch_index = 0;
            self.stage = .row;
        },
        .row => {
            if (self.batch_index == self.batch.len) {
                self.stage = if (self.batch.complete) .result_status else .pull;
                return;
            }
            var buffer: [g.Limits.max_parameters]m.Backend.Column = undefined;
            const fields = try columns(self.prepared, &buffer);
            try self.output(try self.backend.row(fields, self.batch.rows[self.batch_index].?, self.binary), .{ .read = self.read.? }, .row);
            self.batch_index += 1;
        },
        .result_status => try self.request(.status, .result_output),
        .result_output => {
            self.backend.transaction = self.result.status != .idle;
            const bytes = if (self.flags & m.Handshake.deprecate_eof != 0) try self.backend.ok(0, true) else try self.backend.eof();
            try self.output(bytes, .{ .read = self.read.? }, .finish);
        },
        .finish => {
            self.cleanup();
            self.stage = .end;
        },
        .end => try self.request(.end, .ended),
        .ended => self.stage = .idle,
        .clear_output => {
            self.clear();
            self.stage = .reset_output;
        },
        .reset_output => try self.output(try self.backend.ok(0, false), .none, .end),
        .error_request => try self.request(.{ .diagnostic = self.failure }, .error_output),
        .error_output => {
            const diagnostic = self.result.diagnostic;
            const Mapping = struct { source: [5]u8, code: u16, state: [5]u8 };
            const mappings = [_]Mapping{
                .{ .source = "42501".*, .code = 1142, .state = "42000".* },
                .{ .source = "53000".*, .code = 1041, .state = "HY000".* },
                .{ .source = "57014".*, .code = 1317, .state = "70100".* },
                .{ .source = "0A000".*, .code = 1235, .state = "42000".* },
                .{ .source = "22003".*, .code = 1264, .state = "22003".* },
                .{ .source = "22001".*, .code = 1406, .state = "22001".* },
                .{ .source = "23505".*, .code = 1062, .state = "23000".* },
                .{ .source = "23502".*, .code = 1048, .state = "23000".* },
                .{ .source = "23514".*, .code = 3819, .state = "HY000".* },
                .{ .source = "42P07".*, .code = 1050, .state = "42S01".* },
                .{ .source = "42P01".*, .code = 1146, .state = "42S02".* },
                .{ .source = "42601".*, .code = 1064, .state = "42000".* },
                .{ .source = "26000".*, .code = 1243, .state = "HY000".* },
                .{ .source = "28000".*, .code = 1045, .state = "28000".* },
            };
            const mapping = for (mappings) |value| {
                if (std.mem.eql(u8, &diagnostic.state, &value.source)) break value;
            } else Mapping{ .source = diagnostic.state, .code = 1105, .state = "HY000".* };
            var message: [512]u8 = undefined;
            const text = if (diagnostic.detail) |detail| try std.fmt.bufPrint(&message, "{s}; {s}", .{ diagnostic.message, detail }) else diagnostic.message;
            try self.output(try self.backend.failure(mapping.code, mapping.state, text), .none, .end);
        },
    }
}
