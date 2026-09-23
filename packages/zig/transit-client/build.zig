const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const transit = b.dependency("transit", .{ .target = target, .optimize = optimize });
    const module = b.addModule("transit_client", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "transit", .module = transit.module("transit") }},
    });
    b.step("test", "Check the protocol client").dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = module })).step);
}
