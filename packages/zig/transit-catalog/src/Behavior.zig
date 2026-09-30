//! Explicit catalog GenServer. Controls/rejections have input-bound dispositions;
//! successful creation retains its four-write operation receipt instead.
const std = @import("std");
const c = @import("root.zig");
const m = c.Model;
const r = c.Records;
const s = c.station;
const Self = @This();
configuration: m.Configuration,
pub fn interface(self: *Self) s.GenServer.Handler {
    return .{ .context = self, .initialize = initialize, .handle = handle };
}
pub fn guard(self: *Self) s.GenServer.InputGuard {
    return .{ .context = self, .reject = rejectInput };
}
fn catalog(self: *Self) c.Catalog {
    return .{ .configuration = self.configuration };
}
fn administrator(self: *Self, turn: *s.Turn) bool {
    return turn.delivery.input.origin == .external and turn.delivery.input.origin.external.principal == self.configuration.administrator;
}
fn check(self: *Self, turn: *s.Turn) !bool {
    try self.configuration.validate();
    if (turn.delivery.realm != self.configuration.scope.realm or turn.delivery.pid != self.configuration.owner or turn.view.resource != self.configuration.scope.resource) return error.CatalogOwnerChanged;
    const value = (try turn.read(r.key(self.configuration.scope.catalog, 'c', 0, 0))) orelse return false;
    if (!std.meta.eql(try r.decode(m.Configuration, 'c', value), self.configuration)) return error.CatalogConfigurationChanged;
    return true;
}
fn initializer(self: *Self, turn: *s.Turn, command: m.Command) bool {
    return command == .initialize and self.administrator(turn) and std.meta.eql(command.initialize, self.configuration);
}
fn disposition(self: *Self, turn: *s.Turn, outcome: @FieldType(m.Disposition, "outcome")) !bool {
    const value: m.Disposition = .{
        .scope = self.configuration.scope,
        .origin = switch (turn.delivery.input.origin) {
            .external => .external,
            .process => .process,
            .effect => .effect,
        },
        .principal = if (turn.delivery.input.origin == .external) turn.delivery.input.origin.external.principal else 0,
        .input = turn.delivery.input.position,
        .payload = try m.Disposition.fingerprint(turn.delivery.input.value),
        .outcome = outcome,
    };
    const key = r.key(value.scope.catalog, 'e', value.input, 0);
    const encoded = try r.encode('e', value);
    if (try turn.read(key)) |existing| {
        _ = try r.decode(m.Disposition, 'e', existing);
        if (!existing.eql(encoded)) return error.InvalidCatalogDisposition;
        return true;
    }
    try turn.write(key, encoded);
    return true;
}
fn initialize(raw: ?*anyopaque, turn: *s.Turn) !void {
    const self: *Self = @ptrCast(@alignCast(raw.?));
    const frame = try s.Frame.decode(turn.delivery.input.value);
    if (frame.kind != .cast or !self.initializer(turn, try m.Command.decode(frame.payload))) return error.UninitializedCatalog;
    // A supplied behavior must not silently take over a previously initialized
    // manual catalog whose framework descriptor is missing.
    if (try self.check(turn)) return error.CatalogAlreadyPopulated;
    const before = turn.decision;
    errdefer turn.decision = before;
    try self.catalog().initialize(turn);
    _ = try self.disposition(turn, .initialized);
}
fn rejectInput(raw: ?*anyopaque, turn: *s.Turn) !bool {
    const self: *Self = @ptrCast(@alignCast(raw.?));
    const initialized = try self.check(turn);
    const frame = s.Frame.decode(turn.delivery.input.value) catch return if (initialized) self.disposition(turn, .invalid_command) else error.UninitializedCatalog;
    if (frame.kind != .cast or turn.delivery.input.origin != .external) return if (initialized) self.disposition(turn, .invalid_command) else error.UninitializedCatalog;
    const command = m.Command.decode(frame.payload) catch return if (initialized) self.disposition(turn, .invalid_command) else error.UninitializedCatalog;
    if (!initialized) {
        if (!self.initializer(turn, command)) return error.UninitializedCatalog;
        return false;
    }
    if (!std.meta.eql(command.scope(), self.configuration.scope)) return self.disposition(turn, .identity_conflict);
    if (command != .create_table and !self.administrator(turn)) return self.disposition(turn, .denied);
    if (command == .initialize and !self.initializer(turn, command)) return self.disposition(turn, .identity_conflict);
    return false;
}
fn handle(raw: ?*anyopaque, turn: *s.Turn, frame: s.Frame) !void {
    const self: *Self = @ptrCast(@alignCast(raw.?));
    if (!try self.check(turn)) return error.UninitializedCatalog;
    if (frame.kind != .cast or turn.delivery.input.origin != .external) return error.CatalogDenied;
    const command = try m.Command.decode(frame.payload);
    const before = turn.decision;
    apply(self, turn, command) catch |err| {
        turn.decision = before;
        if (turn.read_error != null) return err;
        const reason: @FieldType(m.Disposition, "outcome") = switch (err) {
            error.CatalogDenied => .denied,
            error.CatalogScopeChanged, error.CatalogIdentityConflict => .identity_conflict,
            error.CatalogPolicyConflict => .stale_policy,
            else => return err,
        };
        _ = try self.disposition(turn, reason);
    };
}
fn apply(self: *Self, turn: *s.Turn, command: m.Command) !void {
    if (!std.meta.eql(command.scope(), self.configuration.scope)) return error.CatalogScopeChanged;
    switch (command) {
        .initialize => {
            if (!self.initializer(turn, command)) return error.CatalogDenied;
            const key = r.key(self.configuration.scope.catalog, 'e', turn.delivery.input.position, 0);
            // GenServer invokes initialize and handle in the same private turn.
            if (try turn.read(key) == null) try self.catalog().initialize(turn);
            _ = try self.disposition(turn, .initialized);
        },
        .create_table => |request| _ = try self.catalog().createTable(turn, request),
        .set_policy => |change| {
            try self.catalog().setPolicy(turn, change.expected_revision, change.policy);
            _ = try self.disposition(turn, .policy_applied);
        },
    }
}
