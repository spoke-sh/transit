const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const adapter = b.dependency("transit_ursula", .{ .target = target, .optimize = optimize });
    const tests = b.addTest(.{ .root_module = adapter.module("transit_ursula") });
    b.step("test", "Run Zig unit and protocol tests").dependOn(&b.addRunArtifact(tests).step);
    const proof = b.addExecutable(.{
        .name = "transit-storage-proof",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/storage.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "transit_ursula", .module = adapter.module("transit_ursula") }},
        }),
    });
    b.installArtifact(proof);
    const integration = b.addSystemCommand(&.{ "python3", "-B" });
    integration.addFileArg(b.path("tests/storage.py"));
    integration.addArtifactArg(proof);
    integration.has_side_effects = true;
    integration.stdio = .inherit;
    b.step("test-storage", "Prove conditional writes and disk recovery against Ursula").dependOn(&integration.step);
}
