import {
  LiveView,
  ReactiveError,
  Session,
  type ReactiveResponse,
} from "@rey/transit-reactive-client";
import "./style.css";
const element = <T extends HTMLElement>(id: string) => document.getElementById(id) as T;
const status = element("status"),
  basis = element("basis"),
  rows = element("rows"),
  coverage = element("coverage");
const follow = element<HTMLButtonElement>("follow"),
  pause = element<HTMLButtonElement>("pause"),
  recover = element<HTMLButtonElement>("recover");
const session = new Session();
const view = new LiveView<NonNullable<ReactiveResponse["snapshot"]>>(session, async (signal) => {
  const response = await session.snapshot(signal);
  if (!response.snapshot) throw new ReactiveError(0, "invalid_response");
  return { value: response.snapshot, basis: response.snapshot.observation.basis };
});
function render() {
  const state = view.getSnapshot();
  status.textContent = `${state.phase.replaceAll("_", " ")} · ${state.detail}${state.operationDetail ? `\n${state.operationDetail}` : ""}`;
  status.dataset.phase = state.phase;
  recover.hidden = !session.pending;
  follow.disabled = view.following || view.stopping || !!session.pending;
  recover.disabled = view.stopping;
  const snapshot = state.snapshot;
  basis.textContent = snapshot
    ? `Resource ${snapshot.basis.cut.resource} · revision ${snapshot.basis.cut.revision} · data progress ${snapshot.value.observation.data_revision}`
    : "No authorized snapshot.";
  rows.replaceChildren();
  for (const row of snapshot?.value.rows ?? []) {
    if (!row) continue;
    const tr = document.createElement("tr");
    for (const text of [row.key, row.value ?? "NULL"]) {
      const td = document.createElement("td");
      td.textContent = text;
      tr.append(td);
    }
    rows.append(tr);
  }
  coverage.textContent = snapshot
    ? snapshot.value.more
      ? "First bounded page; more rows exist. This is not a complete Table result."
      : "Complete bounded counter snapshot."
    : "";
}
view.subscribe(render);
const failure = (error: unknown) => {
  status.textContent =
    error instanceof ReactiveError
      ? error.reason
      : "Connection unavailable. Recover any uncertain control before continuing.";
  recover.hidden = !session.pending;
};
follow.addEventListener("click", () => {
  void view.start().catch(failure);
});
pause.addEventListener("click", () => {
  void view.pause().catch(failure);
});
recover.addEventListener("click", () => {
  void view.recover().then(render).catch(failure);
});
document.addEventListener("visibilitychange", () => {
  if (document.hidden) void view.pause();
});
window.addEventListener("pagehide", () => {
  void view.pause();
});
render();
