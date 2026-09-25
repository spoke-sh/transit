const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const protocol = b.dependency("transit_protocol", .{ .target = target, .optimize = optimize });
    const module = b.addModule("transit_client", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{ .{ .name = "transit_observability", .module = b.dependency("transit_observability", .{ .target = target, .optimize = optimize }).module("transit_observability") }, .{ .name = "transit_protocol", .module = protocol.module("transit_protocol") } },
    });
    const library = b.addLibrary(.{ .name = "transit_client", .linkage = .dynamic, .root_module = b.createModule(.{
        .root_source_file = b.path("src/c.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .imports = &.{.{ .name = "transit_client", .module = module }},
    }) });
    const abi = b.addModule("client_abi", .{ .root_source_file = b.path("src/Abi.zig"), .target = target, .optimize = optimize, .imports = &.{.{ .name = "transit_client", .module = module }} });
    library.installHeader(b.path("include/transit_client.h"), "transit_client.h");
    b.installArtifact(library);
    b.step("abi", "Build the shared Transit C ABI").dependOn(b.getInstallStep());
    const contract = b.addExecutable(.{ .name = "transit-client-contract", .root_module = b.createModule(.{
        .root_source_file = b.path("src/abi_contract.zig"),
        .target = b.graph.host,
        .optimize = optimize,
        .imports = &.{.{ .name = "transit_client", .module = module }},
    }) });
    b.installArtifact(contract);
    b.step("contract", "Export reflected C ABI signatures").dependOn(&b.addRunArtifact(contract).step);
    const test_step = b.step("test", "Check the protocol client");
    test_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = module })).step);
    test_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = abi })).step);
}
