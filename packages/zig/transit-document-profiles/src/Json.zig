//! Incremental RFC 8259 scalar reference parser. The caller supplies token and
//! depth buffers. No allocator, I/O, storage or global total-node array is used.
const std = @import("std");
const Profile = @import("Profile.zig");
const Event = @import("Event.zig").Event;
const Step = @import("Event.zig").Step;
const Self = @This();
const Utf8 = @import("Utf8.zig");

pub const Frame = struct {
    kind: enum { object, array },
    state: enum { key_or_end, key, colon, value_or_end, value, comma_or_end },
};
const Token = enum { none, string, number, literal };
const Number = enum { minus, zero, integer, dot, fraction, exponent_mark, exponent_sign, exponent };
const Escape = enum { none, escaped, hex, low_slash, low_u };

part_id: u64,
budget: Profile.Budget,
frames: []Frame,
token: []u8,
depth: usize = 0,
root_written: bool = false,
finished: bool = false,
failed: bool = false,
failure_offset: ?u64 = null,
mode: Token = .none,
used: usize = 0,
start: u64 = 0,
key: bool = false,
escape: Escape = .none,
hex_digits: u3 = 0,
hex_value: u16 = 0,
high_surrogate: ?u16 = null,
number: Number = .integer,
literal: []const u8 = "",
literal_index: usize = 0,
utf8: Utf8 = .{},

pub fn init(descriptor: Profile.contract.Descriptor, part_id: u64, frames: []Frame, token: []u8) !Self {
    try Profile.require(descriptor, .json);
    if (part_id == 0 or frames.len < descriptor.limits.depth or token.len < descriptor.limits.token_bytes)
        return error.DocumentWorkspaceTooSmall;
    return .{ .part_id = part_id, .budget = .{ .limits = descriptor.limits }, .frames = frames[0..descriptor.limits.depth], .token = token[0..descriptor.limits.token_bytes] };
}

/// `eof` describes the end of this input slice; keep passing its unconsumed tail
/// after an event/yield. Completion is emitted only after the entire frame and
/// trailing whitespace have been consumed. Any parse/refusal error is sticky.
pub fn next(self: *Self, input: []const u8, eof: bool, work: u32) !Step {
    if (work == 0) return error.InvalidDocumentWorkBudget;
    if (self.failed) return error.DocumentParserFailed;
    if (self.finished) {
        if (input.len != 0) return error.DocumentParserComplete;
        return .{ .consumed = 0, .result = .complete };
    }
    return self.advance(input, eof, work) catch |err| {
        self.failed = true;
        self.failure_offset = self.budget.offset;
        return err;
    };
}

fn advance(self: *Self, input: []const u8, eof: bool, work: u32) !Step {
    var i: usize = 0;
    while (i < input.len and i < work) {
        const c = input[i];
        if (self.mode == .number and !isNumberByte(c)) {
            if (!delimiter(c)) return error.InvalidJsonNumber;
            return .{ .consumed = i, .result = .{ .event = try self.finishNumber() } };
        }
        try self.budget.consume();
        i += 1;
        if (try self.byte(c)) |value| return .{ .consumed = i, .result = .{ .event = value } };
    }
    if (i != input.len) return .{ .consumed = i, .result = .yield };
    if (!eof) return .{ .consumed = i, .result = .need_input };
    if (self.mode == .number) return .{ .consumed = i, .result = .{ .event = try self.finishNumber() } };
    if (self.mode != .none or self.depth != 0 or !self.root_written) return error.IncompleteDocumentFrame;
    self.finished = true;
    return .{ .consumed = i, .result = .complete };
}

fn byte(self: *Self, c: u8) !?Event {
    switch (self.mode) {
        .string => return self.stringByte(c),
        .number => {
            try self.numberByte(c);
            return null;
        },
        .literal => {
            if (c != self.literal[self.literal_index]) return error.InvalidJsonLiteral;
            self.literal_index += 1;
            if (self.literal_index == self.literal.len) {
                try self.budget.output(self.literal.len);
                self.mode = .none;
                try self.afterValue();
                return self.event(if (self.literal[0] == 'n') .null_value else .boolean, self.literal);
            }
            return null;
        },
        .none => {},
    }
    if (whitespace(c)) return null;
    if (self.depth != 0) {
        const top = &self.frames[self.depth - 1];
        switch (top.state) {
            .colon => {
                if (c != ':') return error.InvalidJsonSyntax;
                top.state = .value;
                return null;
            },
            .comma_or_end => {
                if (c == ',') {
                    top.state = if (top.kind == .object) .key else .value;
                    return null;
                }
                if ((c == '}' and top.kind == .object) or (c == ']' and top.kind == .array)) return self.close(c);
                return error.InvalidJsonSyntax;
            },
            .key_or_end, .key => {
                if (c == '}' and top.state == .key_or_end) return self.close(c);
                if (c != '"') return error.InvalidJsonSyntax;
                self.beginString(true);
                return null;
            },
            .value_or_end => if (c == ']') return self.close(c),
            .value => {},
        }
    } else if (self.root_written) return error.TrailingDocumentBytes;
    self.start = self.budget.offset - 1;
    self.used = 0;
    switch (c) {
        '{', '[' => {
            if (self.depth == self.frames.len) return error.DocumentDepthLimitExceeded;
            try self.budget.node();
            try self.afterValue();
            const event_value = self.event(if (c == '{') .object_start else .array_start, "");
            self.frames[self.depth] = .{ .kind = if (c == '{') .object else .array, .state = if (c == '{') .key_or_end else .value_or_end };
            self.depth += 1;
            return event_value;
        },
        '"' => self.beginString(false),
        't', 'f', 'n' => {
            self.mode = .literal;
            self.literal = switch (c) {
                't' => "true",
                'f' => "false",
                else => "null",
            };
            if (self.literal.len > self.token.len) return error.DocumentTokenLimitExceeded;
            self.literal_index = 1;
            try self.budget.node();
        },
        '-', '0'...'9' => {
            self.mode = .number;
            self.number = if (c == '-') .minus else if (c == '0') .zero else .integer;
            try self.append(c);
            try self.budget.node();
        },
        else => return error.InvalidJsonSyntax,
    }
    return null;
}

fn beginString(self: *Self, key: bool) void {
    self.mode = .string;
    self.start = self.budget.offset - 1;
    self.used = 0;
    self.key = key;
    self.escape = .none;
    self.high_surrogate = null;
    self.utf8 = .{};
}

fn stringByte(self: *Self, c: u8) !?Event {
    switch (self.escape) {
        .low_slash => {
            if (c != '\\') return error.InvalidJsonUnicode;
            self.escape = .low_u;
        },
        .low_u => {
            if (c != 'u') return error.InvalidJsonUnicode;
            self.escape = .hex;
            self.hex_digits = 0;
            self.hex_value = 0;
        },
        .hex => {
            const value = std.fmt.charToDigit(c, 16) catch return error.InvalidJsonUnicode;
            self.hex_value = (self.hex_value << 4) | value;
            self.hex_digits += 1;
            if (self.hex_digits == 4) {
                const code: u21 = if (self.high_surrogate) |high| blk: {
                    if (self.hex_value < 0xdc00 or self.hex_value > 0xdfff) return error.InvalidJsonUnicode;
                    self.high_surrogate = null;
                    break :blk 0x10000 + ((@as(u21, high) - 0xd800) << 10) + (self.hex_value - 0xdc00);
                } else if (self.hex_value >= 0xd800 and self.hex_value <= 0xdbff) {
                    self.high_surrogate = self.hex_value;
                    self.escape = .low_slash;
                    return null;
                } else if (self.hex_value >= 0xdc00 and self.hex_value <= 0xdfff) return error.InvalidJsonUnicode else self.hex_value;
                var bytes: [4]u8 = undefined;
                const len = try std.unicode.utf8Encode(code, &bytes);
                for (bytes[0..len]) |b| try self.append(b);
                self.escape = .none;
            }
        },
        .escaped => {
            if (c == 'u') {
                self.escape = .hex;
                self.hex_digits = 0;
                self.hex_value = 0;
            } else {
                try self.append(switch (c) {
                    '"', '\\', '/' => c,
                    'b' => 8,
                    'f' => 12,
                    'n' => 10,
                    'r' => 13,
                    't' => 9,
                    else => return error.InvalidJsonEscape,
                });
                self.escape = .none;
            }
        },
        .none => switch (c) {
            '"' => {
                try self.utf8.finish();
                self.mode = .none;
                try self.budget.node();
                if (self.key) self.frames[self.depth - 1].state = .colon else try self.afterValue();
                return self.event(if (self.key) .key else .string, self.token[0..self.used]);
            },
            '\\' => {
                try self.utf8.finish();
                self.escape = .escaped;
            },
            0...31 => return error.InvalidJsonString,
            else => try self.append(c),
        },
    }
    return null;
}

fn append(self: *Self, c: u8) !void {
    if (self.used == self.token.len) return error.DocumentTokenLimitExceeded;
    if (self.mode == .string) _ = try self.utf8.accept(c);
    try self.budget.output(1);
    self.token[self.used] = c;
    self.used += 1;
}

fn afterValue(self: *Self) !void {
    if (self.depth == 0) {
        if (self.root_written) return error.TrailingDocumentBytes;
        self.root_written = true;
    } else {
        self.frames[self.depth - 1].state = .comma_or_end;
    }
}

fn close(self: *Self, c: u8) Event {
    self.start = self.budget.offset - 1;
    self.depth -= 1;
    return self.event(if (c == '}') .object_end else .array_end, "");
}

fn event(self: *Self, kind: @FieldType(Event, "kind"), value: []const u8) Event {
    return .{ .kind = kind, .span = .{ .part_id = self.part_id, .space = .raw, .byte_start = self.start, .byte_end = self.budget.offset }, .depth = @intCast(self.depth), .value = value };
}

fn finishNumber(self: *Self) !Event {
    switch (self.number) {
        .zero, .integer, .fraction, .exponent => {},
        else => return error.InvalidJsonNumber,
    }
    self.mode = .none;
    try self.afterValue();
    return self.event(.number, self.token[0..self.used]);
}

fn numberByte(self: *Self, c: u8) !void {
    self.number = switch (self.number) {
        .minus => switch (c) {
            '0' => .zero,
            '1'...'9' => .integer,
            else => return error.InvalidJsonNumber,
        },
        .zero => switch (c) {
            '.' => .dot,
            'e', 'E' => .exponent_mark,
            else => return error.InvalidJsonNumber,
        },
        .integer => switch (c) {
            '0'...'9' => .integer,
            '.' => .dot,
            'e', 'E' => .exponent_mark,
            else => return error.InvalidJsonNumber,
        },
        .dot => switch (c) {
            '0'...'9' => .fraction,
            else => return error.InvalidJsonNumber,
        },
        .fraction => switch (c) {
            '0'...'9' => .fraction,
            'e', 'E' => .exponent_mark,
            else => return error.InvalidJsonNumber,
        },
        .exponent_mark => switch (c) {
            '+', '-' => .exponent_sign,
            '0'...'9' => .exponent,
            else => return error.InvalidJsonNumber,
        },
        .exponent_sign => switch (c) {
            '0'...'9' => .exponent,
            else => return error.InvalidJsonNumber,
        },
        .exponent => switch (c) {
            '0'...'9' => .exponent,
            else => return error.InvalidJsonNumber,
        },
    };
    try self.append(c);
}

fn isNumberByte(c: u8) bool {
    return switch (c) {
        '0'...'9', '-', '+', '.', 'e', 'E' => true,
        else => false,
    };
}

fn whitespace(c: u8) bool {
    return c == ' ' or c == '\t' or c == '\r' or c == '\n';
}

fn delimiter(c: u8) bool {
    return whitespace(c) or c == ',' or c == ']' or c == '}';
}
