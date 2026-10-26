# Shared-client scheduling simulation

`just test::scheduler-simulation [--seeds N --steps N]` runs four saved cases and
four generated schedules by default. `--trace PATH` replays concrete events.
`just test::scheduler-simulation-mutations` requires committed HEAD and detects
omitted Session activation validation or discarded uncertain courier requests.

Real shared Session/courier functions use a test transport that signs native
queries and invokes the core, preserving response validation and modeled error
classes. Worker events separate preparation from submission. Four fault kinds
cover request versus response loss at query and submit boundaries. Saved cases
require the selected fault to fire. Host-loss events discard volatile pending
state; durable input/output progress remains observable. A finite profile tests
recorded permits, settlement, maintenance-driven expiry, checkpoint/trim and
clock rollback/uncertainty. This does not test HTTP framing or host task joining.

The independent checker conserves original admitted values, consumed prefixes,
outputs, destination admissions and provenance, plus ownership and current
permissions. It checks frozen pending digests and terminal dispositions. The
finite fair suffix admits no further input and gives two Sessions and the courier
twenty rounds to drain four inputs per producer. At most 512 events, 1 MiB input,
1..64 seeds, 1..256 random steps and 90 seconds per driver run are admitted.
Replay must be identical. Incomplete/invalid/time-limited runs cannot pass.

Evidence and replay/minimized failures live under
`.cache/verification/scheduler-simulation{.json,/}` with source, compiler,
binary/oracle, generator/configuration, exercised faults and completion identity.
The provider is the modeled atomic journal, not a real disk. Real caller and
courier integration remains `just test::callers`.
