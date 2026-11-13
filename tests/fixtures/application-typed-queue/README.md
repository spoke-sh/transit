# Nominal Queue program fixture

RequestId, MachineId and SiteId deliberately share BIGINT representations while
retaining distinct source identities. Imported resource and program modules use
exact signatures. Two explicit sets of Queue, Table, Stream and program names
exercise the same source without sharing durable objects.

The first pipeline accepts request 7 after a Machine lookup. Requests 8 and 9
refuse on an absent and a multiple-row lookup respectively. Request 10 stages an
insert before a later guard refuses; neither the Table row nor Stream output may
survive. The second pipeline independently accepts request 7. CASE, LET and
nullable record projection preserve the MachineId annotation. Source assertions
require exact counters and complete rows; they do not establish Queue emptiness.

The build target installs all five inputs and both pipelines together. The test
target gives success, each refusal and the second named pipeline separate cases,
each in a fresh database under the unchanged 30-second case budget. Every refusal
asserts both zero Table rows and zero Stream rows. The installed build journey
checks the combined scenario and retained recovery; isolated cases do not replace
that shared-installation proof.

`expected.sql` is independently authored scalar SQL with explicit bindings,
instruction order and atomic boundaries. It contains no runtime source domains
or sidecar. Ordinary SQL can submit scalar values to these resources: source
annotations do not authenticate a sender or prove referenced-row existence.
The explicit lookup and guard supply the application's existence check.

Compiler/grammar checks establish source checking and lowering. The application
build/test journeys own installed execution, frozen offline dependencies,
source-free execution, original-token recovery, restart and current-rights denial.
This public synthetic fixture does not qualify effects, protected data, migrations,
replacement, simulated time or a provider.
