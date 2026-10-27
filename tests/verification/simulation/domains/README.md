# Component simulation

`just test::domain-simulation` runs two seeds over real Document, Exchange,
query/refresh, core runtime and catalog implementations. `--seed N --seeds N` selects a
bounded range (at most 64 seeds). Each package runs twice; structured event
records must agree and all six domains must appear. Each run has a 120-second
deadline. The ordinary suite owns two seeds; scheduled discovery owns sixteen.

Artifacts in `.cache/verification/domain-simulation/` retain actual choices and
test logs; the adjacent JSON report records source/dirty status, compiler, binary
hashes, generator, seed range, trace hashes, elapsed time and completion. Replay
uses the same binary/seed. This package profile does not support arbitrary trace
editing or minimization. Errors, timeouts and missing domains cannot pass.

`just test::domain-simulation-mutations` uses committed source clones to omit
Document conflict retention, checkpoint floor advancement, Exchange replay holds,
refresh generation fencing, runtime readiness, current catalog create policy and
original catalog receipt positions. Only executed contract assertion
failures count as detection; compilation and infrastructure failures do not.
The private-turn stores model atomic publication and current-reader failure;
actual WAL durability and application installation remain separate integration
checks. No connector transport runs or dispatches during these replay tests.

Each catalog seed runs 64 requests: sixteen fresh Tables and sixteen conflicts
for each of name, object and physical Table identity. Seeded choices select
existing conflicting objects, policy revocations, point/page read failures,
discarded proposals and caller/owner replacement after lost replies. An independent
accepted-request ledger checks original receipts, visible definitions, sorted
bounded pages and the exact committed key count. Changed page cuts reject.
The fixture uses a dynamic map and models atomic commit; it injects read faults,
not allocator or physical journal failures. The catalog native/installed SDK
schedules separately qualify signed transport, current native grants and disk
restart. This component profile does not qualify native catalog growth.

