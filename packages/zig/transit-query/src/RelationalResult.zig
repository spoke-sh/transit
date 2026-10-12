//! Complete captured results through a fresh public native snapshot. The frozen
//! request is supplied by its caller; no schema is rebound through a live name.
const std = @import("std");
const q = @import("root.zig");
const f = q.fuze;
const r = q.RelationalRecords;
const p = q.protocol;
const g = p.Growth;
const c = q.catalog;
const Self = @This();
bundle: q.RelationalBundle,
source: q.wire.SnapshotReader,
stored: r.Job,
vector: q.RelationalCaptured.Vector,
cuts: [f.Relational.max_sources]f.Relational.Cut,
progress: f.RelationalCheckpoint,
ordinal: u64 = 0,
bytes: u64 = 0,
canonical_bytes: u64,
chain: [32]u8 = r.initialChain(),
previous: ?@FieldType(f.RelationalExecution.Output, "identity") = null,
requests: u64,
request_limit: u64,
complete: bool = false,
failed: bool = false,

pub const Options = struct { owner: u64, peer: u64, resource: u64, job: u64, requests: u64 };
/// client must hold current native read grants to the result and both sources.
/// The selected profile keeps result state in the first Table owner's resource.
pub fn open(client: q.wire.ResourceReader, bundle: q.RelationalBundle, options: Options, nonce: [16]u8) !Self {
    try bundle.validate();
    if (options.requests < 2) return error.QueryPageBudget;
    if (bundle.sources[0].scope.realm != client.realm or bundle.sources[0].scope.resource != options.resource or bundle.sources[0].owner != options.owner) return error.RelationalSourceChanged;
    var self: Self = .{ .bundle = bundle, .source = try q.wire.SnapshotReader.open(client, options.resource, nonce), .stored = undefined, .vector = undefined, .cuts = undefined, .progress = undefined, .canonical_bytes = 0, .requests = 2, .request_limit = options.requests };
    errdefer {
        const rejection = client.wire.last_rejection;
        self.close() catch {};
        client.wire.last_rejection = rejection;
    }
    var reader: Reader = .{ .owner = &self, .view = self.source.view };
    self.stored = try q.RelationalCapture.job(&reader, options.job);
    if (self.stored.destination != options.peer or self.stored.request_version.pid != options.owner) return error.QueryDenied;
    if (self.stored.phase != .complete) return error.IncompleteResult;
    const reference = try bundle.reference(self.stored.request.resource, self.stored.request.namespace);
    if (!std.meta.eql(reference, self.stored.request)) return error.RelationalSourceChanged;
    // Every source policy, the job and coordinator policy are checked together.
    try self.authorize(false);
    const vector_value = (try reader.read(r.key('v', self.stored.id, 0))) orelse return error.MissingQueryProgress;
    self.vector = try q.RelationalCaptured.Vector.decode(bundle, vector_value);
    try self.vector.boundCuts(bundle, &self.cuts);
    const pages: q.RelationalState = .{ .publication = self.stored.publication(options.resource) };
    var bytes: [r.Manifest.max_bytes]u8 = undefined;
    const manifest = try r.Manifest.decode(try pages.read(&reader, self.stored.manifest, r.manifest_format, &bytes));
    if (!std.meta.eql(manifest.job, self.stored) or !manifest.vector.eql(vector_value) or manifest.checkpoint.resource != options.resource) return error.InvalidRelationalRecord;
    const descriptor = try pages.publication.inspect(&reader, self.stored.checkpoint);
    if (!std.meta.eql(descriptor.spec, manifest.checkpoint.spec)) return error.InvalidRelationalRecord;
    self.progress = try pages.checkpoint(&reader, self.stored.checkpoint, self.bound());
    if (self.progress.phase != .complete or self.progress.result_rows != self.stored.outputs) return error.IncompleteResult;
    var fields: [f.Relational.max_outputs]f.Types.Field = undefined;
    var schema_bytes: [f.Types.max_encoding_bytes]u8 = undefined;
    self.canonical_bytes = (try (try bundle.plan.outputSchema(&fields)).encode(&schema_bytes)).len;
    try self.authorize(false);
    return self;
}
fn bound(self: *const Self) f.Relational.Bound {
    return .{ .plan = self.bundle.plan, .cuts = self.cuts[0..self.vector.count] };
}
const Reader = struct {
    owner: *Self,
    view: @FieldType(q.wire.SnapshotReader, "view"),
    pub fn read(self: *Reader, key: p.Value) !?p.Value {
        var points: g.SnapshotRead.Keys = @splat(null);
        points[0] = key;
        const result = try self.owner.request(.{ .snapshot = .{ .existing = self.owner.source.snapshot.id }, .points = points });
        return if (result.points[0]) |entry| entry.value else null;
    }
};
fn request(self: *Self, query: g.SnapshotRead.Query) !g.SnapshotRead.Result {
    if (self.requests == self.request_limit) return error.QueryPageBudget;
    self.requests += 1;
    const result = try self.source.batch(query);
    try g.SnapshotRead.validateResult(result, query);
    return result;
}
fn add(selections: *[g.SnapshotRead.current_resources]?g.SnapshotRead.Current, resource: u64, key: p.Value) !void {
    var at: usize = 0;
    while (at < selections.len and selections[at] != null and selections[at].?.resource != resource) : (at += 1) {}
    if (at == selections.len) return error.InvalidRelationalSources;
    if (selections[at] == null) selections[at] = .{ .resource = resource, .keys = @splat(null) };
    var slot: usize = 0;
    while (slot < g.page_size and selections[at].?.keys[slot] != null and !selections[at].?.keys[slot].?.eql(key)) : (slot += 1) {}
    if (slot == g.page_size) return error.InvalidRelationalSources;
    selections[at].?.keys[slot] = key;
}
const Current = struct {
    value: g.SnapshotRead.CurrentResult,
    view: struct { resource: u64 },
    pub fn read(self: *Current, key: p.Value) !?p.Value {
        for (self.value.entries) |slot| if (slot) |entry| if (entry.key.eql(key)) return entry.value;
        return null;
    }
};
fn authorize(self: *Self, finish: bool) !void {
    var selections: [g.SnapshotRead.current_resources]?g.SnapshotRead.Current = @splat(null);
    const resource = self.source.view.resource;
    const policy_key = r.key('p', self.stored.destination, 0);
    const job_key = r.key('j', self.stored.id, 0);
    try add(&selections, resource, policy_key);
    try add(&selections, resource, job_key);
    // The committed coordinator policy supplies catalog identity; decode it
    // once from the leased cut, then compare its exact bytes at the final cut.
    var reader: Reader = .{ .owner = self, .view = self.source.view };
    const grant = (try q.RelationalCapture.policy(&reader, self.stored.destination)) orelse return error.QueryDenied;
    if (!grant.allow or grant.revision != self.stored.policy_revision or grant.requests != self.stored.request.resource or !std.mem.eql(u8, &grant.request, &try self.bundle.fingerprint())) return error.QueryDenied;
    for (self.bundle.sources) |source| {
        try add(&selections, source.scope.resource, c.Records.key(source.scope.catalog, 'c', 0, 0));
        try add(&selections, source.scope.resource, c.Records.key(source.scope.catalog, 'p', grant.principal, 0));
    }
    const result = try self.request(.{ .snapshot = .{ .existing = self.source.snapshot.id }, .current = selections, .finish = finish });
    for (result.current) |slot| if (slot) |value| {
        var current: Current = .{ .value = value, .view = .{ .resource = value.resource.id } };
        if (value.resource.id == resource) {
            const live = (try q.RelationalCapture.policy(&current, self.stored.destination)) orelse return error.QueryDenied;
            if (!std.meta.eql(live, grant) or !std.meta.eql(try q.RelationalCapture.job(&current, self.stored.id), self.stored)) return error.QueryDenied;
        }
        for (self.bundle.sources) |source| if (source.scope.resource == value.resource.id) {
            _ = try source.checkCurrent(&current, grant.principal);
        };
    };
}
pub fn schema(self: *Self, fields: []f.Types.Field) !f.Types.Type {
    if (self.failed or self.complete) return error.QueryClosed;
    try self.authorize(false);
    return self.bundle.plan.outputSchema(fields);
}
/// One owned scalar row. A failed/unfinished prefix remains incomplete until
/// the final null has checked counts, digest chain, canonical bytes and rights.
pub fn next(self: *Self) !?f.RelationalExecution.Output {
    if (self.failed) return error.FailedRelationalQuery;
    if (self.complete) return null;
    errdefer self.failed = true;
    try self.authorize(false);
    if (self.ordinal == self.stored.outputs) {
        if (self.bytes != self.stored.output_bytes or self.canonical_bytes != self.progress.result_bytes or !std.mem.eql(u8, &self.chain, &self.stored.chain)) return error.IncompleteResult;
        try self.authorize(true);
        self.complete = true;
        return null;
    }
    var reader: Reader = .{ .owner = self, .view = self.source.view };
    const record = try r.Output.decode((try reader.read(r.key('o', self.stored.id, self.ordinal))) orelse return error.IncompleteResult);
    if (record.ordinal != self.ordinal or record.reference.resource != self.source.view.resource or record.reference.namespace != self.stored.namespace() or record.reference.record >= self.stored.next_record) return error.InvalidRelationalRecord;
    const pages: q.RelationalState = .{ .publication = self.stored.publication(self.source.view.resource) };
    const descriptor = try pages.publication.inspect(&reader, record.reference.record);
    if (!std.meta.eql(descriptor.spec, record.reference.spec)) return error.InvalidRelationalRecord;
    var bytes: [f.RelationalOutput.max_bytes]u8 = undefined;
    const output = try f.RelationalOutput.decode(self.bound(), try pages.read(&reader, record.reference.record, r.output_format, &bytes));
    if (output.ordinal != self.ordinal) return error.InvalidRelationalRecord;
    if (self.previous) |previous| switch (output.row.identity) {
        .group => |key| if (previous != .group or key.order(previous.group) != .gt) return error.InvalidRelationalGroupOrder,
        .pair => |pair| {
            if (previous != .pair) return error.InvalidRelationalSourceOrder;
            const order = f.RelationalExecution.identityOrder(pair.left, previous.pair.left);
            if (order == .lt or (order == .eq and (pair.right == null or previous.pair.right == null or f.RelationalExecution.identityOrder(pair.right.?, previous.pair.right.?) != .gt))) return error.InvalidRelationalSourceOrder;
        },
    };
    const next_bytes = try std.math.add(u64, self.bytes, record.reference.spec.length);
    var canonical = self.canonical_bytes;
    for (output.row.cells[0..output.row.len]) |cell| canonical = try std.math.add(u64, canonical, 5 + @as(u64, if (cell == .null) 0 else 8));
    if (next_bytes > self.stored.output_bytes or canonical > self.progress.result_bytes) return error.IncompleteResult;
    try self.authorize(false);
    self.bytes = next_bytes;
    self.canonical_bytes = canonical;
    self.previous = output.row.identity;
    self.chain = try record.extend(self.chain);
    self.ordinal += 1;
    return output.row;
}
pub fn close(self: *Self) !void {
    try self.source.close();
}
