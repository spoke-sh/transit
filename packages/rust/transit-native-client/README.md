# transit-native-client

The Rust public client's version-matched Linux x86_64 native artifact. Built
packages contain `lib/libtransit_client.so`; Rust embeds these bytes into the
consumer so its installed executable does not depend on a Cargo cache path.
The first open loads a private temporary copy and removes the file. Later opens
share that code mapping, retained until process exit; import/linking starts no work.
The native library requires the pinned Nix runtime closure.

Source development may set `TRANSIT_LIBRARY_DIR` at build time. Clean installed
consumers use the artifact's bundled library and need no loader-path assembly.
Registry publication and other platforms remain unqualified.
