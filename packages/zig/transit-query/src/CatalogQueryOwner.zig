//! Compose general Table lifecycle and durable queries at the catalog owner.
//! Catalog initialization and requester delegation are separate public actions.
const std = @import("std");
const q = @import("root.zig");
const c = q.catalog;
const s = q.station;
const p = q.protocol;
const r = q.UnifiedRecords;
const Self = @This();
tables: c.TableBehavior,
resources: s.client.ResourceReader,
adapter: []u8,
workspace: []u8,
cancellation: *const q.fuze.execution.Cancellation,

pub const PolicyChange = q.UnifiedBehavior.PolicyChange;
pub fn check(configuration: c.TableCatalogRecords.Configuration, turn: *s.Turn) !void {
    try configuration.validate();
    if (turn.delivery.realm != configuration.scope.realm or turn.delivery.pid != configuration.owner or turn.view.resource != configuration.scope.resource) return error.CatalogOwnerChanged;
    const record = (try turn.read(c.Records.key(configuration.scope.catalog, 'c', 0, 0))) orelse return error.CatalogNotInitialized;
    if (!std.meta.eql(try c.Records.decode(c.TableCatalogRecords.Configuration, 'C', record), configuration)) return error.CatalogConfigurationChanged;
}
pub fn interface(self: *Self) s.GenServer.Handler {
    return .{ .context = self, .initialize = initialize, .handle = handle };
}
pub fn guard(self: *Self) s.GenServer.InputGuard {
    return .{ .context = self, .reject = rejectInput };
}
fn initialize(raw: ?*anyopaque, turn: *s.Turn) !void {
    const self: *Self = @ptrCast(@alignCast(raw.?));
    const table = self.tables.interface();
    try table.initialize.?(table.context, turn);
}
fn queryFrame(frame: s.Frame) bool {
    return frame.kind == .call or frame.kind == .cancel or (frame.kind == .cast and std.mem.startsWith(u8, frame.payload.slice(), "UQN1"));
}
fn policyFrame(frame: s.Frame) bool {
    return frame.kind == .cast and std.mem.startsWith(u8, frame.payload.slice(), "CQG1");
}
fn rejectInput(raw: ?*anyopaque, turn: *s.Turn) !bool {
    const self: *Self = @ptrCast(@alignCast(raw.?));
    const frame = s.Frame.decode(turn.delivery.input.value) catch {
        const table = self.tables.guard();
        return table.reject(table.context, turn);
    };
    if (queryFrame(frame) or policyFrame(frame)) {
        try check(self.tables.configuration, turn);
        return false;
    }
    const table = self.tables.guard();
    return table.reject(table.context, turn);
}
fn disposition(self: *Self, turn: *s.Turn, outcome: @FieldType(c.TableControl.Disposition, "outcome")) !void {
    const evidence: c.TableControl.Disposition = .{
        .scope = self.tables.configuration.scope,
        .origin = switch (turn.delivery.input.origin) {
            .external => .external,
            .process => .process,
            .effect => .effect,
        },
        .principal = if (turn.delivery.input.origin == .external) turn.delivery.input.origin.external.principal else 0,
        .input = turn.delivery.input.position,
        .payload = try c.Model.fingerprint(turn.delivery.input.value),
        .outcome = outcome,
    };
    const key = c.Records.key(evidence.scope.catalog, 'e', evidence.input, 0);
    const encoded = try c.Records.encode('E', evidence);
    if (try turn.read(key)) |existing| {
        _ = try c.Records.decode(c.TableControl.Disposition, 'E', existing);
        if (!existing.eql(encoded)) return error.InvalidCatalogDisposition;
    } else try turn.write(key, encoded);
}
/// Conditional delegation, authenticated by the enclosing native input. Exact
/// repeats are idempotent; changing another requester's map needs its revision.
pub fn changePolicy(self: *Self, turn: *s.Turn, payload: p.Value) !void {
    try check(self.tables.configuration, turn);
    const before = turn.decision;
    errdefer turn.decision = before;
    if (turn.delivery.input.origin != .external or turn.delivery.input.origin.external.principal != self.tables.configuration.administrator) return self.disposition(turn, .denied);
    const change = PolicyChange.decode(payload) catch |err| switch (err) {
        error.IncompatibleDefinition => return err,
        else => return self.disposition(turn, .invalid_command),
    };
    const target = change.policy.target.catalog;
    if (!std.meta.eql(target.scope, self.tables.configuration.scope) or target.owner != self.tables.configuration.owner) return self.disposition(turn, .identity_conflict);
    if (try q.UnifiedCapture.policy(turn, change.policy.peer)) |current| {
        if (std.meta.eql(current, change.policy)) return self.disposition(turn, .policy_applied);
        if (current.revision != change.expected_revision) return self.disposition(turn, .stale_policy);
    } else if (change.expected_revision != 0) return self.disposition(turn, .stale_policy);
    try q.UnifiedCapture.setPolicy(turn, change.policy);
    try self.disposition(turn, .policy_applied);
}
fn handle(raw: ?*anyopaque, turn: *s.Turn, frame: s.Frame) !void {
    const self: *Self = @ptrCast(@alignCast(raw.?));
    if (policyFrame(frame)) return self.changePolicy(turn, frame.payload);
    if (queryFrame(frame)) {
        return q.UnifiedBehavior.dispatchCatalogSource(turn, frame, self.tables.configuration, self.resources, self.adapter, self.workspace, self.cancellation) catch |err| {
            if (turn.read_error == null and (err == error.Rejected or err == error.Conflict) and (self.resources.wire.last_rejection == .StateResourceExpired or self.resources.wire.last_rejection == .UnknownStateResource)) {
                const cause = if (self.resources.wire.last_rejection == .StateResourceExpired) error.RequestResourceExpired else error.RequestResourceMissing;
                if (frame.kind == .call) return turn.reply(try q.QueryFailure.fromError(cause, .admission).?.encode());
                if (frame.kind == .cast and (s.Frame.source(turn.delivery.input) catch 0) == turn.delivery.pid) return q.UnifiedCapture.closeFailure(turn, (try r.Continuation.decode(frame.payload)).job, q.QueryFailure.fromError(cause, .execution).?);
            }
            return err;
        };
    }
    const table = self.tables.interface();
    return table.handle(table.context, turn, frame);
}
