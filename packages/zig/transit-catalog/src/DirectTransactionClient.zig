//! Explicit signed transaction calls. Persist the original token and operation
//! identities before mutation. No method substitutes a retry identity or turns
//! a transport error into rejection; inspect and resume the original work.
const std = @import("std");
const c = @import("root.zig");
const w = c.DirectTransactionRequest;
const Self = @This();
catalog: c.DirectTableClient,

pub fn advanceCall(self: Self, key: c.DirectClientToken.Key, steps: u16, control: bool, cancel: bool) !?c.DirectTransactionCall.Result {
    return (try self.call(.{ .call = .{ .key = key, .steps = steps, .control = control, .cancel = cancel } })).call;
}
pub fn callOutcome(self: Self, key: c.DirectClientToken.Key) !?c.DirectTransactionCall.Result {
    return (try self.call(.{ .call_outcome = key })).call;
}
pub fn begin(self: Self, request: w.Begin) !c.DirectClientToken.Receipt {
    return (try self.call(.{ .begin = request })).begun;
}
pub fn acquire(self: Self, key: c.DirectClientToken.Key) !c.DirectTransaction.Acquired {
    return (try self.call(.{ .acquire = key })).acquired;
}
pub fn inspect(self: Self, key: c.DirectClientToken.Key) !c.DirectTransactionControl.Status {
    return (try self.call(.{ .inspect = key })).status;
}
pub fn stage(self: Self, key: c.DirectClientToken.Key, basis: c.protocol.DataLifecycle.Position, sequence: u64, work: c.DirectTableIntent.Work) !c.DirectTransactionWorkspace.Request {
    return (try self.call(.{ .stage = .{ .key = key, .basis = basis, .sequence = sequence, .work = work } })).staged;
}

pub fn stageKV(self: Self, key: c.DirectClientToken.Key, basis: c.protocol.DataLifecycle.Position, sequence: u64, work: c.DirectKV.Mutation) !c.DirectTransactionWorkspace.Request {
    return (try self.call(.{ .stage_kv = .{ .key = key, .basis = basis, .sequence = sequence, .work = work } })).staged;
}
pub fn stageLog(self: Self, key: c.DirectClientToken.Key, basis: c.protocol.DataLifecycle.Position, sequence: u64, work: c.DirectTransactionLogWork.Work, payload: ?c.DirectTableProtocol.Binary) !c.DirectTransactionLogWork.Request {
    return (try self.call(.{ .stage_log = .{ .key = key, .basis = basis, .sequence = sequence, .work = work, .payload = payload } })).staged_log;
}
pub fn admitLog(self: Self, key: c.DirectClientToken.Key, request: c.DirectTransactionLogWork.Request) !?c.DirectTransactionLogWork.Outcome {
    return (try self.call(.{ .log_statement = .{ .key = key, .request = request, .execute = false } })).log_statement;
}
pub fn executeLog(self: Self, key: c.DirectClientToken.Key, request: c.DirectTransactionLogWork.Request) !c.DirectTransactionLogWork.Outcome {
    return (try self.call(.{ .log_statement = .{ .key = key, .request = request, .execute = true } })).log_statement.?;
}
pub fn logOutcome(self: Self, key: c.DirectClientToken.Key, request: c.DirectTransactionLogWork.Request) !?c.DirectTransactionLogWork.Outcome {
    return (try self.call(.{ .log_outcome = .{ .key = key, .request = request } })).log_statement;
}
pub fn admit(self: Self, key: c.DirectClientToken.Key, request: c.DirectTransactionWorkspace.Request) !?c.storage.TableWorkspace.Outcome {
    return (try self.call(.{ .statement = .{ .key = key, .request = request, .execute = false } })).statement;
}
pub fn execute(self: Self, key: c.DirectClientToken.Key, request: c.DirectTransactionWorkspace.Request) !c.storage.TableWorkspace.Outcome {
    return (try self.call(.{ .statement = .{ .key = key, .request = request, .execute = true } })).statement.?;
}
/// Advance preparation or cleanup by at most steps participants. The returned
/// decision is final; cleanup_complete separately reports pin/barrier release.
pub fn advance(self: Self, key: c.DirectClientToken.Key, steps: u16) !c.DirectTransactionControl.Status {
    return (try self.call(.{ .advance = .{ .key = key, .steps = steps } })).status;
}
pub fn statementOutcome(self: Self, key: c.DirectClientToken.Key, request: c.DirectTransactionWorkspace.Request) !?c.storage.TableWorkspace.Outcome {
    return (try self.call(.{ .statement_outcome = .{ .key = key, .request = request } })).statement;
}
pub fn savepointOutcome(self: Self, key: c.DirectClientToken.Key, request: c.DirectTransactionSavepoint.Request) !?c.DirectTransactionSavepoint.Result {
    return (try self.call(.{ .savepoint_outcome = .{ .key = key, .request = request } })).savepoint_outcome;
}
pub fn savepoint(self: Self, key: c.DirectClientToken.Key, request: c.DirectTransactionSavepoint.Request, steps: u16) !c.DirectTransactionSavepoint.Result {
    return (try self.call(.{ .savepoint = .{ .key = key, .request = request, .steps = steps } })).savepoint;
}
pub fn settle(self: Self, key: c.DirectClientToken.Key, operation: c.protocol.DataLifecycle.Operation, command: c.DirectTransactionControl.Command, steps: u16) !c.DirectTransactionControl.Status {
    return (try self.call(.{ .settle = .{ .key = key, .operation = operation, .command = command, .steps = steps } })).status;
}
fn call(self: Self, request: w.Request) !w.Result {
    try request.validate();
    if (!std.meta.eql(request.key().connection, self.catalog.connection)) return error.CatalogIdentityConflict;
    var caller = self.catalog;
    caller.transaction = null;
    const response = try caller.call(.{ .transaction = request });
    defer response.deinit();
    // Result contains only owned fixed-size values, no response-arena slices.
    return response.value.result.transaction;
}
