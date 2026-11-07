import type { ReactElement } from "react";
import Layout from "@theme/Layout";
import Link from "@docusaurus/Link";
import Statement from "./Statement";
import StoryJourney from "./StoryJourney";
import { stories, type Story } from "../stories";
import "../css/home.css";
import "../css/stories.css";

export default function StoryPage({ story }: { story: Story }): ReactElement {
  return (
    <Layout title={story.title} description={story.description}>
      <main className="transit-story-page">
        <header className="transit-story-intro">
          <Link className="transit-text-link" to="/">
            ← Transit handbook
          </Link>
          <p className="transit-kicker">{story.title}</p>
          <h1>{story.headline}</h1>
          <p className="transit-story-deck">{story.description}</p>
          <a className="transit-text-link" href={`#${story.steps[0]?.id}`}>
            Follow the story <span aria-hidden="true">↓</span>
          </a>
        </header>
        <StoryJourney route={story.route} />
        <div className="transit-story-preparation">
          <p>{story.premise}</p>
          <Link className="transit-text-link" to={story.preparation.to}>
            {story.preparation.label} <span aria-hidden="true">↗</span>
          </Link>
        </div>
        <div className="transit-story-layout">
          <nav className="transit-story-nav" aria-label="Story chapters">
            <p className="transit-kicker">IN THIS STORY</p>
            <ol>
              {story.steps.map((step, index) => (
                <li key={step.id}>
                  <a href={`#${step.id}`}>
                    <span aria-hidden="true">{String(index + 1).padStart(2, "0")}</span>
                    {step.label}
                  </a>
                </li>
              ))}
            </ol>
            <Link to="/guides/introduction">Browse the documentation ↗</Link>
          </nav>
          <article aria-label={story.title}>
            {story.steps.map((step, index) => (
              <section
                key={step.id}
                id={step.id}
                className="transit-story-step"
                aria-labelledby={`${step.id}-title`}
              >
                <div className="transit-story-copy">
                  <p className="transit-kicker">
                    {String(index + 1).padStart(2, "0")} / {step.label.toUpperCase()}
                  </p>
                  <h2 id={`${step.id}-title`}>{step.title}</h2>
                  {step.paragraphs.map((paragraph) => (
                    <p key={paragraph}>{paragraph}</p>
                  ))}
                  <Link className="transit-text-link" to={step.reference.to}>
                    {step.reference.label} <span aria-hidden="true">↗</span>
                  </Link>
                </div>
                <div className="transit-story-evidence">
                  {step.statement && (
                    <Statement
                      example={step.statement}
                      caption={step.caption ?? "From the task-dataset walkthrough."}
                    />
                  )}
                  <div className="transit-story-observation">
                    <p className="transit-kicker">
                      {story.intent === "target"
                        ? "WHAT THIS UNLOCKS"
                        : step.statement
                          ? "WHAT TO OBSERVE"
                          : "WHAT THIS UNLOCKS"}
                    </p>
                    <p className="transit-story-value">{step.observation.value}</p>
                    <p>{step.observation.detail}</p>
                  </div>
                </div>
              </section>
            ))}
          </article>
        </div>
        <footer className="transit-story-next">
          <p className="transit-kicker">KEEP EXPLORING</p>
          <h2>The next question is yours.</h2>
          <div className="transit-actions">
            <Link className="button button--primary" to={story.next.to}>
              {story.next.label} <span aria-hidden="true">↗</span>
            </Link>
            {[stories.dataset, stories.model, stories.queries]
              .filter((other) => other.route !== story.route && `/${other.route}` !== story.next.to)
              .map((other) => (
                <Link key={other.route} className="transit-text-link" to={`/${other.route}`}>
                  {other.title} <span aria-hidden="true">↗</span>
                </Link>
              ))}
          </div>
        </footer>
      </main>
    </Layout>
  );
}
