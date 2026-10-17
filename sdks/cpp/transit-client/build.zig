const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const client = b.dependency("transit_sdk_client", .{ .target = target, .optimize = optimize });
    const module = b.addModule("transit_sdk_client_cpp", .{ .target = target, .optimize = optimize, .link_libc = true, .link_libcpp = true });
    module.addIncludePath(b.path("include"));
    module.addIncludePath(client.path("include"));
    module.linkLibrary(client.artifact("transit_sdk_client"));
    const check = b.addExecutable(.{ .name = "transit-cpp-header-check", .root_module = module });
    module.addCSourceFile(.{ .file = b.path("tests/check.cpp"), .flags = &.{ "-std=c++17", "-Wall", "-Wextra", "-Werror" } });
    b.step("check", "Compile and check public C++ ownership types").dependOn(&b.addRunArtifact(check).step);
    b.getInstallStep().dependOn(&b.addInstallDirectory(.{ .source_dir = b.path("include"), .install_dir = .header, .install_subdir = "" }).step);
}
