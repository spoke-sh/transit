const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const protocol = b.dependency("transit_sql_protocol", .{ .target = target, .optimize = optimize });
    const catalog = b.dependency("transit_catalog", .{ .target = target, .optimize = optimize });
    const module = b.addModule("transit_sql", .{ .root_source_file = b.path("src/root.zig"), .target = target, .optimize = optimize, .imports = &.{ .{ .name = "transit_client", .module = b.dependency("transit_client", .{ .target = target, .optimize = optimize }).module("transit_client") }, .{ .name = "transit_query_direct", .module = b.dependency("transit_query_direct", .{ .target = target, .optimize = optimize }).module("transit_query_direct") }, .{ .name = "transit_sql_results", .module = b.dependency("transit_sql_results", .{ .target = target, .optimize = optimize }).module("transit_sql_results") }, .{ .name = "transit_sql_protocol", .module = protocol.module("transit_sql_protocol") }, .{ .name = "transit_catalog", .module = catalog.module("transit_catalog") } } });
    const tests = b.addTest(.{ .root_module = module });
    module.addImport("transit_memory", b.dependency("transit_memory", .{ .target = target, .optimize = optimize }).module("transit_memory"));
    requireDatabaseDependencies(b, module);
    b.step("test", "Test database SQL and account recovery").dependOn(&b.addRunArtifact(tests).step);
    b.step("check", "Compile the shared SQL runtime").dependOn(&tests.step);
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
