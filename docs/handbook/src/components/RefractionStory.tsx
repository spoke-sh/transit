import { useEffect, useRef, useState, type ReactElement } from "react";
import Link from "@docusaurus/Link";
import ContextFabric from "./ContextFabric";
import Radiograph from "./Radiograph";

import lateralResonance from "../../../design/handbook-theme/images/d3-lateral-basin.jpg";

export default function RefractionStory(): ReactElement {
  const [dark, setDark] = useState(false);
  useEffect(() => {
    // Follow the same root attribute used by the theme's pre-hydration script.
    const root = document.documentElement;
    const update = () => setDark(root.dataset.theme === "dark");
    const observer = new MutationObserver(update);
    observer.observe(root, { attributes: true, attributeFilter: ["data-theme"] });
    update();
    return () => observer.disconnect();
  }, []);
  const story = useRef<HTMLElement>(null);
  const activity = useRef<HTMLDivElement>(null);
  const viewport = useRef<HTMLDivElement>(null);
  const artwork = useRef<HTMLImageElement>(null);
  const contextCopy = useRef<HTMLDivElement>(null);
  useEffect(() => {
    const element = story.current;
    if (!element || dark) return;
    const media = window.matchMedia(
      "(min-width: 997px) and (prefers-reduced-motion: no-preference)",
    );
    let visible = false;
    let frame = 0;
    const paint = () => {
      frame = 0;
      if (!media.matches || !visible) return;
      const bounds = activity.current?.getBoundingClientRect();
      if (!bounds) return;
      // Keep the selected three-chapter framing independent of the new fabric's length.
      const referenceHeight = bounds.height + (contextCopy.current?.offsetHeight ?? 0);
      const progress = Math.min(
        1,
        Math.max(0, -bounds.top / Math.max(1, referenceHeight - window.innerHeight)),
      );
      const travel = Math.max(
        0,
        (artwork.current?.offsetHeight ?? 0) - (viewport.current?.clientHeight ?? 0),
      );
      element.style.setProperty("--scene-shift", `${(-progress * travel).toFixed(2)}px`);
    };
    const schedule = () => {
      if (media.matches && visible && !frame) frame = window.requestAnimationFrame(paint);
    };
    const configure = () => {
      if (frame) window.cancelAnimationFrame(frame);
      frame = 0;
      element.style.removeProperty("--scene-shift");
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
      delete element.dataset.motion;
    };
  }, [dark]);
  return (
    <section ref={story} className="refraction-story" aria-label="From structure to change">
      <div className="radiograph-heading">
        <p className="transit-kicker">A DIFFERENT WAY TO SEE</p>
        <h2>Through the surface.</h2>
      </div>
      <div className="refraction-track">
        <Radiograph />
        <div ref={activity} className="refraction-activity">
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
                Tables, documents, key-value state and streams give different kinds of data a place
                in the same model.
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
        <section className="refraction-context" aria-labelledby="context-title">
          <div ref={contextCopy} className="refraction-chapter context-copy">
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
              Explicit permissions, retention and resource budgets define the boundaries in which
              that work happens.
            </p>
            <Link
              className="transit-text-link"
              to="/reference/data-model#inspect-whether-a-declaration-is-being-fulfilled"
            >
              Follow a declaration to its outcome <span aria-hidden="true">↗</span>
            </Link>
          </div>
          <div className="context-visual">
            <ContextFabric />
          </div>
        </section>
      </div>
    </section>
  );
}
