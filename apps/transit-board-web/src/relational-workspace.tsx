import { useCallback, useEffect, useRef, useState } from "react";
import {
  BoardError,
  relationalQuery,
  type RelationalProfile,
  type RelationalDescription,
  type RelationalOpened,
  type RelationalPage,
  type RelationalReference,
} from "@transit/board-client";
import { QueryDiagnostic } from "./query-diagnostic";
import type { Diagnostic } from "@transit/query-client";

type Statement = { sql: string; routes: number[] };
// Recovery identities outlive route components. No result or credential is saved.
const retained: {
  reference: RelationalReference | null;
  pending: { id: string; statement: Statement } | null;
  ordinal: string;
} = { reference: null, pending: null, ordinal: "0" };
function freshId() {
  const bytes = crypto.getRandomValues(new Uint8Array(16));
  bytes[0] = bytes[0]! | 1;
  return Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("");
}

/** Explicit relational operations; edits never create a query or advance a page. */
export function RelationalWorkspace() {
  const [sql, setSql] = useState("");
  const [routes, setRoutes] = useState<number[]>([0]);
  const [profile, setProfile] = useState<RelationalProfile | null>(null);
  const [proposed, setProposed] = useState<RelationalDescription | null>(null);
  const [opened, setOpened] = useState<RelationalOpened | null>(null);
  const [page, setPage] = useState<RelationalPage | null>(null);
  const [error, setError] = useState("");
  const [diagnostic, setDiagnostic] = useState<Diagnostic | null>(null);
  const [busy, setBusy] = useState(false);
  const [recovery, changed] = useState(0);
  const flight = useRef<AbortController | null>(null);
  const clear = useCallback(() => {
    setProfile(null);
    setProposed(null);
    setOpened(null);
    setPage(null);
    setDiagnostic(null);
  }, []);
  const attempt = useCallback(
    async (work: (signal: AbortSignal) => Promise<void>) => {
      if (flight.current || document.hidden) return;
      const controller = new AbortController();
      flight.current = controller;
      setBusy(true);
      setError("");
      setDiagnostic(null);
      try {
        await work(controller.signal);
      } catch (cause) {
        clear();
        if (!controller.signal.aborted) {
          if (cause instanceof BoardError) {
            setError(
              cause.code === "QueryDisabled"
                ? "Relational queries are not configured on this Board instance."
                : `Relational query unavailable (${cause.code}). Any returned prefix remains incomplete. Retry the original operation or inspect the active query.`,
            );
            if (
              cause.code === "Forbidden" ||
              cause.code === "StateResourceExpired" ||
              cause.code === "HistoryReclaimed"
            )
              setSql("");
            else setDiagnostic(cause.diagnostic ?? null);
          } else
            setError(
              "Connection unavailable. Inspect the active query or retry the original operation; no replacement query was started.",
            );
        }
      } finally {
        if (flight.current === controller) flight.current = null;
        setBusy(false);
        changed((value) => value + 1);
      }
    },
    [clear],
  );
  const inspect = useCallback(
    (signal: AbortSignal) =>
      relationalQuery({ describe: {} }, signal).then((result) => {
        if (signal.aborted || document.hidden || !("description" in result)) return;
        const value = result.description;
        if (
          value.active &&
          retained.pending &&
          value.active.opened.reference.id !== retained.pending.id
        )
          throw new BoardError(409, "QueryConflict");
        setProfile(value);
        setProposed(null);
        setPage(null);
        setOpened(value.active?.opened ?? null);
        retained.reference = value.active?.opened.reference ?? null;
        retained.ordinal = value.active?.ordinal ?? "0";
        if (value.active) retained.pending = null;
      }),
    [],
  );
  const read = useCallback(
    async (ordinal: string, signal: AbortSignal) => {
      const reference = retained.reference;
      if (!reference) throw new BoardError(409, "QueryExpired");
      const result = await relationalQuery({ query: { page: { reference, ordinal } } }, signal);
      if (signal.aborted || document.hidden || !("query" in result) || !("page" in result.query))
        return;
      const value = result.query.page;
      if (
        value.row &&
        opened &&
        (value.row.cells.length !== opened.description.columns.length ||
          value.row.cells.some((cell, index) => {
            const column = opened.description.columns[index]!;
            if ("null" in cell) return !column.nullable;
            return (
              !("value" in cell) ||
              !("atom" in cell.value) ||
              ("int64" in column.type
                ? !("signed" in cell.value.atom)
                : !("unsigned" in cell.value.atom))
            );
          }))
      )
        throw new BoardError(0, "InvalidResponse");
      retained.ordinal = ordinal;
      setPage(value);
    },
    [opened],
  );
  useEffect(() => {
    const hidden = () => {
      if (document.hidden) {
        flight.current?.abort();
        clear();
      } else if (retained.reference) void attempt(inspect);
    };
    document.addEventListener("visibilitychange", hidden);
    return () => {
      document.removeEventListener("visibilitychange", hidden);
      flight.current?.abort();
    };
  }, [attempt, clear, inspect]);
  useEffect(() => {
    if (!page) return;
    const timer = setInterval(() => void attempt((signal) => read(page.ordinal, signal)), 5000);
    return () => clearInterval(timer);
  }, [page, read, attempt]);
  const open = () =>
    attempt(async (signal) => {
      retained.pending ??= { id: freshId(), statement: { sql, routes: [...routes] } };
      const result = await relationalQuery({ query: { open: retained.pending } }, signal);
      if (signal.aborted || document.hidden || !("query" in result) || !("opened" in result.query))
        return;
      const value = result.query.opened;
      retained.reference = value.reference;
      retained.ordinal = "0";
      retained.pending = null;
      setOpened(value);
      setPage(null);
    });
  void recovery;
  return (
    <section aria-label="Relational worksheet">
      <h2>Relational worksheet</h2>
      <p>
        Explicit Table joins and groups. One active query is shared by viewers of this Board
        instance.
      </p>
      <button disabled={busy} onClick={() => void attempt(inspect)}>
        Inspect relational workspace
      </button>
      {profile && (
        <>
          <p>Catalog routes · metadata observation only</p>
          <ul>
            {profile.routes.map((route, index) => (
              <li key={index}>
                Route {index}: realm {route.connection.scope.realm}, resource{" "}
                {route.connection.scope.resource}, catalog {route.connection.scope.catalog}, owner{" "}
                {route.connection.owner}; metadata revision {route.resource_revision}, policy{" "}
                {route.policy_revision}
              </li>
            ))}
          </ul>
        </>
      )}
      <label>
        Relational SQL
        <textarea
          aria-label="Relational SQL"
          value={sql}
          maxLength={4096}
          onChange={(event) => {
            setSql(event.target.value);
            setProposed(null);
          }}
        />
      </label>
      <fieldset disabled={busy || !profile}>
        <legend>Catalog route for each SQL target</legend>
        {routes.map((route, index) => (
          <label key={index}>
            {index === 0 ? "FROM" : "JOIN"} route
            <select
              aria-label={`${index === 0 ? "FROM" : "JOIN"} route`}
              value={route}
              onChange={(event) => {
                setRoutes((current) =>
                  current.map((v, i) => (i === index ? Number(event.target.value) : v)),
                );
                setProposed(null);
              }}
            >
              {profile?.routes.map((_, i) => (
                <option key={i} value={i}>
                  Route {i}
                </option>
              ))}
            </select>
          </label>
        ))}
        <button
          onClick={() => {
            setRoutes((current) => (current.length === 1 ? [...current, 0] : current.slice(0, 1)));
            setProposed(null);
          }}
        >
          {routes.length === 1 ? "Add JOIN route" : "Remove JOIN route"}
        </button>
      </fieldset>
      <button
        disabled={busy || !profile || !sql}
        onClick={() =>
          void attempt(async (signal) => {
            const result = await relationalQuery({ query: { explain: { sql, routes } } }, signal);
            if (
              !signal.aborted &&
              !document.hidden &&
              "query" in result &&
              "explained" in result.query
            )
              setProposed(result.query.explained);
          })
        }
      >
        Explain relational query
      </button>
      <button
        disabled={busy || !!retained.reference || (!retained.pending && (!profile || !sql))}
        onClick={() => void open()}
      >
        {retained.pending ? "Retry original open" : "Run relational query"}
      </button>
      <button
        disabled={busy || !retained.reference}
        onClick={() =>
          void attempt(async (signal) => {
            await relationalQuery({ query: { close: retained.reference! } }, signal);
            if (signal.aborted) return;
            retained.reference = null;
            retained.pending = null;
            retained.ordinal = "0";
            setOpened(null);
            setPage(null);
          })
        }
      >
        Close relational query
      </button>
      {proposed && (
        <div>
          <h3>Proposed plan · not executed</h3>
          <code>{proposed.plan}</code>
          <p>
            Sources:{" "}
            {proposed.sources
              .map(
                (source) => `${source.alias}: resource ${source.resource}, object ${source.object}`,
              )
              .join("; ")}
          </p>
          <p>Outputs: {proposed.columns.map((column) => column.name).join(", ")}</p>
        </div>
      )}
      {opened && (
        <div>
          <h3>Active query</h3>
          <p>Query {opened.reference.id}</p>
          <p>
            Plan <code>{opened.reference.plan}</code>
          </p>
          <p>
            Basis <code>{opened.reference.basis}</code>
          </p>
          <ul>
            {opened.cuts.map((cut, index) => (
              <li key={index}>
                {opened.description.sources[index]!.alias}: resource {cut.resource}, revision{" "}
                {cut.revision}, schema <code>{cut.schema}</code>
              </li>
            ))}
          </ul>
          <p>
            Per-resource snapshot vector; different resources do not share a global transaction.
          </p>
          <button
            disabled={busy}
            onClick={() => void attempt((signal) => read(retained.ordinal, signal))}
          >
            Read current relational page
          </button>
          <button
            disabled={busy || !page?.row}
            onClick={() =>
              void attempt((signal) => read((BigInt(retained.ordinal) + 1n).toString(), signal))
            }
          >
            Next relational page
          </button>
        </div>
      )}
      {page && (
        <div>
          <h3>
            {page.complete_coverage ? "Complete coverage" : "Incomplete prefix"} · page{" "}
            {page.ordinal}
          </h3>
          {page.row && opened && (
            <div className="table-scroll">
              <table>
                <caption>One current authorized row</caption>
                <thead>
                  <tr>
                    {opened.description.columns.map((column, index) => (
                      <th key={index}>{column.name}</th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  <tr>
                    {page.row.cells.map((cell, index) => (
                      <td key={index}>
                        {"null" in cell
                          ? "NULL"
                          : "value" in cell && "atom" in cell.value
                            ? "signed" in cell.value.atom
                              ? cell.value.atom.signed
                              : "unsigned" in cell.value.atom
                                ? cell.value.atom.unsigned
                                : "Invalid scalar"
                            : "Invalid cell"}
                      </td>
                    ))}
                  </tr>
                </tbody>
              </table>
            </div>
          )}
          <p>
            Current-page reads recheck every source. Only terminal coverage completes the result.
          </p>
        </div>
      )}
      <p role="status">{busy ? "Reading relational state…" : error}</p>
      {diagnostic && <QueryDiagnostic value={diagnostic} />}
    </section>
  );
}
