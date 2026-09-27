# Unified query clients and codecs

The additive `station_unified_query_codec(json, length, output)` export and
`unified_query_codec` port action share `QueryCodec`. Generated schemas come from
the same Zig types. The [v2 contract](../../../../contracts/UNIFIED_QUERY_V2.md)
owns source identity, typed semantics and the foreign representation.

| Action | Returned value |
| --- | --- |
| `prepare` | Canonical finite bundle as hex plus its Publication specification |
| `decode` | Validated typed source, plan and explicit work limits |
| `source` | Canonical source bytes, exact digest, policy declaration digest and schema |
| `inspect_arrow` | Owned typed rows from one verified nested IPC segment and declared schema |

`prepare` binds the plan to the declared source schema before encoding. It cannot
infer a KV decoder, adopt an unknown Document format or widen a Table schema.
Document paths are UTF-8 name arrays; list expansion and text projections retain
their explicit traversal/byte budgets. `decode` rejects incomplete/trailing bytes.

Keep all non-counter 64-bit quantities as decimal strings. Float values use
`float_bits` hex to preserve negative zero; binary uses hex and UTF-8 uses text.
Projection indices are numeric arrays. Returned conflicts include their original
ordered assignment IDs and distinguish null from a typed value or type error.

The complete JSON input is at most 256 KiB. The native implementation additionally
enforces the 16 KiB bundle, 8-column/8-row page, 4 KiB scalar and 64 KiB Arrow
segment bounds. Arrow parsing uses a 4 MiB fixed workspace. All returned arrays,
names, scalars and IPC-derived values are copied into the owned result; they do
not borrow temporary parsing storage. Release every native `station_buffer`
once, and join in-flight work before destroying a foreign owner.

The port can run with `{"local_codec":true}`. It needs no authority URL, key or
execution handle. Pure decoding does not establish current source availability
or authorization; signed submission/result qualification is separate.

`tests/unified_codec.py HOST LIBRARY` checks both transports against independently
encoded bundles and PyArrow-produced streams. It covers all three sources, six
primitive types, five cell states, Unicode, binary, full-width integers/IDs,
negative zero, empty results and malformed inputs. Public SDK qualification
remains in progress.

## Signed caller ownership

`station_unified_query_create/call/destroy` own a separate query caller. Creation
requires a URL, explicit seed, realm/principal and source/requester PID/resource
bindings; it requires no activation or writer ownership. The generated
`UnifiedQueryConfig`, `UnifiedQueryAction` and `UnifiedQueryResult` schemas define
the additive ABI. The port selects `query_client` instead of either server
profile and accepts `unified_query` actions. Importing a language package does
not open this owner or load a credential.

`capabilities` advertises the local v2 implementation. `describe` separately
checks the configured current source policy and declared schema. `next` prepares
one upload/admission command for a caller-selected namespace and canonical
bundle. Persist its opaque `prepared` string before `submit`. An admission
receipt supplies the input position for `observe`; wait for `committed` before
preparing the next command. A null prepared command means upload/admission has
stopped; inspect `status` for completion, denial or cancellation. It is not a
complete-result claim. `prepare` also supports explicit cancel, retire and
bounded collect commands.

After uncertain dispatch, retain and resubmit the **identical prepared string**,
including after replacing the native owner. Never parse/re-encode it or prepare
a new command to resolve the old attempt. Local invalid-envelope failures occur
before dispatch; unconfirmed transport or result failures after dispatch return
`uncertain`. Successful admission still differs from observed behavior completion.

`page` returns an owned IPC segment, typed source/plan commitments and complete
manifest counters. Its opaque `next` string preserves verification progress,
not permission. Each page rechecks current source/request access and lifecycle;
only a null continuation after whole-result verification establishes coverage.
Save a cursor only with its exact connection/namespace. A failed page cannot
advance it. Decimal strings retain full-width quantities in manifests; signed
prepared/cursor strings must remain opaque to numeric JSON parsers.

Each handle admits one operation at a time and returns `busy` on overlap. Join
all calls before destroy. Foreign cancellation of an await does not cancel
durable work; an explicit prepared cancellation is a separate command. Native
buffers own their data independently of the handle. Calls use bounded request,
bundle, Arrow workspace and segment sizes from the codec profile above.
