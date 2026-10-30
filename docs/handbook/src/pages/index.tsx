import type { ReactElement } from "react";
import Layout from "@theme/Layout";
import Link from "@docusaurus/Link";

const concepts = [
  [
    "Declare data & types (τ ⊥ κ ⊥ ε)",
    "Tables, Documents, KV, Streams, physical codecs, collations and 5-state cell provenance",
    "/reference/data-model",
  ],
  [
    "Query & maintain with Fuze",
    "Vectorized SQL, point-in-time snapshots, recoverable jobs and incremental views",
    "/reference/queries",
  ],
  [
    "Govern & activate with Station",
    "Scoped policy_epoch permissions, unlimited-by-default retention, workflows and connectors",
    "/reference/architecture",
  ],
] as const;

const references = [
  ["Architecture", "Three-plane system model and boundaries", "/reference/architecture"],
  ["SQL & Fuze", "Syntax, 5-state types and query profiles", "/reference/sql"],
  ["Transit CLI", "Serve, install, query and recover", "/reference/cli"],
  ["SQL sessions", "Local and remote HTTP/TLS clients", "/reference/sql-sessions"],
  ["PostgreSQL and MySQL", "Wire-compatible database gateways", "/reference/database-protocols"],
  ["Flight SQL & ADBC", "Zero-copy Arrow interchange", "/reference/flight"],
  ["OpenAPI & AsyncAPI", "HTTP serving and reactive watches", "/reference/openapi"],
  ["Language SDKs", "Native types, turns and ownership", "/reference/sdks"],
  ["Internals", "Storage (.tseg), Fuze, DBSP and formal proofs", "/internals"],
] as const;

export default function Home(): ReactElement {
  return (
    <Layout
      title="Documentation"
      description="Transit is a declarative, versioned multi-model database, vectorized/incremental query engine (Fuze), and durable execution runtime (Station) written in Zig."
    >
      <main className="docs-home">
        <section className="docs-hero" aria-labelledby="hero-title">
          <div>
            <p className="eyebrow">TRANSIT HANDBOOK</p>
            <h1 id="hero-title">Declarative database, query engine & durable runtime.</h1>
            <p className="hero-description">
              Declare Tables, Key-Value state, collaborative Documents and Streams with orthogonal
              types, encodings and collations. Query with <code>Fuze</code> across five-state cells
              and versioned snapshots, and coordinate stateful workflows and recorded external
              effects with <code>Station</code>.
            </p>
            <div className="hero-actions">
              <Link className="button button--primary button--lg" to="/guides/quickstart">
                Create your first dataset →
              </Link>
              <Link
                className="button button--outline button--secondary button--lg"
                to="/reference/data-model"
              >
                Explore the data model
              </Link>
            </div>
            <p className="profile-note">
              Control & Policy Plane · Direct Data & Fuze Query Plane · Station Process & Effect
              Plane
            </p>
          </div>
          <div
            className="model-diagram"
            aria-label="Control and Policy Plane governs the Direct Data and Fuze Query Plane and the Station Process and Effect Plane."
          >
            <div className="model-node">
              CONTROL & POLICY PLANE
              <span>Versioned catalog · τ ⊥ κ ⊥ ε · policy_epoch · retention</span>
            </div>
            <div className="model-connector">validate, fence & bind ↓</div>
            <div className="model-node model-authority">
              DIRECT DATA & FUZE QUERY PLANE
              <span>TransitLog (TWAL1) · .tseg segments · 5-state vectorized SQL</span>
            </div>
            <div className="model-connector">activate deltas & inspect ↓</div>
            <div className="model-node">
              PROCESS, EFFECT & GATEWAY PLANE
              <span>Station turns · recorded connectors · sans-I/O gateways</span>
            </div>
          </div>
        </section>
        <section className="reference-section" aria-labelledby="data-title">
          <div className="section-heading">
            <h2 id="data-title">Start with your data.</h2>
            <Link to="/guides/introduction">What is Transit? →</Link>
          </div>
          <p>
            Describe the data, computation and policies you need, then inspect whether Transit is
            fulfilling that declaration. Each interface defines which lifecycle operations it
            supports.
          </p>
          <div className="reference-grid">
            {concepts.map(([title, description, to]) => (
              <Link key={title} className="reference-card" to={to}>
                <h3>{title}</h3>
                <p>{description}</p>
              </Link>
            ))}
          </div>
        </section>
        <section className="journey-grid" aria-label="Documentation paths">
          <div>
            <p className="eyebrow">DEFINE AND QUERY</p>
            <h2>From a schema to attributable answers.</h2>
            <p>
              Create a Table, write records, compute an answer and evolve its schema. Read the same
              versioned data from independent sessions.
            </p>
            <Link to="/guides/quickstart">Follow the quickstart →</Link>
          </div>
          <div>
            <p className="eyebrow">OBSERVE AND EXTEND</p>
            <h2>Know what your declaration produced.</h2>
            <p>
              Inspect published definitions, complete five-state results and recorded progress. Add
              custom Station workers and connectors when your data needs stateful workflows.
            </p>
            <Link to="/reference/data-model#inspect-whether-a-declaration-is-being-fulfilled">
              Understand the lifecycle →
            </Link>
          </div>
        </section>
        <section className="reference-section" aria-labelledby="reference-title">
          <div className="section-heading">
            <h2 id="reference-title">Explore the seven handbook pillars</h2>
            <Link to="/guides/choose-interface">Compare interfaces →</Link>
          </div>
          <div className="reference-grid">
            {references.map(([title, description, to]) => (
              <Link key={title} className="reference-card" to={to}>
                <h3>
                  {title}
                  <span aria-hidden="true">↗</span>
                </h3>
                <p>{description}</p>
              </Link>
            ))}
          </div>
        </section>
      </main>
    </Layout>
  );
}
