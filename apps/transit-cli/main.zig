//! Signed query shell. SQL/authorization/result semantics live in transit-query.
const std = @import("std");
const q = @import("transit_query");
const Config = struct { url: []const u8, seed_file: []const u8, connection: q.Model.Connection, request_timeout_ms: u32 = 5000 };
const Session = struct {
    client: *q.Client,
    correlation: ?u64 = null,
    ordinal: u64 = 0,
    pending: ?q.Model.Prepared = null,
    cancellation: ?q.protocol.Growth.SignedRequest = null,
    format: enum { table, json } = .table,
    fn clear(self: *Session) void {
        self.correlation = null;
        self.ordinal = 0;
        self.pending = null;
        self.cancellation = null;
    }
};
pub fn main(init: std.process.Init) !void {
    dispatch(init) catch |err| {
        std.debug.print("transit: {s}\n", .{@errorName(err)});
        std.process.exit(switch (err) {
            error.ConsoleInterrupted => 130,
            error.InvalidInvocation, error.InvalidConfiguration, error.InvalidConfigurationPath, error.InvalidCredentialFile => 2,
            else => 1,
        });
    };
}
fn dispatch(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len > 1 and std.mem.eql(u8, args[1], "__transit_child_v1")) return @import("server/Process.zig").trampoline(init, args);
    if (args.len == 3 and std.mem.eql(u8, args[1], "__transit_gateway_v1")) return @import("server/Gateway.zig").run(init, args[2]);
    if (args.len == 3 and std.mem.eql(u8, args[1], "query-v2")) return @import("Unified.zig").run(init, args[2]);
    if (args.len != 3 or !std.mem.eql(u8, args[1], "query")) {
        const options = try @import("Options.zig").parseWithConsoleConfig(args[1..], init.environ_map.get("TRANSIT_CONSOLE_CONFIG"));
        if (options.command == .help or options.help) return std.Io.File.stdout().writeStreamingAll(init.io, @import("Options.zig").help);
        return switch (options.command) {
            .version => std.Io.File.stdout().writeStreamingAll(init.io, "Transit development; CLI contract 1\n"),
            .console => @import("Console.zig").run(init, options),
            .server => @import("server/Server.zig").run(init, options),
            .help => unreachable,
        };
    }
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, args[2], init.gpa, .limited(8192));
    defer init.gpa.free(bytes);
    const parsed = try std.json.parseFromSlice(Config, init.gpa, bytes, .{});
    defer parsed.deinit();
    const config = parsed.value;
    if (config.request_timeout_ms == 0 or config.request_timeout_ms > 60000) return error.InvalidConfiguration;
    var wire = q.wire.Client.init(init.gpa, init.io, config.url);
    defer wire.deinit();
    wire.timeout_ms = config.request_timeout_ms;
    var client: q.Client = .{ .wire = &wire, .connection = config.connection, .key = try q.wire.readKey(init.gpa, init.io, config.seed_file) };
    var session: Session = .{ .client = &client };
    var input_buffer: [8192]u8 = undefined;
    var input = std.Io.File.stdin().reader(init.io, &input_buffer);
    var output_buffer: [8192]u8 = undefined;
    var output = std.Io.File.stdout().writerStreaming(init.io, &output_buffer);
    try output.interface.writeAll("Transit query — SQL runs on Enter. /help lists commands.\n");
    try output.interface.flush();
    while (try input.interface.takeDelimiter('\n')) |raw| {
        const line = std.mem.trim(u8, raw, " \t\r");
        if (std.mem.eql(u8, line, "/quit")) break;
        if (line.len == 0) continue;
        var arena = std.heap.ArenaAllocator.init(init.gpa);
        defer arena.deinit();
        command(&session, line, arena.allocator(), &output.interface) catch |err| {
            // Rows only live in the command arena. Access loss also erases the
            // remembered identity/prepared request; prior terminal bytes remain
            // previously disclosed data, not an offline result store.
            if (err == error.AccessDenied or err == error.QueryAccessDenied or err == error.QuerySourceUnavailable) session.clear();
            try output.interface.print("error: {s}\n", .{@errorName(err)});
        };
        try output.interface.flush();
    }
}
fn json(out: *std.Io.Writer, value: anytype) !void {
    try std.json.Stringify.value(value, .{}, out);
    try out.writeByte('\n');
}
fn command(session: *Session, line: []const u8, allocator: std.mem.Allocator, out: *std.Io.Writer) !void {
    const client = session.client;
    if (std.mem.eql(u8, line, "/help")) return out.writeAll("SQL: qualified read-only Table SELECT, one statement per line (4096 bytes).\n/help /tables /schema /info /status /next /resume ID /cancel /retry /format table|json /quit\nA receipt means submitted; /status reports admission and verified completion.\n/next reads one complete-result segment. /quit disconnects without cancelling.\n");
    if (std.mem.eql(u8, line, "/info")) {
        _ = try client.describe();
        return json(out, .{ .connection = client.connection, .correlation = session.correlation, .uncertain = session.pending != null or session.cancellation != null, .format = session.format });
    }
    if (std.mem.eql(u8, line, "/tables") or std.mem.eql(u8, line, "/schema")) return json(out, try client.describe());
    if (std.mem.startsWith(u8, line, "/format ")) {
        session.format = std.meta.stringToEnum(@FieldType(Session, "format"), line[8..]) orelse return error.UnsupportedFormat;
        return json(out, .{ .format = session.format });
    }
    if (std.mem.startsWith(u8, line, "/resume ")) {
        const id = try std.fmt.parseInt(u64, line[8..], 10);
        const status = try client.status(id);
        if (session.pending != null or session.cancellation != null) return error.UnresolvedSubmission;
        session.correlation = id;
        session.ordinal = 0;
        return json(out, status);
    }
    if (std.mem.eql(u8, line, "/status")) return json(out, try client.status(session.correlation orelse return error.NoQuery));
    if (std.mem.eql(u8, line, "/next")) {
        const page = try client.page(session.correlation orelse return error.NoQuery, session.ordinal, allocator);
        if (session.format == .json) try json(out, page) else {
            try out.print("complete result {d}; source revision {d}; segment {d}/{d}; rows {d}\n", .{ page.manifest.result, page.manifest.basis.revision, page.ordinal + 1, page.manifest.segments, page.manifest.rows });
            // JSON string escaping prevents terminal control sequences in values
            // or identifiers. Rendering never narrows integers or guesses types.
            for (page.columns) |slot| if (slot) |column| {
                try std.json.Stringify.value(column.name, .{}, out);
                try out.writeByte('\t');
            };
            try out.writeByte('\n');
            for (page.rows[0..page.count]) |row| {
                for (row.?) |slot| if (slot) |cell| {
                    try std.json.Stringify.value(cell, .{}, out);
                    try out.writeByte('\t');
                };
                try out.writeByte('\n');
            }
        }
        session.ordinal += 1;
        return;
    }
    if (std.mem.eql(u8, line, "/cancel")) {
        if (session.pending != null or session.cancellation != null) return error.UnresolvedSubmission;
        session.cancellation = try client.prepareCancel(session.correlation orelse return error.NoQuery);
    } else if (!std.mem.eql(u8, line, "/retry")) {
        if (line[0] == '/') return error.UnknownCommand;
        if (session.pending != null or session.cancellation != null) return error.UnresolvedSubmission;
        session.pending = try client.prepare(line);
    }
    if (session.cancellation) |pending| {
        const receipt = try client.submitCancel(pending);
        session.cancellation = null;
        return json(out, .{ .cancellation_submitted = receipt.position });
    }
    const prepared = session.pending orelse return error.NoPendingSubmission;
    const receipt = try client.submit(prepared);
    session.pending = null;
    session.correlation = receipt.position;
    session.ordinal = 0;
    try json(out, .{ .submitted = receipt.position });
}
