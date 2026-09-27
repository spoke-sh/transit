const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const station = b.dependency("transit_station", .{ .target = target, .optimize = optimize });
    const client = b.dependency("transit_client", .{ .target = target, .optimize = optimize });
    const http = b.dependency("transit_station_http", .{ .target = target, .optimize = optimize });
    const document = b.dependency("transit_station_document", .{ .target = target, .optimize = optimize });
    const grpc = b.dependency("transit_station_grpc", .{ .target = target, .optimize = optimize });
    const abi = b.addModule("station_abi", .{ .root_source_file = b.path("src/Abi.zig"), .target = target, .optimize = optimize, .imports = &.{ .{ .name = "transit_station_document", .module = document.module("transit_station_document") }, .{ .name = "transit_station", .module = station.module("transit_station") }, .{ .name = "client_abi", .module = client.module("client_abi") }, .{ .name = "transit_station_http", .module = http.module("transit_station_http") }, .{ .name = "transit_station_grpc", .module = grpc.module("transit_station_grpc") } } });
    const tests = b.addTest(.{ .root_module = abi });
    b.step("test", "Prove native Station handle and schema ownership").dependOn(&b.addRunArtifact(tests).step);
    b.step("check", "Compile the standalone native binding package").dependOn(&tests.step);
    const library = b.addLibrary(.{ .name = "transit_station", .linkage = .dynamic, .root_module = b.createModule(.{ .root_source_file = b.path("src/c.zig"), .target = target, .optimize = optimize, .link_libc = true, .imports = &.{.{ .name = "station_abi", .module = abi }} }) });
    library.installHeader(b.path("include/transit_station.h"), "transit_station.h");
    b.installArtifact(library);
    b.step("abi", "Build the shared Station implementation").dependOn(b.getInstallStep());
    const contract = b.addExecutable(.{ .name = "transit-station-contract", .root_module = b.createModule(.{ .root_source_file = b.path("src/abi_contract.zig"), .target = b.graph.host, .optimize = optimize, .imports = &.{ .{ .name = "transit_station", .module = station.module("transit_station") }, .{ .name = "station_abi", .module = abi } } }) });
    b.installArtifact(contract);
}
