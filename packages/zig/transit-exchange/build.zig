const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const station = b.dependency("transit_station", .{ .target = target, .optimize = optimize });
    const module = b.addModule("transit_exchange", .{ .root_source_file = b.path("src/root.zig"), .target = target, .optimize = optimize, .imports = &.{.{ .name = "transit_station", .module = station.module("transit_station") }} });
    const tests = b.addTest(.{ .root_module = module });
    b.step("test", "Check exchange capture, identity and cleanup").dependOn(&b.addRunArtifact(tests).step);
    b.step("check", "Compile exchange capture").dependOn(&tests.step);
}
