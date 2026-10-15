//! Native fixture provisioning through the same public owners used by callers.
const std = @import("std");
const q = @import("transit_query");
const s = @import("transit_station");
const p = s.protocol;
const Catalog = @import("catalog_query_support.zig");
const c = q.catalog;
const Admin = @import("growing_support.zig").Admin(46);
const limits: q.Bundle.Limits = .{ .pages = 1000, .segments = 100, .result_bytes = 1048576 };
fn path(init: std.process.Init, directory: []const u8, name: []const u8) ![]const u8 {
    return std.fmt.allocPrint(init.arena.allocator(), "{s}/{s}", .{ directory, name });
}
fn save(init: std.process.Init, directory: []const u8, name: []const u8, value: anytype) !void {
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = try path(init, directory, name), .data = try std.json.Stringify.valueAlloc(init.arena.allocator(), value, .{}) });
}
fn seed(init: std.process.Init, directory: []const u8, name: []const u8, byte: u8) ![]const u8 {
    const location = try path(init, directory, name);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = location, .data = &std.fmt.bytesToHex(@as([32]u8, @splat(byte)), .lower) });
    return location;
}
pub fn print(init: std.process.Init, value: anytype) !void {
    var buffer: [4096]u8 = undefined;
    var out = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    try std.json.Stringify.value(value, .{}, &out.interface);
    try out.interface.writeByte('\n');
    try out.interface.flush();
}
const send = Catalog.send;
pub fn provision(init: std.process.Init, url: []const u8, wire: *s.client.Client, admin: *Admin, directory: []const u8) !void {
    const writer_key = try p.Ed25519.KeyPair.generateDeterministic(@splat(8));
    const requester_key = try p.Ed25519.KeyPair.generateDeterministic(@splat(9));
    const caller_key = try p.Ed25519.KeyPair.generateDeterministic(@splat(10));
    const courier_key = try p.Ed25519.KeyPair.generateDeterministic(@splat(11));
    const requester = try admin.provision(65537, requester_key);
    const writer = try admin.provisionReader(65536, writer_key, requester.resource);
    _ = try Catalog.authorization.login(c, admin, "query-caller", 1234, caller_key, null);
    _ = try admin.submit(.{ .grant = .{ .subject = 65538, .public_key = courier_key.public_key.toBytes(), .permissions = p.permission(.inspect) | p.permission(.send) | p.permission(.delivery) } });

    for ([_]u64{ writer.resource, requester.resource }) |resource| _ = try admin.submit(.{ .grant_resource = .{ .resource = resource, .subject = 1234, .permissions = p.State.permission(.inspect) | p.State.permission(.read) } });
    const config = try Catalog.provision(admin, writer.resource, writer.pid);
    const connection: q.UnifiedClient.Connection = .{ .realm = 46, .principal = 1234, .source = writer.pid, .resource = writer.resource, .requester = requester.pid, .requests = requester.resource };
    try save(init, directory, "combined.json", config);
    try save(init, directory, "combined-connection.json", connection);
    _ = try admin.submit(.{ .own = .{ .pid = writer.pid, .expected_generation = writer.generation, .worker = 65536 } });
    try save(init, directory, "source.json", .{ .url = url, .realm = 46, .principal = 65536, .pid = writer.pid, .generation = writer.generation + 1, .seed_file = try seed(init, directory, "source.seed", 8), .activation_directory = directory, .interval_ms = 10, .role = .{ .catalog = config } });
    try save(init, directory, "requester.json", .{ .url = url, .realm = 46, .principal = 65537, .pid = requester.pid, .generation = requester.generation, .seed_file = try seed(init, directory, "requester.seed", 9), .activation_directory = directory, .interval_ms = 10, .role = .{ .unified_requester = .{ .principal = @as(u64, 1234), .source = writer.pid } } });
    try save(init, directory, "courier.json", .{ .url = url, .realm = 46, .principal = 65538, .seed_file = try seed(init, directory, "courier.seed", 11), .interval_ms = 10, .role = .{ .courier = .{ .destinations = .{ writer.pid, requester.pid } } } });
    _ = try seed(init, directory, "caller.seed", 10);
    _ = try wire.submit(try p.Growth.sign(.{ .realm = 46, .principal = 1234, .sequence = 1, .command = .{ .send = .{ .pid = requester.pid, .value = try (s.Frame{ .kind = .cast, .payload = try q.UnifiedRequest.Command.encode(.initialize) }).encode() } } }, caller_key));
    return print(init, connection);
}
pub fn execute(init: std.process.Init, url: []const u8, wire: *s.client.Client, admin: *Admin, directory: []const u8, command: []const u8, connection: q.UnifiedClient.Connection) !void {
    if (std.mem.eql(u8, command, "combined-fence") or std.mem.eql(u8, command, "combined-fence-requester")) {
        const requester = std.mem.eql(u8, command, "combined-fence-requester");
        const pid = if (requester) connection.requester else connection.source;
        const process = (try admin.query(.{ .process = pid })).body.process.process;
        _ = try admin.submit(.{ .own = .{ .pid = pid, .expected_generation = process.generation, .worker = if (requester) 65537 else 65536 } });
        return print(init, .{ .generation = process.generation + 1 });
    }
    if (std.mem.eql(u8, command, "combined-progress")) {
        // Progress polling needs the current input only. Reading Table policies
        // here opens a resource view that the very turn being polled may change.
        const process = (try admin.query(.{ .process = connection.source })).body.process;
        return print(init, .{ .pending = if (process.input) |value| value.position else @as(?u64, null) });
    }
    if (std.mem.eql(u8, command, "combined-deliver") or std.mem.eql(u8, command, "combined-deliver-table")) {
        const tables_only = std.mem.eql(u8, command, "combined-deliver-table");
        for (0..32) |_| {
            var after: ?u64 = null;
            const basis = (try admin.query(.capabilities)).position;
            for (0..4096) |_| {
                const response = admin.query(.{ .outputs = .{ .after = after, .position = basis } }) catch |err| {
                    // Like the real courier, restart only an expired read. No
                    // signed delivery has been prepared or sent at this point.
                    if (err == error.Conflict and wire.last_rejection == .QueryExpired) break;
                    return err;
                };
                const page = response.body.outputs;
                for (page.entries) |slot| if (slot) |output| {
                    if (tables_only) {
                        if (output.source != connection.source or output.destination != connection.source) continue;
                        const frame = try s.Frame.decode(output.value);
                        if (frame.kind != .cast or !(std.mem.startsWith(u8, frame.payload.slice(), "TCQ1") or std.mem.startsWith(u8, frame.payload.slice(), "TCA1V"))) continue;
                    }
                    if (output.phase == .pending and (output.destination == connection.source or output.destination == connection.requester)) return print(init, .{ .delivered = try admin.submit(.{ .deliver = output.id }) });
                };
                after = page.next orelse return print(init, .{ .delivered = @as(?u64, null) });
            } else return error.ProofDeliveryBudgetExceeded;
        }
        return error.ProofDeliveryReadConflict;
    }
    const encoded = try std.Io.Dir.cwd().readFileAlloc(init.io, try path(init, directory, "combined.json"), init.arena.allocator(), .limited(8192));
    const config = try std.json.parseFromSliceLeaky(c.TableCatalogRecords.Configuration, init.arena.allocator(), encoded, .{});
    if (std.mem.eql(u8, command, "combined-grants")) {
        try Catalog.grant(admin, config);
        return print(init, .{ .authorization_revision = (try admin.query(.{ .authorization = .{ .kind = .identity } })).body.authorization.revision });
    }
    if (std.mem.eql(u8, command, "combined-delegate")) return print(init, try Catalog.delegate(wire, config, connection.requester, connection.requests, limits, 1));
    if (std.mem.eql(u8, command, "combined-source-export")) {
        var caller = try Catalog.caller(wire, config);
        var found = (try caller.lookup(init.gpa, try c.TableMetadata.Name.init("items"))) orelse return error.TableNotFound;
        defer found.deinit();
        var table = try q.TableSource.from(init.gpa, config, found);
        defer table.deinit();
        const definition: q.SourceDefinition = .{ .resource = config.scope.resource, .source = .{ .table = table.source } };
        const source_value = try q.Values.Source.fromNative(init.arena.allocator(), definition);
        var query_client: q.UnifiedClient = .{ .wire = wire, .connection = connection, .key = try p.Ed25519.KeyPair.generateDeterministic(@splat(10)) };
        const bundle = try query_client.authorizeBundle(try q.Bundle.fromSql(init.arena.allocator(), definition, "items", "SELECT * FROM items", limits));
        var bytes: [q.Bundle.max_bytes]u8 = undefined;
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = try path(init, directory, "bundle.bin"), .data = try bundle.encode(&bytes) });
        try save(init, directory, "client.json", .{ .url = url, .connection = connection, .kind = "table", .source = source_value });
        const credential = try path(init, directory, "caller.seed");
        try save(init, directory, "shell.json", .{ .url = url, .seed_file = credential, .connection = connection, .workspace = q.Workspace.Config{ .name = "items", .source = source_value, .limits = try q.Values.Limits.fromNative(init.arena.allocator(), limits) } });
        try save(init, directory, "catalog-console.json", .{ .version = 1, .profile = "catalog_v1", .execution = "interactive", .transport = "loopback", .format = "json", .url = url, .seed_file = credential, .catalog = c.TableClient.Connection{ .scope = config.scope, .owner = config.owner, .principal = connection.principal }, .writes = .{ .recovery_file = "console-writes.json" } });
        return print(init, source_value);
    }
    var reader = try (s.client.ResourceReader{ .wire = wire, .realm = 46, .principal = 0, .key = admin.key }).open(connection.resource);
    if (std.mem.eql(u8, command, "combined-state")) {
        const process = (try admin.query(.{ .process = connection.source })).body.process;
        const initialized = try reader.read(c.Records.key(config.scope.catalog, 'c', 0, 0));
        if (initialized) |record| if (!std.meta.eql(try c.Records.decode(c.TableCatalogRecords.Configuration, 'C', record), config)) return error.CatalogConfigurationChanged;
        return print(init, .{ .phase = if (initialized != null) "ready" else "uninitialized", .pending = if (process.input) |value| value.position else @as(?u64, null), .query = try q.UnifiedCapture.policy(&reader, connection.requester), .authorization_revision = (try admin.query(.{ .authorization = .{ .kind = .identity } })).body.authorization.revision });
    }
    if (std.mem.eql(u8, command, "combined-initialize")) {
        var caller = try Catalog.caller(wire, config);
        return print(init, try caller.submit(try caller.prepareControl(.{ .initialize = config })));
    }
    if (std.mem.eql(u8, command, "combined-query-revoke") or std.mem.eql(u8, command, "combined-query-restore")) {
        var policy = (try q.UnifiedCapture.policy(&reader, connection.requester)).?;
        const expected = policy.revision;
        policy.revision += 1;
        policy.allow = std.mem.eql(u8, command, "combined-query-restore");
        return print(init, try send(wire, connection.source, try (q.CatalogQueryOwner.PolicyChange{ .expected_revision = expected, .policy = policy }).encode()));
    }
    if (std.mem.eql(u8, command, "combined-mutation-revoke") or std.mem.eql(u8, command, "combined-mutation-restore")) {
        const who = try Catalog.authorization.loginRole(c, wire, 46, connection.principal, try p.Ed25519.KeyPair.generateDeterministic(@splat(10)));
        try Catalog.authorization.tablePrivileges(c, admin, config, 1, who, c.TableAuthority.insert | c.TableAuthority.update | c.TableAuthority.delete, std.mem.eql(u8, command, "combined-mutation-restore"));
        return print(init, .{ .authorization_revision = (try admin.query(.{ .authorization = .{ .kind = .identity } })).body.authorization.revision });
    }
    return error.InvalidCombinedCommand;
}
