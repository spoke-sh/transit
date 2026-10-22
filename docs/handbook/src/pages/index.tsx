import type { ReactElement } from "react";
import Layout from "@theme/Layout";
import Link from "@docusaurus/Link";

const concepts = [
  ["Define data", "Tables, key-value data, Documents and schemas", "/reference/data-model"],
  ["Compute from data", "Interactive, captured and maintained results", "/reference/queries"],
  [
    "Govern its use",
    "Permissions, retention and execution budgets",
    "/reference/data-model#govern-access-and-lifetime",
  ],
] as const;

const references = [
  ["SQL", "Syntax, types and query profiles", "/reference/sql"],
  ["Transit CLI", "Serve, install, query and recover", "/reference/cli"],
  ["SQL sessions", "Local and remote HTTP/TLS clients", "/reference/sql-sessions"],
  ["PostgreSQL and MySQL", "Connect, authenticate and query", "/reference/database-protocols"],
  ["OpenAPI", "HTTP operations and schemas", "/reference/openapi"],
  ["AsyncAPI", "Reactive channels and messages", "/reference/asyncapi"],
  ["Flight SQL", "Arrow clients and compatibility", "/reference/flight"],
  ["Language SDKs", "Native types, turns and ownership", "/reference/sdks"],
  ["Contracts", "Wire definitions and schema downloads", "/reference/contracts"],
] as const;

export default function Home(): ReactElement {
  return (
    <Layout
      title="Documentation"
      description="Transit is programmable data infrastructure for applications: tables, key-value data, collaborative documents, queries and durable execution."
    >
      <main className="docs-home">
        <section className="docs-hero" aria-labelledby="hero-title">
          <div>
            <p className="eyebrow">TRANSIT DOCUMENTATION</p>
            <h1 id="hero-title">Programmable data infrastructure.</h1>
            <p className="hero-description">
              Store and query tables, key-value data and collaborative documents. Use durable
              execution to transform data and coordinate work around it.
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
            <p className="profile-note">Define data · Compute results · Inspect progress</p>
          </div>
          <div
            className="model-diagram"
            aria-label="Describe data, computation and policies; Transit validates and executes supported operations; inspect definitions, results and progress."
          >
            <div className="model-node">
              DESCRIBE<span>Data · computation · policies</span>
            </div>
            <div className="model-connector">validate and apply ↓</div>
            <div className="model-node model-authority">
              TRANSIT<span>Store · query · execute</span>
            </div>
            <div className="model-connector">observe results ↓</div>
            <div className="model-node">
              INSPECT<span>Definitions · results · progress</span>
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
            <h2>From a schema to useful data.</h2>
            <p>
              Create a Table, write records, compute an answer and evolve its schema. Read the same
              data from independent sessions.
            </p>
            <Link to="/guides/quickstart">Follow the quickstart →</Link>
          </div>
          <div>
            <p className="eyebrow">OBSERVE AND EXTEND</p>
            <h2>Know what your declaration produced.</h2>
            <p>
              Inspect published definitions, complete results and recorded progress. Add custom
              workers when your data needs application-defined behavior.
            </p>
            <Link to="/reference/data-model#inspect-whether-a-declaration-is-being-fulfilled">
              Understand the lifecycle →
            </Link>
          </div>
        </section>
        <section className="reference-section" aria-labelledby="reference-title">
          <div className="section-heading">
            <h2 id="reference-title">Find your interface</h2>
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
