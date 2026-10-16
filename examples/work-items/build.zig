const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const sdk = b.dependency("transit_sdk", .{ .target = target, .optimize = optimize });
    const module = b.addModule("work_items", .{ .root_source_file = b.path("WorkItems.zig"), .target = target, .optimize = optimize, .imports = &.{
        .{ .name = "transit_station_app", .module = sdk.module("transit_station_app") },
        .{ .name = "transit_query", .module = sdk.module("transit_query") },
    } });
    inline for (.{ .{ "transit-work-items", "main.zig" }, .{ "work-items", "operator.zig" } }) |entry| {
        const exe = b.addExecutable(.{ .name = entry[0], .root_module = b.createModule(.{ .root_source_file = b.path(entry[1]), .target = target, .optimize = optimize, .imports = &.{.{ .name = "work_items", .module = module }} }) });
        b.installArtifact(exe);
    }
}
