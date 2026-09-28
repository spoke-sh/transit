const std = @import("std");
pub fn build(b: *std.Build) void {
    const module = b.addModule("transit_http_server", .{
        .root_source_file = b.path("src/root.zig"),
        .target = b.standardTargetOptions(.{}),
        .optimize = b.standardOptimizeOption(.{}),
    });
    const tests = b.addTest(.{ .root_module = module });
    b.step("test", "Qualify bounded HTTP lifecycle and framing").dependOn(&b.addRunArtifact(tests).step);
    b.step("check", "Compile HTTP server checks").dependOn(&tests.step);
}
