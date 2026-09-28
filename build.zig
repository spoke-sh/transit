const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const http_server = b.dependency("transit_http_server", .{ .target = target, .optimize = optimize });
    const serving_http = b.dependency("transit_serving_http", .{ .target = target, .optimize = optimize });
    const application = b.dependency("transit_station_app", .{ .target = target, .optimize = optimize });
    const install_app = b.addInstallArtifact(application.artifact("transit-app"), .{});
    b.step("transit-app", "Install the bounded application declaration compiler").dependOn(&install_app.step);
    const serving = b.dependency("transit_serving", .{ .target = target, .optimize = optimize });
    const serving_api = b.addExecutable(.{ .name = "transit-serving-api", .root_module = b.createModule(.{
        .root_source_file = b.path("packages/zig/transit-serving/src/export.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "transit_serving", .module = serving.module("transit_serving") }},
    }) });
    b.step("serving-api", "Export reflected OpenAPI and AsyncAPI descriptions").dependOn(&b.addInstallArtifact(serving_api, .{}).step);
    const counter_embed = b.addSystemCommand(&.{ "python3", "-B" });
    counter_embed.addFileArg(b.path("tasks/embed_web.py"));
    const counter_assets = counter_embed.addOutputFileArg("assets.zig");
    counter_embed.addArg("examples/serving/web");
    counter_embed.has_side_effects = true;
    const counter_asset_module = b.createModule(.{ .root_source_file = counter_assets, .target = target, .optimize = optimize });
    const serving_example = b.addExecutable(.{ .name = "transit-serving-example", .root_module = b.createModule(.{
        .root_source_file = b.path("examples/serving/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{ .{ .name = "assets", .module = counter_asset_module }, .{ .name = "transit_serving_http", .module = serving_http.module("transit_serving_http") }, .{ .name = "transit_serving", .module = serving.module("transit_serving") }, .{ .name = "transit_http_server", .module = http_server.module("transit_http_server") } },
    }) });
    const install_serving = b.addInstallArtifact(serving_example, .{});
    b.step("serving-example", "Install the signed HTTP service example").dependOn(&install_serving.step);
    b.step("transit-serving-example", "Install the signed HTTP service artifact").dependOn(&install_serving.step);
    const document = b.dependency("transit_station_document", .{ .target = target, .optimize = optimize });
    const station_grpc = b.dependency("transit_station_grpc", .{ .target = target, .optimize = optimize });
    const station_flight = b.dependency("transit_station_flight", .{ .target = target, .optimize = optimize });
    const flight = b.dependency("transit_flight", .{ .target = target, .optimize = optimize });
    const grpc = b.dependency("transit_grpc", .{ .target = target, .optimize = optimize });
    const exchange = b.dependency("transit_exchange", .{ .target = target, .optimize = optimize });
    const station_http = b.dependency("transit_station_http", .{ .target = target, .optimize = optimize });
    const fuze = b.dependency("transit_fuze", .{ .target = target, .optimize = optimize });
    const query = b.dependency("transit_query", .{ .target = target, .optimize = optimize });
    b.step("query-api", "Export reflected query workspace declarations").dependOn(&b.addInstallArtifact(query.artifact("transit-query-api"), .{}).step);
    const station = b.dependency("transit_station", .{ .target = target, .optimize = optimize });
    const station_bindings = b.dependency("transit_station_bindings", .{ .target = target, .optimize = optimize });
    b.step("station-contract", "Export reflected Station ABI and host schemas").dependOn(&b.addRunArtifact(station_bindings.artifact("transit-station-contract")).step);
    b.step("station-abi", "Build the shared Station implementation").dependOn(&b.addInstallArtifact(station_bindings.artifact("transit_station"), .{}).step);
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
    const sql_driver = b.addExecutable(.{ .name = "transit-sql-proof", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/sql_driver.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "transit_fuze", .module = fuze.module("transit_fuze") }},
    }) });
    const sql_test = b.addSystemCommand(&.{ "python3", "-B" });
    sql_test.addFileArg(b.path("tests/sql/compiler.py"));
    sql_test.addArtifactArg(sql_driver);
    const unified_sql = b.addExecutable(.{ .name = "transit-unified-sql-proof", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/unified_sql.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "transit_fuze", .module = fuze.module("transit_fuze") }},
    }) });
    sql_test.addArtifactArg(unified_sql);
    sql_test.has_side_effects = true;
    sql_test.stdio = .inherit;
    b.step("test-sql", "Qualify SQL parser, plans and Arrow execution against independent references").dependOn(&sql_test.step);
    const observations = b.dependency("transit_observability", .{ .target = target, .optimize = optimize });
    const telemetry = b.dependency("telemetry", .{ .target = target, .optimize = optimize });
    const adapter = b.dependency("transit_backend_ursula", .{ .target = target, .optimize = optimize });
    const tests = b.addTest(.{ .root_module = adapter.module("transit_backend_ursula") });
    const test_step = b.step("test", "Run Zig unit and protocol tests");
    const work_items_module = b.createModule(.{ .root_source_file = b.path("examples/work-items/WorkItems.zig"), .target = target, .optimize = optimize, .imports = &.{ .{ .name = "transit_station_app", .module = application.module("transit_station_app") }, .{ .name = "transit_query", .module = query.module("transit_query") } } });
    const work_items_test = b.addRunArtifact(b.addTest(.{ .root_module = work_items_module }));
    const work_items = b.addExecutable(.{ .name = "transit-work-items", .root_module = b.createModule(.{ .root_source_file = b.path("examples/work-items/main.zig"), .target = target, .optimize = optimize, .imports = &.{.{ .name = "work_items", .module = work_items_module }} }) });
    const install_work_items = b.addInstallArtifact(work_items, .{});
    b.step("example-work-items", "Install the work-item application worker").dependOn(&install_work_items.step);
    b.step("transit-work-items", "Install the work-item application worker image entry point").dependOn(&install_work_items.step);
    const work_items_generated = b.addSystemCommand(&.{ "python3", "-B" });
    work_items_generated.addFileArg(b.path("examples/work-items/generate.py"));
    work_items_generated.addArtifactArg(application.artifact("transit-app"));
    work_items_generated.addArg("--check");
    work_items_generated.has_side_effects = true;
    const work_items_embed = b.addSystemCommand(&.{ "python3", "-B" });
    work_items_embed.addFileArg(b.path("tasks/embed_web.py"));
    const work_items_assets = work_items_embed.addOutputFileArg("assets.zig");
    work_items_embed.addArg("examples/work-items/web");
    work_items_embed.has_side_effects = true;
    work_items_embed.step.dependOn(&work_items_generated.step);
    const work_items_gateway = b.addExecutable(.{ .name = "transit-work-items-gateway", .root_module = b.createModule(.{ .root_source_file = b.path("examples/work-items/Gateway.zig"), .target = target, .optimize = optimize, .imports = &.{ .{ .name = "work_items", .module = work_items_module }, .{ .name = "transit_http_server", .module = http_server.module("transit_http_server") }, .{ .name = "assets", .module = b.createModule(.{ .root_source_file = work_items_assets, .target = target, .optimize = optimize }) } } }) });
    const install_work_items_gateway = b.addInstallArtifact(work_items_gateway, .{});
    b.step("work-items-gateway", "Install the generated work-item application gateway").dependOn(&install_work_items_gateway.step);
    b.step("transit-work-items-gateway", "Install the generated work-item gateway image entry point").dependOn(&install_work_items_gateway.step);
    b.step("test-work-items-unit", "Check the application-owned Table migration").dependOn(&work_items_test.step);
    test_step.dependOn(&work_items_test.step);
    const work_items_contract = b.addSystemCommand(&.{ "python3", "-B" });
    work_items_contract.addFileArg(b.path("tests/work_items_contract.py"));
    work_items_contract.has_side_effects = true;
    work_items_contract.stdio = .inherit;
    test_step.dependOn(&work_items_contract.step);
    const application_contract = b.addSystemCommand(&.{ "python3", "-B" });
    application_contract.addFileArg(b.path("tests/application_contract.py"));
    application_contract.has_side_effects = true;
    application_contract.stdio = .inherit;
    test_step.dependOn(&application_contract.step);
    const application_migration = b.addSystemCommand(&.{ "python3", "-B" });
    application_migration.addFileArg(b.path("tests/application_migration_contract.py"));
    application_migration.has_side_effects = true;
    application_migration.stdio = .inherit;
    test_step.dependOn(&application_migration.step);
    const query_draft = b.addSystemCommand(&.{ "python3", "-B" });
    query_draft.addFileArg(b.path("tests/query_draft_contract.py"));
    query_draft.has_side_effects = true;
    query_draft.stdio = .inherit;
    test_step.dependOn(&query_draft.step);
    const application_signing = b.addSystemCommand(&.{ "python3", "-B" });
    application_signing.addFileArg(b.path("tests/application_signing.py"));
    application_signing.has_side_effects = true;
    application_signing.stdio = .inherit;
    test_step.dependOn(&application_signing.step);
    test_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = application.module("transit_station_app") })).step);
    test_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = serving_http.module("transit_serving_http") })).step);
    test_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = serving.module("transit_serving") })).step);
    test_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = http_server.module("transit_http_server") })).step);
    test_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = document.module("transit_station_document") })).step);
    test_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = b.dependency("transit_tls", .{ .target = target, .optimize = optimize }).module("transit_tls") })).step);
    test_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = grpc.module("transit_grpc") })).step);
    test_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = exchange.module("transit_exchange") })).step);
    test_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = station_grpc.module("transit_station_grpc") })).step);
    test_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = station_http.module("transit_station_http") })).step);
    test_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = query.module("transit_query") })).step);
    const unified_contract_test = b.addSystemCommand(&.{ "python3", "-B" });
    unified_contract_test.addFileArg(b.path("tests/unified_contract.py"));
    unified_contract_test.has_side_effects = true;
    unified_contract_test.stdio = .inherit;
    test_step.dependOn(&unified_contract_test.step);
    const document_contract_test = b.addSystemCommand(&.{ "python3", "-B" });
    document_contract_test.addFileArg(b.path("tests/document_contract.py"));
    document_contract_test.has_side_effects = true;
    document_contract_test.stdio = .inherit;
    test_step.dependOn(&document_contract_test.step);
    const grpc_contract_test = b.addSystemCommand(&.{ "python3", "-B" });
    grpc_contract_test.addFileArg(b.path("tests/grpc_contract.py"));
    grpc_contract_test.has_side_effects = true;
    grpc_contract_test.stdio = .inherit;
    test_step.dependOn(&grpc_contract_test.step);
    const build_test_step = b.step("test-build", "Compile applications and integration probes");
    build_test_step.dependOn(&work_items.step);
    build_test_step.dependOn(&work_items_gateway.step);
    const work_items_proof = b.addExecutable(.{ .name = "transit-work-items-proof", .root_module = b.createModule(.{ .root_source_file = b.path("tests/work_items.zig"), .target = target, .optimize = optimize, .imports = &.{ .{ .name = "work_items", .module = work_items_module }, .{ .name = "transit_station", .module = station.module("transit_station") } } }) });
    build_test_step.dependOn(&work_items_proof.step);
    b.step("work-items-proof", "Build the native work-item qualification caller").dependOn(&b.addInstallArtifact(work_items_proof, .{}).step);
    const work_items_browser_proof = b.addExecutable(.{ .name = "transit-work-items-browser-proof", .root_module = b.createModule(.{ .root_source_file = b.path("tests/work_items_browser.zig"), .target = target, .optimize = optimize, .imports = &.{ .{ .name = "work_items", .module = work_items_module }, .{ .name = "transit_station", .module = station.module("transit_station") } } }) });
    build_test_step.dependOn(&work_items_browser_proof.step);
    b.step("work-items-browser-proof", "Build the generated application qualification caller").dependOn(&b.addInstallArtifact(work_items_browser_proof, .{}).step);
    build_test_step.dependOn(&application.artifact("transit-app").step);
    build_test_step.dependOn(&query.artifact("transit-query-api").step);
    build_test_step.dependOn(&serving_example.step);
    const serving_http_proof = b.addExecutable(.{ .name = "transit-serving-http-proof", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/serving_http.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "transit_http_server", .module = http_server.module("transit_http_server") }},
    }) });
    build_test_step.dependOn(&serving_http_proof.step);
    const serving_http_test = b.addSystemCommand(&.{ "python3", "-B" });
    serving_http_test.addFileArg(b.path("tests/serving_http.py"));
    serving_http_test.addArtifactArg(serving_http_proof);
    serving_http_test.has_side_effects = true;
    serving_http_test.stdio = .inherit;
    b.step("test-serving-http", "Qualify shared HTTP framing, capacity and joined deadlines").dependOn(&serving_http_test.step);
    const tls_alpn_proof = b.addExecutable(.{ .name = "transit-tls-alpn-proof", .root_module = b.createModule(.{ .root_source_file = b.path("tests/tls_alpn.zig"), .target = target, .optimize = optimize, .imports = &.{.{ .name = "transit_tls", .module = b.dependency("transit_tls", .{ .target = target, .optimize = optimize }).module("transit_tls") }} }) });
    build_test_step.dependOn(&tls_alpn_proof.step);
    const tls_alpn_test = b.addSystemCommand(&.{ "python3", "-B" });
    tls_alpn_test.addFileArg(b.path("tests/tls_alpn.py"));
    tls_alpn_test.addArtifactArg(tls_alpn_proof);
    tls_alpn_test.has_side_effects = true;
    tls_alpn_test.stdio = .inherit;
    b.step("test-tls-alpn", "Qualify required ALPN with independent TLS peers").dependOn(&tls_alpn_test.step);
    const grpc_transport_proof = b.addExecutable(.{ .name = "transit-grpc-transport-proof", .root_module = b.createModule(.{ .root_source_file = b.path("tests/grpc_transport.zig"), .target = target, .optimize = optimize, .imports = &.{ .{ .name = "transit_grpc", .module = grpc.module("transit_grpc") }, .{ .name = "transit_station_grpc", .module = station_grpc.module("transit_station_grpc") } } }) });
    build_test_step.dependOn(&grpc_transport_proof.step);
    const grpc_transport_test = b.addSystemCommand(&.{ "python3", "-B" });
    grpc_transport_test.addFileArg(b.path("tests/grpc_transport.py"));
    grpc_transport_test.addArtifactArg(grpc_transport_proof);
    grpc_transport_test.has_side_effects = true;
    grpc_transport_test.stdio = .inherit;
    b.step("test-grpc-transport", "Qualify finite RPC shapes against independent peers").dependOn(&grpc_transport_test.step);
    test_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = flight.module("transit_flight") })).step);
    const flight_metadata_proof = b.addExecutable(.{ .name = "transit-flight-metadata-proof", .root_module = b.createModule(.{ .root_source_file = b.path("packages/zig/transit-flight/src/metadata_fixture.zig"), .target = target, .optimize = optimize, .imports = &.{.{ .name = "transit_flight", .module = flight.module("transit_flight") }} }) });
    build_test_step.dependOn(&flight_metadata_proof.step);
    const flight_metadata_test = b.addSystemCommand(&.{ "python3", "-B" });
    flight_metadata_test.addFileArg(b.path("tests/flight_metadata.py"));
    flight_metadata_test.addArtifactArg(flight_metadata_proof);
    flight_metadata_test.has_side_effects = true;
    flight_metadata_test.stdio = .inherit;
    b.step("test-flight-metadata", "Qualify standard Flight SQL metadata with independent Arrow").dependOn(&flight_metadata_test.step);
    const grpc_server_proof = b.addExecutable(.{ .name = "transit-grpc-server-proof", .root_module = b.createModule(.{ .root_source_file = b.path("tests/grpc_server.zig"), .target = target, .optimize = optimize, .imports = &.{.{ .name = "transit_grpc", .module = grpc.module("transit_grpc") }} }) });
    build_test_step.dependOn(&grpc_server_proof.step);
    const grpc_server_test = b.addSystemCommand(&.{ "python3", "-B" });
    grpc_server_test.addFileArg(b.path("tests/grpc_server.py"));
    grpc_server_test.addArtifactArg(grpc_server_proof);
    grpc_server_test.has_side_effects = true;
    grpc_server_test.stdio = .inherit;
    b.step("test-grpc-server", "Qualify bounded inbound RPCs against independent clients").dependOn(&grpc_server_test.step);
    const http_transport_proof = b.addExecutable(.{ .name = "transit-http-transport-proof", .root_module = b.createModule(.{ .root_source_file = b.path("tests/http_transport.zig"), .target = target, .optimize = optimize, .imports = &.{.{ .name = "transit_station_http", .module = station_http.module("transit_station_http") }} }) });
    build_test_step.dependOn(&http_transport_proof.step);
    const http_transport_test = b.addSystemCommand(&.{ "python3", "-B" });
    http_transport_test.addFileArg(b.path("tests/http_transport.py"));
    http_transport_test.addArtifactArg(http_transport_proof);
    http_transport_test.has_side_effects = true;
    http_transport_test.stdio = .inherit;
    b.step("test-http-transport", "Qualify single-send HTTP/TLS against independent peers").dependOn(&http_transport_test.step);
    test_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = station.module("transit_station") })).step);
    test_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = station_bindings.module("station_abi") })).step);
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
    const growth_proof = b.addExecutable(.{ .name = "transit-growth-proof", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/growing.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{ .{ .name = "transit_core", .module = core.module("transit_core") }, .{ .name = "transit_backend_ursula", .module = adapter.module("transit_backend_ursula") } },
    }) });
    const growth_test = b.addSystemCommand(&.{ "python3", "-B" });
    growth_test.addFileArg(b.path("tests/growing.py"));
    growth_test.addArtifactArg(growth_proof);
    growth_test.addPassthruArgs();
    growth_test.has_side_effects = true;
    growth_test.stdio = .inherit;
    b.step("test-growing", "Prove growing authority publication and recovery through disk Ursula").dependOn(&growth_test.step);
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
    inline for (.{ "signed request", "Station frames", "growing request" }) |filter| {
        const codecs = b.addTest(.{ .use_llvm = true, .root_module = codec_module, .filters = &.{ filter, "allocation failures release parser" } });
        codec_step.dependOn(&b.addRunArtifact(codecs).step);
    }
    const exporter = b.addExecutable(.{ .name = "transit-contract", .root_module = b.createModule(.{ .root_source_file = b.path("packages/zig/transit-protocol/src/export.zig"), .target = target, .optimize = optimize, .imports = &.{.{ .name = "transit_protocol", .module = protocol.module("transit_protocol") }} }) });
    b.step("contract", "Export public contract JSON Schema to stdout").dependOn(&b.addRunArtifact(exporter).step);
    const growth_contract = b.addRunArtifact(exporter);
    growth_contract.addArg("growth");
    b.step("growth-contract", "Export growing-profile development contract").dependOn(&growth_contract.step);
    test_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = protocol.module("transit_protocol") })).step);
    const transit_board_api = b.dependency("transit_board_api", .{ .target = target, .optimize = optimize });
    test_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = transit_board_api.module("transit_board_api") })).step);
    const board_contract = b.addExecutable(.{ .name = "transit-board-contract", .root_module = b.createModule(.{ .root_source_file = b.path("packages/zig/transit-board-api/src/export.zig"), .target = target, .optimize = optimize, .imports = &.{.{ .name = "transit_board_api", .module = transit_board_api.module("transit_board_api") }} }) });
    b.step("transit-board-contract", "Export Board OpenAPI to stdout").dependOn(&b.addRunArtifact(board_contract).step);
    const client = b.dependency("transit_client", .{ .target = target, .optimize = optimize });
    const installation_fixture = b.addRunArtifact(client.artifact("transit-application-installation-contract"));
    installation_fixture.addArg("--fixture");
    b.step("application-installation-fixture", "Export a shared application signing fixture").dependOn(&installation_fixture.step);
    b.step("application-installation-contract", "Export language-neutral application installation schema").dependOn(&b.addRunArtifact(client.artifact("transit-application-installation-contract")).step);
    b.step("client-contract", "Export reflected client ABI signatures").dependOn(&b.addRunArtifact(client.artifact("transit-client-contract")).step);
    b.step("client-abi", "Build the shared client library").dependOn(&b.addInstallArtifact(client.artifact("transit_client"), .{}).step);
    test_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = client.module("transit_client") })).step);
    test_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = client.module("client_abi") })).step);
    const embed = b.addSystemCommand(&.{ "python3", "-B" });
    embed.addFileArg(b.path("tasks/embed_web.py"));
    const asset_source = embed.addOutputFileArg("assets.zig");
    embed.addArgs(&.{ "apps/transit-board-web", "contracts/transit-board-v1.openapi.json" });
    // Vite owns its dependency graph. Always rebuild the closed asset manifest;
    // Zig still caches compilation by the resulting bytes.
    embed.has_side_effects = true;
    const asset_module = b.createModule(.{ .root_source_file = asset_source, .target = target, .optimize = optimize });
    const board = b.addExecutable(.{ .name = "transit-board", .root_module = b.createModule(.{ .root_source_file = b.path("apps/transit-board/main.zig"), .target = target, .optimize = optimize, .imports = &.{
        .{ .name = "transit_station_app", .module = application.module("transit_station_app") },
        .{ .name = "transit_serving_http", .module = serving_http.module("transit_serving_http") },
        .{ .name = "transit_http_server", .module = http_server.module("transit_http_server") },
        .{ .name = "transit_query", .module = query.module("transit_query") },
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
    var client_host: *std.Build.Step.Compile = undefined;
    for ([_][]const u8{ "transit-node", "rey-cli", "transit-runtime-controller", "transit-delivery", "transit-station-controller", "transit-station-host", "transit-client-host" }) |name| {
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
            app.root_module.addImport("station_abi", station_bindings.module("station_abi"));
            app.root_module.addImport("client_abi", client.module("client_abi"));
        }
        if (std.mem.eql(u8, name, "transit-client-host")) {
            client_host = app;
            app.root_module.addImport("client_abi", client.module("client_abi"));
        }
        if (std.mem.eql(u8, name, "transit-node") and target.result.os.tag == .linux) {
            const clock_c = b.addTranslateC(.{ .root_source_file = b.path("apps/transit-node/clock.h"), .target = target, .optimize = optimize });
            app.root_module.addImport("clock_c", clock_c.createModule());
        }
        build_test_step.dependOn(&app.step);
    }
    const unified_codec_test = b.addSystemCommand(&.{ "python3", "-B" });
    unified_codec_test.addFileArg(b.path("tests/unified_codec.py"));
    unified_codec_test.addArtifactArg(station_host);
    unified_codec_test.addArtifactArg(station_bindings.artifact("transit_station"));
    unified_codec_test.has_side_effects = true;
    unified_codec_test.stdio = .inherit;
    b.step("test-unified-codec", "Qualify unified source and Arrow values through native and port boundaries").dependOn(&unified_codec_test.step);
    test_step.dependOn(&unified_codec_test.step);
    var query_host: *std.Build.Step.Compile = undefined;
    const document_worker = b.addExecutable(.{ .name = "transit-station-document-worker", .root_module = b.createModule(.{ .root_source_file = b.path("apps/transit-station-document-worker/main.zig"), .target = target, .optimize = optimize, .imports = &.{ .{ .name = "transit_station_document", .module = document.module("transit_station_document") }, .{ .name = "telemetry", .module = telemetry.module("telemetry") } } }) });
    const install_document_worker = b.addInstallArtifact(document_worker, .{});
    b.getInstallStep().dependOn(&install_document_worker.step);
    apps_step.dependOn(&install_document_worker.step);
    build_test_step.dependOn(&document_worker.step);
    b.step("transit-station-document-worker", "Install the growing Document writer").dependOn(&install_document_worker.step);
    const document_caller = b.addExecutable(.{ .name = "example-station-document", .root_module = b.createModule(.{ .root_source_file = b.path("examples/station-document/main.zig"), .target = target, .optimize = optimize, .imports = &.{.{ .name = "transit_station_document", .module = document.module("transit_station_document") }} }) });
    const install_document_caller = b.addInstallArtifact(document_caller, .{});
    b.getInstallStep().dependOn(&install_document_caller.step);
    build_test_step.dependOn(&document_caller.step);
    b.step("example-station-document", "Install the collaborative Document caller").dependOn(&install_document_caller.step);
    const grpc_worker = b.addExecutable(.{ .name = "transit-station-grpc-worker", .root_module = b.createModule(.{ .root_source_file = b.path("apps/transit-station-grpc-worker/main.zig"), .target = target, .optimize = optimize, .imports = &.{ .{ .name = "transit_station_grpc", .module = station_grpc.module("transit_station_grpc") }, .{ .name = "telemetry", .module = telemetry.module("telemetry") } } }) });
    const install_grpc_worker = b.addInstallArtifact(grpc_worker, .{});
    b.getInstallStep().dependOn(&install_grpc_worker.step);
    apps_step.dependOn(&install_grpc_worker.step);
    build_test_step.dependOn(&grpc_worker.step);
    b.step("transit-station-grpc-worker", "Install the finite growing RPC worker").dependOn(&install_grpc_worker.step);
    const http_worker = b.addExecutable(.{ .name = "transit-station-http-worker", .root_module = b.createModule(.{ .root_source_file = b.path("apps/transit-station-http-worker/main.zig"), .target = target, .optimize = optimize, .imports = &.{ .{ .name = "transit_station_http", .module = station_http.module("transit_station_http") }, .{ .name = "telemetry", .module = telemetry.module("telemetry") } } }) });
    const install_http_worker = b.addInstallArtifact(http_worker, .{});
    b.getInstallStep().dependOn(&install_http_worker.step);
    apps_step.dependOn(&install_http_worker.step);
    build_test_step.dependOn(&http_worker.step);
    b.step("transit-station-http-worker", "Install the finite growing HTTP worker").dependOn(&install_http_worker.step);
    const http_caller = b.addExecutable(.{ .name = "example-station-http", .root_module = b.createModule(.{ .root_source_file = b.path("examples/station-http/main.zig"), .target = target, .optimize = optimize, .imports = &.{.{ .name = "transit_station_http", .module = station_http.module("transit_station_http") }} }) });
    const install_http_caller = b.addInstallArtifact(http_caller, .{});
    b.getInstallStep().dependOn(&install_http_caller.step);
    build_test_step.dependOn(&http_caller.step);
    b.step("example-station-http", "Install the finite HTTP caller example").dependOn(&install_http_caller.step);
    const grpc_bindings = b.addExecutable(.{ .name = "transit-grpc-bindings", .root_module = b.createModule(.{ .root_source_file = b.path("packages/zig/transit-station-grpc/src/generate.zig"), .target = target, .optimize = optimize, .imports = &.{.{ .name = "transit_station_grpc", .module = station_grpc.module("transit_station_grpc") }} }) });
    const install_grpc_bindings = b.addInstallArtifact(grpc_bindings, .{});
    b.getInstallStep().dependOn(&install_grpc_bindings.step);
    build_test_step.dependOn(&grpc_bindings.step);
    b.step("grpc-bindings", "Install offline RPC request helper generator").dependOn(&install_grpc_bindings.step);
    const grpc_generated = b.addExecutable(.{ .name = "transit-grpc-generated-proof", .root_module = b.createModule(.{ .root_source_file = b.path("tests/grpc_generated.zig"), .target = target, .optimize = optimize, .imports = &.{.{ .name = "transit_station_grpc", .module = station_grpc.module("transit_station_grpc") }} }) });
    const grpc_codegen_test = b.addSystemCommand(&.{ "python3", "-B" });
    grpc_codegen_test.addFileArg(b.path("tests/grpc_codegen.py"));
    grpc_codegen_test.addArtifactArg(grpc_bindings);
    grpc_codegen_test.addArtifactArg(grpc_generated);
    grpc_codegen_test.has_side_effects = true;
    grpc_codegen_test.stdio = .inherit;
    b.step("test-grpc-codegen", "Qualify offline descriptor-generated RPC requests").dependOn(&grpc_codegen_test.step);
    const grpc_caller = b.addExecutable(.{ .name = "example-station-grpc", .root_module = b.createModule(.{ .root_source_file = b.path("examples/station-grpc/main.zig"), .target = target, .optimize = optimize, .imports = &.{.{ .name = "transit_station_grpc", .module = station_grpc.module("transit_station_grpc") }} }) });
    const install_grpc_caller = b.addInstallArtifact(grpc_caller, .{});
    b.getInstallStep().dependOn(&install_grpc_caller.step);
    build_test_step.dependOn(&grpc_caller.step);
    b.step("example-station-grpc", "Install the finite RPC caller example").dependOn(&install_grpc_caller.step);
    const grpc_provision = b.addExecutable(.{ .name = "transit-grpc-worker-proof", .root_module = b.createModule(.{ .root_source_file = b.path("tests/grpc_worker.zig"), .target = target, .optimize = optimize, .imports = &.{ .{ .name = "transit_station_grpc", .module = station_grpc.module("transit_station_grpc") }, .{ .name = "transit_station", .module = station.module("transit_station") } } }) });
    build_test_step.dependOn(&grpc_provision.step);
    const grpc_worker_test = b.addSystemCommand(&.{ "python3", "-B" });
    grpc_worker_test.addFileArg(b.path("tests/grpc_worker.py"));
    grpc_worker_test.addArtifactArg(node_artifact);
    grpc_worker_test.addArtifactArg(grpc_provision);
    grpc_worker_test.addArtifactArg(grpc_worker);
    const grpc_browser = b.option(bool, "grpc-board-browser", "Qualify captured RPC metadata in the browser") orelse false;
    const grpc_board = b.option(bool, "grpc-board", "Qualify Board RPC metadata against real captures") orelse false;
    if (grpc_browser or grpc_board) grpc_worker_test.addArtifactArg(board);
    if (grpc_browser) grpc_worker_test.addArg("browser");
    if (b.option(bool, "grpc-faults", "Run RPC authority and final-publication failure boundaries") orelse false) grpc_worker_test.addArg("faults");
    grpc_worker_test.has_side_effects = true;
    grpc_worker_test.stdio = .inherit;
    b.step("test-grpc-worker", "Prove durable finite RPC capture and recovery").dependOn(&grpc_worker_test.step);
    const flight_outbound = b.addExecutable(.{ .name = "transit-flight-outbound-proof", .root_module = b.createModule(.{ .root_source_file = b.path("tests/flight_outbound.zig"), .target = target, .optimize = optimize, .imports = &.{.{ .name = "transit_station_flight", .module = station_flight.module("transit_station_flight") }} }) });
    build_test_step.dependOn(&flight_outbound.step);
    test_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = station_flight.module("transit_station_flight") })).step);
    const flight_outbound_test = b.addSystemCommand(&.{ "python3", "-B" });
    flight_outbound_test.addFileArg(b.path("tests/flight_outbound.py"));
    for ([_]*std.Build.Step.Compile{ node_artifact, grpc_provision, grpc_worker, flight_outbound }) |artifact| flight_outbound_test.addArtifactArg(artifact);
    flight_outbound_test.has_side_effects = true;
    flight_outbound_test.stdio = .inherit;
    b.step("test-flight-outbound", "Qualify Flight recorded effects and network-free replay").dependOn(&flight_outbound_test.step);
    const http_provision = b.addExecutable(.{ .name = "transit-http-worker-proof", .root_module = b.createModule(.{ .root_source_file = b.path("tests/http_worker.zig"), .target = target, .optimize = optimize, .imports = &.{ .{ .name = "transit_station_http", .module = station_http.module("transit_station_http") }, .{ .name = "transit_station", .module = station.module("transit_station") } } }) });
    build_test_step.dependOn(&http_provision.step);
    const http_worker_test = b.addSystemCommand(&.{ "python3", "-B" });
    http_worker_test.addFileArg(b.path("tests/http_worker.py"));
    http_worker_test.addArtifactArg(node_artifact);
    http_worker_test.addArtifactArg(http_provision);
    http_worker_test.addArtifactArg(http_worker);
    http_worker_test.addArtifactArg(station_bindings.artifact("transit_station"));
    const http_browser = b.option(bool, "http-board-browser", "Include real HTTP exchange inspection in Board") orelse false;
    const http_board = b.option(bool, "http-board", "Qualify Board metadata against real HTTP capture") orelse false;
    if (http_browser or http_board) http_worker_test.addArtifactArg(board);
    if (http_browser) http_worker_test.addArg("--browser");
    http_worker_test.has_side_effects = true;
    http_worker_test.stdio = .inherit;
    b.step("test-http-worker", "Prove durable HTTP capture and unknown-outcome recovery").dependOn(&http_worker_test.step);
    var query_shell: *std.Build.Step.Compile = undefined;
    inline for (.{ .{ "transit-query-host", "transit-query-host" }, .{ "transit", "transit-cli" } }) |entry| {
        const app = b.addExecutable(.{ .name = entry[0], .root_module = b.createModule(.{
            .root_source_file = b.path("apps/" ++ entry[1] ++ "/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "transit_query", .module = query.module("transit_query") }},
        }) });
        if (comptime std.mem.eql(u8, entry[0], "transit-query-host")) app.root_module.addImport("transit_serving", serving.module("transit_serving"));
        if (comptime std.mem.eql(u8, entry[0], "transit")) app.root_module.addImport("transit_http_server", http_server.module("transit_http_server"));
        if (comptime std.mem.eql(u8, entry[0], "transit-query-host")) query_host = app else query_shell = app;
        const install = b.addInstallArtifact(app, .{});
        b.getInstallStep().dependOn(&install.step);
        apps_step.dependOn(&install.step);
        build_test_step.dependOn(&app.step);
        b.step(entry[0], "Install " ++ entry[0]).dependOn(&install.step);
    }
    const lifecycle_test = b.addRunArtifact(b.addTest(.{ .root_module = b.createModule(.{ .root_source_file = b.path("apps/transit-cli/LifecycleTests.zig"), .target = target, .optimize = optimize, .link_libc = true }) }));
    test_step.dependOn(&lifecycle_test.step);
    b.step("test-cli-lifecycle", "Prove bounded local process log draining").dependOn(&lifecycle_test.step);
    const server_test = b.addSystemCommand(&.{ "python3", "-B" });
    server_test.addFileArg(b.path("tests/server.py"));
    for ([_]*std.Build.Step.Compile{ query_shell, node_artifact, query_host }) |artifact| server_test.addArtifactArg(artifact);
    if (b.option(bool, "server-faults", "Qualify interrupted bootstrap, gateway pressure and provider rollback") orelse false) server_test.addArg("--faults");
    server_test.has_side_effects = true;
    server_test.step.dependOn(&lifecycle_test.step);
    server_test.stdio = .inherit;
    b.step("test-server", "Qualify local server bootstrap, gateway and owned process recovery").dependOn(&server_test.step);
    const serving_test = b.addSystemCommand(&.{ "python3", "-B" });
    serving_test.addFileArg(b.path("tests/serving.py"));
    for ([_]*std.Build.Step.Compile{ node_artifact, serving_example, query_host }) |artifact| serving_test.addArtifactArg(artifact);
    if (b.option(bool, "serving-tls", "Qualify the real private nginx TLS termination template") orelse false) serving_test.addArg("--tls");
    if (b.option(bool, "serving-capacity", "Measure gateway RSS and control reserve with delayed authorized reads") orelse false) serving_test.addArg("--capacity");
    if (b.option(bool, "serving-lifetimes", "Qualify service cancellation, timer races and hard expiry") orelse false) serving_test.addArg("--lifetimes");
    if (b.option(bool, "serving-growth", "Qualify retained service operations beyond resident pages") orelse false) serving_test.addArg("--growth");
    if (b.option(bool, "serving-reactive-client", "Qualify shared private reactive host client") orelse false) serving_test.addArg("--reactive-client");
    const views_lifecycle = b.option(bool, "serving-reactive-views-lifecycle", "Qualify browser reconnect, generation and shared viewer lifecycle") orelse false;
    if ((b.option(bool, "serving-reactive-views", "Qualify real Board and counter live views") orelse false) or views_lifecycle) {
        serving_test.addArgs(&.{ "--reactive-views", "--board" });
        serving_test.addArtifactArg(board);
        if (views_lifecycle) serving_test.addArg("--reactive-views-lifecycle");
    }
    if (b.option(bool, "serving-reactive-refresh", "Qualify durable refresh requester and counter source") orelse false) serving_test.addArg("--reactive-refresh");
    if (b.option(bool, "serving-reactive", "Qualify reactive SSE and WebSocket peers") orelse false) serving_test.addArg("--reactive");
    if (b.option(bool, "serving-reactive-limits", "Qualify reactive capacity, cursor and expiry limits") orelse false) serving_test.addArg("--reactive-limits");
    if (b.option(bool, "serving-reactive-browser", "Qualify the real browser reactive bootstrap and transports") orelse false) serving_test.addArg("--reactive-browser");
    serving_test.has_side_effects = true;
    serving_test.stdio = .inherit;
    b.step("test-serving", "Qualify durable HTTP service admission and recovery").dependOn(&serving_test.step);
    const public_query = b.addExecutable(.{ .name = "transit-public-query-proof", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/public_query.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{ .{ .name = "transit_serving", .module = serving.module("transit_serving") }, .{ .name = "transit_query", .module = query.module("transit_query") }, .{ .name = "transit_station", .module = station.module("transit_station") } },
    }) });
    b.step("public-query-proof", "Install the public query provisioning proof").dependOn(&b.addInstallArtifact(public_query, .{}).step);
    build_test_step.dependOn(&public_query.step);
    const flight_gateway = b.dependency("transit_flight_gateway", .{ .target = target, .optimize = optimize }).artifact("transit-flight-gateway");
    b.step("transit-flight-gateway", "Install the finite Flight gateway").dependOn(&b.addInstallArtifact(flight_gateway, .{}).step);
    build_test_step.dependOn(&flight_gateway.step);
    const flight_test = b.addSystemCommand(&.{ "python3", "-B" });
    if (b.option([]const u8, "flight-placement", "Run Flight in compose or reference placement")) |profile| {
        flight_test.addFileArg(b.path("examples/flight/run.py"));
        flight_test.addArg(profile);
    } else flight_test.addFileArg(b.path("tests/flight.py"));
    for ([_]*std.Build.Step.Compile{ node_artifact, query_host, flight_gateway, public_query }) |artifact| flight_test.addArtifactArg(artifact);
    if (b.option(bool, "flight-faults", "Qualify Flight authority, retry and physical recovery boundaries") orelse false) {
        flight_test.addArg("faults");
        flight_test.addArtifactArg(board);
    }
    flight_test.has_side_effects = true;
    flight_test.stdio = .inherit;
    b.step("test-flight", "Qualify real finite queries with independent Flight and ADBC clients").dependOn(&flight_test.step);
    const public_query_test = b.addSystemCommand(&.{ "python3", "-B" });
    public_query_test.addFileArg(b.path("tests/public_query.py"));
    for ([_]*std.Build.Step.Compile{ node_artifact, query_host, query_shell, public_query }) |artifact| public_query_test.addArtifactArg(artifact);
    public_query_test.has_side_effects = true;
    public_query_test.stdio = .inherit;
    b.step("test-public-query", "Qualify the public query hosts and signed shell over disk Ursula").dependOn(&public_query_test.step);
    const unified_query = b.addExecutable(.{ .name = "transit-unified-query-proof", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/unified_query.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{ .{ .name = "transit_query", .module = query.module("transit_query") }, .{ .name = "transit_station", .module = station.module("transit_station") } },
    }) });
    const query_example = b.addExecutable(.{ .name = "example-state-query", .root_module = b.createModule(.{
        .root_source_file = b.path("examples/state-query/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "transit_query", .module = query.module("transit_query") }},
    }) });
    const install_query_example = b.addInstallArtifact(query_example, .{});
    build_test_step.dependOn(&query_example.step);
    b.step("example-state-query", "Install the finite SQL recovery example").dependOn(&install_query_example.step);
    b.step("unified-query-proof", "Install the unified query provisioning proof").dependOn(&b.addInstallArtifact(unified_query, .{}).step);
    build_test_step.dependOn(&unified_query.step);
    const unified_query_test = b.addSystemCommand(&.{ "python3", "-B" });
    unified_query_test.addFileArg(b.path("tests/unified_query.py"));
    for ([_]*std.Build.Step.Compile{ node_artifact, query_host, unified_query, station_host, station_bindings.artifact("transit_station") }) |artifact| unified_query_test.addArtifactArg(artifact);
    if (b.option(bool, "unified-example", "Run the finite SQL example and recover its original intent") orelse false) {
        unified_query_test.addArg("--example");
        unified_query_test.addArtifactArg(query_example);
    }
    if (b.option(bool, "unified-shell", "Include the actual v2 SQL shell in unified recovery") orelse false) {
        unified_query_test.addArg("--shell");
        unified_query_test.addArtifactArg(query_shell);
    }
    if (b.option(bool, "unified-console", "Qualify the versioned Transit console and exact recovery") orelse false) {
        unified_query_test.addArg("--console");
        unified_query_test.addArtifactArg(query_shell);
    }
    if (b.option(bool, "unified-console-tls", "Qualify explicit console TLS trust through nginx") orelse false) unified_query_test.addArg("--console-tls");
    if (b.option(bool, "unified-board", "Include Board's v2 query API in unified recovery") orelse false) {
        unified_query_test.addArg("--board");
        unified_query_test.addArtifactArg(board);
    }
    if (b.option(bool, "unified-browser", "Include the actual v2 Board workspace in unified recovery") orelse false) unified_query_test.addArg("--browser");
    if (b.option(bool, "unified-expiry", "Qualify real finite request expiry across source kinds") orelse false) unified_query_test.addArg("--expiry");
    if (b.option(bool, "unified-lifecycle", "Qualify current grants and cancellation during staged v2 capture") orelse false) unified_query_test.addArg("--lifecycle");
    if (b.option([]const u8, "unified-source", "Limit unified query proof to kv, table or document")) |kind| unified_query_test.addArg(kind);
    if (b.option([]const u8, "unified-sdk", "Comma-separated installed SDKs for unified query recovery")) |languages| {
        var selected = std.mem.splitScalar(u8, languages, ',');
        while (selected.next()) |language| unified_query_test.addArgs(&.{ "--sdk", language });
    }
    unified_query_test.has_side_effects = true;
    unified_query_test.stdio = .inherit;
    b.step("test-unified-query", "Qualify unified query daemons over disk Ursula").dependOn(&unified_query_test.step);
    const query_board_test = b.addSystemCommand(&.{ "python3", "-B" });
    query_board_test.addFileArg(b.path("tests/board_query.py"));
    for ([_]*std.Build.Step.Compile{ node_artifact, query_host, public_query, board }) |artifact| query_board_test.addArtifactArg(artifact);
    if (b.option(bool, "query-browser", "Include the public query browser proof") orelse false) query_board_test.addArg("--browser");
    query_board_test.has_side_effects = true;
    query_board_test.stdio = .inherit;
    b.step("test-board-query", "Qualify growing Board inspection and its optional query capability").dependOn(&query_board_test.step);
    const growing_client = b.addExecutable(.{ .name = "transit-growing-client-proof", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/growing_client.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "transit_client", .module = client.module("transit_client") }},
    }) });
    const growing_service = b.addSystemCommand(&.{ "python3", "-B" });
    growing_service.addFileArg(b.path("tests/growing_service.py"));
    growing_service.addArtifactArg(node_artifact);
    growing_service.addArtifactArg(growing_client);
    const growing_station = b.addExecutable(.{ .name = "transit-growing-station-proof", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/growing_station.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "transit_station", .module = station.module("transit_station") }},
    }) });
    growing_service.addArtifactArg(growing_station);
    const growing_query = b.addExecutable(.{ .name = "transit-growing-query-proof", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/growing_query.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "transit_station", .module = station.module("transit_station") }},
    }) });
    growing_service.addArtifactArg(growing_query);
    const growing_quota = b.addExecutable(.{ .name = "transit-growing-quota-proof", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/growing_quota.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "transit_station", .module = station.module("transit_station") }},
    }) });
    growing_service.addArtifactArg(growing_quota);
    const growing_build = b.step("test-growing-service-build", "Compile growing service proof binaries without executing scenarios");
    for ([_]*std.Build.Step.Compile{ node_artifact, growing_client, growing_station, growing_query, growing_quota }) |artifact| growing_build.dependOn(&artifact.step);
    growing_service.has_side_effects = true;
    growing_service.stdio = .inherit;
    b.step("test-growing-service", "Prove the explicit growing node/client profile over signed HTTP").dependOn(&growing_service.step);
    const growing_load = b.addExecutable(.{ .name = "transit-growing-load-proof", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/growing_load.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "transit_client", .module = client.module("transit_client") }},
    }) });
    build_test_step.dependOn(&growing_load.step);
    const load_proof = b.addSystemCommand(&.{ "python3", "-B" });
    load_proof.addFileArg(b.path("tests/growing_load.py"));
    load_proof.addArtifactArg(node_artifact);
    load_proof.addArtifactArg(growing_load);
    load_proof.addPassthruArgs();
    load_proof.has_side_effects = true;
    load_proof.stdio = .inherit;
    b.step("test-growing-load", "Measure offered load, control progress and bounded state drain").dependOn(&load_proof.step);
    const scale = b.addSystemCommand(&.{ "python3", "-B" });
    scale.addFileArg(b.path("tests/verification/scale.py"));
    scale.addArtifactArg(growth_proof);
    scale.addArtifactArg(node_artifact);
    scale.addArtifactArg(growing_load);
    scale.addPassthruArgs();
    scale.has_side_effects = true;
    scale.stdio = .inherit;
    b.step("test-scale", "Run the repeated finite growth and offered-load matrix").dependOn(&scale.step);
    const quota_proof = b.addSystemCommand(&.{ "python3", "-B" });
    quota_proof.addFileArg(b.path("tests/growing_quota.py"));
    quota_proof.addArtifactArg(node_artifact);
    quota_proof.addArtifactArg(growing_quota);
    quota_proof.has_side_effects = true;
    quota_proof.stdio = .inherit;
    b.step("test-growing-quota", "Focus service and Station quota/recovery behavior").dependOn(&quota_proof.step);
    const growing_behavior = b.addSystemCommand(&.{ "python3", "-B" });
    growing_behavior.addFileArg(b.path("tests/growing_station.py"));
    growing_behavior.addArtifactArg(node_artifact);
    growing_behavior.addArtifactArg(growing_station);
    growing_behavior.addPassthruArgs();
    growing_behavior.has_side_effects = true;
    growing_behavior.stdio = .inherit;
    b.step("test-growing-station", "Focus the growing Station behavior and recovery proof").dependOn(&growing_behavior.step);
    const query_capture = b.addSystemCommand(&.{ "python3", "-B" });
    query_capture.addFileArg(b.path("tests/growing_query.py"));
    query_capture.addArtifactArg(node_artifact);
    query_capture.addArtifactArg(growing_query);
    query_capture.addPassthruArgs();
    query_capture.has_side_effects = true;
    query_capture.stdio = .inherit;
    b.step("test-growing-query", "Prove bounded query capture and recovery through disk Ursula").dependOn(&query_capture.step);
    const document_proof = b.addExecutable(.{ .name = "transit-document-proof", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/document.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{ .{ .name = "transit_station", .module = station.module("transit_station") }, .{ .name = "transit_station_document", .module = document.module("transit_station_document") } },
    }) });
    build_test_step.dependOn(&document_proof.step);
    const document_test = b.addSystemCommand(&.{ "python3", "-B" });
    document_test.addFileArg(b.path("tests/document.py"));
    document_test.addArtifactArg(node_artifact);
    document_test.addArtifactArg(document_proof);
    document_test.has_side_effects = true;
    document_test.stdio = .inherit;
    b.step("test-document", "Prove Document publication, checkpoint and disk recovery").dependOn(&document_test.step);
    const work_items_native = b.addSystemCommand(&.{ "python3", "-B" });
    work_items_native.addFileArg(b.path("tests/work_items.py"));
    work_items_native.addArtifactArg(node_artifact);
    work_items_native.addArtifactArg(work_items);
    work_items_native.addArtifactArg(work_items_proof);
    work_items_native.has_side_effects = true;
    work_items_native.stdio = .inherit;
    b.step("test-work-items", "Qualify the actual Table migration worker through disk recovery").dependOn(&work_items_native.step);
    const work_items_browser = b.addSystemCommand(&.{ "python3", "-B" });
    work_items_browser.addFileArg(b.path("tests/work_items_browser.py"));
    for ([_]*std.Build.Step.Compile{ node_artifact, work_items, query_host, work_items_gateway, work_items_browser_proof }) |artifact| work_items_browser.addArtifactArg(artifact);
    work_items_browser.has_side_effects = true;
    work_items_browser.stdio = .inherit;
    b.step("test-work-items-browser", "Qualify generated application queries through publication and data migration").dependOn(&work_items_browser.step);
    const application_proof = b.addExecutable(.{ .name = "transit-application-proof", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/application.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{ .{ .name = "transit_station_app", .module = application.module("transit_station_app") }, .{ .name = "transit_station", .module = station.module("transit_station") } },
    }) });
    build_test_step.dependOn(&application_proof.step);
    const application_test = b.addSystemCommand(&.{ "python3", "-B" });
    application_test.addFileArg(b.path("tests/application.py"));
    application_test.addArtifactArg(node_artifact);
    application_test.addArtifactArg(application_proof);
    application_test.has_side_effects = true;
    application_test.stdio = .inherit;
    b.step("test-application", "Qualify conditional application publication over signed native ingress and disk recovery").dependOn(&application_test.step);
    const application_browser = b.addSystemCommand(&.{ "python3", "-B" });
    application_browser.addFileArg(b.path("tests/application_board.py"));
    application_browser.addArtifactArg(node_artifact);
    application_browser.addArtifactArg(application_proof);
    application_browser.addArtifactArg(board);
    application_browser.has_side_effects = true;
    application_browser.stdio = .inherit;
    b.step("test-application-browser", "Qualify the embedded declarative editor and signed publication with actual disk recovery").dependOn(&application_browser.step);
    const publication_proof = b.addExecutable(.{ .name = "transit-publication-proof", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/publication.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "transit_station", .module = station.module("transit_station") }},
    }) });
    build_test_step.dependOn(&publication_proof.step);
    const publication_test = b.addSystemCommand(&.{ "python3", "-B" });
    publication_test.addFileArg(b.path("tests/publication.py"));
    publication_test.addArtifactArg(node_artifact);
    publication_test.addArtifactArg(publication_proof);
    publication_test.has_side_effects = true;
    publication_test.stdio = .inherit;
    b.step("test-publication", "Prove bounded immutable Station publication and crash recovery").dependOn(&publication_test.step);
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
    const abi_test_step = b.step("test-client-abi", "Prove the C ABI against real authority and host loss");
    abi_test_step.dependOn(&abi_tests.step);
    const client_host_tests = b.addSystemCommand(&.{ "python3", "-B" });
    client_host_tests.addFileArg(b.path("tests/client_host.py"));
    client_host_tests.addArtifactArg(client_host);
    client_host_tests.addArtifactArg(node_artifact);
    client_host_tests.addArtifactArg(cli_artifact);
    client_host_tests.has_side_effects = true;
    client_host_tests.stdio = .inherit;
    abi_test_step.dependOn(&client_host_tests.step);
    const binding_tests = b.addSystemCommand(&.{ "python3", "-B" });
    binding_tests.addFileArg(b.path("tests/bindings.py"));
    binding_tests.addArtifactArg(node_artifact);
    binding_tests.addArtifactArg(cli_artifact);
    binding_tests.addArtifactArg(delivery_artifact);
    binding_tests.addArtifactArg(station_bindings.artifact("transit_station"));
    binding_tests.addArtifactArg(client.artifact("transit_client"));
    binding_tests.addArtifactArg(station_host);
    const binding_examples = b.step("bindings-examples", "Install the C and C++ Station callers");
    inline for (.{ "c", "cpp" }) |language| {
        const cpp = std.mem.eql(u8, language, "cpp");
        const caller = b.addExecutable(.{ .name = "station-" ++ language ++ "-example", .root_module = b.createModule(.{ .target = target, .optimize = optimize, .link_libc = true, .link_libcpp = cpp }) });
        caller.root_module.addIncludePath(b.path("packages/zig/transit-station-bindings/include"));
        caller.root_module.addIncludePath(b.path("packages/zig/transit-client/include"));
        caller.root_module.addIncludePath(b.path("packages/cpp/transit-station/include"));
        caller.root_module.addCSourceFile(.{ .file = b.path("examples/station-bindings/" ++ language ++ "/main." ++ language), .flags = if (cpp) &.{ "-std=c++17", "-Wall", "-Wextra", "-Werror" } else &.{ "-std=c11", "-D_POSIX_C_SOURCE=200809L", "-Wall", "-Wextra", "-Werror" } });
        caller.root_module.linkLibrary(station_bindings.artifact("transit_station"));
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
    examples_step.dependOn(&install_work_items.step);
    examples_step.dependOn(&install_work_items_gateway.step);
    examples_step.dependOn(&install_query_example.step);
    examples_step.dependOn(&install_document_caller.step);
    examples_step.dependOn(&install_http_caller.step);
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
    const growing_capacity = b.addExecutable(.{ .name = "transit-growing-capacity-proof", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/growing_capacity.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "transit_core", .module = core.module("transit_core") },
            .{ .name = "transit_backend_ursula", .module = adapter.module("transit_backend_ursula") },
        },
    }) });
    b.step("growing-capacity-proof", "Install the growing physical pressure proof driver").dependOn(&b.addInstallArtifact(growing_capacity, .{}).step);
    build_test_step.dependOn(&growing_capacity.step);
}
