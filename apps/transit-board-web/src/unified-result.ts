import { BoardError, unifiedQuery } from "@transit/board-client";
import { verifiedPage as verify, type ReadPage } from "@transit/query-client";
export type { ResultPage, ReadPage } from "@transit/query-client";
export const readPage: ReadPage = async (namespace, cursor, signal) => {
  const response = await unifiedQuery({ page: { namespace, cursor } }, signal);
  if (!("page" in response)) throw new BoardError(0, "InvalidResponse");
  return response.page;
};
export const verifiedPage = (
  namespace: string,
  cursor: string | null,
  segments: string,
  signal: AbortSignal,
  read: ReadPage = readPage,
) => verify(namespace, cursor, segments, signal, read);
