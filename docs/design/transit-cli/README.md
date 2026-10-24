# Transit CLI design reviews

[Design items](../README.md)

This item reviews how Transit communicates through the terminal. The
[public CLI reference](../../handbook/reference/cli.md) owns implemented behavior;
these reviews describe proposed changes.

**Current review:** [D5 — Preserve drafts when canceling history search](D5.md).

| Review | Focus | Status | Outcome or next decision |
| --- | --- | --- | --- |
| [D1](D1.md) | Error wording, selective context, help hierarchy and diagnostic detail | Accepted | Concise errors and command help selected, implemented and locally qualified in M28 |
| [D2](D2.md) | Interactive and batch SQL, dot commands, defaults, discovery and environment overrides | Accepted | Console direction and flags selected; server defaults plus one project/home/system YAML file; merged system/home/project rc settings; implemented and qualified in M29; dot commands only, simplified recovery and preserved input transcript; timing follow-up remains |
| [D3](D3.md) | Grammar/catalog completion, contextual Tab, history navigation, Esc clearing and general undo | Accepted | Implemented; native units, terminal peers and real TLS session completion pass; manual terminal/SSH delivery remains unverified |
| [D4](D4.md) | Immediate filtering, stable selection and background metadata refresh without loading placeholders | Accepted | Implemented; shared lexical units and delayed-response terminal checks pass; retained previews require current evidence before insertion |
| [D5](D5.md) | Seeded history filters, draft restoration and consistent Esc cancellation | Accepted | Implemented; PTYs cover draft/filter separation, cursor restoration, acceptance, delayed completion cancellation and undoable Ctrl-C clearing |

Command structure, local lifecycle and recovery derive from the completed
CLI milestone. M28 owns this
presentation change and its qualification, preserving the earlier evidence.
M29 implements D2's further command/configuration change; it does not extend either
completed milestone's implementation or qualification claims.
