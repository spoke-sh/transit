//! Bounded presentation over the shared logical reader. The caller owns this
//! object at a stable address and serializes access. No SQL or recovery logic.
const std = @import("std");
const sdk = @import("root.zig");
const r = sdk.results;
const Self = @This();
pub const max_rows = 100;
pub const max_value_bytes = 2 * 1024 * 1024;
pub const max_response_bytes = 4 * 1024 * 1024;
pub const View = struct {
    pub const json_schema_sequence_bounds = .{ .columns = 256, .rows = max_rows };
    definition: r.protocol.Growth.Definition = r.protocol.Growth.current_definition,
    result: []const u8,
    columns: []const r.Types.Field,
    rows: []const []const r.fuze.LogicalJson.Cell,
    observation: []const u8,
    observation_kind: enum { data, metadata },
    start: []const u8,
    delivered: []const u8,
    complete_rows: ?[]const u8,
    stopped: enum { complete, row_limit, metadata_window },
};
outcome: *sdk.Executor.Outcome,
memory: r.fuze.MemoryBudget,
arena: std.heap.ArenaAllocator,
rows: std.ArrayList([]const r.fuze.LogicalJson.Cell) = .empty,
start: u64 = 0,
stopped: @FieldType(View, "stopped") = .row_limit,

pub fn init(self: *Self, allocator: std.mem.Allocator, outcome: *sdk.Executor.Outcome) !void {
    if (outcome.value != .rows) return error.ExpectedRowResult;
    try outcome.value.rows.holdDisclosure();
    self.* = .{ .outcome = outcome, .memory = .{ .parent = allocator, .limit = max_value_bytes }, .arena = undefined };
    self.arena = .init(self.memory.allocator());
}
pub fn deinit(self: *Self) void {
    self.arena.deinit();
    self.outcome.deinit();
}
fn append(self: *Self, row: r.Row) !void {
    const a = self.arena.allocator();
    const result = &self.outcome.value.rows;
    const cells = try a.alloc(r.fuze.LogicalJson.Cell, row.len);
    for (row, result.schema.structure, cells) |cell, field, *out| {
        out.* = try r.fuze.LogicalJson.foreignCell(a, cell, field.type);
    }
    try self.rows.append(a, cells);
}
pub fn advance(self: *Self) !void {
    const result = &self.outcome.value.rows;
    if (self.stopped == .complete) return error.ResultExhausted;
    _ = self.arena.reset(.retain_capacity);
    self.rows = .empty;
    self.start = result.progress.delivered;
    // Metadata rows can carry different authority subjects. Keep one logical
    // chunk until it is replaced so revalidation covers every held row.
    if (result.observation == .metadata) {
        if (result.progress.consumption != .exhausted) {
            if (try result.nextBatch()) |batch| {
                var scratch: [256]r.Types.Values.Cell = undefined;
                for (0..batch.len) |i| try self.append(try batch.rowInto(i, &scratch));
            }
        }
        self.stopped = .metadata_window;
    } else {
        while (self.rows.items.len < max_rows and result.progress.consumption != .exhausted) {
            const row = try result.nextRow() orelse break;
            try self.append(row);
        }
        self.stopped = .row_limit;
    }
    if (result.progress.consumption == .exhausted) self.stopped = .complete;
}
/// Validate before every disclosure, including repeats and zero-row completion.
/// A metadata window never includes earlier chunks with different subjects.
pub fn inspect(self: *Self, allocator: std.mem.Allocator) !View {
    const result = &self.outcome.value.rows;
    try result.validateDisclosure();
    return .{
        .result = try std.fmt.allocPrint(allocator, "{x}", .{&result.progress.identity.result}),
        .columns = result.schema.structure,
        .rows = self.rows.items,
        .observation = try sdk.protocol.Json.valueAlloc(allocator, result.observation),
        .observation_kind = if (result.observation == .data) .data else .metadata,
        .start = try std.fmt.allocPrint(allocator, "{d}", .{self.start}),
        .delivered = try std.fmt.allocPrint(allocator, "{d}", .{result.progress.delivered}),
        .complete_rows = if (result.completion()) |completion| try std.fmt.allocPrint(allocator, "{d}", .{completion.rows}) else null,
        .stopped = self.stopped,
    };
}
