//! Bounded startup observations; never readiness or recovery authority.
const std = @import("std");
const telemetry = @import("transit_query").wire.observability.telemetry;
const Self = @This();

pub const Phase = enum {
    configuration,
    installation,
    storage,
    node,
    journal_recovery,
    application_recovery,
    provisioning,
    node_restart,
    board_provisioning,
    workers,
    table_readiness,
    configuration_checkpoint,
    gateway,
    sql_setup,
    board,
    sql_readiness,
    retry_delay,
};

runtime: *telemetry.Runtime,
total: telemetry.Span,
phase: ?Phase = null,
span: telemetry.Span = .{},

pub fn init(runtime: *telemetry.Runtime, started: std.Io.Timestamp) Self {
    var total = runtime.begin(.service, null);
    total.started = started;
    return .{ .runtime = runtime, .total = total };
}

pub fn next(self: *Self, phase: Phase) void {
    if (self.total.finished) return;
    self.endPhase(.ok, null);
    self.phase = phase;
    self.span = self.runtime.begin(.service, self.total.context);
    self.runtime.event(.{ .name = "server.startup.phase.begin", .operation = @tagName(phase) });
}

fn endPhase(self: *Self, outcome: telemetry.Outcome, failure: ?anyerror) void {
    const phase = self.phase orelse return;
    self.span.finish(.{
        .name = "server.startup.phase",
        .operation = @tagName(phase),
        .outcome = outcome,
        .level = if (failure != null) .err else .info,
        .error_type = if (failure) |err| @errorName(err) else null,
    });
    self.phase = null;
}

pub fn finish(self: *Self, outcome: telemetry.Outcome, failure: ?anyerror) void {
    if (self.total.finished) return;
    self.endPhase(outcome, failure);
    self.total.finish(.{
        .name = "server.startup.complete",
        .outcome = outcome,
        .level = if (failure != null) .err else .info,
        .error_type = if (failure) |err| @errorName(err) else null,
    });
}
