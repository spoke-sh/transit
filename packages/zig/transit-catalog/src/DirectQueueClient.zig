//! Explicit Queue work and bounded original-selection pages over the shared
//! signed catalog. No implicit claim retry, renewal, ACK or page collection.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const wire = c.DirectQueue;
const w = c.DirectTableProtocol;

pub const Action = union(enum) {
    observe: p.StreamQueue.Partition,
    mutate: struct { work: c.DirectQueueMutation.Request, payload: ?[]const u8 = null },
    operation: c.DirectQueueMutation.Request,
    page: @FieldType(wire.Request, "page"),
    wait: @FieldType(wire.Request, "wait"),
    pub fn encode(self: Action, scratch: std.mem.Allocator) !wire.Request {
        return switch (self) {
            .mutate => |value| .{ .mutate = .{ .work = value.work, .payload = if (value.payload) |bytes| try w.Binary.encode(scratch, bytes) else null } },
            inline else => |value, tag| @unionInit(wire.Request, @tagName(tag), value),
        };
    }
};
pub const Row = struct { lease: p.QueueRead.LeaseObservation, operation: p.DataLifecycle.Operation, visible_ms: u64, value: c.fuze.TableRow.Row };
pub const Page = struct {
    source: c.DirectLogClient.Metadata,
    basis: p.QueueRead.Basis,
    rows: []const Row,
    cursor: p.QueueRead.Cursor,
    encoded_bytes: u32,
};
pub const Result = union(enum) {
    recovering: c.storage.QueuePartition.Recovery,
    cut: p.StreamQueue.Cut,
    operation: ?wire.Receipt,
    page: Page,
    timed_out: p.StreamQueue.Cut,
};
pub const Saved = struct {
    definition: p.Growth.Definition,
    connection: w.Connection,
    work: @FieldType(wire.Request, "mutate"),
    pub fn validate(self: Saved, scratch: std.mem.Allocator) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.connection.validate();
        try self.connection.object(self.work.work.target().interpretation.object);
        try (wire.Request{ .mutate = self.work }).validate(self.connection.principal, self.connection.scope);
        if (self.work.payload) |binary| {
            const bytes = try binary.decode(scratch, 4 * 1024 * 1024);
            defer scratch.free(bytes);
            if (!std.meta.eql(c.storage.LogBatch.content(bytes), self.work.work.enqueue.payload)) return error.LogPayloadConflict;
        }
    }
};
pub fn save(allocator: std.mem.Allocator, connection: w.Connection, action: @FieldType(Action, "mutate")) ![]u8 {
    var scratch: std.heap.ArenaAllocator = .init(allocator);
    defer scratch.deinit();
    const request = try (Action{ .mutate = action }).encode(scratch.allocator());
    const value: Saved = .{ .definition = p.Growth.current_definition, .connection = connection, .work = request.mutate };
    try value.validate(scratch.allocator());
    return p.Json.valueAllocBounded(allocator, value, w.max_request_bytes);
}
pub fn load(allocator: std.mem.Allocator, bytes: []const u8) !std.json.Parsed(Saved) {
    if (bytes.len == 0 or bytes.len > w.max_request_bytes) return error.InvalidQueueIntent;
    const parsed = try p.Json.parseFromSliceOwned(Saved, allocator, bytes);
    errdefer parsed.deinit();
    var scratch: std.heap.ArenaAllocator = .init(allocator);
    defer scratch.deinit();
    try parsed.value.validate(scratch.allocator());
    return parsed;
}

/// Schema and row values belong to output, independent of wire buffers and
/// later calls. Closing this arena changes no durable Queue or lease state.
pub fn apply(output: *std.heap.ArenaAllocator, client: c.DirectTableClient, action: Action) !Result {
    var scratch: std.heap.ArenaAllocator = .init(client.allocator);
    defer scratch.deinit();
    const response = try client.call(.{ .queue = try action.encode(scratch.allocator()) });
    defer response.deinit();
    if (response.value.result != .queue) return error.InvalidQueueResponse;
    return switch (response.value.result.queue) {
        .page => |page| blk: {
            const schema_bytes = try page.source.schema.decode(scratch.allocator(), c.fuze.TableSchema.max_bytes);
            const schema = (try c.fuze.TableSchema.decode(output.allocator(), schema_bytes)).schema;
            const rows = try output.allocator().alloc(Row, page.rows.len);
            _ = scratch.reset(.retain_capacity);
            for (page.rows, rows) |encoded, *row| {
                _ = scratch.reset(.retain_capacity);
                const bytes = try encoded.encoded.decode(scratch.allocator(), c.fuze.TableRow.max_bytes);
                const decoded = try c.fuze.TableRow.decodeInto(output.allocator(), schema, bytes);
                row.* = .{ .lease = encoded.lease, .operation = encoded.operation, .visible_ms = encoded.visible_ms, .value = decoded.row() };
            }
            break :blk .{ .page = .{ .source = .{ .declaration = page.source.declaration, .schema = schema }, .basis = page.basis, .rows = rows, .cursor = page.cursor, .encoded_bytes = page.encoded_bytes } };
        },
        inline else => |value, tag| @unionInit(Result, @tagName(tag), value),
    };
}
