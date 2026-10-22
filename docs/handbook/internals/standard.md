# Scientific standard for Internals

Internals explains how Transit works and why its design is justified. Its
standard is scientific: a reader must be able to identify the claim, examine
its assumptions, trace its evidence, and reproduce or challenge the reasoning.
This standard applies to architecture explanations wherever they live, as well
as technical studies in this section. Plans belong in [Roadmap](../../roadmap/README.md),
and UI/UX proposals/reviews belong in [Design](../../design/README.md). Those records
retain explicit status; they do not become accounts of implemented behavior.

Scientific rigor does not require academic language or a theorem for every
decision. Use plain language, precise definitions and the method appropriate
to the claim. A test result, a model proof and an engineering judgment support
different conclusions; identify which one you have.

## Audience and ownership

The [guides and reference](../../README.md) explain how to build with and operate
Transit: supported behavior, commands, configuration, compatibility and recovery.
Internals develops the mechanisms, models, assumptions, alternatives and evidence
behind that behavior for readers evaluating or changing the system.

Keep each explanation with its owner. Internals links to current interface
references and exact contracts instead of defining another version of them.
User-facing documentation includes the assumptions and limits needed to use a
feature safely; readers need not reconstruct those rules from a research record.
Both audiences receive accurate, evidence-based documentation. The distinction
is purpose and depth, not permission to weaken correctness in user guides.

## What a technical account must establish

| Element | Required content |
| --- | --- |
| Question and scope | The problem, affected boundary, applicability and explicit exclusions |
| Status and provenance | Implemented mechanism or experimental analysis; source revision, date and interface/profile where relevant; hypotheses and cited historical/proposed claims distinguished from established behavior |
| Model and assumptions | Defined terms and notation; state, actors, transitions, trust, ordering, time, storage and failure assumptions used by the argument |
| Claims | Precise, scoped statements of invariants, safety, liveness, complexity or measured behavior; conditions that would falsify them |
| Mechanism and reasoning | How the design establishes each claim; ownership, lifetime and resource bounds; failure paths and recovery; diagrams tied to the same model |
| Evidence | Direct links to contracts, implementation, executable tests, proof artifacts, measurements or primary external sources; separate observation, deduction and hypothesis |
| Reproduction | Commands, pinned toolchain/revision, fixtures or seeds, environment and analysis needed to repeat an experiment or proof; expected observations and recorded outcomes |
| Alternatives and tradeoffs | Relevant alternatives, the criteria used to compare them, costs and reasons for the choice; identify judgment when evidence is unavailable |
| Limits and open questions | Counterexamples, uncertainty, unsupported cases, threats to validity, missing evidence and the work that could resolve them |

Use these elements in the shape that fits the subject. A short architecture
explanation can link to an owned experiment or proof instead of repeating it.
Mark an inapplicable element with a reason; do not invent measurements, formalism
or citations to fill a template. The [technical account template](template.md)
is a starting point, not a substitute for an argument.

## Match conclusions to evidence

For correctness arguments, state preconditions and invariants, then explain
initialization, each relevant transition and recovery. Separate safety from
liveness; identify fairness, availability and time assumptions needed for
progress. State the modeled state space and the correspondence between a model
and the implementation. A bounded model check or selected theorem does not
establish correctness of every execution.

For measurements, record workload and data sizes, hardware and topology,
configuration, toolchain, sampling method, repetitions and units. Distinguish
setup from steady-state cost, cold from warm runs, throughput from latency,
and retained bytes from resident memory. Report variation and failed runs;
label a single observation as such. Compare alternatives under equivalent
conditions and explain confounders. A target, estimate or synthetic fixture is
not a measured result or a service guarantee.

For design choices, show how the mechanism follows from the stated constraints
and which competing approaches were considered. If the choice depends on an
untested hypothesis, say so and identify the observation that would change it.
For external claims, cite the primary paper, specification or implementation
and the relevant version or section. Attribute borrowed ideas and distinguish
them from Transit-specific conclusions.

The [verification reference](../reference/verification.md) defines the evidence
boundaries. The [proof ledger](../../../tests/README.md) owns executed commands,
results and qualification limits. Link to that evidence; an unchecked box,
planned command, skipped run or incomplete check never counts as a pass.

## Review and maintenance

New and substantively revised technical accounts must meet this standard.
Reviewers check whether the argument supports its claims, whether its evidence
can be inspected, and whether its limits remain visible to the reader. Site
checks validate coverage, links and rendering; they do not certify scientific
correctness. Do not describe a document as peer-reviewed without an actual
recorded review.

The [history archive](../../history/README.md) retains mixed proposals and past
implementations. Linking that source material does not retroactively validate
it against this standard. Preserve their dates, decisions and outcomes; identify superseded
claims and link their current owners. When a claim changes, update the owning
explanation and evidence together, keeping the original observation attributable
to its revision. Carry user-relevant consequences into the usage reference.
