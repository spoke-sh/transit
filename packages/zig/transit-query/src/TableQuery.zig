//! Catalog-routed finite logical SELECT over one leased native resource cut.
//! General Table roots/schema stay frozen; scoped and native rights stay current.
const std = @import("std");
const q = @import("root.zig");
const c = q.catalog;
const s = q.station;
const f = q.fuze;
const p = q.protocol;
const g = p.Growth;
const logical = f.LogicalQuery;
const Self = @This();
pub const Limits = struct {
    requests: u64,
    rows: u64,
    result_bytes: u64,
    pub fn validate(self: Limits) !void {
        if (self.requests == 0 or self.rows == 0 or self.result_bytes == 0) return error.InvalidQueryBudget;
    }
};
compiled: f.TableSelect.Owned,
execution: logical.Execution(Scan, .selected_prefix),
limits: Limits,
result_bytes: u64,
complete: bool = false,
failed: bool = false,
native_rejection: ?p.ErrorCode = null,

pub fn open(allocator: std.mem.Allocator, client: *c.TableClient, text: []const u8, nonce: [16]u8, limits: Limits, cancellation: ?*const std.atomic.Value(bool), location: ?*f.Sql.Location) !Self {
    try client.connection.validate();
    try limits.validate();
    if (cancellation) |flag| if (flag.load(.acquire)) return error.Cancelled;
    var names: std.heap.ArenaAllocator = .init(allocator);
    defer names.deinit();
    const name = try c.TableMetadata.Name.init(try f.TableSelect.targetDiagnostic(names.allocator(), text, location));
    var scan = try Scan.open(allocator, client, name, nonce, limits.requests, cancellation);
    errdefer {
        const native = scan.rejection;
        scan.deinit();
        client.transport.last_rejection = native;
    }
    const definition = &scan.definition.?;
    var fields: [f.TableSchema.max_columns]f.Types.Field = undefined;
    var compiled = try f.TableSelect.compile(allocator, text, definition.metadata.name.slice(), try definition.schema.schema.rowType(&fields), try scan.fingerprint(), location);
    errdefer compiled.deinit();
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
    return .{ .compiled = compiled, .execution = try .init(scan, compiled.plan), .limits = limits, .result_bytes = encoded.len };
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
const Cached = struct { key: p.Value, entry: ?g.Entry };
const Scan = struct {
    allocator: std.mem.Allocator,
    connection: c.TableClient.Connection,
    configuration: c.TableCatalogRecords.Configuration,
    definition: ?c.TableCatalog.Definition = null,
    source: q.wire.SnapshotReader,
    view: @FieldType(q.wire.SnapshotReader, "view"),
    cache: [64]?Cached = @splat(null),
    cache_slot: usize = 0,
    table_nodes: s.ImmutableIndex.Cache = .{},
    requests: u64 = 1,
    request_limit: u64,
    after: ?f.TableRow.Identity = null,
    point: ?[]const f.Types.Values.Cell = null,
    point_read: bool = false,
    scanned: u64 = 0,
    complete: bool = false,
    rejection: ?p.ErrorCode = null,
    fn metadata(connection: c.TableClient.Connection) [g.SnapshotRead.current_resources]?g.SnapshotRead.Current {
        var keys: g.SnapshotRead.Keys = @splat(null);
        keys[0] = c.Records.key(connection.scope.catalog, 'c', 0, 0);
        keys[1] = c.Records.key(connection.scope.catalog, 'p', connection.principal, 0);
        return .{ .{ .resource = connection.scope.resource, .keys = keys }, null };
    }
    fn current(connection: c.TableClient.Connection, result: g.SnapshotRead.Result) !q.wire.ResourceReader.Batch {
        const selection = metadata(connection)[0].?;
        const value = result.current[0] orelse return error.InvalidResourceRead;
        if (value.resource.id != connection.scope.resource or value.resource.writer != connection.owner or value.resource.phase != .active) return error.CatalogOwnerChanged;
        return .{ .resource = value.resource, .view = .{ .resource = value.resource.id, .revision = value.resource.revision }, .keys = selection.keys, .entries = value.entries };
    }
    fn configurationAt(connection: c.TableClient.Connection, batch: *q.wire.ResourceReader.Batch) !c.TableCatalogRecords.Configuration {
        const config = try c.Records.decode(c.TableCatalogRecords.Configuration, 'C', (try batch.read(metadata(connection)[0].?.keys[0].?)) orelse return error.CatalogNotInitialized);
        if (!std.meta.eql(config.scope, connection.scope) or config.owner != connection.owner) return error.CatalogConfigurationChanged;
        const catalog: c.TableCatalog = .{ .configuration = config };
        _ = try catalog.authorize(batch, connection.principal, .inspect);
        _ = try catalog.authorize(batch, connection.principal, .read);
        return config;
    }
    fn open(allocator: std.mem.Allocator, client: *c.TableClient, name: c.TableMetadata.Name, nonce: [16]u8, request_limit: u64, cancellation: ?*const std.atomic.Value(bool)) !Scan {
        const resources: q.wire.ResourceReader = .{ .wire = client.transport, .realm = client.connection.scope.realm, .principal = client.connection.principal, .key = client.key };
        const support = try q.wire.SnapshotReader.support(resources);
        const requested = metadata(client.connection);
        var acquired = try support.acquire(.{ .snapshot = .{ .open = .{ .resource = client.connection.scope.resource, .nonce = nonce } }, .current = requested, .points = requested[0].?.keys });
        errdefer {
            const native = client.transport.last_rejection;
            acquired.reader.close() catch {};
            client.transport.last_rejection = native;
        }
        if (acquired.reader.snapshot.resource.writer != client.connection.owner or acquired.reader.snapshot.resource.phase != .active) return error.CatalogOwnerChanged;
        var batch = try current(client.connection, acquired.result);
        var self: Scan = .{ .allocator = allocator, .connection = client.connection, .configuration = try configurationAt(client.connection, &batch), .source = acquired.reader, .view = acquired.reader.view, .request_limit = request_limit };
        self.source.cancellation = cancellation;
        for (requested[0].?.keys, acquired.result.points) |key, value| if (key) |address| self.remember(address, value);
        const catalog: c.TableCatalog = .{ .configuration = self.configuration };
        _ = try catalog.authorize(&self, client.connection.principal, .read);
        self.definition = (try catalog.lookup(allocator, &self, client.connection.principal, name)) orelse return error.TableNotFound;
        return self;
    }
    fn fingerprint(self: *const Scan) ![32]u8 {
        const definition = self.definition.?;
        const spec = try definition.metadata.spec();
        const head = try definition.head.encode();
        var digest: std.crypto.hash.sha2.Sha256 = .init(.{});
        digest.update("transit.table.query.source.v1\x00");
        digest.update(@tagName(g.current_definition));
        inline for (.{ self.connection.scope.realm, self.connection.scope.resource, self.connection.scope.catalog, self.connection.owner, self.view.revision, definition.metadata.object }) |value| {
            var bytes: [8]u8 = undefined;
            std.mem.writeInt(u64, &bytes, value, .little);
            digest.update(&bytes);
        }
        digest.update(&spec.digest);
        digest.update(head.slice());
        return digest.finalResult();
    }
    pub fn deinit(self: *Scan) void {
        self.source.close() catch {};
        if (self.definition) |*definition| definition.deinit();
        self.* = undefined;
    }
    fn checkCancellation(self: *const Scan) !void {
        if (self.source.cancellation) |flag| if (flag.load(.acquire)) return error.Cancelled;
    }
    fn request(self: *Scan, value: g.SnapshotRead.Query) !g.SnapshotRead.Result {
        try self.checkCancellation();
        if (self.requests == self.request_limit) return error.QueryPageBudget;
        self.requests += 1;
        return self.source.batch(value) catch |err| {
            if (err == error.AccessDenied or err == error.Rejected or err == error.Conflict) self.rejection = self.source.client.wire.last_rejection;
            return err;
        };
    }
    fn validateCurrent(self: *Scan, finish: bool) !void {
        const response = try self.request(.{ .snapshot = .{ .existing = self.source.snapshot.id }, .current = metadata(self.connection), .finish = finish });
        var batch = try current(self.connection, response);
        if (!std.meta.eql(try configurationAt(self.connection, &batch), self.configuration)) return error.CatalogConfigurationChanged;
    }
    fn remember(self: *Scan, key: p.Value, entry: ?g.Entry) void {
        self.cache[self.cache_slot] = .{ .key = key, .entry = entry };
        self.cache_slot = (self.cache_slot + 1) % self.cache.len;
    }
    pub fn read(self: *Scan, key: p.Value) !?p.Value {
        try self.checkCancellation();
        for (self.cache) |slot| if (slot) |cached| if (cached.key.eql(key)) return if (cached.entry) |entry| entry.value else null;
        try self.prefetch(&.{key});
        for (self.cache) |slot| if (slot) |cached| if (cached.key.eql(key)) return if (cached.entry) |entry| entry.value else null;
        return error.InvalidResourceRead;
    }
    pub fn prefetch(self: *Scan, keys: []const p.Value) !void {
        if (keys.len > g.page_size) return error.InvalidResourceRead;
        var missing: g.SnapshotRead.Keys = @splat(null);
        var count: usize = 0;
        next_key: for (keys) |key| {
            for (self.cache) |slot| if (slot) |cached| if (cached.key.eql(key)) continue :next_key;
            for (missing[0..count]) |earlier| if (earlier.?.eql(key)) continue :next_key;
            missing[count] = key;
            count += 1;
        }
        if (count == 0) return;
        const result = try self.request(.{ .snapshot = .{ .existing = self.source.snapshot.id }, .points = missing });
        for (missing[0..count], result.points[0..count]) |key, value| self.remember(key.?, value);
    }
    pub fn page(self: *Scan, after: ?p.Value) !g.Batch(g.Entry, p.Value) {
        const result = try self.request(.{ .snapshot = .{ .existing = self.source.snapshot.id }, .range = .{ .after = after, .limit = g.page_size } });
        var batch: g.Batch(g.Entry, p.Value) = .{ .next = result.next };
        for (result.entries[0..g.page_size], &batch.entries) |entry, *slot| {
            slot.* = entry;
            if (entry) |value| self.remember(value.key, value);
        }
        return batch;
    }
    pub fn next(self: *Scan) !?logical.Row {
        if (self.complete) return null;
        try self.checkCancellation();
        const definition = &self.definition.?;
        const data: s.TableData = .{ .schema = definition.schema.schema, .index = definition.head.index };
        var pages: s.TablePages.Reader(*Scan) = .{ .pages = .{ .resource = self.view.resource, .object = definition.metadata.object }, .source = self };
        pages.cache = &self.table_nodes;
        const selected = if (self.point) |key| point: {
            if (self.point_read) break :point null;
            self.point_read = true;
            const id = (try data.findKey(self.allocator, &pages, key)) orelse break :point null;
            break :point (try data.get(self.allocator, &pages, id)) orelse return error.InvalidTableIndex;
        } else try data.next(self.allocator, &pages, self.after);
        if (selected) |owned| {
            var row = owned;
            errdefer row.deinit();
            self.after = row.identity;
            self.scanned = try std.math.add(u64, self.scanned, 1);
            // Transfer the decoded row's single arena, including nested cells
            // and its physical descriptor, into the shared pull executor.
            return .{ .arena = row.value.descriptor.arena, .cells = row.row().cells };
        }
        if (self.point == null and self.scanned != definition.head.rows) return error.InvalidTableIndex;
        self.complete = true;
        return null;
    }
};

test "typed Table query validates budgets and connection before source access" {
    const t = std.testing;
    var caller: c.TableClient = .{ .transport = undefined, .connection = .{ .scope = .{ .realm = 1, .resource = 2, .catalog = 3 }, .owner = 4, .principal = 5 }, .key = try p.Ed25519.KeyPair.generateDeterministic(@splat(7)) };
    const limits: Limits = .{ .requests = 100, .rows = 100, .result_bytes = 1024 };
    inline for (.{ "requests", "rows", "result_bytes" }) |field| {
        var invalid = limits;
        @field(invalid, field) = 0;
        try t.expectError(error.InvalidQueryBudget, open(t.allocator, &caller, "SELECT * FROM people", @splat(1), invalid, null, null));
    }
    const cancelled = std.atomic.Value(bool).init(true);
    try t.expectError(error.Cancelled, open(t.allocator, &caller, "SELECT * FROM people", @splat(1), limits, &cancelled, null));
    caller.connection.scope.resource = 0;
    try t.expectError(error.InvalidCatalogIdentity, open(t.allocator, &caller, "SELECT * FROM people", @splat(1), limits, null, null));
}
test "invalid Table SELECT headers retain location before acquiring a source" {
    var client: c.TableClient = .{ .transport = undefined, .connection = .{ .scope = .{ .realm = 1, .resource = 7, .catalog = 9 }, .owner = 3, .principal = 17 }, .key = try p.Ed25519.KeyPair.generateDeterministic(@splat(10)) };
    var location: f.Sql.Location = .{ .offset = 999 };
    try std.testing.expectError(error.InvalidSqlSyntax, open(std.testing.allocator, &client, "SELECT FROM people", @splat(1), .{ .requests = 100, .rows = 100, .result_bytes = 1024 }, null, &location));
    try std.testing.expectEqual(@as(usize, 7), location.offset);
}
