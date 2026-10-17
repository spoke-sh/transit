//! Console adapter for shared settings plans. Recovery reuses .status/.resume.
const std = @import("std");
const q = @import("transit_query");
const C = q.settings.Contract;
const Console = @import("Console.zig").Console;
const Files = @import("server/Files.zig");
const Output = @import("Output.zig");
pub const Configuration = struct { binding: C.Binding, recovery_file: ?[]const u8 = null };
pub const Saved = struct { definition: q.protocol.Growth.Definition, request: C.Request, principal: u64, role: ?u64, complete: bool };
pub const Connection = struct { client: q.SettingsClient, recovery_file: ?[]const u8, saved: ?Saved = null, session: ?q.SettingsSession = null };
pub fn open(init: std.process.Init, client: q.SettingsClient, path: ?[]const u8) !Connection {
    var result: Connection = .{ .client = client, .recovery_file = path };
    if (path) |file| result.saved = Files.read(Saved, init.io, init.arena.allocator(), file) catch |err| if (err == error.FileNotFound) null else return err;
    if (result.saved) |saved| {
        try saved.request.validate();
        if (saved.definition != q.protocol.Growth.current_definition or !std.meta.eql(saved.request.binding, client.binding) or saved.principal != client.principal or saved.role != client.role or saved.request.action != .reload) return error.InvalidConfigurationRecovery;
    }
    return result;
}
pub fn unresolved(console: *const Console) bool {
    const connection = console.settings orelse return false;
    return if (connection.saved) |saved| !saved.complete else false;
}
pub fn clearComplete(console: *Console) !void {
    const connection = console.settings orelse return;
    const saved = connection.saved orelse return;
    if (!saved.complete) return error.UnresolvedSubmission;
    const path = connection.recovery_file orelse return error.ConfigurationRecoveryRequired;
    const directory = try std.Io.Dir.cwd().openDir(console.init.io, std.fs.path.dirname(path) orelse ".", .{ .iterate = true });
    defer directory.close(console.init.io);
    try directory.deleteFile(console.init.io, std.fs.path.basename(path));
    if (std.c.fsync(directory.handle) != 0) return error.InstallationSyncFailed;
    connection.saved = null;
}
pub fn capture(console: *Console) !void {
    const connection = if (console.settings) |connection| connection else return;
    if (connection.session == null) connection.session = try q.SettingsSession.capture(connection.client);
}
pub fn command(console: *Console, text: []const u8) !bool {
    if (std.mem.startsWith(u8, text, ".")) {
        if (console.settings) |connection| if (connection.saved != null) {
            if (std.mem.eql(u8, text, ".resume")) {
                try submit(console, connection);
                return true;
            }
            if (std.mem.eql(u8, text, ".status")) {
                const response = try connection.client.read(.{ .reloads = .{ .operation = connection.saved.?.request.operation } });
                defer response.deinit();
                var bytes: std.Io.Writer.Allocating = .init(console.init.gpa);
                defer bytes.deinit();
                try std.json.Stringify.value(response.value.result.reloads, .{}, &bytes.writer);
                try bytes.writer.writeByte('\n');
                try Output.write(console.init, console.out, bytes.written());
                return true;
            }
            if (unresolved(console) and std.mem.eql(u8, text, ".cancel")) return error.ConfigurationCancellationUnsupported;
        };
        return false;
    }
    var plan = (q.SettingsSql.parse(console.init.gpa, text, .transit) catch |err| {
        if (try q.SettingsSql.diagnostic(err)) |detail| {
            console.diagnostic.envelope = detail;
            return err;
        }
        return console.sqlFailure(text, err);
    }) orelse return false;
    defer plan.deinit();
    if (plan.statement == .catalog) {
        if (plan.statement.catalog == .tables) return false;
        try catalog(console, plan.statement.catalog);
        return true;
    }
    const connection = if (console.settings) |connection| connection else return error.ConfigurationServiceRequired;
    try capture(console);
    switch (plan.statement) {
        .set => |setting| {
            try connection.session.?.set(setting.value);
            try Output.write(console.init, console.out, if (console.session.format == .json) "{\"command\":\"SET\"}\n" else "SET\n");
        },
        .reset => {
            connection.session.?.reset();
            try Output.write(console.init, console.out, if (console.session.format == .json) "{\"command\":\"RESET\"}\n" else "RESET\n");
        },
        .reload => {
            if (unresolved(console) or (console.writes != null and console.writes.?.unresolved())) return error.UnresolvedSubmission;
            if (console.session.pending != null or console.session.input != null or (console.session.namespace != null and !console.session.complete)) return error.UnresolvedSubmission;
            if (connection.recovery_file == null) return error.ConfigurationRecoveryRequired;
            if (console.writes) |writer| try writer.clearComplete();
            const observed = try connection.client.read(.{ .settings = .{ .name = "version" } });
            defer observed.deinit();
            var operation: [16]u8 = undefined;
            try console.init.io.randomSecure(&operation);
            const signed = try connection.client.prepare(.{ .reload = .{ .expected_generation = observed.value.result.settings.generation } }, operation);
            connection.saved = .{ .definition = q.protocol.Growth.current_definition, .request = signed.configuration, .principal = connection.client.principal, .role = connection.client.role, .complete = false };
            try Files.json(console.init.io, console.init.gpa, connection.recovery_file.?, connection.saved.?);
            try submit(console, connection);
        },
        .show, .relation => {
            var schema = try plan.output(console.init.gpa);
            defer schema.deinit();
            var reader = q.SettingsReader.init(console.init.gpa, connection.client, &plan, connection.session.?);
            defer reader.deinit();
            var storage: [16384]u8 = undefined;
            var stream = Output.Stream.init(console.init.io, console.out, &storage);
            var count: usize = 0;
            while (try reader.next()) |row| {
                if (@import("Signals.zig").interrupted()) return error.ConsoleInterrupted;
                try emit(console, &stream.interface, schema.type.structure, row);
                count += 1;
            }
            if (console.session.format == .json) try stream.interface.print("{{\"complete\":true,\"rows\":{d}}}\n", .{count});
            try stream.flush();
        },
        .catalog => unreachable,
    }
    return true;
}
fn submit(console: *Console, connection: *Connection) !void {
    const saved = connection.saved orelse return error.NoConfigurationOperation;
    const signed = try connection.client.prepare(saved.request.action, saved.request.operation);
    const response = try connection.client.submit(signed);
    defer response.deinit();
    const outcome = response.value.result.reload;
    connection.saved.?.complete = true;
    try Files.json(console.init.io, console.init.gpa, connection.recovery_file.?, connection.saved.?);
    var bytes: std.Io.Writer.Allocating = .init(console.init.gpa);
    defer bytes.deinit();
    const id = std.fmt.bytesToHex(outcome.operation, .lower);
    if (console.session.format == .json) try std.json.Stringify.value(.{ .transit_reload_conf = &id, .outcome = outcome }, .{}, &bytes.writer) else try bytes.writer.print("{s} ({s})", .{ id, @tagName(outcome.phase) });
    try bytes.writer.writeByte('\n');
    try Output.write(console.init, console.out, bytes.written());
    if (outcome.phase == .rejected) return console.diagnostic.fail(error.ConfigurationReloadRejected, "configuration reload rejected; active settings are unchanged", "Inspect transit_config_reloads() for the retained operation and error field. Correct the configuration and submit a new reload.");
}
fn catalog(console: *Console, kind: q.SettingsSql.Catalog) !void {
    const client = console.catalog orelse return error.ConsoleCatalogRequired;
    var storage: [16384]u8 = undefined;
    var stream = Output.Stream.init(console.init.io, console.out, &storage);
    const columns: []const q.fuze.Types.Field = &.{.{ .name = if (kind == .databases) "database" else "schema", .type = .utf8 }};
    if (kind == .databases) {
        const database = try client.describeDatabase();
        try emit(console, &stream.interface, columns, &.{.{ .value = .{ .atom = .{ .bytes = database.configuration.database_name.slice() } } }});
    } else {
        var cursor: ?q.catalog.SchemaCatalog.Cursor = null;
        for (0..10000) |_| {
            if (@import("Signals.zig").interrupted()) return error.ConsoleInterrupted;
            const page = try client.schemas(cursor);
            for (page.schemas) |schema| if (schema) |value| try emit(console, &stream.interface, columns, &.{.{ .value = .{ .atom = .{ .bytes = value.name.slice() } } }});
            cursor = page.next;
            if (cursor == null) break;
        } else return error.ConfigurationReadBudgetExceeded;
    }
    try stream.flush();
}
fn emit(console: *Console, out: *std.Io.Writer, columns: []const q.fuze.Types.Field, cells: []const q.fuze.Types.Values.Cell) !void {
    if (console.session.format == .json) {
        var json: std.json.Stringify = .{ .writer = out };
        try json.beginObject();
        for (columns, cells) |column, cell| {
            try json.objectField(column.name);
            if (cell == .null) try json.write(null) else switch (cell.value.atom) {
                .bytes => |v| try json.write(v),
                .unsigned => |v| try json.write(v),
                .boolean => |v| try json.write(v),
                else => unreachable,
            }
        }
        try json.endObject();
        try out.writeByte('\n');
    } else {
        for (columns, cells, 0..) |column, cell, i| {
            if (i != 0) try out.writeAll(" | ");
            try q.fuze.LogicalDisplay.cell(out, cell, column.type);
        }
        try out.writeByte('\n');
    }
}
