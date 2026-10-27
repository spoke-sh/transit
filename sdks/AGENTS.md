# Working on consumer SDKs

Start with the [SDK index](README.md), the language/package README,
[caller semantics](../docs/handbook/reference/callers.md) and
[binding tooling](../bindings/README.md). Public language APIs and native
distribution packages live here. Shared protocol/framework semantics belong to
the Zig owners in `packages/zig/`; runtime apps and packages do not import SDKs.

Keep generated wire declarations separate from idiomatic APIs. Preserve original
request identity, uncertain outcomes, current authorization, cancellation and
joined disposal through adapters. Host tasks and handler fields are not durable
state. Follow the current v1 hard cutover policy; do not add fallback bindings.

Use `nix develop .#bindings` and the owning language task from
[bindings/README.md](../bindings/README.md#build-and-verification). Iterate with
that language's unit/type checks, then its installed consumer. `bindings::c-sdk-test`
covers C/C++; `bindings::beam-sdk-test` covers Erlang/Elixir. Raw Go has a separate
profile. Use `vp` and locked dependencies for TypeScript operations.

Keep installed-consumer isolation, actual example binaries and matching native
source/definition/target/build profiles. A source-tree import or warm local
installation is not a substitute. Do not reuse Debug and ReleaseSafe artifacts
interchangeably or share mutable installation directories between concurrent
suites. Register shared observations in the
[SDK scenarios](../tests/sdk/sdk.json) and preserve per-language owners
in the [suite inventory](../tests/runner/suite.json). Changes to a shared
boundary need all affected callers; language-only changes use their own scope.
