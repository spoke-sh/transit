const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const libraries = b.dependency("zig_libs", .{ .target = target, .optimize = optimize });
    const module = b.addModule("transit_grpc", .{ .root_source_file = b.path("src/root.zig"), .target = target, .optimize = optimize, .imports = &.{
        .{ .name = "http", .module = libraries.module("http") },
        .{ .name = "grpc", .module = libraries.module("grpc") },
        .{ .name = "protobuf", .module = libraries.module("protobuf") },
        .{ .name = "transit_tls", .module = b.dependency("transit_tls", .{ .target = target, .optimize = optimize }).module("transit_tls") },
    } });
    const tests = b.addTest(.{ .root_module = module });
    b.step("test", "Check bounded RPC transport").dependOn(&b.addRunArtifact(tests).step);
    b.step("check", "Compile bounded RPC transport").dependOn(&tests.step);
}
