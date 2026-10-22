# Transit Erlang client

The independent `transit_client` OTP application provides typed host references,
receipts, tagged outcomes and opaque exact-retry objects over the shared Zig
client port. It depends directly on the separate native application and does not
import Station. Public records are in `include/transit_client.hrl`; generated
wire schemas remain in `priv/contract.json`.

The external-consumer proof passes under [Language SDKs](../../../docs/handbook/reference/sdks.md)
through `just bindings::beam-sdk-test`. The [usage guide](docs/USAGE.md) describes
installation, recovery, scheduling and supervision. The target is Linux x86_64 with OTP 28 from
the optional pinned bindings shell. Runtime loading starts no native work.
The bridge supports ordinary ownership or an OTP supervisor via `child_spec/1`;
local bridge PIDs are distinct from durable `#transit_process{}` references.

A waiting caller's death leaves admitted work owned. One atomic admission slot
rejects overlap before requests reach the native worker queue. Explicit close
joins admitted work, awaits native cleanup/exit and returns retained evidence.
Observe startup and close results; killing a supervisor/VM can leave work
uncertain. Local supervision never grants Transit ownership or retry authority.

The generated contract validator resolves bounded root-local recursive schemas,
keeps separate schema roots isolated, and rejects missing/external references,
unknown validation rules and non-consuming cycles. Data depth and reference hops
have separate bounds. Large canonical hex and UTF-8 length checks use linear
scans without constructing payload-sized lists.
