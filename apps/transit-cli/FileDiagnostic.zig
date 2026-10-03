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
schema_file: bool = false,
schema_failure: ?f.Types.Diagnostic = null,
capture_failure: ?@import("FileCapture.zig").Failure = null,
output_budget: ?f.FileSource.BudgetDiagnostic = null,

pub fn render(self: Self, out: *std.Io.Writer, err: anyerror, style: @import("Style.zig")) !void {
    try style.text(out, .failure, "error: File Query Error");
    try out.print(":\n{s} ({s})\n", .{ if (self.location.conversion != null and err == error.Overflow) "The input scalar is outside the declared type's range." else self.explanation(err), @errorName(err) });
    if (self.output_budget orelse self.location.budget) |budget| {
        try out.print("Budget: {s}; required{s}: {d} {s}; limit: {d} {s}.\n", .{ @tagName(budget.dimension), if (budget.minimum) " at least" else "", budget.required, budget.unit(), budget.limit, budget.unit() });
    } else switch (err) {
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
    if (self.capture_failure) |capture| {
        try out.print("; operation: {s}", .{@tagName(capture.phase)});
        if (capture.storage()) if (capture.directory) |directory| {
            try out.writeAll("; temporary directory: ");
            try quoted(out, directory);
        };
    }
    if (self.location.record) |record| try out.print("; logical record: {d}", .{record});
    if (self.location.byte) |byte| try out.print("; record starts at byte: {d}", .{byte});
    if (self.location.field_len != 0) {
        try out.writeAll("; field: ");
        try quoted(out, self.location.field[0..self.location.field_len]);
        if (self.location.field_truncated) try out.writeAll(" [truncated]");
    }
    try out.writeAll(".\n");
    if (self.location.field_index) |index| try out.print("Field position (zero-based): {d}.\n", .{index});
    if (self.location.earlier_field_index) |index| try out.print("Conflicting earlier field position (zero-based): {d}.\n", .{index});
    if (self.location.unsupported_type) |kind| try out.print("Unsupported CSV field type: {s}. Use a supported scalar type or JSONL.\n", .{@tagName(kind)});
    if (self.schema_file and err == error.IncompatibleDefinition) try out.print("Required type definition: {s}.\n", .{f.Types.definition});
    if (self.location.json) |detail| {
        if (detail.path) |path| {
            try out.writeAll("JSON path (JSON Pointer): ");
            try quoted(out, path.slice());
            if (path.truncated) try out.writeAll(" [truncated]");
            try out.writeAll(".\n");
        }
        if (detail.offset) |offset| try out.print("{s} byte offset (zero-based): {d}.\n", .{ if (self.schema_file) "Schema" else "Record", self.location.prefix_bytes + offset });
        if (detail.earlier) |offset| try out.print("Earlier member byte offset in record (zero-based): {d}.\n", .{self.location.prefix_bytes + offset});
        try out.print("{s}\n", .{detail.constraint()});
    }
    if (self.schema_failure orelse self.location.descriptor orelse self.location.inference) |detail| {
        try out.writeAll(if (self.location.inference != null) "Discovery field path (JSON Pointer): " else "Descriptor path (JSON Pointer): ");
        try quoted(out, detail.path.slice());
        if (detail.path.truncated) try out.writeAll(" [truncated]");
        try out.print(".\n{s}\n", .{detail.constraint()});
        if (detail.offset) |offset| try out.print("Schema byte offset (zero-based): {d}.\n", .{offset});
        if (detail.expected_len != 0) try out.print("Expected: {s}.\n", .{detail.expectedType()});
        if (detail.value_len != 0 or detail.kind == .name_empty) {
            try out.writeAll("Supplied: ");
            try quoted(out, detail.supplied());
            if (detail.value_truncated) try out.writeAll(" [truncated]");
            try out.writeAll(".\n");
        }
        if (detail.actual) |actual| try out.print("Actual {s}: {d}.\n", .{ if (detail.kind == .duplicate_name) "field position (zero-based)" else "value/count", actual });
        if (detail.limit) |limit| try out.print("Maximum: {d}{s}{s}.\n", .{ limit, if (detail.unit() != null) " " else "", detail.unit() orelse "" });
        if (detail.earlier) |earlier| try out.print("Conflicting earlier field position (zero-based): {d}.\n", .{earlier});
    }
    if (self.location.discovery) |discovery| {
        try out.print("Discovery entered {d} records / {d} bytes; complete: {}.\n", .{ discovery.records, discovery.sampled_bytes, discovery.complete });
        if (err == error.UnresolvedSchema and !discovery.complete) try out.writeAll("Increase the discovery sample or use --mode full to inspect later records.\n");
    }
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
fn explanation(self: Self, err: anyerror) []const u8 {
    if (self.location.json) |detail| return detail.constraint();
    if (self.schema_failure orelse self.location.descriptor orelse self.location.inference) |detail| return detail.constraint();
    if (self.capture_failure) |capture| {
        if (capture.storage() and err != error.OutOfMemory and err != error.FileQueryInterrupted) return "Private temporary capture storage could not be opened, created, unlinked or written. Check TMPDIR access, capacity and the reported operation.";
    }
    if (self.schema_file) switch (err) {
        error.UnknownField, error.DuplicateField, error.MissingField, error.UnexpectedToken, error.InvalidEnumTag => return "The schema JSON does not match the logical type descriptor. Check its field names, tags and required members.",
        error.WriteFailed => return "The encoded logical schema exceeds its 16384-byte bound.",
        else => {},
    };
    return switch (err) {
        error.InvalidGzipChecksum => "The gzip checksum or decoded length does not match the captured input.",
        error.InvalidGzipHeader, error.InvalidGzipHeaderCrc => "The gzip header is invalid or fails its checksum.",
        error.GzipTrailingData => "The input contains trailing data after its single gzip member.",
        error.EndOfStream => "The captured input ended before its required framing was complete.",
        error.GzipHeaderTooLarge => "The gzip header exceeds its 65536-byte bound.",
        error.FileNotFound, error.SourceOpenFailed => "The selected source could not be opened. Check its path and read permissions.",
        error.NonRegularSourcePath => "The selected path is not a regular file. Pipe streaming input through stdin.",
        error.SourceReadFailed, error.ReadFailed => "The source could not be read completely.",
        error.CaptureQuotaExceeded => "The input exceeds the remaining encoded or expanded capture quota.",
        error.RaggedCsvRow => "The CSV record has a different field count from its header.",
        error.DuplicateField => "The input contains a duplicate field name.",
        error.UnknownField => "An input field is absent from the frozen schema.",
        error.MissingCsvHeader => "The CSV source has no required header.",
        error.UnresolvedSchema => "Discovery found no columns. Supply an explicit --schema or use --mode raw to query raw records.",
        error.UnterminatedCsvQuote => "A quoted CSV field reaches the end of the source without its closing quote.",
        error.InvalidCsvQuote => "CSV quoting is malformed. Quote complete fields and escape an embedded quote by doubling it.",
        error.InvalidUtf8 => "The input contains invalid UTF-8 bytes. Decode the source to UTF-8 before querying it.",
        error.NoSpaceLeft => "The filesystem has no space available for this operation.",
        error.OutOfMemory => "Memory allocation failed while processing the file query.",
        error.FileQueryInterrupted => "The local file query was interrupted. No completion marker was written.",
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
        error.FieldBudgetExceeded => "The input record or resolved schema exceeds the configured field-count limit.",
        error.HeaderNameBudgetExceeded => "The CSV header names exceed the total 4096-byte name budget.",
        error.EmptyJsonRecord => "The JSONL source contains an empty record. Each line must contain one JSON object.",
        error.InvalidLineEnding => "A carriage return outside a quoted CSV field must be followed by a line feed. Use LF or CRLF record endings.",
        error.InvalidFieldName => "A field name must be nonempty UTF-8, at most 255 bytes, and contain no NUL byte.",
        error.UnsupportedCsvType => "The declared field type cannot be decoded from CSV. Choose a supported scalar type or use JSONL.",
        error.UnsupportedLiteralType => "The input scalar cannot be decoded as the declared logical type.",
        error.IncompatibleDefinition => "The schema's logical type definition is incompatible with this build.",
        error.InvalidExplicitSchema => "The explicit schema must be a nonempty root struct within the configured field limit.",
        error.InvalidDecimal => "Decimal precision must be 1 to 38 and scale must not exceed precision.",
        error.InvalidFieldCount => "A struct or tagged union must declare 1 to 255 fields.",
        error.InvalidMapKey => "A map key must have a supported scalar logical type.",
        error.InvalidUnion => "Tagged-union variants cannot be optional.",
        error.InvalidEnumTag, error.MissingField, error.UnexpectedToken => "The schema JSON does not match the logical type descriptor. Check its field names, tags and required members.",
        error.InvalidJson, error.SyntaxError, error.UnexpectedEndOfInput => "The input is not complete, well-formed JSON.",
        error.InvalidCharacter, error.InvalidNumber, error.LengthMismatch => "The input value is outside its declared representation.",
        error.JsonByteBudgetExceeded => "The JSON input exceeds its byte budget.",
        error.JsonDepthExceeded => "The JSON input exceeds its nesting-depth budget.",
        error.JsonTokenBudgetExceeded => "The JSON input exceeds its syntax-token budget.",
        error.JsonFieldBudgetExceeded => "A JSON object exceeds the configured field-count limit.",
        error.InferenceDepthExceeded => "Schema discovery exceeds the 16-level nesting budget.",
        error.InferenceNameBudgetExceeded => "Schema discovery exceeds the 4096-byte field-name budget.",
        error.InferenceNodeBudgetExceeded => "Schema discovery exceeds the 256-node type budget.",
        error.InferenceWorkExceeded => "Schema discovery exceeds the representable observation count.",
        error.TypeBudgetExceeded => "The logical schema exceeds a type depth, node, name or encoded-byte budget.",
        error.ValueBudgetExceeded, error.CodecBudgetExceeded => "The logical value exceeds a recursive depth, size or child-count budget.",
        error.OutputRecordTooLarge => "The serialized result record exceeds the 262144-byte JSON output bound.",
        error.ArrowShapeTooLarge => "The logical schema or row exceeds the bounded Arrow shape profile.",
        error.ArrowSegmentTooLarge => "A single Arrow schema or row exceeds the 65536-byte encoded segment bound. Splitting batches cannot reduce this item further.",
        error.ArrowWorkspaceExceeded => "A single Arrow schema or row exceeds the 4194304-byte encoding workspace. Splitting batches cannot reduce this item further.",
        error.InvalidCode, error.InvalidMatch, error.WrongStoredBlockNlen, error.InvalidBlockType, error.InvalidDynamicBlockHeader, error.OversubscribedHuffmanTree, error.IncompleteHuffmanTree, error.MissingEndOfBlockCode => "The captured gzip member contains an invalid DEFLATE stream.",
        error.StreamTooLong => "The schema file exceeds the 65536-byte input bound.",
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
    const storage = if (self.capture_failure) |capture| capture.storage() and err != error.OutOfMemory and err != error.FileQueryInterrupted else false;
    const code: []const u8 = if (storage) "file.capture_storage_unavailable" else if (self.schema_file and err == error.WriteFailed) "file.schema_encoding_limit" else if (self.schema_file and (self.schema_failure == null or self.schema_failure.?.jsonMember()) and (err == error.UnknownField or err == error.DuplicateField or err == error.MissingField or err == error.UnexpectedToken or err == error.InvalidEnumTag)) "file.invalid_schema_descriptor" else switch (err) {
        error.RaggedCsvRow => "file.ragged_csv_row",
        error.DuplicateField => "file.duplicate_field",
        error.UnknownField => "file.unknown_field",
        error.MissingCsvHeader => "file.missing_csv_header",
        error.UnresolvedSchema => "file.unresolved_schema",
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
        error.Overflow => if (self.location.conversion != null or self.schema_failure != null) "file.scalar_out_of_range" else "file.arithmetic_overflow",
        error.RecordTooLarge => "file.record_byte_limit",
        error.SourceWorkExceeded => "file.record_count_limit",
        error.SourceBudgetExceeded => "file.scan_byte_limit",
        error.FieldBudgetExceeded => "file.field_count_limit",
        error.HeaderNameBudgetExceeded => "file.header_name_byte_limit",
        error.EmptyJsonRecord => "file.empty_json_record",
        error.InvalidLineEnding => "file.invalid_line_ending",
        error.InvalidFieldName => "file.invalid_field_name",
        error.UnsupportedCsvType => "file.unsupported_csv_type",
        error.UnsupportedLiteralType => "file.unsupported_literal_type",
        error.IncompatibleDefinition => "file.incompatible_type_definition",
        error.InvalidDecimal => "file.invalid_decimal_type",
        error.InvalidFieldCount => "file.invalid_schema_field_count",
        error.InvalidMapKey => "file.invalid_map_key_type",
        error.InvalidUnion => "file.invalid_union_type",
        error.InvalidEnumTag, error.MissingField, error.UnexpectedToken => "file.invalid_schema_descriptor",
        error.InvalidCharacter, error.InvalidNumber, error.LengthMismatch => "file.invalid_scalar_encoding",
        error.JsonByteBudgetExceeded => "file.json_byte_limit",
        error.JsonDepthExceeded => "file.json_depth_limit",
        error.JsonTokenBudgetExceeded => "file.json_token_limit",
        error.JsonFieldBudgetExceeded => "file.json_field_limit",
        error.InferenceDepthExceeded => "file.inference_depth_limit",
        error.InferenceNameBudgetExceeded => "file.inference_name_limit",
        error.InferenceNodeBudgetExceeded => "file.inference_node_limit",
        error.InferenceWorkExceeded => "file.inference_work_limit",
        error.TypeBudgetExceeded => "file.schema_limit",
        error.ValueBudgetExceeded, error.CodecBudgetExceeded => "file.value_limit",
        error.OutputRecordTooLarge => "file.output_record_limit",
        error.ArrowShapeTooLarge => "file.arrow_shape_limit",
        error.ArrowSegmentTooLarge => "file.arrow_segment_limit",
        error.ArrowWorkspaceExceeded => "file.arrow_workspace_limit",
        error.InvalidCode, error.InvalidMatch, error.WrongStoredBlockNlen, error.InvalidBlockType, error.InvalidDynamicBlockHeader, error.OversubscribedHuffmanTree, error.IncompleteHuffmanTree, error.MissingEndOfBlockCode => "file.invalid_deflate",
        error.StreamTooLong => "file.schema_file_limit",
        error.GzipHeaderTooLarge => "file.gzip_header_limit",
        error.CaptureQuotaExceeded => "file.capture_quota",
        error.SourceChanged => "file.source_changed",
        error.IncompleteSource => "file.incomplete_source",
        error.WriteFailed, error.BrokenPipe, error.OutputWriteFailed => "file.output_incomplete",
        error.InvalidJson, error.SyntaxError, error.UnexpectedEndOfInput => "file.invalid_json",
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
    const output = self.output_budget != null or err == error.ArrowShapeTooLarge or err == error.ArrowSegmentTooLarge or err == error.ArrowWorkspaceExceeded or err == error.BrokenPipe or err == error.OutputWriteFailed;
    const category: d.Category = if (storage) .unavailable else if (self.schema_file and err == error.WriteFailed) .limit else switch (err) {
        error.RecordTooLarge, error.SourceWorkExceeded, error.SourceBudgetExceeded, error.FieldBudgetExceeded, error.CaptureQuotaExceeded, error.GzipHeaderTooLarge, error.HeaderNameBudgetExceeded, error.JsonByteBudgetExceeded, error.JsonDepthExceeded, error.JsonTokenBudgetExceeded, error.JsonFieldBudgetExceeded, error.InferenceDepthExceeded, error.InferenceNameBudgetExceeded, error.InferenceNodeBudgetExceeded, error.InferenceWorkExceeded, error.TypeBudgetExceeded, error.ValueBudgetExceeded, error.CodecBudgetExceeded, error.OutputRecordTooLarge, error.ArrowShapeTooLarge, error.ArrowSegmentTooLarge, error.ArrowWorkspaceExceeded, error.StreamTooLong => .limit,
        error.UnsupportedCsvType, error.UnsupportedLiteralType => .unsupported,
        error.IncompatibleDefinition, error.InvalidCode, error.InvalidMatch, error.WrongStoredBlockNlen, error.InvalidBlockType, error.InvalidDynamicBlockHeader, error.OversubscribedHuffmanTree, error.IncompleteHuffmanTree, error.MissingEndOfBlockCode => .integrity,
        error.EmptyJsonRecord, error.InvalidLineEnding, error.InvalidJson, error.SyntaxError, error.UnexpectedEndOfInput, error.UnterminatedCsvQuote, error.InvalidCsvQuote, error.InvalidUtf8 => .syntax,
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
    }, .not_applicable, .none, if (self.location.conversion != null and err == error.Overflow) "The input scalar is outside the declared type's range." else self.explanation(err));
    value.cause = try d.Code.init(@errorName(switch (err) {
        error.ArrowSegmentTooLarge => error.WriteFailed,
        error.ArrowWorkspaceExceeded => error.OutOfMemory,
        else => err,
    }));
    try value.fact(.completion, .execution, .{ .boolean = false });
    if (self.path) |path| try @import("StructuredDiagnostic.zig").pathFact(&value, path);
    if (self.capture_failure) |capture| {
        try value.text(.operation, .execution, @tagName(capture.phase));
        if (storage) if (capture.directory) |directory| try bounded(&value, .scope, directory, false);
    }
    if (self.location.record) |record| try value.fact(.source_row, .execution, .{ .unsigned = .init(record) });
    if (self.location.byte) |byte| if (self.location.json == null or self.location.json.?.offset == null) try value.fact(.byte_offset, .execution, .{ .unsigned = .init(byte) });
    // A logical record can span physical lines. Its byte offset is a fact;
    // never invent line/column coordinates from its ordinal.
    if (self.location.json) |detail| {
        if (detail.path) |path| try bounded(&value, .field_path, path.slice(), path.truncated);
        if (detail.offset) |offset| try value.fact(.byte_offset, .execution, .{ .unsigned = .init((self.location.byte orelse 0) + self.location.prefix_bytes + offset) });
        if (detail.earlier) |offset| try value.fact(.first_occurrence, .execution, .{ .unsigned = .init((self.location.byte orelse 0) + self.location.prefix_bytes + offset) });
        try value.text(.constraint, .owner, detail.constraint());
    }
    if (self.schema_failure orelse self.location.descriptor orelse self.location.inference) |detail| {
        try bounded(&value, .field_path, detail.path.slice(), detail.path.truncated);
        if (detail.offset) |offset| try value.fact(.byte_offset, .caller, .{ .unsigned = .init(offset) });
        try value.text(.constraint, .schema, detail.constraint());
        if (detail.expected_len != 0) try value.text(.expected_type, .schema, detail.expectedType());
        if (detail.value_len != 0 or detail.kind == .name_empty) try bounded(&value, .supplied_value, detail.supplied(), detail.value_truncated);
        if (detail.earlier) |earlier| try value.fact(.first_occurrence, .schema, .{ .unsigned = .init(earlier) });
        if (detail.unit()) |unit| {
            try value.text(.budget, .owner, @tagName(detail.kind));
            try value.text(.unit, .owner, unit);
        }
        if (detail.actual) |actual| try value.fact(if (detail.unit() != null) .required else if (detail.kind == .duplicate_name) .column else .actual_count, .schema, .{ .unsigned = .init(actual) });
        if (detail.limit) |limit| try value.fact(.limit, .owner, .{ .unsigned = .init(limit) });
    } else if (self.location.conversion) |detail| {
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
    if (self.location.discovery) |discovery| {
        var text: [192]u8 = undefined;
        try value.text(.source_basis, .execution, try std.fmt.bufPrint(&text, "Discovery entered {d} records / {d} bytes; complete: {}", .{ discovery.records, discovery.sampled_bytes, discovery.complete }));
    }
    if (self.location.inference != null) try value.text(.schema_origin, .schema, "inferred");
    if (self.location.field_index) |index| try value.fact(.column, .execution, .{ .unsigned = .init(index) });
    if (self.location.earlier_field_index) |index| try value.fact(.first_occurrence, .execution, .{ .unsigned = .init(index) });
    if (self.location.unsupported_type) |kind| try value.text(.actual_type, .schema, @tagName(kind));
    if (self.schema_file and err == error.IncompatibleDefinition) try value.text(.expected_type, .owner, f.Types.definition);
    const budget: ?struct { []const u8, u64, []const u8 } = switch (err) {
        error.RecordTooLarge => .{ "record_bytes", self.max_record_bytes, "bytes" },
        error.SourceWorkExceeded => .{ "scan_records", self.max_records, "records" },
        error.SourceBudgetExceeded => .{ "scan_bytes", self.max_scan_bytes, "bytes" },
        error.ArrowSegmentTooLarge => .{ "arrow_segment_bytes", f.LogicalArrow.segment_bytes, "bytes" },
        error.ArrowWorkspaceExceeded => .{ "arrow_workspace_bytes", f.LogicalArrow.working_bytes, "bytes" },
        error.StreamTooLong => .{ "schema_file_bytes", 65536, "bytes" },
        error.WriteFailed => if (self.schema_file) .{ "schema_encoding_bytes", f.Types.max_encoding_bytes, "bytes" } else null,
        else => null,
    };
    if (self.output_budget orelse self.location.budget) |measured| {
        try value.text(.budget, .owner, @tagName(measured.dimension));
        try value.fact(.limit, .owner, .{ .unsigned = .init(measured.limit) });
        try value.fact(.required, .execution, .{ .unsigned = .init(measured.required) });
        try value.text(.unit, .owner, measured.unit());
        if (measured.minimum) try value.text(.constraint, .execution, "Required is the measured minimum at the stopping boundary; unread input may require more.");
    } else if (budget) |limit| {
        try value.text(.budget, .owner, limit[0]);
        try value.fact(.limit, .caller, .{ .unsigned = .init(limit[1]) });
        try value.absent(.required, .execution, .unrecorded);
        try value.text(.unit, .owner, limit[2]);
    }
    if (self.limited and self.stage == .execute) try value.text(.operation, .owner, "LIMIT does not skip validation of remaining file records.");
    if (category == .binding or category == .syntax or category == .unsupported) try value.action(.correct_input);
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
