# Working on installed SDK checks

Follow the [test instructions](../AGENTS.md), [SDK index](README.md),
[caller semantics](../../docs/handbook/reference/callers.md) and
[SDK reference](../../docs/handbook/reference/sdks.md).

Keep shared schedules, scenario catalogs and independent fixtures here. Put
language-specific programs/builders in `consumers/<language>/`; package-local
units remain in `sdks/`. Keep the semantic query/catalog/storage assertion with
its domain owner when adding an installed language adapter.

Use the repository test launcher for drivers and qualified helper imports.
Copied installed consumer programs must execute outside the source tree with
only their declared package dependencies. Do not export the repository test
import root into children or make source packages satisfy an installed check.
Copy all required headers and fixtures explicitly; compile against installed
manifests and libraries. Keep language type rejection and missing/foreign native
definition controls.

Pass matching native binaries and package paths explicitly. Each schedule owns
its installation, processes and durable state. Preserve original saved work and
current authorization through recovery, and distinguish uncertain outcomes from
new submissions. Test real example binaries and cross-language peers; shared
native code does not make every adapter automatically correct.

When moving a driver, update dynamic module names, temporary-project inputs,
nested retry processes, task recipes and the scenario catalog together. Execute
the affected installed schedules, including incompatible-definition, lifetime
and failure controls. Record automatic results through the runner; do not commit
routine output or count skipped language coverage as passed.
Register shared installed-language dispatch in `consumer_registry.py`; use
explicit imports so the fast import audit can follow its owners. Do not construct
test module names from strings to bypass dependency review.
