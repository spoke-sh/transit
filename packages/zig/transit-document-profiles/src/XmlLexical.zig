//! Shared lexical restrictions of the admitted namespace-free XML grammar.
const std = @import("std");
pub fn nameStart(c: u8) bool {
    return std.ascii.isAlphabetic(c) or c == '_';
}
pub fn nameContinue(c: u8) bool {
    return nameStart(c) or std.ascii.isDigit(c) or c == '.' or c == '-';
}
pub fn xmlChar(c: u21) bool {
    return c == 9 or c == 10 or c == 13 or (c >= 0x20 and c <= 0xd7ff) or (c >= 0xe000 and c <= 0xfffd) or (c >= 0x10000 and c <= 0x10ffff);
}
pub fn requireName(bytes: []const u8) !void {
    if (std.mem.indexOfScalar(u8, bytes, ':') != null) return error.UnsupportedXmlNamespace;
    if (bytes.len == 0 or !nameStart(bytes[0])) return error.InvalidXmlName;
    for (bytes[1..]) |byte| if (!nameContinue(byte)) return error.InvalidXmlName;
}
