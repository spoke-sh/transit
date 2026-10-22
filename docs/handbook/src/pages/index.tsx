import type { ReactElement } from "react";
import Layout from "@theme/Layout";
import Link from "@docusaurus/Link";

const references = [
  ["SQL", "Syntax, types and query profiles", "/reference/sql"],
  ["Transit CLI", "Serve, install, query and recover", "/reference/cli"],
  ["OpenAPI", "HTTP operations and schemas", "/reference/openapi"],
  ["AsyncAPI", "Reactive channels and messages", "/reference/asyncapi"],
  ["Flight SQL", "Arrow clients and compatibility", "/reference/flight"],
  ["Language SDKs", "Native types, turns and ownership", "/reference/sdks"],
] as const;

export default function Home(): ReactElement {
  return (
    <Layout
      title="Documentation"
      description="Build applications on Transit: durable processes, state, queries and recoverable work."
    >
      <main className="docs-home">
        <section className="docs-hero" aria-labelledby="hero-title">
          <div>
            <p className="eyebrow">TRANSIT DOCUMENTATION</p>
            <h1 id="hero-title">
              Build on
              <br />
              durable state.
            </h1>
            <p className="hero-description">
              Messages, state and work that survive the worker.
              <br />
              Learn the model. Find the contract. Ship your application.
            </p>
            <div className="hero-actions">
              <Link className="button button--primary button--lg" to="/guides/quickstart">
                Run Transit locally →
              </Link>
              <Link
                className="button button--outline button--secondary button--lg"
                to="/guides/introduction"
              >
                Explore the concepts
              </Link>
            </div>
            <p className="profile-note">Durable processes · Versioned state · Recoverable work</p>
          </div>
          <div
            className="model-diagram"
            aria-label="Applications propose changes; Transit validates and commits them to durable history."
          >
            <div className="model-node">
              YOUR APPLICATION<span>Workers · callers · clients</span>
            </div>
            <div className="model-connector">propose changes ↓</div>
            <div className="model-node model-authority">
              TRANSIT<span>Validate · authorize · commit</span>
            </div>
            <div className="model-connector">accepted history ↓</div>
            <div className="model-node">
              DURABLE STATE<span>Messages · resources · outcomes</span>
            </div>
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
        <section className="journey-grid" aria-label="Documentation paths">
          <div>
            <p className="eyebrow">BUILD</p>
            <h2>Your code, its own worker.</h2>
            <p>
              Compile independently, declare the resources you need, and install with scoped
              permissions.
            </p>
            <Link to="/guides/applications">Build an application →</Link>
          </div>
          <div>
            <p className="eyebrow">OPERATE</p>
            <h2>Know what committed.</h2>
            <p>
              Inspect durable evidence, distinguish admission from completion, and recover the
              original work.
            </p>
            <Link to="/reference/deployment">Deployment and recovery →</Link>
          </div>
        </section>
      </main>
    </Layout>
  );
}
