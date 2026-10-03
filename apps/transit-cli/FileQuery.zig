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
    \\  --output json|arrow      Lossless JSON (default) or logical Arrow IPC stream
    \\  --batch-rows N           Arrow batch rows, 1 to 8 (default 8)
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
    output: enum { json, arrow } = .json,
    batch_rows: u8 = 8,
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
        const names = [_][]const u8{ "--help", "--gzip", "--no-header", "-c", "--format", "--mode", "--schema", "--mismatch", "--sample-records", "--sample-bytes", "--max-bytes", "--max-encoded-bytes", "--max-records", "--max-record-bytes", "--max-fields", "--delimiter", "--quote", "--null-token", "--output", "--batch-rows" };
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
                    13 => {
                        if (number > 65536) return diagnostic.invalidOption("must be at most 65536");
                        result.source.max_record_bytes = @intCast(number);
                    },
                    14 => {
                        if (number > 128) return diagnostic.invalidOption("must be at most 128");
                        result.source.max_fields = @intCast(number);
                    },
                    else => unreachable,
                }
            },
            15, 16 => {
                if (value.len != 1 or value[0] < 0x20 or value[0] >= 0x7f) return diagnostic.invalidOption("requires one printable ASCII character");
                if (index == 15) result.source.dialect.delimiter = value[0] else result.source.dialect.quote = value[0];
            },
            17 => {
                if (value.len > 1024 or !std.unicode.utf8ValidateSlice(value)) return diagnostic.invalidOption("requires UTF-8 of at most 1024 bytes");
                result.null_token[0] = value;
                result.has_null = true;
            },
            18 => result.output = std.meta.stringToEnum(@TypeOf(result.output), value) orelse return diagnostic.invalidOption("must be json or arrow"),
            19 => {
                if (value.len != 1 or value[0] < '1' or value[0] > '8') return diagnostic.invalidOption("must be 1 to 8");
                result.batch_rows = value[0] - '0';
            },
            else => unreachable,
        }
    }
    diagnostic.atArgument(null, null);
    if (result.source.dialect.delimiter == result.source.dialect.quote) return diagnostic.invalidInvocation("--delimiter and --quote must be different characters");
    try result.source.validate();
    if (result.source.format == .jsonl and (seen & ((1 << 2) | (1 << 15) | (1 << 16) | (1 << 17))) != 0) return diagnostic.invalidInvocation("CSV options require --format csv");
    if (result.output != .arrow and seen & (1 << 19) != 0) return diagnostic.invalidInvocation("--batch-rows requires --output arrow");
    if ((result.source.mode == .explicit and result.schema == null) or (result.source.mode == .raw and result.schema != null)) return diagnostic.invalidInvocation("explicit mode requires --schema; raw mode rejects it");
    if (!result.help and (seen & (1 << 4) == 0 or result.sql == null or result.path_count == 0)) return diagnostic.invalidInvocation("--format, -c and at least one source path are required");
    return result;
}
fn emit(init: std.process.Init, value: anytype, diagnostic: *?f.FileSource.BudgetDiagnostic) !void {
    const bytes = try std.json.Stringify.valueAlloc(init.gpa, value, .{});
    defer init.gpa.free(bytes);
    if (bytes.len > f.LogicalJson.max_input_bytes) {
        diagnostic.* = .{ .dimension = .output_record_bytes, .required = bytes.len, .limit = f.LogicalJson.max_input_bytes };
        return error.OutputRecordTooLarge;
    }
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
    var stage: @import("FileDiagnostic.zig").Stage = .capture;
    var location: f.FileSource.Location = .{};
    var runtime_failure: ?f.FileQuery.Failure = null;
    var output_budget: ?f.FileSource.BudgetDiagnostic = null;
    var schema_file = false;
    var schema_failure: ?f.Types.Diagnostic = null;
    var capture_failure: Capture.Failure = .{ .phase = .source_open };
    var output_started = false;
    var limited = false;
    errdefer if (diagnostic.sql == null) {
        diagnostic.source = .{ .stage = stage, .capture_failure = if (stage == .capture) capture_failure else null, .schema_file = schema_file, .schema_failure = schema_failure, .output_budget = output_budget, .runtime_failure = runtime_failure, .path = if (location.source) |index| options.paths[index] else diagnostic.file, .location = location, .output_started = output_started, .limited = limited, .max_record_bytes = options.source.max_record_bytes, .max_records = options.source.max_records, .max_scan_bytes = options.source.max_scan_bytes };
    };
    var explicit: ?f.Types.Decoded = null;
    defer if (explicit) |*owner| owner.deinit();
    if (options.schema) |path| {
        schema_file = true;
        stage = .schema;
        diagnostic.atFile(path);
        const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(65536));
        defer init.gpa.free(bytes);
        explicit = try f.LogicalJson.decodeTypeFullContext(init.gpa, bytes, &location.budget, &schema_failure, &location.json);
        if (explicit.?.type != .structure) {
            schema_failure = .{ .path = (f.Types.Diagnostic.Path{}).field("type"), .kind = .root };
            schema_failure.?.capture(@tagName(explicit.?.type));
            return error.InvalidExplicitSchema;
        }
    }
    schema_file = false;
    stage = .capture;
    var captures: [128]Capture = undefined;
    var count: usize = 0;
    defer for (captures[0..count]) |*capture| capture.close();
    var sources: [128]f.FileSource.Source = undefined;
    var encoded = options.encoded_quota;
    var expanded = options.source.max_scan_bytes;
    for (options.paths[0..options.path_count]) |path| {
        diagnostic.atFile(path);
        captures[count] = try Capture.acquireDiagnostic(init, path, &encoded, &expanded, options.gzip, &capture_failure);
        sources[count] = captures[count].source();
        count += 1;
    }
    diagnostic.file = null;
    stage = .schema;
    var binding = try f.FileSource.discoverDiagnostic(init.gpa, sources[0..count], options.source, if (explicit) |owner| owner.type.structure else &.{}, &location);
    defer binding.deinit();
    stage = .compile;
    var context: f.Sql.Binding = .{};
    var compiled = f.FileQuery.compileDiagnostic(init.gpa, options.sql.?, "input", &binding, &context) catch |err| {
        diagnostic.sql = f.SqlDiagnostic.bound(options.sql.?, err, false, context);
        if (diagnostic.sql) |*failure| failure.hint = "Use the source name input and columns in the file schema. Run transit file-query --help for supported syntax, schema and type options.";
        return err;
    };
    defer compiled.deinit();
    var execution = try f.FileQuery.Execution.init(init.gpa, &binding, sources[0..count], compiled.plan);
    defer execution.deinit();
    stage = .execute;
    limited = compiled.plan.limit != null;
    errdefer {
        location = execution.scan.position();
        runtime_failure = execution.failure;
        if (!execution.scan.failed) location.field_len = 0;
    }
    var fields: [128]f.Types.Field = undefined;
    const schema = try compiled.plan.outputSchema(&fields);
    output_started = true;
    if (options.output == .arrow) return arrowOutput(init, &binding, &execution, schema, options.batch_rows);
    const basis = std.fmt.bytesToHex(binding.digest, .lower);
    const plan = std.fmt.bytesToHex(execution.fingerprint, .lower);
    var evidence_records: [20]u8 = undefined;
    var evidence_bytes: [20]u8 = undefined;
    try emit(init, .{ .definition = definition, .schema = f.LogicalJson.TypeEnvelope{ .definition = f.Types.definition, .type = schema }, .binding = &basis, .plan = &plan, .evidence = .{
        .records = try std.fmt.bufPrint(&evidence_records, "{d}", .{binding.evidence.records}),
        .sampled_bytes = try std.fmt.bufPrint(&evidence_bytes, "{d}", .{binding.evidence.sampled_bytes}),
        .complete = binding.evidence.complete,
    } }, &output_budget);
    while (try execution.next()) |owned| {
        var row = owned;
        defer row.deinit();
        const value = try f.LogicalJson.foreignCell(row.arena.allocator(), .{ .value = .{ .structure = row.cells } }, schema);
        try Capture.check(undefined);
        try emit(init, .{ .row = value }, &output_budget);
    }
    if (!execution.complete) return error.IncompleteSource;
    try Capture.check(undefined);
    var scanned: [20]u8 = undefined;
    var emitted: [20]u8 = undefined;
    try emit(init, .{ .complete = .{ .binding = &basis, .plan = &plan, .scanned = try std.fmt.bufPrint(&scanned, "{d}", .{execution.scanned}), .emitted = try std.fmt.bufPrint(&emitted, "{d}", .{execution.emitted}) } }, &output_budget);
}
fn arrowOutput(init: std.process.Init, binding: *const f.FileSource.Binding, execution: *f.FileQuery.Execution, schema: f.Types.Type, batch_rows: u8) !void {
    const workspace = try init.gpa.alloc(u8, f.LogicalArrow.working_bytes);
    defer init.gpa.free(workspace);
    const output = try init.gpa.alloc(u8, f.LogicalArrow.segment_bytes);
    defer init.gpa.free(output);
    try writeOutput(f.LogicalArrow.messages(schema, &.{}, .{ .batch = false, .end = false, .evidence = .{ .binding = binding.digest, .plan = execution.fingerprint, .records = binding.evidence.records, .sampled_bytes = binding.evidence.sampled_bytes, .complete = binding.evidence.complete } }, workspace, output) catch |err| return arrowError(err));
    var owners: [f.LogicalArrow.max_rows]f.FileSource.Row = undefined;
    var rows: [f.LogicalArrow.max_rows]f.LogicalArrow.Row = undefined;
    var count: usize = 0;
    defer for (owners[0..count]) |*owner| owner.deinit();
    while (try execution.next()) |row| {
        owners[count] = row;
        rows[count] = .{ .cells = row.cells };
        count += 1;
        if (count == batch_rows) {
            try arrowBatch(schema, rows[0..count], workspace, output);
            for (owners[0..count]) |*owner| owner.deinit();
            count = 0;
        }
    }
    if (count != 0) try arrowBatch(schema, rows[0..count], workspace, output);
    if (!execution.complete) return error.IncompleteSource;
    try Capture.check(undefined);
    try writeOutput(f.LogicalArrow.messages(schema, &.{}, .{ .schema = false, .batch = false }, workspace, output) catch |err| return arrowError(err));
}
fn arrowBatch(schema: f.Types.Type, rows: []const f.LogicalArrow.Row, workspace: []u8, output: []u8) anyerror!void {
    try Capture.check(undefined);
    const bytes = f.LogicalArrow.messages(schema, rows, .{ .schema = false, .end = false }, workspace, output) catch |err| {
        if ((err == error.WriteFailed or err == error.OutOfMemory) and rows.len > 1) {
            const middle = rows.len / 2;
            try arrowBatch(schema, rows[0..middle], workspace, output);
            return arrowBatch(schema, rows[middle..], workspace, output);
        }
        return arrowError(err);
    };
    try writeOutput(bytes);
}

fn arrowError(err: anyerror) anyerror {
    return switch (err) {
        error.WriteFailed => error.ArrowSegmentTooLarge,
        error.OutOfMemory => error.ArrowWorkspaceExceeded,
        else => err,
    };
}
