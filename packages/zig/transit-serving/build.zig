const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const station = b.dependency("transit_station", .{ .target = target, .optimize = optimize });
    const module = b.addModule("transit_serving", .{ .root_source_file = b.path("src/root.zig"), .target = target, .optimize = optimize, .imports = &.{.{ .name = "transit_station", .module = station.module("transit_station") }} });
    const tests = b.addTest(.{ .root_module = module });
    b.step("test", "Qualify service admission and scoped recovery").dependOn(&b.addRunArtifact(tests).step);
    b.step("check", "Compile the serving package").dependOn(&tests.step);
}
