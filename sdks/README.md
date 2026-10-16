# Transit SDKs

Consumer applications start from the [handbook SDK section](../docs/reference/sdks.md).
Language directories own public APIs, native distribution packages and usage
guides. The [binding tooling](../bindings/README.md) owns generation, packaging
and installed-consumer checks.

| Source | Language |
| --- | --- |
| [zig](zig/README.md) | Zig |
| [python](python/README.md) | Python |
| [ts](ts/README.md) | TypeScript / Node.js |
| [rust](rust/README.md) | Rust |
| [ruby](ruby/README.md) | Ruby |
| [c](c/README.md) | C |
| [cpp](cpp/README.md) | C++ |
| [java](java/README.md) | Java |
| [dotnet](dotnet/README.md) | .NET |
| [beam](beam/README.md) | Erlang and Elixir |

SDKs depend on shared implementation in `packages/`; runtime code in `apps/`
and `packages/` does not depend on SDKs. Board and its browser libraries remain
runtime components. Shared Zig client, Station and binding implementations stay
in `packages/zig/`. The Zig SDK re-exports their modules without copying source.

The root build composes runtime targets and SDK-backed examples. Runtime-only
builds use `-Dsdk-examples=false`; an attempted example build then fails explicitly.
The Nix runtime source excludes this directory and SDK example consumers.
`just bindings::runtime-boundary` builds that source; `just bindings::zig-test`
checks module identity and builds a real application outside the checkout.
