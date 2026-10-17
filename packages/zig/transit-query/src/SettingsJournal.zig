//! One recoverable administrative request per configured account lane. Hosts
//! serialize this file; retained history and current authority live at the owner.
const std = @import("std");
const q = @import("root.zig");
const C = q.settings.Contract;
pub const Record = struct { definition: q.protocol.Growth.Definition, request: C.Request, principal: u64, role: ?u64, complete: bool };
pub fn read(a: std.mem.Allocator, io: std.Io, path: []const u8, client: q.SettingsClient) !?Record {
    const bytes = std.Io.Dir.cwd().readFileAlloc(io, path, a, .limited(C.max_bytes)) catch |err| if (err == error.FileNotFound) return null else return err;
    defer a.free(bytes);
    const parsed = try std.json.parseFromSlice(Record, a, bytes, .{});
    defer parsed.deinit();
    const record = parsed.value;
    try record.request.validate();
    if (record.definition != q.protocol.Growth.current_definition or !std.meta.eql(record.request.binding, client.binding) or record.principal != client.principal or (!record.complete and record.role != client.role) or record.request.action != .reload) return error.InvalidConfigurationRecovery;
    return record; // Reload requests have no borrowed string fields.
}
pub fn write(a: std.mem.Allocator, io: std.Io, path: []const u8, record: Record) !void {
    const bytes = try q.protocol.Json.valueAlloc(a, record);
    defer a.free(bytes);
    if (bytes.len > C.max_bytes) return error.ConfigurationTooLarge;
    const dir = try std.Io.Dir.cwd().openDir(io, std.fs.path.dirname(path) orelse ".", .{ .iterate = true });
    defer dir.close(io);
    var file = try dir.createFileAtomic(io, std.fs.path.basename(path), .{ .replace = true, .permissions = .fromMode(0o600) });
    defer file.deinit(io);
    try file.file.writeStreamingAll(io, bytes);
    try file.file.sync(io);
    try file.replace(io);
    if (std.c.fsync(dir.handle) != 0) return error.ConfigurationRecoverySyncFailed;
}
