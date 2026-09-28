const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const module = b.addModule("work_items", .{ .root_source_file = b.path("WorkItems.zig"), .target = target, .optimize = optimize, .imports = &.{
        .{ .name = "transit_station_app", .module = b.dependency("transit_station_app", .{ .target = target, .optimize = optimize }).module("transit_station_app") },
        .{ .name = "transit_query", .module = b.dependency("transit_query", .{ .target = target, .optimize = optimize }).module("transit_query") },
    } });
    inline for (.{ .{ "transit-work-items", "main.zig" }, .{ "work-items", "operator.zig" } }) |entry| {
        const exe = b.addExecutable(.{ .name = entry[0], .root_module = b.createModule(.{ .root_source_file = b.path(entry[1]), .target = target, .optimize = optimize, .imports = &.{.{ .name = "work_items", .module = module }} }) });
        b.installArtifact(exe);
    }
}
