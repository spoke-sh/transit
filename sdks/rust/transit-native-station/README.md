# transit-native-station

Embedded Linux x86_64 and ARM64 Station ABI for the Rust public SDK. Built artifacts contain
`lib/libtransit_station.so`; installed consumers retain these bytes in their own
executable. The first explicit open loads a private temporary copy and removes
the file; later opens share the code mapping until process exit. The native library
requires the pinned Nix runtime closure. `TRANSIT_LIBRARY_DIR` is a build-time
source-development override; installed crate consumers need no loader paths.
No credentials or application work are discovered at import or build time.
