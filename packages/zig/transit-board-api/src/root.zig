//! Board v1: evidence-preserving projections over the public Transit contract.
const std = @import("std");
pub const protocol = @import("transit_protocol");
const p = protocol;
const i = p.Inspection;
pub const max_edges = 32;
pub const Mapping = struct { pid: u64, kind: []const u8, version: u32 };
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
pub const Lens = struct {
    kind: []const u8,
    version: u32,
    provenance: enum { operator_mapping } = .operator_mapping,
    status: enum { applied, unknown, malformed },
    source: Reference,
    count: ?i64 = null,
};
pub const Response = struct { observation: i.Page, lens: ?Lens = null, edges: [max_edges]?Edge = @splat(null) };
pub const Capabilities = struct {
    version: u32 = 1,
    realm: u64,
    scope_pid: ?u64,
    read_only: bool = true,
    shared_principal: bool = true,
    page_size: u32 = i.page_size,
    scan_limit: u32 = i.scan_limit,
    max_edges: u32 = max_edges,
    min_refresh_ms: u32 = 5000,
    max_request_bytes: u32 = 4096,
    session_seconds: u32,
    station: bool = false,
    http_connector: bool = false,
    push: bool = false,
};
pub const Error = struct { err: enum { Unauthorized, Forbidden, NotFound, InvalidQuery, QueryExpired, HistoryReclaimed, Unavailable, RateLimited, InvalidOrigin, UnsafePrincipal } };
pub const Session = struct { expires_in: u32 };

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
pub fn project(page: i.Page, mappings: []const Mapping) error{InvalidObservation}!Response {
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
    // A lens requires an explicit operator declaration, never a code-tag guess.
    if (page.resource == .process) if (page.processes[0]) |process| {
        for (mappings) |mapping| if (mapping.pid == process.pid) {
            var lens: Lens = .{ .kind = mapping.kind, .version = mapping.version, .status = .unknown, .source = reference(page, process.pid, .state, process.revision) };
            if (std.mem.eql(u8, mapping.kind, "rey.example.counter") and mapping.version == 1) {
                lens.status = .malformed;
                if (process.state.asInteger()) |value| {
                    if (value >= -p.max_counter and value <= p.max_counter) {
                        lens.status = .applied;
                        lens.count = value;
                    }
                } else |_| {}
            }
            result.lens = lens;
            break;
        };
    };
    return result;
}

test "lenses require explicit mapping and preserve kernel facts on malformed or unknown data" {
    var page: i.Page = .{ .realm = 1, .resource = .process, .pid = 3, .cut = .{ .position = 10, .policy_revision = 2, .retained_from = 0 }, .reader = .{ .principal = 1, .permissions = 16, .pid = null }, .history = .retained };
    page.processes[0] = .{ .pid = 3, .code = 1, .state = p.Value.integer(23), .lifecycle = .expired };
    try std.testing.expectEqual(null, (try project(page, &.{})).lens);
    const known = try project(page, &.{.{ .pid = 3, .kind = "rey.example.counter", .version = 1 }});
    try std.testing.expectEqual(.applied, known.lens.?.status);
    try std.testing.expectEqual(23, known.lens.?.count.?);
    try std.testing.expectEqual(.expired, known.observation.processes[0].?.lifecycle);
    const unknown = try project(page, &.{.{ .pid = 3, .kind = "rey.example.counter", .version = 2 }});
    try std.testing.expectEqual(.unknown, unknown.lens.?.status);
    page.processes[0].?.state = try p.Value.init("<script>alert('test')</script>");
    try std.testing.expectEqual(.malformed, (try project(page, &.{.{ .pid = 3, .kind = "rey.example.counter", .version = 1 }})).lens.?.status);
}

test "journey edges are explicit and retained gaps do not fabricate history" {
    var page: i.Page = .{ .realm = 1, .resource = .outbox, .pid = 3, .cut = .{ .position = 20, .policy_revision = 2, .retained_from = 10 }, .reader = .{ .principal = 1, .permissions = 16, .pid = null }, .history = .prefix_reclaimed };
    page.outbox[0] = .{ .id = 1, .source = 3, .turn = 7, .index = 0, .destination = 4, .value = .{}, .phase = .delivered, .resolved_at = 12 };
    const view = try project(page, &.{});
    try std.testing.expectEqual(.reclaimed, view.edges[0].?.from_coverage);
    try std.testing.expectEqual(.current_state, view.edges[0].?.to_coverage);
    try std.testing.expectEqual(4, view.edges[1].?.to.pid);
    try std.testing.expectEqual(12, view.edges[1].?.to.id);
    try std.testing.expectEqual(null, view.edges[2]);
    page.outbox[0].?.phase = .denied;
    try std.testing.expectEqual(null, (try project(page, &.{})).edges[1]);
}

test "malformed mixed resource pages cannot overflow or fabricate a journey" {
    var page: i.Page = .{ .realm = 1, .resource = .history, .pid = 3, .cut = .{ .position = 30, .policy_revision = 2, .retained_from = 0 }, .reader = .{ .principal = 1, .permissions = 16, .pid = null }, .history = .retained };
    page.events = @splat(.{ .position = 7, .pid = 3, .kind = .turn, .policy_revision = 2, .input = 5, .effect = 7 });
    const valid = try project(page, &.{});
    try std.testing.expect(valid.edges[max_edges - 1] != null);
    page.outbox[0] = .{ .id = 1, .source = 3, .turn = 7, .index = 0, .destination = 4, .value = .{} };
    try std.testing.expectError(error.InvalidObservation, project(page, &.{}));
    page.outbox[0] = null;
    page.complete = false;
    try std.testing.expectError(error.InvalidObservation, project(page, &.{}));
}
