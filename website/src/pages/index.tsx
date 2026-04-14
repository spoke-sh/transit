import type {ReactNode} from 'react';
import Link from '@docusaurus/Link';
import Layout from '@theme/Layout';

import styles from './index.module.css';

type Tone = 'routeBlue' | 'routeYellow' | 'routeGreen';

const signals: Array<{label: string; title: string; body: string; tone: Tone}> = [
  {
    label: 'Blue Line',
    title: 'One Engine',
    body: 'Transit keeps embedded and server mode on the same storage model instead of splitting the product in two.',
    tone: 'routeBlue',
  },
  {
    label: 'Green Line',
    title: 'Lineage Native',
    body: 'Streams can branch and merge explicitly, so divergence is recorded instead of hidden.',
    tone: 'routeGreen',
  },
  {
    label: 'Yellow Line',
    title: 'Tiered By Design',
    body: 'Remote object storage is a first-class part of the history model, not an afterthought bolted onto local append.',
    tone: 'routeYellow',
  },
];

const tracks: Array<{
  label: string;
  title: string;
  body: string;
  href: string;
  tone: Tone;
}> = [
  {
    label: 'Blue Line',
    title: 'Embedded Track',
    body: 'Start from the shared Rust engine when you want append, replay, branch, merge, and publication in-process.',
    href: '/docs/start-here/embedded-library-first-run',
    tone: 'routeBlue',
  },
  {
    label: 'Green Line',
    title: 'Server Track',
    body: 'Start from the daemon and client surfaces when you want the same semantics through a network boundary.',
    href: '/docs/start-here/server-first-run',
    tone: 'routeGreen',
  },
  {
    label: 'Yellow Line',
    title: 'Reference Track',
    body: 'Move from the public narrative into foundational contracts when you need the exact repo-level constraints.',
    href: '/docs/reference/foundational-docs',
    tone: 'routeYellow',
  },
];

const firstStops: Array<{
  label: string;
  href: string;
  command: string;
}> = [
  {
    label: 'Understand the model',
    href: '/docs/intro',
    command: '/docs/intro',
  },
  {
    label: 'Choose your track',
    href: '/docs/start-here/choose-your-track',
    command: '/docs/start-here',
  },
  {
    label: 'Run the proof path',
    href: '/docs/start-here/embedded-library-first-run',
    command: 'just screen',
  },
  {
    label: 'Read the contracts',
    href: '/docs/reference/foundational-docs',
    command: '/docs/reference',
  },
];

export default function Home(): ReactNode {
  return (
    <Layout
      title="Transit"
      description="Lineage-aware, object-storage-native event streaming for embedded runtimes and networked servers.">
      <main className={styles.page}>
        <section className={styles.hero}>
          <div className="container">
            <div className={styles.heroGrid}>
              <div className={styles.heroCopy}>
                <p className={styles.eyebrow}>Lineage-Aware Event Rails</p>
                <h1>Move event history like a rail network, not a dead-end queue.</h1>
                <p className={styles.lede}>
                  Transit is an append-only event engine with native branches,
                  explicit merges, and tiered storage. It runs embedded in your
                  process or as a server without changing the underlying model.
                </p>
                <div className={styles.actions}>
                  <Link className={styles.primaryAction} to="/docs/intro">
                    Read The Docs
                  </Link>
                  <Link className={styles.secondaryAction} to="/docs/start-here/choose-your-track">
                    Choose Your Track
                  </Link>
                </div>
                <ul className={styles.heroPoints}>
                  <li>Keep immutable history explicit instead of implied.</li>
                  <li>Branch cheaply without copying ancestor bytes.</li>
                  <li>Separate local, replicated, and tiered durability claims.</li>
                </ul>
              </div>
              <div className={styles.scenePanel}>
                <div className={styles.sceneFrame}>
                  <div className={styles.sceneChrome} aria-hidden="true">
                    <span />
                    <span />
                    <span />
                  </div>
                  <p className={styles.sceneLabel}>Transit Network Shape</p>
                  <pre className={styles.sceneDiagram} aria-hidden="true">
                    {[
                      'mainline  ──●──●──●─────●',
                      '              \\',
                      'branch a       ●──●',
                      '                 \\',
                      'branch b          ●──●',
                    ].join('\n')}
                  </pre>
                  <ol className={styles.sceneSteps}>
                    {firstStops.map((item) => (
                      <li key={item.command}>
                        <Link className={styles.sceneStepLink} to={item.href}>
                          <span>{item.label}</span>
                          <code>{item.command}</code>
                        </Link>
                      </li>
                    ))}
                  </ol>
                </div>
              </div>
            </div>
          </div>
        </section>

        <section className={styles.section}>
          <div className="container">
            <div className={styles.sectionHeader}>
              <p className={styles.sectionEyebrow}>Why Transit Feels Different</p>
              <h2>The engine is built around divergence, provenance, and explicit storage boundaries.</h2>
              <p>
                Transit does not pretend branching, publication, and durability
                tradeoffs are edge cases. The docs shell should reflect that the
                product is intentional all the way down.
              </p>
            </div>
            <div className={styles.signalGrid}>
              {signals.map((signal) => (
                <article key={signal.title} className={`${styles.signalCard} ${styles[signal.tone]}`}>
                  <span className={`${styles.routeBadge} ${styles[signal.tone]}`}>{signal.label}</span>
                  <h3>{signal.title}</h3>
                  <p>{signal.body}</p>
                </article>
              ))}
            </div>
          </div>
        </section>

        <section className={styles.sectionAlt}>
          <div className="container">
            <div className={styles.sectionHeader}>
              <p className={styles.sectionEyebrow}>Choose Your Track</p>
              <h2>Take the route that matches how you plan to use the engine.</h2>
              <p>
                The same storage semantics show up in two packaging modes. Start
                with the adoption path that matches your current job, then move
                deeper into the shared contracts.
              </p>
            </div>
            <div className={styles.trackGrid}>
              {tracks.map((track) => (
                <Link
                  key={track.title}
                  to={track.href}
                  className={`${styles.trackCard} ${styles[track.tone]}`}>
                  <span className={`${styles.routeBadge} ${styles[track.tone]}`}>{track.label}</span>
                  <strong>{track.title}</strong>
                  <span>{track.body}</span>
                </Link>
              ))}
            </div>
          </div>
        </section>

        <section className={styles.ctaBand}>
          <div className="container">
            <div className={styles.ctaCard}>
              <div>
                <p className={styles.sectionEyebrow}>Start Here</p>
                <h2>Read the model, pick a track, and run the current proof path.</h2>
              </div>
              <div className={styles.actions}>
                <Link className={styles.primaryAction} to="/docs/intro">
                  Open The Docs
                </Link>
                <Link className={styles.secondaryAction} to="/docs/start-here/server-first-run">
                  Run The Server Track
                </Link>
              </div>
            </div>
          </div>
        </section>
      </main>
    </Layout>
  );
}
