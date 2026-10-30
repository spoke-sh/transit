// Repository-only motion study. Scroll position is the sole camera input.
const depth = document.querySelector<HTMLElement>(".depth")!;
const track = document.querySelector<HTMLElement>(".depth-track")!;
const sticky = document.querySelector<HTMLElement>(".depth-sticky")!;
const camera = document.querySelector<HTMLElement>(".camera")!;
const depthStatus = document.querySelector<HTMLElement>("#depth-status")!;
const toggle = document.querySelector<HTMLButtonElement>("#motion-toggle")!;
const media = window.matchMedia(
  "(min-width: 997px) and (min-height: 700px) and (prefers-reduced-motion: no-preference)",
);
let frame = 0;
let paused = false;
let visible = false;

function paint(): void {
  frame = 0;
  if (!media.matches || paused || !visible || document.hidden) return;
  const top = Number.parseFloat(getComputedStyle(sticky).top);
  const bounds = track.getBoundingClientRect();
  const distance = Math.max(1, bounds.height - sticky.offsetHeight);
  const progress = Math.max(0, Math.min(1, (top - bounds.top) / distance));
  // Moving the scene toward the observer is equivalent to moving the camera in.
  // Every plane keeps its own z coordinate; x/y and field of view remain fixed.
  camera.style.setProperty("--camera-z", `${(650 * progress).toFixed(3)}px`);
  depth.dataset.progress = progress.toFixed(6);
  depthStatus.textContent = `DEPTH / ${Math.round(progress * 100)
    .toString()
    .padStart(3, "0")}`;
}

function schedule(): void {
  if (media.matches && !paused && visible && !document.hidden && !frame)
    frame = window.requestAnimationFrame(paint);
}

function configure(): void {
  if (frame) window.cancelAnimationFrame(frame);
  frame = 0;
  if (media.matches) depth.dataset.enhanced = "";
  else delete depth.dataset.enhanced;
  paused = false;
  toggle.hidden = !media.matches;
  toggle.setAttribute("aria-pressed", "false");
  toggle.textContent = "Pause depth motion";
  camera.style.removeProperty("--camera-z");
  delete depth.dataset.progress;
  depthStatus.textContent = media.matches ? "DEPTH / 000" : "Static section";
  schedule();
}

const observer = new IntersectionObserver(([entry]) => {
  visible = entry?.isIntersecting ?? false;
  schedule();
});
observer.observe(track);
toggle.addEventListener("click", () => {
  paused = !paused;
  toggle.setAttribute("aria-pressed", String(paused));
  toggle.textContent = paused ? "Resume depth motion" : "Pause depth motion";
  schedule();
});
media.addEventListener("change", configure);
window.addEventListener("scroll", schedule, { passive: true });
window.addEventListener("resize", schedule);
document.addEventListener("visibilitychange", schedule);
configure();
