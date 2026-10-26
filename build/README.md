# Build composition

The [root build](../build.zig) selects the target, optimization and registration
profile. Package build files own their libraries and tests.

| Owner | Registered work |
| --- | --- |
| [runtime.zig](runtime.zig) | Runtime applications, Board assets and shared package/build objects |
| [checks.zig](checks.zig) | Cross-component checks, consumer examples, benchmarks and development exporters |
| [test_modules.zig](test_modules.zig) | Explicit native fixture imports across test domains |

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
