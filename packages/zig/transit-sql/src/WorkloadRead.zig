//! SQL service composition over original native workload pages. No mutation,
//! name lookup or SQL recompile occurs here. The service must recheck disclosure
//! after buffering a batch, including repeats and empty terminal responses.
const std = @import("std");
const g = @import("root.zig");
const c = g.catalog;
const p = c.protocol;
const f = g.fuze;
const w = c.DirectTableProtocol;
const native = c.DirectWorkloadResult;

pub const Prepared = struct {
    reference: c.DirectWorkloadIntent.Reference,
    intent: c.DirectWorkloadIntent,
    declaration: c.storage.LogDeclaration.Owned,
    plan: f.LogicalPlanCodec.Owned,
    output: f.Types.Decoded,
    projector: f.WorkloadProjection.Projector,
    projection_hash: [32]u8,

    pub fn init(caller: c.DirectTableClient, reference: c.DirectWorkloadIntent.Reference) !Prepared {
        try reference.validate();
        if (!std.meta.eql(caller.connection, reference.connection)) return error.CatalogIdentityConflict;
        const bytes = try c.DirectRecord.read(caller.allocator, caller, reference.record);
        defer caller.allocator.free(bytes);
        var intent = try c.DirectWorkloadIntent.restore(caller.allocator, bytes);
        errdefer intent.deinit();
        try reference.requireSame(try intent.reference(reference.record.scope.account));
        const projection = intent.parsed.value.projection orelse return error.WorkloadProjectionUnavailable;
        var declaration = try c.DirectLogProtocol.decodeMetadata(caller.allocator, caller.connection, intent.parsed.value.source);
        errdefer declaration.deinit();
        const source: f.WorkloadProjection.Source = .{ .binding = reference.binding, .schema = declaration.definition.schema };
        var plan = try projection.restore(caller.allocator, source);
        errdefer plan.deinit();
        const projector = try f.WorkloadProjection.Projector.init(caller.allocator, source, projection.fields, plan.plan);
        const encoded = try projection.plan.decode(caller.allocator, f.LogicalPlanCodec.max_bytes);
        defer caller.allocator.free(encoded);
        var projection_hash: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(encoded, &projection_hash, .{});
        var fields: [f.TableSchema.max_columns]f.Types.Field = undefined;
        const output = try (try plan.plan.outputSchema(&fields)).clone(caller.allocator);
        return .{ .reference = reference, .intent = intent, .declaration = declaration, .plan = plan, .output = output, .projector = projector, .projection_hash = projection_hash };
    }
    pub fn deinit(self: *Prepared) void {
        self.output.deinit();
        self.plan.deinit();
        self.declaration.deinit();
        self.intent.deinit();
        self.* = undefined;
    }
    pub fn limits(self: *const Prepared) native.Limits {
        const declared = self.reference.source.declaration.limits;
        return .{ .rows = @min(g.session_protocol.max_rows, declared.read_rows), .encoded_bytes = @min(1024 * 1024, declared.read_bytes), .scanned_rows = 65536 };
    }
    pub fn open(self: *const Prepared, caller: c.DirectTableClient) !c.DirectWorkloadResultProtocol.Opened {
        const response = try caller.call(.{ .workload_result = .{ .open = .{ .intent = self.reference, .limits = self.limits() } } });
        defer response.deinit();
        const value = response.value.result.workload_result.opened;
        // Only fixed-value fields escape this response. Its source schema is
        // already owned by Prepared and checked by the native response validator.
        return .{ .reference = value.reference, .position = value.position, .source = self.intent.parsed.value.source };
    }
};

pub const Read = struct {
    prepared: *Prepared,
    caller: c.DirectTableClient,
    reference: native.Reference,
    position: native.Position,
    projector: f.WorkloadProjection.Projector,
    response: ?std.json.Parsed(w.Response) = null,
    index: usize = 0,
    scratch: std.heap.ArenaAllocator,

    pub fn init(prepared: *Prepared, caller: c.DirectTableClient) !Read {
        const opened = try prepared.open(caller);
        return .{ .prepared = prepared, .caller = caller, .reference = opened.reference, .position = opened.position, .projector = prepared.projector, .scratch = .init(caller.allocator) };
    }
    pub fn deinit(self: *Read) void {
        if (self.response) |response| response.deinit();
        self.scratch.deinit();
        self.* = undefined;
    }
    pub fn observation(self: *const Read) !g.results.Workload.Observation {
        return .{ .intent = self.prepared.reference.record.content, .schema = try self.prepared.declaration.definition.schema.fingerprint(), .projection = self.prepared.projection_hash, .selection = self.reference.selection };
    }
    pub fn checkDisclosure(self: *const Read) !void {
        const opened = try self.prepared.open(self.caller);
        try self.reference.requireSame(opened.reference);
    }
    fn page(self: *const Read) ?native.Page {
        const response = self.response orelse return null;
        return response.value.result.workload_result.page.page;
    }
    fn length(self: *const Read) usize {
        return if (self.page()) |value| switch (value) {
            inline else => |body| body.rows.len,
        } else 0;
    }
    pub fn complete(self: *const Read) !bool {
        return self.index == self.length() and try self.position.complete(self.reference.selection);
    }
    pub fn completion(self: *const Read, rows: u64) !g.results.Completion {
        if (!try self.complete()) return error.IncompleteWorkloadCoverage;
        const value: g.results.Completion = .{ .rows = rows, .workload = .{ .intent = self.prepared.reference.record.content, .position = self.position } };
        try value.validate(.{ .data = .{ .workload = try self.observation() } });
        return value;
    }
    fn fetch(self: *Read) !void {
        const response = try self.caller.call(.{ .workload_result = .{ .page = .{ .reference = self.reference, .position = self.position } } });
        errdefer response.deinit();
        const next = response.value.result.workload_result.page;
        try self.reference.requireSame(next.reference);
        if (self.response) |old| old.deinit();
        self.response = response;
        self.position = next.position;
        self.index = 0;
    }
    /// Borrow one projected row until the next pull/deinit. The enclosing SQL
    /// batch owner copies it before resetting scratch and calls checkDisclosure
    /// after buffering. Empty native pages remain progress, never completion.
    pub fn pull(self: *Read, deadline: g.DatabaseRuntime.Deadline) !?g.results.Row {
        _ = self.scratch.reset(.retain_capacity);
        while (true) {
            if (self.index == self.length()) {
                if (try self.complete()) return null;
                try deadline.check(self.caller.service.http.io);
                try self.fetch();
                continue;
            }
            const value = self.page().?;
            var metadata: f.WorkloadProjection.Projector.Metadata = undefined;
            const encoded: w.Binary = switch (value) {
                .append => |body| blk: {
                    const row = body.rows[self.index];
                    metadata = .{ .offset = row.offset };
                    break :blk row.encoded;
                },
                .consume => |body| blk: {
                    const row = body.rows[self.index];
                    metadata = .{ .offset = row.offset };
                    break :blk row.encoded;
                },
                .claim => |body| blk: {
                    const row = body.rows[self.index];
                    metadata = .{ .offset = row.lease.original.offset, .lease = row.lease.original };
                    break :blk row.encoded;
                },
            };
            _ = self.scratch.reset(.retain_capacity);
            const bytes = try encoded.decode(self.scratch.allocator(), f.TableRow.max_bytes);
            const decoded = try f.TableRow.decodeInto(self.scratch.allocator(), self.prepared.declaration.definition.schema, bytes);
            const row = try self.projector.row(decoded.row().cells, metadata);
            self.index += 1;
            if (row) |selected| return selected;
        }
    }
};

test "workload reader retains projected cells and original coverage through lost reads and disclosure denial" {
    const t = std.testing;
    const s = c.storage;
    const Peer = struct {
        intent: *const c.DirectWorkloadIntent,
        reference: c.DirectWorkloadIntent.Reference,
        receipt: p.StreamRead.Receipt,
        rows: [3]s.LogBatch.EncodedRow,
        operation: p.DataLifecycle.Operation,
        key: [32]u8,
        calls: usize = 0,
        pages: usize = 0,
        denied: bool = false,
        lose_page: bool = false,
        fn cursor(self: *@This(), through: u64) p.StreamRead.Cursor {
            return .{ .read = self.receipt.handle(), .coverage = .{ .cut = self.receipt.cut, .from = 0, .until = 3, .through = through, .rows = through, .complete = through == 3 }, .authentication = @splat(17) };
        }
        fn invoke(raw: *anyopaque, invocation: *g.wire.LocalEndpoint.Invocation) !void {
            const self: *@This() = @ptrCast(@alignCast(raw));
            const request = try invocation.request(w.Request);
            try request.validate(invocation.allocator);
            try request.proof.verify(self.key);
            self.calls += 1;
            if (self.denied) return invocation.client.reject(.forbidden, .AccessDenied);
            const result: w.Result = switch (request.action) {
                .record => |record| blk: {
                    if (record != .read) return error.TestUnexpectedMutation;
                    try self.reference.record.requireSame(record.read);
                    break :blk .{ .record = .{ .reference = record.read, .bytes = try w.Binary.encode(invocation.allocator, self.intent.bytes) } };
                },
                .workload_result => |query| blk: {
                    const reference: native.Reference = .{ .intent = self.reference, .selection = .{ .consume = self.receipt }, .limits = .{ .rows = 1, .encoded_bytes = 8192, .scanned_rows = 65536 } };
                    if (query == .open) break :blk .{ .workload_result = .{ .opened = .{ .reference = reference, .position = .{ .consume = self.cursor(0) }, .source = self.intent.parsed.value.source } } };
                    try reference.requireSame(query.page.reference);
                    self.pages += 1;
                    if (self.lose_page) {
                        self.lose_page = false;
                        return error.AuthorityUnavailable;
                    }
                    const index = query.page.position.consume.coverage.through;
                    if (index >= 3) return error.TestUnexpectedPage;
                    const row = self.rows[@intCast(index)];
                    const rows = try invocation.allocator.alloc(c.DirectStream.Row, 1);
                    rows[0] = .{ .offset = index, .operation = self.operation, .ordinal = row.ordinal, .tombstone = false, .encoded = try w.Binary.encode(invocation.allocator, row.bytes) };
                    const next = self.cursor(index + 1);
                    break :blk .{ .workload_result = .{ .page = .{ .reference = reference, .position = .{ .consume = next }, .page = .{ .consume = .{ .source = self.intent.parsed.value.source, .rows = rows, .cursor = next, .examined = 1, .encoded_bytes = @intCast(row.bytes.len + s.LogBatch.row_header_bytes) } } } } };
                },
                else => return error.TestUnexpectedMutation,
            };
            const claim = request.proof.claim;
            const response: w.Response = .{ .definition = p.Growth.current_definition, .context = claim.context, .policy_revision = 1, .subject = .{ .principal = claim.principal, .login_role = 1, .role = 1, .credential_epoch = claim.credential_epoch, .audience = claim.audience, .context = claim.context }, .result = result };
            try invocation.respond(try g.wire.LocalEndpoint.clone(invocation.allocator, response));
        }
    };
    const scope: p.DataLifecycle.Scope = .{ .realm = 1, .resource = 2, .catalog = 3 };
    const connection: w.Connection = .{ .scope = scope, .branch = 1, .audience = 4, .principal = 5, .role = null };
    const columns = [_]f.TableSchema.Column{.{ .id = 7, .name = "payload", .type = .utf8, .nullable = false, .collation = .ascii_ci }};
    const schema: f.TableSchema.Schema = .{ .object = 9, .revision = 1, .next_column = 8, .columns = &columns, .primary_key = &.{} };
    const properties: c.DirectCatalog.Properties = .{ .namespace = 1, .authorization = 11, .name = try .init("events") };
    var properties_buffer: [4096]u8 = undefined;
    var declared = try s.LogDeclaration.prepare(t.allocator, .{ .object = .{ .scope = scope, .branch = 1, .object = 9 }, .revision = 1, .schema = schema, .properties = try properties.encode(&properties_buffer), .configuration = .{ .partitioning = .{ .count = 1, .key_column = null, .hash = .sha256_64 }, .retention = .{ .max_age_ms = null }, .policy = .{ .stream = .{ .compact_key_column = null, .timestamp_column = null } } }, .limits = .{ .append_rows = 3, .append_bytes = 8192, .claim_rows = 1, .read_rows = 1, .read_bytes = 8192, .active_leases = 1, .waiters = 1, .timer_steps = 1 } });
    defer declared.deinit();
    const stored = try declared.stored();
    const definition: c.DirectLog.Definition = .{ .stored = stored, .seed = stored, .properties = properties, .initialization = .{ .scope = scope, .principal = 5, .operation = 1 }, .first_partition = 13 };
    var schema_buffer: [f.TableSchema.max_bytes]u8 = undefined;
    const binary_schema = try w.Binary.encode(t.allocator, try schema.encode(&schema_buffer));
    defer t.allocator.free(binary_schema.base64);
    const source: c.DirectLogProtocol.Definition = .{ .declaration = definition, .schema = binary_schema };
    const operation: p.DataLifecycle.Operation = .{ .scope = scope, .principal = 5, .operation = 100 };
    const target: p.StreamQueue.Partition = .{ .definition = p.Growth.current_definition, .interpretation = stored.declaration.interpretation, .partition = 0 };
    const work: c.DirectWorkloadIntent.Work = .{ .stream = .{ .work = .{ .consume = .{ .target = target, .operation = .{ .scope = scope, .principal = 5, .operation = 101 }, .group = .{ .id = 7, .generation = 1, .principal = 5 }, .from = 0, .until = null, .timestamp = null } }, .payload = null } };
    const input: f.WorkloadProjection.Source = .{ .binding = try work.binding(t.allocator), .schema = schema };
    const fields = [_]f.WorkloadProjection.Field{ .offset, .{ .column = 7 } };
    var compiled = try f.WorkloadProjection.compile(t.allocator, input, &fields, "events", "SELECT payload AS body, _offset FROM events WHERE payload = 'alpha'", null);
    defer compiled.deinit();
    var plan_buffer: [f.LogicalPlanCodec.max_bytes]u8 = undefined;
    const plan = try w.Binary.encode(t.allocator, try f.WorkloadProjection.encode(input, &fields, compiled.plan, t.allocator, &plan_buffer));
    defer t.allocator.free(plan.base64);
    var intent = try c.DirectWorkloadIntent.createProjected(t.allocator, connection, source, work, .{ .fields = &fields, .plan = plan });
    defer intent.deinit();
    const reference = try intent.reference(@splat(19));
    var payload_buffer: [8192]u8 = undefined;
    const payload = try s.LogBatch.encode(schema, operation, .stream, &.{
        .{ .cells = &.{.{ .value = .{ .atom = .{ .bytes = "aLpHa" } } }} },
        .{ .cells = &.{.{ .value = .{ .atom = .{ .bytes = "beta" } } }} },
        .{ .cells = &.{.{ .value = .{ .atom = .{ .bytes = "Alpha" } } }} },
    }, &payload_buffer);
    const key = try p.Ed25519.KeyPair.generateDeterministic(@splat(1));
    var peer: Peer = .{ .intent = &intent, .reference = reference, .receipt = .{ .request = work.stream.work.consume, .cut = .{ .target = target, .accepted = .{ .partition = 13, .next_lsn = 5 }, .retained_from = 0, .next = 3 }, .until = 3, .source = s.LogBatch.content(payload), .accepted = .{ .partition = 13, .next_lsn = 6 } }, .rows = undefined, .operation = operation, .key = key.public_key.toBytes() };
    var iterator = try s.LogBatch.Iterator.init(payload, schema, .stream, 3);
    for (&peer.rows) |*row| row.* = (try iterator.next()).?;
    var transport = g.wire.Client.init(t.allocator, t.io, "http://127.0.0.1:1");
    defer transport.deinit();
    transport.local = .{ .context = &peer, .invoke = Peer.invoke };
    const caller: c.DirectTableClient = .{ .allocator = t.allocator, .authority = &transport, .service = &transport, .connection = connection, .key = key, .credential_epoch = 1 };
    var prepared = try Prepared.init(caller, reference);
    defer prepared.deinit();
    try t.expectEqualStrings("body", prepared.output.type.structure[0].name);
    var read = try Read.init(&prepared, caller);
    defer read.deinit();
    const deadline: g.DatabaseRuntime.Deadline = .{ .start = std.Io.Clock.awake.now(t.io), .milliseconds = 30000 };
    var retained: std.heap.ArenaAllocator = .init(t.allocator);
    defer retained.deinit();
    const first = try g.results.copyRow(retained.allocator(), prepared.output.type.structure, (try read.pull(deadline)).?);
    try read.checkDisclosure();
    try t.expectEqualStrings("aLpHa", first[0].value.atom.bytes);
    try t.expectEqual(0, first[1].value.atom.unsigned);
    const position = read.position;
    peer.lose_page = true;
    try t.expectError(error.AuthorityUnavailable, read.pull(deadline));
    try t.expectEqualDeep(position, read.position);
    const second = (try read.pull(deadline)).?;
    try t.expectEqualStrings("Alpha", second[0].value.atom.bytes);
    try t.expectEqual(2, second[1].value.atom.unsigned);
    try t.expectEqualStrings("aLpHa", first[0].value.atom.bytes);
    try t.expectEqual(null, try read.pull(deadline));
    const terminal = try read.completion(2);
    try t.expectEqual(3, terminal.workload.?.position.consume.coverage.rows);
    try t.expectEqual(7, (try read.observation()).selection.consume.request.group.?.id);
    peer.denied = true;
    try t.expectError(error.AccessDenied, read.checkDisclosure());
    peer.denied = false;
    const before_close = closed: {
        var reopened = try Read.init(&prepared, caller);
        defer reopened.deinit();
        try t.expectEqualStrings("aLpHa", (try reopened.pull(deadline)).?[0].value.atom.bytes);
        break :closed peer.calls;
    };
    try t.expectEqual(before_close, peer.calls);
}
