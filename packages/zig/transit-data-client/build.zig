const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const catalog = b.dependency("transit_catalog", .{ .target = target, .optimize = optimize });
    const module = b.addModule("transit_data_client", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "transit_catalog", .module = catalog.module("transit_catalog") }},
    });
    requireIndependentClient(b, module);
    const tests = b.addTest(.{ .root_module = module });
    b.step("check", "Compile the independent data client").dependOn(&tests.step);
    b.step("test", "Prove data caller ownership and attempt evidence").dependOn(&b.addRunArtifact(tests).step);
}

fn requireIndependentClient(b: *std.Build, root: *std.Build.Module) void {
    var modules: std.AutoArrayHashMapUnmanaged(*std.Build.Module, void) = .empty;
    modules.put(b.allocator, root, {}) catch @panic("OOM");
    var index: usize = 0;
    while (index < modules.count()) : (index += 1) {
        for (modules.keys()[index].import_table.keys(), modules.keys()[index].import_table.values()) |name, dependency| {
            if (std.mem.startsWith(u8, name, "transit_station") or std.mem.eql(u8, name, "station_abi"))
                @panic("data clients must not depend on Station");
            modules.put(b.allocator, dependency, {}) catch @panic("OOM");
        }
    }
}
