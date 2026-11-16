const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const module = b.addModule("transit_http", .{ .root_source_file = b.path("src/root.zig"), .target = target, .optimize = optimize, .imports = &.{.{ .name = "transit_tls", .module = b.dependency("transit_tls", .{ .target = target, .optimize = optimize }).module("transit_tls") }} });
    const tests = b.addTest(.{ .root_module = module });
    b.step("test", "Check bounded HTTP requests, framing and capture callbacks").dependOn(&b.addRunArtifact(tests).step);
    b.step("check", "Compile HTTP mechanics without Station").dependOn(&tests.step);
}
