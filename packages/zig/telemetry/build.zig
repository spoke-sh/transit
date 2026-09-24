const std = @import("std");
pub fn build(b: *std.Build) void {
    const module = b.addModule("telemetry", .{
        .root_source_file = b.path("src/root.zig"),
        .target = b.standardTargetOptions(.{}),
        .optimize = b.standardOptimizeOption(.{}),
    });
    b.step("test", "Test bounded telemetry and correlation").dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = module })).step);
}
