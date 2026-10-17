const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const station = b.dependency("transit_station", .{ .target = target, .optimize = optimize });
    const document = b.dependency("transit_station_document", .{ .target = target, .optimize = optimize });
    const catalog = b.dependency("transit_catalog", .{ .target = target, .optimize = optimize });
    const config = b.dependency("transit_config", .{ .target = target, .optimize = optimize });
    const module = b.addModule("transit_query", .{ .root_source_file = b.path("src/root.zig"), .target = target, .optimize = optimize, .imports = &.{ .{ .name = "transit_config", .module = config.module("transit_config") }, .{ .name = "transit_station", .module = station.module("transit_station") }, .{ .name = "transit_station_document", .module = document.module("transit_station_document") }, .{ .name = "transit_catalog", .module = catalog.module("transit_catalog") } } });
    const tests = b.addTest(.{ .root_module = module });
    const catalog_tests = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("src/native_catalog_query_test.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "transit_query", .module = module }},
    }) });
    const catalog_run = b.addRunArtifact(catalog_tests);
    b.step("test-catalog-query", "Verify durable catalog query authority and recovery").dependOn(&catalog_run.step);
    const api = b.addExecutable(.{ .name = "transit-query-api", .root_module = b.createModule(.{
        .root_source_file = b.path("src/export.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "transit_query", .module = module }},
    }) });
    b.installArtifact(api);
    const service_contract = b.addExecutable(.{ .name = "transit-table-service-contract", .root_module = b.createModule(.{
        .root_source_file = b.path("src/service_export.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "transit_query", .module = module }},
    }) });
    b.installArtifact(service_contract);
    const settings_contract = b.addExecutable(.{ .name = "transit-configuration-contract", .root_module = b.createModule(.{
        .root_source_file = b.path("src/settings_export.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "transit_query", .module = module }},
    }) });
    b.installArtifact(settings_contract);
    const check = b.step("check", "Compile the public query package");
    check.dependOn(&api.step);
    check.dependOn(&settings_contract.step);
    check.dependOn(&service_contract.step);
    const test_step = b.step("test", "Check public query contracts and bounded codecs");
    test_step.dependOn(&b.addRunArtifact(tests).step);
    test_step.dependOn(&catalog_run.step);
    check.dependOn(&tests.step);
    check.dependOn(&catalog_tests.step);
}
