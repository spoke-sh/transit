//! Isolated signed gateway controls and coordinator over real native owners.
const std = @import("std");
const gateway = @import("transit_sql");
const c = gateway.catalog;
const s = gateway.station;
const p = c.protocol;
const native = p.Growth;
const support = @import("native_proof_files.zig");
const authorization = @import("table_authorization_support.zig");
const Catalog = @import("sql_catalog_native.zig");
const Admin = @import("growing_support.zig").Admin(46);
const Config = struct { definition: native.Definition, writer: Admin.Provision, binding: gateway.Ledger.Binding, table_principal: u64 };
fn tableSeed(config: Config) !u8 {
    return switch (config.table_principal) {
        1234 => 10,
        1235 => 11,
        else => error.UnknownProofPrincipal,
    };
}
fn tableKey(config: Config) !p.Ed25519.KeyPair {
    return switch (config.table_principal) {
        1234 => support.key(10),
        1235 => support.key(11),
        else => error.UnknownProofPrincipal,
    };
}
const read_options: gateway.query.DirectRelationalQuery.Options = .{ .consistency = .independent_table_snapshots, .budgets = .{ .resident_bytes = 16 * 1024 * 1024, .spill_bytes = 16 * 1024 * 1024, .result_bytes = 1024 * 1024, .output_rows = 1000, .work_steps = 100000, .source_pins = 2 }, .requests = 10000, .spill_work = 10000 };
fn appendRow(allocator: std.mem.Allocator, rows: *std.ArrayList([]const ?i128), cells: []const c.fuze.Types.Values.Cell) !void {
    if (rows.items.len == 32 or cells.len > 8) return error.ProofRowBudget;
    const values = try allocator.alloc(?i128, cells.len);
    for (cells, values) |cell, *value| value.* = switch (cell) {
        .null => null,
        .value => |item| if (item != .atom) return error.UnexpectedProofValue else switch (item.atom) {
            .signed => |number| number,
            .unsigned => |number| @intCast(number),
            else => return error.UnexpectedProofValue,
        },
        else => return error.UnexpectedProofValue,
    };
    try rows.append(allocator, values);
}
fn ledger(config: Config) !gateway.Ledger {
    if (config.definition != native.current_definition) return error.IncompatibleDefinition;
    // The caller retains config for the lifetime of the returned binding slice.
    return .{ .configuration = .{ .realm = 46, .resource = config.writer.resource, .owner = config.writer.pid, .worker = 2000, .ingress = 2001, .control = 2002, .coordinator = 2003, .table_principal = config.table_principal, .account = @splat(77), .bindings = undefined, .intent_bytes = 65536, .operation_quota = 1000, .byte_quota = 128 * 1024 * 1024, .pending_quota = 32 } };
}
fn roleKey(principal: u64) !p.Ed25519.KeyPair {
    return switch (principal) {
        2000 => support.key(21),
        2001 => support.key(22),
        2002 => support.key(23),
        2003 => support.key(24),
        else => error.UnknownProofPrincipal,
    };
}
fn client(wire: *s.client.Client, owner: gateway.Ledger, principal: u64) !gateway.Client {
    return .{ .transport = wire, .ledger = owner, .principal = principal, .key = try roleKey(principal) };
}
fn pump(init: std.process.Init, wire: *s.client.Client, directory: []const u8, config: Config) !usize {
    var registry = try ledger(config);
    registry.configuration.bindings = &.{config.binding};
    var behavior: gateway.Behavior = .{ .allocator = init.gpa, .ledger = registry };
    const provision = config.writer;
    const principal: u64 = 2000;
    const name = "ledger-worker-pending.json";
    const old = support.load(s.client.Session.Pending, init, directory, name) catch |err| switch (err) {
        error.FileNotFound => null,
        else => return err,
    };
    if (old) |pending| {
        _ = try pending.submit(wire);
        try std.Io.Dir.cwd().deleteFile(init.io, try support.path(init, directory, name));
    }
    var server = try s.GenServer.init(.{ .client = wire, .realm = 46, .principal = principal, .pid = provision.pid, .generation = provision.generation, .key = try roleKey(principal) }, "state");
    server.input_guard = behavior.guard();
    server.failure_policy = .stop;
    const handler = behavior.interface();
    var count: usize = 0;
    for (0..10000) |_| {
        switch (try server.prepare(@intCast(std.Io.Clock.real.now(init.io).toMilliseconds() + 30000))) {
            .idle => if (try support.deliver(init, wire, directory)) continue else return count,
            .blocked => return error.BlockedOwner,
            .committed => unreachable,
            .progress => {},
            .ready => {
                if (server.initializing) try handler.initialize.?(handler.context, &server.ready.?);
                try handler.handle(handler.context, &server.ready.?, try s.Frame.decode(server.ready.?.delivery.input.value));
                try server.finish(null);
            },
        }
        if (server.pending) |pending| {
            try support.save(init, directory, name, pending);
            const outcome = try server.dispatchPending();
            try std.Io.Dir.cwd().deleteFile(init.io, try support.path(init, directory, name));
            if (outcome == .committed) count += 1;
        }
    }
    return error.ProofTurnLimit;
}
fn control(init: std.process.Init, caller: *gateway.Client, directory: []const u8, config: Config, command: gateway.Control.Command) !p.Receipt {
    const prepared = try caller.prepare(command);
    const bytes = try prepared.save(init.gpa);
    defer init.gpa.free(bytes);
    try support.saveBytes(init, directory, "control-pending.json", bytes);
    const receipt = try caller.submit(prepared);
    _ = try pump(init, caller.transport, directory, config);
    switch (try caller.progress(prepared, receipt)) {
        .pending => return error.ControlNotProcessed,
        .processed => |disposition| if (disposition) |rejected| {
            std.debug.print("Gateway disposition: {s}\n", .{rejected.cause[0..rejected.cause_length]});
            return error.GatewayControlRejected;
        },
    }
    try std.Io.Dir.cwd().deleteFile(init.io, try support.path(init, directory, "control-pending.json"));
    return receipt;
}
fn runtimeWorker(runtime: *gateway.AccountRuntime) !void {
    while (true) {
        const progressed = runtime.tick() catch |err| blk: {
            if (!s.client.Client.unavailable(err)) return err;
            break :blk false;
        };
        if (!progressed) try runtime.waitIdle(2);
    }
}
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len < 4) return error.Usage;
    const directory = args[3];
    const mode = args[2];
    var wire = s.client.Client.init(init.gpa, init.io, args[1]);
    defer wire.deinit();
    wire.timeout_ms = 10000;
    errdefer if (wire.last_rejection) |cause| std.debug.print("Authority rejection: {s}\n", .{@tagName(cause)});
    if (std.mem.eql(u8, mode, "provision") or std.mem.eql(u8, mode, "provision-empty")) {
        var admin: Admin = .{ .wire = &wire, .key = try support.key(7) };
        admin.sequence = (try admin.query(.capabilities)).principal_sequence;
        const catalog = try support.load(Catalog.Config, init, directory, "catalog.json");
        var config: Config = .{ .definition = native.current_definition, .writer = try admin.provision(2000, try roleKey(2000)), .binding = .{ .resource = catalog.catalog.scope.resource, .catalog = catalog.catalog.scope.catalog, .owner = catalog.catalog.audience }, .table_principal = if (args.len > 4) try std.fmt.parseInt(u64, args[4], 10) else 1234 };
        _ = try tableSeed(config);
        if (config.table_principal == 1235) config.binding.role = (try admin.query(.{ .authorization = .{ .kind = .{ .resolve = try p.Value.init("gateway-caller") } } })).body.authorization.body.resolve.id;
        for ([_]u64{ 2001, 2002, 2003 }) |principal| {
            _ = try admin.submit(.{ .grant = .{ .subject = principal, .public_key = (try roleKey(principal)).public_key.toBytes(), .permissions = p.permission(.inspect) | p.permission(.send), .pid = config.writer.pid } });
            _ = try admin.submit(.{ .grant_resource = .{ .resource = config.writer.resource, .subject = principal, .permissions = p.State.permission(.inspect) | p.State.permission(.read) } });
        }
        try support.save(init, directory, "gateway.json", config);
        if (std.mem.eql(u8, mode, "provision-empty")) return support.print(init, config);
        var registry = try ledger(config);
        registry.configuration.bindings = &.{config.binding};
        var caller = try client(&wire, registry, 2002);
        _ = try control(init, &caller, directory, config, .initialize);
        return support.print(init, config);
    }
    var config = try support.load(Config, init, directory, "gateway.json");
    var registry = try ledger(config);
    registry.configuration.bindings = &.{config.binding};
    var coordinator_client = try client(&wire, registry, 2003);
    var coordinator: gateway.Coordinator = .{ .allocator = init.gpa, .client = &coordinator_client, .table_key = try tableKey(config), .generation = config.writer.generation };
    defer coordinator.deinit();
    if (std.mem.eql(u8, mode, "source-pin-status")) {
        const bytes = try support.loadBytes(init, directory, "orphaned-source-pin.json", gateway.ReadPins.max_bytes);
        defer init.gpa.free(bytes);
        const saved = try p.Json.parseFromSlice(gateway.ReadPins.Record, init.gpa, bytes);
        defer saved.deinit();
        const record = saved.value;
        try record.validate();
        if (!std.meta.eql(record.gateway.account, registry.configuration.account) or record.gateway.owner != config.writer.pid) return error.InvalidSqlReadRecovery;
        const sources = try support.load([]const gateway.Configuration.Source, init, directory, "session-sources.json");
        for (sources) |source| {
            if (source.connection.principal != record.table.connection.principal) continue;
            var caller: gateway.query.UnifiedClient = .{ .wire = &wire, .connection = source.connection, .key = try gateway.query.wire.readKey(init.gpa, init.io, source.key_file) };
            const tables = (try gateway.query.Workspace.directTables(init.arena.allocator(), &caller, source.workspace)) orelse return error.InvalidSqlReadRecovery;
            if (!std.meta.eql(tables.connection, record.table.connection)) return error.InvalidSqlReadRecovery;
            const response = try tables.call(.{ .pin_status = .{ .object = record.table.interpretation.interpretation.object, .owner = record.owner() } });
            defer response.deinit();
            return support.print(init, .{ .released = response.value.result.pin_state.released });
        }
        return error.InvalidSqlReadRecovery;
    }
    if (std.mem.eql(u8, mode, "configuration") or std.mem.eql(u8, mode, "configuration-deny") or std.mem.eql(u8, mode, "configuration-allow")) {
        const C = gateway.query.settings.Contract;
        var admin: Admin = .{ .wire = &wire, .key = try support.key(7) };
        admin.sequence = (try admin.query(.capabilities)).principal_sequence;
        const selected = config.binding.role orelse return error.MissingProofRole;
        if (!std.mem.eql(u8, mode, "configuration")) {
            const binding = try support.load(C.Binding, init, directory, "configuration-binding.json");
            if (std.mem.eql(u8, mode, "configuration-deny")) _ = try admin.authorization(.{ .revoke_privileges = .{ .object = binding.object, .grantee = selected, .privileges = C.reload, .behavior = .cascade } }) else _ = try admin.authorization(.{ .grant = .{ .object = binding.object, .grantee = selected, .privileges = C.reload } });
            return support.print(init, .{ .changed = true });
        }
        const owner = (try admin.authorization(.{ .create_role = .{ .name = try .init("configuration-admin") } })).?;
        const domain = (try admin.authorization(.{ .register_domain = .{ .registrar = 0, .actions = C.all_privileges } })).?;
        const installation: [16]u8 = @splat(99);
        const object = (try admin.authorization(.{ .register_object = .{ .domain = domain, .owner = owner, .binding = C.Binding.identity(installation) } })).?;
        const binding: C.Binding = .{ .realm = 46, .installation = installation, .object = .{ .kind = .domain, .id = object } };
        _ = try admin.authorization(.{ .grant = .{ .object = binding.object, .grantee = selected, .privileges = C.all_privileges } });
        try support.save(init, directory, "configuration-binding.json", binding);
        return support.print(init, binding);
    }
    if (std.mem.eql(u8, mode, "session-sources")) {
        var admin: Admin = .{ .wire = &wire, .key = try support.key(7) };
        admin.sequence = (try admin.query(.capabilities)).principal_sequence;
        const role = try authorization.loginRole(c, &wire, 46, config.table_principal, try tableKey(config));
        const Sources = @import("sql_session_sources.zig");
        const selection = if (args.len > 4) std.meta.stringToEnum(Sources.Selection, args[4]) orelse return error.InvalidSourceSelection else .all;
        try Sources.provision(init, &wire, &admin, directory, role, config.binding.role, selection);
        return support.print(init, .{ .sources = true });
    }
    if (std.mem.eql(u8, mode, "app-config")) {
        const keys = .{ .{ "worker", @as(u8, 21) }, .{ "ingress", @as(u8, 22) }, .{ "coordinator", @as(u8, 24) }, .{ "table", try tableSeed(config) } };
        var files: gateway.Configuration.KeyFiles = undefined;
        inline for (keys) |entry| {
            const name = "gateway-" ++ entry[0] ++ ".seed";
            try support.saveBytes(init, directory, name, &std.fmt.bytesToHex(@as([32]u8, @splat(entry[1])), .lower));
            @field(files, entry[0]) = try support.path(init, directory, name);
        }
        const auth: s.client.AuthorizationClient = .{ .transport = &wire, .realm = 46, .principal = config.table_principal, .key = try tableKey(config) };
        const identity = (try auth.read(.identity)).body.authorization.body.identity;
        try support.save(init, directory, "gateway-credential.json", gateway.Configuration.Credential{ .version = 1, .definition = native.current_definition, .account = registry.configuration.account, .revision = 1, .principal = identity.principal, .login_role = identity.login_role, .credential_epoch = identity.credential_epoch, .enabled = true, .verifier = try gateway.Authentication.Verifier.create("proof-password", @splat(19), 4096) });
        const configuration: gateway.Configuration = .{ .version = 1, .definition = native.current_definition, .native_url = args[1], .certificate_file = try support.path(init, directory, "certificate.pem"), .certificate_key_file = try support.path(init, directory, "key.pem"), .activation_directory = directory, .spill_directory = directory, .postgres_port = try std.fmt.parseInt(u16, args[4], 10), .accounts = &.{.{ .name = "proof", .verifier_file = try support.path(init, directory, "gateway-credential.json"), .ledger = registry.configuration, .generation = config.writer.generation, .keys = files, .databases = &.{.{ .name = "data", .binding = config.binding }} }} };
        try configuration.validate();
        try support.save(init, directory, "sql-gateway.json", configuration);
        try support.saveBytes(init, directory, "gateway-control.seed", &std.fmt.bytesToHex(@as([32]u8, @splat(23)), .lower));
        try support.save(init, directory, "sql-control.json", .{ .version = @as(u8, 1), .definition = native.current_definition, .native_url = args[1], .ledger = registry.configuration, .control_key_file = try support.path(init, directory, "gateway-control.seed"), .table_key_file = files.table, .pending_file = try support.path(init, directory, "operator-pending.json"), .timeout_ms = @as(u32, 30000) });
        return support.print(init, .{ .configured = true });
    }
    if (std.mem.eql(u8, mode, "raw-denied")) {
        const raw: s.client.ResourceReader = .{ .wire = &wire, .realm = 46, .principal = config.table_principal, .key = try tableKey(config) };
        if (raw.open(config.binding.resource)) |_| return error.UnexpectedRawAccess else |err| {
            if (err != error.AccessDenied) return err;
        }
        return support.print(init, .{ .raw_denied = true });
    }
    if (std.mem.eql(u8, mode, "runtime")) {
        const runtime = try gateway.AccountRuntime.init(init.gpa, init.io, args[1], registry, config.writer.generation, "state", .{ .worker = try roleKey(2000), .ingress = try roleKey(2001), .coordinator = try roleKey(2003), .table = try tableKey(config) }, 5000);
        defer runtime.deinit();
        var worker = try init.io.concurrent(runtimeWorker, .{runtime});
        defer worker.cancel(init.io) catch |err| if (err != error.Cancelled and err != error.Canceled) {
            std.debug.print("Runtime failed: {s}\n", .{@errorName(err)});
        };
        const deadline: gateway.AccountRuntime.Deadline = .{ .start = std.Io.Clock.awake.now(init.io), .milliseconds = 60000 };
        while (!runtime.ready.load(.acquire)) {
            try deadline.check(init.io);
            try init.io.sleep(.fromMilliseconds(2), .awake);
        }
        var observer = try client(&wire, registry, 2001);
        const detached_nonce: [16]u8 = @splat(177);
        const detach = args.len > 5 and std.mem.eql(u8, args[5], "detach");
        if (detach) {
            var waiting = try init.io.concurrent(gateway.AccountRuntime.control, .{ runtime, .{ .begin = .{ .nonce = detached_nonce, .binding = config.binding } }, deadline });
            try init.io.sleep(.fromMilliseconds(100), .awake);
            if (waiting.cancel(init.io)) |_| return error.ExpectedCancelledWait else |err| if (err != error.Canceled and err != error.Cancelled) return err;
        }
        var table: c.DirectTableClient = .{ .allocator = init.gpa, .authority = &wire, .service = &wire, .connection = .{ .scope = .{ .realm = 46, .resource = config.binding.resource, .catalog = config.binding.catalog }, .branch = 1, .audience = config.binding.owner, .principal = config.table_principal, .role = config.binding.role }, .key = try tableKey(config) };
        var statement = try gateway.Statement.prepare(init.gpa, &table, config.binding.namespace, args[4], .transit, .wire, read_options);
        defer statement.deinit();
        var operation: ?u64 = null;
        const result = try runtime.execute(init.gpa, &observer, &table, &statement, &.{}, deadline, &operation);
        var source = try observer.source();
        const detached = if (detach) (try registry.discover(&source, detached_nonce)).?.id else null;
        return support.print(init, .{ .operation = operation, .outcome = result, .detached = detached });
    }
    if (std.mem.eql(u8, mode, "read")) {
        var caller: c.DirectTableClient = .{ .allocator = init.gpa, .authority = &wire, .service = &wire, .connection = .{ .scope = .{ .realm = 46, .resource = config.binding.resource, .catalog = config.binding.catalog }, .branch = 1, .audience = config.binding.owner, .principal = config.table_principal, .role = config.binding.role }, .key = try tableKey(config) };
        const dialect: c.fuze.Sql.Dialect = if (std.mem.eql(u8, args[4], "mysql")) .mysql else .transit;
        var statement = try gateway.Statement.prepare(init.gpa, &caller, config.binding.namespace, args[5], dialect, .wire, read_options);
        defer statement.deinit();
        var values: [1]?c.fuze.Types.Values.Atom = .{null};
        if (args.len > 6 and !std.mem.eql(u8, args[6], "null")) values[0] = .{ .signed = try std.fmt.parseInt(i64, args[6], 10) };
        const bound = values[0..@intFromBool(args.len > 6)];
        try statement.checkValues(init.gpa, bound);
        try statement.validate(&caller);
        var rows: std.ArrayList([]const ?i128) = .empty;
        const arena = init.arena.allocator();
        const directory_handle = try std.Io.Dir.cwd().openDir(init.io, directory, .{});
        defer directory_handle.close(init.io);
        var pins = try gateway.ReadPins.init(init.gpa, init.io, directory_handle, .{ .realm = 46, .owner = config.writer.pid, .account = registry.configuration.account }, config.writer.generation);
        defer pins.deinit();
        var records: [c.fuze.Relational.max_sources]?gateway.ReadPins.Record = @splat(null);
        defer for (records) |record| if (record) |pin| {
            pins.close(caller, pin) catch {};
        };
        var snapshots: [c.fuze.Relational.max_sources]c.DirectTableProtocol.Snapshot = undefined;
        const count = if (statement.plan == .relational) statement.plan.relational.plan.sources.len else 1;
        for (0..count) |i| {
            const binding = if (statement.plan == .relational) statement.plan.relational.bindings[i] else statement.plan.select.binding;
            var shared: ?usize = null;
            for (records[0..i], 0..) |record, j| if (record) |pin| if (std.meta.eql(pin.table, binding)) {
                shared = j;
                break;
            };
            if (shared) |j| {
                snapshots[i] = snapshots[j];
                continue;
            }
            const response = try caller.call(.{ .lookup = .{ .namespace = binding.namespace, .name = binding.name.slice() } });
            defer response.deinit();
            const metadata = response.value.result.lookup orelse return error.TableNotFound;
            try binding.check(caller.connection, metadata);
            records[i] = try pins.acquire(caller, binding, metadata.position);
            snapshots[i] = try records[i].?.snapshot();
        }
        if (statement.plan == .relational) {
            const query = try statement.openRelational(init.gpa, init.io, directory_handle, "gateway-read-spill", &caller, snapshots[0..count], read_options, null);
            defer query.deinit();
            while (try query.next()) |row| try appendRow(arena, &rows, row.cells[0..row.len]);
            query.close();
        } else {
            var query = try statement.openSelect(init.gpa, &caller, bound, snapshots[0], .{ .requests = 10000, .rows = 32, .result_bytes = 65536 }, null);
            defer query.deinit();
            while (try query.next()) |value| {
                var row = value;
                defer row.deinit();
                try appendRow(arena, &rows, row.cells);
            }
            query.close();
        }
        for (records) |record| if (record) |pin| try pins.close(caller, pin);
        return support.print(init, .{ .rows = rows.items, .columns = statement.fields().len });
    }
    if (std.mem.eql(u8, mode, "replace") or std.mem.eql(u8, mode, "fence")) {
        var admin: Admin = .{ .wire = &wire, .key = try support.key(7) };
        admin.sequence = (try admin.query(.capabilities)).principal_sequence;
        _ = try admin.submit(.{ .own = .{ .pid = config.writer.pid, .expected_generation = config.writer.generation, .worker = 2000 } });
        config.writer.generation += 1;
        try support.save(init, directory, "gateway.json", config);
        if (std.mem.eql(u8, mode, "fence")) return support.print(init, .{ .generation = config.writer.generation });
        if (coordinator.fence()) |_| return error.ExpectedStaleFence else |err| if (err != error.StaleGatewayCoordinator) return err;
        const stale = try coordinator_client.prepare(.{ .activate = coordinator.generation });
        const receipt = try coordinator_client.submit(stale);
        _ = try pump(init, &wire, directory, config);
        const observed = try coordinator_client.progress(stale, receipt);
        if (observed != .processed or observed.processed == null or !std.mem.eql(u8, observed.processed.?.cause[0..observed.processed.?.cause_length], "StaleGatewayCoordinator")) return error.ExpectedCommittedStaleRejection;
        return support.print(init, .{ .generation = config.writer.generation, .stale_rejected = true });
    }
    if (std.mem.eql(u8, mode, "pump")) return support.print(init, .{ .turns = try pump(init, &wire, directory, config) });
    if (std.mem.eql(u8, mode, "retry-control")) {
        const bytes = try support.loadBytes(init, directory, "control-pending.json", gateway.Client.Prepared.max_saved_bytes);
        defer init.gpa.free(bytes);
        const prepared = try gateway.Client.Prepared.restore(init.gpa, bytes);
        var caller = try client(&wire, registry, prepared.signed.request.principal);
        const receipt = try caller.submit(prepared);
        _ = try pump(init, &wire, directory, config);
        return support.print(init, .{ .receipt = receipt.position, .progress = try caller.progress(prepared, receipt) });
    }
    if (std.mem.eql(u8, mode, "begin") or std.mem.eql(u8, mode, "enqueue")) {
        var caller = try client(&wire, registry, 2001);
        const number = try std.fmt.parseInt(u64, args[4], 10);
        var nonce: [16]u8 = @splat(0);
        std.mem.writeInt(u64, nonce[0..8], number, .little);
        _ = try control(init, &caller, directory, config, .{ .begin = .{ .nonce = nonce, .binding = config.binding } });
        var source = try caller.source();
        const item = (try registry.discover(&source, nonce)) orelse return error.MissingOperation;
        if (std.mem.eql(u8, mode, "begin")) return support.print(init, item);
        var table = coordinator.table(item);
        var statement = try gateway.Statement.prepare(init.gpa, &table, config.binding.namespace, args[5], .transit, .wire, read_options);
        defer statement.deinit();
        var intent = try statement.bindWrite(init.gpa, &table, &.{}, item.id);
        defer intent.deinit();
        const reference = try intent.stage(table, config.binding.namespace);
        var buffer: [gateway.IntentReference.max_bytes]u8 = undefined;
        const bytes = try gateway.IntentReference.encode(reference, &buffer);
        _ = try control(init, &caller, directory, config, .{ .begin_intent = .{ .operation = item.id, .spec = try s.Publication.Digest.of(gateway.LedgerRecords.intent_format, bytes) } });
        for (0..(bytes.len + 127) / 128) |part| {
            const offset: u32 = @intCast(part * 128);
            _ = try control(init, &caller, directory, config, .{ .intent_part = .{ .operation = item.id, .part = try gateway.Control.Part.init(offset, bytes[offset..][0..@min(128, bytes.len - offset)]) } });
        }
        _ = try control(init, &caller, directory, config, .{ .seal_intent = item.id });
        return support.print(init, .{ .operation = item.id, .intent_bytes = bytes.len });
    }
    if (std.mem.eql(u8, mode, "cancel") or std.mem.eql(u8, mode, "reconcile")) {
        var caller = try client(&wire, registry, 2002);
        const id = try std.fmt.parseInt(u64, args[4], 10);
        _ = try control(init, &caller, directory, config, if (std.mem.eql(u8, mode, "cancel")) .{ .cancel = id } else .{ .reconcile = id });
        return support.print(init, .{ .requested = id });
    }
    if (std.mem.eql(u8, mode, "list")) {
        var source = try coordinator_client.source();
        return support.print(init, try registry.list(&source, null));
    }
    if (std.mem.eql(u8, mode, "history")) {
        var ingress = try client(&wire, registry, 2001);
        var operator = try client(&wire, registry, 2002);
        for (0..27) |index| {
            var nonce: [16]u8 = @splat(99);
            std.mem.writeInt(u64, nonce[0..8], index, .little);
            _ = try control(init, &ingress, directory, config, .{ .begin = .{ .nonce = nonce, .binding = config.binding } });
            var source = try ingress.source();
            const item = (try registry.discover(&source, nonce)).?;
            _ = try control(init, &operator, directory, config, .{ .cancel = item.id });
            _ = try control(init, &coordinator_client, directory, config, .{ .cancel_unsent = .{ .operation = item.id, .generation = config.writer.generation } });
        }
        var source = try coordinator_client.source();
        var cursor: ?gateway.Ledger.Cursor = null;
        var count: usize = 0;
        var pages: usize = 0;
        while (true) {
            const page = try registry.list(&source, cursor);
            pages += 1;
            for (page.entries) |slot| if (slot) |item| {
                if (!std.meta.eql(item, (try registry.discover(&source, item.nonce)).?)) return error.DiscoveryMismatch;
                count += 1;
            };
            cursor = page.next orelse break;
        }
        if (try registry.indexed(&source, .admission, 0) != null or try registry.indexed(&source, .ready, 0) != null) return error.UnsettledHistory;
        return support.print(init, .{ .count = count, .pages = pages, .empty_scheduling_indexes = true });
    }
    if (std.mem.eql(u8, mode, "status")) {
        var source = try coordinator_client.source();
        return support.print(init, try registry.operation(&source, try std.fmt.parseInt(u64, args[4], 10)));
    }
    if (std.mem.eql(u8, mode, "run")) {
        const stop = if (args.len > 4) args[4] else "terminal";
        for (0..10000) |_| {
            const action = try coordinator.next();
            switch (action) {
                .control => |command| {
                    _ = try control(init, &coordinator_client, directory, config, command);
                    if (std.mem.eql(u8, stop, @tagName(command))) return support.print(init, .{ .stopped = stop });
                },
                .dispatch => |step| {
                    const command = try coordinator.dispatch(step);
                    if (std.mem.eql(u8, stop, "after-dispatch")) return support.print(init, .{ .stopped = stop });
                    switch (command) {
                        .control => |value| _ = try control(init, &coordinator_client, directory, config, value),
                        .pending => {},
                        .data_blocked => |blocked| return blocked.cause,
                    }
                },
                .data_blocked => |blocked| return blocked.cause,
                .blocked => |id| return support.print(init, .{ .blocked = id }),
                .idle => {
                    var source = try coordinator_client.source();
                    const head = try registry.head(&source);
                    if (head.unsettled == 0) return support.print(init, .{ .settled = head.operations });
                },
            }
        }
        return error.ProofActionLimit;
    }
    return error.Usage;
}
