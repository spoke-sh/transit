const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const settings = .{ .target = target, .optimize = optimize };
    const examples = b.dependency("transit_sdk_examples_c", settings);
    const client = b.dependency("transit_sdk_client", settings);
    const station = b.dependency("transit_sdk_station", settings);
    const module = b.addModule("transit_sdk_examples_cpp", .{ .target = target, .optimize = optimize, .link_libc = true, .link_libcpp = true });
    module.addIncludePath(b.path("include"));
    module.addIncludePath(examples.path("include"));
    module.addIncludePath(client.path("include"));
    module.addIncludePath(station.path("include"));
    module.addIncludePath(b.dependency("transit_sdk_client_cpp", settings).path("include"));
    module.addIncludePath(b.dependency("transit_sdk_station_cpp", settings).path("include"));
    module.linkLibrary(examples.artifact("transit_sdk_examples_c"));
    module.linkLibrary(client.artifact("transit_sdk_client"));
    module.linkLibrary(station.artifact("transit_sdk_station"));
    module.addRPathSpecial("$ORIGIN/../lib");
    module.addCSourceFile(.{ .file = b.path("src/main.cpp"), .flags = &.{ "-std=c++17", "-Wall", "-Wextra", "-Werror" } });
    const cli = b.addExecutable(.{ .name = "transit-cpp-counter", .root_module = module });
    b.installArtifact(cli);
    b.getInstallStep().dependOn(&b.addInstallDirectory(.{ .source_dir = b.path("include"), .install_dir = .header, .install_subdir = "" }).step);
    b.step("check", "Build the real C++ counter CLI and typed Table/query handlers").dependOn(&cli.step);
}
