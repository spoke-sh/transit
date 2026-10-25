//! Executable projections for the semantic coverage manifest. No authority or I/O
//! beyond the bounded JSON-lines report; recovery proofs remain separate.
const std = @import("std");
const q = @import("transit_query");
const a = @import("transit_station_app");
const c = @import("transit_catalog");
const s = @import("transit_serving");
const x = @import("transit_exchange");
const p = q.protocol;
const d = p.Diagnostic;

fn emit(out: *std.Io.Writer, family: []const u8, variant: []const u8, detail: d) !void {
    return emitScenario(out, family, variant, "default", detail);
}
fn emitScenario(out: *std.Io.Writer, family: []const u8, variant: []const u8, scenario: []const u8, detail: d) !void {
    return emitTransport(out, family, variant, scenario, detail, null);
}
fn emitTransport(out: *std.Io.Writer, family: []const u8, variant: []const u8, scenario: []const u8, detail: d, transport_status: ?u16) !void {
    try detail.validate();
    const Fact = struct { field: d.Field, origin: d.Origin, availability: d.Availability };
    var facts: [16]?Fact = @splat(null);
    for (detail.facts, 0..) |slot, index| if (slot) |fact| {
        facts[index] = .{ .field = fact.field, .origin = fact.origin, .availability = fact.availability };
    };
    try std.json.Stringify.value(.{ .family = family, .variant = variant, .scenario = scenario, .code = detail.code.slice(), .category = detail.category, .stage = detail.stage, .outcome = detail.outcome, .evidence = detail.evidence, .identity = detail.identity, .facts = facts, .actions = detail.actions, .transport_status = transport_status }, .{}, out);
    try out.writeByte('\n');
}
fn queries(out: *std.Io.Writer) !void {
    @setEvalBranchQuota(10000);
    inline for (comptime std.meta.tags(q.QueryFailure.Code)) |code| {
        inline for (comptime std.meta.tags(q.QueryFailure.Stage)) |stage| {
            inline for (.{ q.UnifiedRequest.Phase.denied, q.UnifiedRequest.Phase.rejected, q.UnifiedRequest.Phase.retired }) |phase| {
                const failure: q.QueryFailure = .{ .code = code, .stage = stage };
                try emitScenario(out, "query.failure", @tagName(code), comptime @tagName(stage) ++ "." ++ @tagName(phase), try failure.diagnostic(19, phase));
                const flight: @import("transit_flight").Diagnostic = .{ .namespace = 19, .phase = phase, .failure = failure };
                try emitTransport(out, "query.flight_failure", @tagName(code), comptime @tagName(stage) ++ "." ++ @tagName(phase), try flight.structured(), flight.status());
            }
        }
    }
}
fn applicationCallers(out: *std.Io.Writer) !void {
    for (a.Diagnostic.entries) |entry| {
        try emitScenario(out, "application.compiler", @errorName(entry.cause), "parse", try (a.Diagnostic{ .stage = .parse }).structured(entry.cause));
        try emitScenario(out, "application.compiler", @errorName(entry.cause), "output", try (a.Diagnostic{ .stage = .output }).structured(entry.cause));
    }
    const config: a.Host.Config = .{ .scope = .{ .realm = 1, .application = 2, .pid = 3, .resource = 4, .namespace = .{ .value = 5 } } };
    const signed: a.Native.Signed = .{ .prepared = try a.Native.prepare(config.scope, 6, .{ .value = 7 }, .initialize), .signature = @splat(0) };
    for (a.HostDiagnostic.entries) |entry| {
        try emitScenario(out, "application.host", @errorName(entry.cause), "read", try a.HostDiagnostic.attempt(config, .info, entry.cause, false, null));
        try emitScenario(out, "application.host", @errorName(entry.cause), "dispatched", try a.HostDiagnostic.attempt(config, .{ .submit = signed }, entry.cause, true, null));
    }
}
fn serving(out: *std.Io.Writer) !void {
    inline for (comptime std.meta.tags(s.Model.Phase)) |phase| {
        const record: s.Model.Operation = .{ .principal = 9, .operation = 19, .binding = 1, .codec = 1, .deadline_ms = 1000, .digest = @splat(1), .target = 2, .correlation = 11, .policy_revision = 1, .phase = phase, .resolution_input = if (phase == .admitted) 0 else 12, .result = if (phase == .completed) try p.Value.init("reply") else .{}, .reply_bytes = if (phase == .completed) 5 else if (phase == .failed) s.station.Frame.max_payload else 0 };
        try emit(out, "serving.phase", @tagName(phase), try s.OperationDiagnostic.project(1, 2, 7, record));
    }
    inline for (comptime std.meta.tags(s.ServingFailure.Reason)) |reason| {
        try emit(out, "serving.input", @tagName(reason), try s.ServingFailure.project(1, 7, 2, .{ .reason = reason, .input = 11, .kind = .service, .subject = 19, .generation = 0, .payload = @splat(1), .cause = try p.Value.init(@tagName(reason)), .witness = .none }));
    }
}
fn capture(out: *std.Io.Writer) !void {
    inline for (comptime std.meta.tags(x.Failure.Reason)) |reason| {
        var failure: x.Failure = if (reason == .transport_failure or reason == .capture_failure or reason == .preparation_failure) .failed(reason, error.OriginalFixtureCause) else .{ .reason = reason };
        failure.resource = 7;
        failure.exchange = 19;
        failure.owner = 2;
        failure.principal = 9;
        failure.input = 11;
        if (reason == .preparation_failure) failure.origin_input = 8;
        try emit(out, "exchange.capture", @tagName(reason), try failure.diagnostic(1));
    }
}
fn effects(out: *std.Io.Writer) !void {
    inline for (comptime std.meta.tags(@FieldType(p.Growth.Effect, "phase"))) |phase| {
        var effect: p.Growth.Effect = .{ .id = 2, .pid = 1, .payload = .{}, .max_observations = 2, .phase = phase };
        if (phase == .authorized or phase == .unknown or phase == .observed or phase == .closed_unknown) {
            effect.attempt = 3;
            effect.executor = 4;
            effect.authorization_policy = 1;
        }
        if (phase == .unknown or phase == .observed or phase == .closed_unknown) {
            effect.observations = 1;
            effect.last_observation = .{ .input = 5, .policy_revision = 1 };
        }
        if (phase == .observed) {
            effect.result = .integer(0);
            effect.closed_at = 5;
            effect.closure = .{ .reason = .observed, .principal = 4, .policy_revision = 1 };
        }
        if (phase == .cancelled or phase == .closed_unknown) effect.closed_at = 6;
        if (phase == .cancelled) effect.closure = .{ .reason = .unattempted_cancel, .principal = 0, .policy_revision = 0 };
        if (phase == .closed_unknown) effect.closure = .{ .reason = .abandoned, .principal = 9, .policy_revision = 1 };
        try emit(out, "effect.phase", @tagName(phase), try p.EffectDiagnostic.from(1, 10, effect));
    }
}
fn closures(out: *std.Io.Writer) !void {
    inline for (comptime std.meta.tags(@FieldType(p.Growth.EffectClosure, "reason"))) |reason| {
        var effect: p.Growth.Effect = .{ .id = 2, .pid = 1, .payload = .{}, .max_observations = 2, .phase = .closed_unknown, .attempt = 3, .executor = 4, .authorization_policy = 1, .closed_at = 6, .observations = 1, .last_observation = .{ .input = 6, .policy_revision = 1 }, .closure = .{ .reason = reason, .principal = 4, .policy_revision = 1 } };
        switch (reason) {
            .observed => {
                effect.phase = .observed;
                effect.result = .integer(0);
            },
            .observation_budget => effect.observations = 2,
            .deadline => {
                effect.reconcile_before_ms = 100;
                effect.closure.?.clock_lower_ms = 100;
            },
            .abandoned => {},
            .unattempted_cancel => effect = .{ .id = 2, .pid = 1, .payload = .{}, .phase = .cancelled, .closed_at = 6, .closure = .{ .reason = reason, .principal = 0, .policy_revision = 0 } },
        }
        try emit(out, "effect.closure", @tagName(reason), try p.EffectDiagnostic.from(1, 10, effect));
    }
}
fn refresh(out: *std.Io.Writer) !void {
    var view: s.RefreshModel.View = .{ .principal = 9, .session = .{ .session = 19, .generation = 1 }, .generation = 2, .source = .{ .revision = 1, .audience = 2, .resource = 7, .realm = 1, .catalog = .{ .value = 9 }, .branch = 1, .namespace = 1, .object = .{ .value = 1 }, .interpretation_revision = .{ .value = 1 }, .interpretation_digest = @splat(1) }, .template = .{ .value = 20 }, .namespace = .{ .value = 21 }, .dirty = .{ .value = 11 }, .covered = .{ .value = 10 }, .limit = 8, .starts = 8 };
    inline for (comptime std.meta.tags(s.RefreshFailure.Reason)) |reason| {
        view.failure = s.RefreshFailure.record(12, reason, .{});
        try emit(out, "refresh.stop", @tagName(reason), (try s.RefreshFailure.project(1, 7, view)).?);
    }
}
fn noRead(_: *anyopaque, _: p.Growth.View, _: p.Value) anyerror!?p.Value {
    return error.UnexpectedProjectionRead;
}
fn publications(out: *std.Io.Writer) !void {
    const scope: a.Native.Scope = .{ .realm = 1, .application = 9, .pid = 2, .resource = 7, .namespace = .{ .value = 19 } };
    const proposal: a.Publication.Proposal = .{ .operation = .{ .value = 20 }, .record = .{ .value = 21 }, .expected = .{ .value = 1 }, .expected_digest = @splat(1), .revision = .{ .value = 2 }, .spec = .{ .format = a.Publication.format, .length = 1, .digest = @splat(2) } };
    inline for (comptime std.meta.tags(a.Publication.Phase)) |phase| {
        try emit(out, "publication.phase", @tagName(phase), try a.PublicationDiagnostic.receipt(scope, .{ .proposal = proposal, .phase = phase, .input = 11, .owns_record = true, .conflict_basis = if (phase == .conflict) .absent else .none }));
    }
    var context: u8 = 0;
    const turn = try a.station.Turn.init(.{ .realm = 1, .principal = 9, .pid = 2, .generation = 1, .sequence = 5, .revision = 0, .input = .{ .position = 11, .ordinal = 1, .value = try p.Value.init("proposal"), .origin = .{ .external = .{ .principal = 9, .policy_revision = 1 } } }, .permit = null, .needs_permit = false }, .{ .id = 6, .pid = 2, .principal = 9, .generation = 1, .input = 11, .process_revision = 0, .resource = 7, .revision = 0, .deadline_ms = 100000 }, .{ .context = &context, .read = noRead });
    inline for (comptime std.meta.tags(a.PublicationFailure.Reason)) |reason| {
        const record = try a.PublicationFailure.capture(&turn, .{ .publish = .{ .value = 20 } }, reason, .{});
        try emit(out, "publication.input", @tagName(reason), try a.PublicationFailure.project(scope, record, .none));
    }
}

fn migrations(out: *std.Io.Writer) !void {
    const plan: a.Migration.Plan = .{ .proposal = .{ .plan = .{ .value = 19 }, .expected = .{ .value = 1 }, .next = .{ .value = 2 }, .source = @splat(1), .target = @splat(2), .transform = 1 }, .digest = @splat(3), .principal = 9, .input = 11 };
    inline for (comptime std.meta.tags(a.Migration.Phase)) |phase| {
        try emit(out, "migration.phase", @tagName(phase), try a.MigrationDiagnostic.progress(9, 1, 7, plan, .{ .phase = phase, .next = .{ .value = 2 }, .input = 12 }));
    }
    for (a.MigrationFailure.mappings) |mapping| {
        const record: a.MigrationFailure.Record = .{ .cause = try p.Value.init(mapping.name), .input = 11, .plan = .{ .value = 19 }, .ordinal = .{ .value = 2 }, .operation = 1, .payload = @splat(3) };
        try emit(out, "migration.input", mapping.name, try a.MigrationFailure.project(9, 1, 7, record, .none, a.MigrationFailure.classification(mapping.name).?));
    }
}

fn queryCallers(out: *std.Io.Writer) !void {
    for (@import("diagnostic_cases").query_caller) |cause| {
        try emitScenario(out, "query.caller", @errorName(cause), "read", try q.ApiDiagnostic.project(.{ .status = "19" }, cause, .{}, false, null));
        try emitScenario(out, "query.caller", @errorName(cause), "dispatched", try q.ApiDiagnostic.project(.{ .submit = "saved" }, cause, .{}, true, .{ .domain = .transport, .id = .init(42), .sequence = .init(42) }));
        const board = @import("transit_board_api");
        const read = try q.ApiDiagnostic.project(.{ .status = "19" }, cause, .{}, false, null);
        try emitTransport(out, "query.board", @errorName(cause), "read", read, @backingInt(board.FailureResponse.project(read).status));
        const flight = @import("transit_flight").DiagnosticDetail;
        const status = flight.statusFor(cause);
        try emitTransport(out, "query.flight", @errorName(cause), "read", try flight.attempt(cause, status), status);
    }
}

fn writeCallers(out: *std.Io.Writer) !void {
    const read: c.DirectTableBridge.Action = .{ .lookup = .{ .namespace = 1, .name = "items" } };
    const attempted: c.DirectTableClient.Attempt = .{ .mutation = .{ .action = .admit_saved, .identity = .{ .scope = .{ .realm = 46, .resource = 7, .catalog = 2 }, .principal = 17, .operation = 12 } } };
    for (@import("diagnostic_cases").catalog_caller) |cause| {
        try emitScenario(out, "catalog.caller", @errorName(cause), "read", try c.DirectTableDiagnostic.failure(read, cause, .{}, .{}, null));
        try emitScenario(out, "catalog.caller", @errorName(cause), "dispatched", try c.DirectTableDiagnostic.failure(read, cause, .{}, attempted, null));
    }
}

fn inspections(out: *std.Io.Writer) !void {
    const owner = @import("transit_board_api").InspectionDiagnostic;
    for (@import("diagnostic_cases").board_inspection) |cause| {
        try emitScenario(out, "inspection.caller", @errorName(cause), "read", try owner.project(cause, null));
        try emitScenario(out, "inspection.caller", @errorName(cause), "denied", try owner.project(cause, .AccessDenied));
    }
    inline for (comptime std.meta.tags(p.ErrorCode)) |native| {
        try emit(out, "inspection.native", @tagName(native), try owner.project(error.Rejected, native));
    }
}

fn flightCalls(out: *std.Io.Writer) !void {
    const owner = @import("transit_flight").DiagnosticDetail;
    for (owner.codes.entries) |entry| {
        try emitTransport(out, "flight.rpc", @errorName(entry.cause), "default", try owner.attempt(entry.cause, owner.statusFor(entry.cause)), owner.statusFor(entry.cause));
    }
}

fn servingCallers(out: *std.Io.Writer) !void {
    const owner = s.ServingDiagnostic;
    for (owner.codes.entries) |entry| {
        var attempt: owner.Attempt = .{};
        try attempt.label(.input, "prepare");
        try emitTransport(out, "serving.adapter", @errorName(entry.cause), "input", try attempt.project(entry.cause), attempt.disposition(entry.cause).status);
        try attempt.label(.read, "status");
        try emitTransport(out, "serving.adapter", @errorName(entry.cause), "read", try attempt.project(entry.cause), attempt.disposition(entry.cause).status);
        try attempt.label(.control, "submit");
        attempt.identity = .{ .domain = .transport, .id = .init(12), .realm = .init(46), .sequence = .init(12) };
        attempt.dispatched = true;
        try emitScenario(out, "serving.adapter", @errorName(entry.cause), "dispatched", try attempt.project(entry.cause));
        attempt.receipt = 17;
        try emitScenario(out, "serving.adapter", @errorName(entry.cause), "receipt", try attempt.project(entry.cause));
        attempt.receipt = null;
        attempt.rejected(error.Conflict, .ConflictingRetry);
        try emitScenario(out, "serving.adapter", @errorName(entry.cause), "native_rejected", try attempt.project(entry.cause));
    }
}

pub fn main(init: std.process.Init) !void {
    var buffer: [8192]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    try queries(&stdout.interface);
    try queryPhases(&stdout.interface);
    try serving(&stdout.interface);
    try capture(&stdout.interface);
    try effects(&stdout.interface);
    try closures(&stdout.interface);
    try refresh(&stdout.interface);
    try publications(&stdout.interface);
    try migrations(&stdout.interface);
    try queryCallers(&stdout.interface);
    try writeCallers(&stdout.interface);
    try inspections(&stdout.interface);
    try flightCalls(&stdout.interface);
    try servingCallers(&stdout.interface);
    try applicationCallers(&stdout.interface);
    try stdout.interface.flush();
}

fn queryPhases(out: *std.Io.Writer) !void {
    inline for (comptime std.meta.tags(q.UnifiedRequest.Phase)) |phase| {
        var value: q.UnifiedRequest.Status = .{ .reference = .{ .resource = 7, .domain = .query_request, .namespace = 19, .record = 1, .spec = .{ .format = q.Bundle.format, .length = q.Bundle.header_bytes, .digest = @splat(1) } }, .phase = phase };
        if (phase == .admitted or phase == .complete or phase == .denied or phase == .rejected) value.correlation = 12;
        if (phase == .denied) value.failure = .{ .code = .policy_denied, .stage = .admission };
        if (phase == .rejected) value.failure = .{ .code = .arithmetic_overflow, .stage = .execution };
        if (phase == .complete) value.manifest = .{ .resource = 8, .domain = .query_result, .namespace = 29, .record = q.UnifiedRecords.manifest_record, .spec = .{ .format = q.UnifiedRecords.manifest_format, .length = 1, .digest = @splat(2) } };
        if (try q.Bridge.statusDiagnostic(value)) |detail| {
            try emit(out, "query.phase", @tagName(phase), detail);
        } else {
            try std.json.Stringify.value(.{ .family = "query.phase", .variant = @tagName(phase), .scenario = "default", .absent = true }, .{}, out);
            try out.writeByte('\n');
        }
    }
}
