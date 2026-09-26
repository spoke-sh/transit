# transit-native-client for Python

The Linux x86_64 native dependency for `transit-client` 0.2.0. Its built wheel
contains only `libtransit_client.so` and `transit-client-host`; Station is not a
dependency. Import opens no library or process. `library_path()` and `host_path()`
resolve package-owned artifacts and reject missing files or unsupported platforms.

Build through [the artifact builder](../../../bindings/build_python.py) after
`just bindings::build`. The builder copies explicit outputs into an isolated
wheel staging directory; binary artifacts are not committed. The initial consumer
qualification uses the repository's pinned Linux Nix runtime, including its native
loader dependencies; this is not a manylinux portability or registry release claim.
