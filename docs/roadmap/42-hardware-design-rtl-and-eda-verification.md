# 42. Hardware design, RTL/netlist verification and EDA evidence

[Roadmap](README.md) · [Standards & Multi-Model #31](https://github.com/spoke-sh/transit/issues/31) · **Status:** Planned

Let applications capture elaborated Verilog/SystemVerilog RTL, gate/transistor
netlists, simulation waveforms and 2.5D physical VLSI layouts as versioned
relational, graph and spatial datasets; verify structural, timing, physical and
security invariants using incremental Datalog fixpoints; and track attributable
RTL-to-silicon evidence across branches and tape-out milestones.

This is planned workload and verification-lifecycle work. Transit provides the
versioned multi-model database, incremental deductive/spatial engine and
provenance boundary; it does not bundle a proprietary logic synthesizer, SPICE
analog solver, commercial foundry PDK or FPGA vendor bitstream generator in the
kernel.

The supporting [on-demand specialization research workflow](on-demand-specialization-research.md)
defines experiments for Nix-packaged RTL tools, captured analysis evidence and
Platform execution. Physical FPGA specialization is a separate optional profile;
RTL ingestion, CPU simulation and synthesis do not establish device deployment.

## Prerequisites and ownership

Consume [managed computations and bitemporal queries](12-sql-and-dataflows.md),
[Worst-Case Optimal Joins and bounded execution](13-data-structures-and-performance.md),
[first-class strings and symbol dictionaries](14-vectorized-strings-and-search.md),
[AOT compilation](15-data-centric-compilation-and-specialization.md),
[2.5D `.layout_manhattan`, `.scene_dag`, `.topo_arc` and `COCHAIN_FIELD` spatial/continuum types](17-geospatial-and-spatio-temporal-computing.md),
[foreign EDA, netlist and waveform projections](18-multi-model-and-foreign-relations.md),
[waveform pyramids and continuum simulation kernels](19-game-asset-pipelines-and-simulation-streaming.md),
[branches and structural `DIFF`](20-branches-merges-and-restore.md),
[formal semantics](22-formal-semantics-and-correspondence.md),
[security-barrier and spatial RLS](27-control-and-policy-plane.md),
[retained investigations](28-published-resources-and-investigations.md),
[reviewed publication](29-reviewed-data-collaboration.md),
[Board spatial and layout layer inspection](30-board-reimplementation.md),
[calibrated scientific arrays](35-scientific-arrays-and-measurements.md),
[software and build evidence](39-software-build-and-deployment-evidence.md),
[constrained planning and optimization](40-constrained-planning-and-optimization.md)
and [deductive rules, Datalog fixpoints and equivalence graphs](41-deductive-rules-datalog-and-equivalence-graphs.md).
Reuse the [data lifecycle](../../contracts/DATA_LIFECYCLE_V1.md),
[SQL results](../../contracts/SQL_RESULTS_V1.md),
[investigation](../../contracts/INVESTIGATION_V1.md) and
[publication](../../contracts/PUBLISHED_RESOURCE_V1.md) contracts.

Applications and qualified EDA workers own RTL elaboration, synthesis scripts,
PDK rule decks and place-and-route solvers. Transit owns schema/graph/layout
storage, incremental Datalog/spatial evaluation, IP compartmentalization,
branch diffing and immutable design-to-artifact provenance.

## Delivery sequence

1. **Model elaborated RTL, hierarchy and netlists as versioned tables and graphs.**
   Define canonical relational and SQL/PGQ property-graph schemas across design
   stages (`RTL`, `GateNetlist`, `PhysicalNetlist`, `ExtractedParasitics`) with
   stable identities: modules, parameterized hierarchical instances (reusing
   `.scene_dag` prototype dictionaries and path interning), ports, bit-accurate
   wires/buses, net equivalence classes ([M41](41-deductive-rules-datalog-and-equivalence-graphs.md)
   Union-Find), sequential elements (`always_ff` registers, latches and SRAM
   macros with explicit clock, reset and enable pins), combinational logic cones
   (`always_comb`, primitive gates, muxes and arithmetic units), FSM state tables
   and security/clock/power domain annotations. Qualify foreign ingestion in
   [Milestone 18](18-multi-model-and-foreign-relations.md) for synthesized
   Verilog/RTLIL JSON, structural Verilog, `LEF`/`DEF` and `SPICE` netlists,
   preserving source file/line/span provenance ([M16](16-document-profiles-and-gateway-exchange-lifecycle.md)).
2. **Verify RTL and netlist security, CDC and structural invariants via Datalog ([M41](41-deductive-rules-datalog-and-equivalence-graphs.md)).**
   Express hardware verification suites as stratified, incremental Datalog
   computations over the design graph:
   - *Hardware Information Flow Tracking (IFT) and Taint Analysis:* Propagate
     confidentiality and integrity labels from designated secret sources
     (cryptographic keys, fuse blocks, privileged CSRs) across combinational and
     sequential edges, verifying that tainted signals never reach untrusted
     outputs, shared buses or debug/JTAG ports without passing through an
     authorized sanitizer/zeroizer gate, and emitting shortest counterexample
     signal-path witnesses.
   - *Clock-Domain Crossing (CDC), Reset-Domain Crossing (RDC) and Structural Lint:*
     Identify asynchronous domain crossings lacking qualified multi-stage
     synchronizers, gray-code handshakes or glitch-free barriers, alongside
     combinational dependency loops, unbuffered high-fanout nets, undriven/multi-driven
     wires and dead logic cones.
   - *Topological Logic Depth and Static Timing Bounds:* Compute logic-level
     depths and conservative arrival/slack bounds across combinational cones using
     [M41's](41-deductive-rules-datalog-and-equivalence-graphs.md) monotonic
     tropical $(\max, +)$ and $(\min, +)$ lattice fixpoints.
3. **Unify 2.5D physical layout verification (`DRC` / `LVS`), thermal/IR-drop fields and constrained P&R.**
   Connect [Milestone 17's](17-geospatial-and-spatio-temporal-computing.md)
   `.layout_manhattan` storage (exact integer nanometer grids $\delta_{\text{grid}} = 1\,\text{nm}$,
   layer/purpose tables, $90^\circ/45^\circ$ polygons, $D_4$ dihedral instance
   transforms and `(nx, ny, dx, dy)` cell arrays from `GDSII`/`OASIS`/`LEF`/`DEF`)
   with incremental DBSP and [M41](41-deductive-rules-datalog-and-equivalence-graphs.md)
   deductive queries:
   - *Incremental Design Rule Checking (`DRC`):* Evaluate minimum width, spacing,
     enclosure, density and antenna rules over Manhattan spatial tiles and
     `.topo_arc` boundaries, recomputing only affected tiles and hierarchical
     fanout cones on cell edits.
   - *Layout Versus Schematic (`LVS`):* Match extracted physical device and net
     connectivity graphs against the golden RTL/SPICE schematic via WCOJ cyclic
     pattern matching and Union-Find net equivalence, reporting exact port/net/device
     discrepancies.
   - *Continuum Thermal / IR-Drop Fields and Constrained Optimization:* Bind
     steady-state and transient power-grid IR-drop and thermal `COCHAIN_FIELD`
     (`.float_zfp`) distributions ([M17](17-geospatial-and-spatio-temporal-computing.md),
     [M35](35-scientific-arrays-and-measurements.md)) and floorplanning,
     placement and routing optimization runs ([M40](40-constrained-planning-and-optimization.md))
     to the exact netlist and layout `SnapshotId`.
4. **Synchronize digital/mixed-signal simulation waveforms with netlist queries.**
   Project digital simulation traces (`VCD`, `FST`) and analog `SPICE` outputs
   into compressed multi-state signal transition tables (`0`, `1`, `X`, `Z` and
   bus words) and [M19](19-game-asset-pipelines-and-simulation-streaming.md)/[M35](35-scientific-arrays-and-measurements.md)
   `WAVEFORM` columns with cycle/picosecond time axes. Support temporal `AS OF JOIN`
   and windowed assertion queries joining live or recorded signal transitions
   with the structural netlist and Datalog taint/CDC witnesses to pinpoint the
   exact clock cycle and module instance where an X-propagation, bus contention
   or security-assertion failure originated.
5. **Enforce IP compartmentalization, branch-isolated ECOs and RTL-to-silicon provenance.**
   - *Branch-Isolated ECOs and Structural `DIFF`:* Evaluate Engineering Change
     Orders (ECOs), late timing fixes and agent-proposed RTL edits
     ([M46](46-declarative-language-context-and-synthesis.md)) on zero-copy
     branches ([M20](20-branches-merges-and-restore.md)), running incremental
     DBSP Datalog/DRC/LVS checks and inspecting key-aligned netlist/layout `DIFF`
     and layer overlays in [Board](30-board-reimplementation.md).
   - *IP & PDK Security Boundaries:* Apply [Milestone 27's](27-control-and-policy-plane.md)
     security-barrier RLS and 2.5D Spatial RLS so SoC integrators can verify
     top-level interconnect, timing and taint-boundary contracts against
     black-box/grey-box third-party IP macros without disclosing restricted
     internal transistor layouts or foundry PDK internals.
   - *Tape-Out Evidence Chain ([M39](39-software-build-and-deployment-evidence.md)):*
     Bind RTL source revisions, synthesis/P&R tool digests, constraint files
     (`SDC`), gate netlists, physical `GDSII`/`OASIS` masks, simulation coverage
     and Datalog/DRC/LVS verification results into an immutable provenance graph,
     catching unattested netlist modifications (hardware Trojans) or stale
     sign-off checks before publication.

## First acceptance journey

An application ingests an elaborated cryptographic peripheral + bus fabric RTL
design alongside its placed-and-routed `DEF`/`GDSII` layout and a `FST`/`VCD`
simulation trace at a pinned `SnapshotId`. A Datalog verification suite detects
an unsanitized key-register taint leak across a debug multiplexor and an
unsynchronized clock-domain crossing, returning the exact module/wire witness
paths and the simulation cycle where tainted bits appear on the debug bus. On a
branch, an engineer applies an RTL/ECO fix gating the debug path and inserting a
2-FF synchronizer; incremental DBSP recomputation clears both Datalog violations,
verifies DRC/LVS cleanliness on the updated layout tiles, and binds the passing
evidence to the reviewed candidate ([M29](29-reviewed-data-collaboration.md)).

## Completion evidence

- Verify RTL/netlist ingestion, hierarchy elaboration, Union-Find net connectivity
  and Datalog IFT/taint, CDC/RDC, combinational-loop and logic-depth queries
  against independent reference EDA/Datalog oracles across parameterized modules,
  bus slices, reconvergent fanout and multi-clock domains.
- Compare incremental DBSP recomputation after RTL module edits, ECO net rewires
  and shared layout cell edits against full finite re-verification for Datalog
  security rules, Manhattan `DRC` (width/spacing/enclosure) and `LVS` graph
  matching, charging high-fanout global net edits (`clk`, `VDD`/`VSS`) explicitly.
- Exercise digital/mixed-signal waveform joins (`0`/`1`/`X`/`Z` states, clock
  edges, glitch windows and X-propagation traces) against independent simulation
  oracles, plus incomplete/truncated trace handling and budget refusals.
- Challenge forged or stale synthesis/DRC/LVS sign-off attestations, unattested
  gate-level netlist insertions (hardware Trojan negative controls), incomplete
  fixpoint prefixes and unauthorized attempts to read RLS-protected hard-macro
  internals through spatial or Datalog side channels.
- Record ingestion throughput, `.layout_manhattan` and netlist compression ratios,
  incremental vs. batch verification latency, WCOJ LVS matching memory, warm
  allocations and Board layout/witness inspection responsiveness.

## Primary references

- [OpenTitan Hardware Security & DV Methodology](https://opentitan.org/book/doc/security/)
  and [Google XLS (Accelerated HW Synthesis)](https://google.github.io/xls/) for
  open-source silicon security verification, taint/information-flow guarantees
  and declarative IR analysis.
- [Yosys RTLIL](https://yosyshq.readthedocs.io/projects/yosys/en/latest/yosys_internals/formats/rtlil_rep.html),
  [LEF/DEF](https://coriolis.lip6.fr/doc/lefdef/lefdefref/lefdefref.html) and
  [OASIS (`SEMI P39`)](https://store-us.semi.org/products/p03900-semi-p39-oasis-open-artwork-system-interchange-standard)
  for structural RTL, placement/routing and hierarchical Manhattan layout
  representations.
