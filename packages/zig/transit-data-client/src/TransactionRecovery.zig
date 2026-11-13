//! Explicit local journal for one shared transaction context. Immutable Begin
//! and settlement identities survive process replacement; progress uses CAS.
const std = @import("std");
const c = @import("transit_catalog");
const p = c.protocol;
const Transaction = @import("Transaction.zig");
const Store = @import("LocalRecoveryStore.zig");
const Self = @This();
const Original = struct {
    definition: p.Growth.Definition,
    begin: c.DirectTransactionRequest.Begin,
    settlement: p.DataLifecycle.Operation,
};
const Progress = struct {
    last_statement: u64,
    statement: ?c.DirectTransactionWorkspace.StatementWork,
    last_control: u64,
    control: ?c.DirectTransactionSavepoint.Request,
    command: ?c.DirectTransactionControl.Command,
};

allocator: std.mem.Allocator,
store: *Store,
buffer: []u8,
identity: ?Store.Key = null,
revision: u64 = 0,
original_digest: [32]u8 = undefined,
progress_digest: [32]u8 = undefined,

pub fn init(allocator: std.mem.Allocator, store: *Store) !Self {
    return .{ .allocator = allocator, .store = store, .buffer = try allocator.alloc(u8, store.buffer.len) };
}
pub fn deinit(self: *Self) void {
    std.crypto.secureZero(u8, self.buffer);
    self.allocator.free(self.buffer);
    self.* = undefined;
}
pub fn key(begin: c.DirectTransactionRequest.Begin) !Store.Key {
    try begin.validate();
    return p.Json.hashBounded("transit.client.transaction.key.v1\x00", begin.key, 4096);
}
fn original(state: Transaction.State) Original {
    return .{ .definition = p.Growth.current_definition, .begin = state.begin, .settlement = state.settlement };
}
fn encode(self: *Self, value: anytype) ![]const u8 {
    var writer: std.Io.Writer = .fixed(self.buffer);
    var encoder: std.json.Stringify = .{ .writer = &writer };
    p.Json.write(value, &encoder) catch return error.RecoveryRecordCapacity;
    return writer.buffered();
}
fn journal(self: *Self) Transaction.Journal {
    return .{ .context = self, .save = save };
}
/// Persists the original before returning an owned context. An existing record
/// is loaded with its current progress; create never resets accepted work.
pub fn create(self: *Self, state: Transaction.State) !Transaction {
    if (self.identity != null) return error.RecoveryAdapterBound;
    try state.validate();
    if (state.last_statement != 0 or state.statement != null or state.last_control != 0 or state.control != null or state.command != null)
        return error.InvalidTransactionSession;
    const identity = try key(state.begin);
    _ = try self.store.insert(identity, try self.encode(original(state)));
    return self.load(identity);
}
/// The returned context owns its target slice independently of this adapter's
/// buffers. Reload after uncertain local publication; never synthesize progress.
pub fn load(self: *Self, identity: Store.Key) !Transaction {
    if (self.identity) |bound| if (!std.mem.eql(u8, &bound, &identity)) return error.RecoveryAdapterBound;
    const record = try self.store.get(identity, self.buffer) orelse return error.RecoveryRecordMissing;
    const parsed = try p.Json.parseFromSliceOwned(Original, self.allocator, record.original);
    defer parsed.deinit();
    const value = parsed.value;
    if (value.definition != p.Growth.current_definition or !std.mem.eql(u8, &identity, &try key(value.begin))) return error.RecoveryKeyConflict;
    var state: Transaction.State = .{ .begin = value.begin, .settlement = value.settlement };
    if (record.evidence.len != 0) {
        const progress = try p.Json.parseFromSliceOwned(Progress, self.allocator, record.evidence);
        defer progress.deinit();
        state.last_statement = progress.value.last_statement;
        state.statement = progress.value.statement;
        state.last_control = progress.value.last_control;
        state.control = progress.value.control;
        state.command = progress.value.command;
    }
    const digest = try p.Json.hashBounded("transit.client.transaction.original.v1\x00", value, self.buffer.len);
    const progress_digest = try p.Json.hashBounded("transit.client.transaction.progress.v1\x00", progressOf(state), self.buffer.len);
    const result = try Transaction.init(self.allocator, state, self.journal());
    self.identity = identity;
    self.revision = record.revision;
    self.original_digest = digest;
    self.progress_digest = progress_digest;
    return result;
}
fn save(raw: *anyopaque, previous: Transaction.State, state: Transaction.State, _: Transaction.Event) !void {
    const self: *Self = @ptrCast(@alignCast(raw));
    try state.validate();
    const identity = self.identity orelse return error.RecoveryRecordMissing;
    if (!std.mem.eql(u8, &identity, &try key(state.begin)) or
        !std.mem.eql(u8, &self.original_digest, &try p.Json.hashBounded("transit.client.transaction.original.v1\x00", original(state), self.buffer.len)))
        return error.RecoveryKeyConflict;
    if (!std.mem.eql(u8, &self.progress_digest, &try p.Json.hashBounded("transit.client.transaction.progress.v1\x00", progressOf(previous), self.buffer.len)))
        return error.RecoveryRevisionConflict;
    const progress = progressOf(state);
    const digest = try p.Json.hashBounded("transit.client.transaction.progress.v1\x00", progress, self.buffer.len);
    self.revision = try self.store.update(identity, self.revision, try self.encode(progress));
    self.progress_digest = digest;
}

fn progressOf(state: Transaction.State) Progress {
    return .{ .last_statement = state.last_statement, .statement = state.statement, .last_control = state.last_control, .control = state.control, .command = state.command };
}
