//! Board v1: evidence-preserving projections over the public Transit contract.
const std = @import("std");
pub const Exchange = @import("Exchange.zig");
pub const Http = @import("Http.zig");
pub const HttpResponse = Http.Response;
pub const Grpc = @import("Grpc.zig");
pub const GrpcResponse = Grpc.Response;
pub const Document = @import("Document.zig");
pub const DocumentResponse = Document.Response;
pub const Query = @import("Query.zig");
pub const Json = @import("Json.zig");
test {
    _ = Json;
    _ = Exchange;
    _ = Document;
    _ = Query;
}
pub const protocol = @import("transit_protocol");
const p = protocol;
const i = p.Inspection;
pub const max_edges = 32;
pub const Reference = struct {
    realm: u64,
    pid: u64,
    kind: enum { input, turn, output, effect, event, state },
    id: u64,
};
pub const Coverage = enum { retained, reclaimed, current_state };
pub const Edge = struct {
    from: Reference,
    to: Reference,
    relation: enum { input_to_turn, turn_to_effect, turn_to_output, output_to_admission, effect_to_observation },
    from_coverage: Coverage,
    to_coverage: Coverage,
};
pub const Response = struct { observation: i.Page, edges: [max_edges]?Edge = @splat(null) };
pub const Lens = struct {
    version: u8 = 1,
    source: struct { realm: u64, pid: u64, resource: u64, key: p.Value, entry_revision: u64, resource_revision: u64, position: u64 },
    declaration: @import("transit_station").Metadata.Detail,
};
pub const StateResponse = struct { observation: p.State.Page, framework: [p.State.page_size]?Lens = @splat(null) };
pub const ExchangeLens = struct { version: u8 = 1, source: @FieldType(Lens, "source"), declaration: Exchange.Detail };
pub const RecordIdentity = struct { key: p.Value, revision: u64 };
pub const RecordsResponse = struct {
    version: u8 = 1,
    realm: u64,
    position: u64,
    resource: p.Growth.Resource,
    page: p.Growth.Batch(RecordIdentity, p.Value),
    exchanges: [p.Growth.page_size]?ExchangeLens = @splat(null),
    documents: [p.Growth.page_size]?Document.Lens = @splat(null),
    queries: [p.Growth.page_size]?Query.Lens = @splat(null),
};
pub fn projectRecords(allocator: std.mem.Allocator, realm: u64, position: u64, resource: p.Growth.Resource, page: p.Growth.Batch(p.Growth.Entry, p.Value)) !RecordsResponse {
    var result: RecordsResponse = .{ .realm = realm, .position = position, .resource = resource, .page = .{ .next = page.next } };
    for (page.entries, 0..) |slot, index| if (slot) |entry| {
        result.page.entries[index] = .{ .key = entry.key, .revision = entry.revision };
        if (try Query.decode(allocator, resource.writer, resource.id, entry.key, entry.value)) |detail| result.queries[index] = .{ .source = .{ .realm = realm, .pid = resource.writer, .resource = resource.id, .key = entry.key, .entry_revision = entry.revision, .resource_revision = resource.revision, .position = position }, .declaration = detail };
        if (try Document.decode(allocator, entry.key, entry.value)) |detail| result.documents[index] = .{ .source = .{ .realm = realm, .pid = resource.writer, .resource = resource.id, .key = entry.key, .entry_revision = entry.revision, .resource_revision = resource.revision, .position = position }, .declaration = detail };
        if (try Exchange.decode(allocator, resource.writer, entry.key, entry.value)) |detail| result.exchanges[index] = .{ .source = .{ .realm = realm, .pid = resource.writer, .resource = resource.id, .key = entry.key, .entry_revision = entry.revision, .resource_revision = resource.revision, .position = position }, .declaration = detail };
    };
    return result;
}
test "growing metadata projection never returns captured or application values" {
    const t = std.testing;
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    var page: p.Growth.Batch(p.Growth.Entry, p.Value) = .{};
    const body = try p.Value.init("private captured body");
    page.entries[0] = .{ .key = try p.Value.init("application"), .value = body, .revision = 5 };
    const projected = try projectRecords(arena.allocator(), 1, 7, .{ .id = 3, .writer = 2, .owner = null, .revision = 5, .entries = 1, .deadline_ms = null }, page);
    try t.expectEqual(null, projected.exchanges[0]);
    try t.expect(projected.page.entries[0].?.key.eql(page.entries[0].?.key));
    const json = try std.json.Stringify.valueAlloc(arena.allocator(), projected, .{});
    try t.expect(std.mem.indexOf(u8, json, "private captured body") == null);
    const hex = try std.fmt.allocPrint(arena.allocator(), "{x}", .{body.slice()});
    try t.expect(std.mem.indexOf(u8, json, hex) == null);
}
pub const Capabilities = struct {
    version: u32 = 1,
    profile: enum { legacy_v2, growing_v3 } = .legacy_v2,
    query_enabled: bool = false,
    realm: u64,
    scope_pid: ?u64,
    read_only: bool = true,
    shared_principal: bool = true,
    page_size: u32 = i.page_size,
    scan_limit: u32 = i.scan_limit,
    max_edges: u32 = max_edges,
    min_refresh_ms: u32 = 5000,
    max_request_bytes: u32 = 4096,
    state_resources: bool = true,
    station: bool = true,
    http_connector: bool = false,
    grpc_connector: bool = false,
    documents: bool = false,
    reactive_table: bool = false,
    push: bool = false,
};
pub const Error = struct { err: enum { Forbidden, NotFound, InvalidQuery, QueryExpired, HistoryReclaimed, Unavailable, RateLimited, InvalidOrigin, UnsafePrincipal, StateResourceExpired, QueryDisabled, QueryBusy, UnsupportedQuery, QueryRequestTooLarge, IncompleteResult, InvalidQueryOrdinal, QueryConflict } };

pub const QueryRequest = @import("transit_query").Model.Request;
pub const QueryResponse = @import("transit_query").Model.Response;
pub const UnifiedQueryRequest = @import("transit_query").Workspace.Request;
pub const UnifiedQueryResponse = @import("transit_query").Workspace.Response;
pub const unified_query_schema_options = @import("transit_query").Workspace.schema_options;
pub const AtlasResponse = struct {
    version: u8 = 1,
    realm: u64,
    position: u64,
    identity: p.Growth.Identity,
    processes: p.Growth.Batch(p.Growth.Process, u64),
    resources: p.Growth.Batch(p.Growth.Resource, u64),
    query_resource: ?u64,
    query_version: ?u8 = null,
};

/// One bounded process page and one authorized association page per process.
/// Every association page has its own basis; these are not a global census.
pub const ParticipationResponse = struct {
    version: u8 = 1,
    realm: u64,
    resource: p.Growth.Resource,
    resource_position: u64,
    process_position: ?u64,
    policy_revision: u64,
    members: [p.Growth.page_size]?struct { pid: u64, association_position: u64, matches: u8, next: ?u64 } = @splat(null),
    next: ?u64,
};

fn reference(page: i.Page, pid: u64, kind: @FieldType(Reference, "kind"), id: u64) Reference {
    return .{ .realm = page.realm, .pid = pid, .kind = kind, .id = id };
}
fn coverage(page: i.Page, ref: Reference) @FieldType(Edge, "from_coverage") {
    if (ref.kind == .output or ref.kind == .state) return .current_state;
    return if (ref.id < page.cut.retained_from) .reclaimed else .retained;
}
fn add(result: *Response, count: *usize, from: Reference, to: Reference, relation: @FieldType(Edge, "relation")) void {
    std.debug.assert(count.* < max_edges);
    result.edges[count.*] = .{ .from = from, .to = to, .relation = relation, .from_coverage = coverage(result.observation, from), .to_coverage = coverage(result.observation, to) };
    count.* += 1;
}
pub fn project(page: i.Page) error{InvalidObservation}!Response {
    const collection = switch (page.resource) {
        .process, .processes => "processes",
        .mailbox, .history => "events",
        .outbox => "outbox",
        .effects => "effects",
        .payloads => "payloads",
    };
    // JSON's fixed arrays bound bytes, but do not enforce resource exclusivity.
    // Reject malformed upstream projections before interpreting any evidence;
    // one page then needs at most two edges for each of its sixteen facts.
    inline for (.{ "processes", "events", "outbox", "effects", "payloads" }) |name| {
        if (!std.mem.eql(u8, name, collection)) for (@field(page, name)) |slot| {
            if (slot != null) return error.InvalidObservation;
        };
    }
    if (page.version != 1 or (page.next == null) != page.complete) return error.InvalidObservation;
    var result: Response = .{ .observation = page };
    var count: usize = 0;
    for (page.events) |slot| if (slot) |event| {
        const dest = reference(page, event.pid, if (event.kind == .turn) .turn else .event, event.position);
        if (event.input) |input| if (event.kind == .turn) add(&result, &count, reference(page, event.pid, .input, input), dest, .input_to_turn);
        if (event.effect) |effect| {
            const effect_ref = reference(page, event.pid, .effect, effect);
            if (event.kind == .turn) {
                add(&result, &count, dest, effect_ref, .turn_to_effect);
            } else if (event.kind == .observe) add(&result, &count, effect_ref, dest, .effect_to_observation);
        }
    };
    for (page.outbox) |slot| if (slot) |output| {
        const out = reference(page, output.source, .output, output.id);
        add(&result, &count, reference(page, output.source, .turn, output.turn), out, .turn_to_output);
        if (output.phase == .delivered) if (output.resolved_at) |at| add(&result, &count, out, reference(page, output.destination, .input, at), .output_to_admission);
    };
    return result;
}

test "journey edges are explicit and retained gaps do not fabricate history" {
    var page: i.Page = .{ .realm = 1, .resource = .outbox, .pid = 3, .cut = .{ .position = 20, .policy_revision = 2, .retained_from = 10 }, .reader = .{ .principal = 1, .permissions = 16, .pid = null }, .history = .prefix_reclaimed };
    page.outbox[0] = .{ .id = 1, .source = 3, .turn = 7, .index = 0, .destination = 4, .value = .{}, .phase = .delivered, .resolved_at = 12 };
    const view = try project(page);
    try std.testing.expectEqual(.reclaimed, view.edges[0].?.from_coverage);
    try std.testing.expectEqual(.current_state, view.edges[0].?.to_coverage);
    try std.testing.expectEqual(4, view.edges[1].?.to.pid);
    try std.testing.expectEqual(12, view.edges[1].?.to.id);
    try std.testing.expectEqual(null, view.edges[2]);
    page.outbox[0].?.phase = .denied;
    try std.testing.expectEqual(null, (try project(page)).edges[1]);
}

test "malformed mixed resource pages cannot overflow or fabricate a journey" {
    var page: i.Page = .{ .realm = 1, .resource = .history, .pid = 3, .cut = .{ .position = 30, .policy_revision = 2, .retained_from = 0 }, .reader = .{ .principal = 1, .permissions = 16, .pid = null }, .history = .retained };
    page.events = @splat(.{ .position = 7, .pid = 3, .kind = .turn, .policy_revision = 2, .input = 5, .effect = 7 });
    const valid = try project(page);
    try std.testing.expect(valid.edges[max_edges - 1] != null);
    page.outbox[0] = .{ .id = 1, .source = 3, .turn = 7, .index = 0, .destination = 4, .value = .{} };
    try std.testing.expectError(error.InvalidObservation, project(page));
    page.outbox[0] = null;
    page.complete = false;
    try std.testing.expectError(error.InvalidObservation, project(page));
}

pub fn projectState(page: p.State.Page) !StateResponse {
    if (page.version != 1 or page.view != null or page.capabilities != null) return error.InvalidObservation;
    const collection = switch (page.kind) {
        .resources => "resources",
        .associations => "associations",
        .entries => "entries",
        else => return error.InvalidObservation,
    };
    inline for (.{ "resources", "associations", "entries" }) |name| {
        if (!std.mem.eql(u8, collection, name) and !(page.kind == .entries and std.mem.eql(u8, name, "resources"))) {
            for (@field(page, name)) |slot| if (slot != null) return error.InvalidObservation;
        }
    }
    var response: StateResponse = .{ .observation = page };
    if (page.kind == .entries) {
        const resource = page.resources[0] orelse return error.InvalidObservation;
        for (page.resources[1..]) |slot| if (slot != null) return error.InvalidObservation;
        for (page.entries, 0..) |slot, index| if (slot) |entry| {
            if (@import("transit_station").Metadata.decode(resource.writer, resource.id, entry)) |declaration| {
                response.framework[index] = .{ .source = .{ .realm = page.realm, .pid = resource.writer, .resource = resource.id, .key = entry.key, .entry_revision = entry.revision, .resource_revision = resource.revision, .position = page.cut.position }, .declaration = declaration };
            }
        };
    }
    return response;
}

test "state projection cannot mix metadata-only associations with opaque values" {
    var page: p.State.Page = .{ .realm = 1, .principal_sequence = 0, .kind = .associations, .reader = .{ .principal = 1, .permissions = 16, .pid = 2 }, .cut = .{ .position = 5, .policy_revision = 3, .retained_from = 0 } };
    page.associations[0] = .{ .pid = 2, .name = try p.Value.init("opaque"), .resource = 3, .revision = 4, .required = true };
    try std.testing.expectEqual(page, (try projectState(page)).observation);
    page.entries[0] = .{ .key = try p.Value.init("key"), .value = try p.Value.init("private"), .revision = 4 };
    try std.testing.expectError(error.InvalidObservation, projectState(page));
}
