//! Transit vocabulary only. No core, storage, Board or deployment dependencies.
const std = @import("std");
pub const telemetry = @import("telemetry");
const protocol = @import("transit_protocol");
pub const Kind = enum { client_request, storage_operation, maintenance_step, delivery_step, recovery, runtime_step, provider_operation, caller_turn, caller_activation };
pub const Observation = struct {
    span: telemetry.Span,
    event: telemetry.Event,

    pub fn fail(self: *Observation, err: anyerror) void {
        self.event.level = .warn;
        self.event.error_type = @errorName(err);
        self.event.outcome = switch (err) {
            error.AuthorityTimeout, error.MaintenanceTimeout, error.Timeout => .timeout,
            error.Canceled => .canceled,
            error.Conflict => .conflict,
            error.AccessDenied, error.Rejected, error.Forbidden, error.Unauthorized => .rejected,
            else => .failed,
        };
    }
    pub fn finish(self: *Observation) void {
        self.span.finish(self.event);
    }
};

pub fn begin(runtime: ?*telemetry.Runtime, kind: Kind, operation: ?[]const u8, parent: ?telemetry.Context) Observation {
    const scope: telemetry.Scope = switch (kind) {
        .client_request => .client,
        .storage_operation, .recovery => .storage,
        .maintenance_step, .delivery_step => .maintenance,
        .runtime_step, .provider_operation => .runtime,
        .caller_turn, .caller_activation => .application,
    };
    const name = switch (kind) {
        .client_request => "transit.client.request",
        .storage_operation => "transit.storage.operation",
        .maintenance_step => "transit.maintenance.step",
        .delivery_step => "transit.delivery.step",
        .recovery => "transit.recovery",
        .runtime_step => "transit.runtime.step",
        .provider_operation => "transit.provider.operation",
        .caller_turn => "transit.caller.turn",
        .caller_activation => "transit.caller.activation",
    };
    return .{ .span = telemetry.begin(runtime, scope, parent), .event = .{ .name = name, .operation = operation, .level = if (kind == .client_request or kind == .storage_operation or kind == .provider_operation) .debug else .info } };
}

/// Supply only after authorization, or for the caller's own accepted receipt.
pub fn pid(command: protocol.Command) ?u64 {
    return switch (command) {
        .lifecycle => |c| protocol.Lifecycle.pid(c),
        .inspect, .terminate, .expire => |value| value,
        inline else => |value| switch (@typeInfo(@TypeOf(value))) {
            .@"struct" => if (@hasField(@TypeOf(value), "pid")) value.pid else null,
            else => null,
        },
    };
}

test "transport timeout is distinct from known receipt and rejection" {
    var observation = begin(null, .client_request, "turn", null);
    observation.event.protocol_outcome = .uncertain;
    observation.fail(error.AuthorityTimeout);
    observation.finish();
    try std.testing.expectEqual(telemetry.Outcome.timeout, observation.event.outcome);
    try std.testing.expectEqual(telemetry.ProtocolOutcome.uncertain, observation.event.protocol_outcome);
}
