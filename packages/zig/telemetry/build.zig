const std = @import("std");
pub fn build(b: *std.Build) void {
    const module = b.addModule("telemetry", .{
        .root_source_file = b.path("src/root.zig"),
        .target = b.standardTargetOptions(.{}),
        .optimize = b.standardOptimizeOption(.{}),
    });
    const tests = b.addTest(.{ .root_module = module });
    b.step("test", "Test bounded telemetry and correlation").dependOn(&b.addRunArtifact(tests).step);
    b.step("check", "Compile standalone package tests without executing them").dependOn(&tests.step);
}
