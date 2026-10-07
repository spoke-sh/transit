//! Growing query callers use only Station/client APIs. Python independently
//! checks the captured IPC and restarts the real node and disk-backed provider.
const std = @import("std");
const station = @import("transit_station");
const client = station.client;
const p = station.protocol;
const g = p.Growth;
const q = station.Query;
const f = station.fuze;
const Server = station.GenServer;
const Turn = station.Turn;
const t = std.testing;
const Realm = 44;
const Count = 41;
const Admin = @import("growing_support.zig").Admin(Realm);
const Expected = struct { service: u64, requester: u64, resource: u64, requests: u64, result: u64, correlation: u64, output: u64, generation: u64 = 2, requester_generation: u64 = 2 };
const schema: f.TableSchema.Schema = .{ .object = 1, .revision = 1, .next_column = 3, .columns = &.{
    .{ .id = 1, .name = "id", .type = .int64, .nullable = false },
    .{ .id = 2, .name = "value", .type = .utf8 },
}, .primary_key = &.{1} };
const Handler = struct {
    allocator: std.mem.Allocator,
    table_ready: bool = false,
    write_done: bool = false,
    writer: bool,
    peer: u64,
    result: u64 = 0,
    initialized: usize = 0,
    handled: usize = 0,
    completed: usize = 0,
    uncertain_cancellations: usize = 0,
    cancellation: f.execution.Cancellation = .init(false),
    workspace: [f.execution.working_bytes]u8 = undefined,
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
        if (!self.writer) {
            if (frame.kind == .result_complete) {
                const manifest = try q.completed(turn, frame.correlation);
                try t.expectEqual(@as(u64, Count), manifest.rows);
                try turn.put(try p.Value.init("completed"), frame.payload);
                self.completed += 1;
                return;
            }
            if (frame.kind != .cast) return error.UnexpectedFrame;
            self.result = try turn.call(self.peer, try p.Value.init("all"), null);
            return;
        }
        if (frame.kind == .call) {
            var table = try station.TableReader.open(self.allocator, turn, schema.object);
            defer table.deinit();
            var fields: [f.TableSchema.max_columns]f.Types.Field = undefined;
            const job = try q.start(turn, &table, .{ .schema = try table.schema.schema.rowType(&fields), .source_basis = table.basis.head, .projection = &.{ 0, 1 } });
            self.result = job.result;
            return;
        }
        if (frame.kind != .cast) return error.UnexpectedFrame;
        if (std.mem.eql(u8, frame.payload.slice(), "publish")) return q.beginPublication(turn, self.result);
        if (std.mem.eql(u8, frame.payload.slice(), "init")) {
            const created = try station.TableCreation.step(self.allocator, turn, schema, .{ .record_bytes = 65536, .staging_bytes = 8 * 1024 * 1024, .staging_records = 1024 });
            self.table_ready = created.state == .applied;
            if (self.table_ready) try q.setPolicy(turn, self.peer, schema.object, 0, true);
            return;
        }
        if (std.mem.startsWith(u8, frame.payload.slice(), "GQC1")) {
            const cancel = f.execution.Cancellation.init(false);
            _ = try q.advance(self.allocator, turn, try q.Continuation.decode(frame.payload), &self.workspace, &cancel);
            return;
        }
        const i: usize = @intCast(try frame.payload.asInteger());
        const text: [220]u8 = @splat(@as(u8, @intCast('a' + i % 26)));
        const cells = [_]f.Types.Values.Cell{
            .{ .value = .{ .atom = .{ .signed = @intCast(i) } } },
            if (i % 5 == 0) .null else .{ .value = .{ .atom = .{ .bytes = &text } } },
        };
        var write: station.TableWrite.Request = .{ .resource = turn.view.resource, .principal = 65536, .operation = i + 1, .schema = schema, .change = undefined };
        write.change = .{ .insert = .{ .identity = try write.insertIdentity(), .cells = &cells } };
        const state = try station.TableWrite.step(self.allocator, turn, write);
        try t.expect(state.state == .building or state.state == .applied);
        self.write_done = state.state == .applied;
    }
    fn interface(self: *Handler) Server.Handler {
        return .{ .context = self, .initialize = initialize, .handle = handle };
    }
    fn configure(self: *Handler, host: *Server) void {
        host.query = .{ .allocator = self.allocator, .workspace = &self.workspace, .cancellation = &self.cancellation };
    }
};
fn deadline(io: std.Io) u64 {
    return @as(u64, @intCast(std.Io.Clock.real.now(io).toMilliseconds())) + 30000;
}
fn drive(io: std.Io, server: *Server, handler: *Handler) !void {
    for (0..24) |_| {
        const before = handler.handled;
        const step = server.step(handler.interface(), deadline(io)) catch |err| {
            if (err != error.InvalidAuthorityResponse or server.pending == null) return err;
            try t.expectEqual(before, handler.handled); // Lost receipt never reruns a handler.
            if (server.query != null) {
                // Cancellation after an uncertain submit cannot discard it.
                handler.cancellation.store(true, .release);
                handler.uncertain_cancellations += 1;
            }
            continue;
        };
        switch (step) {
            .committed => {
                handler.cancellation.store(false, .release);
                return;
            },
            .blocked => return server.handler_error orelse error.BehaviorBlocked,
            .idle => return error.MissingInput,
            .progress => {},
        }
    }
    return error.StepBudgetExceeded;
}
fn makeServer(wire: *client.Client, principal: u64, pid: u64, generation: u64, key: p.Ed25519.KeyPair) !Server {
    return Server.init(.{ .client = wire, .realm = Realm, .principal = principal, .pid = pid, .generation = generation, .key = key }, "state");
}
fn deliver(admin: *Admin, after: *u64) !void {
    _ = try deliverMessage(admin, after);
}
fn deliverMessage(admin: *Admin, after: *u64) !g.Outbox {
    const position = (try admin.query(.{ .capabilities = {} })).position;
    const output = (try admin.query(.{ .outputs = .{ .after = if (after.* == 0) null else after.*, .position = position } })).body.outputs.entries[0] orelse return error.MissingOutput;
    try t.expect(output.phase == .pending);
    _ = try admin.submit(.{ .deliver = output.id });
    after.* = output.id;
    return output;
}
fn value(admin: *Admin, resource: u64, key: p.Value) !?p.Value {
    const metadata = (try admin.query(.{ .resource = resource })).body.resource;
    const entry = (try admin.query(.{ .entries = .{ .resource = resource, .revision = metadata.revision, .key = key } })).body.entries.page.entries[0];
    return if (entry) |item| item.value else null;
}
fn save(init: std.process.Init, path: []const u8, expected: Expected) !void {
    const bytes = try std.json.Stringify.valueAlloc(init.gpa, expected, .{});
    defer init.gpa.free(bytes);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = bytes });
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
    const writer_key = try p.Ed25519.KeyPair.generateDeterministic(@splat(8));
    const requester_key = try p.Ed25519.KeyPair.generateDeterministic(@splat(9));
    if (std.mem.eql(u8, args[2], "write")) {
        const writer = try admin.provision(65536, writer_key);
        const requester = try admin.provision(65537, requester_key);
        var write_server = try makeServer(&wire, 65536, writer.pid, 2, writer_key);
        var request_server = try makeServer(&wire, 65537, requester.pid, 2, requester_key);
        var handler: Handler = .{ .allocator = init.gpa, .writer = true, .peer = requester.pid };
        var request_handler: Handler = .{ .allocator = init.gpa, .writer = false, .peer = writer.pid };
        for (0..64) |_| {
            _ = try admin.submit(.{ .send = .{ .pid = writer.pid, .value = try (station.Frame{ .kind = .cast, .payload = try p.Value.init("init") }).encode() } });
            try drive(init.io, &write_server, &handler);
            if (handler.table_ready) break;
        }
        try t.expect(handler.table_ready);
        for (0..Count) |i| {
            handler.write_done = false;
            for (0..64) |_| {
                try admin.send(writer.pid, @intCast(i));
                try drive(init.io, &write_server, &handler);
                if (handler.write_done) break;
            }
            try t.expect(handler.write_done);
        }
        try admin.send(requester.pid, 0);
        try drive(init.io, &request_server, &request_handler);
        var after: u64 = 0;
        try deliver(&admin, &after);
        try drive(init.io, &write_server, &handler); // Start retains source with the frozen plan and job.
        try deliver(&admin, &after);
        try drive(init.io, &write_server, &handler); // First three fragments, not a sealed segment.
        const stage = try q.records.Stage.decode((try value(&admin, writer.resource, q.records.key('s', handler.result, 0, 0))).?);
        try t.expect(stage.written == 3 * q.records.fragment_bytes and stage.written < stage.segment.bytes);
        try t.expect((try value(&admin, writer.resource, q.records.key('e', handler.result, 0, 0))) == null);
        try save(init, args[3], .{ .service = writer.pid, .requester = requester.pid, .resource = writer.resource, .requests = requester.resource, .result = handler.result, .correlation = request_handler.result, .output = after });
    } else if (std.mem.eql(u8, args[2], "seal") or std.mem.eql(u8, args[2], "recover")) {
        const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, args[3], init.gpa, .limited(8192));
        defer init.gpa.free(bytes);
        const parsed = try std.json.parseFromSlice(Expected, init.gpa, bytes, .{});
        defer parsed.deinit();
        var expected = parsed.value;
        _ = try admin.submit(.{ .own = .{ .pid = expected.service, .expected_generation = expected.generation, .worker = 65536 } });
        expected.generation += 1;
        var write_server = try makeServer(&wire, 65536, expected.service, expected.generation, writer_key);
        var handler: Handler = .{ .allocator = init.gpa, .writer = true, .peer = expected.requester };
        var captured = false;
        for (0..256) |_| {
            try deliver(&admin, &expected.output);
            try drive(init.io, &write_server, &handler);
            const saved_progress = (try value(&admin, expected.resource, q.records.key('e', expected.result, 0, 0))) orelse continue;
            const progress = try f.LogicalStream.Progress.decodeRecord(saved_progress.slice());
            if (std.mem.eql(u8, args[2], "seal") and progress.segments == 1) {
                try t.expectEqual(@as(u64, 1), progress.pages);
                try t.expect(progress.finished == null);
                try save(init, args[3], expected);
                captured = true; // This phase intentionally stops after one sealed segment.
                break;
            }
            if (progress.finished != null) {
                try t.expectEqual(@as(u64, Count), progress.rows);
                try t.expectEqual(@as(u64, 6), progress.segments);
                captured = true;
                break;
            }
        }
        try t.expect(captured and handler.initialized == 0);
        if (std.mem.eql(u8, args[2], "recover")) {
            const version = try write_server.session.version(.{ .pid = expected.service, .input = expected.result, .index = 0 });
            try t.expect(version.released_at != null);
            try t.expectError(error.Rejected, wire.query(.{ .realm = Realm, .principal = 65536, .kind = .{ .version_entries = .{ .id = version.id, .generation = expected.generation } } }, writer_key));
            try t.expectEqual(.ReadVersionReleased, wire.last_rejection.?);
            _ = try admin.submit(.{ .send = .{ .pid = expected.service, .value = try (station.Frame{ .kind = .cast }).encode() } });
            for (0..24) |_| {
                const state = try write_server.poll(deadline(init.io));
                if (state == .ready) break;
                try t.expectEqual(Server.Poll.progress, state);
            }
            const turn = if (write_server.ready) |*ready| ready else return error.NoPreparedTurn;
            const result = try q.captured(turn, expected.result);
            var buffer: [q.records.segment_bytes]u8 = undefined;
            var manifests: [6]q.Segment = undefined;
            var path_buffer: [4096]u8 = undefined;
            for (&manifests, 0..) |*manifest, ordinal| {
                const segment = try q.capturedSegment(turn, expected.result, ordinal, &buffer);
                manifest.* = segment.manifest;
                const path = try std.fmt.bufPrint(&path_buffer, "{s}.{d}.arrow", .{ args[3], ordinal });
                try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = segment.bytes });
            }
            const job_record = try result.job.encode();
            const job_hex = std.fmt.bytesToHex(job_record.data[0..152].*, .lower);
            const progress_hex = std.fmt.bytesToHex(try result.progress.encodeRecord(), .lower);
            const report = try std.json.Stringify.valueAlloc(init.gpa, .{ .job = result.job, .job_wire = job_hex[0..], .progress = result.progress, .progress_wire = progress_hex[0..], .segments = manifests }, .{});
            defer init.gpa.free(report);
            const path = try std.fmt.bufPrint(&path_buffer, "{s}.result.json", .{args[3]});
            try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = report });
            try write_server.finish(null);
            try drive(init.io, &write_server, &handler);
            const wait = try Turn.Wait.decode((try value(&admin, expected.requests, Turn.waitKey(expected.correlation))).?);
            try t.expectEqual(.waiting, wait.phase); // Capture is not delivery/acknowledgement.
            try save(init, args[3], expected);
        }
    } else if (std.mem.eql(u8, args[2], "publish") or std.mem.eql(u8, args[2], "deliver")) {
        const saved = try std.Io.Dir.cwd().readFileAlloc(init.io, args[3], init.gpa, .limited(8192));
        defer init.gpa.free(saved);
        const parsed = try std.json.parseFromSlice(Expected, init.gpa, saved, .{});
        defer parsed.deinit();
        var expected = parsed.value;
        _ = try admin.submit(.{ .own = .{ .pid = expected.service, .expected_generation = expected.generation, .worker = 65536 } });
        expected.generation += 1;
        _ = try admin.submit(.{ .own = .{ .pid = expected.requester, .expected_generation = expected.requester_generation, .worker = 65537 } });
        expected.requester_generation += 1;
        var sender = try makeServer(&wire, 65536, expected.service, expected.generation, writer_key);
        var receiver = try makeServer(&wire, 65537, expected.requester, expected.requester_generation, requester_key);
        var send_handler: Handler = .{ .allocator = init.gpa, .writer = true, .peer = expected.requester, .result = expected.result };
        var receive_handler: Handler = .{ .allocator = init.gpa, .writer = false, .peer = expected.service };
        send_handler.configure(&sender);
        receive_handler.configure(&receiver);
        const stopping = std.mem.eql(u8, args[2], "publish");
        if (stopping) {
            _ = try admin.submit(.{ .send = .{ .pid = expected.service, .value = try (station.Frame{ .kind = .cast, .payload = try p.Value.init("publish") }).encode() } });
            try drive(init.io, &sender, &send_handler);
        }
        var fragments: usize = 0;
        var done = false;
        var cancellation_checked = false;
        for (0..192) |_| {
            const message = try deliverMessage(&admin, &expected.output);
            const frame = try station.Frame.decode(message.value);
            if (message.destination == expected.service) {
                if (stopping and !cancellation_checked) {
                    send_handler.cancellation.store(true, .release);
                    try t.expectError(error.Cancelled, drive(init.io, &sender, &send_handler));
                    try t.expect(sender.pending == null and sender.ready == null);
                    const still_pending = (try admin.query(.{ .process = expected.service })).body.process;
                    try t.expect(still_pending.input != null and still_pending.process.failure == null);
                    send_handler.cancellation.store(false, .release);
                    cancellation_checked = true;
                }
                try drive(init.io, &sender, &send_handler);
                if (frame.kind == .result_ack) {
                    done = true;
                    break;
                }
            } else {
                try t.expectEqual(expected.requester, message.destination);
                try drive(init.io, &receiver, &receive_handler);
                if (frame.kind == .result_chunk and std.mem.startsWith(u8, frame.payload.slice(), "GQF1")) fragments += 1;
                if (stopping and fragments == 2) {
                    const transfer = try q.records.Transfer.decode((try value(&admin, expected.requests, q.records.key('r', expected.correlation, 0, 0))).?);
                    try t.expect(transfer.pending == 2 * q.records.fragment_bytes and transfer.segments == 0);
                    const wait = try Turn.Wait.decode((try value(&admin, expected.requests, Turn.waitKey(expected.correlation))).?);
                    try t.expectEqual(.waiting, wait.phase);
                    try t.expect(cancellation_checked and send_handler.uncertain_cancellations == 1 and receive_handler.uncertain_cancellations == 1);
                    try save(init, args[3], expected);
                    done = true;
                    break;
                }
            }
        }
        try t.expect(done and send_handler.initialized == 0 and receive_handler.initialized == 0);
        if (!stopping) {
            try t.expectEqual(@as(usize, 1), receive_handler.completed);
            const job = try q.Job.decode((try value(&admin, expected.resource, q.records.key('j', expected.result, 0, 0))).?);
            try t.expectEqual(q.records.Phase.acknowledged, job.phase);
            _ = try admin.submit(.{ .send = .{ .pid = expected.requester, .value = try (station.Frame{ .kind = .cast }).encode() } });
            for (0..24) |_| {
                const state = try receiver.poll(deadline(init.io));
                if (state == .ready) break;
                try t.expectEqual(Server.Poll.progress, state);
            }
            const turn = if (receiver.ready) |*ready| ready else return error.NoPreparedTurn;
            const result = try q.completed(turn, expected.correlation);
            var buffer: [q.records.segment_bytes]u8 = undefined;
            var manifests: [6]q.Segment = undefined;
            var path_buffer: [4096]u8 = undefined;
            for (&manifests, 0..) |*manifest, ordinal| {
                const segment = try q.completedSegment(turn, expected.correlation, ordinal, &buffer);
                manifest.* = segment.manifest;
                const path = try std.fmt.bufPrint(&path_buffer, "{s}.received.{d}.arrow", .{ args[3], ordinal });
                try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = segment.bytes });
            }
            const report = try std.json.Stringify.valueAlloc(init.gpa, .{ .manifest = result, .segments = manifests }, .{});
            defer init.gpa.free(report);
            const path = try std.fmt.bufPrint(&path_buffer, "{s}.received.json", .{args[3]});
            try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = report });
            try receiver.finish(null);
            try drive(init.io, &receiver, &receive_handler);
            try t.expectEqual(@as(usize, 1), receive_handler.completed);
        }
    } else return error.UnknownPhase;
    try output.interface.print("Growing query {s}: passed\n", .{args[2]});
    try output.interface.flush();
}
