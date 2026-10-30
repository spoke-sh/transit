import { useEffect, useRef, type ReactElement } from "react";
import Link from "@docusaurus/Link";
import ContextEchoes from "./ContextEchoes";

import lateralResonance from "../../../design/handbook-theme/images/d3-lateral-basin.jpg";

export default function RefractionStory(): ReactElement {
  const story = useRef<HTMLElement>(null);
  const viewport = useRef<HTMLDivElement>(null);
  const artwork = useRef<HTMLImageElement>(null);
  const context = useRef<HTMLElement>(null);
  useEffect(() => {
    const element = story.current;
    if (!element) return;
    const media = window.matchMedia(
      "(min-width: 997px) and (prefers-reduced-motion: no-preference)",
    );
    let visible = false;
    let frame = 0;
    const paint = () => {
      frame = 0;
      if (!media.matches || !visible) return;
      const bounds = element.getBoundingClientRect();
      const progress = Math.min(
        1,
        Math.max(0, -bounds.top / Math.max(1, bounds.height - window.innerHeight)),
      );
      const travel = Math.max(
        0,
        (artwork.current?.offsetHeight ?? 0) - (viewport.current?.clientHeight ?? 0),
      );
      element.style.setProperty("--scene-shift", `${(-progress * travel).toFixed(2)}px`);
      const contextBounds = context.current?.getBoundingClientRect();
      if (contextBounds) {
        const depth = Math.min(
          1,
          Math.max(
            0,
            (window.innerHeight - contextBounds.top) / (window.innerHeight + contextBounds.height),
          ),
        );
        element.style.setProperty("--context-depth", depth.toFixed(4));
      }
    };
    const schedule = () => {
      if (media.matches && visible && !frame) frame = window.requestAnimationFrame(paint);
    };
    const configure = () => {
      if (frame) window.cancelAnimationFrame(frame);
      frame = 0;
      element.style.removeProperty("--scene-shift");
      element.style.removeProperty("--context-depth");
      if (media.matches) element.dataset.motion = "enabled";
      else delete element.dataset.motion;
      schedule();
    };
    const observer = new IntersectionObserver(([entry]) => {
      visible = entry?.isIntersecting ?? false;
      schedule();
    });
    observer.observe(element);
    configure();
    media.addEventListener("change", configure);
    window.addEventListener("scroll", schedule, { passive: true });
    window.addEventListener("resize", schedule);
    return () => {
      observer.disconnect();
      media.removeEventListener("change", configure);
      window.removeEventListener("scroll", schedule);
      window.removeEventListener("resize", schedule);
      if (frame) window.cancelAnimationFrame(frame);
      element.style.removeProperty("--scene-shift");
      element.style.removeProperty("--context-depth");
      delete element.dataset.motion;
    };
  }, []);
  return (
    <section ref={story} className="refraction-story" aria-label="From structure to change">
      <div className="refraction-activity">
        <div className="refraction-visual">
          <div ref={viewport} className="refraction-window">
            <img
              ref={artwork}
              className="refraction-artwork"
              src={lateralResonance}
              alt="Vertical graphite waves widen sideways into overlapping resonance rings, joined by a vermilion thread."
              width={1024}
              height={1536}
              loading="lazy"
              decoding="async"
            />
          </div>
        </div>
        <div className="refraction-narrative">
          <section className="refraction-chapter" aria-labelledby="structure-title">
            <p className="transit-kicker">01 / STRUCTURE</p>
            <h2 id="structure-title">
              Begin with
              <br />
              what matters.
            </h2>
            <p>
              Describe the data your application needs, the computation it performs, and the
              policies that govern its use.
            </p>
            <p>
              Tables, documents, key-value state and streams give different kinds of data a place in
              the same model.
            </p>
            <Link className="transit-text-link" to="/reference/data-model">
              Data, computation and policies <span aria-hidden="true">↗</span>
            </Link>
          </section>
          <section className="refraction-chapter" aria-labelledby="activity-title">
            <p className="transit-kicker">02 / ACTIVITY</p>
            <h2 id="activity-title">
              Let the structure
              <br />
              do useful work.
            </h2>
            <p>
              Ask a point-in-time question, maintain a derived view, or coordinate stateful work.
              Choose the lifetime that fits the computation.
            </p>
            <p>
              Fuze computes over your data. Station coordinates durable processes and recorded
              external effects.
            </p>
            <Link className="transit-text-link" to="/reference/queries">
              Explore computation lifetimes <span aria-hidden="true">↗</span>
            </Link>
          </section>
        </div>
      </div>
      <section ref={context} className="refraction-context" aria-labelledby="context-title">
        <div className="refraction-chapter">
          <p className="transit-kicker">03 / CONTEXT</p>
          <h2 id="context-title">
            See the result.
            <br />
            Keep its context.
          </h2>
          <p>
            A useful answer has a basis. Inspect versioned data, recorded progress and outcomes to
            understand what a declaration produced.
          </p>
          <p>
            Explicit permissions, retention and resource budgets define the boundaries in which that
            work happens.
          </p>
          <Link
            className="transit-text-link"
            to="/reference/data-model#inspect-whether-a-declaration-is-being-fulfilled"
          >
            Follow a declaration to its outcome <span aria-hidden="true">↗</span>
          </Link>
        </div>
        <div className="context-visual">
          <ContextEchoes />
        </div>
      </section>
    </section>
  );
}
