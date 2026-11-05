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
fn call(caller: c.DirectTableClient, saved: Intent.Saved, action: enum { inspect, execute, cancel }) !std.json.Parsed(w.Response) {
    return caller.call(switch (saved.work) {
        .stream => |value| .{ .stream = switch (action) {
            .inspect => .{ .operation = value.work },
            .execute => if (saved.wait_ms) |milliseconds| .{ .wait = .{ .consume = value.work.consume, .milliseconds = milliseconds } } else .{ .mutate = value },
            .cancel => .{ .cancel = value.work },
        } },
        .queue => |value| .{ .queue = switch (action) {
            .inspect => .{ .operation = value.work },
            .execute => if (saved.wait_ms) |milliseconds| .{ .wait = .{ .claim = value.work.claim, .milliseconds = milliseconds } } else .{ .mutate = value },
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
/// Passive recovery can settle an original receipt or requested cancellation.
/// A saved wait can execute only through a foreground, explicitly requested
/// attempt. A timeout never creates an empty result or closes accepted SQL work.
pub fn advance(caller: c.DirectTableClient, state: c.DirectClientToken.Progress) !bool {
    return (try step(caller, state, .passive)).pending;
}
pub fn attempt(caller: c.DirectTableClient, state: c.DirectClientToken.Progress) !?g.results.Workload.Wait {
    return (try step(caller, state, .explicit)).wait;
}
pub fn initialWait(caller: c.DirectTableClient, state: c.DirectClientToken.Progress) !?g.results.Workload.Wait {
    return (try step(caller, state, .initial_wait)).wait;
}
const Step = struct { pending: bool, wait: ?g.results.Workload.Wait = null };
fn waiting(reference: Intent.Reference, milliseconds: u32) g.results.Workload.Wait {
    return .{ .intent = reference.record.content, .binding = reference.binding, .milliseconds = milliseconds };
}
fn step(caller: c.DirectTableClient, state: c.DirectClientToken.Progress, mode: enum { passive, explicit, initial_wait }) !Step {
    if (!state.pending) return .{ .pending = false };
    var intent = try load(caller, state);
    defer intent.deinit();
    const reference = state.receipt.binding.intent.workload;
    const saved = intent.parsed.value;
    if (mode == .initial_wait and saved.wait_ms == null) return .{ .pending = true };
    const observed = try call(caller, saved, .inspect);
    defer observed.deinit();
    if (try evidence(reference, saved.work, observed.value.result) == null) {
        if (saved.wait_ms != null and mode == .passive and !state.cancel) return .{ .pending = true };
        const response = try call(caller, saved, if (state.cancel) .cancel else .execute);
        defer response.deinit();
        if (saved.wait_ms) |milliseconds| {
            if (!state.cancel) {
                const cut: ?c.protocol.StreamQueue.Cut = switch (saved.work) {
                    .stream => |value| blk: {
                        if (response.value.result != .stream) return error.InvalidWorkloadEvidence;
                        const result = response.value.result.stream;
                        try c.DirectStreamResponse.validate(caller.allocator, caller.connection, .{ .wait = .{ .consume = value.work.consume, .milliseconds = milliseconds } }, result);
                        break :blk if (result == .timed_out) result.timed_out else null;
                    },
                    .queue => |value| blk: {
                        if (response.value.result != .queue) return error.InvalidWorkloadEvidence;
                        const result = response.value.result.queue;
                        try c.DirectQueueResponse.validate(caller.allocator, caller.connection, .{ .wait = .{ .claim = value.work.claim, .milliseconds = milliseconds } }, result);
                        break :blk if (result == .timed_out) result.timed_out else null;
                    },
                };
                if (cut) |timed_out| {
                    var wait = waiting(reference, milliseconds);
                    wait.timed_out = timed_out;
                    return .{ .pending = true, .wait = wait };
                }
            }
        }
        if (try evidence(reference, saved.work, response.value.result) == null) return .{ .pending = true };
    }
    _ = try c.DirectClientToken.update(caller, .{ .key = state.receipt.binding.key, .expected = state.revision, .pending = false, .cancel = state.cancel, .record = state.record });
    return .{ .pending = false };
}
pub fn status(caller: c.DirectTableClient, state: c.DirectClientToken.Progress) !g.session_protocol.Operation {
    var intent = try load(caller, state);
    defer intent.deinit();
    const response = try call(caller, intent.parsed.value, .inspect);
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
        .wait = if (terminal == null and intent.parsed.value.wait_ms != null) waiting(state.receipt.binding.intent.workload, intent.parsed.value.wait_ms.?) else null,
    };
    try result.validate();
    return result;
}
