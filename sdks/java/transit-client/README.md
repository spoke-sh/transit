# Transit Java client

Independent typed raw Transit APIs for Java 21, version 0.0.1. The SDK owns public
records, bounded scheduling and packaging; the shared Zig client owns signing,
operation identities, protocol validation and exact retry. It does not depend on
Station or select credentials automatically.

Use `nix develop .#bindings` and `just bindings::java-sdk-test` for strict compilation
and a clean JAR consumer against the real growing authority. The
[usage guide](docs/USAGE.md) covers installation, asynchronous calls and recovery.
The generated resources under `resources/` come from `just bindings::generate`;
`io.transit.client.internal` is an exact-version implementation interface shared
with the Station SDK, not the application API.

The baseline is OpenJDK 21, Gson 2.12.1 and Linux x86_64 and ARM64 native artifacts from the
pinned Nix shell. Maven publication and other platforms are not qualified.
