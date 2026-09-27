//! Verified finite result pages over current signed resource reads. References
//! and continuation state carry identity/coverage, never authority.
const std = @import("std");
const q = @import("root.zig");
const s = q.station;
const r = q.UnifiedRecords;
const m = q.fuze.Unified;
const Ref = s.PublicationReference;
pub const Expected = struct {
    resource: u64,
    source: u64,
    requester: u64,
    correlation: u64,
    request: Ref,
};
pub const Open = struct {
    manifest: r.Manifest,
    bundle: q.Bundle,
    pub fn outputSchema(self: Open, columns: *[m.max_columns]m.Column) !m.Schema {
        if (self.bundle.plan.aggregate != .rows) {
            columns[0] = .{ .name = try m.Name.init(@tagName(self.bundle.plan.aggregate)), .type = if (self.bundle.plan.aggregate == .count) .uint64 else .int64 };
            return .{ .columns = columns[0..1] };
        }
        var input: [m.max_columns]m.Column = undefined;
        const schema = try self.bundle.source.schema(&input);
        for (self.bundle.plan.projection, 0..) |index, offset| columns[offset] = try schema.column(index);
        return .{ .columns = columns[0..self.bundle.plan.projection.len] };
    }
};
fn checkReference(reference: Ref, expected: Expected) !void {
    try reference.validate();
    inline for (.{ "resource", "source", "requester", "correlation" }) |name| try r.identity(@field(expected, name));
    try q.Bundle.checkReference(expected.request);
    if (reference.resource != expected.resource or reference.record != r.manifest_record or reference.spec.format != r.manifest_format or reference.spec.length == 0 or reference.spec.length > r.Manifest.max_bytes) return error.InvalidQueryManifest;
}
fn live(reference: Ref, expected: Expected, opened: Open, source: anytype) !void {
    try checkReference(reference, expected);
    const job = opened.manifest.job;
    if (job.source.pid != expected.source or job.destination != expected.requester or job.correlation != expected.correlation or !std.meta.eql(job.request, expected.request) or job.namespace() != reference.namespace) return error.QueryIdentityMismatch;
    var reader = try source.open(reference.resource);
    if (!std.meta.eql(try q.UnifiedCapture.job(&reader, job.id), job) or job.phase != .complete) return error.ResultUnavailable;
    const grant = (try q.UnifiedCapture.permitted(&reader, job)) orelse return error.QueryDenied;
    if (opened.bundle.source.resource != reference.resource or !std.mem.eql(u8, &grant.declaration, &try q.Bundle.declaration(opened.bundle.source)) or !grant.limits.permits(opened.bundle.limits)) return error.QueryDenied;
    try q.UnifiedSource.checkCurrent(opened.bundle.source, &reader);
    const descriptor = try reference.publication().inspect(&reader, reference.record);
    if (descriptor.state != .published or descriptor.publisher != expected.source or !std.meta.eql(descriptor.spec, reference.spec)) return error.ResultUnavailable;
    try q.Bundle.checkPublisher(job.request, source, job.destination);
}
/// Borrowed definition/plan data belongs to allocator. The finite manifest is
/// owned by value. No source pin or current policy is cached by this handle.
pub fn open(reference: Ref, expected: Expected, source: anytype, allocator: std.mem.Allocator) !Open {
    try checkReference(reference, expected);
    var manifest_bytes: [r.Manifest.max_bytes]u8 = undefined;
    const manifest = try r.Manifest.decode(try reference.read(source, &manifest_bytes));
    if (!std.meta.eql(manifest.job.request, expected.request)) return error.QueryIdentityMismatch;
    const request_bytes = try allocator.alloc(u8, manifest.job.request.spec.length);
    const bundle = try q.Bundle.decode(allocator, try manifest.job.request.read(source, request_bytes));
    const opened: Open = .{ .manifest = manifest, .bundle = bundle };
    try live(reference, expected, opened, source);
    var columns: [m.max_columns]m.Column = undefined;
    const bound = try bundle.plan.bind(try q.UnifiedSource.basis(bundle.source, manifest.checkpoint.progress.basis.revision), try bundle.source.schema(&columns));
    try manifest.checkpoint.progress.validate(bound);
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
    next: ?Cursor,
    arrow: []const u8,
    schema: m.Schema,
};
/// decoded must be at its final address; strings/columns belong to allocator,
/// Arrow bytes borrow output. Any error invalidates all output storage. A null
/// continuation proves complete ordered row/byte/digest coverage.
pub fn page(reference: Ref, expected: Expected, cursor: ?Cursor, source: anytype, allocator: std.mem.Allocator, workspace: []u8, output: []u8, decoded: *m.Inspect.Batch) !Page {
    const opened = try open(reference, expected, source, allocator);
    const manifest = opened.manifest;
    var next: Cursor = cursor orelse .{ .reference = reference };
    if (!std.meta.eql(next.reference, reference) or next.ordinal >= manifest.checkpoint.progress.segments or next.rows > manifest.checkpoint.progress.rows or next.bytes > manifest.checkpoint.bytes) return error.InvalidQueryCursor;
    if (next.ordinal == 0 and (next.rows != 0 or next.bytes != 0 or !std.mem.eql(u8, &next.chain, &r.initialChain()))) return error.InvalidQueryCursor;
    var reader = try source.open(reference.resource);
    const segment = try r.Segment.decode((try reader.read(r.key('s', manifest.job.id, next.ordinal))) orelse return error.MissingResultSegment);
    if (segment.ordinal != next.ordinal or segment.row_start != next.rows or segment.reference.resource != reference.resource or segment.reference.namespace != reference.namespace) return error.InvalidResultSegment;
    const descriptor = try segment.reference.publication().inspect(&reader, segment.reference.record);
    if (descriptor.publisher != expected.source or descriptor.state != .published or !std.meta.eql(descriptor.spec, segment.reference.spec)) return error.ResultUnavailable;
    const bytes = try segment.reference.read(source, output);
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    if (!std.mem.eql(u8, &digest, &segment.arrow_digest)) return error.InvalidResultDigest;
    var columns: [m.max_columns]m.Column = undefined;
    const schema = try opened.outputSchema(&columns);
    try m.Inspect.decode(schema, bytes, segment.rows, workspace, allocator, decoded);
    next.ordinal = try std.math.add(u64, next.ordinal, 1);
    next.rows = try std.math.add(u64, next.rows, segment.rows);
    next.bytes = try std.math.add(u64, next.bytes, bytes.len);
    next.chain = try segment.extend(next.chain);
    if (next.rows > manifest.checkpoint.progress.rows or next.bytes > manifest.checkpoint.bytes) return error.InvalidQueryCursor;
    const complete = next.ordinal == manifest.checkpoint.progress.segments;
    if (complete and (next.rows != manifest.checkpoint.progress.rows or next.bytes != manifest.checkpoint.bytes or !std.mem.eql(u8, &next.chain, &manifest.checkpoint.chain))) return error.IncompleteResult;
    // Recheck current policy, Document lifecycle, request and result disposition
    // after all reads/decoding, before the caller may disclose this page.
    try live(reference, expected, opened, source);
    return .{ .manifest = manifest, .next = if (complete) null else next, .arrow = bytes, .schema = .{ .columns = try allocator.dupe(m.Column, schema.columns) } };
}
