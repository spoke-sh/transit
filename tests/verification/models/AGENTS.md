# Working on formal models

Follow the [verification rules](../AGENTS.md) and [model guide](README.md). Keep
specifications, configurations, owning contracts and implementation correspondence
discoverable together. The existing Authority, Delivery, Console and WAL models
have different boundaries; do not promote one model's claims to another owner.

For each change, state the question, finite domains, initial states, transition
rules, safety/liveness properties, fairness assumptions and excluded behavior.
Retain explicit model and implementation negative controls where supplied. Unknown
actions, partial exploration, timeouts and tool errors cannot establish a pass.

Run the owning `just test::*` model task with the pinned tools, then its affected
concrete replay or disk/caller tests. Keep small regression configurations separate
from expanded discovery. Do not shrink an established bound merely to meet a CI
budget; justify and qualify any change to exploration coverage.

Record source/configuration/tool identity, completion, state/edge counts and
counterexamples. Preserve the distinction between model mutations, production
mutations, selected counterexample replay and complete finite-edge correspondence.
Keep detailed executed results in qualification history and raw evidence, not
this instruction file or the root test index.
