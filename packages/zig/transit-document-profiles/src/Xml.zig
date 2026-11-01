//! Bounded, incremental XML 1.0 UTF-8 subset. Tokens retain raw coordinates;
//! decoded values borrow caller workspace. DTDs and namespaces are refused.
const std = @import("std");
const Profile = @import("Profile.zig");
const Event = @import("Event.zig").Event;
const Step = @import("Event.zig").Step;
const Utf8 = @import("Utf8.zig");
const Self = @This();

pub const Frame = struct { name_len: usize };
pub const Attribute = struct { start: usize, name_end: usize, value_start: usize, value_end: usize, end: usize };
pub const Workspace = struct { frames: []Frame, names: []u8, attributes: []Attribute, raw: []u8, decoded: []u8 };
const Mode = enum { text, markup };
const Pending = enum { none, attributes, empty_end };

part_id: u64,
budget: Profile.Budget,
workspace: Workspace,
depth: usize = 0,
used: usize = 0,
start: u64 = 0,
mode: Mode = .text,
quote: u8 = 0,
root_seen: bool = false,
finished: bool = false,
failed: bool = false,
failure_offset: ?u64 = null,
pending: Pending = .none,
attribute_count: usize = 0,
attribute_index: usize = 0,
empty: bool = false,

pub fn init(descriptor: Profile.contract.Descriptor, part_id: u64, workspace: Workspace) !Self {
    try Profile.require(descriptor, .xml);
    const limits = descriptor.limits;
    const name_bytes = std.math.mul(usize, limits.depth, limits.token_bytes) catch return error.DocumentWorkspaceTooSmall;
    if (part_id == 0 or workspace.frames.len < limits.depth or workspace.names.len < name_bytes or
        workspace.attributes.len < limits.attributes or workspace.raw.len < limits.token_bytes or
        workspace.decoded.len < limits.token_bytes) return error.DocumentWorkspaceTooSmall;
    return .{ .part_id = part_id, .budget = .{ .limits = limits }, .workspace = .{
        .frames = workspace.frames[0..limits.depth],
        .names = workspace.names[0..name_bytes],
        .attributes = workspace.attributes[0..limits.attributes],
        .raw = workspace.raw[0..limits.token_bytes],
        .decoded = workspace.decoded[0..limits.token_bytes],
    } };
}

/// `work` bounds newly consumed input bytes. Finalizing one bounded token can
/// additionally scan at most token_bytes * (attributes + 4) bytes; all such
/// scans debit the total work budget. Events are provisional until complete.
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
    if (self.pending != .none) return .{ .consumed = 0, .result = .{ .event = try self.pendingEvent() } };
    var i: usize = 0;
    while (i < input.len and i < work) {
        const c = input[i];
        if (self.mode == .text and c == '<' and self.used != 0) {
            if (try self.textEvent()) |value| return .{ .consumed = i, .result = .{ .event = value } };
        }
        if (self.used == 0) self.start = self.budget.offset;
        try self.budget.consume();
        i += 1;
        if (self.used == self.workspace.raw.len) return error.DocumentTokenLimitExceeded;
        self.workspace.raw[self.used] = c;
        self.used += 1;
        if (self.mode == .text) {
            if (c == '<') {
                self.mode = .markup;
                self.quote = 0;
            }
        } else if (try self.markupComplete(c)) {
            if (try self.markupEvent()) |value| return .{ .consumed = i, .result = .{ .event = value } };
        }
    }
    if (i != input.len) return .{ .consumed = i, .result = .yield };
    if (!eof) return .{ .consumed = i, .result = .need_input };
    if (self.mode == .markup) return error.IncompleteDocumentFrame;
    if (self.used != 0) {
        if (try self.textEvent()) |value| return .{ .consumed = i, .result = .{ .event = value } };
    }
    if (!self.root_seen or self.depth != 0) return error.IncompleteDocumentFrame;
    self.finished = true;
    return .{ .consumed = i, .result = .complete };
}

fn markupComplete(self: *Self, c: u8) !bool {
    const raw = self.workspace.raw[0..self.used];
    if (raw.len < 2) return false;
    if (raw[1] == '!') {
        if (std.mem.startsWith(u8, "<!--", raw) or std.mem.startsWith(u8, "<![CDATA[", raw)) return false;
        if (std.mem.startsWith(u8, raw, "<!--")) return std.mem.endsWith(u8, raw, "-->");
        if (std.mem.startsWith(u8, raw, "<![CDATA[")) return std.mem.endsWith(u8, raw, "]]>");
        return error.UnsupportedXmlDeclaration;
    }
    if (raw[1] == '?') return std.mem.endsWith(u8, raw, "?>");
    if (self.quote != 0) {
        if (c == self.quote) self.quote = 0;
        if (c == '<') return error.InvalidXmlAttribute;
        return false;
    }
    if (c == '"' or c == '\'') self.quote = c;
    return c == '>' and self.quote == 0;
}

fn markupEvent(self: *Self) !?Event {
    const raw = self.workspace.raw[0..self.used];
    self.mode = .text;
    // Parsing names/attributes is linear, apart from bounded duplicate checks.
    try self.budget.chargeWork(raw.len);
    if (std.mem.startsWith(u8, raw, "<!--")) {
        const body = raw[4 .. raw.len - 3];
        if (std.mem.indexOf(u8, body, "--") != null or std.mem.endsWith(u8, body, "-")) return error.InvalidXmlComment;
        const value = try self.decode(body, false, false);
        try self.budget.node();
        const result = self.makeEvent(.comment, value, "", self.start, self.budget.offset, self.depth);
        self.used = 0;
        return result;
    }
    if (std.mem.startsWith(u8, raw, "<![CDATA[")) {
        if (self.depth == 0) return error.InvalidXmlSyntax;
        const value = try self.decode(raw[9 .. raw.len - 3], false, false);
        try self.budget.node();
        const result = self.makeEvent(.text, value, "", self.start, self.budget.offset, self.depth);
        self.used = 0;
        return result;
    }
    if (raw[1] == '?') return self.processingInstruction(raw);
    if (raw[1] == '/') {
        var index: usize = 2;
        const name_end = try readName(raw, &index);
        skipSpace(raw, &index);
        if (index != raw.len - 1 or self.depth == 0) return error.InvalidXmlSyntax;
        const name = raw[2..name_end];
        try self.budget.chargeWork(name.len);
        if (!std.mem.eql(u8, name, self.frameName(self.depth - 1))) return error.XmlElementMismatch;
        try self.budget.output(name.len);
        self.depth -= 1;
        self.used = 0;
        return self.makeEvent(.element_end, name, "", self.start, self.budget.offset, self.depth);
    }
    if (self.depth == self.workspace.frames.len) return error.DocumentDepthLimitExceeded;
    if (self.depth == 0 and self.root_seen) return error.TrailingDocumentBytes;
    var index: usize = 1;
    const name_end = try readName(raw, &index);
    const name = raw[1..name_end];
    self.attribute_count = 0;
    self.attribute_index = 0;
    self.empty = false;
    while (true) {
        const before = index;
        skipSpace(raw, &index);
        if (index == raw.len - 1) break;
        if (raw[index] == '/' and index + 1 == raw.len - 1) {
            self.empty = true;
            break;
        }
        if (before == index) return error.InvalidXmlAttribute;
        if (self.attribute_count == self.workspace.attributes.len) return error.DocumentAttributeLimitExceeded;
        const attr = try readAttribute(raw, &index);
        const attr_name = raw[attr.start..attr.name_end];
        if (std.mem.eql(u8, attr_name, "xmlns")) return error.UnsupportedXmlNamespace;
        for (self.workspace.attributes[0..self.attribute_count]) |previous| {
            try self.budget.chargeWork(attr_name.len);
            if (std.mem.eql(u8, attr_name, raw[previous.start..previous.name_end])) return error.DuplicateXmlAttribute;
        }
        self.workspace.attributes[self.attribute_count] = attr;
        self.attribute_count += 1;
    }
    try self.budget.output(name.len);
    const name_slot = self.workspace.names[self.depth * self.workspace.raw.len ..][0..name.len];
    @memcpy(name_slot, name);
    self.workspace.frames[self.depth] = .{ .name_len = name.len };
    try self.budget.node();
    const result = self.makeEvent(.element_start, name_slot, "", self.start, self.budget.offset, self.depth);
    self.depth += 1;
    self.root_seen = true;
    self.pending = if (self.attribute_count != 0) .attributes else if (self.empty) .empty_end else .none;
    if (self.pending == .none) self.used = 0;
    return result;
}

fn pendingEvent(self: *Self) !Event {
    if (self.pending == .empty_end) {
        self.depth -= 1;
        self.pending = .none;
        self.used = 0;
        return self.makeEvent(.element_end, self.frameName(self.depth), "", self.start, self.budget.offset, self.depth);
    }
    const attr = self.workspace.attributes[self.attribute_index];
    const name = self.workspace.raw[attr.start..attr.name_end];
    const value = try self.decode(self.workspace.raw[attr.value_start..attr.value_end], true, true);
    try self.budget.output(name.len);
    try self.budget.node();
    self.attribute_index += 1;
    if (self.attribute_index == self.attribute_count) {
        self.pending = if (self.empty) .empty_end else .none;
        if (self.pending == .none) self.used = 0;
    }
    return self.makeEvent(.attribute, name, value, self.start + attr.start, self.start + attr.end, self.depth);
}

fn processingInstruction(self: *Self, raw: []const u8) !?Event {
    var index: usize = 2;
    const name_end = try readName(raw, &index);
    const name = raw[2..name_end];
    const before = index;
    skipSpace(raw, &index);
    if (index != raw.len - 2 and index == before) return error.InvalidXmlSyntax;
    if (std.ascii.eqlIgnoreCase(name, "xml")) {
        if (!std.mem.eql(u8, name, "xml") or self.start != 0) return error.InvalidXmlDeclaration;
        var count: usize = 0;
        var encoding_seen = false;
        var standalone_seen = false;
        index = name_end;
        while (true) {
            const previous = index;
            skipSpace(raw, &index);
            if (index == raw.len - 2) break;
            if (index == previous) return error.InvalidXmlDeclaration;
            const attr = try readAttribute(raw, &index);
            const key = raw[attr.start..attr.name_end];
            const value = raw[attr.value_start..attr.value_end];
            if (count == 0) {
                if (!std.mem.eql(u8, key, "version") or !std.mem.eql(u8, value, "1.0")) return error.UnsupportedXmlDeclaration;
            } else if (std.mem.eql(u8, key, "encoding") and !encoding_seen and !standalone_seen) {
                if (!std.ascii.eqlIgnoreCase(value, "UTF-8")) return error.UnsupportedXmlEncoding;
                encoding_seen = true;
            } else if (std.mem.eql(u8, key, "standalone") and !standalone_seen) {
                if (!std.mem.eql(u8, value, "yes") and !std.mem.eql(u8, value, "no")) return error.InvalidXmlDeclaration;
                standalone_seen = true;
            } else return error.InvalidXmlDeclaration;
            count += 1;
        }
        if (count == 0) return error.InvalidXmlDeclaration;
        self.used = 0;
        return null;
    }
    const value = try self.decode(raw[index .. raw.len - 2], false, false);
    try self.budget.output(name.len);
    try self.budget.node();
    self.used = 0;
    return self.makeEvent(.processing_instruction, name, value, self.start, self.budget.offset, self.depth);
}

fn textEvent(self: *Self) !?Event {
    const raw = self.workspace.raw[0..self.used];
    if (self.depth == 0) {
        for (raw) |c| if (!space(c)) return error.InvalidXmlSyntax;
        self.used = 0;
        return null;
    }
    if (std.mem.indexOf(u8, raw, "]]>") != null) return error.InvalidXmlSyntax;
    const value = try self.decode(raw, true, false);
    try self.budget.node();
    self.used = 0;
    return self.makeEvent(.text, value, "", self.start, self.budget.offset, self.depth);
}

fn frameName(self: *Self, depth: usize) []const u8 {
    return self.workspace.names[depth * self.workspace.raw.len ..][0..self.workspace.frames[depth].name_len];
}

fn makeEvent(self: *Self, kind: @FieldType(Event, "kind"), value: []const u8, detail: []const u8, start: u64, end: u64, depth: usize) Event {
    return .{ .kind = kind, .value = value, .detail = detail, .depth = @intCast(depth), .span = .{
        .part_id = self.part_id,
        .space = .raw,
        .byte_start = start,
        .byte_end = end,
    } };
}

fn decode(self: *Self, raw: []const u8, entities: bool, attribute: bool) ![]const u8 {
    // Includes UTF-8 validation, entity scanning and output. The charge is a
    // conservative linear bound, independent of whether each path is exercised.
    try self.budget.chargeWork(@as(u64, raw.len) * 3);
    var utf8: Utf8 = .{};
    var index: usize = 0;
    var out: usize = 0;
    while (index < raw.len) {
        var c = raw[index];
        index += 1;
        if (entities and c == '&') {
            try utf8.finish();
            const end = std.mem.indexOfScalarPos(u8, raw, index, ';') orelse return error.InvalidXmlEntity;
            const code = try entity(raw[index..end]);
            var bytes: [4]u8 = undefined;
            const len = try std.unicode.utf8Encode(code, &bytes);
            @memcpy(self.workspace.decoded[out..][0..len], bytes[0..len]);
            out += len;
            index = end + 1;
            continue;
        }
        if (c == '\r') {
            if (index < raw.len and raw[index] == '\n') index += 1;
            c = '\n';
        }
        if (attribute and space(c)) c = ' ';
        if (try utf8.accept(c)) |code| if (!xmlChar(code)) return error.InvalidXmlCharacter;
        self.workspace.decoded[out] = c;
        out += 1;
    }
    try utf8.finish();
    try self.budget.output(out);
    return self.workspace.decoded[0..out];
}

fn readName(raw: []const u8, index: *usize) !usize {
    if (index.* >= raw.len or !nameStart(raw[index.*])) return error.InvalidXmlName;
    index.* += 1;
    while (index.* < raw.len and nameContinue(raw[index.*])) index.* += 1;
    if (index.* < raw.len and raw[index.*] == ':') return error.UnsupportedXmlNamespace;
    return index.*;
}

fn readAttribute(raw: []const u8, index: *usize) !Attribute {
    const start = index.*;
    const name_end = try readName(raw, index);
    skipSpace(raw, index);
    if (index.* >= raw.len or raw[index.*] != '=') return error.InvalidXmlAttribute;
    index.* += 1;
    skipSpace(raw, index);
    if (index.* >= raw.len or (raw[index.*] != '"' and raw[index.*] != '\'')) return error.InvalidXmlAttribute;
    const quote = raw[index.*];
    index.* += 1;
    const value_start = index.*;
    while (index.* < raw.len and raw[index.*] != quote) : (index.* += 1) {
        if (raw[index.*] == '<') return error.InvalidXmlAttribute;
    }
    if (index.* == raw.len) return error.IncompleteDocumentFrame;
    const value_end = index.*;
    index.* += 1;
    return .{ .start = start, .name_end = name_end, .value_start = value_start, .value_end = value_end, .end = index.* };
}

fn nameStart(c: u8) bool {
    return std.ascii.isAlphabetic(c) or c == '_';
}
fn nameContinue(c: u8) bool {
    return nameStart(c) or std.ascii.isDigit(c) or c == '.' or c == '-';
}
fn space(c: u8) bool {
    return c == ' ' or c == '\t' or c == '\r' or c == '\n';
}
fn skipSpace(raw: []const u8, index: *usize) void {
    while (index.* < raw.len and space(raw[index.*])) index.* += 1;
}
fn xmlChar(c: u21) bool {
    return c == 9 or c == 10 or c == 13 or (c >= 0x20 and c <= 0xd7ff) or (c >= 0xe000 and c <= 0xfffd) or (c >= 0x10000 and c <= 0x10ffff);
}

fn entity(raw: []const u8) !u21 {
    // The five predefined names have unique (length, first-byte) slots.
    const predefined: ?u21 = switch (raw.len) {
        2 => switch (raw[0]) {
            'l' => if (std.mem.eql(u8, raw, "lt")) '<' else null,
            'g' => if (std.mem.eql(u8, raw, "gt")) '>' else null,
            else => null,
        },
        3 => if (std.mem.eql(u8, raw, "amp")) '&' else null,
        4 => switch (raw[0]) {
            'a' => if (std.mem.eql(u8, raw, "apos")) '\'' else null,
            'q' => if (std.mem.eql(u8, raw, "quot")) '"' else null,
            else => null,
        },
        else => null,
    };
    const value: u21 = if (predefined) |code| code else if (raw.len >= 2 and raw[0] == '#') blk: {
        const hex = raw[1] == 'x';
        const digits = raw[if (hex) @as(usize, 2) else 1..];
        if (digits.len == 0) return error.InvalidXmlEntity;
        var code: u32 = 0;
        for (digits) |c| {
            const digit = std.fmt.charToDigit(c, if (hex) 16 else 10) catch return error.InvalidXmlEntity;
            code = std.math.mul(u32, code, if (hex) 16 else 10) catch return error.InvalidXmlEntity;
            code = std.math.add(u32, code, digit) catch return error.InvalidXmlEntity;
        }
        if (code > 0x10ffff) return error.InvalidXmlCharacter;
        break :blk @intCast(code);
    } else return error.UnsupportedXmlEntity;
    if (!xmlChar(value)) return error.InvalidXmlCharacter;
    return value;
}
