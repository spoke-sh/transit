# Verification index

[Tests](../README.md) · [Contribution rules](AGENTS.md) ·
[Guarantees and limits](../../docs/handbook/reference/verification.md)

Choose a proof by its claim and execution boundary. Formal exploration,
implementation correspondence, modeled faults and physical integration establish
different evidence; an inventory entry or incomplete run is never a pass.

| Owner | Navigate or run |
| --- | --- |
| Formal specifications, finite bounds and correspondence | [Models](models/README.md); `just ci formal` |
| Deterministic implementation schedules and saved regressions | [Simulation](simulation/README.md) |
| Executed production guard controls | [Mutation campaigns](mutations/README.md) |
| Stable invariants and their proof owners | [invariants.json](invariants.json) |
| Reviewed operation, resident and deployment limits | [limits.json](limits.json) |
| Installed SDK scenario definitions | [sdk.json](sdk.json), [caller guide](../../docs/handbook/reference/sdks.md) |
| Finite offered-load matrix | [scale.json](scale.json); `just test::scale` |
| Physical process/transport faults and external profiles | [Fault profile guide](../harness/fault-profiles.md) |
| Check selection, task ownership, clean execution and automatic artifacts | [Runner](../runner/README.md) |
| Historical qualification and retained record identities | [Qualification history](../../docs/history/qualification/verification.md), [results](../evidence/README.md) |

Run `python3 -B tests/runner/launch.py tests/verification/check.py` in
`nix develop` to validate ownership, links, reviewed limits and SDK observations.
The fast check includes it. It checks declarations and drift; actual executions
belong to the named tasks in [suite.json](../runner/suite.json).

`just ci clean --lane formal` repeats the formal lane from committed HEAD.
The task guide and owner README files describe other scopes and their prerequisites.
Current behavior belongs to the public handbook; this index does not carry a
running qualification diary or copies of generated results.
