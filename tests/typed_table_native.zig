//! General typed Table proof through signed native ingress and GenServer hooks.
const std = @import("std");
const c = @import("transit_catalog");
const q = @import("transit_query");
const s = c.station;
const p = c.protocol;
const g = p.Growth;
const Admin = @import("growing_support.zig").Admin(46);
pub const Config = struct { definition: g.Definition, writer: Admin.Provision, worker: u64, owner_role: u64, authority: c.TableAuthority.Profile };
const Pending = struct { definition: g.Definition, pending: s.client.Session.Pending };
pub fn key(comptime byte: u8) !p.Ed25519.KeyPair {
    return p.Ed25519.KeyPair.generateDeterministic(@splat(byte));
}
pub fn configuration(config: Config) c.TableCatalogRecords.Configuration {
    return .{ .scope = .{ .realm = 46, .resource = config.writer.resource, .catalog = std.math.maxInt(u64) }, .owner = config.writer.pid, .administrator = 1234, .authority = config.authority, .database_name = c.TableAuthority.Name.init("transit") catch unreachable, .table_limits = .{ .record_bytes = c.fuze.TableRow.max_bytes, .staging_bytes = 2 * c.fuze.TableRow.max_bytes, .staging_records = 2 } };
}
pub fn path(init: std.process.Init, directory: []const u8, name: []const u8) ![]const u8 {
    return std.fmt.allocPrint(init.arena.allocator(), "{s}/{s}", .{ directory, name });
}
pub fn saveBytes(init: std.process.Init, directory: []const u8, name: []const u8, bytes: []const u8) !void {
    const dir = try std.Io.Dir.cwd().openDir(init.io, directory, .{ .iterate = true });
    defer dir.close(init.io);
    var file = try dir.createFileAtomic(init.io, name, .{ .replace = true, .permissions = .fromMode(0o600) });
    defer file.deinit(init.io);
    try file.file.writeStreamingAll(init.io, bytes);
    try file.file.sync(init.io);
    try file.replace(init.io);
    if (std.c.fsync(dir.handle) != 0) return error.SyncFailed;
}
pub fn save(init: std.process.Init, directory: []const u8, name: []const u8, value: anytype) !void {
    const bytes = try std.json.Stringify.valueAlloc(init.gpa, value, .{});
    defer init.gpa.free(bytes);
    try saveBytes(init, directory, name, bytes);
}
pub fn loadBytes(init: std.process.Init, directory: []const u8, name: []const u8, limit: usize) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(init.io, try path(init, directory, name), init.gpa, .limited(limit));
}
pub fn load(comptime T: type, init: std.process.Init, directory: []const u8, name: []const u8) !T {
    const bytes = try loadBytes(init, directory, name, 65536);
    defer init.gpa.free(bytes);
    const parsed = try std.json.parseFromSliceLeaky(T, init.arena.allocator(), bytes, .{});
    const encoded = try std.json.Stringify.valueAlloc(init.gpa, parsed, .{});
    defer init.gpa.free(encoded);
    if (!std.mem.eql(u8, bytes, encoded)) return error.NoncanonicalFixture;
    return parsed;
}
pub fn print(init: std.process.Init, value: anytype) !void {
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
    const started = std.Io.Clock.awake.now(init.io);
    while (true) {
        return @call(.auto, function, arguments) catch |err| {
            const unavailable = s.client.Client.unavailable(err) or wire.contended(err);
            const stale = (err == error.Rejected or err == error.Conflict) and wire.last_rejection == .StaleStateResource;
            if ((!unavailable and !stale) or (unavailable and started.durationTo(std.Io.Clock.awake.now(init.io)).toSeconds() >= 30) or (!unavailable and attempts == 64)) return err;
            if (!unavailable) attempts += 1;
            try init.io.sleep(.fromMilliseconds(if (unavailable) 20 else 1), .awake);
            continue;
        };
    }
}
const Witness = struct {
    source: []const u8,
    row: c.fuze.TableRow.Identity,
    column: u64,
    preview: []const u8,
    truncated: bool,
    fn from(value: *const c.fuze.TableWitness) Witness {
        return .{ .source = @tagName(value.source), .row = value.row, .column = value.column, .preview = value.text(), .truncated = value.truncated };
    }
};
fn outcome(init: std.process.Init, value: c.TableClient.Outcome) !void {
    switch (value) {
        .ddl => |*result| try print(init, .{ .state = if (result.terminal()) "terminal" else "running", .kind = "ddl", .outcome = @tagName(result.operation.state), .table_outcome = if (result.table) |table| @tagName(table.state) else null, .reason = @tagName(result.operation.reason), .object = result.operation.actual_object, .witness = if (result.table) |*table| Witness.from(&table.witness) else null }),
        .dml => |*result| try print(init, .{ .state = if (result.state != .building) "terminal" else "running", .kind = "dml", .outcome = @tagName(result.state), .reason = @tagName(result.rejection), .matched = result.matched, .changed = result.changed, .witness = Witness.from(&result.witness) }),
    }
}
fn host(init: std.process.Init, wire: *s.client.Client, directory: []const u8, original: Config, url: []const u8) !void {
    var admin: Admin = .{ .wire = wire, .key = try key(7) };
    admin.sequence = (try admin.query(.capabilities)).principal_sequence;
    var config = original;
    _ = try admin.submit(.{ .own = .{ .pid = config.writer.pid, .expected_generation = config.writer.generation, .worker = config.worker } });
    config.writer.generation += 1;
    try save(init, directory, "catalog.json", config);
    _ = try admin.submit(.{ .grant = .{ .subject = 65537, .public_key = (try key(9)).public_key.toBytes(), .permissions = p.permission(.inspect) | p.permission(.delivery) | p.permission(.send) } });
    try saveBytes(init, directory, "host.seed", &std.fmt.bytesToHex(@as([32]u8, @splat(8)), .lower));
    try saveBytes(init, directory, "courier.seed", &std.fmt.bytesToHex(@as([32]u8, @splat(9)), .lower));
    try saveBytes(init, directory, "caller.seed", &std.fmt.bytesToHex(@as([32]u8, @splat(10)), .lower));
    try save(init, directory, "host.json", .{ .url = url, .realm = @as(u64, 46), .principal = config.worker, .pid = config.writer.pid, .generation = config.writer.generation, .seed_file = try path(init, directory, "host.seed"), .activation_directory = directory, .interval_ms = @as(u32, 2), .idle_max_interval_ms = @as(u32, 50), .request_timeout_ms = @as(u32, 10000), .role = .{ .catalog = configuration(config) } });
    try save(init, directory, "courier-config.json", .{ .url = url, .realm = @as(u64, 46), .principal = @as(u64, 65537), .seed_file = try path(init, directory, "courier.seed"), .interval_ms = @as(u32, 2), .idle_max_interval_ms = @as(u32, 50), .request_timeout_ms = @as(u32, 10000), .role = .{ .courier = .{ .destinations = [_]u64{config.writer.pid} } } });
    try save(init, directory, "console.json", .{ .version = @as(u8, 1), .profile = "catalog_v1", .url = url, .transport = "loopback", .seed_file = "caller.seed", .catalog = c.TableClient.Connection{ .scope = configuration(config).scope, .owner = config.writer.pid, .principal = 1234 }, .format = "json", .execution = "interactive", .writes = .{ .recovery_file = "console-writes.json" } });
    try print(init, .{ .generation = config.writer.generation });
}
pub fn deliver(init: std.process.Init, wire: *s.client.Client, directory: []const u8) !bool {
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
    var server = try s.GenServer.init(.{ .client = wire, .realm = 46, .principal = config.worker, .pid = config.writer.pid, .generation = config.writer.generation, .key = try key(8) }, "state");
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
                handler.handle(handler.context, &server.ready.?, try s.Frame.decode(server.ready.?.delivery.input.value)) catch |err| {
                    if (err != error.CatalogRegistrationRequired) return err;
                    const action = behavior.registration orelse return err;
                    if (action != .register_object) return error.InvalidAuthorizationObject;
                    try server.discard();
                    const registrar: s.client.AuthorizationClient = .{ .transport = wire, .realm = 46, .principal = config.worker, .key = try key(8) };
                    const registration = try registrar.registration(action.register_object);
                    if (registration == .submit) _ = try wire.submit(registration.submit);
                    continue;
                };
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
    var raw = try (s.client.ResourceReader{ .wire = wire, .realm = 46, .principal = 1234, .key = try key(10) }).open(config.writer.resource);
    var source = (try caller.authorizationContext()).wrap(&raw);
    var definition = try (c.TableCatalog{ .configuration = configuration(config) }).readDefinition(init.gpa, &source, 1234, found.metadata.object, .{ .id = found.metadata.revision, .spec = try found.metadata.spec() });
    defer definition.deinit();
    var pages: s.TablePages.Reader(@TypeOf(&source)) = .{ .pages = .{ .resource = config.writer.resource, .object = definition.metadata.object }, .source = &source };
    const data: s.TableData = .{ .schema = definition.schema.schema, .index = definition.head.index };
    var buffer: [4096]u8 = undefined;
    var out = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    try out.interface.print("{{\"found\":true,\"object\":{d},\"count\":{d},\"head\":", .{ definition.metadata.object, definition.head.rows });
    try std.json.Stringify.value(definition.head, .{}, &out.interface);
    try out.interface.writeAll(",\"columns\":[");
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
        try source.finish();
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
    try source.finish();
    try out.interface.writeAll("]}\n");
    try out.interface.flush();
}
fn select(comptime batched: bool, buffered: bool, disclosure: bool, init: std.process.Init, caller: *c.TableClient, text: []const u8, held: bool, limits: q.TableQuery.Limits) !void {
    var nonce: [16]u8 = undefined;
    try init.io.randomSecure(&nonce);
    const cancelled = std.atomic.Value(bool).init(false);
    const Query = if (batched) q.TableQuery else q.ReferenceTableQuery;
    var query = try Query.open(init.gpa, caller, text, nonce, limits, &cancelled, null);
    defer query.deinit();
    if (buffered) {
        // Two disclosures force the experimental engine to retain a private
        // remainder, then pause before its next current-policy check.
        for (0..2) |_| {
            var row = (try query.next()) orelse return error.ExpectedBufferedRows;
            row.deinit();
        }
    }
    if (held or buffered) {
        try print(init, .{ .ready = true });
        var input_buffer: [32]u8 = undefined;
        var input = std.Io.File.stdin().readerStreaming(init.io, &input_buffer);
        while (try input.interface.takeByte() == 'k') {
            // Holding a source through slow mutations still requires an active
            // lease. Renew through the same authorized public read operation;
            // never reopen the cut or extend its hard lifetime.
            const snapshot = query.execution.scan.source.snapshot;
            try query.execution.scan.validateCurrent(false);
            const renewed = query.execution.scan.source.snapshot;
            if (!std.meta.eql(snapshot.id, renewed.id) or snapshot.hard_deadline_ms != renewed.hard_deadline_ms or !std.meta.eql(snapshot.resource, renewed.resource)) return error.ChangedHeldSnapshot;
            try print(init, .{ .renewed = true });
        }
    }
    var fields: [128]c.fuze.Types.Field = undefined;
    const schema = try query.schema(&fields);
    const schema_json = try c.fuze.LogicalJson.encodeType(init.gpa, schema);
    defer init.gpa.free(schema_json);
    var buffer: [4096]u8 = undefined;
    var out = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    try out.interface.print("{{\"object\":{d},\"schema\":{s},\"rows\":[", .{ query.sourceObject(), schema_json });
    var count: usize = 0;
    while (true) {
        var batch = query.nextBatch(if (disclosure) 8 else 1) catch |err| {
            if (query.native_rejection) |reason| std.debug.print("Query authority rejection: {s}\n", .{@tagName(reason)});
            return err;
        };
        defer batch.deinit();
        for (batch.rows[0..batch.len]) |value| {
            const row = value.?;
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
        if (batch.complete) break;
    }
    if (!query.complete) return error.IncompleteSource;
    try out.interface.print("],\"complete\":true,\"scanned\":{d},\"requests\":{d}}}\n", .{ query.execution.scanned, query.execution.scan.requests });
    try out.interface.flush();
}
fn relational(init: std.process.Init, directory: []const u8, caller: *c.TableClient, text: []const u8, held: bool, second_directory: ?[]const u8) !void {
    var syntax = try c.fuze.RelationalSql.parse(init.gpa, text, null);
    defer syntax.deinit();
    var nonces: [2][16]u8 = undefined;
    try init.io.randomSecure(std.mem.asBytes(&nonces));
    const spill_name = try std.fmt.allocPrint(init.arena.allocator(), "relational-{s}", .{std.fmt.bytesToHex(nonces[0], .lower)});
    const dir = try std.Io.Dir.cwd().openDir(init.io, directory, .{});
    defer dir.close(init.io);
    var second = caller.*;
    if (second_directory) |other| {
        const other_owner = configuration(try load(Config, init, other, "catalog.json"));
        second.connection = .{ .scope = other_owner.scope, .owner = other_owner.owner, .principal = caller.connection.principal };
    }
    const clients = [_]*c.TableClient{ caller, &second };
    const query = try q.RelationalQuery.open(init.gpa, init.io, dir, spill_name, clients[0..syntax.targets.len], text, nonces, .{ .consistency = .per_resource_snapshot_vector, .budgets = .{ .resident_bytes = 16 * 1024 * 1024, .spill_bytes = 16 * 1024 * 1024, .result_bytes = 8 * 1024 * 1024, .output_rows = 1000, .work_steps = 100000, .source_pins = 2 }, .requests = 100000, .spill_work = 100000 }, null, null);
    defer query.deinit();
    if (held) {
        try print(init, .{ .ready = true });
        var input_buffer: [32]u8 = undefined;
        var input = std.Io.File.stdin().readerStreaming(init.io, &input_buffer);
        _ = try input.interface.takeByte();
    }
    var fields: [128]c.fuze.Types.Field = undefined;
    const schema = try query.schema(&fields);
    var buffer: [4096]u8 = undefined;
    var out = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    try out.interface.print("{{\"plan\":\"{s}\",\"cuts\":", .{std.fmt.bytesToHex(try query.execution.bound.plan.fingerprint(), .lower)});
    try std.json.Stringify.value(query.tables.cuts[0..query.tables.count], .{}, &out.interface);
    try out.interface.writeAll(",\"rows\":[");
    var count: usize = 0;
    while (try query.next()) |row| {
        if (count != 0) try out.interface.writeByte(',');
        try out.interface.writeByte('[');
        for (row.cells[0..row.len], schema.structure, 0..) |cell, field, i| {
            if (i != 0) try out.interface.writeByte(',');
            const json = try c.fuze.LogicalJson.encode(init.gpa, cell, field);
            defer init.gpa.free(json);
            try out.interface.writeAll(json);
        }
        try out.interface.writeByte(']');
        count += 1;
    }
    if (!query.complete) return error.IncompleteSource;
    try out.interface.print("],\"complete\":true,\"requests\":{d},\"spill_bytes\":{d},\"heap_peak\":{d}}}\n", .{ query.tables.requests, query.spill.count * query.spill.record_bytes, query.memory.peak });
    try out.interface.flush();
}
fn tablePrivileges(init: std.process.Init, admin: *Admin, caller: *c.TableClient, config: Config, role: u64, privileges: u64, allowed: bool) !void {
    var cursor: ?c.TableCatalog.Cursor = null;
    while (true) {
        const page = try currentRead(init, admin.wire, c.TableClient.list, .{ caller, cursor });
        for (page.entries) |slot| if (slot) |entry| {
            const binding = try c.TableAuthority.binding(configuration(config).scope, .table, entry.metadata.object);
            const target = (try admin.query(.{ .authorization = .{ .kind = .{ .binding = .{ .domain = config.authority.table_domain, .key = binding } } } })).body.authorization.body.binding orelse return error.MissingProofTable;
            _ = try admin.authorization(if (allowed)
                .{ .grant = .{ .object = target.reference, .grantee = role, .privileges = privileges } }
            else
                .{ .revoke_privileges = .{ .object = target.reference, .grantee = role, .privileges = privileges, .behavior = .cascade } });
        };
        cursor = page.next orelse return;
    }
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
        const worker = if (args.len > 4) try std.fmt.parseInt(u64, args[4], 10) else 65536;
        const provision = try admin.provision(worker, try key(8));
        // The Table owner is an ordinary LOGIN role. Private worker roles only
        // execute and register objects; they never own the logical database.
        if (worker == 65536) {
            const role = (try admin.authorization(.{ .create_role = .{ .name = try p.Value.init("table-owner"), .login = true } })).?;
            _ = try admin.authorization(.{ .bind_credential = .{ .principal = 1234, .role = role, .public_key = (try key(10)).public_key.toBytes() } });
            _ = try admin.authorization(.{ .grant = .{ .object = .{ .kind = .realm, .id = 0 }, .grantee = role, .privileges = p.permission(.inspect) | p.permission(.send) } });
        }
        const identity: s.client.AuthorizationClient = .{ .transport = &wire, .realm = 46, .principal = 1234, .key = try key(10) };
        const owner_role = (try identity.read(.identity)).body.authorization.body.identity.login_role;
        const scope: c.Model.Scope = .{ .realm = 46, .resource = provision.resource, .catalog = std.math.maxInt(u64) };
        const database_domain = (try admin.authorization(.{ .register_domain = .{ .registrar = worker, .actions = c.TableAuthority.connect } })).?;
        const schema_domain = (try admin.authorization(.{ .register_domain = .{ .registrar = worker, .actions = c.TableAuthority.usage | c.TableAuthority.create } })).?;
        const table_domain = (try admin.authorization(.{ .register_domain = .{ .registrar = worker, .actions = c.TableAuthority.table_actions } })).?;
        const database = (try admin.authorization(.{ .register_object = .{ .domain = database_domain, .owner = owner_role, .binding = try c.TableAuthority.binding(scope, .database, 0) } })).?;
        const schema = (try admin.authorization(.{ .register_object = .{ .domain = schema_domain, .owner = owner_role, .schema = c.TableAuthority.reference(database), .binding = try c.TableAuthority.binding(scope, .schema, 1) } })).?;
        const config: Config = .{ .definition = g.current_definition, .writer = provision, .worker = worker, .owner_role = owner_role, .authority = .{ .database_domain = database_domain, .schema_domain = schema_domain, .table_domain = table_domain, .database = database, .initial_schema = 1, .initial_schema_authority = schema } };
        _ = try admin.submit(.{ .grant_resource = .{ .resource = config.writer.resource, .subject = 1234, .permissions = p.State.permission(.inspect) | p.State.permission(.read) } });
        try save(init, directory, "catalog.json", config);
        return print(init, config);
    }
    const config = try load(Config, init, directory, "catalog.json");
    if (std.mem.eql(u8, mode, "activate-host")) {
        if (args.len != 5) return error.Usage;
        var public: [32]u8 = undefined;
        if ((try std.fmt.hexToBytes(&public, args[4])).len != 32) return error.InvalidPublicKey;
        var admin: Admin = .{ .wire = &wire, .key = try key(7) };
        admin.sequence = (try admin.query(.capabilities)).principal_sequence;
        _ = try admin.submit(.{ .grant = .{ .subject = config.worker, .public_key = public, .permissions = p.permission(.inspect) | p.permission(.execute) | p.permission(.publish), .pid = config.writer.pid } });
        _ = try admin.submit(.{ .grant_resource = .{ .resource = config.writer.resource, .subject = config.worker, .permissions = p.State.all_permissions } });
        _ = try admin.submit(.{ .own = .{ .pid = config.writer.pid, .expected_generation = config.writer.generation, .worker = config.worker } });
        var replacement = config;
        replacement.writer.generation += 1;
        try save(init, directory, "catalog.json", replacement);
        return print(init, .{ .generation = replacement.writer.generation });
    }
    if (std.mem.eql(u8, mode, "board-inspector")) {
        var admin: Admin = .{ .wire = &wire, .key = try key(7) };
        admin.sequence = (try admin.query(.capabilities)).principal_sequence;
        if (config.worker == 65536) _ = try admin.submit(.{ .grant = .{ .subject = 1240, .public_key = (try key(12)).public_key.toBytes(), .permissions = p.permission(.inspect) } });
        _ = try admin.submit(.{ .grant_resource = .{ .resource = config.writer.resource, .subject = 1240, .permissions = p.State.permission(.inspect) | p.State.permission(.read) } });
        try saveBytes(init, directory, "board-inspector.seed", &std.fmt.bytesToHex(@as([32]u8, @splat(12)), .lower));
        return print(init, .{ .principal = @as(u64, 1240) });
    }
    const owner = configuration(config);
    var caller: c.TableClient = .{ .transport = &wire, .connection = .{ .scope = owner.scope, .owner = owner.owner, .principal = 1234 }, .key = try key(10) };
    if (std.mem.eql(u8, mode, "external-provision")) {
        // Provision before assigning either principal's dedicated sequence role.
        // The wire fixture uses 1235 for SQL and retains 1234 for administration.
        var admin: Admin = .{ .wire = &wire, .key = try key(7) };
        admin.sequence = (try admin.query(.capabilities)).principal_sequence;
        const login = (try admin.authorization(.{ .create_role = .{ .name = try p.Value.init("gateway-login"), .login = true } })).?;
        const role = (try admin.authorization(.{ .create_role = .{ .name = try p.Value.init("gateway-caller") } })).?;
        _ = try admin.authorization(.{ .membership = .{ .member = login, .role = role, .inherit = false, .set = true } });
        // Independent schema tests explicitly select the SQL-created object's
        // owner role. Catalog administration alone does not confer ownership.
        _ = try admin.authorization(.{ .membership = .{ .member = config.owner_role, .role = role, .inherit = false, .set = true } });
        _ = try admin.authorization(.{ .bind_credential = .{ .principal = 1235, .role = login, .public_key = (try key(11)).public_key.toBytes() } });
        _ = try admin.authorization(.{ .grant = .{ .object = .{ .kind = .realm, .id = 0 }, .grantee = role, .privileges = p.permission(.send) } });
        _ = try admin.authorization(.{ .grant = .{ .object = c.TableAuthority.reference(config.authority.database), .grantee = role, .privileges = c.TableAuthority.connect } });
        _ = try admin.authorization(.{ .grant = .{ .object = c.TableAuthority.reference(config.authority.initial_schema_authority), .grantee = role, .privileges = c.TableAuthority.usage | c.TableAuthority.create } });
        _ = try admin.authorization(.{ .default_grant = .{ .creator = config.owner_role, .schema = c.TableAuthority.reference(config.authority.initial_schema_authority), .domain = config.authority.table_domain, .grantee = role, .privileges = c.TableAuthority.table_actions } });
        _ = try admin.authorization(.{ .default_grant = .{ .creator = role, .schema = c.TableAuthority.reference(config.authority.initial_schema_authority), .domain = config.authority.table_domain, .grantee = config.owner_role, .privileges = c.TableAuthority.table_actions } });
        try tablePrivileges(init, &admin, &caller, config, role, c.TableAuthority.table_actions, true);
        return print(init, .{ .principal = @as(u64, 1235), .role = role });
    }
    if (std.mem.eql(u8, mode, "external-role")) {
        var admin: Admin = .{ .wire = &wire, .key = try key(7) };
        admin.sequence = (try admin.query(.capabilities)).principal_sequence;
        const role = (try admin.query(.{ .authorization = .{ .kind = .{ .resolve = try p.Value.init("gateway-caller") } } })).body.authorization.body.resolve.id;
        const login = (try admin.query(.{ .authorization = .{ .kind = .{ .resolve = try p.Value.init("gateway-login") } } })).body.authorization.body.resolve.id;
        const allowed = std.mem.eql(u8, args[4], "allow");
        if (allowed) {
            _ = try admin.authorization(.{ .membership = .{ .member = login, .role = role, .inherit = false, .set = true } });
        } else {
            const page = (try admin.query(.{ .authorization = .{ .kind = .{ .memberships = .{ .member = login } } } })).body.authorization.body.memberships;
            if (page.next != null) return error.UnexpectedProofMemberships;
            var found = false;
            for (page.records) |slot| if (slot) |membership| {
                if (membership.role != role or !membership.set) continue;
                _ = try admin.authorization(.{ .revoke_membership = .{ .id = membership.id, .option = .set, .behavior = .cascade } });
                found = true;
            };
            if (!found) return error.MissingProofMembership;
        }
        return print(init, .{ .selected = allowed });
    }
    if (std.mem.eql(u8, mode, "external-write-grants")) {
        // Principal 1234 administers the catalog; 1235 belongs exclusively to
        // the SQL gateway in this fixture. Reads never borrow its sequence.
        var admin: Admin = .{ .wire = &wire, .key = try key(7) };
        admin.sequence = (try admin.query(.capabilities)).principal_sequence;
        const role = (try admin.query(.{ .authorization = .{ .kind = .{ .resolve = try p.Value.init("gateway-caller") } } })).body.authorization.body.resolve.id;
        const allowed = std.mem.eql(u8, args[4], "allow");
        const schema = c.TableAuthority.reference(config.authority.initial_schema_authority);
        _ = try admin.authorization(if (allowed)
            .{ .grant = .{ .object = schema, .grantee = role, .privileges = c.TableAuthority.create } }
        else
            .{ .revoke_privileges = .{ .object = schema, .grantee = role, .privileges = c.TableAuthority.create, .behavior = .cascade } });
        try tablePrivileges(init, &admin, &caller, config, role, c.TableAuthority.insert | c.TableAuthority.update | c.TableAuthority.delete, allowed);
        return print(init, .{ .write = allowed, .revision = (try admin.query(.{ .authorization = .{ .kind = .identity } })).body.authorization.revision });
    }
    if (std.mem.eql(u8, mode, "external-ddl") or std.mem.eql(u8, mode, "external-ddl-admin")) {
        const operator: s.client.AuthorizationClient = .{ .transport = &wire, .realm = owner.scope.realm, .principal = 1234, .key = try key(10) };
        caller.connection.role = (try currentRead(init, &wire, s.client.AuthorizationClient.read, .{ operator, @FieldType(p.Authorization.Query, "kind"){ .resolve = try p.Value.init("gateway-caller") } })).body.authorization.body.resolve.id;
        if (std.mem.eql(u8, mode, "external-ddl")) {
            caller.connection.principal = 1235;
            caller.key = try key(11);
        }
        const operation = try std.fmt.parseInt(u64, args[4], 10);
        var work = try currentRead(init, &wire, c.TableClient.compile, .{ &caller, init.gpa, args[5], .{ .operation = operation, .namespace = 1000 + operation, .create_object = if (std.mem.startsWith(u8, args[5], "CREATE")) operation else null }, null });
        defer work.deinit();
        try saveBytes(init, directory, "external-intent.bin", work.bytes);
        const started = std.Io.Clock.awake.now(init.io);
        while (started.durationTo(std.Io.Clock.awake.now(init.io)).toSeconds() < 120) {
            switch (try currentRead(init, &wire, c.TableClient.next, .{ &caller, &work })) {
                .send => |request| {
                    const saved = try request.save(init.gpa);
                    defer init.gpa.free(saved);
                    try saveBytes(init, directory, "external-prepared.json", saved);
                    const receipt = while (true) {
                        // The proposal was saved above. Retry only these exact
                        // signed bytes, never compilation or a new sequence.
                        break caller.submit(request) catch |err| {
                            if ((!s.client.Client.unavailable(err) and !wire.contended(err)) or started.durationTo(std.Io.Clock.awake.now(init.io)).toSeconds() >= 120) return err;
                            try init.io.sleep(.fromMilliseconds(20), .awake);
                            continue;
                        };
                    };
                    while (true) {
                        const progress = try currentRead(init, &wire, c.TableClient.waitProgress, .{ &caller, &work, request, receipt.position });
                        if (progress != .pending) break;
                        if (started.durationTo(std.Io.Clock.awake.now(init.io)).toSeconds() >= 120) return error.ProofTimeout;
                        try init.io.sleep(.fromMilliseconds(5), .awake);
                    }
                },
                .terminal => |value| return outcome(init, value),
                .upload_cancelled => return error.UnexpectedUploadCancellation,
                .running => try init.io.sleep(.fromMilliseconds(5), .awake),
            }
        }
        return error.ProofTimeout;
    }
    if (std.mem.eql(u8, mode, "host")) return host(init, &wire, directory, config, args[1]);
    if (std.mem.eql(u8, mode, "initialize")) return submit(init, directory, &caller, try caller.prepareControl(.{ .initialize = owner }));
    if (std.mem.eql(u8, mode, "pump")) return pump(init, &wire, directory, config, if (args.len > 4) try std.fmt.parseInt(usize, args[4], 10) else 10000);
    if (std.mem.eql(u8, mode, "inspect")) return inspect(init, &wire, &caller, config, args[4]);
    if (std.mem.startsWith(u8, mode, "prepared-")) return @import("table_parameters_native.zig").run(@This(), init, &caller, directory, args);
    if (std.mem.startsWith(u8, mode, "exchange-")) return @import("relational_exchange_native.zig").run(@This(), init, &wire, directory, config, args);
    if (std.mem.startsWith(u8, mode, "captured-") or std.mem.startsWith(u8, mode, "maintained-")) return @import("relational_captured_native.zig").run(@This(), init, &wire, directory, config, &caller, args);
    if (std.mem.startsWith(u8, mode, "relational")) return relational(init, directory, &caller, args[4], std.mem.eql(u8, mode, "relational-held"), if (args.len > 5) args[5] else null);
    if (std.mem.startsWith(u8, mode, "select-batch")) return select(true, std.mem.eql(u8, mode, "select-batch-buffered"), std.mem.eql(u8, mode, "select-batch-disclosure") or std.mem.eql(u8, mode, "select-batch-buffered"), init, &caller, args[4], std.mem.eql(u8, mode, "select-batch-held"), .{ .requests = 10000, .rows = 128, .result_bytes = 8 * 1024 * 1024 });
    if (std.mem.startsWith(u8, mode, "select")) return select(false, false, false, init, &caller, args[4], std.mem.eql(u8, mode, "select-held"), if (args.len == 8) .{ .requests = try std.fmt.parseInt(u64, args[5], 10), .rows = try std.fmt.parseInt(u64, args[6], 10), .result_bytes = try std.fmt.parseInt(u64, args[7], 10) } else .{ .requests = 10000, .rows = 128, .result_bytes = 8 * 1024 * 1024 });
    if (std.mem.eql(u8, mode, "assist")) return print(init, try currentRead(init, &wire, q.TableAssistance.complete, .{ init.arena.allocator(), &caller, .{ .sql = args[4], .cursor = try std.fmt.parseInt(u16, args[5], 10), .generation = 7, .mode = .console } }));
    if (std.mem.eql(u8, mode, "table-select")) {
        var admin: Admin = .{ .wire = &wire, .key = try key(7) };
        admin.sequence = (try admin.query(.capabilities)).principal_sequence;
        const allowed = std.mem.eql(u8, args[4], "allow");
        try tablePrivileges(init, &admin, &caller, config, config.owner_role, c.TableAuthority.select, allowed);
        return print(init, .{ .read = allowed });
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
