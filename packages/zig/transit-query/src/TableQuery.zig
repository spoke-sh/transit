//! Catalog-routed finite logical SELECT over one leased native resource cut.
//! General Table roots/schema stay frozen; scoped and native rights stay current.
const std = @import("std");
const q = @import("root.zig");
const c = q.catalog;
const f = q.fuze;
const p = q.protocol;
const logical = f.LogicalQuery;
const QueryLimits = struct {
    requests: u64,
    rows: u64,
    result_bytes: u64,
    pub fn validate(self: QueryLimits) !void {
        if (self.requests == 0 or self.rows == 0 or self.result_bytes == 0) return error.InvalidQueryBudget;
    }
};
/// Experimental batching is selected only by proof/measurement callers.
pub fn Query(comptime batched: bool) type {
    return struct {
        const Self = @This();
        pub const Limits = QueryLimits;
        compiled: f.TableSelect.Owned,
        execution: if (batched) f.BatchExecution.Execution(Scan, .selected_prefix) else logical.Execution(Scan, .selected_prefix),
        limits: Limits,
        result_bytes: u64,
        complete: bool = false,
        failed: bool = false,
        native_rejection: ?p.ErrorCode = null,

        pub const Compute = struct { limits: f.Batch.Limits = .{}, runner: ?f.Batch.Runner = null };
        pub fn open(allocator: std.mem.Allocator, client: *c.TableClient, text: []const u8, nonce: [16]u8, limits: Limits, cancellation: ?*const std.atomic.Value(bool), location: ?*f.Sql.Location) !Self {
            return openWith(allocator, client, text, nonce, limits, cancellation, location, .{});
        }
        pub fn openWith(allocator: std.mem.Allocator, client: *c.TableClient, text: []const u8, nonce: [16]u8, limits: Limits, cancellation: ?*const std.atomic.Value(bool), location: ?*f.Sql.Location, compute: Compute) !Self {
            try client.connection.validate();
            try limits.validate();
            if (cancellation) |flag| if (flag.load(.acquire)) return error.Cancelled;
            var names: std.heap.ArenaAllocator = .init(allocator);
            defer names.deinit();
            const name = try c.TableMetadata.Name.init(try f.TableSelect.targetDiagnostic(names.allocator(), text, location));
            var scan = try Scan.open(allocator, client, name, nonce, limits.requests, cancellation);
            errdefer scan.deinit();
            const definition = &scan.definition.?;
            var fields: [f.TableSchema.max_columns]f.Types.Field = undefined;
            var compiled = try f.TableSelect.compile(allocator, text, definition.metadata.name.slice(), try definition.schema.schema.rowType(&fields), try scan.fingerprint(), location);
            errdefer compiled.deinit();
            return start(&scan, &compiled, limits, compute);
        }
        /// A new authorized cut for each execution. The immutable preparation
        /// identity is checked before binding; no saved execution plan is reused.
        pub fn openPrepared(allocator: std.mem.Allocator, client: *c.TableClient, template: *const q.TablePrepared, values: []const ?f.Types.Values.Atom, nonce: [16]u8, limits: Limits, cancellation: ?*const std.atomic.Value(bool), detail: ?*f.Sql.Binding, compute: Compute) !Self {
            try client.connection.validate();
            try limits.validate();
            if (cancellation) |flag| if (flag.load(.acquire)) return error.Cancelled;
            var scan = try Scan.open(allocator, client, template.binding.metadata.name, nonce, limits.requests, cancellation);
            errdefer scan.deinit();
            var compiled = try template.instantiate(allocator, client.connection, scan.definition.?, try scan.fingerprint(), values, detail);
            errdefer compiled.deinit();
            return start(&scan, &compiled, limits, compute);
        }
        /// Borrows candidates on error and transfers both owners on success.
        fn start(scan: *Scan, compiled: *f.TableSelect.Owned, limits: Limits, compute: Compute) !Self {
            const definition = &scan.definition.?;
            var single: [1]f.LogicalPredicate.Program.Instruction = undefined;
            const program: ?f.LogicalPredicate.Program = switch (compiled.plan.predicate) {
                .program => |value| value,
                .compare => |value| blk: {
                    single[0] = .{ .atom = .{ .compare = value } };
                    break :blk .{ .instructions = &single };
                },
                else => null,
            };
            if (program) |predicate| {
                const qualification: f.TableDml.Plan = .{ .name = compiled.name, .schema = definition.schema.schema, .action = .delete, .predicate = predicate };
                var keys: [f.TableSchema.max_columns]f.Types.Values.Cell = undefined;
                if (try qualification.primaryKeyEquality(&keys)) |key| scan.point = try compiled.arena.allocator().dupe(f.Types.Values.Cell, key);
            }
            var output: [f.TableSchema.max_columns]f.Types.Field = undefined;
            var scratch: [f.Types.max_encoding_bytes]u8 = undefined;
            const encoded = try (try compiled.plan.outputSchema(&output)).encode(&scratch);
            if (encoded.len > limits.result_bytes) return error.QueryResultBudget;
            // Parsing and schema work can outlive a policy observation. Revalidate before
            // returning the output schema, including LIMIT 0 and empty Tables.
            try scan.validateCurrent(false);
            const Engine = @FieldType(Self, "execution");
            var execution = if (batched) try Engine.initBudget(scan.*, compiled.plan, compute.limits) else try Engine.init(scan.*, compiled.plan);
            if (batched) execution.runner = compute.runner;
            return .{ .compiled = compiled.*, .execution = execution, .limits = limits, .result_bytes = encoded.len };
        }
        pub fn schema(self: *const Self, fields: *[f.TableSchema.max_columns]f.Types.Field) !f.Types.Type {
            if (self.failed) return error.FailedQuery;
            return self.compiled.plan.outputSchema(fields);
        }
        pub fn sourceObject(self: *const Self) u64 {
            return self.execution.scan.definition.?.metadata.object;
        }
        /// One independently owned output row. Completion is visible only after final
        /// current validation; callers must treat every earlier row as an incomplete prefix.
        pub fn next(self: *Self) !?logical.Row {
            if (self.failed) return error.FailedQuery;
            if (self.complete) return null;
            if (self.execution.scan.source.closed) return error.QueryClosed;
            self.execution.scan.rejection = null;
            errdefer {
                self.failed = true;
                self.native_rejection = self.execution.scan.rejection;
            }
            try self.execution.scan.checkCancellation();
            var row = try self.execution.next();
            errdefer if (row) |*value| value.deinit();
            var bytes = self.result_bytes;
            if (row) |value| {
                if (self.execution.emitted > self.limits.rows) return error.QueryResultBudget;
                var fields: [f.TableSchema.max_columns]f.Types.Field = undefined;
                const output = try self.compiled.plan.outputSchema(&fields);
                var scratch: [256]u8 = undefined;
                var count: std.Io.Writer.Discarding = .init(&scratch);
                for (value.cells, output.structure) |cell, field| {
                    try count.writer.writeInt(u32, 0, .little); // canonical cell-length prefix
                    try f.Types.Codec.writeBound(cell, field, &count.writer);
                }
                bytes = std.math.add(u64, bytes, count.fullCount()) catch return error.QueryResultBudget;
                if (bytes > self.limits.result_bytes) return error.QueryResultBudget;
            }
            try self.execution.scan.validateCurrent(self.execution.complete);
            try self.execution.scan.checkCancellation();
            self.complete = self.execution.complete;
            self.result_bytes = bytes;
            return row;
        }
        pub fn close(self: *Self) !void {
            try self.execution.scan.source.close();
        }
        pub fn deinit(self: *Self) void {
            self.execution.deinit();
            self.compiled.deinit();
            self.* = undefined;
        }
    };
}

const Scan = @import("TableScan.zig");

test "typed Table query validates budgets and connection before source access" {
    const t = std.testing;
    var caller: c.TableClient = .{ .transport = undefined, .connection = .{ .scope = .{ .realm = 1, .resource = 2, .catalog = 3 }, .owner = 4, .principal = 5 }, .key = try p.Ed25519.KeyPair.generateDeterministic(@splat(7)) };
    const limits: QueryLimits = .{ .requests = 100, .rows = 100, .result_bytes = 1024 };
    inline for (.{ "requests", "rows", "result_bytes" }) |field| {
        var invalid = limits;
        @field(invalid, field) = 0;
        try t.expectError(error.InvalidQueryBudget, Query(false).open(t.allocator, &caller, "SELECT * FROM people", @splat(1), invalid, null, null));
    }
    const cancelled = std.atomic.Value(bool).init(true);
    try t.expectError(error.Cancelled, Query(false).open(t.allocator, &caller, "SELECT * FROM people", @splat(1), limits, &cancelled, null));
    caller.connection.scope.resource = 0;
    try t.expectError(error.InvalidCatalogIdentity, Query(false).open(t.allocator, &caller, "SELECT * FROM people", @splat(1), limits, null, null));
}
test "invalid Table SELECT headers retain location before acquiring a source" {
    var client: c.TableClient = .{ .transport = undefined, .connection = .{ .scope = .{ .realm = 1, .resource = 7, .catalog = 9 }, .owner = 3, .principal = 17 }, .key = try p.Ed25519.KeyPair.generateDeterministic(@splat(10)) };
    var location: f.Sql.Location = .{ .offset = 999 };
    try std.testing.expectError(error.InvalidSqlSyntax, Query(false).open(std.testing.allocator, &client, "SELECT FROM people", @splat(1), .{ .requests = 100, .rows = 100, .result_bytes = 1024 }, null, &location));
    try std.testing.expectEqual(@as(usize, 7), location.offset);
}
