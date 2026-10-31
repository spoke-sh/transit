//! Exact private read context. A descriptor binds an active accepted workspace;
//! it is neither a durable Table pin nor authority to read without the token.
const std = @import("std");
const c = @import("root.zig");
const d = c.protocol.DataLifecycle;
pub const Context = struct {
    key: c.DirectClientToken.Key,
    revision: d.Position,
    pub fn validate(self: Context) !void {
        try self.key.validate();
        try self.revision.validate();
        if (self.revision.next_lsn == 0) return error.InvalidTransactionRead;
    }
    pub fn allow(self: Context, action: c.DirectTableProtocol.Action) !void {
        try self.validate();
        switch (action) {
            .lookup, .check, .check_set, .read_authority, .pin, .pin_status, .snapshot, .read_key, .scan, .column_scan, .filter_scan, .key_range, .release => {},
            else => return error.UnsupportedTransactionRead,
        }
    }
};

pub fn view(context: Context, head: c.DirectTransactionWorkspace.Head, source: c.protocol.Transaction.StateGuard, state: c.storage.TableWorkspace.State) !c.protocol.Transaction.ReadView {
    try context.validate();
    try state.validate();
    if (!std.meta.eql(context.revision, head.revision) or !std.meta.eql(state.begin, head.acquired.cut.begin)) return error.TransactionReadChanged;
    var bytes: [64 * 1024]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&bytes);
    var encoder: std.json.Stringify = .{ .writer = &writer };
    try c.protocol.Json.write(.{ .context = context, .source = source, .state = state }, &encoder);
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.transaction.private-read.v1\x00");
    hash.update(writer.buffered());
    const result: c.protocol.Transaction.ReadView = .{ .cut = head.acquired.cut, .revision = head.revision, .last_statement = head.last_statement, .source = source, .private_position = .{ .partition = state.root.partition, .next_lsn = state.root.next_lsn }, .private = .{ .bytes = writer.buffered().len, .sha256 = hash.finalResult() } };
    try result.validate();
    return result;
}

/// One request owns every private Table/cache allocation. Output has the normal
/// transport budget; no workspace owner or borrowed context survives dispatch.
pub fn apply(output: std.mem.Allocator, catalog: *c.DirectCatalog, policy: c.DirectCatalog.Policy, context: Context, action: c.DirectTableProtocol.Action, execution: c.DirectTableDispatch.Execution) anyerror!c.DirectTableProtocol.Result {
    try context.allow(action);
    const head = try catalog.transactionReadHead(context, policy);
    var memory: c.fuze.MemoryBudget = .{ .parent = catalog.allocator, .limit = @intCast(head.acquired.cut.begin.limits.resident_bytes) };
    const parent = catalog.allocator;
    const retained = catalog.options.table_owner;
    const previous = catalog.transaction_read;
    catalog.allocator = memory.allocator();
    catalog.options.table_owner = null;
    catalog.transaction_read = context;
    defer {
        catalog.allocator = parent;
        catalog.options.table_owner = retained;
        catalog.transaction_read = previous;
        std.debug.assert(memory.used == 0);
    }
    return c.DirectTableDispatch.apply(output, catalog, policy, action, null, execution) catch |err| return if (err == error.OutOfMemory and memory.exhausted) error.TransactionMemoryLimit else err;
}
