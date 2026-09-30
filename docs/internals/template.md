# Technical account template

Use the [scientific standard](standard.md) for new or substantively revised
architecture explanations and technical studies. Replace prompts with evidence
and reasoning; identify missing evidence explicitly. UI/UX reviews retain their
own [review structure](../design/TEMPLATE.md).

## Question, scope and status

State the problem and boundary. Identify the implemented mechanism or
experimental analysis and record its source revision, applicable interface/profile
and date where needed. Label hypotheses separately from established behavior.
Link the current user reference, contract and implementation owners; link earlier
proposals and historical records from their separate owners.

## Model and assumptions

Define terms, state and transitions. State trust, failure, storage, time,
concurrency and resource assumptions. Explain what the model excludes.

## Claims and mechanism

State each claim precisely and explain the mechanism or derivation that supports
it. Include failure and recovery paths, bounds and possible counterexamples.
Distinguish safety, liveness, complexity and empirical claims where applicable.

## Evidence and reproduction

Link evidence for each claim. Record methods, commands, revision/toolchain,
environment, fixtures/seeds, measurements and observed results. Identify
planned, failed, skipped and incomplete checks separately from passing evidence.
Explain how evidence from a model or experiment applies to the implementation.

## Alternatives and tradeoffs

Compare plausible alternatives against explicit criteria. Distinguish measured
costs from estimates and engineering judgment. Explain the selected choice.

## Limits and open questions

Record uncertainty, threats to validity, unsupported cases and unresolved
hypotheses. State what evidence would change the conclusion.

## References and review

Link primary sources and precise repository owners. Record review outcomes and
superseding accounts when they exist; acceptance does not establish implementation.
