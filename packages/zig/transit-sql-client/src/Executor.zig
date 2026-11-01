//! Ordinary statement submission and settlement. The UI supplies cancellation
//! intent and renders semantic outcomes; it never repairs sessions or polls jobs.
const std = @import("std");
const sdk = @import("root.zig");
const api = sdk.protocol;
const r = sdk.results;
const Self = @This();
client: *sdk.Client,
control: *sdk.Client,
config: sdk.Client.Config,
password: ?[]const u8 = null,
cancellation: ?Cancellation = null,
observer: ?struct { context: *anyopaque, changed: *const fn (*anyopaque, Phase) void } = null,
interrupted: bool = false,
session_lost: bool = false,
access_lost: bool = false,
pub const Cancellation = struct {
    pub const Request = enum { none, cancel, terminate };
    context: *anyopaque,
    requested: *const fn (*anyopaque) Request,
    acknowledge: *const fn (*anyopaque) void,
};
pub const Phase = enum { prepare, submit, wait, fetch };
pub fn enter(self: *Self, phase: Phase) void {
    if (self.observer) |observer| observer.changed(observer.context, phase);
}
pub const Options = struct {
    resident_bytes: usize = 16 * 1024 * 1024,
    captured: bool = false,
    before_submit: ?BeforeSubmit = null,
};
/// Borrowed only during persist. The application must durably copy this value
/// before returning success when it promises recovery after caller loss.
/// Carries the mandatory definition and exact original execute token, without
/// the secret session handle, endpoint credentials or prepared-statement state.
pub const Submission = struct {
    version: u8,
    definition: api.native.Definition,
    instance: api.Instance,
    account: api.Account,
    database: []const u8,
    source: ?[]const u8,
    transaction: ?r.protocol.Transaction.Handle,
    execute: @FieldType(api.Action, "execute"),

    pub fn validate(self: Submission) !void {
        if (self.execute.sql == null or self.execute.statement != null or self.execute.token == null) return error.InvalidSqlSubmission;
        // Reuse protocol validation with an inert local handle. This envelope
        // is never dispatched; no credential is stored or reconstructed.
        try (api.Request{ .version = self.version, .definition = self.definition, .instance = self.instance, .session = @splat(0), .action = .{ .execute = self.execute } }).validate();
        if (self.transaction) |transaction| try transaction.validate();
    }

    /// Observe through a separately authenticated client. Does not restore a
    /// session/transaction, submit SQL or establish that acceptance occurred.
    pub fn pending(self: Submission, client: *sdk.Client) !sdk.Pending {
        try self.validate();
        if (!std.meta.eql(client.instance, @as(?api.Instance, self.instance))) return error.SqlInstanceChanged;
        if (!std.meta.eql(client.account, @as(?api.Account, self.account))) return error.SqlObservationDenied;
        if (client.session == null) return error.SqlSessionRequired;
        return sdk.Pending.init(client, self.execute.token.?);
    }
};
pub const BeforeSubmit = struct {
    context: *anyopaque,
    /// No reentry into this executor/its clients or mutation/retention of borrows.
    /// Failure stops before execute; this hook never observes a domain outcome.
    persist: *const fn (*anyopaque, Submission) anyerror!void,
};
pub const Outcome = struct {
    parent: std.mem.Allocator,
    memory: r.fuze.MemoryBudget,
    arena: std.heap.ArenaAllocator,
    value: r.StatementOutcome,
    prepared: ?struct { executor: *Self, id: api.Id } = null,
    pub fn deinit(self: *Outcome) void {
        if (self.value == .rows) self.value.rows.deinit();
        if (self.prepared) |prepared| prepared.executor.release(.{ .release = prepared.id });
        self.arena.deinit();
        std.debug.assert(self.memory.used == 0);
        self.parent.destroy(self);
    }
};

/// Prepare through the service's typed dispatch, refuse commands, then execute
/// that exact prepared binding. No SQL parsing, new admission token, or retry is
/// performed here. A lost execute reply is a lost interactive read, never a
/// reason to run the SQL again. The outcome owns the prepared handle.
pub fn read(self: *Self, sql: []const u8, options: Options) !*Outcome {
    if (options.captured) return error.ReadOnlyStatementRequired;
    if (options.before_submit != null) return error.ReadOnlyStatementRequired;
    self.enter(.prepare);
    const out = try self.createOutcome(options);
    errdefer out.deinit();
    const a = out.arena.allocator();
    const prepared = try self.call(.{ .prepare = .{ .sql = sql } }, out.memory.allocator());
    defer prepared.deinit();
    if (prepared.value.result == .err) {
        out.value = .{ .failure = try self.failure(a, prepared.value.result.err) };
        return out;
    }
    if (prepared.value.result != .described) return error.InvalidSqlResponse;
    const description = prepared.value.result.described;
    out.prepared = .{ .executor = self, .id = description.statement };
    try requireRead(description);
    self.enter(.submit);
    const response = try self.call(.{ .execute = .{ .statement = description.statement } }, out.memory.allocator());
    var retained = false;
    defer if (!retained) response.deinit();
    switch (response.value.result) {
        .err => |err| out.value = .{ .failure = try self.failure(a, err) },
        .batch => |batch| {
            const result = @import("NativeResult.zig").open(out.memory.allocator(), self, response, options.resident_bytes) catch |err| {
                self.release(.{ .close_result = batch.cursor });
                return err;
            };
            retained = true;
            out.value = .{ .rows = result };
        },
        else => return error.InvalidSqlResponse,
    }
    return out;
}

fn requireRead(description: api.Description) !void {
    if (description.mutation or description.schema == null or description.parameters.len != 0) return error.ReadOnlyStatementRequired;
}

test "read admission uses authoritative statement semantics" {
    const t = std.testing;
    const row: api.Description = .{ .statement = @splat(1), .schema = "schema", .parameters = &.{}, .mutation = false };
    try requireRead(row);
    var command = row;
    command.mutation = true;
    try t.expectError(error.ReadOnlyStatementRequired, requireRead(command));
    command.mutation = false;
    command.schema = null;
    try t.expectError(error.ReadOnlyStatementRequired, requireRead(command));
    command = row;
    command.parameters = &.{"unbound"};
    try t.expectError(error.ReadOnlyStatementRequired, requireRead(command));
}

pub fn execute(self: *Self, sql: []const u8, parameters: ?[]const r.fuze.LogicalJson.Atom, options: Options) !*Outcome {
    self.enter(.prepare);
    const out = try self.createOutcome(options);
    errdefer out.deinit();
    const a = out.arena.allocator();
    // Own the exact text before a persistence callback can release its input.
    const text = if (options.before_submit != null) try a.dupe(u8, sql) else sql;
    var values: []const []const u8 = &.{};
    if (parameters) |bindings| {
        const metadata = try self.call(.{ .prepare = .{ .sql = text } }, out.memory.allocator());
        defer metadata.deinit();
        if (metadata.value.result == .err) {
            out.value = .{ .failure = try self.failure(a, metadata.value.result.err) };
            return out;
        }
        if (metadata.value.result != .described) return error.InvalidSqlResponse;
        const described = metadata.value.result.described;
        defer self.release(.{ .release = described.statement });
        if (described.parameters.len != bindings.len) return error.ParameterCountMismatch;
        const encoded = try a.alloc([]const u8, bindings.len);
        for (bindings, described.parameters, encoded) |binding, descriptor, *value| {
            const kind = try api.Codec.decodeSchema(a, descriptor);
            value.* = try api.Codec.parameter(a, try r.fuze.LogicalJson.atomFromForeign(a, binding, kind), kind);
        }
        values = encoded;
    }
    var token: api.Token = undefined;
    try self.client.io.randomSecure(&token);
    const action: api.Action = .{ .execute = .{ .sql = text, .parameters = values, .token = token, .captured = options.captured } };
    if (options.before_submit) |hook| {
        const request: api.Request = .{ .version = 1, .definition = api.native.current_definition, .instance = self.client.instance, .session = self.client.session, .action = action };
        try request.validate();
        const account = self.client.account orelse return error.SqlSessionRequired;
        // Read actual session selection/attachment, not initial Config values:
        // a session may have changed its database or attached a transaction.
        const observed = try self.call(.context, out.memory.allocator());
        defer observed.deinit();
        if (observed.value.result == .err) {
            out.value = .{ .failure = try self.failure(a, observed.value.result.err) };
            return out;
        }
        if (observed.value.result != .context or !std.mem.eql(u8, &observed.value.result.context.account, &account)) return error.InvalidSqlResponse;
        const scope = observed.value.result.context;
        try hook.persist(hook.context, .{ .version = request.version, .definition = request.definition, .instance = request.instance.?, .account = account, .database = scope.database, .source = scope.source, .transaction = scope.transaction, .execute = action.execute });
        // Detect handle replacement before any accepting dispatch. This is not
        // permission to reenter the single-borrower session inside the callback.
        if (!std.meta.eql(self.client.instance, request.instance) or
            !std.meta.eql(self.client.session, request.session) or
            !std.meta.eql(self.client.account, @as(?api.Account, account)) or
            !std.meta.eql(self.control.instance, request.instance) or
            !std.meta.eql(self.control.session, request.session) or
            !std.meta.eql(self.control.account, @as(?api.Account, account))) return error.SqlSubmissionScopeChanged;
    }
    var pending = sdk.Pending.init(self.control, token);
    self.enter(.submit);
    const response = self.call(action, out.memory.allocator()) catch |err| {
        // Slot refusal precedes dispatch. It cannot create an accepted attempt
        // requiring settlement; other failures may follow a successful send.
        if (err == error.SqlResponseCapacity or err == error.SqlResponseBusy) return err;
        out.value = try self.settle(&pending, err == error.ResultCancelled);
        return out;
    };
    var retained = false;
    defer if (!retained) response.deinit();
    switch (response.value.result) {
        .operation => |operation| {
            try pending.observe(operation);
            out.value = try self.settle(&pending, false);
        },
        .err => |err| {
            if (err.retry == .control or err.retry == .same_token) {
                if (err.operation) |operation| try pending.observe(operation);
                out.value = try self.settle(&pending, false);
            } else out.value = .{ .failure = try self.failure(a, err) };
        },
        .completion => |completion| {
            try completion.validate();
            out.value = .{ .command = completion };
        },
        .batch => |batch| {
            const result = @import("NativeResult.zig").open(out.memory.allocator(), self, response, options.resident_bytes) catch |err| {
                self.release(.{ .close_result = batch.cursor });
                return err;
            };
            retained = true;
            out.value = .{ .rows = result };
        },
        else => return error.InvalidSqlResponse,
    }
    return out;
}
fn createOutcome(self: *Self, options: Options) !*Outcome {
    if (options.resident_bytes == 0 or options.resident_bytes > 16 * 1024 * 1024) return error.InvalidResultBudget;
    const out = try self.client.allocator.create(Outcome);
    out.* = .{ .parent = self.client.allocator, .memory = .{ .parent = self.client.allocator, .limit = options.resident_bytes }, .arena = undefined, .value = .{ .failure = .{ .code = "Uninitialized", .sqlstate = "XX000".*, .message = "Statement has not been submitted" } } };
    out.arena = .init(out.memory.allocator());
    return out;
}
fn failure(self: *Self, allocator: std.mem.Allocator, value: api.Error) !r.Failure {
    const result: r.Failure = .{ .code = try allocator.dupe(u8, value.code), .sqlstate = value.sqlstate, .message = try allocator.dupe(u8, value.message), .diagnostic = value.diagnostic };
    self.access_lost = self.access_lost or result.denied();
    self.session_lost = self.session_lost or std.mem.eql(u8, value.code, "SqlSessionExpired");
    return result;
}
fn settle(self: *Self, pending: *sdk.Pending, cancel: bool) !r.StatementOutcome {
    self.enter(.wait);
    defer self.session_lost = self.session_lost or pending.session_lost;
    const value = self.awaitPending(pending, cancel) catch |err| {
        self.access_lost = self.access_lost or err == error.SqlObservationDenied;
        return .{ .unresolved = .{
            .account = pending.account,
            .instance = self.client.instance.?,
            .token = pending.token,
            .operation = if (pending.operation) |operation| operation.identity else null,
            .reason = if (err == error.SqlObservationDenied) .denied else if (self.interrupted) .interrupted else if (err == error.SqlInstanceChanged or err == error.IncompatibleSqlDefinition) .identity_changed else .unavailable,
        } };
    };
    const completion = try value.completion();
    return .{ .command = completion };
}
fn awaitPending(self: *Self, pending: *sdk.Pending, cancel: bool) anyerror!api.Operation {
    if (self.cancellation == null) return pending.settle(self.control, self.config, self.password, cancel);
    const Event = union(enum) { reply: anyerror!api.Operation, signal: anyerror!void };
    var events: [2]Event = undefined;
    var selection: std.Io.Select(Event) = .init(self.client.io, &events);
    defer selection.cancelDiscard();
    try selection.concurrent(.signal, poll, .{self});
    try selection.concurrent(.reply, sdk.Pending.settle, .{ pending, self.control, self.config, self.password, cancel });
    switch (try selection.await()) {
        .reply => |reply| return reply,
        .signal => |result| {
            try result;
            selection.cancelDiscard();
            const terminating = self.acknowledge();
            if (terminating or cancel) return error.SqlOutcomeUnknown;
            return self.awaitPending(pending, true);
        },
    }
}
fn poll(self: *Self) !void {
    const cancellation = self.cancellation.?;
    while (cancellation.requested(cancellation.context) == .none) try self.client.io.sleep(.fromMilliseconds(20), .awake);
}
fn acknowledge(self: *Self) bool {
    const cancellation = self.cancellation.?;
    self.interrupted = true;
    const terminating = cancellation.requested(cancellation.context) == .terminate;
    cancellation.acknowledge(cancellation.context);
    return terminating;
}
pub fn call(self: *Self, action: api.Action, allocator: std.mem.Allocator) !sdk.Response {
    if (self.cancellation == null) return self.client.callAllocated(action, allocator);
    const Event = union(enum) { reply: anyerror!sdk.Response, signal: anyerror!void };
    var events: [2]Event = undefined;
    var selection: std.Io.Select(Event) = .init(self.client.io, &events);
    defer while (selection.cancel()) |pending| switch (pending) {
        .reply => |result| if (result) |reply| reply.deinit() else |_| {},
        .signal => {},
    };
    try selection.concurrent(.signal, poll, .{self});
    try selection.concurrent(.reply, sdk.Client.callAllocated, .{ self.client, action, allocator });
    switch (try selection.await()) {
        .reply => |reply| return reply,
        .signal => |result| {
            try result;
            _ = self.acknowledge();
            if (action != .execute) self.release(.{ .cancel = .{ .query = @splat(0) } });
            return error.ResultCancelled;
        },
    }
}
pub fn release(self: *Self, action: api.Action) void {
    const prior = self.control.timeout_ms;
    self.control.timeout_ms = @min(prior, 1000);
    defer self.control.timeout_ms = prior;
    if (self.control.call(action)) |reply| reply.deinit() else |_| {}
}
/// Renew this same session while a consumer is doing work between reads. An
/// expired session fails; this never reopens or substitutes an interactive cut.
pub fn renew(self: *Self) !void {
    const response = try self.call(.touch, self.client.allocator);
    defer response.deinit();
    if (response.value.result != .closed) return error.SqlSessionUnavailable;
}
/// Explicitly open retained rows after captured computation has settled. This
/// starts a new consumption; it is never an implicit repair of a lost SELECT.
pub fn openCaptured(self: *Self, operation: r.Operation, options: Options) !*Outcome {
    if (operation.kind != .captured) return error.InvalidResultOperation;
    const out = try self.createOutcome(options);
    errdefer out.deinit();
    const response = try self.call(.{ .result = operation }, out.memory.allocator());
    var retained = false;
    defer if (!retained) response.deinit();
    if (response.value.result == .err) {
        out.value = .{ .failure = try self.failure(out.arena.allocator(), response.value.result.err) };
        return out;
    }
    if (response.value.result != .batch) return error.SqlResultUnavailable;
    const batch = response.value.result.batch;
    const result = @import("NativeResult.zig").open(out.memory.allocator(), self, response, options.resident_bytes) catch |err| {
        self.release(.{ .close_result = batch.cursor });
        return err;
    };
    retained = true;
    out.value = .{ .rows = result };
    return out;
}
