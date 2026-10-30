import { useEffect, useRef, type ReactElement } from "react";
import Link from "@docusaurus/Link";

// Deterministic decorative geometry keeps server and client renders identical.
const contours = Array.from({ length: 29 }, (_, index) => (index - 14) * 6);
const rules = Array.from({ length: 7 }, (_, index) => 246 + index * 18);

function terrain(offset: number): string {
  return `M 505 ${300 + offset * 0.18} C 570 ${300 + offset * 0.3}, 580 ${155 + offset}, 652 ${177 + offset}
    S 737 ${218 + offset * 0.7}, 775 ${119 + offset * 0.7}
    S 850 ${108 + offset * 0.8}, 920 ${143 + offset * 0.8}`;
}
function wave(offset: number): string {
  return `M 230 ${300 + offset * 0.65} C 284 ${300 + offset * 0.65}, 300 ${220 + offset * 0.8}, 350 ${267 + offset * 0.7}
    S 414 ${373 + offset * 0.6}, 457 ${319 + offset * 0.4}
    S 487 ${300 + offset * 0.18}, 505 ${300 + offset * 0.18}`;
}
function RefractionScene(): ReactElement {
  return (
    <svg className="refraction-scene" viewBox="0 0 940 630" aria-hidden="true" focusable="false">
      <g className="refraction-registration">
        <path d="M 25 32 H 915 M 25 598 H 915 M 25 28 V 36 M 915 28 V 36 M 25 594 V 602 M 915 594 V 602" />
        <path d="M 505 52 V 578" strokeDasharray="2 9" />
      </g>
      <g className="refraction-history">
        {[-115, -95, 110, 130].map((offset) => (
          <path key={offset} d={terrain(offset)} />
        ))}
      </g>
      <g className="refraction-score">
        {rules.map((y, row) => (
          <g key={y}>
            <path d={`M 20 ${y} H 230`} />
            {[0, 1, 2, 3, 4].map((mark) => (
              <rect key={mark} x={36 + mark * 39 + (row % 2) * 12} y={y - 3} width="4" height="6" />
            ))}
          </g>
        ))}
        <path className="refraction-thread" d="M 20 300 H 230" />
      </g>
      <g className="refraction-waves">
        {contours.map((offset) => (
          <path key={offset} d={wave(offset)} />
        ))}
        <path className="refraction-thread" d={wave(0)} />
      </g>
      <g className="refraction-terrain">
        {contours.map((offset) => (
          <path key={offset} d={terrain(offset)} />
        ))}
        <path className="refraction-thread" d={terrain(0)} />
      </g>
      <g className="refraction-planes">
        {Array.from({ length: 12 }, (_, i) => (
          <path
            key={i}
            className="refraction-plane"
            d={`M 505 300 L ${640 + i * 12} ${370 + i * 9} L 920 ${344 + i * 20} Z`}
          />
        ))}
        <path
          className="refraction-thread"
          d="M 505 300 C 575 315, 627 396, 696 423 S 817 451, 920 524"
        />
      </g>
    </svg>
  );
}

export default function RefractionStory(): ReactElement {
  const story = useRef<HTMLElement>(null);
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
      element.style.setProperty("--scene-progress", progress.toFixed(4));
    };
    const schedule = () => {
      if (media.matches && visible && !frame) frame = window.requestAnimationFrame(paint);
    };
    const configure = () => {
      if (frame) window.cancelAnimationFrame(frame);
      frame = 0;
      element.style.removeProperty("--scene-progress");
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
      element.style.removeProperty("--scene-progress");
      delete element.dataset.motion;
    };
  }, []);
  return (
    <section ref={story} className="refraction-story" aria-label="From structure to change">
      <div className="refraction-visual">
        <RefractionScene />
        <div className="refraction-legend" aria-hidden="true">
          <span>STRUCTURE</span>
          <span>ACTIVITY</span>
          <span>CONTEXT</span>
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
            Describe the data your application needs, the computation it performs, and the policies
            that govern its use.
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
        <section className="refraction-chapter" aria-labelledby="context-title">
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
        </section>
      </div>
    </section>
  );
}
