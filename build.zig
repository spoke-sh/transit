const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const adapter = b.dependency("transit_ursula", .{ .target = target, .optimize = optimize });
    const tests = b.addTest(.{ .root_module = adapter.module("transit_ursula") });
    const test_step = b.step("test", "Run Zig unit and protocol tests");
    test_step.dependOn(&b.addRunArtifact(tests).step);
    const transit = b.dependency("transit", .{ .target = target, .optimize = optimize });
    const client = b.dependency("transit_client", .{ .target = target, .optimize = optimize });
    const runtime = b.dependency("runtime_substrate", .{ .target = target, .optimize = optimize });
    test_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = runtime.module("runtime_substrate") })).step);
    const counter = b.createModule(.{
        .root_source_file = b.path("examples/counter.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "transit", .module = transit.module("transit") }},
    });
    const services = b.addSystemCommand(&.{ "python3", "-B" });
    const apps_step = b.step("apps", "Install application executables without storage proof binaries");
    const probe = b.addExecutable(.{ .name = "isolation-probe", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/isolation.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    }) });
    const install_probe = b.addInstallArtifact(probe, .{});
    b.step("probe", "Install the adversarial reference sandbox executable").dependOn(&install_probe.step);
    test_step.dependOn(&probe.step);
    services.addFileArg(b.path("tests/service.py"));
    for ([_][]const u8{ "transit-node", "transit-worker", "rey-cli", "runtime-controller" }) |name| {
        const app = b.addExecutable(.{ .name = name, .root_module = b.createModule(.{
            .root_source_file = b.path(b.fmt("apps/{s}/main.zig", .{name})),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{
                .{ .name = "transit", .module = transit.module("transit") },
                .{ .name = "transit_client", .module = client.module("transit_client") },
                .{ .name = "counter", .module = counter },
            },
        }) });
        if (std.mem.eql(u8, name, "transit-node")) app.root_module.addImport("transit_ursula", adapter.module("transit_ursula"));
        const install = b.addInstallArtifact(app, .{});
        b.getInstallStep().dependOn(&install.step);
        apps_step.dependOn(&install.step);
        if (std.mem.eql(u8, name, "runtime-controller")) app.root_module.addImport("runtime_substrate", runtime.module("runtime_substrate")) else services.addArtifactArg(app);
        if (std.mem.eql(u8, name, "transit-node") and target.result.os.tag == .linux) {
            const clock_c = b.addTranslateC(.{ .root_source_file = b.path("apps/transit-node/clock.h"), .target = target, .optimize = optimize });
            app.root_module.addImport("clock_c", clock_c.createModule());
        }
        test_step.dependOn(&app.step);
    }
    services.has_side_effects = true;
    services.stdio = .inherit;
    // A separately compiled, reviewed test workload emits one scalar intent.
    // It is never installed as the counter node or accepted into its realms.
    const effect_counter = b.createModule(.{
        .root_source_file = b.path("tests/effect_counter.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "transit", .module = transit.module("transit") }},
    });
    for ([_][]const u8{ "effect-node", "effect-executor" }) |name| {
        const is_node = std.mem.eql(u8, name, "effect-node");
        const proof = b.addExecutable(.{ .name = name, .root_module = b.createModule(.{
            .root_source_file = b.path(if (is_node) "apps/transit-node/main.zig" else "tests/effect_executor.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{
                .{ .name = "transit", .module = transit.module("transit") },
                .{ .name = "transit_client", .module = client.module("transit_client") },
            },
        }) });
        if (is_node) {
            proof.root_module.addImport("counter", effect_counter);
            proof.root_module.addImport("transit_ursula", adapter.module("transit_ursula"));
            if (target.result.os.tag == .linux) {
                const clock_c = b.addTranslateC(.{ .root_source_file = b.path("apps/transit-node/clock.h"), .target = target, .optimize = optimize });
                proof.root_module.addImport("clock_c", clock_c.createModule());
            }
        }
        services.addArtifactArg(proof);
        test_step.dependOn(&proof.step);
    }
    b.step("test-service", "Prove signed ingress and worker recovery over HTTP").dependOn(&services.step);
    test_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = transit.module("transit") })).step);
    const integration = b.addSystemCommand(&.{ "python3", "-B" });
    integration.addFileArg(b.path("tests/storage.py"));
    for ([_][]const u8{ "storage", "kernel", "effects", "lifetime", "outbox", "runtime", "deletion" }) |name| {
        const proof = b.addExecutable(.{
            .name = b.fmt("transit-{s}-proof", .{name}),
            .root_module = b.createModule(.{
                .root_source_file = b.path(b.fmt("tests/{s}.zig", .{name})),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "transit", .module = transit.module("transit") },
                    .{ .name = "transit_ursula", .module = adapter.module("transit_ursula") },
                },
            }),
        });
        b.installArtifact(proof);
        integration.addArtifactArg(proof);
        if (std.mem.eql(u8, name, "deletion")) services.addArtifactArg(proof);
    }
    integration.has_side_effects = true;
    integration.stdio = .inherit;
    b.step("test-storage", "Prove conditional writes and disk recovery against Ursula").dependOn(&integration.step);
    const capacity = b.addExecutable(.{ .name = "transit-capacity-proof", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/capacity.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "transit", .module = transit.module("transit") },
            .{ .name = "transit_ursula", .module = adapter.module("transit_ursula") },
        },
    }) });
    b.step("capacity-proof", "Install the physical storage pressure proof driver").dependOn(&b.addInstallArtifact(capacity, .{}).step);
    test_step.dependOn(&capacity.step);
}
