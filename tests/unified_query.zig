//! Public provisioning and signed client for actual v2 query daemons.
const std = @import("std");
const q = @import("transit_query");
const s = @import("transit_station");
const p = s.protocol;
const Admin = @import("growing_support.zig").Admin(46);
const Kind = enum { kv, table, document };
const count = 41;
const document_count = 12;
const budgets: q.Bundle.Limits = .{ .pages = 1000, .segments = 100, .result_bytes = 1048576 };
const Config = struct { url: []const u8, connection: q.UnifiedClient.Connection, kind: Kind };
const path = [_]q.document.Model.Name{q.document.Model.Name.init("items") catch unreachable};
const optional_path = [_]q.document.Model.Name{q.document.Model.Name.init("optional") catch unreachable};
const projections = [_]q.SourceDefinition.Projection{
    .{ .column = .{ .name = q.fuze.Unified.Name.init("value") catch unreachable, .type = .utf8 }, .path = &.{}, .relative = true },
    .{ .column = .{ .name = q.fuze.Unified.Name.init("counter") catch unreachable, .type = .uint64 }, .path = &.{}, .relative = true, .mode = .element_counter },
    .{ .column = .{ .name = q.fuze.Unified.Name.init("replica") catch unreachable, .type = .uint64 }, .path = &.{}, .relative = true, .mode = .element_replica },
    .{ .column = .{ .name = q.fuze.Unified.Name.init("optional") catch unreachable, .type = .utf8 }, .path = &optional_path },
};
fn definition(kind: Kind, resource: u64) !q.SourceDefinition {
    return .{ .resource = resource, .source = switch (kind) {
        .kv => .{ .kv = .{ .prefix = try p.Value.init("k"), .key = .{ .type = .binary }, .value = .{ .type = .utf8 } } },
        .table => .{ .table = .{ .id = 1, .schema = .{ .names = .{ try .init("id"), try .init("value") }, .value_type = .utf8 } } },
        .document => .{ .document = .{ .reference = .{ .resource = resource, .document = 17, .epoch = 1, .type_revision = 1, .revision = document_count + 1 }, .expand = &path, .projections = &projections } },
    } };
}
fn bundle(config: Config) !q.Bundle {
    const selected: u8 = if (config.kind == .document) 0 else 1;
    return .{ .source = try definition(config.kind, config.connection.resource), .plan = .{ .projection = if (config.kind == .document) &.{ 0, 1, 2, 3 } else &.{1}, .predicate = .{ .compare = .{ .column = selected, .op = .ne, .value = .{ .utf8 = &@as([512]u8, @splat('x')) } } } }, .limits = budgets };
}
fn value(index: usize, buffer: []u8, padding: usize) ![]const u8 {
    const bytes: [128]u8 = @splat('x');
    return std.fmt.bufPrint(buffer, "東京🙂/{s}/{d:0>2}", .{ bytes[0..padding], index });
}
const Seed = struct {
    kind: Kind,
    peer: u64,
    requests: u64,
    done: bool = false,
    fn initialize(raw: ?*anyopaque, turn: *s.GrowingTurn) !void {
        const self: *Seed = @ptrCast(@alignCast(raw.?));
        switch (self.kind) {
            .kv => {},
            .table => {
                _ = try s.Table.create(turn, 1, (try definition(.table, turn.view.resource)).source.table.schema);
            },
            .document => try (q.document.Service{ .resource = turn.view.resource, .document = 17 }).create(turn, 1, .{ .record_bytes = 4096, .staging_bytes = 4096, .staging_records = 1 }),
        }
    }
    fn change(job: u64) !q.document.Change {
        if (job == 1) {
            var out: q.document.Change = .{ .document = 17, .epoch = 1, .replica = 1, .first = 1, .len = 1 };
            out.operations[0] = .{ .assign = .{ .field = path[0], .value = .list } };
            return out;
        }
        const start = job - 2;
        var out: q.document.Change = .{ .document = 17, .epoch = 1, .replica = 1, .previous = start + 1, .first = start + 2, .len = 1 };
        for (0..out.len) |offset| {
            const index = start + offset;
            var bytes: [220]u8 = undefined;
            out.operations[offset] = .{ .insert = .{ .object = .{ .counter = 1, .replica = 1 }, .after = if (index == 0) .root else .{ .counter = index + 1, .replica = 1 }, .value = .{ .string = try .init(try value(index, &bytes, 64)) } } };
        }
        return out;
    }
    fn handle(raw: ?*anyopaque, turn: *s.GrowingTurn, frame: s.Frame) !void {
        const self: *Seed = @ptrCast(@alignCast(raw.?));
        const command = try frame.payload.asInteger();
        self.done = false;
        if (command == -1) return;
        if (command == -2 or command == -3) {
            try q.UnifiedCapture.setPolicy(turn, .{ .peer = self.peer, .requests = self.requests, .revision = if (command == -2) 1 else 2, .allow = command == -2, .limits = budgets, .declaration = try q.Bundle.declaration(try definition(self.kind, turn.view.resource)) });
            if (command == -2) {
                var source: q.UnifiedBehavior.Source = .{ .peer = self.peer, .initializer = 65536, .resources = undefined, .adapter = &.{}, .workspace = &.{}, .cancellation = undefined };
                const handler = source.interface();
                try handler.initialize.?(handler.context, turn);
            }
            return;
        }
        if (self.kind == .document) {
            const job: u64 = @intCast(@mod(command, 10000));
            const service: q.document.Service = .{ .resource = turn.view.resource, .document = 17 };
            if (command < 20000) {
                _ = try service.prepare(turn, job, try change(job), 512);
            } else if (command < 30000) self.done = try service.upload(turn, job, try change(job)) else self.done = try service.advance(turn, job) != .progress;
            return;
        }
        const first: usize = @intCast(command);
        for (first..@min(first + 4, count)) |index| {
            var bytes: [220]u8 = undefined;
            const text = try value(index, &bytes, 128);
            if (self.kind == .table) {
                const table = try s.Table.open(turn, 1);
                try table.insert(turn, .{ .key = @intCast(index), .value = .{ .utf8 = try .init(text) } });
            } else {
                var key: [9]u8 = undefined;
                key[0] = 'k';
                std.mem.writeInt(u64, key[1..9], index, .big);
                try turn.put(try p.Value.init(&key), try p.Value.init(text));
            }
        }
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
fn file(init: std.process.Init, directory: []const u8, name: []const u8) ![]const u8 {
    return std.fmt.allocPrint(init.arena.allocator(), "{s}/{s}", .{ directory, name });
}
fn save(init: std.process.Init, directory: []const u8, name: []const u8, data: anytype) !void {
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = try file(init, directory, name), .data = try std.json.Stringify.valueAlloc(init.arena.allocator(), data, .{}) });
}
fn keyFile(init: std.process.Init, directory: []const u8, name: []const u8, byte: u8) ![]const u8 {
    const location = try file(init, directory, name);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = location, .data = &std.fmt.bytesToHex(@as([32]u8, @splat(byte)), .lower) });
    return location;
}
fn print(init: std.process.Init, data: anytype) !void {
    var buffer: [4096]u8 = undefined;
    var out = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    try std.json.Stringify.value(data, .{}, &out.interface);
    try out.interface.writeByte('\n');
    try out.interface.flush();
}
fn observe(init: std.process.Init, client: *q.UnifiedClient, receipt: p.Receipt) !void {
    for (0..1000) |_| {
        switch (try client.observe(receipt.position)) {
            .committed => return,
            .rejected => |reason| {
                try print(init, .{ .rejected = reason.slice() });
                return error.QueryCommandRejected;
            },
            .pending => {},
        }
        try init.io.sleep(.fromMilliseconds(20), .awake);
    }
    return error.QueryCommandPending;
}
const JobSnapshot = struct { job: ?q.UnifiedRecords.Job = null, checkpoint: ?q.UnifiedRecords.Checkpoint = null };
fn inspectJob(transport: *s.client.Client, root: p.Ed25519.KeyPair, connection: q.UnifiedClient.Connection, correlation: u64) !JobSnapshot {
    const resource_client: s.client.ResourceReader = .{ .wire = transport, .realm = 46, .principal = 0, .key = root };
    var reader = try resource_client.open(connection.resource);
    const index = (try reader.read(q.UnifiedRecords.key('i', connection.requester, correlation))) orelse return .{};
    const job = try q.UnifiedCapture.job(&reader, try q.Request.readIdentity(index));
    return .{ .job = job, .checkpoint = try q.UnifiedCapture.checkpoint(&reader, job.id) };
}
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const root = try p.Ed25519.KeyPair.generateDeterministic(@splat(7));
    if (args.len == 2 and std.mem.eql(u8, args[1], "public")) return print(init, root.public_key.toBytes());
    if (args.len < 4) return error.Usage;
    const url = args[1];
    const command = args[2];
    const directory = args[3];
    var transport = s.client.Client.init(init.gpa, init.io, url);
    defer transport.deinit();
    transport.timeout_ms = 10000;
    var admin: Admin = .{ .wire = &transport, .key = root };
    admin.sequence = (try admin.query(.{ .capabilities = {} })).principal_sequence;
    if (std.mem.eql(u8, command, "provision")) {
        if (args.len != 5) return error.Usage;
        const kind = std.meta.stringToEnum(Kind, args[4]) orelse return error.InvalidKind;
        const writer_key = try p.Ed25519.KeyPair.generateDeterministic(@splat(8));
        const requester_key = try p.Ed25519.KeyPair.generateDeterministic(@splat(9));
        const caller_key = try p.Ed25519.KeyPair.generateDeterministic(@splat(10));
        const courier_key = try p.Ed25519.KeyPair.generateDeterministic(@splat(11));
        const requester = try admin.provision(65537, requester_key);
        const writer = try admin.provisionReader(65536, writer_key, requester.resource);
        _ = try admin.submit(.{ .grant = .{ .subject = 1234, .public_key = caller_key.public_key.toBytes(), .permissions = p.permission(.inspect) | p.permission(.send) } });
        _ = try admin.submit(.{ .grant = .{ .subject = 65538, .public_key = courier_key.public_key.toBytes(), .permissions = p.permission(.inspect) | p.permission(.send) | p.permission(.delivery) } });
        for ([_]u64{ writer.resource, requester.resource }) |resource| _ = try admin.submit(.{ .grant_resource = .{ .resource = resource, .subject = 1234, .permissions = p.State.permission(.inspect) | p.State.permission(.read) } });
        var server = try s.GrowingGenServer.init(.{ .client = &transport, .realm = 46, .principal = 65536, .pid = writer.pid, .generation = writer.generation, .key = writer_key }, "state");
        var seed: Seed = .{ .kind = kind, .peer = requester.pid, .requests = requester.resource };
        const handler: s.GrowingGenServer.Handler = .{ .context = &seed, .initialize = Seed.initialize, .handle = Seed.handle };
        try admin.send(writer.pid, -1);
        try drive(init, &server, handler);
        if (kind == .document) {
            for (1..document_count + 2) |job| {
                try admin.send(writer.pid, @intCast(10000 + job));
                try drive(init, &server, handler);
                for ([_]usize{ 20000, 30000 }) |stage| {
                    for (0..10000) |_| {
                        try admin.send(writer.pid, @intCast(stage + job));
                        try drive(init, &server, handler);
                        if (seed.done) break;
                    } else return error.DocumentDidNotFinish;
                }
            }
        } else {
            for (0..11) |index| {
                try admin.send(writer.pid, @intCast(index * 4));
                try drive(init, &server, handler);
            }
        }
        try admin.send(writer.pid, -2);
        try drive(init, &server, handler);
        var requests = try s.GrowingGenServer.init(.{ .client = &transport, .realm = 46, .principal = 65537, .pid = requester.pid, .generation = requester.generation, .key = requester_key }, "state");
        var behavior: q.UnifiedBehavior.Requester = .{ .principal = 1234, .source = writer.pid };
        _ = try transport.submitGrowing(try p.Growth.sign(.{ .realm = 46, .principal = 1234, .sequence = 1, .command = .{ .send = .{ .pid = requester.pid, .value = try (s.Frame{ .kind = .cast, .payload = try q.UnifiedRequest.Command.encode(.initialize) }).encode() } } }, caller_key));
        try drive(init, &requests, behavior.interface());
        _ = try admin.submit(.{ .own = .{ .pid = writer.pid, .expected_generation = writer.generation, .worker = 65536 } });
        _ = try admin.submit(.{ .own = .{ .pid = requester.pid, .expected_generation = requester.generation, .worker = 65537 } });
        const connection: q.UnifiedClient.Connection = .{ .realm = 46, .principal = 1234, .source = writer.pid, .resource = writer.resource, .requester = requester.pid, .requests = requester.resource };
        const client_config: Config = .{ .url = url, .connection = connection, .kind = kind };
        try save(init, directory, "client.json", client_config);
        try save(init, directory, "shell.json", .{ .url = url, .seed_file = try keyFile(init, directory, "caller.seed", 10), .connection = connection, .workspace = q.Workspace.Config{ .name = "items", .source = try q.Values.Source.fromNative(init.arena.allocator(), try definition(kind, connection.resource)), .limits = try q.Values.Limits.fromNative(init.arena.allocator(), budgets) } });
        _ = try keyFile(init, directory, "caller.seed", 10);
        var bundle_bytes: [q.Bundle.max_bytes]u8 = undefined;
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = try file(init, directory, "bundle.bin"), .data = try (try bundle(client_config)).encode(&bundle_bytes) });
        try save(init, directory, "source.json", .{ .url = url, .realm = 46, .principal = 65536, .pid = writer.pid, .generation = writer.generation + 1, .seed_file = try keyFile(init, directory, "source.seed", 8), .activation_directory = directory, .role = .{ .unified_source = .{ .peer = requester.pid, .initializer = 65536 } } });
        try save(init, directory, "requester.json", .{ .url = url, .realm = 46, .principal = 65537, .pid = requester.pid, .generation = requester.generation + 1, .seed_file = try keyFile(init, directory, "requester.seed", 9), .activation_directory = directory, .role = .{ .unified_requester = behavior } });
        try save(init, directory, "courier.json", .{ .url = url, .realm = 46, .principal = 65538, .seed_file = try keyFile(init, directory, "courier.seed", 11), .role = .{ .courier = .{ .destinations = .{ writer.pid, requester.pid } } } });
        return print(init, connection);
    }
    const parsed = try std.json.parseFromSlice(Config, init.arena.allocator(), try std.Io.Dir.cwd().readFileAlloc(init.io, try file(init, directory, "client.json"), init.arena.allocator(), .limited(8192)), .{});
    const config = parsed.value;
    if (std.mem.eql(u8, command, "board-provision")) {
        const inspector = try p.Ed25519.KeyPair.generateDeterministic(@splat(12));
        _ = try admin.submit(.{ .grant = .{ .subject = 55, .public_key = inspector.public_key.toBytes(), .permissions = p.permission(.inspect) } });
        for ([_]u64{ config.connection.resource, config.connection.requests }) |resource| _ = try admin.submit(.{ .grant_resource = .{ .resource = resource, .subject = 55, .permissions = p.State.permission(.inspect) | p.State.permission(.read) } });
        return print(init, .{ .seed_file = try keyFile(init, directory, "inspector.seed", 12) });
    }
    var client: q.UnifiedClient = .{ .wire = &transport, .connection = config.connection, .key = try p.Ed25519.KeyPair.generateDeterministic(@splat(10)) };
    if (std.mem.eql(u8, command, "upload")) {
        for (0..1000) |_| {
            const pending = (try client.prepareNext(1, try bundle(config))) orelse return print(init, (try client.status(1)).?);
            try save(init, directory, "pending.json", pending);
            try observe(init, &client, try client.submit(pending));
        }
        return error.UploadIncomplete;
    }
    if (std.mem.eql(u8, command, "resume")) {
        const pending = try std.json.parseFromSlice(q.UnifiedClient.Prepared, init.arena.allocator(), try std.Io.Dir.cwd().readFileAlloc(init.io, try file(init, directory, "pending.json"), init.arena.allocator(), .limited(8192)), .{});
        const receipt = try client.submit(pending.value);
        try observe(init, &client, receipt);
        return print(init, receipt);
    }
    if (std.mem.eql(u8, command, "status")) return print(init, try client.status(1));
    if (std.mem.eql(u8, command, "request-read-revoke") or std.mem.eql(u8, command, "request-read-restore")) {
        _ = try admin.submit(.{ .grant_resource = .{ .resource = config.connection.requests, .subject = 65536, .permissions = if (std.mem.eql(u8, command, "request-read-revoke")) 0 else p.State.permission(.inspect) | p.State.permission(.read) } });
        return;
    }
    if (std.mem.eql(u8, command, "job")) {
        if (args.len != 5) return error.Usage;
        const namespace = try std.fmt.parseInt(u64, args[4], 10);
        const status = (try client.status(namespace)) orelse return error.QueryUploadNotFound;
        for (0..3) |_| {
            const snapshot = inspectJob(&transport, root, config.connection, status.correlation) catch |err| {
                if ((err == error.Conflict or err == error.Rejected) and (transport.last_rejection == .QueryExpired or transport.last_rejection == .StaleStateResource)) continue;
                return err;
            };
            return print(init, snapshot);
        }
        return error.QueryReadConflict;
    }
    if (std.mem.eql(u8, command, "released-read")) {
        const versions = (try admin.query(.{ .read_versions = .{ .pid = config.connection.source } })).body.read_versions;
        for (versions.entries) |slot| if (slot) |version| {
            if (version.released_at != null) {
                _ = transport.queryGrowing(.{ .realm = 46, .principal = 65536, .kind = .{ .version_entries = .{ .id = version.id, .generation = (try admin.query(.{ .process = config.connection.source })).body.process.process.generation } } }, try p.Ed25519.KeyPair.generateDeterministic(@splat(8))) catch {
                    if (transport.last_rejection != .ReadVersionReleased) return error.WrongVersionRejection;
                    return print(init, .{ .released_read_denied = true });
                };
                return error.ReleasedVersionReadable;
            }
        };
        return error.NoReleasedVersion;
    }
    if (std.mem.eql(u8, command, "revoke") or std.mem.eql(u8, command, "restore")) {
        _ = try admin.submit(.{ .grant_resource = .{ .resource = config.connection.resource, .subject = 1234, .permissions = if (std.mem.eql(u8, command, "revoke")) 0 else p.State.permission(.inspect) | p.State.permission(.read) } });
        return;
    }
    if (std.mem.eql(u8, command, "fence") or std.mem.eql(u8, command, "fence-requester")) {
        const requester = std.mem.eql(u8, command, "fence-requester");
        const process = (try admin.query(.{ .process = if (requester) config.connection.requester else config.connection.source })).body.process.process;
        _ = try admin.submit(.{ .own = .{ .pid = process.pid, .expected_generation = process.generation, .worker = if (requester) 65537 else 65536 } });
        return print(init, .{ .generation = process.generation + 1 });
    }
    if (std.mem.eql(u8, command, "page")) {
        const cursor_path = try file(init, directory, "cursor.json");
        const saved = std.Io.Dir.cwd().readFileAlloc(init.io, cursor_path, init.arena.allocator(), .limited(8192)) catch |err| switch (err) {
            error.FileNotFound => null,
            else => return err,
        };
        const cursor: ?q.UnifiedResult.Cursor = if (saved) |bytes| (try std.json.parseFromSlice(q.UnifiedResult.Cursor, init.arena.allocator(), bytes, .{})).value else null;
        const workspace = try init.arena.allocator().alloc(u8, q.fuze.Unified.Arrow.working_bytes);
        var bytes: [q.fuze.Unified.Arrow.segment_bytes]u8 = undefined;
        var decoded: q.fuze.Unified.Inspect.Batch = undefined;
        const page = try client.page(1, cursor, init.arena.allocator(), workspace, &bytes, &decoded);
        const ordinal = if (cursor) |previous| previous.ordinal else 0;
        const path_name = try std.fmt.allocPrint(init.arena.allocator(), "result-{d}.arrow", .{ordinal});
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = try file(init, directory, path_name), .data = page.arrow });
        if (page.next) |next| try save(init, directory, "cursor.json", next);
        return print(init, .{ .rows = decoded.count, .ordinal = ordinal, .complete = page.next == null, .manifest = page.manifest });
    }
    if (std.mem.eql(u8, command, "versions")) {
        const versions = (try admin.query(.{ .read_versions = .{ .pid = config.connection.source } })).body.read_versions;
        return print(init, versions);
    }
    return error.UnknownCommand;
}
