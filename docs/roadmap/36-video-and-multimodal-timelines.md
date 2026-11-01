# 36. Video and synchronized multimodal timelines

[Roadmap](README.md) · **Status:** Planned

Let applications retain video, audio, sensor intervals, transcripts and annotations
as aligned, versioned evidence. A user can find an event, inspect the supporting
frames/samples, compare interpretations and export an authorized bounded interval
without decoding an entire recording or losing source attribution.

This milestone is planned. Existing binary values, image/spatial types and
stream transports do not establish video ingestion, decoding or playback.

## Prerequisites and ownership

Consume [Streams](06-streams-queues-and-durable-runtime.md),
[Document/container profiles](16-document-profiles-and-gateway-exchange-lifecycle.md),
[foreign readers](18-multi-model-and-foreign-relations.md),
[audio and asset cooking](19-game-asset-pipelines-and-simulation-streaming.md),
[shared measurements](35-scientific-arrays-and-measurements.md),
[policy](27-control-and-policy-plane.md) and
[published investigations](28-published-resources-and-investigations.md).
Use the [data lifecycle](../../contracts/DATA_LIFECYCLE_V1.md),
[SQL results](../../contracts/SQL_RESULTS_V1.md) and
[serving boundary](../../contracts/SERVING_V1.md); consult the
[query](../handbook/reference/queries.md),
[Arrow](../handbook/reference/arrow.md) and
[reactive](../handbook/reference/reactive.md) public owners before projection.

The foreign owner supplies bounded container parsing, M19 supplies waveform/DSP
and derived asset mechanisms, and this milestone owns temporal media semantics
and qualified caller journeys. Model execution and annotations consume
[ML/AI](37-ml-ai-and-experiment-provenance.md) only when that profile is qualified;
ordinary captured-media inspection does not require a model.

## Delivery sequence

1. **Define media identities and temporal interpretation.** Bind asset revision,
   track, codec/configuration, rational time base, decode and presentation times,
   duration, edit mappings, color/orientation and sample/frame coordinates.
   Represent variable frame rate, discontinuities and encoder priming explicitly.
   Alignment maps between media, sensor and wall-clock domains have versioned
   offsets/drift/uncertainty; equal timestamp numbers do not imply synchronized
   observations. Source byte ranges remain tied to exact captured content.
2. **Index encoded media before selective decoding.** Preserve original encoded
   objects and bounded packet/chunk indexes, random-access points and decode
   dependencies. Qualify an explicit container/codec matrix beginning with one
   common recording profile. A requested frame may require earlier reference
   frames; charge all dependency decoding to the budget. Missing references or
   truncated streams produce explicit incomplete coverage, never invented frames.
3. **Implement bounded media operations.** Provide interval selection, frame/sample
   extraction, resampling/alignment and summary generation through shared typed
   operations. Bound compressed bytes, decoded surfaces, pending work and output
   across cancellation and early close. Define ownership of CPU/GPU buffers and
   decoder lifetime when an optional accelerator is used. Reuse summaries and
   thumbnails only under their exact source/interpretation and current access.
   Rendering cost is measured against viewport/output size and decode work.
4. **Version annotations and derived tracks.** Relate transcript spans, regions,
   detections, labels and embeddings to original temporal/spatial coordinates.
   Preserve human/model authorship, model/transform identity, quality/confidence
   and supersession. An inferred event does not replace a captured observation.
   Alignment edits and model updates invalidate dependent outputs according to
   M35's declared dependency extent; completed older revisions remain attributable.
5. **Deliver shared query and application consumption.** Combine temporal media
   selection with relational/spatial filters and structural search. Expose bounded
   manifests, timelines and results through existing clients and publication
   owners; define any missing transport contract before UI use. A player cursor,
   thumbnail or metadata index confers no permission to source bytes. Recheck
   buffered disclosure and exported clips, including decoder preroll outside the
   requested interval. Public exports require their own authorized operation.

## Acceptance and qualification

Use a manufacturing recording: locate a vibration event, inspect synchronized
camera/audio intervals and a maintenance record on one explicit investigation
basis, then compare a successor annotation. The UI must show gaps, clock
uncertainty, estimated labels and source coverage distinctly. Board inspection
remains read-only over public operations; playback and application annotation
actions retain separately scoped authority.

- Independent decoders and timing oracles verify reordered frames, variable rate,
  track offsets, discontinuities, priming, seeking and boundary frames.
- Exercise malformed containers, missing reference frames, enormous declared
  dimensions, corrupt indexes, interrupted capture and unsupported codecs under
  fixed memory/CPU/IO limits. Finishing a clip does not prove capture completeness.
- Test recovery of the original capture/extraction identity, cancellation while
  decoding, restart before publication, source deletion and revocation after
  buffering. Verify no partial output is installed as a complete derived track.
- Compare authorized and denied metadata, thumbnails, transcripts and byte-range
  disclosure. Keep hidden tracks and unauthorized preroll out of returned output.
- Record seek/first-frame/completion latency, decoded and transferred bytes,
  resident surfaces, synchronization error and mixed-load control responsiveness.
  Browser playback checks and server codec checks are separate evidence.

## Primary reference

[WebCodecs](https://www.w3.org/TR/webcodecs/) describes key chunks, presentation
timestamps, codec configuration and explicit media resource lifetimes. Pin the
actual browser/server profiles used in qualification; this reference does not
select a universal codec or promise zero-copy decoding.
