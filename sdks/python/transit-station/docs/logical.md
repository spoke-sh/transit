# Local logical types and values

`transit_station.logical` supplies immutable `Type` and `Value` owners through
a synchronous `Codec`. The shared Zig implementation owns all interpretation,
casts, structural operations and Arrow layout. Opening starts one bounded native
worker; it reads no credentials and opens no source or authority connection.

```python
from transit_station.logical import Codec

with Codec() as codec:
    datatype = codec.type_json(
        '{"definition":"transit.fuze.types.v1.2026-11-01.companions","type":{"uint128":{}}}'
    )
    value = codec.bind(datatype, '340282366920938463463374607431768211455')
    saved = value.bytes
    ipc = codec.arrow(value)
# value, saved and ipc remain owned after closing the codec.
```

`type_json`/`type_bytes` and `value_json`/`value_bytes` validate complete documents
or canonical binary. Values expose immutable `json` and `bytes`; types also expose
`fingerprint`, `equality` and `ordering`. `bind`, `cast`, `equal`, `order`, `hash`
and `arrow` delegate to Zig. Cast rounding defaults to `reject`; callers may
select `toward_zero` or `nearest_even`. Unsupported traits and invalid/foreign
documents raise native errors. Calls after `close` raise `RuntimeError`.

The [logical JSON contract](../../../../contracts/FUZE_TYPES_V1.md#neutral-logical-json)
represents exact integers and decimal coefficients as strings and floats as bits,
including inside recursive cells and conflict alternatives. These document APIs
do not automatically map arbitrary Python objects to logical values. Requests
and results are bounded to 256 KiB; canonical binary values to 96 KiB. Arrow
export yields an owned one-column stream within the 64 KiB segment bound.
Use separate codecs for overlapping host work; a codec is synchronous and closes
its worker explicitly. Stored Tables, native query callers and Flight retain
their separately documented type profiles.
