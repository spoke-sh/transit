//! Durable CONNECTION/SOURCE commands over the shared Catalog owner. Recovery
//! reads the original typed request; it never reparses SQL or dispatches HTTP.
const std = @import("std");
const g = @import("root.zig");
const c = g.catalog;
const p = c.protocol;
const S = c.DirectSource;
const api = g.session_protocol;
const ops = g.SessionOperations;
pub const Prepared = g.database.SourceSql.Prepared;
pub const Saved = c.DirectSourceClient.Saved;
pub fn requireProfile(host: *g.Session) !void {
    if (!host.native_profile) return error.UnsupportedSourceStatement;
    try requireOwner(host);
}
fn requireOwner(host: *g.Session) !void {
    if (host.source != null or host.transaction.handle != null) return error.UnsupportedSourceStatement;
    if (host.wire.local == null or host.wire.local.?.changes == null) return error.SourceRequiresCohostedService;
}
pub fn lookup(host: *g.Session, arena: *std.heap.ArenaAllocator, kind: c.SourceDeclaration.Kind, name: c.TableAuthority.Name) !S.Metadata {
    return (try c.DirectSourceClient.apply(arena, host.table, .{ .lookup = .{ .selection = .{ .namespace = host.namespace, .kind = kind }, .name = name } })).metadata orelse error.CatalogNameNotFound;
}
pub fn proposal(host: *g.Session, arena: *std.heap.ArenaAllocator, statement: g.database.SourceSql.Statement) !S.Proposal {
    const response = try host.table.call(.describe);
    defer response.deinit();
    const owner = response.value.subject.role;
    return switch (statement) {
        .connection => |value| .{ .namespace = host.namespace, .name = value.name, .owner = owner, .payload = .{ .connection = .{ .endpoint = value.endpoint } } },
        .create, .explain => |value| blk: {
            const executor = (try host.account.database(host.database)).source_executor orelse return error.SourceExecutorNotConfigured;
            const upstream = try lookup(host, arena, .connection, value.connection);
            const destination = (try c.DirectLogClient.apply(arena, host.table, .{ .lookup = .{ .namespace = host.namespace, .name = value.destination.slice() } })).lookup orelse return error.CatalogNameNotFound;
            break :blk .{ .namespace = host.namespace, .name = value.name, .owner = owner, .payload = .{ .source = .{
                .connection = upstream.state.declaration.interpretation,
                .destination = destination.declaration.stored.declaration.interpretation,
                .executor = executor,
                .http = value.http,
                .columns = try c.SourceBinding.columns(destination.schema, destination.declaration.stored.declaration.configuration),
            } } };
        },
        else => error.UnsupportedSourceStatement,
    };
}
pub fn validate(host: *g.Session, prepared: *const Prepared) !void {
    try requireProfile(host);
    if (prepared.statement == .control and prepared.statement.control.command != .retire) return error.SourceExecutionUnsupported;
    var arena: std.heap.ArenaAllocator = .init(host.allocator);
    defer arena.deinit();
    switch (prepared.statement) {
        .connection, .create => {
            const value = try proposal(host, &arena, prepared.statement);
            const preview = (try c.DirectSourceClient.apply(&arena, host.table, .{ .prepare = value })).preview;
            if (preview.reason != .none) return error.SourceDeclarationConflict;
        },
        .control => |value| _ = try lookup(host, &arena, .source, value.name),
        .drop => |value| _ = try lookup(host, &arena, value.kind, value.name),
        else => return error.UnsupportedSourceStatement,
    }
}
fn prepareRequest(host: *g.Session, arena: *std.heap.ArenaAllocator, prepared: *const Prepared, original: [16]u8) !Saved {
    const object = (std.mem.readInt(u64, original[0..8], .big) % p.max_counter) + 1;
    const operation = (std.mem.readInt(u64, original[8..16], .big) % p.max_counter) + 1;
    var expected: ?p.DataLifecycle.Definition = null;
    const intent: S.Intent = switch (prepared.statement) {
        .connection, .create => blk: {
            const value = try proposal(host, arena, prepared.statement);
            break :blk .{ .kind = std.meta.activeTag(value.payload), .namespace = host.namespace, .name = value.name, .action = .{ .create = .{ .owner = value.owner, .payload = value.payload } } };
        },
        .control => |value| blk: {
            const current = try lookup(host, arena, .source, value.name);
            expected = current.state.declaration.interpretation;
            break :blk .{ .kind = .source, .namespace = host.namespace, .name = value.name, .action = .{ .control = .{ .expected_epoch = current.state.control.?.epoch, .command = value.command } } };
        },
        .drop => |value| blk: {
            const current = try lookup(host, arena, value.kind, value.name);
            expected = current.state.declaration.interpretation;
            break :blk .{ .kind = value.kind, .namespace = host.namespace, .name = value.name, .action = .{ .drop = .{ .expected_epoch = if (current.state.control) |control| control.epoch else null } } };
        },
        else => return error.UnsupportedSourceStatement,
    };
    const saved: Saved = .{ .definition = p.Growth.current_definition, .connection = host.table.connection, .request = .{ .binding = .{
        .definition = p.Growth.current_definition,
        .identity = .{ .scope = host.table.connection.scope, .principal = host.table.connection.principal, .operation = operation },
        .target = if (expected) |definition| definition.object else .{ .scope = host.table.connection.scope, .branch = 1, .object = object },
        .action = switch (intent.action) {
            .create => .create,
            .control => .alter,
            .drop => .drop,
        },
        .expected_definition = expected,
        .expected_data = null,
        .intent = try intent.digest(arena.allocator()),
    }, .intent = intent } };
    try saved.validate(arena.allocator());
    return saved;
}
fn read(host: *g.Session, id: u64) !std.json.Parsed(Saved) {
    var reader = try host.observer.source();
    const item = try ops.external(host.runtime.execution, &reader, id);
    if (item.kind != .connector or !std.meta.eql(item.binding(), try host.account.database(host.database))) return error.SqlOperationBindingChanged;
    const bytes = try ops.readInline(&reader, try reader.operation(id), host.allocator);
    defer host.allocator.free(bytes);
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    if (!std.mem.eql(u8, &digest, &item.source)) return error.InvalidSourceDeclaration;
    const saved = try p.Json.parseFromSlice(Saved, host.allocator, bytes);
    errdefer saved.deinit();
    try saved.value.requireCaller(host.table);
    return saved;
}
pub fn admit(host: *g.Session, prepared: *const Prepared, token: api.Token, fingerprint: [32]u8) !api.Operation {
    try host.runtime.settings_mutex.lock(host.io);
    defer host.runtime.settings_mutex.unlock(host.io);
    if (try host.fresh(g.ConfigurationOperations.find, .{ host, token, @as(?[32]u8, fingerprint) })) |reference| return status(host, reference.id);
    try validate(host, prepared);
    var original: [16]u8 = undefined;
    try host.io.randomSecure(&original);
    var arena: std.heap.ArenaAllocator = .init(host.allocator);
    defer arena.deinit();
    const saved = try prepareRequest(host, &arena, prepared, original);
    const bytes = try p.Json.valueAllocBounded(arena.allocator(), saved, c.SourceDeclaration.max_bytes);
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    var reader = try host.observer.source();
    defer host.runtime.notifyExternal();
    const reference = try ops.beginOwned(&reader, .{ .nonce = token, .fingerprint = fingerprint, .kind = .connector, .binding = try host.account.database(host.database), .original = original, .source = digest, .expected_generation = 1, .reservation = @intCast(2 * bytes.len + 8192) }, bytes);
    return status(host, reference.id);
}
fn command(intent: S.Intent) g.results.Command {
    return switch (intent.action) {
        .create => if (intent.kind == .source) .create_source else .create_connection,
        .control => .retire_source,
        .drop => if (intent.kind == .source) .drop_source else .drop_connection,
    };
}
pub fn status(host: *g.Session, id: u64) !api.Operation {
    const saved = try read(host, id);
    defer saved.deinit();
    var reader = try host.observer.source();
    const item = try ops.external(host.runtime.execution, &reader, id);
    return .{ .command = command(saved.value.request.intent), .identity = .{ .account = host.account.execution.account, .id = id, .kind = .connector }, .token = item.nonce, .phase = if (item.phase == .terminal) .terminal else .ready, .outcome = switch (item.summary) {
        .none => null,
        .applied => .applied,
        .rejected => .rejected,
        .cancelled => .cancelled,
        .partial => return error.InvalidSourceDeclaration,
    }, .owner_operation = item.original };
}
pub fn resumeOperation(host: *g.Session, id: u64) !api.Operation {
    return advance(host, id, false);
}
pub fn cancel(host: *g.Session, id: u64) !api.Operation {
    return advance(host, id, true);
}
fn advance(host: *g.Session, id: u64, cancelling: bool) !api.Operation {
    try requireOwner(host);
    try host.runtime.settings_mutex.lock(host.io);
    defer host.runtime.settings_mutex.unlock(host.io);
    var reader = try host.observer.source();
    if ((try ops.external(host.runtime.execution, &reader, id)).phase == .terminal) return status(host, id);
    const saved = try read(host, id);
    defer saved.deinit();
    try ops.retain(&reader, id);
    var arena: std.heap.ArenaAllocator = .init(host.allocator);
    defer arena.deinit();
    const request = saved.value.request;
    var result = (try c.DirectSourceClient.apply(&arena, host.table, .{ .declaration = .{ .request = request, .command = if (cancelling) .cancel else .reserve } })).observation.operation;
    if (result.pending() and !cancelling) result = (try c.DirectSourceClient.apply(&arena, host.table, .{ .declaration = .{ .request = request, .command = .execute } })).observation.operation;
    if (!result.pending()) try ops.complete(&reader, id, switch (result.phase) {
        .applied => .applied,
        .rejected => .rejected,
        .cancelled => .cancelled,
        .reserved => unreachable,
    });
    host.runtime.notify();
    return status(host, id);
}
test {
    std.testing.refAllDecls(@This());
}
