//! Owned bounded JSON Pointer. Truncation is explicit and preserves UTF-8 units.
const std = @import("std");
const Path = @This();
bytes: [256]u8 = @splat(0),
len: u16 = 0,
truncated: bool = false,
pub fn slice(self: *const Path) []const u8 {
    return self.bytes[0..self.len];
}
fn append(self: *Path, bytes: []const u8) void {
    if (self.truncated) return;
    if (bytes.len > self.bytes.len - self.len) {
        self.truncated = true;
        return;
    }
    @memcpy(self.bytes[self.len..][0..bytes.len], bytes);
    self.len += @intCast(bytes.len);
}
/// JSON Pointer escaping keeps '.', '/', '~' and numeric field names
/// unambiguous. Array indices are zero-based, as in JSON Pointer.
pub fn field(self: Path, name: []const u8) Path {
    var next = self;
    next.append("/");
    var at: usize = 0;
    while (at < name.len) {
        const width = std.unicode.utf8ByteSequenceLength(name[at]) catch 1;
        const end = @min(at + width, name.len);
        next.append(switch (name[at]) {
            '~' => "~0",
            '/' => "~1",
            else => name[at..end],
        });
        at = end;
    }
    return next;
}
pub fn index(self: Path, ordinal: usize) Path {
    var bytes: [20]u8 = undefined;
    return self.field(std.fmt.bufPrint(&bytes, "{d}", .{ordinal}) catch unreachable);
}
