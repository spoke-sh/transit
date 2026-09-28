# Board grammar design reviews

[Design items](../README.md)

Board grammar brings the [Atlas](../board-atlas/README.md) and
[Console](../board-console/README.md) explorations into one reactive interface
language. SQL, visual composition and typed APIs describe the same definitions;
a monochrome visual vocabulary makes their structure, changes and evidence
legible. Board is the first application of that language, with a downstream
reactive application workflow as the reuse test.

**Current review:** [D2 — A bounded monochrome implementation profile](D2.md).

| Review | Focus | Status | Outcome or next decision |
| --- | --- | --- | --- |
| [D1](D1.md) | SQL-to-visual mapping, theme dimensions, reactive composition and migration experience | In review | Monochrome direction and vector Atlas redraws requested; historical review acceptance remains open |
| [D2](D2.md) | Explicit M23 shell, grammar, evidence and operator interaction profile | Implementation selection | Engineering choices recorded for implementation; real visual review and browser qualification remain open |

The user selected monochrome as the intended reactive UI aesthetic and asked
for all Atlas D1–D8 figures to be redrawn as vector wireframes. The new studies
are collected in [Atlas D10](../board-atlas/D10.md); D1–D9 retain their historical
outcomes. That direction does not accept every earlier interaction or prove
implementation.

[M23](../../roadmap/M23.md) owns implementation and qualification after M19–M22.
[Reactive applications](../../REACTIVE_APPLICATIONS.md) owns the proposed system
model, application lifecycle and migration semantics. This directory owns the
interface review, not a second architecture or wire specification.

## Supporting material

- [D1 visual studies](D1.md#visual-studies) and [SVG sources](images/).
- [Reproduction script](render.py) for all four D1 studies and the Atlas redraws.
- [Synthetic review fixture](d1-fixture.json).
- [Candidate Board declarations](board.proposed.sql): non-executable design text.
- [Atlas D10](../board-atlas/D10.md): all 34 figures redrawn, with original mappings.

Follow the shared [template](../TEMPLATE.md) and linear review workflow; the next
review in this item is D3.
