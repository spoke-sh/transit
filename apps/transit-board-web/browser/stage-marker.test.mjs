import {
  closeSync,
  mkdtempSync,
  openSync,
  readFileSync,
  readSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { expect, test } from "vite-plus/test";
import { publishStage } from "./stage-marker.mjs";

function observeAcrossPublication(publish) {
  const directory = mkdtempSync(join(tmpdir(), "transit-stage-marker-"));
  const marker = join(directory, "stage");
  let reader;
  try {
    writeFileSync(marker, "rotate-viewer");
    reader = openSync(marker, "r");
    const prefix = Buffer.alloc(13);
    expect(readSync(reader, prefix, 0, prefix.length, null)).toBe(13);
    publish(marker, "replace-viewer");
    const suffix = Buffer.alloc(1);
    const count = readSync(reader, suffix, 0, suffix.length, null);
    return {
      observed: prefix.toString() + suffix.subarray(0, count).toString(),
      published: readFileSync(marker, "utf8"),
    };
  } finally {
    if (reader !== undefined) closeSync(reader);
    rmSync(directory, { recursive: true, force: true });
  }
}

test("in-place marker publication reproduces the mixed-stage failure", () => {
  expect(observeAcrossPublication(writeFileSync)).toEqual({
    observed: "rotate-viewerr",
    published: "replace-viewer",
  });
});

test("atomic marker publication preserves an already-open stage reader", () => {
  expect(observeAcrossPublication(publishStage)).toEqual({
    observed: "rotate-viewer",
    published: "replace-viewer",
  });
});
