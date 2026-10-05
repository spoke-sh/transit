//! Experimental codec used only by the isolated page-layout study.
const std = @import("std");
pub fn encode(page: anytype, bytes: []u8) ![]const u8 {
    try page.validate();
    var out: std.Io.Writer = .fixed(bytes);
    try out.writeAll("TPG1");
    try out.writeByte(page.height);
    try out.writeByte(page.count);
    switch (page.body) {
        .leaf => |entries| for (entries[0..page.count]) |slot| {
            const entry = slot.?;
            try out.writeByte(@intCast(entry.key.len));
            try out.writeInt(u16, entry.value.len, .little);
            try out.writeAll(entry.key.slice());
            try out.writeAll(entry.value.slice());
        },
        .branch => |children| for (children[0..page.count]) |slot| {
            const child = slot.?;
            try out.writeByte(@intCast(child.minimum.len));
            try out.writeAll(child.minimum.slice());
            try out.writeAll(&child.reference.digest);
            try out.writeAll(&child.reference.location);
        },
    }
    return out.buffered();
}
pub fn decode(comptime P: type, bytes: []const u8) !P.Page {
    if (bytes.len > P.max_encoded_bytes or bytes.len < 6 or !std.mem.eql(u8, bytes[0..4], "TPG1")) return error.InvalidPage;
    var input: std.Io.Reader = .fixed(bytes[4..]);
    const height = try input.takeByte();
    const count = try input.takeByte();
    var page: P.Page = .{ .height = height, .count = count, .body = if (height == 0) .{ .leaf = @splat(null) } else .{ .branch = @splat(null) } };
    if (count == 0 or count > (if (height == 0) @as(usize, P.leaf_entries) else P.branch_children)) return error.InvalidPage;
    if (height == 0) {
        for (page.body.leaf[0..count]) |*entry| {
            const key_len = try input.takeByte();
            const value_len = try input.takeInt(u16, .little);
            entry.* = .{ .key = try P.Key.init(try input.take(key_len)), .value = try P.Value.init(try input.take(value_len)) };
        }
    } else {
        for (page.body.branch[0..count]) |*child| {
            const key_len = try input.takeByte();
            child.* = .{ .minimum = try P.Key.init(try input.take(key_len)), .reference = .{ .digest = (try input.take(32))[0..32].*, .location = (try input.take(16))[0..16].* } };
        }
    }
    if (input.seek != bytes.len - 4) return error.InvalidPage;
    try page.validate();
    return page;
}
