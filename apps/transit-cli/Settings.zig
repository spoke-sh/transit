//! CLI diagnostics and atomic output around shared configuration input.
const std = @import("std");
const input = @import("transit_query").settings.Input;
pub const Value = input.Value;
pub const max_bytes = input.max_bytes;
pub const max_depth = input.max_depth;
pub const max_nodes = input.max_nodes;
pub const readTyped = input.readTyped;
pub const object = input.object;
pub const merge = input.merge;
pub const shape = input.shape;
pub const discover = input.discover;
pub const discoverServer = input.discoverServer;
pub const read = input.read;
pub const Yaml = input.Yaml;
pub const environment = input.environment;
pub const environmentOrigin = input.environmentOrigin;

/// Human configuration defaults to YAML; explicit .json exports stay compatible.
pub fn write(init: std.process.Init, name: []const u8, value: anytype) !void {
    const Files = @import("server/Files.zig");
    if (std.mem.endsWith(u8, name, ".json")) return Files.json(init.io, init.gpa, name, value);
    var arena: std.heap.ArenaAllocator = .init(init.gpa);
    defer arena.deinit();
    const allocator = arena.allocator();
    const encoded = try std.json.Stringify.valueAlloc(allocator, value, .{});
    if (encoded.len > max_bytes) return error.ConfigurationTooLarge;
    const tree = try input.jsonValue(allocator, encoded);
    const buffer = try allocator.alloc(u8, max_bytes);
    var output: std.Io.Writer = .fixed(buffer);
    try input.yaml(&output, tree, 0);
    try Files.write(init.io, name, output.buffered());
}
