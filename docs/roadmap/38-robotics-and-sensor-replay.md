# 38. Robotics, industrial sensing and calibrated replay

[Roadmap](README.md) · **Status:** Planned

Let applications reconstruct a machine or robot episode from captured sensor
data, software, maps, calibration and coordinate transforms, then evaluate a
candidate interpretation against the same evidence. Start with offline incident
analysis and calibrated sensor replay; physical control remains a separately
authorized application/effect profile.

This is planned. Streams, trajectories and durable execution alone establish
neither synchronized sensor fusion nor hard real-time or safety-critical control.

## Prerequisites and ownership

Consume [Streams/Queues](06-streams-queues-and-durable-runtime.md),
[temporal computation](12-sql-and-dataflows.md),
[spatial frames and trajectories](17-geospatial-and-spatio-temporal-computing.md),
[foreign readers](18-multi-model-and-foreign-relations.md),
[waveform/DSP and simulation assets](19-game-asset-pipelines-and-simulation-streaming.md),
[branches](20-branches-merges-and-restore.md),
[measurement semantics](35-scientific-arrays-and-measurements.md) and
[multimodal timelines](36-video-and-multimodal-timelines.md).
[ML/AI](37-ml-ai-and-experiment-provenance.md) is a dependency only for learned
perception/evaluation profiles. Reuse the
[data lifecycle](../../contracts/DATA_LIFECYCLE_V1.md),
[retained investigation](../../contracts/INVESTIGATION_V1.md) and
[result](../../contracts/SQL_RESULTS_V1.md) contracts. Follow the public
[Streams](../handbook/reference/streams.md),
[connectors](../handbook/reference/connectors.md) and
[retention](../handbook/reference/retention.md) owners.

Native adapters and deterministic kernels remain Zig-owned. Device drivers,
motion policy, safety interlocks and application-specific controllers stay
outside database authority. Board consumes public read operations; it does not
become a device-control or raw-log authority.

## Delivery sequence

1. **Declare the episode and sensor basis.** Bind device/sensor/channel identity,
   payload schema, sequence epoch, native clock domain, acquisition/publication/
   recording times, firmware/map revisions and capture coverage. Define wrap,
   reset, gap, duplicate, out-of-order and late-data behavior. Absence of a packet
   is not an observed zero measurement. Immutable chunks and offsets preserve
   source bytes and exact capture identity across indexing and compaction.
2. **Version clocks, frames and calibration.** Extend M35 with clock conversion
   models, drift/uncertainty bounds and frame-transform graphs with validity
   intervals. Define missing edges, cycles, interpolation/extrapolation limits
   and ambiguous calibration selection. Retain both raw measurements and derived
   values. A revised calibration or transform creates a new interpretation;
   replay of the original episode retains its original bindings. Distinguish
   rigid poses, unit conversion, sensor intrinsics and measurement covariance.
3. **Qualify capture adapters and aligned reads.** Begin with one MCAP/ROS message
   profile and one industrial waveform profile from the foreign-format owner.
   Preserve channel schemas, log/publish times, sequence evidence and attachments.
   Implement bounded interval and spatial/temporal joins over frames, point
   clouds, poses and signals, with declared nearest/prior/interpolated matching
   and uncertainty policy. Shared numeric timestamps do not prove clock alignment.
4. **Deliver reproducible replay and candidate evaluation.** Freeze a retained
   episode basis, computation and replay parameters; separate replay clock from
   wall time. Record scheduling/order assumptions, checkpoints and output
   coverage. Branch-based calibration, perception or map proposals produce
   attributable candidate results. Classify dependency extent so local corrections
   trigger valid recomputation; recursive estimation or global optimization may
   require replay from an earlier checkpoint or the complete episode.
5. **Keep replay, simulation and actuation distinct.** Recorded device actions
   and outcomes are replay inputs. Replay dispatches no physical commands.
   A later live profile needs explicit destination, current grants, fencing,
   latency/failure requirements and connector reconciliation for uncertain remote
   outcomes. Database cancellation cannot promise physical cancellation.
   Simulated trajectories and model predictions remain labeled derived evidence.

## First acceptance journey

Capture a calibrated vibration signal and synchronized camera/pose interval for
an equipment incident. Find an event, inspect the supporting samples and frames,
then revise calibration on a branch and show exactly which features/events
change. Reopen the original investigation after a worker restart and recover the
same raw basis and interpretation. No device command is sent during replay.

## Completion evidence

- Compare interval selection, transform composition, clock conversion and feature
  outputs with independent oracles, including drift, reset, wrap, reordered
  messages, duplicate packets, gaps and calibration validity boundaries.
- Exercise partial recordings, corrupted indexes, missing transforms, conflicting
  calibrations, excessive interpolation and unknown clock relationships. Report
  incomplete/ambiguous evidence instead of silently aligning or filling it.
- Kill capture/replay workers, lose acceptance replies and interrupt checkpoint
  publication. Recover original identities and complete outputs without splicing
  a newer source basis into the original replay.
- Test retained collections beyond RAM, bounded decode/halo work, backpressure,
  control progress during catch-up, cancellation and revocation after buffering.
- Verify through a recording connector that offline replay emits zero physical
  effects. Application simulation and live-control checks are separate profiles.
- Measure ingest gaps, capture-to-analysis delay, alignment error, replay/catch-up
  rate under continuing input, memory and complete-result latency. Publish the
  actual sensor, schema, clock and deployment profiles qualified.

## Primary reference

[MCAP format specification](https://mcap.dev/spec) defines channels, schemas,
recording/publication timestamps, sequence counters and indexed chunks. Those
fields provide capture evidence; sensor clock synchronization requires the
additional interpretation contract above.
