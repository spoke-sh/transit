//! Isolated signed gateway controls and coordinator over real native owners.
const std = @import("std");
const gateway = @import("transit_sql_service");
const c = gateway.catalog;
const s = @import("transit_station");
const p = c.protocol;
const native = p.Growth;
const support = @import("fixture_native_proof_files");
const authorization = @import("fixture_table_authorization_support");
const Catalog = @import("fixture_sql_catalog_native");
const Admin = @import("fixture_growing_support").Admin(46);
const Config = struct { definition: native.Definition, generation: u64, binding: gateway.DatabaseAccount.Binding, table_principal: u64 };
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
const read_options: gateway.query.direct.DirectRelationalQuery.Options = .{ .consistency = .independent_table_snapshots, .budgets = .{ .resident_bytes = 16 * 1024 * 1024, .spill_bytes = 16 * 1024 * 1024, .result_bytes = 1024 * 1024, .output_rows = 1000, .work_steps = 100000, .source_pins = 2 }, .requests = 10000, .spill_work = 10000 };
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
fn execution(config: Config) !gateway.DatabaseAccount {
    if (config.definition != native.current_definition) return error.IncompatibleDefinition;
    return .{ .configuration = .{ .realm = 46, .table_principal = config.table_principal, .account = @splat(77), .bindings = undefined, .intent_bytes = 65536, .operation_quota = 1000, .byte_quota = 128 * 1024 * 1024, .pending_quota = 32 } };
}
fn client(wire: *s.client.Client, owner: gateway.DatabaseAccount, config: Config) !gateway.Client {
    return .{ .transport = wire, .execution = owner, .principal = config.table_principal, .key = try tableKey(config) };
}
fn startRuntime(init: std.process.Init, url: []const u8, directory: []const u8, config: *Config, registry: gateway.DatabaseAccount) !*gateway.DatabaseRuntime {
    config.generation += 1;
    try support.save(init, directory, "gateway.json", config.*);
    return gateway.DatabaseRuntime.init(init.gpa, init.io, url, registry, config.generation, .{ .table = try tableKey(config.*) }, 5000);
}
fn enqueue(init: std.process.Init, caller: *gateway.Client, config: Config, number: u64, sql: []const u8) !u64 {
    var nonce: [16]u8 = @splat(0);
    std.mem.writeInt(u64, nonce[0..8], number, .little);
    var fingerprint: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(sql, &fingerprint, .{});
    var source = try caller.source();
    if (try source.lookup(nonce, fingerprint)) |prior| return prior.id();
    var table = caller.table(config.binding);
    var statement = try gateway.Statement.prepare(init.gpa, &table, config.binding.namespace, sql, .transit, .wire, read_options);
    defer statement.deinit();
    var random: [8]u8 = undefined;
    try init.io.randomSecure(&random);
    var intent = try statement.bindWrite(init.gpa, &table, &.{}, (std.mem.readInt(u64, &random, .little) % p.max_counter) + 1);
    defer intent.deinit();
    const reference = try intent.stage(table, config.binding.namespace);
    const receipt = try c.DirectClientToken.bind(table, .{ .key = .{ .definition = native.current_definition, .connection = table.connection, .account = caller.execution.configuration.account, .token = nonce }, .fingerprint = fingerprint, .intent = reference, .budget = caller.execution.configuration.budget(caller.execution.configuration.reservation()) });
    return receipt.position.next_lsn;
}
fn drain(runtime: *gateway.DatabaseRuntime, caller: *gateway.Client) !void {
    for (0..1000) |_| {
        _ = try runtime.tick();
        var source = try caller.source();
        if ((try gateway.SessionOperations.list(caller.execution, &source, 0, true)).entries[0] == null) return;
    }
    return error.ProofOperationLimit;
}
fn runtimeWorker(runtime: *gateway.DatabaseRuntime) !void {
    while (true) {
        const progressed = runtime.tick() catch |err| blk: {
            if (!s.client.Client.unavailable(err)) return err;
            break :blk false;
        };
        if (!progressed) try runtime.waitIdle(2);
    }
}
fn sessionFraming(init: std.process.Init, runtime: *gateway.DatabaseRuntime, directory: []const u8) !void {
    const api = gateway.session_protocol;
    var configuration = try support.load(gateway.Configuration, init, directory, "sql-gateway.json");
    configuration.limits.connections = 2;
    configuration.limits.connections_per_account = 2;
    configuration.limits.authentications = 1;
    try configuration.validate();
    const credential = try gateway.Session.loadCredential(init.gpa, init.io, &configuration.accounts[0]);
    var sessions = try gateway.Registry.init(init.gpa, init.io, &configuration, &.{runtime}, @splat(71));
    defer sessions.deinit();
    const cases = [_]struct { sql: []const u8, rows: u32 }{
        .{ .sql = "SELECT id, value FROM wire_data", .rows = 70 },
        .{ .sql = "SELECT value FROM wire_data WHERE id = 999", .rows = 0 },
        .{ .sql = "DESCRIBE wire_data", .rows = 2 },
    };
    var refused: usize = 0;
    var repeats: usize = 0;
    var advances: usize = 0;
    for (cases) |case| {
        const slot = try sessions.create(0, credential, "data", .transit, true);
        slot.mutex.unlock(init.io);
        defer {
            slot.mutex.lockUncancelable(init.io);
            sessions.remove(slot);
            slot.mutex.unlock(init.io);
        }
        const request: api.Request = .{ .version = 1, .definition = native.current_definition, .instance = sessions.instance, .session = slot.id, .action = .{ .execute = .{ .sql = case.sql } } };
        var bytes = try sessions.request(init.gpa, init.gpa, request, .{});
        defer init.gpa.free(bytes);
        var frame = try api.ResultFrame.parseBorrowed(init.arena.allocator(), bytes);
        const schema = try api.results.Types.decodeInto(init.arena.allocator(), frame.description.?.schema);
        if (frame.ordinal != 0) return error.InvalidFramingProof;
        var fetch = request;
        fetch.action = .{ .fetch = .{ .cursor = frame.cursor, .batch = frame.ordinal } };
        var total: u32 = 0;
        var seen: [70]bool = @splat(false);
        while (true) {
            if (frame.rows != @min(api.max_rows, case.rows - total)) return error.InvalidFramingProof;
            total += frame.rows;
            if ((frame.completion != null) != (total == case.rows)) return error.InvalidFramingProof;
            if (frame.completion) |completion| if (completion.rows != total) return error.InvalidFramingProof;
            if (case.rows == 70) {
                const batch = try api.ResultColumns.decode(init.gpa, init.arena.allocator(), schema.structure, frame.columns, frame.rows);
                for (0..batch.len) |row| {
                    const id = batch.cell(row, 0).value.atom.signed;
                    if (id < 1 or id > 70) return error.InvalidFramingProof;
                    const index: usize = @intCast(id - 1);
                    if (seen[index] or batch.cell(row, 1).value.atom.signed != (if (id == 2) @as(i128, 21) else id * 10)) return error.InvalidFramingProof;
                    seen[index] = true;
                }
            }
            for (0..3) |_| {
                // Only response framing fails; rights and cursor storage retain
                // their independent owners. Repetition must not advance rows.
                try refuseFrame(init, &sessions, fetch);
                refused += 1;
                if (slot.cursor == null) return error.LostRetainedBatch;
                const repeated = try sessions.request(init.gpa, init.gpa, fetch, .{});
                defer init.gpa.free(repeated);
                if (!std.mem.eql(u8, bytes, repeated)) return error.ChangedRetainedBatch;
                repeats += 1;
            }
            if (frame.completion != null) break;
            fetch.action.fetch.batch += 1;
            // This request consumes the next source batch before framing fails.
            // Its retry must recover that ordinal without skipping or recounting.
            try refuseFrame(init, &sessions, fetch);
            refused += 1;
            if (slot.cursor == null) return error.LostRetainedBatch;
            const next = try sessions.request(init.gpa, init.gpa, fetch, .{});
            init.gpa.free(bytes);
            bytes = next;
            frame = try api.ResultFrame.parseBorrowed(init.arena.allocator(), bytes);
            if (frame.ordinal != fetch.action.fetch.batch or !std.meta.eql(frame.cursor, fetch.action.fetch.cursor)) return error.InvalidFramingProof;
            advances += 1;
        }
        if (case.rows == 70 and !std.mem.allEqual(bool, &seen, true)) return error.InvalidFramingProof;
        // A buffered frame, including empty terminal counts and metadata, is
        // not authorization. A fresh credential denial must disclose no frame.
        var revoked = credential;
        revoked.enabled = false;
        try support.save(init, directory, "gateway-credential.json", revoked);
        defer support.save(init, directory, "gateway-credential.json", credential) catch unreachable;
        if (sessions.request(init.gpa, init.gpa, fetch, .{})) |disclosed| {
            init.gpa.free(disclosed);
            return error.DisclosedRevokedBatch;
        } else |err| if (err != error.InvalidAuthentication) return err;
        if (slot.cursor != null) return error.RetainedDeniedCursor;
    }
    return support.print(init, .{ .framing_refusals = refused, .exact_repeats = repeats, .advanced_recoveries = advances, .revoked_results = cases.len });
}
fn refuseFrame(init: std.process.Init, sessions: *gateway.Registry, request: gateway.session_protocol.Request) !void {
    var failing = std.testing.FailingAllocator.init(init.gpa, .{ .fail_index = 0 });
    if (sessions.request(failing.allocator(), init.gpa, request, .{})) |bytes| {
        init.gpa.free(bytes);
        return error.ExpectedFramingRefusal;
    } else |err| if (err != error.OutOfMemory) return err;
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
        var config: Config = .{ .definition = native.current_definition, .generation = 1, .binding = .{ .resource = catalog.catalog.scope.resource, .catalog = catalog.catalog.scope.catalog, .owner = catalog.catalog.audience }, .table_principal = if (args.len > 4) try std.fmt.parseInt(u64, args[4], 10) else 1234 };
        _ = try tableSeed(config);
        if (config.table_principal == 1235) config.binding.role = (try admin.query(.{ .authorization = .{ .kind = .{ .resolve = try p.Value.init("gateway-caller") } } })).body.authorization.body.resolve.id;
        try support.save(init, directory, "gateway.json", config);
        return support.print(init, config);
    }
    var config = try support.load(Config, init, directory, "gateway.json");
    var registry = try execution(config);
    registry.configuration.bindings = &.{config.binding};
    var caller = try client(&wire, registry, config);
    if (std.mem.eql(u8, mode, "source-pin-status")) {
        const sources = try support.load([]const gateway.Configuration.Source, init, directory, "session-sources.json");
        const dir = try std.Io.Dir.cwd().openDir(init.io, directory, .{});
        defer dir.close(init.io);
        var pins = try gateway.ReadCache.init(init.gpa, init.io, dir, .{ .realm = 46, .account = registry.configuration.account }, config.generation);
        defer pins.deinit();
        var saved: ?gateway.ReadCache.Record = support.load(gateway.ReadCache.Record, init, directory, "orphaned-source-pin.json") catch |err| if (err == error.FileNotFound) null else return err;
        for (sources) |source| {
            if (source.workspace.source.source != .table) continue;
            var source_caller: gateway.query.UnifiedClient = .{ .wire = &wire, .connection = source.connection, .key = try gateway.query.wire.readKey(init.gpa, init.io, source.key_file) };
            const tables = (try gateway.query.Workspace.directTables(init.arena.allocator(), &source_caller, source.workspace)) orelse return error.InvalidSqlReadRecovery;
            if (saved == null) for (0..gateway.ReadCache.capacity) |index| {
                if (try pins.inspect(tables, index)) |record| {
                    saved = record;
                    try support.save(init, directory, "orphaned-source-pin.json", record);
                    break;
                }
            };
            const record = saved orelse continue;
            if (!std.meta.eql(tables.connection, record.table.connection)) continue;
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
        const Sources = @import("fixture_sql_session_sources");
        const selection = if (args.len > 4) std.meta.stringToEnum(Sources.Selection, args[4]) orelse return error.InvalidSourceSelection else .all;
        try Sources.provision(init, &wire, &admin, directory, role, config.binding.role, selection);
        return support.print(init, .{ .sources = true });
    }
    if (std.mem.eql(u8, mode, "app-config")) {
        config.generation += 1;
        try support.save(init, directory, "gateway.json", config);
        const keys = .{.{ "table", try tableSeed(config) }};
        var files: gateway.Configuration.KeyFiles = undefined;
        inline for (keys) |entry| {
            const name = "gateway-" ++ entry[0] ++ ".seed";
            try support.saveBytes(init, directory, name, &std.fmt.bytesToHex(@as([32]u8, @splat(entry[1])), .lower));
            @field(files, entry[0]) = try support.path(init, directory, name);
        }
        const auth: s.client.AuthorizationClient = .{ .transport = &wire, .realm = 46, .principal = config.table_principal, .key = try tableKey(config) };
        const identity = (try auth.read(.identity)).body.authorization.body.identity;
        try support.save(init, directory, "gateway-credential.json", gateway.Configuration.Credential{ .version = 1, .definition = native.current_definition, .account = registry.configuration.account, .revision = 1, .principal = identity.principal, .login_role = identity.login_role, .credential_epoch = identity.credential_epoch, .enabled = true, .verifier = try gateway.Authentication.Verifier.create("proof-password", @splat(19), 4096) });
        const configuration: gateway.Configuration = .{ .version = 1, .definition = native.current_definition, .native_url = args[1], .certificate_file = try support.path(init, directory, "certificate.pem"), .certificate_key_file = try support.path(init, directory, "key.pem"), .activation_directory = directory, .spill_directory = directory, .postgres_port = try std.fmt.parseInt(u16, args[4], 10), .accounts = &.{.{ .name = "proof", .verifier_file = try support.path(init, directory, "gateway-credential.json"), .execution = registry.configuration, .generation = config.generation, .keys = files, .databases = &.{.{ .name = "data", .binding = config.binding }} }} };
        try configuration.validate();
        try support.save(init, directory, "sql-gateway.json", configuration);
        try support.saveBytes(init, directory, "gateway-control.seed", &std.fmt.bytesToHex(@as([32]u8, @splat(23)), .lower));
        try support.save(init, directory, "sql-control.json", .{ .version = @as(u8, 1), .definition = native.current_definition, .native_url = args[1], .execution = registry.configuration, .table_key_file = files.table, .timeout_ms = @as(u32, 30000) });
        return support.print(init, .{ .configured = true });
    }
    if (std.mem.eql(u8, mode, "raw-denied")) {
        const raw: s.client.ResourceReader = .{ .wire = &wire, .realm = 46, .principal = config.table_principal, .key = try tableKey(config) };
        if (raw.open(config.binding.resource)) |_| return error.UnexpectedRawAccess else |err| {
            if (err != error.AccessDenied) return err;
        }
        return support.print(init, .{ .raw_denied = true });
    }
    if (std.mem.eql(u8, mode, "runtime") or std.mem.eql(u8, mode, "session-framing")) {
        const runtime = try startRuntime(init, args[1], directory, &config, registry);
        defer runtime.deinit();
        if (std.mem.eql(u8, mode, "session-framing")) {
            const parent = try std.Io.Dir.cwd().openDir(init.io, directory, .{});
            defer parent.close(init.io);
            try runtime.attachReadCache(parent, .{});
        }
        var worker = try init.io.concurrent(runtimeWorker, .{runtime});
        defer worker.cancel(init.io) catch |err| if (err != error.Cancelled and err != error.Canceled) {
            std.debug.print("Runtime failed: {s}\n", .{@errorName(err)});
        };
        const deadline: gateway.DatabaseRuntime.Deadline = .{ .start = std.Io.Clock.awake.now(init.io), .milliseconds = 60000 };
        while (!runtime.ready.load(.acquire)) {
            try deadline.check(init.io);
            try init.io.sleep(.fromMilliseconds(2), .awake);
        }
        if (std.mem.eql(u8, mode, "session-framing")) return sessionFraming(init, runtime, directory);
        var observer = try client(&wire, registry, config);
        var table: c.DirectTableClient = .{ .allocator = init.gpa, .authority = &wire, .service = &wire, .connection = .{ .scope = .{ .realm = 46, .resource = config.binding.resource, .catalog = config.binding.catalog }, .branch = 1, .audience = config.binding.owner, .principal = config.table_principal, .role = config.binding.role }, .key = try tableKey(config) };
        var statement = try gateway.Statement.prepare(init.gpa, &table, config.binding.namespace, args[4], .transit, .wire, read_options);
        defer statement.deinit();
        var operation: ?u64 = null;
        const result = try runtime.execute(init.gpa, &observer, &table, &statement, &.{}, deadline, &operation);
        return support.print(init, .{ .operation = operation, .outcome = result.terminal, .completion = result.completion });
    }

    if (std.mem.eql(u8, mode, "read")) {
        var read_caller: c.DirectTableClient = .{ .allocator = init.gpa, .authority = &wire, .service = &wire, .connection = .{ .scope = .{ .realm = 46, .resource = config.binding.resource, .catalog = config.binding.catalog }, .branch = 1, .audience = config.binding.owner, .principal = config.table_principal, .role = config.binding.role }, .key = try tableKey(config) };
        const dialect: c.fuze.Sql.Dialect = if (std.mem.eql(u8, args[4], "mysql")) .mysql else .transit;
        var statement = try gateway.Statement.prepare(init.gpa, &read_caller, config.binding.namespace, args[5], dialect, .wire, read_options);
        defer statement.deinit();
        var values: [1]?c.fuze.Types.Values.Atom = .{null};
        if (args.len > 6 and !std.mem.eql(u8, args[6], "null")) values[0] = .{ .signed = try std.fmt.parseInt(i64, args[6], 10) };
        const bound = values[0..@intFromBool(args.len > 6)];
        try statement.checkValues(init.gpa, bound);
        try statement.validate(&read_caller);
        var rows: std.ArrayList([]const ?i128) = .empty;
        const arena = init.arena.allocator();
        const directory_handle = try std.Io.Dir.cwd().openDir(init.io, directory, .{});
        defer directory_handle.close(init.io);
        var pins = try gateway.ReadCache.init(init.gpa, init.io, directory_handle, .{ .realm = 46, .account = registry.configuration.account }, config.generation);
        defer pins.deinit();
        var records: [c.fuze.Relational.max_sources]?gateway.ReadCache.Record = @splat(null);
        defer for (records) |record| if (record) |pin| {
            pins.close(read_caller, pin) catch {};
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
            const response = try read_caller.call(.{ .lookup = .{ .namespace = binding.namespace, .name = binding.name.slice() } });
            defer response.deinit();
            const metadata = response.value.result.lookup orelse return error.TableNotFound;
            try binding.check(read_caller.connection, metadata);
            records[i] = try pins.acquireCurrent(read_caller, binding);
            snapshots[i] = try records[i].?.snapshot();
        }
        if (statement.plan == .relational) {
            const query = try statement.openRelational(init.gpa, init.io, directory_handle, "gateway-read-spill", &read_caller, snapshots[0..count], read_options, null);
            defer query.deinit();
            while (try query.next()) |value| {
                var row = value;
                defer row.deinit();
                try appendRow(arena, &rows, row.cells[0..row.len]);
            }
            query.close();
        } else {
            var query = try statement.openSelect(init.gpa, &read_caller, bound, snapshots[0], .{ .requests = 10000, .rows = 32, .result_bytes = 65536 }, null);
            defer query.deinit();
            while (try query.next()) |value| {
                var row = value;
                defer row.deinit();
                try appendRow(arena, &rows, row.cells);
            }
            query.close();
        }
        for (records) |record| if (record) |pin| try pins.close(read_caller, pin);
        return support.print(init, .{ .rows = rows.items, .columns = statement.fields().len });
    }
    if (std.mem.eql(u8, mode, "replace") or std.mem.eql(u8, mode, "fence")) {
        const previous = try startRuntime(init, args[1], directory, &config, registry);
        defer previous.deinit();
        const replacement = try startRuntime(init, args[1], directory, &config, registry);
        defer replacement.deinit();
        if (previous.fence(&caller)) |_| return error.ExpectedStaleFence else |err| if (err != error.StaleGatewayCoordinator) return err;
        const stale = previous.private.table(registry.configuration.bindings[0]);
        if (stale.call(.{ .lookup = .{ .namespace = 1, .name = "wire_data" } })) |response| {
            response.deinit();
            return error.ExpectedStaleFence;
        } else |err| if (!previous.background.contended(err)) return err;
        return support.print(init, .{ .generation = config.generation, .stale_rejected = true });
    }
    if (std.mem.eql(u8, mode, "enqueue")) return support.print(init, .{ .operation = try enqueue(init, &caller, config, try std.fmt.parseInt(u64, args[4], 10), args[5]) });
    if (std.mem.eql(u8, mode, "cancel")) {
        var source = try caller.source();
        const state = try source.operation(try std.fmt.parseInt(u64, args[4], 10));
        _ = try c.DirectClientToken.update(source.direct(state), .{ .key = state.receipt.binding.key, .expected = state.revision, .pending = state.pending, .cancel = true, .record = state.record });
        return support.print(init, .{ .requested = state.id() });
    }
    if (std.mem.eql(u8, mode, "list")) {
        var source = try caller.source();
        return support.print(init, try gateway.SessionOperations.list(registry, &source, if (args.len > 4) try std.fmt.parseInt(u64, args[4], 10) else 0, false));
    }
    if (std.mem.eql(u8, mode, "status")) {
        var source = try caller.source();
        const state = try source.operation(try std.fmt.parseInt(u64, args[4], 10));
        const reference = state.receipt.binding.intent;
        const observed = try reference.operation(source.direct(state), .inspect, 1);
        defer observed.deinit();
        const terminal = try gateway.Terminal.fromReference(reference, observed.value.result);
        return support.print(init, .{ .phase = if (terminal != null) "terminal" else "ready", .summary = if (terminal) |value| @tagName(value.state) else "none", .matched = if (terminal) |value| value.matched else 0, .changed = if (terminal) |value| value.changed else 0, .reference = reference, .cancellation_requested = state.cancel });
    }
    if (std.mem.eql(u8, mode, "run")) {
        const runtime = try startRuntime(init, args[1], directory, &config, registry);
        defer runtime.deinit();
        if (args.len > 4) {
            _ = try runtime.tick();
            return support.print(init, .{ .stopped = "admitted" });
        }
        try drain(runtime, &caller);
        return support.print(init, .{ .complete = true });
    }
    if (std.mem.eql(u8, mode, "history")) {
        const runtime = try startRuntime(init, args[1], directory, &config, registry);
        defer runtime.deinit();
        for (0..27) |index| {
            _ = try enqueue(init, &caller, config, 1000 + index, "UPDATE wire_data SET value = 10 WHERE id = 1");
            try drain(runtime, &caller);
        }
        var source = try caller.source();
        var after: u64 = 0;
        var count: usize = 0;
        var pages: usize = 0;
        while (true) {
            const page = try gateway.SessionOperations.list(registry, &source, after, false);
            pages += 1;
            for (page.entries) |slot| if (slot) |entry| {
                const state = (try source.lookup(entry.nonce, null)) orelse return error.DiscoveryMismatch;
                if (state.id() != entry.id) return error.DiscoveryMismatch;
                count += 1;
            };
            after = page.next orelse break;
        }
        return support.print(init, .{ .count = count, .pages = pages, .empty_scheduling_indexes = (try gateway.SessionOperations.list(registry, &source, 0, true)).entries[0] == null });
    }
    return error.UnknownMode;
}
