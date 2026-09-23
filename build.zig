const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const adapter = b.dependency("transit_ursula", .{ .target = target, .optimize = optimize });
    const tests = b.addTest(.{ .root_module = adapter.module("transit_ursula") });
    const test_step = b.step("test", "Run Zig unit and protocol tests");
    test_step.dependOn(&b.addRunArtifact(tests).step);
    const transit = b.dependency("transit", .{ .target = target, .optimize = optimize });
    test_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = transit.module("transit") })).step);
    const integration = b.addSystemCommand(&.{ "python3", "-B" });
    integration.addFileArg(b.path("tests/storage.py"));
    for ([_][]const u8{ "storage", "kernel", "effects", "lifetime", "outbox" }) |name| {
        const proof = b.addExecutable(.{
            .name = b.fmt("transit-{s}-proof", .{name}),
            .root_module = b.createModule(.{
                .root_source_file = b.path(b.fmt("tests/{s}.zig", .{name})),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "transit", .module = transit.module("transit") },
                    .{ .name = "transit_ursula", .module = adapter.module("transit_ursula") },
                },
            }),
        });
        b.installArtifact(proof);
        integration.addArtifactArg(proof);
    }
    integration.has_side_effects = true;
    integration.stdio = .inherit;
    b.step("test-storage", "Prove conditional writes and disk recovery against Ursula").dependOn(&integration.step);
}
