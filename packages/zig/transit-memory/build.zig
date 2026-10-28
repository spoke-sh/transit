const std = @import("std");
pub fn build(b: *std.Build) void {
    const module = b.addModule("transit_memory", .{
        .root_source_file = b.path("src/root.zig"),
        .target = b.standardTargetOptions(.{}),
        .optimize = b.standardOptimizeOption(.{}),
    });
    const tests = b.addTest(.{ .root_module = module });
    b.step("test", "Verify bounded memory ownership and allocation accounting").dependOn(&b.addRunArtifact(tests).step);
    b.step("check", "Compile memory primitives").dependOn(&tests.step);
}
