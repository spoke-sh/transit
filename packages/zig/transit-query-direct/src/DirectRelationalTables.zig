//! Independent retained Table sources with stable row-identity traversal.
//! Pin acquisition/release belongs to the caller, including partial failures.
const std = @import("std");
const q = @import("root.zig");
const c = q.catalog;
const f = q.fuze;
const r = f.Relational;
const e = f.RelationalExecution;
const Scan = @import("DirectTableScan.zig");
const Self = @This();
allocator: std.mem.Allocator,
client: c.DirectTableClient,
scans: [r.max_sources]?Scan = @splat(null),
declarations: []const r.Source,
cuts: [r.max_sources]r.Cut = undefined,
requests: u64 = 0,
request_limit: u64,
closed: bool = false,

pub fn open(allocator: std.mem.Allocator, client: c.DirectTableClient, snapshots: []const c.DirectTableProtocol.Snapshot, sources: []const r.Source, requests: u64, cancellation: ?*const std.atomic.Value(bool)) !Self {
    if (sources.len == 0 or sources.len > r.max_sources or snapshots.len != sources.len) return error.InvalidRelationalSources;
    var self: Self = .{ .allocator = allocator, .client = client, .declarations = sources, .request_limit = requests };
    errdefer self.deinit();
    for (snapshots, sources, 0..) |snapshot, source, i| {
        if (self.requests >= requests) return error.QueryPageBudget;
        self.scans[i] = try Scan.open(allocator, client, snapshot, requests - self.requests, cancellation);
        const scan = &self.scans[i].?;
        self.requests += scan.requests;
        const basis = scan.reader.basis;
        const object = basis.interpretation.interpretation.object;
        const schema = scan.reader.schema.schema;
        try q.DirectTableQuery.qualify(schema);
        if (source.realm != object.scope.realm or source.resource != object.scope.resource or source.catalog != object.scope.catalog or source.owner != client.connection.audience or
            !std.mem.eql(u8, &try source.schema.fingerprint(), &try schema.fingerprint())) return error.RelationalSourceChanged;
        self.cuts[i] = .{ .domain = .{ .table_partition = .{ .branch = object.branch, .object = object.object, .partition = basis.accepted.partition } }, .resource = object.scope.resource, .revision = basis.accepted.next_lsn, .commitment = try scan.fingerprint(), .schema = try schema.fingerprint() };
    }
    try self.authorize();
    return self;
}
pub fn deinit(self: *Self) void {
    for (&self.scans) |*slot| if (slot.*) |*scan| scan.deinit();
    self.* = undefined;
}
pub fn close(self: *Self) void {
    self.closed = true;
}
pub fn validate(self: *Self, bound: r.Bound) !void {
    if (self.closed) return error.QueryClosed;
    try bound.validate();
    if (bound.plan.lifetime != .interactive or bound.plan.sources.len != self.declarations.len) return error.RelationalSourceChanged;
    for (bound.plan.sources, self.declarations, bound.cuts, 0..) |source, expected, cut, i| {
        if (source.realm != expected.realm or source.resource != expected.resource or source.catalog != expected.catalog or source.owner != expected.owner or
            !std.mem.eql(u8, source.alias, expected.alias) or !std.mem.eql(u8, &try source.schema.fingerprint(), &self.cuts[i].schema) or !std.meta.eql(cut, self.cuts[i])) return error.RelationalSourceChanged;
    }
    try self.authorize();
}
fn authorize(self: *Self) !void {
    if (self.closed) return error.QueryClosed;
    if (self.requests > self.request_limit or self.request_limit - self.requests < 2) return error.QueryPageBudget;
    var checks: [r.max_sources]c.DirectTableProtocol.ReadCheck = undefined;
    for (self.scans[0..self.declarations.len], 0..) |slot, i| {
        try slot.?.checkCancellation();
        checks[i] = .{ .snapshot = slot.?.reader.basis.snapshot };
    }
    self.requests += 2;
    const response = try self.client.call(.{ .check_set = checks[0..self.declarations.len] });
    defer response.deinit();
}
pub fn next(self: *Self, source: u8, after: ?r.RowIdentity) !?e.Row {
    if (self.closed) return error.QueryClosed;
    if (source >= self.declarations.len) return error.UnknownRelationalSource;
    if (self.requests >= self.request_limit) return error.QueryPageBudget;
    const scan = &self.scans[source].?;
    scan.request_limit = std.math.add(u64, scan.requests, self.request_limit - self.requests) catch return error.QueryPageBudget;
    const before = scan.requests;
    defer self.requests += scan.requests - before;
    var row = (try scan.nextAfter(after)) orelse return null;
    defer row.deinit();
    return try e.Row.fromCells(self.allocator, scan.after.?, self.declarations[source].schema.columns, row.cells);
}
