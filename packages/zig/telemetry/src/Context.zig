//! W3C traceparent version 00 only. No baggage or tracestate propagation.
const std = @import("std");
const Context = @This();
trace_id: [16]u8,
span_id: [8]u8,
parent_span_id: ?[8]u8 = null,

pub fn parse(value: []const u8) ?Context {
    if (value.len != 55 or !std.mem.startsWith(u8, value, "00-") or value[35] != '-' or value[52] != '-') return null;
    for (value, 0..) |c, at| {
        if (at == 2 or at == 35 or at == 52) continue;
        if (!std.ascii.isDigit(c) and !(c >= 'a' and c <= 'f')) return null;
    }
    var result: Context = undefined;
    _ = std.fmt.hexToBytes(&result.trace_id, value[3..35]) catch return null;
    _ = std.fmt.hexToBytes(&result.span_id, value[36..52]) catch return null;
    result.parent_span_id = null;
    if (std.mem.allEqual(u8, &result.trace_id, 0) or std.mem.allEqual(u8, &result.span_id, 0)) return null;
    return result;
}

pub fn header(self: Context) [55]u8 {
    var result: [55]u8 = undefined;
    result[0..3].* = "00-".*;
    result[3..35].* = std.fmt.bytesToHex(self.trace_id, .lower);
    result[35] = '-';
    result[36..52].* = std.fmt.bytesToHex(self.span_id, .lower);
    // Collection policy is local; remote sampling flags never enable collection.
    result[52..55].* = "-00".*;
    return result;
}

pub fn fromRequest(req: *std.http.Server.Request, trusted: bool) ?Context {
    if (!trusted) return null;
    var found: ?Context = null;
    var seen = false;
    var iter = req.iterateHeaders();
    while (iter.next()) |h| if (std.ascii.eqlIgnoreCase(h.name, "traceparent")) {
        if (seen) return null;
        seen = true;
        found = parse(h.value);
    };
    return found;
}

test "traceparent has bounded strict identifiers and ignores sampling flags" {
    const valid = "00-0123456789abcdef0123456789abcdef-0123456789abcdef-01";
    const context = parse(valid).?;
    try std.testing.expectEqualStrings(valid[0..53] ++ "00", &context.header());
    for ([_][]const u8{
        "00-00000000000000000000000000000000-0123456789abcdef-00",
        "00-0123456789abcdef0123456789abcdef-0000000000000000-00",
        "00-0123456789abcdef0123456789ABCDEF-0123456789abcdef-00",
        valid ++ "secret",
        "\r\ninject",
        "01-0123456789abcdef0123456789abcdef-0123456789abcdef-01",
    }) |value| try std.testing.expect(parse(value) == null);
}
