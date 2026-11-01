//! Cross-component checks, examples and development exporters.
const std = @import("std");
const Runtime = @import("runtime.zig").Context;

pub fn register(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, context: Runtime) void {
    @import("native_fixtures.zig").register(b, target, optimize, context);
    const sdk_authority = b.option([]const u8, "sdk-authority", "Explicit verified node executable for installed SDK catalog checks");
    const sdk_packages = b.option([]const u8, "sdk-packages", "Installed SDK package directory") orelse ".cache/bindings/Debug";
    const http_server = context.http_server;
    const serving_http = context.serving_http;
    const application = context.application;
    const serving = context.serving;
    const web_dependencies = context.web_dependencies;
    const document = context.document;
    const document_core = b.dependency("transit_document", .{ .target = target, .optimize = optimize });
    const station_grpc = context.station_grpc;
    const station_flight = context.station_flight;
    const flight = context.flight;
    const grpc = context.grpc;
    const exchange = context.exchange;
    const station_http = context.station_http;
    const fuze = context.fuze;
    const query = context.query;
    const sql_client = context.sql_client;
    const sql_gateway = context.sql_gateway;
    const tls_server = context.tls_server;
    const sql_gateway_app = context.sql_gateway_app;
    const catalog = context.catalog;
    const station = context.station;
    const station_bindings = context.station_bindings;
    const observations = context.observations;
    const telemetry = context.telemetry;
    const storage = context.storage;
    const local_backend = context.local_backend;
    const adapter = context.adapter;
    const core = context.core;
    const protocol = context.protocol;
    const transit_board_api = context.transit_board_api;
    const client = context.client;
    const sql_protocol = context.sql_protocol;
    const board = context.board;
    const runtime = context.runtime;
    const node_artifact = context.node_artifact;
    const cli_artifact = context.cli_artifact;
    const delivery_artifact = context.delivery_artifact;
    const controller_artifact = context.controller_artifact;
    const kubectl_transit = context.kubectl_transit;
    const station_controller = context.station_controller;
    const station_host = context.station_host;
    const client_host = context.client_host;
    const query_host = context.query_host;
    const document_worker = context.document_worker;
    const grpc_worker = context.grpc_worker;
    const http_worker = context.http_worker;
    const grpc_bindings = context.grpc_bindings;
    const transit_cli = context.transit_cli;
    const flight_gateway = context.flight_gateway;

    const test_modules = @import("test_modules.zig").Set.init(b, target, optimize);
    // SDK dependencies belong to development/example registration. A caller
    // disabling examples can still run focused non-consumer checks.
    const sdk_examples = b.option(bool, "sdk-examples", "Enable consumer examples through the Zig SDK") orelse true;
    const sdk = if (sdk_examples) b.lazyDependency("transit_sdk", .{ .target = target, .optimize = optimize }) orelse return else null;
    const counter_embed = b.addSystemCommand(&.{ "python3", "-B" });
    counter_embed.addFileArg(b.path("tasks/embed_web.py"));
    const counter_assets = counter_embed.addOutputFileArg("assets.zig");
    counter_embed.addArg("examples/serving/web");
    counter_embed.has_side_effects = true;
    counter_embed.step.dependOn(&web_dependencies.step);
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
    b.step("logical-contract", "Export reflected logical type and value schemas").dependOn(&b.addRunArtifact(fuze.artifact("transit-logical-contract")).step);
    const diagnostic_grammar = b.addExecutable(.{ .name = "transit-diagnostic-grammar", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/interfaces/cli/diagnostic_grammar.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{ .{ .name = "transit_query", .module = query.module("transit_query") }, .{ .name = "transit_sql_service", .module = sql_gateway.module("transit_sql_service") }, .{ .name = "transit_station_app", .module = application.module("transit_station_app") } },
    }) });
    b.step("diagnostic-grammar", "Build the public compiler diagnostic corpus consumer").dependOn(&b.addInstallArtifact(diagnostic_grammar, .{}).step);
    const mutation_latency_client = b.addExecutable(.{ .name = "transit-mutation-latency-client", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/performance/mutations/mutation_latency_client.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "transit_query", .module = query.module("transit_query") }},
        .link_libc = true,
    }) });
    b.step("mutation-latency-client", "Build the persistent public mutation caller control").dependOn(&b.addInstallArtifact(mutation_latency_client, .{}).step);
    if (sdk) |public_sdk| {
        const sdk_performance = b.addExecutable(.{ .name = "transit-sdk-performance", .root_module = b.createModule(.{
            .root_source_file = b.path("tests/sdk/consumers/zig/performance.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "transit_data_client", .module = public_sdk.module("transit_data_client") },
                .{ .name = "transit_catalog", .module = public_sdk.module("transit_catalog") },
                .{ .name = "transit_query_direct", .module = public_sdk.module("transit_query_direct") },
            },
            .link_libc = true,
        }) });
        b.step("sdk-performance-client", "Build the public Zig SDK performance consumer").dependOn(&b.addInstallArtifact(sdk_performance, .{}).step);
    }
    const cli_support = b.createModule(.{
        .root_source_file = b.path("apps/transit-cli/Support.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{ .{ .name = "transit_query", .module = query.module("transit_query") }, .{ .name = "transit_sql_service", .module = sql_gateway.module("transit_sql_service") }, .{ .name = "transit_sql_client", .module = sql_client.module("transit_sql_client") }, .{ .name = "transit_serving_http", .module = serving_http.module("transit_serving_http") } },
    });
    const file_capture = test_modules.get(.operations_file_capture);
    const file_benchmark = b.addExecutable(.{ .name = "transit-file-benchmark", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/performance/query/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{ .{ .name = "transit_fuze", .module = fuze.module("transit_fuze") }, .{ .name = "file_capture", .module = file_capture }, .{ .name = "transit_query", .module = query.module("transit_query") } },
    }) });
    const file_benchmark_step = b.step("file-benchmark", "Build bounded source/discovery/execution phase measurements");
    file_benchmark_step.dependOn(&b.addInstallArtifact(file_benchmark, .{}).step);
    const allocation_probe = b.addLibrary(.{ .name = "transit-fuze-allocations", .linkage = .dynamic, .root_module = b.createModule(.{ .target = target, .optimize = optimize, .link_libc = true }) });
    allocation_probe.root_module.addCSourceFile(.{ .file = b.path("tests/performance/query/allocations.c"), .flags = &.{ "-std=c11", "-Wall", "-Wextra", "-Werror" } });
    file_benchmark_step.dependOn(&b.addInstallArtifact(allocation_probe, .{}).step);
    const six_benchmark = b.addExecutable(.{ .name = "transit-six-benchmark", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/performance/query/six.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "transit_fuze", .module = fuze.module("transit_fuze") }},
    }) });
    b.step("six-benchmark", "Build the specialized six-type execution control").dependOn(&b.addInstallArtifact(six_benchmark, .{}).step);
    const vector_benchmark = b.addExecutable(.{ .name = "transit-fuze-vector-benchmark", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/performance/query/vector.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{ .{ .name = "transit_fuze", .module = fuze.module("transit_fuze") }, .{ .name = "transit_query", .module = query.module("transit_query") } },
    }) });
    b.step("vector-benchmark", "Build bounded vector operator and pipeline measurements").dependOn(&b.addInstallArtifact(vector_benchmark, .{}).step);
    b.step("direct-table-contract", "Export signed direct Table envelopes").dependOn(&b.addRunArtifact(catalog.artifact("transit-direct-table-contract")).step);
    const diagnostic_cases = b.addSystemCommand(&.{ "python3", "-B" });
    diagnostic_cases.addFileArg(b.path("tests/runner/launch.py"));
    diagnostic_cases.addFileArg(b.path("tests/interfaces/cli/diagnostic_case_codes.py"));
    diagnostic_cases.addFileArg(b.path("contracts/diagnostics/mappings.json"));
    const diagnostic_cases_file = diagnostic_cases.addOutputFileArg("causes.zig");
    const diagnostic_outcomes = b.addExecutable(.{ .name = "transit-diagnostic-outcomes", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/interfaces/cli/diagnostic_outcomes.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{ .{ .name = "transit_board_api", .module = b.dependency("transit_board_api", .{ .target = target, .optimize = optimize }).module("transit_board_api") }, .{ .name = "transit_flight", .module = flight.module("transit_flight") }, .{ .name = "diagnostic_cases", .module = b.createModule(.{ .root_source_file = diagnostic_cases_file, .target = target, .optimize = optimize }) }, .{ .name = "transit_station_app", .module = application.module("transit_station_app") }, .{ .name = "transit_query", .module = query.module("transit_query") }, .{ .name = "transit_catalog", .module = catalog.module("transit_catalog") }, .{ .name = "transit_serving", .module = serving.module("transit_serving") }, .{ .name = "transit_exchange", .module = exchange.module("transit_exchange") } },
    }) });
    b.step("diagnostic-outcomes", "Build executable semantic outcome projections").dependOn(&b.addInstallArtifact(diagnostic_outcomes, .{}).step);
    const file_diagnostic_module = b.createModule(.{ .root_source_file = b.path("tests/interfaces/cli/operations/FileDiagnosticTests.zig"), .target = target, .optimize = optimize, .imports = &.{ .{ .name = "transit_query", .module = query.module("transit_query") }, .{ .name = "cli_support", .module = cli_support }, .{ .name = "fixture_operations_file_diagnostic", .module = test_modules.get(.operations_file_diagnostic) } } });
    const file_diagnostics = b.addExecutable(.{ .name = "transit-file-diagnostics", .root_module = file_diagnostic_module });
    const diagnostic_outcomes_test = b.addSystemCommand(&.{ "python3", "-B" });
    diagnostic_outcomes_test.addFileArg(b.path("tests/runner/launch.py"));
    diagnostic_outcomes_test.addFileArg(b.path("tests/interfaces/cli/diagnostic_outcomes.py"));
    diagnostic_outcomes_test.addArtifactArg(diagnostic_outcomes);
    diagnostic_outcomes_test.addArtifactArg(file_diagnostics);
    diagnostic_outcomes_test.has_side_effects = true;
    diagnostic_outcomes_test.stdio = .inherit;
    b.step("test-diagnostic-outcomes", "Check reviewed semantic outcomes and exact recovery targets").dependOn(&diagnostic_outcomes_test.step);
    const diagnostic_errors = b.addExecutable(.{ .name = "transit-diagnostic-errors", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/interfaces/cli/diagnostic_errors.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{ .{ .name = "transit_query", .module = query.module("transit_query") }, .{ .name = "transit_catalog", .module = catalog.module("transit_catalog") }, .{ .name = "transit_station_app", .module = application.module("transit_station_app") }, .{ .name = "transit_serving", .module = serving.module("transit_serving") } },
    }) });
    b.step("diagnostic-errors", "Inspect compiler-inferred public error sets").dependOn(&b.addInstallArtifact(diagnostic_errors, .{}).step);
    const diagnostic_errors_test = b.addSystemCommand(&.{ "python3", "-B" });
    diagnostic_errors_test.addFileArg(b.path("tests/runner/launch.py"));
    diagnostic_errors_test.addFileArg(b.path("tests/interfaces/cli/diagnostic_errors.py"));
    diagnostic_errors_test.addArtifactArg(diagnostic_errors);
    diagnostic_errors_test.has_side_effects = true;
    diagnostic_errors_test.stdio = .inherit;
    b.step("test-diagnostic-errors", "Check compiler-inferred error sets and open-boundary fallbacks").dependOn(&diagnostic_errors_test.step);
    b.step("query-api", "Export reflected query workspace declarations").dependOn(&b.addInstallArtifact(query.artifact("transit-query-api"), .{}).step);
    const settings_reference = b.addExecutable(.{ .name = "transit-settings-reference", .root_module = b.createModule(.{
        .root_source_file = b.path("apps/transit-cli/SettingsReference.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{ .{ .name = "transit_query", .module = query.module("transit_query") }, .{ .name = "transit_sql_service", .module = sql_gateway.module("transit_sql_service") } },
    }) });
    b.step("settings-reference", "Export the typed configuration registry").dependOn(&b.addRunArtifact(settings_reference).step);
    b.step("configuration-contract", "Export reflected configuration operations").dependOn(&b.addRunArtifact(query.artifact("transit-configuration-contract")).step);
    b.step("station-contract", "Export reflected Station ABI and host schemas").dependOn(&b.addRunArtifact(station_bindings.artifact("transit-station-contract")).step);
    b.step("station-abi", "Build the shared Station implementation").dependOn(&b.addInstallArtifact(station_bindings.artifact("transit_station"), .{}).step);
    const arrow_proof = b.addExecutable(.{ .name = "transit-arrow-proof", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/query/arrow/arrow.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "transit_fuze", .module = fuze.module("transit_fuze") }},
    }) });
    const arrow_test = b.addSystemCommand(&.{ "python3", "-B" });
    arrow_test.addFileArg(b.path("tests/runner/launch.py"));
    arrow_test.addFileArg(b.path("tests/query/arrow/arrow.py"));
    arrow_test.addArtifactArg(arrow_proof);
    arrow_test.has_side_effects = true;
    arrow_test.stdio = .inherit;
    b.step("test-arrow", "Qualify finite IPC with an independent Arrow implementation").dependOn(&arrow_test.step);
    const sql_driver = b.addExecutable(.{ .name = "transit-sql-proof", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/query/sql/sql_driver.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{ .{ .name = "transit_fuze", .module = fuze.module("transit_fuze") }, .{ .name = "transit_query", .module = query.module("transit_query") } },
    }) });
    const sql_test = b.addSystemCommand(&.{ "python3", "-B" });
    sql_test.addFileArg(b.path("tests/runner/launch.py"));
    sql_test.addFileArg(b.path("tests/query/sql/compiler.py"));
    sql_test.addArtifactArg(sql_driver);
    const unified_sql = b.addExecutable(.{ .name = "transit-unified-sql-proof", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/query/unified/unified_sql.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "transit_fuze", .module = fuze.module("transit_fuze") }},
    }) });
    sql_test.addArtifactArg(unified_sql);
    const mutation_sql = b.addExecutable(.{ .name = "transit-mutation-sql-proof", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/interfaces/sql/sql_mutation.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "transit_station", .module = station.module("transit_station") }},
    }) });
    sql_test.addArtifactArg(mutation_sql);
    const table_dml_sql = b.addSystemCommand(&.{ "python3", "-B" });
    table_dml_sql.addFileArg(b.path("tests/runner/launch.py"));
    table_dml_sql.addFileArg(b.path("tests/query/sql/mutations.py"));
    table_dml_sql.addArtifactArg(mutation_sql);
    table_dml_sql.has_side_effects = true;
    table_dml_sql.stdio = .inherit;
    b.step("test-table-dml-sql", "Compare general Table DML with independent typed plan semantics").dependOn(&table_dml_sql.step);
    const declaration_sql = b.addExecutable(.{ .name = "transit-declaration-sql-proof", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/interfaces/sql/sql_declaration.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "transit_fuze", .module = fuze.module("transit_fuze") }},
    }) });
    sql_test.addArtifactArg(declaration_sql);
    const table_ddl_sql = b.addSystemCommand(&.{ "python3", "-B" });
    table_ddl_sql.addFileArg(b.path("tests/runner/launch.py"));
    table_ddl_sql.addFileArg(b.path("tests/query/sql/declarations.py"));
    table_ddl_sql.addArtifactArg(declaration_sql);
    table_ddl_sql.has_side_effects = true;
    table_ddl_sql.stdio = .inherit;
    b.step("test-table-ddl-sql", "Compare general Table DDL with independent grammar/schema semantics").dependOn(&table_ddl_sql.step);
    sql_test.has_side_effects = true;
    sql_test.stdio = .inherit;
    b.step("test-sql", "Qualify SQL parser, plans and Arrow execution against independent references").dependOn(&sql_test.step);
    const relational_sql = b.addExecutable(.{ .name = "transit-relational-sql-proof", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/query/execution/relational_sql.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "transit_fuze", .module = fuze.module("transit_fuze") }},
    }) });
    const relational_sql_test = b.addSystemCommand(&.{ "python3", "-B" });
    relational_sql_test.addFileArg(b.path("tests/runner/launch.py"));
    relational_sql_test.addFileArg(b.path("tests/query/sql/relational.py"));
    relational_sql_test.addArtifactArg(relational_sql);
    relational_sql_test.has_side_effects = true;
    relational_sql_test.stdio = .inherit;
    b.step("test-relational-sql", "Compare relational syntax across Zig, ANTLR and PostgreSQL").dependOn(&relational_sql_test.step);
    sql_test.step.dependOn(&relational_sql_test.step);
    const sql_benchmark = b.addExecutable(.{ .name = "transit-sql-benchmark", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/performance/declarative/sql_bench.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{ .{ .name = "transit_fuze", .module = fuze.module("transit_fuze") }, .{ .name = "transit_query", .module = query.module("transit_query") } },
    }) });
    b.step("sql-benchmark", "Build the pure SQL performance probe").dependOn(&b.addInstallArtifact(sql_benchmark, .{}).step);
    const declarative_benchmark = b.addExecutable(.{ .name = "transit-declarative-benchmark", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/performance/declarative/declarative_bench.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "transit_station", .module = station.module("transit_station") }},
    }) });
    b.step("declarative-benchmark", "Build declarative workload component benchmarks").dependOn(&b.addInstallArtifact(declarative_benchmark, .{}).step);
    const storage_benchmark = b.addExecutable(.{ .name = "transit-storage-benchmark", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/performance/storage/storage_benchmark.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{ .{ .name = "transit_storage", .module = b.dependency("transit_storage", .{ .target = target, .optimize = optimize }).module("transit_storage") }, .{ .name = "transit_fuze", .module = fuze.module("transit_fuze") }, .{ .name = "transit_core", .module = b.dependency("transit_core", .{ .target = target, .optimize = optimize }).module("transit_core") }, .{ .name = "transit_backend_local", .module = local_backend.module("transit_backend_local") } },
    }) });
    const storage_benchmark_options = b.addOptions();
    storage_benchmark.root_module.addImport("transit_memory", b.dependency("transit_memory", .{ .target = target, .optimize = optimize }).module("transit_memory"));
    const storage_body_bytes = b.option(u32, "storage-benchmark-body-bytes", "Deterministic storage probe payload bytes (16..65536)") orelse 1024;
    if (storage_body_bytes < 16 or storage_body_bytes > 65536) @panic("storage-benchmark-body-bytes must be 16..65536");
    storage_benchmark_options.addOption(u32, "body_bytes", storage_body_bytes);
    storage_benchmark.root_module.addOptions("storage_benchmark_options", storage_benchmark_options);
    b.step("storage-benchmark", "Build paired disk-backed native and Table owner measurements").dependOn(&b.addInstallArtifact(storage_benchmark, .{}).step);
    const tests = b.addTest(.{ .root_module = adapter.module("transit_backend_ursula") });
    const test_step = b.step("test", "Run compiled components, independent fixtures and local process faults");
    const components_step = b.step("test-components", "Run compiled component tests, including package-local filesystem checks");
    const fixtures_step = b.step("test-fixtures", "Run independent contract fixtures and native/port codec checks");
    const faults_step = b.step("test-faults", "Run local storage process-death and CLI lifecycle checks");
    test_step.dependOn(components_step);
    test_step.dependOn(fixtures_step);
    test_step.dependOn(faults_step);
    const counter_tests = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("examples/serving/counter_test.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "transit_serving", .module = serving.module("transit_serving") }},
    }) });
    const counter_test = b.addRunArtifact(counter_tests);
    components_step.dependOn(&counter_test.step);
    b.step("test-serving-counter", "Check direct counter acceptance and original native progress").dependOn(&counter_test.step);

    components_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = file_diagnostic_module })).step);
    const work_items_module = b.createModule(.{ .root_source_file = b.path("examples/work-items/WorkItems.zig"), .target = target, .optimize = optimize, .imports = &.{ .{ .name = "transit_station_app", .module = exampleModule(b, sdk, "transit_station_app", target, optimize) }, .{ .name = "transit_query", .module = exampleModule(b, sdk, "transit_query", target, optimize) } } });
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
    work_items_embed.step.dependOn(&web_dependencies.step);
    work_items_embed.step.dependOn(&work_items_generated.step);
    const work_items_gateway = b.addExecutable(.{ .name = "transit-work-items-gateway", .root_module = b.createModule(.{ .root_source_file = b.path("examples/work-items/Gateway.zig"), .target = target, .optimize = optimize, .imports = &.{ .{ .name = "work_items", .module = work_items_module }, .{ .name = "transit_http_server", .module = http_server.module("transit_http_server") }, .{ .name = "assets", .module = b.createModule(.{ .root_source_file = work_items_assets, .target = target, .optimize = optimize }) } } }) });
    const install_work_items_gateway = b.addInstallArtifact(work_items_gateway, .{});
    b.step("work-items-gateway", "Install the generated work-item application gateway").dependOn(&install_work_items_gateway.step);
    b.step("transit-work-items-gateway", "Install the generated work-item gateway image entry point").dependOn(&install_work_items_gateway.step);
    b.step("test-work-items-unit", "Check the application-owned Table migration").dependOn(&work_items_test.step);
    components_step.dependOn(&work_items_test.step);
    const work_items_contract = b.addSystemCommand(&.{ "python3", "-B" });
    work_items_contract.addFileArg(b.path("tests/runner/launch.py"));
    work_items_contract.addFileArg(b.path("tests/runtime/application/work_items_contract.py"));
    work_items_contract.has_side_effects = true;
    work_items_contract.stdio = .inherit;
    fixtures_step.dependOn(&work_items_contract.step);
    const application_contract = b.addSystemCommand(&.{ "python3", "-B" });
    application_contract.addFileArg(b.path("tests/runner/launch.py"));
    application_contract.addFileArg(b.path("tests/interfaces/installation/application_contract.py"));
    application_contract.has_side_effects = true;
    application_contract.stdio = .inherit;
    fixtures_step.dependOn(&application_contract.step);
    const application_migration = b.addSystemCommand(&.{ "python3", "-B" });
    application_migration.addFileArg(b.path("tests/runner/launch.py"));
    application_migration.addFileArg(b.path("tests/interfaces/installation/application_migration_contract.py"));
    application_migration.has_side_effects = true;
    application_migration.stdio = .inherit;
    fixtures_step.dependOn(&application_migration.step);
    const query_draft = b.addSystemCommand(&.{ "python3", "-B" });
    query_draft.addFileArg(b.path("tests/runner/launch.py"));
    query_draft.addFileArg(b.path("tests/interfaces/board/query_draft_contract.py"));
    query_draft.has_side_effects = true;
    query_draft.stdio = .inherit;
    fixtures_step.dependOn(&query_draft.step);
    const application_signing = b.addSystemCommand(&.{ "python3", "-B" });
    application_signing.addFileArg(b.path("tests/runner/launch.py"));
    application_signing.addFileArg(b.path("tests/interfaces/installation/application_signing.py"));
    application_signing.has_side_effects = true;
    application_signing.stdio = .inherit;
    fixtures_step.dependOn(&application_signing.step);
    const reactive_signing = b.addSystemCommand(&.{ "python3", "-B" });
    reactive_signing.addFileArg(b.path("tests/runner/launch.py"));
    reactive_signing.addFileArg(b.path("tests/interfaces/reactive/reactive_fixtures.py"));
    reactive_signing.addArg("--check");
    reactive_signing.has_side_effects = true;
    reactive_signing.stdio = .inherit;
    fixtures_step.dependOn(&reactive_signing.step);
    components_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = application.module("transit_station_app") })).step);
    components_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = serving_http.module("transit_serving_http") })).step);
    components_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = serving.module("transit_serving") })).step);
    components_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = http_server.module("transit_http_server") })).step);
    components_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = document.module("transit_station_document") })).step);
    components_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = document_core.module("transit_document") })).step);
    components_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = b.dependency("transit_tls", .{ .target = target, .optimize = optimize }).module("transit_tls") })).step);
    components_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = grpc.module("transit_grpc") })).step);
    components_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = exchange.module("transit_exchange") })).step);
    components_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = station_grpc.module("transit_station_grpc") })).step);
    components_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = station_http.module("transit_station_http") })).step);
    components_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = query.module("transit_query") })).step);
    components_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = catalog.module("transit_catalog") })).step);
    components_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = storage.module("transit_storage") })).step);
    const local_native_tests = b.addRunArtifact(b.addTest(.{ .root_module = local_backend.module("transit_backend_local") }));
    const local_catalog_tests = b.addRunArtifact(b.addTest(.{ .filters = b.option([]const []const u8, "local-catalog-filter", "Select local catalog tests during development") orelse &.{}, .root_module = b.createModule(.{
        .root_source_file = b.path("apps/transit-node/LocalCatalogPolicy.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{ .{ .name = "transit_io", .module = b.dependency("transit_io", .{ .target = target, .optimize = optimize }).module("transit_io") }, .{ .name = "transit_memory", .module = b.dependency("transit_memory", .{ .target = target, .optimize = optimize }).module("transit_memory") }, .{ .name = "transit_catalog", .module = catalog.module("transit_catalog") }, .{ .name = "transit_backend_local", .module = local_backend.module("transit_backend_local") }, .{ .name = "transit_client", .module = b.dependency("transit_client", .{ .target = target, .optimize = optimize }).module("transit_client") }, .{ .name = "transit_core", .module = b.dependency("transit_core", .{ .target = target, .optimize = optimize }).module("transit_core") }, .{ .name = "transit_observability", .module = observations.module("transit_observability") } },
    }) }));
    b.step("test-local-catalog", "Verify direct catalog lifecycle against current local native policy").dependOn(&local_catalog_tests.step);
    // The required storage-query lane owns test-local-catalog. Running it here
    // as well repeated the same physical catalog workload in the core lane.
    const local_data_collection_tests = b.addRunArtifact(b.addTest(.{ .filters = b.option([]const []const u8, "local-data-collection-filter", "Select local data collection tests during development") orelse &.{}, .root_module = b.createModule(.{
        .root_source_file = b.path("tests/storage/local/direct_collection.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{ .{ .name = "transit_catalog", .module = catalog.module("transit_catalog") }, .{ .name = "transit_backend_local", .module = local_backend.module("transit_backend_local") }, .{ .name = "transit_core", .module = b.dependency("transit_core", .{ .target = target, .optimize = optimize }).module("transit_core") } },
    }) }));
    b.step("test-local-data-collection", "Verify Table expiry and retained data across physical collection").dependOn(&local_data_collection_tests.step);
    components_step.dependOn(&local_data_collection_tests.step);
    components_step.dependOn(&local_native_tests.step);
    b.step("test-local-native", "Verify native authority over local disk storage").dependOn(&local_native_tests.step);
    const local_collection_faults = b.addExecutable(.{ .name = "transit-local-native-collection-faults", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/storage/local/local_native_collection_faults.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{ .{ .name = "transit_catalog", .module = catalog.module("transit_catalog") }, .{ .name = "transit_backend_local", .module = local_backend.module("transit_backend_local") }, .{ .name = "transit_core", .module = b.dependency("transit_core", .{ .target = target, .optimize = optimize }).module("transit_core") } },
    }) });
    const local_collection_test = b.addSystemCommand(&.{ "python3", "-B" });
    local_collection_test.addFileArg(b.path("tests/runner/launch.py"));
    local_collection_test.addFileArg(b.path("tests/storage/local/local_native_collection_faults.py"));
    local_collection_test.addArtifactArg(local_collection_faults);
    local_collection_test.has_side_effects = true;
    local_collection_test.stdio = .inherit;
    faults_step.dependOn(&local_collection_test.step);
    b.step("test-local-native-collection-faults", "Verify process death during native physical collection").dependOn(&local_collection_test.step);
    const direct_collection_test = b.addSystemCommand(&.{ "python3", "-B" });
    direct_collection_test.addFileArg(b.path("tests/runner/launch.py"));
    direct_collection_test.addFileArg(b.path("tests/storage/local/local_native_collection_faults.py"));
    direct_collection_test.addArtifactArg(local_collection_faults);
    direct_collection_test.addArg("direct");
    direct_collection_test.has_side_effects = true;
    direct_collection_test.stdio = .inherit;
    faults_step.dependOn(&direct_collection_test.step);
    b.step("test-local-data-collection-faults", "Verify process death during direct-data physical collection").dependOn(&direct_collection_test.step);
    const local_objects = b.addExecutable(.{ .name = "transit-local-objects-proof", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/storage/local/local_objects.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "transit_storage", .module = storage.module("transit_storage") }},
    }) });
    const local_objects_test = b.addSystemCommand(&.{ "python3", "-B" });
    local_objects_test.addFileArg(b.path("tests/runner/launch.py"));
    local_objects_test.addFileArg(b.path("tests/storage/local/local_objects.py"));
    local_objects_test.addArtifactArg(local_objects);
    local_objects_test.has_side_effects = true;
    local_objects_test.stdio = .inherit;
    faults_step.dependOn(&local_objects_test.step);
    b.step("test-local-objects", "Qualify local object CAS and immutable publication across processes").dependOn(&local_objects_test.step);
    const local_faults = b.addExecutable(.{ .name = "transit-local-storage-faults", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/storage/local/local_storage_faults.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{ .{ .name = "transit_storage", .module = storage.module("transit_storage") }, .{ .name = "transit_fuze", .module = fuze.module("transit_fuze") }, .{ .name = "transit_protocol", .module = b.dependency("transit_protocol", .{ .target = target, .optimize = optimize }).module("transit_protocol") } },
    }) });
    const local_faults_test = b.addSystemCommand(&.{ "python3", "-B" });
    local_faults_test.addFileArg(b.path("tests/runner/launch.py"));
    local_faults_test.addFileArg(b.path("tests/storage/local/local_storage_faults.py"));
    local_faults_test.addArtifactArg(local_faults);
    local_faults_test.has_side_effects = true;
    local_faults_test.stdio = .inherit;
    faults_step.dependOn(&local_faults_test.step);
    b.step("test-local-storage-faults", "Verify process death at local WAL and object publication boundaries").dependOn(&local_faults_test.step);
    const unified_contract_test = b.addSystemCommand(&.{ "python3", "-B" });
    unified_contract_test.addFileArg(b.path("tests/runner/launch.py"));
    unified_contract_test.addFileArg(b.path("tests/query/unified/unified_contract.py"));
    unified_contract_test.has_side_effects = true;
    unified_contract_test.stdio = .inherit;
    fixtures_step.dependOn(&unified_contract_test.step);
    const relational_records_test = b.addSystemCommand(&.{ "python3", "-B" });
    relational_records_test.addFileArg(b.path("tests/runner/launch.py"));
    relational_records_test.addFileArg(b.path("tests/query/execution/relational_records.py"));
    relational_records_test.has_side_effects = true;
    relational_records_test.stdio = .inherit;
    fixtures_step.dependOn(&relational_records_test.step);
    const named_relational_records_test = b.addSystemCommand(&.{ "python3", "-B" });
    named_relational_records_test.addFileArg(b.path("tests/runner/launch.py"));
    named_relational_records_test.addFileArg(b.path("tests/query/execution/named_relational_records.py"));
    named_relational_records_test.has_side_effects = true;
    named_relational_records_test.stdio = .inherit;
    fixtures_step.dependOn(&named_relational_records_test.step);
    const relational_exchange_test = b.addSystemCommand(&.{ "python3", "-B" });
    relational_exchange_test.addFileArg(b.path("tests/runner/launch.py"));
    relational_exchange_test.addFileArg(b.path("tests/query/execution/relational_exchange.py"));
    relational_exchange_test.has_side_effects = true;
    relational_exchange_test.stdio = .inherit;
    fixtures_step.dependOn(&relational_exchange_test.step);
    const worker_handoff_test = b.addSystemCommand(&.{ "python3", "-B" });
    worker_handoff_test.addFileArg(b.path("tests/runner/launch.py"));
    worker_handoff_test.addFileArg(b.path("tests/query/execution/worker_handoff.py"));
    worker_handoff_test.has_side_effects = true;
    worker_handoff_test.stdio = .inherit;
    fixtures_step.dependOn(&worker_handoff_test.step);
    const document_contract_test = b.addSystemCommand(&.{ "python3", "-B" });
    document_contract_test.addFileArg(b.path("tests/runner/launch.py"));
    document_contract_test.addFileArg(b.path("tests/runtime/document/document_contract.py"));
    document_contract_test.has_side_effects = true;
    document_contract_test.stdio = .inherit;
    fixtures_step.dependOn(&document_contract_test.step);
    const grpc_contract_test = b.addSystemCommand(&.{ "python3", "-B" });
    grpc_contract_test.addFileArg(b.path("tests/runner/launch.py"));
    grpc_contract_test.addFileArg(b.path("tests/interfaces/grpc/grpc_contract.py"));
    grpc_contract_test.has_side_effects = true;
    grpc_contract_test.stdio = .inherit;
    fixtures_step.dependOn(&grpc_contract_test.step);
    const exchange_failure_test = b.addSystemCommand(&.{ "python3", "-B" });
    exchange_failure_test.addFileArg(b.path("tests/runner/launch.py"));
    exchange_failure_test.addFileArg(b.path("tests/query/execution/exchange_failure.py"));
    exchange_failure_test.has_side_effects = true;
    exchange_failure_test.stdio = .inherit;
    fixtures_step.dependOn(&exchange_failure_test.step);
    const build_test_step = b.step("test-build", "Compile applications and integration probes");
    for ([_]*std.Build.Step.Compile{ node_artifact, cli_artifact, controller_artifact, delivery_artifact, station_controller, station_host, client_host, query_host, transit_cli }) |app| {
        build_test_step.dependOn(&app.step);
    }
    build_test_step.dependOn(&work_items.step);
    build_test_step.dependOn(&work_items_gateway.step);
    const work_items_proof = b.addExecutable(.{ .name = "transit-work-items-proof", .root_module = b.createModule(.{ .root_source_file = b.path("tests/runtime/application/work_items.zig"), .target = target, .optimize = optimize, .imports = &.{ .{ .name = "work_items", .module = work_items_module }, .{ .name = "transit_station", .module = station.module("transit_station") }, .{ .name = "fixture_growing_support", .module = test_modules.get(.growing_support) }, .{ .name = "fixture_table_authorization_support", .module = test_modules.get(.table_authorization_support) } } }) });
    build_test_step.dependOn(&work_items_proof.step);
    b.step("work-items-proof", "Build the native work-item qualification caller").dependOn(&b.addInstallArtifact(work_items_proof, .{}).step);
    const work_items_browser_proof = b.addExecutable(.{ .name = "transit-work-items-browser-proof", .root_module = b.createModule(.{ .root_source_file = b.path("tests/runtime/application/work_items_browser.zig"), .target = target, .optimize = optimize, .imports = &.{ .{ .name = "work_items", .module = work_items_module }, .{ .name = "transit_station", .module = station.module("transit_station") }, .{ .name = "fixture_growing_support", .module = test_modules.get(.growing_support) }, .{ .name = "fixture_table_authorization_support", .module = test_modules.get(.table_authorization_support) }, .{ .name = "fixture_work_items", .module = test_modules.get(.work_items) } } }) });
    build_test_step.dependOn(&work_items_browser_proof.step);
    b.step("work-items-browser-proof", "Build the generated application qualification caller").dependOn(&b.addInstallArtifact(work_items_browser_proof, .{}).step);
    build_test_step.dependOn(&application.artifact("transit-app").step);
    build_test_step.dependOn(&query.artifact("transit-query-api").step);
    build_test_step.dependOn(&serving_example.step);
    const serving_http_proof = b.addExecutable(.{ .name = "transit-serving-http-proof", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/interfaces/http/serving_http.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "transit_http_server", .module = http_server.module("transit_http_server") }},
    }) });
    build_test_step.dependOn(&serving_http_proof.step);
    const serving_http_test = b.addSystemCommand(&.{ "python3", "-B" });
    serving_http_test.addFileArg(b.path("tests/runner/launch.py"));
    serving_http_test.addFileArg(b.path("tests/interfaces/http/serving_http.py"));
    serving_http_test.addArtifactArg(serving_http_proof);
    serving_http_test.has_side_effects = true;
    serving_http_test.stdio = .inherit;
    b.step("test-serving-http", "Qualify shared HTTP framing, capacity and joined deadlines").dependOn(&serving_http_test.step);
    const tls_alpn_proof = b.addExecutable(.{ .name = "transit-tls-alpn-proof", .root_module = b.createModule(.{ .root_source_file = b.path("tests/interfaces/http/tls_alpn.zig"), .target = target, .optimize = optimize, .imports = &.{.{ .name = "transit_tls", .module = b.dependency("transit_tls", .{ .target = target, .optimize = optimize }).module("transit_tls") }} }) });
    build_test_step.dependOn(&tls_alpn_proof.step);
    const tls_alpn_test = b.addSystemCommand(&.{ "python3", "-B" });
    tls_alpn_test.addFileArg(b.path("tests/runner/launch.py"));
    tls_alpn_test.addFileArg(b.path("tests/interfaces/http/tls_alpn.py"));
    tls_alpn_test.addArtifactArg(tls_alpn_proof);
    tls_alpn_test.has_side_effects = true;
    tls_alpn_test.stdio = .inherit;
    b.step("test-tls-alpn", "Qualify required ALPN with independent TLS peers").dependOn(&tls_alpn_test.step);
    const grpc_transport_proof = b.addExecutable(.{ .name = "transit-grpc-transport-proof", .root_module = b.createModule(.{ .root_source_file = b.path("tests/interfaces/grpc/grpc_transport.zig"), .target = target, .optimize = optimize, .imports = &.{ .{ .name = "transit_grpc", .module = grpc.module("transit_grpc") }, .{ .name = "transit_station_grpc", .module = station_grpc.module("transit_station_grpc") } } }) });
    grpc_transport_proof.root_module.addAnonymousImport("grpc_descriptor", .{ .root_source_file = b.path("tests/fixtures/grpc/peer.pb") });
    build_test_step.dependOn(&grpc_transport_proof.step);
    const grpc_transport_test = b.addSystemCommand(&.{ "python3", "-B" });
    grpc_transport_test.addFileArg(b.path("tests/runner/launch.py"));
    grpc_transport_test.addFileArg(b.path("tests/interfaces/grpc/grpc_transport.py"));
    grpc_transport_test.addArtifactArg(grpc_transport_proof);
    grpc_transport_test.has_side_effects = true;
    grpc_transport_test.stdio = .inherit;
    b.step("test-grpc-transport", "Qualify finite RPC shapes against independent peers").dependOn(&grpc_transport_test.step);
    components_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = flight.module("transit_flight") })).step);
    const flight_metadata_proof = b.addExecutable(.{ .name = "transit-flight-metadata-proof", .root_module = b.createModule(.{ .root_source_file = b.path("packages/zig/transit-flight/src/metadata_fixture.zig"), .target = target, .optimize = optimize, .imports = &.{.{ .name = "transit_flight", .module = flight.module("transit_flight") }} }) });
    build_test_step.dependOn(&flight_metadata_proof.step);
    const flight_metadata_test = b.addSystemCommand(&.{ "python3", "-B" });
    flight_metadata_test.addFileArg(b.path("tests/runner/launch.py"));
    flight_metadata_test.addFileArg(b.path("tests/interfaces/flight/flight_metadata.py"));
    flight_metadata_test.addArtifactArg(flight_metadata_proof);
    flight_metadata_test.has_side_effects = true;
    flight_metadata_test.stdio = .inherit;
    b.step("test-flight-metadata", "Qualify standard Flight SQL metadata with independent Arrow").dependOn(&flight_metadata_test.step);
    const grpc_server_proof = b.addExecutable(.{ .name = "transit-grpc-server-proof", .root_module = b.createModule(.{ .root_source_file = b.path("tests/interfaces/grpc/grpc_server.zig"), .target = target, .optimize = optimize, .imports = &.{.{ .name = "transit_grpc", .module = grpc.module("transit_grpc") }} }) });
    build_test_step.dependOn(&grpc_server_proof.step);
    const grpc_server_test = b.addSystemCommand(&.{ "python3", "-B" });
    grpc_server_test.addFileArg(b.path("tests/runner/launch.py"));
    grpc_server_test.addFileArg(b.path("tests/interfaces/grpc/grpc_server.py"));
    grpc_server_test.addArtifactArg(grpc_server_proof);
    grpc_server_test.has_side_effects = true;
    grpc_server_test.stdio = .inherit;
    b.step("test-grpc-server", "Qualify bounded inbound RPCs against independent clients").dependOn(&grpc_server_test.step);
    const http_transport_proof = b.addExecutable(.{ .name = "transit-http-transport-proof", .root_module = b.createModule(.{ .root_source_file = b.path("tests/interfaces/http/http_transport.zig"), .target = target, .optimize = optimize, .imports = &.{.{ .name = "transit_station_http", .module = station_http.module("transit_station_http") }} }) });
    build_test_step.dependOn(&http_transport_proof.step);
    const http_transport_test = b.addSystemCommand(&.{ "python3", "-B" });
    http_transport_test.addFileArg(b.path("tests/runner/launch.py"));
    http_transport_test.addFileArg(b.path("tests/interfaces/http/http_transport.py"));
    http_transport_test.addArtifactArg(http_transport_proof);
    http_transport_test.has_side_effects = true;
    http_transport_test.stdio = .inherit;
    b.step("test-http-transport", "Qualify single-send HTTP/TLS against independent peers").dependOn(&http_transport_test.step);
    components_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = station.module("transit_station") })).step);
    components_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = station_bindings.module("station_abi") })).step);
    components_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = b.dependency("transit_data_client", .{ .target = target, .optimize = optimize }).module("transit_data_client") })).step);
    components_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = b.dependency("transit_memory", .{ .target = target, .optimize = optimize }).module("transit_memory") })).step);
    components_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = b.dependency("transit_bitmap", .{ .target = target, .optimize = optimize }).module("transit_bitmap") })).step);
    components_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = b.dependency("transit_io", .{ .target = target, .optimize = optimize }).module("transit_io") })).step);
    components_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = fuze.module("transit_fuze") })).step);
    components_step.dependOn(&b.addRunArtifact(tests).step);
    components_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = telemetry.module("telemetry") })).step);
    const telemetry_proof = b.addExecutable(.{ .name = "telemetry-proof", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/interfaces/inspection/telemetry.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "telemetry", .module = telemetry.module("telemetry") }},
    }) });
    const telemetry_test = b.addSystemCommand(&.{ "python3", "-B" });
    telemetry_test.addFileArg(b.path("tests/runner/launch.py"));
    telemetry_test.addFileArg(b.path("tests/interfaces/inspection/telemetry.py"));
    telemetry_test.addArtifactArg(telemetry_proof);
    telemetry_test.has_side_effects = true;
    telemetry_test.stdio = .inherit;
    b.step("test-telemetry", "Prove bounded telemetry under stalled and closed sinks").dependOn(&telemetry_test.step);
    components_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = observations.module("transit_observability") })).step);
    const page_proof = b.addExecutable(.{ .name = "transit-page-proof", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/storage/providers/pages.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{ .{ .name = "transit_core", .module = core.module("transit_core") }, .{ .name = "transit_backend_ursula", .module = adapter.module("transit_backend_ursula") } },
    }) });
    const page_test = b.addSystemCommand(&.{ "python3", "-B" });
    page_test.addFileArg(b.path("tests/runner/launch.py"));
    page_test.addFileArg(b.path("tests/storage/providers/pages.py"));
    page_test.addArtifactArg(page_proof);
    page_test.addPassthruArgs();
    page_test.has_side_effects = true;
    page_test.stdio = .inherit;
    b.step("test-pages", "Qualify immutable pages and bounded cache over disk Ursula").dependOn(&page_test.step);
    const block_proof = b.addExecutable(.{ .name = "transit-block-proof", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/storage/providers/block_storage.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{ .{ .name = "transit_core", .module = core.module("transit_core") }, .{ .name = "transit_backend_ursula", .module = adapter.module("transit_backend_ursula") } },
    }) });
    const block_test = b.addSystemCommand(&.{ "python3", "-B" });
    block_test.addFileArg(b.path("tests/runner/launch.py"));
    block_test.addFileArg(b.path("tests/storage/providers/block_storage.py"));
    block_test.addArtifactArg(block_proof);
    block_test.has_side_effects = true;
    block_test.stdio = .inherit;
    b.step("test-block-storage", "Qualify bounded immutable blocks and retained roots over disk Ursula").dependOn(&block_test.step);
    const collection_proof = b.addExecutable(.{ .name = "transit-storage-collection-proof", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/storage/providers/storage_collection.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{ .{ .name = "transit_core", .module = core.module("transit_core") }, .{ .name = "transit_backend_ursula", .module = adapter.module("transit_backend_ursula") } },
    }) });
    const collection_test = b.addSystemCommand(&.{ "python3", "-B" });
    collection_test.addFileArg(b.path("tests/runner/launch.py"));
    collection_test.addFileArg(b.path("tests/storage/providers/storage_collection.py"));
    collection_test.addArtifactArg(collection_proof);
    collection_test.has_side_effects = true;
    collection_test.stdio = .inherit;
    b.step("test-storage-collection", "Qualify epoch-fenced physical reclamation and restart accounting").dependOn(&collection_test.step);
    const growth_proof = b.addExecutable(.{ .name = "transit-growth-proof", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/storage/providers/growing.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{ .{ .name = "transit_core", .module = core.module("transit_core") }, .{ .name = "transit_backend_ursula", .module = adapter.module("transit_backend_ursula") } },
    }) });
    const growth_test = b.addSystemCommand(&.{ "python3", "-B" });
    growth_test.addFileArg(b.path("tests/runner/launch.py"));
    growth_test.addFileArg(b.path("tests/storage/providers/growing.py"));
    growth_test.addArtifactArg(growth_proof);
    growth_test.addPassthruArgs();
    growth_test.has_side_effects = true;
    growth_test.stdio = .inherit;
    b.step("test-growing", "Prove growing authority publication and recovery through disk Ursula").dependOn(&growth_test.step);
    const simulation_blocks = b.createModule(.{
        .root_source_file = b.path("tests/verification/simulation/storage/simulation_blocks.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "transit_core", .module = core.module("transit_core") }},
    });
    const simulation_store = b.createModule(.{
        .root_source_file = b.path("tests/verification/simulation/storage/simulation_store.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{ .{ .name = "transit_core", .module = core.module("transit_core") }, .{ .name = "simulation_blocks", .module = simulation_blocks } },
    });
    const delivery_simulation = b.createModule(.{
        .root_source_file = b.path("tests/verification/simulation/storage/delivery_simulation.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{ .{ .name = "transit_core", .module = core.module("transit_core") }, .{ .name = "simulation_blocks", .module = simulation_blocks } },
    });
    const transition_driver = b.addExecutable(.{ .name = "transit-transition-driver", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/verification/simulation/transitions/transition_driver.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{ .{ .name = "transit_core", .module = core.module("transit_core") }, .{ .name = "simulation_blocks", .module = simulation_blocks } },
    }) });
    const properties = b.addSystemCommand(&.{ "python3", "-B" });
    properties.addFileArg(b.path("tests/runner/launch.py"));
    properties.addFileArg(b.path("tests/verification/simulation/transitions/transitions.py"));
    properties.addArtifactArg(transition_driver);
    properties.addPassthruArgs();
    properties.has_side_effects = true;
    properties.stdio = .inherit;
    b.step("test-properties", "Run reproducible authority schedules and saved regressions").dependOn(&properties.step);
    const simulation_driver = b.addExecutable(.{ .name = "transit-delivery-simulation", .root_module = delivery_simulation });
    const simulation = b.addSystemCommand(&.{ "python3", "-B" });
    simulation.addFileArg(b.path("tests/runner/launch.py"));
    simulation.addFileArg(b.path("tests/verification/simulation/storage/simulation.py"));
    simulation.addArtifactArg(simulation_driver);
    simulation.addPassthruArgs();
    simulation.has_side_effects = true;
    simulation.stdio = .inherit;
    b.step("test-simulation", "Simulate competing workers, ordered delivery and bounded recovery progress").dependOn(&simulation.step);
    const resource_simulation_driver = b.addExecutable(.{ .name = "transit-resource-simulation", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/verification/simulation/resources/resource_simulation.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{ .{ .name = "transit_core", .module = core.module("transit_core") }, .{ .name = "simulation_store", .module = simulation_store } },
    }) });
    const resource_simulation = b.addSystemCommand(&.{ "python3", "-B" });
    resource_simulation.addFileArg(b.path("tests/runner/launch.py"));
    resource_simulation.addFileArg(b.path("tests/verification/simulation/resources/resource_simulation.py"));
    resource_simulation.addArtifactArg(resource_simulation_driver);
    resource_simulation.addPassthruArgs();
    resource_simulation.has_side_effects = true;
    resource_simulation.stdio = .inherit;
    b.step("test-resource-simulation", "Simulate page I/O faults and atomic resource publication").dependOn(&resource_simulation.step);
    const formal = b.addSystemCommand(&.{ "python3", "-B" });
    formal.addFileArg(b.path("tests/runner/launch.py"));
    formal.addFileArg(b.path("tests/verification/models/model.py"));
    formal.addArtifactArg(transition_driver);
    formal.addPassthruArgs();
    formal.has_side_effects = true;
    formal.stdio = .inherit;
    b.step("test-model", "Check finite authority model and replay counterexamples against Zig").dependOn(&formal.step);
    // The pinned native x86 backend does not emit usable fuzz coverage yet.
    const codec_module = b.createModule(.{
        .root_source_file = b.path("tests/interfaces/native/codecs.zig"),
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
    const diagnostics_export = b.addRunArtifact(exporter);
    diagnostics_export.addArg("--diagnostic");
    b.step("diagnostic-contract", "Export bounded shared diagnostic JSON Schema").dependOn(&diagnostics_export.step);
    const lifecycle_export = b.addRunArtifact(exporter);
    lifecycle_export.addArg("--data-lifecycle");
    b.step("data-lifecycle-contract", "Export neutral data lifecycle and snapshot schemas").dependOn(&lifecycle_export.step);
    const index_export = b.addRunArtifact(exporter);
    index_export.addArg("--index-lifecycle");
    b.step("index-lifecycle-contract", "Export neutral index declaration and coverage schemas").dependOn(&index_export.step);
    components_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = protocol.module("transit_protocol") })).step);
    components_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = transit_board_api.module("transit_board_api") })).step);
    const board_contract = b.addExecutable(.{ .name = "transit-board-contract", .root_module = b.createModule(.{ .root_source_file = b.path("packages/zig/transit-board-api/src/export.zig"), .target = target, .optimize = optimize, .imports = &.{.{ .name = "transit_board_api", .module = transit_board_api.module("transit_board_api") }} }) });
    b.step("transit-board-contract", "Export Board OpenAPI to stdout").dependOn(&b.addRunArtifact(board_contract).step);
    const scheduler_driver = b.addExecutable(.{ .name = "transit-scheduler-simulation", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/verification/simulation/scheduler/scheduler_simulation.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{ .{ .name = "transit_core", .module = core.module("transit_core") }, .{ .name = "transit_client", .module = client.module("transit_client") }, .{ .name = "simulation_store", .module = simulation_store }, .{ .name = "delivery_simulation", .module = delivery_simulation } },
    }) });
    const scheduler = b.addSystemCommand(&.{ "python3", "-B" });
    scheduler.addFileArg(b.path("tests/runner/launch.py"));
    scheduler.addFileArg(b.path("tests/verification/simulation/scheduler/scheduler_simulation.py"));
    scheduler.addArtifactArg(scheduler_driver);
    scheduler.addPassthruArgs();
    scheduler.has_side_effects = true;
    scheduler.stdio = .inherit;
    b.step("test-scheduler-simulation", "Schedule shared Sessions/courier with faults, clocks and maintenance").dependOn(&scheduler.step);
    const domains = b.addSystemCommand(&.{ "python3", "-B" });
    domains.addFileArg(b.path("tests/runner/launch.py"));
    domains.addFileArg(b.path("tests/verification/simulation/domains/domain_simulation.py"));
    inline for (.{ document_core.module("transit_document"), document.module("transit_station_document"), exchange.module("transit_exchange"), serving.module("transit_serving"), core.module("transit_core"), catalog.module("transit_catalog") }) |module| {
        domains.addArtifactArg(b.addTest(.{ .root_module = module, .filters = &.{"simulation:"} }));
    }
    domains.addPassthruArgs();
    domains.has_side_effects = true;
    domains.stdio = .inherit;
    b.step("test-domain-simulation", "Replay seeded Document, Exchange, refresh, provider and catalog schedules").dependOn(&domains.step);
    const installation_fixture = b.addRunArtifact(client.artifact("transit-application-installation-contract"));
    installation_fixture.addArg("--fixture");
    b.step("application-installation-fixture", "Export a shared application signing fixture").dependOn(&installation_fixture.step);
    b.step("application-installation-contract", "Export language-neutral application installation schema").dependOn(&b.addRunArtifact(client.artifact("transit-application-installation-contract")).step);
    b.step("client-contract", "Export reflected client ABI signatures").dependOn(&b.addRunArtifact(client.artifact("transit-client-contract")).step);
    // Compile schema exporters in one graph; the independent validators receive
    // immutable artifact paths, without overwriting any shared install prefix.
    b.step("browser-contract", "Export browser declarations and public responses").dependOn(&b.addRunArtifact(catalog.artifact("transit-browser-contract")).step);
    const contract_checks = b.addSystemCommand(&.{ "python3", "-B" });
    contract_checks.addFileArg(b.path("tests/runner/checks.py"));
    contract_checks.addArg("contracts");
    inline for (.{
        .{ "protocol", exporter },
        .{ "installation", client.artifact("transit-application-installation-contract") },
        .{ "client", client.artifact("transit-client-contract") },
        .{ "station", station_bindings.artifact("transit-station-contract") },
        .{ "logical", fuze.artifact("transit-logical-contract") },
        .{ "direct-table", catalog.artifact("transit-direct-table-contract") },
        .{ "browser", catalog.artifact("transit-browser-contract") },
        .{ "configuration", query.artifact("transit-configuration-contract") },
        .{ "settings-reference", settings_reference },
        .{ "sql-session", sql_protocol.artifact("transit-sql-contract") },
    }) |entry| {
        contract_checks.addArgs(&.{ "--generator", entry[0] });
        contract_checks.addArtifactArg(entry[1]);
    }
    // Validators read checked-in schemas and fixtures; always rerun them even
    // when compilation was cached. A generator failure cannot become an empty
    // successful pipe or hide behind a later validator's exit status.
    contract_checks.has_side_effects = true;
    contract_checks.stdio = .inherit;
    b.step("check-contracts", "Check generated contracts through one build graph").dependOn(&contract_checks.step);
    b.step("client-abi", "Build the shared client library").dependOn(&b.addInstallArtifact(client.artifact("transit_client"), .{}).step);
    components_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = client.module("transit_client") })).step);
    components_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = client.module("client_abi") })).step);
    b.step("test-transit-board-unit", "Test Board ingress and route boundaries").dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = board.root_module })).step);
    components_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = runtime.module("transit_runtime_substrate") })).step);
    const services = b.addSystemCommand(&.{ "python3", "-B" });
    const plugin_tests = b.addSystemCommand(&.{ "python3", "-B" });
    plugin_tests.addFileArg(b.path("tests/runner/launch.py"));
    plugin_tests.addFileArg(b.path("tests/interfaces/deployment/kubectl_transit.py"));
    plugin_tests.addArtifactArg(kubectl_transit);
    plugin_tests.has_side_effects = true;
    plugin_tests.stdio = .inherit;
    b.step("test-kubectl-transit", "Verify Kubernetes plugin boundaries without a cluster").dependOn(&plugin_tests.step);
    const probe = b.addExecutable(.{ .name = "isolation-probe", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/runtime/deployment/isolation.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    }) });
    const install_probe = b.addInstallArtifact(probe, .{});
    b.step("probe", "Install the adversarial reference sandbox executable").dependOn(&install_probe.step);
    build_test_step.dependOn(&probe.step);
    services.addFileArg(b.path("tests/runner/launch.py"));
    services.addFileArg(b.path("tests/interfaces/native/service.py"));
    const unified_codec_test = b.addSystemCommand(&.{ "python3", "-B" });
    unified_codec_test.addFileArg(b.path("tests/runner/launch.py"));
    unified_codec_test.addFileArg(b.path("tests/query/unified/unified_codec.py"));
    unified_codec_test.addArtifactArg(station_host);
    unified_codec_test.addArtifactArg(station_bindings.artifact("transit_station"));
    unified_codec_test.has_side_effects = true;
    unified_codec_test.stdio = .inherit;
    b.step("test-unified-codec", "Qualify unified source and Arrow values through native and port boundaries").dependOn(&unified_codec_test.step);
    fixtures_step.dependOn(&unified_codec_test.step);
    build_test_step.dependOn(&document_worker.step);
    const document_caller = b.addExecutable(.{ .name = "example-station-document", .root_module = b.createModule(.{ .root_source_file = b.path("examples/station-document/main.zig"), .target = target, .optimize = optimize, .imports = &.{.{ .name = "transit_station_document", .module = exampleModule(b, sdk, "transit_station_document", target, optimize) }} }) });
    const install_document_caller = b.addInstallArtifact(document_caller, .{});
    b.getInstallStep().dependOn(&install_document_caller.step);
    build_test_step.dependOn(&document_caller.step);
    b.step("example-station-document", "Install the collaborative Document caller").dependOn(&install_document_caller.step);
    build_test_step.dependOn(&grpc_worker.step);
    build_test_step.dependOn(&http_worker.step);
    const http_caller = b.addExecutable(.{ .name = "example-station-http", .root_module = b.createModule(.{ .root_source_file = b.path("examples/station-http/main.zig"), .target = target, .optimize = optimize, .imports = &.{.{ .name = "transit_station_http", .module = exampleModule(b, sdk, "transit_station_http", target, optimize) }} }) });
    const install_http_caller = b.addInstallArtifact(http_caller, .{});
    b.getInstallStep().dependOn(&install_http_caller.step);
    build_test_step.dependOn(&http_caller.step);
    b.step("example-station-http", "Install the finite HTTP caller example").dependOn(&install_http_caller.step);
    build_test_step.dependOn(&grpc_bindings.step);
    const grpc_generated = b.addExecutable(.{ .name = "transit-grpc-generated-proof", .root_module = b.createModule(.{ .root_source_file = b.path("tests/interfaces/grpc/grpc_generated.zig"), .target = target, .optimize = optimize, .imports = &.{ .{ .name = "transit_station_grpc", .module = station_grpc.module("transit_station_grpc") }, .{ .name = "fixture_fixtures_grpc_methods", .module = test_modules.get(.fixtures_grpc_methods) } } }) });
    grpc_generated.root_module.addAnonymousImport("grpc_descriptor", .{ .root_source_file = b.path("tests/fixtures/grpc/peer.pb") });
    const grpc_codegen_test = b.addSystemCommand(&.{ "python3", "-B" });
    grpc_codegen_test.addFileArg(b.path("tests/runner/launch.py"));
    grpc_codegen_test.addFileArg(b.path("tests/interfaces/grpc/grpc_codegen.py"));
    grpc_codegen_test.addArtifactArg(grpc_bindings);
    grpc_codegen_test.addArtifactArg(grpc_generated);
    grpc_codegen_test.has_side_effects = true;
    grpc_codegen_test.stdio = .inherit;
    b.step("test-grpc-codegen", "Qualify offline descriptor-generated RPC requests").dependOn(&grpc_codegen_test.step);
    const grpc_caller = b.addExecutable(.{ .name = "example-station-grpc", .root_module = b.createModule(.{ .root_source_file = b.path("examples/station-grpc/main.zig"), .target = target, .optimize = optimize, .imports = &.{.{ .name = "transit_station_grpc", .module = exampleModule(b, sdk, "transit_station_grpc", target, optimize) }} }) });
    const install_grpc_caller = b.addInstallArtifact(grpc_caller, .{});
    b.getInstallStep().dependOn(&install_grpc_caller.step);
    build_test_step.dependOn(&grpc_caller.step);
    b.step("example-station-grpc", "Install the finite RPC caller example").dependOn(&install_grpc_caller.step);
    const grpc_provision = b.addExecutable(.{ .name = "transit-grpc-worker-proof", .root_module = b.createModule(.{ .root_source_file = b.path("tests/runtime/effects/grpc_worker.zig"), .target = target, .optimize = optimize, .imports = &.{ .{ .name = "transit_station_grpc", .module = station_grpc.module("transit_station_grpc") }, .{ .name = "transit_station", .module = station.module("transit_station") }, .{ .name = "fixture_growing_support", .module = test_modules.get(.growing_support) } } }) });
    build_test_step.dependOn(&grpc_provision.step);
    const grpc_worker_test = b.addSystemCommand(&.{ "python3", "-B" });
    grpc_worker_test.addFileArg(b.path("tests/runner/launch.py"));
    grpc_worker_test.addFileArg(b.path("tests/runtime/effects/grpc_worker.py"));
    grpc_worker_test.addArtifactArg(node_artifact);
    grpc_worker_test.addArtifactArg(grpc_provision);
    grpc_worker_test.addArtifactArg(grpc_worker);
    const grpc_browser = b.option(bool, "grpc-board-browser", "Qualify captured RPC metadata in the browser") orelse false;
    const grpc_board = b.option(bool, "grpc-board", "Qualify Board RPC metadata against real captures") orelse false;
    if (grpc_browser or grpc_board) grpc_worker_test.addArtifactArg(board);
    if (grpc_browser) grpc_worker_test.addArg("browser");
    const grpc_faults = b.option(bool, "grpc-faults", "Run RPC authority and final-publication failure boundaries") orelse false;
    const grpc_control = b.option(bool, "grpc-control", "Run the isolated RPC work-cutoff and blocked-peer control proof") orelse false;
    if (grpc_control and (grpc_faults or grpc_browser or grpc_board)) @panic("Select one RPC proof profile");
    if (grpc_control) grpc_worker_test.addArg("control") else if (grpc_faults) grpc_worker_test.addArg("faults");
    grpc_worker_test.has_side_effects = true;
    grpc_worker_test.stdio = .inherit;
    b.step("test-grpc-worker", "Prove durable finite RPC capture and recovery").dependOn(&grpc_worker_test.step);
    const flight_outbound = b.addExecutable(.{ .name = "transit-flight-outbound-proof", .root_module = b.createModule(.{ .root_source_file = b.path("tests/interfaces/flight/flight_outbound.zig"), .target = target, .optimize = optimize, .imports = &.{.{ .name = "transit_station_flight", .module = station_flight.module("transit_station_flight") }} }) });
    build_test_step.dependOn(&flight_outbound.step);
    components_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = station_flight.module("transit_station_flight") })).step);
    const flight_outbound_test = b.addSystemCommand(&.{ "python3", "-B" });
    flight_outbound_test.addFileArg(b.path("tests/runner/launch.py"));
    flight_outbound_test.addFileArg(b.path("tests/interfaces/flight/flight_outbound.py"));
    for ([_]*std.Build.Step.Compile{ node_artifact, grpc_provision, grpc_worker, flight_outbound }) |artifact| flight_outbound_test.addArtifactArg(artifact);
    flight_outbound_test.has_side_effects = true;
    flight_outbound_test.stdio = .inherit;
    b.step("test-flight-outbound", "Qualify Flight recorded effects and network-free replay").dependOn(&flight_outbound_test.step);
    const http_provision = b.addExecutable(.{ .name = "transit-http-worker-proof", .root_module = b.createModule(.{ .root_source_file = b.path("tests/runtime/effects/http_worker.zig"), .target = target, .optimize = optimize, .imports = &.{ .{ .name = "transit_station_http", .module = station_http.module("transit_station_http") }, .{ .name = "transit_station", .module = station.module("transit_station") }, .{ .name = "fixture_growing_support", .module = test_modules.get(.growing_support) }, .{ .name = "fixture_http_caller", .module = test_modules.get(.http_caller) }, .{ .name = "fixture_http_registry", .module = test_modules.get(.http_registry) } } }) });
    build_test_step.dependOn(&http_provision.step);
    const http_worker_test = b.addSystemCommand(&.{ "python3", "-B" });
    http_worker_test.addFileArg(b.path("tests/runner/launch.py"));
    http_worker_test.addFileArg(b.path("tests/runtime/effects/http_worker.py"));
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
    const operation_module = b.createModule(.{
        .root_source_file = b.path("tests/interfaces/cli/operations/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .imports = &.{ .{ .name = "cli_support", .module = cli_support }, .{ .name = "transit_query", .module = query.module("transit_query") }, .{ .name = "transit_catalog", .module = catalog.module("transit_catalog") }, .{ .name = "fixture_operations_application", .module = test_modules.get(.operations_application) }, .{ .name = "fixture_operations_authorization", .module = test_modules.get(.operations_authorization) }, .{ .name = "fixture_operations_diagnostic", .module = test_modules.get(.operations_diagnostic) }, .{ .name = "fixture_operations_direct_authorization", .module = test_modules.get(.operations_direct_authorization) }, .{ .name = "fixture_operations_file_diagnostic", .module = test_modules.get(.operations_file_diagnostic) }, .{ .name = "fixture_operations_file_query", .module = test_modules.get(.operations_file_query) }, .{ .name = "fixture_operations_recovery_tests", .module = test_modules.get(.operations_recovery_tests) }, .{ .name = "fixture_operations_unified", .module = test_modules.get(.operations_unified) } },
    });
    const operations = b.addExecutable(.{ .name = "operation-fixture", .root_module = operation_module });
    // Only this explicit test target copies the helper; it never enters bin/.
    const operation_install = b.addInstallArtifact(operations, .{ .dest_dir = .{ .override = .{ .custom = "tests" } } });
    b.step("test-operation-fixture", "Build private native operation test helpers").dependOn(&operation_install.step);
    components_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = operation_module })).step);
    const lifecycle_module = b.createModule(.{ .root_source_file = b.path("apps/transit-cli/LifecycleTests.zig"), .target = target, .optimize = optimize, .link_libc = true, .imports = &.{
        .{ .name = "transit_sql_service", .module = sql_gateway.module("transit_sql_service") },
        .{ .name = "transit_sql_client", .module = sql_client.module("transit_sql_client") },
        .{ .name = "transit_tls_server", .module = tls_server.module("transit_tls_server") },
        .{ .name = "transit_query", .module = query.module("transit_query") },
        .{ .name = "transit_catalog", .module = catalog.module("transit_catalog") },
        .{ .name = "transit_http_server", .module = http_server.module("transit_http_server") },
        .{ .name = "transit_serving_http", .module = serving_http.module("transit_serving_http") },
    } });
    lifecycle_module.linkSystemLibrary("crypto", .{ .use_pkg_config = .force, .preferred_link_mode = if (target.result.abi.isMusl()) .static else .dynamic });
    const lifecycle_test = b.addRunArtifact(b.addTest(.{ .root_module = lifecycle_module }));
    faults_step.dependOn(&lifecycle_test.step);
    b.step("test-cli-lifecycle", "Prove console recovery and bounded local process mechanics").dependOn(&lifecycle_test.step);
    const diagnostics_test = b.addSystemCommand(&.{ "python3", "-B" });
    diagnostics_test.addFileArg(b.path("tests/runner/launch.py"));
    diagnostics_test.addFileArg(b.path("tests/interfaces/cli/cli_diagnostics.py"));
    diagnostics_test.addArtifactArg(transit_cli);
    diagnostics_test.has_side_effects = true;
    diagnostics_test.stdio = .inherit;
    b.step("test-cli-diagnostics", "Check CLI failure coordinates, next steps and output privacy").dependOn(&diagnostics_test.step);
    const operation_diagnostics = b.addSystemCommand(&.{ "python3", "-B" });
    operation_diagnostics.addFileArg(b.path("tests/runner/launch.py"));
    operation_diagnostics.addFileArg(b.path("tests/interfaces/cli/operation_diagnostics.py"));
    operation_diagnostics.addArtifactArg(operations);
    operation_diagnostics.has_side_effects = true;
    operation_diagnostics.stdio = .inherit;
    b.step("test-operation-diagnostics", "Check native helper artifacts and file failure evidence").dependOn(&operation_diagnostics.step);
    diagnostics_test.step.dependOn(&operation_diagnostics.step);
    const console_input_gate = b.addLibrary(.{ .name = "transit-console-input-gate", .linkage = .dynamic, .root_module = b.createModule(.{ .target = target, .optimize = optimize, .link_libc = true }) });
    console_input_gate.root_module.addCSourceFile(.{ .file = b.path("tests/interfaces/cli/console_input_gate.c"), .flags = &.{ "-std=c11", "-Wall", "-Wextra", "-Werror" } });
    const history_test = b.addSystemCommand(&.{ "python3", "-B" });
    history_test.addFileArg(b.path("tests/runner/launch.py"));
    history_test.addFileArg(b.path("tests/interfaces/cli/console_history.py"));
    history_test.addArtifactArg(transit_cli);
    history_test.addArtifactArg(console_input_gate);
    history_test.has_side_effects = true;
    history_test.stdio = .inherit;
    b.step("test-console-history", "Check real terminal history, persistence and external editing").dependOn(&history_test.step);
    const console_editor = b.createModule(.{
        .root_source_file = b.path("apps/transit-cli/EditorState.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "transit_query", .module = query.module("transit_query") }},
    });
    const console_trace = b.addExecutable(.{ .name = "console-state-trace", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/verification/models/console_state.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "console_editor", .module = console_editor }},
    }) });
    const console_model = b.addSystemCommand(&.{ "python3", "-B" });
    console_model.addFileArg(b.path("tests/runner/launch.py"));
    console_model.addFileArg(b.path("tests/verification/models/console_model.py"));
    console_model.addArtifactArg(console_trace);
    console_model.has_side_effects = true;
    console_model.stdio = .inherit;
    console_model.addPassthruArgs();
    b.step("test-console-model", "Check the console model and replay transitions against its Zig owner").dependOn(&console_model.step);
    const write_lifecycle_trace = b.addExecutable(.{ .name = "write-lifecycle-state-trace", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/verification/models/write_lifecycle_state.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{ .{ .name = "transit_catalog", .module = catalog.module("transit_catalog") }, .{ .name = "transit_storage", .module = storage.module("transit_storage") }, .{ .name = "transit_fuze", .module = fuze.module("transit_fuze") }, .{ .name = "transit_protocol", .module = b.dependency("transit_protocol", .{ .target = target, .optimize = optimize }).module("transit_protocol") } },
    }) });
    const write_lifecycle_model = b.addSystemCommand(&.{ "python3", "-B" });
    write_lifecycle_model.addFileArg(b.path("tests/runner/launch.py"));
    write_lifecycle_model.addFileArg(b.path("tests/verification/models/write_lifecycle_model.py"));
    write_lifecycle_model.addArtifactArg(write_lifecycle_trace);
    write_lifecycle_model.has_side_effects = true;
    write_lifecycle_model.stdio = .inherit;
    write_lifecycle_model.addPassthruArgs();
    b.step("test-write-lifecycle-model", "Check SQL write models and replay selected Table counterexamples").dependOn(&write_lifecycle_model.step);
    const transaction_decision_trace = b.addExecutable(.{ .name = "transaction-decision-state-trace", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/verification/models/transaction_decision_state.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{ .{ .name = "transit_storage", .module = storage.module("transit_storage") }, .{ .name = "transit_protocol", .module = b.dependency("transit_protocol", .{ .target = target, .optimize = optimize }).module("transit_protocol") } },
    }) });
    const transaction_decision_model = b.addSystemCommand(&.{ "python3", "-B" });
    transaction_decision_model.addFileArg(b.path("tests/runner/launch.py"));
    transaction_decision_model.addFileArg(b.path("tests/verification/models/transaction_decision_model.py"));
    transaction_decision_model.addArtifactArg(transaction_decision_trace);
    transaction_decision_model.has_side_effects = true;
    transaction_decision_model.stdio = .inherit;
    transaction_decision_model.addPassthruArgs();
    b.step("test-transaction-decision-model", "Check transaction decision model and replay counterexamples against Zig").dependOn(&transaction_decision_model.step);
    const transaction_workspace_trace = b.addExecutable(.{ .name = "transaction-workspace-state-trace", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/verification/models/transaction_workspace_state.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "transit_catalog", .module = catalog.module("transit_catalog") }},
    }) });
    const transaction_workspace_model = b.addSystemCommand(&.{ "python3", "-B" });
    transaction_workspace_model.addFileArg(b.path("tests/runner/launch.py"));
    transaction_workspace_model.addFileArg(b.path("tests/verification/models/transaction_workspace_model.py"));
    transaction_workspace_model.addArtifactArg(transaction_workspace_trace);
    transaction_workspace_model.has_side_effects = true;
    transaction_workspace_model.stdio = .inherit;
    transaction_workspace_model.addPassthruArgs();
    b.step("test-transaction-workspace-model", "Check catalog transaction workspace model and replay counterexamples against Zig").dependOn(&transaction_workspace_model.step);
    const storage_lifecycle_trace = b.addExecutable(.{ .name = "storage-lifecycle-state-trace", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/verification/models/storage_lifecycle_state.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "transit_catalog", .module = catalog.module("transit_catalog") }},
    }) });
    const storage_lifecycle_model = b.addSystemCommand(&.{ "python3", "-B" });
    storage_lifecycle_model.addFileArg(b.path("tests/runner/launch.py"));
    storage_lifecycle_model.addFileArg(b.path("tests/verification/models/storage_lifecycle_model.py"));
    storage_lifecycle_model.addArtifactArg(storage_lifecycle_trace);
    storage_lifecycle_model.has_side_effects = true;
    storage_lifecycle_model.stdio = .inherit;
    storage_lifecycle_model.addPassthruArgs();
    b.step("test-storage-lifecycle-model", "Check storage lifecycle model and replay counterexamples against Zig").dependOn(&storage_lifecycle_model.step);
    const resident_owner_cache_trace = b.addExecutable(.{ .name = "resident-owner-cache-state-trace", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/verification/models/resident_owner_cache_state.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "transit_catalog", .module = catalog.module("transit_catalog") }},
    }) });
    const resident_owner_cache_model = b.addSystemCommand(&.{ "python3", "-B" });
    resident_owner_cache_model.addFileArg(b.path("tests/runner/launch.py"));
    resident_owner_cache_model.addFileArg(b.path("tests/verification/models/resident_owner_cache_model.py"));
    resident_owner_cache_model.addArtifactArg(resident_owner_cache_trace);
    resident_owner_cache_model.has_side_effects = true;
    resident_owner_cache_model.stdio = .inherit;
    resident_owner_cache_model.addPassthruArgs();
    b.step("test-resident-owner-cache-model", "Check resident owner and ReadCache model and replay counterexamples against Zig").dependOn(&resident_owner_cache_model.step);
    const statement_result_trace = b.addExecutable(.{ .name = "statement-result-state-trace", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/verification/models/statement_result_state.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "transit_sql_client", .module = sql_client.module("transit_sql_client") }},
    }) });
    const statement_result_model = b.addSystemCommand(&.{ "python3", "-B" });
    statement_result_model.addFileArg(b.path("tests/runner/launch.py"));
    statement_result_model.addFileArg(b.path("tests/verification/models/statement_result_model.py"));
    statement_result_model.addArtifactArg(statement_result_trace);
    statement_result_model.has_side_effects = true;
    statement_result_model.stdio = .inherit;
    statement_result_model.addPassthruArgs();
    b.step("test-statement-result-model", "Check SQL result models and replay every Progress edge against Zig").dependOn(&statement_result_model.step);
    const file_query_test = b.addSystemCommand(&.{ "python3", "-B" });
    file_query_test.addFileArg(b.path("tests/runner/launch.py"));
    file_query_test.addFileArg(b.path("tests/query/files/fuze_file_query.py"));
    file_query_test.addArtifactArg(operations);
    file_query_test.has_side_effects = true;
    file_query_test.stdio = .inherit;
    b.step("test-file-query", "Prove captured CSV/JSONL queries, gzip, quotas and cancellation").dependOn(&file_query_test.step);
    const logical_arrow_proof = b.addExecutable(.{ .name = "transit-logical-arrow-proof", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/query/arrow/fuze_logical_arrow.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "transit_fuze", .module = fuze.module("transit_fuze") }},
    }) });
    b.step("logical-arrow-proof", "Install the canonical logical Arrow fixture producer").dependOn(&b.addInstallArtifact(logical_arrow_proof, .{}).step);
    unified_codec_test.addArtifactArg(logical_arrow_proof);
    const logical_arrow_test = b.addSystemCommand(&.{ "python3", "-B" });
    logical_arrow_test.addFileArg(b.path("tests/runner/launch.py"));
    logical_arrow_test.addFileArg(b.path("tests/query/arrow/fuze_logical_arrow.py"));
    logical_arrow_test.addArtifactArg(operations);
    logical_arrow_test.addArtifactArg(logical_arrow_proof);
    logical_arrow_test.has_side_effects = true;
    logical_arrow_test.stdio = .inherit;
    b.step("test-logical-arrow", "Independently check logical type/state Arrow export").dependOn(&logical_arrow_test.step);
    const server_test = b.addSystemCommand(&.{ "python3", "-B" });
    server_test.addFileArg(b.path("tests/runner/launch.py"));
    server_test.addFileArg(b.path("tests/interfaces/installation/server.py"));
    server_test.step.dependOn(&operation_install.step);
    server_test.has_side_effects = true;
    server_test.step.dependOn(&lifecycle_test.step);
    server_test.stdio = .inherit;
    b.step("test-server", "Qualify local server bootstrap, gateway and owned process recovery").dependOn(&server_test.step);
    const direct_server_test = b.addSystemCommand(&.{ "python3", "-B" });
    direct_server_test.addFileArg(b.path("tests/runner/launch.py"));
    direct_server_test.addFileArg(b.path("tests/interfaces/installation/server_direct_tables.py"));
    for ([_]*std.Build.Step.Compile{ transit_cli, node_artifact, query_host, board, sql_gateway_app }) |artifact| direct_server_test.addArtifactArg(artifact);
    direct_server_test.has_side_effects = true;
    direct_server_test.stdio = .inherit;
    b.step("test-server-direct-tables", "Prove installed SQL uses the direct Table owner and exact bootstrap recovery").dependOn(&direct_server_test.step);
    const single_server_test = b.addSystemCommand(&.{ "python3", "-B" });
    single_server_test.addFileArg(b.path("tests/runner/launch.py"));
    single_server_test.addFileArg(b.path("tests/interfaces/installation/server_board_package.py"));
    single_server_test.addArtifactArg(transit_cli);
    single_server_test.has_side_effects = true;
    single_server_test.stdio = .inherit;
    b.step("test-server-single-executable", "Prove default server, console and Board from one copied executable").dependOn(&single_server_test.step);
    const migrate_lifecycle_test = b.addSystemCommand(&.{ "python3", "-B" });
    migrate_lifecycle_test.addFileArg(b.path("tests/runner/launch.py"));
    migrate_lifecycle_test.addFileArg(b.path("tests/interfaces/cli/migrate_lifecycle.py"));
    migrate_lifecycle_test.addArtifactArg(transit_cli);
    migrate_lifecycle_test.has_side_effects = true;
    migrate_lifecycle_test.stdio = .inherit;
    b.step("test-migrate-lifecycle", "Qualify reviewable, resumable application schema and data migrations").dependOn(&migrate_lifecycle_test.step);
    const browser_fault_host = b.createModule(.{
        .root_source_file = b.path("tests/interfaces/http/browser_fault_host.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "serving_http", .module = serving_http.module("transit_serving_http") }},
    });
    const browser_fault_module = b.createModule(.{ .root_source_file = b.path("apps/transit-node/main.zig"), .target = target, .optimize = optimize, .link_libc = true });
    // Keep Debug fixture DWARF outside the installation's executable-byte cap.
    // Runtime assertions and the selected optimization mode remain unchanged.
    browser_fault_module.strip = true;
    var browser_imports = node_artifact.root_module.import_table.iterator();
    while (browser_imports.next()) |entry| browser_fault_module.addImport(entry.key_ptr.*, if (std.mem.eql(u8, entry.key_ptr.*, "transit_serving_http")) browser_fault_host else entry.value_ptr.*);
    const browser_fault_node = b.addExecutable(.{ .name = "transit-node-browser-fixture", .root_module = browser_fault_module });
    b.step("browser-fault-fixture", "Build browser buffered-read fault boundary").dependOn(&b.addInstallArtifact(browser_fault_node, .{}).step);
    const browser_test = b.addSystemCommand(&.{ "python3", "-B" });
    browser_test.addFileArg(b.path("tests/runner/launch.py"));
    browser_test.addFileArg(b.path("tests/interfaces/http/declarative_browser.py"));
    for ([_]*std.Build.Step.Compile{ transit_cli, cli_artifact, browser_fault_node }) |artifact| browser_test.addArtifactArg(artifact);
    browser_test.has_side_effects = true;
    browser_test.stdio = .inherit;
    b.step("test-declarative-browser", "Qualify durable browser sessions, provider exchanges and native publications").dependOn(&browser_test.step);
    // Same production node, with only the SQL host import decorated by a
    // test-owned typed-boundary fault injector. No fault switch ships at runtime.
    const fault_host = b.createModule(.{
        .root_source_file = b.path("tests/interfaces/installation/sql_fault_host.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{ .{ .name = "sql_host", .module = node_artifact.root_module.import_table.get("transit_sql_host").? }, .{ .name = "transit_sql_service", .module = sql_gateway.module("transit_sql_service") } },
    });
    const fault_node_module = b.createModule(.{ .root_source_file = b.path("apps/transit-node/main.zig"), .target = target, .optimize = optimize, .link_libc = true });
    var node_imports = node_artifact.root_module.import_table.iterator();
    while (node_imports.next()) |entry| fault_node_module.addImport(entry.key_ptr.*, if (std.mem.eql(u8, entry.key_ptr.*, "transit_sql_host")) fault_host else entry.value_ptr.*);
    const fault_node = b.addExecutable(.{ .name = "transit-node-fault-fixture", .root_module = fault_node_module });
    // The lifecycle proof also withholds accepted direct execution to exercise
    // native-session reply loss; co-hosted calls bypass its HTTP proxy.
    for ([_]*std.Build.Step.Compile{ transit_cli, fault_node, query_host, board, sql_gateway_app }) |artifact| server_test.addArtifactArg(artifact);
    if (b.option(bool, "server-faults", "Qualify interrupted bootstrap, gateway pressure and provider rollback") orelse false) server_test.addArg("--faults");
    const direct_fault_test = b.addSystemCommand(&.{ "python3", "-B" });
    direct_fault_test.addFileArg(b.path("tests/runner/launch.py"));
    direct_fault_test.addFileArg(b.path("tests/interfaces/installation/server_direct_faults.py"));
    for ([_]*std.Build.Step.Compile{ transit_cli, fault_node, query_host, board, sql_gateway_app }) |artifact| direct_fault_test.addArtifactArg(artifact);
    direct_fault_test.has_side_effects = true;
    direct_fault_test.stdio = .inherit;
    b.step("test-server-direct-faults", "Prove installed direct Table recovery and control during data-owner failures").dependOn(&direct_fault_test.step);
    const logging_test = b.addSystemCommand(&.{ "python3", "-B" });
    logging_test.addFileArg(b.path("tests/runner/launch.py"));
    logging_test.addFileArg(b.path("tests/interfaces/installation/server_logging.py"));
    for ([_]*std.Build.Step.Compile{ transit_cli, node_artifact, query_host, board, sql_gateway_app }) |artifact| logging_test.addArtifactArg(artifact);
    logging_test.step.dependOn(&operation_install.step);
    logging_test.has_side_effects = true;
    logging_test.stdio = .inherit;
    b.step("test-server-logging", "Qualify terminal and machine logs across local services").dependOn(&logging_test.step);
    const lifetime_test = b.addSystemCommand(&.{ "python3", "-B" });
    lifetime_test.addFileArg(b.path("tests/runner/launch.py"));
    lifetime_test.addFileArg(b.path("tests/interfaces/installation/server_sql_lifetimes.py"));
    for ([_]*std.Build.Step.Compile{ transit_cli, node_artifact, query_host, board, sql_gateway_app }) |artifact| lifetime_test.addArtifactArg(artifact);
    lifetime_test.step.dependOn(&operation_install.step);
    lifetime_test.has_side_effects = true;
    lifetime_test.stdio = .inherit;
    b.step("test-server-sql-lifetimes", "Qualify idle SQL connections, native leases and partial frame deadlines").dependOn(&lifetime_test.step);
    inline for (.{ .{ "test-server-sql", "tests/interfaces/installation/server_sql.py" }, .{ "test-server-sql-faults", "tests/interfaces/installation/server_sql_faults.py" }, .{ "test-server-sql-local", "tests/interfaces/installation/server_sql_local.py" } }) |proof| {
        const run = b.addSystemCommand(&.{ "python3", "-B" });
        run.addFileArg(b.path("tests/runner/launch.py"));
        run.addFileArg(b.path(proof[1]));
        if (comptime std.mem.eql(u8, proof[0], "test-server-sql-local")) {
            // Exercise the default installation users run from zig-out/bin,
            // including built-in runtime roles from that one installed artifact.
            run.addArg("--source-install");
            run.addDirectoryArg2(.{ .relative = .{ .base = .install_prefix } }, .{});
            run.step.dependOn(b.getInstallStep());
        } else {
            for ([_]*std.Build.Step.Compile{ transit_cli, if (comptime std.mem.eql(u8, proof[0], "test-server-sql")) fault_node else node_artifact, query_host, board, sql_gateway_app }) |artifact| run.addArtifactArg(artifact);
        }
        run.step.dependOn(&operation_install.step);
        run.has_side_effects = true;
        run.stdio = .inherit;
        b.step(proof[0], "Qualify configured local SQL enrollment, clients and retained recovery").dependOn(&run.step);
    }
    const serving_test = b.addSystemCommand(&.{ "python3", "-B" });
    serving_test.addFileArg(b.path("tests/runner/launch.py"));
    serving_test.addFileArg(b.path("tests/interfaces/http/serving.py"));
    for ([_]*std.Build.Step.Compile{ node_artifact, serving_example, query_host, station_host }) |artifact| serving_test.addArtifactArg(artifact);
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
        .root_source_file = b.path("tests/query/execution/public_query.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{ .{ .name = "transit_serving", .module = serving.module("transit_serving") }, .{ .name = "transit_query", .module = query.module("transit_query") }, .{ .name = "transit_station", .module = station.module("transit_station") }, .{ .name = "fixture_growing_support", .module = test_modules.get(.growing_support) }, .{ .name = "fixture_public_query_catalog", .module = test_modules.get(.public_query_catalog) }, .{ .name = "fixture_table_authorization_support", .module = test_modules.get(.table_authorization_support) } },
    }) });
    b.step("public-query-proof", "Install the public query provisioning proof").dependOn(&b.addInstallArtifact(public_query, .{}).step);
    build_test_step.dependOn(&public_query.step);
    build_test_step.dependOn(&flight_gateway.step);
    build_test_step.dependOn(&sql_gateway_app.step);
    components_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = sql_gateway_app.root_module })).step);
    components_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = node_artifact.root_module.import_table.get("transit_sql_host").? })).step);
    const flight_test = b.addSystemCommand(&.{ "python3", "-B" });
    if (b.option([]const u8, "flight-placement", "Run Flight in compose or reference placement")) |profile| {
        flight_test.addFileArg(b.path("examples/flight/run.py"));
        flight_test.addArg(profile);
    } else flight_test.addFileArg(b.path("tests/interfaces/flight/flight.py"));
    for ([_]*std.Build.Step.Compile{ node_artifact, query_host, flight_gateway, public_query }) |artifact| flight_test.addArtifactArg(artifact);
    if (b.option(bool, "flight-faults", "Qualify Flight authority, retry and physical recovery boundaries") orelse false) {
        flight_test.addArg("faults");
        flight_test.addArtifactArg(board);
    }
    flight_test.has_side_effects = true;
    flight_test.stdio = .inherit;
    b.step("test-flight", "Qualify real finite queries with independent Flight and ADBC clients").dependOn(&flight_test.step);
    const public_query_test = b.addSystemCommand(&.{ "python3", "-B" });
    public_query_test.addFileArg(b.path("tests/runner/launch.py"));
    public_query_test.addFileArg(b.path("tests/query/execution/public_query.py"));
    for ([_]*std.Build.Step.Compile{ node_artifact, query_host, operations, public_query }) |artifact| public_query_test.addArtifactArg(artifact);
    public_query_test.has_side_effects = true;
    public_query_test.stdio = .inherit;
    b.step("test-public-query", "Qualify public query hosts and native callers over local direct Tables").dependOn(&public_query_test.step);
    const unified_query = b.addExecutable(.{ .name = "transit-unified-query-proof", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/query/unified/unified_query.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{ .{ .name = "transit_query", .module = query.module("transit_query") }, .{ .name = "transit_station", .module = station.module("transit_station") }, .{ .name = "fixture_catalog_query_support", .module = test_modules.get(.catalog_query_support) }, .{ .name = "fixture_growing_support", .module = test_modules.get(.growing_support) }, .{ .name = "fixture_table_query_writer_support", .module = test_modules.get(.table_query_writer_support) } },
    }) });
    const query_example = b.addExecutable(.{ .name = "example-state-query", .root_module = b.createModule(.{
        .root_source_file = b.path("examples/state-query/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "transit_query", .module = exampleModule(b, sdk, "transit_query", target, optimize) }},
    }) });
    const install_query_example = b.addInstallArtifact(query_example, .{});
    build_test_step.dependOn(&query_example.step);
    b.step("example-state-query", "Install the finite SQL recovery example").dependOn(&install_query_example.step);
    b.step("unified-query-proof", "Install the unified query provisioning proof").dependOn(&b.addInstallArtifact(unified_query, .{}).step);
    build_test_step.dependOn(&unified_query.step);
    const unified_query_test = b.addSystemCommand(&.{ "python3", "-B" });
    unified_query_test.addFileArg(b.path("tests/runner/launch.py"));
    unified_query_test.addFileArg(b.path("tests/query/unified/unified_query.py"));
    for ([_]*std.Build.Step.Compile{ node_artifact, query_host, unified_query, station_host, station_bindings.artifact("transit_station") }) |artifact| unified_query_test.addArtifactArg(artifact);
    if (b.option(bool, "unified-example", "Run the finite SQL example and recover its original intent") orelse false) {
        unified_query_test.addArg("--example");
        unified_query_test.addArtifactArg(query_example);
    }
    if (b.option(bool, "unified-shell", "Include the native query test driver in unified recovery") orelse false) {
        unified_query_test.addArg("--shell");
        unified_query_test.addArtifactArg(operations);
    }
    if (b.option(bool, "unified-compound", "Recover a filtering Boolean program across installed callers") orelse false) unified_query_test.addArg("--compound");
    if (b.option(bool, "unified-board", "Include Board's v1 query API in unified recovery") orelse false) {
        unified_query_test.addArg("--board");
        unified_query_test.addArtifactArg(board);
    }
    if (b.option(bool, "unified-browser", "Include the actual v1 Board workspace in unified recovery") orelse false) unified_query_test.addArg("--browser");
    if (b.option(bool, "unified-expiry", "Qualify real finite request expiry across source kinds") orelse false) unified_query_test.addArg("--expiry");
    if (b.option(bool, "unified-lifecycle", "Qualify current grants and cancellation during staged v1 capture") orelse false) unified_query_test.addArg("--lifecycle");
    if (b.option(bool, "unified-counts", "Qualify partial COUNT progress through disk recovery, denial and cancellation") orelse false) unified_query_test.addArg("--counts");
    if (b.option([]const u8, "unified-source", "Limit unified query proof to kv, table or document")) |kind| unified_query_test.addArg(kind);
    if (b.option([]const u8, "unified-sdk", "Comma-separated installed SDKs for unified query recovery")) |languages| {
        var selected = std.mem.splitScalar(u8, languages, ',');
        while (selected.next()) |language| unified_query_test.addArgs(&.{ "--sdk", language });
    }
    unified_query_test.has_side_effects = true;
    unified_query_test.stdio = .inherit;
    b.step("test-unified-query", "Qualify unified query daemons over disk Ursula").dependOn(&unified_query_test.step);
    const query_board_test = b.addSystemCommand(&.{ "python3", "-B" });
    query_board_test.addFileArg(b.path("tests/runner/launch.py"));
    query_board_test.addFileArg(b.path("tests/interfaces/board/board_query.py"));
    for ([_]*std.Build.Step.Compile{ node_artifact, query_host, public_query, board }) |artifact| query_board_test.addArtifactArg(artifact);
    if (b.option(bool, "query-browser", "Include the public query browser proof") orelse false) query_board_test.addArg("--browser");
    query_board_test.has_side_effects = true;
    query_board_test.stdio = .inherit;
    b.step("test-board-query", "Qualify growing Board inspection and its optional query capability").dependOn(&query_board_test.step);
    const growing_client = b.addExecutable(.{ .name = "transit-growing-client-proof", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/interfaces/native/growing_client.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "transit_client", .module = client.module("transit_client") }},
    }) });
    const growing_service = b.addSystemCommand(&.{ "python3", "-B" });
    const node_recovery = b.addSystemCommand(&.{ "python3", "-B" });
    node_recovery.addFileArg(b.path("tests/runner/launch.py"));
    node_recovery.addFileArg(b.path("tests/storage/providers/node_recovery.py"));
    node_recovery.addArtifactArg(node_artifact);
    node_recovery.addArtifactArg(growing_client);
    node_recovery.has_side_effects = true;
    node_recovery.stdio = .inherit;
    b.step("test-node-recovery", "Qualify read-only retained startup through transient storage faults").dependOn(&node_recovery.step);
    const node_concurrency_fixtures = b.addExecutable(.{ .name = "transit-node-concurrency-fixtures", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/storage/providers/node_concurrency.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "transit_client", .module = client.module("transit_client") }},
    }) });
    const node_concurrency = b.addSystemCommand(&.{ "python3", "-B" });
    node_concurrency.addFileArg(b.path("tests/runner/launch.py"));
    node_concurrency.addFileArg(b.path("tests/storage/providers/node_concurrency.py"));
    node_concurrency.addArtifactArg(node_artifact);
    node_concurrency.addArtifactArg(node_concurrency_fixtures);
    node_concurrency.has_side_effects = true;
    node_concurrency.stdio = .inherit;
    b.step("test-node-concurrency", "Qualify independent native I/O, publication races and revocation").dependOn(&node_concurrency.step);
    const native_blocks = b.addSystemCommand(&.{ "python3", "-B" });
    native_blocks.addFileArg(b.path("tests/runner/launch.py"));
    native_blocks.addFileArg(b.path("tests/storage/providers/block_native.py"));
    native_blocks.addArtifactArg(node_artifact);
    native_blocks.has_side_effects = true;
    native_blocks.stdio = .inherit;
    b.step("test-native-blocks", "Qualify atomic native bulk publication and current-authorized retained reads").dependOn(&native_blocks.step);
    growing_service.addFileArg(b.path("tests/runner/launch.py"));
    growing_service.addFileArg(b.path("tests/interfaces/native/growing_service.py"));
    growing_service.addArtifactArg(node_artifact);
    growing_service.addArtifactArg(growing_client);
    const growing_station = b.addExecutable(.{ .name = "transit-growing-station-proof", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/runtime/application/growing_station.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{ .{ .name = "transit_station", .module = station.module("transit_station") }, .{ .name = "fixture_growing_support", .module = test_modules.get(.growing_support) }, .{ .name = "fixture_growing_views", .module = test_modules.get(.growing_views) } },
    }) });
    growing_service.addArtifactArg(growing_station);
    const growing_query = b.addExecutable(.{ .name = "transit-query-proof", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/query/execution/growing_query.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{ .{ .name = "transit_station", .module = station.module("transit_station") }, .{ .name = "fixture_growing_support", .module = test_modules.get(.growing_support) } },
    }) });
    growing_service.addArtifactArg(growing_query);
    const growing_quota = b.addExecutable(.{ .name = "transit-growing-quota-proof", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/runtime/station/growing_quota.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{ .{ .name = "transit_station", .module = station.module("transit_station") }, .{ .name = "fixture_growing_support", .module = test_modules.get(.growing_support) } },
    }) });
    growing_service.addArtifactArg(growing_quota);
    const growing_build = b.step("test-growing-service-build", "Compile growing service proof binaries without executing scenarios");
    for ([_]*std.Build.Step.Compile{ node_artifact, growing_client, growing_station, growing_query, growing_quota }) |artifact| growing_build.dependOn(&artifact.step);
    growing_service.has_side_effects = true;
    growing_service.stdio = .inherit;
    b.step("test-growing-service", "Prove the explicit growing node/client profile over signed HTTP").dependOn(&growing_service.step);
    const local_service = b.addSystemCommand(&.{ "python3", "-B" });
    local_service.addFileArg(b.path("tests/runner/launch.py"));
    local_service.addFileArg(b.path("tests/interfaces/native/growing_service.py"));
    local_service.addArg("--local");
    local_service.addArtifactArg(node_artifact);
    local_service.addArtifactArg(growing_client);
    local_service.has_side_effects = true;
    local_service.stdio = .inherit;
    b.step("test-local-native-service", "Prove the local native node with public signed callers and reply faults").dependOn(&local_service.step);
    const local_fault_node = b.addExecutable(.{ .name = "transit-local-owner-fault-node", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/storage/local/local_owner_fault_node.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .imports = &.{.{ .name = "transit_node", .module = node_artifact.root_module }},
    }) });
    const local_owner_recovery = b.addSystemCommand(&.{ "python3", "-B" });
    local_owner_recovery.addFileArg(b.path("tests/runner/launch.py"));
    local_owner_recovery.addFileArg(b.path("tests/storage/local/local_owner_recovery.py"));
    local_owner_recovery.addArtifactArg(local_fault_node);
    local_owner_recovery.has_side_effects = true;
    local_owner_recovery.stdio = .inherit;
    b.step("test-local-owner-recovery", "Resolve uncertain WAL writes by reopening the exclusive node owner").dependOn(&local_owner_recovery.step);
    const local_payload_service = b.addSystemCommand(&.{ "python3", "-B" });
    local_payload_service.addFileArg(b.path("tests/runner/launch.py"));
    local_payload_service.addFileArg(b.path("tests/storage/local/local_payload_service.py"));
    local_payload_service.addArtifactArg(node_artifact);
    local_payload_service.addArtifactArg(growing_client);
    local_payload_service.has_side_effects = true;
    local_payload_service.stdio = .inherit;
    b.step("test-local-payload-service", "Qualify authenticated local standalone payload lifecycle").dependOn(&local_payload_service.step);
    const direct_table_client = b.addExecutable(.{ .name = "transit-direct-table-proof", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/interfaces/native/direct_table_client.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{ .{ .name = "transit_data_client", .module = b.dependency("transit_data_client", .{ .target = target, .optimize = optimize }).module("transit_data_client") }, .{ .name = "transit_catalog", .module = catalog.module("transit_catalog") }, .{ .name = "transit_query", .module = query.module("transit_query") }, .{ .name = "transit_serving", .module = serving.module("transit_serving") }, .{ .name = "transit_sql_service", .module = sql_gateway.module("transit_sql_service") }, .{ .name = "transit_station_app", .module = application.module("transit_station_app") }, .{ .name = "fixture_direct_captured_query", .module = test_modules.get(.direct_captured_query) }, .{ .name = "fixture_direct_dependencies", .module = test_modules.get(.direct_dependencies) }, .{ .name = "fixture_direct_exchange_workers", .module = test_modules.get(.direct_exchange_workers) }, .{ .name = "fixture_direct_follow_query", .module = test_modules.get(.direct_follow_query) }, .{ .name = "fixture_direct_maintained_query", .module = test_modules.get(.direct_maintained_query) }, .{ .name = "fixture_direct_named_resources", .module = test_modules.get(.direct_named_resources) }, .{ .name = "fixture_direct_relational_capacity", .module = test_modules.get(.direct_relational_capacity) }, .{ .name = "fixture_direct_relational_exchanges", .module = test_modules.get(.direct_relational_exchanges) }, .{ .name = "fixture_direct_relational_failures", .module = test_modules.get(.direct_relational_failures) }, .{ .name = "fixture_direct_sql_conditions", .module = test_modules.get(.direct_sql_conditions) }, .{ .name = "fixture_direct_sql_read_recovery", .module = test_modules.get(.direct_sql_read_recovery) }, .{ .name = "fixture_direct_table_authorization", .module = test_modules.get(.direct_table_authorization) }, .{ .name = "fixture_direct_table_collations", .module = test_modules.get(.direct_table_collations) }, .{ .name = "fixture_direct_table_count_ranges", .module = test_modules.get(.direct_table_count_ranges) }, .{ .name = "fixture_direct_table_delegation", .module = test_modules.get(.direct_table_delegation) }, .{ .name = "fixture_direct_table_growth", .module = test_modules.get(.direct_table_growth) }, .{ .name = "fixture_direct_table_history", .module = test_modules.get(.direct_table_history) }, .{ .name = "fixture_direct_table_lifecycle", .module = test_modules.get(.direct_table_lifecycle) }, .{ .name = "fixture_direct_table_maintenance", .module = test_modules.get(.direct_table_maintenance) }, .{ .name = "fixture_direct_table_predicates", .module = test_modules.get(.direct_table_predicates) }, .{ .name = "fixture_direct_table_prepared", .module = test_modules.get(.direct_table_prepared) }, .{ .name = "fixture_direct_table_projection", .module = test_modules.get(.direct_table_projection) }, .{ .name = "fixture_direct_unified_boundaries", .module = test_modules.get(.direct_unified_boundaries) } },
    }) });
    direct_table_client.root_module.addImport("fixture_direct_queue", test_modules.get(.direct_queue));
    direct_table_client.root_module.addImport("fixture_direct_kv", test_modules.get(.direct_kv));
    direct_table_client.root_module.addImport("fixture_direct_state_transaction", test_modules.get(.direct_state_transaction));
    direct_table_client.root_module.addImport("fixture_direct_queue_transfer", test_modules.get(.direct_queue_transfer));
    direct_table_client.root_module.addImport("fixture_direct_log_token", test_modules.get(.direct_log_token));
    b.step("direct-table-proof", "Build the signed direct database proof caller").dependOn(&b.addInstallArtifact(direct_table_client, .{}).step);
    const direct_table_service = b.addSystemCommand(&.{ "python3", "-B" });
    direct_table_service.addFileArg(b.path("tests/runner/launch.py"));
    direct_table_service.addFileArg(b.path("tests/storage/tables/direct_table_service.py"));
    direct_table_service.addArtifactArg(node_artifact);
    direct_table_service.addArtifactArg(direct_table_client);
    direct_table_service.addPassthruArgs();
    direct_table_service.has_side_effects = true;
    direct_table_service.stdio = .inherit;
    b.step("test-direct-table-service", "Prove direct Table HTTP writes, snapshots and reply recovery over local disk").dependOn(&direct_table_service.step);
    const direct_kv = b.addSystemCommand(&.{ "python3", "-B" });
    direct_kv.addFileArg(b.path("tests/runner/launch.py"));
    direct_kv.addFileArg(b.path("tests/storage/tables/direct_table_service.py"));
    direct_kv.addArtifactArg(node_artifact);
    direct_kv.addArtifactArg(direct_table_client);
    direct_kv.addArg("kv");
    direct_kv.has_side_effects = true;
    direct_kv.stdio = .inherit;
    b.step("test-direct-kv", "Prove signed direct KV batches, pinned reads, current rights and original recovery over local disk").dependOn(&direct_kv.step);
    const direct_table_maintenance = b.addSystemCommand(&.{ "python3", "-B" });
    direct_table_maintenance.addFileArg(b.path("tests/runner/launch.py"));
    direct_table_maintenance.addFileArg(b.path("tests/storage/tables/direct_table_service.py"));
    direct_table_maintenance.addArtifactArg(node_artifact);
    direct_table_maintenance.addArtifactArg(direct_table_client);
    direct_table_maintenance.addArg("maintenance");
    direct_table_maintenance.has_side_effects = true;
    direct_table_maintenance.stdio = .inherit;
    const direct_stream_maintenance = b.addSystemCommand(&.{ "python3", "-B" });
    direct_stream_maintenance.addFileArg(b.path("tests/runner/launch.py"));
    direct_stream_maintenance.addFileArg(b.path("tests/storage/tables/direct_table_service.py"));
    direct_stream_maintenance.addArtifactArg(node_artifact);
    direct_stream_maintenance.addArtifactArg(direct_table_client);
    direct_stream_maintenance.addArg("stream-maintenance");
    direct_stream_maintenance.has_side_effects = true;
    direct_stream_maintenance.stdio = .inherit;
    // Keep the disk schedules sequential while sharing their built artifacts.
    direct_stream_maintenance.step.dependOn(&direct_table_maintenance.step);
    b.step("test-direct-table-maintenance", "Prove automatic Table and Stream maintenance, restart and retained pins on physical disk").dependOn(&direct_stream_maintenance.step);
    const direct_callers = b.addSystemCommand(&.{ "python3", "-B" });
    direct_callers.addFileArg(b.path("tests/runner/launch.py"));
    direct_callers.addFileArg(b.path("tests/storage/tables/direct_table_service.py"));
    direct_callers.addArtifactArg(node_artifact);
    direct_callers.addArtifactArg(direct_table_client);
    direct_callers.addArg("callers");
    direct_callers.has_side_effects = true;
    direct_callers.stdio = .inherit;
    b.step("test-direct-table-callers", "Prove shared SQL and typed host callers through the public Table owner").dependOn(&direct_callers.step);
    const direct_catalog_abi = b.addSystemCommand(&.{ "python3", "-B" });
    direct_catalog_abi.addFileArg(b.path("tests/runner/launch.py"));
    direct_catalog_abi.addFileArg(b.path("tests/storage/tables/direct_table_service.py"));
    direct_catalog_abi.addArtifactArg(node_artifact);
    direct_catalog_abi.addArtifactArg(direct_table_client);
    direct_catalog_abi.addArg("abi");
    direct_catalog_abi.addArtifactArg(station_bindings.artifact("transit_station"));
    direct_catalog_abi.addArtifactArg(station_host);
    direct_catalog_abi.has_side_effects = true;
    direct_catalog_abi.stdio = .inherit;
    b.step("test-direct-catalog-abi", "Prove direct catalog ABI and port recovery after accepted reply loss").dependOn(&direct_catalog_abi.step);
    const direct_catalog_python = b.addSystemCommand(&.{ "python3", "-B" });
    direct_catalog_python.addFileArg(b.path("tests/runner/launch.py"));
    direct_catalog_python.addFileArg(b.path("tests/storage/tables/direct_table_service.py"));
    if (sdk_authority) |node| {
        direct_catalog_python.addFileArg(.{ .cwd_relative = node });
    } else {
        direct_catalog_python.addArtifactArg(node_artifact);
    }
    direct_catalog_python.addArtifactArg(direct_table_client);
    direct_catalog_python.addArgs(&.{ "sdk-python", b.pathJoin(&.{ sdk_packages, "wheels" }) });
    direct_catalog_python.has_side_effects = true;
    direct_catalog_python.stdio = .inherit;
    b.step("test-direct-catalog-python", "Prove installed Python direct lifecycle and retained SQL recovery").dependOn(&direct_catalog_python.step);
    const direct_catalog_node = b.addSystemCommand(&.{ "python3", "-B" });
    direct_catalog_node.addFileArg(b.path("tests/runner/launch.py"));
    direct_catalog_node.addFileArg(b.path("tests/storage/tables/direct_table_service.py"));
    if (sdk_authority) |node| {
        direct_catalog_node.addFileArg(.{ .cwd_relative = node });
    } else {
        direct_catalog_node.addArtifactArg(node_artifact);
    }
    direct_catalog_node.addArtifactArg(direct_table_client);
    direct_catalog_node.addArgs(&.{ "sdk-node", b.pathJoin(&.{ sdk_packages, "node" }) });
    direct_catalog_node.has_side_effects = true;
    direct_catalog_node.stdio = .inherit;
    b.step("test-direct-catalog-node", "Prove installed Node direct lifecycle and retained SQL recovery").dependOn(&direct_catalog_node.step);
    const direct_catalog_ruby = b.addSystemCommand(&.{ "python3", "-B" });
    direct_catalog_ruby.addFileArg(b.path("tests/runner/launch.py"));
    direct_catalog_ruby.addFileArg(b.path("tests/storage/tables/direct_table_service.py"));
    if (sdk_authority) |node| {
        direct_catalog_ruby.addFileArg(.{ .cwd_relative = node });
    } else {
        direct_catalog_ruby.addArtifactArg(node_artifact);
    }
    direct_catalog_ruby.addArtifactArg(direct_table_client);
    direct_catalog_ruby.addArgs(&.{ "sdk-ruby", b.pathJoin(&.{ sdk_packages, "ruby" }) });
    direct_catalog_ruby.has_side_effects = true;
    direct_catalog_ruby.stdio = .inherit;
    b.step("test-direct-catalog-ruby", "Prove installed Ruby direct lifecycle and retained metadata recovery").dependOn(&direct_catalog_ruby.step);
    const direct_catalog_java = b.addSystemCommand(&.{ "python3", "-B" });
    direct_catalog_java.addFileArg(b.path("tests/runner/launch.py"));
    direct_catalog_java.addFileArg(b.path("tests/storage/tables/direct_table_service.py"));
    if (sdk_authority) |node| {
        direct_catalog_java.addFileArg(.{ .cwd_relative = node });
    } else {
        direct_catalog_java.addArtifactArg(node_artifact);
    }
    direct_catalog_java.addArtifactArg(direct_table_client);
    direct_catalog_java.addArgs(&.{ "sdk-java", b.pathJoin(&.{ sdk_packages, "java" }) });
    direct_catalog_java.has_side_effects = true;
    direct_catalog_java.stdio = .inherit;
    b.step("test-direct-catalog-java", "Prove installed Java direct lifecycle and retained metadata recovery").dependOn(&direct_catalog_java.step);
    const direct_catalog_dotnet = b.addSystemCommand(&.{ "python3", "-B" });
    direct_catalog_dotnet.addFileArg(b.path("tests/runner/launch.py"));
    direct_catalog_dotnet.addFileArg(b.path("tests/storage/tables/direct_table_service.py"));
    if (sdk_authority) |node| {
        direct_catalog_dotnet.addFileArg(.{ .cwd_relative = node });
    } else {
        direct_catalog_dotnet.addArtifactArg(node_artifact);
    }
    direct_catalog_dotnet.addArtifactArg(direct_table_client);
    direct_catalog_dotnet.addArgs(&.{ "sdk-dotnet", b.pathJoin(&.{ sdk_packages, "dotnet" }) });
    direct_catalog_dotnet.has_side_effects = true;
    direct_catalog_dotnet.stdio = .inherit;
    b.step("test-direct-catalog-dotnet", "Prove installed .NET direct lifecycle and retained metadata recovery").dependOn(&direct_catalog_dotnet.step);
    const direct_catalog_rust = b.addSystemCommand(&.{ "python3", "-B" });
    direct_catalog_rust.addFileArg(b.path("tests/runner/launch.py"));
    direct_catalog_rust.addFileArg(b.path("tests/storage/tables/direct_table_service.py"));
    if (sdk_authority) |node| {
        direct_catalog_rust.addFileArg(.{ .cwd_relative = node });
    } else {
        direct_catalog_rust.addArtifactArg(node_artifact);
    }
    direct_catalog_rust.addArtifactArg(direct_table_client);
    direct_catalog_rust.addArgs(&.{ "sdk-rust", b.pathJoin(&.{ sdk_packages, "rust" }) });
    direct_catalog_rust.has_side_effects = true;
    direct_catalog_rust.stdio = .inherit;
    b.step("test-direct-catalog-rust", "Prove installed Rust direct lifecycle and retained metadata recovery").dependOn(&direct_catalog_rust.step);
    const direct_catalog_beam = b.addSystemCommand(&.{ "python3", "-B" });
    direct_catalog_beam.addFileArg(b.path("tests/runner/launch.py"));
    direct_catalog_beam.addFileArg(b.path("tests/storage/tables/direct_table_service.py"));
    if (sdk_authority) |node| {
        direct_catalog_beam.addFileArg(.{ .cwd_relative = node });
    } else {
        direct_catalog_beam.addArtifactArg(node_artifact);
    }
    direct_catalog_beam.addArtifactArg(direct_table_client);
    direct_catalog_beam.addArgs(&.{ "sdk-beam", b.pathJoin(&.{ sdk_packages, "beam" }) });
    direct_catalog_beam.has_side_effects = true;
    direct_catalog_beam.stdio = .inherit;
    b.step("test-direct-catalog-beam", "Prove installed Erlang and Elixir direct lifecycle and retained metadata recovery").dependOn(&direct_catalog_beam.step);
    const direct_catalog_c = b.addSystemCommand(&.{ "python3", "-B" });
    direct_catalog_c.addFileArg(b.path("tests/runner/launch.py"));
    direct_catalog_c.addFileArg(b.path("tests/storage/tables/direct_table_service.py"));
    if (sdk_authority) |node| {
        direct_catalog_c.addFileArg(.{ .cwd_relative = node });
    } else {
        direct_catalog_c.addArtifactArg(node_artifact);
    }
    direct_catalog_c.addArtifactArg(direct_table_client);
    direct_catalog_c.addArgs(&.{ "sdk-c", b.pathJoin(&.{ sdk_packages, "c" }) });
    direct_catalog_c.has_side_effects = true;
    direct_catalog_c.stdio = .inherit;
    b.step("test-direct-catalog-c", "Prove installed C and C++ direct lifecycle and retained metadata recovery").dependOn(&direct_catalog_c.step);

    const direct_board = b.addSystemCommand(&.{ "python3", "-B" });
    direct_board.addFileArg(b.path("tests/runner/launch.py"));
    direct_board.addFileArg(b.path("tests/storage/tables/direct_table_service.py"));
    direct_board.addArtifactArg(node_artifact);
    direct_board.addArtifactArg(direct_table_client);
    direct_board.addArg(if (b.option(bool, "direct-board-browser", "Qualify direct relational Board in Chromium") orelse false) "board-browser" else "board");
    direct_board.addArtifactArg(station_bindings.artifact("transit_station"));
    direct_board.addArtifactArg(board);
    direct_board.has_side_effects = true;
    direct_board.stdio = .inherit;
    b.step("test-direct-board", "Prove direct Board reads, original pin recovery and current authorization").dependOn(&direct_board.step);

    const direct_dependencies = b.addSystemCommand(&.{ "python3", "-B" });
    direct_dependencies.addFileArg(b.path("tests/runner/launch.py"));
    direct_dependencies.addFileArg(b.path("tests/storage/tables/direct_table_service.py"));
    direct_dependencies.addArtifactArg(node_artifact);
    direct_dependencies.addArtifactArg(direct_table_client);
    direct_dependencies.addArg("dependencies");
    direct_dependencies.has_side_effects = true;
    direct_dependencies.stdio = .inherit;
    b.step("test-direct-dependencies", "Prove direct dependency registration, RESTRICT and exact recovery across node loss").dependOn(&direct_dependencies.step);
    const named_resources = b.addSystemCommand(&.{ "python3", "-B" });
    named_resources.addFileArg(b.path("tests/runner/launch.py"));
    named_resources.addFileArg(b.path("tests/storage/tables/direct_table_service.py"));
    named_resources.addArtifactArg(node_artifact);
    named_resources.addArtifactArg(direct_table_client);
    named_resources.addArg("resources");
    named_resources.has_side_effects = true;
    named_resources.stdio = .inherit;
    b.step("test-direct-named-resources", "Prove named Document initialization and original receipt recovery across node loss").dependOn(&named_resources.step);
    const direct_captured_query = b.addSystemCommand(&.{ "python3", "-B" });
    direct_captured_query.addFileArg(b.path("tests/runner/launch.py"));
    direct_captured_query.addFileArg(b.path("tests/query/execution/direct_captured_query.py"));
    direct_captured_query.addArtifactArg(node_artifact);
    direct_captured_query.addArtifactArg(direct_table_client);
    if (b.option(bool, "direct-query-example", "Run the finite SQL example through direct capture and restart recovery") orelse false) {
        direct_captured_query.addArg("--example");
        direct_captured_query.addArtifactArg(query_example);
    }
    direct_captured_query.addPassthruArgs();
    direct_captured_query.has_side_effects = true;
    direct_captured_query.stdio = .inherit;
    b.step("test-direct-captured-query", "Prove captured direct Table queries with independent native progress and restart").dependOn(&direct_captured_query.step);
    const growing_load = b.addExecutable(.{ .name = "transit-growing-load-proof", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/performance/load/growing_load.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "transit_client", .module = client.module("transit_client") }},
    }) });
    build_test_step.dependOn(&growing_load.step);
    const load_proof = b.addSystemCommand(&.{ "python3", "-B" });
    load_proof.addFileArg(b.path("tests/runner/launch.py"));
    load_proof.addFileArg(b.path("tests/performance/load/growing_load.py"));
    load_proof.addArtifactArg(node_artifact);
    load_proof.addArtifactArg(growing_load);
    load_proof.addPassthruArgs();
    load_proof.has_side_effects = true;
    load_proof.stdio = .inherit;
    b.step("test-growing-load", "Measure offered load, control progress and bounded state drain").dependOn(&load_proof.step);
    const scale = b.addSystemCommand(&.{ "python3", "-B" });
    scale.addFileArg(b.path("tests/runner/launch.py"));
    scale.addFileArg(b.path("tests/performance/scale/scale.py"));
    scale.addArtifactArg(growth_proof);
    scale.addArtifactArg(node_artifact);
    scale.addArtifactArg(growing_load);
    scale.addPassthruArgs();
    scale.has_side_effects = true;
    scale.stdio = .inherit;
    b.step("test-scale", "Run the repeated finite growth and offered-load matrix").dependOn(&scale.step);
    const quota_proof = b.addSystemCommand(&.{ "python3", "-B" });
    quota_proof.addFileArg(b.path("tests/runner/launch.py"));
    quota_proof.addFileArg(b.path("tests/runtime/station/growing_quota.py"));
    quota_proof.addArtifactArg(node_artifact);
    quota_proof.addArtifactArg(growing_quota);
    quota_proof.has_side_effects = true;
    quota_proof.stdio = .inherit;
    b.step("test-growing-quota", "Focus service and Station quota/recovery behavior").dependOn(&quota_proof.step);
    const growing_behavior = b.addSystemCommand(&.{ "python3", "-B" });
    growing_behavior.addFileArg(b.path("tests/runner/launch.py"));
    growing_behavior.addFileArg(b.path("tests/runtime/application/growing_station.py"));
    growing_behavior.addArtifactArg(node_artifact);
    growing_behavior.addArtifactArg(growing_station);
    growing_behavior.addPassthruArgs();
    growing_behavior.has_side_effects = true;
    growing_behavior.stdio = .inherit;
    b.step("test-growing-station", "Focus the growing Station behavior and recovery proof").dependOn(&growing_behavior.step);
    const query_capture = b.addSystemCommand(&.{ "python3", "-B" });
    query_capture.addFileArg(b.path("tests/runner/launch.py"));
    query_capture.addFileArg(b.path("tests/query/execution/growing_query.py"));
    query_capture.addArtifactArg(node_artifact);
    query_capture.addArtifactArg(growing_query);
    query_capture.addPassthruArgs();
    query_capture.has_side_effects = true;
    query_capture.stdio = .inherit;
    b.step("test-query", "Prove bounded query capture and recovery through disk Ursula").dependOn(&query_capture.step);
    const document_proof = b.addExecutable(.{ .name = "transit-document-proof", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/runtime/document/document.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{ .{ .name = "transit_station", .module = station.module("transit_station") }, .{ .name = "transit_station_document", .module = document.module("transit_station_document") }, .{ .name = "fixture_growing_support", .module = test_modules.get(.growing_support) } },
    }) });
    build_test_step.dependOn(&document_proof.step);
    const document_test = b.addSystemCommand(&.{ "python3", "-B" });
    document_test.addFileArg(b.path("tests/runner/launch.py"));
    document_test.addFileArg(b.path("tests/runtime/document/document.py"));
    document_test.addArtifactArg(node_artifact);
    document_test.addArtifactArg(document_proof);
    document_test.addPassthruArgs();
    document_test.has_side_effects = true;
    document_test.stdio = .inherit;
    b.step("test-document", "Prove Document publication, checkpoint and disk recovery").dependOn(&document_test.step);
    const work_items_native = b.addSystemCommand(&.{ "python3", "-B" });
    work_items_native.addFileArg(b.path("tests/runner/launch.py"));
    work_items_native.addFileArg(b.path("tests/runtime/application/work_items.py"));
    work_items_native.addArtifactArg(node_artifact);
    work_items_native.addArtifactArg(work_items);
    work_items_native.addArtifactArg(work_items_proof);
    work_items_native.addArtifactArg(query_host);
    work_items_native.has_side_effects = true;
    work_items_native.stdio = .inherit;
    b.step("test-work-items", "Qualify the actual Table migration worker through disk recovery").dependOn(&work_items_native.step);
    const work_items_browser = b.addSystemCommand(&.{ "python3", "-B" });
    work_items_browser.addFileArg(b.path("tests/runner/launch.py"));
    work_items_browser.addFileArg(b.path("tests/runtime/application/work_items_browser.py"));
    for ([_]*std.Build.Step.Compile{ node_artifact, work_items, query_host, work_items_gateway, work_items_browser_proof }) |artifact| work_items_browser.addArtifactArg(artifact);
    work_items_browser.has_side_effects = true;
    work_items_browser.stdio = .inherit;
    b.step("test-work-items-browser", "Qualify generated application queries through publication and data migration").dependOn(&work_items_browser.step);
    const application_proof = b.addExecutable(.{ .name = "transit-application-proof", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/runtime/application/application.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{ .{ .name = "transit_station_app", .module = application.module("transit_station_app") }, .{ .name = "transit_station", .module = station.module("transit_station") }, .{ .name = "fixture_growing_support", .module = test_modules.get(.growing_support) } },
    }) });
    build_test_step.dependOn(&application_proof.step);
    const application_test = b.addSystemCommand(&.{ "python3", "-B" });
    application_test.addFileArg(b.path("tests/runner/launch.py"));
    application_test.addFileArg(b.path("tests/runtime/application/application.py"));
    application_test.addArtifactArg(node_artifact);
    application_test.addArtifactArg(application_proof);
    application_test.has_side_effects = true;
    application_test.stdio = .inherit;
    b.step("test-application", "Qualify conditional application publication over signed native ingress and disk recovery").dependOn(&application_test.step);
    const application_browser = b.addSystemCommand(&.{ "python3", "-B" });
    application_browser.addFileArg(b.path("tests/runner/launch.py"));
    application_browser.addFileArg(b.path("tests/interfaces/installation/application_board.py"));
    application_browser.addArtifactArg(node_artifact);
    application_browser.addArtifactArg(application_proof);
    application_browser.addArtifactArg(board);
    application_browser.has_side_effects = true;
    application_browser.stdio = .inherit;
    b.step("test-application-browser", "Qualify the embedded declarative editor and signed publication with actual disk recovery").dependOn(&application_browser.step);
    const publication_proof = b.addExecutable(.{ .name = "transit-publication-proof", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/runtime/application/publication.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{ .{ .name = "transit_station", .module = station.module("transit_station") }, .{ .name = "fixture_growing_support", .module = test_modules.get(.growing_support) } },
    }) });
    build_test_step.dependOn(&publication_proof.step);
    const publication_test = b.addSystemCommand(&.{ "python3", "-B" });
    publication_test.addFileArg(b.path("tests/runner/launch.py"));
    publication_test.addFileArg(b.path("tests/runtime/application/publication.py"));
    publication_test.addArtifactArg(node_artifact);
    publication_test.addArtifactArg(publication_proof);
    publication_test.has_side_effects = true;
    publication_test.stdio = .inherit;
    b.step("test-publication", "Prove bounded immutable Station publication and crash recovery").dependOn(&publication_test.step);
    const relational_capacity_proof = b.step("relational-capacity-proof", "Build native relational physical-capacity fixtures");
    relational_capacity_proof.dependOn(&b.addInstallArtifact(node_artifact, .{}).step);
    relational_capacity_proof.dependOn(&b.addInstallArtifact(direct_table_client, .{}).step);
    const sql_catalog_proof = b.addExecutable(.{ .name = "transit-sql-catalog-proof", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/interfaces/sql/sql_catalog_native.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{ .{ .name = "transit_sql_service", .module = b.dependency("transit_sql_service", .{ .target = target, .optimize = optimize }).module("transit_sql_service") }, .{ .name = "transit_catalog", .module = catalog.module("transit_catalog") }, .{ .name = "transit_station", .module = station.module("transit_station") }, .{ .name = "transit_query", .module = query.module("transit_query") }, .{ .name = "fixture_catalog_query_support", .module = test_modules.get(.catalog_query_support) }, .{ .name = "fixture_growing_support", .module = test_modules.get(.growing_support) }, .{ .name = "fixture_native_proof_files", .module = test_modules.get(.native_proof_files) }, .{ .name = "fixture_table_authorization_support", .module = test_modules.get(.table_authorization_support) } },
    }) });
    build_test_step.dependOn(&sql_catalog_proof.step);
    const sql_gateway_proof = b.addExecutable(.{ .name = "transit-sql-gateway-proof", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/interfaces/sql/sql_gateway_native.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{ .{ .name = "transit_sql_service", .module = b.dependency("transit_sql_service", .{ .target = target, .optimize = optimize }).module("transit_sql_service") }, .{ .name = "transit_catalog", .module = catalog.module("transit_catalog") }, .{ .name = "transit_station", .module = station.module("transit_station") }, .{ .name = "transit_query", .module = query.module("transit_query") }, .{ .name = "transit_station_app", .module = application.module("transit_station_app") }, .{ .name = "fixture_growing_support", .module = test_modules.get(.growing_support) }, .{ .name = "fixture_native_proof_files", .module = test_modules.get(.native_proof_files) }, .{ .name = "fixture_sql_catalog_native", .module = test_modules.get(.sql_catalog_native) }, .{ .name = "fixture_sql_session_sources", .module = test_modules.get(.sql_session_sources) }, .{ .name = "fixture_table_authorization_support", .module = test_modules.get(.table_authorization_support) } },
    }) });
    build_test_step.dependOn(&sql_gateway_proof.step);
    const sql_gateway_native = b.addSystemCommand(&.{ "python3", "-B" });
    sql_gateway_native.addFileArg(b.path("tests/runner/launch.py"));
    sql_gateway_native.addFileArg(b.path("tests/interfaces/sql/sql_gateway_native.py"));
    sql_gateway_native.addArtifactArg(node_artifact);
    sql_gateway_native.addArtifactArg(sql_catalog_proof);
    sql_gateway_native.addArtifactArg(sql_gateway_proof);
    sql_gateway_native.has_side_effects = true;
    sql_gateway_native.stdio = .inherit;
    b.step("test-sql-gateway", "Prove signed gateway ledger recovery through real native owners").dependOn(&sql_gateway_native.step);
    const sql_wire_encoding = b.addExecutable(.{ .name = "transit-sql-wire-encoding", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/interfaces/sql/sql_wire_encoding.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{ .{ .name = "transit_postgres", .module = b.dependency("transit_postgres", .{ .target = target, .optimize = optimize }).module("transit_postgres") }, .{ .name = "transit_mysql", .module = b.dependency("transit_mysql", .{ .target = target, .optimize = optimize }).module("transit_mysql") } },
    }) });
    sql_wire_encoding.root_module.addImport("transit_memory", b.dependency("transit_memory", .{ .target = target, .optimize = optimize }).module("transit_memory"));
    build_test_step.dependOn(&sql_wire_encoding.step);
    const encoding_cost = b.addRunArtifact(sql_wire_encoding);
    encoding_cost.has_side_effects = true;
    b.step("test-sql-wire-encoding", "Measure framed row encoding separately from authority and transport").dependOn(&encoding_cost.step);
    const allocation_client = b.addExecutable(.{ .name = "transit-sql-result-allocations", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/interfaces/sql/sql_result_allocations.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .imports = &.{
            .{ .name = "transit_sql_client", .module = sql_client.module("transit_sql_client") },
            .{ .name = "transit_memory", .module = b.dependency("transit_memory", .{ .target = target, .optimize = optimize }).module("transit_memory") },
            .{ .name = "transit_io", .module = b.dependency("transit_io", .{ .target = target, .optimize = optimize }).module("transit_io") },
        },
    }) });
    allocation_client.root_module.addCSourceFile(.{ .file = b.path("tests/interfaces/sql/allocation_probe.c"), .flags = &.{ "-std=c11", "-fno-builtin", "-Wall", "-Wextra", "-Werror" } });
    build_test_step.dependOn(&allocation_client.step);
    const allocation_test = b.addSystemCommand(&.{ "python3", "-B" });
    allocation_test.addFileArg(b.path("tests/runner/launch.py"));
    allocation_test.addFileArg(b.path("tests/interfaces/sql_sessions/allocations.py"));
    allocation_test.addArtifactArg(allocation_client);
    allocation_test.has_side_effects = true;
    allocation_test.stdio = .inherit;
    b.step("test-sql-result-allocations", "Enforce shared-client allocation bounds across transport replacement").dependOn(&allocation_test.step);
    const configuration_probe = b.addExecutable(.{ .name = "transit-configuration-probe", .root_module = b.createModule(.{
        .root_source_file = b.path("apps/transit-cli/ConfigurationProbe.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .imports = &.{ .{ .name = "transit_query", .module = query.module("transit_query") }, .{ .name = "transit_sql_service", .module = sql_gateway.module("transit_sql_service") }, .{ .name = "transit_sql_client", .module = sql_client.module("transit_sql_client") }, .{ .name = "transit_http_server", .module = b.dependency("transit_http_server", .{ .target = target, .optimize = optimize }).module("transit_http_server") }, .{ .name = "transit_serving_http", .module = serving_http.module("transit_serving_http") } },
    }) });
    const sql_wire_gateway = b.addSystemCommand(&.{ "python3", "-B" });
    const sql_wire_build = b.step("test-sql-wire-build", "Install SQL proof binaries for measurements after compilation finishes");
    sql_wire_gateway.step.dependOn(&encoding_cost.step);
    sql_wire_gateway.addFileArg(b.path("tests/runner/launch.py"));
    sql_wire_gateway.addFileArg(b.path("tests/interfaces/sql_wire/gateway.py"));
    for ([_]*std.Build.Step.Compile{ node_artifact, sql_catalog_proof, sql_gateway_proof, query_host, sql_gateway_app, configuration_probe, transit_cli }) |artifact| {
        sql_wire_gateway.addArtifactArg(artifact);
        sql_wire_build.dependOn(&b.addInstallArtifact(artifact, .{}).step);
    }
    sql_wire_gateway.addPassthruArgs();
    sql_wire_gateway.step.dependOn(&operation_install.step);
    sql_wire_gateway.has_side_effects = true;
    sql_wire_gateway.stdio = .inherit;
    b.step("test-sql-wire-gateway", "Exercise database clients against native gateway owners").dependOn(&sql_wire_gateway.step);
    if (b.option([]const u8, "sql-wire-placement", "Database gateway placement: compose or reference")) |placement| {
        const placed = b.addSystemCommand(&.{ "python3", "-B" });
        placed.addFileArg(b.path("examples/sql-wire/run.py"));
        placed.addArg(placement);
        for ([_]*std.Build.Step.Compile{ node_artifact, sql_catalog_proof, sql_gateway_proof, sql_gateway_app }) |artifact| placed.addArtifactArg(artifact);
        placed.has_side_effects = true;
        placed.stdio = .inherit;
        b.step("test-sql-wire-placement", "Qualify scoped SQL deployment and fenced physical recovery").dependOn(&placed.step);
    }
    const relational_callers_native = b.addSystemCommand(&.{ "python3", "-B" });
    relational_callers_native.addFileArg(b.path("tests/runner/launch.py"));
    relational_callers_native.addFileArg(b.path("tests/storage/tables/direct_table_service.py"));
    relational_callers_native.addArtifactArg(node_artifact);
    relational_callers_native.addArtifactArg(direct_table_client);
    const relational_sdk = b.option(enum { python, node }, "relational-sdk", "Include installed relational SDK callers");
    relational_callers_native.addArg(if (relational_sdk) |language| switch (language) {
        .python => "relational-python",
        .node => "relational-node",
    } else "relational");
    relational_callers_native.addArtifactArg(station_bindings.artifact("transit_station"));
    relational_callers_native.addArtifactArg(station_host);
    relational_callers_native.has_side_effects = true;
    relational_callers_native.stdio = .inherit;
    const relational_callers_step = b.step("test-relational-callers", "Prove explicit retained relational callers against the direct owner");
    relational_callers_step.dependOn(&relational_callers_native.step);
    if (b.option(bool, "relational-board", "Qualify explicit relational Board requests") orelse false) relational_callers_step.dependOn(&direct_board.step);
    const relational_exchanges = b.step("test-relational-exchanges", "Qualify direct exchanges through process loss and multiple producers");
    var previous_exchange: ?*std.Build.Step = null;
    for ([_][]const u8{ "--exchanges-only", "--exchange-workers-only" }) |mode| {
        const exchange_proof = b.addSystemCommand(&.{ "python3", "-B" });
        exchange_proof.addFileArg(b.path("tests/runner/launch.py"));
        exchange_proof.addFileArg(b.path("tests/query/execution/direct_captured_query.py"));
        exchange_proof.addArtifactArg(node_artifact);
        exchange_proof.addArtifactArg(direct_table_client);
        exchange_proof.addArg(mode);
        exchange_proof.has_side_effects = true;
        exchange_proof.stdio = .inherit;
        if (previous_exchange) |previous| exchange_proof.step.dependOn(previous);
        previous_exchange = &exchange_proof.step;
    }
    relational_exchanges.dependOn(previous_exchange.?);
    const named_relational_native = b.addSystemCommand(&.{ "python3", "-B" });
    named_relational_native.addFileArg(b.path("tests/runner/launch.py"));
    named_relational_native.addFileArg(b.path("tests/query/execution/direct_captured_query.py"));
    named_relational_native.addArtifactArg(node_artifact);
    named_relational_native.addArtifactArg(direct_table_client);
    named_relational_native.addArg("--named-only");
    named_relational_native.has_side_effects = true;
    named_relational_native.stdio = .inherit;
    b.step("test-named-relational", "Prove separate named publication, activation and complete revision recovery on disk").dependOn(&named_relational_native.step);
    const combined_table_test = b.addSystemCommand(&.{ "python3", "-B" });
    combined_table_test.addFileArg(b.path("tests/runner/launch.py"));
    combined_table_test.addFileArg(b.path("tests/query/execution/direct_captured_query.py"));
    combined_table_test.addArtifactArg(node_artifact);
    combined_table_test.addArtifactArg(direct_table_client);
    combined_table_test.addArg("--unified-boundaries-only");
    combined_table_test.has_side_effects = true;
    combined_table_test.stdio = .inherit;
    b.step("test-table-query-writer", "Prove direct Table capture and independent native query progress").dependOn(&combined_table_test.step);
    const c_proof = b.addExecutable(.{ .name = "transit-client-c-proof", .root_module = b.createModule(.{ .target = target, .optimize = optimize, .link_libc = true }) });
    c_proof.root_module.addCSourceFile(.{ .file = b.path("tests/sdk/client_abi.c"), .flags = &.{ "-std=c11", "-Wall", "-Werror" } });
    c_proof.root_module.addIncludePath(b.path("packages/zig/transit-client/include"));
    c_proof.root_module.linkLibrary(client.artifact("transit_client"));
    const abi_tests = b.addSystemCommand(&.{ "python3", "-B" });
    abi_tests.addFileArg(b.path("tests/runner/launch.py"));
    abi_tests.addFileArg(b.path("tests/sdk/client_abi.py"));
    abi_tests.addArtifactArg(client.artifact("transit_client"));
    abi_tests.addArtifactArg(node_artifact);
    abi_tests.addArtifactArg(cli_artifact);
    abi_tests.addArtifactArg(c_proof);
    abi_tests.has_side_effects = true;
    abi_tests.stdio = .inherit;
    const abi_test_step = b.step("test-client-abi", "Prove the C ABI against real authority and host loss");
    abi_test_step.dependOn(&abi_tests.step);
    const client_host_tests = b.addSystemCommand(&.{ "python3", "-B" });
    client_host_tests.addFileArg(b.path("tests/runner/launch.py"));
    client_host_tests.addFileArg(b.path("tests/sdk/client_host.py"));
    client_host_tests.addArtifactArg(client_host);
    client_host_tests.addArtifactArg(node_artifact);
    client_host_tests.addArtifactArg(cli_artifact);
    client_host_tests.has_side_effects = true;
    client_host_tests.stdio = .inherit;
    abi_test_step.dependOn(&client_host_tests.step);
    const binding_tests = b.addSystemCommand(&.{ "python3", "-B" });
    binding_tests.addFileArg(b.path("tests/runner/launch.py"));
    binding_tests.addFileArg(b.path("tests/sdk/bindings.py"));
    binding_tests.addArtifactArg(node_artifact);
    binding_tests.addArtifactArg(cli_artifact);
    binding_tests.addArtifactArg(station_bindings.artifact("transit_station"));
    binding_tests.addArtifactArg(client.artifact("transit_client"));
    binding_tests.addArtifactArg(station_host);
    binding_tests.has_side_effects = true;
    binding_tests.stdio = .inherit;
    b.step("test-bindings", "Qualify current Station ABI and native port recovery").dependOn(&binding_tests.step);
    const readiness_caller = b.addExecutable(.{ .name = "transit-readiness-caller", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/storage/retention/readiness_client.zig"),
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
        .imports = &.{.{ .name = "transit_query", .module = exampleModule(b, sdk, "transit_query", target, optimize) }},
    }) });
    const install_ledger = b.addInstallArtifact(station_ledger, .{});
    b.step("example-station-ledger", "Install the Station ledger example").dependOn(&install_ledger.step);
    examples_step.dependOn(&install_ledger.step);
    b.getInstallStep().dependOn(&install_ledger.step);
    const station_test = b.addSystemCommand(&.{ "python3", "-B" });
    station_test.addFileArg(b.path("tests/runner/launch.py"));
    station_test.addFileArg(b.path("tests/runtime/station/station.py"));
    station_test.addArtifactArg(node_artifact);
    station_test.addArtifactArg(cli_artifact);
    station_test.addArtifactArg(station_ledger);
    station_test.addArtifactArg(delivery_artifact);
    station_test.addArtifactArg(station_controller);
    station_test.has_side_effects = true;
    station_test.stdio = .inherit;
    b.step("test-station", "Prove recoverable Station callers against durable authority").dependOn(&station_test.step);
    const upgrade_tests = b.addSystemCommand(&.{ "python3", "-B" });
    upgrade_tests.addFileArg(b.path("tests/runner/launch.py"));
    upgrade_tests.addFileArg(b.path("tests/runtime/deployment/runtime_upgrade.py"));
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
            .imports = &.{.{ .name = "transit_client", .module = exampleModule(b, sdk, "transit_client", target, optimize) }},
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
        .root_source_file = b.path("tests/runtime/effects/effect_executor.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "transit_client", .module = client.module("transit_client") }},
    }) });
    services.addArtifactArg(executor);
    build_test_step.dependOn(&executor.step);
    b.step("test-service", "Prove signed ingress and worker recovery over HTTP").dependOn(&services.step);
    components_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = core.module("transit_core") })).step);
    const integration = b.addSystemCommand(&.{ "python3", "-B" });
    integration.addFileArg(b.path("tests/runner/launch.py"));
    integration.addFileArg(b.path("tests/storage/providers/storage.py"));
    const proofs_step = b.step("proofs", "Install disk conformance proof executables");
    const disk_proofs = [_]struct { name: []const u8, path: []const u8 }{
        .{ .name = "storage", .path = "tests/storage/providers/storage.zig" },
        .{ .name = "kernel", .path = "tests/runtime/core/kernel.zig" },
        .{ .name = "effects", .path = "tests/runtime/effects/effects.zig" },
        .{ .name = "lifetime", .path = "tests/storage/retention/lifetime.zig" },
        .{ .name = "outbox", .path = "tests/runtime/delivery/outbox.zig" },
        .{ .name = "runtime", .path = "tests/runtime/core/runtime.zig" },
        .{ .name = "deletion", .path = "tests/storage/retention/deletion.zig" },
        .{ .name = "state", .path = "tests/runtime/core/state.zig" },
        .{ .name = "readiness", .path = "tests/storage/retention/readiness.zig" },
    };
    for (disk_proofs) |entry| {
        const name = entry.name;
        const proof = b.addExecutable(.{
            .name = b.fmt("transit-{s}-proof", .{name}),
            .root_module = b.createModule(.{
                .root_source_file = b.path(entry.path),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "transit_core", .module = core.module("transit_core") },
                    .{ .name = "transit_backend_ursula", .module = adapter.module("transit_backend_ursula") },
                },
            }),
        });
        if (!std.mem.eql(u8, name, "storage")) proof.root_module.addImport("fixture_native_disk", test_modules.get(.native_disk));
        proofs_step.dependOn(&b.addInstallArtifact(proof, .{}).step);
        integration.addArtifactArg(proof);
        if (std.mem.eql(u8, name, "deletion")) services.addArtifactArg(proof);
    }
    integration.has_side_effects = true;
    integration.stdio = .inherit;
    b.step("test-storage", "Prove conditional writes and disk recovery against Ursula").dependOn(&integration.step);
    const board_tests = b.addSystemCommand(&.{ "python3", "-B" });
    board_tests.addFileArg(b.path("tests/runner/launch.py"));
    board_tests.addFileArg(b.path("tests/interfaces/board/board.py"));
    board_tests.addArtifactArg(node_artifact);
    board_tests.addArtifactArg(cli_artifact);
    board_tests.addArtifactArg(board);
    if (b.option(bool, "transit-board-browser", "Include real browser qualification") orelse false) board_tests.addArg("--browser");
    board_tests.has_side_effects = true;
    board_tests.stdio = .inherit;
    b.step("test-transit-board", "Qualify Board against disk-backed Transit").dependOn(&board_tests.step);
    const observation_tests = b.addSystemCommand(&.{ "python3", "-B" });
    observation_tests.addFileArg(b.path("tests/runner/launch.py"));
    observation_tests.addFileArg(b.path("tests/interfaces/inspection/observability.py"));
    observation_tests.addArtifactArg(node_artifact);
    observation_tests.addArtifactArg(cli_artifact);
    observation_tests.addArtifactArg(board);
    observation_tests.has_side_effects = true;
    observation_tests.stdio = .inherit;
    b.step("test-observability", "Prove cross-service correlation and diagnostic semantics").dependOn(&observation_tests.step);
    const inspection = b.addSystemCommand(&.{ "python3", "-B" });
    inspection.addFileArg(b.path("tests/runner/launch.py"));
    inspection.addFileArg(b.path("tests/interfaces/inspection/inspection.py"));
    inspection.addArtifactArg(node_artifact);
    inspection.addArtifactArg(cli_artifact);
    inspection.has_side_effects = true;
    inspection.stdio = .inherit;
    b.step("test-inspection", "Prove scoped public inspection against disk Ursula").dependOn(&inspection.step);
    const state_api = b.addSystemCommand(&.{ "python3", "-B" });
    state_api.addFileArg(b.path("tests/runner/launch.py"));
    state_api.addFileArg(b.path("tests/interfaces/native/state_api.py"));
    state_api.addArtifactArg(node_artifact);
    state_api.addArtifactArg(cli_artifact);
    state_api.addArtifactArg(example_artifacts[0]);
    state_api.has_side_effects = true;
    state_api.stdio = .inherit;
    b.step("test-state", "Prove state resources through the public service").dependOn(&state_api.step);
    const callers = b.addSystemCommand(&.{ "python3", "-B" });
    callers.addFileArg(b.path("tests/runner/launch.py"));
    callers.addFileArg(b.path("tests/runtime/application/callers.py"));
    // Both callers use the exact same authority and public CLI artifacts.
    callers.addArtifactArg(node_artifact);
    callers.addArtifactArg(cli_artifact);
    for (example_artifacts) |example| callers.addArtifactArg(example);
    const client_probe = b.addExecutable(.{ .name = "client-probe", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/sdk/client_probe.zig"),
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
    const vortex = b.addSystemCommand(&.{ "python3", "-B" });
    vortex.addFileArg(b.path("tests/runner/launch.py"));
    vortex.addFileArg(b.path("tests/runtime/delivery/vortex.py"));
    for ([_]*std.Build.Step.Compile{ node_artifact, cli_artifact, example_artifacts[0], delivery_artifact }) |artifact| vortex.addArtifactArg(artifact);
    vortex.addPassthruArgs();
    vortex.has_side_effects = true;
    vortex.stdio = .inherit;
    b.step("test-vortex", "Supervise real workers/courier/node and disk Ursula through external faults").dependOn(&vortex.step);
    const capacity = b.addExecutable(.{ .name = "transit-capacity-proof", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/storage/retention/capacity.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{ .{ .name = "transit_core", .module = core.module("transit_core") }, .{ .name = "transit_backend_ursula", .module = adapter.module("transit_backend_ursula") }, .{ .name = "fixture_growing_capacity", .module = test_modules.get(.growing_capacity) } },
    }) });
    b.step("capacity-proof", "Install the physical storage pressure proof driver").dependOn(&b.addInstallArtifact(capacity, .{}).step);
    build_test_step.dependOn(&capacity.step);
    const growing_capacity = b.addExecutable(.{ .name = "transit-growing-capacity-proof", .root_module = b.createModule(.{
        .root_source_file = b.path("tests/storage/providers/growing_capacity.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "transit_core", .module = core.module("transit_core") },
            .{ .name = "transit_backend_ursula", .module = adapter.module("transit_backend_ursula") },
        },
    }) });
    b.step("growing-capacity-proof", "Install the growing physical pressure proof driver").dependOn(&b.addInstallArtifact(growing_capacity, .{}).step);
    build_test_step.dependOn(&growing_capacity.step);
    test_modules.wire(&.{
        .{ .name = "transit_data_client", .module = b.dependency("transit_data_client", .{ .target = target, .optimize = optimize }).module("transit_data_client") },
        .{ .name = "cli_support", .module = cli_support },
        .{ .name = "transit_backend_ursula", .module = adapter.module("transit_backend_ursula") },
        .{ .name = "transit_catalog", .module = catalog.module("transit_catalog") },
        .{ .name = "transit_core", .module = core.module("transit_core") },
        .{ .name = "transit_query", .module = query.module("transit_query") },
        .{ .name = "transit_serving", .module = serving.module("transit_serving") },
        .{ .name = "transit_sql_service", .module = sql_gateway.module("transit_sql_service") },
        .{ .name = "transit_station", .module = station.module("transit_station") },
        .{ .name = "transit_station_app", .module = application.module("transit_station_app") },
        .{ .name = "transit_station_grpc", .module = station_grpc.module("transit_station_grpc") },
        .{ .name = "transit_station_http", .module = station_http.module("transit_station_http") },
        .{ .name = "work_items", .module = work_items_module },
    });
}

fn exampleModule(b: *std.Build, sdk: ?*std.Build.Dependency, name: []const u8, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Module {
    if (sdk) |dependency| return dependency.module(name);
    // A runtime-only build must not silently compile consumers against an
    // alternate package surface. This module fails only if an example is built.
    return b.createModule(.{ .root_source_file = b.path("tests/sdk/sdk_disabled.zig"), .target = target, .optimize = optimize });
}
