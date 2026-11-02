import { atlas } from "@transit/board-client/evidence";
import { BoardError } from "@transit/board-client/request";
import { message } from "./inspection-state";
import { useRead } from "./use-observation";
export type AtlasCursor = { position: number; process_after?: number; resource_after?: number };
/** One authorized page; continuation never becomes an automatically restarted scan. */
export function useAtlasObservation(cursor?: AtlasCursor, revision = 0) {
  const state = useRead(
    JSON.stringify(["atlas", cursor, revision]),
    (signal) => atlas(cursor, signal),
    cursor ? 0 : 5000,
  );
  return {
    data: state.value,
    error: state.failure ? message(new BoardError(0, state.failure.code)) : "",
  };
}
