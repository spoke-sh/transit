//! Finite direct Table capture: retirement, bounded memory and attempt failures.
const std = @import("std");
const q = @import("transit_query");
const c = q.catalog;
const s = q.station;
const p = q.protocol;
const w = c.DirectTableProtocol;
const r = q.UnifiedRecords;
const support = @import("fixture_direct_captured_query");
const t = std.testing;
const limits: q.Bundle.Limits = .{ .pages = 32, .segments = 32, .result_bytes = 1048576 };
pub const Case = enum { retired_empty, large_row, adapter_memory, arrow_memory, external_memory };
const Host = struct {
    case: Case,
    bundle: q.Bundle,
    bytes: []const u8,
    reference: s.PublicationReference,
    resources: q.UnifiedBehavior.Resources,
    adapter: []u8,
    workspace: []u8,
    probed: bool = false,
    const correlation_key = p.Value.init("direct-unified-correlation") catch unreachable;
    fn interface(self: *Host) s.GenServer.Handler {
        return .{ .context = self, .handle = handle };
    }
    fn handle(raw: ?*anyopaque, turn: *s.Turn, frame: s.Frame) anyerror!void {
        const self: *Host = @ptrCast(@alignCast(raw.?));
        const local = (s.Frame.source(turn.delivery.input) catch 0) == turn.delivery.pid;
        const external = switch (turn.delivery.input.origin) {
            .external => |origin| origin.principal == 101,
            else => false,
        };
        if (frame.kind == .reply) return;
        if (frame.kind == .call) {
            if (!local) return error.AccessDenied;
            _ = try q.UnifiedCapture.startBoundedDiagnostic(turn, try s.PublicationReference.decode(frame.payload), self.resources, self.adapter, null);
            return;
        }
        if (frame.kind != .cast) return error.InvalidProofFrame;
        if (frame.payload.eql(try .init("retire"))) {
            if (!external) return error.AccessDenied;
            const correlation = try r.readIdentity((try turn.read(correlation_key)).?);
            const id = try r.readIdentity((try turn.read(r.key('i', turn.delivery.pid, correlation))).?);
            return q.UnifiedCapture.close(turn, id, .retired);
        }
        if (frame.payload.eql(try .init("configure"))) {
            if (!external) return error.AccessDenied;
            const table = self.bundle.source.source.table;
            try q.UnifiedCapture.setPolicy(turn, .{ .peer = turn.delivery.pid, .requests = turn.view.resource, .revision = 1, .allow = true, .limits = limits, .target = .{ .catalog = .{ .scope = table.scope, .owner = table.owner, .principal = 101 } } });
            return;
        }
        if (frame.payload.eql(try .init("upload"))) {
            if (!local and !external) return error.AccessDenied;
            if (try s.PublicationUpload.step(turn, .{ .domain = .query_request, .namespace = 1, .identity_key = r.key('u', 1, 0), .identity = try self.reference.encode(), .limits = .{ .record_bytes = q.Bundle.max_bytes, .staging_bytes = q.Bundle.max_bytes, .staging_records = 1 }, .records = &.{.{ .id = 1, .spec = self.reference.spec, .bytes = self.bytes }} })) {
                try turn.write(correlation_key, r.identityValue(try turn.call(turn.delivery.pid, try self.reference.encode(), null)));
            } else try turn.cast(turn.delivery.pid, frame.payload);
            return;
        }
        if (!local) return error.AccessDenied;
        const continuation = try r.Continuation.decode(frame.payload);
        const job = try q.UnifiedCapture.job(turn, continuation.job);
        const capturing = job.phase == .capturing;
        const cancellation = q.fuze.execution.Cancellation.init(false);
        if (capturing and self.case == .external_memory and !self.probed) {
            var unavailable = self.resources;
            unavailable.tables.?.allocator = t.failing_allocator;
            const before = turn.decision;
            var detail: ?q.QueryFailure = null;
            // The client's allocating JSON writer reports OutOfMemory.
            // The adapter has capacity: this is not its durable budget failure.
            try t.expectError(error.OutOfMemory, q.UnifiedCapture.advanceBoundedDiagnostic(turn, continuation, unavailable, self.adapter, self.workspace, &cancellation, &detail));
            try t.expect(turn.read_error == null and detail == null);
            try t.expectEqualDeep(before, turn.decision);
            // Keep signing/authority reads healthy and fail only allocation of
            // the separate Table HTTP client's owned response. This exercises
            // OutOfMemory inside tablePage without a poisoned native read.
            var transport = s.client.Client.init(t.failing_allocator, self.resources.native.wire.http.io, self.resources.tables.?.service.url);
            defer transport.deinit();
            unavailable = self.resources;
            unavailable.tables.?.service = &transport;
            try t.expectError(error.OutOfMemory, q.UnifiedCapture.advanceBoundedDiagnostic(turn, continuation, unavailable, self.adapter, self.workspace, &cancellation, &detail));
            try t.expect(turn.read_error == null and detail == null);
            try t.expectEqualDeep(before, turn.decision);
            self.probed = true;
        }
        var diagnostic: ?q.QueryFailure = null;
        _ = q.UnifiedCapture.advanceBoundedDiagnostic(turn, continuation, self.resources, if (capturing and self.case == .adapter_memory) &.{} else self.adapter, if (capturing and self.case == .arrow_memory) &.{} else self.workspace, &cancellation, &diagnostic) catch |err| {
            if (turn.read_error != null) return err;
            const failure = diagnostic orelse q.QueryFailure.fromError(err, .execution) orelse return err;
            return q.UnifiedCapture.closeFailure(turn, continuation.job, failure);
        };
    }
};
fn step(init: std.process.Init, running: *s.GenServer, behavior: *Host, admin: anytype) !void {
    const deadline: u64 = @intCast(std.Io.Clock.real.now(init.io).toMilliseconds() + 30000);
    if (try running.step(behavior.interface(), deadline) == .blocked) return running.handler_error orelse error.Blocked;
    const pending = try admin.client.query(.{ .realm = 42, .principal = 0, .kind = .delivery }, try support.key(17));
    if (pending.body.delivery.next) |next| _ = try admin.submit(.{ .deliver = next });
}
fn retire(client: c.DirectTableClient, definition: w.Definition, operation: u64) !void {
    var ddl: w.Ddl = .{ .binding = .{ .definition = p.Growth.current_definition, .identity = .{ .scope = client.connection.scope, .principal = 101, .operation = operation }, .target = definition.interpretation.interpretation.object, .action = .rename, .expected_definition = definition.interpretation.interpretation, .expected_data = null, .intent = @splat(0) }, .namespace = 1, .name = "retired_empty", .action = .{ .rename = "retired_empty_renamed" } };
    ddl.binding.intent = try ddl.digest(client.allocator);
    (try client.call(.{ .admit_ddl = ddl })).deinit();
    const renamed = try client.call(.{ .operation = .{ .binding = ddl.binding, .command = .execute, .steps = 32 } });
    defer renamed.deinit();
    ddl.binding.identity.operation += 1;
    ddl.binding.expected_definition = renamed.value.result.ddl.committed.resulting.interpretation;
    ddl.binding.action = .drop;
    ddl.name = "retired_empty_renamed";
    ddl.action = .drop;
    ddl.binding.intent = try ddl.digest(client.allocator);
    (try client.call(.{ .admit_ddl = ddl })).deinit();
    const dropped = try client.call(.{ .operation = .{ .binding = ddl.binding, .command = .execute, .steps = 32 } });
    defer dropped.deinit();
    try t.expect(dropped.value.result.ddl.committed.resulting.retired);
}
pub fn run(init: std.process.Init, client: c.DirectTableClient, admin: anytype, role: u64, case: Case) !void {
    const alloc = init.arena.allocator();
    const ordinal: u64 = @backingInt(case);
    const principal = 150 + ordinal;
    const seed: u8 = @intCast(120 + ordinal);
    const operation = 1200 + 10 * ordinal;
    const name = @tagName(case);
    const schema: q.fuze.TableSchema.Schema = .{ .object = 100 + ordinal, .revision = 1, .next_column = 3, .columns = &.{ .{ .id = 1, .name = "id", .type = .int64, .nullable = false }, .{ .id = 2, .name = "value", .type = .utf8, .nullable = false } }, .primary_key = &.{1} };
    const value = try alloc.alloc(u8, if (case == .large_row) 600 * 1024 else 8);
    @memset(value, 'x');
    var row_bytes: [q.fuze.TableRow.max_bytes]u8 = undefined;
    const row: q.fuze.TableRow.Row = .{ .identity = try w.Rows.insertIdentity(.{ .scope = client.connection.scope, .principal = 101, .operation = operation + 1 }, 0), .cells = &.{ .{ .value = .{ .atom = .{ .signed = 1 } } }, .{ .value = .{ .atom = .{ .bytes = value } } } } };
    const changes = [_]w.RowChange{.{ .insert = try .encode(alloc, try row.encode(schema, &row_bytes)) }};
    try support.tableRows(alloc, client, role, name, operation, schema, if (case == .retired_empty) &.{} else &changes);
    var worker = try support.provision(admin, principal, seed);
    _ = try admin.change(.{ .grant = .{ .object = .{ .kind = .process, .id = worker.pid }, .grantee = role, .privileges = p.permission(.send) | p.permission(.inspect) } });
    worker.generation = (try admin.client.query(.{ .realm = 42, .principal = 0, .kind = .{ .process = worker.pid } }, try support.key(17))).body.process.process.generation;
    _ = try admin.submit(.{ .own = .{ .pid = worker.pid, .expected_generation = worker.generation, .worker = principal } });
    worker.generation += 1;
    const found = try client.call(.{ .lookup = .{ .namespace = 1, .name = name } });
    defer found.deinit();
    const definition = found.value.result.lookup.?;
    const source = try q.TableSource.from(alloc, client.connection, definition);
    const description = try q.Bundle.fromSql(alloc, .{ .resource = client.connection.scope.resource, .source = .{ .table = source.source } }, name, try std.fmt.allocPrint(alloc, "SELECT * FROM {s}", .{name}), limits);
    const bundle = try description.authorizeCapture(.{ .transport = client.authority, .realm = 42, .principal = 101, .key = client.key }, client, worker.pid, worker.resource, worker.pid, worker.resource, .{ .executor = principal, .operation = operation + 2, .expected = definition.position });
    var executor = client;
    executor.connection.principal = principal;
    executor.key = try support.key(seed);
    var bytes: [q.Bundle.max_bytes]u8 = undefined;
    var behavior: Host = .{ .case = case, .bundle = bundle, .bytes = try bundle.encode(&bytes), .reference = try bundle.reference(worker.resource, 1), .resources = .{ .native = .{ .wire = client.authority, .realm = 42, .principal = principal, .key = executor.key }, .tables = executor }, .adapter = try alloc.alloc(u8, q.UnifiedBehavior.adapter_bytes), .workspace = try alloc.alloc(u8, q.fuze.LogicalArrow.working_bytes) };
    const configuration: s.client.Session = .{ .client = client.authority, .realm = 42, .principal = principal, .pid = worker.pid, .generation = worker.generation, .key = executor.key };
    var running = try s.GenServer.init(configuration, "state");
    running.failure_policy = .stop;
    const resources: s.client.ResourceReader = .{ .wire = client.authority, .realm = 42, .principal = 101, .key = client.key };
    try support.send(client, worker.pid, try .init("configure"));
    try support.send(client, worker.pid, try .init("upload"));
    var retired = false;
    var completed: r.Job = undefined;
    for (0..2000) |iteration| {
        if (iteration != 0 and iteration % 17 == 0) {
            running = try s.GenServer.init(configuration, "state");
            running.failure_policy = .stop;
        }
        try step(init, &running, &behavior, admin);
        var reader = try resources.open(worker.resource);
        const correlation = try r.readIdentity((try reader.read(Host.correlation_key)) orelse continue);
        const id = try r.readIdentity((try reader.read(r.key('i', worker.pid, correlation))) orelse continue);
        completed = try q.UnifiedCapture.job(&reader, id);
        if (case == .retired_empty and completed.phase == .capturing and !retired) {
            try retire(client, definition, operation + 3);
            retired = true;
        }
        if (completed.phase != .complete and completed.phase != .failed) continue;
        const pin = (try q.CapturedTablePin.observe(alloc, &reader, .{ .job = id, .source = 0 }, worker.pid)).?;
        if (pin.phase != .closed or (completed.phase == .failed and completed.cleanup != 0)) continue;
        break;
    } else return error.UnifiedBoundaryPending;
    var reader = try resources.open(worker.resource);
    const checkpoint = try q.UnifiedCapture.checkpoint(&reader, completed.id);
    const status = try client.call(.{ .pin_status = .{ .object = bundle.retention.?.binding.interpretation.object, .owner = bundle.retention.?.binding.owner } });
    defer status.deinit();
    try t.expect(status.value.result.pin_state.released);
    if (case == .retired_empty or case == .external_memory) {
        try t.expectEqual(.complete, completed.phase);
        try t.expect(case != .retired_empty or retired);
        try t.expect(case != .external_memory or behavior.probed);
        const publication = completed.publication(worker.resource);
        const manifest: s.PublicationReference = .{ .domain = .query_result, .resource = worker.resource, .namespace = publication.namespace, .record = r.manifest_record, .spec = (try publication.inspect(&reader, r.manifest_record)).spec };
        const expected = try (q.UnifiedResult.Expected{ .resource = worker.resource, .source = worker.pid, .requester = worker.pid, .correlation = completed.correlation, .request = completed.request }).authorize(manifest, null, .{ .transport = client.authority, .realm = 42, .principal = 101, .key = client.key });
        var decoded: q.fuze.LogicalInspect.Batch = undefined;
        const result = try q.UnifiedResult.page(manifest, expected, null, resources, alloc, behavior.workspace, try alloc.alloc(u8, q.fuze.LogicalArrow.segment_bytes), &decoded);
        defer decoded.deinit();
        try t.expect(result.next == null);
        try t.expectEqual(@as(u64, if (case == .retired_empty) 0 else 1), checkpoint.progress.rows);
        try t.expectEqual(@as(usize, if (case == .retired_empty) 0 else 1), decoded.rows.len);
        try t.expectEqualStrings("value", result.schema.structure[1].name);
    } else {
        try t.expectEqual(.failed, completed.phase);
        try t.expectEqual(if (case == .arrow_memory) q.QueryFailure.Code.arrow_workspace_budget else .adapter_memory_budget, completed.failure.?.code);
        try t.expectEqual(.execution, completed.failure.?.stage);
        try t.expectEqual(@as(u64, 0), checkpoint.progress.segments);
        // Failure closes only the computation. The accepted row remains intact.
        const current = try client.call(.{ .lookup = .{ .namespace = 1, .name = name } });
        defer current.deinit();
        try t.expectEqualDeep(definition.interpretation, current.value.result.lookup.?.interpretation);
        const pinned = try client.call(.{ .pin = .{ .object = definition.interpretation.interpretation.object, .owner = .{ .scope = client.connection.scope, .principal = 101, .operation = operation + 5 }, .expected = current.value.result.lookup.?.position } });
        defer pinned.deinit();
        const snapshot: w.Snapshot = .{ .object = definition.interpretation.interpretation.object, .handle = pinned.value.result.pin };
        var stored = try c.DirectTableReader.open(init.gpa, client, snapshot);
        defer stored.deinit();
        var batch = (try stored.next(client, .{})).?;
        defer batch.deinit();
        try t.expectEqual(@as(usize, 1), batch.count);
        try t.expectEqualStrings(value, batch.rows[0].?.row().cells[1].value.atom.bytes);
        (try client.call(.{ .release = snapshot })).deinit();
    }
    if (completed.phase == .complete) {
        try support.send(client, worker.pid, try .init("retire"));
        for (0..200) |_| {
            try step(init, &running, &behavior, admin);
            reader = try resources.open(worker.resource);
            const current = try q.UnifiedCapture.job(&reader, completed.id);
            if (current.phase != .retired or current.cleanup != 0) continue;
            const budget = try current.publication(worker.resource).budget(&reader);
            try t.expectEqual(@as(u64, 0), budget.bytes);
            try t.expectEqual(@as(u32, 0), budget.records);
            const pin = (try q.CapturedTablePin.observe(alloc, &reader, .{ .job = current.id, .source = 0 }, worker.pid)).?;
            try t.expectEqual(.closed, pin.phase);
            break;
        } else return error.UnifiedRetirementPending;
    }
}
