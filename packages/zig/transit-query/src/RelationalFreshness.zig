//! Read-only comparisons with each result's actual direct Table cut. Independent
//! source observations are not one atomic catalog snapshot or output verification.
const std = @import("std");
const q = @import("root.zig");
const p = q.protocol;
const c = q.catalog;
const d = p.DataLifecycle;
const Self = @This();
pub const State = enum { fresh, stale, definition_changed };
pub const Current = struct { accepted: d.Position, changed_lsn: u64, policy_revision: u64 };
pub const Entry = struct { interpretation: d.Definition, captured: d.Position, state: State, current: ?Current };
count: u8,
entries: [q.fuze.Relational.max_sources]Entry = undefined,
pub fn fresh(self: Self) bool {
    for (self.entries[0..self.count]) |entry| if (entry.state != .fresh) return false;
    return true;
}

fn compare(cut: d.Position, current: d.Position, changed_lsn: u64) !State {
    try cut.validate();
    try current.validate();
    if (cut.next_lsn == 0 or cut.partition != current.partition or current.next_lsn < cut.next_lsn or changed_lsn > current.next_lsn) return error.SourceChanged;
    return if (changed_lsn <= cut.next_lsn) .fresh else .stale;
}
fn observe(bundle: q.RelationalBundle, cuts: []const d.Position, clients: []const c.DirectTableClient, subject: p.Authorization.Subject) !Self {
    try bundle.validate();
    if (subject != .signed or cuts.len != bundle.sources.len or clients.len != cuts.len) return error.InvalidRelationalSources;
    var result: Self = .{ .count = @intCast(cuts.len) };
    for (bundle.sources, cuts, clients, 0..) |source, cut, client, i| {
        try source.requireConnection(client);
        if (client.delegation != null or client.closure != null or client.borrow != null or
            client.connection.principal != subject.signed.claim.principal or client.connection.role != subject.signed.claim.role) return error.QueryDenied;
        const original = try bundle.sourceOrdinal(i);
        if (original != i) {
            if (!std.meta.eql(cut, cuts[original])) return error.InconsistentRelationalCut;
            result.entries[i] = result.entries[original];
            continue;
        }
        const definition = source.interpretation.interpretation;
        const response = client.call(.{ .observe = .{ .namespace = source.namespace, .interpretation = definition, .rows = null } }) catch |err| {
            if (err != error.Conflict or client.service.last_rejection != .TableDefinitionChanged) return err;
            // The service checks current source rights before this rejection.
            // A denied/unavailable read propagates without returning metadata.
            result.entries[i] = .{ .interpretation = definition, .captured = cut, .state = .definition_changed, .current = null };
            continue;
        };
        defer response.deinit();
        const current = response.value.result.observation.definition;
        result.entries[i] = .{ .interpretation = definition, .captured = cut, .state = try compare(cut, current.position, current.changed_lsn), .current = .{ .accepted = current.position, .changed_lsn = current.changed_lsn, .policy_revision = response.value.policy_revision } };
    }
    return result;
}
/// These vector methods compare source progress only. Result reader methods
/// additionally bind the vector to its manifest and recheck disclosure rights.
pub fn captured(bundle: q.RelationalBundle, vector: q.RelationalCaptured.Vector, clients: []const c.DirectTableClient, subject: p.Authorization.Subject) !Self {
    try vector.validate(bundle);
    var cuts: [q.fuze.Relational.max_sources]d.Position = undefined;
    for (vector.entries[0..vector.count], cuts[0..vector.count]) |entry, *cut| cut.* = .{ .partition = entry.partition, .next_lsn = entry.position };
    return observe(bundle, cuts[0..vector.count], clients, subject);
}
pub fn maintained(bundle: q.RelationalBundle, vector: q.RelationalHistory.Vector, clients: []const c.DirectTableClient, subject: p.Authorization.Subject) !Self {
    try vector.validate(bundle);
    var cuts: [q.fuze.Relational.max_sources]d.Position = undefined;
    for (vector.entries[0..vector.count], cuts[0..vector.count]) |entry, *cut| cut.* = entry.record.basis.accepted;
    return observe(bundle, cuts[0..vector.count], clients, subject);
}

test "freshness ignores physical bookkeeping but detects logical changes and inconsistent cuts" {
    const t = std.testing;
    const cut: d.Position = .{ .partition = 7, .next_lsn = 30 };
    try t.expectEqual(State.fresh, try compare(cut, .{ .partition = 7, .next_lsn = 49 }, 30));
    try t.expectEqual(State.stale, try compare(cut, .{ .partition = 7, .next_lsn = 49 }, 31));
    try t.expectError(error.SourceChanged, compare(cut, .{ .partition = 8, .next_lsn = 49 }, 31));
    try t.expectError(error.SourceChanged, compare(cut, .{ .partition = 7, .next_lsn = 29 }, 29));
    try t.expectError(error.SourceChanged, compare(cut, .{ .partition = 7, .next_lsn = 49 }, 50));
}
