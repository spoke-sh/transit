const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const station = b.dependency("transit_station", .{ .target = target, .optimize = optimize });
    const storage = b.dependency("transit_storage", .{ .target = target, .optimize = optimize });
    const module = b.addModule("transit_catalog", .{ .root_source_file = b.path("src/root.zig"), .target = target, .optimize = optimize, .imports = &.{ .{ .name = "transit_station", .module = station.module("transit_station") }, .{ .name = "transit_storage", .module = storage.module("transit_storage") } } });
    const tests = b.addTest(.{ .root_module = module });
    const direct_contract = b.addExecutable(.{ .name = "transit-direct-table-contract", .root_module = b.createModule(.{
        .root_source_file = b.path("src/direct_export.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "transit_catalog", .module = module }},
    }) });
    b.installArtifact(direct_contract);
    b.step("direct-contract", "Export the direct Table request contract").dependOn(&b.addRunArtifact(direct_contract).step);
    b.step("test", "Check conditional catalog publication and bounded inspection").dependOn(&b.addRunArtifact(tests).step);
    b.step("check", "Compile the independent catalog library").dependOn(&tests.step);
}
