//! Bounded HTTP/1.1 chunk framing (RFC 9112 section 7.1). Extensions are
//! validated and ignored; trailer disclosure remains the transport's policy.
const std = @import("std");
const Chunked = @This();

input: *std.Io.Reader,
scratch: []u8,
remaining: u64 = 0,
budget: u64,
delimiter: bool = false,
done: bool = false,
trailers: []const u8 = &.{},

fn byte(self: *Chunked) !u8 {
    return self.input.takeByte() catch |err| return switch (err) {
        error.EndOfStream => error.HttpChunkTruncated,
        else => err,
    };
}

fn line(self: *Chunked, storage: []u8, overflow: anyerror) ![]const u8 {
    var count: usize = 0;
    while (true) {
        const value = try self.byte();
        if (value == '\r') {
            if (try self.byte() != '\n') return error.HttpChunkInvalid;
            return storage[0..count];
        }
        if (value == '\n') return error.HttpChunkInvalid;
        if (count == storage.len) return overflow;
        storage[count] = value;
        count += 1;
    }
}

fn token(value: u8) bool {
    return std.ascii.isAlphanumeric(value) or std.mem.indexOfScalar(u8, "!#$%&'*+-.^_`|~", value) != null;
}
fn whitespace(text: []const u8, index: *usize) void {
    while (index.* < text.len and (text[index.*] == ' ' or text[index.*] == '\t')) index.* += 1;
}
fn size(text: []const u8) !u64 {
    var index: usize = 0;
    var count: u64 = 0;
    while (index < text.len and std.ascii.isHex(text[index])) : (index += 1) {
        const digit = std.fmt.charToDigit(text[index], 16) catch unreachable;
        count = std.math.mul(u64, count, 16) catch return error.HttpChunkSizeOverflow;
        count = std.math.add(u64, count, digit) catch return error.HttpChunkSizeOverflow;
    }
    if (index == 0) return error.HttpChunkInvalid;
    while (index < text.len) {
        whitespace(text, &index);
        if (index == text.len or text[index] != ';') return error.HttpChunkInvalid;
        index += 1;
        whitespace(text, &index);
        const name = index;
        while (index < text.len and token(text[index])) index += 1;
        if (index == name) return error.HttpChunkInvalid;
        const after_name = index;
        whitespace(text, &index);
        if (index == text.len or text[index] != '=') {
            index = after_name;
            continue;
        }
        index += 1;
        whitespace(text, &index);
        if (index == text.len) return error.HttpChunkInvalid;
        if (text[index] == '"') {
            index += 1;
            while (true) {
                if (index == text.len) return error.HttpChunkInvalid;
                const value = text[index];
                index += 1;
                if (value == '"') break;
                if (value == '\\') {
                    if (index == text.len) return error.HttpChunkInvalid;
                    const escaped = text[index];
                    if ((escaped < 32 and escaped != '\t') or escaped == 127) return error.HttpChunkInvalid;
                    index += 1;
                } else if ((value < 32 and value != '\t') or value == 127) return error.HttpChunkInvalid;
            }
        } else {
            const start = index;
            while (index < text.len and token(text[index])) index += 1;
            if (index == start) return error.HttpChunkInvalid;
        }
    }
    return count;
}

pub fn read(self: *Chunked, output: []u8) !usize {
    var used: usize = 0;
    while (used < output.len and !self.done) {
        if (self.remaining == 0) {
            if (self.delimiter) {
                if (try self.byte() != '\r' or try self.byte() != '\n') return error.HttpChunkInvalid;
                self.delimiter = false;
            }
            self.remaining = try size(try self.line(self.scratch, error.HttpChunkLineTooLong));
            if (self.remaining > self.budget) return error.HttpResponseTooLarge;
            self.budget -= self.remaining;
            if (self.remaining == 0) {
                var end: usize = 0;
                while (true) {
                    if (self.scratch.len - end < 2) return error.HttpTrailersOversize;
                    const field = try self.line(self.scratch[end .. self.scratch.len - 2], error.HttpTrailersOversize);
                    end += field.len;
                    @memcpy(self.scratch[end..][0..2], "\r\n");
                    end += 2;
                    if (field.len == 0) break;
                }
                self.trailers = if (end == 2) &.{} else self.scratch[0..end];
                self.done = true;
                break;
            }
        }
        const amount: usize = @intCast(@min(output.len - used, self.remaining));
        self.input.readSliceAll(output[used..][0..amount]) catch |err| return switch (err) {
            error.EndOfStream => error.HttpChunkTruncated,
            else => err,
        };
        used += amount;
        self.remaining -= amount;
        self.delimiter = self.remaining == 0;
    }
    return used;
}

test "chunk grammar distinguishes invalid size, extensions, overflow and truncation" {
    const t = std.testing;
    try t.expectEqual(@as(u64, 255), try size("fF ; name = \"a;\\\"b\"; flag;other=token"));
    try t.expectEqual(@as(u64, 0), try size("000"));
    try t.expectEqual(std.math.maxInt(u64), try size("ffffffffffffffff"));
    for ([_][]const u8{ "", "Z", "1z", "1x", "+1", "0x1", "1 ", "1;", "1;=x", "1;x=", "1;x=\"", "1;x=\"\\\x01\"", "1;x=\"\x7f\"", "1;x=\"ok\"junk" }) |bad| try t.expectError(error.HttpChunkInvalid, size(bad));
    try t.expectError(error.HttpChunkSizeOverflow, size("10000000000000000"));
    var scratch: [128]u8 = undefined;
    var buffer: [16]u8 = undefined;
    var input = std.Io.Reader.fixed("1;tag=ok\r\na\r\n2\r\nbc\r\n00\r\nX-Test: x\r\n\r\nextra");
    var chunks: Chunked = .{ .input = &input, .scratch = &scratch, .budget = 3 };
    try t.expectEqual(@as(usize, 3), try chunks.read(&buffer));
    try t.expectEqualStrings("abc", buffer[0..3]);
    try t.expectEqualStrings("X-Test: x\r\n\r\n", chunks.trailers);
    try t.expectEqual(@as(usize, 0), try chunks.read(&buffer));
    try t.expectEqual(@as(u8, 'e'), try input.takeByte());
    for ([_][]const u8{ "1\rX", "1\na\r\n0\r\n\r\n", "1\r\naX\n", "0\r\nX: x\n" }) |bad| {
        input = .fixed(bad);
        chunks = .{ .input = &input, .scratch = &scratch, .budget = 3 };
        try t.expectError(error.HttpChunkInvalid, chunks.read(&buffer));
    }
    for ([_][]const u8{ "1", "1\r", "1\r\n", "1\r\na", "1\r\na\r", "1\r\na\r\n", "0\r\n", "0\r\nX: x\r\n" }) |bad| {
        input = .fixed(bad);
        chunks = .{ .input = &input, .scratch = &scratch, .budget = 3 };
        try t.expectError(error.HttpChunkTruncated, chunks.read(&buffer));
    }
    input = .fixed("4\r\n");
    chunks = .{ .input = &input, .scratch = &scratch, .budget = 3 };
    try t.expectError(error.HttpResponseTooLarge, chunks.read(&buffer));
    input = .fixed("0000\r\n\r\n");
    chunks = .{ .input = &input, .scratch = scratch[0..3], .budget = 3 };
    try t.expectError(error.HttpChunkLineTooLong, chunks.read(&buffer));
    input = .fixed("0\r\nX:x\r\n\r\n");
    chunks = .{ .input = &input, .scratch = scratch[0..5], .budget = 3 };
    try t.expectError(error.HttpTrailersOversize, chunks.read(&buffer));
}
