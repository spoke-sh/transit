const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const protocol = b.dependency("transit_protocol", .{ .target = target, .optimize = optimize });
    const core = b.dependency("transit_core", .{ .target = target, .optimize = optimize });
    const fuze_dep = b.dependency("transit_fuze", .{ .target = target, .optimize = optimize });
    const fuze_mod = fuze_dep.module("transit_fuze");

    const module = b.addModule("transit_storage", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "transit_protocol", .module = protocol.module("transit_protocol") },
            .{ .name = "transit_core", .module = core.module("transit_core") },
            .{ .name = "transit_fuze", .module = fuze_mod },
        },
    });

    const tests = b.addTest(.{ .root_module = module });
    b.step("test", "Qualify TransitLog, TransitObjectStore, TableMemtable, NvmeCache, and OCC").dependOn(&b.addRunArtifact(tests).step);
    b.step("check", "Compile the tiered storage runtime library").dependOn(&tests.step);
}
