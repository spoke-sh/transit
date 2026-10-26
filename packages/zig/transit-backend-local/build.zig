const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const core = b.dependency("transit_core", .{ .target = target, .optimize = optimize }).module("transit_core");
    const storage = b.dependency("transit_storage", .{ .target = target, .optimize = optimize }).module("transit_storage");
    const observations = b.dependency("transit_observability", .{ .target = target, .optimize = optimize }).module("transit_observability");
    const fuze = b.dependency("transit_fuze", .{ .target = target, .optimize = optimize }).module("transit_fuze");
    const module = b.addModule("transit_backend_local", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{ .{ .name = "transit_core", .module = core }, .{ .name = "transit_storage", .module = storage }, .{ .name = "transit_observability", .module = observations } },
    });
    module.addImport("transit_fuze", fuze);
    const filters = b.option([]const []const u8, "test-filter", "Run local native tests whose names contain a filter") orelse &.{};
    const tests = b.addTest(.{ .root_module = module, .filters = filters });
    b.step("test", "Verify native authority over local durable storage").dependOn(&b.addRunArtifact(tests).step);
    b.step("check", "Compile local native persistence checks").dependOn(&tests.step);
}
