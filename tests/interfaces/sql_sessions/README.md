# SQL session checks

`just test::sql-log-declarations` runs Stream/Queue CREATE, policy ALTER,
RENAME, DROP, named metadata and paged listings through native, PostgreSQL and MySQL
sessions, plus a real console declaration script. It checks original-token recovery after service replacement, a 40-row
schema and 35-name listing across two result batches, filtered empty listings,
repeated batches, exact-definition invalidation and permission revocation after
metadata buffering. The same driver admits PRODUCE/ENQUEUE through all four
interfaces, checks typed parameters/defaults and independent row/offset values,
reopens a 65-row original result after gateway replacement, repeats all three
batches, and verifies revoked disclosure. A subsequent append proves that
result delivery and recovery did not append again.

The same installed task runs [positional consumption](consumes.py) through all
four interfaces. It verifies filtered progress versus returned rows, LIMIT 0,
partial-limit completion and exhaustion below the limit, 65 rows across three
SQL batches, typed parameters and revoked buffered/empty terminals. A saved
read and token must retain their original cut after a later append and service
replacement. GROUP and WAIT remain explicit SQL refusals in this profile.

The [session contract](../../../contracts/SQL_SESSION_V1.md) defines supported
operations; [contribution instructions](AGENTS.md) describe their test boundary.

| Responsibility | Driver |
| --- | --- |
| Independent contract fixtures and binary result oracle | [contracts.py](contracts.py), [result_frame.py](result_frame.py) |
| Native and local sessions | [native.py](native.py), [local.py](local.py) |
| Current disclosure rights and resources | [security.py](security.py), [resources.py](resources.py) |
| Disconnects, replacement and cancellation | [faults.py](faults.py), [boundaries.py](boundaries.py) |
| Node and Table storage observations, wire consumers and buffered revocation | [storage.py](storage.py), executed by [native.py](native.py) before captured-query workloads |
| Table transactions, original decisions and checkpoint/outbox histories | [transactions.py](transactions.py), via `just test::sql-transactions` |
| CHECK enforcement, staged FK dependencies, deferred validation and original DDL recovery | [integrity.py](integrity.py), via `just test::sql-integrity` |
| Console peer and measurements | [editor_peer.py](editor_peer.py), [measurements.py](measurements.py) |
| Shared client allocation bounds over Unix, HTTP and TLS | [allocations.py](allocations.py), [client probe](../sql/sql_result_allocations.zig) |

`just test::sql-result-allocations` runs 300 statements per transport against a
finite-relation peer. It varies schemas, widths and batch counts, repeats one
lost fetch ordinal, crosses the 256-request connection boundary and replaces idle
sockets. Thirty statements prepare and bind an independently encoded parameter;
a command completion stays retained through the run. Four retained responses
force the next submission to fail before dispatch without damaging their data.
A separate 33-row wide window spans two wire batches, survives early source
close, and remains unchanged while a 16,384-row result streams through the same
client with periodic consumer delays. Its independent 1 MiB reserve is charged
throughout; the incomplete prefix never becomes a completed result.
A sliced Arrow value view also remains borrowed from a retained first batch
while 100 touch responses reuse other response slots. The view and its buffer
directory end before the next result pull; borrowing does not extend their
documented lifetime or establish a storage retention pin.
The peer also stalls partial responses for one timeout and one cancellation;
an independent control connection confirms the exchange started before cancellation.
A fresh read then checks that joined tasks returned their response and transport
storage. These failed non-mutating calls do not establish statement completion.
One lost write reply settles through its original token after the observation
session expires. The peer checks one submission, a separate replacement observer,
three token observations and the exact terminal operation/counts; the original
interactive session identity remains unchanged. This proves client settlement
and reuse against the peer, not durable acceptance by a Transit authority.
HTTP/TLS peers use numeric IPv4 endpoints; DNS/NSS resolution is not
qualified by this profile. A sealed allocator observes both client reserves and bounded I/O task
storage after finite setup. On Linux/glibc the linked test-only interposer counts
malloc/calloc/realloc/aligned allocation attempts; pinned `strace` observes all
child threads' mappings, heap growth and worker creation in the same interval.
A negative run deliberately calls libc, the direct page allocator and a new
thread outside the Zig wrapper and must be detected. Missing permissions,
unsupported platforms and incomplete traces cannot establish a pass. This tests
communication and result ownership, not service computation or current
authorization. Hidden allocators that neither cross an instrumented boundary nor
grow the process heap remain outside the observation claim.

The runner retains source/toolchain/binary identities, stdout, diagnostics,
memory-only traces and process/thread-attributed events in a unique directory
under `.cache/allocations/runs/`, including failures. No network writes or payloads
are traced. Measurement starts after finite initialization and ends before report
serialization; replacements and retries stay inside it. Counts from independent
parent peer processes are not attributed to the Transit client.

The separate `just test::sql-gateway` real-authority fixture injects response
allocation failure into buffered data, empty and metadata results. It also
fails framing after advancing across three data batches: retrying that ordinal
must retain every exact row and report the final count once. Buffered repeats
must remain byte-identical, while credential revocation must reject disclosure
and clear the cursor. This proves producer failure/retry semantics; it does not
attribute allocations in the composed source and authority services.

The installed native session schedule also waits for account recovery readiness
to disappear after revocation, then repeats data, empty, metadata and storage
results. Denial must still report current access failure and disclose no rows.
Restoring authority cannot revive the cleared result cursor.

Use `just test::sql-sessions` and the affected installed SQL task from the
[test module](../../../tasks/test.just). Measurements describe elapsed work;
they do not replace completion, authorization or recovery assertions.

The shared result model and client correspondence checks run through
`just test::sql-wire-contracts`. They exercise row and column sources with the
same public consumers, Arrow value-buffer borrowing with state details, finite
partition schedules, malformed evidence, allocation failure and bounded resident
memory. `console_outcomes.py` adds independent HTTP loss/cancellation schedules and
one-result presentation; native sessions verify owner counts, retained cuts and
current authorization on buffered data, metadata and empty-terminal repeats.
The binary oracle checks TSR1 framing and commitments, TCP1 columns, canonical
padding and exact logical cells. Its hex cell observations are internal test
values; it rejects JSON result payloads. The generated fixture is decoded by the
Zig owner as well as the independent peer. Mutation controls check that damaged
framing and commitments fail instead of establishing completion.
Independent workload frames cover append rows, filtered Stream output with larger
native coverage, and original Queue claims. Both peers reject missing coverage,
foreign saved bodies and invalid counts; Zig also rejects partial positions.
These codec checks do not establish installed workload SQL execution.
`measurements.py` owns the native portion of the seeded console comparison in the
[performance runner](../../performance/console/console_latency.py). Executed results
and limitations remain in qualification history.

The native session schedule also loses one successful `commit_saved` reply at
the authority proxy. INSERT settlement must still observe the original
identity, terminal outcome and exact counts; typed reads and restart/token retry retain
that same row and operation. This tests uncertain-owner reply recovery without changing physical sync semantics.

`history.py` drives selected historical catalogs through native SQL, PostgreSQL
and MySQL, including rename/name reuse, prepared execution, current revocation,
gateway replacement and explicit release. `just test::sql-history` owns this
installed check. Retention uses the public direct historical operations; its
selector bytes and expected rows are independently specified in the driver.
