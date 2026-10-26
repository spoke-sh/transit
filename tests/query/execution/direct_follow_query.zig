//! Real LiveService scheduling over caller-signed direct captures, with native
//! and Table storage in independent resources. The Python harness restarts the
//! node between committed selection and source acquisition.
const std = @import("std");
const live = @import("transit_serving");
const q = @import("transit_query");
const c = q.catalog;
const s = q.station;
const p = q.protocol;
const w = c.DirectTableProtocol;
const t = std.testing;
const support = @import("fixture_direct_captured_query");
const limits: q.Bundle.Limits = .{ .pages = 32, .segments = 32, .result_bytes = 1048576 };
pub const State = struct {
    connection: q.UnifiedClient.Connection,
    worker_generation: u64,
    requester_generation: u64,
    source: live.ReactiveModel.Source,
    selection: live.RefreshModel.Selection,
    original: q.TablePosition,
    workspace: q.Workspace.Config,
};
const Hosts = struct {
    source: s.GenServer,
    requester: s.GenServer,
    behavior: q.UnifiedBehavior.Source,
    service: live.LiveService,
    fn create(init: std.process.Init, client: c.DirectTableClient, state: State, cancellation: *const q.fuze.execution.Cancellation) !Hosts {
        const alloc = init.arena.allocator();
        var tables = client;
        tables.connection.principal = 103;
        tables.key = try support.key(43);
        return .{
            .source = try s.GenServer.init(.{ .client = client.authority, .realm = 42, .principal = 103, .pid = state.connection.source, .generation = state.worker_generation, .key = tables.key }, "state"),
            .requester = try s.GenServer.init(.{ .client = client.authority, .realm = 42, .principal = 104, .pid = state.connection.requester, .generation = state.requester_generation, .key = try support.key(47) }, "state"),
            .behavior = .{ .peer = state.connection.requester, .initializer = 101, .resources = .{ .wire = client.authority, .realm = 42, .principal = 103, .key = tables.key }, .tables = tables, .adapter = try alloc.alloc(u8, q.UnifiedBehavior.adapter_bytes), .workspace = try alloc.alloc(u8, q.fuze.LogicalArrow.working_bytes), .cancellation = cancellation },
            // The private reader has independent read grants. RefreshReader must also
            // mediate the original accepted caller on every observation.
            .service = .{ .configuration = .{ .service = .{ .service = 99, .administrator = 101, .observer = 101 }, .query_principal = 101, .source = state.connection.source }, .resources = .{ .wire = client.authority, .realm = 42, .principal = 105, .key = try support.key(53) }, .scratch = try alloc.alloc(u8, q.UnifiedBehavior.adapter_bytes), .upper_ms = now(init.io) },
        };
    }
    fn step(self: *Hosts, io: std.Io, admin: anytype) !void {
        self.service.upper_ms = now(io);
        const deadline = self.service.upper_ms + 30000;
        self.requester.input_guard = self.service.guard();
        self.requester.failure_policy = .stop;
        self.source.failure_policy = .stop;
        if (try self.requester.step(self.service.interface(), deadline) == .blocked) return self.requester.handler_error orelse error.Blocked;
        if (try self.source.step(self.behavior.interface(), deadline) == .blocked) return self.source.handler_error orelse error.Blocked;
        const delivery = try admin.client.query(.{ .realm = 42, .principal = 0, .kind = .delivery }, try support.key(17));
        if (delivery.body.delivery.next) |next| _ = try admin.submit(.{ .deliver = next });
    }
    fn reader(self: *Hosts, state: State) !s.client.ResourceReader.Reader {
        return self.service.resources.open(state.connection.requests);
    }
    fn control(self: *Hosts, init: std.process.Init, client: c.DirectTableClient, admin: anytype, state: State, command: live.Model.Command) !u64 {
        const identity = try client.authority.query(.{ .realm = 42, .principal = 101, .kind = .identity }, client.key);
        const prepared = try p.Growth.sign(.{ .realm = 42, .principal = 101, .sequence = identity.principal_sequence + 1, .command = .{ .send = .{ .pid = state.connection.requester, .value = try (s.Frame{ .kind = .cast, .payload = try command.encode() }).encode() } } }, client.key);
        const private: live.ReactiveClient = .{ .wire = client.authority, .connection = .{ .realm = 42, .principal = 101, .service = 99, .ingress = state.connection.requester }, .key = client.key, .refresh = true };
        const adapter: live.Adapter = .{ .resources = self.service.resources, .service = 99, .ingress = state.connection.requester, .resource = state.connection.requests };
        const saved: live.ReactiveModel.SignedSend = .{ .request = .{ .definition = prepared.request.definition, .realm = prepared.request.realm, .principal = prepared.request.principal, .sequence = prepared.request.sequence, .command = .{ .send = prepared.request.command.send } }, .signature = prepared.signature };
        const recoverable = command == .refresh or (command == .reactive and switch (command.reactive) {
            .open, .attach, .subscribe, .renew, .unsubscribe, .close => true,
            else => false,
        });
        if (recoverable) {
            const recovered = try private.recoverControl(adapter, saved);
            try t.expectEqualDeep(private.connection, recovered.connection);
            try t.expectEqual(null, recovered.input);
            if (command == .reactive) try t.expectEqualDeep(command.reactive, recovered.control.reactive.native());
            var invalid = saved;
            invalid.signature = (try p.Growth.sign(invalid.native().request, try support.key(97))).signature;
            try t.expectError(error.SignatureVerificationFailed, private.recoverControl(adapter, invalid));
        }
        const receipt = try client.authority.submit(prepared);
        // A duplicate transport submission must preserve the original identity.
        try t.expectEqualDeep(receipt, try client.authority.submit(prepared));
        if (recoverable) {
            // Reconstruct from the original bytes and actual receipt; a missing
            // browser receipt must not create a replacement native sequence.
            const recovered = try private.recoverControl(adapter, saved);
            try t.expectEqual(receipt.position, recovered.input.?);
            const current = try client.authority.query(.{ .realm = 42, .principal = 101, .kind = .identity }, client.key);
            try t.expectEqual(prepared.request.sequence, current.principal_sequence);
        }
        var caller = query(client, state);
        for (0..2000) |_| {
            try self.step(init.io, admin);
            switch (try caller.observe(receipt.position)) {
                .pending => continue,
                .rejected => return error.ControlRejected,
                .committed => {
                    var observed = try self.reader(state);
                    if (try live.ServingFailure.read(&observed, 42, state.connection.requests, 99, 101, receipt.position)) |failure| {
                        std.debug.print("Follow control rejected: {s}\n", .{try p.Json.valueAlloc(init.arena.allocator(), failure)});
                        return error.ControlRejected;
                    }
                    return receipt.position;
                },
            }
        }
        return error.ControlPending;
    }
    fn upload(self: *Hosts, init: std.process.Init, client: c.DirectTableClient, admin: anytype, state: State, namespace: u64, bundle: q.Bundle, prepared_only: bool) !void {
        var caller = query(client, state);
        for (0..2000) |_| {
            const next = if (prepared_only) try caller.prepareTemplateNext(namespace, bundle) else try caller.prepareNext(namespace, bundle);
            const token = next orelse return;
            if (prepared_only) {
                try t.expectEqual(null, try caller.recoverPreparation(token, namespace));
                try t.expectError(error.QueryIdentityMismatch, caller.recoverPreparation(token, namespace + 100));
            }
            const receipt = try caller.submit(token);
            if (prepared_only) {
                const sequence = (try caller.authorizationClient().read(.identity)).principal_sequence;
                const recovered = try q.Workspace.apply(init.arena.allocator(), &caller, state.workspace, .{ .recover_preparation = .{
                    .token = try std.json.Stringify.valueAlloc(init.arena.allocator(), token, .{}),
                    .namespace = try q.document.JsonValues.decimal(init.arena.allocator(), namespace),
                } });
                try t.expectEqualDeep(receipt, recovered.recovered_preparation.?);
                try t.expectEqual(sequence, (try caller.authorizationClient().read(.identity)).principal_sequence);
            }
            for (0..2000) |_| {
                try self.step(init.io, admin);
                switch (try caller.observe(receipt.position)) {
                    .committed => break,
                    .rejected => return error.QueryUploadRejected,
                    .pending => {},
                }
            } else return error.QueryUploadPending;
        }
        return error.QueryUploadPending;
    }
};
fn now(io: std.Io) u64 {
    return @intCast(std.Io.Clock.real.now(io).toMilliseconds());
}
fn query(client: c.DirectTableClient, state: State) q.UnifiedClient {
    return .{ .wire = client.authority, .tables = client, .connection = state.connection, .key = client.key };
}
/// Drive only workers/delivery while the separate example process owns its
/// caller sequence. The example must compile, authorize, save and upload itself.
pub fn example(init: std.process.Init, client: c.DirectTableClient, admin: anytype, saved: State) !void {
    var state = saved;
    for ([_]u64{ state.connection.source, state.connection.requester }, [_]u64{ 103, 104 }) |pid, principal| {
        const generation = (try admin.client.query(.{ .realm = 42, .principal = 0, .kind = .{ .process = pid } }, try support.key(17))).body.process.process.generation;
        _ = try admin.submit(.{ .own = .{ .pid = pid, .expected_generation = generation, .worker = principal } });
        if (principal == 103) state.worker_generation = generation + 1 else state.requester_generation = generation + 1;
    }
    const cancellation = q.fuze.execution.Cancellation.init(false);
    var hosts = try Hosts.create(init, client, state, &cancellation);
    var caller = query(client, state);
    for (0..10000) |_| {
        try hosts.step(init.io, admin);
        if (try caller.status(970)) |status| {
            if (status.phase == .complete) {
                _ = try result(init, client, state, 970, 20);
                for (0..8) |_| try hosts.step(init.io, admin);
                return;
            }
            if (status.phase == .denied or status.phase == .rejected or status.phase == .cancelled) return error.QueryCaptureFailed;
        }
    }
    return error.QueryCapturePending;
}
fn mutate(init: std.process.Init, client: c.DirectTableClient, operation: u64, sql: []const u8) !void {
    const lookup = try client.call(.{ .lookup = .{ .namespace = 1, .name = "follow_items" } });
    defer lookup.deinit();
    const definition = lookup.value.result.lookup.?;

    const bytes = try definition.schema.decode(init.arena.allocator(), q.fuze.TableSchema.max_bytes);
    var schema = try q.fuze.TableSchema.decode(init.gpa, bytes);
    defer schema.deinit();
    var compiled = try q.fuze.TableDml.compile(init.gpa, sql, "follow_items", schema.schema, null);
    defer compiled.deinit();
    var intent = try c.DirectTableIntent.fromDml(init.gpa, client.connection, definition, operation, compiled.plan, .point);
    defer intent.deinit();
    (try intent.admit(client)).deinit();
    const outcome = try intent.operation(client, .execute, 32);
    defer outcome.deinit();
    try t.expect(outcome.value.result.rows == .committed);
}
fn result(init: std.process.Init, client: c.DirectTableClient, state: State, namespace: u64, expected: i128) !q.TablePosition {
    var caller = query(client, state);
    const alloc = init.arena.allocator();
    const workspace = try alloc.alloc(u8, q.fuze.LogicalArrow.working_bytes);
    const output = try alloc.alloc(u8, q.fuze.LogicalArrow.segment_bytes);
    var decoded: q.fuze.LogicalInspect.Batch = undefined;
    const page = try caller.page(namespace, null, alloc, workspace, output, &decoded);
    defer decoded.deinit();
    try t.expect(page.next == null);
    try t.expectEqual(@as(usize, 1), decoded.rows.len);
    try t.expectEqual(expected, decoded.rows[0].cells[0].value.atom.signed);
    return page.table_position.?;
}
pub fn prepare(init: std.process.Init, client: c.DirectTableClient, admin: anytype, role: u64) !State {
    const alloc = init.arena.allocator();
    const schema: q.fuze.TableSchema.Schema = .{ .object = 96, .revision = 1, .next_column = 3, .columns = &.{ .{ .id = 1, .name = "id", .type = .int64, .nullable = false }, .{ .id = 2, .name = "value", .type = .int64 } }, .primary_key = &.{1} };
    try support.tableRows(alloc, client, role, "follow_items", 960, schema, &.{});
    try mutate(init, client, 962, "INSERT INTO follow_items VALUES (1, 10)");
    var worker = try support.provision(admin, 103, 43);
    var requester = try support.provision(admin, 104, 47);
    _ = try admin.submit(.{ .grant_resource = .{ .resource = requester.resource, .subject = 103, .permissions = p.State.permission(.inspect) | p.State.permission(.read) } });
    _ = try admin.submit(.{ .associate = .{ .pid = worker.pid, .name = try p.Value.init("requests"), .resource = requester.resource, .required = false } });
    for ([_]u64{ worker.pid, requester.pid }) |pid| _ = try admin.change(.{ .grant = .{ .object = .{ .kind = .process, .id = pid }, .grantee = role, .privileges = p.permission(.inspect) | p.permission(.send) } });
    worker.generation = (try admin.client.query(.{ .realm = 42, .principal = 0, .kind = .{ .process = worker.pid } }, try support.key(17))).body.process.process.generation;
    requester.generation = (try admin.client.query(.{ .realm = 42, .principal = 0, .kind = .{ .process = requester.pid } }, try support.key(17))).body.process.process.generation;
    _ = try admin.submit(.{ .own = .{ .pid = worker.pid, .expected_generation = worker.generation, .worker = 103 } });
    _ = try admin.submit(.{ .own = .{ .pid = requester.pid, .expected_generation = requester.generation, .worker = 104 } });
    const lookup = try client.call(.{ .lookup = .{ .namespace = 1, .name = "follow_items" } });
    defer lookup.deinit();
    const definition = lookup.value.result.lookup.?;
    // Proof authentication spans both the requester and independent source
    // audiences. Use an explicit read-only inspector, not a PID-scoped worker.
    _ = try admin.submit(.{ .grant = .{ .subject = 105, .public_key = (try support.key(53)).public_key.toBytes(), .permissions = p.permission(.inspect), .pid = null } });
    const host_role = (try (s.client.AuthorizationClient{ .transport = client.authority, .realm = 42, .principal = 105, .key = try support.key(53) }).read(.identity)).body.authorization.body.identity.login_role;
    const required = try client.call(.{ .read_authority = definition.interpretation.interpretation.object });
    defer required.deinit();
    const requirements = try required.value.result.read_authority.guard(.{ .accepted = .{ .pid = requester.pid, .input = 1, .principal = 101 } });
    for (requirements.requirements) |requirement| if (requirement) |value| {
        _ = try admin.change(.{ .grant = .{ .object = value.object, .grantee = host_role, .privileges = value.privileges } });
    };
    for ([_]u64{ worker.resource, requester.resource }) |resource| _ = try admin.submit(.{ .grant_resource = .{ .resource = resource, .subject = 105, .permissions = p.State.permission(.inspect) | p.State.permission(.read) } });
    var declaration = try q.TableSource.from(init.gpa, client.connection, definition);
    defer declaration.deinit();
    var state: State = .{ .connection = .{ .realm = 42, .principal = 101, .source = worker.pid, .resource = worker.resource, .requester = requester.pid, .requests = requester.resource }, .worker_generation = worker.generation + 1, .requester_generation = requester.generation + 1, .source = try .from(1, declaration.source), .selection = undefined, .original = undefined, .workspace = .{ .name = "follow_items", .source = try q.Values.Source.fromNative(alloc, .{ .resource = client.connection.scope.resource, .source = .{ .table = declaration.source } }), .limits = try q.Values.Limits.fromNative(alloc, limits), .executor = 103 } };
    try t.expect(state.connection.resource != state.source.resource);
    try t.expect(state.connection.source != state.source.audience);
    const cancellation = q.fuze.execution.Cancellation.init(false);
    var hosts = try Hosts.create(init, client, state, &cancellation);
    var caller = query(client, state);
    try support.send(client, worker.pid, try q.UnifiedRequest.Command.encode(.initialize));
    _ = try caller.submit(try caller.prepare(.initialize));
    try support.send(client, worker.pid, try (q.UnifiedBehavior.PolicyChange{ .expected_revision = 0, .policy = .{ .peer = requester.pid, .requests = requester.resource, .revision = 1, .allow = true, .limits = limits, .target = .{ .catalog = .{ .scope = client.connection.scope, .owner = client.connection.audience, .principal = 101 } } } }).encode());
    for (0..100) |_| try hosts.step(init.io, admin);
    _ = try hosts.control(init, client, admin, state, .{ .publish = .{ .expected = 0, .binding = .{ .revision = 1, .target = worker.pid, .codec = 1, .active_limit = 2, .wait_before_ms = now(init.io) + 300000 } } });
    _ = try hosts.control(init, client, admin, state, .{ .policy = .{ .principal = 101, .expected = 0, .policy = .{ .revision = 1, .reads = true, .commands = true, .active_limit = 2 } } });
    _ = try hosts.control(init, client, admin, state, .{ .reactive = .{ .publish = .{ .expected = 0, .source = state.source } } });
    const workspace = state.workspace;
    caller.tables = try q.Workspace.directTables(alloc, &caller, workspace);
    const compiled = (try q.Workspace.apply(alloc, &caller, workspace, .{ .compile = .{ .sql = "SELECT SUM(value) AS total FROM follow_items" } })).compiled;
    const unsigned = try q.Bundle.decode(alloc, try q.Values.unhex(alloc, compiled.bundle, q.Bundle.max_bytes));
    try t.expect(unsigned.authorization == null and unsigned.retention == null);
    var unconfigured = workspace;
    unconfigured.executor = null;
    const capture: q.Workspace.Request = .{ .capture = .{ .bundle = compiled.bundle, .operation = "963" } };
    try t.expectError(error.QuerySourceUnavailable, q.Workspace.apply(alloc, &caller, unconfigured, capture));
    const authorized = (try q.Workspace.apply(alloc, &caller, workspace, capture)).compiled;
    const bundle = try q.Bundle.decode(alloc, try q.Values.unhex(alloc, authorized.bundle, q.Bundle.max_bytes));
    try t.expectEqual(.current, bundle.retention.?.binding.selection);
    try t.expectEqual(@as(u64, 103), bundle.retention.?.binding.executor);
    try t.expectError(error.QueryAlreadyAuthorized, q.Workspace.apply(alloc, &caller, workspace, .{ .capture = .{ .bundle = authorized.bundle, .operation = "963" } }));
    const before_upload = try client.call(.{ .pin_status = .{ .object = definition.interpretation.interpretation.object, .owner = bundle.retention.?.binding.owner } });
    defer before_upload.deinit();
    try t.expect(before_upload.value.result.pin_state.handle == null);
    try t.expectEqualDeep(definition.position, before_upload.value.result.pin_state.position);
    try hosts.upload(init, client, admin, state, 1, bundle, false);
    for (0..2000) |_| {
        try hosts.step(init.io, admin);
        if ((try caller.status(1)).?.phase == .complete) break;
    } else return error.QueryCapturePending;
    state.original = try result(init, client, state, 1, 10);
    for ([_]u64{ 2, 3 }) |namespace| {
        const prepared = (try q.Workspace.apply(alloc, &caller, workspace, .{ .refresh = .{ .template = "1", .operation = try q.document.JsonValues.decimal(alloc, 962 + namespace) } })).compiled;
        const refresh = try q.Bundle.decode(alloc, try q.Values.unhex(alloc, prepared.bundle, q.Bundle.max_bytes));
        try t.expectEqual(.current, refresh.retention.?.binding.selection);
        try hosts.upload(init, client, admin, state, namespace, refresh, true);
        try t.expectEqual(.prepared, (try caller.status(namespace)).?.phase);
        const pin = try client.call(.{ .pin_status = .{ .object = refresh.retention.?.binding.interpretation.object, .owner = refresh.retention.?.binding.owner } });
        defer pin.deinit();
        try t.expect(pin.value.result.pin_state.handle == null);
    }
    const observed_ms = now(init.io);
    _ = try hosts.control(init, client, admin, state, .{ .reactive = .{ .observe_clock = observed_ms } });
    _ = try hosts.control(init, client, admin, state, .{ .reactive = .{ .open = .{ .session = 1, .source_revision = 1, .lease_before_ms = observed_ms + 29000 } } });
    var reader = try hosts.reader(state);
    state.selection.session = .{ .session = 1, .generation = (try live.ReactiveService.session(&reader, 101, 1)).?.generation };
    state.selection.generation = try hosts.control(init, client, admin, state, .{ .refresh = .{ .follow = .{ .view = .{ .session = state.selection.session, .expected = 0, .template = .{ .value = 1 }, .captures = .{ .{ .value = 2 }, .{ .value = 3 }, .{ .value = 0 }, .{ .value = 0 }, .{ .value = 0 }, .{ .value = 0 }, .{ .value = 0 }, .{ .value = 0 } }, .limit = 2 } } } });
    try mutate(init, client, 966, "UPDATE follow_items SET value = 20 WHERE id = 1");
    _ = try hosts.control(init, client, admin, state, .{ .refresh = .{ .invalidate = state.selection } });
    for (0..2000) |_| {
        reader = try hosts.reader(state);
        const view = (try live.Refresh.current(&reader, 101, state.selection.session)).?;
        if (view.phase == .preparing) {
            try t.expectEqual(@as(u64, 2), view.namespace.value);
            try t.expectEqual(.prepared, (try caller.status(2)).?.phase);
            return state;
        }
        try hosts.step(init.io, admin);
    }
    return error.RefreshSelectionPending;
}
pub fn recover(init: std.process.Init, client: c.DirectTableClient, admin: anytype, saved: State) !void {
    var state = saved;
    _ = try admin.submit(.{ .own = .{ .pid = state.connection.source, .expected_generation = state.worker_generation, .worker = 103 } });
    state.worker_generation += 1;
    _ = try admin.submit(.{ .own = .{ .pid = state.connection.requester, .expected_generation = state.requester_generation, .worker = 104 } });
    state.requester_generation += 1;
    const cancellation = q.fuze.execution.Cancellation.init(false);
    var hosts = try Hosts.create(init, client, state, &cancellation);
    for (0..4000) |_| {
        try hosts.step(init.io, admin);
        var reader = try hosts.reader(state);
        const view = (try live.Refresh.current(&reader, 101, state.selection.session)).?;
        if (view.phase == .ready) {
            const fresh = try result(init, client, state, 2, 20);
            try t.expect(fresh.sameSource(state.original));
            try t.expect(fresh.accepted.value > state.original.accepted.value);
            _ = try hosts.control(init, client, admin, state, .{ .refresh = .{ .acknowledged = .{ .selection = state.selection, .namespace = .{ .value = 2 } } } });
            reader = try hosts.reader(state);
            const acknowledged = (try live.Refresh.current(&reader, 101, state.selection.session)).?;
            try t.expectEqualDeep(fresh.accepted, acknowledged.covered);
            try t.expect(acknowledged.covered.value >= acknowledged.dirty.value);
            _ = try hosts.control(init, client, admin, state, .{ .refresh = .{ .pause = state.selection } });
            var caller = query(client, state);
            try t.expectEqual(.prepared, (try caller.status(3)).?.phase);
            return;
        }
        if (view.phase == .denied or view.phase == .failed) {
            std.debug.print("Follow failed: {any}\n", .{view});
            return error.RefreshFailed;
        }
    }
    return error.RefreshResultPending;
}
