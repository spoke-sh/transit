//! Public provisioning and signed client for actual v1 query daemons.
const std = @import("std");
const q = @import("transit_query");
const s = @import("transit_station");
const p = s.protocol;
const Admin = @import("growing_support.zig").Admin(46);
const Combined = @import("table_query_writer_support.zig");
const Catalog = @import("catalog_query_support.zig");
pub const Kind = enum { kv, table, document };
const count = 41;
const document_count = 12;
const budgets: q.Bundle.Limits = .{ .pages = 1000, .segments = 100, .result_bytes = 1048576 };
const Config = struct { url: []const u8, connection: q.UnifiedClient.Connection, kind: Kind, source: q.Values.Source, expiry_at_ms: ?u64 = null, compound: bool = false };
const path = [_]q.document.Model.Name{q.document.Model.Name.init("items") catch unreachable};
const optional_path = [_]q.document.Model.Name{q.document.Model.Name.init("optional") catch unreachable};
const projections = [_]q.SourceDefinition.Projection{
    .{ .column = .{ .name = q.fuze.Unified.Name.init("value") catch unreachable, .type = .utf8 }, .path = &.{}, .relative = true },
    .{ .column = .{ .name = q.fuze.Unified.Name.init("counter") catch unreachable, .type = .uint64 }, .path = &.{}, .relative = true, .mode = .element_counter },
    .{ .column = .{ .name = q.fuze.Unified.Name.init("replica") catch unreachable, .type = .uint64 }, .path = &.{}, .relative = true, .mode = .element_replica },
    .{ .column = .{ .name = q.fuze.Unified.Name.init("optional") catch unreachable, .type = .utf8 }, .path = &optional_path },
};
pub fn definition(kind: Kind, resource: u64) !q.SourceDefinition {
    return .{ .resource = resource, .source = switch (kind) {
        .kv => .{ .kv = .{ .prefix = try p.Value.init("k"), .key = .{ .type = .binary }, .value = .{ .type = .utf8 } } },
        .table => return error.CatalogDefinitionRequired,
        .document => .{ .document = .{ .reference = .{ .resource = resource, .document = 17, .epoch = 1, .type_revision = 1, .revision = document_count + 1 }, .expand = &path, .projections = &projections } },
    } };
}
fn bundle(config: Config, allocator: std.mem.Allocator) !q.Bundle {
    const source = try config.source.native(allocator);
    const projection = if (config.kind == .document) "value AS \"Result\",counter,replica,optional" else "value AS \"Result\"";
    const ceiling = if (config.kind == .document) "東京🙂/" ++ @as([64]u8, @splat('x')) ++ "/10" else "東京🙂/" ++ @as([128]u8, @splat('x')) ++ "/39";
    const clause = if (config.compound) try std.fmt.allocPrint(allocator, " AND NOT (value >= '{s}' OR value IS NULL)", .{ceiling}) else "";
    const sql = try std.fmt.allocPrint(allocator, "SELECT {s} FROM items WHERE value <> '{s}'{s}", .{ projection, @as([512]u8, @splat('x')), clause });
    return q.Bundle.fromSql(allocator, source, "items", sql, budgets);
}
fn value(index: usize, buffer: []u8, padding: usize) ![]const u8 {
    const bytes: [128]u8 = @splat('x');
    return std.fmt.bufPrint(buffer, "東京🙂/{s}/{d:0>2}", .{ bytes[0..padding], index });
}
pub const Seed = struct {
    initializer: u64 = 65536,
    kind: Kind,
    rows: usize = count,
    peer: u64,
    requests: u64,
    done: bool = false,
    freeze: bool = false,
    pub fn initialize(raw: ?*anyopaque, turn: *s.Turn) !void {
        const self: *Seed = @ptrCast(@alignCast(raw.?));
        switch (self.kind) {
            .kv => {},
            .table => {},
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
    pub fn handle(raw: ?*anyopaque, turn: *s.Turn, frame: s.Frame) !void {
        const self: *Seed = @ptrCast(@alignCast(raw.?));
        const command = try frame.payload.asInteger();
        self.done = false;
        if (command == -1) return;
        if (command == -4) {
            if (self.freeze) return error.FreezeForAssociation;
            return;
        }
        if (command == -5 or command == -6) {
            if (self.kind != .kv) return error.ExpectedKvSource;
            const key = [_]u8{ 'k', 0, 0, 0, 0, 0, 0, 0, 0 };
            var bytes: [220]u8 = undefined;
            try turn.put(try p.Value.init(&key), try p.Value.init(if (command == -5) "\xff" else try value(0, &bytes, 128)));
            return;
        }
        if (command == -7 or command == -8) {
            var limits = budgets;
            limits.pages = if (command == -7) 999 else 1000;
            try q.UnifiedCapture.setPolicy(turn, .{ .peer = self.peer, .requests = self.requests, .revision = if (command == -7) 2 else 3, .allow = true, .limits = limits, .target = .{ .declaration = try q.Bundle.declaration(try definition(self.kind, turn.view.resource)) } });
            return;
        }
        if (command == -2 or command == -3) {
            try q.UnifiedCapture.setPolicy(turn, .{ .peer = self.peer, .requests = self.requests, .revision = if (command == -2) 1 else 2, .allow = command == -2, .limits = budgets, .target = .{ .declaration = try q.Bundle.declaration(try definition(self.kind, turn.view.resource)) } });
            if (command == -2) {
                var source: q.UnifiedBehavior.Source = .{ .peer = self.peer, .initializer = self.initializer, .resources = undefined, .adapter = &.{}, .workspace = &.{}, .cancellation = undefined };
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
        for (first..@min(first + 4, self.rows)) |index| {
            var bytes: [220]u8 = undefined;
            const text = try value(index, &bytes, 128);
            if (self.kind != .kv) return error.CatalogDefinitionRequired;
            var key: [9]u8 = undefined;
            key[0] = 'k';
            std.mem.writeInt(u64, key[1..9], index, .big);
            try turn.put(try p.Value.init(&key), try p.Value.init(text));
        }
    }
};
const drive = Catalog.drive;
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
    const job = try q.UnifiedCapture.job(&reader, try q.UnifiedRecords.readIdentity(index));
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
    errdefer if (transport.last_rejection) |reason| std.debug.print("Authority rejection: {s}\n", .{@tagName(reason)});
    var admin: Admin = .{ .wire = &transport, .key = root };
    admin.sequence = (try admin.query(.{ .capabilities = {} })).principal_sequence;
    if (std.mem.eql(u8, command, "provision-combined")) return Combined.provision(init, url, &transport, &admin, directory);
    if (std.mem.eql(u8, command, "provision") or std.mem.eql(u8, command, "provision-expiring") or std.mem.eql(u8, command, "provision-compound")) {
        if (args.len != 5 and args.len != 6) return error.Usage;
        const kind = std.meta.stringToEnum(Kind, args[4]) orelse return error.InvalidKind;
        const rows = if (args.len == 6) try std.fmt.parseInt(usize, args[5], 10) else count;
        if (rows > 512 or (kind == .document and args.len == 6)) return error.InvalidRowCount;
        const writer_key = try p.Ed25519.KeyPair.generateDeterministic(@splat(8));
        const requester_key = try p.Ed25519.KeyPair.generateDeterministic(@splat(9));
        const caller_key = try p.Ed25519.KeyPair.generateDeterministic(@splat(10));
        const courier_key = try p.Ed25519.KeyPair.generateDeterministic(@splat(11));
        const expiring = std.mem.eql(u8, command, "provision-expiring");
        var requester: Admin.Provision = if (expiring) .{ .pid = try admin.submit(.{ .spawn = .{} }), .resource = 0, .generation = 0 } else try admin.provision(65537, requester_key);
        if (expiring) _ = try admin.submit(.{ .grant = .{ .subject = 65537, .public_key = requester_key.public_key.toBytes(), .permissions = p.permission(.inspect) | p.permission(.execute) | p.permission(.publish), .pid = requester.pid } });
        var writer = try admin.provisionReader(65536, writer_key, if (expiring) null else requester.resource);
        _ = try Catalog.authorization.login(q.catalog, &admin, "query-caller", 1234, caller_key, null);
        _ = try admin.submit(.{ .grant = .{ .subject = 65538, .public_key = courier_key.public_key.toBytes(), .permissions = p.permission(.inspect) | p.permission(.send) | p.permission(.delivery) } });
        for ([_]u64{ writer.resource, requester.resource }) |resource| {
            if (resource != 0) _ = try admin.submit(.{ .grant_resource = .{ .resource = resource, .subject = 1234, .permissions = p.State.permission(.inspect) | p.State.permission(.read) } });
        }
        var server = try s.GenServer.init(.{ .client = &transport, .realm = 46, .principal = 65536, .pid = writer.pid, .generation = writer.generation, .key = writer_key }, "state");
        var seed: Seed = .{ .kind = kind, .rows = rows, .peer = requester.pid, .requests = requester.resource };
        const handler: s.GenServer.Handler = .{ .context = &seed, .initialize = Seed.initialize, .handle = Seed.handle };
        const table_config: ?q.catalog.TableCatalogRecords.Configuration = if (kind == .table) try Catalog.provision(&admin, writer.resource, writer.pid) else null;
        var table_owner: ?*q.CatalogQueryOwner = null;
        var source_definition: q.SourceDefinition = undefined;
        if (kind == .table) {
            try Catalog.grant(&admin, table_config.?);
            table_owner = try Catalog.owner(init, &transport, table_config.?);
            server.input_guard = table_owner.?.guard();
            server.failure_policy = .stop;
            var catalog_client = try Catalog.caller(&transport, table_config.?);
            source_definition = try Catalog.initialize(init, &admin, &server, table_owner.?, &catalog_client, table_config.?, rows);
        } else {
            try admin.send(writer.pid, -1);
            try drive(init, &server, handler);
            source_definition = try definition(kind, writer.resource);
        }
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
        } else if (kind == .kv) {
            for (0..(rows + 3) / 4) |index| {
                try admin.send(writer.pid, @intCast(index * 4));
                try drive(init, &server, handler);
            }
        }
        var expiry_at_ms: ?u64 = null;
        if (expiring) {
            // The growing profile only permits association changes while
            // unowned. Record/retry a deliberate seed barrier before installing
            // the late finite request resource; never mutate topology under an
            // active writer or broaden its PID-scoped grant.
            server.input_guard = null;
            seed.freeze = true;
            try admin.send(writer.pid, -4);
            drive(init, &server, handler) catch |err| {
                if (err != error.FreezeForAssociation) return err;
            };
            const paused = (try admin.query(.{ .process = writer.pid })).body.process.process;
            _ = try admin.submit(.{ .retry = .{ .pid = writer.pid, .expected_generation = paused.generation, .failure_input = paused.failure orelse return error.SeedBarrierMissing } });
            writer.generation = paused.generation + 1;
            // Start the explicitly opted-in lifetime after expensive source
            // seeding. The real synchronized node clock enforces the deadline.
            expiry_at_ms = @as(u64, @intCast(std.Io.Clock.real.now(init.io).toMilliseconds())) + 180000;
            requester.resource = try admin.submit(.{ .create_resource = .{ .writer = requester.pid, .deadline_ms = expiry_at_ms } });
            for ([_]u64{ 0, 65537 }) |subject| _ = try admin.submit(.{ .grant_resource = .{ .resource = requester.resource, .subject = subject, .permissions = p.State.all_permissions } });
            for ([_]u64{ 1234, 65536 }) |subject| _ = try admin.submit(.{ .grant_resource = .{ .resource = requester.resource, .subject = subject, .permissions = p.State.permission(.inspect) | p.State.permission(.read) } });
            _ = try admin.submit(.{ .associate = .{ .pid = requester.pid, .name = try p.Value.init("state"), .resource = requester.resource } });
            _ = try admin.submit(.{ .own = .{ .pid = requester.pid, .expected_generation = 1, .worker = 65537 } });
            requester.generation = 2;
            _ = try admin.submit(.{ .associate = .{ .pid = writer.pid, .name = try p.Value.init("requests"), .resource = requester.resource, .required = false } });
            writer.generation += 1;
            _ = try admin.submit(.{ .own = .{ .pid = writer.pid, .expected_generation = writer.generation, .worker = 65536 } });
            writer.generation += 1;
            seed.requests = requester.resource;
            seed.freeze = false;
            server = try s.GenServer.init(.{ .client = &transport, .realm = 46, .principal = 65536, .pid = writer.pid, .generation = writer.generation, .key = writer_key }, "state");
            try drive(init, &server, handler);
        }
        if (table_owner) |catalog_owner| {
            server.input_guard = catalog_owner.guard();
            _ = try Catalog.delegate(&transport, table_config.?, requester.pid, requester.resource, budgets, 1);
            try Catalog.driveCatalog(init, &server, catalog_owner);
        } else {
            try admin.send(writer.pid, -2);
            try drive(init, &server, handler);
        }
        var requests = try s.GenServer.init(.{ .client = &transport, .realm = 46, .principal = 65537, .pid = requester.pid, .generation = requester.generation, .key = requester_key }, "state");
        var behavior: q.UnifiedBehavior.Requester = .{ .principal = 1234, .source = writer.pid };
        _ = try transport.submit(try p.Growth.sign(.{ .realm = 46, .principal = 1234, .sequence = 1, .command = .{ .send = .{ .pid = requester.pid, .value = try (s.Frame{ .kind = .cast, .payload = try q.UnifiedRequest.Command.encode(.initialize) }).encode() } } }, caller_key));
        try drive(init, &requests, behavior.interface());
        _ = try admin.submit(.{ .own = .{ .pid = writer.pid, .expected_generation = writer.generation, .worker = 65536 } });
        _ = try admin.submit(.{ .own = .{ .pid = requester.pid, .expected_generation = requester.generation, .worker = 65537 } });
        const connection: q.UnifiedClient.Connection = .{ .realm = 46, .principal = 1234, .source = writer.pid, .resource = writer.resource, .requester = requester.pid, .requests = requester.resource };
        const client_config: Config = .{ .url = url, .connection = connection, .kind = kind, .source = try q.Values.Source.fromNative(init.arena.allocator(), source_definition), .expiry_at_ms = expiry_at_ms, .compound = std.mem.eql(u8, command, "provision-compound") };
        try save(init, directory, "client.json", client_config);
        try save(init, directory, "shell.json", .{ .url = url, .seed_file = try keyFile(init, directory, "caller.seed", 10), .connection = connection, .workspace = q.Workspace.Config{ .name = "items", .source = client_config.source, .limits = try q.Values.Limits.fromNative(init.arena.allocator(), budgets) } });
        _ = try keyFile(init, directory, "caller.seed", 10);
        var query_client: q.UnifiedClient = .{ .wire = &transport, .connection = connection, .key = caller_key };
        const description_bundle = try bundle(client_config, init.arena.allocator());
        var bundle_bytes: [q.Bundle.max_bytes]u8 = undefined;
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = try file(init, directory, "bundle-description.bin"), .data = try description_bundle.encode(&bundle_bytes) });
        const authorized_bundle = try query_client.authorizeBundle(description_bundle);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = try file(init, directory, "bundle.bin"), .data = try authorized_bundle.encode(&bundle_bytes) });
        if (kind == .table) try save(init, directory, "source.json", .{ .url = url, .realm = 46, .principal = 65536, .pid = writer.pid, .generation = writer.generation + 1, .seed_file = try keyFile(init, directory, "source.seed", 8), .activation_directory = directory, .role = .{ .catalog = table_config.? } }) else try save(init, directory, "source.json", .{ .url = url, .realm = 46, .principal = 65536, .pid = writer.pid, .generation = writer.generation + 1, .seed_file = try keyFile(init, directory, "source.seed", 8), .activation_directory = directory, .role = .{ .unified_source = .{ .peer = requester.pid, .initializer = 65536 } } });
        try save(init, directory, "requester.json", .{ .url = url, .realm = 46, .principal = 65537, .pid = requester.pid, .generation = requester.generation + 1, .seed_file = try keyFile(init, directory, "requester.seed", 9), .activation_directory = directory, .role = .{ .unified_requester = behavior } });
        try save(init, directory, "courier.json", .{ .url = url, .realm = 46, .principal = 65538, .seed_file = try keyFile(init, directory, "courier.seed", 11), .role = .{ .courier = .{ .destinations = .{ writer.pid, requester.pid } } } });
        return print(init, connection);
    }
    if (std.mem.startsWith(u8, command, "combined-")) {
        const selected = try std.json.parseFromSlice(q.UnifiedClient.Connection, init.arena.allocator(), try std.Io.Dir.cwd().readFileAlloc(init.io, try file(init, directory, "combined-connection.json"), init.arena.allocator(), .limited(4096)), .{});
        return Combined.execute(init, url, &transport, &admin, directory, command, selected.value);
    }
    const parsed = try std.json.parseFromSlice(Config, init.arena.allocator(), try std.Io.Dir.cwd().readFileAlloc(init.io, try file(init, directory, "client.json"), init.arena.allocator(), .limited(8192)), .{});
    const config = parsed.value;
    if (std.mem.eql(u8, command, "invalidate-kv") or std.mem.eql(u8, command, "repair-kv") or std.mem.eql(u8, command, "lower-policy") or std.mem.eql(u8, command, "restore-policy")) {
        if (!std.mem.eql(u8, command, "lower-policy") and !std.mem.eql(u8, command, "restore-policy") and config.kind != .kv) return error.ExpectedKvSource;
        const process = (try admin.query(.{ .process = config.connection.source })).body.process.process;
        var server = try s.GenServer.init(.{ .client = &transport, .realm = 46, .principal = 65536, .pid = config.connection.source, .generation = process.generation, .key = try p.Ed25519.KeyPair.generateDeterministic(@splat(8)) }, "state");
        if (config.kind == .table) {
            const table_config = try Catalog.configuration(&transport, config.connection.resource, config.connection.source);
            const owner = try Catalog.owner(init, &transport, table_config);
            server.input_guard = owner.guard();
            server.failure_policy = .stop;
            var limits = budgets;
            const restore = std.mem.eql(u8, command, "restore-policy");
            limits.pages = if (restore) 1000 else 999;
            _ = try Catalog.delegate(&transport, table_config, config.connection.requester, config.connection.requests, limits, if (restore) 3 else 2);
            return drive(init, &server, owner.interface());
        }
        var seed: Seed = .{ .kind = config.kind, .peer = config.connection.requester, .requests = config.connection.requests };
        try admin.send(config.connection.source, if (std.mem.eql(u8, command, "restore-policy")) -8 else if (std.mem.eql(u8, command, "lower-policy")) -7 else if (std.mem.eql(u8, command, "invalidate-kv")) -5 else -6);
        return drive(init, &server, .{ .context = &seed, .initialize = Seed.initialize, .handle = Seed.handle });
    }
    if (std.mem.eql(u8, command, "age")) {
        if (args.len != 5) return error.Usage;
        const entries = try std.fmt.parseInt(usize, args[4], 10);
        if (entries > 10000) return error.InvalidHistoryCount;
        for (0..entries) |_| _ = try admin.submit(.{ .spawn = .{} });
        return;
    }
    if (std.mem.eql(u8, command, "expire-request")) {
        if (config.expiry_at_ms == null) return error.ExpiryNotOptedIn;
        _ = try admin.submit(.{ .expire_resource = config.connection.requests });
        return print(init, (try admin.query(.{ .resource = config.connection.requests })).body.resource);
    }
    if (std.mem.eql(u8, command, "board-provision")) {
        const inspector = try p.Ed25519.KeyPair.generateDeterministic(@splat(12));
        _ = try admin.submit(.{ .grant = .{ .subject = 55, .public_key = inspector.public_key.toBytes(), .permissions = p.permission(.inspect) } });
        for ([_]u64{ config.connection.resource, config.connection.requests }) |resource| _ = try admin.submit(.{ .grant_resource = .{ .resource = resource, .subject = 55, .permissions = p.State.permission(.inspect) | p.State.permission(.read) } });
        return print(init, .{ .seed_file = try keyFile(init, directory, "inspector.seed", 12) });
    }
    var client: q.UnifiedClient = .{ .wire = &transport, .connection = config.connection, .key = try p.Ed25519.KeyPair.generateDeterministic(@splat(10)) };
    if (std.mem.eql(u8, command, "compile-count")) {
        if (args.len != 5) return error.Usage;
        const source = try config.source.native(init.arena.allocator());
        const result = try q.Bundle.fromSql(init.arena.allocator(), source, "items", args[4], budgets);
        if (result.plan.aggregate != .count_values) return error.ExpectedValueCount;
        var bytes: [q.Bundle.max_bytes]u8 = undefined;
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = try file(init, directory, "count-bundle.bin"), .data = try result.encode(&bytes) });
        return;
    }
    if (std.mem.eql(u8, command, "upload")) {
        for (0..1000) |_| {
            const pending = (try client.prepareNext(1, try bundle(config, init.arena.allocator()))) orelse return print(init, (try client.status(1)).?);
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
    if (std.mem.eql(u8, command, "status")) return print(init, try client.status(if (args.len == 5) try std.fmt.parseInt(u64, args[4], 10) else 1));
    if (std.mem.eql(u8, command, "activate-host")) {
        if (args.len != 6) return error.Usage;
        const requester = std.mem.eql(u8, args[4], "requester");
        if (!requester and !std.mem.eql(u8, args[4], "source")) return error.InvalidRole;
        const pid = if (requester) config.connection.requester else config.connection.source;
        const principal: u64 = if (requester) 65537 else 65536;
        const registration_bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, args[5], init.arena.allocator(), .limited(2048));
        const registration = (try std.json.parseFromSlice(s.client.bootstrap.GrowingRegistration, init.arena.allocator(), registration_bytes, .{})).value;
        const process = (try admin.query(.{ .process = pid })).body.process.process;
        if (registration.version != 1 or registration.realm != 46 or registration.pid != pid or registration.principal != principal or registration.generation != process.generation + 1) return error.InvalidRegistration;
        _ = try admin.submit(.{ .grant = .{ .subject = principal, .public_key = registration.public_key, .permissions = p.permission(.inspect) | p.permission(.execute) | p.permission(.publish), .pid = pid } });
        _ = try admin.submit(.{ .grant_resource = .{ .resource = if (requester) config.connection.requests else config.connection.resource, .subject = principal, .permissions = p.State.all_permissions } });
        if (!requester) _ = try admin.submit(.{ .grant_resource = .{ .resource = config.connection.requests, .subject = principal, .permissions = p.State.permission(.inspect) | p.State.permission(.read) } });
        _ = try admin.submit(.{ .own = .{ .pid = pid, .expected_generation = process.generation, .worker = principal } });
        return print(init, .{ .generation = process.generation + 1 });
    }
    if (std.mem.eql(u8, command, "host-generation")) {
        if (args.len != 5) return error.Usage;
        const requester = std.mem.eql(u8, args[4], "requester");
        if (!requester and !std.mem.eql(u8, args[4], "source")) return error.InvalidRole;
        const process = (try admin.query(.{ .process = if (requester) config.connection.requester else config.connection.source })).body.process.process;
        return print(init, .{ .generation = process.generation });
    }
    if (std.mem.eql(u8, command, "retire-source")) {
        _ = try admin.submit(.{ .terminate = config.connection.source });
        _ = try admin.submit(.{ .retire_resource = config.connection.resource });
        return;
    }
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
                _ = transport.query(.{ .realm = 46, .principal = 65536, .kind = .{ .version_entries = .{ .id = version.id, .generation = (try admin.query(.{ .process = config.connection.source })).body.process.process.generation } } }, try p.Ed25519.KeyPair.generateDeterministic(@splat(8))) catch {
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
        const workspace = try init.arena.allocator().alloc(u8, q.fuze.LogicalArrow.working_bytes);
        var bytes: [q.fuze.LogicalArrow.segment_bytes]u8 = undefined;
        var decoded: q.fuze.LogicalInspect.Batch = undefined;
        const page = try client.page(1, cursor, init.arena.allocator(), workspace, &bytes, &decoded);
        defer decoded.deinit();
        const ordinal = if (cursor) |previous| previous.ordinal else 0;
        const path_name = try std.fmt.allocPrint(init.arena.allocator(), "result-{d}.arrow", .{ordinal});
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = try file(init, directory, path_name), .data = page.arrow });
        if (page.next) |next| try save(init, directory, "cursor.json", next);
        return print(init, .{ .rows = decoded.rows.len, .ordinal = ordinal, .complete = page.next == null, .manifest = page.manifest });
    }
    if (std.mem.eql(u8, command, "versions")) {
        if (args.len != 4 and args.len != 6) return error.Usage;
        const after = if (args.len == 6) (try std.json.parseFromSlice(p.Growth.ReadVersionId, init.arena.allocator(), args[4], .{})).value else null;
        const position = if (args.len == 6) try std.fmt.parseInt(u64, args[5], 10) else null;
        const response = try admin.query(.{ .read_versions = .{ .pid = config.connection.source, .after = after, .position = position } });
        const versions = response.body.read_versions;
        return print(init, .{ .position = response.position, .entries = versions.entries, .next = versions.next });
    }
    return error.UnknownCommand;
}
