//! Shared catalog Table scan over a leased resource cut. All retained caches
//! contain immutable data; current policy validation remains explicit.
const std = @import("std");
const q = @import("root.zig");
const c = q.catalog;
const s = q.station;
const f = q.fuze;
const p = q.protocol;
const g = p.Growth;
const logical = f.LogicalQuery;
const Cached = struct { key: p.Value, entry: ?g.Entry };
const Scan = @This();
allocator: std.mem.Allocator,
connection: c.TableClient.Connection,
configuration: c.TableCatalogRecords.Configuration,
authority: c.TableAuthority.Context,
definition: ?c.TableCatalog.Definition = null,
history_object: ?u64 = null,
source: q.wire.SnapshotReader,
owns_lease: bool = true,
view: @FieldType(q.wire.SnapshotReader, "view"),
cache: [64]?Cached = @splat(null),
cache_slot: usize = 0,
table_nodes: s.ImmutableIndex.Cache = .{},
requests: u64 = 1,
request_limit: u64,
after: ?f.TableRow.Identity = null,
point: ?[]const f.Types.Values.Cell = null,
point_read: bool = false,
row_references: [g.page_size]s.TableData.RowReference = undefined,
reference_count: usize = 0,
reference_index: usize = 0,
reference_end: bool = false,
scanned: u64 = 0,
complete: bool = false,
rejection: ?p.ErrorCode = null,
pub fn metadata(connection: c.TableClient.Connection) [g.SnapshotRead.current_resources]?g.SnapshotRead.Current {
    var keys: g.SnapshotRead.Keys = @splat(null);
    keys[0] = c.Records.key(connection.scope.catalog, 'c', 0, 0);
    return .{ .{ .resource = connection.scope.resource, .keys = keys }, null };
}
pub fn current(connection: c.TableClient.Connection, result: g.SnapshotRead.Result) !q.wire.ResourceReader.Batch {
    const selection = metadata(connection)[0].?;
    const value = result.current[0] orelse return error.InvalidResourceRead;
    if (value.resource.id != connection.scope.resource or value.resource.writer != connection.owner or value.resource.phase != .active) return error.CatalogOwnerChanged;
    return .{ .resource = value.resource, .view = .{ .resource = value.resource.id, .revision = value.resource.revision }, .keys = selection.keys, .entries = value.entries };
}
pub fn configurationAt(connection: c.TableClient.Connection, batch: *q.wire.ResourceReader.Batch) !c.TableCatalogRecords.Configuration {
    const config = try c.Records.decode(c.TableCatalogRecords.Configuration, 'C', (try batch.read(metadata(connection)[0].?.keys[0].?)) orelse return error.CatalogNotInitialized);
    if (!std.meta.eql(config.scope, connection.scope) or config.owner != connection.owner) return error.CatalogConfigurationChanged;
    return config;
}
pub fn open(allocator: std.mem.Allocator, client: *c.TableClient, name: c.TableMetadata.Name, nonce: [16]u8, request_limit: u64, cancellation: ?*const std.atomic.Value(bool)) !Scan {
    var self = try openResource(allocator, client, nonce, request_limit, cancellation);
    errdefer self.deinit();
    const catalog: c.TableCatalog = .{ .configuration = self.configuration, .namespace = self.connection.namespace };
    self.definition = (try catalog.lookup(allocator, &self, client.connection.principal, name)) orelse return error.TableNotFound;
    try self.checkRead();
    return self;
}
/// Authorized backing cut for immutable Table history, including retired Tables.
/// Opening a resource does not resolve a current name or adopt a new object.
pub fn openResource(allocator: std.mem.Allocator, client: *c.TableClient, nonce: [16]u8, request_limit: u64, cancellation: ?*const std.atomic.Value(bool)) !Scan {
    if (request_limit == 0) return error.InvalidQueryBudget;
    try client.connection.validate();
    const resources = client.resources();
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
    var self: Scan = .{ .allocator = allocator, .connection = client.connection, .configuration = try configurationAt(client.connection, &batch), .authority = try client.authorizationContext(), .source = acquired.reader, .view = acquired.reader.view, .request_limit = request_limit };
    self.source.cancellation = cancellation;
    for (requested[0].?.keys, acquired.result.points) |key, value| if (key) |address| self.remember(address, value);
    const catalog: c.TableCatalog = .{ .configuration = self.configuration, .namespace = self.connection.namespace };
    _ = try catalog.authorize(&self, client.connection.principal, .inspect);
    return self;
}
pub fn authorizationSubject(self: *Scan, who: u64) !p.Authorization.Subject {
    return self.authority.authorizationSubject(who);
}
pub fn requireAuthorization(self: *Scan, requested: p.Authorization.Guard) !p.Authorization.Verified {
    var authority = self.authority;
    authority.budget = .{ .used = &self.requests, .limit = self.request_limit };
    return authority.requireAuthorization(requested);
}
pub fn checkRead(self: *Scan) !void {
    if (self.definition) |definition| {
        _ = try self.requireAuthorization(try c.TableAuthority.guard(self.authority.subject, self.configuration.authority, definition.namespace, definition.authority, .read));
    } else if (self.history_object) |object| {
        const catalog: c.TableCatalog = .{ .configuration = self.configuration, .namespace = self.connection.namespace };
        _ = try catalog.authorizeObject(self, self.connection.principal, object, .read);
    } else {
        _ = try self.requireAuthorization(try c.TableAuthority.guard(self.authority.subject, self.configuration.authority, null, null, .database));
    }
}
pub fn fingerprint(self: *const Scan) ![32]u8 {
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
    const rejection = self.source.client.wire.last_rejection;
    if (self.owns_lease) self.source.close() catch {};
    self.source.client.wire.last_rejection = rejection;
    if (self.definition) |*definition| definition.deinit();
    self.* = undefined;
}
/// Reuse an already retained resource cut for another Table/alias. The
/// owning scan alone releases this lease. Never open a second resource cut.
pub fn openAt(allocator: std.mem.Allocator, client: *c.TableClient, name: c.TableMetadata.Name, source: q.wire.SnapshotReader, request_limit: u64) !Scan {
    if (source.view.resource != client.connection.scope.resource or source.client.principal != client.resources().principal or source.client.wire != client.transport) return error.RelationalSourceChanged;
    var retained = source;
    const requested = metadata(client.connection);
    const response = try retained.batch(.{ .snapshot = .{ .existing = source.snapshot.id }, .current = requested, .points = requested[0].?.keys });
    var batch = try current(client.connection, response);
    var self: Scan = .{ .allocator = allocator, .connection = client.connection, .configuration = try configurationAt(client.connection, &batch), .authority = try client.authorizationContext(), .source = retained, .owns_lease = false, .view = retained.view, .request_limit = request_limit };
    errdefer self.deinit();
    for (requested[0].?.keys, response.points) |key, value| if (key) |address| self.remember(address, value);
    const catalog: c.TableCatalog = .{ .configuration = self.configuration, .namespace = self.connection.namespace };
    self.definition = (try catalog.lookup(allocator, &self, client.connection.principal, name)) orelse return error.TableNotFound;
    try self.checkRead();
    return self;
}
pub fn nextAfter(self: *Scan, after: ?f.TableRow.Identity) !?logical.Row {
    if (!std.meta.eql(after, self.after)) {
        if (after != null) return error.InvalidRelationalSourceOrder;
        self.after = null;
        self.reference_count = 0;
        self.reference_index = 0;
        self.reference_end = false;
        self.scanned = 0;
        self.complete = false;
    }
    return self.next();
}
pub fn checkCancellation(self: *const Scan) !void {
    if (self.source.cancellation) |flag| if (flag.load(.acquire)) return error.Cancelled;
}
pub fn request(self: *Scan, value: g.SnapshotRead.Query) !g.SnapshotRead.Result {
    try self.checkCancellation();
    if (self.requests == self.request_limit) return error.QueryPageBudget;
    self.requests += 1;
    return self.source.batch(value) catch |err| {
        if (err == error.AccessDenied or err == error.Rejected or err == error.Conflict) self.rejection = self.source.client.wire.last_rejection;
        return err;
    };
}
pub fn validateCurrent(self: *Scan, finish: bool) !void {
    const response = try self.request(.{ .snapshot = .{ .existing = self.source.snapshot.id }, .current = metadata(self.connection), .finish = finish });
    var batch = try current(self.connection, response);
    if (!std.meta.eql(try configurationAt(self.connection, &batch), self.configuration)) return error.CatalogConfigurationChanged;
    try self.checkRead();
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
    return self.nextAllocated(self.allocator);
}
/// Row decoding may borrow a host cache; source metadata and native I/O do not.
pub fn nextAllocated(self: *Scan, row_allocator: std.mem.Allocator) !?logical.Row {
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
        break :point (try data.get(row_allocator, &pages, id)) orelse return error.InvalidTableIndex;
    } else batch: {
        if (self.reference_index == self.reference_count) {
            if (self.reference_end) break :batch null;
            self.reference_count = try data.references(&pages, self.after, &self.row_references);
            self.reference_index = 0;
            self.reference_end = self.reference_count < self.row_references.len;
            if (self.reference_count == 0) break :batch null;
        }
        const row = try data.loadReference(row_allocator, &pages, self.row_references[self.reference_index]);
        self.reference_index += 1;
        break :batch row;
    };
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

/// Original stable identity for private physical-batch provenance.
pub fn batchIdentity(self: *const Scan) ?f.TableRow.Identity {
    return self.after;
}
