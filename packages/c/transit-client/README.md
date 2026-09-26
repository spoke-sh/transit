# Transit public C client

M11's independent C11 interface is [transit/client.h](include/transit/client.h).
It wraps the shared Zig ABI with typed references, capabilities, prepared sends,
opaque mutation recovery and explicit dispatch outcomes. Station is not a
dependency. The implementation uses C++17 internally; C callers need only the C
header and the SDK shared library. The pinned Zig toolchain builds both.

`just bindings::c-build` produces separate SDK, native and C++ header archives.
Extract the C and native archives into one installation prefix, then compile
with `zig cc app.c $(pkg-config --cflags --libs transit-client-c)`. Point
`PKG_CONFIG_PATH` at the prefix's `lib/pkgconfig` directory. The resulting
consumer finds the SDK through its installed rpath; the SDK loads the native
library beside itself. No library-path environment variable is needed.
`native_directory` explicitly overrides native discovery. Missing symbols or
incompatible versions produce `TRANSIT_SDK_INCOMPATIBLE_NATIVE` with a bounded
phase. Loading a library neither discovers credentials nor starts a client.

The qualified platform is Linux x86_64 with the pinned Zig 0.17 compiler and the
build's Nix runtime closure. These are local installation artifacts, not portable
Linux distributions or registry publications. See [usage and ownership](docs/USAGE.md)
and the [C++ wrappers](../../cpp/transit-client/README.md).

`build.zig.zon` declares the direct generated-ABI dependency. `zig build check`
in this package compiles the library; `just bindings::c-sdk-test` qualifies clean
C/C++ consumers against the shared real-authority raw-client schedule.
