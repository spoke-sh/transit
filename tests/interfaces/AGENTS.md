# Working on public interface checks

Follow the [test instructions](../AGENTS.md) and [interface index](README.md).
Start with the owning public reference and wire contract. Place assertions by the
boundary they protect: transport/CLI/Board/session semantics here, domain
semantics with catalog/query/storage/runtime, and reusable process mechanics in
harness. Keep Board inspection read-only.

Use qualified Python imports and the shared test launcher. Generated subprocess
wrappers must name their imports explicitly; copied independent consumers must
remain independently executable. Update task/build commands, browser/Node
imports, compiler inputs, examples and dynamic subprocesses when moving files.

Preserve exact saved operation identities through disconnects and lost replies.
Current authorization, readiness, disclosure, cancellation and durable completion
are separate assertions. Do not turn an unknown result into a fresh mutation or
extend a timeout to hide a failure. Keep timing probes separate from acceptance
conditions and runtime policy clocks.

Each installed fixture owns its mutable state, ports and child processes. Keep
failed installations private when needed for diagnosis; never publish credentials.
Use explicit matching binaries and preserve actual local/Ursula backend selection.
Run the affected real interface and fault schedules after contract/static checks.
Browser, packaged installation and reference deployment checks remain distinct;
missing infrastructure cannot count as a pass.
