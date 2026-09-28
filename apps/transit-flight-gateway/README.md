# Transit Flight gateway

M22's qualified finite Table Flight SQL entry point. It composes
[`transit-flight`](../../packages/zig/transit-flight/README.md) with the native
gRPC listener. A private configuration file supplies scoped caller mappings,
credential/key file paths and a fixed source schema. No client can choose an
upstream URL, native principal or resource.

The listener speaks private cleartext HTTP/2 and must be placed behind the
explicit TLS edge; it is not a public plaintext service. Pinned PyArrow and ADBC
Python/C consumers pass native, Compose and reference TLS workloads with physical
recovery. Native fault/load proofs cover per-RPC authority, lost acceptance,
retirement, concurrent reads and bounded credit stalls. See
[configuration and limits](docs/configuration.md)
and the [protocol and exclusions](../../contracts/FLIGHT_V1.md).
