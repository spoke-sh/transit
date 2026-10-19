//! Two real Station callers. Only public framework/client interfaces are used.
const std = @import("std");
const station = @import("transit_station");
const client = station.client;
const p = client.protocol;
const g = p.Growth;
const Server = station.GenServer;
const Turn = station.Turn;
const t = std.testing;
const f = station.fuze;
const alloc = std.heap.page_allocator;
const Table = station.TableReader;
const schema: f.TableSchema.Schema = .{ .object = 1, .revision = 1, .next_column = 4, .columns = &.{
    .{ .id = 1, .name = "id", .type = .int64, .nullable = false },
    .{ .id = 2, .name = "amount", .type = .int64 },
    .{ .id = 3, .name = "label", .type = .utf8, .nullable = false },
}, .primary_key = &.{1} };
const Realm = 43;
const Count = 40;
const Expected = struct { requester: u64, writer: u64, requests: u64, rows: u64, retained_input: u64 = 0, after: u64 = 0, stale: ?client.Session.Pending = null };

const Admin = @import("growing_support.zig").Admin(Realm);

const Handler = struct {
    writer: bool,
    peer: u64,
    initialized: usize = 0,
    handled: usize = 0,
    read_failures: usize = 0,
    fn context(raw: ?*anyopaque) *Handler {
        return @ptrCast(@alignCast(raw.?));
    }
    fn initialize(raw: ?*anyopaque, _: *Turn) anyerror!void {
        const self = context(raw);
        self.initialized += 1;
    }
    fn handle(raw: ?*anyopaque, turn: *Turn, frame: station.Frame) anyerror!void {
        const self = context(raw);
        self.handled += 1;
        if (self.writer) {
            if (frame.kind == .cast and std.mem.eql(u8, frame.payload.slice(), "retain")) {
                const id = try turn.retain();
                try t.expectEqual(@as(u8, 0), id.index);
                try turn.put(try p.Value.init("retained"), p.Value.integer(@intCast(id.input)));
                return;
            }
            if (frame.kind == .cast and std.mem.eql(u8, frame.payload.slice(), "version-scan")) return scanVersion(turn);
            if (frame.kind == .cast and std.mem.eql(u8, frame.payload.slice(), "scan")) {
                var table = try Table.open(alloc, turn, 1);
                defer table.deinit();
                var cursor: ?Table.Cursor = null;
                var count: usize = 0;
                var pages: usize = 0;
                while (true) {
                    var page = try table.page(alloc, turn, cursor, 8);
                    defer page.deinit();
                    pages += 1;
                    for (page.rows[0..page.len]) |slot| {
                        try checkRow(slot.?.row(), count);
                        count += 1;
                    }
                    cursor = page.next;
                    if (cursor == null) break;
                }
                try t.expectEqual(@as(usize, Count + 1), count);
                try t.expectEqual(@as(usize, 6), pages);
                try turn.put(try p.Value.init("scanned"), p.Value.integer(@intCast(count)));
                return;
            }
            if (frame.kind == .cast and std.mem.eql(u8, frame.payload.slice(), "advance")) {
                try t.expectEqual(turn.delivery.pid, try station.Frame.source(turn.delivery.input));
                return advance(turn);
            }
            if (frame.kind != .call) return error.ExpectedCall;
            const key = try p.Value.init("pending-row");
            if (try turn.read(key) != null) return error.PreviousCallPending;
            // This proof sends one call at a time. Persist its original input,
            // authenticated reply destination and correlation before resuming.
            var pending: [32]u8 = undefined;
            std.mem.writeInt(u64, pending[0..8], turn.delivery.input.position, .little);
            std.mem.writeInt(u64, pending[8..16], try station.Frame.source(turn.delivery.input), .little);
            std.mem.writeInt(u64, pending[16..24], frame.correlation, .little);
            std.mem.writeInt(i64, pending[24..32], try frame.payload.asInteger(), .little);
            try turn.put(key, try p.Value.init(&pending));
            try turn.cast(turn.delivery.pid, try p.Value.init("advance"));
        } else switch (frame.kind) {
            .cast => {
                // The proxy corrupts this read once. Swallowing that transport
                // error must still prevent private writes/outputs from committing.
                _ = turn.read(try p.Value.init("read-fault")) catch blk: {
                    self.read_failures += 1;
                    break :blk null;
                };
                try turn.put(try p.Value.init("attempt"), frame.payload);
                if (turn.read_error != null) {
                    try turn.cast(self.peer, frame.payload);
                    return;
                }
                _ = try turn.call(self.peer, frame.payload, null);
            },
            .reply => {
                try t.expectEqual(.replied, (try turn.waiting(frame.correlation)).?.phase);
                try turn.put(try p.Value.init("last"), frame.payload);
            },
            else => return error.UnexpectedFrame,
        }
    }
    fn advance(turn: *Turn) !void {
        const key = try p.Value.init("pending-row");
        const saved = (try turn.read(key)) orelse return error.MissingPendingCall;
        if (saved.len != 32) return error.InvalidPendingCall;
        const creation = try station.TableCreation.step(alloc, turn, schema, .{ .record_bytes = 65536, .staging_bytes = 8 * 1024 * 1024, .staging_records = 1024 });
        if (creation.state == .building or creation.completed_input == turn.delivery.input.position) {
            return turn.cast(turn.delivery.pid, try p.Value.init("advance"));
        }
        const index = std.mem.readInt(i64, saved.data[24..32], .little);
        const cells: [3]f.Types.Values.Cell = .{ .{ .value = .{ .atom = .{ .signed = index } } }, .{ .value = .{ .atom = .{ .signed = index * 2 } } }, .{ .value = .{ .atom = .{ .bytes = "retained" } } } };
        var request: station.TableWrite.Request = .{ .resource = turn.view.resource, .principal = 0, .operation = std.mem.readInt(u64, saved.data[0..8], .little), .schema = schema, .change = undefined };
        request.change = .{ .insert = .{ .identity = try request.insertIdentity(), .cells = &cells } };
        const status = try station.TableWrite.step(alloc, turn, request);
        var writes: usize = 0;
        for (turn.decision.mutations) |slot| writes += @intFromBool(slot != null);
        if (status.state == .building or writes == turn.decision.mutations.len) {
            return turn.cast(turn.delivery.pid, try p.Value.init("advance"));
        }
        try t.expectEqual(.applied, status.state);
        try t.expectEqual(@as(u64, 1), status.changed);
        try turn.delete(key);
        try turn.send(std.mem.readInt(u64, saved.data[8..16], .little), .{ .kind = .reply, .correlation = std.mem.readInt(u64, saved.data[16..24], .little), .payload = p.Value.integer(index * 2) });
    }
    fn interface(self: *Handler) Server.Handler {
        return .{ .context = self, .initialize = initialize, .handle = handle };
    }
    fn scanVersion(turn: *Turn) !void {
        const input = try (try turn.read(try p.Value.init("retained"))).?.asInteger();
        var source = try turn.openVersion(.{ .pid = turn.delivery.pid, .input = @intCast(input), .index = 0 });
        var table = try Table.open(alloc, &source, 1);
        defer table.deinit();
        const progress_key = try p.Value.init("version-progress");
        const progress = try turn.read(progress_key);
        var count: u64 = 0;
        var after: f.TableRow.Identity = undefined;
        if (progress) |value| {
            if (value.len != 28) return error.InvalidScanProgress;
            count = std.mem.readInt(u64, value.data[0..8], .little);
            after = try f.TableRow.Identity.decode(value.data[8..28]);
            try t.expectEqual(turn.delivery.pid, try station.Frame.source(turn.delivery.input));
        }
        const cursor: ?Table.Cursor = if (progress != null) .{ .basis = table.basis, .after = after } else null;
        var page = try table.page(alloc, &source, cursor, 8);
        defer page.deinit();
        for (page.rows[0..page.len]) |slot| {
            try checkRow(slot.?.row(), count);
            count += 1;
            after = slot.?.identity;
        }
        var saved: [28]u8 = undefined;
        std.mem.writeInt(u64, saved[0..8], count, .little);
        saved[8..28].* = try after.encode();
        try turn.put(progress_key, try p.Value.init(&saved));
        if (page.next != null) {
            try turn.cast(turn.delivery.pid, try p.Value.init("version-scan"));
        } else {
            try t.expectEqual(@as(u64, Count), count); // Excludes the later 41st row.
            try turn.put(try p.Value.init("version-scanned"), p.Value.integer(@intCast(count)));
            try turn.release(source.view.id);
        }
    }
};

fn deadline(io: std.Io) u64 {
    return @as(u64, @intCast(std.Io.Clock.real.now(io).toMilliseconds())) + 30000;
}
fn gatedStep(server: *Server, handler: Server.Handler, read_deadline: u64) !Server.Poll {
    if (server.pending != null) {
        // A persistence callback can fail/retry here without sending anything.
        // Native unit tests also exercise permit/open/commit with no I/O client.
        const frozen = server.pending.?.signed;
        try t.expectEqual(.progress, try server.prepare(read_deadline));
        try t.expect(std.meta.eql(frozen, server.pending.?.signed));
        try t.expectError(error.PendingOperation, server.discard());
        const input = server.delivery.?.input.position;
        const result = try server.dispatchPending();
        try t.expect(server.pending == null and server.confirmation != null);
        try t.expectEqual(input, server.confirmation.?.input);
        try t.expect(server.confirmation.?.receipt.position > 0);
        return result;
    }
    const result = try server.prepare(read_deadline);
    if (result != .ready) return result;
    var failure: ?anyerror = null;
    if (server.initializing) if (handler.initialize) |initialize| initialize(handler.context, &server.ready.?) catch |err| {
        failure = err;
    };
    if (failure == null) handler.handle(handler.context, &server.ready.?, try station.Frame.decode(server.ready.?.delivery.input.value)) catch |err| {
        failure = err;
    };
    try server.finish(failure);
    return .progress;
}
fn drive(io: std.Io, server: *Server, handler: *Handler, prepare_only: bool) !usize {
    var lost: usize = 0;
    for (0..24) |_| {
        if (prepare_only and server.pending != null and server.pending_kind == .commit) return lost;
        const before = handler.handled;
        const result = gatedStep(server, handler.interface(), deadline(io)) catch |err| {
            if (err != error.InvalidAuthorityResponse) return err;
            if (server.pending) |pending| {
                try t.expectEqual(.turn, std.meta.activeTag(pending.signed.request.command));
                try t.expectEqual(before, handler.handled);
                lost += 1;
            } else {
                try t.expect(server.ready == null and server.view_id != null);
                try t.expectEqual(@as(usize, 1), handler.read_failures);
            }
            continue;
        };
        switch (result) {
            .committed => return lost,
            .blocked => return error.BehaviorBlocked,
            .idle => return error.MissingInput,
            .progress => {},
            .ready => unreachable,
        }
    }
    return error.StepBudgetExceeded;
}
fn makeServer(wire: *client.Client, principal: u64, pid: u64, generation: u64, key: p.Ed25519.KeyPair) !Server {
    return Server.init(.{ .client = wire, .realm = Realm, .principal = principal, .pid = pid, .generation = generation, .key = key }, "state");
}
fn verify(admin: *Admin, expected: Expected, count: usize) !void {
    const process = (try admin.query(.{ .process = expected.requester })).body.process;
    try t.expect(process.input == null);
    try t.expectEqual(@as(u64, count * 2), process.process.consumed);
    const requests = (try admin.query(.{ .resource = expected.requests })).body.resource;
    try t.expectEqual(@as(u64, count + 3), requests.entries); // descriptor, attempt, last, waits
    var after: ?p.Value = null;
    var waits: usize = 0;
    while (true) {
        const page = (try admin.query(.{ .entries = .{ .resource = requests.id, .revision = requests.revision, .after = after } })).body.entries.page;
        for (page.entries) |slot| if (slot) |entry| {
            if (entry.key.len == 10 and std.mem.eql(u8, entry.key.data[0..2], "\x00w")) {
                const wait = try Turn.Wait.decode(entry.value);
                try t.expectEqual(.replied, wait.phase);
                try t.expectEqual(expected.writer, wait.target);
                waits += 1;
            }
        };
        after = page.next;
        if (after == null) break;
    }
    try t.expectEqual(count, waits);
    const rows = (try admin.query(.{ .resource = expected.rows })).body.resource;
    const Source = struct {
        admin: *Admin,
        view: struct { id: u64 = 0, resource: u64, revision: u64 },
        pub fn prefetchBlocks(_: *@This(), _: []const p.Value) !void {}
        pub fn readBlock(self: *@This(), key: p.Value, output: []u8) !?[]const u8 {
            const query: p.Growth.BlockRead.Query = .{ .source = .{ .resource = .{ .id = self.view.resource, .revision = self.view.revision } }, .keys = .{ key, null, null, null, null, null, null, null } };
            const response = try self.admin.wire.queryBlocks(.{ .realm = Realm, .principal = 0, .kind = .{ .block_entries = query } }, self.admin.key);
            const block_batch = try client.BlockBatch.init(query.keys, response.response.body.block_entries.entries, response.blocks);
            return block_batch.read(key, output);
        }
        pub fn read(self: *@This(), key: p.Value) !?p.Value {
            const page = (try self.admin.query(.{ .entries = .{ .resource = self.view.resource, .revision = self.view.revision, .key = key } })).body.entries.page;
            return if (page.entries[0]) |entry| entry.value else null;
        }
    };
    var source: Source = .{ .admin = admin, .view = .{ .resource = rows.id, .revision = rows.revision } };
    var table = try Table.open(alloc, &source, 1);
    defer table.deinit();
    try t.expectEqual(count, table.head.rows);
    for (0..count) |i| {
        var row = (try table.getKey(alloc, &source, &.{.{ .value = .{ .atom = .{ .signed = @intCast(i) } } }})).?;
        defer row.deinit();
        try checkRow(row.row(), i);
    }
}

fn checkRow(row: f.TableRow.Row, index: u64) !void {
    try t.expectEqual(3, row.cells.len);
    try t.expectEqual(@as(i128, @intCast(index)), row.cells[0].value.atom.signed);
    try t.expectEqual(@as(i128, @intCast(index * 2)), row.cells[1].value.atom.signed);
    try t.expectEqualStrings("retained", row.cells[2].value.atom.bytes);
}
fn deliver(admin: *Admin, after: *u64) !g.Outbox {
    const position = (try admin.query(.{ .capabilities = {} })).position;
    const item = (try admin.query(.{ .outputs = .{ .after = if (after.* == 0) null else after.*, .position = position } })).body.outputs.entries[0] orelse return error.MissingOutput;
    try t.expectEqual(.pending, item.phase);
    _ = try admin.submit(.{ .deliver = item.id });
    after.* = item.id;
    return item;
}
fn finishCall(io: std.Io, admin: *Admin, after: *u64, writer: *Server, writer_handler: *Handler, requester: *Server, requester_handler: *Handler) !usize {
    var lost: usize = 0;
    for (0..256) |_| {
        const item = try deliver(admin, after);
        if (item.destination == requester.session.pid) {
            lost += try drive(io, requester, requester_handler, false);
            return lost;
        }
        try t.expectEqual(writer.session.pid, item.destination);
        lost += try drive(io, writer, writer_handler, false);
    }
    return error.TableContinuationBudgetExceeded;
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const root_key = try p.Ed25519.KeyPair.generateDeterministic(@splat(7));
    var output_buffer: [4096]u8 = undefined;
    var output = std.Io.File.stdout().writerStreaming(init.io, &output_buffer);
    if (args.len == 2 and std.mem.eql(u8, args[1], "public")) {
        try std.json.Stringify.value(root_key.public_key.toBytes(), .{}, &output.interface);
        return output.interface.flush();
    }
    if (args.len != 4) return error.Usage;
    var wire = client.Client.init(init.gpa, init.io, args[1]);
    defer wire.deinit();
    wire.timeout_ms = 10000;
    var admin: Admin = .{ .wire = &wire, .key = root_key };
    admin.sequence = (try admin.query(.{ .capabilities = {} })).principal_sequence;
    if (std.mem.startsWith(u8, args[2], "views")) return @import("growing_views.zig").run(init, &wire, args[2], args[3]);
    const requester_key = try p.Ed25519.KeyPair.generateDeterministic(@splat(8));
    const writer_key = try p.Ed25519.KeyPair.generateDeterministic(@splat(9));
    if (std.mem.eql(u8, args[2], "write")) {
        const requester = try admin.provision(65536, requester_key);
        const writer = try admin.provision(65537, writer_key);
        var request_server = try makeServer(&wire, 65536, requester.pid, 2, requester_key);
        var write_server = try makeServer(&wire, 65537, writer.pid, 2, writer_key);
        var request_handler: Handler = .{ .writer = false, .peer = writer.pid };
        var write_handler: Handler = .{ .writer = true, .peer = requester.pid };
        var lost: usize = 0;
        var after: u64 = 0;
        for (0..Count) |i| {
            try admin.send(requester.pid, @intCast(i));
            lost += try drive(init.io, &request_server, &request_handler, false);
            lost += try finishCall(init.io, &admin, &after, &write_server, &write_handler, &request_server, &request_handler);
        }
        try t.expectEqual(@as(usize, 1), lost);
        try t.expectEqual(@as(usize, 1), request_handler.read_failures);
        try t.expectEqual(@as(usize, 2), request_handler.initialized); // first private attempt failed its read
        try t.expectEqual(@as(usize, 1), write_handler.initialized);
        try t.expectEqual(@as(usize, Count * 2 + 1), request_handler.handled);
        try t.expect(write_handler.handled > Count); // Committed Table continuations.
        var expected: Expected = .{ .requester = requester.pid, .writer = writer.pid, .requests = requester.resource, .rows = writer.resource };
        try verify(&admin, expected, Count);
        expected.retained_input = try admin.submit(.{ .send = .{ .pid = writer.pid, .value = try (station.Frame{ .kind = .cast, .payload = try p.Value.init("retain") }).encode() } });
        _ = try drive(init.io, &write_server, &write_handler, false);
        try admin.send(requester.pid, Count);
        _ = try drive(init.io, &request_server, &request_handler, false);
        _ = try deliver(&admin, &after);
        _ = try drive(init.io, &write_server, &write_handler, false); // Original call admission.
        _ = try deliver(&admin, &after);
        _ = try drive(init.io, &write_server, &write_handler, true); // Unsent native Table step.
        expected.after = after;
        expected.stale = write_server.pending.?;
        const bytes = try std.json.Stringify.valueAlloc(init.gpa, expected, .{});
        defer init.gpa.free(bytes);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = args[3], .data = bytes });
    } else if (std.mem.eql(u8, args[2], "recover") or std.mem.eql(u8, args[2], "resume")) {
        const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, args[3], init.gpa, .limited(client.max_body));
        defer init.gpa.free(bytes);
        const parsed = try std.json.parseFromSlice(Expected, init.gpa, bytes, .{});
        defer parsed.deinit();
        var expected = parsed.value;
        if (std.mem.eql(u8, args[2], "resume")) {
            _ = try admin.submit(.{ .own = .{ .pid = expected.writer, .expected_generation = 3, .worker = 65537 } });
            var server = try makeServer(&wire, 65537, expected.writer, 4, writer_key);
            var handler: Handler = .{ .writer = true, .peer = expected.requester };
            var complete = false;
            for (0..6) |_| {
                _ = try deliver(&admin, &expected.after);
                _ = try drive(init.io, &server, &handler, false);
                const resource = (try admin.query(.{ .resource = expected.rows })).body.resource;
                const value = (try admin.query(.{ .entries = .{ .resource = resource.id, .revision = resource.revision, .key = try p.Value.init("version-scanned") } })).body.entries.page.entries[0];
                if (value) |entry| {
                    try t.expectEqual(@as(i64, Count), try entry.value.asInteger());
                    complete = true;
                    break;
                }
            }
            try t.expect(complete and handler.initialized == 0);
            const id: g.ReadVersionId = .{ .pid = expected.writer, .input = expected.retained_input, .index = 0 };
            const version = try server.session.version(id);
            try t.expect(version.released_at != null);
            try t.expectError(error.Rejected, wire.query(.{ .realm = Realm, .principal = 65537, .kind = .{ .version_entries = .{ .id = id, .generation = 4 } } }, writer_key));
            try t.expectEqual(.ReadVersionReleased, wire.last_rejection.?);
            try output.interface.writeAll("Growing Station resume: passed\n");
            return output.interface.flush();
        }
        _ = try admin.submit(.{ .own = .{ .pid = expected.requester, .expected_generation = 2, .worker = 65536 } });
        _ = try admin.submit(.{ .own = .{ .pid = expected.writer, .expected_generation = 2, .worker = 65537 } });
        try t.expectError(error.Rejected, expected.stale.?.submit(&wire));
        try t.expectEqual(.StaleGeneration, wire.last_rejection.?);
        var request_server = try makeServer(&wire, 65536, expected.requester, 3, requester_key);
        var write_server = try makeServer(&wire, 65537, expected.writer, 3, writer_key);
        var request_handler: Handler = .{ .writer = false, .peer = expected.writer };
        var write_handler: Handler = .{ .writer = true, .peer = expected.requester };
        _ = try drive(init.io, &write_server, &write_handler, false);
        _ = try finishCall(init.io, &admin, &expected.after, &write_server, &write_handler, &request_server, &request_handler);
        try t.expectEqual(@as(usize, 0), request_handler.initialized + write_handler.initialized);
        try t.expectEqual(@as(usize, 1), request_handler.handled);
        // The unsent Table successor fits one bulk turn after recovery.
        try t.expectEqual(@as(usize, 1), write_handler.handled);
        try verify(&admin, expected, Count + 1);
        _ = try admin.submit(.{ .send = .{ .pid = expected.writer, .value = try (station.Frame{ .kind = .cast, .payload = try p.Value.init("scan") }).encode() } });
        _ = try drive(init.io, &write_server, &write_handler, false);
        const resource = (try admin.query(.{ .resource = expected.rows })).body.resource;
        const scanned = (try admin.query(.{ .entries = .{ .resource = resource.id, .revision = resource.revision, .key = try p.Value.init("scanned") } })).body.entries.page.entries[0].?;
        try t.expectEqual(@as(i64, Count + 1), try scanned.value.asInteger());
        _ = try admin.submit(.{ .send = .{ .pid = expected.writer, .value = try (station.Frame{ .kind = .cast, .payload = try p.Value.init("version-scan") }).encode() } });
        _ = try drive(init.io, &write_server, &write_handler, false);
        const saved = try std.json.Stringify.valueAlloc(init.gpa, expected, .{});
        defer init.gpa.free(saved);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = args[3], .data = saved });
        // One source page/progress/output committed. The harness loses this
        // caller and both services before delivering its self-continuation.
    } else return error.UnknownPhase;
    try output.interface.print("Growing Station {s}: passed\n", .{args[2]});
    try output.interface.flush();
}
