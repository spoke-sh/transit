const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const module = b.addModule("transit_station_grpc", .{ .root_source_file = b.path("src/root.zig"), .target = target, .optimize = optimize, .imports = &.{
        .{ .name = "transit_exchange", .module = b.dependency("transit_exchange", .{ .target = target, .optimize = optimize }).module("transit_exchange") },
        .{ .name = "transit_grpc", .module = b.dependency("transit_grpc", .{ .target = target, .optimize = optimize }).module("transit_grpc") },
    } });
    const generator = b.addExecutable(.{ .name = "transit-grpc-bindings", .root_module = b.createModule(.{ .root_source_file = b.path("src/generate.zig"), .target = target, .optimize = optimize, .imports = &.{.{ .name = "transit_station_grpc", .module = module }} }) });
    b.installArtifact(generator);
    const generate = b.addRunArtifact(generator);
    if (b.option([]const u8, "descriptor", "Local FileDescriptorSet path")) |path| generate.addFileArg(.{ .cwd_relative = path });
    b.step("generate", "Generate request helpers from a local descriptor set").dependOn(&generate.step);
    const tests = b.addTest(.{ .root_module = module });
    b.step("test", "Check finite RPC publication and capture").dependOn(&b.addRunArtifact(tests).step);
    b.step("check", "Compile RPC adapter").dependOn(&tests.step);
}
