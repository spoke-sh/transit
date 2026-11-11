//! Fault schedules against the exact listener-free CLI host and SQL sessions.
const std = @import("std");
const host = @import("transit_cli_role").ApplicationTestHost;
const lib = @import("transit_test");
const g = lib.service;
const p = g.catalog.protocol;
const w = g.catalog.DirectTableProtocol;

fn require(value: bool) !void {
    if (!value) return error.ApplicationHostProofFailed;
}
fn write(session: *g.Session, sql: []const u8) !g.results.CommandCompletion {
    try session.begin();
    defer session.end();
    const prepared = try session.prepare(sql);
    defer session.destroy(prepared);
    return session.write(prepared, &.{});
}
fn denied(session: *g.Session, err: anyerror) !void {
    try require(err == error.AccessDenied and session.wire.last_rejection == .AccessDenied);
}

const Authority = struct {
    empty: bool,
    restore: bool = true,
    fn run(raw: *anyopaque, context: host.Context) !bool {
        const self: *@This() = @ptrCast(@alignCast(raw));
        const session = context.session;
        _ = try write(session, "CREATE TABLE items(id BIGINT PRIMARY KEY)");
        _ = try write(session, "INSERT INTO items VALUES (1), (2)");
        const lookup = try session.table.call(.{ .lookup = .{ .namespace = 1, .name = "items" } });
        const object = g.catalog.TableAuthority.reference(lookup.value.result.lookup.?.authorization);
        lookup.deinit();
        const owner = try context.authority.authorize(.{ .create_role = .{ .name = try .init("other_owner") } });
        _ = try context.authority.authorize(.{ .transfer_object = .{ .object = object, .owner = owner } });
        _ = try context.authority.authorize(.{ .grant = .{ .object = object, .grantee = context.role, .privileges = g.catalog.TableAuthority.select } });
        if (write(session, "INSERT INTO items VALUES (3)")) |_| return error.UnauthorizedWritePassed else |err| try denied(session, err);
        try session.begin();
        defer session.end();
        const prepared = try session.prepare(if (self.empty) "SELECT * FROM items WHERE id = 99" else "SELECT * FROM items");
        defer session.destroy(prepared);
        const read = try session.openRead(prepared, &.{});
        defer session.closeRead(read);
        const buffered = try read.nextBatch(1);
        try require(if (self.empty) buffered.len == 0 and buffered.complete else buffered.len == 1 and !buffered.complete);
        _ = try context.authority.authorize(.{ .revoke_privileges = .{ .object = object, .grantee = context.role, .privileges = g.catalog.TableAuthority.select } });
        read.resumeWire();
        if (read.validateDisclosure()) |_| return error.RevokedDisclosurePassed else |err| try denied(session, err);
        read.resumeWire();
        if (read.nextBatch(1)) |_| return error.RevokedFetchPassed else |err| try denied(session, err);
        if (self.restore) _ = try context.authority.authorize(.{ .grant = .{ .object = object, .grantee = context.role, .privileges = g.catalog.TableAuthority.select } });
        return true;
    }
};
const LostReply = struct {
    endpoint: g.wire.LocalEndpoint,
    lost: bool = false,
    commits: usize = 0,
    fn invoke(raw: *anyopaque, invocation: *g.wire.LocalEndpoint.Invocation) !void {
        const self: *@This() = @ptrCast(@alignCast(raw));
        const committing = if (invocation.isRequest(w.Request)) blk: {
            const request = try invocation.requestPtr(w.Request);
            break :blk request.action == .commit_saved and request.action.commit_saved.binding.action == .insert;
        } else false;
        try self.endpoint.invoke(self.endpoint.context, invocation);
        if (committing) {
            self.commits += 1;
            if (!self.lost) {
                self.lost = true;
                return error.TestLostReply;
            }
        }
    }
    fn run(_: *anyopaque, context: host.Context) !bool {
        const session = context.session;
        _ = try write(session, "CREATE TABLE items(id BIGINT PRIMARY KEY)");
        var proxy: LostReply = .{ .endpoint = context.endpoint };
        session.wire.local = .{ .context = &proxy, .invoke = invoke };
        defer session.wire.local = context.endpoint;
        if (write(session, "INSERT INTO items VALUES (7)")) |_| return error.LostReplyDidNotFail else |err| try require(err == error.TestLostReply);
        const original = session.operation orelse return error.MissingOriginalOperation;
        try require(proxy.lost and proxy.commits == 1);
        session.wire.local = context.endpoint;
        const result = try context.runtime.status(session.allocator, &session.observer, &session.table, session.namespace, original);
        try require(result.phase == .terminal and result.outcome == .applied and result.matched == 1 and result.changed == 1 and result.identity.id == original);
        // Resolve bookkeeping with the ordinary owner using its frozen original
        // reference. It must not admit another SQL operation or duplicate rows.
        try context.runtime.waitProgress(100);
        const after = try context.runtime.status(session.allocator, &session.observer, &session.table, session.namespace, original);
        try require(std.meta.eql(result.identity, after.identity));
        try session.begin();
        defer session.end();
        const prepared = try session.prepare("SELECT * FROM items");
        defer session.destroy(prepared);
        const read = try session.openRead(prepared, &.{});
        defer session.closeRead(read);
        const batch = try read.nextBatch(32);
        try require(batch.complete and batch.len == 1);
        var encoded: [1024]u8 = undefined;
        const row = try @import("transit_compiler").Test.rowBytes(batch.rows[0].?, prepared.native.output.?.type, &encoded);
        try require(row.len > 0);
        return true;
    }
};
const WorkflowAuthority = struct {
    fn run(_: *anyopaque, context: host.Context) !bool {
        const compiler = @import("transit_compiler");
        var diagnostic: ?p.Diagnostic = null;
        const source = "CREATE TEST TARGET tests AS BEGIN TEST 'workflow authority' USING MODULES () AS BEGIN CREATE PUBLIC QUEUE input (id BIGINT NOT NULL); CREATE PUBLIC DATAFLOW process FROM QUEUE input AS request AS BEGIN REQUIRE TRUE ELSE 'No'; END; AUTHORIZE DATAFLOW process AS ROLE CURRENT_ROLE; RETIRE DATAFLOW process; ASSERT WORKFLOW NAME 'process' COMPLETED 0 REFUSED 0 WITHIN 1000 OBSERVATIONS; END; END;";
        const product = try compiler.compile(context.session.allocator, &.{.{ .path = "build.transit", .text = source }}, .{ .mode = .test_suite, .target = "tests", .compiler_revision = "workflow-authority-proof" }, &diagnostic);
        defer product.deinit();
        var runner: lib.Runner = .{ .allocator = context.session.allocator, .session = context.session };
        try require((try runner.run(product.cases[0])).passed);
        // Quiesce the explicitly retired program before changing inspection
        // grants, so this schedule isolates disclosure from executor fencing.
        const declared = (try g.ManagedOperations.program(context.session, try .init("process"))) orelse return error.MissingWorkflow;
        defer declared.deinit();
        const manager: g.direct.ManagedApplication = .{ .client = context.session.table };
        while (!(try manager.inspect(declared.value)).head.retirement_complete) {
            try context.session.deadline.check(context.session.io);
            try context.session.io.sleep(.fromMilliseconds(10), .awake);
        }
        const lookup = try context.session.table.call(.{ .kv_lookup = .{ .namespace = 1, .name = "process" } });
        const object = g.catalog.TableAuthority.reference(lookup.value.result.kv_lookup.?.authorization);
        lookup.deinit();
        const owner = try context.authority.authorize(.{ .create_role = .{ .name = try .init("workflow_owner") } });
        _ = try context.authority.authorize(.{ .transfer_object = .{ .object = object, .owner = owner } });
        _ = try context.authority.authorize(.{ .grant = .{ .object = object, .grantee = context.role, .privileges = g.catalog.KVAuthority.inspect | g.catalog.KVAuthority.read } });
        var case = product.cases[0];
        case.actions = case.actions[case.actions.len - 1 ..];
        try require((try runner.run(case)).passed);
        _ = try context.authority.authorize(.{ .revoke_privileges = .{ .object = object, .grantee = context.role, .privileges = g.catalog.KVAuthority.read } });
        if (runner.run(case)) |_| return error.RevokedWorkflowPassed else |err| try denied(context.session, err);
        _ = try context.authority.authorize(.{ .transfer_object = .{ .object = object, .owner = context.role } });
        const input = try context.session.table.call(.{ .log_lookup = .{ .namespace = 1, .name = "input" } });
        const dependency = g.catalog.TableAuthority.reference(input.value.result.log_lookup.?.declaration.properties.authorization);
        input.deinit();
        _ = try context.authority.authorize(.{ .transfer_object = .{ .object = dependency, .owner = owner } });
        _ = try context.authority.authorize(.{ .grant = .{ .object = dependency, .grantee = context.role, .privileges = g.catalog.LogAuthority.inspect } });
        try require((try runner.run(case)).passed);
        _ = try context.authority.authorize(.{ .revoke_privileges = .{ .object = dependency, .grantee = context.role, .privileges = g.catalog.LogAuthority.inspect } });
        if (runner.run(case)) |_| return error.RevokedWorkflowDependencyPassed else |err| try denied(context.session, err);
        _ = try context.authority.authorize(.{ .transfer_object = .{ .object = dependency, .owner = context.role } });
        return true;
    }
};
const QueueAuthority = struct {
    fn run(_: *anyopaque, context: host.Context) !bool {
        const compiler = @import("transit_compiler");
        const session = context.session;
        var diagnostic: ?p.Diagnostic = null;
        const source = "CREATE TARGET default AS BEGIN CREATE PUBLIC QUEUE requests (id BIGINT NOT NULL); ENQUEUE INTO requests VALUES (7); END;";
        const product = try compiler.compile(session.allocator, &.{.{ .path = "build.transit", .text = source }}, .{ .compiler_revision = "queue-authority-proof" }, &diagnostic);
        defer product.deinit();
        _ = try write(session, product.steps[0].sql);
        const lookup = try session.table.call(.{ .log_lookup = .{ .namespace = 1, .name = "requests" } });
        const object = g.catalog.TableAuthority.reference(lookup.value.result.log_lookup.?.declaration.properties.authorization);
        lookup.deinit();
        const owner = try context.authority.authorize(.{ .create_role = .{ .name = try .init("queue_owner") } });
        _ = try context.authority.authorize(.{ .transfer_object = .{ .object = object, .owner = owner } });
        const privileges = g.catalog.LogAuthority.inspect | g.catalog.LogAuthority.append;
        _ = try context.authority.authorize(.{ .grant = .{ .object = object, .grantee = context.role, .privileges = privileges } });
        try session.begin();
        defer session.end();
        const prepared = try session.prepare(product.steps[1].sql);
        defer session.destroy(prepared);
        // The build and SQL preparation both precede revocation. Neither is an
        // authority lease: submitting the frozen emitted append must still fail.
        _ = try context.authority.authorize(.{ .revoke_privileges = .{ .object = object, .grantee = context.role, .privileges = g.catalog.LogAuthority.append } });
        if (session.write(prepared, &.{})) |_| return error.RevokedQueueAppendPassed else |err| try denied(session, err);
        _ = try context.authority.authorize(.{ .transfer_object = .{ .object = object, .owner = context.role } });
        return true;
    }
};
const Fault = struct {
    mode: enum { dropped, duplicate, reordered, terminal, timeout, memory },
    endpoint: g.wire.LocalEndpoint = undefined,
    injected: bool = false,
    fn invoke(raw: *anyopaque, invocation: *g.wire.LocalEndpoint.Invocation) !void {
        const self: *@This() = @ptrCast(@alignCast(raw));
        if (self.mode == .timeout and invocation.isRequest(w.Request)) {
            const request = try invocation.requestPtr(w.Request);
            if (request.action == .commit_saved) {
                self.injected = true;
                return error.AuthorityTimeout;
            }
        }
        try self.endpoint.invoke(self.endpoint.context, invocation);
        if (!invocation.isRequest(w.Request) or self.injected) return;
        const response: *w.Response = @ptrCast(@alignCast(invocation.output));
        if (response.result != .page or response.result.page.rows.len < 2) return;
        const page = &response.result.page;
        self.injected = true;
        switch (self.mode) {
            .dropped => return error.TestLostRead,
            .terminal => page.next = null,
            .duplicate, .reordered => {
                const rows = try invocation.allocator.dupe(w.Binary, page.rows);
                if (self.mode == .duplicate) rows[1] = rows[0] else std.mem.swap(w.Binary, &rows[0], &rows[1]);
                page.rows = rows;
            },
            else => unreachable,
        }
    }
    fn run(raw: *anyopaque, context: host.Context) !bool {
        const self: *@This() = @ptrCast(@alignCast(raw));
        if (self.mode == .memory) {
            const bytes = try context.session.allocator.alloc(u8, 256 * 1024 * 1024);
            defer context.session.allocator.free(bytes);
            return error.MemoryCapNotEnforced;
        }
        const compiler = @import("transit_compiler");
        var diagnostic: ?p.Diagnostic = null;
        const source = if (self.mode == .timeout)
            "CREATE TEST TARGET tests AS BEGIN TEST 'timeout' USING MODULES () AS BEGIN ASSERT STATEMENT (INSERT INTO items VALUES (1)) FAILS WITH 'duplicate_key'; END; END;"
        else
            "CREATE TEST TARGET tests AS BEGIN TEST 'read' USING MODULES () AS BEGIN SELECT * FROM items; END; END;";
        // Compile the real test product with its own setup, then run only its
        // body against the same setup established through the ordinary session.
        const setup = "CREATE PUBLIC TABLE items(id BIGINT PRIMARY KEY);";
        // Catalog setup belongs inside the case so its ordinary compiler can
        // bind the statement, but is executed before fault injection below.
        const text = try std.mem.replaceOwned(u8, context.session.allocator, source, "USING MODULES () AS BEGIN ", "USING MODULES () AS BEGIN " ++ setup);
        defer context.session.allocator.free(text);
        const product = try compiler.compile(context.session.allocator, &.{.{ .path = "build.transit", .text = text }}, .{ .mode = .test_suite, .target = "tests", .compiler_revision = "fault-proof" }, &diagnostic);
        defer product.deinit();
        _ = try write(context.session, "CREATE TABLE items(id BIGINT PRIMARY KEY)");
        _ = try write(context.session, "INSERT INTO items VALUES (1),(2),(3),(4),(5),(6),(7),(8),(9)");
        self.endpoint = context.endpoint;
        context.session.wire.local = .{ .context = self, .invoke = invoke };
        defer context.session.wire.local = context.endpoint;
        var case = product.cases[0];
        case.actions = case.actions[1..];
        var runner: lib.Runner = .{ .allocator = context.session.allocator, .session = context.session };
        if (runner.run(case)) |_| return error.FaultPassed else |err| {
            try require(self.injected);
            try require(if (self.mode == .timeout) err == error.AuthorityTimeout else err == error.InvalidTableResponse or err == error.TestLostRead);
        }
        return true;
    }
};
pub fn main(init: std.process.Init) !void {
    const temporary = try std.Io.Dir.cwd().openDir(init.io, "/tmp", .{ .iterate = true });
    defer temporary.close(init.io);
    var random: [16]u8 = undefined;
    var nonempty: Authority = .{ .empty = false };
    var empty: Authority = .{ .empty = true };
    var unused: u8 = 0;
    for ([_]host.Action{ .{ .context = &nonempty, .call = Authority.run }, .{ .context = &empty, .call = Authority.run }, .{ .context = &unused, .call = LostReply.run }, .{ .context = &unused, .call = WorkflowAuthority.run }, .{ .context = &unused, .call = QueueAuthority.run } }, 0..) |action, index| {
        try init.io.randomSecure(&random);
        const name = try std.fmt.allocPrint(init.arena.allocator(), "transit-test-host-{s}", .{std.fmt.bytesToHex(&random, .lower)});
        try temporary.createDir(init.io, name, .fromMode(0o700));
        const directory = try temporary.openDir(init.io, name, .{ .iterate = true });
        const path = try std.fs.path.join(init.arena.allocator(), &.{ "/tmp", name });
        const outcome = host.runAction(init, directory, path, g.wire.Deadline.init(init.io, 30000, null), action);
        directory.close(init.io);
        try temporary.deleteTree(init.io, name);
        const passed = outcome catch |err| {
            std.debug.print("host authority schedule {d}: {s}\n", .{ index, @errorName(err) });
            return err;
        };
        try require(passed);
    }
    var revoked: Authority = .{ .empty = true, .restore = false };
    var faults = [_]Fault{ .{ .mode = .dropped }, .{ .mode = .duplicate }, .{ .mode = .reordered }, .{ .mode = .terminal }, .{ .mode = .timeout }, .{ .mode = .memory } };
    for (0..faults.len + 3) |index| {
        try init.io.randomSecure(&random);
        const name = try std.fmt.allocPrint(init.arena.allocator(), "transit-test-host-{s}", .{std.fmt.bytesToHex(&random, .lower)});
        try temporary.createDir(init.io, name, .fromMode(0o700));
        const directory = try temporary.openDir(init.io, name, .{ .iterate = true });
        const path = try std.fs.path.join(init.arena.allocator(), &.{ "/tmp", name });
        var process = init;
        var failing = std.testing.FailingAllocator.init(init.gpa, .{ .fail_index = 0 });
        if (index == faults.len + 1) process.gpa = failing.allocator();
        const action: host.Action = if (index < faults.len) .{ .context = &faults[index], .call = Fault.run } else .{ .context = &revoked, .call = Authority.run };
        const outcome = if (index == faults.len + 2) host.runActionWithStorage(process, directory, path, g.wire.Deadline.init(init.io, 30000, null), action, .{ .bytes = 1, .control_bytes = 1024 * 1024 }) else host.runAction(process, directory, path, g.wire.Deadline.init(init.io, 30000, null), action);
        directory.close(init.io);
        try host.delete(init.io, temporary, name);
        // Native bootstrap reports unavailable authority when the private
        // provider cannot admit its next control transition. It is not a
        // statement constraint refusal.
        const expected: ?anyerror = if (index == faults.len + 2) error.AuthorityUnavailable else if (index == faults.len + 1) error.OutOfMemory else if (index == faults.len) error.TestReadCleanupFailed else if (faults[index].mode == .memory) error.TestMemoryLimit else null;
        if (expected) |failure| {
            if (outcome) |_| return error.ExpectedHostFailure else |err| {
                if (err != failure) {
                    std.debug.print("host schedule {d}: expected {s}, observed {s}\n", .{ index, @errorName(failure), @errorName(err) });
                    return error.ApplicationHostProofFailed;
                }
            }
        } else try require(try outcome);
    }
    const Timer = struct {
        fn wait(io: std.Io) !void {
            try io.sleep(.fromSeconds(1), .awake);
        }
    };
    if (host.bounded(void, init.io, .init(init.io, 1, null), Timer.wait, .{init.io})) |_| return error.DeadlineNotEnforced else |err| try require(err == error.TestDeadline);
    try std.Io.File.stdout().writeStreamingAll(init.io, "Application test host: denied writes, buffered/empty revocation original lost-reply recovery, corrupted reads, timeout, allocation and cleanup failures passed\n");
}
