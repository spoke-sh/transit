//! Incremental scalar validation with at most four bytes of retained state.
const std = @import("std");
const Self = @This();
bytes: [4]u8 = undefined,
used: u3 = 0,
length: u3 = 0,

pub fn accept(self: *Self, byte: u8) !?u21 {
    if (self.used == 0) {
        self.length = std.unicode.utf8ByteSequenceLength(byte) catch return error.InvalidDocumentUtf8;
    } else if (byte & 0xc0 != 0x80) return error.InvalidDocumentUtf8;
    self.bytes[self.used] = byte;
    self.used += 1;
    if (self.used != self.length) return null;
    const value = std.unicode.utf8Decode(self.bytes[0..self.used]) catch return error.InvalidDocumentUtf8;
    self.used = 0;
    return value;
}

pub fn finish(self: Self) !void {
    if (self.used != 0) return error.InvalidDocumentUtf8;
}
