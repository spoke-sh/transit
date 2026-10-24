//! Growing inspection and separately credentialed public query operations.
const std = @import("std");
const client = @import("transit_client");
const q = @import("transit_query");
const api = @import("transit_board_api");
const p = client.protocol;
const g = p.Growth;
pub const UnifiedQueryConfig = struct { seed_file: []const u8, connection: q.UnifiedClient.Connection, workspace: q.Workspace.Config };
pub fn unifiedQuery(wire: *client.Client, io: std.Io, config: UnifiedQueryConfig, request: api.UnifiedQueryRequest, allocator: std.mem.Allocator) !api.UnifiedQueryResponse {
    return unifiedQueryDiagnostic(wire, io, config, request, allocator, null);
}
pub fn unifiedQueryDiagnostic(wire: *client.Client, io: std.Io, config: UnifiedQueryConfig, request: api.UnifiedQueryRequest, allocator: std.mem.Allocator, diagnostic: ?*?p.Diagnostic) !api.UnifiedQueryResponse {
    var local: ?p.Diagnostic = null;
    const out = diagnostic orelse &local;
    out.* = null;
    wire.last_rejection = null;
    var key = client.readKey(allocator, io, config.seed_file) catch |err| {
        out.* = q.Workspace.diagnostic(request, err, .{}, false, null) catch null;
        return err;
    };
    defer std.crypto.secureZero(u8, std.mem.asBytes(&key));
    var caller: q.UnifiedClient = .{ .wire = wire, .connection = config.connection, .key = key };
    caller.tables = try q.Workspace.directTables(allocator, &caller, config.workspace);
    defer std.crypto.secureZero(u8, std.mem.asBytes(&caller));
    // Only the native capacity refusal is eligible here. Keep this list
    // exhaustive: a new operation must decide whether it may repeat. Preparing
    // a token does not dispatch it; an uncertain submit still needs exact,
    // explicit recovery by the caller.
    const read_only = switch (request) {
        .describe, .sql_capabilities, .suggest, .assist, .compile, .capture, .refresh, .inspect, .next, .next_draft, .draft_open, .draft_close, .draft_status, .observe, .status, .page, .prepare_control, .recover_preparation => true,
        .submit => false,
    };
    var attempt: u2 = 0;
    while (true) {
        return q.Workspace.applyStructured(allocator, &caller, config.workspace, request, out) catch |err| {
            // HTTP 503 maps to AuthorityUnavailable; only the separately validated
            // rejection identifies a capacity refusal rather than an unknown loss.
            if (!read_only or err != error.AuthorityUnavailable or wire.last_rejection != .HttpCapacity or attempt == 3) return err;
            // At most four bounded workspace attempts, all under the original
            // request cancellation/deadline. No candidate page is disclosed early.
            try io.sleep(.fromMilliseconds(@as(u32, 500) << attempt), .awake);
            attempt += 1;
            continue;
        };
    }
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
    const response = try wire.query(.{ .realm = realm, .principal = principal, .kind = .{ .identity = {} } }, key);
    if (response.body.identity.permissions != p.permission(.inspect)) return error.UnsafePrincipal;
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
    const processes = try wire.query(.{ .realm = realm, .principal = principal, .kind = .{ .processes = .{ .after = cursor.process_after, .position = reader.position } } }, key);
    const resources = try wire.query(.{ .realm = realm, .principal = principal, .kind = .{ .resources = .{ .after = cursor.resource_after, .position = reader.position } } }, key);
    if (processes.position != reader.position or resources.position != reader.position) return error.QueryChanged;
    // Configuration never discloses a resource hidden by the inspection grant.
    const visible = for (resources.body.resources.entries) |slot| {
        if (slot) |resource| if (resource.id == query_resource) break query_resource;
    } else null;
    return .{ .realm = realm, .position = reader.position, .identity = reader.body.identity, .processes = processes.body.processes, .resources = resources.body.resources, .query_resource = visible };
}
pub const ParticipationCursor = struct { resource: u64, after: ?u64 = null, pid: ?u64 = null, association_after: ?u64 = null, position: ?u64 = null };
pub fn participation(wire: *client.Client, realm: u64, principal: u64, key: p.Ed25519.KeyPair, cursor: ParticipationCursor) !api.ParticipationResponse {
    const reader = try identity(wire, realm, principal, key);
    if (cursor.position) |expected| if (reader.position != expected) return error.QueryChanged;
    _ = try wire.query(.{ .realm = realm, .principal = principal, .kind = .{ .resource = cursor.resource } }, key);
    var pids: [g.page_size]?u64 = @splat(null);
    var position: ?u64 = null;
    var next: ?u64 = null;
    if (cursor.pid) |pid| {
        pids[0] = pid;
    } else {
        const processes = try wire.query(.{ .realm = realm, .principal = principal, .kind = .{ .processes = .{ .after = cursor.after, .position = cursor.position } } }, key);
        position = processes.position;
        next = processes.body.processes.next;
        for (processes.body.processes.entries, 0..) |slot, index| if (slot) |process| {
            pids[index] = process.pid;
        };
    }
    var result: api.ParticipationResponse = .{ .realm = realm, .resource = undefined, .resource_position = 0, .process_position = position, .policy_revision = reader.body.identity.policy_revision, .next = next };
    for (pids, 0..) |slot, index| if (slot) |pid| {
        const page = try wire.query(.{ .realm = realm, .principal = principal, .kind = .{ .associations = .{ .pid = pid, .after = cursor.association_after, .position = if (cursor.association_after != null) cursor.position else null } } }, key);
        var matches: u8 = 0;
        for (page.body.associations.entries) |entry| if (entry) |association| {
            // The native reader filters grants before returning any names. Only
            // the selected resource contributes; no hidden-resource counts leak.
            if (association.resource == cursor.resource) matches += 1;
        };
        result.members[index] = .{ .pid = pid, .association_position = page.position, .matches = matches, .next = page.body.associations.next };
    };
    const resource = try wire.query(.{ .realm = realm, .principal = principal, .kind = .{ .resource = cursor.resource } }, key);
    const current = try identity(wire, realm, principal, key);
    if (current.body.identity.policy_revision != reader.body.identity.policy_revision) return error.QueryChanged;
    result.resource = resource.body.resource;
    result.resource_position = resource.position;
    return result;
}
pub fn records(wire: *client.Client, realm: u64, principal: u64, key: p.Ed25519.KeyPair, cursor: RecordsCursor, allocator: std.mem.Allocator) !api.RecordsResponse {
    _ = try identity(wire, realm, principal, key);
    const revision = cursor.revision orelse (try wire.query(.{ .realm = realm, .principal = principal, .kind = .{ .resource = cursor.resource } }, key)).body.resource.revision;
    const response = try wire.query(.{ .realm = realm, .principal = principal, .kind = .{ .entries = .{ .resource = cursor.resource, .revision = revision, .after = cursor.after } } }, key);
    const entries = response.body.entries;
    if (entries.resource.id != cursor.resource) return error.QueryChanged;
    if (entries.resource.phase != .active) return error.QuerySourceUnavailable;
    return api.projectRecords(allocator, realm, response.position, entries.resource, entries.page);
}
/// The Board read projection binds every page to a current authorization cut.
pub fn inspect(wire: *client.Client, realm: u64, principal: u64, key: p.Ed25519.KeyPair, selector: g.Inspection.Query) !api.Response {
    const response = try wire.query(.{ .realm = realm, .principal = principal, .kind = .{ .inspection = selector } }, key);
    if (response.body.inspection.reader.permissions != p.permission(.inspect)) return error.UnsafePrincipal;
    return api.project(response.body.inspection);
}
pub fn state(wire: *client.Client, realm: u64, principal: u64, key: p.Ed25519.KeyPair, selector: api.StateQuery) !api.StateResponse {
    const basis = try wire.query(.{ .realm = realm, .principal = principal, .kind = .{ .inspection = .{ .resource = .processes } } }, key);
    const reader = basis.body.inspection.reader;
    if (reader.permissions != p.permission(.inspect)) return error.UnsafePrincipal;
    if (selector.cut) |cut| if (!std.meta.eql(cut, basis.body.inspection.cut)) return error.QueryChanged;
    const kind: @FieldType(g.Query, "kind") = switch (selector.kind) {
        .resources => if (selector.resource) |id| .{ .resource = id } else .{ .resources = .{ .after = if (selector.after == 0) null else selector.after, .position = basis.position } },
        .associations => .{ .associations = .{ .pid = selector.pid.?, .after = if (selector.after == 0) null else selector.after, .position = basis.position } },
        .entries => blk: {
            const meta = try wire.query(.{ .realm = realm, .principal = principal, .kind = .{ .resource = selector.resource.? } }, key);
            if (meta.position != basis.position) return error.QueryChanged;
            if (selector.revision) |revision| if (revision != meta.body.resource.revision) return error.QueryChanged;
            break :blk .{ .entries = .{ .resource = selector.resource.?, .revision = meta.body.resource.revision, .after = selector.after_key } };
        },
    };
    const response = try wire.query(.{ .realm = realm, .principal = principal, .kind = kind }, key);
    if (response.position != basis.position) return error.QueryChanged;
    var page: api.StatePage = .{ .realm = realm, .principal_sequence = response.principal_sequence, .reader = reader, .kind = selector.kind, .cut = basis.body.inspection.cut };
    switch (response.body) {
        .resource => |resource| page.resources[0] = resource,
        .resources => |resources| {
            page.resources = resources.entries;
            page.next = resources.next;
        },
        .associations => |associations| {
            page.associations = associations.entries;
            page.next = associations.next;
        },
        .entries => |entries| {
            page.resources[0] = entries.resource;
            page.entries = entries.page.entries;
            page.next_key = entries.page.next;
        },
        else => return error.InvalidAuthorityResponse,
    }
    return api.projectState(page);
}
