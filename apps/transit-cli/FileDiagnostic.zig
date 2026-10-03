//! File-query attribution, independent of result stdout and completion markers.
const std = @import("std");
const f = @import("transit_query").fuze;
const Self = @This();
pub const Stage = enum { capture, schema, compile, execute };
stage: Stage,
path: ?[]const u8,
location: f.FileSource.Location,
output_started: bool,
limited: bool,
max_record_bytes: u64,
max_records: u64,
max_scan_bytes: u64,
runtime_failure: ?f.FileQuery.Failure = null,

pub fn render(self: Self, out: *std.Io.Writer, err: anyerror, style: @import("Style.zig")) !void {
    try style.text(out, .failure, "error: File Query Error");
    try out.print(":\n{s} ({s})\n", .{ if (self.location.conversion != null and err == error.Overflow) "The input scalar is outside the declared type's range." else explanation(err), @errorName(err) });
    switch (err) {
        error.RecordTooLarge => try out.print("Configured record limit: {d} bytes.\n", .{self.max_record_bytes}),
        error.SourceWorkExceeded => try out.print("Configured scan limit: {d} data records.\n", .{self.max_records}),
        error.SourceBudgetExceeded => try out.print("Configured scan budget: {d} bytes.\n", .{self.max_scan_bytes}),
        else => {},
    }
    try out.print("Stage: {s}", .{@tagName(self.stage)});
    if (self.path) |path| {
        try out.writeAll("; file: ");
        try quoted(out, path);
    }
    if (self.location.record) |record| try out.print("; logical record: {d}", .{record});
    if (self.location.byte) |byte| try out.print("; record starts at byte: {d}", .{byte});
    if (self.location.field_len != 0) {
        try out.writeAll("; field: ");
        try quoted(out, self.location.field[0..self.location.field_len]);
        if (self.location.field_truncated) try out.writeAll(" [truncated]");
    }
    try out.writeAll(".\n");
    if (self.location.conversion) |detail| {
        try out.writeAll("Field path (JSON Pointer): ");
        try quoted(out, detail.path.slice());
        if (detail.path.truncated) try out.writeAll(" [truncated]");
        if (detail.map_key) try out.writeAll("; map key");
        try out.print(".\nExpected: {s}; actual: {s}.\n", .{ detail.expectedType(), @tagName(detail.actual) });
        if (detail.has_preview) {
            try out.writeAll("Supplied scalar: ");
            try quoted(out, detail.scalar());
            if (detail.preview_truncated) try out.writeAll(" [truncated after 128 bytes]");
            try out.writeAll(".\n");
        }
        if (detail.expected_count) |count| try out.print("Expected element/field count: {d}.\n", .{count});
        if (detail.actual_count) |count| try out.print("Actual element/field count: {d}.\n", .{count});
        if (detail.nullable) |nullable| try out.print("NULL permitted: {s}.\n", .{if (nullable) "yes" else "no"});
        if (detail.optional) |optional| try out.print("Missing field permitted: {s}.\n", .{if (optional) "yes" else "no"});
        if (detail.origin) |origin| try out.print("Schema origin: {s}.\n", .{@tagName(origin)});
        if (detail.origin != null) try out.print("Discovery examined {d} data records / {d} bytes; complete: {s}.\n", .{ detail.sampling_records, detail.sampling_bytes, if (detail.sampling_complete) "yes" else "no" });
        if (detail.origin == .inferred and !detail.sampling_complete) try out.writeAll("The schema was inferred from a prefix. Correct the value or specify a schema that represents the whole source.\n");
    }
    if (self.runtime_failure) |detail| {
        try out.print("Operation: {s}; scan row: {d}; column: ", .{ @tagName(detail.operation), detail.row });
        try quoted(out, detail.columnName());
        if (detail.column_truncated) try out.writeAll(" [truncated]");
        if (detail.instruction) |instruction| try out.print("; predicate instruction: {d}", .{instruction});
        try out.print(".\nExpected: {s}; cell state: {s}.\nBinding: {x}\nPlan: {x}\n", .{ detail.expectedType(), @tagName(detail.state), detail.binding, detail.plan });
    }
    if (self.output_started) try out.writeAll("Any emitted output is incomplete. Discard the prefix; no completion marker was written.\n");
    if (self.limited and self.stage == .execute) try out.writeAll("LIMIT does not skip required validation of the remaining file records.\n");
}
fn explanation(err: anyerror) []const u8 {
    return switch (err) {
        error.InvalidGzipChecksum => "The gzip checksum or decoded length does not match the captured input.",
        error.InvalidGzipHeader, error.InvalidGzipHeaderCrc => "The gzip header is invalid or fails its checksum.",
        error.GzipTrailingData => "The input contains trailing data after its single gzip member.",
        error.EndOfStream => "The captured input ended before its required framing was complete.",
        error.GzipHeaderTooLarge => "The gzip header exceeds its 65536-byte bound.",
        error.SourceOpenFailed => "The selected source could not be opened. Check its path and read permissions.",
        error.NonRegularSourcePath => "The selected path is not a regular file. Pipe streaming input through stdin.",
        error.SourceReadFailed, error.ReadFailed => "The source could not be read completely.",
        error.CaptureQuotaExceeded => "The input exceeds the remaining encoded or expanded capture quota.",
        error.RaggedCsvRow => "The CSV record has a different field count from its header.",
        error.DuplicateField => "The input contains a duplicate field name.",
        error.UnknownField => "An input field is absent from the frozen schema.",
        error.MissingCsvHeader => "The CSV source has no required header.",
        error.JsonObjectRequired => "Each JSONL record must be a JSON object.",
        error.InvalidLiteral, error.TypeMismatch => "The input value cannot be represented by its declared type.",
        error.Inexact => "The input value cannot be represented exactly by its declared type.",
        error.NonFiniteValue => "The input number is not finite; the declared type requires a finite value.",
        error.InvalidDate => "The input is not a valid date for the declared type.",
        error.InvalidTime => "The input is not a valid time for the declared type.",
        error.InvalidTimestamp => "The input timestamp does not match the declared civil or UTC type.",
        error.InvalidUuid => "The input is not a valid UUID.",
        error.NullNotAllowed => "The field is NULL, but its schema does not permit NULL.",
        error.MissingRequiredField => "A required field is missing from the input.",
        error.InvalidArrayLength => "The array length differs from its declared length.",
        error.MapKeyOrder => "The map has duplicate keys after conversion to the declared key type.",
        error.QueryTypeError => "The query encountered a type-error cell. Correct the input or handle that cell state explicitly.",
        error.QueryConflict => "The query encountered an unresolved conflict cell.",
        error.Overflow => "Checked query arithmetic exceeded the result type's range.",
        error.RecordTooLarge => "A logical input record exceeds the configured record-byte limit.",
        error.SourceWorkExceeded => "The source exceeds the configured record-count limit.",
        error.SourceBudgetExceeded => "The source exceeds the configured scan-byte budget.",
        error.FieldBudgetExceeded => "The input exceeds the configured field-count limit.",
        error.SourceChanged => "The captured input or frozen source binding failed identity verification.",
        error.IncompleteSource => "The input ended without successful source verification.",
        error.WriteFailed, error.BrokenPipe, error.OutputWriteFailed => "The result output could not be written completely.",
        else => "The file query could not complete; inspect the cause and source position below.",
    };
}
fn quoted(out: *std.Io.Writer, value: []const u8) !void {
    try out.writeByte('"');
    for (value[0..@min(value.len, 256)]) |byte| switch (byte) {
        '"', '\\' => {
            try out.writeByte('\\');
            try out.writeByte(byte);
        },
        0x20...0x21, 0x23...0x5b, 0x5d...0x7e => try out.writeByte(byte),
        else => try out.print("\\x{x:0>2}", .{byte}),
    };
    if (value.len > 256) try out.writeAll("...");
    try out.writeByte('"');
}

pub fn structured(self: Self, err: anyerror) !@import("transit_query").protocol.Diagnostic {
    const d = @import("transit_query").protocol.Diagnostic;
    const code: []const u8 = switch (err) {
        error.RaggedCsvRow => "file.ragged_csv_row",
        error.DuplicateField => "file.duplicate_field",
        error.UnknownField => "file.unknown_field",
        error.MissingCsvHeader => "file.missing_csv_header",
        error.JsonObjectRequired => "file.json_object_required",
        error.InvalidLiteral => "file.invalid_literal",
        error.TypeMismatch => "file.type_mismatch",
        error.Inexact => "file.inexact_value",
        error.NonFiniteValue => "file.nonfinite_value",
        error.InvalidDate => "file.invalid_date",
        error.InvalidTime => "file.invalid_time",
        error.InvalidTimestamp => "file.invalid_timestamp",
        error.InvalidUuid => "file.invalid_uuid",
        error.NullNotAllowed => "file.null_not_allowed",
        error.MissingRequiredField => "file.missing_required_field",
        error.InvalidArrayLength => "file.invalid_array_length",
        error.MapKeyOrder => "file.map_key_collision",
        error.QueryTypeError => "file.type_error_cell",
        error.QueryConflict => "file.conflict_cell",
        error.Overflow => if (self.location.conversion != null) "file.scalar_out_of_range" else "file.arithmetic_overflow",
        error.RecordTooLarge => "file.record_byte_limit",
        error.SourceWorkExceeded => "file.record_count_limit",
        error.SourceBudgetExceeded => "file.scan_byte_limit",
        error.FieldBudgetExceeded => "file.field_count_limit",
        error.GzipHeaderTooLarge => "file.gzip_header_limit",
        error.CaptureQuotaExceeded => "file.capture_quota",
        error.SourceChanged => "file.source_changed",
        error.IncompleteSource => "file.incomplete_source",
        error.WriteFailed, error.BrokenPipe, error.OutputWriteFailed => "file.output_incomplete",
        error.SyntaxError, error.UnexpectedEndOfInput => "file.invalid_json",
        error.UnterminatedCsvQuote, error.InvalidCsvQuote => "file.invalid_csv_quote",
        error.InvalidUtf8 => "file.invalid_utf8",
        error.InvalidExplicitSchema => "file.invalid_schema",
        error.InvalidGzipChecksum, error.InvalidGzipHeader, error.InvalidGzipHeaderCrc, error.GzipTrailingData, error.EndOfStream => "file.invalid_gzip",
        error.SourceOpenFailed, error.FileNotFound => "file.source_unavailable",
        error.NonRegularSourcePath => "file.nonregular_source",
        error.SourceReadFailed, error.ReadFailed => "file.read_failed",
        error.NoSpaceLeft => "file.storage_full",
        error.OutOfMemory => "file.memory_unavailable",
        error.FileQueryInterrupted => "file.interrupted",
        else => "file.internal_failure",
    };
    const output = err == error.WriteFailed or err == error.BrokenPipe or err == error.OutputWriteFailed;
    const category: d.Category = switch (err) {
        error.RecordTooLarge, error.SourceWorkExceeded, error.SourceBudgetExceeded, error.FieldBudgetExceeded, error.CaptureQuotaExceeded, error.GzipHeaderTooLarge => .limit,
        error.SourceChanged, error.IncompleteSource, error.InvalidGzipChecksum, error.InvalidGzipHeader, error.InvalidGzipHeaderCrc, error.GzipTrailingData, error.EndOfStream => .integrity,
        error.QueryConflict => .conflict,
        error.WriteFailed, error.BrokenPipe, error.OutputWriteFailed, error.SourceOpenFailed, error.FileNotFound, error.SourceReadFailed, error.ReadFailed, error.NoSpaceLeft, error.OutOfMemory => .unavailable,
        error.FileQueryInterrupted => .lifecycle,
        else => if (std.mem.eql(u8, code, "file.internal_failure")) .internal else .binding,
    };
    var value = try d.init(code, category, if (output) .output else switch (self.stage) {
        .capture => .input,
        .schema => .decode,
        .compile => .compile,
        .execute => if (self.location.conversion != null) .decode else .execute,
    }, .not_applicable, .none, if (self.location.conversion != null and err == error.Overflow) "The input scalar is outside the declared type's range." else explanation(err));
    value.cause = try d.Code.init(@errorName(err));
    try value.fact(.completion, .execution, .{ .boolean = false });
    if (self.path) |path| try @import("StructuredDiagnostic.zig").pathFact(&value, path);
    if (self.location.record) |record| try value.fact(.source_row, .execution, .{ .unsigned = .init(record) });
    if (self.location.byte) |byte| try value.fact(.byte_offset, .execution, .{ .unsigned = .init(byte) });
    // A logical record can span physical lines. Its byte offset is a fact;
    // never invent line/column coordinates from its ordinal.
    if (self.location.conversion) |detail| {
        try bounded(&value, .field_path, detail.path.slice(), detail.path.truncated);
        try value.text(.expected_type, .schema, detail.expectedType());
        try value.text(.actual_type, .execution, @tagName(detail.actual));
        if (detail.has_preview) try bounded(&value, .supplied_value, detail.scalar(), detail.preview_truncated);
        if (detail.expected_count) |count| try value.fact(.expected_count, .schema, .{ .unsigned = .init(count) });
        if (detail.actual_count) |count| try value.fact(.actual_count, .execution, .{ .unsigned = .init(count) });
        // These related scalar rules form one bounded explanation; no new
        // wire field or unsupported logical type is inferred from the value.
        var rules: [192]u8 = undefined;
        var rule: std.Io.Writer = .fixed(&rules);
        if (detail.nullable) |allowed| try rule.print("NULL allowed: {}; ", .{allowed});
        if (detail.optional) |allowed| try rule.print("missing allowed: {}; ", .{allowed});
        if (detail.map_key) try rule.writeAll("map key; ");
        if (rule.end != 0) try value.text(.constraint, .schema, rule.buffered());
        if (detail.origin) |origin| {
            try value.text(.schema_origin, .schema, @tagName(origin));
            var sample: [192]u8 = undefined;
            try value.text(.source_basis, .schema, try std.fmt.bufPrint(&sample, "Discovery examined {d} records / {d} bytes; complete: {}", .{ detail.sampling_records, detail.sampling_bytes, detail.sampling_complete }));
        }
    } else if (self.runtime_failure) |detail| {
        try value.text(.operation, .execution, @tagName(detail.operation));
        try bounded(&value, .column, detail.columnName(), detail.column_truncated);
        try value.text(.expected_type, .schema, detail.expectedType());
        try value.text(.actual_type, .execution, @tagName(detail.state));
        if (detail.instruction) |instruction| try value.fact(.expression, .execution, .{ .unsigned = .init(instruction) });
        try value.fact(.source_basis, .execution, .{ .digest = detail.binding });
        try value.fact(.proposal, .execution, .{ .digest = detail.plan });
    } else if (self.location.field_len != 0) try bounded(&value, .field_path, self.location.field[0..self.location.field_len], self.location.field_truncated);
    const budget: ?struct { []const u8, u64, []const u8 } = switch (err) {
        error.RecordTooLarge => .{ "record_bytes", self.max_record_bytes, "bytes" },
        error.SourceWorkExceeded => .{ "scan_records", self.max_records, "records" },
        error.SourceBudgetExceeded => .{ "scan_bytes", self.max_scan_bytes, "bytes" },
        else => null,
    };
    if (budget) |limit| {
        try value.text(.budget, .owner, limit[0]);
        try value.fact(.limit, .caller, .{ .unsigned = .init(limit[1]) });
        try value.absent(.required, .execution, .unrecorded);
        try value.text(.unit, .owner, limit[2]);
    }
    if (self.limited and self.stage == .execute) try value.text(.operation, .owner, "LIMIT does not skip validation of remaining file records.");
    if (category == .binding) try value.action(.correct_input);
    try value.validate();
    return value;
}
fn bounded(value: *@import("transit_query").protocol.Diagnostic, field: @import("transit_query").protocol.Diagnostic.Field, bytes: []const u8, truncated: bool) !void {
    const d = @import("transit_query").protocol.Diagnostic;
    if (!std.unicode.utf8ValidateSlice(bytes)) {
        var escaped: [256]u8 = undefined;
        var out: std.Io.Writer = .fixed(&escaped);
        try out.writeAll("escaped bytes: ");
        var copied: usize = 0;
        for (bytes) |byte| {
            if (out.buffer.len - out.end < 4) break;
            try out.print("\\x{x:0>2}", .{byte});
            copied += 1;
        }
        return value.add(.{ .field = field, .origin = .execution, .availability = if (truncated or copied < bytes.len) .truncated else .provided, .value = .{ .text = try d.Text.init(out.buffered()) } });
    }
    const text = try d.Text.truncate(bytes);
    try value.add(.{ .field = field, .origin = .execution, .availability = if (truncated or text.slice().len != bytes.len) .truncated else .provided, .value = .{ .text = text } });
}
