const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const serving = b.dependency("transit_serving", .{ .target = target, .optimize = optimize });
    const query = b.dependency("transit_query", .{ .target = target, .optimize = optimize });
    const module = b.addModule("transit_station_app", .{ .root_source_file = b.path("src/root.zig"), .target = target, .optimize = optimize, .imports = &.{ .{ .name = "transit_serving", .module = serving.module("transit_serving") }, .{ .name = "transit_query", .module = query.module("transit_query") } } });
    const filters = b.option([]const []const u8, "test-filter", "Run application tests whose names contain a filter") orelse &.{};
    const tests = b.addTest(.{ .root_module = module, .filters = filters });
    const cli = b.addExecutable(.{ .name = "transit-app", .root_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "transit_station_app", .module = module }},
    }) });
    b.installArtifact(cli);
    b.step("test", "Check application definitions and recoverable publication").dependOn(&b.addRunArtifact(tests).step);
    const check = b.step("check", "Compile the application package");
    check.dependOn(&tests.step);
    check.dependOn(&cli.step);
}
