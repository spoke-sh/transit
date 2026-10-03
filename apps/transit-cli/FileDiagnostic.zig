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
        error.WriteFailed, error.BrokenPipe => "The result output could not be written completely.",
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
