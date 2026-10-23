//! File-query attribution, independent of result stdout and completion markers.
const std = @import("std");
const f = @import("transit_query").fuze;
const Self = @This();
pub const codes = @import("FileCodes.zig");
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
schema_read_failure: bool = false,
schema_failure: ?f.Types.Diagnostic = null,
capture_failure: ?@import("FileCapture.zig").Failure = null,
output_budget: ?f.FileSource.BudgetDiagnostic = null,

pub fn render(self: Self, out: *std.Io.Writer, err: anyerror, style: @import("cli_support").Style) !void {
    try style.text(out, .failure, "error: File Query Error");
    try out.print(":\n{s} ({s})\n", .{ if (self.location.conversion != null and err == error.Overflow) "The input scalar is outside the declared type's range." else self.explanation(err), @errorName(err) });
    if (self.capture_failure) |capture| {
        var cause_buffer: [64]u8 = undefined;
        if (capture.systemCause(&cause_buffer)) |cause| try out.print("System cause: {s} ({d}). {s}\n", .{ cause, capture.system_errno.?, capture.systemExplanation() });
    }
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
    if (self.schema_read_failure) return "The schema file could not be read completely. Check its path and local read permissions.";
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
    return codes.fromError(err).message;
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
    const code: []const u8 = if (self.schema_read_failure) "file.schema_read_unavailable" else if (err == error.EndOfStream and self.capture_failure != null and self.capture_failure.?.phase == .decompress) "file.invalid_gzip" else if (storage) "file.capture_storage_unavailable" else if (self.schema_file and err == error.WriteFailed) "file.schema_encoding_limit" else if (self.schema_file and (self.schema_failure == null or self.schema_failure.?.jsonMember()) and (err == error.UnknownField or err == error.DuplicateField or err == error.MissingField or err == error.UnexpectedToken or err == error.InvalidEnumTag)) "file.invalid_schema_descriptor" else if (err == error.Overflow and (self.location.conversion != null or self.schema_failure != null)) "file.scalar_out_of_range" else codes.fromError(err).code;
    const output = self.output_budget != null or err == error.ArrowShapeTooLarge or err == error.ArrowSegmentTooLarge or err == error.ArrowWorkspaceExceeded or err == error.BrokenPipe or err == error.OutputWriteFailed;
    const category: d.Category = if (self.schema_read_failure or storage) .unavailable else if (self.schema_file and err == error.WriteFailed) .limit else codes.fromError(err).category;
    var value = try d.init(code, category, if (self.schema_read_failure) .input else if (output) .output else switch (self.stage) {
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
    if (self.capture_failure) |capture| {
        var cause_buffer: [64]u8 = undefined;
        if (capture.systemCause(&cause_buffer)) |cause| value.cause = try d.Code.init(cause);
    }
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
    if (self.schema_read_failure) try value.action(.retry_read);
    if (category == .internal or err == error.InvalidColumnCount) try value.action(.contact_operator);
    if (category == .access) try value.action(.inspect_scope);
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
