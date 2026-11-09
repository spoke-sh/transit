const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const module = b.addModule("transit_compiler", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "transit_fuze", .module = b.dependency("transit_fuze", .{ .target = target, .optimize = optimize }).module("transit_fuze") },
            .{ .name = "transit_memory", .module = b.dependency("transit_memory", .{ .target = target, .optimize = optimize }).module("transit_memory") },
            .{ .name = "transit_protocol", .module = b.dependency("transit_protocol", .{ .target = target, .optimize = optimize }).module("transit_protocol") },
        },
    });
    const tests = b.addTest(.{ .root_module = module });
    b.step("test", "Check recursive source compilation and SQL equivalence").dependOn(&b.addRunArtifact(tests).step);
    b.step("check", "Compile source compiler tests").dependOn(&tests.step);
}
