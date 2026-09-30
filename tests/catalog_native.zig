//! Explicit catalog test application over public client/Station APIs.
const std = @import("std");
const t = std.testing;
const c = @import("transit_catalog");
const s = @import("transit_station");
const p = s.protocol;
const g = p.Growth;
const Admin = @import("growing_support.zig").Admin(46);
const Config = struct { definition: g.Definition, writer: Admin.Provision };
const Frozen = struct { definition: g.Definition, signed: g.SignedRequest };
const SavedCursor = struct { definition: g.Definition, cursor: ?c.Inspection.Cursor };
fn owner(config: Config) c.Catalog {
    return .{ .configuration = .{ .scope = .{ .realm = 46, .resource = config.writer.resource, .catalog = std.math.maxInt(u64) }, .owner = config.writer.pid, .administrator = 1234 } };
}
fn key(comptime byte: u8) !p.Ed25519.KeyPair {
    return p.Ed25519.KeyPair.generateDeterministic(@splat(byte));
}
fn save(init: std.process.Init, directory: []const u8, name: []const u8, value: anytype) !void {
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = try std.fmt.allocPrint(init.arena.allocator(), "{s}/{s}", .{ directory, name }), .data = try std.json.Stringify.valueAlloc(init.arena.allocator(), value, .{}) });
}
fn load(comptime T: type, init: std.process.Init, directory: []const u8, name: []const u8) !T {
    const a = init.arena.allocator();
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, try std.fmt.allocPrint(a, "{s}/{s}", .{ directory, name }), a, .limited(65536));
    const value = try std.json.parseFromSliceLeaky(T, a, bytes, .{});
    if (!std.mem.eql(u8, bytes, try std.json.Stringify.valueAlloc(a, value, .{}))) return error.NoncanonicalFixture;
    return value;
}
fn print(init: std.process.Init, value: anytype) !void {
    var buffer: [8192]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    try std.json.Stringify.value(value, .{}, &stdout.interface);
    try stdout.interface.writeByte('\n');
    try stdout.interface.flush();
}
fn send(wire: *s.client.Client, config: Config, payload: p.Value) !g.SignedRequest {
    const sequence = (try wire.query(.{ .realm = 46, .principal = 1234, .kind = .capabilities }, try key(10))).principal_sequence;
    return g.sign(.{ .realm = 46, .principal = 1234, .sequence = sequence + 1, .command = .{ .send = .{ .pid = config.writer.pid, .value = try (s.Frame{ .kind = .cast, .payload = payload }).encode() } } }, try key(10));
}
const Adapter = struct {
    session: *s.client.Session,
    fn read(raw: *anyopaque, view: g.View, address: p.Value) !?p.Value {
        const self: *Adapter = @ptrCast(@alignCast(raw));
        const result = try self.session.readView(view.id, address, null);
        if (result.view == null or !std.meta.eql(result.view.?, view)) return error.InvalidAuthorityResponse;
        return if (result.page.entries[0]) |entry| entry.value else null;
    }
    fn page(raw: *anyopaque, view: g.View, after: ?p.Value) !s.Turn.Page {
        const self: *Adapter = @ptrCast(@alignCast(raw));
        const result = try self.session.readView(view.id, null, after);
        if (result.view == null or !std.meta.eql(result.view.?, view)) return error.InvalidAuthorityResponse;
        return result.page;
    }
};
fn prepare(init: std.process.Init, wire: *s.client.Client, config: Config) !s.client.Session.Pending {
    var session: s.client.Session = .{ .client = wire, .realm = 46, .principal = 65536, .pid = config.writer.pid, .generation = config.writer.generation, .key = try key(8) };
    const delivery = (try session.receive()) orelse return error.MissingInput;
    const resource = (try wire.query(.{ .realm = 46, .principal = 65536, .kind = .{ .resource = config.writer.resource } }, try key(8))).body.resource;
    const deadline: u64 = @intCast(std.Io.Clock.real.now(init.io).toMilliseconds() + 30000);
    const opened = try (try session.prepareView(delivery, resource, deadline)).submit(wire);
    const first = try session.readView(opened.position, c.Records.key(std.math.maxInt(u64), 'c', 0, 0), null);
    const fresh = (try session.receive()) orelse return error.MissingInput;
    if (fresh.input.position != delivery.input.position or fresh.revision != delivery.revision) return error.InputChanged;
    var adapter: Adapter = .{ .session = &session };
    var turn = try s.Turn.init(fresh, first.view.?, .{ .context = &adapter, .read = Adapter.read, .page = Adapter.page });
    const payload = (try s.Frame.decode(fresh.input.value)).payload;
    const catalog = owner(config);
    if (std.mem.eql(u8, payload.slice(), "catalog.initialize")) {
        try catalog.initialize(&turn);
    } else if (std.mem.startsWith(u8, payload.slice(), "TCA1p")) {
        const policy = try c.Records.decode(c.Model.Policy, 'p', payload);
        try catalog.setPolicy(&turn, policy.revision - 1, policy);
    } else {
        _ = try catalog.createTable(&turn, try c.Records.decode(c.Model.CreateTable, 'q', payload));
    }
    try turn.validate();
    return session.prepareCommit(fresh, turn.decision);
}
fn request(init: std.process.Init, directory: []const u8) !c.Model.CreateTable {
    const saved = try load(Frozen, init, directory, "send.json");
    return c.Records.decode(c.Model.CreateTable, 'q', (try s.Frame.decode(saved.signed.request.command.send.value)).payload);
}
fn restored(init: std.process.Init, directory: []const u8) !c.Client.Prepared {
    return restoredFile(init, directory, "prepared.json");
}
fn restoredFile(init: std.process.Init, directory: []const u8, name: []const u8) !c.Client.Prepared {
    const a = init.arena.allocator();
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, try std.fmt.allocPrint(a, "{s}/{s}", .{ directory, name }), a, .limited(c.Client.Prepared.max_saved_bytes));
    return c.Client.Prepared.restore(a, bytes);
}
fn hostConfig(init: std.process.Init, url: []const u8, directory: []const u8, config: Config) !void {
    const seed = try std.fmt.allocPrint(init.arena.allocator(), "{s}/worker.key", .{directory});
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = seed, .data = "0808080808080808080808080808080808080808080808080808080808080808" });
    try save(init, directory, "host.json", .{ .url = url, .realm = @as(u64, 46), .principal = @as(u64, 65536), .pid = config.writer.pid, .generation = config.writer.generation, .seed_file = seed, .activation_directory = directory, .interval_ms = @as(u32, 2), .request_timeout_ms = @as(u32, 10000), .role = .{ .catalog = owner(config).configuration } });
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
    var admin: Admin = .{ .wire = &wire, .key = try key(7) };
    admin.sequence = (try admin.query(.capabilities)).principal_sequence;
    if (std.mem.eql(u8, mode, "provision") or std.mem.eql(u8, mode, "provision-host")) {
        const config: Config = .{ .definition = g.current_definition, .writer = try admin.provision(65536, try key(8)) };
        _ = try admin.submit(.{ .grant = .{ .subject = 1234, .public_key = (try key(10)).public_key.toBytes(), .permissions = p.permission(.inspect) | p.permission(.send) } });
        _ = try admin.submit(.{ .grant_resource = .{ .resource = config.writer.resource, .subject = 1234, .permissions = p.State.permission(.inspect) | p.State.permission(.read) } });
        if (std.mem.eql(u8, mode, "provision")) {
            _ = try wire.submit(try send(&wire, config, try p.Value.init("catalog.initialize")));
            _ = try (try prepare(init, &wire, config)).submit(&wire);
        } else try hostConfig(init, args[1], directory, config);
        try save(init, directory, "catalog.json", config);
        return print(init, config);
    }
    var config = try load(Config, init, directory, "catalog.json");
    var caller: c.Client = .{ .transport = &wire, .connection = .{ .scope = owner(config).configuration.scope, .owner = config.writer.pid, .principal = 1234 }, .key = try key(10) };
    if (std.mem.eql(u8, mode, "list")) {
        var cursor: ?c.Inspection.Cursor = if (args.len > 4) (try load(SavedCursor, init, directory, "cursor.json")).cursor else null;
        if (args.len > 4 and std.mem.eql(u8, args[4], "stale")) cursor.?.resource_revision -= 1;
        if (args.len > 4 and std.mem.eql(u8, args[4], "foreign")) cursor.?.scope.catalog -= 1;
        const page = try caller.list(cursor);
        try save(init, directory, "cursor.json", SavedCursor{ .definition = g.current_definition, .cursor = page.next });
        return print(init, page);
    }
    if (std.mem.eql(u8, mode, "lookup")) return print(init, try caller.lookup(try c.fuze.model.Name.init(args[4])));
    if (std.mem.eql(u8, mode, "definition")) return print(init, try caller.definition(try std.fmt.parseInt(u64, args[4], 10), try std.fmt.parseInt(u64, args[5], 10)));
    if (std.mem.eql(u8, mode, "prepare-send") or std.mem.eql(u8, mode, "prepare-raw")) {
        if (args.len != 8) return error.Usage;
        const operation = try std.fmt.parseInt(u64, args[4], 10);
        const object = try std.fmt.parseInt(u64, args[5], 10);
        const table = try std.fmt.parseInt(u32, args[6], 10);
        const req = try c.Model.CreateTable.compile(owner(config).configuration.scope, operation, object, table, args[7]);
        const prepared: c.Client.Prepared = if (std.mem.eql(u8, mode, "prepare-send")) try caller.prepareCreate(req) else .{ .version = 1, .definition = g.current_definition, .connection = caller.connection, .signed = try send(&wire, config, try c.Records.encode('q', req)) };
        try save(init, directory, "prepared.json", prepared);
        try save(init, directory, "send.json", Frozen{ .definition = g.current_definition, .signed = prepared.signed });
        return print(init, .{ .prepared = operation });
    }
    if (std.mem.eql(u8, mode, "submit-send")) return print(init, try caller.submit(try restored(init, directory)));
    if (std.mem.eql(u8, mode, "status")) return print(init, try caller.status(try request(init, directory)));
    if (std.mem.eql(u8, mode, "observe")) return print(init, try caller.observe(try restored(init, directory), try std.fmt.parseInt(u64, args[4], 10)));
    if (std.mem.eql(u8, mode, "input-disposition")) return print(init, try caller.inputDisposition(try restored(init, directory), try std.fmt.parseInt(u64, args[4], 10)));
    if (std.mem.eql(u8, mode, "retry-control")) return print(init, try caller.submit(try restoredFile(init, directory, "control.json")));
    if (std.mem.eql(u8, mode, "control-disposition")) return print(init, try caller.inputDisposition(try restoredFile(init, directory, "control.json"), try std.fmt.parseInt(u64, args[4], 10)));
    if (std.mem.eql(u8, mode, "observe-control")) return print(init, try caller.observe(try restoredFile(init, directory, "control.json"), try std.fmt.parseInt(u64, args[4], 10)));
    if (std.mem.eql(u8, mode, "send-initialize") or std.mem.eql(u8, mode, "send-policy")) {
        const control: c.Model.Command = if (std.mem.eql(u8, mode, "send-initialize")) .{ .initialize = owner(config).configuration } else blk: {
            if (args.len != 7 and args.len != 8) return error.Usage;
            const revision = try std.fmt.parseInt(u64, args[4], 10);
            if (revision == 0) return error.InvalidCatalogPolicy;
            break :blk .{ .set_policy = .{ .expected_revision = revision - 1, .policy = .{ .scope = caller.connection.scope, .principal = if (args.len == 8) try std.fmt.parseInt(u64, args[7], 10) else 1234, .revision = revision, .create = std.mem.eql(u8, args[5], "true"), .inspect = std.mem.eql(u8, args[6], "true") } } };
        };
        const prepared = switch (control) {
            .initialize => |value| try caller.prepareInitialize(value),
            .set_policy => |value| try caller.preparePolicy(value),
            else => unreachable,
        };
        try save(init, directory, "control.json", prepared);
        return print(init, try caller.submit(prepared));
    }
    if (std.mem.eql(u8, mode, "write-host")) {
        try hostConfig(init, args[1], directory, config);
        return print(init, .{ .written = true });
    }
    if (std.mem.eql(u8, mode, "disposition") or std.mem.eql(u8, mode, "initial-snapshot")) {
        const input = try std.fmt.parseInt(u64, args[4], 10);
        const resources: s.client.ResourceReader = .{ .wire = &wire, .realm = 46, .principal = 1234, .key = try key(10) };
        const address = c.Records.key(caller.connection.scope.catalog, 'e', input, 0);
        if (std.mem.eql(u8, mode, "disposition")) {
            const reader = try resources.readBatch(config.writer.resource, null, &.{address});
            return print(init, if (try reader.read(address)) |value| try c.Records.decode(c.Model.Disposition, 'e', value) else @as(?c.Model.Disposition, null));
        }
        const keys = [_]p.Value{ s.GenServer.descriptor_key, c.Records.key(caller.connection.scope.catalog, 'c', 0, 0), c.Records.key(caller.connection.scope.catalog, 'p', 1234, 0), address };
        const reader = try resources.readBatch(config.writer.resource, null, &keys);
        var entries: [4]?g.Entry = undefined;
        for (keys, &entries) |key_address, *slot| slot.* = try reader.entry(key_address);
        return print(init, .{ .resource_revision = reader.view.revision, .entries = entries });
    }
    if (std.mem.eql(u8, mode, "policy")) {
        if (args.len != 7) return error.Usage;
        const policy: c.Model.Policy = .{ .scope = caller.connection.scope, .principal = 1234, .revision = try std.fmt.parseInt(u64, args[4], 10), .create = std.mem.eql(u8, args[5], "true"), .inspect = std.mem.eql(u8, args[6], "true") };
        _ = try wire.submit(try send(&wire, config, try c.Records.encode('p', policy)));
        _ = try (try prepare(init, &wire, config)).submit(&wire);
        return print(init, .{ .changed = true });
    }
    if (std.mem.eql(u8, mode, "prepare-commit")) {
        const pending = try prepare(init, &wire, config);
        try save(init, directory, "commit.json", Frozen{ .definition = g.current_definition, .signed = pending.signed });
        var count: usize = 0;
        for (pending.signed.request.command.turn.mutations) |slot| if (slot != null) {
            count += 1;
        };
        return print(init, .{ .mutations = count, .input = pending.signed.request.command.turn.input });
    }
    if (std.mem.eql(u8, mode, "commit") or std.mem.eql(u8, mode, "changed-retry")) {
        var frozen = try load(Frozen, init, directory, "commit.json");
        if (std.mem.eql(u8, mode, "changed-retry")) {
            frozen.signed.request.command.turn.mutations[0].?.value = try p.Value.init("changed");
            frozen.signed = try g.sign(frozen.signed.request, try key(8));
        }
        return print(init, try wire.submit(frozen.signed));
    }
    if (std.mem.eql(u8, mode, "reown")) {
        _ = try admin.submit(.{ .own = .{ .pid = config.writer.pid, .expected_generation = config.writer.generation, .worker = 65536 } });
        config.writer.generation += 1;
        try save(init, directory, "catalog.json", config);
        return print(init, config);
    }
    if (std.mem.eql(u8, mode, "revoke-writer") or std.mem.eql(u8, mode, "restore-writer") or std.mem.eql(u8, mode, "revoke-reader") or std.mem.eql(u8, mode, "restore-reader")) {
        const reader = std.mem.eql(u8, mode, "revoke-reader") or std.mem.eql(u8, mode, "restore-reader");
        const permissions: u8 = if (std.mem.eql(u8, mode, "revoke-reader")) 0 else if (std.mem.eql(u8, mode, "restore-writer")) p.State.all_permissions else p.State.permission(.inspect) | p.State.permission(.read);
        _ = try admin.submit(.{ .grant_resource = .{ .resource = config.writer.resource, .subject = if (reader) 1234 else 65536, .permissions = permissions } });
        return print(init, .{ .changed = true });
    }
    if (std.mem.eql(u8, mode, "snapshot")) {
        const req = try request(init, directory);
        var resource = try (s.client.ResourceReader{ .wire = &wire, .realm = 46, .principal = 1234, .key = try key(10) }).open(config.writer.resource);
        const keys = [_]p.Value{ s.Table.descriptorKey(req.table), c.Records.key(req.scope.catalog, 'd', req.object, 1), try c.Records.nameKey(req.scope.catalog, req.name), c.Records.key(req.scope.catalog, 'o', 1234, req.operation) };
        var entries: [4]?g.Entry = undefined;
        for (keys, &entries) |address, *slot| slot.* = try resource.entry(address);
        return print(init, .{ .resource_revision = resource.view.revision, .entries = entries });
    }
    if (std.mem.eql(u8, mode, "progress")) {
        const process = (try admin.query(.{ .process = config.writer.pid })).body.process;
        return print(init, .{ .admitted = process.process.admitted, .consumed = process.process.consumed, .pending = if (process.input) |input| input.position else @as(?u64, null) });
    }
    return error.InvalidMode;
}
