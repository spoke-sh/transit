# Build composition

The [root build](../build.zig) selects the target, optimization and registration
profile. Package build files own their libraries and tests.

| Owner | Registered work |
| --- | --- |
| [runtime.zig](runtime.zig) | Runtime applications, Board assets and shared package/build objects |
| [checks.zig](checks.zig) | Cross-component checks, consumer examples, benchmarks and development exporters |
| [test_modules.zig](test_modules.zig) | Explicit native fixture imports across test domains |
| [native_fixtures.zig](native_fixtures.zig) | Immutable client and authority prefixes assembled from actual runtime artifacts |

Development builds register both graphs. `-Dchecks=false` registers only runtime
targets and does not access `tests/` or SDK source. Nix runtime and SQL gateway
packages use this profile with those trees excluded from their input source.
Requesting a disabled check fails as an unknown step; enabling checks requires
their actual inputs. Missing fixtures must never silently remove a target.

Both graphs share the same runtime modules and artifact objects. Test registration
adds dependencies to those objects instead of reconstructing runtime binaries.

The fixture registry declares shared Zig modules and their direct imports.
Scenario implementations live under their [test owners](../tests/README.md).
The registry creates each shared module once, then connects imports so every
consumer in a graph sees the same types, including mutually dependent fixtures.
Package modules come from the composing build; fixtures do not import sibling
package source files.

Use `zig build test-build` in `nix develop` to compile integration probes.
Run the affected [test task](../tasks/test.just) to qualify actual behavior;
compilation alone does not exercise a service, provider or failure schedule.

For an explicit native fixture prefix, run the harness resolver inside the pinned
shell:

```sh
python3 -B tests/runner/launch.py tests/harness/native_artifacts.py prepare clients --optimize Debug
python3 -B tests/runner/launch.py tests/harness/native_artifacts.py prepare authority --optimize ReleaseSafe
```

The command prints a complete prefix in Zig's build cache. Pass it explicitly to
the consuming package builder or scenario; do not modify its files. The build
graph owns dependency caching and keeps optimization profiles separate. Each
invocation asks Zig for current outputs and records source identity, resolved CPU,
target, compiler, definition and file hashes under `.cache/native-artifacts/`.
Changed source during compilation, missing output or a mismatched set/profile
prevents publication of a successful record. Build-graph timing includes cache
lookup and collection; it is not a measurement of compilation alone.

The client set contains both native libraries, their hosts, the administration
client and HTTP/gRPC workers. The authority set contains the node. These helpers
do not reuse mutable installations or test outcomes. Existing task consumers that
still use install prefixes retain their own build steps until migrated explicitly.
