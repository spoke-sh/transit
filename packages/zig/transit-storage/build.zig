const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const document = b.dependency("transit_document", .{ .target = target, .optimize = optimize });
    const protocol = b.dependency("transit_protocol", .{ .target = target, .optimize = optimize });
    const core = b.dependency("transit_core", .{ .target = target, .optimize = optimize });
    const fuze_dep = b.dependency("transit_fuze", .{ .target = target, .optimize = optimize });
    const fuze_mod = fuze_dep.module("transit_fuze");

    const module = b.addModule("transit_storage", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "transit_bitmap", .module = b.dependency("transit_bitmap", .{ .target = target, .optimize = optimize }).module("transit_bitmap") },
            .{ .name = "transit_document", .module = document.module("transit_document") },
            .{ .name = "transit_protocol", .module = protocol.module("transit_protocol") },
            .{ .name = "transit_core", .module = core.module("transit_core") },
            .{ .name = "transit_fuze", .module = fuze_mod },
        },
    });

    requireDatabaseDependencies(b, module);

    const filters = b.option([]const []const u8, "test-filter", "Run storage tests whose names contain a filter") orelse &.{};
    const tests = b.addTest(.{ .root_module = module, .filters = filters });
    b.step("test", "Qualify TransitLog, TransitObjectStore, TablePartition, NvmeCache, and OCC").dependOn(&b.addRunArtifact(tests).step);
    b.step("check", "Compile the tiered storage runtime library").dependOn(&tests.step);
}

/// Inspect imports without caching the graph before consumers finish wiring it.
fn requireDatabaseDependencies(b: *std.Build, root: *std.Build.Module) void {
    var modules: std.AutoArrayHashMapUnmanaged(*std.Build.Module, void) = .empty;
    modules.put(b.allocator, root, {}) catch @panic("OOM");
    var index: usize = 0;
    while (index < modules.count()) : (index += 1) {
        const module = modules.keys()[index];
        for (module.import_table.keys(), module.import_table.values()) |name, dependency| {
            if (std.mem.startsWith(u8, name, "transit_station"))
                @panic("database query/catalog modules must not depend on Station");
            modules.put(b.allocator, dependency, {}) catch @panic("OOM");
        }
    }
}
