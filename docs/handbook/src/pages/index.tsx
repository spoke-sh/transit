import type { ReactElement } from "react";
import Layout from "@theme/Layout";
import Link from "@docusaurus/Link";
import HeroArtwork from "../components/HeroArtwork";
import RefractionStory from "../components/RefractionStory";
import "../css/home.css";
import "../css/radiograph.css";

const chapters = [
  [
    "Overview & quickstart",
    "From your first dataset to a working application.",
    "/guides/introduction",
  ],
  [
    "Data model & types",
    "Represent data. Define its structure and meaning.",
    "/reference/data-model",
  ],
  ["Query engine & SQL", "Compute answers and understand their source basis.", "/reference/sql"],
  [
    "Durable execution & apps",
    "Coordinate stateful work and recorded effects.",
    "/reference/station",
  ],
  [
    "Clients & interfaces",
    "Connect through SQL, protocols, the CLI and SDKs.",
    "/guides/choose-interface",
  ],
  [
    "Security & operations",
    "Set boundaries. Inspect progress. Operate the system.",
    "/reference/security",
  ],
  [
    "Internals & verification",
    "Explore the mechanisms and the evidence behind them.",
    "/internals",
  ],
] as const;

export default function Home(): ReactElement {
  return (
    <Layout
      title="Data, computation and policies"
      description="Transit is a declarative, versioned multi-model database, vectorized/incremental query engine, and durable execution runtime, written in Zig."
    >
      <main className="transit-home">
        <section className="transit-hero" aria-labelledby="hero-title">
          <div className="transit-hero-copy">
            <p className="transit-kicker">DATA · COMPUTATION · POLICY</p>
            <h1 id="hero-title">
              Give structure
              <br />
              to change.
            </h1>
            <div className="transit-hero-introduction">
              <p>
                Keep what happened. Turn it into answers that stay <strong>current</strong>. Put
                those answers to work. Transit is bringing data, computation and policies into one
                programmable model for your application.
              </p>
              <p className="transit-implementation">
                Written in Zig. SDKs for a wide range of languages.
              </p>
              <div className="transit-actions">
                <Link className="button button--primary" to="/stories/first-dataset">
                  Create your first dataset <span aria-hidden="true">↗</span>
                </Link>
                <Link className="transit-text-link" to="/stories/data-model">
                  Explore the data model <span aria-hidden="true">↗</span>
                </Link>
              </div>
            </div>
          </div>
          <HeroArtwork />
          <div className="transit-hero-foot">
            <a href="#structure-title">
              Follow the connected workflow <span aria-hidden="true">↓</span>
            </a>
            <a href="#handbook">
              Go to the handbook <span aria-hidden="true">↓</span>
            </a>
          </div>
        </section>
        <RefractionStory />
        <section id="handbook" className="transit-directory" aria-labelledby="handbook-title">
          <div className="transit-directory-heading">
            <p className="transit-kicker">THE HANDBOOK</p>
            <h2 id="handbook-title">Find your way in.</h2>
            <p>
              Start with a dataset, explore an interface, or follow the system down to its
              foundations.
            </p>
            <Link className="transit-text-link" to="/guides/quickstart">
              Follow the quickstart <span aria-hidden="true">↗</span>
            </Link>
          </div>
          <ol className="transit-chapters">
            {chapters.map(([title, description, to], index) => (
              <li key={to}>
                <Link to={to}>
                  <span className="transit-chapter-number" aria-hidden="true">
                    0{index + 1}
                  </span>
                  <div>
                    <h3>{title}</h3>
                    <p>{description}</p>
                  </div>
                  <span className="transit-chapter-arrow" aria-hidden="true">
                    ↗
                  </span>
                </Link>
              </li>
            ))}
          </ol>
        </section>
      </main>
    </Layout>
  );
}
