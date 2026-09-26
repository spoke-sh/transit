//! Shared, versioned host operations. Foreign runtimes describe private work;
//! this Zig implementation supplies state, Tables, queries and message semantics.
const std = @import("std");
const s = @import("transit_station");
const p = s.protocol;
const m = s.fuze.model;
pub const Cell = union(enum) { null, int64: []const u8, boolean: bool, utf8: []const u8, binary: p.Value };
pub const Row = struct { key: []const u8, value: Cell };
pub const Plan = struct {
    projection: enum { both, key, value } = .both,
    limit: u8 = m.max_rows,
    aggregate: enum { rows, count, sum } = .rows,
    predicate: union(enum) { all, is_null: u8, compare: struct { column: u8, op: s.fuze.Plan.Comparison, value: Cell } } = .all,
    pub fn native(self: Plan) !s.fuze.Plan {
        return .{ .projection = switch (self.projection) {
            .both => .{ 0, 1 },
            .key => .{ 0, null },
            .value => .{ 1, null },
        }, .limit = self.limit, .aggregate = switch (self.aggregate) {
            .rows => .rows,
            .count => .count,
            .sum => .sum,
        }, .predicate = switch (self.predicate) {
            .all => .all,
            .is_null => |column| .{ .is_null = column },
            .compare => |comparison| .{ .compare = .{ .column = comparison.column, .op = comparison.op, .value = try nativeCell(comparison.value) } },
        } };
    }
};
pub const QueryRequest = struct { id: u32, plan: Plan = .{} };
pub const Action = union(enum) {
    get: p.Value,
    put: struct { key: p.Value, value: p.Value },
    delete: p.Value,
    cast: struct { pid: u64, value: p.Value },
    call: struct { pid: u64, value: p.Value, deadline_ms: ?u64 = null, observer: ?u8 = null },
    reply: p.Value,
    cancel: []const u8,
    effect: p.Value,
    table_create: struct { id: u32, key_name: []const u8, value_name: []const u8, value_type: m.Type },
    table_get: struct { id: u32, key: []const u8 },
    table_write: struct { id: u32, mode: enum { insert, update, upsert }, row: Row },
    table_delete: struct { id: u32, key: []const u8 },
    query: QueryRequest,
    query_reply: QueryRequest,
    query_result: []const u8,
    query_policy: struct { peer: u64, table: u32, expected_revision: u64, allow: bool },
    registry_create: u32,
    registry_grant: struct { scope: u32, subject: s.Registry.Subject, lookup: bool, mutate: bool },
    registry_handle: void,
    registry_route: struct { registry: u64, payload: p.Value },
    supervisor_register: s.Supervisor.Child,
    supervisor_observe: void,
};
pub const Result = union(enum) { none, value: ?p.Value, correlation: []const u8, row: ?Row, arrow: []const u8, manifest: struct { result: u64, correlation: []const u8, bytes: u16, rows: u8 } };
pub fn decimal(allocator: std.mem.Allocator, value: anytype) ![]const u8 {
    return std.fmt.allocPrint(allocator, "{d}", .{value});
}
pub fn nativeCell(cell: Cell) !m.Cell {
    return switch (cell) {
        .null => .null,
        .int64 => |value| .{ .int64 = try std.fmt.parseInt(i64, value, 10) },
        .boolean => |value| .{ .boolean = value },
        .utf8 => |value| .{ .utf8 = try m.Bytes.init(value) },
        .binary => |value| .{ .binary = try m.Bytes.init(value.slice()) },
    };
}
pub fn foreignCell(allocator: std.mem.Allocator, cell: m.Cell) !Cell {
    return switch (cell) {
        .null => .null,
        .int64 => |value| .{ .int64 = try decimal(allocator, value) },
        .boolean => |value| .{ .boolean = value },
        .utf8 => |value| .{ .utf8 = try allocator.dupe(u8, value.slice()) },
        .binary => |value| .{ .binary = try p.Value.init(value.slice()) },
    };
}
/// Client-side consumption of finite IPC without exposing borrowed Arrow/native
/// pointers to a foreign runtime. All int64 cells remain decimal strings.
pub const ArrowCell = struct { rows: u8, columns: u8, name: []const u8, value: Cell };
pub fn arrowCell(allocator: std.mem.Allocator, bytes: []const u8, row: u32, column: u32) !ArrowCell {
    return arrowCellBounded(allocator, bytes, row, column, s.Query.max_bytes);
}
pub fn arrowCellBounded(allocator: std.mem.Allocator, bytes: []const u8, row: u32, column: u32, limit: usize) !ArrowCell {
    if (bytes.len == 0 or bytes.len > limit) return error.InvalidArrowResult;
    var workspace: [s.fuze.execution.working_bytes]u8 = undefined;
    var arena = std.heap.FixedBufferAllocator.init(&workspace);
    var source = std.Io.Reader.fixed(bytes);
    var reader = s.fuze.arrow.IpcStreamReader(*std.Io.Reader).init(arena.allocator(), &source);
    defer reader.deinit();
    const schema = try reader.readSchema();
    if (schema.fields.len == 0 or schema.fields.len > 2 or column >= schema.fields.len) return error.InvalidColumn;
    var batch = (try reader.nextRecordBatch()) orelse return error.InvalidArrowResult;
    defer batch.deinit();
    if (batch.numRows() > m.max_rows or row >= batch.numRows()) return error.InvalidRow;
    var validation_workspace: [s.fuze.execution.working_bytes]u8 = undefined;
    _ = try s.fuze.Inspect.segment(bytes, @intCast(batch.numRows()), &validation_workspace);
    const data = batch.column(column).data();
    const cell: m.Cell = if (data.isNull(row)) .null else switch (schema.fields[column].data_type.*) {
        .int64 => .{ .int64 = try (s.fuze.arrow.Int64Array{ .data = data }).value(row) },
        .bool => .{ .boolean = try (s.fuze.arrow.BooleanArray{ .data = data }).value(row) },
        .string => .{ .utf8 = try m.Bytes.init(try (s.fuze.arrow.StringArray{ .data = data }).value(row)) },
        .binary => .{ .binary = try m.Bytes.init(try (s.fuze.arrow.BinaryArray{ .data = data }).value(row)) },
        else => return error.UnsupportedType,
    };
    return .{ .rows = @intCast(batch.numRows()), .columns = @intCast(schema.fields.len), .name = try allocator.dupe(u8, schema.fields[column].name), .value = try foreignCell(allocator, cell) };
}
pub fn hex(allocator: std.mem.Allocator, bytes: []const u8) ![]const u8 {
    const output = try allocator.alloc(u8, bytes.len * 2);
    const digits = "0123456789abcdef";
    for (bytes, 0..) |byte, index| {
        output[index * 2] = digits[byte >> 4];
        output[index * 2 + 1] = digits[byte & 15];
    }
    return output;
}
/// The result borrows the supplied arena; serialize/copy before releasing it.
/// All actions mutate only the private turn. The host explicitly finishes it.
pub fn basic(comptime R: type, allocator: std.mem.Allocator, turn: anytype, action: anytype) !?R {
    switch (action) {
        .get => |key| return .{ .value = try turn.read(key) },
        .put => |put| try turn.put(put.key, put.value),
        .delete => |key| try turn.delete(key),
        .cast => |cast| try turn.cast(cast.pid, cast.value),
        .call => |call| return .{ .correlation = try decimal(allocator, try turn.callWithTimer(call.pid, call.value, call.deadline_ms, call.observer)) },
        .reply => |value| try turn.reply(value),
        .cancel => |correlation| {
            const cancelled = try s.Waiting.cancel(turn, try std.fmt.parseInt(u64, correlation, 10));
            if (@hasField(R, "cancelled")) {
                try turn.validate();
                return .{ .cancelled = cancelled };
            }
        },
        .effect => |value| {
            try value.validate();
            if (turn.decision.effect != null) return error.EffectBudgetExceeded;
            turn.decision.effect = value;
        },
        .table_create => |table| {
            _ = try s.Table.create(turn, table.id, .{ .names = .{ try m.Name.init(table.key_name), try m.Name.init(table.value_name) }, .value_type = table.value_type });
        },
        .table_get => |request| {
            const table = try s.Table.open(turn, request.id);
            const row = (try table.get(turn, try std.fmt.parseInt(i64, request.key, 10))) orelse return .{ .row = null };
            return .{ .row = .{ .key = try decimal(allocator, row.key), .value = try foreignCell(allocator, row.value) } };
        },
        .table_write => |write| {
            const table = try s.Table.open(turn, write.id);
            const row: m.Row = .{ .key = try std.fmt.parseInt(i64, write.row.key, 10), .value = try nativeCell(write.row.value) };
            switch (write.mode) {
                .insert => try table.insert(turn, row),
                .update => try table.update(turn, row),
                .upsert => try table.upsert(turn, row),
            }
        },
        .table_delete => |request| try (try s.Table.open(turn, request.id)).delete(turn, try std.fmt.parseInt(i64, request.key, 10)),
        else => return null,
    }
    try turn.validate();
    return .none;
}
pub fn apply(allocator: std.mem.Allocator, turn: *s.Turn, action: Action) !Result {
    if (try basic(Result, allocator, turn, action)) |result| return result;
    switch (action) {
        .query, .query_reply => |request| {
            const table = try s.Table.open(turn, request.id);
            var workspace: [s.fuze.execution.working_bytes]u8 = undefined;
            const cancellation = s.fuze.execution.Cancellation.init(false);
            if (action == .query_reply) {
                const manifest = try s.Query.capture(turn, table, try request.plan.native(), &workspace, &cancellation);
                return .{ .manifest = .{ .result = manifest.result, .correlation = try decimal(allocator, manifest.correlation), .bytes = manifest.bytes, .rows = manifest.rows } };
            }
            var snapshot = try table.snapshot(turn);
            var output: [s.Query.max_bytes]u8 = undefined;
            const result = try s.fuze.execution.run(try (try request.plan.native()).bind(snapshot.source()), snapshot.source(), &workspace, &output, &cancellation);
            return .{ .arrow = try hex(allocator, result.bytes) };
        },
        .query_result => |correlation| {
            const result = try s.Query.completed(turn, try std.fmt.parseInt(u64, correlation, 10));
            return .{ .arrow = try hex(allocator, result.bytes()) };
        },
        .query_policy => |grant| try s.Query.setPolicy(turn, grant.peer, grant.table, grant.expected_revision, grant.allow),
        .registry_create => |scope| try s.Registry.create(turn, scope),
        .registry_grant => |grant| try s.Registry.grant(turn, grant.scope, grant.subject, .{ .lookup = grant.lookup, .mutate = grant.mutate }),
        .registry_handle => try s.Registry.handle(turn, try s.Frame.decode(turn.delivery.input.value)),
        .registry_route => |route| {
            _ = try s.Registry.route(turn, route.registry, try s.Frame.decode(turn.delivery.input.value), route.payload);
        },
        .supervisor_register => |child| try s.Supervisor.register(turn, child),
        .supervisor_observe => try s.Supervisor.observe(turn, try s.Supervisor.Observation.decode(try s.Frame.decode(turn.delivery.input.value))),
        else => unreachable,
    }
    try turn.validate();
    return .none;
}
