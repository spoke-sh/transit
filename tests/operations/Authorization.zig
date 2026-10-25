//! Explicit administration over the shared client lifecycle. Apply checkpoints
//! each exact signed step before dispatch and never re-resolves a saved action.
const std = @import("std");
const q = @import("transit_query");
const wire = q.wire;
const p = wire.protocol;
const B = wire.AuthorizationBridge;
const Change = wire.AuthorizationChange;
const Set = wire.AuthorizationSet;
const Diagnostic = @import("cli_support").Diagnostic;
const Recovery = @import("RecoveryFiles.zig");
const Files = @import("cli_support").Files;
pub const Config = @import("cli_support").AuthorizationProfile;
pub const Kind = enum { change, changeset };
pub const Saved = struct { definition: p.Growth.Definition, kind: Kind, record: []const u8, preview: ?p.Authorization.Preview = null };
pub const Mode = enum { capabilities, read, prepare, @"prepare-plan", @"prepare-set", next, submit, observe, recover, abandon, apply };
const Flags = struct { config: ?[]const u8 = null, file: ?[]const u8 = null, output: ?[]const u8 = null, steps: ?[]const u8 = null };
pub const Options = struct { mode: Mode, flags: Flags = .{}, steps: u8 = 16 };
fn writes(mode: Mode) bool {
    return mode == .prepare or mode == .@"prepare-plan" or mode == .@"prepare-set" or mode == .next or mode == .recover or mode == .abandon;
}
fn allowed(mode: Mode, field: []const u8) bool {
    if (std.mem.eql(u8, field, "output")) return writes(mode);
    if (std.mem.eql(u8, field, "steps")) return mode == .apply;
    return mode != .capabilities;
}
pub fn parse(args: []const []const u8, report: *Diagnostic) !Options {
    report.command = "authorization fixture";
    report.atArgument(2, null);
    if (args.len == 0) return report.invalidInvocation("an authorization command is required");
    var result: Options = .{ .mode = std.meta.stringToEnum(Mode, args[0]) orelse return report.invalidArgument("unknown authorization command") };
    var i: usize = 1;
    while (i < args.len) {
        report.atArgument(i + 2, null);

        var found = false;
        inline for (@typeInfo(Flags).@"struct".field_names) |field| {
            if (std.mem.eql(u8, args[i], "--" ++ field)) {
                report.option = "--" ++ field;
                if (!allowed(result.mode, field)) return report.invalidOption("is not supported by this command");
                if (@field(result.flags, field) != null) return report.invalidOption("can only be specified once");
                if (i + 1 == args.len or args[i + 1].len == 0 or std.mem.startsWith(u8, args[i + 1], "--")) return report.invalidOption("requires a value");
                @field(result.flags, field) = args[i + 1];
                found = true;
            }
        }
        if (!found) return report.invalidArgument("unexpected input");
        i += 2;
    }
    if (result.flags.steps) |text| {
        result.steps = std.fmt.parseInt(u8, text, 10) catch return report.invalidOption("steps must be between 1 and 64");
        if (result.steps == 0 or result.steps > 64) return report.invalidOption("steps must be between 1 and 64");
    }
    inline for (@typeInfo(Flags).@"struct".field_names) |field| {
        if (!std.mem.eql(u8, field, "steps") and allowed(result.mode, field) and @field(result.flags, field) == null) {
            report.atArgument(null, "--" ++ field);
            return report.invalidOption("is required");
        }
    }
    return result;
}
fn read(comptime T: type, init: std.process.Init, path: []const u8, report: *Diagnostic) !T {
    const value = try report.readJson(std.json.Value, init, path, B.max_input_bytes);
    const bytes = try std.json.Stringify.valueAlloc(init.arena.allocator(), value, .{});
    const checked = try p.Json.parseFromSlice(T, init.arena.allocator(), bytes);
    defer checked.deinit();
    return std.json.parseFromSliceLeaky(T, init.arena.allocator(), bytes, .{ .allocate = .alloc_always });
}
fn saved(init: std.process.Init, config: Config, path: []const u8, report: *Diagnostic) !Saved {
    const value = try read(Saved, init, path, report);
    if (value.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
    switch (value.kind) {
        .change => _ = try B.record(init.arena.allocator(), config.connection, value.record),
        .changeset => _ = try B.setRecord(init.arena.allocator(), config.connection, value.record),
    }
    return value;
}
fn checkpoint(init: std.process.Init, path: []const u8, record: Change.Record, preview: ?p.Authorization.Preview) !void {
    const value: Saved = .{ .definition = p.Growth.current_definition, .kind = .change, .record = try record.save(init.arena.allocator()), .preview = preview };
    try Files.jsonBounded(init.io, init.arena.allocator(), path, value, B.max_input_bytes);
}
fn attempt(init: std.process.Init, transport: *wire.Client, key: p.Ed25519.KeyPair, connection: B.Connection, action: B.Action, report: *Diagnostic) !B.Result {
    const identity = B.identity(init.arena.allocator(), connection, action) catch null;
    var dispatched = false;
    transport.last_rejection = null;
    return B.apply(init.arena.allocator(), transport, key, connection, action, &dispatched) catch |err| {
        report.envelope = B.diagnostic(action, err, dispatched, identity, transport.last_rejection) catch null;
        return err;
    };
}
pub fn run(init: std.process.Init, args: []const []const u8, report: *Diagnostic) !void {
    const options = try parse(args, report);
    if (options.mode == .capabilities) return output(init, B.Result{ .capabilities = .{} });
    const alloc = init.arena.allocator();
    report.atFile(options.flags.config.?);
    const absolute = try std.Io.Dir.cwd().realPathFileAlloc(init.io, options.flags.config.?, alloc);
    const config = try @import("cli_support").Settings.readTyped(Config, init, absolute, report);
    if (config.version != 1) return report.invalidField("version", "must be 1", null);
    try config.connection.validate();
    if (config.request_timeout_ms == 0 or config.request_timeout_ms > 60000) return report.invalidField("request_timeout_ms", "must be between 1 and 60000", null);
    if (config.url.len == 0 or config.url.len > 2048) return report.invalidField("url", "requires an HTTP or HTTPS authority URL", null);
    const uri = std.Uri.parse(config.url) catch return report.invalidField("url", "requires an HTTP or HTTPS authority URL", null);
    if (!(std.mem.eql(u8, uri.scheme, "http") or std.mem.eql(u8, uri.scheme, "https")) or uri.host == null or uri.user != null or uri.password != null or uri.query != null or uri.fragment != null) return report.invalidField("url", "requires an HTTP or HTTPS authority URL without embedded credentials, query or fragment", null);
    if (config.seed_file.len == 0) return report.invalidField("seed_file", "requires a credential file path", null);
    var path = options.flags.file.?;
    var lock: ?std.Io.File = null;
    defer if (lock) |value| value.close(init.io);
    if (options.mode == .apply) {
        // Resolve aliases before locking so two invocations cannot advance the
        // same recovery artifact through different relative/symlink paths.
        const canonical = try std.Io.Dir.cwd().realPathFileAlloc(init.io, path, alloc);
        path = canonical;
        lock = try std.Io.Dir.cwd().createFile(init.io, try std.fmt.allocPrint(alloc, "{s}.lock", .{canonical}), .{ .truncate = false, .permissions = .fromMode(0o600) });
        if (!try lock.?.tryLock(init.io, .exclusive)) return error.AuthorizationFileInUse;
    }
    // Parse and authenticate retained material before loading a key or doing I/O.
    var plan: ?q.catalog.AuthorizationLowering.Plan = null;
    var kind: Kind = .change;
    const action: B.Action = switch (options.mode) {
        .capabilities => unreachable,
        .read => .{ .read = try read(B.Read, init, path, report) },
        .prepare => .{ .prepare = try read(@FieldType(B.Action, "prepare"), init, path, report) },
        .@"prepare-set" => value: {
            kind = .changeset;
            break :value .{ .changeset = .{ .prepare = try read(Set.Document, init, path, report) } };
        },
        .@"prepare-plan" => value: {
            const artifact = try read(struct { authorization_plan: q.catalog.TableValues.AuthorizationPlan }, init, path, report);
            plan = try artifact.authorization_plan.native();
            if (plan.?.scope.realm != config.connection.realm or plan.?.principal != config.connection.principal or plan.?.action != .authorization) return error.InvalidAuthorizationChange;
            break :value .{ .prepare = .{ .expected_revision = plan.?.expected_revision, .action = plan.?.action.authorization } };
        },
        else => value: {
            const artifact = try saved(init, config, path, report);
            kind = artifact.kind;
            const record = artifact.record;
            if (kind == .changeset) break :value .{ .changeset = switch (options.mode) {
                .next => .{ .next = record },
                .submit => .{ .submit = record },
                .observe => .{ .observe = record },
                .recover => .{ .recover_pending = record },
                .abandon => .{ .abandon = record },
                .apply => .{ .restore = record },
                else => unreachable,
            } };
            break :value switch (options.mode) {
                .next => .{ .next = record },
                .submit => .{ .submit = record },
                .observe => .{ .observe = record },
                .recover => .{ .recover_pending = record },
                .abandon => .{ .abandon = record },
                .apply => .{ .restore = record },
                else => unreachable,
            };
        },
    };
    try B.validate(alloc, config.connection, action);
    report.atFile(absolute);
    const seed_path = try std.fs.path.resolve(alloc, &.{ std.fs.path.dirname(absolute).?, config.seed_file });
    var key = wire.readKey(init.gpa, init.io, seed_path) catch |err| {
        report.setFailure(err, "cannot load the authorization signing credential", "Check seed_file relative to the configuration file and its permissions; do not print or paste the seed.");
        return error.InvalidCredentialFile;
    };
    defer std.crypto.secureZero(u8, std.mem.asBytes(&key));
    var transport = wire.Client.init(init.gpa, init.io, config.url);
    defer transport.deinit();
    transport.timeout_ms = config.request_timeout_ms;
    if (plan) |compiled| {
        const identity = (try attempt(init, &transport, key, config.connection, .{ .read = .identity }, report)).observation.body.authorization;
        if (identity.role != compiled.role or identity.revision != compiled.expected_revision) return error.StaleAuthorizationRevision;
    }
    if (options.mode == .apply) return switch (kind) {
        .change => apply(init, &transport, key, config.connection, path, try B.record(alloc, config.connection, action.restore), options.steps, report),
        .changeset => applySet(init, &transport, key, config.connection, path, try B.setRecord(alloc, config.connection, action.changeset.restore), options.steps, report),
    };
    const result = try attempt(init, &transport, key, config.connection, action, report);
    if (options.flags.output) |destination| {
        const value: ?Saved = switch (result) {
            .prepared => |prepared| .{ .definition = p.Growth.current_definition, .kind = kind, .record = prepared.record, .preview = prepared.preview },
            .record => |record| .{ .definition = p.Growth.current_definition, .kind = kind, .record = record },
            .next => |next| if (next == .pending) .{ .definition = p.Growth.current_definition, .kind = kind, .record = next.pending } else null,
            .recovered => |recovered| if (recovered) |record| .{ .definition = p.Growth.current_definition, .kind = kind, .record = record } else null,
            .changeset => |set| switch (set) {
                .prepared => |prepared| .{ .definition = p.Growth.current_definition, .kind = kind, .record = prepared.record, .preview = prepared.preview },
                .record => |record| .{ .definition = p.Growth.current_definition, .kind = kind, .record = record },
                .next => |next| if (next == .record) .{ .definition = p.Growth.current_definition, .kind = kind, .record = next.record } else null,
                .recovered => |recovered| if (recovered) |record| .{ .definition = p.Growth.current_definition, .kind = kind, .record = record } else null,
                else => null,
            },
            else => null,
        };
        if (value) |artifact| try Recovery.createBounded(init, destination, artifact, B.max_input_bytes);
    }
    output(init, result) catch |err| {
        if (action == .submit or (action == .changeset and action.changeset == .submit)) report.envelope = B.diagnostic(action, err, true, try B.identity(alloc, config.connection, action), null) catch null;
        return err;
    };
}
fn apply(init: std.process.Init, transport: *wire.Client, key: p.Ed25519.KeyPair, connection: B.Connection, path: []const u8, initial: Change.Record, limit: u8, report: *Diagnostic) !void {
    const alloc = init.arena.allocator();
    var record = initial;
    var steps: u8 = 0;
    while (true) {
        const bytes = try record.save(alloc);
        if (record.pending != null) {
            // Recovery comes first, including after credential rotation. An
            // absent receipt permits only resubmitting these same signed bytes.
            const recovered = (try attempt(init, transport, key, connection, .{ .recover_pending = bytes }, report)).recovered;
            if (recovered) |saved_record| {
                record = try B.record(alloc, connection, saved_record);
                try checkpoint(init, path, record, null);
                continue;
            }
            if (steps == limit) return output(init, .{ .pending = true, .steps = steps, .change = record.change });
            const receipt = (try attempt(init, transport, key, connection, .{ .submit = bytes }, report)).receipt;
            record = try record.received(receipt);
            checkpoint(init, path, record, null) catch |err| {
                report.envelope = B.diagnostic(.{ .submit = bytes }, err, true, try B.identity(alloc, connection, .{ .submit = bytes }), null) catch null;
                return err;
            };
            steps += 1;
        } else {
            const next = (try attempt(init, transport, key, connection, .{ .next = bytes }, report)).next;
            if (next == .terminal) return output(init, .{ .terminal = next.terminal, .steps = steps });
            record = try B.record(alloc, connection, next.pending);
            // Durable save precedes every new dispatch, including publication.
            try checkpoint(init, path, record, null);
        }
    }
}
fn checkpointSet(init: std.process.Init, path: []const u8, record: Set.Record) !void {
    const artifact: Saved = .{ .definition = p.Growth.current_definition, .kind = .changeset, .record = try record.save(init.arena.allocator()) };
    try Files.jsonBounded(init.io, init.arena.allocator(), path, artifact, B.max_input_bytes);
}
fn applySet(init: std.process.Init, transport: *wire.Client, key: p.Ed25519.KeyPair, connection: B.Connection, path: []const u8, initial: Set.Record, limit: u8, report: *Diagnostic) !void {
    const alloc = init.arena.allocator();
    var record = initial;
    var steps: u8 = 0;
    while (true) {
        const bytes = try record.save(alloc);
        if (record.current != null and record.current.?.pending != null) {
            const recovered = (try attempt(init, transport, key, connection, .{ .changeset = .{ .recover_pending = bytes } }, report)).changeset.recovered;
            if (recovered) |value| {
                record = try B.setRecord(alloc, connection, value);
                try checkpointSet(init, path, record);
                continue;
            }
            if (steps == limit) return output(init, .{ .pending = true, .steps = steps, .completed = record.completed.len, .total = record.seal.document.intents.len });
            const send: B.Action = .{ .changeset = .{ .submit = bytes } };
            const receipt = (try attempt(init, transport, key, connection, send, report)).changeset.receipt;
            record = try record.received(receipt);
            checkpointSet(init, path, record) catch |err| {
                report.envelope = B.diagnostic(send, err, true, try B.identity(alloc, connection, send), null) catch null;
                return err;
            };
            steps += 1;
        } else {
            const next = (try attempt(init, transport, key, connection, .{ .changeset = .{ .next = bytes } }, report)).changeset.next;
            if (next == .terminal) return output(init, .{ .terminal = next.terminal, .steps = steps });
            record = try B.setRecord(alloc, connection, next.record);
            try checkpointSet(init, path, record);
        }
    }
}
fn output(init: std.process.Init, value: anytype) !void {
    const bytes = try p.Json.valueAlloc(init.arena.allocator(), value);
    var scratch: [4096]u8 = undefined;
    var writer = std.Io.File.stdout().writerStreaming(init.io, &scratch);
    try writer.interface.writeAll(bytes);
    try writer.interface.writeByte('\n');
    try writer.interface.flush();
}
