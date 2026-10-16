//! Private operator CLI over the same signed native controls as the runtime.
//! Inspection never submits. One locked recovery file owns the control sequence.
const std = @import("std");
const g = @import("transit_sql_gateway");
const p = g.catalog.protocol;
const native = p.Growth;
const Config = struct {
    version: u8,
    definition: native.Definition,
    native_url: []const u8,
    ledger: g.Ledger.Configuration,
    control_key_file: []const u8,
    table_key_file: []const u8,
    reader_key_file: []const u8,
    pending_file: []const u8,
    timeout_ms: u32 = 30000,
};
const Pending = struct { prepared: g.Client.Prepared, receipt: ?p.Receipt = null, processed: bool = false, disposition: ?g.Control.Disposition = null };
fn print(init: std.process.Init, value: anytype) !void {
    const bytes = try std.json.Stringify.valueAlloc(init.gpa, value, .{});
    defer init.gpa.free(bytes);
    try std.Io.File.stdout().writeStreamingAll(init.io, bytes);
    try std.Io.File.stdout().writeStreamingAll(init.io, "\n");
}
fn save(init: std.process.Init, path: []const u8, value: anytype) !void {
    const bytes = try std.json.Stringify.valueAlloc(init.gpa, value, .{});
    defer init.gpa.free(bytes);
    defer std.crypto.secureZero(u8, bytes);
    const parent = try std.Io.Dir.cwd().openDir(init.io, std.fs.path.dirname(path) orelse ".", .{ .iterate = true });
    defer parent.close(init.io);
    var file = try parent.createFileAtomic(init.io, std.fs.path.basename(path), .{ .replace = true, .permissions = .fromMode(0o600) });
    defer file.deinit(init.io);
    try file.file.writeStreamingAll(init.io, bytes);
    try file.file.sync(init.io);
    try file.replace(init.io);
    if (std.c.fsync(parent.handle) != 0) return error.GatewayControlSyncFailed;
}
fn loadPending(init: std.process.Init, config: Config, client: *g.Client) !?Pending {
    const bytes = std.Io.Dir.cwd().readFileAlloc(init.io, config.pending_file, init.gpa, .limited(8192)) catch |err| {
        if (err == error.FileNotFound) return null;
        return err;
    };
    defer init.gpa.free(bytes);
    const parsed = try std.json.parseFromSlice(Pending, init.gpa, bytes, .{});
    defer parsed.deinit();
    try client.validate(parsed.value.prepared);
    if ((parsed.value.processed and parsed.value.receipt == null) or (!parsed.value.processed and parsed.value.disposition != null)) return error.InvalidGatewayPrepared;
    return parsed.value;
}
fn number(args: []const []const u8, index: usize) !u64 {
    if (index >= args.len) return error.ExpectedControlArguments;
    return std.fmt.parseInt(u64, args[index], 10);
}
fn command(args: []const []const u8, table_wire: *g.station.client.Client, config: Config, table_key: p.Ed25519.KeyPair) !g.Control.Command {
    if (args.len == 1 and std.mem.eql(u8, args[0], "initialize")) {
        const caller: g.station.client.AuthorizationClient = .{ .transport = table_wire, .realm = config.ledger.realm, .principal = config.ledger.table_principal, .key = table_key };
        const response = try caller.read(.identity);
        return .{ .initialize = response.principal_sequence };
    }
    if (args.len == 2 and std.mem.eql(u8, args[0], "reconcile")) return .{ .reconcile = try number(args, 1) };
    if (args.len == 2 and std.mem.eql(u8, args[0], "cancel")) return .{ .cancel = try number(args, 1) };
    if (args.len == 3 and std.mem.eql(u8, args[0], "reserve")) return .{ .reserve = .{ .operation = try number(args, 1), .bytes = try number(args, 2) } };
    if (args.len == 4 and std.mem.eql(u8, args[0], "capacity")) {
        const pending = try number(args, 3);
        if (pending > 1024) return error.InvalidGatewayLimits;
        return .{ .capacity = .{ .operations = try number(args, 1), .bytes = try number(args, 2), .pending = @intCast(pending) } };
    }
    return error.ExpectedControlArguments;
}
const Entry = struct {
    operation: u64,
    resource: u64,
    catalog: u64,
    phase: g.LedgerRecords.Phase,
    pending_sequence: u64,
    input: u64,
    blocked: bool,
    cancellation_requested: bool,
    fn from(item: g.LedgerRecords.Operation) Entry {
        return .{ .operation = item.id, .resource = item.resource, .catalog = item.catalog, .phase = item.phase, .pending_sequence = item.pending_sequence, .input = item.input, .blocked = item.blocked != 0, .cancellation_requested = item.cancel != 0 };
    }
};
fn terminal(init: std.process.Init, client: *g.Client, source: anytype, item: g.LedgerRecords.Operation, key: p.Ed25519.KeyPair, reader_key: p.Ed25519.KeyPair) !?g.Terminal {
    if (item.phase != .terminal) return null;
    const ledger = client.ledger;
    var cached = try client.cachedSource(source.view.revision);
    const bytes = try g.Upload.read(init.gpa, ledger.publication(item.id), &cached, 1, ledger.configuration.intent_bytes);
    defer init.gpa.free(bytes);
    defer std.crypto.secureZero(u8, bytes);
    var intent = try g.catalog.TableIntent.restore(init.gpa, bytes);
    defer intent.deinit();
    defer std.crypto.secureZero(u8, intent.bytes);
    var table: g.catalog.TableClient = .{ .transport = client.transport, .connection = .{ .scope = .{ .realm = ledger.configuration.realm, .resource = item.resource, .catalog = item.catalog }, .owner = item.owner, .principal = ledger.configuration.table_principal, .namespace = item.namespace, .role = item.selectedRole() }, .key = key, .reader = .{ .wire = client.transport, .realm = ledger.configuration.realm, .principal = ledger.configuration.reader, .key = reader_key } };
    const observation = try table.inspectIntent(&intent);
    const actual = if (observation.outcome) |outcome| try g.Terminal.fromOutcome(outcome) else if (observation.upload) |upload| try g.Terminal.fromUpload(upload) else return error.GatewayOperationNotTerminal;
    const saved = try g.LedgerRecords.decode(g.Terminal, (try source.read(g.LedgerRecords.key('t', item.id, 0))) orelse return error.InvalidGatewayTerminal);
    if (!std.meta.eql(saved, actual)) return error.GatewayIdentityConflict;
    return actual;
}
fn list(client: *g.Client, cursor: ?g.Ledger.Cursor) !g.Ledger.Page {
    var source = try client.source();
    return client.ledger.list(&source, cursor);
}
const Status = struct { operation: Entry, terminal: ?g.Terminal };
fn status(init: std.process.Init, client: *g.Client, id: u64, key: p.Ed25519.KeyPair, reader_key: p.Ed25519.KeyPair) !Status {
    var source = try client.source();
    const item = try client.ledger.operation(&source, id);
    return .{ .operation = Entry.from(item), .terminal = try terminal(init, client, &source, item, key, reader_key) };
}
// A concurrent ledger turn can invalidate a current-revision metadata read.
// Retry only the observation before printing any output. Caller-supplied page
// cursors still reject foreign accounts or backward revisions; controls and
// signatures never retry through this path.
fn fresh(init: std.process.Init, client: *g.Client, timeout_ms: u32, comptime function: anytype, arguments: std.meta.ArgsTuple(@TypeOf(function))) !@typeInfo(@typeInfo(@TypeOf(function)).@"fn".return_type.?).error_union.payload {
    const deadline: g.AccountRuntime.Deadline = .{ .start = std.Io.Clock.awake.now(init.io), .milliseconds = timeout_ms };
    while (true) {
        try deadline.check(init.io);
        return @call(.auto, function, arguments) catch |err| {
            if ((err != error.Rejected and err != error.Conflict) or client.transport.last_rejection != .StaleStateResource) return err;
            try init.io.sleep(.fromMilliseconds(5), .awake);
            continue;
        };
    }
}
pub fn run(init: std.process.Init, args: []const []const u8) !void {
    if (args.len < 2) return error.ExpectedControlArguments;
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, args[0], init.gpa, .limited(65536));
    defer init.gpa.free(bytes);
    const parsed = try std.json.parseFromSlice(Config, init.gpa, bytes, .{});
    defer parsed.deinit();
    const config = parsed.value;
    if (config.version != 1 or config.definition != native.current_definition) return error.IncompatibleDefinition;
    try config.ledger.validate();
    if (config.timeout_ms == 0 or config.timeout_ms > 270000 or config.pending_file.len == 0) return error.InvalidGatewayConfiguration;
    var control_key = try g.query.wire.readKey(init.gpa, init.io, config.control_key_file);
    defer std.crypto.secureZero(u8, std.mem.asBytes(&control_key));
    var table_key = try g.query.wire.readKey(init.gpa, init.io, config.table_key_file);
    defer std.crypto.secureZero(u8, std.mem.asBytes(&table_key));
    var reader_key = try g.query.wire.readKey(init.gpa, init.io, config.reader_key_file);
    defer std.crypto.secureZero(u8, std.mem.asBytes(&reader_key));
    var wire = g.station.client.Client.init(init.gpa, init.io, config.native_url);
    defer wire.deinit();
    errdefer if (wire.last_rejection) |cause| std.debug.print("Native rejection: {s}\n", .{@tagName(cause)});
    var client: g.Client = .{ .transport = &wire, .ledger = .{ .configuration = config.ledger }, .principal = config.ledger.control, .key = control_key };
    const action = args[1];
    if (std.mem.eql(u8, action, "list") and (args.len == 2 or args.len == 3)) {
        var cursor: ?g.Ledger.Cursor = null;
        if (args.len == 3) {
            const encoded = try std.Io.Dir.cwd().readFileAlloc(init.io, args[2], init.gpa, .limited(4096));
            defer init.gpa.free(encoded);
            const value = try std.json.parseFromSlice(g.Ledger.Cursor, init.gpa, encoded, .{});
            defer value.deinit();
            cursor = value.value;
        }
        const page = try fresh(init, &client, config.timeout_ms, list, .{ &client, cursor });
        var entries: [native.page_size]Entry = undefined;
        var count: usize = 0;
        for (page.entries) |slot| if (slot) |item| {
            entries[count] = .from(item);
            count += 1;
        };
        return print(init, .{ .entries = entries[0..count], .next = page.next, .revision = page.revision });
    }
    if (std.mem.eql(u8, action, "status") and args.len == 3) {
        return print(init, try fresh(init, &client, config.timeout_ms, status, .{ init, &client, try number(args, 2), table_key, reader_key }));
    }
    if (std.mem.eql(u8, action, "credential") and args.len == 5) {
        const password = try std.Io.Dir.cwd().readFileAlloc(init.io, args[2], init.gpa, .limited(g.Authentication.max_password_bytes));
        defer init.gpa.free(password);
        defer std.crypto.secureZero(u8, password);
        var salt: [16]u8 = undefined;
        try init.io.randomSecure(&salt);
        const native_identity: g.station.client.AuthorizationClient = .{ .transport = &wire, .realm = config.ledger.realm, .principal = config.ledger.table_principal, .key = table_key };
        const identity = (try native_identity.read(.identity)).body.authorization.body.identity;
        var value: g.Configuration.Credential = .{ .version = 1, .definition = native.current_definition, .account = config.ledger.account, .revision = try number(args, 4), .principal = identity.principal, .login_role = identity.login_role, .credential_epoch = identity.credential_epoch, .enabled = true, .verifier = try g.Authentication.Verifier.create(password, salt, 65536) };
        defer std.crypto.secureZero(u8, std.mem.asBytes(&value));
        try value.validate(config.ledger.account);
        try save(init, args[3], value);
        return print(init, .{ .revision = value.revision });
    }
    const lock_path = try std.fmt.allocPrint(init.gpa, "{s}.lock", .{config.pending_file});
    defer init.gpa.free(lock_path);
    const lock = try std.Io.Dir.cwd().createFile(init.io, lock_path, .{ .truncate = false, .permissions = .fromMode(0o600) });
    defer lock.close(init.io);
    if (!try lock.tryLock(init.io, .exclusive)) return error.GatewayControlInUse;
    var pending = try loadPending(init, config, &client);
    if (std.mem.eql(u8, action, "prepare") and args.len > 2) {
        if (pending) |value| if (!value.processed) return error.GatewayControlPending;
        const prepared = try client.prepare(try command(args[2..], &wire, config, table_key));
        try save(init, config.pending_file, Pending{ .prepared = prepared });
        return print(init, .{ .state = "prepared", .sequence = prepared.signed.request.sequence });
    }
    if (args.len != 2 or (!std.mem.eql(u8, action, "submit") and !std.mem.eql(u8, action, "pending"))) return error.ExpectedControlArguments;
    const value = if (pending) |*present| present else return error.GatewayControlNotFound;
    if (std.mem.eql(u8, action, "pending")) return print(init, .{ .sequence = value.prepared.signed.request.sequence, .receipt = value.receipt, .processed = value.processed, .disposition = value.disposition });
    if (!value.processed) {
        // A lost receipt leaves the exact signed request in the synced file.
        if (value.receipt == null) {
            value.receipt = try client.submit(value.prepared);
            try save(init, config.pending_file, value.*);
        }
        const started = std.Io.Clock.awake.now(init.io);
        while (true) {
            switch (try client.progress(value.prepared, value.receipt.?)) {
                .pending => {},
                .processed => |disposition| {
                    value.processed = true;
                    value.disposition = disposition;
                    try save(init, config.pending_file, value.*);
                    break;
                },
            }
            if (started.durationTo(std.Io.Clock.awake.now(init.io)).toMilliseconds() >= config.timeout_ms) return error.GatewayDeadline;
            try init.io.sleep(.fromMilliseconds(10), .awake);
        }
    }
    return print(init, .{ .sequence = value.prepared.signed.request.sequence, .receipt = value.receipt, .processed = value.processed, .disposition = value.disposition });
}
