# External fault testing

`just test::vortex` owns a disposable node, counter worker, courier and disk Ursula.
Four rounds cover request loss/delay and response loss/delay, dropped connections,
worker/node/provider SIGKILL, courier stop/continue and restart against current
history. `--seed 19 --rounds 12` changes workload intent; rounds are bounded to
4–32. Public calls, readiness, fault observation and eligible progress have finite
deadlines. It never edits provider files or private installation checkpoints.

The peer records synthetic signed requests, actual replies and monotonic event
times. Each requested fault must fire; courier reply loss must produce an exact
retry. A consumed source prefix has the independently expected cumulative value
and original outputs, and each destination admission preserves its output/turn
origin. Current denial/stale activation and three corrupted-observation controls
challenge the checker. Full JSONL histories, process/provider logs and report JSON
are retained per run in `.cache/verification/vortex/`, with source, toolchain,
binary hashes, topology, seed, configuration, duration and cleanup status. Private
seed files remain only in the disposable fixture and are never copied to artifacts.

`just test::vortex-profile PROFILE` selects an independent experiment:

| Profile       | Owned checks                                                                                                                                   | Environment / boundary                                                                       |
| ------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------- |
| `sdk`         | Installed Python wheels and Node tarballs: frozen bytes, dropped reply, seedless host recovery, await cancellation, disposal and revoked retry | Native Linux public SDKs; package/build hashes and per-host histories                        |
| `application` | Lost provisioning/rotation/migration/activation replies, current revocation and runtime upgrade                                                | Local application manager and provider adapter fixture; no Kubernetes claim                  |
| `query`       | Durable capture cancellation/expiry plus interactive Table snapshot cancellation/current denial                                                | Distinct durable and leased query lifetimes; pinned native MinIO for interactive cold reads |
| `reactive`    | Real browser refresh replacement, pause, revocation and lifecycle recovery                                                                     | Owning TLS/browser rig; installed Chromium required                                          |
| `discovery`   | Expanded finite model/property/simulation campaigns, sixteen external fault rounds, codec fuzzing and all compiling guard mutations             | Separate exploration campaign; committed source required                                     |

The profile runner retains commands, logs, source/compiler identity and per-stage
completion in `.cache/verification/external/`. The four selected external profiles
keep a 900-second stage cap. Discovery has a 3,600-second cap per stage. Its
resource command samples fault points with four seeds; it does not request
`--exhaustive`. The tasks retain their own fault,
progress and mutation limits. A failed stage stops the campaign and leaves the
overall report incomplete.
SDK histories record actual signed attempts, receipts and host-ownership checks.
The original owning tasks remain runnable independently. A seed does not fix OS
scheduling. External failures are retained; automatic schedule minimization is
limited to the in-process JSON trace profiles. Real reference placement, physical
ENOSPC, arbitrary corruption and host power loss retain separate proof owners.

The ordinary core lane owns the four-round external regression; weekly discovery
runs sixteen rounds. The [fault workflow](../../.github/workflows/fault-verification.yml)
runs discovery weekly and accepts any profile on demand. It retains the same
thirteen exploration commands formerly appended to ordinary bindings, with a
separate 180-minute job cap for discovery and 60 minutes for the external profiles.
It preserves complete and incomplete reports and traces. Stage deadlines
are failure limits, not measured feedback targets. Local and hosted timing evidence
must remain separate; the existing hosted budgets are not requalified by adding
these tasks or by one local passing sample.

