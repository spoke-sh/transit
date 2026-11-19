//! Fault schedules against the exact listener-free CLI host and SQL sessions.
const std = @import("std");
const host = @import("transit_cli_role").ApplicationTestHost;
const lib = @import("transit_test");
const g = lib.service;
const p = g.catalog.protocol;
const w = g.catalog.DirectTableProtocol;
const contract = @import("transit_test_protocol");
const location: p.Diagnostic.Location = .{ .offset = .init(0), .length = .init(0), .line = .init(1), .byte_column = .init(1) };

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
        const row = try @import("transit_test_protocol").Assertions.rowBytes(batch.rows[0].?, prepared.native.output.?.type, &encoded);
        try require(row.len > 0);
        return true;
    }
};
const WorkflowAuthority = struct {
    fn run(_: *anyopaque, context: host.Context) !bool {
        const case: contract.Wire.Executable = .{
            .steps = &.{
                .{ .sql = "CREATE QUEUE INPUT ( ID BIGINT NOT NULL )" },
                .{ .sql = "CREATE DATAFLOW PROCESS FROM QUEUE INPUT AS REQUEST AS BEGIN REQUIRE TRUE ELSE 'No' ; END" },
                .{ .sql = "AUTHORIZE DATAFLOW PROCESS AS ROLE CURRENT_ROLE" },
                .{ .sql = "RETIRE DATAFLOW PROCESS" },
            },
            .actions = &.{ .{ .step = 0, .expectation = .complete, .location = location }, .{ .step = 1, .expectation = .complete, .location = location }, .{ .step = 2, .expectation = .complete, .location = location }, .{ .step = 3, .expectation = .complete, .location = location }, .{ .expectation = .{ .workflow = .{ .name = "process", .completed = 0, .refused = 0, .observations = 1000 } }, .location = location } },
        };
        var runner: lib.Runner = .{ .allocator = context.session.allocator, .session = context.session };
        try require((try runner.run(case)).passed);
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
        const case: contract.Wire.Executable = .{
            .steps = &.{.{ .sql = if (self.mode == .timeout) "INSERT INTO items VALUES (1)" else "SELECT * FROM items" }},
            .actions = &.{.{ .step = 0, .expectation = if (self.mode == .timeout) .{ .refusal = .duplicate_key } else .complete, .location = location }},
        };
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
