# Board atlas design reviews

[Design items](../README.md)

This design item covers Board’s browser, relief atlas and resource workspace.
Reviews form one linear sequence, read from top to bottom. Each review owns
its question, proposal, visual evidence and recorded outcome.

**Current review:** [D9 — Implemented bounded atlas and Table workspace](D9.md).
**Selected visual direction:** [D2, Figure 7 — Queue-count fabric](D2.md#figure-7-queue-counts-with-age-on-the-well-walls).
The reviewer also endorsed [D5's architecture](D5.md#visual-studies),
[D6's subtle fabric](D6.md#figure-1-processes-in-front-resources-as-landmarks)
and [overhead detail](D6.md#figure-4-zoom-within-resources-reveals-flat-detail).

| Review | Focus | Status | Outcome or next decision |
| --- | --- | --- | --- |
| [D1](D1.md) | Board browser and relief atlas | Reviewed | Two coordinated views; D2 extends the initial inbox-only relief |
| [D2](D2.md) | Board inbox, outbox and age | Accepted in part | Figure 7 selected; age-driven depth remains an alternative |
| [D3](D3.md) | Board fabric at 100–100,000 processes | Reviewed | Scale visuals favored; grouping remains open; D4 extends scale and simplifies the UI |
| [D4](D4.md) | Board fabric at 1 million–1 billion processes | Reviewed | Visual direction endorsed; exact metrics and grouping remain open; D5 adds resources |
| [D5](D5.md) | Table, KV and Document resource cityscapes | Accepted in part | Architectural visuals endorsed; exact metrics/grouping remain open; D7 explores entering the resource |
| [D6](D6.md) | Process/resource emphasis and semantic zoom | Accepted in part | Figures 1 and 4 endorsed; emphasis policy and motion remain open; D7 develops the transition and interior |
| [D7](D7.md) | Neighborhood navigation, resource portals and query workspaces | In review | Review Auto/pinned emphasis, deliberate resource entry, and Canvas/Browse representations of one sample query |
| [D8](D8.md) | Shared-resource venues, past/future growth and readiness | In review | Compare stadium/park/fairground layouts, conditional day-to-decade envelopes, and separate capacity/workload evidence |
| [D9](D9.md) | Implemented bounded atlas and Table workspace | In review | M13 engineering baseline: explicit emphasis/entry and one draft/result; no new reviewer acceptance |

Review status records the design discussion. D1–D8 contain proposed
interfaces and synthetic imagery; none establishes implemented capacity. D9
records the bounded implemented baseline separately from reviewer acceptance.
Delivery scope and qualification belong in the [roadmap](../../roadmap/README.md);
[M13](../../roadmap/M13.md) scopes the query capability, the accepted D5/D6
foundation and D7's data workspace, without retroactively accepting D7 or D8's
still-open interactions. [Board](../../BOARD.md) owns the product boundary and
current inspection contracts.

Follow the shared [review workflow](../README.md#maintaining-the-sequence)
and [template](../TEMPLATE.md) when adding the next review. Keep this table,
the current-review link and previous/next navigation in sync.

## Supporting material

- [Images](images/): thirty-four generated figures, including the thirty-one
  unchanged D1–D7 images and three D8 venue/growth/readiness studies, plus
  two D9 screenshots from the real embedded UI proof.
- [D1 interaction and evidence specification](INTERACTIONS.md).
- [D1 generation prompts](prompts.json).
- [D2 fabric and age prompts](fabric-prompts.json).
- [D3 scale prompts](scale-prompts.json) and [synthetic fixture](scale-fixture.json).
- [D4 million-to-billion prompts](d4-prompts.json) and [summary fixture](d4-fixture.json).
- [D5 resource city prompts](d5-prompts.json) and [resource fixture](d5-fixture.json).
- [D6 canvas transition prompts](d6-prompts.json) and [scene fixture](d6-fixture.json).
- [D7 resource doorway and query prompts](d7-prompts.json) and [sample-query fixture](d7-fixture.json).
- [D8 shared venues and growth prompts](d8-prompts.json) and [participation/growth fixture](d8-fixture.json).

D1–D8 PNGs are design references, generated with the built-in image tool and
stored without raster post-processing. D9 screenshots come directly from the
real browser qualification, also without raster post-processing. They are not embedded application assets.
Review decisions and discussion live in the numbered documents.
