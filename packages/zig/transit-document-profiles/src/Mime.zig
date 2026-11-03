//! MIME entity framing only: ordered ASCII fields, a mandatory CRLF separator
//! and an opaque binary body. No field semantics, decoding or transport authority.
const Profile = @import("Profile.zig");
const Event = @import("Event.zig").Event;
const Step = @import("Event.zig").Step;
const Self = @This();

pub const Workspace = struct { raw: []u8, unfolded: []u8 };
pub const maximum_line_bytes = 998;
const State = enum { start, name, value, line_lf, after_line, separator_lf, body };

part_id: u64,
budget: Profile.Budget,
workspace: Workspace,
state: State = .start,
used: usize = 0,
name_end: usize = 0,
line_bytes: usize = 0,
fields: u32 = 0,
start: u64 = 0,
finished: bool = false,
failed: bool = false,
failure_offset: ?u64 = null,

pub fn init(descriptor: Profile.contract.Descriptor, part_id: u64, workspace: Workspace) !Self {
    try Profile.require(descriptor, .mime);
    const size = descriptor.limits.token_bytes;
    if (part_id == 0 or workspace.raw.len < size or workspace.unfolded.len < size)
        return error.DocumentWorkspaceTooSmall;
    return .{ .part_id = part_id, .budget = .{ .limits = descriptor.limits }, .workspace = .{
        .raw = workspace.raw[0..size],
        .unfolded = workspace.unfolded[0..size],
    } };
}

/// Consumes at most work input bytes; finalizing one field additionally scans
/// at most token_bytes bytes, charged to the cumulative work budget. Returned
/// slices borrow workspace until the next call, never the input slice.
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
    if (self.state == .body and input.len != 0) {
        const count = @min(input.len, work, self.workspace.raw.len);
        const start = self.budget.offset;
        for (input[0..count]) |_| try self.budget.consume();
        try self.budget.output(count);
        @memcpy(self.workspace.raw[0..count], input[0..count]);
        return .{ .consumed = count, .result = .{ .event = self.event(.mime_body, start, self.budget.offset, self.workspace.raw[0..count], "") } };
    }
    var i: usize = 0;
    while (i < input.len and i < work) {
        const c = input[i];
        if (self.state == .after_line) {
            if (c != ' ' and c != '\t') return .{ .consumed = i, .result = .{ .event = try self.field() } };
            self.state = .value;
        }
        try self.budget.consume();
        i += 1;
        switch (self.state) {
            .start => {
                self.start = self.budget.offset - 1;
                self.used = 0;
                self.line_bytes = 0;
                if (c == '\r') {
                    self.state = .separator_lf;
                } else {
                    if (!nameByte(c)) return error.InvalidMimeField;
                    if (self.fields == self.budget.limits.attributes) return error.DocumentAttributeLimitExceeded;
                    try self.budget.node();
                    self.fields += 1;
                    try self.append(c);
                    self.state = .name;
                }
            },
            .name => {
                if (c == ':') {
                    self.name_end = self.used;
                    self.state = .value;
                } else if (!nameByte(c)) return error.InvalidMimeField;
                try self.append(c);
            },
            .value => {
                if (c == '\r') {
                    self.state = .line_lf;
                } else if (c != '\t' and (c < 32 or c > 126)) return error.InvalidMimeField;
                try self.append(c);
            },
            .line_lf => {
                if (c != '\n') return error.InvalidMimeFraming;
                try self.append(c);
                self.line_bytes = 0;
                self.state = .after_line;
            },
            .separator_lf => {
                if (c != '\n') return error.InvalidMimeFraming;
                // One logical body, including an empty body. Fetch windows do
                // not change the semantic node count or admission budget.
                try self.budget.node();
                self.state = .body;
                return .{ .consumed = i, .result = .{ .event = self.event(.mime_headers_end, self.start, self.budget.offset, "", "") } };
            },
            .after_line, .body => unreachable,
        }
    }
    if (i != input.len) return .{ .consumed = i, .result = .yield };
    if (!eof) return .{ .consumed = i, .result = .need_input };
    if (self.state != .body) return error.IncompleteDocumentFrame;
    self.finished = true;
    return .{ .consumed = i, .result = .complete };
}

fn append(self: *Self, c: u8) !void {
    if (self.used == self.workspace.raw.len) return error.DocumentTokenLimitExceeded;
    if (c != '\r' and c != '\n') {
        if (self.line_bytes == maximum_line_bytes) return error.MimeLineLimitExceeded;
        self.line_bytes += 1;
    }
    self.workspace.raw[self.used] = c;
    self.used += 1;
}

fn field(self: *Self) !Event {
    // The final CRLF is framing; every earlier CRLF was followed by WSP and
    // belongs to the folded field's exact raw span.
    const end = self.used - 2;
    try self.budget.chargeWork(end - self.name_end - 1);
    var written: usize = 0;
    var i = self.name_end + 1;
    while (i < end) : (i += 1) {
        if (self.workspace.raw[i] == '\r') {
            i += 1; // Skip only CRLF, preserving the continuation whitespace.
        } else {
            self.workspace.unfolded[written] = self.workspace.raw[i];
            written += 1;
        }
    }
    try self.budget.output(self.name_end + written);
    self.state = .start;
    return self.event(.mime_field, self.start, self.budget.offset - 2, self.workspace.raw[0..self.name_end], self.workspace.unfolded[0..written]);
}

fn event(self: *const Self, kind: @FieldType(Event, "kind"), start: u64, end: u64, value: []const u8, detail: []const u8) Event {
    return .{ .kind = kind, .span = .{ .part_id = self.part_id, .space = .raw, .byte_start = start, .byte_end = end }, .depth = 0, .value = value, .detail = detail };
}

fn nameByte(c: u8) bool {
    return c >= 33 and c <= 126 and c != ':';
}
