//! Account inspection and cancellation use the database's public operations.
const std = @import("std");
const g = @import("transit_sql_service");
const p = g.catalog.protocol;
const native = p.Growth;
const Config = g.OperatorConfiguration;
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

fn number(args: []const []const u8, index: usize) !u64 {
    if (index >= args.len) return error.ExpectedControlArguments;
    return std.fmt.parseInt(u64, args[index], 10);
}
pub fn run(init: std.process.Init, args: []const []const u8, diagnostics: *g.query.wire.observability.telemetry.Runtime) !void {
    if (args.len < 2) return error.ExpectedControlArguments;
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, args[0], init.gpa, .limited(65536));
    defer init.gpa.free(bytes);
    const parsed = try std.json.parseFromSlice(Config, init.gpa, bytes, .{});
    defer parsed.deinit();
    const config = parsed.value;
    if (config.version != 1 or config.definition != native.current_definition) return error.IncompatibleDefinition;
    try config.execution.validate();
    if (config.timeout_ms == 0 or config.timeout_ms > 270000) return error.InvalidGatewayConfiguration;
    var table_key = try g.wire.readKey(init.gpa, init.io, config.table_key_file);
    defer std.crypto.secureZero(u8, std.mem.asBytes(&table_key));
    var wire = g.wire.Client.init(init.gpa, init.io, config.native_url);
    defer wire.deinit();
    wire.timeout_ms = config.timeout_ms;
    errdefer if (wire.last_rejection) |cause| diagnostics.event(.{ .name = "sql.control.rejected", .level = .err, .outcome = .rejected, .error_type = @tagName(cause) });
    var client: g.Client = .{ .transport = &wire, .execution = .{ .configuration = config.execution }, .principal = config.execution.table_principal, .key = table_key };
    const action = args[1];
    var source = try client.source();
    if (std.mem.eql(u8, action, "list") and (args.len == 2 or args.len == 3)) return print(init, try g.SessionOperations.list(client.execution, &source, if (args.len == 3) try number(args, 2) else 0, false));
    if (std.mem.eql(u8, action, "credential") and args.len == 5) {
        const password = try std.Io.Dir.cwd().readFileAlloc(init.io, args[2], init.gpa, .limited(g.Authentication.max_password_bytes));
        defer init.gpa.free(password);
        defer std.crypto.secureZero(u8, password);
        var salt: [16]u8 = undefined;
        try init.io.randomSecure(&salt);
        const native_identity: g.wire.AuthorizationClient = .{ .transport = &wire, .realm = config.execution.realm, .principal = config.execution.table_principal, .key = table_key };
        const identity = (try native_identity.read(.identity)).body.authorization.body.identity;
        var value: g.Configuration.Credential = .{ .version = 1, .definition = native.current_definition, .account = config.execution.account, .revision = try number(args, 4), .principal = identity.principal, .login_role = identity.login_role, .credential_epoch = identity.credential_epoch, .enabled = true, .verifier = try g.Authentication.Verifier.create(password, salt, 65536) };
        defer std.crypto.secureZero(u8, std.mem.asBytes(&value));
        try value.validate(config.execution.account);
        try save(init, args[3], value);
        return print(init, .{ .revision = value.revision });
    }

    if (args.len != 3) return error.ExpectedControlArguments;
    const state = try source.operation(try number(args, 2));
    const caller = source.direct(state);
    if (std.mem.eql(u8, action, "cancel")) {
        return print(init, try g.catalog.DirectClientToken.update(caller, .{ .key = state.receipt.binding.key, .expected = state.revision, .pending = state.pending, .cancel = true, .record = state.record }));
    }
    if (!std.mem.eql(u8, action, "status")) return error.ExpectedControlArguments;
    const reference = state.receipt.binding.intent;
    if (reference == .external) return print(init, try g.SessionOperations.external(client.execution, &source, state.id()));
    const response = try reference.operation(caller, .inspect, 1);
    defer response.deinit();
    return print(init, .{ .operation = state, .terminal = try g.Terminal.fromReference(reference, response.value.result) });
}
