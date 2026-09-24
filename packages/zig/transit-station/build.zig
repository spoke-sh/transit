const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const client = b.dependency("transit_client", .{ .target = target, .optimize = optimize });
    const fuze = b.dependency("transit_fuze", .{ .target = target, .optimize = optimize });
    const module = b.addModule("transit_station", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{ .{ .name = "transit_client", .module = client.module("transit_client") }, .{ .name = "transit_fuze", .module = fuze.module("transit_fuze") } },
    });
    b.step("test", "Prove Station turns and mailbox protocols").dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = module })).step);
}
