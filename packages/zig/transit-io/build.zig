const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const module = b.addModule("transit_io", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "transit_memory", .module = b.dependency("transit_memory", .{ .target = target, .optimize = optimize }).module("transit_memory") }},
    });
    const tests = b.addTest(.{ .root_module = module });
    b.step("test", "Verify bounded I/O task and worker reuse").dependOn(&b.addRunArtifact(tests).step);
    b.step("check", "Compile bounded I/O ownership").dependOn(&tests.step);
}
