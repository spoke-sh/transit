const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const station = b.dependency("transit_station", .{ .target = target, .optimize = optimize });
    const document = b.dependency("transit_station_document", .{ .target = target, .optimize = optimize });
    const module = b.addModule("transit_query", .{ .root_source_file = b.path("src/root.zig"), .target = target, .optimize = optimize, .imports = &.{ .{ .name = "transit_station", .module = station.module("transit_station") }, .{ .name = "transit_station_document", .module = document.module("transit_station_document") } } });
    const tests = b.addTest(.{ .root_module = module });
    b.step("test", "Check public query contracts and bounded codecs").dependOn(&b.addRunArtifact(tests).step);
    b.step("check", "Compile the public query package").dependOn(&tests.step);
}
