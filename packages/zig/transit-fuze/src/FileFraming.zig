//! Incremental CSV/JSONL framing over caller-supplied chunks. One record borrows
//! a caller-owned buffer. Release it before feeding again; no I/O is performed.
const std = @import("std");
const BudgetDiagnostic = @import("BudgetDiagnostic.zig");
pub const Format = enum { csv, jsonl };
pub const Dialect = struct {
    delimiter: u8 = ',',
    quote: u8 = '"',
    header: bool = true,
    null_tokens: []const []const u8 = &.{},
    pub fn validate(self: Dialect) !void {
        if (self.delimiter < 0x20 or self.delimiter >= 0x7f or self.quote < 0x20 or self.quote >= 0x7f or self.delimiter == self.quote) return error.InvalidDialect;
        if (self.null_tokens.len > 16) return error.InvalidDialect;
        var size: usize = 0;
        for (self.null_tokens, 0..) |token, i| {
            size += token.len;
            if (size > 1024 or !std.unicode.utf8ValidateSlice(token)) return error.InvalidDialect;
            for (self.null_tokens[0..i]) |earlier| if (std.mem.eql(u8, token, earlier)) return error.InvalidDialect;
        }
    }
};
pub const CsvState = enum { start, unquoted, quoted, after_quote };
pub const Framer = struct {
    format: Format,
    dialect: Dialect,
    buffer: []u8,
    length: usize = 0,
    ready: bool = false,
    ended: bool = false,
    failed: bool = false,
    state: CsvState = .start,
    carriage: bool = false,
    preamble: [3]u8 = undefined,
    preamble_length: u8 = 0,
    preamble_done: bool = false,
    prefix_bytes: u8 = 0,
    encoding_offset: ?usize = null,
    pub fn init(format: Format, dialect: Dialect, buffer: []u8) !Framer {
        try dialect.validate();
        if (buffer.len == 0 or buffer.len > 65536) return error.InvalidRecordBudget;
        return .{ .format = format, .dialect = dialect, .buffer = buffer };
    }
    /// Returns the consumed prefix. A ready record must be released before
    /// reusing its buffer; a caller can retain unconsumed bytes without copying.
    pub fn feed(self: *Framer, input: []const u8) !usize {
        if (self.ready or self.ended or self.failed) return error.InvalidFramerState;
        errdefer self.failed = true;
        for (input, 0..) |byte, i| {
            if (!self.preamble_done) {
                self.preamble[self.preamble_length] = byte;
                self.preamble_length += 1;
                if ((self.preamble_length == 1 and byte == 0xef) or (self.preamble_length == 2 and self.preamble[0] == 0xef and byte == 0xbb)) continue;
                self.preamble_done = true;
                if (self.preamble_length == 3 and std.mem.eql(u8, &self.preamble, "\xef\xbb\xbf")) {
                    self.prefix_bytes = 3;
                    continue;
                }
                for (self.preamble[0..self.preamble_length]) |initial| try self.push(initial);
            } else try self.push(byte);
            if (self.ready) return i + 1;
        }
        return input.len;
    }
    fn push(self: *Framer, byte: u8) !void {
        if (self.carriage) {
            if (byte != '\n') return error.InvalidLineEnding;
            self.carriage = false;
            self.ready = true;
            return;
        }
        if (self.format == .jsonl or self.state != .quoted) {
            if (byte == '\n') {
                self.ready = true;
                return;
            }
            if (byte == '\r') {
                self.carriage = true;
                return;
            }
        }
        if (self.length == self.buffer.len) return error.RecordTooLarge;
        self.buffer[self.length] = byte;
        self.length += 1;
        if (self.format == .csv) switch (self.state) {
            .start => {
                if (byte == self.dialect.quote) self.state = .quoted else if (byte != self.dialect.delimiter) self.state = .unquoted;
            },
            .unquoted => {
                if (byte == self.dialect.quote) return error.InvalidCsvQuote;
                if (byte == self.dialect.delimiter) self.state = .start;
            },
            .quoted => if (byte == self.dialect.quote) {
                self.state = .after_quote;
            },
            .after_quote => {
                if (byte == self.dialect.quote) self.state = .quoted else if (byte == self.dialect.delimiter) self.state = .start else return error.InvalidCsvQuote;
            },
        };
    }
    pub fn finish(self: *Framer) !void {
        if (self.ready or self.ended or self.failed) return error.InvalidFramerState;
        errdefer self.failed = true;
        if (!self.preamble_done) {
            self.preamble_done = true;
            for (self.preamble[0..self.preamble_length]) |initial| try self.push(initial);
        }
        if (self.carriage) return error.InvalidLineEnding;
        if (self.format == .csv and self.state == .quoted) return error.UnterminatedCsvQuote;
        self.ended = true;
        self.ready = self.length > 0;
    }
    pub fn record(self: *Framer) ![]u8 {
        if (!self.ready or self.failed) return error.InvalidFramerState;
        if (self.format == .jsonl and self.length == 0) return error.EmptyJsonRecord;
        self.encoding_offset = @import("JsonDiagnostic.zig").invalidUtf8Offset(self.buffer[0..self.length]);
        if (self.encoding_offset != null) return error.InvalidUtf8;
        return self.buffer[0..self.length];
    }
    pub fn release(self: *Framer) !void {
        if (!self.ready or self.failed) return error.InvalidFramerState;
        self.ready = false;
        self.length = 0;
        self.state = .start;
    }
};
pub const CsvField = struct { text: []const u8, quoted: bool, is_null: bool };
/// Decodes quoting in place. Returned text borrows record. All columns are
/// decoded/validated, including fields a later projection might discard.
pub fn csv(record: []u8, dialect: Dialect, output: []CsvField) ![]const CsvField {
    return csvDiagnostic(record, dialect, output, null);
}
pub fn csvDiagnostic(record: []u8, dialect: Dialect, output: []CsvField, diagnostic: ?*?BudgetDiagnostic) ![]const CsvField {
    try dialect.validate();
    if (!std.unicode.utf8ValidateSlice(record)) return error.InvalidUtf8;
    var input: usize = 0;
    var target: usize = 0;
    var count: usize = 0;
    while (true) {
        if (count == output.len) {
            BudgetDiagnostic.save(diagnostic, .{ .dimension = .record_fields, .required = count + 1, .limit = output.len, .minimum = true });
            return error.FieldBudgetExceeded;
        }
        const start = target;
        const quoted = input < record.len and record[input] == dialect.quote;
        if (quoted) {
            input += 1;
            var closed = false;
            while (input < record.len) {
                const byte = record[input];
                input += 1;
                if (byte == dialect.quote) {
                    if (input < record.len and record[input] == dialect.quote) {
                        input += 1;
                        record[target] = byte;
                        target += 1;
                    } else {
                        closed = true;
                        break;
                    }
                } else {
                    record[target] = byte;
                    target += 1;
                }
            }
            if (!closed) return error.UnterminatedCsvQuote;
            if (input < record.len and record[input] != dialect.delimiter) return error.InvalidCsvQuote;
        } else {
            while (input < record.len and record[input] != dialect.delimiter) {
                const byte = record[input];
                if (byte == dialect.quote or byte == '\r' or byte == '\n') return error.InvalidCsvQuote;
                record[target] = byte;
                target += 1;
                input += 1;
            }
        }
        const text = record[start..target];
        var is_null = false;
        if (!quoted) for (dialect.null_tokens) |token| {
            if (std.mem.eql(u8, token, text)) {
                is_null = true;
                break;
            }
        };
        output[count] = .{ .text = text, .quoted = quoted, .is_null = is_null };
        count += 1;
        if (input == record.len) break;
        input += 1;
    }
    return output[0..count];
}
test "CSV incremental chunks preserve quoted newlines escapes BOM null and empty fields" {
    const t = std.testing;
    const input = "\xef\xbb\xbfkey,value\r\n00123,\"a\r\nb\"\r\n2,\"escaped \"\"quote\"\"\"\n3,\n4,\"\"";
    for (1..input.len + 1) |width| {
        var buffer: [256]u8 = undefined;
        var framer = try Framer.init(.csv, .{ .null_tokens = &.{""} }, &buffer);
        var position: usize = 0;
        var rows: usize = 0;
        while (!framer.ended) {
            if (position < input.len) position += try framer.feed(input[position..@min(position + width, input.len)]) else try framer.finish();
            if (framer.ready) {
                var fields: [2]CsvField = undefined;
                const row = try csv(try framer.record(), framer.dialect, &fields);
                try t.expectEqual(@as(usize, 2), row.len);
                switch (rows) {
                    0 => try t.expectEqualStrings("key", row[0].text),
                    1 => {
                        try t.expectEqualStrings("00123", row[0].text);
                        try t.expectEqualStrings("a\r\nb", row[1].text);
                    },
                    2 => try t.expectEqualStrings("escaped \"quote\"", row[1].text),
                    3 => try t.expect(row[1].is_null),
                    4 => {
                        try t.expect(row[1].quoted);
                        try t.expect(!row[1].is_null);
                        try t.expectEqualStrings("", row[1].text);
                    },
                    else => return error.ExtraRecord,
                }
                rows += 1;
                try framer.release();
            }
        }
        try t.expectEqual(@as(usize, 5), rows);
    }
}
test "framing rejects malformed quotes line endings bounds and incomplete Unicode" {
    const t = std.testing;
    var buffer: [8]u8 = undefined;
    var framer = try Framer.init(.csv, .{}, &buffer);
    try t.expectError(error.RecordTooLarge, framer.feed("123456789"));
    framer = try Framer.init(.csv, .{}, &buffer);
    try t.expectError(error.InvalidCsvQuote, framer.feed("a\"b\n"));
    framer = try Framer.init(.csv, .{}, &buffer);
    _ = try framer.feed("\"a");
    try t.expectError(error.UnterminatedCsvQuote, framer.finish());
    framer = try Framer.init(.jsonl, .{}, &buffer);
    _ = try framer.feed("\n");
    try t.expectError(error.EmptyJsonRecord, framer.record());
    framer = try Framer.init(.csv, .{}, &buffer);
    _ = try framer.feed("\xef\xbb");
    try framer.finish();
    try t.expectError(error.InvalidUtf8, framer.record());
}
