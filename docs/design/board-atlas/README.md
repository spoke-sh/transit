# Board: relief atlas design study

Status: **proposed visual design, not implemented UI**. These thirteen generated
concept images explore a shared browser and map workspace. At a distance,
pending inputs form a shallow relief atlas. As the viewer approaches a process,
the terrain flattens into readable cards and recorded relationships.

The images use synthetic data, not a deployment or a captured Transit transcript.
They are review material, not assets to embed in the Board executable.
[Board's design contract](../../BOARD.md) remains authoritative.

**Latest review: [Fabric at 100 to 100,000 processes](SCALE.md).** Four new
studies extend the accepted queue-count fabric with stable groups, summaries
and age pins. They are future-scale concepts, beyond M9's bounded runtime.

The [inbox, outbox and age study](FABRIC.md) compares count-based wells,
age-driven depth, and the transition to a flat inspector. Study 7 supplies the
visual baseline for the scale exploration. All age values are synthetic and
require proposed timestamp support. The original six views below remain as the
earlier design.

## Walk through the design

Read the first three images as successive views of the same region. Process 04
stays selected, with 36 pending inputs, generation 3 and state revision 18.
Changing elevation is a presentation transition, not changing backlog.

### 1. Relief overview

![Board map with one hexagonal realm, raised backlog contours, eight process markers and the selected Process 04 inspector.](images/01-relief-overview.png)

The central peak represents Process 04's 36 pending inputs. Processes 07 and 08
sit at zero elevation. The summary describes the eight displayed processes,
not a realm-wide total. Height, selection and lifecycle have separate meanings.

### 2. Process neighborhood

![The same eight-process map with shallow relief, exact pending labels, a resource association and one recorded delivery relationship.](images/02-neighborhood.png)

As relief decreases, process labels and relationships appear. The dashed
association to Resource 12 differs from the directed delivery to Process 05.
Neither spatial proximity nor an association grants authority.

### 3. Flat investigation

![A flat map with process cards and a bounded Input 41 to Turn 18 to Output 7 to destination Input 22 journey.](images/03-flat-investigation.png)

At reading distance, terrain yields to flat cards and evidence. Destination
admission remains distinct from completion of the destination's turn.
The inspector preserves the same identity and values across the descent.

### 4. Browser overview

![Board's browser mode with an eight-row process table, Process 04 selected, and the same inspector with a Show on map action.](images/04-browser-overview.png)

The browser supports scanning, sorting and precise navigation. Switching to Map
keeps the selection and filters. The miniature locator connects the two modes.

### 5. Process document

![Process 04 document showing mailbox accounting, a state association, a recorded journey and retained-history coverage.](images/05-process-document.png)

A readable document exposes the exact facts behind the map. Its mailbox
accounting is 120 admitted minus 80 consumed minus 4 cancelled, leaving 36 pending.
The resource link opens separately authorized inspection.

### 6. Stale observations and coverage

![Board map with an interrupted-connection notice, explicitly stale pending values, an outside-page hatch and a retained-history gap.](images/06-coverage-gap.png)

This is an existing viewer's last observation after a transport failure.
Unknown coverage is not zero. Known denial is a different state: it removes the
affected data, including relief and relationships; it is not represented by
stale terrain or identifiable silhouettes.

## Review and handoff

- [Interaction and evidence specification](INTERACTIONS.md): zoom, navigation,
  relief encoding, accessibility, read boundaries and implementation questions.
- [Exact generation prompts](prompts.json): built-in image generation, the
  shared visual specification and targeted refinement prompts.
- [Fabric and age prompts](fabric-prompts.json): the follow-up exploration and
  its zoom refinement.
- [Scale prompts](scale-prompts.json) and [synthetic fixture](scale-fixture.json):
  four populations, grouping, aggregation and individual outliers.
- [Board frontend](../../../apps/transit-board-web/README.md): current implemented
  browser behavior and verification commands.

The selected PNGs are original generated outputs, copied into this directory
without raster post-processing. Subsequent screens used the selected overview
as a visual reference. Image generation is nondeterministic; the prompts record
intent, not a byte-reproducible build.

These are independent raster compositions, not frames captured from a working
camera. Small placement, font and control differences remain. In particular,
the close view illustrates semantic disclosure at approximately the same
framing; the exact zoom trajectory, anchored selection, numeric height ratios,
contrast, responsive behavior and keyboard interaction need a real prototype.
The written specification takes precedence over pictorial geometry.

The single-realm header is a scope label. Its generated chevron does not propose
multi-realm discovery. Search, the mode switch and map navigation are proposed
controls, not claims about the current frontend.

## Synthetic reference scene

All counts are for one displayed page in realm 1. Process aliases are explanatory
labels, not Station registry names. IDs and counts below are design examples,
not wire fixtures or evidence of a valid execution schedule.

| Label | PID | Lifecycle | Pending inputs | Map location |
| --- | --- | --- | --- | --- |
| Process 01 | 1 | Running | 18 | Upper left |
| Process 02 | 2 | Running | 12 | Upper middle |
| Process 03 | 3 | Suspended | 8 | Upper right |
| Process 04 | 4 | Running | 36 | Center, selected |
| Process 05 | 5 | Running | 6 | Right |
| Process 06 | 6 | Running | 4 | Lower right |
| Process 07 | 7 | Running | 0 | Lower left |
| Process 08 | 8 | Terminated | 0 | Left |

The page sum is 84 pending inputs. Process 04's associated Resource 12 has
revision 9. Its example observation is position 240, policy revision 7, retained
from position 160. Resource observations must retain their own source basis in
an implementation; this shared illustration footer is not a global snapshot.

The journey illustrates recorded links from PID 4 input 41 through turn 18 and
output 7 to PID 5 input 22. Identifiers are not timestamps or journal positions.
No duration, throughput, worker-liveness or external-outcome claim is implied.

## Milestone relationship

This study is grounded in the completed [M2 inspection boundaries](../../roadmap/M2.md)
and [M7 state-resource inspection](../../roadmap/M7.md). The scale follow-up is
rebased onto completed [M9 Station qualification](../../roadmap/M9.md), using
its authorized framework evidence as a candidate grouping basis. It does not reopen their
exit criteria or claim completion of a new interface.

Implementation is not scheduled by this design-only change. Select a new
numbered milestone using the [roadmap sequencing rule](../../roadmap/README.md#maintaining-the-sequence)
before implementing the canvas or expanding the read profile. The study does
not require Station for a generic view, multi-realm discovery, deployment topology
or application value decoding. Station grouping is optional; aggregate discovery
and the larger populations remain outside the implemented inspection profile.
