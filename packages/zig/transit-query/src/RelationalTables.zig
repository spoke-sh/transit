//! Interactive Table source vectors over public native snapshots. Acquisition
//! owns partial-pin cleanup; aliases in one resource reuse exactly one lease.
const std = @import("std");
const q = @import("root.zig");
const c = q.catalog;
const p = q.protocol;
const g = p.Growth;
const f = q.fuze;
const r = f.Relational;
const e = f.RelationalExecution;
const Scan = @import("TableScan.zig");
const Self = @This();
pub const Binding = struct { client: *c.TableClient, name: c.TableMetadata.Name, alias: []const u8 };
pub const Consistency = enum { per_resource_snapshot_vector, atomic };
allocator: std.mem.Allocator,
scans: [r.max_sources]?Scan = @splat(null),
declarations: [r.max_sources]r.Source = undefined,
cuts: [r.max_sources]r.Cut = undefined,
count: usize,
requests: u64 = 0,
request_limit: u64,
closed: bool = false,

/// Clients, aliases and their credentials borrow the caller. No plan may borrow
/// declarations/cuts before this owner reaches its stable address.
pub fn open(allocator: std.mem.Allocator, bindings: []const Binding, nonces: [r.max_sources][16]u8, consistency: Consistency, requests: u64, cancellation: ?*const std.atomic.Value(bool)) !Self {
    if (consistency != .per_resource_snapshot_vector) return error.UnsupportedRelationalConsistency;
    if (bindings.len == 0 or bindings.len > r.max_sources) return error.InvalidRelationalSources;
    if (requests == 0) return error.InvalidQueryBudget;
    try validateBindings(bindings);
    var self: Self = .{ .allocator = allocator, .count = bindings.len, .request_limit = requests };
    errdefer self.deinit();
    for (bindings, 0..) |binding, i| {
        var previous: ?usize = null;
        for (bindings[0..i], 0..) |earlier, j| if (binding.client.connection.scope.resource == earlier.client.connection.scope.resource) {
            previous = j;
            break;
        };
        if (self.requests >= requests) return error.QueryPageBudget;
        self.scans[i] = if (previous) |index|
            try Scan.openAt(allocator, binding.client, binding.name, self.scans[index].?.source, requests - self.requests)
        else
            try Scan.open(allocator, binding.client, binding.name, nonces[i], requests - self.requests, cancellation);
        const scan = &self.scans[i].?;
        self.requests = try std.math.add(u64, self.requests, scan.requests);
        const schema = scan.definition.?.schema.schema;
        const connection = binding.client.connection;
        self.declarations[i] = .{ .alias = binding.alias, .realm = connection.scope.realm, .resource = connection.scope.resource, .catalog = connection.scope.catalog, .owner = connection.owner, .schema = schema };
        self.cuts[i] = .{ .resource = connection.scope.resource, .revision = scan.view.revision, .commitment = commitment(scan), .schema = try schema.fingerprint() };
    }
    try self.authorize();
    return self;
}
/// Shared route validation for metadata compilation and snapshot execution.
/// Checking route coherence grants neither metadata access nor execution rights.
pub fn validateBindings(bindings: []const Binding) !void {
    if (bindings.len == 0 or bindings.len > r.max_sources) return error.InvalidRelationalSources;
    for (bindings, 0..) |binding, i| {
        try binding.client.connection.validate();
        if (binding.alias.len == 0 or binding.alias.len > 255 or !std.unicode.utf8ValidateSlice(binding.alias) or std.mem.indexOfScalar(u8, binding.alias, 0) != null) return error.InvalidRelationalName;
        const first = bindings[0].client;
        if (binding.client.connection.scope.realm != first.connection.scope.realm) return error.CrossRealmRelationalQuery;
        if (binding.client.transport != first.transport or binding.client.connection.principal != first.connection.principal or binding.client.connection.role != first.connection.role or !std.mem.eql(u8, &binding.client.key.public_key.bytes, &first.key.public_key.bytes)) return error.RelationalCallerChanged;
        for (bindings[0..i]) |earlier| if (std.mem.eql(u8, earlier.alias, binding.alias)) return error.DuplicateRelationalAlias;
    }
}
pub fn deinit(self: *Self) void {
    // Borrowing scans release only descriptors; one owner closes each pin.
    for (&self.scans) |*slot| if (slot.*) |*scan| scan.deinit();
    self.* = undefined;
}
pub fn close(self: *Self) !void {
    var failure: ?anyerror = null;
    for (&self.scans) |*slot| if (slot.*) |*scan| if (scan.owns_lease) {
        scan.source.close() catch |err| {
            failure = err;
        };
    };
    self.closed = true;
    if (failure) |err| return err;
}
pub fn validate(self: *Self, bound: r.Bound) !void {
    if (self.closed) return error.QueryClosed;
    try bound.validate();
    if (bound.plan.lifetime != .interactive or bound.plan.sources.len != self.count) return error.RelationalSourceChanged;
    for (bound.plan.sources, bound.cuts, 0..) |source, cut, i| {
        const expected = self.declarations[i];
        if (source.realm != expected.realm or source.resource != expected.resource or source.catalog != expected.catalog or source.owner != expected.owner or !std.mem.eql(u8, source.alias, expected.alias) or !std.mem.eql(u8, &try source.schema.fingerprint(), &self.cuts[i].schema) or !std.meta.eql(cut, self.cuts[i])) return error.RelationalSourceChanged;
    }
    try self.authorize();
}
fn remaining(self: *Self, scan: *Scan) !void {
    if (self.requests >= self.request_limit) return error.QueryPageBudget;
    scan.request_limit = std.math.add(u64, scan.requests, self.request_limit - self.requests) catch return error.QueryPageBudget;
}
fn authorize(self: *Self) !void {
    if (self.closed) return error.QueryClosed;
    // Every resource's lease is checked. The combined read checks native rights
    // and catalog identities; the final guard checks ALL logical source rights
    // together under the same original subject and current policy revision.
    var requested: [g.SnapshotRead.current_resources]?g.SnapshotRead.Current = @splat(null);
    for (self.scans[0..self.count]) |slot| {
        const scan = slot.?;
        const selection = Scan.metadata(scan.connection)[0].?;
        var index: usize = 0;
        while (index < requested.len and requested[index] != null and requested[index].?.resource != selection.resource) : (index += 1) {}
        if (index == requested.len) return error.InvalidRelationalSources;
        if (requested[index] == null) requested[index] = .{ .resource = selection.resource, .keys = @splat(null) };
        for (selection.keys) |candidate| if (candidate) |key| {
            var at: usize = 0;
            while (at < g.page_size and requested[index].?.keys[at] != null and !requested[index].?.keys[at].?.eql(key)) : (at += 1) {}
            if (at == g.page_size) return error.InvalidRelationalSources;
            requested[index].?.keys[at] = key;
        };
    }
    var anchor: usize = 0;
    for (self.scans[0..self.count], 0..) |slot, i| if (slot.?.source.snapshot.hard_deadline_ms < self.scans[anchor].?.source.snapshot.hard_deadline_ms) {
        anchor = i;
    };
    for (self.scans[0..self.count], 0..) |_, i| {
        if (i == anchor or !self.scans[i].?.owns_lease) continue;
        const scan = &self.scans[i].?;
        try self.remaining(scan);
        const before = scan.requests;
        defer self.requests += scan.requests - before;
        try scan.validateCurrent(false);
    }
    const scan = &self.scans[anchor].?;
    try self.remaining(scan);
    const before = scan.requests;
    defer self.requests += scan.requests - before;
    const response = try scan.request(.{ .snapshot = .{ .existing = scan.source.snapshot.id }, .current = requested });
    var guard: ?p.Authorization.Guard = null;
    for (self.scans[0..self.count]) |slot| {
        const selected = slot.?;
        var found = false;
        for (response.current, requested) |current, selection| if (current) |value| {
            if (value.resource.id != selected.connection.scope.resource) continue;
            if (value.resource.writer != selected.connection.owner or value.resource.phase != .active) return error.CatalogOwnerChanged;
            var batch: q.wire.ResourceReader.Batch = .{ .resource = value.resource, .view = .{ .resource = value.resource.id, .revision = value.resource.revision }, .keys = selection.?.keys, .entries = value.entries };
            if (!std.meta.eql(try Scan.configurationAt(selected.connection, &batch), selected.configuration)) return error.CatalogConfigurationChanged;
            found = true;
        };
        if (!found) return error.InvalidResourceRead;
        const definition = selected.definition.?;
        const requirement = try c.TableAuthority.guard(scan.authority.subject, selected.configuration.authority, definition.namespace, definition.authority, .read);
        guard = if (guard) |previous| try previous.merge(requirement) else requirement;
    }
    _ = try scan.requireAuthorization(guard orelse return error.InvalidRelationalSources);
}
pub fn next(self: *Self, source: u8, after: ?r.RowIdentity) !?e.Row {
    if (self.closed) return error.QueryClosed;
    if (source >= self.count) return error.UnknownRelationalSource;
    const scan = &self.scans[source].?;
    try self.remaining(scan);
    const before = scan.requests;
    defer self.requests += scan.requests - before;
    var row = (try scan.nextAfter(after)) orelse return null;
    defer row.deinit();
    var result: e.Row = .{ .identity = scan.after.? };
    for (self.declarations[source].schema.columns, row.cells, 0..) |column, value, i| {
        if (column.type != .int64) continue;
        result.values[i] = if (value == .null) null else integer: {
            if (value != .value or value.value != .atom or value.value.atom != .signed) return error.InvalidRelationalSourceRow;
            break :integer std.math.cast(i64, value.value.atom.signed) orelse return error.InvalidRelationalSourceRow;
        };
    }
    return result;
}
fn commitment(scan: *const Scan) [32]u8 {
    var hash: std.crypto.hash.sha2.Sha256 = .init(.{});
    hash.update("transit.relational.leased-resource.v1\x00");
    hash.update(@tagName(g.current_definition));
    hash.update(&scan.source.snapshot.id.epoch);
    inline for (.{ scan.connection.scope.realm, scan.view.resource, scan.view.revision, scan.source.snapshot.id.serial }) |value| {
        var bytes: [8]u8 = undefined;
        std.mem.writeInt(u64, &bytes, value, .little);
        hash.update(&bytes);
    }
    return hash.finalResult();
}

test "relational routes cannot combine different selected roles" {
    var transport: q.wire.Client = undefined;
    var left: c.TableClient = .{ .transport = &transport, .connection = .{ .scope = .{ .realm = 1, .resource = 7, .catalog = 9 }, .owner = 3, .principal = 17, .role = 23 }, .key = try p.Ed25519.KeyPair.generateDeterministic(@splat(5)) };
    var right = left;
    const bindings = [_]Binding{ .{ .client = &left, .name = try .init("items"), .alias = "a" }, .{ .client = &right, .name = try .init("items"), .alias = "b" } };
    try validateBindings(&bindings);
    right.connection.role = 29;
    try std.testing.expectError(error.RelationalCallerChanged, validateBindings(&bindings));
    right.connection.role = null;
    try std.testing.expectError(error.RelationalCallerChanged, validateBindings(&bindings));
}
