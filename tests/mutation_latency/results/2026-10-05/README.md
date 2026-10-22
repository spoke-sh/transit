# Mutation completion campaign, 2026-10-05

Physical-disk controls for [issue #73](https://github.com/spoke-sh/transit/issues/73).
The runtime baseline is merged `96943293`; bounded waits are `799a7a69`,
correlated attribution is `d793fff3`, and leaf-frontier batching is `79b53c8c`.
The later wide-batch unit and measurement-fixture commits do not change runtime.
Reports retain binary hashes and original runner/build revision fields. Dirty
flags include the user's unrelated untracked DuckDB files; the counts/reader
controls also ran while test and documentation edits were pending.

The host is an AMD Ryzen Threadripper 3960X with 48 logical CPUs, Linux,
pinned Zig 0.17 and the pinned locally corrected Ursula 0.5.1. Mutation fixtures
use owned ext4 directories under `/var/tmp`, MinIO, eight cache pages and default
workers. No extra qualification ran concurrently with the uninstrumented mutation
controls; shared-host load is not controlled. The offered-load repeat overlaps
unit/cold-page/full-check work and uses a separate native-node fixture.

All three 140-case ordinary controls complete without unknown outcomes or
observed supervisor restarts. INSERT/UPDATE/DELETE p50 is 142/153/138 ms at the
baseline, 131/149/129 ms with waits and 113/130/112 ms with leaf batches.
Each repetition contains seven independently verified cases: one/three-row
INSERT, existing/same-value/absent UPDATE and existing/absent DELETE. Cleanup
and independent read verification are outside timed samples.

Both instrumented controls complete 21/21 correlated timelines. Median
admission/view/turn provider requests fall from 16/11/29 to 14/8/22 with leaf
batches. Median authority work falls from 25.1/22.4/41.2 ms to 19.8/13.0/29.4 ms.
The latter median receipt-to-observation tail is 4.94 ms; observation-to-caller
completion is 9.32 ms. Proxies change transport costs, and a receipt is not an
exact commit/fsync timestamp. Read/write request counts are not flush counts.
The reader control completes 140 writes and 1,280 reads without unknown outcomes,
reader failure or observed restart; INSERT/UPDATE/DELETE p50 is 138/156/137 ms.

The initial offered-load fixture fails because it assumes all offered work is
admitted. Its report remains inconclusive. The corrected fixture at `63ccf9af`
records explicit pre-admission refusal and supplies only accepted senders to the
independent drain oracle. Its four-worker/1 ms burst admits four and refuses 44;
all accepted receipts and exact resulting rows survive node/provider replacement.
The initial control command is also refused and is checked separately after the
burst. Rejected sends are not retried. This is a finite overload/recovery result,
not sustainable throughput or simultaneous full SQL mutation capacity.

The paced 50 ms control admits all 48 requests, refuses none, and completes
revocation during the offered interval. Admitted p50/p95 is 16.4/26.6 ms;
the subsequent drain takes 2.54 s. All receipts and exact rows survive restart.
This experiment overlaps qualification and is an admission/recovery control,
not an isolated end-to-end SQL benchmark.

The S3-compatible cold-page proof also passes 1,024 keys with a two-page cache,
provider restart, checkpoint/trim and all three batch acknowledgement faults.
Recovery stages no pages, and retained roots preserve exact values.

The direct-caller controls each complete 140 independently verified cases with no
uncertainty or observed restart. Baseline INSERT/UPDATE/DELETE p50 is 123/150/145 ms
and p95 152/177/150 ms; the candidate records p50 113/134/113 ms and p95 128/163/129 ms.
They run sequentially after clean qualification, without overlapping heavy checks.
This caller omits console rendering and uses its own fsynced checkpoints for
exact requests, receipts and terminal outcomes. Its timings compare that caller
profile; they do not isolate rendering cost or establish console recovery parity.

All 75 ordinary tasks pass in one isolated clean run at `be0e03d1`. The
[qualification record](../../../verification/results/m45-completion-2026-10-05.json)
retains every task, full-check and focused-proof outcomes, exact provenance and
failed development attempts. The selected exhaustive resource control passes
1,170 traces and 22,652 events with identical replay.

## Artifacts

Compressed files preserve original report bytes. They contain fixed identities,
measurements and fixture paths, without credentials or original signed requests.

| Report | Status | Compressed SHA-256 |
| --- | --- | --- |
| [baseline](baseline.json.gz) | complete | `b535ba857040714b7a0adf751080c9cc9708dfbd00539942918e9f7cfc6db63a` |
| [waits](waits.json.gz) | complete | `f39817d3240b9d7ae3ae9c4dc6dc45cbdcd8a1dca8df8208c05e13571f5529b9` |
| [waits-counts](waits-counts.json.gz) | complete | `82ca2cef1dff71967901759a1f702a57e25165056e747901bb5dda10a0863098` |
| [leaf-batches](leaf-batches.json.gz) | complete | `77184e9076f717e685a045d2b9172e632bf9ab0aba3136f372c142bf4996cd91` |
| [leaf-batches-counts](leaf-batches-counts.json.gz) | complete | `dc12bb746ccd3063e32a27fbe26e2b9897daa327cdab2f8ca3dc9fccebc4c793` |
| [leaf-batches-readers](leaf-batches-readers.json.gz) | complete | `5e3cca41bd7b6a0e16a5f3d3d05dc0e8cd057d900009f7bedbcc3244e036a49d` |
| [leaf-batches-pages](leaf-batches-pages.json.gz) | passed | `49d9fd295acf9cdeec5228ebbf34d037d5783e1a273cee0075e9151a7dd91b4d` |
| [offered-load](offered-load.json.gz) | inconclusive | `ac5637bdb2d96e53fdc3c12885d3fd8301c29675b996c8aaa222c28cce907469` |
| [offered-load-repeat](offered-load-repeat.json.gz) | passed | `6419c342f7f05ca31f424b21e7e5b4f5ee4f1d2380c294bd1eeb7f38b346c544` |
| [leaf-batches-cold](leaf-batches-cold.json.gz) | passed | `ca223076efa711dbbb751fb3b54e503a1d7623541141e64e4c33c289da635a9f` |
| [offered-load-paced](offered-load-paced.json.gz) | passed | `c851a0298fa27892b60e96f45ec837fcda65ba3b4ec4d3dd8eee377234fd5203` |
| [baseline-direct](baseline-direct.json.gz) | complete | `fb141d9b38b09dd5e121f4a33a68974dd87f44736fff81a5891d8af1a58a0b27` |
| [leaf-batches-direct](leaf-batches-direct.json.gz) | complete | `2b87bd9026c689f453d3fdeb992989534a2f3773ecbeafaa27a970027012c246` |
| [resource-exhaustive](resource-exhaustive.json.gz) | passed | `c30ac8f4a04d5bf228ca4edcc32eeabae49d1ec8074c2bdd8f624e8b0570cb0b` |

## Reproduction and limits

Enter `nix develop`; set `TMPDIR` to an owned ext4 directory after entering Nix.
Build each frozen source with `zig build transit transit-node transit-query-host
transit-board mutation-latency-client -Doptimize=ReleaseSafe --prefix PREFIX`.
After the build completes, run `python3 -B tests/mutation_latency.py
PREFIX/bin/transit PREFIX/bin/transit-node PREFIX/bin/transit-query-host
--repeat 20 --build-revision REVISION --output FILE`. Use fresh installations;
do not reset or reuse another test's authority. `--instrument --repeat 3` selects
attribution; `--readers 1 --repeat 20` selects the read-contention control. Add
`--client PREFIX/bin/transit-mutation-latency-client --repeat 20` for the separate
direct-caller profile; run baseline and candidate sequentially after other checks.

`just test::growing-load --rows 64 --cache 8 --workers 4 --interval-ms 1
--output FILE` selects the separate finite overload profile. Requests are offered
independently of completion; response latency includes bounded generator queueing.
Admission, refusal and work counters are distinct from later drain time. Fewer
than 20/100 observations yield null p95/p99. See the [proof ledger](../../../README.md#mutation-completion-follow-up)
for checks, development failures and clean qualification status.

The packed-page report checks 256 keys, two cache pages, lost/partial batch
acknowledgements and provider restart/checkpoint/trim. These finite checks establish
neither arbitrary-fault correctness nor provider-memory bounds. Larger architectural
changes retain their explicit contracts in the [storage account](../../../../docs/handbook/internals/storage-runtime.md#alternatives-and-contract-boundaries).
