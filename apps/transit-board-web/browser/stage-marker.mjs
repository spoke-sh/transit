import { renameSync, writeFileSync } from "node:fs";

// Each fixture has one writer per marker. Replacing the inode keeps a reader
// from appending bytes from the next stage to a read of the previous stage.
export function publishStage(marker, stage) {
  const pending = marker + ".next";
  writeFileSync(pending, stage);
  renameSync(pending, marker);
}
