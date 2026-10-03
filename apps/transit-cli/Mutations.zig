//! Thin explicit CLI over the shared definition-bound Table mutation caller.
const std = @import("std");
const q = @import("transit_query");
const B = q.TableMutationBridge;
const Options = @import("MutationOptions.zig");
const Diagnostic = @import("Diagnostic.zig");
const Config = struct { version: u8, url: []const u8, seed_file: []const u8, connection: q.TableMutationClient.Connection, request_timeout_ms: u32 = 5000 };
const CompiledFile = struct { compiled: B.Compiled };
const PreparedFile = struct { prepared: ?[]const u8 };
pub const help =
    \\Compile, prepare, submit and observe bounded SQL Table mutations.
    \\
    \\Usage: transit mutate COMMAND [OPTIONS]
    \\
    \\Commands:
    \\  capabilities  Read local compiler limits without credentials or network
    \\  describe      Read current authorized Table and mutation policy
    \\  compile       Compile SQL into a new private request artifact
    \\  next          Prepare the next upload stage into a new private artifact
    \\  prepare       Prepare an explicit apply or cancel control
    \\  submit        Submit the exact command in a saved prepared artifact
    \\  observe       Observe processing of an admitted command
    \\  rejection     Read its separate input rejection, if any
    \\  status        Read durable application status by complete request identity
    \\
    \\Only submit sends a command; retry the same file after an unknown outcome.
    \\Run transit mutate COMMAND --help for required options.
    \\
;
pub fn run(init: std.process.Init, args: []const []const u8, diagnostic: *Diagnostic) !void {
    if (args.len == 0 or (args.len == 1 and std.mem.eql(u8, args[0], "--help"))) return std.Io.File.stdout().writeStreamingAll(init.io, help);
    const options = try Options.parse(args, diagnostic);
    if (options.help) return Options.help(init.io, options.mode);
    if (options.mode == .capabilities) return output(init, .{ .capabilities = .{} });
    const alloc = init.arena.allocator();
    const flags = options.flags;
    diagnostic.atFile(flags.config.?);
    const absolute = std.Io.Dir.cwd().realPathFileAlloc(init.io, flags.config.?, alloc) catch |err| {
        diagnostic.configurationFailure(err);
        return error.InvalidConfigurationPath;
    };
    var config = try @import("Settings.zig").readTyped(Config, init, absolute, diagnostic);
    if (config.version != 1) return diagnostic.invalidField("version", "must be 1", null);
    config.connection.validate() catch return diagnostic.invalidField("connection", "requires positive native identities and a positive Table ID", null);
    if (config.request_timeout_ms == 0 or config.request_timeout_ms > 60000) return diagnostic.invalidField("request_timeout_ms", "must be between 1 and 60000", null);
    if (config.url.len == 0 or config.url.len > 2048) return diagnostic.invalidField("url", "requires an HTTP or HTTPS authority URL", null);
    const uri = std.Uri.parse(config.url) catch return diagnostic.invalidField("url", "requires an HTTP or HTTPS authority URL", null);
    if (!(std.mem.eql(u8, uri.scheme, "http") or std.mem.eql(u8, uri.scheme, "https")) or uri.host == null or uri.user != null or uri.password != null or uri.query != null or uri.fragment != null) return diagnostic.invalidField("url", "requires an HTTP or HTTPS authority URL without embedded credentials, query or fragment", null);
    config.seed_file = try std.fs.path.resolve(alloc, &.{ std.fs.path.dirname(absolute).?, config.seed_file });
    // Read and validate local artifacts before loading keys or contacting authority.
    const action = actionFromFile(init, options, diagnostic) catch |err| {
        if (diagnostic.presentation == .general) diagnostic.envelope = q.MutationDiagnostic.artifact(@tagName(options.mode), err) catch null;
        return err;
    };
    diagnostic.atFile(absolute);
    diagnostic.field = "seed_file";
    var key = q.wire.readKey(init.gpa, init.io, config.seed_file) catch |err| {
        diagnostic.setFailure(err, "cannot load the mutation signing credential", "Check seed_file relative to the configuration file and its permissions; do not print or paste the seed.");
        return error.InvalidCredentialFile;
    };
    defer std.crypto.secureZero(u8, std.mem.asBytes(&key));
    diagnostic.field = null;
    var wire = q.wire.Client.init(init.gpa, init.io, config.url);
    defer wire.deinit();
    wire.timeout_ms = config.request_timeout_ms;
    var client: q.TableMutationClient = .{ .wire = &wire, .connection = config.connection, .key = key };
    defer std.crypto.secureZero(u8, std.mem.asBytes(&client.key));
    const submitting = action == .submit;
    var identity: ?q.protocol.Diagnostic.Identity = null;
    if (submitting) {
        const prepared = try B.prepared(alloc, action.submit);
        client.validate(prepared) catch |err| {
            diagnostic.envelope = q.MutationDiagnostic.attempt(action, err, .{}, false, null) catch null;
            return err;
        };
        identity = .{ .domain = .transport, .id = .init(prepared.signed.request.sequence), .sequence = .init(prepared.signed.request.sequence), .realm = .init(prepared.signed.request.realm) };
    }
    var binding: q.fuze.Sql.Binding = .{};
    const result = B.applyDiagnostic(alloc, &client, action, &binding) catch |err| {
        const failure = if (submitting and err != error.AccessDenied and err != error.Rejected and err != error.Conflict) uncertain(diagnostic, err) else err;
        diagnostic.envelope = q.MutationDiagnostic.attempt(action, err, binding, submitting, identity) catch null;
        q.MutationDiagnostic.qualify(&diagnostic.envelope, client.connection, wire.last_rejection);
        if (action == .compile and diagnostic.envelope != null) if (diagnostic.envelope.?.location) |*location| (q.protocol.Diagnostic.SourcePath.init(options.flags.file.?) catch return failure).apply(location);
        return failure;
    };
    if (flags.output) |path| {
        // Preparation admits no native command. The artifact must be durable
        // before the caller can explicitly submit it in a later invocation.
        diagnostic.atFile(path);
        try createArtifact(init, path, result);
    }
    output(init, result) catch |err| {
        if (submitting) {
            const failure = uncertain(diagnostic, err);
            var detail = try q.protocol.Diagnostic.init("mutation.receipt_output_incomplete", .unavailable, .output, .pending, .native_receipt, "The native receipt was received but its output could not be written. The receipt proves input admission, not domain application. Reconcile the same saved command.");
            detail.cause = try q.protocol.Diagnostic.Code.init(@errorName(err));
            detail.identity = identity;
            try detail.fact(.native_input, .authority, .{ .unsigned = .init(result.receipt.position) });
            try detail.fact(.completion, .execution, .{ .boolean = false });
            try detail.action(.inspect_status);
            try detail.action(.resume_exact);
            diagnostic.envelope = detail;
            return failure;
        }
        return err;
    };
}
fn uncertain(diagnostic: *Diagnostic, cause: anyerror) anyerror {
    diagnostic.setFailure(cause, "the mutation command's outcome is unknown", "Keep the original prepared file and retry it with the same configuration:\n  transit mutate submit --config PATH --file PREPARED\nDo not prepare a replacement command or advance the upload.");
    return error.MutationOutcomeUnknown;
}
fn actionFromFile(init: std.process.Init, options: Options.Options, diagnostic: *Diagnostic) !B.Action {
    const alloc = init.arena.allocator();
    if (options.mode == .describe) return .describe;
    const path = options.flags.file.?;
    switch (options.mode) {
        .compile => {
            diagnostic.atFile(path);
            const sql = std.Io.Dir.cwd().readFileAlloc(init.io, path, alloc, .limited(4096)) catch |err| {
                diagnostic.configurationFailure(err);
                return error.InvalidConfiguration;
            };
            return .{ .compile = .{ .name = options.flags.name.?, .sql = sql, .namespace = try q.document.JsonValues.decimal(alloc, options.namespace) } };
        },
        .next, .prepare, .status => {
            const compiled = (try diagnostic.readJson(CompiledFile, init, path, 4096)).compiled;
            _ = try compiled.native(alloc);
            return switch (options.mode) {
                .next => .{ .next = compiled },
                .prepare => .{ .prepare = switch (options.control) {
                    .apply => .{ .apply = compiled.reference },
                    .cancel => .{ .cancel = compiled.reference },
                } },
                .status => .{ .status = compiled.reference },
                else => unreachable,
            };
        },
        .submit, .observe, .rejection => {
            const prepared = (try diagnostic.readJson(PreparedFile, init, path, 65536)).prepared orelse return error.NoPreparedMutation;
            _ = try B.prepared(alloc, prepared);
            return switch (options.mode) {
                .submit => .{ .submit = prepared },
                .observe => .{ .observe = .{ .prepared = prepared, .input = options.input } },
                .rejection => .{ .rejection = .{ .prepared = prepared, .input = options.input } },
                else => unreachable,
            };
        },
        else => unreachable,
    }
}
fn output(init: std.process.Init, result: B.Result) !void {
    var buffer: [8192]u8 = undefined;
    var writer = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    try std.json.Stringify.value(result, .{ .escape_unicode = true }, &writer.interface);
    try writer.interface.writeByte('\n');
    try writer.interface.flush();
}
fn createArtifact(init: std.process.Init, path: []const u8, result: B.Result) !void {
    return @import("RecoveryFiles.zig").create(init, path, result) catch |err| switch (err) {
        error.ArtifactTooLarge => error.MutationArtifactTooLarge,
        error.ArtifactSyncFailed => error.MutationArtifactSyncFailed,
        else => err,
    };
}
