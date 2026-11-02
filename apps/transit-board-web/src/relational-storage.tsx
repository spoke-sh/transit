import { useState } from "react";
import { relationalQuery, type RelationalDescription } from "@transit/board-client/relational";
import { QueryError } from "@transit/query-client/error";
import { useRead } from "./use-observation";
import { ReadStatus } from "./read-status";
import { TableStorageView } from "./storage";
type Source = RelationalDescription["sources"][number];
export function TableStorage({ source, route }: { source: Source; route: number }) {
  const [visible, setVisible] = useState(false);
  return (
    <section aria-label={`Storage for ${source.alias}`}>
      <button onClick={() => setVisible(!visible)}>
        {visible ? "Hide" : "Inspect"} storage for {source.alias}
      </button>
      {visible && <TableStorageRead source={source} route={route} />}
    </section>
  );
}
function TableStorageRead({ source, route }: { source: Source; route: number }) {
  const state = useRead(
    JSON.stringify(["relational-storage", route, source.binding]),
    async (signal) => {
      const result = await relationalQuery({ storage: { route, binding: source.binding } }, signal);
      if (!("storage" in result)) throw new QueryError(0, "InvalidResponse");
      return result.storage;
    },
  );
  return state.value ? (
    <TableStorageView page={state.value} />
  ) : (
    <ReadStatus failure={state.failure} retry={state.retry} subject="Table storage" />
  );
}
