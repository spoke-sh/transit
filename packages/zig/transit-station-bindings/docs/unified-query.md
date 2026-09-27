# Unified query codecs

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
