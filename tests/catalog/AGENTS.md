# Working on catalog checks

Follow [test instructions](../AGENTS.md), the [catalog index](README.md) and the
owning data/definition/policy contracts. Separate stable identity, definition
validation, publication, activation, observed progress and completion.

Keep independent expected bytes and semantic fixtures here. Do not derive signing
expectations, type encodings or authorization decisions from the production
encoder being checked. Preserve current-policy denial, missing/foreign definition
rejection, dependency ownership and incomplete outcomes.

Keep public caller schedules with their boundary. SDK installation mechanics
belong in SDK; physical storage/recovery belongs in storage; actors are application
execution. Share harness mechanics without moving assertions into generic helpers.

Use the Python test launcher and qualified imports for repository drivers. Copied
fault-host programs intentionally resolve their own private sibling files and
must run independently of repository imports. Migrate callers, manifests and
catalog references together. Execute affected declarations, denial and recovery
schedules after fixture checks; record results automatically.
