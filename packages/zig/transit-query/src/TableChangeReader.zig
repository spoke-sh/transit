//! Leased snapshot/change handoff through public signed reads. A resume token
//! names one complete Table head, never a delivered row prefix or permission.
const std = @import("std");
const q = @import("root.zig");
const s = q.station;
const f = q.fuze;
const p = q.protocol;
const Scan = @import("TableScan.zig");
const Self = @This();
allocator: std.mem.Allocator,
scan: Scan,
position: Position,
snapshot_after: ?f.TableRow.Identity = null,
snapshot_complete: bool,
diff: ?s.TableChanges.Diff = null,
cursor: s.TableChanges.Cursor = .{},
closed: bool = false,
pub const Position = struct {
    version: u8,
    definition: p.Growth.Definition,
    connection: q.catalog.TableClient.Connection,
    /// STJ1 includes the mandatory current definition, head and native position.
    record: p.Value,
    pub fn validate(self: Position) !s.TableHistory.Record {
        if (self.version != 1 or self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.connection.validate();
        const value = try s.TableHistory.Record.decode(self.record);
        if (value.head.resource != self.connection.scope.resource) return error.RelationalSourceChanged;
        return value;
    }
};
pub const Event = union(enum) {
    /// One bounded diff step with no visible row change.
    progress,
    /// Owns at most two decoded rows; the caller deinitializes this value.
    change: s.TableChanges.Change,
    /// Only this event advances the resumable position. Zero changes is valid.
    transaction: struct { previous: Position, next: Position, changes: u64 },
    /// Complete coverage of this lease's upper cut; reopen to observe later work.
    caught_up,
};
pub fn open(allocator: std.mem.Allocator, client: *q.catalog.TableClient, name: q.catalog.TableMetadata.Name, nonce: [16]u8, requests: u64, cancellation: ?*const std.atomic.Value(bool)) !Self {
    var scan = try Scan.open(allocator, client, name, nonce, requests, cancellation);
    errdefer scan.deinit();
    const head = try s.TableHistory.current(&scan, scan.definition.?.head.object);
    if (!(try head.head.encode()).eql(try scan.definition.?.head.encode())) return error.TableHeadChanged;
    try scan.validateCurrent(false);
    return .{ .allocator = allocator, .scan = scan, .position = .{ .version = 1, .definition = p.Growth.current_definition, .connection = client.connection, .record = try head.encode() }, .snapshot_complete = false };
}
/// Replays any partially delivered transaction from its beginning. The caller
/// saves positions only together with applying the complete corresponding batch.
pub fn openTail(allocator: std.mem.Allocator, client: *q.catalog.TableClient, position: Position, nonce: [16]u8, requests: u64, cancellation: ?*const std.atomic.Value(bool)) !Self {
    const previous = try position.validate();
    if (!std.meta.eql(position.connection, client.connection)) return error.RelationalCallerChanged;
    var scan = try Scan.openResource(allocator, client, nonce, requests, cancellation);
    errdefer scan.deinit();
    // A raw resource lease grants no Table disclosure. Preserve the original
    // object's binding when resuming history, including DROP and name reuse.
    scan.history_object = previous.head.object;
    try scan.checkRead();
    const upper = try s.TableHistory.current(&scan, previous.head.object);
    const observed = try s.TableHistory.revision(&scan, upper, previous.head.revision);
    if (!(try observed.encode()).eql(position.record)) return error.TableHistoryConflict;
    try scan.validateCurrent(false);
    return .{ .allocator = allocator, .scan = scan, .position = position, .snapshot_complete = true };
}
pub fn deinit(self: *Self) void {
    if (self.diff) |*diff| diff.deinit();
    self.scan.deinit();
    self.* = undefined;
}
pub fn close(self: *Self) !void {
    try self.scan.source.close();
    self.closed = true;
}
/// The initial frozen snapshot is incomplete until null. Later accepted heads
/// remain in immutable history while this reader is paused or disconnected.
pub fn snapshotNext(self: *Self) !?f.TableRow.Owned {
    if (self.closed) return error.QueryClosed;
    if (self.snapshot_complete) return null;
    try self.scan.validateCurrent(false);
    const initial = try self.position.validate();
    var schema = try initial.head.readSchema(self.allocator, &self.scan);
    defer schema.deinit();
    const pages: s.TablePages = .{ .resource = initial.head.resource, .object = initial.head.object };
    var reader: s.TablePages.Reader(*Scan) = .{ .pages = pages, .source = &self.scan };
    const data: s.TableData = .{ .schema = schema.schema, .index = initial.head.index };
    var row = (try data.next(self.allocator, &reader, self.snapshot_after)) orelse {
        try self.scan.validateCurrent(false);
        self.snapshot_complete = true;
        return null;
    };
    errdefer row.deinit();
    try self.scan.validateCurrent(false);
    self.snapshot_after = row.identity;
    return row;
}
pub fn checkpoint(self: *Self) !Position {
    if (self.closed) return error.QueryClosed;
    if (!self.snapshot_complete or self.diff != null) return error.IncompleteTableChanges;
    try self.scan.validateCurrent(false);
    return self.position;
}
pub fn next(self: *Self) !Event {
    if (self.closed) return error.QueryClosed;
    if (!self.snapshot_complete) return error.IncompleteTableChanges;
    try self.scan.validateCurrent(false);
    if (self.diff == null) {
        const transaction = (try s.TableChanges.next(&self.scan, try self.position.validate())) orelse return .caught_up;
        self.diff = try s.TableChanges.Diff.open(self.allocator, &self.scan, transaction);
        self.cursor = .{};
    }
    // Never advance the cursor before the final current-policy check succeeds.
    var cursor = self.cursor;
    var event = try self.diff.?.step(&self.scan, &cursor);
    errdefer if (event == .change) event.change.deinit();
    try self.scan.validateCurrent(false);
    self.cursor = cursor;
    return switch (event) {
        .progress => .progress,
        .change => |change| .{ .change = change },
        .complete => blk: {
            const previous = self.position;
            self.position.record = try self.diff.?.transaction.after.encode();
            self.diff.?.deinit();
            self.diff = null;
            break :blk .{ .transaction = .{ .previous = previous, .next = self.position, .changes = cursor.changes } };
        },
    };
}
