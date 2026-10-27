# Installed SDK checks

These checks exercise public client and Station SDKs through installed packages,
native ABI/port adapters and language interoperability. Package unit tests remain
beside their implementation in [sdks/](../../sdks/README.md).

| Boundary | Owner |
| --- | --- |
| Scenario definitions and independent signing/codec inputs | [Scenario catalog](sdk.json), [observations](sdk_scenarios.py), [operations](sdk-operations-v1.json), [codecs](sdk-codecs-v1.json), [Table work](sdk-table-work-v1.json) |
| Raw clients and incompatible native definitions | [Shared schedule](sdk_raw_client.py), [ABI](client_abi.py), [recovery](client_abi_growing.py), [port host](client_host.py) |
| Station callbacks, saved work and lifetime ownership | [Station schedule](sdk_station_runner.py), [native growth](station_growing_abi.py), [query failures](sdk_query_failures.py) |
| Installed language programs and their builders | [Consumer directory](consumers/README.md) |
| Shared schedules' explicit language dispatch | [Consumer registry](consumer_registry.py) |
| Query and direct catalog callers | [Unified consumers](sdk_unified.py), [catalog consumers](direct_sdk_catalog.py), [relational consumers](sdk_relational.py) |
| HTTP/gRPC effects and Documents | [Exchange schedule](sdk_exchange_runner.py), [gRPC entry point](sdk_grpc_runner.py), [Document entry point](sdk_document_runner.py) |
| Cross-language requests and real example binaries | [Interoperability ring](sdk_public_interop.py), [Zig consumer](sdk_zig.py) |
| Packaging and runtime source separation | [Binding declarations](binding_schema_types.py), [runtime packaging](sdk_runtime.py), [build scripts](../../bindings/README.md) |

Enter `nix develop .#bindings`. The [binding task module](../../tasks/bindings.just)
owns package preparation, language checks, installed consumers and interop;
[execution inventory](../runner/suite.json) records required CI coverage and
nested execution. Run repository drivers through
`python3 -B tests/runner/launch.py tests/sdk/DRIVER.py`; their task recipes supply
matching native binaries and package directories. Copied programs run directly
inside their private installed environments.

Native inputs come from [immutable fixture sets](../harness/README.md), with
separate Debug and ReleaseSafe package directories. The query-failure driver
requires both a client `--native-prefix` and an explicit `--node`; the Rust
lifetime driver requires explicit node, CLI, library and installed artifacts.
Neither driver infers these inputs from the last contents of `zig-out/`.

C/C++ installations compile an HTTP, gRPC or Document peer when that installation
first invokes it. Each peer still compiles against private installed headers and
libraries; unrelated schedules do not compile unused peers. Station/header and
incompatible-native checks remain in each installation. Preparation and peer
compilation have separate automatic phase records.

Query/storage and interface fixtures own their semantic assertions. The SDK
installers expose those same schedules to language callers; a codec-only check
does not establish live authorization, uncertain-call recovery or disk behavior.
Use [test contribution rules](../AGENTS.md) and [SDK instructions](AGENTS.md)
before changing these boundaries.

[binding_port_fixture.py](binding_port_fixture.py) is a retained adversarial peer
with no current executable consumer. It does not contribute to the registered
host-boundary proof; any reuse requires current contract and task registration.
