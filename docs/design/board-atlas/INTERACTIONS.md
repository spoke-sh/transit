# Board atlas: interaction and evidence specification

Status: proposed technical appendix to [D1](../D1.md).
Return to the [design review index](../README.md) for the review sequence and outcomes.
The existing [Board contract](../../BOARD.md), [frontend limits](../../../apps/transit-board-web/README.md)
and [API bounds](../../../apps/transit-board/README.md#bounds-and-observations)
remain the implemented baseline.

## One workspace, two views

Browse and Map share the selected realm/PID/resource, filters, focused journey
and observation state. A table row opens the same inspector as a map marker.
Open process promotes that inspector to a document. Show on map returns to its
spatial context. Browser Back restores the preceding selection and viewport.

Shareable URLs identify the view, selected public identity and bounded filters;
they never contain credentials, payloads or a serialized graph. URLs do not
grant access. A proposed viewport parameter needs route validation and size
bounds before implementation. Do not introduce local storage or an offline
cache as a side effect of remembering the camera.

Search starts with the displayed, authorized page and says so. Opening an exact
ID reauthorizes through the public read surface. Search across all processes,
resource bodies or realms is not implied by the mock search field.

## Visual grammar

| Element | Meaning |
| --- | --- |
| Single hexagonal outline | Layout frame for the configured realm |
| Circular marker | Process, with its PID available in the inspector |
| Rectangular plate or card | Independently authorized state resource |
| Elevation | Selected measured quantity, initially pending inputs |
| Amber ring or row rule | Current selection |
| Labeled lifecycle badge | Recorded lifecycle; not worker liveness |
| Solid directed connection | A specific recorded causal/delivery relationship |
| Dashed connection labeled Association | A recorded association, not causal ownership |
| Hatch at the displayed-page boundary | Coverage limit, with no implied hidden entities |
| Explicit break in a journey | Missing retained evidence; no inferred continuation |

The warm-paper/deep-ink palette follows the current frontend's tokens. Reserve
amber for selection and attention, always with a label or shape. A high hill is
not inherently unhealthy. Avoid road scenery, compass directions and terrain
outside the measured scope; this is a schematic map with no physical geography.

Typography, search, navigation, evidence panels, menus and focus states remain
flat and readable at every scale. Generated imagery is a design reference;
production text and controls must be real, selectable interface elements.

## Relief encodes a named quantity

For one process, pending input is the implemented expression:
admitted minus consumed minus cancelled. Preserve exact integer semantics.
A sum is meaningful only over the disclosed process set from a compatible
observation basis. Label it Displayed page; never imply all-realm coverage.

At overview scale, propose a linear height mapping with fixed units for the
current layer and view. Heights at process anchors correspond to their own
counts. The selected count and a labeled scale remain available. Do not
renormalize heights to the tallest visible process when the viewer pans:
that would make an unchanged process appear to grow.

Contour shapes between anchors provide visual continuity only. They are not
additional samples, inferred processes or an integral of backlog over area.
They must not create peaks for unobserved objects, turn zero into positive
height, or cross a coverage boundary. A prototype should compare separate
non-overlapping mounds with a clipped interpolated surface to establish which
is easier to read honestly.

Layer candidates beyond pending inputs need separate definitions:

| Candidate | Proposed quantity | Qualification needed |
| --- | --- | --- |
| Process density | Count of displayed processes in a fixed layout bin | Label bin size and covered set; layout distance is not deployment distance |
| Unresolved effects | Count in specifically defined unresolved phases | Define included phases; closed-unknown must not be counted as still open |
| State associations | Authorized associations per process | Distinguish edge count from unique resource count; preserve resource grants |

None is a health score, resource utilization measure or capacity forecast.
Switching a layer keeps horizontal coordinates and selection stable and
relabels the units. Unavailable evidence makes a layer unavailable, not zero.

## Inbox, outbox and age follow-up

The subsequent [scale study](../D3.md) keeps D2's Figure 7 queue-count fabric as its
baseline. It adds a proposed hierarchy of stable presentation groups, disjoint
aggregate marks and separate outlier pins at 100 to 100,000 synthetic processes.
Its grouping and aggregation rules extend this interaction intent; M9's bounded
completion does not establish those capacities or a bulk inspection API.

[D4](../D4.md) extends the scale studies to one billion synthetic processes and
proposes a roomier interface: a full-width surface, one header and combined
legend, with inspection shown on selection. Its
[information placement](../D4.md#give-each-piece-of-information-one-place)
updates the persistent panels in the earlier images while preserving critical
coverage/freshness state and access to detailed evidence.

The [fabric exploration](../D2.md) extends this initial height-only study with
an inbox shoulder and an independently readable outbox well. It compares count
depth plus age tint with an explicit age-depth layer. The interface uses Inbox
as the mailbox display name. All illustrated ages are synthetic: current
outbox inspection has no per-output source-commit timestamp. The follow-up
specifies unavailable/stale age, scoped extrema and the evidence needed before
implementation. Both upward and downward relief flatten on approach.

## Semantic descent

| Stage | Surface and camera | Detail disclosed |
| --- | --- | --- |
| Overview | Shallow oblique relief with readable contours | Major process anchors, exact selected count, coverage and layer scale |
| Neighborhood | Camera approaches top-down; relief amplitude decreases | More labels, independently selectable relationship layers |
| Detail | Zero height, directly top-down | Flat cards, source-linked values and a bounded journey |
| Document | Conventional page with location context | Exact evidence, history coverage, associations and explicit byte reads |

Zoom changes both magnification and a presentation-only relief factor. As that
factor approaches zero, the scale explicitly reports that height is flattened
for reading; numeric values remain unchanged. Do not animate this transition
as if work is draining or a worker is moving.

Keep each process's horizontal layout anchor stable during refresh. Zoom
around the pointer or selected focus point and compensate the camera while
elevation collapses so that the selected marker does not jump. Place new
objects without continuously running a force layout. Do not collapse an
unrelated whole realm into a new layout when a detail card opens.

Reveal labels with collision handling and stable thresholds. Selected labels
take precedence. Use a small threshold separation on entry/exit to avoid
flicker at a zoom boundary. Keep cards at readable screen sizes rather than
scaling ordinary text to illegibility.

Animation timing and zoom thresholds are prototype questions, not promises
made by these still images. Reduced motion uses immediate stage changes
while preserving identity, position and keyboard focus.

## Navigation

- Scroll or pinch zooms around the focal point; background dragging pans.
  The default interaction moves the viewport, not the process.
- Visible zoom in, zoom out, fit selection and fit displayed page controls
  provide alternatives to gestures. The locator becomes useful when the
  viewport covers only part of the displayed layout.
- Click or keyboard activation selects and opens the inspector. A separate
  Open process/resource action opens the document.
- Right-click offers Open details, Show recorded journey, Focus and Copy link.
  The same actions are available through a normal labeled menu button.
- Escape closes a menu or inspector with focus restored to its trigger.
  Browser Back restores the previous route instead of being swallowed by
  the canvas.
- Filters and a layer picker change presentation, not Transit authority.
  Refresh rereads evidence; it is never a retry of process work.

Node dragging, connecting ports, editable payloads, restart/terminate controls
and a global history scrubber are outside this proposal. Ordinary tab controls
and history pagination remain available through the document.

## Coverage, staleness and access

Freshness and completeness are independent. A fresh page may be partial, and a
complete page can subsequently become stale. Keep the source position, policy
revision and retained boundary inspectable; show separate observation bases
for process, resource and journey reads. A shared footer must not collapse
multiple sources into a purported atomic snapshot.

| State | Presentation and behavior |
| --- | --- |
| Authorized page with more results | Label displayed-page coverage; loading another page is explicit |
| Healthy empty response | Explicit empty result in that scope, without an invented landform |
| Transport interruption in an already open view | Mark all retained observations stale, including badges and totals; use bounded backoff |
| Pagination cut expired | Request an explicit refresh; do not merge old and new pages |
| Retained history gap | Show the missing interval/boundary and stop unsupported causal paths |
| Known process or resource denial | Clear affected values, terrain, endpoints, counts and search results immediately |

The stale concept is not permission to serve cached data to a new request when
current authorization cannot be checked. A resource denial may leave an
independently authorized process view available. Do not disclose the denied
resource's shape, label, count or former edge as a spatial placeholder.

The hatched band represents the boundary of this query window. Its size does
not encode how many additional or unauthorized objects exist. A future map must
not infer a realm's physical extent from a page of results.

## Evidence and data budget

All data still comes through the Board API and public Transit client. No raw
Ursula, provider API, application handler or second history store is introduced.
Map geometry, picking indexes and any aggregation are bounded derived state.

The implemented baseline returns at most 16 inspection facts per page, eight
state entries/associations per page and 32 journey edges. Start a prototype
within these bounds. Camera zoom is not authorization for recursive discovery,
prefetching every PID or an automatic full-realm scan.

Observation refresh retains the frontend's bounded requests, hidden-tab pause,
five-second polling and error backoff. Camera animation must not trigger reads
on every frame. A stationary map should not require a continuous render loop.
Any budget expansion needs an explicitly qualified contract.

Do not infer a causal edge from nearby positions, matching payloads or similar
names. Link displayed relationships to their source records. Associations do
not establish ownership or access. Lifecycle running does not establish an
executing worker; output delivery establishes admission, not destination turn
completion. Closed-unknown remains an unknown external outcome.

## Accessibility and responsive behavior

Every investigation must be reachable in Browse with semantic tables, headings,
links and textual statuses. The map also needs a bounded keyboard-selectable
object list and explicit navigation controls; an accessible browser view alone
does not excuse inaccessible map controls.

Keep focus and selection across polling and mode changes. Use visible focus,
non-color cues, reduced motion and sufficient contrast. At narrow widths,
promote the inspector to its own page or an accessible sheet rather than
squeezing two columns. WebGL failure leaves Browse and the selected document
usable. These behaviors are specified, not tested by the raster images.

## Renderer decision and implementation gate

React Three Fiber is a candidate for the relief surface and camera. An
orthographic scene with bounded geometry and HTML overlays is the first
approach to evaluate. The final flat view can retain the same scene anchors;
accessible document components stay outside the graphics renderer.

This design does not select or install a new dependency. Compare text/picking
alignment, pointer-centered zoom, reduced-motion behavior, render-on-demand,
WebGL failure and bundled size before committing to a renderer. Respect the
existing standalone executable's asset bounds and prohibition on runtime CDN
or font downloads.

Before implementation, scope a new numbered roadmap milestone. Its evidence
should include:

1. Same identity, filters, viewport and browser history across Browse and Map.
2. Fixed counts while relief flattens, stable positions during updates and
   correct zero/missing representations.
3. Bounded discovery, geometry and request work under zoom/pan/slow readers.
4. Revocation clearing relief, labels, aggregates, edges and search without
   leaking denied identities.
5. Explicit stale, expired-cut and retained-gap states using the real API.
6. Keyboard, reduced-motion, responsive and renderer-failure behavior.
7. The real embedded Board binary within asset bounds, with no new runtime
   downloads or inspection-load regression.

The current design PR establishes visual intent only. Existing M2/M7 evidence
does not qualify the proposed canvas.
