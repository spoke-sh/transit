//! The real node with an external, one-shot disk sync failure. Fault controls
//! exist only in this fixture; production configuration has no injection path.
const std = @import("std");
const node = @import("transit_node");

const Fault = struct {
    var real: std.Io = undefined;
    var directory: std.Io.Dir = undefined;
    var mutex: std.Io.Mutex = .init;
    var count: u32 = 0;

    fn sync(context: ?*anyopaque, file: std.Io.File) std.Io.File.SyncError!void {
        try real.vtable.fileSync(context, file);
        try mutex.lock(real);
        defer mutex.unlock(real);
        var selected: [128]u8 = undefined;
        const selection = directory.readFile(real, "arm", &selected) catch |err| switch (err) {
            error.FileNotFound => return,
            else => return error.InputOutput,
        };
        var descriptor: [64]u8 = undefined;
        const path = std.fmt.bufPrint(&descriptor, "/proc/self/fd/{d}", .{file.handle}) catch unreachable;
        var target: [4096]u8 = undefined;
        const length = std.Io.Dir.readLinkAbsolute(real, path, &target) catch return error.InputOutput;
        if (!std.mem.endsWith(u8, target[0..length], ".twal") or
            std.mem.indexOf(u8, target[0..length], selection) == null) return;
        directory.deleteFile(real, "arm") catch return error.InputOutput;
        count += 1;
        var buffer: [32]u8 = undefined;
        const fired = std.fmt.bufPrint(&buffer, "{d}", .{count}) catch unreachable;
        directory.writeFile(real, .{ .sub_path = "fired", .data = fired }) catch return error.InputOutput;
        // The append reached physical disk, but the caller cannot know that.
        // Recovery must resolve the retained original operation identity.
        return error.InputOutput;
    }
};

pub fn main(init: std.process.Init) !void {
    Fault.real = init.io;
    Fault.directory = try std.Io.Dir.cwd().openDir(init.io, init.environ_map.get("TRANSIT_TEST_OWNER_FAULT") orelse return error.ExpectedFaultDirectory, .{});
    defer Fault.directory.close(init.io);
    var vtable = init.io.vtable.*;
    vtable.fileSync = Fault.sync;
    var modified = init;
    modified.io = .{ .userdata = init.io.userdata, .vtable = &vtable };
    try node.main(modified);
}
