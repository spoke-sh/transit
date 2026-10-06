//! General typed Table proof through signed native ingress and GenServer hooks.
const std = @import("std");
const c = @import("transit_catalog");
const q = @import("transit_query");
const s = c.station;
const p = c.protocol;
const g = p.Growth;
const Admin = @import("growing_support.zig").Admin(46);
const Config = struct { definition: g.Definition, writer: Admin.Provision };
const Pending = struct { definition: g.Definition, pending: s.client.Session.Pending };
fn key(comptime byte: u8) !p.Ed25519.KeyPair {
    return p.Ed25519.KeyPair.generateDeterministic(@splat(byte));
}
fn configuration(config: Config) c.TableCatalogRecords.Configuration {
    return .{ .scope = .{ .realm = 46, .resource = config.writer.resource, .catalog = std.math.maxInt(u64) }, .owner = config.writer.pid, .administrator = 1234, .table_limits = .{ .record_bytes = c.fuze.TableRow.max_bytes, .staging_bytes = 2 * c.fuze.TableRow.max_bytes, .staging_records = 2 } };
}
fn path(init: std.process.Init, directory: []const u8, name: []const u8) ![]const u8 {
    return std.fmt.allocPrint(init.arena.allocator(), "{s}/{s}", .{ directory, name });
}
fn saveBytes(init: std.process.Init, directory: []const u8, name: []const u8, bytes: []const u8) !void {
    const dir = try std.Io.Dir.cwd().openDir(init.io, directory, .{ .iterate = true });
    defer dir.close(init.io);
    var file = try dir.createFileAtomic(init.io, name, .{ .replace = true, .permissions = .fromMode(0o600) });
    defer file.deinit(init.io);
    try file.file.writeStreamingAll(init.io, bytes);
    try file.file.sync(init.io);
    try file.replace(init.io);
    if (std.c.fsync(dir.handle) != 0) return error.SyncFailed;
}
fn save(init: std.process.Init, directory: []const u8, name: []const u8, value: anytype) !void {
    const bytes = try std.json.Stringify.valueAlloc(init.gpa, value, .{});
    defer init.gpa.free(bytes);
    try saveBytes(init, directory, name, bytes);
}
fn loadBytes(init: std.process.Init, directory: []const u8, name: []const u8, limit: usize) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(init.io, try path(init, directory, name), init.gpa, .limited(limit));
}
fn load(comptime T: type, init: std.process.Init, directory: []const u8, name: []const u8) !T {
    const bytes = try loadBytes(init, directory, name, 65536);
    defer init.gpa.free(bytes);
    const parsed = try std.json.parseFromSliceLeaky(T, init.arena.allocator(), bytes, .{});
    const encoded = try std.json.Stringify.valueAlloc(init.gpa, parsed, .{});
    defer init.gpa.free(encoded);
    if (!std.mem.eql(u8, bytes, encoded)) return error.NoncanonicalFixture;
    return parsed;
}
fn print(init: std.process.Init, value: anytype) !void {
    var buffer: [4096]u8 = undefined;
    var out = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    try std.json.Stringify.value(value, .{}, &out.interface);
    try out.interface.writeByte('\n');
    try out.interface.flush();
}
fn prepared(init: std.process.Init, directory: []const u8) !c.TableClient.Prepared {
    const bytes = try loadBytes(init, directory, "prepared.json", c.TableClient.Prepared.max_saved_bytes);
    defer init.gpa.free(bytes);
    return c.TableClient.Prepared.restore(init.gpa, bytes);
}
fn intent(init: std.process.Init, directory: []const u8) !c.TableIntent {
    const bytes = try loadBytes(init, directory, "intent.bin", c.TableIntent.max_bytes);
    defer init.gpa.free(bytes);
    return c.TableIntent.restore(init.gpa, bytes);
}
fn submit(init: std.process.Init, directory: []const u8, caller: *c.TableClient, value: c.TableClient.Prepared) !void {
    const saved = try value.save(init.gpa);
    defer init.gpa.free(saved);
    try saveBytes(init, directory, "prepared.json", saved);
    const receipt = try caller.submit(value);
    try save(init, directory, "input.json", receipt.position);
    try print(init, .{ .state = "sent", .input = receipt.position });
}
// A deployed host can advance the resource between bounded metadata reads.
// Retry only fresh read/preparation operations, never submit or captured scans.
fn currentRead(init: std.process.Init, wire: *s.client.Client, comptime function: anytype, arguments: std.meta.ArgsTuple(@TypeOf(function))) !@typeInfo(@typeInfo(@TypeOf(function)).@"fn".return_type.?).error_union.payload {
    var attempts: u8 = 0;
    while (true) {
        return @call(.auto, function, arguments) catch |err| {
            if (attempts == 64 or (err != error.Rejected and err != error.Conflict) or wire.last_rejection != .StaleStateResource) return err;
            attempts += 1;
            try init.io.sleep(.fromMilliseconds(1), .awake);
            continue;
        };
    }
}
fn outcome(init: std.process.Init, value: c.TableClient.Outcome) !void {
    switch (value) {
        .ddl => |result| try print(init, .{ .state = if (result.terminal()) "terminal" else "running", .kind = "ddl", .outcome = @tagName(result.operation.state), .table_outcome = if (result.table) |table| @tagName(table.state) else null, .reason = @tagName(result.operation.reason), .object = result.operation.actual_object }),
        .dml => |result| try print(init, .{ .state = if (result.state != .building) "terminal" else "running", .kind = "dml", .outcome = @tagName(result.state), .reason = @tagName(result.rejection), .matched = result.matched, .changed = result.changed }),
    }
}
fn host(init: std.process.Init, wire: *s.client.Client, directory: []const u8, original: Config, url: []const u8) !void {
    var admin: Admin = .{ .wire = wire, .key = try key(7) };
    admin.sequence = (try admin.query(.capabilities)).principal_sequence;
    var config = original;
    _ = try admin.submit(.{ .own = .{ .pid = config.writer.pid, .expected_generation = config.writer.generation, .worker = 65536 } });
    config.writer.generation += 1;
    try save(init, directory, "catalog.json", config);
    _ = try admin.submit(.{ .grant = .{ .subject = 65537, .public_key = (try key(9)).public_key.toBytes(), .permissions = p.permission(.inspect) | p.permission(.delivery) | p.permission(.send) } });
    try saveBytes(init, directory, "host.seed", &std.fmt.bytesToHex(@as([32]u8, @splat(8)), .lower));
    try saveBytes(init, directory, "courier.seed", &std.fmt.bytesToHex(@as([32]u8, @splat(9)), .lower));
    try saveBytes(init, directory, "caller.seed", &std.fmt.bytesToHex(@as([32]u8, @splat(10)), .lower));
    try save(init, directory, "host.json", .{ .url = url, .realm = @as(u64, 46), .principal = @as(u64, 65536), .pid = config.writer.pid, .generation = config.writer.generation, .seed_file = try path(init, directory, "host.seed"), .activation_directory = directory, .interval_ms = @as(u32, 2), .idle_max_interval_ms = @as(u32, 50), .request_timeout_ms = @as(u32, 10000), .role = .{ .catalog = configuration(config) } });
    try save(init, directory, "courier-config.json", .{ .url = url, .realm = @as(u64, 46), .principal = @as(u64, 65537), .seed_file = try path(init, directory, "courier.seed"), .interval_ms = @as(u32, 2), .idle_max_interval_ms = @as(u32, 50), .request_timeout_ms = @as(u32, 10000), .role = .{ .courier = .{ .destinations = [_]u64{config.writer.pid} } } });
    try save(init, directory, "console.json", .{ .version = @as(u8, 1), .profile = "catalog_v1", .url = url, .transport = "loopback", .seed_file = "caller.seed", .catalog = c.TableClient.Connection{ .scope = configuration(config).scope, .owner = config.writer.pid, .principal = 1234 }, .format = "json", .execution = "interactive", .writes = .{ .recovery_file = "console-writes.json" } });
    try print(init, .{ .generation = config.writer.generation });
}
fn deliver(init: std.process.Init, wire: *s.client.Client, directory: []const u8) !bool {
    const previous = load(Pending, init, directory, "courier.json") catch |err| switch (err) {
        error.FileNotFound => null,
        else => return err,
    };
    const pending = if (previous) |value| value else pending: {
        const state = try wire.query(.{ .realm = 46, .principal = 0, .kind = .delivery }, try key(7));
        const output = state.body.delivery.next orelse return false;
        const value: Pending = .{ .definition = g.current_definition, .pending = .{ .signed = try g.sign(.{ .realm = 46, .principal = 0, .sequence = state.principal_sequence + 1, .command = .{ .deliver = output } }, try key(7)) } };
        try save(init, directory, "courier.json", value);
        break :pending value;
    };
    _ = try pending.pending.submit(wire);
    try std.Io.Dir.cwd().deleteFile(init.io, try path(init, directory, "courier.json"));
    return true;
}
fn pump(init: std.process.Init, wire: *s.client.Client, directory: []const u8, config: Config, limit: usize) !void {
    // Exact pending native mutations are reconciled before creating a new host.
    const previous = load(Pending, init, directory, "worker.json") catch |err| switch (err) {
        error.FileNotFound => null,
        else => return err,
    };
    if (previous) |value| {
        _ = try value.pending.submit(wire);
        try std.Io.Dir.cwd().deleteFile(init.io, try path(init, directory, "worker.json"));
    }
    var behavior: c.TableBehavior = .{ .allocator = init.gpa, .configuration = configuration(config) };
    var server = try s.GenServer.init(.{ .client = wire, .realm = 46, .principal = 65536, .pid = config.writer.pid, .generation = config.writer.generation, .key = try key(8) }, "state");
    server.input_guard = behavior.guard();
    server.failure_policy = .stop;
    var committed: usize = 0;
    const until = std.Io.Clock.awake.now(init.io).toMilliseconds() + 300000;
    while (committed < limit) {
        if (std.Io.Clock.awake.now(init.io).toMilliseconds() >= until) return error.ProofTimedOut;
        const deadline: u64 = @intCast(std.Io.Clock.real.now(init.io).toMilliseconds() + 30000);
        switch (try server.prepare(deadline)) {
            .idle => if (try deliver(init, wire, directory)) continue else return print(init, .{ .state = "idle", .committed = committed }),
            .blocked => return error.BlockedOwner,
            .committed => unreachable,
            .progress => {},
            .ready => {
                const handler = behavior.interface();
                if (server.initializing) try handler.initialize.?(handler.context, &server.ready.?);
                try handler.handle(handler.context, &server.ready.?, try s.Frame.decode(server.ready.?.delivery.input.value));
                try server.finish(null);
            },
        }
        if (server.pending) |pending| {
            try save(init, directory, "worker.json", Pending{ .definition = g.current_definition, .pending = pending });
            const result = try server.dispatchPending();
            try std.Io.Dir.cwd().deleteFile(init.io, try path(init, directory, "worker.json"));
            if (result == .committed) committed += 1;
        }
    }
    try print(init, .{ .state = "pumped", .committed = committed });
}
fn inspect(init: std.process.Init, wire: *s.client.Client, caller: *c.TableClient, config: Config, name: []const u8) !void {
    var found = (try caller.lookup(init.gpa, try c.TableMetadata.Name.init(name))) orelse return print(init, .{ .found = false });
    defer found.deinit();
    var source = try (s.client.ResourceReader{ .wire = wire, .realm = 46, .principal = 1234, .key = try key(10) }).open(config.writer.resource);
    var definition = try (c.TableCatalog{ .configuration = configuration(config) }).readDefinition(init.gpa, &source, 1234, found.metadata.object, .{ .id = found.metadata.revision, .spec = try found.metadata.spec() });
    defer definition.deinit();
    var pages: s.TablePages.Reader(*s.client.ResourceReader.Reader) = .{ .pages = .{ .resource = config.writer.resource, .object = definition.metadata.object }, .source = &source };
    const data: s.TableData = .{ .schema = definition.schema.schema, .index = definition.head.index };
    var buffer: [4096]u8 = undefined;
    var out = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    try out.interface.print("{{\"found\":true,\"object\":{d},\"count\":{d},\"columns\":[", .{ definition.metadata.object, definition.head.rows });
    for (definition.schema.schema.columns, 0..) |column, index| {
        if (index != 0) try out.interface.writeByte(',');
        try std.json.Stringify.value(column.name, .{}, &out.interface);
    }
    try out.interface.writeAll("],\"rows\":[");
    var after: ?c.fuze.TableRow.Identity = null;
    var count: usize = 0;
    while (try data.next(init.gpa, &pages, after)) |value| {
        var row = value;
        defer row.deinit();
        if (count == 128) return error.ProofRowLimit;
        if (count != 0) try out.interface.writeByte(',');
        try out.interface.writeByte('[');
        for (row.row().cells, definition.schema.schema.columns, 0..) |cell, column, index| {
            if (index != 0) try out.interface.writeByte(',');
            const bytes = try c.fuze.LogicalJson.encode(init.gpa, cell, column.field());
            defer init.gpa.free(bytes);
            try out.interface.writeAll(bytes);
        }
        try out.interface.writeByte(']');
        after = row.identity;
        count += 1;
    }
    try out.interface.writeAll("]}\n");
    try out.interface.flush();
}
fn select(init: std.process.Init, caller: *c.TableClient, text: []const u8, held: bool, limits: q.TableQuery.Limits) !void {
    var nonce: [16]u8 = undefined;
    try init.io.randomSecure(&nonce);
    const cancelled = std.atomic.Value(bool).init(false);
    var query = try q.TableQuery.open(init.gpa, caller, text, nonce, limits, &cancelled, null);
    defer query.deinit();
    if (held) {
        try print(init, .{ .ready = true });
        var input_buffer: [32]u8 = undefined;
        var input = std.Io.File.stdin().readerStreaming(init.io, &input_buffer);
        _ = try input.interface.takeByte();
    }
    var fields: [128]c.fuze.Types.Field = undefined;
    const schema = try query.schema(&fields);
    const schema_json = try c.fuze.LogicalJson.encodeType(init.gpa, schema);
    defer init.gpa.free(schema_json);
    var buffer: [4096]u8 = undefined;
    var out = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    try out.interface.print("{{\"object\":{d},\"schema\":{s},\"rows\":[", .{ query.sourceObject(), schema_json });
    var count: usize = 0;
    while (query.next() catch |err| {
        if (query.native_rejection) |reason| std.debug.print("Query authority rejection: {s}\n", .{@tagName(reason)});
        return err;
    }) |value| {
        var row = value;
        defer row.deinit();
        if (count == 128) return error.ProofRowLimit;
        if (count != 0) try out.interface.writeByte(',');
        try out.interface.writeByte('[');
        for (row.cells, schema.structure, 0..) |cell, field, i| {
            if (i != 0) try out.interface.writeByte(',');
            const json = try c.fuze.LogicalJson.encode(init.gpa, cell, field);
            defer init.gpa.free(json);
            try out.interface.writeAll(json);
        }
        try out.interface.writeByte(']');
        count += 1;
    }
    if (!query.complete) return error.IncompleteSource;
    try out.interface.print("],\"complete\":true,\"scanned\":{d}}}\n", .{query.execution.scanned});
    try out.interface.flush();
}
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len == 2 and std.mem.eql(u8, args[1], "public")) return print(init, (try key(7)).public_key.toBytes());
    if (args.len < 4) return error.Usage;
    const mode = args[2];
    const directory = args[3];
    var wire = s.client.Client.init(init.gpa, init.io, args[1]);
    defer wire.deinit();
    wire.timeout_ms = 10000;
    errdefer if (wire.last_rejection) |reason| std.debug.print("Authority rejection: {s}\n", .{@tagName(reason)});
    if (std.mem.eql(u8, mode, "provision")) {
        var admin: Admin = .{ .wire = &wire, .key = try key(7) };
        admin.sequence = (try admin.query(.capabilities)).principal_sequence;
        const config: Config = .{ .definition = g.current_definition, .writer = try admin.provision(65536, try key(8)) };
        _ = try admin.submit(.{ .grant = .{ .subject = 1234, .public_key = (try key(10)).public_key.toBytes(), .permissions = p.permission(.inspect) | p.permission(.send) } });
        _ = try admin.submit(.{ .grant_resource = .{ .resource = config.writer.resource, .subject = 1234, .permissions = p.State.permission(.inspect) | p.State.permission(.read) } });
        try save(init, directory, "catalog.json", config);
        return print(init, config);
    }
    const config = try load(Config, init, directory, "catalog.json");
    const owner = configuration(config);
    var caller: c.TableClient = .{ .transport = &wire, .connection = .{ .scope = owner.scope, .owner = owner.owner, .principal = 1234 }, .key = try key(10) };
    if (std.mem.eql(u8, mode, "host")) return host(init, &wire, directory, config, args[1]);
    if (std.mem.eql(u8, mode, "initialize")) return submit(init, directory, &caller, try caller.prepareControl(.{ .initialize = owner }));
    if (std.mem.eql(u8, mode, "pump")) return pump(init, &wire, directory, config, if (args.len > 4) try std.fmt.parseInt(usize, args[4], 10) else 10000);
    if (std.mem.eql(u8, mode, "inspect")) return inspect(init, &wire, &caller, config, args[4]);
    if (std.mem.startsWith(u8, mode, "select")) return select(init, &caller, args[4], std.mem.eql(u8, mode, "select-held"), if (args.len == 8) .{ .requests = try std.fmt.parseInt(u64, args[5], 10), .rows = try std.fmt.parseInt(u64, args[6], 10), .result_bytes = try std.fmt.parseInt(u64, args[7], 10) } else .{ .requests = 10000, .rows = 128, .result_bytes = 8 * 1024 * 1024 });
    if (std.mem.eql(u8, mode, "assist")) return print(init, try currentRead(init, &wire, q.TableAssistance.complete, .{ init.arena.allocator(), &caller, .{ .sql = args[4], .cursor = try std.fmt.parseInt(u16, args[5], 10), .generation = 7, .mode = .console } }));
    if (std.mem.eql(u8, mode, "policy")) {
        const description = try caller.describe();
        var policy = description.policy;
        policy.revision += 1;
        policy.read = std.mem.eql(u8, args[4], "allow");
        return submit(init, directory, &caller, try caller.prepareControl(.{ .policy = .{ .expected_revision = description.policy.revision, .policy = policy } }));
    }
    if (std.mem.eql(u8, mode, "retry-send")) return submit(init, directory, &caller, try prepared(init, directory));
    if (std.mem.eql(u8, mode, "compile")) {
        const operation = try std.fmt.parseInt(u64, args[4], 10);
        var work = try currentRead(init, &wire, c.TableClient.compile, .{ &caller, init.gpa, args[6], .{ .operation = operation, .namespace = 1000 + operation, .create_object = if (std.mem.eql(u8, args[5], "-")) null else try std.fmt.parseInt(u64, args[5], 10) }, null });
        defer work.deinit();
        try saveBytes(init, directory, "intent.bin", work.bytes);
        return print(init, .{ .kind = @tagName(work.header.kind), .bytes = work.body.len, .namespace = work.namespace });
    }
    var work = try intent(init, directory);
    defer work.deinit();
    if (std.mem.eql(u8, mode, "next")) return switch (try currentRead(init, &wire, c.TableClient.next, .{ &caller, &work })) {
        .send => |value| submit(init, directory, &caller, value),
        .running => print(init, .{ .state = "running" }),
        .terminal => |value| outcome(init, value),
        .upload_cancelled => print(init, .{ .state = "upload_cancelled" }),
    };
    if (std.mem.eql(u8, mode, "status")) return if (try currentRead(init, &wire, c.TableClient.status, .{ &caller, &work })) |value| outcome(init, value) else print(init, .{ .state = "absent" });
    if (std.mem.eql(u8, mode, "progress")) {
        const result = try currentRead(init, &wire, c.TableClient.waitProgress, .{ &caller, &work, try prepared(init, directory), try load(u64, init, directory, "input.json") });
        return switch (result) {
            .pending => print(init, .{ .state = "pending" }),
            .processed => |value| if (value.disposition) |entry| print(init, .{ .state = "disposed", .reason = @tagName(entry.outcome) }) else if (value.outcome) |entry| outcome(init, entry) else print(init, .{ .state = "processed" }),
        };
    }
    if (std.mem.eql(u8, mode, "resume")) return submit(init, directory, &caller, try caller.prepareResume(&work));
    if (std.mem.eql(u8, mode, "cancel")) {
        const control: c.TableControl.Command = if (work.body.len > s.Frame.max_payload) .{ .cancel_upload = work.upload() } else switch (work.identity) {
            .ddl => |ref| .{ .cancel_ddl = ref },
            .dml => |ref| .{ .cancel_dml = .{ .scope = owner.scope, .reference = ref.reference } },
        };
        return submit(init, directory, &caller, try caller.prepareControl(control));
    }
    return error.Usage;
}
