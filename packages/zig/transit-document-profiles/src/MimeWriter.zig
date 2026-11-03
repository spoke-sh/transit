//! Bounded MIME entity construction. Preserves unfolded field bytes and opaque
//! bodies; regenerated folding and source coordinates are not raw-frame replay.
const std = @import("std");
const Profile = @import("Profile.zig");
const Mime = @import("Mime.zig");
const Event = @import("Event.zig").Event;
const Hash = std.crypto.hash.sha2.Sha256;
const Self = @This();

pub const Token = union(enum) {
    field: struct { name: []const u8, value: []const u8 },
    headers_end,
    body: []const u8,
};
const Pending = struct { bytes: []const u8, offset: usize = 0 };

part_id: u64,
profile: [32]u8,
limits: Profile.contract.Limits,
header: []u8,
phase: enum { headers, body } = .headers,
fields: u32 = 0,
nodes: u64 = 0,
expanded: u64 = 0,
encoded: u64 = 0,
work: u64 = 0,
pending: ?Pending = null,
hash: Hash = .init(.{}),
failed: bool = false,
finished: ?Profile.contract.Part = null,

pub fn init(descriptor: Profile.contract.Descriptor, part_id: u64, header: []u8) !Self {
    try Profile.require(descriptor, .mime);
    if (part_id == 0 or header.len < descriptor.limits.token_bytes) return error.DocumentWorkspaceTooSmall;
    return .{ .part_id = part_id, .profile = descriptor.digest, .limits = descriptor.limits, .header = header[0..descriptor.limits.token_bytes] };
}

/// Fields are staged in header workspace. Body bytes are borrowed until fully
/// drained. Keep workspace exclusive and separate from token and output memory.
pub fn begin(self: *Self, token: Token) !void {
    try self.requireActive();
    if (self.pending != null) return error.DocumentWriterBusy;
    self.prepare(token) catch |err| {
        self.failed = true;
        return err;
    };
}

/// Drain before consuming a Candidate event or advancing its source Reader.
/// Completion of the new part never certifies unread or unverified source bytes.
pub fn beginEvent(self: *Self, event: Event) !void {
    try self.requireActive();
    if (self.pending != null) return error.DocumentWriterBusy;
    errdefer self.failed = true;
    if (event.depth != 0) return error.InvalidDocumentEvent;
    const token: Token = switch (event.kind) {
        .mime_field => .{ .field = .{ .name = event.value, .value = event.detail } },
        .mime_headers_end => if (event.value.len == 0 and event.detail.len == 0) .headers_end else return error.InvalidDocumentEvent,
        .mime_body => if (event.value.len != 0 and event.detail.len == 0) .{ .body = event.value } else return error.InvalidDocumentEvent,
        else => return error.InvalidDocumentEvent,
    };
    try self.begin(token);
}

fn prepare(self: *Self, token: Token) !void {
    try self.charge(1);
    var bytes: []const u8 = "";
    var expanded: usize = 0;
    switch (token) {
        .field => |field| {
            if (self.phase != .headers) return error.InvalidMimeFraming;
            if (self.fields == self.limits.attributes) return error.DocumentAttributeLimitExceeded;
            const size = std.math.add(usize, field.name.len, field.value.len) catch return error.DocumentTokenLimitExceeded;
            if (size > self.header.len or self.header.len - size < 3) return error.DocumentTokenLimitExceeded;
            if (field.name.len == 0) return error.InvalidMimeField;
            if (field.name.len >= Mime.maximum_line_bytes) return error.MimeLineLimitExceeded;
            for (field.name) |c| {
                try self.charge(1);
                if (!Mime.fieldNameByte(c)) return error.InvalidMimeField;
            }
            for (field.value) |c| {
                try self.charge(1);
                if (!Mime.fieldValueByte(c)) return error.InvalidMimeField;
            }
            var used: usize = 0;
            try self.append(&used, field.name);
            try self.append(&used, ":");
            var line = used;
            var offset: usize = 0;
            while (field.value.len - offset > Mime.maximum_line_bytes - line) {
                const capacity = Mime.maximum_line_bytes - line;
                var fold: ?usize = null;
                // Include capacity: a fold immediately after a full 998-byte
                // line is valid when the next byte is continuation whitespace.
                for (field.value[offset..][0 .. capacity + 1], 0..) |c, i| {
                    try self.charge(1);
                    if ((c == ' ' or c == '\t') and (line != 0 or i != 0)) fold = i;
                }
                const at = fold orelse return error.MimeLineLimitExceeded;
                try self.append(&used, field.value[offset..][0..at]);
                try self.append(&used, "\r\n");
                offset += at;
                line = 0;
            }
            try self.append(&used, field.value[offset..]);
            try self.append(&used, "\r\n");
            bytes = self.header[0..used];
            expanded = size;
            self.fields += 1;
            try self.node();
        },
        .headers_end => {
            if (self.phase != .headers) return error.InvalidMimeFraming;
            try self.node();
            self.phase = .body;
            bytes = "\r\n";
        },
        .body => |body| {
            if (self.phase != .body) return error.InvalidMimeFraming;
            if (body.len > self.limits.token_bytes) return error.DocumentTokenLimitExceeded;
            bytes = body;
            expanded = body.len;
        },
    }
    if (expanded > self.limits.expanded_bytes - self.expanded) return error.DocumentExpansionLimitExceeded;
    if (bytes.len > self.limits.input_bytes - self.encoded) return error.DocumentInputLimitExceeded;
    self.expanded += expanded;
    self.encoded += bytes.len;
    if (bytes.len != 0) self.pending = .{ .bytes = bytes };
}

fn append(self: *Self, used: *usize, bytes: []const u8) !void {
    if (bytes.len > self.header.len - used.*) return error.DocumentTokenLimitExceeded;
    @memcpy(self.header[used.*..][0..bytes.len], bytes);
    used.* += bytes.len;
}

fn node(self: *Self) !void {
    if (self.nodes == self.limits.nodes) return error.DocumentNodeLimitExceeded;
    self.nodes += 1;
}

pub fn needsDrain(self: *const Self) bool {
    return self.pending != null;
}

pub fn drain(self: *Self, output: []u8, work_budget: u32) !usize {
    if (output.len == 0 or work_budget == 0) return error.InvalidDocumentWorkBudget;
    try self.requireActive();
    const pending = if (self.pending) |*pending| pending else return error.DocumentWriterNoToken;
    const count = @min(output.len, work_budget, pending.bytes.len - pending.offset);
    self.charge(count) catch |err| {
        self.failed = true;
        return err;
    };
    @memcpy(output[0..count], pending.bytes[pending.offset..][0..count]);
    self.hash.update(output[0..count]);
    pending.offset += count;
    if (pending.offset == pending.bytes.len) self.pending = null;
    return count;
}

pub fn finish(self: *Self) !Profile.contract.Part {
    if (self.failed) return error.DocumentWriterFailed;
    if (self.finished) |part| return part;
    if (self.pending != null) return error.DocumentWriterBusy;
    if (self.phase != .body) {
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
