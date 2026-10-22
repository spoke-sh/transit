const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const client = b.dependency("ursula_zig", .{ .target = target, .optimize = optimize });
    const core = b.dependency("transit_core", .{ .target = target, .optimize = optimize });
    const storage = b.dependency("transit_storage", .{ .target = target, .optimize = optimize });
    const module = b.addModule("transit_backend_ursula", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "transit_observability", .module = b.dependency("transit_observability", .{ .target = target, .optimize = optimize }).module("transit_observability") },
            .{ .name = "ursula", .module = client.module("ursula") },
            .{ .name = "transit_core", .module = core.module("transit_core") },
            .{ .name = "transit_storage", .module = storage.module("transit_storage") },
        },
    });
    const tests = b.addTest(.{ .root_module = module });
    b.step("test", "Test the Ursula adapter").dependOn(&b.addRunArtifact(tests).step);
    b.step("check", "Compile standalone package tests without executing them").dependOn(&tests.step);
}
