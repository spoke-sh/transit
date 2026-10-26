# Working on application runtime checks

Follow [test instructions](../AGENTS.md), the [runtime index](README.md) and owning
Station/process/effect contracts. Keep application actors separate from the
direct data plane. Preserve actor execution checks while storage architecture
changes; remove a superseded path only with an identified executed replacement.

Assert stable accepted-work identity, current authorization, fencing, input/output
commit boundaries, bounded active work and recovery. Provider observations,
restored snapshots and names do not grant execution rights. Replay must not
dispatch effects. Unknown remote outcomes need connector policy and remain
distinct from local cancellation or successful closure.

Share process and transport mechanics through harness while keeping fault intent
and semantic assertions in this owner. The Vortex receipt-loss control belongs
with its delivery supervisor. State its physical process/fault boundary separately
from deterministic models; a seed cannot make OS scheduling deterministic.

Use qualified Python imports and the test launcher. Preserve standalone generated
provider peers and copied installed binaries. Update task/build callers and
examples with moves, and execute real caller, delivery, effect, restart and
provider schedules as affected. Keep original failed state private and automatic
results distinct from planned or unavailable checks.
