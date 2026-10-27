//! Bounded observation of one submitted token. Never carries or replays SQL.
//! This adapter uses the existing session contract; it is not a ResultSet API.
const std = @import("std");
const api = @import("root.zig").protocol;
const Client = @import("Client.zig");
const Self = @This();
token: api.Token,
account: api.Account,
started: std.Io.Timestamp,
milliseconds: u32,
operation: ?api.Operation = null,
session_lost: bool = false,

pub fn init(client: *Client, token: api.Token) Self {
    return .{ .token = token, .account = client.account.?, .started = std.Io.Clock.awake.now(client.io), .milliseconds = client.timeout_ms };
}
pub fn observe(self: *Self, value: api.Operation) !void {
    try value.validate();
    if (!std.mem.eql(u8, &self.token, &value.token) or !std.mem.eql(u8, &self.account, &value.identity.account)) return error.InvalidSqlResponse;
    if (self.operation) |prior| {
        if (!std.meta.eql(prior.identity, value.identity)) return error.InvalidSqlResponse;
        if (prior.command != null and prior.command != value.command) return error.InvalidSqlResponse;
    }
    if ((value.phase == .terminal) != (value.outcome != null)) return error.InvalidSqlResponse;
    self.operation = value;
}
fn sleep(io: std.Io, milliseconds: u32) !void {
    try io.sleep(.fromMilliseconds(milliseconds), .awake);
}
/// Admission discovery uses the remaining request budget. Once acceptance is
/// known, settlement has 270 seconds from the original submission, including
/// polling and at most one replacement observation session.
pub fn settle(self: *Self, client: *Client, config: Client.Config, password: ?[]const u8, cancel: bool) !api.Operation {
    var observer: ?Client = null;
    defer if (observer) |*value| {
        value.timeout_ms = 100;
        if (value.call(.close)) |reply| reply.deinit() else |_| {}
        value.deinit();
    };
    if (cancel) {
        self.started = std.Io.Clock.awake.now(client.io);
        self.milliseconds = 1000;
    }
    while (true) {
        if (!cancel and self.operation != null) self.milliseconds = 270000;
        const elapsed = self.started.durationTo(std.Io.Clock.awake.now(client.io)).toMilliseconds();
        if (elapsed >= self.milliseconds) return error.SqlOutcomeUnknown;
        const Event = union(enum) { result: anyerror!api.Operation, timeout: anyerror!void };
        var events: [2]Event = undefined;
        var selection: std.Io.Select(Event) = .init(client.io, &events);
        defer selection.cancelDiscard();
        try selection.concurrent(.timeout, sleep, .{ client.io, self.milliseconds - @as(u32, @intCast(@max(0, elapsed))) });
        try selection.concurrent(.result, run, .{ self, client, config, password, cancel, &observer });
        const operation = try switch (try selection.await()) {
            .result => |value| value,
            .timeout => |value| blk: {
                try value;
                break :blk error.SqlOutcomeUnknown;
            },
        };
        // Discovering an accepted operation after a lost execute reply has the
        // same settlement budget as receiving it directly. Never restart time.
        if (operation.phase == .terminal) return operation;
    }
}
fn run(self: *Self, original: *Client, config: Client.Config, password: ?[]const u8, cancel: bool, observer: *?Client) !api.Operation {
    const discovering = self.operation == null and !cancel;
    var client = if (observer.*) |*value| value else original;
    // Stopping an active read is independent of cancelling an accepted write.
    if (cancel) {
        const prior_timeout = client.timeout_ms;
        client.timeout_ms = @min(prior_timeout, 250);
        defer client.timeout_ms = prior_timeout;
        if (client.call(.{ .cancel = .{ .query = @splat(0) } })) |reply| reply.deinit() else |_| {}
    }
    var request_cancel = cancel;
    while (true) {
        if (self.operation) |value| {
            if (value.phase == .terminal) return value;
            if (!cancel and value.phase == .abandoned) return error.SqlOutcomeUnknown;
        }
        const reply = client.call(if (request_cancel) .{ .cancel = .{ .token = self.token } } else .{ .status = .{ .token = self.token } }) catch |err| switch (err) {
            error.SqlInstanceChanged, error.IncompatibleSqlDefinition, error.InvalidSqlResponse, error.Canceled, error.OutOfMemory => return err,
            else => {
                try sleep(client.io, 25);
                continue;
            },
        };
        defer reply.deinit();
        switch (reply.value.result) {
            .operation => |value| {
                try self.observe(value);
                if (discovering) return value;
                request_cancel = false;
            },
            .err => |failure| {
                if (std.mem.eql(u8, &failure.sqlstate, "42501") or std.mem.eql(u8, &failure.sqlstate, "28000")) return error.SqlObservationDenied;
                if (std.mem.eql(u8, failure.code, "SqlSessionExpired")) {
                    if (observer.* != null) return error.SqlOutcomeUnknown;
                    self.session_lost = true;
                    var pinned = config;
                    pinned.instance = original.instance;
                    observer.* = try Client.init(original.allocator, original.io, pinned);
                    client = &observer.*.?;
                    try client.open(pinned, password);
                    if (!std.mem.eql(u8, &self.account, &client.account.?)) return error.SqlObservationDenied;
                    continue;
                }
                // Configuration reload cannot be cancelled; observation can
                // still establish its original outcome within the same budget.
                if (std.mem.eql(u8, failure.code, "ConfigurationCancellationUnsupported")) request_cancel = false else if (!std.mem.eql(u8, failure.code, "MissingGatewayOperation") and !std.mem.eql(u8, failure.code, "SqlSessionBusy") and !std.mem.eql(u8, failure.code, "AuthorityUnavailable") and !std.mem.eql(u8, failure.code, "AuthorityTimeout") and !std.mem.eql(u8, failure.code, "GatewayOwnerUnavailable") and !std.mem.eql(u8, failure.code, "StaleGatewayCoordinator")) return error.SqlOutcomeUnknown;
            },
            else => return error.InvalidSqlResponse,
        }
        try sleep(client.io, 25);
    }
}
