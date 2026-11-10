//! Fuze relational source over an existing finite `StreamRead` pin. The caller
//! retains ownership of that durable pin; closing this scan does not release it.
const std = @import("std");
const q = @import("root.zig");
const c = q.catalog;
const f = q.fuze;
const p = q.protocol;
const Self = @This();

allocator: std.mem.Allocator,
client: c.DirectTableClient,
namespace: u64,
receipt: p.StreamRead.Receipt,
expected_schema: f.TableSchema.Schema,
expected_fingerprint: [32]u8,
include_tombstones: bool,
limits: q.storage.StreamPartition.ReadLimits,
request_limit: u64,
requests: u64 = 2,
cancellation: ?*const std.atomic.Value(bool),
initial_cursor: p.StreamRead.Cursor,
cursor: p.StreamRead.Cursor,
page_arena: std.heap.ArenaAllocator,
page: ?c.DirectStreamClient.Page = null,
timestamp_index: ?usize = null,
index: usize = 0,
after: ?f.TableRow.Identity = null,
complete: bool = false,
closed: bool = false,
rejection: ?p.ErrorCode = null,
row_cells: [f.TableSchema.max_columns]f.Types.Values.Cell = undefined,

pub fn sliceSchema(allocator: std.mem.Allocator, user: f.TableSchema.Schema, timestamp_column: ?u64) !f.TableSchema.Owned {
    if (user.columns.len > q.storage.LogDeclaration.max_user_columns) return error.InvalidColumnCount;
    var columns: [f.TableSchema.max_columns]f.TableSchema.Column = undefined;
    const n = user.columns.len;
    @memcpy(columns[0..n], user.columns);
    columns[n] = .{ .id = user.next_column, .name = "_partition", .type = .uint64, .nullable = false };
    columns[n + 1] = .{ .id = user.next_column + 1, .name = "_offset", .type = .uint64, .nullable = false };
    columns[n + 2] = .{ .id = user.next_column + 2, .name = "_timestamp", .type = .{ .timestamp = .utc }, .nullable = timestamp_column == null };
    columns[n + 3] = .{ .id = user.next_column + 3, .name = "_tombstone", .type = .boolean, .nullable = false };
    const expanded: f.TableSchema.Schema = .{
        .object = user.object,
        .revision = user.revision,
        .next_column = user.next_column + 4,
        .columns = columns[0 .. n + 4],
    };
    return expanded.clone(allocator);
}

pub fn tombstoneColumnId(schema: f.TableSchema.Schema) ?u64 {
    if (schema.columns.len <= 4) return null;
    const last = schema.columns[schema.columns.len - 1];
    return if (std.mem.eql(u8, last.name, "_tombstone")) last.id else null;
}

pub fn open(
    allocator: std.mem.Allocator,
    client: c.DirectTableClient,
    namespace: u64,
    receipt: p.StreamRead.Receipt,
    expected_schema: f.TableSchema.Schema,
    include_tombstones: bool,
    limits: q.storage.StreamPartition.ReadLimits,
    request_limit: u64,
    cancellation: ?*const std.atomic.Value(bool),
) !Self {
    if (request_limit < 2 or limits.rows == 0 or limits.encoded_bytes == 0 or limits.scanned_rows == 0) return error.InvalidQueryBudget;
    if (cancellation) |flag| if (flag.load(.acquire)) return error.Cancelled;
    if (client.transaction != null) return error.UnsupportedLogTransaction;
    try receipt.validate();
    if (receipt.request.group != null) return error.InvalidStreamRead;
    if (expected_schema.columns.len <= 4) return error.InvalidColumnCount;
    try q.DirectTableQuery.qualify(expected_schema);
    const expected_fingerprint = try expected_schema.fingerprint();
    var page_arena = std.heap.ArenaAllocator.init(allocator);
    errdefer page_arena.deinit();
    const response = try c.DirectStreamClient.apply(&page_arena, client, .{
        .cursor = .{ .target = receipt.request.target, .read = receipt.handle() },
    });
    if (response != .cursor) return error.InvalidStreamResponse;
    try response.cursor.requireReceipt(receipt);
    _ = page_arena.reset(.retain_capacity);
    return .{
        .allocator = allocator,
        .client = client,
        .namespace = namespace,
        .receipt = receipt,
        .expected_schema = expected_schema,
        .expected_fingerprint = expected_fingerprint,
        .include_tombstones = include_tombstones,
        .limits = limits,
        .request_limit = request_limit,
        .cancellation = cancellation,
        .initial_cursor = response.cursor,
        .cursor = response.cursor,
        .page_arena = page_arena,
    };
}

pub fn deinit(self: *Self) void {
    self.page_arena.deinit();
    self.* = undefined;
}

pub fn checkCancellation(self: *const Self) !void {
    if (self.closed) return error.QueryClosed;
    if (self.cancellation) |flag| if (flag.load(.acquire)) return error.Cancelled;
}

fn charge(self: *Self) !void {
    try self.checkCancellation();
    self.rejection = null;
    if (self.requests > self.request_limit or self.request_limit - self.requests < 2) return error.QueryPageBudget;
    self.requests += 2;
}

fn rejected(self: *Self, err: anyerror) anyerror {
    self.rejection = self.client.authority.last_rejection orelse self.client.service.last_rejection;
    return err;
}

pub fn fingerprint(self: *const Self) ![32]u8 {
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.stream.slice.source.v1\x00");
    hash.update(&self.receipt.source.sha256);
    var bounds: [25]u8 = undefined;
    std.mem.writeInt(u64, bounds[0..8], self.receipt.request.from, .little);
    std.mem.writeInt(u64, bounds[8..16], self.receipt.until, .little);
    bounds[16] = @intFromBool(self.receipt.request.timestamp != null);
    if (self.receipt.request.timestamp) |ts| {
        std.mem.writeInt(i64, bounds[17..25], ts.from_us, .little);
        hash.update(&bounds);
        var until_bytes: [8]u8 = undefined;
        std.mem.writeInt(i64, &until_bytes, ts.until_us, .little);
        hash.update(&until_bytes);
    } else {
        hash.update(bounds[0..17]);
    }
    return hash.finalResult();
}

pub fn nextBorrowed(self: *Self) !?[]const f.Types.Values.Cell {
    try self.checkCancellation();
    if (self.complete) return null;
    const user_cols = self.expected_schema.columns.len - 4;
    while (true) {
        if (self.page) |page| {
            while (self.index < page.rows.len) {
                const row = page.rows[self.index];
                self.index += 1;
                if (row.tombstone and !self.include_tombstones) continue;
                if (row.value.cells.len != user_cols) return error.RelationalSourceChanged;
                @memcpy(self.row_cells[0..user_cols], row.value.cells[0..user_cols]);
                self.row_cells[user_cols] = .{ .value = .{ .atom = .{ .unsigned = self.receipt.request.target.partition } } };
                self.row_cells[user_cols + 1] = .{ .value = .{ .atom = .{ .unsigned = row.offset } } };
                self.row_cells[user_cols + 2] = if (self.timestamp_index) |idx| row.value.cells[idx] else .null;
                self.row_cells[user_cols + 3] = .{ .value = .{ .atom = .{ .boolean = row.tombstone } } };
                self.after = .{
                    .origin = self.receipt.cut.accepted.partition,
                    .operation = row.offset + 1,
                    .ordinal = row.value.identity.ordinal,
                };
                return self.row_cells[0 .. user_cols + 4];
            }
        }
        self.page = null;
        self.index = 0;
        if (self.cursor.coverage.complete) {
            self.complete = true;
            return null;
        }
        try self.charge();
        _ = self.page_arena.reset(.retain_capacity);
        const result = c.DirectStreamClient.apply(&self.page_arena, self.client, .{
            .page = .{ .cursor = self.cursor, .limits = self.limits },
        }) catch |err| return self.rejected(err);
        if (result != .page) return error.InvalidStreamResponse;
        const page = result.page;
        try page.cursor.requireReceipt(self.receipt);
        if (!std.meta.eql(page.source.declaration.stored.declaration.interpretation, self.receipt.request.target.interpretation) or
            page.source.schema.columns.len != user_cols)
        {
            return error.RelationalSourceChanged;
        }
        const timestamp_column = page.source.declaration.stored.declaration.configuration.policy.stream.timestamp_column;
        var expanded = try sliceSchema(self.page_arena.allocator(), page.source.schema, timestamp_column);
        defer expanded.deinit();
        if (!std.mem.eql(u8, &self.expected_fingerprint, &try expanded.schema.fingerprint())) return error.RelationalSourceChanged;
        self.timestamp_index = if (timestamp_column) |col_id| try page.source.schema.index(col_id) else null;
        self.cursor = page.cursor;
        self.page = page;
    }
}

pub fn nextBorrowedAfter(self: *Self, after: ?f.TableRow.Identity) !?[]const f.Types.Values.Cell {
    try self.checkCancellation();
    if (std.meta.eql(after, self.after)) return self.nextBorrowed();
    self.page = null;
    self.index = 0;
    self.after = null;
    self.complete = false;
    self.cursor = self.initial_cursor;
    while (try self.nextBorrowed()) |cells| {
        if (after == null or f.RelationalExecution.identityOrder(self.after.?, after.?) == .gt) return cells;
    }
    return null;
}

pub fn close(self: *Self) void {
    self.closed = true;
}

test "direct STREAM_SLICE relational compilation, star expansion, tombstone filtering and Table join" {
    const t = std.testing;
    const s = c.storage;
    const w = c.DirectTableProtocol;
    const Peer = struct {
        stream_source: c.DirectLogProtocol.Definition,
        queue_source: c.DirectLogProtocol.Definition,
        table_def: w.Definition,
        receipt: p.StreamRead.Receipt,
        rows: [3]s.LogBatch.EncodedRow,
        operation: p.DataLifecycle.Operation,
        key: [32]u8,
        fn cursor(self: *@This(), through: u64) p.StreamRead.Cursor {
            return .{
                .read = self.receipt.handle(),
                .coverage = .{ .cut = self.receipt.cut, .from = 0, .until = 3, .through = through, .rows = through, .complete = through == 3 },
                .authentication = @splat(17),
            };
        }
        fn invoke(raw: *anyopaque, invocation: *c.client.LocalEndpoint.Invocation) !void {
            const self: *@This() = @ptrCast(@alignCast(raw));
            const request = try invocation.request(w.Request);
            try request.validate(invocation.allocator);
            try request.proof.verify(self.key);
            const result: w.Result = switch (request.action) {
                .log_lookup => |lookup| .{ .log_lookup = if (std.mem.eql(u8, lookup.name, "events"))
                    self.stream_source
                else if (std.mem.eql(u8, lookup.name, "jobs"))
                    self.queue_source
                else
                    null },
                .lookup => |lookup| .{ .lookup = if (std.mem.eql(u8, lookup.name, "tenants")) self.table_def else null },
                .check, .check_set => .checked,
                .stream => |action| switch (action) {
                    .cursor => .{ .stream = .{ .cursor = self.cursor(0) } },
                    .page => |page_req| blk: {
                        const index = page_req.cursor.coverage.through;
                        const count: u32 = if (index >= 3) 0 else @intCast(@min(page_req.limits.rows, 3 - index));
                        const rows = try invocation.allocator.alloc(c.DirectStream.Row, count);
                        var encoded_bytes: u32 = 0;
                        for (rows, 0..) |*out, at| {
                            const row = self.rows[@intCast(index + at)];
                            out.* = .{
                                .offset = index + at,
                                .operation = self.operation,
                                .ordinal = row.ordinal,
                                .tombstone = row.tombstone,
                                .encoded = try w.Binary.encode(invocation.allocator, row.bytes),
                            };
                            encoded_bytes += @intCast(row.bytes.len + s.LogBatch.row_header_bytes);
                        }
                        const next = self.cursor(index + count);
                        break :blk .{ .stream = .{ .page = .{
                            .source = self.stream_source,
                            .rows = rows,
                            .cursor = next,
                            .examined = count,
                            .encoded_bytes = encoded_bytes,
                        } } };
                    },
                    else => return error.TestUnexpectedStreamAction,
                },
                else => return error.TestUnexpectedRequest,
            };
            const claim = request.proof.claim;
            const response: w.Response = .{
                .definition = p.Growth.current_definition,
                .context = claim.context,
                .policy_revision = 1,
                .subject = .{ .principal = claim.principal, .login_role = 1, .role = 1, .credential_epoch = claim.credential_epoch, .audience = claim.audience, .context = claim.context },
                .result = result,
            };
            try invocation.respond(try c.client.LocalEndpoint.clone(invocation.allocator, response));
        }
    };
    const scope: p.DataLifecycle.Scope = .{ .realm = 1, .resource = 2, .catalog = 3 };
    const connection: w.Connection = .{ .scope = scope, .branch = 1, .audience = 4, .principal = 5, .role = null };
    const stream_cols = [_]f.TableSchema.Column{
        .{ .id = 1, .name = "tenant", .type = .utf8, .nullable = false, .collation = .utf8_binary },
        .{ .id = 2, .name = "ts", .type = .{ .timestamp = .utc }, .nullable = false },
    };
    const stream_schema: f.TableSchema.Schema = .{ .object = 9, .revision = 1, .next_column = 3, .columns = &stream_cols, .primary_key = &.{} };
    const stream_props: c.DirectCatalog.Properties = .{ .namespace = 1, .authorization = 11, .name = try .init("events") };
    var props_buf: [4096]u8 = undefined;
    var stream_decl = try s.LogDeclaration.prepare(t.allocator, .{
        .object = .{ .scope = scope, .branch = 1, .object = 9 },
        .revision = 1,
        .schema = stream_schema,
        .properties = try stream_props.encode(&props_buf),
        .configuration = .{
            .partitioning = .{ .count = 1, .key_column = 1, .hash = .sha256_64 },
            .retention = .{ .max_age_ms = null },
            .policy = .{ .stream = .{ .compact_key_column = 1, .timestamp_column = 2 } },
        },
        .limits = .{ .append_rows = 8, .append_bytes = 8192, .claim_rows = 1, .read_rows = 8, .read_bytes = 8192, .active_leases = 1, .waiters = 1, .timer_steps = 1 },
    });
    defer stream_decl.deinit();
    const stream_stored = try stream_decl.stored();
    const stream_def: c.DirectLog.Definition = .{ .stored = stream_stored, .seed = stream_stored, .properties = stream_props, .initialization = .{ .scope = scope, .principal = 5, .operation = 1 }, .first_partition = 13 };
    var schema_buf: [f.TableSchema.max_bytes]u8 = undefined;
    const bin_stream_schema = try w.Binary.encode(t.allocator, try stream_schema.encode(&schema_buf));
    defer t.allocator.free(bin_stream_schema.base64);

    const queue_schema: f.TableSchema.Schema = .{ .object = 10, .revision = 1, .next_column = 3, .columns = &stream_cols, .primary_key = &.{} };
    const queue_props: c.DirectCatalog.Properties = .{ .namespace = 1, .authorization = 12, .name = try .init("jobs") };
    var queue_decl = try s.LogDeclaration.prepare(t.allocator, .{
        .object = .{ .scope = scope, .branch = 1, .object = 10 },
        .revision = 1,
        .schema = queue_schema,
        .properties = try queue_props.encode(&props_buf),
        .configuration = .{
            .partitioning = .{ .count = 1, .key_column = null, .hash = .sha256_64 },
            .retention = .{ .max_age_ms = null },
            .policy = .{ .queue = .{ .ordering = .unordered, .key_column = null, .lease_ms = 1000, .maximum_lease_ms = 5000, .maximum_attempts = 3, .backoff = .{ .initial_ms = 100, .maximum_ms = 1000, .multiplier = 2 }, .dead_letter = null } },
        },
        .limits = stream_stored.declaration.limits,
    });
    defer queue_decl.deinit();
    const queue_stored = try queue_decl.stored();
    const queue_def: c.DirectLog.Definition = .{ .stored = queue_stored, .seed = queue_stored, .properties = queue_props, .initialization = .{ .scope = scope, .principal = 5, .operation = 2 }, .first_partition = 14 };
    var queue_schema_buf: [f.TableSchema.max_bytes]u8 = undefined;
    const bin_queue_schema = try w.Binary.encode(t.allocator, try queue_schema.encode(&queue_schema_buf));
    defer t.allocator.free(bin_queue_schema.base64);

    const table_cols = [_]f.TableSchema.Column{
        .{ .id = 1, .name = "tenant", .type = .utf8, .nullable = false, .collation = .utf8_binary },
        .{ .id = 2, .name = "weight", .type = .int64, .nullable = false },
    };
    const table_schema: f.TableSchema.Schema = .{ .object = 20, .revision = 1, .next_column = 3, .columns = &table_cols, .primary_key = &.{1} };
    const table_props: c.DirectCatalog.Properties = .{ .namespace = 1, .authorization = 21, .name = try .init("tenants") };
    var table_decl = try s.TableDeclaration.prepare(t.allocator, .{ .kind = .table, .object = .{ .scope = scope, .branch = 1, .object = 20 }, .revision = 1, .schema = table_schema, .properties = try table_props.encode(&props_buf), .retired = false });
    defer table_decl.deinit();
    var table_schema_buf: [f.TableSchema.max_bytes]u8 = undefined;
    const bin_table_schema = try w.Binary.encode(t.allocator, try table_schema.encode(&table_schema_buf));
    defer t.allocator.free(bin_table_schema.base64);
    const table_stored = try table_decl.stored();
    const table_def: w.Definition = .{
        .interpretation = table_stored,
        .namespace = 1,
        .authorization = 21,
        .name = try .init("tenants"),
        .position = .{ .partition = 25, .next_lsn = 4 },
        .changed_lsn = 3,
        .row_count = 1,
        .schema = bin_table_schema,
    };

    const operation: p.DataLifecycle.Operation = .{ .scope = scope, .principal = 5, .operation = 100 };
    var payload_buf: [8192]u8 = undefined;
    const payload = try s.LogBatch.encode(stream_schema, operation, .stream, &.{
        .{ .cells = &.{ .{ .value = .{ .atom = .{ .bytes = "acme" } } }, .{ .value = .{ .atom = .{ .timestamp = 1_000_000 } } } } },
        .{ .tombstone = true, .cells = &.{ .{ .value = .{ .atom = .{ .bytes = "acme" } } }, .{ .value = .{ .atom = .{ .timestamp = 1_500_000 } } } } },
        .{ .cells = &.{ .{ .value = .{ .atom = .{ .bytes = "acme" } } }, .{ .value = .{ .atom = .{ .timestamp = 2_000_000 } } } } },
    }, &payload_buf);
    const target: p.StreamQueue.Partition = .{ .definition = p.Growth.current_definition, .interpretation = stream_stored.declaration.interpretation, .partition = 0 };
    const receipt: p.StreamRead.Receipt = .{
        .request = .{ .target = target, .operation = .{ .scope = scope, .principal = 5, .operation = 101 }, .group = null, .from = 0, .until = 3, .timestamp = null },
        .cut = .{ .target = target, .accepted = .{ .partition = 13, .next_lsn = 5 }, .retained_from = 0, .next = 3 },
        .until = 3,
        .source = s.LogBatch.content(payload),
        .accepted = .{ .partition = 13, .next_lsn = 6 },
    };
    const key = try p.Ed25519.KeyPair.generateDeterministic(@splat(1));
    var peer: Peer = .{
        .stream_source = .{ .declaration = stream_def, .schema = bin_stream_schema },
        .queue_source = .{ .declaration = queue_def, .schema = bin_queue_schema },
        .table_def = table_def,
        .receipt = receipt,
        .rows = undefined,
        .operation = operation,
        .key = key.public_key.toBytes(),
    };
    var iterator = try s.LogBatch.Iterator.init(payload, stream_schema, .stream, 3);
    for (&peer.rows) |*row| row.* = (try iterator.next()).?;

    var transport = c.client.Client.init(t.allocator, t.io, "http://127.0.0.1:1");
    defer transport.deinit();
    transport.local = .{ .context = &peer, .invoke = Peer.invoke };
    const caller: c.DirectTableClient = .{ .allocator = t.allocator, .authority = &transport, .service = &transport, .connection = connection, .key = key, .credential_epoch = 1 };
    const options: q.DirectRelationalQuery.Options = .{
        .consistency = .independent_table_snapshots,
        .budgets = .{ .resident_bytes = 16 * 1024 * 1024, .spill_bytes = 16 * 1024 * 1024, .result_bytes = 1024 * 1024, .output_rows = 100, .work_steps = 10000, .source_pins = 2 },
        .requests = 100,
        .spill_work = 1000,
    };

    // 1. Negative controls: QUEUE, TABLE, missing object, out-of-range partition.
    try t.expectError(error.CatalogKindMismatch, q.DirectRelationalCompilation.prepareProjectedAt(t.allocator, &.{caller}, 1, "SELECT * FROM STREAM_SLICE(jobs, PARTITION 0, OFFSET 0 TO 3)", .interactive, options, null, .read, null, null));
    try t.expectError(error.CatalogKindMismatch, q.DirectRelationalCompilation.prepareProjectedAt(t.allocator, &.{caller}, 1, "SELECT * FROM STREAM_SLICE(tenants, PARTITION 0, OFFSET 0 TO 3)", .interactive, options, null, .read, null, null));
    try t.expectError(error.CatalogNameNotFound, q.DirectRelationalCompilation.prepareProjectedAt(t.allocator, &.{caller}, 1, "SELECT * FROM STREAM_SLICE(unknown_stream, PARTITION 0, OFFSET 0 TO 3)", .interactive, options, null, .read, null, null));
    try t.expectError(error.InvalidLogPartition, q.DirectRelationalCompilation.prepareProjectedAt(t.allocator, &.{caller}, 1, "SELECT * FROM STREAM_SLICE(events, PARTITION 1, OFFSET 0 TO 3)", .interactive, options, null, .read, null, null));

    // 2. SELECT * expands only user columns (tenant, ts) and excludes tombstones by default.
    var star_comp = try q.DirectRelationalCompilation.prepareProjectedAt(t.allocator, &.{caller}, 1, "SELECT * FROM STREAM_SLICE(events, PARTITION 0, OFFSET 0 TO 3)", .interactive, options, null, .read, null, null);
    defer star_comp.deinit();
    var out_fields: [f.TableSchema.max_columns]f.Types.Field = undefined;
    const star_schema = try star_comp.plan.outputSchema(&out_fields);
    try t.expectEqual(@as(usize, 2), star_schema.structure.len);
    try t.expectEqualStrings("tenant", star_schema.structure[0].name);
    try t.expectEqualStrings("ts", star_schema.structure[1].name);

    const stream_pin: q.DirectRelationalTables.SourcePin = .{ .stream = .{ .namespace = 1, .receipt = receipt } };
    var star_query = try q.DirectRelationalQuery.openBoundPreparedPins(t.allocator, t.io, std.Io.Dir.cwd(), "test-star", caller, star_comp, &.{}, &.{stream_pin}, options, null);
    defer star_query.deinit();
    var star_count: usize = 0;
    while (try star_query.next()) |row_val| {
        var row = row_val;
        defer row.deinit();
        try t.expectEqualStrings("acme", row.cells[0].value.atom.bytes);
        star_count += 1;
    }
    try t.expectEqual(@as(usize, 2), star_count);

    // 3. Explicit _tombstone reference includes tombstones and populates system columns.
    var tomb_comp = try q.DirectRelationalCompilation.prepareProjectedAt(t.allocator, &.{caller}, 1, "SELECT tenant, _partition, _offset, _timestamp, _tombstone FROM STREAM_SLICE(events, PARTITION 0, OFFSET 0 TO 3) WHERE _tombstone = true OR _offset >= 0 ORDER BY _offset ASC", .interactive, options, null, .read, null, null);
    defer tomb_comp.deinit();
    var tomb_query = try q.DirectRelationalQuery.openBoundPreparedPins(t.allocator, t.io, std.Io.Dir.cwd(), "test-tomb", caller, tomb_comp, &.{}, &.{stream_pin}, options, null);
    defer tomb_query.deinit();
    var seen_offsets: usize = 0;
    while (try tomb_query.next()) |row_val| {
        var row = row_val;
        defer row.deinit();
        try t.expectEqual(@as(u64, 0), row.cells[1].value.atom.unsigned);
        try t.expectEqual(@as(u64, seen_offsets), row.cells[2].value.atom.unsigned);
        if (seen_offsets == 1) {
            try t.expectEqual(@as(i64, 1_500_000), row.cells[3].value.atom.timestamp);
            try t.expectEqual(true, row.cells[4].value.atom.boolean);
        } else {
            try t.expect(row.cells[3] == .value);
            try t.expectEqual(false, row.cells[4].value.atom.boolean);
        }
        seen_offsets += 1;
    }
    try t.expectEqual(@as(usize, 3), seen_offsets);

    // 4. STREAM_SLICE joined with STREAM_SLICE (exercising nextBorrowedAfter rewinds) with GROUP BY, HAVING, ORDER BY, LIMIT.
    var join_comp = try q.DirectRelationalCompilation.prepareProjectedAt(t.allocator, &.{ caller, caller }, 1, "SELECT s.tenant AS tenant, COUNT(*) AS pairs FROM STREAM_SLICE(events, PARTITION 0, OFFSET 0 TO 3) AS s INNER JOIN STREAM_SLICE(events, PARTITION 0, OFFSET 0 TO 3) AS r ON s.tenant = r.tenant GROUP BY s.tenant HAVING COUNT(*) = 4 ORDER BY tenant ASC LIMIT 5", .interactive, options, null, .read, null, null);
    defer join_comp.deinit();
    const join_pins = [_]q.DirectRelationalTables.SourcePin{ stream_pin, stream_pin };
    var join_query = try q.DirectRelationalQuery.openBoundPreparedPins(t.allocator, t.io, std.Io.Dir.cwd(), "test-join", caller, join_comp, &.{}, &join_pins, options, null);
    defer join_query.deinit();
    var first_join = (try join_query.next()).?;
    defer first_join.deinit();
    try t.expectEqualStrings("acme", first_join.cells[0].value.atom.bytes);
    try t.expectEqual(@as(u64, 4), first_join.cells[1].value.atom.unsigned);
    try t.expectEqual(@as(?f.RelationalExecution.Output, null), try join_query.next());
}
