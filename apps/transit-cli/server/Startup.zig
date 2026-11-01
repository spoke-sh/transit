//! Bounded startup observations; never readiness or recovery authority.
const std = @import("std");
const telemetry = @import("transit_query").wire.observability.telemetry;
const Observation = @import("transit_query").wire.observability.Observation;
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

pub const Work = enum { artifact_validation, journal_checkpoint, native_query, native_submit, worker_spawn, worker_registration };

/// Debug-only children attribute sequential work inside a phase. Labels come
/// from closed enums, never requests or configuration. These spans are included
/// in their parent phase, so consumers must not add them to startup elapsed time.
pub fn measure(self: ?*Self, work: Work, comptime operation: anytype, args: anytype) @TypeOf(@call(.auto, operation, args)) {
    var observation: Observation = .{ .span = .{}, .event = .{
        .name = "server.startup.work",
        .operation = @tagName(work),
        .level = .debug,
    } };
    if (self) |s| if (!s.total.finished and s.runtime.config.level == .debug) {
        observation.span = s.runtime.begin(.service, s.span.context);
    };
    defer observation.finish();
    return @call(.auto, operation, args) catch |err| {
        observation.fail(err);
        return err;
    };
}

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
