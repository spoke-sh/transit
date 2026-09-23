const std = @import("std");
pub fn build(b: *std.Build) void {
    const module = b.addModule("transit_protocol", .{ .root_source_file = b.path("src/root.zig"), .target = b.standardTargetOptions(.{}), .optimize = b.standardOptimizeOption(.{}) });
    b.step("test", "Test public wire contract").dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = module })).step);
}
