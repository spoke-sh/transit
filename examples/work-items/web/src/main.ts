import {
  generation,
  presentation,
  readInterface,
  requireArtifacts,
  ApplicationTransportError,
  type Compiled,
  type Definition,
} from "@rey/transit-application";
import {
  DraftSession,
  httpTransport,
  unifiedCellText,
  verifiedPage,
  QueryError,
  diagnosticLines,
  type ResultPage,
} from "@rey/transit-query-client";
import { proposal } from "./proposal.generated";
import "./style.css";

const element = <T extends HTMLElement>(id: string) => document.getElementById(id) as T;
const query = httpTransport("/api/v1/query");
const session = new DraftSession(query); // Accepted work outlives every screen.
let current: Compiled | null = null;
let identity = "";
let visible: ResultPage | null = null;
let namespace: string | null = null;
let selectedCursor: string | null = null;
let seenResult: object | null = null;
let pageReader = new AbortController();
let reading = false;
let paging = false;
const sql = element<HTMLTextAreaElement>("sql");
type QueryBinding = Extract<Definition["bindings"][number]["source"], { query: unknown }>["query"];
function binding(): QueryBinding | null {
  const selected = current?.definition.bindings.find((item) => "query" in item.source);
  return selected && "query" in selected.source ? selected.source.query : null;
}
function clearResult() {
  pageReader.abort();
  pageReader = new AbortController();
  visible = null;
  namespace = null;
  selectedCursor = null;
  element("rows").replaceChildren();
  element("result").hidden = true;
  element("basis").textContent = "No currently verified result.";
}
function compatible(page: ResultPage) {
  const declared = binding(),
    basis = page.evidence.manifest.basis;
  return (
    declared &&
    declared.source_kind === "table" &&
    declared.profile === "unified_v1" &&
    declared.resource === basis.resource &&
    JSON.stringify(declared.schema) === JSON.stringify(basis.contract)
  );
}
function show(page: ResultPage, selected: string, cursor: string | null = null) {
  if (!compatible(page) || document.hidden) {
    clearResult();
    return;
  }
  // This decoder belongs to the downstream application, never Board or Fuze.
  const columns = page.evidence.columns;
  if (
    columns.length !== 2 ||
    columns[0]?.name !== "id" ||
    !["status", "state"].includes(columns[1]?.name ?? "")
  )
    throw new Error("The work-item renderer requires its declared two-column result");
  const rows = page.cells.map((row) => {
    const tr = document.createElement("tr");
    const id = document.createElement("td"),
      state = document.createElement("td");
    id.textContent = unifiedCellText(row[0]!);
    const value = row[1]!;
    const status = "value" in value && "int64" in value.value ? value.value.int64 : null;
    const old = columns[1]!.name === "status";
    state.textContent =
      status === (old ? "0" : "10")
        ? "Open"
        : status === (old ? "1" : "20")
          ? "Done"
          : unifiedCellText(value);
    tr.append(id, state);
    return tr;
  });
  visible = page;
  namespace = selected;
  selectedCursor = cursor;
  element("rows").replaceChildren(...rows);
  element("result").hidden = false;
  element("next").hidden = page.evidence.next === null;
  const manifest = page.evidence.manifest;
  element("basis").textContent =
    `Query ${selected} · resource ${manifest.basis.resource} · revision ${manifest.basis.revision} · ${columns[1]!.name} schema`;
  element("coverage").textContent =
    `Complete ordered coverage verified: ${manifest.rows} rows. Showing page ${BigInt(page.evidence.ordinal) + 1n}; ${page.evidence.rows} visible rows.`;
}
function render() {
  const state = session.getSnapshot();
  element("query-status").textContent =
    `${state.phase} · ${state.detail}${state.budget ? ` · ${state.budget.starts}/${state.budget.limit} native intents used` : ""}${state.diagnostic ? `\n${diagnosticLines(state.diagnostic).join("\n")}` : ""}`;
  const active = ["opening", "running", "active"].includes(state.phase);
  for (const id of ["run", "live"])
    element<HTMLButtonElement>(id).disabled = !current || state.acceptedWork || active;
  for (const id of ["recover", "cancel", "save"])
    element<HTMLButtonElement>(id).disabled = !state.acceptedWork;
  element<HTMLInputElement>("restore").disabled = state.acceptedWork || active;
  if (state.phase === "denied") {
    clearResult();
    sql.value = "";
  }
  if (state.result && state.result !== seenResult) {
    seenResult = state.result;
    try {
      show(state.result.page, state.result.namespace);
    } catch (error) {
      clearResult();
      notice(error);
    }
  }
}
session.subscribe(render);
function notice(error: unknown) {
  element("recovery-status").textContent = errorMessage(error);
}
function errorMessage(error: unknown): string {
  if (
    (error instanceof QueryError || error instanceof ApplicationTransportError) &&
    error.diagnostic
  )
    return diagnosticLines(error.diagnostic).join("\n");
  return error instanceof Error ? error.message : "Operation unavailable";
}
async function attempt(action: () => Promise<unknown> | void) {
  element("recovery-status").textContent = "";
  try {
    await action();
  } catch (error) {
    notice(error);
  }
}
function selectScreen() {
  const definition = current?.definition;
  const screen = definition?.screens.find(
    (item) =>
      item.path === location.pathname ||
      (location.pathname === "/" && item.name === definition.entry),
  );
  element("workspace").hidden = !screen;
  if (!screen) return;
  element("title").textContent = screen.label;
  element("items").hidden = screen.renderer !== "work_items";
  element("definition").hidden = screen.renderer !== "definition";
  element("definition").textContent = current!.canonical;
  for (const node of element("navigation").querySelectorAll("button"))
    node.setAttribute("aria-current", node.dataset.path === screen.path ? "page" : "false");
}
function navigate(path: string) {
  session.pause();
  history.pushState({}, "", path);
  selectScreen();
}
window.addEventListener("popstate", () => {
  session.pause();
  selectScreen();
});
sql.addEventListener("input", () => session.edit(sql.value));
element("run").onclick = () =>
  void attempt(() => {
    session.edit(sql.value);
    return session.open(1);
  });
element("live").onclick = () =>
  void attempt(() => {
    session.edit(sql.value);
    return session.open(2);
  });
element("pause").onclick = () => session.pause();
element("recover").onclick = () => session.recover();
element("cancel").onclick = () => session.cancel();
element("save").onclick = () =>
  void attempt(() => {
    const url = URL.createObjectURL(
      new Blob([session.exportRecovery()], { type: "application/json" }),
    );
    const link = document.createElement("a");
    link.href = url;
    link.download = "work-items-query.json";
    link.click();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
  });
element<HTMLInputElement>("restore").onchange = (event) =>
  void attempt(async () => {
    const input = event.target as HTMLInputElement,
      file = input.files?.[0];
    input.value = "";
    if (!file) return;
    if (file.size > 131072) throw new Error("Recovery exceeds 128 KiB");
    session.restoreRecovery(await file.text());
  });
element<HTMLSelectElement>("density").onchange = (event) => {
  document.body.dataset.density = (event.target as HTMLSelectElement).value;
};
async function readPage(cursor: string | null) {
  if (paging) return;
  paging = true;
  element<HTMLButtonElement>("next").disabled = true;
  try {
    // Join an existing observation; prevent another poll from racing navigation.
    while (reading) await new Promise((resolve) => setTimeout(resolve, 25));
    await loadPage(cursor);
  } finally {
    paging = false;
    element<HTMLButtonElement>("next").disabled = false;
  }
}
async function loadPage(cursor: string | null) {
  const selected = namespace,
    expected = identity,
    signal = pageReader.signal;
  if (!selected || !visible) return;
  const page = await verifiedPage(
    selected,
    cursor,
    session.getSnapshot().budget?.budgets.segments ?? "0",
    signal,
    async (namespace, cursor, signal) => {
      const result = await query({ page: { namespace, cursor } }, signal);
      if (!("page" in result)) throw new Error("Invalid result page");
      return result.page;
    },
  );
  if (!signal.aborted && identity === expected && selected === namespace)
    show(page, selected, cursor);
}
element("next").onclick = () => void attempt(() => readPage(visible?.evidence.next ?? null));
// One bounded observation at a time. No query is admitted by polling metadata.
async function refresh() {
  if (reading || paging || document.hidden) return;
  reading = true;
  try {
    const value = await readInterface(AbortSignal.timeout(6000));
    if (!("published" in value)) throw new Error("The application requires a published interface");
    const definition = value.published.compiled.definition;
    requireArtifacts(proposal, definition);
    const next = generation(definition.realm, definition.name, value.published.head);
    if (document.hidden) return;
    if (next !== identity) {
      session.pause();
      clearResult();
      identity = next;
      current = value.published.compiled;
      seenResult = session.getSnapshot().result;
      const links = definition.screens.map((screen) => {
        const button = document.createElement("button");
        button.textContent = screen.label;
        button.dataset.path = screen.path;
        button.onclick = () => navigate(screen.path);
        return button;
      });
      element("navigation").replaceChildren(...links);
      document.body.dataset.density = presentation(definition).density;
      element<HTMLSelectElement>("density").value = presentation(definition).density;
      sql.value = binding()?.sql ?? "";
      session.edit(sql.value);
      selectScreen();
    }
    element("interface-status").textContent =
      `Published interface revision ${definition.revision}. Source and query authority are checked independently.`;
    // The session verifies initial publication; a held visible page still needs
    // a current-authority read. This does not replace its immutable result.
    if (visible && namespace && !session.getSnapshot().acceptedWork) {
      const expected = identity,
        selected = namespace,
        old = visible;
      const response = await query(
        { page: { namespace, cursor: selectedCursor } },
        pageReader.signal,
      );
      if (
        !("page" in response) ||
        !compatible(response.page) ||
        JSON.stringify(response.page.evidence.manifest) !== JSON.stringify(old.evidence.manifest)
      )
        throw new Error("Current source contract changed");
      if (expected === identity && selected === namespace && old === visible && !document.hidden) {
        show(response.page, selected, selectedCursor);
      }
    }
  } catch (error) {
    current = null;
    identity = "";
    clearResult();
    if (
      typeof error === "object" &&
      error !== null &&
      "status" in error &&
      (error.status === 403 || error.status === 410)
    )
      session.invalidate();
    else session.pause();
    element("workspace").hidden = true;
    element("navigation").replaceChildren();
    element("interface-status").textContent = errorMessage(error);
  } finally {
    reading = false;
    render();
  }
}
document.addEventListener("visibilitychange", () => {
  if (document.hidden) {
    session.pause();
    clearResult();
    current = null;
    identity = "";
    element("workspace").hidden = true;
  } else void refresh();
});
render();
void refresh();
setInterval(() => void refresh(), 2000);
