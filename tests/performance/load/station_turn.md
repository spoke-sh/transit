# Installed Station handler-turn baseline

Run `just test::station-turn-baseline --output .cache/performance/station-turn`
inside the pinned development shell. The task builds matching ReleaseSafe node
and caller artifacts and copies them into a private installation. Run it without
concurrent heavy builds or measurements. The default is three warmup turns and
20 measured turns; `--warmup 1 --repeat 1` exercises the correctness path without
claiming a latency percentile budget. Warmup is bounded to 1–10 and measurement
to 1–100 turns. The first warmup also initializes the behavior descriptor.

Each real GenServer handler receives one integer input, checks its previous
128-byte state, writes one new 128-byte value and publishes one outbound cast
intent. It uses the ordinary public client, scoped process/resource grants,
ownership generation and associated state view. One worker drives one input at
a time. The native local disk backend uses one resident page, unlimited
retention, a 10-second native request timeout and a 30-second requested read-view
deadline. No courier or recipient runs: the measured completion is publication
of the durable outbound intent.

Timing starts before preparing the accepted input and ends after the original
turn commit confirmation. It includes public reads, permit/view/commit commands,
the handler, and writing private pending/receipt records. Input admission and
verification reads are outside this interval. Each exact signed input and each
pending command is saved before dispatch. A failed or uncertain turn fails the
run; the driver never reruns its handler or creates a replacement mutation.
The private installation remains available for original-outcome investigation.
Recorder writes are not a simulated power-loss durability proof.

After every turn, public inspection checks consumed input progress and the exact
state bytes. A bounded paged outbox scan checks every original commit, source,
destination and payload. A separate Python oracle verifies the observed state
and output hashes, complete input coverage and original attribution. After a
SIGTERM node stop and fresh node/caller start, it repeats the complete outbox scan and final
state check without running a handler or dispatching a command.
The report records stop exit codes; a fallback SIGKILL fails this profile.
SIGTERM completion alone does not claim application-level drain.

`report.json` records source/definition/toolchain and binary/driver hashes,
hardware and load, the raw confirmed samples, warmup boundaries, attempt and
unknown counts, and client backing allocations. p95 requires at least 20
successful measured turns; p99 requires 100. The allocation probe covers the
public native client and HTTP transport; private recorder allocations are outside
that probe. Node process CPU ticks, resident high-water marks and Linux I/O byte
counters are separate observations. CPU cycles, server allocator work, storage
IOPS and client RSS remain explicitly unmeasured. These measurements establish
an initial workload basis; they impose no invented absolute Station target.

The [reporting controls](station_turn_test.py) reject missing completion, missing
or corrupt state/output observations, changed original receipts, foreign build
definitions and absent allocation observations. This baseline covers current
native handler turns. Transactional Station replacement, concurrent offered
load, output delivery, remote effects and injected crash schedules need their
own measurements and correctness checks.

## Private transactional comparison

`just test::station-transaction-baseline .cache/performance/station-transaction`
uses the private runner and the same modular 128-byte state sequence, three
warmups, twenty measured turns and one output intent per turn. It additionally
inserts a Table row, checks private Table read-your-writes and appends a journal
entry. The input is a typed Queue payload. Report those differences when comparing
it with the native baseline; this is not an isolated measurement of the storage
commit mechanism.

The timer includes pending discovery, claim, handler execution, all five
transaction participants, decision and bounded cleanup. Admission and independent
verification are outside it. The allocator probe includes the runner, signed
Catalog caller and HTTP transport. The resident runner limit remains 64 MiB;
the default private turn and transaction limits are unchanged. The fixture uses
one resident storage page, unlimited retention, 30-second client exchanges and
a five-minute Queue lease. It does not renew a claim to obtain a sample.

The [comparison driver](station_transaction.py) retains each attempt and sample
in a fresh output directory. The installed oracle checks exact state, Table rows,
journal/input/transaction attribution, original ACKs and every output payload.
Two SIGKILL node restarts repeat that oracle with a different authorized worker
and zero handler invocations. Missing, duplicate, corrupt or failed samples fail
the report; the private installation remains available on failure. Physical
power-loss behavior and external effect execution are outside this profile.
