# Monochrome console structure

Proposed in [board-console D5](D5.md). This is a reusable wireframe vocabulary,
not a shipped component library or a selected visual theme. D3's compact shell
and D4's search/realm placement remain the foundation.

## The working frame

At the review viewport of **1440 × 960**, use a 56 px header, a 208 px sidebar
and 32 px content gutters. Transit stays at the left of the header, Search
Transit at its center and the realm at the right. The Workspace/Operations
area toggle stays above the contextual navigation. Workspace contains Atlas,
Explore, Connections, Sources, Sinks and Activity, in that order.

The content hierarchy is **destination → selected object → local view**. A
destination opens a paged collection; following an object's name replaces that
collection with its detail. Back restores the collection's filter, page and
focus if its read basis still qualifies. A stale continuation requires refresh.
Do not keep an extra object rail permanently beside the existing sidebar.
Global search and authorized dependency links can enter the same detail directly.

Use one page title and one local action group. A definition detail has its
identity and accepted revision below its title, followed by Definition,
Dependencies, Changes and Activity. These are local views of the selected
object. Definition opens in Form with SQL one selection away; Dependencies
offers a textual list and optional diagram of the same references. Explore
keeps D4's SQL-first worksheet and is not converted into a definition form.

## Drawing vocabulary

| Element | Review rule | Meaning |
| --- | --- | --- |
| Canvas | White; black text and strokes | Neutral structure |
| Spacing | 8 px unit; 16/24/32 px grouping | Proximity establishes hierarchy |
| Page title | 24 px, bold | Current task or object |
| Section title | 16 px, bold | Local grouping |
| Body / controls | 14–16 px | Essential information |
| Metadata | 12–13 px, black | Secondary identity/basis; never low-contrast opacity |
| Identifiers / SQL | Monospace, 13–16 px | Literal names and values |
| Rules | 1 px; 2 px for active underline | Separate rows/areas without nested cards |
| Navigation selection | 3 px black marker plus bold name | Current destination |
| Tabs | Bold name plus solid underline | Current local view |
| Primary local action | Black fill, white text | One action of greatest local importance |
| Secondary action | White fill, black outline | Available local action |
| Unavailable action | Dashed outline plus nearby reason | No action is available; never infer this from dimming alone |
| Dependency edge | Solid line, arrow and verb | Declared reference in arrow direction; no implied traffic |
| Proposed difference | Dashed enclosure plus Before/After labels | Draft, not accepted state |
| Evidence sequence | Solid connector only between recorded linked stages | Recorded ordering within that work item |
| Missing evidence | Broken connector with explicit gap label | Unknown or unavailable history |

Dashed marks always have a local label; they are not a universal protocol state.
Selection and operational status use different channels: an active black button
does not mean healthy, authorized or complete. Write **Not observed**, **Partial**,
**Unavailable** and **Closed · outcome unknown** as text. Do not use traffic-light
dots, decorative metric cards, shadows, gradients or unlabeled icon actions.
The compact area toggle is inherited from D3 and retains its named choices.

D4's reviewer-selected pale-grey provisional result surface is a narrow exception
inside Explore. D5 does not reuse grey to mean disabled, historical, uncertain
or unhealthy. It also does not change D4's result timing design.

## Collections and details

Collections have one search/filter row, a table and bounded-page navigation.
Show what distinguishes an object: connection family and endpoint; source read
target; sink write target and input binding. A count describes the returned page
or explicitly qualified catalog coverage. Do not imply a realm-wide total from
a page, a hidden dependency count or an arbitrary loaded prefix.

Definition is the primary content. An **Observed** section follows the accepted
definition, with its own observation time and evidence link. Avoid placing a
permanent inspector next to every form. Opening Activity replaces the definition
with the same activity view filtered to this object. Its filter can be removed
explicitly to return to realm activity; it never silently expands scope.

Activity has different material: recorded work and change outcomes. A row opens
one identified work item with its recorded stages, outcome, source basis and
retained coverage. Definition dependencies and causal evidence use different
views even when they reference the same object.

## Interaction and smaller screens

These are implementation requirements to qualify later, not behavior proved by
the drawings:

- Object names, evidence links and breadcrumbs are links. Tabs and local actions
  are buttons with visible keyboard focus. Selection also has a textual or
  accessible selected state; essential meaning does not depend on hover.
- The area's choices have accessible Workspace/Operations names. At coarse
  pointer sizes, controls have at least 44 px effective targets even when their
  visible outlines are 36 px high. Escape closes temporary overlays and returns
  focus to their trigger. Back returns focus to the originating row.
- Polling does not reorder the row under focus. Offer newly observed Activity
  records as a **New records** action; selecting it reads a fresh bounded page.
  This is bounded polling, not D4 Live execution or a durable subscription.
- Below a proposed 1100 px breakpoint, collapse the sidebar behind a named menu
  and stack supporting definition/evidence columns. Below 720 px, table rows
  become labeled record summaries; keep name, outcome and observation basis.
  Secondary metadata moves into detail, never off-screen without a route to it.
- At 200% zoom and narrow widths, SQL can scroll within its own region; page
  controls and explanatory text reflow. Long identifiers can wrap or have an
  explicit copy/full-value affordance. Truncation must not hide identity collisions.
- Realm changes stop old reads and clear protected content before resolving the
  new scope. Known denial clears it immediately. A failed authorization refresh
  hides protected rows; it does not retain them under a stale label. Draft and
  uncertain-operation handling follow D3 and D2, with no implicit submission.

## Review checklist

Can a reader identify the current task, the exact selected object, what is
defined, what is merely drafted, and what has actually been observed? Can they
follow a dependency or outcome without interpreting color? Does each action
name its consequence, and does missing evidence remain missing? Those are the
questions these wireframes should answer before styling begins.
