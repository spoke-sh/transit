//! Semantic construction for the existing namespace-free XML grammar. Bounded
//! markup is staged in caller workspace before draining; no input is retained.
const std = @import("std");
const Profile = @import("Profile.zig");
const Event = @import("Event.zig").Event;
const Lexical = @import("XmlLexical.zig");
const Utf8 = @import("Utf8.zig");
const Self = @This();
pub const Token = union(enum) {
    element_start: []const u8,
    element_end,
    attribute: struct { name: []const u8, value: []const u8 },
    text: []const u8,
    comment: []const u8,
    processing_instruction: struct { name: []const u8, body: []const u8 },
};
pub const Frame = struct { name_len: usize };
pub const Attribute = struct { start: usize, len: usize };
pub const Workspace = struct { frames: []Frame, names: []u8, attributes: []Attribute, attribute_names: []u8, encoded: []u8 };

part_id: u64,
profile: [32]u8,
limits: Profile.contract.Limits,
workspace: Workspace,
depth: usize = 0,
root_seen: bool = false,
start_open: bool = false,
open_bytes: u64 = 0,
text_bytes: u64 = 0,
attribute_count: usize = 0,
attribute_bytes: usize = 0,
used: usize = 0,
offset: usize = 0,
hash: std.crypto.hash.sha2.Sha256 = .init(.{}),
encoded: u64 = 0,
expanded: u64 = 0,
nodes: u64 = 0,
work: u64 = 0,
failed: bool = false,
finished: ?Profile.contract.Part = null,

pub fn init(descriptor: Profile.contract.Descriptor, part_id: u64, workspace: Workspace) !Self {
    try Profile.require(descriptor, .xml);
    const limits = descriptor.limits;
    const names = std.math.mul(usize, limits.depth, limits.token_bytes) catch return error.DocumentWorkspaceTooSmall;
    const encoded = std.math.add(usize, limits.token_bytes, 1) catch return error.DocumentWorkspaceTooSmall;
    if (part_id == 0 or workspace.frames.len < limits.depth or workspace.names.len < names or
        workspace.attributes.len < limits.attributes or workspace.attribute_names.len < limits.token_bytes or
        workspace.encoded.len < encoded) return error.DocumentWorkspaceTooSmall;
    return .{ .part_id = part_id, .profile = descriptor.digest, .limits = limits, .workspace = .{
        .frames = workspace.frames[0..limits.depth],
        .names = workspace.names[0..names],
        .attributes = workspace.attributes[0..limits.attributes],
        .attribute_names = workspace.attribute_names[0..limits.token_bytes],
        .encoded = workspace.encoded[0..encoded],
    } };
}

pub fn begin(self: *Self, token: Token) !void {
    try self.requireActive();
    if (self.needsDrain()) return error.DocumentWriterBusy;
    self.prepare(token) catch |err| {
        self.failed = true;
        return if (err == error.WriteFailed) error.DocumentTokenLimitExceeded else err;
    };
}

pub fn beginEvent(self: *Self, event: Event) !void {
    try self.requireActive();
    if (self.needsDrain()) return error.DocumentWriterBusy;
    errdefer self.failed = true;
    const end = event.kind == .element_end;
    if (event.depth != (if (end and self.depth > 0) self.depth - 1 else self.depth)) return error.InvalidDocumentEvent;
    if (event.kind != .attribute and event.kind != .processing_instruction and event.detail.len != 0) return error.InvalidDocumentEvent;
    const token: Token = switch (event.kind) {
        .element_start => .{ .element_start = event.value },
        .element_end => blk: {
            if (self.depth == 0 or !std.mem.eql(u8, self.name(self.depth - 1), event.value)) return error.InvalidDocumentEvent;
            break :blk .element_end;
        },
        .attribute => .{ .attribute = .{ .name = event.value, .value = event.detail } },
        .text => .{ .text = event.value },
        .comment => .{ .comment = event.value },
        .processing_instruction => .{ .processing_instruction = .{ .name = event.value, .body = event.detail } },
        else => return error.InvalidDocumentEvent,
    };
    try self.begin(token);
}

fn prepare(self: *Self, token: Token) !void {
    try self.charge(1);
    var out: std.Io.Writer = .fixed(self.workspace.encoded);
    self.used = 0;
    self.offset = 0;
    var prefix: usize = 0;
    if (self.start_open and token != .attribute and token != .element_end) {
        try out.writeByte('>');
        prefix = 1;
        self.start_open = false;
    }
    switch (token) {
        .element_start => |value| {
            try self.checkName(value);
            if (self.depth == self.workspace.frames.len) return error.DocumentDepthLimitExceeded;
            if (self.depth == 0 and self.root_seen) return error.TrailingDocumentBytes;
            if (value.len + 3 > self.limits.token_bytes) return error.DocumentTokenLimitExceeded;
            const slot = self.workspace.names[self.depth * self.limits.token_bytes ..][0..value.len];
            @memcpy(slot, value);
            self.workspace.frames[self.depth] = .{ .name_len = value.len };
            self.depth += 1;
            self.root_seen = true;
            self.start_open = true;
            self.attribute_count = 0;
            self.attribute_bytes = 0;
            self.open_bytes = 1 + value.len;
            try out.writeByte('<');
            try out.writeAll(slot);
        },
        .attribute => |value| {
            if (!self.start_open) return error.InvalidXmlAttribute;
            try self.checkName(value.name);
            if (std.mem.eql(u8, value.name, "xmlns")) return error.UnsupportedXmlNamespace;
            try self.checkText(value.value);
            if (self.attribute_count == self.workspace.attributes.len) return error.DocumentAttributeLimitExceeded;
            for (self.workspace.attributes[0..self.attribute_count]) |previous| {
                try self.charge(value.name.len);
                if (std.mem.eql(u8, value.name, self.workspace.attribute_names[previous.start..][0..previous.len])) return error.DuplicateXmlAttribute;
            }
            if (value.name.len > self.workspace.attribute_names.len - self.attribute_bytes) return error.DocumentTokenLimitExceeded;
            @memcpy(self.workspace.attribute_names[self.attribute_bytes..][0..value.name.len], value.name);
            self.workspace.attributes[self.attribute_count] = .{ .start = self.attribute_bytes, .len = value.name.len };
            self.attribute_bytes += value.name.len;
            self.attribute_count += 1;
            try out.writeByte(' ');
            try out.writeAll(value.name);
            try out.writeAll("=\"");
            try escaped(&out, value.value, true);
            try out.writeByte('"');
            self.open_bytes += out.buffered().len;
            if (self.open_bytes + 2 > self.limits.token_bytes) return error.DocumentTokenLimitExceeded;
        },
        .element_end => {
            if (self.depth == 0) return error.InvalidXmlSyntax;
            self.depth -= 1;
            if (self.start_open) {
                try out.writeAll("/>");
                self.start_open = false;
            } else {
                try self.checkBytes(self.name(self.depth));
                try out.writeAll("</");
                try out.writeAll(self.name(self.depth));
                try out.writeByte('>');
            }
        },
        .text => |value| {
            if (self.depth == 0) return error.InvalidXmlSyntax;
            try self.checkText(value);
            try escaped(&out, value, false);
        },
        .comment => |value| {
            try self.checkText(value);
            if (std.mem.indexOf(u8, value, "--") != null or std.mem.endsWith(u8, value, "-") or std.mem.indexOfScalar(u8, value, '\r') != null) return error.InvalidXmlComment;
            try out.writeAll("<!--");
            try out.writeAll(value);
            try out.writeAll("-->");
        },
        .processing_instruction => |value| {
            try self.checkName(value.name);
            try self.checkText(value.body);
            if (std.ascii.eqlIgnoreCase(value.name, "xml")) return error.UnsupportedXmlDeclaration;
            if (std.mem.indexOf(u8, value.body, "?>") != null or std.mem.indexOfScalar(u8, value.body, '\r') != null or
                (value.body.len != 0 and std.ascii.isWhitespace(value.body[0]))) return error.InvalidXmlSyntax;
            try out.writeAll("<?");
            try out.writeAll(value.name);
            if (value.body.len != 0) {
                try out.writeByte(' ');
                try out.writeAll(value.body);
            }
            try out.writeAll("?>");
        },
    }
    const bytes = out.buffered().len;
    if (bytes - prefix > self.limits.token_bytes) return error.DocumentTokenLimitExceeded;
    if (token == .text) {
        self.text_bytes += bytes - prefix;
        if (self.text_bytes > self.limits.token_bytes) return error.DocumentTokenLimitExceeded;
    } else self.text_bytes = 0;
    if (bytes > self.limits.input_bytes - self.encoded) return error.DocumentInputLimitExceeded;
    if (token != .element_end) {
        if (self.nodes == self.limits.nodes) return error.DocumentNodeLimitExceeded;
        self.nodes += 1;
    }
    self.used = bytes;
    self.encoded += bytes;
}

fn escaped(out: *std.Io.Writer, value: []const u8, attribute: bool) !void {
    for (value) |byte| switch (byte) {
        '&' => try out.writeAll("&amp;"),
        '<' => try out.writeAll("&lt;"),
        '>' => try out.writeAll("&gt;"),
        '"' => if (attribute) try out.writeAll("&quot;") else try out.writeByte(byte),
        '\r' => try out.writeAll("&#13;"),
        '\n' => if (attribute) try out.writeAll("&#10;") else try out.writeByte(byte),
        '\t' => if (attribute) try out.writeAll("&#9;") else try out.writeByte(byte),
        else => try out.writeByte(byte),
    };
}

fn checkName(self: *Self, value: []const u8) !void {
    try self.checkBytes(value);
    try Lexical.requireName(value);
}
fn checkText(self: *Self, value: []const u8) !void {
    try self.checkBytes(value);
    var utf8: Utf8 = .{};
    for (value) |byte| if (try utf8.accept(byte)) |code| {
        if (!Lexical.xmlChar(code)) return error.InvalidXmlCharacter;
    };
    try utf8.finish();
}
fn checkBytes(self: *Self, value: []const u8) !void {
    if (value.len > self.limits.token_bytes) return error.DocumentTokenLimitExceeded;
    try self.charge(@as(u64, value.len) * 3);
    if (value.len > self.limits.expanded_bytes - self.expanded) return error.DocumentExpansionLimitExceeded;
    self.expanded += value.len;
}
fn name(self: *const Self, depth: usize) []const u8 {
    return self.workspace.names[depth * self.limits.token_bytes ..][0..self.workspace.frames[depth].name_len];
}

pub fn needsDrain(self: *const Self) bool {
    return self.offset != self.used;
}
pub fn drain(self: *Self, output: []u8, work_budget: u32) !usize {
    if (output.len == 0 or work_budget == 0) return error.InvalidDocumentWorkBudget;
    try self.requireActive();
    const count = @min(output.len, work_budget, self.used - self.offset);
    self.charge(count) catch |err| {
        self.failed = true;
        return err;
    };
    @memcpy(output[0..count], self.workspace.encoded[self.offset..][0..count]);
    self.hash.update(output[0..count]);
    self.offset += count;
    return count;
}
pub fn finish(self: *Self) !Profile.contract.Part {
    if (self.failed) return error.DocumentWriterFailed;
    if (self.finished) |part| return part;
    if (self.needsDrain()) return error.DocumentWriterBusy;
    if (!self.root_seen or self.depth != 0) {
        self.failed = true;
        return error.IncompleteDocumentFrame;
    }
    const part: Profile.contract.Part = .{ .definition = @import("transit_protocol").Growth.current_definition, .profile = self.profile, .id = self.part_id, .bytes = self.encoded, .sha256 = self.hash.finalResult(), .coverage = .complete, .source = null };
    self.finished = part;
    return part;
}
fn requireActive(self: *const Self) !void {
    if (self.failed) return error.DocumentWriterFailed;
    if (self.finished != null) return error.DocumentWriterComplete;
}
fn charge(self: *Self, amount: u64) !void {
    if (amount > self.limits.work - self.work) return error.DocumentWorkLimitExceeded;
    self.work += amount;
}
