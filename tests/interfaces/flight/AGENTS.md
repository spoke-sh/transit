# Working on Flight qualification

Follow [test instructions](../../AGENTS.md) and the [Flight test guide](README.md).
This directory owns pinned independent ADBC declarations used by the cross-process
Flight checks. The [Flight reference](../../../docs/handbook/reference/flight.md)
owns supported profiles.

Preserve upstream source/version attribution and independent schema/value checks.
Use the owning `just test::flight*` recipes and their explicit deployment
prerequisites. Metadata checks, installed clients, fault recovery and reference
placement are separate evidence. Do not infer the last three from the first.
