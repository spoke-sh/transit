# Working on SQL session checks

Follow [test instructions](../../AGENTS.md). Read the
[session contract](../../../contracts/SQL_SESSION_V1.md). `contracts.py` checks the
boundary; `native.py` and `local.py` exercise real owners; `security.py`,
`resources.py` and `faults.py` retain their independent obligations.

Use `just test::sql-sessions` and the affected installed SQL tasks. Preserve
session/statement identities, current disclosure rights, explicit completion,
cancellation versus unknown outcomes and bounded resource cleanup. A transport
disconnect does not authorize replaying SQL. Retain the original saved operation
through lost replies and replacement. Keep elapsed measurements separate from
correctness budgets and from the owning runtime's expiry policy.
