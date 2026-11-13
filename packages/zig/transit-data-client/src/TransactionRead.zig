//! Shared private reads. Context admission owns I/O only for the duration of a
//! call; readers and returned values own their memory independently.
const std = @import("std");
const c = @import("transit_catalog");
const Native = c.DirectTransactionReader;
pub const Owner = struct { context: *anyopaque, slot: usize, serial: u64 };
pub const TableReader = struct {
    native: Native,
    owner: ?Owner,
    busy: std.atomic.Value(bool) = .init(false),

    /// Join active calls first. Local disposal never releases transaction pins.
    pub fn deinit(self: *TableReader) void {
        std.debug.assert(!self.busy.load(.acquire));
        self.native.deinit();
        self.* = undefined;
    }
};
pub const Command = union(enum) {
    describe,
    next: c.storage.TablePartition.ReadLimits,
    key: []const c.fuze.Types.Values.Cell,
};
pub const Action = union(enum) {
    kv: Native.KV,
    open_table: struct { allocator: std.mem.Allocator, table: Native.Table },
    table: struct { reader: *TableReader, command: Command },
};
pub const Result = union(enum) {
    kv: c.DirectKVClient.Read,
    opened: TableReader,
    description: Native.Description,
    batch: ?c.DirectTableReader.Batch,
    row: ?c.fuze.TableRow.Owned,
};

/// The transaction owner holds its exclusive call guard across this function.
/// Output owns values/schema copies, while open_table uses its explicit retained
/// allocator. Neither allocator may die while its returned values are live.
pub fn apply(state: c.DirectTransactionSession.State, client: c.DirectTableClient, output: *std.heap.ArenaAllocator, action: Action, owner: ?Owner) !Result {
    try state.validate();
    if (state.statement != null or state.control != null) return error.TransactionSessionPending;
    if (state.command != null) return error.TransactionSessionSettling;
    if (!std.meta.eql(state.begin.key.connection, client.connection)) return error.CatalogIdentityConflict;
    return switch (action) {
        .kv => |request| .{ .kv = try Native.get(output, client, state.begin.key, request) },
        .open_table => |request| .{ .opened = .{ .native = try Native.open(request.allocator, client, state.begin.key, request.table), .owner = owner } },
        .table => |request| blk: {
            const reader = request.reader;
            if (reader.busy.swap(true, .acquire)) return error.Busy;
            defer reader.busy.store(false, .release);
            if (!std.meta.eql(reader.owner, owner)) return error.InvalidClientHandle;
            break :blk switch (request.command) {
                .describe => .{ .description = try reader.native.describe(client, state.begin.key, output.allocator()) },
                .next => |limits| .{ .batch = try reader.native.next(client, state.begin.key, output.allocator(), limits) },
                .key => |keys| .{ .row = try reader.native.readKey(client, state.begin.key, output.allocator(), keys) },
            };
        },
    };
}
