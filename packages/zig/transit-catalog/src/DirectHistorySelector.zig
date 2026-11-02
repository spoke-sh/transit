//! Canonical SQL spelling of the existing published DataLifecycle snapshot.
const std = @import("std");
const c = @import("root.zig");
const d = c.protocol.DataLifecycle;
pub const encoded_bytes = 297;
pub const text_bytes = encoded_bytes * 2;
fn validate(value: d.Snapshot) !void {
    try value.validate();
    if (value.definition != c.protocol.Growth.current_definition) return error.IncompatibleDefinition;
    if (value.source_count == 0 and value.consistency != .independent) return error.InvalidHistoricalSelector;
    switch (value.consistency) {
        .single_partition => |position| if (value.source_count != 1 or position.next_lsn == 0) return error.InvalidHistoricalSelector,
        .independent => {},
        .common_transaction => {},
    }
}
pub fn encode(value: d.Snapshot, output: *[text_bytes]u8) ![]const u8 {
    try validate(value);
    var bytes: [encoded_bytes]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&bytes);
    try writer.writeAll("THSNAP01");
    try writer.writeAll(&c.protocol.Growth.definition_bytes);
    for ([_]u64{ value.owner.scope.realm, value.owner.scope.resource, value.owner.scope.catalog, value.owner.principal, value.owner.operation, value.branch }) |field| try writer.writeInt(u64, field, .little);
    for ([_]d.Content{ value.catalog_root, value.sources_root }) |content| {
        try writer.writeInt(u64, content.bytes, .little);
        try writer.writeAll(&content.sha256);
    }
    try writer.writeInt(u64, value.source_count, .little);
    try writer.writeByte(switch (value.consistency) {
        .single_partition => 1,
        .independent => 2,
        .common_transaction => 3,
    });
    const position: d.Position = if (value.consistency == .single_partition) value.consistency.single_partition else .{ .partition = 0, .next_lsn = 0 };
    try writer.writeInt(u64, position.partition, .little);
    try writer.writeInt(u64, position.next_lsn, .little);
    if (value.consistency == .common_transaction) {
        const cut = value.consistency.common_transaction;
        for ([_]u64{ cut.transaction.scope.realm, cut.transaction.scope.resource, cut.transaction.scope.catalog, cut.transaction.principal, cut.transaction.operation, cut.acquired.partition, cut.acquired.next_lsn, cut.sources.bytes }) |field| try writer.writeInt(u64, field, .little);
        try writer.writeAll(&cut.sources.sha256);
        try writer.writeInt(u64, cut.source_count, .little);
    } else try writer.splatByteAll(0, 104);
    std.debug.assert(writer.end == encoded_bytes);
    const hex = "0123456789abcdef";
    for (bytes, 0..) |byte, i| {
        output[i * 2] = hex[byte >> 4];
        output[i * 2 + 1] = hex[byte & 15];
    }
    return output;
}
pub fn decode(text: []const u8) !d.Snapshot {
    if (text.len != text_bytes) return error.InvalidHistoricalSelector;
    var bytes: [encoded_bytes]u8 = undefined;
    _ = std.fmt.hexToBytes(&bytes, text) catch return error.InvalidHistoricalSelector;
    if (!std.mem.eql(u8, bytes[0..8], "THSNAP01")) return error.InvalidHistoricalSelector;
    if (!std.mem.eql(u8, bytes[8..40], &c.protocol.Growth.definition_bytes)) return error.IncompatibleDefinition;
    const fields = struct {
        fn u64At(input: []const u8, index: usize) u64 {
            return std.mem.readInt(u64, input[index..][0..8], .little);
        }
    };
    var value: d.Snapshot = .{
        .definition = c.protocol.Growth.current_definition,
        .owner = .{ .scope = .{ .realm = fields.u64At(&bytes, 40), .resource = fields.u64At(&bytes, 48), .catalog = fields.u64At(&bytes, 56) }, .principal = fields.u64At(&bytes, 64), .operation = fields.u64At(&bytes, 72) },
        .branch = fields.u64At(&bytes, 80),
        .catalog_root = .{ .bytes = fields.u64At(&bytes, 88), .sha256 = bytes[96..128].* },
        .sources_root = .{ .bytes = fields.u64At(&bytes, 128), .sha256 = bytes[136..168].* },
        .source_count = fields.u64At(&bytes, 168),
        .consistency = undefined,
    };
    const position: d.Position = .{ .partition = fields.u64At(&bytes, 177), .next_lsn = fields.u64At(&bytes, 185) };
    value.consistency = switch (bytes[176]) {
        1 => .{ .single_partition = position },
        2 => blk: {
            if (position.partition != 0 or position.next_lsn != 0) return error.InvalidHistoricalSelector;
            break :blk .independent;
        },
        3 => .{ .common_transaction = .{
            .transaction = .{ .scope = .{ .realm = fields.u64At(&bytes, 193), .resource = fields.u64At(&bytes, 201), .catalog = fields.u64At(&bytes, 209) }, .principal = fields.u64At(&bytes, 217), .operation = fields.u64At(&bytes, 225) },
            .acquired = .{ .partition = fields.u64At(&bytes, 233), .next_lsn = fields.u64At(&bytes, 241) },
            .sources = .{ .bytes = fields.u64At(&bytes, 249), .sha256 = bytes[257..289].* },
            .source_count = fields.u64At(&bytes, 289),
        } },
        else => return error.InvalidHistoricalSelector,
    };
    var canonical: [text_bytes]u8 = undefined;
    if (!std.mem.eql(u8, text, try encode(value, &canonical))) return error.InvalidHistoricalSelector;
    return value;
}
