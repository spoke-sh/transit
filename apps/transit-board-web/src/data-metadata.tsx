import { Link } from "@tanstack/react-router";
import { useScope } from "./state";
import { useRead } from "./use-observation";
import { ReadStatus } from "./read-status";
import type { ReadFailure } from "./observation";
export function useMetadata<T>(key: string, read: (signal: AbortSignal) => Promise<T>) {
  const scope = useScope().scope;
  const state = useRead(`${scope?.realm}/${key}`, read);
  return { value: state.value, error: state.failure, retry: state.retry };
}
export function Unavailable({ error, retry }: { error: ReadFailure | null; retry: () => void }) {
  return (
    <>
      <ReadStatus failure={error} retry={retry} subject="Data" />
      {error && <Link to="/operations">Open Operations</Link>}
    </>
  );
}
