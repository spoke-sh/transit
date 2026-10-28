//! Database-owned captured-request sequencing. Complete saved submissions are
//! published before dispatch; a source lane retains the original uncertain send.
const std = @import("std");
const g = @import("root.zig");
const c = g.catalog;
const p = c.protocol;
const ops = g.SessionOperations;
pub const State = ops.Capture;
const Lane = struct { owner: u64, number: u64, saved: c.DirectRecord.Reference, input: u64 };
const lane_format: u32 = 0x53514c31;
const LaneState = struct { state: c.DirectClientToken.Progress, value: ?Lane };
const internalAccount = g.database.AccountIdentity.internal;
fn lane(source: *g.Client.Source, item: ops.External, create: bool) !?LaneState {
    const caller = source.client.table(item.binding());
    const account = internalAccount(source.client.execution.configuration.account, "captured-source", &item.source);
    const key: c.DirectClientToken.Key = .{ .definition = p.Growth.current_definition, .connection = caller.connection, .account = account, .token = @splat(0) };
    var found = try c.DirectClientToken.inspect(caller, key);
    if (found == null) {
        if (!create) return null;
        const record = try c.DirectRecord.stage(caller, account, lane_format, &item.source);
        const accepted = try c.DirectClientToken.bind(caller, .{ .key = key, .fingerprint = item.source, .intent = .{ .external = .{ .connection = caller.connection, .namespace = item.namespace, .operation = (std.mem.readInt(u64, account[0..8], .little) % p.max_counter) + 1, .record = record } } });
        found = try c.DirectClientToken.inspect(caller, accepted.binding.key);
    }
    const current = found orelse return error.MissingGatewayOperation;
    return .{ .state = current, .value = if (current.record) |record| try ops.decode(Lane, source, record) else null };
}
fn saveLane(source: *g.Client.Source, current: LaneState, value: ?Lane) !void {
    const caller = source.direct(current.state);
    var record: ?c.DirectRecord.Reference = null;
    if (value) |selected| {
        const bytes = try p.Json.valueAlloc(caller.allocator, selected);
        defer caller.allocator.free(bytes);
        record = try c.DirectRecord.stage(caller, current.state.receipt.binding.key.account, lane_format, bytes);
    }
    _ = try c.DirectClientToken.update(caller, .{ .key = current.state.receipt.binding.key, .expected = current.state.revision, .pending = true, .cancel = false, .record = record });
}
pub fn state(execution: g.DatabaseAccount, source: *g.Client.Source, id: u64) !State {
    const item = try ops.external(execution, source, id);
    const operation = try source.operation(id);
    var result = (try ops.progress(source, operation)).capture;
    result.cancel = @intFromBool(operation.cancel);
    const current = (try lane(source, item, false)) orelse return result;
    if (current.value) |value| if (value.owner == id and value.number > result.records) {
        result.records = value.number;
        result.pending = value.number;
        result.input = value.input;
        result.saved = value.saved;
    };
    return result;
}
/// A complete request competes for one durable source lane. Losing the CAS
/// cannot dispatch its request and cannot replace the winner's saved bytes.
pub fn publish(source: *g.Client.Source, id: u64, number: u64, format: u32, bytes: []const u8) !void {
    const item = try ops.external(source.client.execution, source, id);
    if (item.kind != .captured or item.phase != .ready or number < 2 or number > 1024 or format != g.query.SavedSubmission.format) return error.InvalidSavedQuerySubmission;
    const own = try source.operation(id);
    const progress = try ops.progress(source, own);
    if (number != progress.capture.records + 1) return error.GatewayUnresolvedStep;
    if (item.reservation < 512 or progress.capture.stored > item.reservation - 512 or bytes.len > item.reservation - 512 - progress.capture.stored) return error.GatewayRecordTooLarge;
    var current = (try lane(source, item, true)) orelse return error.GatewayUnresolvedStep;
    if (current.value) |value| {
        const owner_state = try source.operation(value.owner);
        const owner_progress = try ops.progress(source, owner_state);
        if (owner_progress.capture.records < value.number) return error.SqlSourceBusy;
        try saveLane(source, current, null);
        current = (try lane(source, item, false)) orelse return error.GatewayUnresolvedStep;
    }
    const caller = source.direct(own);
    const record = try c.DirectRecord.stage(caller, own.receipt.binding.key.account, format, bytes);
    try saveLane(source, current, .{ .owner = id, .number = number, .saved = record, .input = 0 });
}
pub fn readBytes(allocator: std.mem.Allocator, source: *g.Client.Source, id: u64, number: u64, maximum: usize) ![]u8 {
    const operation = try source.operation(id);
    const initial = try ops.readInitial(source, operation);
    const reference = if (number == 1) initial.body orelse return error.InvalidQueryBundle else (try state(source.client.execution, source, id)).saved orelse return error.GatewayUnresolvedStep;
    if (reference.content.bytes > maximum) return error.GatewayRecordTooLarge;
    return c.DirectRecord.read(allocator, source.direct(operation), reference);
}
pub fn busy(source: *g.Client.Source, item: ops.External) !bool {
    const current = (try lane(source, item, false)) orelse return false;
    const value = current.value orelse return false;
    if (value.owner == item.id) return false;
    const owner = try source.operation(value.owner);
    return (try ops.progress(source, owner)).capture.records < value.number;
}
pub fn receipt(source: *g.Client.Source, id: u64, number: u64, input: u64) !void {
    const item = try ops.external(source.client.execution, source, id);
    const current = (try lane(source, item, false)) orelse return error.GatewayUnresolvedStep;
    var value = current.value orelse return error.GatewayUnresolvedStep;
    if (value.owner != id or value.number != number or input == 0 or (value.input != 0 and value.input != input)) return error.InvalidCapturedQueryReceipt;
    value.input = input;
    try saveLane(source, current, value);
}
pub fn processed(source: *g.Client.Source, id: u64, number: u64, rejected: u8) !void {
    const item = try ops.external(source.client.execution, source, id);
    const current = (try lane(source, item, false)) orelse return error.GatewayUnresolvedStep;
    const value = current.value orelse return error.GatewayUnresolvedStep;
    if (value.owner != id or value.number != number or value.input == 0 or rejected > 1) return error.InvalidCapturedQueryReceipt;
    const operation = try source.operation(id);
    var progress = try ops.progress(source, operation);
    if (progress.capture.records < number) {
        progress.capture.records = number;
        progress.capture.stored += value.saved.content.bytes;
        progress.capture.rejected = rejected;
        _ = try ops.save(source, operation, progress, true, operation.cancel);
    }
    try saveLane(source, current, null);
}
