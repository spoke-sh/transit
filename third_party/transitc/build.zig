const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const embedded = b.option(bool, "embedded", "Export libraries for a caller supplying shared modules") orelse false;
    const workspace_dep = b.dependency("transitc_workspace", .{ .target = target, .optimize = optimize, .embedded = embedded });
    const workspace = workspace_dep.module("transitc_workspace");
    const compiler = if (embedded) b.dependency("transitc_compiler", .{ .target = target, .optimize = optimize, .embedded = true }).module("transitc_compiler") else workspace_dep.module("transitc_compiler");
    workspace.addImport("transit_compiler", compiler);
    b.modules.put(b.allocator, "transitc_compiler", compiler) catch @panic("out of memory");
    b.modules.put(b.allocator, "transitc_workspace", workspace) catch @panic("out of memory");
    if (embedded) return;
    const options = b.addOptions();
    options.addOption([]const u8, "version", "0.0.0-dev");
    options.addOption([]const u8, "revision", b.option([]const u8, "revision", "Compiler Git revision for provenance") orelse "development");
    options.addOption([]const u8, "test_runtime", b.option([]const u8, "test-runtime", "Transit executable providing the compiled-case test host") orelse "transit");
    const cli = b.addExecutable(.{ .name = "transitc", .root_module = b.createModule(.{
        .root_source_file = b.path("apps/transitc-cli/src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "transitc_workspace", .module = workspace }},
    }) });
    cli.root_module.addOptions("build_options", options);
    b.installArtifact(cli);
    const check = b.step("check", "Compile CLI and library tests");
    check.dependOn(&cli.step);
    const test_step = b.step("test", "Run compiler and workspace tests");
    for ([_]*std.Build.Module{ compiler, workspace }) |module| {
        const tests = b.addTest(.{ .root_module = module });
        check.dependOn(&tests.step);
        test_step.dependOn(&b.addRunArtifact(tests).step);
    }
    const embedded_example = b.addExecutable(.{ .name = "transitc-embed-example", .root_module = b.createModule(.{
        .root_source_file = b.path("examples/embed/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "transitc_compiler", .module = compiler },
            .{ .name = "transit_protocol", .module = compiler.import_table.get("transit_protocol").? },
        },
    }) });
    check.dependOn(&embedded_example.step);
    const embed_run = b.addRunArtifact(embedded_example);
    test_step.dependOn(&embed_run.step);
    b.step("test-embed", "Compile and run the public embedding example").dependOn(&embed_run.step);
    const probe = b.addExecutable(.{ .name = "transitc-source-probe", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/query/application_source/driver.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "transit_compiler", .module = compiler },
            .{ .name = "transit_protocol", .module = compiler.import_table.get("transit_protocol").? },
            .{ .name = "transit_memory", .module = compiler.import_table.get("transit_memory").? },
        },
    }) });
    const install_probe = b.addInstallArtifact(probe, .{});
    b.step("source-probe", "Build the private independent comparison adapter").dependOn(&install_probe.step);
    const run = b.addRunArtifact(cli);
    run.addPassthruArgs();
    b.step("run", "Run transitc").dependOn(&run.step);
}
