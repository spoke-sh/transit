//! Growing inspection and separately credentialed public query operations.
const std = @import("std");
const client = @import("transit_client");
const q = @import("transit_query");
const api = @import("transit_board_api");
const p = client.protocol;
const g = p.Growth;
pub const QueryConfig = struct { seed_file: []const u8, connection: q.Model.Connection };
pub const Cursor = struct { position: ?u64 = null, process_after: ?u64 = null, resource_after: ?u64 = null };
pub fn identity(wire: *client.Client, realm: u64, principal: u64, key: p.Ed25519.KeyPair) !g.Response {
    const response = try wire.queryGrowing(.{ .realm = realm, .principal = principal, .kind = .{ .identity = {} } }, key);
    // First growing Board profile supports a realm inspector plus filtered
    // resource grants. Legacy PID-scoped inspection remains on the v2 routes.
    if (response.body.identity.permissions != p.permission(.inspect) or response.body.identity.pid != null) return error.UnsafePrincipal;
    return response;
}
pub fn atlas(wire: *client.Client, realm: u64, principal: u64, key: p.Ed25519.KeyPair, cursor: Cursor, query_resource: ?u64) !api.AtlasResponse {
    const reader = try identity(wire, realm, principal, key);
    if (cursor.position) |position| if (position != reader.position) return error.QueryChanged;
    const processes = try wire.queryGrowing(.{ .realm = realm, .principal = principal, .kind = .{ .processes = .{ .after = cursor.process_after, .position = reader.position } } }, key);
    const resources = try wire.queryGrowing(.{ .realm = realm, .principal = principal, .kind = .{ .resources = .{ .after = cursor.resource_after, .position = reader.position } } }, key);
    if (processes.position != reader.position or resources.position != reader.position) return error.QueryChanged;
    // Configuration never discloses a resource hidden by the inspection grant.
    const visible = for (resources.body.resources.entries) |slot| {
        if (slot) |resource| if (resource.id == query_resource) break query_resource;
    } else null;
    return .{ .realm = realm, .position = reader.position, .identity = reader.body.identity, .processes = processes.body.processes, .resources = resources.body.resources, .query_resource = visible };
}
pub fn query(wire: *client.Client, io: std.Io, config: QueryConfig, request: api.QueryRequest, allocator: std.mem.Allocator) !api.QueryResponse {
    var key = try client.readKey(allocator, io, config.seed_file);
    defer std.crypto.secureZero(u8, std.mem.asBytes(&key));
    var caller: q.Client = .{ .wire = wire, .connection = config.connection, .key = key };
    defer std.crypto.secureZero(u8, std.mem.asBytes(&caller.key));
    return switch (request) {
        .describe => .{ .source = try caller.describe() },
        .prepare => |value| blk: {
            const prepared = try caller.prepare(value.sql);
            const bound = try prepared.plan.bind(.{ .resource = prepared.source.connection.resource, .revision = prepared.source.resource_revision, .schema = try prepared.source.schema.fingerprint() }, prepared.source.schema);
            break :blk .{ .prepared = .{ .source = prepared.source, .explanation = bound.explain(), .frozen = .{ .token = try std.json.Stringify.valueAlloc(allocator, prepared, .{}) } } };
        },
        .submit => |value| blk: {
            const prepared = std.json.parseFromSlice(q.Model.Prepared, allocator, value.token, .{}) catch return error.InvalidQueryRequest;
            defer prepared.deinit();
            break :blk .{ .receipt = try caller.submit(prepared.value) };
        },
        .status => |value| .{ .status = try caller.status(value.correlation) },
        .page => |value| .{ .page = try caller.page(value.correlation, value.ordinal, allocator) },
        .prepare_cancel => |value| .{ .cancellation = .{ .token = try std.json.Stringify.valueAlloc(allocator, try caller.prepareCancel(value.correlation), .{}) } },
        .cancel => |value| blk: {
            const prepared = std.json.parseFromSlice(g.SignedRequest, allocator, value.token, .{}) catch return error.InvalidQueryRequest;
            defer prepared.deinit();
            break :blk .{ .receipt = try caller.submitCancel(prepared.value) };
        },
    };
}
