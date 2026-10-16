# Transit native Java Station artifact

Version 0.2.0 packages the shared Zig `transit-station-host` executable for the
[Java Station SDK](../transit-station-sdk/README.md). It uses the same private,
version-checked extraction and joined cleanup as the independent Java client's
[native artifact](../transit-native-client/README.md). The normal classpath
discovers the JAR; loading it starts no host or credential discovery.

`just bindings::java-build` builds the artifact for Linux x86_64 in the pinned Nix
environment. It requires that runtime closure. Maven Central publication and
portable Linux/native platform releases are not qualified.
