//! SQL retains only this bounded control reference. Complete mutation bytes
//! live in the direct Table owner's immutable object store.
const std = @import("std");
const g = @import("root.zig");
const p = g.catalog.protocol;
pub const Reference = g.catalog.DirectTableIntent.Reference;
pub const max_bytes = 4096;
pub const prefix_bytes = 36;

pub fn encode(value: Reference, output: *[max_bytes]u8) ![]const u8 {
    try value.validate();
    var writer: std.Io.Writer = .fixed(output);
    try writer.writeAll("GIR1");
    try writer.writeAll(&p.Growth.definition_bytes);
    var json: std.json.Stringify = .{ .writer = &writer };
    try p.Json.write(value, &json);
    return writer.buffered();
}
pub fn decode(allocator: std.mem.Allocator, bytes: []const u8) !Reference {
    if (bytes.len <= prefix_bytes or bytes.len > max_bytes or !std.mem.eql(u8, bytes[0..4], "GIR1")) return error.InvalidGatewayIntent;
    if (!std.mem.eql(u8, bytes[4..36], &p.Growth.definition_bytes)) return error.IncompatibleDefinition;
    const parsed = try p.Json.parseFromSlice(Reference, allocator, bytes[prefix_bytes..]);
    defer parsed.deinit();
    var canonical: [max_bytes]u8 = undefined;
    if (!std.mem.eql(u8, bytes, try encode(parsed.value, &canonical))) return error.InvalidGatewayIntent;
    return parsed.value;
}
/// Complete binding commitment, independent of transport and credentials.
pub fn bindingDigest(binding: p.DataLifecycle.Binding) ![32]u8 {
    try binding.validate();
    var buffer: [max_bytes]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&buffer);
    var json: std.json.Stringify = .{ .writer = &writer };
    try p.Json.write(binding, &json);
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.sql.direct.binding.v1\x00");
    hash.update(writer.buffered());
    return hash.finalResult();
}
