import { useEffect, useRef, useState, type CSSProperties, type ReactElement } from "react";
import refraction from "../../../design/transit-artwork/images/d1-refraction-graphite.jpg";
import radiograph from "../../../design/handbook-theme/images/d6-radiograph.jpg";
import lookout from "../assets/hero-fire-lookout.webp";
import { createHeroScore, HERO_SCORE_CHORD_SECONDS } from "./hero-score";
import "../css/hero-artwork.css";

const clamp = (value: number) => Math.max(0, Math.min(1, value));

export default function HeroArtwork(): ReactElement {
  const artwork = useRef<HTMLElement>(null);
  const score = useRef<ReturnType<typeof createHeroScore> | null>(null);
  const [supported, setSupported] = useState(false);
  const [playing, setPlaying] = useState(false);
  const [audioError, setAudioError] = useState(false);

  useEffect(() => {
    setSupported(typeof window.AudioContext === "function");
    const stop = () => {
      score.current?.stop();
      score.current = null;
      setPlaying(false);
    };
    const visibility = () => {
      if (document.hidden) stop();
    };
    document.addEventListener("visibilitychange", visibility);
    window.addEventListener("pagehide", stop);
    return () => {
      document.removeEventListener("visibilitychange", visibility);
      window.removeEventListener("pagehide", stop);
      score.current?.stop();
      score.current = null;
    };
  }, []);

  useEffect(() => {
    const element = artwork.current;
    if (!element) return;
    const reduced = window.matchMedia("(prefers-reduced-motion: reduce)");
    const touch = window.matchMedia("(hover: none), (pointer: coarse)");
    let visible = false;
    let frame = 0;
    let pointer: { x: number; y: number } | null = null;
    const reset = () => {
      for (const property of [
        "--beacon-energy",
        "--prism-energy",
        "--light-travel",
        "--light-shift",
      ])
        element.style.removeProperty(property);
    };
    const paint = () => {
      frame = 0;
      if (!visible || document.hidden || reduced.matches) return;
      const bounds = element.getBoundingClientRect();
      const x = pointer ? (pointer.x - bounds.left) / bounds.width : 0.5;
      const y = pointer ? (pointer.y - bounds.top) / bounds.height : 0.5;
      const approach = touch.matches
        ? clamp(
            (window.innerHeight * 0.85 - (bounds.top + bounds.height * 0.1)) /
              (window.innerHeight * 0.55),
          )
        : pointer
          ? clamp(1 - Math.hypot((x - 0.917) * 2, y - 0.08) / 0.65)
          : 0;
      const light = touch.matches
        ? approach
        : pointer
          ? clamp(1 - Math.hypot(x - 0.78, y - 0.68))
          : 0;
      element.style.setProperty("--beacon-energy", approach.toFixed(3));
      element.style.setProperty("--prism-energy", light.toFixed(3));
      element.style.setProperty(
        "--light-travel",
        `${((touch.matches ? approach : x) * -180).toFixed(2)}px`,
      );
      element.style.setProperty(
        "--light-shift",
        `${((touch.matches ? approach - 0.5 : pointer ? x - 0.5 : 0) * 7).toFixed(2)}px`,
      );
    };
    const schedule = () => {
      if (visible && !document.hidden && !reduced.matches && !frame)
        frame = window.requestAnimationFrame(paint);
    };
    const move = (event: PointerEvent) => {
      if (event.pointerType === "touch") return;
      pointer = { x: event.clientX, y: event.clientY };
      schedule();
    };
    const leave = () => {
      pointer = null;
      schedule();
    };
    const configure = () => {
      if (frame) window.cancelAnimationFrame(frame);
      frame = 0;
      pointer = null;
      reset();
      schedule();
    };
    const observer = new IntersectionObserver(([entry]) => {
      visible = entry?.isIntersecting ?? false;
      element.dataset.artVisible = String(visible);
      if (!visible) configure();
      else schedule();
    });
    observer.observe(element);
    element.addEventListener("pointermove", move, { passive: true });
    element.addEventListener("pointerleave", leave);
    window.addEventListener("scroll", schedule, { passive: true });
    window.addEventListener("resize", schedule);
    document.addEventListener("visibilitychange", configure);
    reduced.addEventListener("change", configure);
    touch.addEventListener("change", configure);
    return () => {
      observer.disconnect();
      element.removeEventListener("pointermove", move);
      element.removeEventListener("pointerleave", leave);
      window.removeEventListener("scroll", schedule);
      window.removeEventListener("resize", schedule);
      document.removeEventListener("visibilitychange", configure);
      reduced.removeEventListener("change", configure);
      touch.removeEventListener("change", configure);
      if (frame) window.cancelAnimationFrame(frame);
      reset();
      delete element.dataset.artVisible;
    };
  }, []);

  const toggleScore = async () => {
    if (score.current) {
      score.current.stop();
      score.current = null;
      setPlaying(false);
      return;
    }
    setAudioError(false);
    let next: ReturnType<typeof createHeroScore> | null = null;
    try {
      next = createHeroScore();
      score.current = next;
      await next.play();
      if (score.current !== next) return;
      setPlaying(true);
      const current = next;
      current.context.onstatechange = () => {
        if (current.context.state !== "running" && score.current === current) {
          current.stop();
          score.current = null;
          setPlaying(false);
        }
      };
    } catch {
      next?.stop();
      if (score.current !== next) return;
      score.current = null;
      setPlaying(false);
      setAudioError(true);
    }
  };

  return (
    <figure
      ref={artwork}
      className="transit-hero-art"
      data-playing={playing}
      style={{ "--score-cycle": `${HERO_SCORE_CHORD_SECONDS}s` } as CSSProperties}
    >
      <img
        className="transit-hero-light"
        src={refraction}
        alt="A measured score becomes waves, branching upward into graphite terrain and downward into translucent planes, joined by a vermilion thread."
        width={1774}
        height={887}
        fetchPriority="high"
      />
      <img
        className="transit-hero-dark"
        src={radiograph}
        alt="Silver membranes open into depth, exposing translucent internal folds and a vermilion thread receding through them."
        width={1774}
        height={887}
        loading="lazy"
        fetchPriority="high"
      />
      <svg className="hero-light-scene" viewBox="0 0 1774 887" aria-hidden="true" focusable="false">
        <defs>
          <radialGradient id="hero-beacon-halo">
            <stop stopColor="#f6dfa8" stopOpacity="0.38" />
            <stop offset="0.2" stopColor="#eac68c" stopOpacity="0.18" />
            <stop offset="0.6" stopColor="#dcb780" stopOpacity="0.04" />
            <stop offset="1" stopColor="#dcb780" stopOpacity="0" />
          </radialGradient>
          <radialGradient id="hero-beacon-core">
            <stop stopColor="#f7e3b7" stopOpacity="0.7" />
            <stop offset="0.45" stopColor="#edc58c" stopOpacity="0.45" />
            <stop offset="1" stopColor="#d9ab73" stopOpacity="0" />
          </radialGradient>
          <linearGradient
            id="hero-beacon-beam"
            gradientUnits="userSpaceOnUse"
            x1="1631"
            y1="39"
            x2="1774"
            y2="39"
          >
            <stop stopColor="#e7c28b" stopOpacity="0.24" />
            <stop offset="0.35" stopColor="#e7c28b" stopOpacity="0.13" />
            <stop offset="1" stopColor="#e7c28b" stopOpacity="0" />
          </linearGradient>
          <filter id="hero-beacon-soften" x="-10%" y="-30%" width="120%" height="160%">
            <feGaussianBlur stdDeviation="1.8" />
          </filter>
          <path
            id="hero-beacon-ray"
            d="M1631 38.5 L1774 15 L1774 63 L1631 39.5Z"
            fill="url(#hero-beacon-beam)"
            filter="url(#hero-beacon-soften)"
          />
          <linearGradient id="hero-spectrum" x1="0" y1="0" x2="1" y2="0.6">
            <stop stopColor="#dfac53" stopOpacity="0" />
            <stop offset="0.23" stopColor="#e4b25d" />
            <stop offset="0.48" stopColor="#b8a2c6" />
            <stop offset="0.72" stopColor="#72adbd" />
            <stop offset="1" stopColor="#e3c584" stopOpacity="0.35" />
          </linearGradient>
          <linearGradient id="hero-ray">
            <stop stopColor="#fff4c1" stopOpacity="0" />
            <stop offset="0.55" stopColor="#ffe7a1" stopOpacity="0.55" />
            <stop offset="1" stopColor="#fff4c1" stopOpacity="0" />
          </linearGradient>
        </defs>
        <g className="hero-prismatic-planes" fill="url(#hero-spectrum)">
          <path d="M870 389 C1010 448 1104 508 1290 555 C1460 602 1606 590 1774 539 L1774 622 C1517 647 1390 645 1220 566 C1090 503 964 429 870 389Z" />
          <path d="M875 392 C1028 506 1092 591 1243 613 C1440 637 1552 681 1774 719 L1774 760 C1555 698 1407 702 1266 649 C1095 587 999 471 875 392Z" />
          <path d="M900 414 C1071 555 1204 666 1347 740 L1529 887 L1463 887 C1302 729 1096 600 900 414Z" />
        </g>
        <g className="hero-channel-edges" fill="none" stroke="url(#hero-spectrum)" strokeWidth="2">
          <path d="M875 390 C1068 489 1190 580 1391 607 S1624 596 1774 564" />
          <path d="M884 402 C1061 539 1110 600 1285 630 S1582 691 1774 721" />
          <path d="M918 435 C1105 615 1291 686 1494 887" />
        </g>
        <g className="hero-channel-glints" fill="none" stroke="url(#hero-ray)" strokeWidth="3">
          <path d="M875 390 C1068 489 1190 580 1391 607 S1624 596 1774 564" />
          <path d="M884 402 C1061 539 1110 600 1285 630 S1582 691 1774 721" />
        </g>
        <g className="hero-music-light">
          <g
            className="hero-music-current"
            fill="none"
            stroke="url(#hero-spectrum)"
            strokeWidth="4"
          >
            <path d="M875 390 C1068 489 1190 580 1391 607 S1624 596 1774 564" />
            <path d="M884 402 C1061 539 1110 600 1285 630 S1582 691 1774 721" />
            <path d="M918 435 C1105 615 1291 686 1494 887" />
          </g>
        </g>
        <g className="hero-beacon">
          <g className="hero-beacon-aura">
            <use href="#hero-beacon-ray" />
            <circle cx="1631" cy="39" r="12" fill="url(#hero-beacon-halo)" />
          </g>
          <image className="hero-lookout" href={lookout} x="1590" y="25" width="72" height="72" />
          <circle
            className="hero-beacon-core"
            cx="1631"
            cy="39"
            r="1.2"
            fill="url(#hero-beacon-core)"
          />
          <g className="hero-music-light">
            <g className="hero-beacon-breath">
              <use href="#hero-beacon-ray" />
              <circle cx="1631" cy="39" r="10" fill="url(#hero-beacon-halo)" />
            </g>
          </g>
        </g>
      </svg>
      {supported && (
        <div className="hero-score-zone">
          <button
            className="hero-score-button"
            type="button"
            onClick={() => void toggleScore()}
            aria-label={playing ? "Stop music" : "Play warm ambient music"}
            aria-pressed={playing}
          >
            <svg viewBox="0 0 24 24" aria-hidden="true" focusable="false">
              {playing ? <path d="M7 7h10v10H7z" /> : <path d="m7 4 13 8-13 8z" />}
            </svg>
          </button>
        </div>
      )}
      <span className="hero-audio-status" role="status">
        {audioError ? "Audio could not start. Try the play button again." : ""}
      </span>
    </figure>
  );
}
