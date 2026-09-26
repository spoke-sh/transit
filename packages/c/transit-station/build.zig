const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const settings = .{ .target = target, .optimize = optimize };
    const client = b.dependency("transit_sdk_client", settings);
    const module = b.addModule("transit_sdk_station", .{ .target = target, .optimize = optimize, .link_libc = true, .link_libcpp = true });
    module.addIncludePath(b.path("include"));
    module.addIncludePath(client.path("include"));
    module.addIncludePath(b.dependency("transit_client", settings).path("include"));
    module.addIncludePath(b.dependency("transit_station_bindings", settings).path("include"));
    module.linkLibrary(client.artifact("transit_sdk_client"));
    module.addRPathSpecial("$ORIGIN");
    for ([_][]const u8{ "src/bridge.cpp", "src/runner.cpp", "src/turn.cpp", "src/table.cpp", "src/query.cpp", "src/http.cpp" }) |source| {
        module.addCSourceFile(.{ .file = b.path(source), .flags = &.{ "-std=c++17", "-Wall", "-Wextra", "-Werror" } });
    }
    module.linkSystemLibrary("dl", .{});
    module.linkSystemLibrary("pthread", .{});
    const library = b.addLibrary(.{ .name = "transit_sdk_station", .linkage = .dynamic, .root_module = module });
    library.installHeadersDirectory(b.path("include"), "", .{});
    b.installArtifact(library);
    b.step("check", "Compile the typed Station C SDK").dependOn(&library.step);
}
