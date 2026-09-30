//! Explicit ephemeral file-query host. Shared Fuze owns all SQL/type semantics.
const std = @import("std");
const f = @import("transit_query").fuze;
const Capture = @import("FileCapture.zig");
const Signals = @import("Signals.zig");
const Diagnostic = @import("Diagnostic.zig");
pub const definition = "transit.fuze.file-output.v1.2026-09-30";
pub const help =
    \\Query explicit local files or captured stdin with a frozen schema.
    \\
    \\Usage: transit file-query --format csv|jsonl -c SQL [OPTIONS] FILE...
    \\
    \\  -c SQL                  One finite SELECT over the name input
    \\  --format csv|jsonl       Required; JSONL also accepts NDJSON objects
    \\  --mode MODE              sampled (default), explicit, full or raw
    \\  --schema PATH            Neutral logical type JSON; full/partial override
    \\  --mismatch POLICY        fail (default) or type_error
    \\  --sample-records N       Discovery limit (default 1024)
    \\  --sample-bytes N         Discovery bytes (default 1048576)
    \\  --max-bytes N            Total expanded capture/scan quota (default 1 GiB)
    \\  --max-encoded-bytes N    Total encoded capture quota (default 1 GiB)
    \\  --max-records N          Scan record quota (default 100000000)
    \\  --max-record-bytes N     Record bound, at most 65536 (default 65536)
    \\  --max-fields N           Field bound, at most 128 (default 128)
    \\  --delimiter CHAR         CSV delimiter (default comma)
    \\  --quote CHAR             CSV quote (default double quote)
    \\  --no-header              Generate CSV column names
    \\  --null-token TEXT        One unquoted CSV null token (default none)
    \\  --gzip                   All inputs use one gzip member; verify checksums
    \\  --help                   Offline help; validates supplied options
    \\
    \\Use - for stdin once; -- ends options. At most 128 files. Named paths must
    \\be regular files; pipe other streams to stdin. TMPDIR selects spool storage.
    \\Captures are private, unlinked disk files, removed on exit or cancellation.
    \\JSON records preserve exact numbers and five states. Rows are provisional
    \\until the complete record. No durable job, installation or network is used.
    \\
;
const Options = struct {
    source: f.FileSource.Options = .{ .format = .csv },
    encoded_quota: u64 = 1024 * 1024 * 1024,
    schema: ?[]const u8 = null,
    sql: ?[]const u8 = null,
    gzip: bool = false,
    help: bool = false,
    paths: [128][]const u8 = undefined,
    path_count: usize = 0,
    null_token: [1][]const u8 = undefined,
    has_null: bool = false,
};
fn parse(args: []const []const u8, diagnostic: *Diagnostic) !Options {
    var result: Options = .{};
    var seen: u32 = 0;
    var positional = false;
    var stdin = false;
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        diagnostic.atArgument(i + 2, null);
        if (!positional and std.mem.eql(u8, arg, "--")) {
            positional = true;
            continue;
        }
        if (positional or !std.mem.startsWith(u8, arg, "-") or std.mem.eql(u8, arg, "-")) {
            if (arg.len == 0 or result.path_count == result.paths.len) return diagnostic.invalidArgument("requires one to 128 nonempty source paths");
            if (std.mem.eql(u8, arg, "-")) {
                if (stdin) return diagnostic.invalidArgument("stdin can only be used once");
                stdin = true;
            }
            result.paths[result.path_count] = arg;
            result.path_count += 1;
            continue;
        }
        const names = [_][]const u8{ "--help", "--gzip", "--no-header", "-c", "--format", "--mode", "--schema", "--mismatch", "--sample-records", "--sample-bytes", "--max-bytes", "--max-encoded-bytes", "--max-records", "--max-record-bytes", "--max-fields", "--delimiter", "--quote", "--null-token" };
        const index = for (names, 0..) |name, n| {
            if (std.mem.eql(u8, name, arg)) break n;
        } else return diagnostic.invalidArgument("unexpected input");
        diagnostic.option = names[index];
        const mask = @as(u32, 1) << @as(u5, @intCast(index));
        if (seen & mask != 0) return diagnostic.invalidOption("can only be specified once");
        seen |= mask;
        if (index < 3) {
            switch (index) {
                0 => result.help = true,
                1 => result.gzip = true,
                2 => result.source.dialect.header = false,
                else => unreachable,
            }
            continue;
        }
        i += 1;
        if (i == args.len) return diagnostic.invalidOption("requires a value");
        const value = args[i];
        switch (index) {
            3 => {
                if (value.len == 0 or value.len > 65536) return diagnostic.invalidOption("requires one SQL statement of at most 65536 bytes");
                result.sql = value;
            },
            4 => result.source.format = std.meta.stringToEnum(@TypeOf(result.source.format), value) orelse return diagnostic.invalidOption("must be csv or jsonl"),
            5 => result.source.mode = std.meta.stringToEnum(f.FileSource.Mode, value) orelse return diagnostic.invalidOption("must be explicit, sampled, full or raw"),
            6 => {
                if (value.len == 0) return diagnostic.invalidOption("requires a file path");
                result.schema = value;
            },
            7 => result.source.mismatch = std.meta.stringToEnum(f.FileSource.Mismatch, value) orelse return diagnostic.invalidOption("must be fail or type_error"),
            8...14 => {
                if (value.len == 0) return diagnostic.invalidOption("requires a positive decimal integer");
                for (value) |byte| if (!std.ascii.isDigit(byte)) return diagnostic.invalidOption("requires a positive decimal integer");
                const number = std.fmt.parseInt(u64, value, 10) catch return diagnostic.invalidOption("exceeds the integer range");
                if (number == 0) return diagnostic.invalidOption("requires a positive integer");
                switch (index) {
                    8 => result.source.sample_records = number,
                    9 => result.source.sample_bytes = number,
                    10 => result.source.max_scan_bytes = number,
                    11 => result.encoded_quota = number,
                    12 => result.source.max_records = number,
                    13 => result.source.max_record_bytes = std.math.cast(u32, number) orelse return diagnostic.invalidOption("must be at most 65536"),
                    14 => result.source.max_fields = std.math.cast(u16, number) orelse return diagnostic.invalidOption("must be at most 128"),
                    else => unreachable,
                }
            },
            15, 16 => {
                if (value.len != 1) return diagnostic.invalidOption("requires one ASCII character");
                if (index == 15) result.source.dialect.delimiter = value[0] else result.source.dialect.quote = value[0];
            },
            17 => {
                if (value.len > 1024 or !std.unicode.utf8ValidateSlice(value)) return diagnostic.invalidOption("requires UTF-8 of at most 1024 bytes");
                result.null_token[0] = value;
                result.has_null = true;
            },
            else => unreachable,
        }
    }
    diagnostic.atArgument(null, null);
    result.source.validate() catch return diagnostic.invalidInvocation("invalid source limits or CSV dialect");
    if (result.source.format == .jsonl and (seen & ((1 << 2) | (1 << 15) | (1 << 16) | (1 << 17))) != 0) return diagnostic.invalidInvocation("CSV options require --format csv");
    if ((result.source.mode == .explicit and result.schema == null) or (result.source.mode == .raw and result.schema != null)) return diagnostic.invalidInvocation("explicit mode requires --schema; raw mode rejects it");
    if (!result.help and (seen & (1 << 4) == 0 or result.sql == null or result.path_count == 0)) return diagnostic.invalidInvocation("--format, -c and at least one source path are required");
    return result;
}
fn emit(init: std.process.Init, value: anytype) !void {
    const bytes = try std.json.Stringify.valueAlloc(init.gpa, value, .{});
    defer init.gpa.free(bytes);
    if (bytes.len > f.LogicalJson.max_input_bytes) return error.OutputRecordTooLarge;
    try writeOutput(bytes);
    try writeOutput("\n");
}
fn writeOutput(bytes: []const u8) !void {
    var offset: usize = 0;
    while (offset < bytes.len) {
        try Capture.check(undefined);
        var descriptors: [1]std.c.pollfd = .{.{ .fd = 1, .events = std.c.POLL.OUT, .revents = 0 }};
        const ready = std.c.poll(&descriptors, 1, 100);
        if (ready == 0) continue;
        if (ready < 0) {
            if (std.c._errno().* == @backingInt(std.c.E.INTR)) continue;
            return error.OutputWriteFailed;
        }
        // Linux PIPE_BUF-sized writes after writable polling keep a stopped
        // downstream reader cancellable, without altering shared FD flags.
        const part = bytes[offset..][0..@min(4096, bytes.len - offset)];
        const written = std.c.write(1, part.ptr, part.len);
        if (written < 0) {
            if (std.c._errno().* == @backingInt(std.c.E.INTR)) continue;
            return error.OutputWriteFailed;
        }
        if (written == 0) return error.OutputWriteFailed;
        offset += @intCast(written);
    }
}
pub fn run(init: std.process.Init, args: []const []const u8, diagnostic: *Diagnostic) !void {
    diagnostic.command = "transit file-query";
    diagnostic.help = "transit file-query --help";
    var options = try parse(args, diagnostic);
    if (options.help) return std.Io.File.stdout().writeStreamingAll(init.io, help);
    if (options.has_null) options.source.dialect.null_tokens = &options.null_token;
    var signals = try Signals.install();
    defer signals.close();
    var explicit: ?f.Types.Decoded = null;
    defer if (explicit) |*owner| owner.deinit();
    if (options.schema) |path| {
        diagnostic.atFile(path);
        const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(65536));
        defer init.gpa.free(bytes);
        explicit = try f.LogicalJson.decodeType(init.gpa, bytes);
        if (explicit.?.type != .structure) return error.InvalidExplicitSchema;
    }
    var captures: [128]Capture = undefined;
    var count: usize = 0;
    defer for (captures[0..count]) |*capture| capture.close();
    var sources: [128]f.FileSource.Source = undefined;
    var encoded = options.encoded_quota;
    var expanded = options.source.max_scan_bytes;
    for (options.paths[0..options.path_count]) |path| {
        diagnostic.atFile(path);
        captures[count] = try Capture.acquire(init, path, &encoded, &expanded, options.gzip);
        sources[count] = captures[count].source();
        count += 1;
    }
    diagnostic.file = null;
    var binding = try f.FileSource.discover(init.gpa, sources[0..count], options.source, if (explicit) |owner| owner.type.structure else &.{});
    defer binding.deinit();
    var compiled = try f.FileQuery.compile(init.gpa, options.sql.?, "input", &binding);
    defer compiled.deinit();
    var execution = try f.FileQuery.Execution.init(init.gpa, &binding, sources[0..count], compiled.plan);
    defer execution.deinit();
    var fields: [128]f.Types.Field = undefined;
    const schema = try compiled.plan.outputSchema(&fields);
    const basis = std.fmt.bytesToHex(binding.digest, .lower);
    const plan = std.fmt.bytesToHex(execution.fingerprint, .lower);
    var evidence_records: [20]u8 = undefined;
    var evidence_bytes: [20]u8 = undefined;
    try emit(init, .{ .definition = definition, .schema = f.LogicalJson.TypeEnvelope{ .definition = f.Types.definition, .type = schema }, .binding = &basis, .plan = &plan, .evidence = .{
        .records = try std.fmt.bufPrint(&evidence_records, "{d}", .{binding.evidence.records}),
        .sampled_bytes = try std.fmt.bufPrint(&evidence_bytes, "{d}", .{binding.evidence.sampled_bytes}),
        .complete = binding.evidence.complete,
    } });
    while (try execution.next()) |owned| {
        var row = owned;
        defer row.deinit();
        const value = try f.LogicalJson.foreignCell(row.arena.allocator(), .{ .value = .{ .structure = row.cells } }, schema);
        try Capture.check(undefined);
        try emit(init, .{ .row = value });
    }
    if (!execution.complete) return error.IncompleteSource;
    try Capture.check(undefined);
    var scanned: [20]u8 = undefined;
    var emitted: [20]u8 = undefined;
    try emit(init, .{ .complete = .{ .binding = &basis, .plan = &plan, .scanned = try std.fmt.bufPrint(&scanned, "{d}", .{execution.scanned}), .emitted = try std.fmt.bufPrint(&emitted, "{d}", .{execution.emitted}) } });
}
