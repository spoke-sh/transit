// A quiet, original four-chord miniature. Everything is synthesized locally;
// the context is constructed only by the listener's play gesture.
export const HERO_SCORE_CHORD_SECONDS = (60 / 76 / 2) * 16;

export function createHeroScore() {
  const context = new AudioContext();
  const master = context.createGain();
  master.gain.value = 0;
  master.connect(context.destination);
  const filter = context.createBiquadFilter();
  filter.type = "lowpass";
  filter.frequency.value = 1800;
  filter.Q.value = 0.4;
  filter.connect(master);
  const delay = context.createDelay(1);
  delay.delayTime.value = 0.42;
  const echo = context.createGain();
  echo.gain.value = 0.22;
  filter.connect(delay);
  delay.connect(echo);
  echo.connect(delay);
  echo.connect(master);

  // Open major and minor voicings, with a soft low root.
  const chords = [
    [48, 60, 64, 67, 71, 74],
    [45, 60, 64, 67, 71, 72],
    [41, 60, 64, 65, 69, 72],
    [43, 59, 62, 67, 69, 74],
  ];
  const pattern = [1, 3, 2, 4, 3, 5, 2, 4];
  const step = HERO_SCORE_CHORD_SECONDS / 16;
  let beat = 0;
  let next = 0;
  let timer: number | undefined;
  let stopped = false;

  const note = (midi: number, when: number, duration: number, level: number) => {
    const oscillator = context.createOscillator();
    const envelope = context.createGain();
    const pan = context.createStereoPanner();
    oscillator.type = midi < 50 ? "sine" : "triangle";
    oscillator.frequency.value = 440 * 2 ** ((midi - 69) / 12);
    pan.pan.value = midi < 50 ? 0 : ((beat % 5) - 2) * 0.16;
    envelope.gain.setValueAtTime(0, when);
    envelope.gain.linearRampToValueAtTime(level, when + 0.035);
    envelope.gain.exponentialRampToValueAtTime(0.0001, when + duration);
    oscillator.connect(envelope);
    envelope.connect(pan);
    pan.connect(filter);
    oscillator.onended = () => {
      oscillator.disconnect();
      envelope.disconnect();
      pan.disconnect();
    };
    oscillator.start(when);
    oscillator.stop(when + duration + 0.05);
  };
  const schedule = () => {
    if (stopped || context.state !== "running") return;
    // Never catch up a suspended tab with a burst of old notes.
    next = Math.max(next, context.currentTime);
    while (next < context.currentTime + 0.2) {
      const chord = chords[Math.floor(beat / 16) % chords.length]!;
      if (beat % 16 === 0) note(chord[0]!, next, step * 15, 0.18);
      note(chord[pattern[beat % pattern.length]!]!, next, 2.8, beat % 4 === 0 ? 0.12 : 0.085);
      next += step;
      beat++;
    }
  };
  return {
    context,
    async play() {
      await context.resume();
      if (stopped) return;
      if (context.state !== "running") throw new Error("Audio could not start");
      next = context.currentTime + 0.04;
      master.gain.linearRampToValueAtTime(0.55, context.currentTime + 0.3);
      schedule();
      timer = window.setInterval(schedule, 80);
    },
    stop() {
      if (stopped) return;
      stopped = true;
      window.clearInterval(timer);
      // Fade before releasing the graph, including any scheduled notes and echoes.
      if (context.state === "running") {
        const level = master.gain.value;
        master.gain.cancelScheduledValues(context.currentTime);
        master.gain.setValueAtTime(level, context.currentTime);
        master.gain.linearRampToValueAtTime(0, context.currentTime + 0.1);
        window.setTimeout(() => void context.close().catch(() => {}), 140);
      } else if (context.state !== "closed") {
        void context.close().catch(() => {});
      }
    },
  };
}
