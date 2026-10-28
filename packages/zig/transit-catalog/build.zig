const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const client = b.dependency("transit_client", .{ .target = target, .optimize = optimize });
    const protocol = b.dependency("transit_protocol", .{ .target = target, .optimize = optimize });
    const fuze = b.dependency("transit_fuze", .{ .target = target, .optimize = optimize });
    const storage = b.dependency("transit_storage", .{ .target = target, .optimize = optimize });
    const module = b.addModule("transit_catalog", .{ .root_source_file = b.path("src/root.zig"), .target = target, .optimize = optimize, .imports = &.{ .{ .name = "transit_client", .module = client.module("transit_client") }, .{ .name = "transit_protocol", .module = protocol.module("transit_protocol") }, .{ .name = "transit_fuze", .module = fuze.module("transit_fuze") }, .{ .name = "transit_storage", .module = storage.module("transit_storage") } } });
    const filters = b.option([]const []const u8, "test-filter", "Run catalog tests whose names contain a filter") orelse &.{};
    const tests = b.addTest(.{ .root_module = module, .filters = filters });
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
