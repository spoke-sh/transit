import type {ReactNode} from 'react';
import Link from '@docusaurus/Link';
import Layout from '@theme/Layout';

import styles from './index.module.css';

const signals = [
  {
    label: 'One Engine',
    body: 'Transit keeps embedded and server mode on the same storage model instead of splitting the product in two.',
  },
  {
    label: 'Lineage Native',
    body: 'Streams can branch and merge explicitly, so divergence is recorded instead of hidden.',
  },
  {
    label: 'Tiered By Design',
    body: 'Remote object storage is a first-class part of the history model, not an afterthought.',
  },
];

const tracks = [
  {
    title: 'Embedded Track',
    body: 'Start from the shared Rust engine when you want local append, replay, branch, merge, and tiered publication in-process.',
    href: '/docs/start-here/embedded-library-first-run',
  },
  {
    title: 'Server Track',
    body: 'Start from the daemon and client surfaces when you want the same semantics through a network boundary.',
    href: '/docs/start-here/server-first-run',
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
              <div className={styles.copy}>
                <p className={styles.eyebrow}>Lineage-Aware Event Rails</p>
                <h1>Move event history like a rail network, not a dead-end queue.</h1>
                <p className={styles.lede}>
                  Transit is an append-only event engine with native branches,
                  explicit merges, and tiered storage. It runs embedded in your
                  process or as a server without changing the underlying model.
                </p>
                <div className={styles.actions}>
                  <Link className={styles.primary} to="/docs/intro">
                    Read The Docs
                  </Link>
                  <Link className={styles.secondary} to="/docs/start-here/choose-your-track">
                    Choose Your Track
                  </Link>
                </div>
                <ul className={styles.points}>
                  <li>Keep immutable history explicit.</li>
                  <li>Branch cheaply without copying ancestor bytes.</li>
                  <li>Separate local, replicated, and tiered durability claims.</li>
                </ul>
              </div>
              <div className={styles.panel}>
                <div className={styles.mapCard}>
                  <p className={styles.panelLabel}>Transit Shape</p>
                  <pre className={styles.diagram} aria-hidden="true">
                    {[
                      'mainline ──●──●──●─────●',
                      '             \\',
                      'branch A      ●──●',
                      '                \\',
                      'branch B         ●──●',
                    ].join('\n')}
                  </pre>
                  <ol className={styles.steps}>
                    <li>
                      <span>Understand the model</span>
                      <code>/docs/intro</code>
                    </li>
                    <li>
                      <span>Pick library or server</span>
                      <code>/docs/start-here</code>
                    </li>
                    <li>
                      <span>Run the current proof path</span>
                      <code>just screen</code>
                    </li>
                  </ol>
                </div>
              </div>
            </div>
          </div>
        </section>

        <section className={styles.section}>
          <div className="container">
            <div className={styles.sectionHeader}>
              <p className={styles.sectionEyebrow}>What Makes Transit Different</p>
              <h2>The product is built around divergence, provenance, and explicit storage boundaries.</h2>
            </div>
            <div className={styles.signalGrid}>
              {signals.map((signal) => (
                <article key={signal.label} className={styles.signalCard}>
                  <p className={styles.signalLabel}>{signal.label}</p>
                  <p>{signal.body}</p>
                </article>
              ))}
            </div>
          </div>
        </section>

        <section className={styles.sectionAlt}>
          <div className="container">
            <div className={styles.sectionHeader}>
              <p className={styles.sectionEyebrow}>Start Here</p>
              <h2>Take the track that matches how you plan to use the engine.</h2>
            </div>
            <div className={styles.trackGrid}>
              {tracks.map((track) => (
                <Link key={track.title} to={track.href} className={styles.trackCard}>
                  <strong>{track.title}</strong>
                  <span>{track.body}</span>
                </Link>
              ))}
            </div>
          </div>
        </section>
      </main>
    </Layout>
  );
}
