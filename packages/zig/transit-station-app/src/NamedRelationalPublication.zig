//! Saved original-caller publication work. Compilation is inert; explicit graph
//! registration precedes a separately committed native publication. No method
//! signs on behalf of the caller, creates a query or hides uncertain acceptance.
const std = @import("std");
const app = @import("root.zig");
const q = app.query;
const p = app.protocol;
const c = q.catalog;
const r = app.NamedRelationalRecords;
const Self = @This();
pub const max_sources = q.fuze.Relational.max_sources;
pub const max_saved_bytes = 2 * q.RelationalBundle.max_bytes + 16384;
pub const Registration = struct { connection: c.DirectTableProtocol.Connection, operation: u64 };

definition: p.Growth.Definition,
scope: r.Scope,
proposal: r.Proposal,
bundle: c.DirectTableProtocol.Binary,
bindings: [max_sources]?c.DirectDependency.Binding,

pub fn prepare(allocator: std.mem.Allocator, scope: r.Scope, draft: r.Draft, bundle: q.RelationalBundle, registrations: []const Registration) !std.json.Parsed(Self) {
    const proposal = try r.Proposal.prepare(scope, draft, bundle);
    const reference = try proposal.reference(scope);
    var value: Self = .{ .definition = p.Growth.current_definition, .scope = scope, .proposal = proposal, .bundle = undefined, .bindings = @splat(null) };
    var count: usize = 0;
    for (bundle.sources, 0..) |source, index| {
        if (try bundle.sourceOrdinal(index) != index) continue;
        if (count >= registrations.len) return error.InvalidNamedQuery;
        const selected = registrations[count];
        value.bindings[count] = .{
            .definition = p.Growth.current_definition,
            .connection = selected.connection,
            .operation = selected.operation,
            .edge = .{ .source = source.interpretation.interpretation, .dependent = .{ .kind = if (bundle.plan.lifetime == .captured) .captured else .maintained, .interpretation = try reference.interpretation() }, .privileges = c.TableAuthority.select },
            .action = .register,
            .authority = .dependent,
        };
        count += 1;
    }
    if (count != registrations.len) return error.InvalidNamedQuery;
    var binary: [q.RelationalBundle.max_bytes]u8 = undefined;
    value.bundle = try c.DirectTableProtocol.Binary.encode(allocator, try bundle.encode(&binary));
    defer allocator.free(value.bundle.base64);
    const bytes = try save(allocator, value);
    defer allocator.free(bytes);
    return load(allocator, bytes);
}

pub fn validate(self: Self, allocator: std.mem.Allocator) !void {
    if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
    try self.scope.validate();
    const bytes = try self.bundle.decode(allocator, q.RelationalBundle.max_bytes);
    defer allocator.free(bytes);
    var decoded = try q.RelationalBundle.decode(allocator, bytes);
    defer decoded.deinit();
    const bundle = decoded.bundle;
    const proposal = self.proposal;
    const expected = try r.Proposal.prepare(self.scope, .{ .name = proposal.name, .object = proposal.object, .expected = proposal.expected, .peer = proposal.peer, .request = proposal.request }, bundle);
    if (!std.meta.eql(proposal, expected)) return error.NamedQueryChanged;
    const reference = try proposal.reference(self.scope);
    var count: usize = 0;
    for (bundle.sources, 0..) |source, index| {
        if (try bundle.sourceOrdinal(index) != index) continue;
        const binding = self.bindings[count] orelse return error.InvalidNamedQuery;
        try binding.validate();
        const edge: c.DirectDependency.Edge = .{ .source = source.interpretation.interpretation, .dependent = .{ .kind = if (bundle.plan.lifetime == .captured) .captured else .maintained, .interpretation = try reference.interpretation() }, .privileges = c.TableAuthority.select };
        if (!std.meta.eql(edge, binding.edge) or binding.connection.audience != source.owner or binding.action != .register or binding.authority != .dependent) return error.NamedQueryChanged;
        for (self.bindings[0..count]) |earlier| if (std.meta.eql(earlier.?.identity(), binding.identity())) return error.DataIdentityConflict;
        count += 1;
    }
    for (self.bindings[count..]) |binding| if (binding != null) return error.InvalidNamedQuery;
}

pub fn save(allocator: std.mem.Allocator, value: Self) ![]u8 {
    try value.validate(allocator);
    const bytes = try p.Json.valueAlloc(allocator, value);
    errdefer allocator.free(bytes);
    if (bytes.len > max_saved_bytes) return error.InvalidNamedQuery;
    return bytes;
}
pub fn load(allocator: std.mem.Allocator, bytes: []const u8) !std.json.Parsed(Self) {
    if (bytes.len == 0 or bytes.len > max_saved_bytes) return error.InvalidNamedQuery;
    var parsed = try p.Json.parseFromSliceOwned(Self, allocator, bytes);
    errdefer parsed.deinit();
    try parsed.value.validate(allocator);
    return parsed;
}

fn clientFor(clients: []const c.DirectTableClient, binding: c.DirectDependency.Binding) !c.DirectTableClient {
    var result: ?c.DirectTableClient = null;
    for (clients) |client| if (std.meta.eql(client.connection, binding.connection)) {
        if (result != null) return error.CatalogIdentityConflict;
        result = client;
    };
    return result orelse error.CatalogIdentityConflict;
}

/// At most one exchange per distinct source. Save this entire plan before the
/// first call. A withheld reply propagates; repeating uses the same identities.
pub fn register(self: Self, allocator: std.mem.Allocator, clients: []const c.DirectTableClient) !void {
    try self.validate(allocator);
    for (self.bindings) |slot| if (slot) |binding| {
        const client = try clientFor(clients, binding);
        const response = try client.call(.{ .dependency_operation = .{ .binding = binding, .command = .accept } });
        defer response.deinit();
        if (response.value.result.dependency_operation != .outcome or response.value.result.dependency_operation.outcome.phase != .applied) return error.NamedQueryDependencyRejected;
    };
}

/// Read-only confirmation of current membership, not merely old successful
/// receipts. The returned control still needs its original native dispatch and
/// acceptance recovery. Independent catalog and native owners are not atomic.
pub fn publication(self: Self, allocator: std.mem.Allocator, clients: []const c.DirectTableClient) !r.Control {
    try self.validate(allocator);
    for (self.bindings) |slot| if (slot) |binding| {
        const client = try clientFor(clients, binding);
        const response = try client.call(.{ .dependency_state = binding.edge });
        defer response.deinit();
        if (!response.value.result.dependency_state.present) return error.NamedQueryDependencyMissing;
    };
    return .{ .publish = self.proposal };
}

/// Pure cleanup preparation. Save the returned bindings, establish definition
/// retirement or abandoned publication, then explicitly accept their removal.
pub fn removals(self: Self, allocator: std.mem.Allocator, operations: []const u64) ![max_sources]?c.DirectDependency.Binding {
    try self.validate(allocator);
    var result = self.bindings;
    var count: usize = 0;
    for (&result) |*slot| if (slot.*) |*binding| {
        if (count >= operations.len) return error.InvalidNamedQuery;
        binding.operation = operations[count];
        binding.action = .remove;
        try binding.validate();
        for (self.bindings) |original| if (original) |known| if (std.meta.eql(binding.identity(), known.identity())) return error.DataIdentityConflict;
        for (result[0..count]) |earlier| if (std.meta.eql(binding.identity(), earlier.?.identity())) return error.DataIdentityConflict;
        count += 1;
    };
    if (count != operations.len) return error.InvalidNamedQuery;
    return result;
}
