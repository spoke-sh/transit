const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const module = b.addModule("transit_source_import", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "transit_data_client", .module = b.dependency("transit_data_client", .{ .target = target, .optimize = optimize }).module("transit_data_client") },
            .{ .name = "transit_station_http", .module = b.dependency("transit_station_http", .{ .target = target, .optimize = optimize }).module("transit_station_http") },
        },
    });
    const tests = b.addTest(.{ .root_module = module });
    b.step("check", "Compile the sealed SOURCE importer").dependOn(&tests.step);
    b.step("test", "Prove retained HTTP handoff without dispatch").dependOn(&b.addRunArtifact(tests).step);
    const process = b.addExecutable(.{ .name = "transit-source-capture-fixture", .root_module = b.createModule(.{
        .root_source_file = b.path("src/process_fixture.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "transit_data_client", .module = module.import_table.get("transit_data_client").? },
            .{ .name = "transit_station_http", .module = module.import_table.get("transit_station_http").? },
        },
    }) });
    const install = b.addInstallArtifact(process, .{});
    b.step("process-fixture", "Build the separate-process capture proof host").dependOn(&install.step);
}
