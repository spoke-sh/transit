//! Native-session references retain the configuration owner's original reload
//! identity and generation. Observation never dispatches or reparses SQL.
const std = @import("std");
const g = @import("root.zig");
const q = g.query;
const api = g.session_protocol;
const ops = g.SessionOperations;
const Settings = @import("SessionSettings.zig");
const C = q.settings.Contract;
pub fn source(host: *g.Session) ![32]u8 {
    const selected = try Settings.client(host);
    const bytes = try q.protocol.Json.valueAlloc(host.allocator, .{ selected.binding, selected.principal, selected.role });
    defer host.allocator.free(bytes);
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    return digest;
}
pub fn load(host: *g.Session, id: u64) !ops.External {
    var reader = try host.observer.source();
    const item = try ops.external(host.runtime.execution, &reader, id);
    if (item.kind != .configuration or !std.meta.eql(item.binding(), try host.account.database(host.database)) or !std.mem.eql(u8, &item.source, &try source(host))) return error.SqlOperationBindingChanged;
    return item;
}
pub fn find(host: *g.Session, token: api.Token, fingerprint: ?[32]u8) !?ops.Reference {
    var reader = try host.observer.source();
    return ops.lookup(host.runtime.execution, &reader, token, fingerprint);
}
pub fn admit(host: *g.Session, token: api.Token, fingerprint: [32]u8) !api.Operation {
    try host.runtime.settings_mutex.lock(host.io);
    defer host.runtime.settings_mutex.unlock(host.io);
    if (try host.fresh(find, .{ host, token, @as(?[32]u8, fingerprint) })) |ref| return status(host, ref.id);
    const selected = try Settings.client(host);
    const current = try host.fresh(q.SettingsClient.read, .{ selected, C.Action{ .settings = .{ .name = "version" } } });
    defer current.deinit();
    var original: [16]u8 = undefined;
    try host.io.randomSecure(&original);
    defer host.runtime.notifyExternal();
    var reader = try host.observer.source();
    _ = try ops.begin(&reader, .{ .nonce = token, .fingerprint = fingerprint, .kind = .configuration, .binding = try host.account.database(host.database), .original = original, .source = try source(host), .expected_generation = current.value.result.settings.generation, .reservation = 8192 }, null);
    const ref = (try host.fresh(find, .{ host, token, @as(?[32]u8, fingerprint) })) orelse return error.MissingGatewayOperation;
    const item = try host.fresh(load, .{ host, ref.id });
    return status(host, item.id);
}
fn request(host: *g.Session, item: ops.External) !q.SettingsJournal.Record {
    const selected = try Settings.client(host);
    return .{ .definition = q.protocol.Growth.current_definition, .request = .{ .definition = q.protocol.Growth.current_definition, .binding = selected.binding, .operation = item.original, .action = .{ .reload = .{ .expected_generation = item.expected_generation } } }, .principal = selected.principal, .role = selected.role, .complete = false };
}
pub fn status(host: *g.Session, id: u64) !api.Operation {
    const item = try host.fresh(load, .{ host, id });
    const selected = try Settings.client(host);
    const result = try host.fresh(q.SettingsClient.read, .{ selected, C.Action{ .reloads = .{ .operation = item.original } } });
    defer result.deinit();
    if (result.value.result != .reloads or result.value.result.reloads.rows.len > 1) return error.InvalidConfigurationResponse;
    const outcome: ?C.Outcome = if (result.value.result.reloads.rows.len == 0) null else result.value.result.reloads.rows[0];
    if (item.phase == .terminal and outcome == null) return error.MissingConfigurationOutcome;
    const complete = outcome != null and outcome.?.phase != .applying;
    return .{ .command = .reload, .identity = .{ .account = host.account.execution.account, .id = item.id, .kind = .configuration }, .token = item.nonce, .phase = if (complete) .terminal else .ready, .outcome = if (complete) switch (outcome.?.phase) {
        .rejected => .rejected,
        .partial => .partial,
        else => .applied,
    } else null, .owner_operation = item.original, .configuration_phase = if (outcome) |value| @fromBackingInt(@intCast(@backingInt(value.phase))) else null };
}
/// The caller serializes the account's administrative lane. The immutable
/// Catalog reference can reconstruct a missing local journal, never new SQL.
pub fn resumeOperation(host: *g.Session, id: u64) !api.Operation {
    defer if (!host.recovering) host.runtime.notifyExternal();
    try host.runtime.settings_mutex.lock(host.io);
    defer host.runtime.settings_mutex.unlock(host.io);
    const item = try host.fresh(load, .{ host, id });
    if (item.phase == .terminal) return status(host, id);
    const selected = try Settings.client(host);
    const saved = try request(host, item);
    const response = try selected.submit(try selected.prepare(saved.request.action, saved.request.operation));
    defer response.deinit();
    if (response.value.result != .reload) return error.InvalidConfigurationResponse;
    if (response.value.result.reload.phase != .applying) {
        var reader = try host.observer.source();
        try ops.complete(&reader, id, switch (response.value.result.reload.phase) {
            .rejected => .rejected,
            .partial => .partial,
            else => .applied,
        });
    }
    return status(host, id);
}
