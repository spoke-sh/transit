//! Bounded parser/codec properties. No authority mutation or foreign engine.
const std = @import("std");
const t = std.testing;
const p = @import("transit_protocol");
const Frame = @import("station_frame");

fn requestBytes(bytes: []const u8) !void {
    // Parser rejection, including workspace exhaustion, is an allowed result.
    // Every accepted value must validate and retain its canonical identity.
    var memory: [128 * 1024]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&memory);
    const alloc = fixed.allocator();
    const parsed = std.json.parseFromSlice(p.SignedRequest, alloc, bytes, .{ .max_value_len = p.max_entry_bytes }) catch return;
    defer parsed.deinit();
    p.validate(parsed.value.request) catch return;
    const before = p.digest(parsed.value.request);
    const encoded = try std.json.Stringify.valueAlloc(alloc, parsed.value, .{});
    defer alloc.free(encoded);
    const again = try std.json.parseFromSlice(p.SignedRequest, alloc, encoded, .{});
    defer again.deinit();
    try t.expectEqualSlices(u8, &before, &p.digest(again.value.request));
    try t.expectEqualSlices(u8, &parsed.value.signature, &again.value.signature);
}
fn fuzzRequest(_: void, smith: *t.Smith) !void {
    var bytes: [p.max_entry_bytes]u8 = undefined;
    try requestBytes(bytes[0..smith.slice(&bytes)]);
}
fn frameBytes(bytes: []const u8) !void {
    const encoded = p.Value.init(bytes) catch return;
    const decoded = Frame.decode(encoded) catch return;
    try t.expect(encoded.eql(try decoded.encode()));
}
fn fuzzFrame(_: void, smith: *t.Smith) !void {
    var bytes: [p.Value.max_bytes + 1]u8 = undefined;
    try frameBytes(bytes[0..smith.slice(&bytes)]);
}
fn seed(bytes: []const u8, out: []u8) []const u8 {
    // Pinned Zig Smith.slice corpus encoding: little-endian u32, then bytes.
    std.mem.writeInt(u32, out[0..4], @intCast(bytes.len), .little);
    @memcpy(out[4..][0..bytes.len], bytes);
    return out[0 .. bytes.len + 4];
}

test "fuzz signed request parsing and canonical identity within a fixed workspace" {
    const key = try p.Ed25519.KeyPair.generateDeterministic(@splat(7));
    const signed = try p.sign(.{ .realm = 42, .principal = 0, .sequence = 1, .command = .{ .send = .{ .pid = 2, .value = try p.Value.init(&.{ 0, 255, 34, 10 }) } } }, key);
    const bytes = try std.json.Stringify.valueAlloc(t.allocator, signed, .{});
    defer t.allocator.free(bytes);
    try requestBytes(bytes);
    for (0..@min(bytes.len, 64)) |length| try requestBytes(bytes[0..length]);
    var buffer: [p.max_entry_bytes + 4]u8 = undefined;
    try t.fuzz({}, fuzzRequest, .{ .corpus = &.{ seed(bytes, &buffer), "\x04\x00\x00\x00null", "\x01\x00\x00\x00{" } });
}

test "fuzz Station frames preserve exact correlation and owned payload bytes" {
    const frame = try (Frame{ .kind = .reply, .correlation = std.math.maxInt(u64), .payload = try p.Value.init(&.{ 0, 255 }) }).encode();
    try frameBytes(frame.slice());
    for (0..frame.len) |length| try frameBytes(frame.slice()[0..length]);
    var buffer: [p.Value.max_bytes + 4]u8 = undefined;
    try t.fuzz({}, fuzzFrame, .{ .corpus = &.{ seed(frame.slice(), &buffer), "\x04\x00\x00\x00STN1" } });
}

fn allocatedRoundtrip(allocator: std.mem.Allocator) !void {
    const text = "\"00ff220a\"";
    var parsed = try std.json.parseFromSlice(p.Value, allocator, text, .{});
    const value = parsed.value;
    parsed.deinit();
    const encoded = try std.json.Stringify.valueAlloc(allocator, value, .{});
    defer allocator.free(encoded);
    try t.expectEqualStrings(text, encoded);
}

test "allocation failures release parser and canonical output ownership" {
    try t.checkAllAllocationFailures(t.allocator, allocatedRoundtrip, .{});
}
