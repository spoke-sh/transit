# Transit and Station bindings

The shared implementation remains Zig. The raw Transit ABI handles public
protocol operations; Station adds detached handler turns, associated state,
Table queries and durable framework messages. Host adapters own allocation,
exceptions and runtime scheduling. They do not reimplement those protocols.

These are M9's qualified low-level bindings. [M11](../docs/roadmap/M11.md)
plans language-native public SDKs with typed operations, managed handler runners
and installable artifacts. The current manual turn/action APIs remain available;
the [caller design](../docs/CLIENT.md#idiomatic-language-sdks) defines the planned
layer above them.

Public Python and TypeScript SDKs are now implemented separately from these
low-level adapters. Their package guides and installation/recovery proofs are
linked from [M11](../docs/roadmap/M11.md); other language SDKs and public
cross-language qualification remain open.

M11 also adds **Ruby** to the target list. Its proposed adapter uses the shared
native port with Ruby value objects and block-scoped ownership. Ruby packages,
and conformance evidence remain to be implemented; Ruby 3.4.9 / RubyGems 3.7.2
are now pinned by the existing Nix lock. The M9 adapters
and qualified runtime table below do not include Ruby. See the
[M11 language conventions](../docs/roadmap/M11.md#language-conventions).

`just bindings::generate` reflects the native exports and updates adapter
resources. `just bindings::check` rejects drift. The
[shared ABI guide](../packages/zig/transit-station/docs/bindings.md) owns the
contract; the [native port](../apps/transit-station-host/README.md) supplies a
versioned child-process route for Node, Java and BEAM.

The [C/C++](../packages/cpp/transit-station/README.md),
[Rust](../packages/rust/transit-station/README.md),
[Python](../packages/python/transit-station/README.md),
[Node](../packages/ts/transit-station/README.md),
[Java](../packages/java/transit-station/README.md),
[.NET](../packages/dotnet/transit-station/README.md) and
[Elixir/Erlang](../packages/beam/transit-station/README.md) adapters exchange real
Table queries across languages. Native/managed cancellation, host loss, malformed
ports and ownership cleanup have executable checks. The reference deployment
qualifies Zig workers; foreign worker isolation remains separate scope.
[The examples](../examples/station-bindings/README.md) use real
authority and Arrow data, not language-specific server routes. Public package
registry releases and non-Linux platforms are not qualified yet.

The [shared conformance scenarios](../tests/verification/README.md#shared-sdk-conformance)
define the M10-to-M11 handoff. The current matrix checks durable continuation
through each language pair against the same observations; shared native proofs
own sequencing contention, decode-failure policy, uncertain responses and host
cleanup. M11 must repeat these obligations through its public APIs.

The first implemented public raw SDK is [Python transit-client](../packages/python/transit-client/README.md).
`just bindings::python-test` builds wheels and installs the client plus its
independent native dependency in a clean consumer outside the checkout. It checks
typed preparation, native-classified recovery, lost receipts, host restart,
revocation and bounded async cancellation/disposal. No Station wheel is installed in the raw-client proof. A separate installed
consumer qualifies Python's typed Station runner, counter CLI roles, Table/query
handlers, recovery callbacks, scoped state, full-width values and optional PyArrow.
The [Python guide](../packages/python/transit-station/README.md) distinguishes the
public API from its preserved M9 raw adapter.

The [public Node client](../packages/ts/transit-client/README.md) is independent
of Station too. `just bindings::node-sdk-test` builds its native dependency and
SDK tarballs, installs a clean consumer and runs the same raw-client schedule as
Python. A second consumer qualifies the [typed Station SDK](../packages/ts/transit-station-sdk/README.md),
its installed counter/query examples, owned async turns and optional Arrow reader.
The existing `@rey/transit-station` adapter remains compatible. The bindings CI
lane installs both legacy and public Node workspace packages from the lockfile.

The independent [Rust client](../packages/rust/transit-client/README.md) now has
typed raw operations and embedded native artifacts. `just bindings::rust-sdk-test`
in the bindings shell compiles an external locked consumer, removes its build
and extracted source trees, and runs the shared authority/recovery schedule.
Its blocking ownership proof is separate from Python/Node async cancellation;
compile-fail checks enforce exclusive use and consumed-handle disposal. The
[typed Rust Station SDK](../packages/rust/transit-station-sdk/README.md) also runs
the shared handler/recovery/Table/query schedule, with borrowed turn helpers,
stop/block panic policies and optional Arrow Rust ownership checks.

## Qualification tools

`nix develop .#bindings` adds the locked foreign-language tools to the normal
shell. Keeping them optional avoids expanding every developer/CI closure.
C/C++ use the pinned Zig compiler; Python and Node already come from the default
shell. The current Linux x86_64 baselines are:

| Runtime | Locked baseline |
| --- | --- |
| Zig / C / C++ | 0.17.0-dev.2267+48abf1a34 |
| Python | CPython 3.13.15; PyArrow 23.0.0 for independent IPC checks |
| Rust / Cargo | 1.95.0; optional Arrow array/IPC 59.1.0 with locked 59.x components |
| Node.js | 24.21.0 from the existing frontend toolchain |
| Java | OpenJDK 21.0.12.1+1; Gson 2.12.1, separately checksummed |
| .NET SDK | 8.0.425 |
| Erlang | OTP 28.5.0.6 |
| Elixir | 1.18.5 built against OTP 28 |

The Nix lock and [binding tools](../nix/bindings-tools.nix) own these versions.
Every listed language runs both service and requester roles in the Linux matrix.
Only Zig is the intended M9 reference worker; these checks do not qualify foreign
runtimes as Substrate workers.
