# Transit native Java client artifact

Version 0.0.1 packages the independent Zig `transit-client-host` executable for
Linux x86_64 in a separate JAR. It contains no Station dependency. The public
[Java client](../transit-client/README.md) discovers this versioned resource on
the normal Java classpath, extracts it with private permissions, and removes it
after joining the child. Loading the JAR starts no work and reads no credentials.

`just bindings::java-build` builds the host and JAR from the pinned Nix environment.
The artifact requires that environment's runtime closure; portable Linux release
and Maven Central publication are not qualified. An explicit executable override
is available on `ClientConfig` and must negotiate the same ABI/capabilities.
