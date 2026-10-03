//! Explicit catalog commands over the shared typed bridge and signed caller.
const std = @import("std");
const c = @import("transit_catalog");
const B = c.Bridge;
const p = c.protocol;
const Options = @import("CatalogOptions.zig");
const Diagnostic = @import("Diagnostic.zig");
const Config = struct { version: u8, connection: B.Connection, url: ?[]const u8 = null, seed_file: ?[]const u8 = null, request_timeout_ms: u32 = 5000 };
const CompiledFile = struct { compiled: B.Compiled };
const PreparedFile = struct { prepared: []const u8 };
const PageFile = struct { page: B.Page };
pub const help =
    \\Compile, prepare, submit and inspect explicit catalog operations.
    \\
    \\Usage: transit catalog COMMAND [OPTIONS]
    \\
    \\Commands:
    \\  capabilities        Read local capabilities without configuration or I/O
    \\  describe            Read current authorized configuration and policy
    \\  lookup              Read a named definition under current rights
    \\  definition          Read an exact object and definition revision
    \\  list                Read one page; optionally continue a saved page
    \\  compile             Compile CREATE TABLE into a new private artifact offline
    \\  prepare-initialize  Save an explicit initialization command
    \\  prepare-create      Save creation from a reviewed compiled artifact
    \\  prepare-policy      Save a conditional administrator policy control
    \\  submit              Submit the exact command in a saved artifact
    \\  observe             Observe processing of that admitted command
    \\  disposition         Read its control or rejected-input outcome
    \\  status              Read the original Table creation outcome
    \\
    \\Only submit sends a command; retry the same file after an unknown outcome.
    \\Run transit catalog COMMAND --help for required options.
    \\
;
pub fn run(init: std.process.Init, args: []const []const u8, diagnostic: *Diagnostic) !void {
    if (args.len == 0 or (args.len == 1 and std.mem.eql(u8, args[0], "--help"))) return std.Io.File.stdout().writeStreamingAll(init.io, help);
    const options = try Options.parse(args, diagnostic);
    if (options.help) return Options.help(init.io, options.mode);
    if (options.mode == .capabilities) return output(init, .{ .capabilities = .{} });
    const alloc = init.arena.allocator();
    diagnostic.atFile(options.flags.config.?);
    const absolute = std.Io.Dir.cwd().realPathFileAlloc(init.io, options.flags.config.?, alloc) catch |err| {
        diagnostic.configurationFailure(err);
        return error.InvalidConfigurationPath;
    };
    const tree = try @import("Settings.zig").read(init, absolute, diagnostic);
    const bytes = try std.json.Stringify.valueAlloc(alloc, tree, .{});
    const parsed = p.Json.parseFromSlice(Config, alloc, bytes) catch |err| return diagnostic.invalidFieldCause(err, "configuration", "contains an invalid or missing field", null);
    defer parsed.deinit();
    const config = parsed.value;
    if (config.version != 1) return diagnostic.invalidField("version", "must be 1", null);
    const connection = config.connection.native() catch return diagnostic.invalidField("connection", "requires bounded native identities and a canonical positive catalog ID string", null);
    if (config.request_timeout_ms == 0 or config.request_timeout_ms > 60000) return diagnostic.invalidField("request_timeout_ms", "must be between 1 and 60000", null);
    if (config.url) |url| {
        if (url.len == 0 or url.len > 2048) return diagnostic.invalidField("url", "requires an HTTP or HTTPS authority URL", null);
        const uri = std.Uri.parse(url) catch return diagnostic.invalidField("url", "requires an HTTP or HTTPS authority URL", null);
        if (!(std.mem.eql(u8, uri.scheme, "http") or std.mem.eql(u8, uri.scheme, "https")) or uri.host == null or uri.user != null or uri.password != null or uri.query != null or uri.fragment != null) return diagnostic.invalidField("url", "requires an HTTP or HTTPS authority URL without embedded credentials, query or fragment", null);
    }
    // Malformed local artifacts reject before credential loading or network I/O.
    const action = actionFromInput(init, options, diagnostic) catch |err| {
        if (diagnostic.presentation == .general) diagnostic.envelope = c.Diagnostic.artifact(@tagName(options.mode), err) catch null;
        return err;
    };
    if (options.mode == .compile) {
        var binding: c.fuze.Sql.Binding = .{};
        const compiled = B.compileDiagnostic(alloc, connection, action.compile, &binding) catch |err| {
            diagnostic.envelope = c.Diagnostic.attempt(action, err, binding, false, null) catch null;
            if (diagnostic.envelope) |*detail| if (detail.location) |*location| (p.Diagnostic.SourcePath.init(options.flags.file.?) catch return err).apply(location);
            return err;
        };
        return publish(init, options, diagnostic, .{ .compiled = compiled });
    }
    diagnostic.atFile(absolute);
    const url = config.url orelse return diagnostic.invalidField("url", "is required for remote catalog operations", null);
    const seed_file = config.seed_file orelse return diagnostic.invalidField("seed_file", "is required for remote catalog operations", null);
    if (seed_file.len == 0) return diagnostic.invalidField("seed_file", "requires a credential file path", null);
    const seed_path = try std.fs.path.resolve(alloc, &.{ std.fs.path.dirname(absolute).?, seed_file });
    diagnostic.field = "seed_file";
    var key = c.station.client.readKey(init.gpa, init.io, seed_path) catch |err| {
        diagnostic.setFailure(err, "cannot load the catalog signing credential", "Check seed_file relative to the configuration file and its permissions; do not print or paste the seed.");
        return error.InvalidCredentialFile;
    };
    defer std.crypto.secureZero(u8, std.mem.asBytes(&key));
    diagnostic.field = null;
    var transport = c.station.client.Client.init(init.gpa, init.io, url);
    defer transport.deinit();
    transport.timeout_ms = config.request_timeout_ms;
    var client: c.Client = .{ .transport = &transport, .connection = connection, .key = key };
    defer std.crypto.secureZero(u8, std.mem.asBytes(&client.key));
    const submitting = action == .submit;
    var identity: ?p.Diagnostic.Identity = null;
    if (submitting) {
        const prepared = try B.prepared(alloc, action.submit);
        client.validate(prepared) catch |err| {
            diagnostic.envelope = c.Diagnostic.attempt(action, err, .{}, false, null) catch null;
            return err;
        };
        identity = .{ .domain = .transport, .id = .init(prepared.signed.request.sequence), .sequence = .init(prepared.signed.request.sequence), .realm = .init(prepared.signed.request.realm) };
    }
    var binding: c.fuze.Sql.Binding = .{};
    const result = B.applyDiagnostic(alloc, &client, action, &binding) catch |err| {
        const failure = if (submitting and err != error.AccessDenied and err != error.Rejected and err != error.Conflict) uncertain(diagnostic, err) else err;
        diagnostic.envelope = c.Diagnostic.attempt(action, err, binding, submitting, identity) catch null;
        c.Diagnostic.qualify(&diagnostic.envelope, client.connection, transport.last_rejection);
        if (action == .compile and diagnostic.envelope != null) if (diagnostic.envelope.?.location) |*location| (p.Diagnostic.SourcePath.init(options.flags.file.?) catch return failure).apply(location);
        return failure;
    };
    publish(init, options, diagnostic, result) catch |err| {
        if (submitting) {
            const failure = uncertain(diagnostic, err);
            var detail = try p.Diagnostic.init("catalog.receipt_output_incomplete", .unavailable, .output, .pending, .native_receipt, "The native receipt was received but its output could not be written. The receipt proves input admission, not domain application. Reconcile the same saved command.");
            detail.cause = try p.Diagnostic.Code.init(@errorName(err));
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
    diagnostic.setFailure(cause, "the catalog command's outcome is unknown", "Keep the original prepared file and retry it with the same configuration:\n  transit catalog submit --config PATH --file PREPARED\nDo not prepare a replacement command or infer application from a missing response.");
    return error.CatalogOutcomeUnknown;
}
fn artifact(comptime T: type, init: std.process.Init, path: []const u8, limit: usize, diagnostic: *Diagnostic) !T {
    const alloc = init.arena.allocator();
    const tree = try diagnostic.readJson(std.json.Value, init, path, limit);
    const bytes = try std.json.Stringify.valueAlloc(alloc, tree, .{});
    const checked = p.Json.parseFromSlice(T, alloc, bytes) catch |err| return diagnostic.invalidFieldCause(err, "artifact", "contains an invalid or missing field", null);
    defer checked.deinit();
    // All returned strings, including escaped paths/commands, own invocation-arena memory.
    return std.json.parseFromSliceLeaky(T, alloc, bytes, .{ .allocate = .alloc_always });
}
fn actionFromInput(init: std.process.Init, options: Options.Options, diagnostic: *Diagnostic) !B.Action {
    const alloc = init.arena.allocator();
    if (options.mode == .describe) return .describe;
    if (options.mode == .lookup) return .{ .lookup = options.flags.name.? };
    if (options.mode == .definition) return .{ .definition = .{ .object = options.flags.object.?, .revision = options.flags.revision.? } };
    if (options.mode == .list) {
        const path = options.flags.file orelse return .{ .list = null };
        const previous = try artifact(PageFile, init, path, 8192, diagnostic);
        _ = try previous.page.native();
        const cursor = previous.page.next orelse return diagnostic.invalidField("page.next", "the saved page has no continuation", null);
        _ = try cursor.native();
        return .{ .list = cursor };
    }
    const path = options.flags.file.?;
    switch (options.mode) {
        .compile => {
            diagnostic.atFile(path);
            const sql = std.Io.Dir.cwd().readFileAlloc(init.io, path, alloc, .limited(4096)) catch |err| {
                diagnostic.configurationFailure(err);
                return error.InvalidConfiguration;
            };
            return .{ .compile = .{ .operation = options.flags.operation.?, .object = options.flags.object.?, .table = options.table, .sql = sql } };
        },
        .@"prepare-create", .status => {
            const compiled = (try artifact(CompiledFile, init, path, 4096, diagnostic)).compiled;
            const request = try compiled.request.native();
            const canonical = try c.Records.decode(c.Model.CreateTable, 'q', compiled.canonical);
            if (!std.meta.eql(request, canonical)) return error.CatalogArtifactMismatch;
            return if (options.mode == .status) .{ .status = compiled.request } else .{ .prepare_create = compiled.request };
        },
        .@"prepare-initialize" => {
            const configuration = try artifact(B.Configuration, init, path, 4096, diagnostic);
            _ = try configuration.native();
            return .{ .prepare_initialize = configuration };
        },
        .@"prepare-policy" => {
            const change = try artifact(B.PolicyChange, init, path, 4096, diagnostic);
            _ = try change.native();
            return .{ .prepare_policy = change };
        },
        .submit, .observe, .disposition => {
            const prepared = (try artifact(PreparedFile, init, path, 65536, diagnostic)).prepared;
            _ = try B.prepared(alloc, prepared);
            return switch (options.mode) {
                .submit => .{ .submit = prepared },
                .observe => .{ .observe = .{ .prepared = prepared, .input = options.input } },
                .disposition => .{ .input_disposition = .{ .prepared = prepared, .input = options.input } },
                else => unreachable,
            };
        },
        else => unreachable,
    }
}
fn publish(init: std.process.Init, options: Options.Options, diagnostic: *Diagnostic, result: B.Result) !void {
    if (options.flags.output) |path| {
        diagnostic.atFile(path);
        @import("RecoveryFiles.zig").create(init, path, result) catch |err| return switch (err) {
            error.ArtifactTooLarge => error.CatalogArtifactTooLarge,
            error.ArtifactSyncFailed => error.CatalogArtifactSyncFailed,
            else => err,
        };
    }
    try output(init, result);
}
fn output(init: std.process.Init, result: B.Result) !void {
    var buffer: [8192]u8 = undefined;
    var writer = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    try std.json.Stringify.value(result, .{ .escape_unicode = true }, &writer.interface);
    try writer.interface.writeByte('\n');
    try writer.interface.flush();
}
