# transit-native-station for Python

The Linux x86_64 native dependency for the public Station SDK. Its built wheel
contains `libtransit_station.so` and `transit-station-host`. Raw-client consumers
install the independent `transit-native-client` artifact. Import opens no library
or process; package-owned `library_path()` and `host_path()` resolve the artifacts.

Build through [the artifact builder](../../../bindings/build_python.py) after
`just bindings::build`. Artifacts are copied into isolated wheel staging and stay
out of Git. Initial qualification uses the pinned Linux Nix runtime; broader
binary portability and publishing to a registry need separate release work.
