const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const settings = .{ .target = target, .optimize = optimize };
    const station = b.dependency("transit_sdk_station", settings);
    const module = b.addModule("transit_sdk_station_cpp", .{ .target = target, .optimize = optimize, .link_libc = true, .link_libcpp = true });
    module.addIncludePath(b.path("include"));
    module.addIncludePath(station.path("include"));
    module.addIncludePath(b.dependency("transit_sdk_client", settings).path("include"));
    module.addIncludePath(b.dependency("transit_sdk_client_cpp", settings).path("include"));
    module.linkLibrary(station.artifact("transit_sdk_station"));
    module.linkLibrary(b.dependency("transit_sdk_client", settings).artifact("transit_sdk_client"));
    module.addCSourceFile(.{ .file = b.path("tests/check.cpp"), .flags = &.{ "-std=c++17", "-Wall", "-Wextra", "-Werror" } });
    const check = b.addExecutable(.{ .name = "transit-cpp-station-check", .root_module = module });
    b.step("check", "Compile public Station ownership and codec types").dependOn(&b.addRunArtifact(check).step);
    b.getInstallStep().dependOn(&b.addInstallDirectory(.{ .source_dir = b.path("include"), .install_dir = .header, .install_subdir = "" }).step);
}
