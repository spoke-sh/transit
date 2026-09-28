//! Provision a real Table using public APIs. The actual shell and daemon are
//! separate executables exercised by public_query.py, never test-only handlers.
const std = @import("std");
const q = @import("transit_query");
const serving = @import("transit_serving");
const s = @import("transit_station");
const p = s.protocol;
const Admin = @import("growing_support.zig").Admin(45);
const Seed = struct {
    peer: u64,
    fn initialize(raw: ?*anyopaque, turn: *s.GrowingTurn) anyerror!void {
        const self: *Seed = @ptrCast(@alignCast(raw.?));
        _ = try s.Table.create(turn, 1, .{ .names = .{ try .init("id"), try .init("value") }, .value_type = .int64 });
        try s.GrowingQuery.setPolicy(turn, self.peer, 1, 0, true);
    }
    fn handle(_: ?*anyopaque, turn: *s.GrowingTurn, frame: s.Frame) anyerror!void {
        const first = try frame.payload.asInteger();
        if (first < 0) return;
        const table = try s.Table.open(turn, 1);
        var i = first;
        while (i < @min(first + 4, 41)) : (i += 1) try table.insert(turn, .{ .key = i, .value = if (@mod(i, 5) == 0) .null else .{ .int64 = 9007199254740993 + i } });
    }
};
fn drive(init: std.process.Init, server: *s.GrowingGenServer, handler: s.GrowingGenServer.Handler) !void {
    for (0..20) |_| switch (try server.step(handler, @as(u64, @intCast(std.Io.Clock.real.now(init.io).toMilliseconds())) + 30000)) {
        .committed => return,
        .blocked => return server.handler_error orelse error.Blocked,
        .idle => return error.NoInput,
        .progress => {},
    };
    return error.StepBudgetExceeded;
}
fn save(init: std.process.Init, directory: []const u8, name: []const u8, value: anytype) !void {
    const path = try std.fmt.allocPrint(init.arena.allocator(), "{s}/{s}", .{ directory, name });
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = try std.json.Stringify.valueAlloc(init.arena.allocator(), value, .{}) });
}
fn seedFile(init: std.process.Init, directory: []const u8, name: []const u8, byte: u8) ![]const u8 {
    const path = try std.fmt.allocPrint(init.arena.allocator(), "{s}/{s}.seed", .{ directory, name });
    const text = std.fmt.bytesToHex(@as([32]u8, @splat(byte)), .lower);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = &text });
    return path;
}
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const root = try p.Ed25519.KeyPair.generateDeterministic(@splat(7));
    var buffer: [4096]u8 = undefined;
    var output = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    if (args.len == 2 and std.mem.eql(u8, args[1], "public")) {
        try std.json.Stringify.value(root.public_key.toBytes(), .{}, &output.interface);
        return output.interface.flush();
    }
    if (args.len != 4) return error.Usage;
    var wire = s.client.Client.init(init.gpa, init.io, args[1]);
    defer wire.deinit();
    wire.timeout_ms = 10000;
    var admin: Admin = .{ .wire = &wire, .key = root };
    admin.sequence = (try admin.query(.{ .capabilities = {} })).principal_sequence;
    const second_flight = std.mem.eql(u8, args[2], "provision-flight-second");
    const flight = std.mem.eql(u8, args[2], "provision-flight") or second_flight;
    if (std.mem.eql(u8, args[2], "provision") or flight) {
        const writer_principal: u64 = if (second_flight) 65539 else 65536;
        const requester_principal: u64 = if (second_flight) 65540 else 65537;
        const courier_principal: u64 = if (second_flight) 65541 else 65538;
        const query_principal: u64 = if (second_flight) 1235 else 1234;
        const administrator_principal: u64 = if (second_flight) 34 else 33;
        const seed_offset: u8 = if (second_flight) 6 else 0;
        const writer_key = try p.Ed25519.KeyPair.generateDeterministic(@splat(8 + seed_offset));
        const requester_key = try p.Ed25519.KeyPair.generateDeterministic(@splat(9 + seed_offset));
        const caller_key = try p.Ed25519.KeyPair.generateDeterministic(@splat(10 + seed_offset));
        const courier_key = try p.Ed25519.KeyPair.generateDeterministic(@splat(11 + seed_offset));
        const writer = try admin.provision(writer_principal, writer_key);
        const requester = try admin.provisionReader(requester_principal, requester_key, if (flight) writer.resource else null);
        _ = try admin.submit(.{ .grant = .{ .subject = query_principal, .pid = if (flight) requester.pid else null, .public_key = caller_key.public_key.toBytes(), .permissions = p.permission(.inspect) | p.permission(.send) } });
        _ = try admin.submit(.{ .grant = .{ .subject = courier_principal, .public_key = courier_key.public_key.toBytes(), .permissions = p.permission(.inspect) | p.permission(.send) | p.permission(.delivery) } });
        if (!second_flight) _ = try admin.submit(.{ .grant = .{ .subject = 55, .public_key = (try p.Ed25519.KeyPair.generateDeterministic(@splat(12))).public_key.toBytes(), .permissions = p.permission(.inspect) } });
        for ([_]u64{ writer.resource, requester.resource }) |resource| for ([_]u64{ query_principal, 55 }) |principal| {
            _ = try admin.submit(.{ .grant_resource = .{ .resource = resource, .subject = principal, .permissions = p.State.permission(.inspect) | p.State.permission(.read) } });
        };
        var server = try s.GrowingGenServer.init(.{ .client = &wire, .realm = 45, .principal = writer_principal, .pid = writer.pid, .generation = 2, .key = writer_key }, "state");
        var seed: Seed = .{ .peer = requester.pid };
        const handler: s.GrowingGenServer.Handler = .{ .context = &seed, .initialize = Seed.initialize, .handle = Seed.handle };
        try admin.send(writer.pid, -1);
        try drive(init, &server, handler);
        for (0..11) |i| {
            try admin.send(writer.pid, @intCast(i * 4));
            try drive(init, &server, handler);
        }
        var requests = try s.GrowingGenServer.init(.{ .client = &wire, .realm = 45, .principal = requester_principal, .pid = requester.pid, .generation = requester.generation, .key = requester_key }, "state");
        var behavior: q.Behavior.Requester = .{ .principal = query_principal, .source = writer.pid };
        _ = try wire.submitGrowing(try p.Growth.sign(.{ .realm = 45, .principal = query_principal, .sequence = 1, .command = .{ .send = .{ .pid = requester.pid, .value = try (s.Frame{ .kind = .cast, .payload = try .init("PQI1") }).encode() } } }, caller_key));
        var finite: serving.FiniteService = .{ .configuration = .{ .service = .{ .service = 1, .administrator = administrator_principal, .observer = administrator_principal }, .query_principal = query_principal, .source = writer.pid } };
        if (flight) requests.input_guard = finite.guard();
        const requester_handler = if (flight) finite.interface() else behavior.interface();
        try drive(init, &requests, requester_handler);
        if (flight) {
            const administrator = try p.Ed25519.KeyPair.generateDeterministic(@splat(13 + seed_offset));
            _ = try admin.submit(.{ .grant = .{ .subject = administrator_principal, .pid = requester.pid, .public_key = administrator.public_key.toBytes(), .permissions = p.permission(.inspect) | p.permission(.send) } });
            const commands = [_]serving.Model.Command{
                .{ .publish = .{ .expected = 0, .binding = .{ .revision = 1, .target = writer.pid, .codec = 1, .active_limit = 1, .wait_before_ms = 180000 } } },
                .{ .policy = .{ .principal = query_principal, .expected = 0, .policy = .{ .revision = 1, .reads = true, .commands = true, .active_limit = 1 } } },
            };
            for (commands, 0..) |command, index| {
                _ = try wire.submitGrowing(try p.Growth.sign(.{ .realm = 45, .principal = administrator_principal, .sequence = index + 1, .command = .{ .send = .{ .pid = requester.pid, .value = try (s.Frame{ .kind = .cast, .payload = try command.encode() }).encode() } } }, administrator));
                try drive(init, &requests, requester_handler);
            }
        }
        _ = try admin.submit(.{ .own = .{ .pid = writer.pid, .expected_generation = 2, .worker = writer_principal } });
        _ = try admin.submit(.{ .own = .{ .pid = requester.pid, .expected_generation = requester.generation, .worker = requester_principal } });
        const source_seed = try seedFile(init, args[3], "source", 8 + seed_offset);
        const request_seed = try seedFile(init, args[3], "requester", 9 + seed_offset);
        const caller_seed = try seedFile(init, args[3], "caller", 10 + seed_offset);
        const courier_seed = try seedFile(init, args[3], "courier", 11 + seed_offset);
        const inspector_seed = try seedFile(init, args[3], "inspector", 12);
        const connection: q.Model.Connection = .{ .realm = 45, .principal = query_principal, .source = writer.pid, .resource = writer.resource, .table = 1, .name = "items", .requester = requester.pid, .requests = requester.resource };
        try save(init, args[3], "cli.json", .{ .url = args[1], .seed_file = caller_seed, .connection = connection, .request_timeout_ms = 10000 });
        var inspector = connection;
        inspector.principal = 55;
        try save(init, args[3], "inspector.json", .{ .url = args[1], .seed_file = inspector_seed, .connection = inspector });
        try save(init, args[3], "source.json", .{ .url = args[1], .realm = 45, .principal = writer_principal, .pid = writer.pid, .generation = 3, .seed_file = source_seed, .activation_directory = args[3], .role = .{ .source = .{ .table = 1, .peer = requester.pid } } });
        if (flight) try save(init, args[3], "requester.json", .{ .url = args[1], .realm = 45, .principal = requester_principal, .pid = requester.pid, .generation = requester.generation + 1, .seed_file = request_seed, .activation_directory = args[3], .role = .{ .finite_service = finite.configuration } }) else try save(init, args[3], "requester.json", .{ .url = args[1], .realm = 45, .principal = requester_principal, .pid = requester.pid, .generation = requester.generation + 1, .seed_file = request_seed, .activation_directory = args[3], .role = .{ .requester = behavior } });
        try save(init, args[3], "courier.json", .{ .url = args[1], .realm = 45, .principal = courier_principal, .seed_file = courier_seed, .role = .{ .courier = .{ .destinations = .{ writer.pid, requester.pid } } } });
        return;
    }
    const config = try std.Io.Dir.cwd().readFileAlloc(init.io, args[3], init.gpa, .limited(8192));
    defer init.gpa.free(config);
    const parsed = try std.json.parseFromSlice(struct { connection: q.Model.Connection }, init.gpa, config, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    const c = parsed.value.connection;
    if (std.mem.eql(u8, args[2], "released-pins")) {
        var after: ?p.Growth.ReadVersionId = null;
        var count: usize = 0;
        while (true) {
            const page = (try admin.query(.{ .read_versions = .{ .pid = c.source, .after = after } })).body.read_versions;
            for (page.entries) |entry| if (entry) |version| {
                if (version.released_at == null) return error.SourcePinStillHeld;
                count += 1;
            };
            after = page.next;
            if (after == null) break;
        }
        if (count == 0) return error.NoCapturedSource;
        return;
    }
    if (std.mem.startsWith(u8, args[2], "activate-source:") or std.mem.startsWith(u8, args[2], "activate-requester:")) {
        const requester = std.mem.startsWith(u8, args[2], "activate-requester:");
        const pid = if (requester) c.requester else c.source;
        const principal: u64 = if (requester) 65537 else 65536;
        var public: [32]u8 = undefined;
        _ = try std.fmt.hexToBytes(&public, args[2][if (requester) @as(usize, 19) else 16..]);
        const generation = (try admin.query(.{ .process = pid })).body.process.process.generation;
        _ = try admin.submit(.{ .grant = .{ .subject = principal, .pid = pid, .public_key = public, .permissions = p.permission(.inspect) | p.permission(.execute) | p.permission(.publish) } });
        _ = try admin.submit(.{ .grant_resource = .{ .resource = if (requester) c.requests else c.resource, .subject = principal, .permissions = p.State.all_permissions } });
        if (requester) _ = try admin.submit(.{ .grant_resource = .{ .resource = c.resource, .subject = principal, .permissions = p.State.permission(.inspect) | p.State.permission(.read) } });
        _ = try admin.submit(.{ .own = .{ .pid = pid, .expected_generation = generation, .worker = principal } });
        try std.json.Stringify.value(.{ .generation = generation + 1 }, .{}, &output.interface);
        return output.interface.flush();
    }
    if (std.mem.startsWith(u8, args[2], "retry-sequence:")) {
        var caller: q.Client = .{ .wire = &wire, .connection = c, .key = try p.Ed25519.KeyPair.generateDeterministic(@splat(10)) };
        const schema: q.fuze.model.Schema = .{ .names = .{ try .init("id"), try .init("value") }, .value_type = .int64 };
        const signed = try caller.prepareSequence("SELECT id, value FROM items", schema, try std.fmt.parseInt(u64, args[2][15..], 10));
        const receipt = try caller.submitSequence(signed);
        try std.json.Stringify.value(.{ .submitted = receipt.position }, .{}, &output.interface);
        return output.interface.flush();
    }
    if (std.mem.startsWith(u8, args[2], "capture:")) {
        var caller: q.Client = .{ .wire = &wire, .connection = c, .key = try p.Ed25519.KeyPair.generateDeterministic(@splat(10)) };
        const correlation = try std.fmt.parseInt(u64, args[2][8..], 10);
        const manifest = (try caller.status(correlation)).manifest orelse return error.IncompleteResult;
        const workspace = try init.gpa.alloc(u8, q.fuze.execution.working_bytes);
        defer init.gpa.free(workspace);
        var bytes: [s.GrowingQuery.records.segment_bytes]u8 = undefined;
        var chain: [32]u8 = @splat(0);
        var rows: u64 = 0;
        var length: u64 = 0;
        for (0..manifest.segments) |ordinal| {
            const segment = try caller.segment(correlation, ordinal, &bytes, workspace);
            if (!std.meta.eql(segment.result, manifest)) return error.InvalidResultManifest;
            chain = try segment.segment.extend(chain);
            rows += segment.segment.rows;
            length += segment.bytes.len;
        }
        if (!std.mem.eql(u8, &manifest.chain, &chain) or manifest.rows != rows or manifest.bytes != length) return error.IncompleteResult;
        try std.json.Stringify.value(.{ .rows = rows, .bytes = length, .segments = manifest.segments }, .{}, &output.interface);
        return output.interface.flush();
    }
    if (std.mem.eql(u8, args[2], "submit-busy") or std.mem.eql(u8, args[2], "bad-schema")) {
        const caller_key = try p.Ed25519.KeyPair.generateDeterministic(@splat(10));
        const sequence = (try wire.queryGrowing(.{ .realm = 45, .principal = 1234, .kind = .{ .capabilities = {} } }, caller_key)).principal_sequence;
        const schema: q.fuze.model.Schema = .{ .names = .{ try .init("id"), try .init("value") }, .value_type = .int64 };
        const start: q.Request.Start = .{ .schema = if (std.mem.eql(u8, args[2], "bad-schema")) @splat(0) else try schema.fingerprint(), .plan = .{} };
        const receipt = try wire.submitGrowing(try p.Growth.sign(.{ .realm = 45, .principal = 1234, .sequence = sequence + 1, .command = .{ .send = .{ .pid = c.requester, .value = try (s.Frame{ .kind = .cast, .payload = try start.encode() }).encode() } } }, caller_key));
        try std.json.Stringify.value(.{ .submitted = receipt.position }, .{}, &output.interface);
        return output.interface.flush();
    }
    if (std.mem.eql(u8, args[2], "fence") or std.mem.eql(u8, args[2], "fence-requester")) {
        const requester = std.mem.eql(u8, args[2], "fence-requester");
        const pid = if (requester) c.requester else c.source;
        const process = (try admin.query(.{ .process = pid })).body.process.process;
        _ = try admin.submit(.{ .own = .{ .pid = pid, .expected_generation = process.generation, .worker = if (requester) 65537 else 65536 } });
    } else if (std.mem.eql(u8, args[2], "revoke") or std.mem.eql(u8, args[2], "revoke-read")) {
        _ = try admin.submit(.{ .grant_resource = .{ .resource = c.resource, .subject = 1234, .permissions = if (std.mem.eql(u8, args[2], "revoke-read")) p.State.permission(.inspect) else 0 } });
    } else if (std.mem.eql(u8, args[2], "restore")) {
        _ = try admin.submit(.{ .grant_resource = .{ .resource = c.resource, .subject = 1234, .permissions = p.State.permission(.inspect) | p.State.permission(.read) } });
    } else if (std.mem.eql(u8, args[2], "retire-source")) {
        _ = try admin.submit(.{ .terminate = c.source });
        _ = try admin.submit(.{ .retire_resource = c.resource });
    } else if (std.mem.eql(u8, args[2], "retire-requester")) {
        _ = try admin.submit(.{ .terminate = c.requester });
        _ = try admin.submit(.{ .retire_resource = c.requests });
    } else if (std.mem.eql(u8, args[2], "expand-inspector") or std.mem.eql(u8, args[2], "restore-inspector")) {
        _ = try admin.submit(.{ .grant = .{ .subject = 55, .public_key = (try p.Ed25519.KeyPair.generateDeterministic(@splat(12))).public_key.toBytes(), .permissions = if (std.mem.eql(u8, args[2], "expand-inspector")) p.all_permissions else p.permission(.inspect) } });
        // Resource grants bind to the principal incarnation. Replacing its
        // coarse grant never resurrects the previous incarnation's access.
        if (std.mem.eql(u8, args[2], "restore-inspector")) for ([_]u64{ c.resource, c.requests }) |resource| {
            _ = try admin.submit(.{ .grant_resource = .{ .resource = resource, .subject = 55, .permissions = p.State.permission(.inspect) | p.State.permission(.read) } });
        };
    } else return error.UnknownMode;
}
