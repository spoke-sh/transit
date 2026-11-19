# Transit compiler adapter

This package exports `transit_compiler` and `transit_workspace` from the exact
[transitc snapshot](../../../third_party/transitc/upstream.json). Source language,
compiler implementation, workspace resolution and publication are owned by
[transitc](https://github.com/spoke-sh/transitc). This directory contains only build
composition; there is no second compiler implementation.

The embedded profile injects Transit's canonical SQL frontend, protocol and memory
modules into both libraries. It never resolves transitc's standalone shared-source
pin or development flake. Thus runtime test products and SQL values retain the
same Zig type identity. `transit build` and `transit test` keep their invocation
contracts through shared orchestration. Standalone `transitc test` owns source
resolution, compilation, case scheduling and reports, while the runtime test host
remains in Transit behind the [compiled-case contract](../../../third_party/transitc/contracts/TEST_HOST_V1.md).

Run `zig build test` here. It executes the upstream compiler/workspace tests with
this repository's shared modules. Cross-component build/test and source verification
remain registered in Transit's normal schedules. The snapshot is an unmodified
source distribution, checked by `python3 -B tasks/transitc.py`; update its owning
repository, then import an exact reviewed commit with that tool. The import source
checkout is never a build input. See the upstream notice for attribution.
