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

pub const Work = enum {
    artifact_validation,
    journal_checkpoint,
    native_query,
    native_capabilities,
    native_submit,
    authorization_query,
    authorization_begin,
    authorization_advance,
    authorization_publish,
    authorization_abandon,
    worker_spawn,
    worker_registration,
    sql_administrator,
    sql_account_prepare,
    sql_account_provision,
    sql_account_discovery,
    sql_catalog_access,
    sql_enrollment,
    sql_initialization,
    sql_activation,
    sql_host_start,
    sql_trust,
};

pub fn submission(command: @import("transit_query").protocol.Growth.Command) Work {
    return switch (command) {
        .authorization => |action| switch (action) {
            .begin => .authorization_begin,
            .advance => .authorization_advance,
            .publish => .authorization_publish,
            .abandon => .authorization_abandon,
        },
        else => .native_submit,
    };
}

pub fn query(kind: @FieldType(@import("transit_query").protocol.Growth.Query, "kind")) Work {
    return switch (kind) {
        .capabilities => .native_capabilities,
        .authorization => .authorization_query,
        else => .native_query,
    };
}

/// Debug-only children attribute sequential work inside a phase or work span. Labels come
/// from closed enums, never requests or configuration. These spans are included
/// in their parent phase, so consumers must not add them to startup elapsed time.
pub fn measure(self: ?*Self, work: Work, comptime operation: anytype, args: anytype) @TypeOf(@call(.auto, operation, args)) {
    var observation: Observation = .{ .span = .{}, .event = .{
        .name = "server.startup.work",
        .operation = @tagName(work),
        .level = .debug,
    } };
    const parent = if (self) |s| s.work_parent else null;
    if (self) |s| if (!s.total.finished and s.runtime.config.level == .debug) {
        observation.span = s.runtime.begin(.service, s.work_parent orelse s.span.context);
        s.work_parent = observation.span.context;
    };
    defer {
        if (self) |s| s.work_parent = parent;
    }
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
// Startup runs on the supervisor's single control flow. Concurrent startup work
// must carry explicit contexts rather than sharing this scoped parent.
work_parent: ?telemetry.Context = null,

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
