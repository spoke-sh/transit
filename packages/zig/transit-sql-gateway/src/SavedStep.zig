//! Compact exact TableClient.Prepared storage. No signing, I/O or inference from
//! an old definition occurs here. The coordinator verifies identity and signature.
const std = @import("std");
const catalog = @import("root.zig").catalog;
const p = catalog.protocol;
const g = p.Growth;
const Prepared = catalog.TableClient.Prepared;
const Reader = @import("Bytes.zig");
pub const fixed_bytes = 150;
pub const max_bytes = fixed_bytes + 256;
pub const format: u32 = 0x47535301;
pub fn definitionBytes() [32]u8 {
    var bytes: [32]u8 = undefined;
    _ = std.fmt.hexToBytes(&bytes, @tagName(g.current_definition)) catch unreachable;
    return bytes;
}
pub fn encode(step: Prepared, storage: *[max_bytes]u8) ![]const u8 {
    _ = try step.command();
    const request = step.signed.request;
    if (request.version != 1 or request.definition != g.current_definition) return error.IncompatibleDefinition;
    var writer: std.Io.Writer = .fixed(storage);
    try writer.writeAll("GSS1");
    try writer.writeAll(&definitionBytes());
    inline for (.{ step.connection.scope.realm, step.connection.scope.resource, step.connection.scope.catalog, step.connection.owner, step.connection.principal, request.sequence }) |value| try writer.writeInt(u64, value, .little);
    const frame = request.command.send.value;
    try writer.writeInt(u16, frame.len, .little);
    try writer.writeAll(frame.slice());
    try writer.writeAll(&step.signed.signature);
    return writer.buffered();
}
pub fn decode(bytes: []const u8) !Prepared {
    if (bytes.len < fixed_bytes or bytes.len > max_bytes) return error.InvalidSavedGatewayStep;
    var reader: Reader = .{ .bytes = bytes };
    if (!std.mem.eql(u8, try reader.take(4), "GSS1")) return error.InvalidSavedGatewayStep;
    if (!std.mem.eql(u8, try reader.take(32), &definitionBytes())) return error.IncompatibleDefinition;
    const connection: catalog.TableClient.Connection = .{ .scope = .{ .realm = try reader.int(u64, .little), .resource = try reader.int(u64, .little), .catalog = try reader.int(u64, .little) }, .owner = try reader.int(u64, .little), .principal = try reader.int(u64, .little) };
    const sequence = try reader.int(u64, .little);
    const count = try reader.int(u16, .little);
    if (count > 256) return error.InvalidSavedGatewayStep;
    const frame = try p.Value.init(try reader.take(count));
    const signature = (try reader.take(64))[0..64].*;
    try reader.finish();
    const result: Prepared = .{ .version = 1, .definition = g.current_definition, .connection = connection, .signed = .{ .request = .{ .version = 1, .definition = g.current_definition, .realm = connection.scope.realm, .principal = connection.principal, .sequence = sequence, .command = .{ .send = .{ .pid = connection.owner, .value = frame } } }, .signature = signature } };
    _ = try result.command();
    return result;
}
pub fn verify(step: Prepared, intent: *const catalog.TableIntent, public_key: p.Ed25519.PublicKey) !void {
    return verifyBinding(step, intent.binding(), intent, public_key);
}
pub fn verifyBinding(step: Prepared, binding: catalog.TableIntent.Binding, bytes: anytype, public_key: p.Ed25519.PublicKey) !void {
    _ = try step.command();
    try step.connection.header(binding.header);
    const payload = (try @import("root.zig").station.Frame.decode(step.signed.request.command.send.value)).payload;
    if (!try binding.matches(payload, bytes)) return error.GatewayStepIdentityConflict;
    try p.Ed25519.Signature.fromBytes(step.signed.signature).verify(&try g.digest(step.signed.request), public_key);
}
test "compact gateway steps retain canonical signed JSON and reject incompatible or altered bytes" {
    const t = std.testing;
    const connection: catalog.TableClient.Connection = .{ .scope = .{ .realm = 46, .resource = 7, .catalog = 8 }, .owner = 3, .principal = 1234 };
    const request: catalog.TableDdlRequest = .{ .principal = connection.principal, .operation = 9, .object = 0, .expected_revision = 0, .name = try catalog.TableMetadata.Name.init("people"), .action = .{ .drop = .{ .if_exists = true } } };
    var intent = try catalog.TableIntent.create(t.allocator, try catalog.TableCommand.fromDdl(connection.scope, connection.owner, request, null), 9);
    defer intent.deinit();
    const key = try p.Ed25519.KeyPair.generateDeterministic(@splat(10));
    const step: Prepared = .{ .version = 1, .definition = g.current_definition, .connection = connection, .signed = try g.sign(.{ .realm = connection.scope.realm, .principal = connection.principal, .sequence = 3, .command = .{ .send = .{ .pid = connection.owner, .value = try (@import("root.zig").station.Frame{ .kind = .cast, .payload = try p.Value.init(intent.body) }).encode() } } }, key) };
    const original = try step.save(t.allocator);
    defer t.allocator.free(original);
    var storage: [max_bytes]u8 = undefined;
    const bytes = try encode(step, &storage);
    const restored = try decode(bytes);
    try verify(restored, &intent, key.public_key);
    const saved = try restored.save(t.allocator);
    defer t.allocator.free(saved);
    try t.expectEqualSlices(u8, original, saved);
    for (0..bytes.len) |end| {
        if (decode(bytes[0..end])) |_| return error.ExpectedTruncationFailure else |_| {}
    }
    storage[4] ^= 1;
    try t.expectError(error.IncompatibleDefinition, decode(bytes));
    storage[4] ^= 1;
    storage[bytes.len - 1] ^= 1;
    if (verify(try decode(bytes), &intent, key.public_key)) |_| return error.ExpectedSignatureFailure else |_| {}
    storage[bytes.len - 1] ^= 1;
    var other = restored;
    other.signed.request.sequence += 1;
    if (verify(other, &intent, key.public_key)) |_| return error.ExpectedSignatureFailure else |_| {}
}
