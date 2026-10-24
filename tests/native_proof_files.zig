//! Canonical private proof files and exact signed delivery for realm 46 fixtures.
const std = @import("std");
const s = @import("transit_station");
const p = s.protocol;
const g = p.Growth;
const Pending = struct { definition: g.Definition, pending: s.client.Session.Pending };
pub fn key(comptime byte: u8) !p.Ed25519.KeyPair {
    return p.Ed25519.KeyPair.generateDeterministic(@splat(byte));
}
pub fn path(init: std.process.Init, directory: []const u8, name: []const u8) ![]const u8 {
    return std.fmt.allocPrint(init.arena.allocator(), "{s}/{s}", .{ directory, name });
}
pub fn saveBytes(init: std.process.Init, directory: []const u8, name: []const u8, bytes: []const u8) !void {
    const dir = try std.Io.Dir.cwd().openDir(init.io, directory, .{ .iterate = true });
    defer dir.close(init.io);
    var file = try dir.createFileAtomic(init.io, name, .{ .replace = true, .permissions = .fromMode(0o600) });
    defer file.deinit(init.io);
    try file.file.writeStreamingAll(init.io, bytes);
    try file.file.sync(init.io);
    try file.replace(init.io);
    if (std.c.fsync(dir.handle) != 0) return error.SyncFailed;
}
pub fn save(init: std.process.Init, directory: []const u8, name: []const u8, value: anytype) !void {
    const bytes = try std.json.Stringify.valueAlloc(init.gpa, value, .{});
    defer init.gpa.free(bytes);
    try saveBytes(init, directory, name, bytes);
}
pub fn loadBytes(init: std.process.Init, directory: []const u8, name: []const u8, limit: usize) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(init.io, try path(init, directory, name), init.gpa, .limited(limit));
}
pub fn load(comptime T: type, init: std.process.Init, directory: []const u8, name: []const u8) !T {
    const bytes = try loadBytes(init, directory, name, 65536);
    defer init.gpa.free(bytes);
    const parsed = try std.json.parseFromSliceLeaky(T, init.arena.allocator(), bytes, .{});
    const encoded = try std.json.Stringify.valueAlloc(init.gpa, parsed, .{});
    defer init.gpa.free(encoded);
    if (!std.mem.eql(u8, bytes, encoded)) return error.NoncanonicalFixture;
    return parsed;
}
pub fn print(init: std.process.Init, value: anytype) !void {
    var buffer: [4096]u8 = undefined;
    var out = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    try std.json.Stringify.value(value, .{}, &out.interface);
    try out.interface.writeByte('\n');
    try out.interface.flush();
}
pub fn deliver(init: std.process.Init, wire: *s.client.Client, directory: []const u8) !bool {
    const previous = load(Pending, init, directory, "courier.json") catch |err| switch (err) {
        error.FileNotFound => null,
        else => return err,
    };
    const pending = if (previous) |value| value else pending: {
        const state = try wire.query(.{ .realm = 46, .principal = 0, .kind = .delivery }, try key(7));
        const output = state.body.delivery.next orelse return false;
        const value: Pending = .{ .definition = g.current_definition, .pending = .{ .signed = try g.sign(.{ .realm = 46, .principal = 0, .sequence = state.principal_sequence + 1, .command = .{ .deliver = output } }, try key(7)) } };
        try save(init, directory, "courier.json", value);
        break :pending value;
    };
    _ = try pending.pending.submit(wire);
    try std.Io.Dir.cwd().deleteFile(init.io, try path(init, directory, "courier.json"));
    return true;
}
