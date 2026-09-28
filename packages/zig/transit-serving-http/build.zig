const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const module = b.addModule("transit_serving_http", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "transit_serving", .module = b.dependency("transit_serving", .{ .target = target, .optimize = optimize }).module("transit_serving") },
            .{ .name = "transit_http_server", .module = b.dependency("transit_http_server", .{ .target = target, .optimize = optimize }).module("transit_http_server") },
        },
    });
    const tests = b.addTest(.{ .root_module = module });
    b.step("test", "Check shared serving host ownership").dependOn(&b.addRunArtifact(tests).step);
    b.step("check", "Compile the serving HTTP host").dependOn(&tests.step);
}
