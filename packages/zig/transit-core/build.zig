const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const protocol = b.dependency("transit_protocol", .{ .target = target, .optimize = optimize });
    const module = b.addModule("transit_core", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "transit_protocol", .module = protocol.module("transit_protocol") }},
    });
    const tests = b.addTest(.{ .root_module = module });
    b.step("test", "Test Transit protocol and authentication").dependOn(&b.addRunArtifact(tests).step);
    b.step("check", "Compile standalone package tests without executing them").dependOn(&tests.step);
}
