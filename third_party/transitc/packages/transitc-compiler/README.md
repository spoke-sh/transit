# transitc-compiler

Pure bounded `.transit` compilation, extracted from Transit at
`e7434306334e3692c6f3e123cba0d278fa412196`. The public module is
`transitc_compiler`; [the source contract](../../contracts/APPLICATION_SOURCE_V1.md)
owns syntax and limits. See [package boundaries](../README.md) for shared pins.

Call `compile(allocator, sources, options, &diagnostic)` with immutable captured
buffers and an explicit compiler revision. A successful `Product` owns SQL,
ordered statement maps, digests and any test cases independently of its inputs.
Call `product.deinit()`. Failure returns no product. Optional source reports keep
bounded context and expansion spans. Compilation grants no runtime rights.

The package retains syntax/templates, graph resolution, nominal source types,
program lowering, typed binding, catalog simulation, independent SQL reparse,
formatting, explicit-basis migration synthesis and compile-only test products.
`Test.Failure` and `Test.Detail` are bounded host-report values; they contain no
execution implementation. The shared frontend supplies authoritative SQL types
and binders. Allocation, recursion, source/output and work bounds remain explicit.

Run `zig build test` here in the root Nix shell. Root `just test-grammar` and
`just test-types` run independent grammar and finite formal correspondence checks.
These are scoped compiler checks, not native runtime qualification.
