import Link from "@docusaurus/Link";
import { useId } from "react";

const studies = [
  {
    name: "An operations desk",
    promise: "Explain what needs attention, and why.",
    description:
      "Orders arrive, priorities change, and work moves between people. Keep the records, the question you ask of them, and the work that follows connected through explicit identities and outcomes.",
    stages: [
      {
        title: "Keep the context",
        object: "Orders · events · notes",
        detail: "Choose Tables, Streams and Documents for their different kinds of change.",
        link: "/reference/data-model",
        label: "Choose the data",
      },
      {
        title: "Ask what matters",
        object: "Open work by priority",
        detail: "Query a source snapshot. Inspect what the answer includes before refreshing it.",
        link: "/reference/sql",
        label: "Explore SQL",
      },
      {
        title: "Coordinate the work",
        object: "Claim · process · settle",
        detail: "Use leased Queue work and inspect the outcome of each accepted operation.",
        link: "/reference/streams#queue-payloads-and-leased-work",
        label: "Follow a work item",
      },
    ],
    boundary:
      "Available building blocks: Table SQL, Streams, Queue operations and Document APIs. The application connects them and chooses when to refresh its answers.",
  },
  {
    name: "A reproducible investigation",
    promise: "Return to the evidence behind an answer.",
    description:
      "A result matters after the tab closes. Keep its computation and source basis inspectable so a later reader can distinguish the answer you obtained from a new answer over changed data.",
    stages: [
      {
        title: "Select a basis",
        object: "Definitions · source versions",
        detail: "Bind a computation to the data and interpretation it actually reads.",
        link: "/reference/data-model#describe-definitions-data-and-dependencies-separately",
        label: "Understand the basis",
      },
      {
        title: "Capture an answer",
        object: "A complete retained result",
        detail: "Use captured queries when accepted computation must outlive a session.",
        link: "/reference/queries",
        label: "Choose a query lifetime",
      },
      {
        title: "Inspect it later",
        object: "Result · provenance · freshness",
        detail: "Read the recorded result under current permissions and check its source evidence.",
        link: "/reference/data-model#inspect-whether-a-declaration-is-being-fulfilled",
        label: "Inspect the evidence",
      },
    ],
    boundary:
      "Captured results and source evidence have supported interfaces. Shared investigations, writable branches and reviewed publication are a separate proposed experience.",
  },
  {
    name: "A recoverable integration",
    promise: "Carry work forward without forgetting its past.",
    description:
      "An external service responds, a worker disappears, or a reply arrives late. Preserve the original request and observed outcome so recovery can continue from what is known.",
    stages: [
      {
        title: "Record an observation",
        object: "External response · capture",
        detail: "Keep the observed response available to later processing and replay.",
        link: "/reference/connectors",
        label: "Explore connectors",
      },
      {
        title: "Advance the workflow",
        object: "Input · state · output",
        detail: "Commit a Station turn's state, consumed input and recorded outputs together.",
        link: "/reference/processes",
        label: "Understand a turn",
      },
      {
        title: "Recover the outcome",
        object: "Intent · attempt · evidence",
        detail:
          "Inspect original work after interruption. Preserve uncertainty when an external outcome is unknown.",
        link: "/guides/applications",
        label: "Build a worker",
      },
    ],
    boundary:
      "Station and connector APIs provide these boundaries. The application supplies workflow logic and external retry policy; replay does not dispatch the effect again.",
  },
] as const;

function ConnectionDrawing() {
  const gradient = useId();
  return (
    <svg className="atlas-drawing" viewBox="0 0 720 135" aria-hidden="true" focusable="false">
      <defs>
        <linearGradient id={gradient} x2="0.8" y2="1">
          <stop stopColor="currentColor" stopOpacity="0.14" />
          <stop offset="1" stopColor="currentColor" stopOpacity="0.02" />
        </linearGradient>
      </defs>
      <g fill="none" stroke="currentColor" strokeWidth="0.7" opacity="0.38">
        {Array.from({ length: 9 }, (_, i) => (
          <path
            key={i}
            d={`M38 ${48 + i * 5} C154 ${48 + i * 4} 170 ${108 - i * 11} 262 ${79 - i * 4} S365 ${12 + i * 11} 436 ${51 + i * 4} S551 ${115 - i * 4} 680 ${42 + i * 6}`}
          />
        ))}
      </g>
      <g stroke="currentColor" strokeWidth="0.8">
        <path
          d="M54 65 103 45 155 62 106 82Z M54 74 106 91 155 71 M54 83 106 100 155 80"
          fill={`url(#${gradient})`}
        />
        <path
          d="M324 101 324 63 340 56 340 101 M348 101 348 45 364 38 364 101 M372 101 372 62 388 55 388 101"
          fill={`url(#${gradient})`}
        />
        <path
          d="M568 50 617 36 657 55 608 69Z M568 62 608 81 657 67 M568 74 608 93 657 79"
          fill={`url(#${gradient})`}
        />
      </g>
      <path
        className="atlas-thread"
        d="M38 68 C164 68 192 35 260 59 S352 102 431 70 S571 44 680 69"
        fill="none"
        stroke="var(--ifm-color-primary)"
        strokeWidth="1.8"
      />
      <g fill="var(--ifm-background-color)" stroke="var(--ifm-color-primary)" strokeWidth="1.4">
        <circle cx="106" cy="65" r="3" />
        <circle cx="357" cy="83" r="3" />
        <circle cx="612" cy="56" r="3" />
      </g>
    </svg>
  );
}

export default function PossibilityAtlas() {
  return (
    <div className="possibility-atlas" aria-label="Applications you could build with Transit">
      <p className="atlas-introduction">
        Three ways the same foundations become useful. Open a study to follow the connections.
      </p>
      {studies.map((study, index) => (
        <details key={study.name} name="transit-application-studies" open={index === 0}>
          <summary>
            <span className="atlas-number">0{index + 1}</span>
            <span>
              <strong>{study.name}</strong>
              <span>{study.promise}</span>
            </span>
            <span className="atlas-toggle" aria-hidden="true">
              +
            </span>
          </summary>
          <div className="atlas-study">
            <p>{study.description}</p>
            <ConnectionDrawing />
            <div className="atlas-stages">
              {study.stages.map((stage, position) => (
                <div key={stage.title}>
                  <span className="handbook-label">
                    0{position + 1} / {stage.title}
                  </span>
                  <h3>{stage.object}</h3>
                  <p>{stage.detail}</p>
                  <Link to={stage.link}>
                    {stage.label} <span aria-hidden="true">↗</span>
                  </Link>
                </div>
              ))}
            </div>
            <p className="atlas-boundary">
              <span>In practice</span>
              {study.boundary}
            </p>
          </div>
        </details>
      ))}
      <p className="atlas-caption">
        Illustrative applications. Each link leads to the supported interfaces and their limits.
      </p>
    </div>
  );
}
