# SQL session checks

The [session contract](../../../contracts/SQL_SESSION_V1.md) defines supported
operations; [contribution instructions](AGENTS.md) describe their test boundary.

| Responsibility | Driver |
| --- | --- |
| Independent contract fixtures and binary result oracle | [contracts.py](contracts.py), [result_frame.py](result_frame.py) |
| Native and local sessions | [native.py](native.py), [local.py](local.py) |
| Current disclosure rights and resources | [security.py](security.py), [resources.py](resources.py) |
| Disconnects, replacement and cancellation | [faults.py](faults.py), [boundaries.py](boundaries.py) |
| Console peer and measurements | [editor_peer.py](editor_peer.py), [measurements.py](measurements.py) |
| Shared client allocation bounds over Unix, HTTP and TLS | [allocations.py](allocations.py), [client probe](../sql/sql_result_allocations.zig) |

`just test::sql-result-allocations` runs 300 statements per transport against a
finite-relation peer. It varies schemas, widths and batch counts, repeats one
lost fetch ordinal, crosses the 256-request connection boundary and replaces idle
sockets. Thirty statements prepare and bind an independently encoded parameter;
a command completion stays retained through the run. Four retained responses
force the next submission to fail before dispatch without damaging their data.
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
`measurements.py` owns the native portion of the seeded console comparison in the
[performance runner](../../performance/console/console_latency.py). Executed results
and limitations remain in qualification history.
