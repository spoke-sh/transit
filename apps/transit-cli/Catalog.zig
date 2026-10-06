//! Explicit catalog commands over the shared typed bridge and signed caller.
const std = @import("std");
const c = @import("transit_catalog");
const B = c.TableBridge;
const V = c.TableValues;
const p = c.protocol;
const Options = @import("CatalogOptions.zig");
const Diagnostic = @import("Diagnostic.zig");
const Config = struct { version: u8, connection: B.Connection, url: ?[]const u8 = null, seed_file: ?[]const u8 = null, request_timeout_ms: u32 = 5000 };
const CompiledFile = struct { compiled: B.Compiled };
const PreparedFile = struct { prepared: []const u8 };
const PageFile = struct { page: V.Page };
pub const help =
    \\Compile, prepare, submit and inspect general typed Table operations.
    \\
    \\Usage: transit catalog COMMAND [OPTIONS]
    \\
    \\Commands:
    \\  capabilities        Read local capabilities without configuration or I/O
    \\  describe            Read current authorized configuration and policy
    \\  lookup, definition  Read live or exact historical Table metadata
    \\  list                Read one page; optionally continue a saved page
    \\  compile             Bind SQL to a new private saved intent (CREATE is offline)
    \\  prepare             Bind a typed request to a new private saved intent
    \\  next                Save the next signed step, or report running/terminal state
    \\  prepare-initialize  Save an explicit initialization command
    \\  prepare-policy      Save a conditional administrator policy control
    \\  prepare-dependency  Save a conditional dependency registration
    \\  prepare-resume      Save a continuation for the original operation
    \\  cancel, cleanup     Save an operation cancellation or candidate cleanup
    \\  cancel-upload       Save upload cancellation, separate from operation outcome
    \\  collect-upload      Save bounded closed-upload cleanup
    \\  submit              Submit the exact command in a saved artifact
    \\  observe, disposition Observe processing and the separate input disposition
    \\  progress            Observe a saved intent and its exact admitted step
    \\  status              Inspect the original intent's upload and domain outcome
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
    var session: B.Session = .{ .allocator = init.gpa };
    defer session.deinit();
    var client: c.TableClient = .{ .transport = undefined, .connection = connection, .key = undefined };
    // Restore and validate local identity before credentials or network access.
    const action = actionFromInput(init, options, diagnostic, &session, &client) catch |err| {
        if (diagnostic.presentation == .general) diagnostic.envelope = c.TableAttempt.artifact(@tagName(options.mode), err) catch null;
        return err;
    };
    if (offline(action)) {
        var location: c.fuze.Sql.Location = .{};
        const result = session.applyDiagnostic(init.arena, &client, action, &location) catch |err| {
            diagnostic.envelope = c.TableAttempt.attempt(&session, connection, action, err, location, false, null, null) catch null;
            if (diagnostic.envelope) |*detail| if (detail.location) |*where| (p.Diagnostic.SourcePath.init(options.flags.file.?) catch return err).apply(where);
            return err;
        };
        return publish(init, options, diagnostic, result);
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
    client.transport = &transport;
    client.key = key;
    defer std.crypto.secureZero(u8, std.mem.asBytes(&client.key));
    const submitting = action == .submit;
    var identity: ?p.Diagnostic.Identity = null;
    if (submitting) {
        const prepared = try B.prepared(alloc, action.submit);
        client.validate(prepared) catch |err| {
            diagnostic.envelope = c.TableAttempt.attempt(&session, connection, action, err, .{}, false, null, null) catch null;
            return err;
        };
        identity = .{ .domain = .transport, .id = .init(prepared.signed.request.sequence), .sequence = .init(prepared.signed.request.sequence), .realm = .init(prepared.signed.request.realm) };
    }
    var location: c.fuze.Sql.Location = .{};
    var response_arena: std.heap.ArenaAllocator = .init(init.gpa);
    defer response_arena.deinit();
    const result = apply(init.io, &response_arena, &session, &client, action, &location) catch |err| {
        const failure = if (submitting and err != error.AccessDenied and err != error.Rejected and err != error.Conflict) uncertain(diagnostic, err) else err;
        diagnostic.envelope = c.TableAttempt.attempt(&session, connection, action, err, location, submitting, identity, transport.last_rejection) catch null;
        if (action == .compile and diagnostic.envelope != null) if (diagnostic.envelope.?.location) |*where| (p.Diagnostic.SourcePath.init(options.flags.file.?) catch return failure).apply(where);
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
fn apply(io: std.Io, arena: *std.heap.ArenaAllocator, session: *B.Session, client: *c.TableClient, action: B.Action, location: *c.fuze.Sql.Location) !B.Result {
    const deadline = std.Io.Clock.boot.now(io).toMilliseconds() + client.transport.timeout_ms;
    var attempts: u8 = 0;
    while (true) {
        client.transport.last_rejection = null;
        return session.applyDiagnostic(arena, client, action, location) catch |err| {
            // Restart only locally unsubmitted reads whose dependent metadata
            // cut expired. Never retry sends, denial or an incompatible cursor,
            // and never change the saved intent while the owner advances it.
            if (action == .submit or attempts == 8 or (err != error.Rejected and err != error.Conflict) or client.transport.last_rejection != .StaleStateResource or std.Io.Clock.boot.now(io).toMilliseconds() >= deadline) return err;
            attempts += 1;
            _ = arena.reset(.free_all);
            continue;
        };
    }
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
fn offline(action: B.Action) bool {
    if (action == .prepare) return action.prepare.action == .create;
    if (action != .compile) return false;
    var lexer: c.fuze.Sql.Lexer = .{ .text = action.compile.sql };
    const token = lexer.next() catch return true;
    return std.ascii.eqlIgnoreCase(token.text, "CREATE");
}
fn loadIntent(init: std.process.Init, path: []const u8, diagnostic: *Diagnostic, session: *B.Session, client: *c.TableClient) !B.Reference {
    const compiled = (try artifact(CompiledFile, init, path, B.max_input_bytes, diagnostic)).compiled;
    const loaded = (try session.apply(init.arena, client, .{ .load = compiled.saved })).loaded;
    const expected = try std.json.Stringify.valueAlloc(init.arena.allocator(), compiled.intent, .{});
    const actual = try std.json.Stringify.valueAlloc(init.arena.allocator(), loaded, .{});
    if (!std.mem.eql(u8, expected, actual)) return error.CatalogArtifactMismatch;
    return loaded.reference;
}
fn actionFromInput(init: std.process.Init, options: Options.Options, diagnostic: *Diagnostic, session: *B.Session, client: *c.TableClient) !B.Action {
    const alloc = init.arena.allocator();
    if (options.mode == .describe) return .describe;
    if (options.mode == .lookup) return .{ .lookup = options.flags.name.? };
    if (options.mode == .definition) return .{ .definition = .{ .object = options.flags.object.?, .revision = options.flags.revision.? } };
    if (options.mode == .list) {
        const path = options.flags.file orelse return .{ .list = null };
        const previous = try artifact(PageFile, init, path, 65536, diagnostic);
        try validatePage(previous.page);
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
            return .{ .compile = .{ .identity = .{ .operation = options.flags.operation.?, .namespace = options.flags.namespace.? }, .create_object = options.flags.object, .sql = sql } };
        },
        .prepare => {
            const request = try artifact(c.TableTyped.Request, init, path, B.max_input_bytes, diagnostic);
            if (request.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
            _ = try request.identity.native();
            return .{ .prepare = request };
        },
        .next, .status, .@"prepare-resume", .cancel, .cleanup, .@"cancel-upload", .@"collect-upload" => {
            const reference = try loadIntent(init, path, diagnostic, session, client);
            return switch (options.mode) {
                .next => .{ .next = reference },
                .status => .{ .status = reference },
                .@"prepare-resume" => .{ .prepare_resume = reference },
                else => .{ .prepare_control = .{ .intent = reference, .control = switch (options.mode) {
                    .cancel => .cancel_operation,
                    .cleanup => .cleanup_operation,
                    .@"cancel-upload" => .cancel_upload,
                    .@"collect-upload" => .collect_upload,
                    else => unreachable,
                } } },
            };
        },
        .@"prepare-initialize" => {
            const configuration = try artifact(V.Configuration, init, path, 4096, diagnostic);
            _ = try configuration.native();
            return .{ .prepare_initialize = configuration };
        },
        .@"prepare-policy" => {
            const change = try artifact(V.PolicyChange, init, path, 4096, diagnostic);
            _ = try change.native();
            return .{ .prepare_policy = change };
        },
        .@"prepare-dependency" => {
            const change = try artifact(V.DependencyChange, init, path, 4096, diagnostic);
            _ = try change.native();
            return .{ .prepare_dependency = change };
        },
        .submit, .observe, .disposition, .progress => {
            const prepared = (try artifact(PreparedFile, init, path, 65536, diagnostic)).prepared;
            _ = try B.prepared(alloc, prepared);
            return switch (options.mode) {
                .submit => .{ .submit = prepared },
                .observe => .{ .observe = .{ .prepared = prepared, .input = options.input } },
                .disposition => .{ .input_disposition = .{ .prepared = prepared, .input = options.input } },
                .progress => .{ .progress = .{ .intent = try loadIntent(init, options.flags.intent.?, diagnostic, session, client), .prepared = prepared, .input = options.input } },
                else => unreachable,
            };
        },
        else => unreachable,
    }
}
fn validatePage(page: V.Page) !void {
    if (page.resource_revision > p.max_counter) return error.InvalidCatalogPage;
    var previous: u64 = 0;
    var scope: ?c.TableCatalogRecords.Scope = null;
    var ended = false;
    for (page.entries) |slot| {
        const entry = slot orelse {
            ended = true;
            continue;
        };
        const object = try V.unsigned(entry.metadata.object);
        const current = try entry.metadata.scope.native();
        _ = try c.TableMetadata.Name.init(entry.metadata.name);
        if (ended or object <= previous or try V.unsigned(entry.metadata.revision) == 0 or try V.unsigned(entry.metadata.operation) == 0 or try V.unsigned(entry.head.revision) == 0) return error.InvalidCatalogPage;
        _ = try V.unsigned(entry.head.rows);
        _ = try V.unsigned(entry.head.pending);
        _ = try V.digest(entry.metadata.schema_fingerprint);
        try c.Model.nativeId(entry.metadata.principal);
        try c.Model.nativeId(entry.metadata.admitted_input);
        try c.TableCatalogRecords.metadataReference(.{ .id = try V.unsigned(entry.metadata.revision), .spec = entry.metadata.commitment });
        if (scope) |selected| if (!std.meta.eql(selected, current)) return error.InvalidCatalogPage;
        previous = object;
        scope = current;
    }
    if (page.next) |value| {
        const cursor = try value.native();
        if (cursor.resource_revision != page.resource_revision or cursor.after_object < previous) return error.InvalidCatalogPage;
        if (scope) |selected| if (!std.meta.eql(selected, cursor.scope)) return error.InvalidCatalogPage;
    }
}
fn publish(init: std.process.Init, options: Options.Options, diagnostic: *Diagnostic, selected: B.Result) !void {
    const result: B.Result = if (selected == .next and selected.next == .send) .{ .prepared = selected.next.send } else selected;
    if (options.flags.output) |path| {
        diagnostic.atFile(path);
        @import("RecoveryFiles.zig").createBounded(init, path, result, B.max_input_bytes) catch |err| return switch (err) {
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
