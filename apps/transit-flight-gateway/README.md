# Transit Flight gateway

M22's finite Table Flight SQL entry point, under implementation. It composes
[`transit-flight`](../../packages/zig/transit-flight/README.md) with the native
gRPC listener. A private configuration file supplies scoped caller mappings,
credential/key file paths and a fixed source schema. No client can choose an
upstream URL, native principal or resource.

The listener speaks private cleartext HTTP/2 and must be placed behind the
explicit TLS edge; it is not a public plaintext service. Pinned PyArrow and ADBC
Python/C consumers pass native TLS queries. Adversarial lifecycle and placement
qualification are still in progress. See [configuration and limits](docs/configuration.md)
and the [protocol and exclusions](../../contracts/FLIGHT_V1.md).
