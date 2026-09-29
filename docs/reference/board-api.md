# Board OpenAPI reference

Board exposes private system inspection and separately enabled finite query
workspaces. Its [OpenAPI specification](../../contracts/transit-board-v1.openapi.json)
is generated from the Board public types; the operation and schema reference
below is rendered from those exact bytes.

## Access boundary

Every reachable viewer shares the configured upstream inspection identity.
Board has no viewer access keys or sessions. Place it behind the private deployment
boundary; a reachable listener is not per-user authorization. Upstream Transit
still enforces the inspection principal's current read-only grant on each read.

An optional query workspace uses a different explicitly configured identity and
publishes query requests through its own public contract. The opt-in application
editor also has a separate operator identity. Neither grants mutations to the
inspection identity. See [Board configuration](../../apps/transit-board/docs/configuration.md).

## Read evidence, not assumptions

Reads are paged and carry their observation basis. A source association is not
a foreign-resource grant. A recorded result manifest is not proof that all
segments remain readable. Retained gaps, current revocation and unavailable
sources stay visible; Board does not decode arbitrary application values.

The specification covers its declared inspection/query routes. Optional private
reactive and application adapters have their own
[reactive client](../../contracts/REACTIVE_CLIENT_V1.md) and
[application](../../apps/transit-board/docs/application.md) contracts. They are
not silently added to this OpenAPI surface. Read [Board concepts](../internal/BOARD.md)
for the distinction between implemented interfaces and reviewed UI proposals.
