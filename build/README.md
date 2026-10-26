# Build composition

The [root build](../build.zig) composes runtime applications, example binaries and
cross-component checks. Package build files own their libraries and unit tests.

[test_modules.zig](test_modules.zig) declares shared Zig fixture modules and their
direct imports. Scenario implementations live under their [test owners](../tests/README.md).
The registry creates each shared module once, then connects imports so every
consumer in a graph sees the same types, including mutually dependent fixtures.
Package modules come from the composing build; fixtures do not import sibling
package source files.

Use `zig build test-build` in `nix develop` to compile integration probes.
Run the affected [test task](../tasks/test.just) to qualify actual behavior;
compilation alone does not exercise a service, provider or failure schedule.
