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
    const item = try ops.external(host.runtime.ledger, &reader, id);
    if (item.kind != .configuration or !std.meta.eql(item.binding(), try host.account.database(host.database)) or !std.mem.eql(u8, &item.source, &try source(host))) return error.SqlOperationBindingChanged;
    return item;
}
pub fn find(host: *g.Session, token: api.Token, fingerprint: ?[32]u8) !?ops.Reference {
    var reader = try host.observer.source();
    return ops.lookup(host.runtime.ledger, &reader, token, fingerprint);
}
pub fn admit(host: *g.Session, token: api.Token, fingerprint: [32]u8) !api.Operation {
    try host.runtime.settings_mutex.lock(host.io);
    defer host.runtime.settings_mutex.unlock(host.io);
    if (try host.fresh(find, .{ host, token, @as(?[32]u8, fingerprint) })) |ref| return status(host, ref.id);
    const selected = try Settings.client(host);
    const current = try selected.read(.{ .settings = .{ .name = "version" } });
    defer current.deinit();
    var original: [16]u8 = undefined;
    try host.io.randomSecure(&original);
    try host.runtime.control(.{ .external_begin = .{ .nonce = token, .fingerprint = fingerprint, .kind = .configuration, .binding = try host.account.database(host.database), .original = original, .source = try source(host), .expected_generation = current.value.result.settings.generation, .reservation = 8192 } }, host.deadline);
    const ref = (try host.fresh(find, .{ host, token, @as(?[32]u8, fingerprint) })) orelse return error.MissingGatewayOperation;
    const item = try host.fresh(load, .{ host, ref.id });
    try publish(host, item);
    return status(host, item.id);
}
fn request(host: *g.Session, item: ops.External) !q.SettingsJournal.Record {
    const selected = try Settings.client(host);
    return .{ .definition = q.protocol.Growth.current_definition, .request = .{ .definition = q.protocol.Growth.current_definition, .binding = selected.binding, .operation = item.original, .action = .{ .reload = .{ .expected_generation = item.expected_generation } } }, .principal = selected.principal, .role = selected.role, .complete = false };
}
fn path(host: *g.Session, id: u64) ![]u8 {
    return std.fmt.allocPrint(host.allocator, "{s}/configuration-{s}-{d}.json", .{ host.config.activation_directory, std.fmt.bytesToHex(host.account.ledger.account, .lower), id });
}
fn identity(host: *g.Session, saved: q.SettingsJournal.Record) ![]u8 {
    return q.protocol.Json.valueAlloc(host.allocator, .{ saved.request, saved.principal, saved.role });
}
fn publish(host: *g.Session, item: ops.External) !void {
    const selected = try Settings.client(host);
    const expected = try request(host, item);
    const file = try path(host, item.id);
    defer host.allocator.free(file);
    if (try q.SettingsJournal.read(host.allocator, host.io, file, selected)) |saved| {
        if (!std.meta.eql(saved.request, expected.request) or saved.principal != expected.principal or saved.role != expected.role) return error.InvalidConfigurationRecovery;
    } else try q.SettingsJournal.write(host.allocator, host.io, file, expected);
    const bytes = try identity(host, expected);
    defer host.allocator.free(bytes);
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    if (item.phase == .reserved) {
        try host.runtime.control(.{ .external_ready = .{ .operation = item.id, .generation = host.account.generation, .length = @intCast(bytes.len), .digest = digest } }, host.deadline);
    } else if (item.length != bytes.len or !std.mem.eql(u8, &item.digest, &digest)) return error.InvalidConfigurationRecovery;
}
pub fn status(host: *g.Session, id: u64) !api.Operation {
    const item = try host.fresh(load, .{ host, id });
    const selected = try Settings.client(host);
    const result = try selected.read(.{ .reloads = .{ .operation = item.original } });
    defer result.deinit();
    if (result.value.result != .reloads or result.value.result.reloads.rows.len > 1) return error.InvalidConfigurationResponse;
    const outcome: ?C.Outcome = if (result.value.result.reloads.rows.len == 0) null else result.value.result.reloads.rows[0];
    if (item.phase == .terminal and outcome == null) return error.MissingConfigurationOutcome;
    const complete = outcome != null and outcome.?.phase != .applying;
    return .{ .identity = .{ .account = host.account.ledger.account, .id = item.id, .kind = .configuration }, .token = item.nonce, .phase = if (complete) .terminal else if (item.phase == .reserved) .reserved else .ready, .outcome = if (complete) switch (outcome.?.phase) {
        .rejected => .rejected,
        .partial => .partial,
        else => .applied,
    } else null, .owner_operation = item.original, .configuration_phase = if (outcome) |value| @fromBackingInt(@intCast(@backingInt(value.phase))) else null };
}
/// The caller serializes the account's administrative lane. The immutable
/// ledger reference can reconstruct a missing local journal, never new SQL.
pub fn resumeOperation(host: *g.Session, id: u64) !api.Operation {
    try host.runtime.settings_mutex.lock(host.io);
    defer host.runtime.settings_mutex.unlock(host.io);
    const item = try host.fresh(load, .{ host, id });
    if (item.phase == .terminal) return status(host, id);
    try publish(host, item);
    const selected = try Settings.client(host);
    const saved = try request(host, item);
    const response = try selected.submit(try selected.prepare(saved.request.action, saved.request.operation));
    defer response.deinit();
    if (response.value.result != .reload) return error.InvalidConfigurationResponse;
    if (response.value.result.reload.phase != .applying) {
        const file = try path(host, id);
        defer host.allocator.free(file);
        var completed = saved;
        completed.complete = true;
        try q.SettingsJournal.write(host.allocator, host.io, file, completed);
        try host.runtime.control(.{ .external_complete = .{ .operation = id, .generation = host.account.generation, .summary = switch (response.value.result.reload.phase) {
            .rejected => .rejected,
            .partial => .partial,
            else => .applied,
        } } }, host.deadline);
    }
    return status(host, id);
}
