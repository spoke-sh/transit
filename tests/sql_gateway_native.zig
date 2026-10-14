//! Isolated signed gateway controls and coordinator over real native owners.
const std = @import("std");
const gateway = @import("transit_sql_gateway");
const c = gateway.catalog;
const s = gateway.station;
const p = c.protocol;
const native = p.Growth;
const support = @import("typed_table_native.zig");
const Admin = @import("growing_support.zig").Admin(46);
const Config = struct { definition: native.Definition, writer: Admin.Provision, binding: gateway.Ledger.Binding };
const read_options: gateway.query.RelationalQuery.Options = .{ .consistency = .per_resource_snapshot_vector, .budgets = .{ .resident_bytes = 16 * 1024 * 1024, .spill_bytes = 16 * 1024 * 1024, .result_bytes = 1024 * 1024, .output_rows = 1000, .work_steps = 100000, .source_pins = 2 }, .requests = 10000, .spill_work = 10000 };
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
    return .{ .configuration = .{ .realm = 46, .resource = config.writer.resource, .owner = config.writer.pid, .worker = 2000, .ingress = 2001, .control = 2002, .coordinator = 2003, .table_principal = 1234, .table_public_key = (try support.key(10)).public_key.toBytes(), .account = @splat(77), .bindings = undefined, .intent_bytes = 65536, .operation_quota = 1000, .byte_quota = 128 * 1024 * 1024, .pending_quota = 32 } };
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
fn pump(init: std.process.Init, wire: *s.client.Client, directory: []const u8, config: Config, table_mode: bool) !usize {
    const table_config = try support.load(support.Config, init, directory, "catalog.json");
    var registry = try ledger(config);
    registry.configuration.bindings = &.{config.binding};
    var behavior: gateway.Behavior = .{ .allocator = init.gpa, .ledger = registry };
    var table_behavior: c.TableBehavior = .{ .allocator = init.gpa, .configuration = support.configuration(table_config) };
    const provision = if (table_mode) table_config.writer else config.writer;
    const principal: u64 = if (table_mode) table_config.worker else 2000;
    const name = if (table_mode) "table-worker-pending.json" else "ledger-worker-pending.json";
    const old = support.load(s.client.Session.Pending, init, directory, name) catch |err| switch (err) {
        error.FileNotFound => null,
        else => return err,
    };
    if (old) |pending| {
        _ = try pending.submit(wire);
        try std.Io.Dir.cwd().deleteFile(init.io, try support.path(init, directory, name));
    }
    var server = try s.GenServer.init(.{ .client = wire, .realm = 46, .principal = principal, .pid = provision.pid, .generation = provision.generation, .key = if (table_mode) try support.key(8) else try roleKey(principal) }, "state");
    server.input_guard = if (table_mode) table_behavior.guard() else behavior.guard();
    server.failure_policy = .stop;
    const handler = if (table_mode) table_behavior.interface() else behavior.interface();
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
    _ = try pump(init, caller.transport, directory, config, false);
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
        _ = runtime.tick() catch |err| {
            if (!s.client.Client.unavailable(err)) return err;
        };
        try runtime.io.sleep(.fromMilliseconds(2), .awake);
    }
}
fn runtimeTable(init: std.process.Init, url: []const u8, directory: []const u8, config: Config) !void {
    var wire = s.client.Client.init(init.gpa, init.io, url);
    defer wire.deinit();
    while (true) {
        _ = try pump(init, &wire, directory, config, true);
        try init.io.sleep(.fromMilliseconds(2), .awake);
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
    if (std.mem.eql(u8, mode, "provision")) {
        var admin: Admin = .{ .wire = &wire, .key = try support.key(7) };
        admin.sequence = (try admin.query(.capabilities)).principal_sequence;
        const catalog = try support.load(support.Config, init, directory, "catalog.json");
        const config: Config = .{ .definition = native.current_definition, .writer = try admin.provision(2000, try roleKey(2000)), .binding = .{ .resource = catalog.writer.resource, .catalog = std.math.maxInt(u64), .owner = catalog.writer.pid } };
        for ([_]u64{ 2001, 2002, 2003 }) |principal| {
            _ = try admin.submit(.{ .grant = .{ .subject = principal, .public_key = (try roleKey(principal)).public_key.toBytes(), .permissions = p.permission(.inspect) | p.permission(.send), .pid = config.writer.pid } });
            _ = try admin.submit(.{ .grant_resource = .{ .resource = config.writer.resource, .subject = principal, .permissions = p.State.permission(.inspect) | p.State.permission(.read) } });
        }
        try support.save(init, directory, "gateway.json", config);
        var registry = try ledger(config);
        registry.configuration.bindings = &.{config.binding};
        var caller = try client(&wire, registry, 2002);
        const capabilities = try wire.query(.{ .realm = 46, .principal = 1234, .kind = .capabilities }, try support.key(10));
        _ = try control(init, &caller, directory, config, .{ .initialize = capabilities.principal_sequence });
        return support.print(init, config);
    }
    var config = try support.load(Config, init, directory, "gateway.json");
    var registry = try ledger(config);
    registry.configuration.bindings = &.{config.binding};
    var coordinator_client = try client(&wire, registry, 2003);
    var coordinator: gateway.Coordinator = .{ .allocator = init.gpa, .client = &coordinator_client, .table_key = try support.key(10), .generation = config.writer.generation };
    defer coordinator.deinit();
    if (std.mem.eql(u8, mode, "runtime")) {
        const runtime = try gateway.AccountRuntime.init(init.gpa, init.io, args[1], registry, config.writer.generation, "state", .{ .worker = try roleKey(2000), .ingress = try roleKey(2001), .coordinator = try roleKey(2003), .table = try support.key(10) }, 5000);
        defer runtime.deinit();
        var worker = try init.io.concurrent(runtimeWorker, .{runtime});
        defer worker.cancel(init.io) catch |err| if (err != error.Cancelled and err != error.Canceled) {
            std.debug.print("Runtime failed: {s}\n", .{@errorName(err)});
        };
        var table_worker = try init.io.concurrent(runtimeTable, .{ init, args[1], directory, config });
        defer table_worker.cancel(init.io) catch |err| if (err != error.Cancelled and err != error.Canceled) {
            std.debug.print("Table failed: {s}\n", .{@errorName(err)});
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
        var table: c.TableClient = .{ .transport = &wire, .connection = .{ .scope = .{ .realm = 46, .resource = config.binding.resource, .catalog = config.binding.catalog }, .owner = config.binding.owner, .principal = 1234 }, .key = try support.key(10) };
        var statement = try gateway.Statement.prepare(init.gpa, &table, args[4], .transit, read_options);
        defer statement.deinit();
        var operation: ?u64 = null;
        const result = try runtime.execute(init.gpa, &observer, &table, &statement, &.{}, deadline, &operation);
        var source = try observer.source();
        const detached = if (detach) (try registry.discover(&source, detached_nonce)).?.id else null;
        return support.print(init, .{ .operation = operation, .outcome = result, .detached = detached });
    }
    if (std.mem.eql(u8, mode, "read")) {
        var caller: c.TableClient = .{ .transport = &wire, .connection = .{ .scope = .{ .realm = 46, .resource = config.binding.resource, .catalog = config.binding.catalog }, .owner = config.binding.owner, .principal = 1234 }, .key = try support.key(10) };
        const dialect: c.fuze.Sql.Dialect = if (std.mem.eql(u8, args[4], "mysql")) .mysql else .transit;
        var statement = try gateway.Statement.prepare(init.gpa, &caller, args[5], dialect, read_options);
        defer statement.deinit();
        var values: [1]?c.fuze.Types.Values.Atom = .{null};
        if (args.len > 6 and !std.mem.eql(u8, args[6], "null")) values[0] = .{ .signed = try std.fmt.parseInt(i64, args[6], 10) };
        const bound = values[0..@intFromBool(args.len > 6)];
        try statement.checkValues(init.gpa, bound);
        try statement.validate(&caller);
        var rows: std.ArrayList([]const ?i128) = .empty;
        const arena = init.arena.allocator();
        var nonces: [c.fuze.Relational.max_sources][16]u8 = undefined;
        try init.io.randomSecure(std.mem.asBytes(&nonces));
        if (statement.plan == .relational) {
            var directory_handle = try std.Io.Dir.cwd().openDir(init.io, directory, .{});
            defer directory_handle.close(init.io);
            const query = try statement.openRelational(init.gpa, init.io, directory_handle, "gateway-read-spill", &caller, nonces, read_options, null);
            defer query.deinit();
            while (try query.next()) |row| try appendRow(arena, &rows, row.cells[0..row.len]);
            try query.close();
        } else {
            var query = try statement.openSelect(init.gpa, &caller, bound, nonces[0], .{ .requests = 10000, .rows = 32, .result_bytes = 65536 }, null);
            defer query.deinit();
            while (try query.next()) |value| {
                var row = value;
                defer row.deinit();
                try appendRow(arena, &rows, row.cells);
            }
            try query.close();
        }
        return support.print(init, .{ .rows = rows.items, .columns = statement.fields().len });
    }
    if (std.mem.eql(u8, mode, "replace")) {
        var admin: Admin = .{ .wire = &wire, .key = try support.key(7) };
        admin.sequence = (try admin.query(.capabilities)).principal_sequence;
        _ = try admin.submit(.{ .own = .{ .pid = config.writer.pid, .expected_generation = config.writer.generation, .worker = 2000 } });
        config.writer.generation += 1;
        try support.save(init, directory, "gateway.json", config);
        if (coordinator.fence()) |_| return error.ExpectedStaleFence else |err| if (err != error.StaleGatewayCoordinator) return err;
        const stale = try coordinator_client.prepare(.{ .activate = coordinator.generation });
        const receipt = try coordinator_client.submit(stale);
        _ = try pump(init, &wire, directory, config, false);
        const observed = try coordinator_client.progress(stale, receipt);
        if (observed != .processed or observed.processed == null or !std.mem.eql(u8, observed.processed.?.cause[0..observed.processed.?.cause_length], "StaleGatewayCoordinator")) return error.ExpectedCommittedStaleRejection;
        return support.print(init, .{ .generation = config.writer.generation, .stale_rejected = true });
    }
    if (std.mem.eql(u8, mode, "pump")) return support.print(init, .{ .turns = try pump(init, &wire, directory, config, false) });
    if (std.mem.eql(u8, mode, "retry-control")) {
        const bytes = try support.loadBytes(init, directory, "control-pending.json", gateway.Client.Prepared.max_saved_bytes);
        defer init.gpa.free(bytes);
        const prepared = try gateway.Client.Prepared.restore(init.gpa, bytes);
        var caller = try client(&wire, registry, prepared.signed.request.principal);
        const receipt = try caller.submit(prepared);
        _ = try pump(init, &wire, directory, config, false);
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
        var statement = try gateway.Statement.prepare(init.gpa, &table, args[5], .transit, read_options);
        defer statement.deinit();
        var intent = try statement.bindWrite(init.gpa, &table, &.{}, item.id);
        defer intent.deinit();
        _ = try control(init, &caller, directory, config, .{ .begin_intent = .{ .operation = item.id, .spec = try s.Publication.Digest.of(gateway.LedgerRecords.intent_format, intent.bytes) } });
        for (0..(intent.bytes.len + 127) / 128) |part| {
            const offset: u32 = @intCast(part * 128);
            _ = try control(init, &caller, directory, config, .{ .intent_part = .{ .operation = item.id, .part = try gateway.Control.Part.init(offset, intent.bytes[offset..][0..@min(128, intent.bytes.len - offset)]) } });
        }
        _ = try control(init, &caller, directory, config, .{ .seal_intent = item.id });
        return support.print(init, .{ .operation = item.id, .intent_bytes = intent.bytes.len });
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
                    _ = try control(init, &coordinator_client, directory, config, command);
                },
                .blocked => |id| return support.print(init, .{ .blocked = id }),
                .idle => {
                    _ = try pump(init, &wire, directory, config, true);
                    var source = try coordinator_client.source();
                    const head = try registry.head(&source);
                    if (head.unsettled == 0) return support.print(init, .{ .settled = head.operations, .sequence = head.sequence });
                },
            }
        }
        return error.ProofActionLimit;
    }
    return error.Usage;
}
