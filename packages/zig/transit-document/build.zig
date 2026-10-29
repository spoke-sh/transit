const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const module = b.addModule("transit_document", .{ .root_source_file = b.path("src/root.zig"), .target = target, .optimize = optimize });
    requireDatabaseDependencies(b, module);
    const filters = b.option([]const []const u8, "test-filter", "Run selected Document tests") orelse &.{};
    const tests = b.addTest(.{ .root_module = module, .filters = filters });
    b.step("test", "Qualify deterministic Document semantics").dependOn(&b.addRunArtifact(tests).step);
    b.step("check", "Compile the independent Document library").dependOn(&tests.step);
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
