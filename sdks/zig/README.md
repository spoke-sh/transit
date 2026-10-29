# Zig SDK

The `transit_sdk` package exports the shared Zig caller modules for consumer
applications. It preserves their existing import names and exact type identity;
protocol and framework implementation remains in `packages/zig/`.

## Installation

Use the repository's [pinned Zig compiler](../../nix/README.md) and a matching
Transit checkout. Add a path dependency on its `sdks/zig` directory in your
application's `build.zig.zon`:

```zig
.dependencies = .{
    .transit_sdk = .{ .path = "../transit/sdks/zig" },
},
```

The complete checkout supplies the shared dependency closure. Alternatively,
extract `transit-sdk-zig-<version>-source.tar.gz` from the matching GitHub Release
and point the dependency at its `sdks/zig` directory. The archive preserves shared
packages, third-party sources and the real work-items application; copying only
`sdks/zig` is insufficient. Use the compiler recorded in `sdk-manifest.json`.
Select the same protocol definition as the running authority.

In `build.zig`, resolve the SDK once and import only the modules your application
uses, with your own target and optimization settings:

```zig
const sdk = b.dependency("transit_sdk", .{ .target = target, .optimize = optimize });
app.root_module.addImport("transit_client", sdk.module("transit_client"));
app.root_module.addImport("transit_station", sdk.module("transit_station"));
```

Existing `@import("transit_client")` and `@import("transit_station")` statements
remain unchanged. Allocators, I/O, credentials, resident bounds and handle
lifetimes stay explicit in the owning APIs.

## Exported modules

| Module | API owner |
| --- | --- |
| `transit_client` | [Signed operations, scoped sessions and exact recovery](../../packages/zig/transit-client/README.md) |
| `transit_protocol` | [Public values and canonical contracts](../../packages/zig/transit-protocol/README.md) |
| `transit_station` | [Behaviors, turns and state helpers](../../packages/zig/transit-station/README.md) |
| `transit_station_document` | [Document callers](../../packages/zig/transit-station-document/README.md) |
| `transit_station_http` | [Recorded HTTP callers](../../packages/zig/transit-station-http/README.md) |
| `transit_station_grpc` | [Recorded RPC callers](../../packages/zig/transit-station-grpc/README.md) |
| `transit_query` | [Query preparation, admission and reads](../../packages/zig/transit-query/README.md) |
| `transit_catalog` | [Catalog declarations and callers](../../packages/zig/transit-catalog/README.md) |
| `transit_fuze` | [Typed query plans and execution](../../packages/zig/transit-fuze/README.md) |
| `transit_station_app` | [Application declarations and installation](../../packages/zig/transit-station-app/README.md) |

The [work-items application](../../examples/work-items/README.md) has a standalone
manifest consuming this SDK. The root example builds use the same SDK modules.
The [caller reference](../../docs/handbook/reference/callers.md) defines uncertainty,
current authorization and cancellation across all supported languages.
