//! Direct catalog provisioning and independent SQL administrator for gateway proofs.
const std = @import("std");
const g = @import("transit_sql_service");
const c = g.catalog;
const s = @import("transit_station");
const p = c.protocol;
const support = @import("fixture_native_proof_files");
const authorization = @import("fixture_table_authorization_support");
const Admin = @import("fixture_growing_support").Admin(46);
pub const Config = struct { definition: p.Growth.Definition, catalog: c.DirectCatalog.Configuration, owner_role: u64 };
pub fn caller(init: std.process.Init, wire: *s.client.Client, config: Config) !c.DirectTableClient {
    if (config.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
    return .{ .allocator = init.gpa, .authority = wire, .service = wire, .connection = .{ .scope = config.catalog.scope, .branch = config.catalog.branch, .audience = config.catalog.audience, .principal = 1234, .role = null }, .key = try support.key(10) };
}
fn privileges(admin: *Admin, client: c.DirectTableClient, config: Config, role: u64, rights: u64, allowed: bool) !void {
    var cursor: ?u64 = null;
    for (0..100) |_| {
        const response = try client.call(.{ .list = .{ .namespace = 1, .after = cursor } });
        defer response.deinit();
        const page = response.value.result.list;
        for (page.entries) |slot| if (slot) |entry| try authorization.tablePrivileges(c, admin, config.catalog, entry.interpretation.object.object, role, rights, allowed);
        cursor = page.next orelse return;
    }
    return error.ProofTableBudget;
}
const SavedHistory = struct { key: c.DirectClientToken.Key, intent: c.DirectHistory.Intent };
fn history(init: std.process.Init, client: c.DirectTableClient, directory: []const u8, mode: []const u8, args: []const []const u8) !void {
    if (args.len == 0) return error.Usage;
    const operation = try std.fmt.parseInt(u64, args[0], 10);
    const name = try std.fmt.allocPrint(init.arena.allocator(), "history-{d}.json", .{operation});
    const previous = support.load(SavedHistory, init, directory, name) catch |err| switch (err) {
        error.FileNotFound => null,
        else => return err,
    };
    const saved = previous orelse blk: {
        if (!std.mem.eql(u8, mode, "history-retain") or args.len < 2) return error.MissingHistoricalRequest;
        var selection: c.DirectHistory.Selection = .{ .owner = .{ .scope = client.connection.scope, .principal = client.connection.principal, .operation = operation }, .branch = client.connection.branch, .directory = null };
        for (args[1..]) |table| {
            const response = try c.DirectHistory.call(client, .{ .select = .{ .selection = selection, .namespace = 1, .name = try .init(table) } });
            defer response.deinit();
            selection = response.value.result.historical_catalog.selection;
        }
        var token: [16]u8 = @splat(91);
        std.mem.writeInt(u64, token[0..8], operation, .little);
        const value: SavedHistory = .{
            .key = .{ .definition = p.Growth.current_definition, .connection = client.connection, .account = @splat(91), .token = token },
            .intent = .{ .connection = client.connection, .namespace = 1, .operation = operation, .selection = selection.directory.?, .common = null },
        };
        // The complete original selection is durable before any acquisition.
        // Retries load it, even after current names or data have changed.
        try support.save(init, directory, name, value);
        break :blk value;
    };
    const releasing = std.mem.eql(u8, mode, "history-release");
    const inspect = std.mem.eql(u8, mode, "history-inspect");
    if (!releasing and !inspect and !std.mem.eql(u8, mode, "history-retain")) return error.Usage;
    for (0..1000) |step| {
        const request: c.DirectHistory.Request = if (inspect) .{ .inspect = saved.key } else if (releasing) .{ .release = saved.key } else if (step == 0) .{ .acquire = .{ .key = saved.key, .intent = saved.intent } } else .{ .advance = saved.key };
        const response = try c.DirectHistory.call(client, request);
        defer response.deinit();
        const status = response.value.result.historical_catalog.status orelse return error.MissingHistoricalStatus;
        if (inspect or status.state.phase == (if (releasing) c.DirectHistory.Phase.released else c.DirectHistory.Phase.published)) {
            var text: [c.DirectHistory.Selector.text_bytes]u8 = undefined;
            return support.print(init, .{ .phase = status.state.phase, .snapshot = status.state.snapshot, .selector = if (status.state.snapshot) |snapshot| try c.DirectHistory.Selector.encode(snapshot, &text) else null });
        }
    }
    return error.ProofHistoryBudget;
}
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len == 2 and std.mem.eql(u8, args[1], "public")) return support.print(init, (try support.key(7)).public_key.toBytes());
    if (args.len < 4) return error.Usage;
    const mode = args[2];
    const directory = args[3];
    var wire = s.client.Client.init(init.gpa, init.io, args[1]);
    defer wire.deinit();
    wire.timeout_ms = 30000;
    errdefer if (wire.last_rejection) |cause| std.debug.print("Authority rejection: {s}\n", .{@tagName(cause)});
    var admin: Admin = .{ .wire = &wire, .key = try support.key(7) };
    admin.sequence = (try admin.query(.capabilities)).principal_sequence;
    if (std.mem.eql(u8, mode, "provision")) {
        const pid = try admin.submit(.{ .spawn = .{} });
        const resource = try admin.submit(.{ .create_resource = .{ .writer = pid, .owned = false } });
        const owner = try authorization.login(c, &admin, "table-owner", 1234, try support.key(10), null);
        const scope: p.DataLifecycle.Scope = .{ .realm = 46, .resource = resource, .catalog = 1 };
        const config: Config = .{ .definition = p.Growth.current_definition, .owner_role = owner, .catalog = .{ .scope = scope, .branch = 1, .partition = 1, .audience = 100, .authority = try authorization.profile(c, &admin, scope, 0, owner), .database_name = try .init("transit"), .initial_schema_name = try .init("public") } };
        try support.save(init, directory, "catalog.json", config);
        try support.saveBytes(init, directory, "registrar.seed", &std.fmt.bytesToHex(@as([32]u8, @splat(7)), .lower));
        try support.save(init, directory, "catalog-node.json", .{ .catalog = config.catalog, .registrar = .{ .principal = 0, .seed_file = try support.path(init, directory, "registrar.seed") } });
        return support.print(init, config);
    }
    const config = try support.load(Config, init, directory, "catalog.json");
    var client = try caller(init, &wire, config);
    if (std.mem.startsWith(u8, mode, "history-")) return history(init, client, directory, mode, args[4..]);
    if (std.mem.eql(u8, mode, "initialize")) {
        const response = try client.call(.initialize);
        defer response.deinit();
        return support.print(init, response.value.result);
    }
    if (std.mem.eql(u8, mode, "external-provision")) {
        const login = try authorization.login(c, &admin, "gateway-login", 1235, try support.key(11), null);
        const role = (try admin.authorization(.{ .create_role = .{ .name = try .init("gateway-caller") } })).?;
        for ([_]u64{ login, config.owner_role }) |member| _ = try admin.authorization(.{ .membership = .{ .member = member, .role = role, .inherit = false, .set = true } });
        _ = try admin.authorization(.{ .grant = .{ .object = .{ .kind = .realm, .id = 0 }, .grantee = role, .privileges = p.permission(.inspect) | p.permission(.send) } });
        try authorization.grantDefaults(c, &admin, config.catalog.authority, config.owner_role, role, c.TableAuthority.table_actions);
        try authorization.grantDefaults(c, &admin, config.catalog.authority, role, config.owner_role, c.TableAuthority.table_actions);
        _ = try admin.authorization(.{ .grant = .{ .object = c.TableAuthority.reference(config.catalog.authority.initial_schema_authority), .grantee = role, .privileges = c.TableAuthority.create } });
        try privileges(&admin, client, config, role, c.TableAuthority.table_actions, true);
        return support.print(init, .{ .principal = 1235, .role = role });
    }
    if (std.mem.eql(u8, mode, "external-role")) {
        const role = (try admin.query(.{ .authorization = .{ .kind = .{ .resolve = try .init("gateway-caller") } } })).body.authorization.body.resolve.id;
        const login = (try admin.query(.{ .authorization = .{ .kind = .{ .resolve = try .init("gateway-login") } } })).body.authorization.body.resolve.id;
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
        return support.print(init, .{ .selected = allowed });
    }
    if (std.mem.eql(u8, mode, "external-write-grants") or std.mem.eql(u8, mode, "external-read-grants")) {
        const role = (try admin.query(.{ .authorization = .{ .kind = .{ .resolve = try .init("gateway-caller") } } })).body.authorization.body.resolve.id;
        const allowed = std.mem.eql(u8, args[4], "allow");
        const writes = std.mem.eql(u8, mode, "external-write-grants");
        if (writes) {
            const schema = c.TableAuthority.reference(config.catalog.authority.initial_schema_authority);
            _ = try admin.authorization(if (allowed) .{ .grant = .{ .object = schema, .grantee = role, .privileges = c.TableAuthority.create } } else .{ .revoke_privileges = .{ .object = schema, .grantee = role, .privileges = c.TableAuthority.create, .behavior = .cascade } });
        }
        try privileges(&admin, client, config, role, if (writes) c.TableAuthority.insert | c.TableAuthority.update | c.TableAuthority.delete else c.TableAuthority.select, allowed);
        return support.print(init, .{ .write = if (writes) allowed else null, .read = if (!writes) allowed else null });
    }
    if (std.mem.eql(u8, mode, "external-ddl-admin")) {
        client.connection.role = (try admin.query(.{ .authorization = .{ .kind = .{ .resolve = try .init("gateway-caller") } } })).body.authorization.body.resolve.id;
        const operation = try std.fmt.parseInt(u64, args[4], 10);
        var prepared = try c.DirectTablePreparedDdl.prepare(init.gpa, client, 1, args[5], .transit, null);
        defer prepared.deinit();
        var work = try prepared.bind(init.gpa, client, operation, if (prepared.compiled.statement == .create) operation else null);
        defer work.deinit();
        if (work != .table) return error.ExpectedTableIntent;
        try support.saveBytes(init, directory, "external-intent.bin", work.table.bytes);
        try @import("fixture_catalog_query_support").execute(client, &work.table);
        return support.print(init, .{ .state = "terminal", .outcome = "applied" });
    }
    if (std.mem.eql(u8, mode, "inspect")) {
        const response = try client.call(.{ .lookup = .{ .namespace = 1, .name = args[4] } });
        defer response.deinit();
        const metadata = response.value.result.lookup orelse return support.print(init, .{ .found = false });
        const data = try client.call(.{ .observe = .{ .namespace = 1, .interpretation = metadata.interpretation.interpretation, .rows = .{} } });
        defer data.deinit();
        if (data.value.result.observation.page.?.more) return error.ProofRowBudget;
        return support.print(init, .{ .found = true, .object = metadata.interpretation.interpretation.object.object, .count = data.value.result.observation.page.?.rows.len });
    }
    if (std.mem.eql(u8, mode, "select")) {
        var prepared = try g.query.direct.DirectTablePrepared.prepare(init.gpa, client, 1, args[4], .transit, null);
        defer prepared.deinit();
        const response = try client.call(.{ .lookup = .{ .namespace = 1, .name = prepared.binding.name.slice() } });
        defer response.deinit();
        const metadata = response.value.result.lookup orelse return error.TableNotFound;
        try prepared.binding.check(client.connection, metadata);
        const dir = try std.Io.Dir.cwd().openDir(init.io, directory, .{});
        defer dir.close(init.io);
        var pins = try g.ReadCache.init(init.gpa, init.io, dir, .{ .realm = 46, .account = @splat(78) }, 1);
        defer pins.deinit();
        const pin = try pins.acquireCurrent(client, prepared.binding);
        defer pins.close(client, pin) catch {};
        var query = try g.query.direct.DirectTableQuery.openPreparedRetained(init.gpa, client, try pin.snapshot(), &prepared, &.{}, .{ .requests = 10000, .rows = 128, .result_bytes = 8 * 1024 * 1024 }, null, null, .{});
        defer query.deinit();
        var buffer: [4096]u8 = undefined;
        var out = std.Io.File.stdout().writerStreaming(init.io, &buffer);
        try out.interface.writeAll("{\"rows\":[");
        var count: usize = 0;
        while (try query.next()) |value| {
            var row = value;
            defer row.deinit();
            if (count != 0) try out.interface.writeByte(',');
            try out.interface.writeByte('[');
            for (row.cells, prepared.output.type.structure, 0..) |cell, field, i| {
                if (i != 0) try out.interface.writeByte(',');
                const json = try c.fuze.LogicalJson.encode(init.gpa, cell, field);
                defer init.gpa.free(json);
                try out.interface.writeAll(json);
            }
            try out.interface.writeByte(']');
            count += 1;
        }
        try out.interface.writeAll("],\"complete\":true}\n");
        try out.interface.flush();
        return pins.close(client, pin);
    }
    return error.Usage;
}
