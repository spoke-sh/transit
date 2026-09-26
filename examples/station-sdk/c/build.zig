const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const settings = .{ .target = target, .optimize = optimize };
    const client = b.dependency("transit_sdk_client", settings);
    const station = b.dependency("transit_sdk_station", settings);
    const module = b.addModule("transit_sdk_examples_c", .{ .target = target, .optimize = optimize, .link_libc = true });
    module.addIncludePath(b.path("include"));
    module.addIncludePath(client.path("include"));
    module.addIncludePath(station.path("include"));
    for ([_][]const u8{ "src/codecs.c", "src/handlers.c" }) |source| module.addCSourceFile(.{ .file = b.path(source), .flags = &.{ "-std=c11", "-Wall", "-Wextra", "-Werror" } });
    const library = b.addLibrary(.{ .name = "transit_sdk_examples_c", .linkage = .static, .root_module = module });
    library.installHeadersDirectory(b.path("include"), "", .{});
    b.installArtifact(library);
    const main = b.createModule(.{ .target = target, .optimize = optimize, .link_libc = true });
    main.addCSourceFile(.{ .file = b.path("src/main.c"), .flags = &.{ "-std=c11", "-Wall", "-Wextra", "-Werror" } });
    main.addIncludePath(b.path("include"));
    main.addIncludePath(client.path("include"));
    main.addIncludePath(station.path("include"));
    main.linkLibrary(library);
    main.linkLibrary(client.artifact("transit_sdk_client"));
    main.linkLibrary(station.artifact("transit_sdk_station"));
    main.addRPathSpecial("$ORIGIN/../lib");
    const cli = b.addExecutable(.{ .name = "transit-c-counter", .root_module = main });
    b.installArtifact(cli);
    b.step("check", "Build the real C counter CLI and Table/query handlers").dependOn(&cli.step);
}
