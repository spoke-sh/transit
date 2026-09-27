const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const libraries = b.dependency("zig_libs", .{ .target = target, .optimize = optimize });
    const module = b.addModule("transit_tls", .{ .root_source_file = b.path("src/root.zig"), .target = target, .optimize = optimize, .imports = &.{ .{ .name = "x509", .module = libraries.module("x509") }, .{ .name = "testkit", .module = libraries.module("testkit") } } });
    const suite = b.addTest(.{ .root_module = module });
    b.step("test", "Check TLS chain validation").dependOn(&b.addRunArtifact(suite).step);
    b.step("check", "Compile TLS chain validation").dependOn(&suite.step);
}
