const std = @import("std");
pub fn build(b: *std.Build) void {
    const module = b.addModule("transit_config", .{ .root_source_file = b.path("src/root.zig"), .target = b.standardTargetOptions(.{}), .optimize = b.standardOptimizeOption(.{}) });
    const tests = b.addTest(.{ .root_module = module });
    b.step("test", "Verify typed configuration resolution and bounds").dependOn(&b.addRunArtifact(tests).step);
    b.step("check", "Compile configuration checks").dependOn(&tests.step);
}
