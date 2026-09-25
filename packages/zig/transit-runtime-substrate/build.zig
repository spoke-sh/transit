const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const module = b.addModule("transit_runtime_substrate", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "transit_observability", .module = b.dependency("transit_observability", .{ .target = target, .optimize = optimize }).module("transit_observability") }},
    });
    const tests = b.addTest(.{ .root_module = module });
    b.step("test", "Test Substrate identity validation").dependOn(&b.addRunArtifact(tests).step);
    b.step("check", "Compile standalone package tests without executing them").dependOn(&tests.step);
}
