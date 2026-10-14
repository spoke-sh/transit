const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const module = b.addModule("transit_tls_server", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    module.linkSystemLibrary("ssl", .{ .use_pkg_config = .force });
    module.linkSystemLibrary("crypto", .{ .use_pkg_config = .force });
    module.addCSourceFile(.{ .file = b.path("src/abi.c"), .flags = &.{"-std=c11"} });
    const tests = b.addTest(.{ .root_module = module });
    b.step("test", "Verify the pinned server TLS library and configuration").dependOn(&b.addRunArtifact(tests).step);
    b.step("check", "Compile the server TLS library").dependOn(&tests.step);
    const probe = b.addExecutable(.{ .name = "transit-tls-server-probe", .root_module = b.createModule(.{
        .root_source_file = b.path("src/probe.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "transit_tls_server", .module = module }},
    }) });
    b.step("probe", "Build the independent database TLS upgrade peer").dependOn(&b.addInstallArtifact(probe, .{}).step);
}
