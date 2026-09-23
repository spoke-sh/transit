const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const client = b.dependency("ursula_zig", .{ .target = target, .optimize = optimize });
    const module = b.addModule("transit_ursula", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "ursula", .module = client.module("ursula") }},
    });
    b.step("test", "Test the Ursula adapter").dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = module })).step);
}
