# Transit CLI design reviews

[Design items](../README.md)

This item reviews how Transit communicates through the terminal. The
[public CLI reference](../../../reference/cli.md) owns implemented behavior;
these reviews describe proposed changes.

**Current review:** [D2 — One query console and conventional configuration](D2.md).

| Review | Focus | Status | Outcome or next decision |
| --- | --- | --- | --- |
| [D1](D1.md) | Error wording, selective context, help hierarchy and diagnostic detail | Accepted | Concise errors and command help selected, implemented and locally qualified in M28 |
| [D2](D2.md) | Interactive and batch SQL, dot commands, defaults, discovery and environment overrides | Accepted | Console direction and flags selected; server defaults plus one project/home/system YAML file; merged system/home/project rc settings; implementation remains outstanding |

Command structure, local lifecycle and recovery derive from the completed
[CLI milestone](../../roadmap/M24.md). [M28](../../roadmap/M28.md) owns this
presentation change and its qualification, preserving the earlier evidence.
D2 selects a further command/configuration change; it does not extend either
completed milestone's implementation or qualification claims.
