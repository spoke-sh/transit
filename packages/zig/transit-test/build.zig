const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const module = b.addModule("transit_test", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "transit_compiler", .module = b.dependency("transit_compiler", .{ .target = target, .optimize = optimize }).module("transit_compiler") },
            .{ .name = "transit_sql_service", .module = b.dependency("transit_sql_service", .{ .target = target, .optimize = optimize }).module("transit_sql_service") },
            .{ .name = "transit_memory", .module = b.dependency("transit_memory", .{ .target = target, .optimize = optimize }).module("transit_memory") },
        },
    });
    const tests = b.addTest(.{ .root_module = module });
    b.step("test", "Check isolated application assertion execution").dependOn(&b.addRunArtifact(tests).step);
    b.step("check", "Compile application runner tests").dependOn(&tests.step);
}
