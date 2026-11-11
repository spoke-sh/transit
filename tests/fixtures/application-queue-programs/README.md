# Public Queue program source fixture

The input Queue, state Table, output Stream and ordered program are composed
through exact typed exports. `expected.sql` is an independently authored ordinary
SQL oracle, including instruction order and the atomic boundary. No source
module, build metadata or test assertion is required to execute that SQL.

The first isolated case submits three inputs. ID 7 commits one Table row and one
Stream row. ID 0 is refused before mutation. ID 8 is refused after staging its
Table insert inside the atomic block: neither that row nor an output may survive.
The test waits for one recorded completion and two refusals, then checks exact
Table and Stream rows. The second case recreates
the same names in a fresh database and observes empty state and output.

The application build journey also loses an emitted append reply, settles its
original token, and rejects changed SQL under that token. It suspends the program,
settles its empty acquisition (one additional refused attempt), retains another
input across process restart and resumes that original input.
The application build/test journeys own execution, restart and denial checks.
Grammar and compiler unit checks establish syntax and lowering only. This fixture
uses public data, the installed local database and its real clock. It does not
qualify protected effects, simulated time, migration, replacement or a provider.
