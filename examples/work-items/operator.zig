//! Application-owned commands and verification using exported public connections.
const std = @import("std");
const W = @import("work_items");
const s = W.app.station;
const p = W.app.protocol;
const g = p.Growth;
const A = s.client.Application;
const M = W.app.Migration;
const Saved = struct { version: u32 = 1, definition: g.Definition, realm: u64, principal: u64, pid: u64, resource: u64, intent: []const u8, signed: g.SignedRequest, receipt: ?u64 = null };
fn write(init: std.process.Init, path: []const u8, value: anytype) !void {
    const directory = try std.Io.Dir.cwd().openDir(init.io, std.fs.path.dirname(path) orelse ".", .{ .iterate = true });
    defer directory.close(init.io);
    var file = try directory.createFileAtomic(init.io, std.fs.path.basename(path), .{ .replace = true, .permissions = .fromMode(0o600) });
    defer file.deinit(init.io);
    const bytes = try std.json.Stringify.valueAlloc(init.arena.allocator(), value, .{});
    if (bytes.len > 16384) return error.RecoveryFileTooLarge;
    try file.file.writeStreamingAll(init.io, bytes);
    try file.file.sync(init.io);
    try file.replace(init.io);
    if (std.c.fsync(directory.handle) != 0) return error.RecoverySyncFailed;
}
fn read(comptime T: type, init: std.process.Init, path: []const u8) !T {
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.arena.allocator(), .limited(16384));
    return (try p.Json.parseFromSlice(T, init.arena.allocator(), bytes)).value;
}
fn print(init: std.process.Init, value: anytype) !void {
    var buffer: [8192]u8 = undefined;
    var writer = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    var encoder: std.json.Stringify = .{ .writer = &writer.interface };
    try p.Json.write(value, &encoder);
    try writer.interface.writeByte('\n');
    try writer.interface.flush();
}
pub fn main(init: std.process.Init) void {
    run(init) catch |err| {
        if (err != error.DomainRejected) std.debug.print("error: {s}\n", .{@errorName(err)});
        std.process.exit(1);
    };
}
fn run(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len == 8 and std.mem.eql(u8, args[1], "provision-authority")) {
        const profile = try @import("CatalogSetup.zig").run(init, args[2..7]);
        try write(init, args[7], profile);
        return print(init, .{ .authority = profile, .complete = true });
    }
    if (args.len == 3 and std.mem.eql(u8, args[1], "manifest")) {
        const declaration: A.Declaration = .{ .application = "work-items", .roles = &.{.{ .name = "data", .contract = "work-items-v1", .artifact = .{ .path = args[2] }, .configuration = "{\"application\":9}", .accesses = &.{.{ .name = "state", .resource = "data", .permissions = 7 }} }}, .resources = &.{.{ .name = "data", .writer = "data" }}, .callers = &.{ .{ .name = "operator", .send_to = "data", .reads = &.{.{ .resource = "data" }} }, .{ .name = "writer", .send_to = "data", .reads = &.{.{ .resource = "data" }} }, .{ .name = "inspector", .reads = &.{.{ .resource = "data" }} } }, .initialize = &.{.{ .role = "data", .caller = "operator", .value = try (s.Frame{ .kind = .cast, .payload = try W.Command.encode(.initialize) }).encode() }} };
        return print(init, declaration);
    }
    if (args.len < 3) return error.ExpectedConnectionAndCommand;
    const config = try read(A.Connection, init, args[1]);
    try config.validate();
    const pid = try A.binding(config.roles, "data");
    const resource = try A.binding(config.resources, "data");
    const owner: W = .{ .allocator = init.gpa, .configuration = .{ .owner = pid, .application = 9, .realm = config.realm, .administrator = try A.binding(config.callers, "operator"), .writer = try A.binding(config.callers, "writer"), .resource = resource } };
    const ledger = try owner.ledger();
    var key = try s.client.readKey(init.gpa, init.io, config.seed_file);
    defer std.crypto.secureZero(u8, std.mem.asBytes(&key));
    var wire = s.client.Client.init(init.gpa, init.io, config.url);
    defer wire.deinit();
    wire.timeout_ms = 3000;
    const resources: s.client.ResourceReader = .{ .wire = &wire, .realm = config.realm, .principal = config.principal, .key = key };
    const mode = args[2];
    if (std.mem.eql(u8, mode, "inspect")) {
        if (args.len != 3) return error.InvalidInvocation;
        var source = try resources.open(resource);
        var tables = tableClient(resources, pid, resource);
        var reader = (try tables.authorizationContext()).wrap(&source);
        const head = try ledger.head(&reader);
        const plan = try ledger.plan(&reader, .{ .value = 2 });
        const progress = if (plan != null) try ledger.progress(&reader, .{ .value = 2 }) else null;
        const table = try owner.selected(&reader);
        const catalog = try owner.catalog(&reader);
        var cursor: ?W.Table.Identity = null;
        var count: u64 = 0;
        var row_steps: u64 = 0;
        while (true) {
            if (row_steps == 1000) return error.InspectionPageBudget;
            _ = try catalog.authorizeObject(&reader, config.principal, table, .read);
            if (head.epoch.value == 2) _ = try catalog.authorizeObject(&reader, config.principal, 1, .read);
            const row = try W.Table.next(init.gpa, &reader, table, cursor) orelse break;
            if (head.epoch.value == 2) {
                const before = (try W.Table.get(init.gpa, &reader, 1, row.key)) orelse return error.MissingSourceRow;
                if (row.state != (if (before.state == 0) @as(i64, 10) else 20)) return error.IncorrectMigration;
            }
            count += 1;
            row_steps += 1;
            cursor = row.identity;
        }
        _ = try catalog.authorizeObject(&reader, config.principal, table, .read);
        if (head.epoch.value == 2) _ = try catalog.authorizeObject(&reader, config.principal, 1, .read);
        return print(init, .{ .head = head, .migration = progress, .migration_diagnostic = if (progress) |value| try W.app.MigrationDiagnostic.progress(9, config.realm, resource, plan.?, value) else null, .cursor = if (progress) |value| try W.Cursor.decode(value.cursor) else null, .rows = count, .row_steps = row_steps });
    }
    if (args.len < 4) return error.ExpectedRecoveryFile;
    const path = args[3];
    const intent = try std.json.Stringify.valueAlloc(init.arena.allocator(), .{ .mode = mode, .arguments = args[4..] }, .{});
    const lock = try std.Io.Dir.cwd().createFile(init.io, try std.fmt.allocPrint(init.arena.allocator(), "{s}.lock", .{args[1]}), .{ .truncate = false, .permissions = .fromMode(0o600) });
    defer lock.close(init.io);
    if (!try lock.tryLock(init.io, .exclusive)) return error.CallerInUse;
    var saved = read(Saved, init, path) catch |err| value: {
        if (err != error.FileNotFound) return err;
        var command: W.Command = undefined;
        if (std.mem.eql(u8, mode, "initialize-catalog") and args.len == 5) {
            command = .{ .catalog_initialize = try read(W.query.catalog.TableAuthority.Profile, init, args[4]) };
        } else if (std.mem.eql(u8, mode, "prepare-table") and args.len == 5) {
            command = .{ .prepare_table = try std.fmt.parseInt(u32, args[4], 10) };
        } else if (std.mem.eql(u8, mode, "authorize") and args.len == 4) {
            command = .{ .policy = .{ .principal = config.principal, .expected = .{}, .next = .{ .revision = .{ .value = 1 }, .migrate = true } } };
        } else if (std.mem.eql(u8, mode, "put") and args.len == 6) {
            var reader = try resources.open(resource);
            command = .{ .put = .{ .epoch = (try ledger.head(&reader)).epoch, .id = try std.fmt.parseInt(i64, args[4], 10), .state = try std.fmt.parseInt(i64, args[5], 10) } };
        } else if (std.mem.eql(u8, mode, "begin") and args.len == 4) {
            command = .{ .begin = try owner.proposal(2) };
        } else if (std.mem.eql(u8, mode, "step") and args.len == 4) {
            var reader = try resources.open(resource);
            const progress = try ledger.progress(&reader, .{ .value = 2 });
            const cursor = try W.Cursor.decode(progress.cursor);
            command = .{ .step = .{ .plan = .{ .value = 2 }, .ordinal = progress.next, .operation = if (cursor.phase == .ready) 2 else 1, .arguments = progress.cursor } };
        } else if (std.mem.eql(u8, mode, "release") and args.len == 4) {
            var reader = try resources.open(resource);
            const head = try ledger.head(&reader);
            command = .{ .release_writes = .{ .epoch = head.epoch, .contract = head.contract } };
        } else return error.InvalidInvocation;
        const current = try resources.query(.identity);
        // Table creation records the selected ordinary owner role. The private
        // native caller role remains its login identity and must be SET-eligible.
        var role: ?u64 = null;
        if (command == .prepare_table) {
            var source = try resources.open(resource);
            const catalog = try owner.catalog(&source);
            const authority: s.client.AuthorizationClient = .{ .transport = &wire, .realm = config.realm, .principal = config.principal, .key = key };
            role = (try authority.read(.{ .object = W.query.catalog.TableAuthority.reference(catalog.configuration.authority.database) })).body.authorization.body.object.owner;
        }
        const next: Saved = .{ .definition = g.current_definition, .realm = config.realm, .principal = config.principal, .pid = pid, .resource = resource, .intent = intent, .signed = try g.sign(.{ .realm = config.realm, .principal = config.principal, .sequence = current.principal_sequence + 1, .command = .{ .send = .{ .pid = pid, .role = role, .value = try (s.Frame{ .kind = .cast, .payload = try command.encode() }).encode() } } }, key) };
        try write(init, path, next);
        break :value next;
    };
    if (saved.definition != g.current_definition) return error.IncompatibleDefinition;
    if (saved.version != 1 or saved.realm != config.realm or saved.principal != config.principal or saved.pid != pid or saved.resource != resource or !std.mem.eql(u8, saved.intent, intent)) return error.RecoveryIdentityMismatch;
    const authority: s.client.AuthorizationClient = .{ .transport = &wire, .realm = config.realm, .principal = config.principal, .key = key };
    const receipt = (try authority.read(.{ .receipt = saved.signed.request })).body.authorization.body.receipt orelse try wire.submit(saved.signed);
    if (saved.receipt) |position| if (receipt.position != position) return error.RecoveryReceiptMismatch;
    saved.receipt = receipt.position;
    try write(init, path, saved);
    const started = std.Io.Clock.awake.now(init.io);
    while (true) {
        const process = (try resources.query(.{ .process = pid })).body.process;
        if (process.process.failure != null or process.process.lifecycle != .running) return error.WorkerUnavailable;
        if (process.input == null or process.input.?.position > receipt.position) break;
        if (started.durationTo(std.Io.Clock.awake.now(init.io)).toMilliseconds() >= 30000) return error.CompletionUnobserved;
        try init.io.sleep(.fromMilliseconds(50), .awake);
    }
    const command = try W.Command.decode((try s.Frame.decode(saved.signed.request.command.send.value)).payload);
    while (true) {
        if (started.durationTo(std.Io.Clock.awake.now(init.io)).toMilliseconds() >= 30000) return error.CompletionUnobserved;
        if (observe(init, resources, owner, command, receipt.position)) |done| {
            if (done) break;
        } else |err| {
            if (!s.client.Client.unavailable(err) and !((err == error.Rejected or err == error.Conflict) and
                (wire.last_rejection == .StaleStateResource or wire.last_rejection == .QueryExpired))) return err;
        }
        const process = (try resources.query(.{ .process = pid })).body.process;
        if (process.process.failure != null or process.process.lifecycle != .running) return error.WorkerUnavailable;
        try init.io.sleep(.fromMilliseconds(50), .awake);
    }
    try print(init, .{ .accepted = receipt.position, .committed = true });
}
fn observe(init: std.process.Init, resources: s.client.ResourceReader, owner: W, command: W.Command, input: u64) !bool {
    var source = try resources.open(owner.configuration.resource);
    var tables = tableClient(resources, owner.configuration.owner, owner.configuration.resource);
    var reader = (try tables.authorizationContext()).wrap(&source);
    if (try W.Failure.read(owner.configuration, &reader, resources.principal, input)) |failure| {
        std.debug.print("work-items: {s} [{s}] ({s})\n", .{ failure.diagnostic.message.slice(), failure.diagnostic.code.slice(), failure.record.cause.slice() });
        try print(init, .{ .accepted = input, .committed = false, .err = failure.record.cause.slice(), .diagnostic = failure.diagnostic });
        return error.DomainRejected;
    }
    return owner.completed(&reader, command, input);
}
fn tableClient(resources: s.client.ResourceReader, owner: u64, resource: u64) W.query.catalog.TableClient {
    return .{ .transport = resources.wire, .connection = .{ .scope = .{ .realm = resources.realm, .resource = resource, .catalog = 1 }, .owner = owner, .principal = resources.principal }, .key = resources.key };
}
