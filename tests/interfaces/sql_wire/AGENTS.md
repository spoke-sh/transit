# Working on database protocol checks

Follow [test instructions](../../AGENTS.md). Start with the
[database protocol reference](../../../docs/handbook/reference/database-protocols.md)
and [gateway contract](../../../contracts/SQL_GATEWAY_V1.md). `contracts.py`,
`values.py` and `schema.py` cover wire interpretation; `gateway.py`, `clients.py`,
`tls.py`, `authority.py` and `faults.py` cover installed boundaries.

Run the owning `just test::sql-wire-*` tasks with pinned independent clients.
Keep PostgreSQL/MySQL framing, TLS/account identity, logical values and current
authorization explicit. A successful client connection does not establish full
query/result recovery. Never resubmit an uncertain mutation as fresh SQL. Keep
reference transcripts attributable to their source and backend; cost measurements
cannot replace correctness and failure schedules.
