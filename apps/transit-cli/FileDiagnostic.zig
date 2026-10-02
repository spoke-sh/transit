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

pub fn render(self: Self, out: *std.Io.Writer, err: anyerror, style: @import("Style.zig")) !void {
    try style.text(out, .failure, "error: File Query Error");
    try out.print(":\n{s} ({s})\n", .{ explanation(err), @errorName(err) });
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
