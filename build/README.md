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
The local `transit` executable imports the registered node, query host, SQL
gateway and Board entry-point modules. The standalone artifacts and private
local roles share those modules and package identities. Board assets are linked
into the executable; the supervisor launches independent role processes from it.

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

## Changing the release version

All Transit-owned packages use the root [VERSION](../VERSION). The build captures
Git provenance once per configuration; ordinary Git builds recheck it on every
invocation, while `-Dsource-revision` supplies explicit metadata to isolated
builders. See the [release policy](../docs/handbook/reference/versioning.md#software-releases).

For a version change, update `VERSION`, package manifests, exact Transit dependency
pins, embedded SDK version resources, loader expectations, consumer fixtures and
current installation examples together. Preserve upstream dependency versions and
historical evidence. Regenerate package-manager locks using the pinned tools;
`python3 -B tasks/version.py` checks owned versions and dependency pins. Add new
package formats to that check when introducing them. The binding archive builders
read `VERSION` directly.

Commit and qualify the release set before tagging that exact clean commit
`v<version>`. `python3 -B tasks/version.py --tag v<version>` checks tag identity as
well as package consistency. CI applies this gate to tag pushes. Never move a
published tag or replace an artifact with different bytes under the same version.


Nightly builds create a source-bound identity with
`python3 -B tasks/release_identity.py create --channel nightly --date YYYYMMDD --output PATH`.
Set `TRANSIT_RELEASE_IDENTITY` to that absolute path for packaging. The record
contains the base version, effective version, immutable tag, full source SHA,
source epoch and per-language package versions. Consumers reject a record from
another checkout. Pass its effective version through `-Drelease-version` for Zig
or `releaseVersion` for the Nix runtime derivation. Package builders transform
owned pins and loader version literals in temporary staging trees; source
manifests and third-party dependency versions remain unchanged.

The release workflow retains each qualified native runtime archive before
starting container export, SDK packaging and downloaded-installer checks.
Those jobs report independent results; publication still requires every runtime,
container, SDK, documentation and Homebrew gate plus ordinary CI. Container
conversion failures retain public image configuration diagnostics separately
from installation state. Retrying an image job reuses the original runtime
archive and source identity rather than rebuilding the runtime.
Pull requests build nightly candidates without publishing, so installed SDK
checks exercise prerelease dependency pins and native-loader version markers.
Manual candidates can select stable or nightly versions; tag publication uses
the exact stable version in `VERSION`.
New PR commits cancel their obsolete candidate runs so qualification follows the
latest source. Nightly and stable publication runs stay serialized and are never
automatically cancelled by an update. Cancelled candidates retain their failed
or incomplete outcome; they supply no passing release evidence.

Downloaded runtime archives also supply the Board onboarding gate on both native
Linux architectures. The workbench schedule runs the single installed executable
with its embedded roles and assets from a private directory, using explicit
proof-only catalog and SQL credentials. API checks cover paginated discovery,
exact-definition previews, complete/empty results, write refusal and revocation.
Chromium checks Catalog, column profiles and temporary Workbook cells and rejects
external asset requests. This job installs browser tooling but does not build the
frontend or runtime; ordinary source-built Board checks remain separate.
The installed runtime gate also runs the real controlling-terminal transcript
and external-editor schedule with no executable discovery through `PATH`. After
a clean retained restart, it accepts another row, kills the supervisor, joins
all owned children and checks the retained rows and replacement generation.
The same schedule applies to native x86_64 and ARM64 downloads.
