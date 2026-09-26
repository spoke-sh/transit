//! Replay only reads committed bytes. No socket, DNS or credential capability is
//! accepted here. Every returned prefix is provisional until `complete` is true.
const std = @import("std");
const http = @import("root.zig");
const x = http.exchange;
const Self = @This();
client: *x.Client,
reference: x.Client.Reference,
cursor: x.Exchange.Cursor,
validator: Validator,
done: bool = false,
failed: bool = false,
pub const Policy = enum { captured, require_unredacted };
pub const Part = struct { kind: http.Kind, bytes: x.p.Value, complete: bool };
pub fn open(client: *x.Client, reference: x.Client.Reference, policy: Policy) !Self {
    const cursor = try client.open(reference);
    if (cursor.descriptor.protocol != http.protocol_format) return error.WrongExchangeProtocol;
    return .{ .client = client, .reference = reference, .cursor = cursor, .validator = .{ .terminal_status = cursor.descriptor.terminal_code, .policy = policy } };
}
pub fn read(self: *Self) !?Part {
    if (self.failed) return error.HttpReplayFailed;
    if (self.done) return null;
    errdefer self.failed = true;
    const part = try self.client.read(self.reference, self.cursor);
    const kind = std.enums.fromInt(http.Kind, part.kind) orelse return error.InvalidHttpCapture;
    try self.validator.push(kind, part.bytes.slice());
    if (part.next) |cursor| self.cursor = cursor else {
        _ = try self.validator.finish();
        self.done = true;
    }
    return .{ .kind = kind, .bytes = part.bytes, .complete = self.done };
}
/// A bounded protocol validator layered over the shared digest/coverage reader.
/// Direct users must independently verify the exchange commitment before trusting
/// its result. Feed records in order; splitting records into chunks is supported.
pub const Validator = struct {
    terminal_status: u32,
    policy: Policy = .captured,
    current: ?http.Kind = null,
    buffer: [http.Request.maximum_head_bytes]u8 = undefined,
    used: usize = 0,
    template_bytes: u64 = 0,
    request_bytes: u64 = 0,
    response_bytes: u64 = 0,
    request_length: ?u64 = null,
    response_length: ?u64 = null,
    is_head: bool = false,
    heads: u8 = 0,
    status: u16 = 0,
    omission: ?http.Omission = null,
    completion: ?http.Completion = null,
    pub fn push(self: *Validator, kind: http.Kind, bytes: []const u8) !void {
        if (self.completion != null) return error.InvalidHttpCapture;
        if (self.current != kind) {
            if (self.current) |old| {
                try self.end(old);
                const allowed = switch (old) {
                    .request_template => kind == .request_head,
                    .request_head => kind == .request_body,
                    .request_body => kind == .response_head,
                    .response_head => kind == .response_body,
                    .response_body => kind == .response_trailers or kind == .timing,
                    .response_trailers => kind == .timing,
                    .timing => kind == .omission,
                    .omission => kind == .completion,
                    .completion => false,
                };
                if (!allowed) return error.HttpReplayGap;
            } else if (kind != .request_template) return error.HttpReplayGap;
            self.current = kind;
            self.used = 0;
        }
        switch (kind) {
            .request_template => self.template_bytes = try std.math.add(u64, self.template_bytes, bytes.len),
            .request_body => self.request_bytes = try std.math.add(u64, self.request_bytes, bytes.len),
            .response_body => self.response_bytes = try std.math.add(u64, self.response_bytes, bytes.len),
            .response_head => for (bytes) |byte| {
                if (self.used == self.buffer.len or self.status != 0) return error.InvalidHttpCapture;
                self.buffer[self.used] = byte;
                self.used += 1;
                if (std.mem.endsWith(u8, self.buffer[0..self.used], "\r\n\r\n")) {
                    const head = self.buffer[0..self.used];
                    if (head.len < 17 or !std.mem.startsWith(u8, head, "HTTP/1.1 ") or head[12] != ' ') return error.InvalidHttpCapture;
                    const status = try std.fmt.parseInt(u16, head[9..12], 10);
                    if (status < 100 or status > 599 or status == 101 or self.heads == 5) return error.InvalidHttpCapture;
                    self.heads += 1;
                    const length = try headers(head, false);
                    if (status >= 200) {
                        self.status = status;
                        self.response_length = length;
                    }
                    self.used = 0;
                }
            },
            else => {
                if (bytes.len > self.buffer.len - self.used) return error.InvalidHttpCapture;
                @memcpy(self.buffer[self.used..][0..bytes.len], bytes);
                self.used += bytes.len;
            },
        }
    }
    fn end(self: *Validator, kind: http.Kind) !void {
        const bytes = self.buffer[0..self.used];
        switch (kind) {
            .request_template => if (self.template_bytes == 0 or self.template_bytes > http.Request.maximum_head_bytes) return error.InvalidHttpCapture,
            .request_head => {
                const line_end = std.mem.indexOf(u8, bytes, "\r\n") orelse return error.InvalidHttpCapture;
                const line = bytes[0..line_end];
                const space = std.mem.indexOfScalar(u8, line, ' ') orelse return error.InvalidHttpCapture;
                const method = std.meta.stringToEnum(std.http.Method, line[0..space]) orelse return error.InvalidHttpCapture;
                if (!std.mem.endsWith(u8, line, " HTTP/1.1")) return error.InvalidHttpCapture;
                self.is_head = method == .HEAD;
                self.request_length = (try headers(bytes, false)) orelse return error.HttpReplayGap;
            },
            .request_body => if (self.request_length != self.request_bytes) return error.HttpReplayGap,
            .response_head => if (self.used != 0 or self.status == 0) return error.HttpReplayGap,
            .response_body => {},
            .response_trailers => {
                if (try headers(bytes, true) != null) return error.InvalidHttpCapture;
            },
            .timing => _ = try x.codec.decode(http.Timing, try x.p.Value.init(bytes)),
            .omission => self.omission = try x.codec.decode(http.Omission, try x.p.Value.init(bytes)),
            .completion => self.completion = try x.codec.decode(http.Completion, try x.p.Value.init(bytes)),
        }
    }
    pub fn finish(self: *Validator) !http.Completion {
        if (self.current != .completion) return error.HttpReplayGap;
        if (self.completion == null) try self.end(.completion);
        const value = self.completion.?;
        if (value.status != self.status or value.status != self.terminal_status or value.heads != self.heads or value.request_bytes != self.request_bytes or value.response_bytes != self.response_bytes) return error.HttpReplayGap;
        const no_body = self.is_head or value.status == 204 or value.status == 304;
        if ((value.framing == .none) != no_body) return error.InvalidHttpCapture;
        if (value.framing == .length and self.response_length != null and self.response_length.? != value.response_bytes) return error.HttpReplayGap;
        const omitted = self.omission orelse return error.HttpReplayGap;
        if (self.policy == .require_unredacted and (omitted.response_headers != 0 or omitted.request_secrets != 0)) return error.HttpReplayGap;
        return value;
    }
};
fn headers(bytes: []const u8, trailers: bool) !?u64 {
    if (!std.mem.endsWith(u8, bytes, "\r\n\r\n") and !(trailers and std.mem.eql(u8, bytes, "\r\n"))) return error.InvalidHttpCapture;
    var lines = std.mem.splitSequence(u8, bytes, "\r\n");
    if (!trailers) {
        const line = lines.next().?;
        for (line) |byte| if (byte < 32 or byte > 126) return error.InvalidHttpCapture;
    }
    var length: ?u64 = null;
    var seen_length = false;
    var count: usize = 0;
    while (lines.next()) |line| {
        if (line.len == 0) break;
        count += 1;
        if (count > http.Request.maximum_headers) return error.InvalidHttpCapture;
        const colon = std.mem.indexOfScalar(u8, line, ':') orelse return error.InvalidHttpCapture;
        const name = line[0..colon];
        const value = std.mem.trim(u8, line[colon + 1 ..], " \t");
        try http.validateHeader(name, value);
        if (std.ascii.eqlIgnoreCase(name, "content-length")) {
            if (seen_length or trailers) return error.InvalidHttpCapture;
            seen_length = true;
            if (!std.mem.eql(u8, value, "{{omitted}}")) length = try std.fmt.parseInt(u64, value, 10);
        }
        if (trailers and (std.ascii.eqlIgnoreCase(name, "transfer-encoding") or std.ascii.eqlIgnoreCase(name, "trailer"))) return error.InvalidHttpCapture;
    }
    return length;
}
