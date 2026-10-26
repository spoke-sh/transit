//! Finite Fuze SELECT over an explicitly retained direct Table source. This
//! owner borrows the durable pin; callers persist and release it separately.
const std = @import("std");
const q = @import("root.zig");
const c = q.catalog;
const f = q.fuze;
const logical = f.LogicalQuery;
const Scan = @import("DirectTableScan.zig");
const Engine = f.BatchExecution.Execution(Scan, .selected_prefix);
const Self = @This();

pub const Limits = struct {
    requests: u64,
    rows: u64,
    result_bytes: u64,
    pub fn validate(self: Limits) !void {
        if (self.requests < 2 or self.rows == 0 or self.result_bytes == 0) return error.InvalidQueryBudget;
    }
};
pub const Compute = struct { limits: f.Batch.Limits = .{}, runner: ?f.Batch.Runner = null };
pub const Batch = struct {
    pub const max_rows = 8;
    pub const max_bytes = 16 * 1024 * 1024;
    rows: [max_rows]?logical.Row = @splat(null),
    len: u8 = 0,
    bytes: u64 = 0,
    complete: bool = false,
    pub fn deinit(self: *Batch) void {
        for (&self.rows) |*slot| if (slot.*) |*row| row.deinit();
        self.* = .{};
    }
    pub fn take(self: *Batch, index: usize) logical.Row {
        std.debug.assert(index < self.len);
        const row = self.rows[index].?;
        self.rows[index] = null;
        return row;
    }
};
const PreparedRow = struct { row: logical.Row, bytes: u64 };
compiled: f.TableSelect.Owned,
execution: Engine,
limits: Limits,
result_bytes: u64,
complete: bool = false,
failed: bool = false,
native_rejection: ?q.protocol.ErrorCode = null,
pending_row: ?PreparedRow = null,

/// `name` is the explicit SQL binding for this retained source, not a fresh
/// catalog lookup. Neither opening nor cleanup acquires/releases a durable pin.
pub fn openRetained(allocator: std.mem.Allocator, client: c.DirectTableClient, snapshot: c.DirectTableProtocol.Snapshot, name: []const u8, text: []const u8, limits: Limits, cancellation: ?*const std.atomic.Value(bool), location: ?*f.Sql.Location, compute: Compute) !Self {
    try limits.validate();
    try client.connection.validate();
    var scan = try Scan.open(allocator, client, snapshot, limits.requests, cancellation);
    errdefer scan.deinit();
    const table_schema = scan.reader.schema.schema;
    try qualify(table_schema);
    var fields: [f.TableSchema.max_columns]f.Types.Field = undefined;
    var compiled = try f.TableSelect.compile(allocator, text, name, try table_schema.rowType(&fields), try scan.fingerprint(), location);
    errdefer compiled.deinit();
    return start(&scan, &compiled, limits, compute);
}
pub fn qualify(table_schema: f.TableSchema.Schema) !void {
    try table_schema.validate();
    // The shared logical evaluator currently compares text as UTF-8 bytes.
    // Reject other declared semantics instead of silently ignoring them.
    for (table_schema.columns) |column| switch (column.collation) {
        .none, .utf8_binary => {},
        else => return error.UnsupportedTableQueryCollation,
    };
}
/// The caller retains the original pin request/handle across uncertain
/// acquisition. This opens no pin and never substitutes a newer source.
pub fn openPreparedRetained(allocator: std.mem.Allocator, client: c.DirectTableClient, snapshot: c.DirectTableProtocol.Snapshot, prepared: *const q.DirectTablePrepared, values: []const ?f.Types.Values.Atom, limits: Limits, cancellation: ?*const std.atomic.Value(bool), detail: ?*f.Sql.Binding, compute: Compute) !Self {
    try limits.validate();
    if (cancellation) |flag| if (flag.load(.acquire)) return error.Cancelled;
    if (limits.requests < 4) return error.QueryPageBudget;
    _ = try prepared.binding.require(client, .read);
    var scan = try Scan.open(allocator, client, snapshot, limits.requests - 2, cancellation);
    errdefer scan.deinit();
    scan.requests += 2;
    scan.request_limit = limits.requests;
    try qualify(scan.reader.schema.schema);
    var compiled = try prepared.instantiate(allocator, client.connection, scan.reader.basis.interpretation, scan.reader.schema.schema, try scan.fingerprint(), values, detail);
    errdefer compiled.deinit();
    return start(&scan, &compiled, limits, compute);
}
/// Transfers scan and compiled ownership only on success.
fn start(scan: *Scan, compiled: *f.TableSelect.Owned, limits: Limits, compute: Compute) !Self {
    var fields: [f.TableSchema.max_columns]f.Types.Field = undefined;
    var scratch: [f.Types.max_encoding_bytes]u8 = undefined;
    const encoded = try (try compiled.plan.outputSchema(&fields)).encode(&scratch);
    if (encoded.len > limits.result_bytes) return error.QueryResultBudget;
    try scan.validateCurrent();
    scan.selectPoint(compiled.plan);
    var execution = try Engine.initBudget(scan.*, compiled.plan, compute.limits);
    execution.runner = compute.runner;
    return .{ .compiled = compiled.*, .execution = execution, .limits = limits, .result_bytes = encoded.len };
}
pub fn schema(self: *const Self, fields: *[f.TableSchema.max_columns]f.Types.Field) !f.Types.Type {
    if (self.failed) return error.FailedQuery;
    if (self.execution.scan.closed) return error.QueryClosed;
    return self.compiled.plan.outputSchema(fields);
}
pub fn source(self: *const Self) c.DirectTableReader.Basis {
    return self.execution.scan.reader.basis;
}
pub fn next(self: *Self) !?logical.Row {
    var batch = try self.nextBatch(1);
    defer batch.deinit();
    return if (batch.len == 0) null else batch.take(0);
}
pub fn nextBatch(self: *Self, maximum: u8) !Batch {
    if (maximum == 0 or maximum > Batch.max_rows) return error.InvalidQueryBudget;
    if (self.failed) return error.FailedQuery;
    self.execution.scan.rejection = null;
    errdefer {
        self.failed = true;
        self.native_rejection = self.execution.scan.rejection;
    }
    try self.execution.scan.checkCancellation();
    var result: Batch = .{};
    errdefer result.deinit();
    if (!self.complete) while (result.len < maximum) {
        const prepared = if (self.pending_row) |row| row else (try self.prepareRow()) orelse break;
        self.pending_row = prepared;
        if (prepared.bytes > Batch.max_bytes) return error.QueryResultBudget;
        if (result.bytes + prepared.bytes > Batch.max_bytes) break;
        result.rows[result.len] = prepared.row;
        result.len += 1;
        result.bytes += prepared.bytes;
        self.pending_row = null;
    };
    result.complete = self.execution.complete and self.pending_row == null;
    if (result.len == 0 and !result.complete) return error.IncompleteSource;
    // Computation and cached input can outlive a grant. The complete output,
    // including LIMIT 0, aggregates and repeated completion, passes this gate.
    try self.execution.scan.validateCurrent();
    self.complete = result.complete;
    return result;
}
fn prepareRow(self: *Self) !?PreparedRow {
    var row = (try self.execution.next()) orelse return null;
    errdefer row.deinit();
    if (self.execution.emitted > self.limits.rows) return error.QueryResultBudget;
    var fields: [f.TableSchema.max_columns]f.Types.Field = undefined;
    const output = try self.compiled.plan.outputSchema(&fields);
    var scratch: [256]u8 = undefined;
    var count: std.Io.Writer.Discarding = .init(&scratch);
    for (row.cells, output.structure) |cell, field| {
        try count.writer.writeInt(u32, 0, .little);
        try f.Types.Codec.writeBound(cell, field, &count.writer);
    }
    const bytes = std.math.add(u64, self.result_bytes, count.fullCount()) catch return error.QueryResultBudget;
    if (bytes > self.limits.result_bytes) return error.QueryResultBudget;
    self.result_bytes = bytes;
    return .{ .row = row, .bytes = count.fullCount() };
}
/// Close only this computation. The explicit snapshot remains owned by its
/// caller for another computation, recovery or separately authorized release.
pub fn close(self: *Self) void {
    self.execution.scan.close();
}
pub fn deinit(self: *Self) void {
    if (self.pending_row) |*row| row.row.deinit();
    self.execution.deinit();
    self.compiled.deinit();
    self.* = undefined;
}
