//! Growing inspection and separately credentialed public query operations.
const std = @import("std");
const client = @import("transit_client");
const q = @import("transit_query");
const api = @import("transit_board_api");
const p = client.protocol;
const g = p.Growth;
pub const QueryConfig = struct { seed_file: []const u8, connection: q.Model.Connection };
pub const UnifiedQueryConfig = struct { seed_file: []const u8, connection: q.UnifiedClient.Connection, workspace: q.Workspace.Config };
pub fn unifiedQuery(wire: *client.Client, io: std.Io, config: UnifiedQueryConfig, request: api.UnifiedQueryRequest, allocator: std.mem.Allocator) !api.UnifiedQueryResponse {
    var key = try client.readKey(allocator, io, config.seed_file);
    defer std.crypto.secureZero(u8, std.mem.asBytes(&key));
    var caller: q.UnifiedClient = .{ .wire = wire, .connection = config.connection, .key = key };
    defer std.crypto.secureZero(u8, std.mem.asBytes(&caller.key));
    return q.Workspace.apply(allocator, &caller, config.workspace, request);
}
pub const Cursor = struct { position: ?u64 = null, process_after: ?u64 = null, resource_after: ?u64 = null };
pub const RecordsCursor = struct { resource: u64, revision: ?u64 = null, after: ?p.Value = null };
pub const ExchangeCursor = struct { resource: u64, exchange: u64 };
pub const DocumentCursor = struct { resource: u64, document: u64, revision: ?u64 = null, after: ?api.Document.adapter.station.ImmutableIndex.Key = null };
pub fn document(wire: *client.Client, realm: u64, principal: u64, key: p.Ed25519.KeyPair, cursor: DocumentCursor, allocator: std.mem.Allocator) !api.DocumentResponse {
    _ = try identity(wire, realm, principal, key);
    const d = api.Document.adapter;
    const reader: client.ResourceReader = .{ .wire = wire, .realm = realm, .principal = principal, .key = key };
    var source = try reader.open(cursor.resource);
    if (cursor.revision) |revision| if (revision != source.view.revision) return error.QueryChanged;
    const service: d.Service = .{ .resource = cursor.resource, .document = cursor.document };
    const address = service.key('h', 0);
    const observation = try reader.query(.{ .entries = .{ .resource = cursor.resource, .revision = source.view.revision, .key = address } });
    const entry = observation.body.entries.page.entries[0] orelse return error.DocumentNotFound;
    if (!entry.key.eql(address)) return error.InvalidResourceRead;
    const head = try service.head(&source);
    const page = if (head.retired) null else try service.readRegisterMetadata(&source, head.state.revision, cursor.after);
    return .{
        .source = .{ .realm = realm, .pid = observation.body.entries.resource.writer, .resource = cursor.resource, .key = address, .entry_revision = entry.revision, .resource_revision = source.view.revision, .position = observation.position },
        .declaration = try api.Document.project(allocator, head),
        .registers = if (page) |value| .{ .count = value.registers, .conflicts = value.conflicts, .assignments = value.assignments, .next = if (value.next) |next| try std.fmt.allocPrint(allocator, "{x}", .{next.slice()}) else null } else null,
    };
}
pub fn metadata(comptime Projection: type, wire: *client.Client, realm: u64, principal: u64, key: p.Ed25519.KeyPair, cursor: ExchangeCursor, allocator: std.mem.Allocator) !Projection.Response {
    _ = try identity(wire, realm, principal, key);
    const x = Projection.adapter.exchange;
    var reader: x.Client = .{ .wire = wire, .realm = realm, .principal = principal, .key = key };
    var source = try reader.reader(cursor.resource);
    const descriptor_key = x.Exchange.key(cursor.exchange, 'd', 0);
    const page = try reader.query(.{ .entries = .{ .resource = cursor.resource, .revision = source.view.revision, .key = descriptor_key } });
    const entry = page.body.entries.page.entries[0] orelse return error.ExchangeNotFound;
    const summary = try Projection.adapter.Inspection.read(allocator, .{ .resource = cursor.resource, .id = cursor.exchange }, &source);
    return Projection.project(allocator, .{ .realm = realm, .pid = page.body.entries.resource.writer, .resource = cursor.resource, .key = descriptor_key, .entry_revision = entry.revision, .resource_revision = source.view.revision, .position = page.position }, cursor.exchange, summary);
}
pub fn identity(wire: *client.Client, realm: u64, principal: u64, key: p.Ed25519.KeyPair) !g.Response {
    const response = try wire.queryGrowing(.{ .realm = realm, .principal = principal, .kind = .{ .identity = {} } }, key);
    // First growing Board profile supports a realm inspector plus filtered
    // resource grants. Legacy PID-scoped inspection remains on the v2 routes.
    if (response.body.identity.permissions != p.permission(.inspect) or response.body.identity.pid != null) return error.UnsafePrincipal;
    return response;
}
pub fn atlas(wire: *client.Client, realm: u64, principal: u64, key: p.Ed25519.KeyPair, cursor: Cursor, query_resource: ?u64) !api.AtlasResponse {
    // Restart only a fresh acquisition. A caller's continuation remains tied to
    // its original position and cannot silently switch to a newer atlas cut.
    for (0..3) |_| return atlasOnce(wire, realm, principal, key, cursor, query_resource) catch |err| {
        if (cursor.position == null and (err == error.QueryChanged or
            ((err == error.Conflict or err == error.Rejected) and wire.last_rejection == .QueryExpired))) continue;
        return err;
    };
    return error.QueryChanged;
}
fn atlasOnce(wire: *client.Client, realm: u64, principal: u64, key: p.Ed25519.KeyPair, cursor: Cursor, query_resource: ?u64) !api.AtlasResponse {
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
pub fn records(wire: *client.Client, realm: u64, principal: u64, key: p.Ed25519.KeyPair, cursor: RecordsCursor, allocator: std.mem.Allocator) !api.RecordsResponse {
    _ = try identity(wire, realm, principal, key);
    const revision = cursor.revision orelse (try wire.queryGrowing(.{ .realm = realm, .principal = principal, .kind = .{ .resource = cursor.resource } }, key)).body.resource.revision;
    const response = try wire.queryGrowing(.{ .realm = realm, .principal = principal, .kind = .{ .entries = .{ .resource = cursor.resource, .revision = revision, .after = cursor.after } } }, key);
    const entries = response.body.entries;
    if (entries.resource.id != cursor.resource) return error.QueryChanged;
    if (entries.resource.phase != .active) return error.QuerySourceUnavailable;
    return api.projectRecords(allocator, realm, response.position, entries.resource, entries.page);
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
