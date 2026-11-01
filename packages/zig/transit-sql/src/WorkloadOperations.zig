//! SQL projections of original native workload outcomes. Catalog owns tokens;
//! Stream/Queue owners own acceptance, closures and current authorization.
const std = @import("std");
const g = @import("root.zig");
const c = g.catalog;
const w = c.DirectTableProtocol;
const Intent = c.DirectWorkloadIntent;

pub fn supported(reference: Intent.Reference) bool {
    return switch (reference.binding) {
        .stream => |value| value.kind == .append or value.kind == .consume or value.kind == .offset,
        .queue => |value| value.kind == .enqueue or value.kind == .claim or value.kind == .settle,
    };
}
pub fn command(work: Intent.Work) !g.results.Command {
    return switch (work) {
        .stream => |value| switch (value.work) {
            .append => .produce,
            .consume => .consume,
            .offset => .commit_offset,
            else => error.UnsupportedSqlWorkload,
        },
        .queue => |value| switch (value.work) {
            .enqueue => .enqueue,
            .claim => .claim,
            .settle => |request| switch (request.action) {
                .ack => .ack,
                .nack => .nack,
                .extend => .extend_lease,
            },
            else => error.UnsupportedSqlWorkload,
        },
    };
}
fn load(caller: c.DirectTableClient, state: c.DirectClientToken.Progress) !Intent {
    if (state.receipt.binding.intent != .workload) return error.WorkloadOperationRequired;
    const reference = state.receipt.binding.intent.workload;
    if (!std.meta.eql(reference.connection, caller.connection)) return error.CatalogIdentityConflict;
    if (!supported(reference)) return error.UnsupportedSqlWorkload;
    const bytes = try c.DirectRecord.read(caller.allocator, caller, reference.record);
    defer caller.allocator.free(bytes);
    var intent = try Intent.restore(caller.allocator, bytes);
    errdefer intent.deinit();
    try reference.requireSame(try intent.reference(state.receipt.binding.key.account));
    return intent;
}
fn call(caller: c.DirectTableClient, work: Intent.Work, action: enum { inspect, execute, cancel }) !std.json.Parsed(w.Response) {
    return caller.call(switch (work) {
        .stream => |value| .{ .stream = switch (action) {
            .inspect => .{ .operation = value.work },
            .execute => .{ .mutate = value },
            .cancel => .{ .cancel = value.work },
        } },
        .queue => |value| .{ .queue = switch (action) {
            .inspect => .{ .operation = value.work },
            .execute => .{ .mutate = value },
            .cancel => .{ .cancel = value.work },
        } },
    });
}
pub fn evidence(reference: Intent.Reference, work: Intent.Work, result: w.Result) !?g.results.Workload.Evidence {
    var value: g.results.Workload.Evidence = .{ .intent = reference.record.content, .binding = reference.binding, .receipt = undefined };
    switch (work) {
        .stream => |input| {
            if (result != .stream) return error.InvalidWorkloadEvidence;
            if (result.stream == .recovering) return null;
            if (result.stream != .operation) return error.InvalidWorkloadEvidence;
            const receipt = result.stream.operation orelse return null;
            try c.DirectStreamResponse.requireReceipt(input.work, receipt);
            value.receipt = switch (receipt) {
                .append => |v| .{ .append = v },
                .consume => |v| .{ .consume = v },
                .offset => |v| .{ .offset = .{ .request = input.work.offset, .receipt = v } },
                .closed => |v| .{ .closed = v },
                else => return error.UnsupportedSqlWorkload,
            };
        },
        .queue => |input| {
            if (result != .queue) return error.InvalidWorkloadEvidence;
            if (result.queue == .recovering) return null;
            if (result.queue != .operation) return error.InvalidWorkloadEvidence;
            const receipt = result.queue.operation orelse return null;
            try c.DirectQueueResponse.requireReceipt(input.work, receipt);
            value.receipt = switch (receipt) {
                .enqueue => |v| .{ .append = v },
                .claim => |v| .{ .claim = v },
                .settle => |v| .{ .settle = v },
                .closed => |v| .{ .closed = v },
                else => return error.UnsupportedSqlWorkload,
            };
        },
    }
    try value.validate(try command(work));
    return value;
}
/// At most one observation and one original mutation per recovery turn. Missing
/// receipts and owner replay progress remain pending. Token settlement rechecks
/// the native owner through Catalog's existing terminal-evidence gate.
pub fn advance(caller: c.DirectTableClient, state: c.DirectClientToken.Progress) !bool {
    if (!state.pending) return false;
    var intent = try load(caller, state);
    defer intent.deinit();
    const reference = state.receipt.binding.intent.workload;
    const work = intent.parsed.value.work;
    const observed = try call(caller, work, .inspect);
    defer observed.deinit();
    if (try evidence(reference, work, observed.value.result) == null) {
        const response = try call(caller, work, if (state.cancel) .cancel else .execute);
        defer response.deinit();
        if (try evidence(reference, work, response.value.result) == null) return true;
    }
    _ = try c.DirectClientToken.update(caller, .{ .key = state.receipt.binding.key, .expected = state.revision, .pending = false, .cancel = state.cancel, .record = state.record });
    return false;
}
pub fn status(caller: c.DirectTableClient, state: c.DirectClientToken.Progress) !g.session_protocol.Operation {
    var intent = try load(caller, state);
    defer intent.deinit();
    const response = try call(caller, intent.parsed.value.work, .inspect);
    defer response.deinit();
    const terminal = try evidence(state.receipt.binding.intent.workload, intent.parsed.value.work, response.value.result);
    if (!state.pending and terminal == null) return error.MissingGatewayTerminal;
    const kind = try command(intent.parsed.value.work);
    const counts = if (terminal) |value| value.counts(kind) else null;
    const result: g.session_protocol.Operation = .{
        .identity = .{ .account = state.receipt.binding.key.account, .id = state.id(), .kind = .workload },
        .command = kind,
        .token = state.receipt.binding.key.token,
        .phase = if (terminal != null) .terminal else .ready,
        .cancellation_requested = state.cancel,
        .outcome = if (terminal) |value| value.outcome() else null,
        .matched = if (counts) |value| value.matched else 0,
        .changed = if (counts) |value| value.changed else 0,
        .result_kind = if (intent.parsed.value.projection != null and (terminal == null or terminal.?.outcome() == .applied)) .rows else .command,
        .workload = terminal,
    };
    try result.validate();
    return result;
}
