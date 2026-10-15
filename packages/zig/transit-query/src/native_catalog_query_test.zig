const std = @import("std");
const e = std.testing;
const q = @import("transit_query");
const f = q.fuze;
const c = q.catalog;
const s = q.station;
const r = q.UnifiedRecords;
const Store = q.testing.Store;
const config: c.TableCatalogRecords.Configuration = .{ .scope = .{ .realm = 1, .resource = 7, .catalog = 9 }, .owner = 3, .administrator = 17, .database_name = c.TableAuthority.Name.init("test") catch unreachable, .authority = c.testing.Authority.profile, .table_limits = .{ .record_bytes = f.TableRow.max_bytes, .staging_bytes = f.TableRow.max_bytes * 2, .staging_records = 2 } };
const catalog: c.TableCatalog = .{ .configuration = config };
const limits: q.Bundle.Limits = .{ .pages = 1000, .segments = 1000, .result_bytes = 1048576 };
const Access = struct {
    data: *Store,
    requests: *Store,
    pub fn open(self: Access, resource: u64) !s.Turn {
        const store = if (resource == self.data.resource) self.data else if (resource == self.requests.resource) self.requests else return error.AccessDenied;
        if (store.denied) return error.AccessDenied;
        return store.capture();
    }
};
fn turn(store: *Store) !s.Turn {
    var result = try store.capture();
    result.delivery.input.origin = .{ .external = .{ .principal = 17, .policy_revision = 1 } };
    return result;
}
fn message(store: *Store, peer: u64, frame: s.Frame) !s.Turn {
    var result = try store.capture();
    result.delivery.input.origin = .{ .process = .{ .pid = peer, .turn = 1, .output = 0 } };
    result.delivery.input.value = try frame.encode();
    return result;
}
fn ddl(store: *Store, request: c.TableDdlRequest) !c.TableCatalog.Outcome {
    for (0..4000) |_| {
        var next = try turn(store);
        const result = try catalog.step(e.allocator, &next, request);
        try store.commit(next);
        if (result.terminal()) return result;
    }
    return error.UnfinishedTestDdl;
}
fn create(store: *Store, object: u64, operation: u64, sql: []const u8) !q.TableSource.Owned {
    var statement = try f.TableDdl.compile(e.allocator, sql, null, null);
    defer statement.deinit();
    const command = statement.statement.create;
    const name = try c.TableMetadata.Name.init(command.name);
    const outcome = try ddl(store, .{ .principal = 17, .operation = operation, .object = object, .expected_revision = 0, .name = name, .action = .{ .create = .{ .schema = try command.bind(object) } } });
    try e.expectEqual(.applied, outcome.operation.state);
    var reader = try turn(store);
    var found = (try catalog.lookup(e.allocator, &reader, 17, name)).?;
    defer found.deinit();
    return q.TableSource.from(e.allocator, config, found);
}
fn mutate(store: *Store, declaration: q.TableSource, operation: u64, sql: []const u8) !void {
    var reader = try turn(store);
    var found = try catalog.readDefinition(e.allocator, &reader, 17, declaration.object, declaration.metadata);
    defer found.deinit();
    var compiled = try f.TableDml.compile(e.allocator, sql, found.metadata.name.slice(), found.schema.schema, null);
    defer compiled.deinit();
    for (0..4000) |_| {
        var next = try turn(store);
        const result = try catalog.mutate(e.allocator, &next, .{ .principal = 17, .operation = operation, .metadata = declaration.metadata, .plan = compiled.plan });
        try store.commit(next);
        if (result.state != .building) {
            try e.expectEqual(.applied, result.state);
            return;
        }
    }
    return error.UnfinishedTestDml;
}
fn upload(store: *Store, bundle: q.Bundle, namespace: u64) !s.PublicationReference {
    var buffer: [q.Bundle.max_bytes]u8 = undefined;
    const bytes = try bundle.encode(&buffer);
    const reference = try bundle.reference(store.resource, namespace);
    for (0..1000) |_| {
        var next = try store.capture();
        const done = try s.PublicationUpload.step(&next, .{ .domain = .query_request, .namespace = namespace, .identity_key = r.key('u', namespace, 0), .identity = try reference.encode(), .limits = .{ .record_bytes = q.Bundle.max_bytes, .staging_bytes = q.Bundle.max_bytes, .staging_records = 1 }, .records = &.{.{ .id = 1, .spec = reference.spec, .bytes = bytes }} });
        try store.commit(next);
        if (done) return reference;
    }
    return error.UnfinishedTestUpload;
}
fn admit(store: *Store, requests: *Store, bundle: q.Bundle, identity: u64) !r.Job {
    const reference = try upload(requests, bundle, identity);
    var next = try message(store, requests.pid, .{ .kind = .call, .correlation = identity, .payload = try reference.encode() });
    var arena: std.heap.ArenaAllocator = .init(e.allocator);
    defer arena.deinit();
    const result = try q.UnifiedCapture.start(&next, reference, Access{ .data = store, .requests = requests }, arena.allocator());
    try store.commit(next);
    return result;
}
fn finish(store: *Store, requests: *Store, job: r.Job, workspace: []u8) !void {
    const cancel = f.execution.Cancellation.init(false);
    for (0..5000) |_| {
        var current = try store.capture();
        const stored = try q.UnifiedCapture.job(&current, job.id);
        const continuation: r.Continuation = .{ .job = job.id, .input = stored.continuation };
        var next = try message(store, store.pid, .{ .kind = .cast, .payload = try continuation.encode() });
        var arena: std.heap.ArenaAllocator = .init(e.allocator);
        defer arena.deinit();
        const step = try q.UnifiedCapture.advance(&next, continuation, Access{ .data = store, .requests = requests }, arena.allocator(), workspace, &cancel);
        // A discarded proposal must recompute identically from committed state.
        var retry = try message(store, store.pid, .{ .kind = .cast, .payload = try continuation.encode() });
        var second: std.heap.ArenaAllocator = .init(e.allocator);
        defer second.deinit();
        const repeated = try q.UnifiedCapture.advance(&retry, continuation, Access{ .data = store, .requests = requests }, second.allocator(), workspace, &cancel);
        try e.expectEqual(step, repeated);
        try e.expectEqualDeep(next.decision, retry.decision);
        try store.commit(retry);
        if (step == .complete) return;
    }
    return error.UnfinishedTestQuery;
}
test "one catalog query policy admits multiple general Tables and retains exact rows across ALTER DROP reuse" {
    var store: Store = .{};
    defer store.deinit();
    var requests: Store = .{ .resource = 8, .pid = 9 };
    defer requests.deinit();
    var initial = try turn(&store);
    try catalog.initialize(&initial);
    try store.commit(initial);
    var first = try create(&store, 100, 1, "CREATE TABLE people (id INTEGER PRIMARY KEY, name UTF8, balance DECIMAL(18,2), notes LIST(UTF8))");
    defer first.deinit();
    var other = try create(&store, 101, 2, "CREATE TABLE departments (id INTEGER, name UTF8)");
    defer other.deinit();
    try mutate(&store, first.source, 3, "INSERT INTO people VALUES (1, 'Ada', 125000.01, LIST('東京')), (2, 'Grace', NULL, LIST('compiler'))");
    try mutate(&store, other.source, 4, "INSERT INTO departments VALUES (10, 'Research'), (10, 'Research')");
    var policy_turn = try turn(&store);
    try q.UnifiedCapture.setPolicy(&policy_turn, .{ .peer = requests.pid, .requests = requests.resource, .revision = 1, .allow = true, .limits = limits, .target = .{ .catalog = .{ .scope = config.scope, .owner = config.owner, .principal = 17 } } });
    try store.commit(policy_turn);
    var arena: std.heap.ArenaAllocator = .init(e.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const first_source: q.SourceDefinition = .{ .resource = 7, .source = .{ .table = first.source } };
    const original = try Store.signQuery(try q.Bundle.fromSql(alloc, first_source, "people", "SELECT * FROM people", limits), 17, store.pid, requests.pid, requests.resource);
    const first_job = try admit(&store, &requests, original, 1);
    const other_job = try admit(&store, &requests, try Store.signQuery(try q.Bundle.fromSql(alloc, .{ .resource = 7, .source = .{ .table = other.source } }, "departments", "SELECT COUNT(*) FROM departments", limits), 17, store.pid, requests.pid, requests.resource), 2);
    var reader = try turn(&store);
    var found = try catalog.readDefinition(e.allocator, &reader, 17, first.source.object, first.source.metadata);
    defer found.deinit();
    _ = try ddl(&store, .{ .principal = 17, .operation = 5, .object = 100, .expected_revision = 1, .name = try c.TableMetadata.Name.init("people"), .action = .{ .alter = .{ .schema = found.schema.schema, .change = .{ .rename = .{ .column = 2, .name = "full_name" } } } } });
    const stale_reference = try upload(&requests, original, 3);
    var stale_evidence: ?q.QueryFailure = null;
    for (0..2) |_| {
        var stale = try message(&store, 9, .{ .kind = .call, .correlation = 3, .payload = try stale_reference.encode() });
        const proposal = stale.decision;
        var diagnostic: ?q.QueryFailure = null;
        try e.expectError(error.CatalogDefinitionChanged, q.UnifiedCapture.startDiagnostic(&stale, stale_reference, Access{ .data = &store, .requests = &requests }, alloc, &diagnostic));
        try e.expectEqualDeep(proposal, stale.decision);
        const failure = diagnostic.?;
        try e.expectEqual(.table_definition_changed, failure.code);
        try e.expectEqual(.table_metadata, failure.source.?.reason);
        try e.expectEqual(@as(?u64, 100), failure.source.?.object);
        try e.expectEqual(@as(?u64, 1), failure.source.?.expected);
        try e.expectEqual(@as(?u64, 2), failure.source.?.actual);
        try e.expectEqualDeep(first.source.metadata.spec.digest, failure.source.?.expected_hash.?);
        try e.expectEqualDeep(failure, try q.QueryFailure.decode(try failure.encode()));
        if (stale_evidence) |prior| try e.expectEqualDeep(prior, failure) else stale_evidence = failure;
    }
    _ = try ddl(&store, .{ .principal = 17, .operation = 6, .object = 100, .expected_revision = 2, .name = try c.TableMetadata.Name.init("people"), .action = .{ .drop = .{} } });
    var replacement = try create(&store, 102, 7, "CREATE TABLE people (id INTEGER, replacement BOOL)");
    defer replacement.deinit();
    try e.expectError(error.TableRetired, admit(&store, &requests, original, 3));
    // Diagnosis remains the original observed metadata after both definitions
    // have left the live namespace; projecting it performs no source reads.
    const stale_diagnostic = try stale_evidence.?.diagnostic(3, .retired);
    try e.expectEqualStrings("query.table_definition_changed", stale_diagnostic.code.slice());
    try e.expectEqual(@as(u64, 2), try stale_diagnostic.facts[5].?.value.?.unsigned.value());
    const workspace = try alloc.alloc(u8, f.LogicalArrow.working_bytes);
    try finish(&store, &requests, first_job, workspace);
    try finish(&store, &requests, other_job, workspace);
    reader = try store.capture();
    for ([_]r.Job{ first_job, other_job }, 0..) |job, which| {
        const publication = job.publication(store.resource);
        const descriptor = try publication.inspect(&reader, r.manifest_record);
        const reference: s.PublicationReference = .{ .domain = .query_result, .resource = store.resource, .namespace = publication.namespace, .record = r.manifest_record, .spec = descriptor.spec };
        const expected: q.UnifiedResult.Expected = .{ .resource = 7, .source = 3, .requester = 9, .correlation = which + 1, .request = job.request };
        var bytes: [f.LogicalArrow.segment_bytes]u8 = undefined;
        var decoded: f.LogicalInspect.Batch = undefined;
        const page = try q.UnifiedResult.page(reference, expected, null, Access{ .data = &store, .requests = &requests }, alloc, workspace, &bytes, &decoded);
        defer decoded.deinit();
        try e.expect(page.next == null);
        try e.expect(store.versions.get(job.source).?.view.released_at != null);
        if (which == 0) {
            try e.expectEqual(@as(usize, 2), decoded.rows.len);
            try e.expectEqualStrings("name", page.schema.structure[1].name);
            try e.expectEqualStrings("Ada", decoded.rows[0].cells[1].value.atom.bytes);
            try e.expectEqual(@as(i128, 12500001), decoded.rows[0].cells[2].value.atom.decimal);
            try e.expectEqualStrings("東京", decoded.rows[0].cells[3].value.list[0].value.atom.bytes);
        } else try e.expectEqual(@as(u128, 2), decoded.rows[0].cells[0].value.atom.unsigned);
    }
    // An empty result still needs current rights. Revocation becomes a durable
    // denial with exact pin release, never successful empty completion.
    const empty = try Store.signQuery(try q.Bundle.fromSql(alloc, .{ .resource = 7, .source = .{ .table = replacement.source } }, "people", "SELECT * FROM people LIMIT 0", limits), 17, store.pid, requests.pid, requests.resource);
    const empty_job = try admit(&store, &requests, empty, 4);
    var revoked = try c.testing.Authority.Rights.administrator(config.scope, 17);
    revoked.revision = 2;
    revoked.read = false;
    reader = try turn(&store);
    try store.setRights(revoked);
    try store.commit(reader);
    reader = try store.capture();
    const completed = first_job.publication(store.resource);
    const manifest = try completed.inspect(&reader, r.manifest_record);
    const reference: s.PublicationReference = .{ .domain = .query_result, .resource = 7, .namespace = completed.namespace, .record = r.manifest_record, .spec = manifest.spec };
    try e.expectError(error.CatalogDenied, q.UnifiedResult.open(reference, .{ .resource = 7, .source = 3, .requester = 9, .correlation = 1, .request = first_job.request }, Access{ .data = &store, .requests = &requests }, alloc));
    const continuation: r.Continuation = .{ .job = empty_job.id, .input = empty_job.continuation };
    var next = try message(&store, 3, .{ .kind = .cast, .payload = try continuation.encode() });
    const before = next.decision;
    const cancel = f.execution.Cancellation.init(false);
    try e.expectError(error.CatalogDenied, q.UnifiedCapture.advance(&next, continuation, Access{ .data = &store, .requests = &requests }, alloc, workspace, &cancel));
    try e.expectEqualDeep(before, next.decision);
    const failure = q.QueryFailure.fromError(error.CatalogDenied, .execution).?;
    try q.UnifiedCapture.closeFailure(&next, empty_job.id, failure);
    try store.commit(next);
    reader = try store.capture();
    const closed = try q.UnifiedCapture.job(&reader, empty_job.id);
    try e.expectEqual(.denied, closed.phase);
    try e.expectEqual(.catalog_read_denied, closed.failure.?.code);
    try e.expect(store.versions.get(empty_job.source).?.view.released_at != null);
    try e.expectEqual(@as(u64, 0), (try q.UnifiedCapture.checkpoint(&reader, empty_job.id)).progress.segments);
}

test "Table admission rejects unsigned, altered, stale and misrouted caller proofs before retention" {
    var store: Store = .{};
    defer store.deinit();
    var requests: Store = .{ .resource = 8, .pid = 9 };
    defer requests.deinit();
    var next = try turn(&store);
    try catalog.initialize(&next);
    try store.commit(next);
    var table = try create(&store, 100, 1, "CREATE TABLE items (id INT64)");
    defer table.deinit();
    next = try turn(&store);
    try q.UnifiedCapture.setPolicy(&next, .{ .peer = requests.pid, .requests = requests.resource, .revision = 1, .allow = true, .limits = limits, .target = .{ .catalog = .{ .scope = config.scope, .owner = config.owner, .principal = 17 } } });
    try store.commit(next);
    var arena: std.heap.ArenaAllocator = .init(e.allocator);
    defer arena.deinit();
    const description = try q.Bundle.fromSql(arena.allocator(), .{ .resource = 7, .source = .{ .table = table.source } }, "items", "SELECT * FROM items LIMIT 0", limits);
    const original = try Store.signQuery(description, 17, store.pid, requests.pid, requests.resource);
    try e.expectError(error.QueryAlreadyAuthorized, Store.signQuery(original, 17, store.pid, requests.pid, requests.resource));
    for (0..7) |kind| {
        var invalid = original;
        switch (kind) {
            0 => invalid.authorization = null,
            1 => invalid.limits.pages -= 1,
            2 => invalid.authorization.?.proof.claim.audience += 1,
            3 => invalid.authorization.?.requester += 1,
            4 => invalid.authorization.?.proof.signature[0] ^= 1,
            5 => {
                invalid.authorization.?.proof.claim.credential_epoch += 1;
                invalid.authorization.?.proof = try q.protocol.Authorization.Proof.sign(invalid.authorization.?.proof.claim, try c.testing.Authority.key(17));
            },
            6 => {
                invalid.authorization.?.proof.claim.role = 18;
                invalid.authorization.?.proof = try q.protocol.Authorization.Proof.sign(invalid.authorization.?.proof.claim, try c.testing.Authority.key(17));
            },
            else => unreachable,
        }
        const reference = try upload(&requests, invalid, kind + 1);
        next = try message(&store, requests.pid, .{ .kind = .call, .correlation = kind + 1, .payload = try reference.encode() });
        const before = next.decision;
        try e.expectError(if (kind < 4) error.QueryDenied else error.CatalogDenied, q.UnifiedCapture.start(&next, reference, Access{ .data = &store, .requests = &requests }, arena.allocator()));
        try e.expectEqualDeep(before, next.decision);
        try e.expectEqual(@as(?anyerror, null), next.read_error);
    }
    _ = try admit(&store, &requests, original, 8);
}

test "logical checkpoints retain the maximum native key within one value and require their original bundle" {
    var arena: std.heap.ArenaAllocator = .init(e.allocator);
    defer arena.deinit();
    const source: q.SourceDefinition = .{ .resource = 7, .source = .{ .kv = .{ .prefix = try q.protocol.Value.init(""), .key = .{ .type = .binary }, .value = .{ .type = .int64 } } } };
    const bundle = try q.Bundle.fromSql(arena.allocator(), source, "items", "SELECT * FROM items", limits);
    const basis = try q.UnifiedSource.basis(source, 42);
    const plan = try bundle.bind(try basis.fingerprint());
    var progress = try f.LogicalStream.Progress.start(plan);
    progress.pages = 1;
    progress.counters = .{ .scanned = 8, .selected = 8 };
    progress.segments = 1;
    progress.rows = 8;
    const checkpoint: r.Checkpoint = .{ .cut = basis.cut, .progress = progress, .bytes = 8192, .chain = @splat(42), .cursor = .{ .ordinal = 1, .after = try q.protocol.Value.init(&@as([q.protocol.Growth.key_bytes]u8, @splat(255))) } };
    const bytes = try checkpoint.encode();
    try e.expectEqual(@as(u16, 254), bytes.len);
    const decoded = try r.Checkpoint.decode(bytes);
    try e.expectEqualDeep(checkpoint, decoded);
    _ = try decoded.bound(bundle);
    for (0..bytes.len) |length| {
        if (r.Checkpoint.decode(try q.protocol.Value.init(bytes.slice()[0..length]))) |_| return error.AcceptedTruncatedCheckpoint else |_| {}
    }
    var changed = decoded;
    changed.cut.revision += 1;
    try e.expectError(error.SourceChanged, changed.bound(bundle));
    changed = decoded;
    changed.progress.pages = 2;
    try e.expectError(error.InvalidQueryRecord, changed.encode());
    var corrupt = bytes;
    corrupt.data[21] = 1; // Non-Table cuts cannot carry a Table head commitment.
    try e.expectError(error.SourceChanged, r.Checkpoint.decode(corrupt));
}

test "neutral and prepared native bundles preserve exact scalar descriptors and independently owned values" {
    const Case = struct { type: f.Types.Type, atom: f.Types.Values.Atom };
    const cases = [_]Case{
        .{ .type = .int8, .atom = .{ .signed = -128 } },
        .{ .type = .int16, .atom = .{ .signed = -32768 } },
        .{ .type = .int32, .atom = .{ .signed = std.math.minInt(i32) } },
        .{ .type = .int64, .atom = .{ .signed = std.math.minInt(i64) } },
        .{ .type = .int128, .atom = .{ .signed = std.math.minInt(i128) } },
        .{ .type = .uint8, .atom = .{ .unsigned = std.math.maxInt(u8) } },
        .{ .type = .uint16, .atom = .{ .unsigned = std.math.maxInt(u16) } },
        .{ .type = .uint32, .atom = .{ .unsigned = std.math.maxInt(u32) } },
        .{ .type = .uint64, .atom = .{ .unsigned = std.math.maxInt(u64) } },
        .{ .type = .uint128, .atom = .{ .unsigned = std.math.maxInt(u128) } },
        .{ .type = .float32, .atom = .{ .float = -0.0 } },
        .{ .type = .float64, .atom = .{ .float = -0.0 } },
        .{ .type = .{ .decimal = .{ .precision = 38, .scale = 12 } }, .atom = .{ .decimal = 12345678901234567890123456789012345678 } },
        .{ .type = .boolean, .atom = .{ .boolean = true } },
        .{ .type = .utf8, .atom = .{ .bytes = "東京" } },
        .{ .type = .binary, .atom = .{ .bytes = "\x00\xff\x1b" } },
        .{ .type = .date, .atom = .{ .date = -1 } },
        .{ .type = .time, .atom = .{ .time = 86399999999999 } },
        .{ .type = .{ .timestamp = .civil }, .atom = .{ .timestamp = -1 } },
        .{ .type = .{ .timestamp = .utc }, .atom = .{ .timestamp = -1 } },
        .{ .type = .uuid, .atom = .{ .uuid = @splat(255) } },
    };
    for (cases) |case| {
        var arena: std.heap.ArenaAllocator = .init(e.allocator);
        defer arena.deinit();
        const source: q.SourceDefinition = .{ .resource = 7, .source = .{ .table = .{ .scope = config.scope, .owner = 3, .object = std.math.maxInt(u64), .metadata = .{ .id = std.math.maxInt(u64), .spec = .{ .format = c.TableMetadata.format, .length = 100, .digest = @splat(7) } }, .row_type = .{ .structure = &.{.{ .name = "value", .type = case.type, .nullable = true }} } } } };
        var template = try q.SqlTemplate.init(e.allocator, source, "items", "SELECT value FROM items WHERE value = $1 LIMIT $2");
        var bound = try template.bind(e.allocator, source, &.{ case.atom, .{ .unsigned = 1 } }, limits);
        defer bound.deinit();
        template.deinit();
        const copied = try q.Values.Bundle.fromNative(arena.allocator(), bound.bundle);
        const restored = try copied.native(arena.allocator());
        try e.expect(try restored.plan.schema.eql(bound.bundle.plan.schema));
        var original: [q.Bundle.max_bytes]u8 = undefined;
        var again: [q.Bundle.max_bytes]u8 = undefined;
        try e.expectEqualSlices(u8, try bound.bundle.encode(&original), try restored.encode(&again));
        const foreign = try q.Values.foreignScalar(arena.allocator(), case.atom, case.type);
        const scalar = try q.Values.scalar(arena.allocator(), foreign, case.type);
        try e.expectEqual(.eq, try f.Types.Values.atomOrder(case.atom, scalar, case.type));
    }
}

test "bounded query memory exhaustion closes exact work without masking external allocation failure" {
    var store: Store = .{};
    defer store.deinit();
    var requests: Store = .{ .resource = 8, .pid = 9 };
    defer requests.deinit();
    var initial = try turn(&store);
    try catalog.initialize(&initial);
    try store.commit(initial);
    var table = try create(&store, 100, 1, "CREATE TABLE items (id INT64, value UTF8)");
    defer table.deinit();
    try mutate(&store, table.source, 2, "INSERT INTO items VALUES (1, 'original')");
    var policy_turn = try turn(&store);
    try q.UnifiedCapture.setPolicy(&policy_turn, .{ .peer = requests.pid, .requests = requests.resource, .revision = 1, .allow = true, .limits = limits, .target = .{ .catalog = .{ .scope = config.scope, .owner = config.owner, .principal = 17 } } });
    try store.commit(policy_turn);
    var arena: std.heap.ArenaAllocator = .init(e.allocator);
    defer arena.deinit();
    const bundle = try Store.signQuery(try q.Bundle.fromSql(arena.allocator(), .{ .resource = 7, .source = .{ .table = table.source } }, "items", "SELECT * FROM items", limits), 17, store.pid, requests.pid, requests.resource);
    const reference = try upload(&requests, bundle, 1);
    const call: s.Frame = .{ .kind = .call, .correlation = 1, .payload = try reference.encode() };
    const access: Access = .{ .data = &store, .requests = &requests };
    const cancellation = f.execution.Cancellation.init(false);
    var first = try message(&store, requests.pid, call);
    try q.UnifiedBehavior.dispatchCatalogSource(&first, call, config, access, &.{}, &.{}, &cancellation);
    const rejected = try q.QueryFailure.decode((try s.Frame.decode(first.decision.outputs[0].?.value)).payload);
    try e.expectEqual(.adapter_memory_budget, rejected.code);
    try e.expectEqual(.admission, rejected.stage);
    try e.expectEqual(.none, rejected.dimension);
    try e.expectEqual(@as(u64, 0), rejected.observed);
    for (first.decision.retain) |pin| try e.expect(pin == null);
    for (first.decision.mutations) |entry| try e.expect(entry == null);
    try store.commit(first);

    // An ordinary allocator's failure is not a deployment budget observation.
    var ordinary = try message(&store, requests.pid, call);
    const untouched = ordinary.decision;
    try e.expectError(error.OutOfMemory, q.UnifiedCapture.start(&ordinary, reference, access, std.testing.failing_allocator));
    try e.expectEqualDeep(untouched, ordinary.decision);

    const ExternalFailure = struct {
        access: Access,
        opens: *usize,
        pub fn open(self: @This(), resource: u64) !s.Turn {
            self.opens.* += 1;
            // The publication has been decoded locally before this publisher
            // check fails. A broad catch around the whole operation is unsafe.
            if (self.opens.* == 2) return error.OutOfMemory;
            return self.access.open(resource);
        }
    };
    const adapter = try arena.allocator().alloc(u8, q.UnifiedBehavior.adapter_bytes);
    var opens: usize = 0;
    try e.expectError(error.OutOfMemory, q.UnifiedCapture.startBoundedDiagnostic(&ordinary, reference, ExternalFailure{ .access = access, .opens = &opens }, adapter, null));
    try e.expectEqual(@as(usize, 2), opens);
    try e.expectEqualDeep(untouched, ordinary.decision);

    const Poison = struct {
        original: s.Turn.Reader,
        pub fn authorize(raw: *anyopaque, guard: q.protocol.Authorization.Guard) anyerror!?q.protocol.Authorization.Verified {
            const self: *@This() = @ptrCast(@alignCast(raw));
            return self.original.authorization.?(self.original.context, guard);
        }
        pub fn read(raw: *anyopaque, view: q.protocol.Growth.View, key: q.protocol.Value) anyerror!?q.protocol.Value {
            const self: *@This() = @ptrCast(@alignCast(raw));
            if (key.eql(s.TableHead.key(100))) return error.OutOfMemory;
            return self.original.read(self.original.context, view, key);
        }
    };
    var poisoned = try message(&store, requests.pid, call);
    var poison: Poison = .{ .original = poisoned.reader };
    poisoned.reader = .{ .context = &poison, .read = Poison.read, .authorization = Poison.authorize };
    try e.expectError(error.OutOfMemory, q.UnifiedCapture.startBoundedDiagnostic(&poisoned, reference, access, adapter, null));
    try e.expectEqual(error.OutOfMemory, poisoned.read_error.?);
    try e.expectEqualDeep(untouched, poisoned.decision);

    inline for (.{ q.QueryFailure.Code.adapter_memory_budget, q.QueryFailure.Code.arrow_workspace_budget }, 0..) |expected, index| {
        const job = try admit(&store, &requests, bundle, index + 2);
        var reader = try store.capture();
        const continuation: r.Continuation = .{ .job = job.id, .input = (try q.UnifiedCapture.job(&reader, job.id)).continuation };
        const frame: s.Frame = .{ .kind = .cast, .payload = try continuation.encode() };
        var next = try message(&store, store.pid, frame);
        try q.UnifiedBehavior.dispatchCatalogSource(&next, frame, config, access, if (expected == .adapter_memory_budget) &.{} else adapter, &.{}, &cancellation);
        const failed = try q.UnifiedCapture.job(&next, job.id);
        try e.expectEqual(expected, failed.failure.?.code);
        try e.expectEqual(.execution, failed.failure.?.stage);
        try e.expectEqual(.none, failed.failure.?.dimension);
        try e.expectEqual(@as(u64, 0), (try q.UnifiedCapture.checkpoint(&next, job.id)).progress.segments);
        try store.commit(next);
        try e.expect(store.versions.get(job.source).?.view.released_at != null);
        var replay = try message(&store, store.pid, frame);
        try q.UnifiedBehavior.dispatchCatalogSource(&replay, frame, config, access, adapter, &.{}, &cancellation);
        try e.expectEqualDeep(failed.failure, (try q.UnifiedCapture.job(&replay, job.id)).failure);
        try store.commit(replay);
    }
    // The owner can still admit and complete a later, independently requested
    // query with its normal bounded workspaces after recording those failures.
    const workspace = try arena.allocator().alloc(u8, f.LogicalArrow.working_bytes);
    try finish(&store, &requests, try admit(&store, &requests, bundle, 4), workspace);
}

test "a persisted large Table row exceeds the normal query adapter without stopping the owner" {
    var store: Store = .{};
    defer store.deinit();
    var requests: Store = .{ .resource = 8, .pid = 9 };
    defer requests.deinit();
    var next = try turn(&store);
    try catalog.initialize(&next);
    try store.commit(next);
    var table = try create(&store, 100, 1, "CREATE TABLE items (id INT64 PRIMARY KEY, value UTF8)");
    defer table.deinit();
    const text = try e.allocator.alloc(u8, 600 * 1024);
    defer e.allocator.free(text);
    @memset(text, 'x');
    var reader = try turn(&store);
    var found = try catalog.readDefinition(e.allocator, &reader, 17, table.source.object, table.source.metadata);
    defer found.deinit();
    const cells = [_]f.Types.Values.Cell{ .{ .value = .{ .atom = .{ .signed = 1 } } }, .{ .value = .{ .atom = .{ .bytes = text } } } };
    const mutation: c.TableDmlRequest = .{ .principal = 17, .operation = 2, .metadata = table.source.metadata, .plan = .{ .name = "items", .schema = found.schema.schema, .action = .{ .insert = &.{&cells} } } };
    for (0..10000) |_| {
        next = try turn(&store);
        const status = try catalog.mutate(e.allocator, &next, mutation);
        try store.commit(next);
        if (status.state != .building) {
            try e.expectEqual(.applied, status.state);
            break;
        }
    } else return error.UnfinishedTestDml;
    next = try turn(&store);
    try q.UnifiedCapture.setPolicy(&next, .{ .peer = requests.pid, .requests = requests.resource, .revision = 1, .allow = true, .limits = limits, .target = .{ .catalog = .{ .scope = config.scope, .owner = config.owner, .principal = 17 } } });
    try store.commit(next);
    var arena: std.heap.ArenaAllocator = .init(e.allocator);
    defer arena.deinit();
    const bundle = try Store.signQuery(try q.Bundle.fromSql(arena.allocator(), .{ .resource = 7, .source = .{ .table = table.source } }, "items", "SELECT * FROM items", limits), 17, store.pid, requests.pid, requests.resource);
    const job = try admit(&store, &requests, bundle, 1);
    const continuation: r.Continuation = .{ .job = job.id, .input = job.continuation };
    const frame: s.Frame = .{ .kind = .cast, .payload = try continuation.encode() };
    next = try message(&store, store.pid, frame);
    const adapter = try arena.allocator().alloc(u8, q.UnifiedBehavior.adapter_bytes);
    const workspace = try arena.allocator().alloc(u8, f.LogicalArrow.working_bytes);
    const cancellation = f.execution.Cancellation.init(false);
    try q.UnifiedBehavior.dispatchCatalogSource(&next, frame, config, Access{ .data = &store, .requests = &requests }, adapter, workspace, &cancellation);
    const failed = try q.UnifiedCapture.job(&next, job.id);
    try e.expectEqual(.adapter_memory_budget, failed.failure.?.code);
    try e.expect(next.read_error == null);
    try store.commit(next);
    try e.expect(store.versions.get(job.source).?.view.released_at != null);
    // The original committed row and exact mutation receipt remain readable.
    reader = try turn(&store);
    var current = try catalog.readDefinition(e.allocator, &reader, 17, table.source.object, table.source.metadata);
    defer current.deinit();
    const head = try s.TableHead.load(&reader, table.source.object);
    const data: s.TableData = .{ .schema = current.schema.schema, .index = head.index };
    var pages: s.TablePages.Reader(*s.Turn) = .{ .pages = .{ .resource = store.resource, .object = table.source.object }, .source = &reader };
    var row = (try data.next(e.allocator, &pages, null)).?;
    defer row.deinit();
    try e.expectEqualSlices(u8, text, row.row().cells[1].value.atom.bytes);
}
