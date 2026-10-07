//! Foreign growing turns use the same native state/Table/message operations.
//! All results borrow the caller's arena; no pointer escapes the ABI response.
const std = @import("std");
const s = @import("transit_station");
const p = s.protocol;
const a = @import("Actions.zig");
const q = s.Query;
const grpc = @import("GrpcCodec.zig").grpc;
const http = @import("HttpCodec.zig").http;
const unsigned = @import("HttpCodec.zig").unsigned;
fn publishedRequest(turn: *s.Turn, wire: p.Value) !void {
    const reference = try http.RequestRecord.Reference.decode(wire);
    if (reference.resource != turn.view.resource) return error.InvalidHttpRequestReference;
    const publication: s.Publication = .{ .domain = .application, .resource = reference.resource, .namespace = reference.namespace };
    const metadata = try publication.open(turn, http.RequestRecord.metadata_id);
    const body = try publication.open(turn, http.RequestRecord.body_id);
    if (!std.meta.eql(metadata.spec, reference.metadataSpec()) or !std.meta.eql(body.spec, reference.bodySpec())) return error.InvalidHttpRequestReference;
}
fn publishedGrpcRequest(turn: *s.Turn, wire: p.Value) !void {
    const reference = try grpc.RequestRecord.Reference.decode(wire);
    if (reference.resource != turn.view.resource) return error.InvalidGrpcRequestReference;
    const publication: s.Publication = .{ .domain = .application, .resource = reference.resource, .namespace = reference.namespace };
    const metadata = try publication.open(turn, grpc.RequestRecord.metadata_id);
    const body = try publication.open(turn, grpc.RequestRecord.batch_id);
    if (!std.meta.eql(metadata.spec, reference.metadataSpec()) or !std.meta.eql(body.spec, reference.batchSpec())) return error.InvalidGrpcRequestReference;
}
pub const Plan = @import("transit_query").Values.Plan;
pub const Manifest = struct {
    result: u64,
    source: u64,
    destination: u64,
    correlation: []const u8,
    table: []const u8,
    policy_revision: []const u8,
    basis: q.records.Basis,
    plan: [32]u8,
    segments: []const u8,
    bytes: []const u8,
    rows: []const u8,
    chain: [32]u8,
    schema: [32]u8,
};
pub const Action = union(enum) {
    document: @import("DocumentBridge.zig").Action,
    budgets: void,
    get: p.Value,
    put: @FieldType(a.BasicAction, "put"),
    delete: p.Value,
    cast: @FieldType(a.BasicAction, "cast"),
    call: struct { pid: u64, value: p.Value, deadline_ms: ?u64 = null, observer: ?u64 = null },
    reply: p.Value,
    cancel: []const u8,
    effect: p.Value,
    table_create: @FieldType(a.BasicAction, "table_create"),
    table_get: @FieldType(a.BasicAction, "table_get"),
    table_write: @FieldType(a.BasicAction, "table_write"),
    table_delete: @FieldType(a.BasicAction, "table_delete"),
    page: ?[]const u8,
    table_page: struct { id: u32, cursor: ?[]const u8 = null, version: ?p.Growth.ReadVersionId = null },
    table_schema: struct { id: u32, version: ?p.Growth.ReadVersionId = null },
    retain: void,
    release: p.Growth.ReadVersionId,
    version_get: struct { id: p.Growth.ReadVersionId, key: p.Value },
    version_page: struct { id: p.Growth.ReadVersionId, cursor: ?[]const u8 = null },
    version_table_get: struct { version: p.Growth.ReadVersionId, id: u32, key: []const u8 },
    registry_create: u32,
    registry_grant: struct { scope: u32, subject: s.Registry.Subject, lookup: bool, mutate: bool },
    registry_handle: void,
    registry_route: struct { registry: u64, payload: p.Value },
    supervisor_register: s.Supervisor.Child,
    supervisor_observe: void,
    query_policy: @FieldType(a.BasicAction, "query_policy"),
    query_start: struct { id: []const u8, plan: Plan },
    query_close: struct { result: u64, reason: enum { cancelled, denied } },
    query_completed: []const u8,
    query_segment: struct { correlation: []const u8, ordinal: []const u8 },
    publication_create: struct { namespace: []const u8, record_bytes: u32, staging_bytes: []const u8, staging_records: u32 },
    publication_begin: struct { namespace: []const u8, id: []const u8, spec: s.Publication.Spec },
    publication_append: struct { namespace: []const u8, id: []const u8, index: u32, bytes: p.Value },
    publication_publish: struct { namespace: []const u8, id: []const u8 },
    publication_abandon: struct { namespace: []const u8, id: []const u8 },
    publication_retire: struct { namespace: []const u8, id: []const u8 },
    publication_collect: struct { namespace: []const u8, id: []const u8 },
    http_call: struct { pid: u64, reference: p.Value },
    http_stage: struct { reference: p.Value, metadata: []const u8, body: []const u8 },
    http_release: struct { pid: u64, resource: u64, exchange: []const u8 },
    http_followup: struct { pid: u64, resource: u64, parent: []const u8, reason: http.Policy.Reason, reference: p.Value },
    grpc_call: struct { pid: u64, reference: p.Value },
    grpc_stage: struct { reference: p.Value, metadata: []const u8, batch: []const u8 },
    grpc_release: struct { pid: u64, resource: u64, exchange: []const u8 },
    grpc_followup: struct { pid: u64, resource: u64, parent: []const u8, reference: p.Value },

    pub fn requiresQuery(self: Action) bool {
        return switch (self) {
            .query_policy, .query_start, .query_close, .query_completed, .query_segment => true,
            else => false,
        };
    }
};
pub const Result = union(enum) {
    document: @import("DocumentBridge.zig").Result,
    budgets: struct { mutations: u32, outputs: u32, views: u32, retained_reads: u32, retains: u32, releases: u32 },
    none,
    value: ?p.Value,
    correlation: []const u8,
    cancelled: bool,
    publication: s.Publication.Outcome,
    collected: bool,
    staged: bool,
    row: ?a.Row,
    schema: struct { id: u32, key_name: []const u8, value_name: []const u8, value_type: s.fuze.model.Type, basis: s.fuze.model.Basis },
    page: struct { entries: [p.Growth.page_size]?p.Growth.Entry, next: ?[]const u8 },
    rows: struct { basis: s.fuze.model.Basis, rows: [p.Growth.page_size]?a.Row, next: ?[]const u8 },
    version: p.Growth.ReadVersionId,
    query: struct { result: u64, correlation: []const u8, source: p.Growth.ReadVersionId },
    manifest: Manifest,
    segment: struct { result: u64, ordinal: []const u8, rows: u8, bytes: u16, digest: [32]u8, ipc: []const u8 },
};
const Cursor = struct { source: @FieldType(s.Table.Cursor, "source"), resource: u64, revision: u64, after: p.Value };

fn parseCursor(comptime T: type, allocator: std.mem.Allocator, bytes: []const u8) !T {
    if (bytes.len == 0 or bytes.len > 2048) return error.InvalidCursor;
    const parsed = try std.json.parseFromSlice(T, allocator, bytes, .{});
    defer parsed.deinit();
    const canonical = try std.json.Stringify.valueAlloc(allocator, parsed.value, .{});
    if (!std.mem.eql(u8, bytes, canonical)) return error.InvalidCursor;
    return parsed.value;
}
fn page(allocator: std.mem.Allocator, source: anytype, encoded: ?[]const u8) !Result {
    const version = @TypeOf(source.view.id) == p.Growth.ReadVersionId;
    const identity: @FieldType(Cursor, "source") = if (version) .{ .version = source.view.id } else .{ .view = source.view.id };
    const cursor = if (encoded) |bytes| try parseCursor(Cursor, allocator, bytes) else null;
    if (cursor) |saved| if (!std.meta.eql(saved.source, identity) or saved.resource != source.view.resource or saved.revision != source.view.revision) return error.StaleStateCursor;
    const batch = try source.page(if (cursor) |saved| saved.after else null);
    return .{ .page = .{ .entries = batch.entries, .next = if (batch.next) |after| try std.json.Stringify.valueAlloc(allocator, Cursor{ .source = identity, .resource = source.view.resource, .revision = source.view.revision, .after = after }, .{}) else null } };
}
fn tablePage(allocator: std.mem.Allocator, source: anytype, id: u32, encoded: ?[]const u8) !Result {
    const table = try s.Table.open(source, id);
    const cursor = if (encoded) |bytes| try parseCursor(s.Table.Cursor, allocator, bytes) else null;
    const batch = try table.page(source, cursor);
    var rows: [p.Growth.page_size]?a.Row = @splat(null);
    for (rows[0..batch.len], batch.rows[0..batch.len]) |*out, row| out.* = .{ .key = try a.decimal(allocator, row.key), .value = try a.foreignCell(allocator, row.value) };
    return .{ .rows = .{ .basis = batch.basis, .rows = rows, .next = if (batch.next) |next| try std.json.Stringify.valueAlloc(allocator, next, .{}) else null } };
}
fn tableSchema(allocator: std.mem.Allocator, source: anytype, id: u32) !Result {
    const table = try s.Table.open(source, id);
    return .{ .schema = .{
        .id = table.id,
        .key_name = try allocator.dupe(u8, table.schema.names[0].slice()),
        .value_name = try allocator.dupe(u8, table.schema.names[1].slice()),
        .value_type = table.schema.value_type,
        .basis = .{ .resource = source.view.resource, .revision = source.view.revision, .schema = try table.schema.fingerprint() },
    } };
}
pub fn apply(allocator: std.mem.Allocator, turn: *s.Turn, action: Action) !Result {
    if (try a.basic(Result, allocator, turn, action)) |result| return result;
    switch (action) {
        .registry_create => |scope| try s.Registry.create(turn, scope),
        .registry_grant => |grant| try s.Registry.grant(turn, grant.scope, grant.subject, .{ .lookup = grant.lookup, .mutate = grant.mutate }),
        .registry_handle => try s.Registry.handle(turn, try s.Frame.decode(turn.delivery.input.value)),
        .registry_route => |route| {
            _ = try s.Registry.route(turn, route.registry, try s.Frame.decode(turn.delivery.input.value), route.payload);
        },
        .supervisor_register => |child| try s.Supervisor.register(turn, child),
        .supervisor_observe => try s.Supervisor.observe(turn, try s.Supervisor.Observation.decode(try s.Frame.decode(turn.delivery.input.value))),
        .document => |v| return .{ .document = try @import("DocumentBridge.zig").apply(allocator, turn, v) },
        .budgets => return .{ .budgets = .{ .mutations = remaining(turn.decision.mutations), .outputs = remaining(turn.decision.outputs), .views = remaining(turn.decision.views), .retained_reads = remaining(turn.decision.read_versions), .retains = remaining(turn.decision.retain), .releases = remaining(turn.decision.release) } },
        .publication_create => |v| {
            _ = try s.Publication.create(turn, .application, try unsigned(v.namespace), .{ .record_bytes = v.record_bytes, .staging_bytes = try unsigned(v.staging_bytes), .staging_records = v.staging_records });
        },
        .publication_begin => |v| return .{ .publication = try (s.Publication{ .domain = .application, .resource = turn.view.resource, .namespace = try unsigned(v.namespace) }).begin(turn, try unsigned(v.id), v.spec) },
        .publication_append => |v| return .{ .publication = try (s.Publication{ .domain = .application, .resource = turn.view.resource, .namespace = try unsigned(v.namespace) }).append(turn, try unsigned(v.id), v.index, v.bytes.slice()) },
        .publication_publish => |v| return .{ .publication = try (s.Publication{ .domain = .application, .resource = turn.view.resource, .namespace = try unsigned(v.namespace) }).publish(turn, try unsigned(v.id)) },
        .publication_abandon => |v| return .{ .publication = try (s.Publication{ .domain = .application, .resource = turn.view.resource, .namespace = try unsigned(v.namespace) }).abandon(turn, try unsigned(v.id)) },
        .publication_retire => |v| return .{ .publication = try (s.Publication{ .domain = .application, .resource = turn.view.resource, .namespace = try unsigned(v.namespace) }).retire(turn, try unsigned(v.id)) },
        .publication_collect => |v| return .{ .collected = try (s.Publication{ .domain = .application, .resource = turn.view.resource, .namespace = try unsigned(v.namespace) }).collect(turn, try unsigned(v.id)) },
        .http_call => |v| {
            try publishedRequest(turn, v.reference);
            return .{ .correlation = try a.decimal(allocator, try turn.call(v.pid, v.reference, null)) };
        },
        .http_followup => |v| {
            const request = try (@import("HttpCodec.zig").Followup{ .resource = v.resource, .parent = v.parent, .reason = v.reason, .reference = v.reference }).native();
            try publishedRequest(turn, v.reference);
            return .{ .correlation = try a.decimal(allocator, try turn.call(v.pid, try request.encode(), null)) };
        },
        .http_stage => |v| {
            const reference = try http.RequestRecord.Reference.decode(v.reference);
            if (v.metadata.len != @as(usize, reference.metadata_bytes) * 2 or v.body.len != @as(usize, reference.body_bytes) * 2) return error.InvalidHttpRequestReference;
            const metadata = try allocator.alloc(u8, reference.metadata_bytes);
            const body = try allocator.alloc(u8, reference.body_bytes);
            _ = try std.fmt.hexToBytes(metadata, v.metadata);
            _ = try std.fmt.hexToBytes(body, v.body);
            return .{ .staged = try http.RequestRecord.stage(turn, reference, metadata, body) };
        },
        .http_release => |v| {
            const request: http.Service.Release = .{ .resource = v.resource, .exchange = try unsigned(v.exchange) };
            return .{ .correlation = try a.decimal(allocator, try turn.call(v.pid, try request.encode(), null)) };
        },
        .grpc_call => |v| {
            try publishedGrpcRequest(turn, v.reference);
            return .{ .correlation = try a.decimal(allocator, try turn.call(v.pid, v.reference, null)) };
        },
        .grpc_followup => |v| {
            const request = try (@import("GrpcCodec.zig").Followup{ .resource = v.resource, .parent = v.parent, .reference = v.reference }).native();
            try publishedGrpcRequest(turn, v.reference);
            return .{ .correlation = try a.decimal(allocator, try turn.call(v.pid, try request.encode(), null)) };
        },
        .grpc_stage => |v| {
            const reference = try grpc.RequestRecord.Reference.decode(v.reference);
            if (v.metadata.len != @as(usize, reference.metadata_bytes) * 2 or v.batch.len != @as(usize, reference.batch_bytes) * 2) return error.InvalidGrpcRequestReference;
            const metadata = try allocator.alloc(u8, reference.metadata_bytes);
            const batch = try allocator.alloc(u8, reference.batch_bytes);
            _ = try std.fmt.hexToBytes(metadata, v.metadata);
            _ = try std.fmt.hexToBytes(batch, v.batch);
            return .{ .staged = try grpc.RequestRecord.stage(turn, reference, metadata, batch) };
        },
        .grpc_release => |v| {
            const request: grpc.Service.Release = .{ .resource = v.resource, .exchange = try unsigned(v.exchange) };
            return .{ .correlation = try a.decimal(allocator, try turn.call(v.pid, try request.encode(), null)) };
        },
        .page => |cursor| return page(allocator, turn, cursor),
        .table_page => |request| {
            if (request.version) |id| {
                var source = try turn.openVersion(id);
                return tablePage(allocator, &source, request.id, request.cursor);
            }
            return tablePage(allocator, turn, request.id, request.cursor);
        },
        .table_schema => |request| {
            if (request.version) |id| {
                var source = try turn.openVersion(id);
                return tableSchema(allocator, &source, request.id);
            }
            return tableSchema(allocator, turn, request.id);
        },
        .retain => return .{ .version = try turn.retain() },
        .release => |id| try turn.release(id),
        .version_get => |request| {
            var source = try turn.openVersion(request.id);
            return .{ .value = try source.read(request.key) };
        },
        .version_page => |request| {
            var source = try turn.openVersion(request.id);
            return page(allocator, &source, request.cursor);
        },
        .version_table_get => |request| {
            var source = try turn.openVersion(request.version);
            const table = try s.Table.open(&source, request.id);
            const row = (try table.get(&source, try std.fmt.parseInt(i64, request.key, 10))) orelse return .{ .row = null };
            return .{ .row = .{ .key = try a.decimal(allocator, row.key), .value = try a.foreignCell(allocator, row.value) } };
        },
        .query_policy => |grant| try q.setPolicy(turn, grant.peer, grant.table, grant.expected_revision, grant.allow),
        .query_start => |request| {
            var table = try s.TableReader.open(allocator, turn, try unsigned(request.id));
            defer table.deinit();
            var fields: [s.fuze.TableSchema.max_columns]s.fuze.Types.Field = undefined;
            const plan = try request.plan.native(allocator, try table.schema.schema.rowType(&fields), table.basis.head);
            const job = try q.start(turn, &table, plan);
            return .{ .query = .{ .result = job.result, .correlation = try a.decimal(allocator, job.correlation), .source = job.source } };
        },
        .query_close => |request| switch (request.reason) {
            .cancelled => try q.close(turn, request.result, .cancelled),
            .denied => try q.close(turn, request.result, .denied),
        },
        .query_completed => |text| {
            const correlation = try std.fmt.parseInt(u64, text, 10);
            const complete = try q.completed(turn, correlation);
            return .{ .manifest = .{
                .result = complete.result,
                .source = (try turn.waiting(correlation)).?.target,
                .destination = complete.destination,
                .correlation = try a.decimal(allocator, complete.correlation),
                .table = try a.decimal(allocator, complete.table),
                .policy_revision = try a.decimal(allocator, complete.policy_revision),
                .basis = complete.basis,
                .plan = complete.plan,
                .segments = try a.decimal(allocator, complete.segments),
                .bytes = try a.decimal(allocator, complete.bytes),
                .rows = try a.decimal(allocator, complete.rows),
                .chain = complete.chain,
                .schema = complete.schema,
            } };
        },
        .query_segment => |request| {
            var bytes: [q.records.segment_bytes]u8 = undefined;
            const segment = try q.completedSegment(turn, try std.fmt.parseInt(u64, request.correlation, 10), try std.fmt.parseInt(u64, request.ordinal, 10), &bytes);
            return .{ .segment = .{ .result = segment.manifest.result, .ordinal = try a.decimal(allocator, segment.manifest.ordinal), .rows = segment.manifest.rows, .bytes = segment.manifest.bytes, .digest = segment.manifest.digest, .ipc = try a.hex(allocator, segment.bytes) } };
        },
        else => unreachable,
    }
    try turn.validate();
    return .none;
}

fn remaining(slots: anytype) u32 {
    var count: u32 = 0;
    for (slots) |slot| if (slot == null) {
        count += 1;
    };
    return count;
}
