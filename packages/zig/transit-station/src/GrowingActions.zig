//! Foreign growing turns use the same native state/Table/message operations.
//! All results borrow the caller's arena; no pointer escapes the ABI response.
const std = @import("std");
const s = @import("transit_station");
const p = s.protocol;
const a = @import("Actions.zig");
const q = s.GrowingQuery;
pub const Plan = struct {
    projection: @FieldType(a.Plan, "projection") = .both,
    limit: ?[]const u8 = null,
    aggregate: @FieldType(a.Plan, "aggregate") = .rows,
    predicate: @FieldType(a.Plan, "predicate") = .all,
    fn native(self: Plan) !s.fuze.Stream.Plan {
        const shared = try (a.Plan{ .projection = self.projection, .aggregate = self.aggregate, .predicate = self.predicate }).native();
        return .{ .projection = shared.projection, .aggregate = shared.aggregate, .predicate = shared.predicate, .limit = if (self.limit) |limit| try std.fmt.parseInt(u64, limit, 10) else null };
    }
};
pub const Manifest = struct {
    result: u64,
    source: u64,
    destination: u64,
    correlation: []const u8,
    table: u32,
    policy_revision: []const u8,
    basis: s.fuze.model.Basis,
    plan: [32]u8,
    segments: []const u8,
    bytes: []const u8,
    rows: []const u8,
    chain: [32]u8,
    schema: [32]u8,
};
pub const Action = union(enum) {
    get: p.Value,
    put: @FieldType(a.Action, "put"),
    delete: p.Value,
    cast: @FieldType(a.Action, "cast"),
    call: struct { pid: u64, value: p.Value, deadline_ms: ?u64 = null, observer: ?u64 = null },
    reply: p.Value,
    cancel: []const u8,
    effect: p.Value,
    table_create: @FieldType(a.Action, "table_create"),
    table_get: @FieldType(a.Action, "table_get"),
    table_write: @FieldType(a.Action, "table_write"),
    table_delete: @FieldType(a.Action, "table_delete"),
    page: ?[]const u8,
    table_page: struct { id: u32, cursor: ?[]const u8 = null, version: ?p.Growth.ReadVersionId = null },
    retain: void,
    release: p.Growth.ReadVersionId,
    version_get: struct { id: p.Growth.ReadVersionId, key: p.Value },
    version_page: struct { id: p.Growth.ReadVersionId, cursor: ?[]const u8 = null },
    query_policy: @FieldType(a.Action, "query_policy"),
    query_start: struct { id: u32, plan: Plan = .{} },
    query_close: struct { result: u64, reason: enum { cancelled, denied } },
    query_completed: []const u8,
    query_segment: struct { correlation: []const u8, ordinal: []const u8 },

    pub fn requiresQuery(self: Action) bool {
        return switch (self) {
            .query_policy, .query_start, .query_close, .query_completed, .query_segment => true,
            else => false,
        };
    }
};
pub const Result = union(enum) {
    none,
    value: ?p.Value,
    correlation: []const u8,
    cancelled: bool,
    row: ?a.Row,
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
pub fn apply(allocator: std.mem.Allocator, turn: *s.GrowingTurn, action: Action) !Result {
    if (try a.basic(Result, allocator, turn, action)) |result| return result;
    switch (action) {
        .page => |cursor| return page(allocator, turn, cursor),
        .table_page => |request| {
            if (request.version) |id| {
                var source = try turn.openVersion(id);
                return tablePage(allocator, &source, request.id, request.cursor);
            }
            return tablePage(allocator, turn, request.id, request.cursor);
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
        .query_policy => |grant| try q.setPolicy(turn, grant.peer, grant.table, grant.expected_revision, grant.allow),
        .query_start => |request| {
            const job = try q.start(turn, try s.Table.open(turn, request.id), try request.plan.native());
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
                .table = complete.table,
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
