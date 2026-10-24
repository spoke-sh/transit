//! Provision a real Table using public APIs. The actual shell and daemon are
//! separate executables exercised by public_query.py, never test-only handlers.
const std = @import("std");
const q = @import("transit_query");
const serving = @import("transit_serving");
const s = @import("transit_station");
const catalog = q.catalog;
const p = s.protocol;
const Admin = @import("growing_support.zig").Admin(45);
const authorization = @import("table_authorization_support.zig");
const data = @import("public_query_catalog.zig");
const Connection = q.UnifiedClient.Connection;
const limits: q.Bundle.Limits = .{ .pages = 4096, .segments = 63, .result_bytes = 240 * 1024 };
fn provision(admin: *Admin, principal: u64, key: p.Ed25519.KeyPair) !Admin.Provision {
    const pid = try admin.submit(.{ .spawn = .{} });
    _ = try admin.submit(.{ .grant = .{ .subject = principal, .pid = pid, .public_key = key.public_key.toBytes(), .permissions = p.permission(.inspect) | p.permission(.execute) | p.permission(.publish) } });
    const resource = try admin.submit(.{ .create_resource = .{ .writer = pid } });
    for ([_]u64{ 0, principal }) |subject| _ = try admin.submit(.{ .grant_resource = .{ .resource = resource, .subject = subject, .permissions = p.State.all_permissions } });
    _ = try admin.submit(.{ .associate = .{ .pid = pid, .name = try p.Value.init("state"), .resource = resource } });
    return .{ .pid = pid, .resource = resource, .generation = 1 };
}
fn drive(init: std.process.Init, server: *s.GenServer, handler: s.GenServer.Handler) !void {
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
    if (std.mem.eql(u8, args[2], "catalog-bootstrap")) {
        const profile = try data.bootstrap(&admin);
        try save(init, args[3], "catalog-profile.json", profile);
        const registrar = try seedFile(init, args[3], "registrar", 7);
        try save(init, args[3], "catalog-node.json", .{ .catalog = profile.catalog, .registrar = .{ .principal = 0, .seed_file = registrar } });
        return;
    }
    const second_flight = std.mem.eql(u8, args[2], "provision-flight-second");
    const overflow_flight = std.mem.eql(u8, args[2], "provision-flight-overflow");
    const flight = std.mem.eql(u8, args[2], "provision-flight") or second_flight or overflow_flight;
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
        var writer = try provision(&admin, writer_principal, writer_key);
        var requester = try provision(&admin, requester_principal, requester_key);
        for ([_]struct { pid: u64, principal: u64, resource: u64 }{ .{ .pid = writer.pid, .principal = writer_principal, .resource = requester.resource }, .{ .pid = requester.pid, .principal = requester_principal, .resource = writer.resource } }) |link| {
            _ = try admin.submit(.{ .grant_resource = .{ .resource = link.resource, .subject = link.principal, .permissions = p.State.permission(.inspect) | p.State.permission(.read) } });
            _ = try admin.submit(.{ .associate = .{ .pid = link.pid, .name = try p.Value.init("peer"), .resource = link.resource, .required = false } });
            _ = try admin.submit(.{ .own = .{ .pid = link.pid, .expected_generation = 2, .worker = link.principal } });
        }
        writer.generation = 3;
        requester.generation = 3;
        const query_role = try authorization.login(catalog, &admin, if (second_flight) "flight-second-reader" else "query-reader", query_principal, caller_key, null);
        if (flight) {
            _ = try admin.authorization(.{ .revoke_privileges = .{ .object = .{ .kind = .realm, .id = 0 }, .grantee = query_role, .privileges = p.permission(.send), .behavior = .cascade } });
            _ = try admin.authorization(.{ .grant = .{ .object = .{ .kind = .process, .id = requester.pid }, .grantee = query_role, .privileges = p.permission(.send) } });
        }
        _ = try admin.submit(.{ .grant = .{ .subject = courier_principal, .public_key = courier_key.public_key.toBytes(), .permissions = p.permission(.inspect) | p.permission(.send) | p.permission(.delivery) } });
        const inspector_key = try p.Ed25519.KeyPair.generateDeterministic(@splat(12));
        const inspector_role = if (!second_flight) try authorization.login(catalog, &admin, "query-inspector", 55, inspector_key, null) else try authorization.loginRole(catalog, &wire, 45, 55, inspector_key);
        if (!second_flight) _ = try admin.authorization(.{ .revoke_privileges = .{ .object = .{ .kind = .realm, .id = 0 }, .grantee = inspector_role, .privileges = p.permission(.send), .behavior = .cascade } });
        for ([_]u64{ writer.resource, requester.resource }) |resource| for ([_]u64{ query_principal, 55 }) |principal| {
            _ = try admin.submit(.{ .grant_resource = .{ .resource = resource, .subject = principal, .permissions = p.State.permission(.inspect) | p.State.permission(.read) } });
        };
        var server = try s.GenServer.init(.{ .client = &wire, .realm = 45, .principal = writer_principal, .pid = writer.pid, .generation = writer.generation, .key = writer_key }, "state");
        const profile = try data.load(init, args[3]);
        const catalog_principal: u64 = 42;
        const catalog_key = try p.Ed25519.KeyPair.generateDeterministic(@splat(14));
        const configuration = profile.catalog;
        for ([_]u64{ query_role, inspector_role }) |role| try authorization.grantDefaults(catalog, &admin, configuration.authority, profile.owner, role, catalog.TableAuthority.select);
        const caller = try data.client(init.gpa, &wire, profile);
        const initialized = try caller.call(.initialize);
        initialized.deinit();
        const name = if (second_flight) "items_other" else "items";
        try data.seed(init.gpa, caller, if (second_flight) 2 else 1, name, overflow_flight);
        // Seeding completes native registration through this fixture's root
        // registrar. Resume administrative work after its accepted sequence.
        admin.sequence = (try admin.query(.capabilities)).principal_sequence;
        const found = try caller.call(.{ .lookup = .{ .namespace = 1, .name = name } });
        defer found.deinit();
        var table_source = try q.TableSource.from(init.gpa, caller.connection, found.value.result.lookup orelse return error.MissingSeededTable);
        defer table_source.deinit();
        try save(init, args[3], "flight-capture.json", .{ .executor = writer_principal, .minimum = found.value.result.lookup.?.position });
        const definition: q.SourceDefinition = .{ .resource = configuration.scope.resource, .source = .{ .table = table_source.source } };
        var executor = caller;
        executor.connection.principal = writer_principal;
        executor.connection.role = null;
        executor.key = writer_key;
        const adapter = try init.arena.allocator().alloc(u8, q.UnifiedBehavior.adapter_bytes);
        const workspace_bytes = try init.arena.allocator().alloc(u8, q.fuze.LogicalArrow.working_bytes);
        const cancellation = q.fuze.execution.Cancellation.init(false);
        var owner: q.UnifiedBehavior.Source = .{ .peer = requester.pid, .initializer = catalog_principal, .resources = .{ .wire = &wire, .realm = 45, .principal = writer_principal, .key = writer_key }, .tables = executor, .adapter = adapter, .workspace = workspace_bytes, .cancellation = &cancellation };
        server.failure_policy = .stop;
        const initializing = (try wire.query(.{ .realm = 45, .principal = catalog_principal, .kind = .capabilities }, catalog_key)).principal_sequence;
        _ = try wire.submit(try p.Growth.sign(.{ .realm = 45, .principal = catalog_principal, .sequence = initializing + 1, .command = .{ .send = .{ .pid = writer.pid, .value = try (s.Frame{ .kind = .cast, .payload = try q.UnifiedRequest.Command.encode(.initialize) }).encode() } } }, catalog_key));
        try drive(init, &server, owner.interface());
        const policy = try (q.UnifiedBehavior.PolicyChange{ .expected_revision = 0, .policy = .{ .peer = requester.pid, .requests = requester.resource, .revision = 1, .allow = true, .limits = limits, .target = .{ .catalog = .{ .scope = configuration.scope, .owner = configuration.audience, .principal = query_principal } } } }).encode();
        const sequence = (try wire.query(.{ .realm = 45, .principal = catalog_principal, .kind = .capabilities }, catalog_key)).principal_sequence;
        _ = try wire.submit(try p.Growth.sign(.{ .realm = 45, .principal = catalog_principal, .sequence = sequence + 1, .command = .{ .send = .{ .pid = writer.pid, .value = try (s.Frame{ .kind = .cast, .payload = policy }).encode() } } }, catalog_key));
        try drive(init, &server, owner.interface());
        var requests = try s.GenServer.init(.{ .client = &wire, .realm = 45, .principal = requester_principal, .pid = requester.pid, .generation = requester.generation, .key = requester_key }, "state");
        var behavior: q.UnifiedBehavior.Requester = .{ .principal = query_principal, .source = writer.pid };
        _ = try wire.submit(try p.Growth.sign(.{ .realm = 45, .principal = query_principal, .sequence = 1, .command = .{ .send = .{ .pid = requester.pid, .value = try (s.Frame{ .kind = .cast, .payload = try q.UnifiedRequest.Command.encode(.initialize) }).encode() } } }, caller_key));
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
                _ = try wire.submit(try p.Growth.sign(.{ .realm = 45, .principal = administrator_principal, .sequence = index + 1, .command = .{ .send = .{ .pid = requester.pid, .value = try (s.Frame{ .kind = .cast, .payload = try command.encode() }).encode() } } }, administrator));
                try drive(init, &requests, requester_handler);
            }
        }
        _ = try admin.submit(.{ .own = .{ .pid = writer.pid, .expected_generation = writer.generation, .worker = writer_principal } });
        _ = try admin.submit(.{ .own = .{ .pid = requester.pid, .expected_generation = requester.generation, .worker = requester_principal } });
        try save(init, args[3], "source-public.json", writer_key.public_key.toBytes());
        try save(init, args[3], "requester-public.json", requester_key.public_key.toBytes());
        const source_seed = try seedFile(init, args[3], "source", 8 + seed_offset);
        const request_seed = try seedFile(init, args[3], "requester", 9 + seed_offset);
        const caller_seed = try seedFile(init, args[3], "caller", 10 + seed_offset);
        const courier_seed = try seedFile(init, args[3], "courier", 11 + seed_offset);
        const inspector_seed = try seedFile(init, args[3], "inspector", 12);
        const connection: Connection = .{ .realm = 45, .principal = query_principal, .source = writer.pid, .resource = writer.resource, .requester = requester.pid, .requests = requester.resource };
        const workspace: q.Workspace.Config = .{ .name = "items", .executor = writer_principal, .source = try q.Values.Source.fromNative(init.arena.allocator(), definition), .limits = try q.Values.Limits.fromNative(init.arena.allocator(), limits) };
        try save(init, args[3], "cli.json", .{ .url = args[1], .seed_file = caller_seed, .connection = connection, .workspace = workspace, .request_timeout_ms = 10000 });
        var inspector = connection;
        inspector.principal = 55;
        try save(init, args[3], "inspector.json", .{ .url = args[1], .seed_file = inspector_seed, .connection = inspector, .workspace = workspace });
        try save(init, args[3], "source.json", .{ .url = args[1], .realm = 45, .principal = writer_principal, .pid = writer.pid, .generation = writer.generation + 1, .seed_file = source_seed, .activation_directory = args[3], .tables = q.UnifiedBehavior.TableEndpoint{ .url = args[1], .scope = configuration.scope, .branch = configuration.branch, .audience = configuration.audience }, .role = .{ .unified_source = .{ .peer = requester.pid, .initializer = catalog_principal } } });
        if (flight) try save(init, args[3], "requester.json", .{ .url = args[1], .realm = 45, .principal = requester_principal, .pid = requester.pid, .generation = requester.generation + 1, .seed_file = request_seed, .activation_directory = args[3], .role = .{ .finite_service = finite.configuration } }) else try save(init, args[3], "requester.json", .{ .url = args[1], .realm = 45, .principal = requester_principal, .pid = requester.pid, .generation = requester.generation + 1, .seed_file = request_seed, .activation_directory = args[3], .role = .{ .unified_requester = behavior } });
        try save(init, args[3], "courier.json", .{ .url = args[1], .realm = 45, .principal = courier_principal, .seed_file = courier_seed, .role = .{ .courier = .{ .destinations = .{ writer.pid, requester.pid } } } });
        return;
    }
    const config = try std.Io.Dir.cwd().readFileAlloc(init.io, args[3], init.gpa, .limited(8192));
    defer init.gpa.free(config);
    const parsed = try std.json.parseFromSlice(struct { connection: Connection, workspace: q.Workspace.Config }, init.gpa, config, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    const c = parsed.value.connection;
    const caller_key = try p.Ed25519.KeyPair.generateDeterministic(@splat(if (c.principal == 1235) @as(u8, 16) else 10));
    if (std.mem.eql(u8, args[2], "mutate-source") or std.mem.eql(u8, args[2], "restore-source")) {
        const directory = std.fs.path.dirname(args[3]) orelse return error.MissingConfigurationDirectory;
        const profile = try data.load(init, directory);
        try data.mutate(init.gpa, try data.client(init.gpa, &wire, profile), std.mem.eql(u8, args[2], "restore-source"));
        return;
    }
    if (std.mem.eql(u8, args[2], "next-sequence")) {
        const capability = try wire.query(.{ .realm = c.realm, .principal = c.principal, .kind = .{ .capabilities = {} } }, caller_key);
        try std.json.Stringify.value(capability.principal_sequence + 1, .{}, &output.interface);
        return output.interface.flush();
    }
    if (std.mem.eql(u8, args[2], "revoke-select") or std.mem.eql(u8, args[2], "restore-select")) {
        const definition = try parsed.value.workspace.source.native(init.arena.allocator());
        var reader: q.UnifiedClient = .{ .wire = &wire, .connection = c, .key = caller_key };
        var inspector = (try q.Workspace.directTables(init.gpa, &reader, parsed.value.workspace)).?;
        inspector.connection.principal = 55;
        inspector.key = try p.Ed25519.KeyPair.generateDeterministic(@splat(12));
        const table = try inspector.call(.{ .read_authority = definition.source.table.interpretation.interpretation.object });
        defer table.deinit();
        const role = try authorization.loginRole(catalog, &wire, 45, c.principal, reader.key);
        const object = catalog.TableAuthority.reference(table.value.result.read_authority.table);
        _ = try admin.authorization(if (std.mem.eql(u8, args[2], "revoke-select")) .{ .revoke_privileges = .{ .object = object, .grantee = role, .privileges = catalog.TableAuthority.select, .behavior = .cascade } } else .{ .grant = .{ .object = object, .grantee = role, .privileges = catalog.TableAuthority.select } });
        return;
    }
    if (std.mem.eql(u8, args[2], "released-pins")) {
        const resources: s.client.ResourceReader = .{ .wire = &wire, .realm = 45, .principal = 0, .key = root };
        var source = try resources.open(c.resource);
        var reader: q.UnifiedClient = .{ .wire = &wire, .connection = c, .key = caller_key };
        const tables = (try q.Workspace.directTables(init.gpa, &reader, parsed.value.workspace)).?;
        var after: ?p.Value = null;
        var count: usize = 0;
        while (true) {
            const page = try source.page(after);
            for (page.entries) |entry| if (entry) |item| {
                if (!std.mem.startsWith(u8, item.key.slice(), "\x00Uj")) continue;
                const job = try q.UnifiedRecords.Job.decode(item.value);
                if (job.source != .table) return error.UnexpectedNativeSourcePin;
                const pin = (try q.CapturedTablePin.observe(init.arena.allocator(), &source, .{ .job = job.id, .source = 0 }, c.source)) orelse return error.MissingTablePin;
                const status = try tables.call(.{ .pin_status = .{ .object = pin.grant.binding.interpretation.object, .owner = pin.grant.binding.owner } });
                defer status.deinit();
                if (!status.value.result.pin_state.released) return error.SourcePinStillHeld;
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
        const directory = std.fs.path.dirname(args[3]) orelse return error.MissingConfigurationDirectory;
        const filename = if (requester) "requester-public.json" else "source-public.json";
        const previous_path = try std.fs.path.join(init.arena.allocator(), &.{ directory, filename });
        const previous_bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, previous_path, init.arena.allocator(), .limited(1024));
        const previous = try std.json.parseFromSlice([32]u8, init.arena.allocator(), previous_bytes, .{});
        _ = try admin.submit(.{ .rotate_worker = .{ .pid = pid, .worker = principal, .expected_generation = generation, .expected_public_key = previous.value, .expected_permissions = p.permission(.inspect) | p.permission(.execute) | p.permission(.publish), .public_key = public } });
        try save(init, directory, filename, public);
        try std.json.Stringify.value(.{ .generation = generation + 1 }, .{}, &output.interface);
        return output.interface.flush();
    }
    if (std.mem.startsWith(u8, args[2], "capture:")) {
        var caller: q.UnifiedClient = .{ .wire = &wire, .connection = c, .key = caller_key };
        caller.tables = try q.Workspace.directTables(init.gpa, &caller, parsed.value.workspace);
        const namespace = try std.fmt.parseInt(u64, args[2][8..], 10);
        const workspace = try init.gpa.alloc(u8, q.fuze.LogicalArrow.working_bytes);
        defer init.gpa.free(workspace);
        var bytes: [q.fuze.LogicalArrow.segment_bytes]u8 = undefined;
        var cursor: ?q.UnifiedResult.Cursor = null;
        var rows: u64 = 0;
        var length: u64 = 0;
        var segments: u64 = 0;
        while (true) {
            var arena = std.heap.ArenaAllocator.init(init.gpa);
            defer arena.deinit();
            var decoded: q.fuze.LogicalInspect.Batch = undefined;
            const page = try caller.page(namespace, cursor, arena.allocator(), workspace, &bytes, &decoded);
            defer decoded.deinit();
            rows += decoded.rows.len;
            length += page.arrow.len;
            segments += 1;
            cursor = page.next;
            if (cursor == null) break;
        }
        try std.json.Stringify.value(.{ .rows = rows, .bytes = length, .segments = segments }, .{}, &output.interface);
        return output.interface.flush();
    }
    if (std.mem.eql(u8, args[2], "fence") or std.mem.eql(u8, args[2], "fence-requester")) {
        const requester = std.mem.eql(u8, args[2], "fence-requester");
        const pid = if (requester) c.requester else c.source;
        const process = (try admin.query(.{ .process = pid })).body.process.process;
        _ = try admin.submit(.{ .own = .{ .pid = pid, .expected_generation = process.generation, .worker = if (requester) 65537 else 65536 } });
        try std.json.Stringify.value(.{ .generation = process.generation + 1 }, .{}, &output.interface);
        return output.interface.flush();
    } else if (std.mem.eql(u8, args[2], "participation")) {
        // Associations are established before execution ownership. Do not mutate
        // the topology of the already active query workers to build a UI fixture.
        const participant = try admin.submit(.{ .spawn = .{} });
        for (0..10) |index| {
            var name: [32]u8 = undefined;
            _ = try admin.submit(.{ .associate = .{ .pid = participant, .name = try p.Value.init(try std.fmt.bufPrint(&name, "shared-{d}", .{index})), .resource = c.resource, .required = false } });
        }
        const hidden = try admin.submit(.{ .create_resource = .{ .writer = c.source } });
        _ = try admin.submit(.{ .grant_resource = .{ .resource = hidden, .subject = 0, .permissions = p.State.all_permissions } });
        _ = try admin.submit(.{ .associate = .{ .pid = participant, .name = try p.Value.init("hidden-participation"), .resource = hidden, .required = false } });
        try std.json.Stringify.value(.{ .pid = participant }, .{}, &output.interface);
        return output.interface.flush();
    } else if (std.mem.eql(u8, args[2], "revoke-inspector-resource") or std.mem.eql(u8, args[2], "restore-inspector-resource")) {
        _ = try admin.submit(.{ .grant_resource = .{ .resource = c.resource, .subject = 55, .permissions = if (std.mem.eql(u8, args[2], "revoke-inspector-resource")) 0 else p.State.permission(.inspect) | p.State.permission(.read) } });
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
        const role = try authorization.loginRole(catalog, &wire, 45, 55, try p.Ed25519.KeyPair.generateDeterministic(@splat(12)));
        _ = try admin.authorization(if (std.mem.eql(u8, args[2], "expand-inspector")) .{ .grant = .{ .object = .{ .kind = .realm, .id = 0 }, .grantee = role, .privileges = p.all_permissions } } else .{ .revoke_privileges = .{ .object = .{ .kind = .realm, .id = 0 }, .grantee = role, .privileges = p.all_permissions & ~p.permission(.inspect), .behavior = .cascade } });
    } else return error.UnknownMode;
}
