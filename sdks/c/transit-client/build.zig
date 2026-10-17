const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const native = b.dependency("transit_client", .{ .target = target, .optimize = optimize });
    const module = b.addModule("transit_sdk_client", .{ .target = target, .optimize = optimize, .link_libc = true, .link_libcpp = true });
    module.addIncludePath(b.path("include"));
    module.addIncludePath(native.path("include"));
    module.addCSourceFile(.{ .file = b.path("src/client.cpp"), .flags = &.{ "-std=c++17", "-Wall", "-Wextra", "-Werror" } });
    module.linkSystemLibrary("dl", .{});
    module.linkSystemLibrary("pthread", .{});
    const library = b.addLibrary(.{ .name = "transit_sdk_client", .linkage = .dynamic, .root_module = module });
    library.installHeadersDirectory(b.path("include"), "", .{});
    b.installArtifact(library);
    b.step("check", "Compile the C SDK and its generated native dependency").dependOn(&library.step);
}
