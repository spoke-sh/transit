//! Test-only node composition for real installed-server transport faults.
//! The production executable never imports this module or reads its descriptor.
const std = @import("std");
const node = @import("node");
pub const LocalRuntime = node.LocalRuntime;
pub const LocalConfiguration = node.LocalConfiguration;

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len > 1 and std.mem.eql(u8, args[1], "__test_native_node")) {
        var selected = init;
        selected.minimal.args.vector = init.minimal.args.vector[1..];
        return node.main(selected);
    }
    if (args.len < 2) return node.main(init);
    // Node configuration is installation/node.json; the test owns its parent.
    const directory = std.fs.path.dirname(std.fs.path.dirname(args[1]) orelse return error.MissingInstallation) orelse return error.MissingFixture;
    const path = try std.fs.path.join(init.arena.allocator(), &.{ directory, "node-proxy.json" });
    const bytes = std.Io.Dir.cwd().readFileAlloc(init.io, path, init.arena.allocator(), .limited(4096)) catch |err| switch (err) {
        error.FileNotFound => return node.main(init),
        else => return err,
    };
    const proxy = try std.json.parseFromSlice([]const []const u8, init.arena.allocator(), bytes, .{});
    if (proxy.value.len == 0 or proxy.value.len > 8 or !std.fs.path.isAbsolute(proxy.value[0])) return error.InvalidTestProxy;
    const command = try init.arena.allocator().alloc([]const u8, proxy.value.len + args.len - 1);
    @memcpy(command[0..proxy.value.len], proxy.value);
    @memcpy(command[proxy.value.len..], args[1..]);
    return std.process.replace(init.io, .{ .argv = command, .environ_map = init.environ_map });
}
