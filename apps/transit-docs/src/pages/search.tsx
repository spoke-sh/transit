import { useEffect, useState, type ReactElement } from "react";
import Layout from "@theme/Layout";
import Link from "@docusaurus/Link";
import useBaseUrl from "@docusaurus/useBaseUrl";

type SearchEntry = { title: string; route: string; text: string };
function decodeIndex(value: unknown): SearchEntry[] {
  if (
    !Array.isArray(value) ||
    !value.every((entry: unknown) => {
      if (!entry || typeof entry !== "object") return false;
      const record = entry as Record<string, unknown>;
      return ["title", "route", "text"].every((key) => typeof record[key] === "string");
    })
  )
    throw new Error("Invalid documentation index");
  return value as SearchEntry[];
}

export default function Search(): ReactElement {
  const [query, setQuery] = useState("");
  const [index, setIndex] = useState<SearchEntry[]>([]);
  const [status, setStatus] = useState("Loading search index…");
  const url = useBaseUrl("/search-index.json");
  useEffect(() => {
    const controller = new AbortController();
    fetch(url, { signal: controller.signal })
      .then(async (response) => {
        if (!response.ok) throw new Error("Search index unavailable");
        setIndex(decodeIndex(await response.json()));
        setStatus("");
      })
      .catch(() => {
        if (!controller.signal.aborted)
          setStatus("Search is unavailable. Use the documentation sidebar to browse.");
      });
    return () => controller.abort();
  }, [url]);
  const words = query.toLowerCase().trim().split(/\s+/).filter(Boolean).slice(0, 8);
  const results = words.length
    ? index
        .filter((entry) =>
          words.every((word) => `${entry.title} ${entry.text}`.toLowerCase().includes(word)),
        )
        .sort(
          (a, b) =>
            Number(words.every((word) => b.title.toLowerCase().includes(word))) -
            Number(words.every((word) => a.title.toLowerCase().includes(word))),
        )
        .slice(0, 20)
    : [];
  return (
    <Layout
      title="Search"
      description="Search Transit guides, interface references and Internals locally."
    >
      <main className="container search-page">
        <h1>Search documentation</h1>
        <p>
          Search guides, concepts, commands, generated API fields and Internals. Searches stay in
          your browser.
        </p>
        <label htmlFor="docs-search">Words or an interface name</label>
        <input
          id="docs-search"
          type="search"
          maxLength={200}
          value={query}
          onChange={(event) => setQuery(event.target.value)}
          placeholder="SQL, app install, session…"
        />
        <p role="status">
          {status ||
            (words.length
              ? `${results.length} results${results.length === 20 ? " (showing the first 20)" : ""}`
              : "Enter a search term to begin.")}
        </p>
        <ul className="search-results">
          {results.map((entry) => {
            const start = Math.max(0, entry.text.toLowerCase().indexOf(words[0]!) - 60);
            return (
              <li key={entry.route}>
                <h2>
                  <Link to={`/${entry.route}`}>{entry.title}</Link>
                </h2>
                <p>
                  {entry.route === "internals" || entry.route.startsWith("internals/")
                    ? "Internals"
                    : "Guides and reference"}
                </p>
                <p>
                  {start ? "…" : ""}
                  {entry.text.slice(start, start + 240)}…
                </p>
              </li>
            );
          })}
        </ul>
      </main>
    </Layout>
  );
}
