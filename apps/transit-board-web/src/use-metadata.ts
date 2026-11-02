import { BoardError } from "@transit/board-client";
import { message } from "./state";
import { useRead } from "./use-observation";
export function useMetadata<T>(
  resource: number,
  exchange: string,
  load: (resource: number, exchange: string, signal?: AbortSignal) => Promise<T>,
  continuation = "",
) {
  const state = useRead(JSON.stringify(["metadata", resource, exchange, continuation]), (signal) =>
    load(resource, exchange, signal),
  );
  return {
    page: state.value,
    error: state.failure ? message(new BoardError(0, state.failure.code)) : "",
  };
}
