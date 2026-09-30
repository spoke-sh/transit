const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const station = b.dependency("transit_station", .{ .target = target, .optimize = optimize });
    const module = b.addModule("transit_catalog", .{ .root_source_file = b.path("src/root.zig"), .target = target, .optimize = optimize, .imports = &.{.{ .name = "transit_station", .module = station.module("transit_station") }} });
    const tests = b.addTest(.{ .root_module = module });
    b.step("test", "Check conditional catalog publication and bounded inspection").dependOn(&b.addRunArtifact(tests).step);
    b.step("check", "Compile the independent catalog library").dependOn(&tests.step);
}
