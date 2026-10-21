//! Compact, definition-qualified exact native query submission. Restoring never
//! signs a replacement or infers a missing compatibility definition.
const std = @import("std");
const q = @import("root.zig");
const p = q.protocol;
const n = p.Growth;
pub const format: u32 = 0x51535301;
pub const max_bytes = 4 + 32 + 5 * 8 + 1 + 2 + 256 + 64;
pub fn encode(value: q.UnifiedClient.Prepared, output: *[max_bytes]u8) ![]const u8 {
    const request = value.signed.request;
    if (value.version != 1 or request.version != 1 or request.definition != n.current_definition) return error.IncompatibleDefinition;
    if (request.command != .send) return error.InvalidQueryRequest;
    const send = request.command.send;
    var writer: std.Io.Writer = .fixed(output);
    try writer.writeAll("QSS1");
    try writer.writeAll(&q.catalog.TableMetadata.definition());
    inline for (.{ request.realm, request.principal, request.sequence, send.pid }) |number| try writer.writeInt(u64, number, .little);
    try writer.writeByte(@intFromBool(send.role != null));
    try writer.writeInt(u64, send.role orelse 0, .little);
    try writer.writeInt(u16, send.value.len, .little);
    try writer.writeAll(send.value.slice());
    try writer.writeAll(&value.signed.signature);
    return writer.buffered();
}
pub fn decode(bytes: []const u8) !q.UnifiedClient.Prepared {
    if (bytes.len > max_bytes) return error.InvalidSavedQuerySubmission;
    var reader: std.Io.Reader = .fixed(bytes);
    if (!std.mem.eql(u8, try reader.take(4), "QSS1")) return error.InvalidSavedQuerySubmission;
    if (!std.mem.eql(u8, try reader.take(32), &q.catalog.TableMetadata.definition())) return error.IncompatibleDefinition;
    const realm = try reader.takeInt(u64, .little);
    const principal = try reader.takeInt(u64, .little);
    const sequence = try reader.takeInt(u64, .little);
    const pid = try reader.takeInt(u64, .little);
    const present = try reader.takeByte();
    const role = try reader.takeInt(u64, .little);
    if (present > 1 or (present == 0 and role != 0)) return error.InvalidSavedQuerySubmission;
    const count = try reader.takeInt(u16, .little);
    if (count > 256) return error.InvalidSavedQuerySubmission;
    const value = try p.Value.init(try reader.take(count));
    const signature = (try reader.take(64))[0..64].*;
    if (reader.bufferedLen() != 0) return error.InvalidSavedQuerySubmission;
    const frame = try q.station.Frame.decode(value);
    if (frame.kind != .cast) return error.InvalidQueryRequest;
    _ = try q.UnifiedRequest.Command.decode(&frame.payload);
    return .{ .signed = .{ .request = .{ .version = 1, .definition = n.current_definition, .realm = realm, .principal = principal, .sequence = sequence, .command = .{ .send = .{ .pid = pid, .role = if (present == 1) role else null, .value = value } } }, .signature = signature } };
}
test "saved query submissions preserve signed bytes and reject foreign definitions" {
    const t = std.testing;
    const key = try p.Ed25519.KeyPair.generateDeterministic(@splat(9));
    const saved: q.UnifiedClient.Prepared = .{ .signed = try n.sign(.{ .realm = 1, .principal = 2, .sequence = 3, .command = .{ .send = .{ .pid = 4, .role = 7, .value = try (q.station.Frame{ .kind = .cast, .payload = try (q.UnifiedRequest.Command{ .cancel = 8 }).encode() }).encode() } } }, key) };
    var output: [max_bytes]u8 = undefined;
    const bytes = try encode(saved, &output);
    try t.expectEqualDeep(saved, try decode(bytes));
    for (0..bytes.len) |end| if (decode(bytes[0..end])) |_| return error.ExpectedTruncationFailure else |_| {};
    output[4] ^= 1;
    try t.expectError(error.IncompatibleDefinition, decode(bytes));
}
