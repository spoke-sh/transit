//! Bounded semantic JSON construction. It preserves member order, duplicate keys
//! and number lexemes; output is a new representation, not raw-frame replay.
const std = @import("std");
const Profile = @import("Profile.zig");
const Event = @import("Event.zig").Event;
const Number = @import("JsonNumber.zig").State;
const Utf8 = @import("Utf8.zig");
const Hash = std.crypto.hash.sha2.Sha256;
const Self = @This();

pub const Token = union(enum) {
    object_start,
    object_end,
    array_start,
    array_end,
    key: []const u8,
    string: []const u8,
    number: []const u8,
    boolean: bool,
    null_value,
};
pub const Frame = struct { kind: enum { object, array }, has_value: bool = false, expects_value: bool = false };
const Pending = struct {
    prefix: []const u8,
    value: []const u8,
    suffix: []const u8,
    quoted: bool,
    stage: enum { prefix, value, suffix, end } = .prefix,
    offset: usize = 0,
    escaped: [6]u8 = undefined,
    escaped_len: usize = 0,
    escaped_offset: usize = 0,
    remaining: u64,

    fn byte(self: *Pending) u8 {
        while (true) switch (self.stage) {
            .prefix, .suffix => {
                const bytes = if (self.stage == .prefix) self.prefix else self.suffix;
                if (self.offset < bytes.len) {
                    const result = bytes[self.offset];
                    self.offset += 1;
                    return result;
                }
                self.offset = 0;
                self.stage = if (self.stage == .prefix) .value else .end;
            },
            .value => {
                if (self.escaped_offset < self.escaped_len) {
                    const result = self.escaped[self.escaped_offset];
                    self.escaped_offset += 1;
                    return result;
                }
                if (self.offset == self.value.len) {
                    self.offset = 0;
                    self.stage = .suffix;
                    continue;
                }
                const value = self.value[self.offset];
                self.offset += 1;
                if (self.quoted and (value == '"' or value == '\\' or value < 32)) {
                    self.escaped_offset = 0;
                    if (value < 32) {
                        const hex = "0123456789abcdef";
                        self.escaped = .{ '\\', 'u', '0', '0', hex[value >> 4], hex[value & 15] };
                        self.escaped_len = 6;
                    } else {
                        self.escaped[0] = '\\';
                        self.escaped[1] = value;
                        self.escaped_len = 2;
                    }
                    continue;
                }
                return value;
            },
            .end => unreachable,
        };
    }
};

part_id: u64,
profile: [32]u8,
limits: Profile.contract.Limits,
frames: []Frame,
depth: usize = 0,
root_seen: bool = false,
pending: ?Pending = null,
hash: Hash = .init(.{}),
encoded: u64 = 0,
expanded: u64 = 0,
nodes: u64 = 0,
work: u64 = 0,
failed: bool = false,
finished: ?Profile.contract.Part = null,

pub fn init(descriptor: Profile.contract.Descriptor, part_id: u64, frames: []Frame) !Self {
    try Profile.require(descriptor, .json);
    if (part_id == 0 or frames.len < descriptor.limits.depth) return error.DocumentWorkspaceTooSmall;
    return .{ .part_id = part_id, .profile = descriptor.digest, .limits = descriptor.limits, .frames = frames[0..descriptor.limits.depth] };
}

/// Borrows string/number/key bytes until needsDrain() is false. The caller must
/// drain before resetting a parser token buffer or submitting the next token.
pub fn begin(self: *Self, token: Token) !void {
    try self.requireActive();
    if (self.pending != null) return error.DocumentWriterBusy;
    self.prepare(token) catch |err| {
        self.failed = true;
        return err;
    };
}

/// Re-encode one parsed event. Its source coordinates are not relabeled as
/// output coordinates. Only the source Reader can certify source completion.
pub fn beginEvent(self: *Self, event: Event) !void {
    try self.requireActive();
    if (self.pending != null) return error.DocumentWriterBusy;
    errdefer self.failed = true;
    const close = event.kind == .object_end or event.kind == .array_end;
    if (event.detail.len != 0 or event.depth != (if (close and self.depth > 0) self.depth - 1 else self.depth)) return error.InvalidDocumentEvent;
    if ((event.kind == .object_start or event.kind == .object_end or event.kind == .array_start or event.kind == .array_end) and event.value.len != 0) return error.InvalidDocumentEvent;
    const token: Token = switch (event.kind) {
        .object_start => .object_start,
        .object_end => .object_end,
        .array_start => .array_start,
        .array_end => .array_end,
        .key => .{ .key = event.value },
        .string => .{ .string = event.value },
        .number => .{ .number = event.value },
        .boolean => if (std.mem.eql(u8, event.value, "true")) .{ .boolean = true } else if (std.mem.eql(u8, event.value, "false")) .{ .boolean = false } else return error.InvalidDocumentEvent,
        .null_value => if (std.mem.eql(u8, event.value, "null")) .null_value else return error.InvalidDocumentEvent,
        else => return error.InvalidDocumentEvent,
    };
    try self.begin(token);
}

fn prepare(self: *Self, token: Token) !void {
    var value: []const u8 = "";
    var prefix: []const u8 = "";
    var suffix: []const u8 = "";
    var quoted = false;
    const close = token == .object_end or token == .array_end;
    switch (token) {
        .key, .string => |bytes| {
            value = bytes;
            quoted = true;
            suffix = if (token == .key) "\":" else "\"";
        },
        .number => |bytes| value = bytes,
        .boolean => |boolean| value = if (boolean) "true" else "false",
        .null_value => value = "null",
        .object_start => value = "{",
        .object_end => value = "}",
        .array_start => value = "[",
        .array_end => value = "]",
    }
    const scalar = quoted or token == .number or token == .boolean or token == .null_value;
    if (scalar and value.len > self.limits.token_bytes) return error.DocumentTokenLimitExceeded;
    try self.charge(1 + if (scalar) @as(u64, value.len) else 0);
    var value_bytes: u64 = value.len;
    if (quoted) {
        var utf8: Utf8 = .{};
        for (value) |byte| {
            _ = try utf8.accept(byte);
            if (byte < 32) value_bytes += 5 else if (byte == '"' or byte == '\\') value_bytes += 1;
        }
        try utf8.finish();
    } else if (token == .number) try Number.validate(value);

    if (close) {
        if (self.depth == 0) return error.InvalidJsonSyntax;
        const frame = self.frames[self.depth - 1];
        if ((token == .object_end) != (frame.kind == .object) or frame.expects_value) return error.InvalidJsonSyntax;
        self.depth -= 1;
    } else if (token == .key) {
        if (self.depth == 0) return error.InvalidJsonSyntax;
        const frame = &self.frames[self.depth - 1];
        if (frame.kind != .object or frame.expects_value) return error.InvalidJsonSyntax;
        prefix = if (frame.has_value) ",\"" else "\"";
        frame.expects_value = true;
    } else {
        var comma = false;
        if (self.depth == 0) {
            if (self.root_seen) return error.TrailingDocumentBytes;
            self.root_seen = true;
        } else {
            const frame = &self.frames[self.depth - 1];
            if (frame.kind == .object and !frame.expects_value) return error.InvalidJsonSyntax;
            comma = frame.kind == .array and frame.has_value;
            frame.expects_value = false;
            frame.has_value = true;
        }
        prefix = if (quoted) (if (comma) ",\"" else "\"") else if (comma) "," else "";
        if (token == .object_start or token == .array_start) {
            if (self.depth == self.frames.len) return error.DocumentDepthLimitExceeded;
            self.frames[self.depth] = .{ .kind = if (token == .object_start) .object else .array };
            self.depth += 1;
        }
    }
    if (!close) {
        if (self.nodes == self.limits.nodes) return error.DocumentNodeLimitExceeded;
        self.nodes += 1;
    }
    if (scalar) {
        if (value.len > self.limits.expanded_bytes - self.expanded) return error.DocumentExpansionLimitExceeded;
        self.expanded += value.len;
    }
    const bytes = value_bytes + prefix.len + suffix.len;
    if (bytes > self.limits.input_bytes - self.encoded) return error.DocumentInputLimitExceeded;
    self.encoded += bytes;
    self.pending = .{ .prefix = prefix, .value = value, .suffix = suffix, .quoted = quoted, .remaining = bytes };
}

pub fn needsDrain(self: *const Self) bool {
    return self.pending != null;
}

/// Writes at most min(output.len, work_budget) bytes. No input is owned, and
/// output slices belong to the caller. A zero window/budget is a caller error.
pub fn drain(self: *Self, output: []u8, work_budget: u32) !usize {
    if (output.len == 0 or work_budget == 0) return error.InvalidDocumentWorkBudget;
    try self.requireActive();
    const pending = if (self.pending) |*pending| pending else return error.DocumentWriterNoToken;
    const count: usize = @intCast(@min(output.len, work_budget, pending.remaining));
    self.charge(count) catch |err| {
        self.failed = true;
        return err;
    };
    for (output[0..count]) |*byte| byte.* = pending.byte();
    self.hash.update(output[0..count]);
    pending.remaining -= count;
    if (pending.remaining == 0) self.pending = null;
    return count;
}

pub fn finish(self: *Self) !Profile.contract.Part {
    if (self.failed) return error.DocumentWriterFailed;
    if (self.finished) |part| return part;
    if (self.pending != null) return error.DocumentWriterBusy;
    if (!self.root_seen or self.depth != 0) {
        self.failed = true;
        return error.IncompleteDocumentFrame;
    }
    const part: Profile.contract.Part = .{
        .definition = @import("transit_protocol").Growth.current_definition,
        .profile = self.profile,
        .id = self.part_id,
        .bytes = self.encoded,
        .sha256 = self.hash.finalResult(),
        .coverage = .complete,
        .source = null,
    };
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
