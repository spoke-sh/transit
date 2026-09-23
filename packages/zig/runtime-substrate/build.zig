const std = @import("std");
pub fn build(b: *std.Build) void {
    const module = b.addModule("runtime_substrate", .{
        .root_source_file = b.path("src/root.zig"),
        .target = b.standardTargetOptions(.{}),
        .optimize = b.standardOptimizeOption(.{}),
    });
    b.step("test", "Test Substrate identity validation").dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = module })).step);
}
