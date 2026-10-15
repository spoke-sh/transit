//! Verified finite result pages over current signed resource reads. References
//! and continuation state carry identity/coverage, never authority.
const std = @import("std");
const q = @import("root.zig");
const s = q.station;
const r = q.UnifiedRecords;
const f = q.fuze;
const t = f.Types;
const Ref = s.PublicationReference;
pub const Expected = struct {
    resource: u64,
    source: u64,
    requester: u64,
    correlation: u64,
    request: Ref,
    disclosure: ?q.protocol.Authorization.Subject = null,
    pub fn selection(self: Expected, reference: Ref, cursor: ?Cursor) q.ResultDisclosure.Selection {
        return .{ .unified = .{ .reference = reference, .resource = self.resource, .source = self.source, .requester = self.requester, .correlation = self.correlation, .request = self.request, .cursor = cursor } };
    }
    pub fn authorize(self: Expected, reference: Ref, cursor: ?Cursor, client: q.wire.AuthorizationClient) !Expected {
        var result = self;
        result.disclosure = try q.ResultDisclosure.prepare(client, self.selection(reference, cursor));
        return result;
    }
};
pub const Open = struct {
    manifest: r.Manifest,
    bundle: q.Bundle,
    pub fn outputSchema(self: Open, columns: *[q.SourceDefinition.max_columns]t.Field) !t.Type {
        return self.bundle.plan.outputSchema(columns);
    }
};
fn checkReference(reference: Ref, expected: Expected) !void {
    try reference.validate();
    inline for (.{ "resource", "source", "requester", "correlation" }) |name| try r.identity(@field(expected, name));
    try q.Bundle.checkReference(expected.request);
    if (reference.domain != .query_result or reference.resource != expected.resource or reference.record != r.manifest_record or reference.spec.format != r.manifest_format or reference.spec.length == 0 or reference.spec.length > r.Manifest.max_bytes) return error.InvalidQueryManifest;
}
fn live(reference: Ref, expected: Expected, cursor: ?Cursor, opened: Open, source: anytype) !void {
    try checkReference(reference, expected);
    const job = opened.manifest.job;
    if (job.source.pid != expected.source or job.destination != expected.requester or job.correlation != expected.correlation or !std.meta.eql(job.request, expected.request) or job.namespace() != reference.namespace) return error.QueryIdentityMismatch;
    var reader = try source.open(reference.resource);
    if (!std.meta.eql(try q.UnifiedCapture.job(&reader, job.id), job) or job.phase != .complete) return error.ResultUnavailable;
    const grant = (try q.UnifiedCapture.permitted(&reader, job)) orelse return error.QueryDenied;
    if (opened.bundle.source.resource != reference.resource or !grant.limits.permits(opened.bundle.limits)) return error.QueryDenied;
    const descriptor = try reference.publication().inspect(&reader, reference.record);
    if (descriptor.state != .published or descriptor.publisher != expected.source or !std.meta.eql(descriptor.spec, reference.spec)) return error.ResultUnavailable;
    try q.Bundle.checkPublisher(job.request, source, job.destination);
    if (opened.bundle.source.source == .table) {
        const original = (try opened.bundle.subject(expected.source, job.destination, job.request.resource)) orelse return error.QueryDenied;
        const table = opened.bundle.source.source.table;
        if (original.principal() != try grant.tablePrincipal(table)) return error.QueryDenied;
        const current = try q.ResultDisclosure.check(expected.disclosure orelse return error.QueryDenied, expected.selection(reference, cursor), table.scope.realm);
        try q.QueryAuthorization.checkTable(table, &reader, current, current.principal());
    } else {
        // A read-only composition may expose its current reader separately
        // from Table subject mediation. Document still checks the concrete
        // current-reader type; retained readers cannot pass that boundary.
        const current = if (comptime @hasDecl(@TypeOf(reader), "currentReader")) reader.currentReader() else &reader;
        try q.UnifiedSource.checkCurrent(opened.bundle.source, current, try grant.principal(opened.bundle.source));
    }
}
/// Borrowed definition/plan data belongs to allocator. The finite manifest is
/// owned by value. No source pin or current policy is cached by this handle.
pub fn open(reference: Ref, expected: Expected, source: anytype, allocator: std.mem.Allocator) !Open {
    return openAt(reference, expected, null, source, allocator);
}
fn openAt(reference: Ref, expected: Expected, cursor: ?Cursor, source: anytype, allocator: std.mem.Allocator) !Open {
    try checkReference(reference, expected);
    var manifest_bytes: [r.Manifest.max_bytes]u8 = undefined;
    const manifest = try r.Manifest.decode(try reference.read(source, &manifest_bytes));
    if (!std.meta.eql(manifest.job.request, expected.request)) return error.QueryIdentityMismatch;
    const request_bytes = try allocator.alloc(u8, manifest.job.request.spec.length);
    const bundle = try q.Bundle.decode(allocator, try manifest.job.request.read(source, request_bytes));
    const opened: Open = .{ .manifest = manifest, .bundle = bundle };
    try live(reference, expected, cursor, opened, source);
    _ = try manifest.checkpoint.bound(bundle);
    const progress = manifest.checkpoint.progress;
    if (progress.pages > bundle.limits.pages or progress.segments > bundle.limits.segments or manifest.checkpoint.bytes > bundle.limits.result_bytes or (progress.finished == .source_end and !manifest.checkpoint.cursor.done)) return error.InvalidQueryManifest;
    return opened;
}
pub const Cursor = struct {
    reference: Ref,
    ordinal: u64 = 0,
    rows: u64 = 0,
    bytes: u64 = 0,
    chain: [32]u8 = r.initialChain(),
};
pub const Page = struct {
    manifest: r.Manifest,
    basis: q.Basis,
    next: ?Cursor,
    arrow: []const u8,
    schema: t.Type,
    plan: f.LogicalQuery.Plan,
};
/// decoded must be at its final address; strings/columns belong to allocator,
/// Arrow bytes borrow output. Any error invalidates all output storage. A null
/// continuation proves complete ordered row/byte/digest coverage.
pub fn page(reference: Ref, expected: Expected, cursor: ?Cursor, source: anytype, allocator: std.mem.Allocator, workspace: []u8, output: []u8, decoded: *f.LogicalInspect.Batch) !Page {
    const opened = try openAt(reference, expected, cursor, source, allocator);
    const manifest = opened.manifest;
    var next: Cursor = cursor orelse .{ .reference = reference };
    if (!std.meta.eql(next.reference, reference) or next.ordinal >= manifest.checkpoint.progress.segments or next.rows > manifest.checkpoint.progress.rows or next.bytes > manifest.checkpoint.bytes) return error.InvalidQueryCursor;
    if (next.ordinal == 0 and (next.rows != 0 or next.bytes != 0 or !std.mem.eql(u8, &next.chain, &r.initialChain()))) return error.InvalidQueryCursor;
    var reader = try source.open(reference.resource);
    const segment = try r.Segment.decode((try reader.read(r.key('s', manifest.job.id, next.ordinal))) orelse return error.MissingResultSegment);
    if (segment.ordinal != next.ordinal or segment.row_start != next.rows or segment.reference.resource != reference.resource or segment.reference.domain != reference.domain or segment.reference.namespace != reference.namespace) return error.InvalidResultSegment;
    const descriptor = try segment.reference.publication().inspect(&reader, segment.reference.record);
    if (descriptor.publisher != expected.source or descriptor.state != .published or !std.meta.eql(descriptor.spec, segment.reference.spec)) return error.ResultUnavailable;
    const bytes = try segment.reference.read(source, output);
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    if (!std.mem.eql(u8, &digest, &segment.arrow_digest)) return error.InvalidResultDigest;
    var columns: [q.SourceDefinition.max_columns]t.Field = undefined;
    const schema = try opened.outputSchema(&columns);
    decoded.* = try f.LogicalInspect.decode(allocator, schema, bytes, segment.rows, workspace);
    errdefer decoded.deinit();
    next.ordinal = try std.math.add(u64, next.ordinal, 1);
    next.rows = try std.math.add(u64, next.rows, segment.rows);
    next.bytes = try std.math.add(u64, next.bytes, bytes.len);
    next.chain = try segment.extend(next.chain);
    if (next.rows > manifest.checkpoint.progress.rows or next.bytes > manifest.checkpoint.bytes) return error.InvalidQueryCursor;
    const complete = next.ordinal == manifest.checkpoint.progress.segments;
    if (complete) try completeCoverage(next, manifest.checkpoint.progress.rows, manifest.checkpoint.bytes, manifest.checkpoint.chain);
    // Recheck current policy, Document lifecycle, request and result disposition
    // after all reads/decoding, before the caller may disclose this page.
    try live(reference, expected, cursor, opened, source);
    return .{ .manifest = manifest, .basis = try manifest.checkpoint.basis(opened.bundle.source), .next = if (complete) null else next, .arrow = bytes, .schema = try schema.cloneInto(allocator), .plan = opened.bundle.plan };
}

fn completeCoverage(cursor: Cursor, rows: u64, bytes: u64, chain: [32]u8) !void {
    if (cursor.rows != rows or cursor.bytes != bytes or !std.mem.eql(u8, &cursor.chain, &chain)) return error.InvalidResultCoverage;
}

test "final result coverage corruption is distinct from a pending result" {
    const cursor: Cursor = .{ .reference = .{ .resource = 7, .domain = .query_result, .namespace = 19, .record = 1, .spec = .{ .format = 1, .length = 1, .digest = @splat(0) } }, .rows = 8, .bytes = 32, .chain = @splat(1) };
    try completeCoverage(cursor, 8, 32, @splat(1));
    try std.testing.expectError(error.InvalidResultCoverage, completeCoverage(cursor, 9, 32, @splat(1)));
    try std.testing.expectError(error.InvalidResultCoverage, completeCoverage(cursor, 8, 33, @splat(1)));
    try std.testing.expectError(error.InvalidResultCoverage, completeCoverage(cursor, 8, 32, @splat(2)));
}
