//! Authorized complete maintained revisions and atomic delta transactions.
//! Partial delivery never advances a resumable consumer position.
const std = @import("std");
const q = @import("root.zig");
const f = q.fuze;
const p = q.protocol;
const g = p.Growth;
const r = q.RelationalMaintenanceRecords;
const finite = q.RelationalRecords;
const Ref = q.station.PublicationReference;
const Self = @This();
pub const Mode = union(enum) { result, delta: ?Ref };
pub const Options = struct {
    owner: u64,
    resource: u64,
    identity: r.Identity,
    revision: ?u64 = null,
    mode: Mode = .result,
    requests: u64,
    cancellation: ?*const std.atomic.Value(bool) = null,
    pub fn selection(self: Options, bundle: q.RelationalBundle) !q.ResultDisclosure.Selection {
        return .{ .maintained = .{ .request = try bundle.fingerprint(), .owner = self.owner, .resource = self.resource, .identity = self.identity, .revision = self.revision, .mode = self.mode, .requests = self.requests } };
    }
};
pub const Position = struct {
    version: u8,
    definition: g.Definition,
    owner: u64,
    identity: r.Identity,
    id: u64,
    revision: u64,
    reference: Ref,
    request: [32]u8,
    pub fn validate(self: Position) !void {
        if (self.version != 1 or self.definition != g.current_definition) return error.IncompatibleDefinition;
        try self.identity.validate();
        try q.UnifiedRecords.identity(self.owner);
        try q.UnifiedRecords.identity(self.id);
        try self.reference.validate();
        if (self.revision == 0 or self.reference.domain != .query_result or self.reference.namespace != ((@as(u64, 1) << 63) | self.id) or self.reference.spec.format != r.revision_format or self.reference.spec.length > r.Manifest.max_bytes) return error.InvalidMaintainedRecord;
    }
    /// The caller signs this next-read selection with its current credential.
    /// A saved position never carries authority or changes the original bundle.
    pub fn nextOptions(self: Position, requests: u64, cancellation: ?*const std.atomic.Value(bool)) !Options {
        try self.validate();
        const revision = std.math.add(u64, self.revision, 1) catch return error.MaintainedRevisionExhausted;
        return .{ .owner = self.owner, .resource = self.reference.resource, .identity = self.identity, .revision = revision, .mode = .{ .delta = self.reference }, .requests = requests, .cancellation = cancellation };
    }
};
pub const Event = union(enum) { row: f.RelationalExecution.Output, delta: f.RelationalDelta };
bundle: q.RelationalBundle,
source: q.wire.SnapshotReader,
options: Options,
disclosure: p.Authorization.Subject,
stored: r.Head,
reference: Ref,
manifest: r.Manifest,
previous: ?r.Manifest = null,
cuts: [f.Relational.max_sources]f.Relational.Cut = undefined,
old_cuts: [f.Relational.max_sources]f.Relational.Cut = undefined,
progress: f.RelationalCheckpoint,
ordinal: u64 = 0,
bytes: u64 = 0,
canonical_bytes: u64 = 0,
chain: [32]u8,
last: ?@FieldType(f.RelationalExecution.Output, "identity") = null,
requests: u64 = 2,
complete: bool = false,
failed: bool = false,
closed: bool = false,

pub fn open(client: q.wire.ResourceReader, bundle: q.RelationalBundle, options: Options, disclosure: p.Authorization.Subject, nonce: [16]u8) !Self {
    try bundle.validate();
    try options.identity.validate();
    if (bundle.plan.lifetime != .maintained or bundle.sources[0].scope.realm != client.realm) return error.RelationalSourceChanged;
    if (options.requests < 2) return error.QueryPageBudget;
    if (options.cancellation) |flag| if (flag.load(.acquire)) return error.Cancelled;
    const subject = try q.ResultDisclosure.check(disclosure, try options.selection(bundle), client.realm);
    var self: Self = .{ .bundle = bundle, .source = try q.wire.SnapshotReader.open(client, options.resource, nonce), .options = options, .disclosure = subject, .stored = undefined, .reference = undefined, .manifest = undefined, .progress = undefined, .chain = if (options.mode == .result) finite.initialChain() else r.initialDeltaChain() };
    errdefer {
        const rejection = client.wire.last_rejection;
        self.close() catch {};
        client.wire.last_rejection = rejection;
    }
    var reader: Reader = .{ .owner = &self, .view = self.source.view };
    self.stored = try q.RelationalMaintenance.head(&reader, options.identity);
    if (self.stored.request_version.pid != options.owner) return error.QueryDenied;
    if (self.stored.phase == .retired) return error.MaintainedResetRequired;
    const request_ref = try bundle.reference(self.stored.request.resource, self.stored.request.namespace);
    if (!std.meta.eql(request_ref, self.stored.request)) return error.RelationalSourceChanged;
    const revision = options.revision orelse self.stored.revision;
    if (revision == 0 or revision > self.stored.revision) return error.MaintainedRevisionPending;
    try self.authorize(false);
    self.reference = try Ref.decode((try reader.read(r.key('r', self.stored.id, revision, 0))) orelse return error.MaintainedResetRequired);
    self.manifest = try self.readManifest(self.reference, revision);
    try self.manifest.vector.boundCuts(bundle, &self.cuts);
    if (self.manifest.previous) |previous| self.previous = try self.readManifest(previous, revision - 1);
    if (self.previous) |previous| {
        try previous.vector.boundCuts(bundle, &self.old_cuts);
        if (self.manifest.work.old_cursor != previous.work.outputs) return error.IncompleteResult;
    }
    if (options.mode == .delta and !std.meta.eql(options.mode.delta, self.manifest.previous)) return error.MaintainedResetRequired;
    var bytes: [f.RelationalCheckpoint.max_bytes]u8 = undefined;
    self.progress = try f.RelationalCheckpoint.decode(self.bound(), try q.RelationalMaintenance.readBody(self.manifest.checkpoint, &reader, &bytes));
    if (self.progress.phase != .complete or self.progress.result_rows != self.manifest.work.outputs) return error.IncompleteResult;
    var fields: [f.Relational.max_outputs]f.Types.Field = undefined;
    var schema_bytes: [f.Types.max_encoding_bytes]u8 = undefined;
    self.canonical_bytes = (try (try bundle.plan.outputSchema(&fields)).encode(&schema_bytes)).len;
    try self.authorize(false);
    return self;
}
/// Resume exactly the next complete transaction. Pending means no successor is
/// visible yet; reset-required never silently chooses a newer starting point.
pub fn openNext(client: q.wire.ResourceReader, bundle: q.RelationalBundle, position: Position, disclosure: p.Authorization.Subject, nonce: [16]u8, requests: u64, cancellation: ?*const std.atomic.Value(bool)) !Self {
    try position.validate();
    if (!std.mem.eql(u8, &position.request, &try bundle.fingerprint())) return error.RelationalSourceChanged;
    var self = try open(client, bundle, try position.nextOptions(requests, cancellation), disclosure, nonce);
    errdefer self.close() catch {};
    if (self.stored.id != position.id) return error.MaintainedResetRequired;
    return self;
}
fn readManifest(self: *Self, reference: Ref, revision: u64) !r.Manifest {
    if (reference.resource != self.options.resource or reference.domain != .query_result or reference.namespace != self.stored.namespace() or reference.spec.format != r.revision_format or reference.record >= self.stored.next_record) return error.InvalidMaintainedRecord;
    var reader: Reader = .{ .owner = self, .view = self.source.view };
    var bytes: [r.Manifest.max_bytes]u8 = undefined;
    const saved = try r.Manifest.decode(self.bundle, try q.RelationalMaintenance.readBody(reference, &reader, &bytes));
    if (saved.id != self.stored.id or saved.work.revision != revision or saved.work.manifest != reference.record or saved.checkpoint.resource != self.options.resource or saved.work.state_bytes > self.stored.state_bytes) return error.InvalidMaintainedRecord;
    if (revision == self.stored.revision and (saved.work.manifest != self.stored.manifest or saved.work.next_record != self.stored.next_record or saved.work.state_bytes != self.stored.state_bytes)) return error.InvalidMaintainedRecord;
    return saved;
}
fn bound(self: *const Self) f.Relational.Bound {
    return .{ .plan = self.bundle.plan, .cuts = self.cuts[0..self.bundle.sources.len] };
}
fn oldBound(self: *const Self) ?f.Relational.Bound {
    return if (self.previous != null) .{ .plan = self.bundle.plan, .cuts = self.old_cuts[0..self.bundle.sources.len] } else null;
}
const Reader = struct {
    owner: *Self,
    view: @FieldType(q.wire.SnapshotReader, "view"),
    pub fn read(self: *Reader, key: p.Value) !?p.Value {
        var points: g.SnapshotRead.Keys = @splat(null);
        points[0] = key;
        const value = try self.owner.request(.{ .snapshot = .{ .existing = self.owner.source.snapshot.id }, .points = points });
        return if (value.points[0]) |entry| entry.value else null;
    }
};
fn request(self: *Self, query: g.SnapshotRead.Query) !g.SnapshotRead.Result {
    if (self.options.cancellation) |flag| if (flag.load(.acquire)) return error.Cancelled;
    if (self.requests == self.options.requests) return error.QueryPageBudget;
    self.requests += 1;
    const value = try self.source.batch(query);
    try g.SnapshotRead.validateResult(value, query);
    return value;
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
    if (self.closed) return error.QueryClosed;
    var selections: [g.SnapshotRead.current_resources]?g.SnapshotRead.Current = @splat(null);
    try add(&selections, self.options.resource, finite.key('p', self.stored.peer, 0));
    try add(&selections, self.options.resource, self.stored.identity().address());
    var reader: Reader = .{ .owner = self, .view = self.source.view };
    const grant = (try q.RelationalCapture.policy(&reader, self.stored.peer)) orelse return error.QueryDenied;
    if (!grant.allow or grant.revision != self.stored.policy_revision or grant.requests != self.stored.request.resource or !std.mem.eql(u8, &grant.request, &try self.bundle.fingerprint())) return error.QueryDenied;
    const original = try self.bundle.subject(self.stored.request_version.pid, self.stored.peer, self.stored.request.resource);
    if (original.principal() != grant.principal) return error.QueryDenied;
    var authority = q.QueryAuthorization.readerContext(self.source.client, self.disclosure, null);
    authority.budget = .{ .used = &self.requests, .limit = self.options.requests };
    // Immutable acquisition evidence survives direct lease closure. Source
    // permissions remain current and are independent of progress storage.
    var required: ?p.Authorization.Guard = null;
    for (self.bundle.sources, self.bundle.plan.sources, 0..) |source, declared, i| {
        if (try self.bundle.sourceOrdinal(i) != i) continue;
        var storage: [16384]u8 = undefined;
        var fixed: std.heap.FixedBufferAllocator = .init(&storage);
        const slot: q.CapturedTablePin.Slot = .{ .job = self.stored.id, .source = @intCast(i) };
        const pin = (try q.CapturedTablePin.observe(fixed.allocator(), &reader, slot, self.options.owner)) orelse return error.IncompleteSource;
        if (!std.meta.eql(pin.grant, self.bundle.retention[i])) return error.RelationalSourceChanged;
        const retained = try q.CapturedTablePin.source(fixed.allocator(), &reader, slot, self.options.owner);
        _ = try source.basis(retained, declared.schema);
        const guard = try retained.authority.guard(self.disclosure);
        required = if (required) |previous| try previous.merge(guard) else guard;
    }
    const value = try self.request(.{ .snapshot = .{ .existing = self.source.snapshot.id }, .current = selections, .finish = finish });
    for (value.current) |slot| if (slot) |current_result| {
        var current: Current = .{ .value = current_result, .view = .{ .resource = current_result.resource.id } };
        if (current_result.resource.id == self.options.resource) {
            const policy = (try q.RelationalCapture.policy(&current, self.stored.peer)) orelse return error.QueryDenied;
            if (!std.meta.eql(policy, grant)) return error.QueryDenied;
            const live = try q.RelationalMaintenance.head(&current, self.stored.identity());
            // New complete revisions do not invalidate a retained observation.
            // Retirement does. A different admission never substitutes for it.
            if (live.phase == .retired) return error.MaintainedResetRequired;
            if (live.id != self.stored.id or live.policy_revision != self.stored.policy_revision or !std.meta.eql(live.request, self.stored.request) or !std.meta.eql(live.request_version, self.stored.request_version) or live.revision < self.stored.revision) return error.QueryDenied;
        }
    };
    _ = try authority.requireAuthorization(required orelse return error.QueryDenied);
}
fn order(self: *Self, identity: @FieldType(f.RelationalExecution.Output, "identity")) !void {
    if (self.last) |previous| if (try f.RelationalDelta.identityOrder(previous, identity) != .lt) return error.InvalidRelationalSourceOrder;
}
/// Null establishes complete row/delta coverage and current rights. Only then
/// may checkpoint() be saved atomically with installing the consumer relation.
pub fn next(self: *Self) !?Event {
    if (self.failed) return error.FailedRelationalQuery;
    if (self.closed) return error.QueryClosed;
    if (self.complete) return null;
    errdefer self.failed = true;
    try self.authorize(false);
    const work = self.manifest.work;
    const count = if (self.options.mode == .result) work.outputs else work.deltas;
    if (self.ordinal == count) {
        const bytes = if (self.options.mode == .result) work.output_bytes else work.delta_bytes;
        const chain = if (self.options.mode == .result) work.chain else work.delta_chain;
        if (self.bytes != bytes or !std.mem.eql(u8, &self.chain, &chain)) return error.IncompleteResult;
        if (self.options.mode == .result and self.canonical_bytes != self.progress.result_bytes) return error.IncompleteResult;
        try self.authorize(true);
        self.complete = true;
        return null;
    }
    var reader: Reader = .{ .owner = self, .view = self.source.view };
    const key = r.key(if (self.options.mode == .result) 'o' else 'd', self.stored.id, work.revision, self.ordinal);
    const value = (try reader.read(key)) orelse return error.MissingResultSegment;
    const ordinal, const reference, const chain = if (self.options.mode == .result) blk: {
        const record = try finite.Output.decode(value);
        break :blk .{ record.ordinal, record.reference, try record.extend(self.chain) };
    } else blk: {
        const record = try r.Delta.decode(value);
        break :blk .{ record.ordinal, record.reference, try record.extend(self.chain) };
    };
    if (ordinal != self.ordinal or reference.resource != self.options.resource or reference.namespace != self.stored.namespace() or reference.record >= work.manifest or (self.manifest.previous != null and reference.record <= self.manifest.previous.?.record)) return error.InvalidMaintainedRecord;
    var bytes: [f.RelationalDelta.max_bytes]u8 = undefined;
    const body = try q.RelationalMaintenance.readBody(reference, &reader, &bytes);
    var event: Event = undefined;
    var identity: @FieldType(f.RelationalExecution.Output, "identity") = undefined;
    var canonical = self.canonical_bytes;
    if (self.options.mode == .result) {
        const output = try f.RelationalOutput.decode(self.bound(), body);
        if (output.ordinal != ordinal) return error.InvalidMaintainedRecord;
        identity = output.row.identity;
        for (output.row.cells[0..output.row.len]) |cell| canonical = try std.math.add(u64, canonical, 5 + @as(u64, if (cell == .null) 0 else 8));
        if (canonical > self.progress.result_bytes) return error.IncompleteResult;
        event = .{ .row = output.row };
    } else {
        const delta = try f.RelationalDelta.decode(self.oldBound(), self.bound(), body);
        if (delta.ordinal != ordinal) return error.InvalidMaintainedRecord;
        identity = if (delta.before) |row| row.row.identity else delta.after.?.row.identity;
        event = .{ .delta = delta };
    }
    try self.order(identity);
    const size = try std.math.add(u64, self.bytes, reference.spec.length);
    if (size > if (self.options.mode == .result) work.output_bytes else work.delta_bytes) return error.IncompleteResult;
    try self.authorize(false);
    self.ordinal += 1;
    self.bytes = size;
    self.canonical_bytes = canonical;
    self.chain = chain;
    self.last = identity;
    return event;
}
/// Recheck this retained revision's current disclosure rights without reading
/// output or advancing a consumer checkpoint. Composed inspection shares the
/// same request budget and must check again before disclosing its result.
pub fn check(self: *Self) !void {
    if (self.failed or self.complete or self.closed or self.source.closed) return error.QueryClosed;
    try self.authorize(false);
}
/// Observe freshness for this exact complete revision without waking maintenance.
/// Output/delta coverage remains incomplete until next() reaches its checked end.
pub fn freshness(self: *Self, clients: []const q.catalog.DirectTableClient) !q.RelationalFreshness {
    try self.check();
    const result = try q.RelationalFreshness.maintained(self.bundle, self.manifest.vector, clients, self.disclosure);
    try self.check();
    return result;
}
pub fn checkpoint(self: *const Self) !Position {
    if (!self.complete or self.failed) return error.IncompleteResult;
    const position: Position = .{ .version = 1, .definition = g.current_definition, .owner = self.options.owner, .identity = self.stored.identity(), .id = self.stored.id, .revision = self.manifest.work.revision, .reference = self.reference, .request = try self.bundle.fingerprint() };
    try position.validate();
    return position;
}
pub fn close(self: *Self) !void {
    try self.source.close();
    self.closed = true;
}
