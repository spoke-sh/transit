const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const fuze = b.dependency("transit_fuze", .{ .target = target, .optimize = optimize });
    const station = b.dependency("transit_station", .{ .target = target, .optimize = optimize });
    b.step("station-contract", "Export reflected Station ABI and host schemas").dependOn(&b.addRunArtifact(station.artifact("transit-station-contract")).step);
    b.step("station-abi", "Build the shared Station implementation").dependOn(&b.addInstallArtifact(station.artifact("transit_station"), .{}).step);
    const arrow_proof = b.addExecutable(.{ .name = "transit-arrow-proof", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/arrow.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "transit_fuze", .module = fuze.module("transit_fuze") }},
    }) });
    const arrow_test = b.addSystemCommand(&.{ "python3", "-B" });
    arrow_test.addFileArg(b.path("tests/arrow.py"));
    arrow_test.addArtifactArg(arrow_proof);
    arrow_test.has_side_effects = true;
    arrow_test.stdio = .inherit;
    b.step("test-arrow", "Qualify finite IPC with an independent Arrow implementation").dependOn(&arrow_test.step);
    const observations = b.dependency("transit_observability", .{ .target = target, .optimize = optimize });
    const telemetry = b.dependency("telemetry", .{ .target = target, .optimize = optimize });
    const adapter = b.dependency("transit_backend_ursula", .{ .target = target, .optimize = optimize });
    const tests = b.addTest(.{ .root_module = adapter.module("transit_backend_ursula") });
    const test_step = b.step("test", "Run Zig unit and protocol tests");
    const build_test_step = b.step("test-build", "Compile applications and integration probes");
    test_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = station.module("transit_station") })).step);
    test_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = fuze.module("transit_fuze") })).step);
    test_step.dependOn(&b.addRunArtifact(tests).step);
    test_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = telemetry.module("telemetry") })).step);
    const telemetry_proof = b.addExecutable(.{ .name = "telemetry-proof", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/telemetry.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "telemetry", .module = telemetry.module("telemetry") }},
    }) });
    const telemetry_test = b.addSystemCommand(&.{ "python3", "-B" });
    telemetry_test.addFileArg(b.path("tests/telemetry.py"));
    telemetry_test.addArtifactArg(telemetry_proof);
    telemetry_test.has_side_effects = true;
    telemetry_test.stdio = .inherit;
    b.step("test-telemetry", "Prove bounded telemetry under stalled and closed sinks").dependOn(&telemetry_test.step);
    test_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = observations.module("transit_observability") })).step);
    const core = b.dependency("transit_core", .{ .target = target, .optimize = optimize });
    const page_proof = b.addExecutable(.{ .name = "transit-page-proof", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/pages.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{ .{ .name = "transit_core", .module = core.module("transit_core") }, .{ .name = "transit_backend_ursula", .module = adapter.module("transit_backend_ursula") } },
    }) });
    const page_test = b.addSystemCommand(&.{ "python3", "-B" });
    page_test.addFileArg(b.path("tests/pages.py"));
    page_test.addArtifactArg(page_proof);
    page_test.addPassthruArgs();
    page_test.has_side_effects = true;
    page_test.stdio = .inherit;
    b.step("test-pages", "Qualify immutable pages and bounded cache over disk Ursula").dependOn(&page_test.step);
    const transition_driver = b.addExecutable(.{ .name = "transit-transition-driver", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/transition_driver.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "transit_core", .module = core.module("transit_core") }},
    }) });
    const properties = b.addSystemCommand(&.{ "python3", "-B" });
    properties.addFileArg(b.path("tests/verification/transitions.py"));
    properties.addArtifactArg(transition_driver);
    properties.addPassthruArgs();
    properties.has_side_effects = true;
    properties.stdio = .inherit;
    b.step("test-properties", "Run reproducible authority schedules and saved regressions").dependOn(&properties.step);
    const formal = b.addSystemCommand(&.{ "python3", "-B" });
    formal.addFileArg(b.path("tests/verification/model.py"));
    formal.addArtifactArg(transition_driver);
    formal.addPassthruArgs();
    formal.has_side_effects = true;
    formal.stdio = .inherit;
    b.step("test-model", "Check finite authority model and replay counterexamples against Zig").dependOn(&formal.step);
    const protocol = b.dependency("transit_protocol", .{ .target = target, .optimize = optimize });
    // The pinned native x86 backend does not emit usable fuzz coverage yet.
    const codec_module = b.createModule(.{
        .root_source_file = b.path("tests/codecs.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{ .{ .name = "transit_protocol", .module = protocol.module("transit_protocol") }, .{ .name = "station_frame", .module = station.module("station_frame") } },
    });
    const codec_step = b.step("test-codecs", "Run bounded codec corpus and allocation failure enumeration");
    // Separate runs give both boundaries their own finite fuzz budget.
    inline for (.{ "signed request", "Station frames" }) |filter| {
        const codecs = b.addTest(.{ .use_llvm = true, .root_module = codec_module, .filters = &.{ filter, "allocation failures release parser" } });
        codec_step.dependOn(&b.addRunArtifact(codecs).step);
    }
    const exporter = b.addExecutable(.{ .name = "transit-contract", .root_module = b.createModule(.{ .root_source_file = b.path("packages/zig/transit-protocol/src/export.zig"), .target = target, .optimize = optimize, .imports = &.{.{ .name = "transit_protocol", .module = protocol.module("transit_protocol") }} }) });
    b.step("contract", "Export public contract JSON Schema to stdout").dependOn(&b.addRunArtifact(exporter).step);
    test_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = protocol.module("transit_protocol") })).step);
    const transit_board_api = b.dependency("transit_board_api", .{ .target = target, .optimize = optimize });
    test_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = transit_board_api.module("transit_board_api") })).step);
    const board_contract = b.addExecutable(.{ .name = "transit-board-contract", .root_module = b.createModule(.{ .root_source_file = b.path("packages/zig/transit-board-api/src/export.zig"), .target = target, .optimize = optimize, .imports = &.{.{ .name = "transit_board_api", .module = transit_board_api.module("transit_board_api") }} }) });
    b.step("transit-board-contract", "Export Board OpenAPI to stdout").dependOn(&b.addRunArtifact(board_contract).step);
    const client = b.dependency("transit_client", .{ .target = target, .optimize = optimize });
    b.step("client-contract", "Export reflected client ABI signatures").dependOn(&b.addRunArtifact(client.artifact("transit-client-contract")).step);
    b.step("client-abi", "Build the shared client library").dependOn(&b.addInstallArtifact(client.artifact("transit_client"), .{}).step);
    test_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = client.module("transit_client") })).step);
    test_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = client.module("client_abi") })).step);
    const embed = b.addSystemCommand(&.{ "python3", "-B" });
    embed.addFileArg(b.path("apps/transit-board/embed.py"));
    const asset_source = embed.addOutputFileArg("assets.zig");
    // Vite owns its dependency graph. Always rebuild the closed asset manifest;
    // Zig still caches compilation by the resulting bytes.
    embed.has_side_effects = true;
    const asset_module = b.createModule(.{ .root_source_file = asset_source, .target = target, .optimize = optimize });
    const board = b.addExecutable(.{ .name = "transit-board", .root_module = b.createModule(.{ .root_source_file = b.path("apps/transit-board/main.zig"), .target = target, .optimize = optimize, .imports = &.{
        .{ .name = "transit_client", .module = client.module("transit_client") },
        .{ .name = "transit_board_api", .module = transit_board_api.module("transit_board_api") },
        .{ .name = "assets", .module = asset_module },
        .{ .name = "telemetry", .module = telemetry.module("telemetry") },
    } }) });
    const install_board = b.addInstallArtifact(board, .{});
    b.step("transit-board", "Build the standalone Board API and embedded UI").dependOn(&install_board.step);
    b.getInstallStep().dependOn(&install_board.step);
    b.step("test-transit-board-unit", "Test Board ingress and route boundaries").dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = board.root_module })).step);
    const runtime = b.dependency("transit_runtime_substrate", .{ .target = target, .optimize = optimize });
    test_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = runtime.module("transit_runtime_substrate") })).step);
    var node_artifact: *std.Build.Step.Compile = undefined;
    var cli_artifact: *std.Build.Step.Compile = undefined;
    var delivery_artifact: *std.Build.Step.Compile = undefined;
    var controller_artifact: *std.Build.Step.Compile = undefined;
    const services = b.addSystemCommand(&.{ "python3", "-B" });
    const apps_step = b.step("apps", "Install platform executables");
    const kubectl_transit = b.addExecutable(.{ .name = "kubectl-transit", .root_module = b.createModule(.{
        .root_source_file = b.path("apps/kubectl-transit/main.zig"),
        .target = target,
        .optimize = optimize,
    }) });
    const install_plugin = b.addInstallArtifact(kubectl_transit, .{});
    apps_step.dependOn(&install_plugin.step);
    b.getInstallStep().dependOn(&install_plugin.step);
    b.step("kubectl-transit", "Install the Kubernetes inspection plugin").dependOn(&install_plugin.step);
    const plugin_tests = b.addSystemCommand(&.{ "python3", "-B" });
    plugin_tests.addFileArg(b.path("tests/kubectl_transit.py"));
    plugin_tests.addArtifactArg(kubectl_transit);
    plugin_tests.has_side_effects = true;
    plugin_tests.stdio = .inherit;
    b.step("test-kubectl-transit", "Verify Kubernetes plugin boundaries without a cluster").dependOn(&plugin_tests.step);
    const probe = b.addExecutable(.{ .name = "isolation-probe", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/isolation.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    }) });
    const install_probe = b.addInstallArtifact(probe, .{});
    b.step("probe", "Install the adversarial reference sandbox executable").dependOn(&install_probe.step);
    build_test_step.dependOn(&probe.step);
    services.addFileArg(b.path("tests/service.py"));
    var station_controller: *std.Build.Step.Compile = undefined;
    var station_host: *std.Build.Step.Compile = undefined;
    for ([_][]const u8{ "transit-node", "rey-cli", "transit-runtime-controller", "transit-delivery", "transit-station-controller", "transit-station-host" }) |name| {
        const app = b.addExecutable(.{ .name = name, .root_module = b.createModule(.{
            .root_source_file = b.path(b.fmt("apps/{s}/main.zig", .{name})),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{
                .{ .name = "transit_client", .module = client.module("transit_client") },
                .{ .name = "transit_observability", .module = observations.module("transit_observability") },
            },
        }) });
        if (std.mem.eql(u8, name, "transit-node")) app.root_module.addImport("transit_core", core.module("transit_core"));
        if (std.mem.eql(u8, name, "transit-node")) app.root_module.addImport("transit_backend_ursula", adapter.module("transit_backend_ursula"));
        if (std.mem.eql(u8, name, "transit-node")) node_artifact = app;
        if (std.mem.eql(u8, name, "rey-cli")) cli_artifact = app;
        if (std.mem.eql(u8, name, "transit-delivery")) delivery_artifact = app;
        if (std.mem.eql(u8, name, "transit-runtime-controller")) controller_artifact = app;
        const install = b.addInstallArtifact(app, .{});
        b.getInstallStep().dependOn(&install.step);
        apps_step.dependOn(&install.step);
        b.step(name, b.fmt("Install {s}", .{name})).dependOn(&install.step);
        if (std.mem.eql(u8, name, "transit-runtime-controller")) app.root_module.addImport("transit_runtime_substrate", runtime.module("transit_runtime_substrate"));
        if (std.mem.eql(u8, name, "transit-station-controller")) {
            app.root_module.addImport("transit_station", station.module("transit_station"));
            station_controller = app;
        }
        if (std.mem.eql(u8, name, "transit-station-host")) {
            station_host = app;
            app.root_module.addImport("transit_station", station.module("transit_station"));
            app.root_module.addImport("station_abi", station.module("station_abi"));
            app.root_module.addImport("client_abi", client.module("client_abi"));
        }
        if (std.mem.eql(u8, name, "transit-node") and target.result.os.tag == .linux) {
            const clock_c = b.addTranslateC(.{ .root_source_file = b.path("apps/transit-node/clock.h"), .target = target, .optimize = optimize });
            app.root_module.addImport("clock_c", clock_c.createModule());
        }
        build_test_step.dependOn(&app.step);
    }
    const c_proof = b.addExecutable(.{ .name = "transit-client-c-proof", .root_module = b.createModule(.{ .target = target, .optimize = optimize, .link_libc = true }) });
    c_proof.root_module.addCSourceFile(.{ .file = b.path("tests/client_abi.c"), .flags = &.{ "-std=c11", "-Wall", "-Werror" } });
    c_proof.root_module.addIncludePath(b.path("packages/zig/transit-client/include"));
    c_proof.root_module.linkLibrary(client.artifact("transit_client"));
    const abi_tests = b.addSystemCommand(&.{ "python3", "-B" });
    abi_tests.addFileArg(b.path("tests/client_abi.py"));
    abi_tests.addArtifactArg(client.artifact("transit_client"));
    abi_tests.addArtifactArg(node_artifact);
    abi_tests.addArtifactArg(cli_artifact);
    abi_tests.addArtifactArg(c_proof);
    abi_tests.has_side_effects = true;
    abi_tests.stdio = .inherit;
    b.step("test-client-abi", "Prove the C ABI against real authority and host loss").dependOn(&abi_tests.step);
    const binding_tests = b.addSystemCommand(&.{ "python3", "-B" });
    binding_tests.addFileArg(b.path("tests/bindings.py"));
    binding_tests.addArtifactArg(node_artifact);
    binding_tests.addArtifactArg(cli_artifact);
    binding_tests.addArtifactArg(delivery_artifact);
    binding_tests.addArtifactArg(station.artifact("transit_station"));
    binding_tests.addArtifactArg(client.artifact("transit_client"));
    binding_tests.addArtifactArg(station_host);
    const binding_examples = b.step("bindings-examples", "Install the C and C++ Station callers");
    inline for (.{ "c", "cpp" }) |language| {
        const cpp = std.mem.eql(u8, language, "cpp");
        const caller = b.addExecutable(.{ .name = "station-" ++ language ++ "-example", .root_module = b.createModule(.{ .target = target, .optimize = optimize, .link_libc = true, .link_libcpp = cpp }) });
        caller.root_module.addIncludePath(b.path("packages/zig/transit-station/include"));
        caller.root_module.addIncludePath(b.path("packages/zig/transit-client/include"));
        caller.root_module.addIncludePath(b.path("packages/cpp/transit-station/include"));
        caller.root_module.addCSourceFile(.{ .file = b.path("examples/station-bindings/" ++ language ++ "/main." ++ language), .flags = if (cpp) &.{ "-std=c++17", "-Wall", "-Wextra", "-Werror" } else &.{ "-std=c11", "-D_POSIX_C_SOURCE=200809L", "-Wall", "-Wextra", "-Werror" } });
        caller.root_module.linkLibrary(station.artifact("transit_station"));
        caller.root_module.linkLibrary(client.artifact("transit_client"));
        binding_examples.dependOn(&b.addInstallArtifact(caller, .{}).step);
        binding_tests.addArtifactArg(caller);
    }
    if (b.option(bool, "bindings-foreign", "Qualify additional runtimes from the bindings development shell") orelse false) binding_tests.addArg("foreign");
    binding_tests.has_side_effects = true;
    binding_tests.stdio = .inherit;
    b.step("test-bindings", "Qualify foreign Station callers against durable authority").dependOn(&binding_tests.step);
    const readiness_caller = b.addExecutable(.{ .name = "transit-readiness-caller", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/readiness_client.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "transit_client", .module = client.module("transit_client") }},
    }) });
    b.step("readiness-caller", "Install the runtime readiness caller proof").dependOn(&b.addInstallArtifact(readiness_caller, .{}).step);
    build_test_step.dependOn(&readiness_caller.step);
    const examples_step = b.step("examples", "Install runnable example applications");
    const station_ledger = b.addExecutable(.{ .name = "example-station-ledger", .root_module = b.createModule(.{
        .root_source_file = b.path("examples/station-ledger/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "transit_station", .module = station.module("transit_station") }},
    }) });
    const install_ledger = b.addInstallArtifact(station_ledger, .{});
    b.step("example-station-ledger", "Install the Station ledger example").dependOn(&install_ledger.step);
    examples_step.dependOn(&install_ledger.step);
    b.getInstallStep().dependOn(&install_ledger.step);
    const station_test = b.addSystemCommand(&.{ "python3", "-B" });
    station_test.addFileArg(b.path("tests/station.py"));
    station_test.addArtifactArg(node_artifact);
    station_test.addArtifactArg(cli_artifact);
    station_test.addArtifactArg(station_ledger);
    station_test.addArtifactArg(delivery_artifact);
    station_test.addArtifactArg(station_controller);
    station_test.has_side_effects = true;
    station_test.stdio = .inherit;
    b.step("test-station", "Prove recoverable Station callers against durable authority").dependOn(&station_test.step);
    const upgrade_tests = b.addSystemCommand(&.{ "python3", "-B" });
    upgrade_tests.addFileArg(b.path("tests/runtime_upgrade.py"));
    upgrade_tests.addArtifactArg(node_artifact);
    upgrade_tests.addArtifactArg(cli_artifact);
    upgrade_tests.addArtifactArg(controller_artifact);
    upgrade_tests.has_side_effects = true;
    upgrade_tests.stdio = .inherit;
    b.step("test-runtime-upgrade", "Prove provider-switch reconciliation and fencing").dependOn(&upgrade_tests.step);
    var example_artifacts: [2]*std.Build.Step.Compile = undefined;
    inline for (.{ "counter", "byte-log" }, 0..) |name, index| {
        const example = b.addExecutable(.{ .name = "example-" ++ name, .root_module = b.createModule(.{
            .root_source_file = b.path("examples/" ++ name ++ "/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "transit_client", .module = client.module("transit_client") }},
        }) });
        example_artifacts[index] = example;
        const install = b.addInstallArtifact(example, .{});
        examples_step.dependOn(&install.step);
        b.step("example-" ++ name, "Install example-" ++ name).dependOn(&install.step);
        build_test_step.dependOn(&example.step);
    }
    services.addArtifactArg(node_artifact);
    services.addArtifactArg(example_artifacts[0]);
    services.addArtifactArg(cli_artifact);
    services.has_side_effects = true;
    services.stdio = .inherit;
    const executor = b.addExecutable(.{ .name = "effect-executor", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/effect_executor.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "transit_client", .module = client.module("transit_client") }},
    }) });
    services.addArtifactArg(executor);
    build_test_step.dependOn(&executor.step);
    b.step("test-service", "Prove signed ingress and worker recovery over HTTP").dependOn(&services.step);
    test_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = core.module("transit_core") })).step);
    const integration = b.addSystemCommand(&.{ "python3", "-B" });
    integration.addFileArg(b.path("tests/storage.py"));
    const proofs_step = b.step("proofs", "Install disk conformance proof executables");
    for ([_][]const u8{ "storage", "kernel", "effects", "lifetime", "outbox", "runtime", "deletion", "state", "readiness" }) |name| {
        const proof = b.addExecutable(.{
            .name = b.fmt("transit-{s}-proof", .{name}),
            .root_module = b.createModule(.{
                .root_source_file = b.path(b.fmt("tests/{s}.zig", .{name})),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "transit_core", .module = core.module("transit_core") },
                    .{ .name = "transit_backend_ursula", .module = adapter.module("transit_backend_ursula") },
                },
            }),
        });
        proofs_step.dependOn(&b.addInstallArtifact(proof, .{}).step);
        integration.addArtifactArg(proof);
        if (std.mem.eql(u8, name, "deletion")) services.addArtifactArg(proof);
    }
    integration.has_side_effects = true;
    integration.stdio = .inherit;
    b.step("test-storage", "Prove conditional writes and disk recovery against Ursula").dependOn(&integration.step);
    const board_tests = b.addSystemCommand(&.{ "python3", "-B" });
    board_tests.addFileArg(b.path("tests/board.py"));
    board_tests.addArtifactArg(node_artifact);
    board_tests.addArtifactArg(cli_artifact);
    board_tests.addArtifactArg(board);
    if (b.option(bool, "transit-board-browser", "Include real browser qualification") orelse false) board_tests.addArg("--browser");
    board_tests.has_side_effects = true;
    board_tests.stdio = .inherit;
    b.step("test-transit-board", "Qualify Board against disk-backed Transit").dependOn(&board_tests.step);
    const observation_tests = b.addSystemCommand(&.{ "python3", "-B" });
    observation_tests.addFileArg(b.path("tests/observability.py"));
    observation_tests.addArtifactArg(node_artifact);
    observation_tests.addArtifactArg(cli_artifact);
    observation_tests.addArtifactArg(board);
    observation_tests.has_side_effects = true;
    observation_tests.stdio = .inherit;
    b.step("test-observability", "Prove cross-service correlation and diagnostic semantics").dependOn(&observation_tests.step);
    const inspection = b.addSystemCommand(&.{ "python3", "-B" });
    inspection.addFileArg(b.path("tests/inspection.py"));
    inspection.addArtifactArg(node_artifact);
    inspection.addArtifactArg(cli_artifact);
    inspection.has_side_effects = true;
    inspection.stdio = .inherit;
    b.step("test-inspection", "Prove scoped public inspection against disk Ursula").dependOn(&inspection.step);
    const state_api = b.addSystemCommand(&.{ "python3", "-B" });
    state_api.addFileArg(b.path("tests/state_api.py"));
    state_api.addArtifactArg(node_artifact);
    state_api.addArtifactArg(cli_artifact);
    state_api.addArtifactArg(example_artifacts[0]);
    state_api.has_side_effects = true;
    state_api.stdio = .inherit;
    b.step("test-state", "Prove state resources through the public service").dependOn(&state_api.step);
    const callers = b.addSystemCommand(&.{ "python3", "-B", "-c", "import sys; sys.path.insert(0, 'tests'); from pathlib import Path; from callers import run; run(*[Path(p).resolve() for p in sys.argv[1:]])" });
    // Both callers use the exact same authority and public CLI artifacts.
    callers.addArtifactArg(node_artifact);
    callers.addArtifactArg(cli_artifact);
    for (example_artifacts) |example| callers.addArtifactArg(example);
    const client_probe = b.addExecutable(.{ .name = "client-probe", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/client_probe.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "transit_client", .module = client.module("transit_client") }},
    }) });
    callers.addArtifactArg(client_probe);
    callers.addArtifactArg(delivery_artifact);
    build_test_step.dependOn(&client_probe.step);
    callers.has_side_effects = true;
    callers.stdio = .inherit;
    b.step("test-callers", "Prove two independent Zig applications against one generic node").dependOn(&callers.step);
    const capacity = b.addExecutable(.{ .name = "transit-capacity-proof", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/capacity.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "transit_core", .module = core.module("transit_core") },
            .{ .name = "transit_backend_ursula", .module = adapter.module("transit_backend_ursula") },
        },
    }) });
    b.step("capacity-proof", "Install the physical storage pressure proof driver").dependOn(&b.addInstallArtifact(capacity, .{}).step);
    build_test_step.dependOn(&capacity.step);
}
