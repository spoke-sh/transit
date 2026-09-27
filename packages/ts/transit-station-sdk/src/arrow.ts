import { tableFromIPC, type Table } from "apache-arrow";
import { IncompatibleNative } from "@transit/client";
import { IpcSegment } from "./query.ts";
import { Page } from "./unified.ts";

/** Decode one owned stream. The manifest remains the complete-result evidence. */
export function toArrow(segment: IpcSegment): Table {
  if (!(segment instanceof IpcSegment)) throw new TypeError("Expected an owned IPC segment");
  const table = tableFromIPC(segment.ipc);
  if (BigInt(table.numRows) !== segment.rows)
    throw new IncompatibleNative("Arrow row count differs from the native segment");
  return table;
}

/** Keep nested cell states and alternatives; do not coerce them into nullable scalars. */
export function unifiedToArrow(page: Page): Table {
  if (!(page instanceof Page)) throw new TypeError("Expected an owned unified page");
  const table = tableFromIPC(page.ipc);
  if (table.numRows !== page.rows) throw new IncompatibleNative("Arrow row coverage changed");
  return table;
}
