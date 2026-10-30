import { useEffect, useRef, useState, type ReactElement, type RefObject } from "react";
import radiograph from "../../../design/handbook-theme/images/d6-radiograph.jpg";
import near from "../../../design/handbook-theme/images/d6-near.webp";
import middle from "../../../design/handbook-theme/images/d6-middle.webp";

type Props = { dark: boolean; track: RefObject<HTMLDivElement | null> };

export default function Radiograph({ dark, track }: Props): ReactElement {
  const visual = useRef<HTMLDivElement>(null);
  const camera = useRef<HTMLDivElement>(null);
  const [eligible, setEligible] = useState(false);
  const [ready, setReady] = useState(false);
  const [paused, setPaused] = useState(false);
  const pause = useRef(false);
  const requestPaint = useRef<() => void>(() => {});

  useEffect(() => {
    const media = window.matchMedia(
      "(min-width: 997px) and (min-height: 700px) and (prefers-reduced-motion: no-preference)",
    );
    const configure = () => {
      const enabled = dark && media.matches;
      setEligible(enabled);
      if (!enabled) setReady(false);
      pause.current = false;
      setPaused(false);
    };
    configure();
    media.addEventListener("change", configure);
    return () => media.removeEventListener("change", configure);
  }, [dark]);

  useEffect(() => {
    if (!eligible) return;
    const images = camera.current?.querySelectorAll("img");
    if (!images || images.length !== 3) return;
    let cancelled = false;
    // decode() also handles cached images whose load event preceded an effect.
    Promise.all(Array.from(images, (image) => image.decode())).then(
      () => {
        if (!cancelled) setReady(true);
      },
      () => {
        if (!cancelled) setReady(false);
      },
    );
    return () => {
      cancelled = true;
    };
  }, [eligible]);

  useEffect(() => {
    const element = track.current;
    const viewport = visual.current;
    const scene = camera.current;
    if (!dark || !eligible || !ready || !element || !viewport || !scene) return;
    let visible = false;
    let frame = 0;
    const paint = () => {
      frame = 0;
      if (!visible || pause.current || document.hidden) return;
      const top = Number.parseFloat(getComputedStyle(viewport).top);
      const bounds = element.getBoundingClientRect();
      const distance = Math.max(1, bounds.height - viewport.offsetHeight);
      const progress = Math.max(0, Math.min(1, (top - bounds.top) / distance));
      // Fixed perspective and plane depths; scroll moves only the shared z origin.
      scene.style.setProperty("--camera-z", `${(650 * progress).toFixed(3)}px`);
    };
    const schedule = () => {
      if (visible && !pause.current && !document.hidden && !frame)
        frame = window.requestAnimationFrame(paint);
    };
    const intersection = new IntersectionObserver(([entry]) => {
      visible = entry?.isIntersecting ?? false;
      schedule();
    });
    const resize = new ResizeObserver(schedule);
    element.dataset.depthMotion = "enabled";
    intersection.observe(element);
    resize.observe(element);
    resize.observe(viewport);
    requestPaint.current = schedule;
    window.addEventListener("scroll", schedule, { passive: true });
    window.addEventListener("resize", schedule);
    document.addEventListener("visibilitychange", schedule);
    return () => {
      intersection.disconnect();
      resize.disconnect();
      window.removeEventListener("scroll", schedule);
      window.removeEventListener("resize", schedule);
      document.removeEventListener("visibilitychange", schedule);
      if (frame) window.cancelAnimationFrame(frame);
      scene.style.removeProperty("--camera-z");
      delete element.dataset.depthMotion;
      requestPaint.current = () => {};
    };
  }, [dark, eligible, ready, track]);

  const togglePause = () => {
    pause.current = !pause.current;
    setPaused(pause.current);
    requestPaint.current();
  };

  return (
    <div ref={visual} className="radiograph-visual">
      <div
        className="radiograph-volume"
        role="img"
        aria-label="Silver membranes expose translucent internal folds and a deeper pocket, with a vermilion thread receding through them."
      >
        <img
          className="radiograph-poster"
          src={radiograph}
          alt=""
          width={1774}
          height={887}
          loading="lazy"
          decoding="async"
        />
        <div ref={camera} className="radiograph-camera" aria-hidden="true">
          {eligible && (
            <>
              <img
                className="radiograph-plane radiograph-far"
                src={radiograph}
                width={1774}
                height={887}
                alt=""
              />
              <img
                className="radiograph-plane radiograph-middle"
                src={middle}
                width={1536}
                height={1024}
                alt=""
              />
              <img
                className="radiograph-plane radiograph-near"
                src={near}
                width={1536}
                height={1024}
                alt=""
              />
            </>
          )}
        </div>
      </div>
      <div className="radiograph-controls">
        {dark && eligible && ready && (
          <button type="button" aria-pressed={paused} onClick={togglePause}>
            {paused ? "Resume depth motion" : "Pause depth motion"}
          </button>
        )}
        <a href="#handbook">
          Skip to the handbook <span aria-hidden="true">↓</span>
        </a>
      </div>
    </div>
  );
}
