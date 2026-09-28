import { useInterface } from "./interface";
import { useScope } from "./state";
import "./definition.css";
import { Link } from "@tanstack/react-router";
import { useEffect, useReducer, useState } from "react";
import {
  compile,
  abandonPublication,
  diagram,
  importOperatorKey,
  keySigner,
  OperatorSession,
  publish,
  readInterface,
  request,
  reviewPublication,
  restoreReview,
  type Compiled,
  type Definition,
  type Review,
  type Scope,
} from "@rey/transit-application";

// One editor workspace per mounted installation. Route/definition replacement
// never discards an uncertain native submission or reimports a private key.
const workspace: {
  draft: string;
  compiled: Compiled | null;
  session: OperatorSession | null;
  review: Review | null;
  status: string;
  busy: boolean;
} = {
  draft: "",
  compiled: null,
  session: null,
  review: null,
  status: "",
  busy: false,
};
const subscribers = new Set<() => void>();
const changed = () => {
  for (const listener of subscribers) listener();
};
const errorText = (error: unknown) =>
  error instanceof Error ? error.message : "Operation unavailable";
function download(name: string, text: string) {
  const url = URL.createObjectURL(new Blob([text], { type: "application/json" }));
  const link = document.createElement("a");
  link.href = url;
  link.download = name;
  link.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}
export function DefinitionEditor() {
  const current = useInterface();
  const canInspect = useScope().scope?.profile !== "growing_v3" || current !== null;
  const [, render] = useReducer((value: number) => value + 1, 0);
  const [mode, setMode] = useState<"sql" | "form" | "canvas">("sql");
  const [scope, setScope] = useState<Scope | null>(null);
  const [principal, setPrincipal] = useState("");
  const [selected, setSelected] = useState("");
  const [available, setAvailable] = useState("Checking operator endpoint…");
  useEffect(() => {
    subscribers.add(render);
    return () => {
      subscribers.delete(render);
    };
  }, []);
  useEffect(() => {
    let active = true;
    void request({ info: {} })
      .then((info) => {
        if (active && "info" in info) {
          setScope(info.info.scope);
          setAvailable("Operator endpoint enabled");
        }
      })
      .catch(() => {
        if (active) setAvailable("Operator endpoint disabled or unavailable");
      });
    return () => {
      active = false;
    };
  }, []);
  async function run(action: () => Promise<void>) {
    if (workspace.busy) return;
    workspace.busy = true;
    changed();
    try {
      await action();
    } catch (error) {
      workspace.status = errorText(error);
    } finally {
      workspace.busy = false;
      changed();
    }
  }
  async function load() {
    const view = await readInterface();
    const compiled = "builtin" in view ? view.builtin : view.published.compiled;
    workspace.compiled = compiled;
    workspace.draft = compiled.canonical;
    workspace.status = "Loaded complete definition. Edits have no runtime effect.";
  }
  async function format(definition: Definition) {
    const response = await request({ format: definition });
    if (!("compiled" in response)) throw new Error("Missing complete definition");
    workspace.compiled = response.compiled;
    workspace.draft = response.compiled.canonical;
    workspace.status = "Visual edit validated. Review before publication.";
  }
  const definition = workspace.compiled?.definition;
  const session = workspace.session;
  const graph = definition ? diagram(definition) : null;
  const screen = definition?.screens.find((value) => `screen:${value.name}` === selected);
  return (
    <main className="definition-editor">
      <Link to="/atlas">Back to atlas</Link>
      <div className="page-heading">
        <div>
          <p className="eyebrow">OPERATIONS / INTERFACE</p>
          <h1>Definition</h1>
          <p>One complete program across SQL, Form and Canvas.</p>
        </div>
      </div>
      <p>{available}. Compilation and visual edits do not publish changes.</p>
      {!canInspect && (
        <p>
          Current definition access is unavailable. Exact pending submissions remain recoverable.
        </p>
      )}
      {canInspect && (
        <>
          <div className="editor-toolbar">
            <button disabled={workspace.busy} onClick={() => void run(load)}>
              Load current definition
            </button>
            <button
              disabled={workspace.busy || !scope}
              onClick={() =>
                void run(async () => {
                  workspace.compiled = await compile(workspace.draft);
                  workspace.status = "Complete program validated; not published.";
                })
              }
            >
              Validate program
            </button>
            <nav aria-label="Definition views">
              {(["sql", "form", "canvas"] as const).map((view) => (
                <button key={view} aria-pressed={mode === view} onClick={() => setMode(view)}>
                  {view === "sql" ? "SQL" : view === "form" ? "Form" : "Canvas"}
                </button>
              ))}
            </nav>
          </div>
          {mode === "sql" ? (
            <label>
              Interface SQL
              <textarea
                aria-label="Interface SQL"
                maxLength={64 * 1024}
                spellCheck={false}
                value={workspace.draft}
                disabled={workspace.busy}
                onChange={(event) => {
                  workspace.draft = event.target.value;
                  workspace.compiled = null;
                  changed();
                }}
              />
            </label>
          ) : !definition ? (
            <p>Load or validate a complete program first.</p>
          ) : (
            <>
              <label>
                Theme
                <select
                  aria-label="Interface theme"
                  disabled={workspace.busy || !scope}
                  value={definition.theme}
                  onChange={(event) =>
                    void run(() => format({ ...definition, theme: event.target.value }))
                  }
                >
                  {definition.themes.map((theme) => (
                    <option key={theme.name}>{theme.name}</option>
                  ))}
                </select>
              </label>
              {mode === "form" ? (
                <div className="definition-form">
                  {definition.screens.map((item, index) => (
                    <fieldset key={item.name}>
                      <legend>
                        {item.name} · {item.renderer}
                      </legend>
                      <label>
                        Screen label
                        <input
                          aria-label={`${item.name} label`}
                          key={item.label}
                          defaultValue={item.label}
                          disabled={workspace.busy || !scope}
                          onBlur={(event) => {
                            if (event.target.value !== item.label)
                              void run(() =>
                                format({
                                  ...definition,
                                  screens: definition.screens.map((value, at) =>
                                    at === index ? { ...value, label: event.target.value } : value,
                                  ),
                                }),
                              );
                          }}
                        />
                      </label>
                      <p>
                        {item.path} · {item.area} · binding {item.binding}
                      </p>
                    </fieldset>
                  ))}
                </div>
              ) : (
                <>
                  <ul className="definition-canvas" aria-label="Definition graph">
                    {graph?.nodes.map((node) => (
                      <li key={node.id}>
                        <button
                          aria-pressed={selected === node.id}
                          onClick={() => setSelected(node.id)}
                        >
                          {node.kind}: {node.label}
                        </button>
                      </li>
                    ))}
                  </ul>
                  <ul aria-label="Definition connections">
                    {graph?.edges.map((edge) => (
                      <li key={`${edge.from}/${edge.to}`}>
                        {edge.from} → {edge.to}
                      </li>
                    ))}
                  </ul>
                  {screen && (
                    <label>
                      Selected screen label
                      <input
                        aria-label="Selected screen label"
                        key={screen.label}
                        defaultValue={screen.label}
                        disabled={workspace.busy || !scope}
                        onBlur={(event) => {
                          if (event.target.value !== screen.label)
                            void run(() =>
                              format({
                                ...definition,
                                screens: definition.screens.map((value) =>
                                  value.name === screen.name
                                    ? { ...value, label: event.target.value }
                                    : value,
                                ),
                              }),
                            );
                        }}
                      />
                    </label>
                  )}
                </>
              )}
            </>
          )}
        </>
      )}
      <section aria-label="Operator admission">
        <h2>Operator</h2>
        <p>
          The private key stays in this browser session. Current Transit grants and application
          policy authorize each operation.
        </p>
        {session ? (
          <p>
            Principal {session.principal} · realm {session.scope.realm} · application{" "}
            {session.scope.application}
          </p>
        ) : (
          <>
            <label>
              Operator principal
              <input
                aria-label="Operator principal"
                inputMode="numeric"
                value={principal}
                onChange={(event) => setPrincipal(event.target.value)}
              />
            </label>
            <label>
              Private signing key (PKCS#8)
              <input
                aria-label="Operator key"
                type="file"
                disabled={!scope || workspace.busy}
                onChange={(event) => {
                  const file = event.target.files?.[0];
                  event.target.value = "";
                  if (!file || !scope) return;
                  void run(async () => {
                    const id = Number(principal);
                    if (!Number.isSafeInteger(id) || id <= 0 || file.size > 512)
                      throw new Error("Invalid operator credential");
                    const key = await importOperatorKey(await file.arrayBuffer());
                    const next = new OperatorSession(scope, id, keySigner(key));
                    await next.read({ identity: {} });
                    workspace.session = next;
                    workspace.status = "Operator identity verified.";
                  });
                }}
              />
            </label>
          </>
        )}
        <button
          disabled={
            !canInspect ||
            !session ||
            !workspace.compiled ||
            workspace.busy ||
            session.pending !== null
          }
          onClick={() =>
            void run(async () => {
              if (workspace.review) {
                const previous = await session!.read({
                  state: {
                    operation: workspace.review.proposal.operation,
                    record: workspace.review.proposal.record,
                    input: 0,
                  },
                });
                if (!("state" in previous)) throw new Error("Missing application state");
                const receipt = previous.state.receipt;
                if (
                  (receipt && receipt.phase !== "applied" && receipt.phase !== "abandoned") ||
                  (receipt?.phase === "abandoned" &&
                    receipt.owns_record &&
                    previous.state.upload?.reserved !== false) ||
                  (!receipt && workspace.review.lastInput !== 0)
                )
                  throw new Error(
                    "Finish publication or abandon and collect the retained upload before replacing it",
                  );
              }
              workspace.review = await reviewPublication(session!, workspace.compiled!);
              workspace.status =
                "Review the exact base, revision and publication digest before applying.";
            })
          }
        >
          Review publication
        </button>
        {workspace.review && canInspect && (
          <div className="publication-review" aria-label="Publication review">
            <details>
              <summary>Exact reviewed program</summary>
              <pre>{workspace.review.compiled.canonical}</pre>
            </details>
            {workspace.draft !== workspace.review.compiled.canonical && (
              <p>The editor draft differs. Publication uses the reviewed program shown here.</p>
            )}
            <p>
              Base {workspace.review.proposal.expected} → revision{" "}
              {workspace.review.proposal.revision}
            </p>
            <p>
              Operation {workspace.review.proposal.operation} · record{" "}
              {workspace.review.proposal.record}
            </p>
            <code>
              {workspace.review.proposal.spec.digest
                .map((byte) => byte.toString(16).padStart(2, "0"))
                .join("")}
            </code>
            <button
              onClick={() =>
                download("transit-reviewed-publication.json", JSON.stringify(workspace.review))
              }
            >
              Save reviewed plan
            </button>
            <button
              disabled={!session || workspace.busy || session.pending !== null}
              onClick={() =>
                void run(() =>
                  publish(session!, workspace.review!, (text) => {
                    workspace.status = text;
                    changed();
                  }),
                )
              }
            >
              Publish reviewed definition
            </button>
            <button
              disabled={workspace.busy || !session || !!session.pending}
              onClick={() =>
                void run(() =>
                  abandonPublication(session!, workspace.review!, (text) => {
                    workspace.status = text;
                    changed();
                  }),
                )
              }
            >
              Abandon upload and release staging
            </button>
            <p>
              Abandonment closes only an unpublished upload. Applied revisions and retained history
              remain.
            </p>
          </div>
        )}
        {session && (
          <button
            disabled={workspace.busy || session.pending !== null}
            onClick={() => {
              workspace.session = null;
              workspace.status =
                "Operator disconnected; the reviewed operation remains available for recovery.";
              changed();
            }}
          >
            Disconnect operator
          </button>
        )}
        {session?.pending && (
          <div role="alert">
            <p>A submission is unresolved. Keep its exact identity until its outcome is known.</p>
            <button
              disabled={workspace.busy}
              onClick={() =>
                void run(async () => {
                  const input = await session.retry();
                  if (workspace.review) workspace.review.lastInput = input;
                  workspace.status =
                    "Native admission recovered. Resume the reviewed publication to inspect its durable outcome.";
                })
              }
            >
              Retry exact submission
            </button>
            <button
              onClick={() => download("transit-pending-application.json", session.exportPending())}
            >
              Save pending submission
            </button>
          </div>
        )}
        {session && (
          <label>
            Restore reviewed plan
            <input
              aria-label="Restore reviewed plan"
              type="file"
              disabled={workspace.busy}
              onChange={(event) => {
                const file = event.target.files?.[0];
                event.target.value = "";
                if (file)
                  void run(async () => {
                    if (file.size > 1024 * 1024) throw new Error("Reviewed plan too large");
                    const review = restoreReview(await file.text(), session);
                    if (review.compiled.definition.realm !== session.scope.realm)
                      throw new Error("Reviewed plan has another realm");
                    workspace.review = review;
                    workspace.compiled = review.compiled;
                    workspace.draft = review.compiled.canonical;
                    workspace.status = "Reviewed plan restored; its original base remains frozen.";
                  });
              }}
            />
          </label>
        )}
        {session && (
          <label>
            Restore pending submission
            <input
              aria-label="Restore pending submission"
              type="file"
              disabled={workspace.busy || session.pending !== null}
              onChange={(event) => {
                const file = event.target.files?.[0];
                event.target.value = "";
                if (file)
                  void run(async () => {
                    if (file.size > 16384) throw new Error("Pending submission too large");
                    session.restorePending(await file.text());
                    workspace.status = "Exact pending submission restored.";
                  });
              }}
            />
          </label>
        )}
      </section>
      <p role="status">{workspace.status}</p>
    </main>
  );
}
