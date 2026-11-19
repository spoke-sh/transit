# Compiled test host v1

Definition: `transit.test-host.v1.2026-11-19.compiled-cases`.

The executable schema and validation owner is
[`TestHostProtocol.zig`](../packages/transitc-workspace/src/TestHostProtocol.zig).
This is a local tooling boundary between the compiler's test command and a
compatible Transit executable. It is not a database listener or a source-language
execution API. An incompatible change replaces this definition and all consumers.

The compiler resolves sources offline and compiles the complete suite before
starting any case. Each case gets an owned temporary directory. The compiler
writes `case.json`, then starts the selected executable with
`__transit_test_case_v1 DIRECTORY`. The host receives only canonical SQL steps,
typed expectations, case/SQL identities, and a bounded case budget. It receives
no source repository, connection settings, application credentials, or callbacks.
The host validates the complete request before initializing its private database.

Both the host definition and current source definition are required. Every SQL
step must be referenced exactly once, in order, except workflow observations,
which have no SQL step. The SHA256 of the steps joined with `;` and newline must
match `sql_digest`. Row schemas use the shared canonical logical descriptor;
expected rows use its exact bound value codec. Both are lowercase hexadecimal
in JSON. Descriptor, row, byte, action, SQL, and observation limits are checked
before execution. No persisted identity defaults to the current definition.

The host executes ordinary statement owners in one fresh, listener-free local
database per case. Existing grants, synchronized-clock requirements, resource
quotas, uncertainty handling, read completion, and joined cleanup remain in force.
The 30-second case cap and five-second cleanup cap cannot be raised by the
request. Source compilation and the 300-second suite budget belong to the caller.
Each request is limited to 64 MiB, each response to 64 KiB, and each side's
transport allocations to 256 MiB. Native host memory and storage retain their
separate 256 MiB caps. Oversized or invalid input cannot start native execution.

The host returns exactly one JSON response on stdout. A valid response binds
the exact request digest, case identity, SQL digest, both definitions, runtime
revision and executable digest to its observations and terminal outcome.
Completed assertion failures differ from incomplete execution. EOF, a killed
process, timeout, malformed output, a changed runtime, or mismatched identities
cannot establish a pass. Child stderr is not a result. This binding detects
incompatible or mismatched results; it does not prove that a malicious host
computed honestly.

The caller joins its child before deleting case storage. It checks deletion on
success and failure, and reports cleanup failure as incomplete. No uncertain SQL
statement is resubmitted as new work. These are disposable test installations;
the host never attaches to a user's existing installation.
