const std = @import("std");

pub fn build(b: *std.Build) void {
    const module = b.addModule("transit_bitmap", .{
        .root_source_file = b.path("src/root.zig"),
        .target = b.standardTargetOptions(.{}),
        .optimize = b.standardOptimizeOption(.{}),
    });
    const tests = b.addTest(.{ .root_module = module });
    b.step("test", "Verify bounded Roaring containers and canonical codecs").dependOn(&b.addRunArtifact(tests).step);
    b.step("check", "Compile bitmap primitives").dependOn(&tests.step);
}
