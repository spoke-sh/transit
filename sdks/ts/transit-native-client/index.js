import { fileURLToPath } from "node:url";
// Resolution is local; importing this package starts no process or I/O.
export const hostPath = fileURLToPath(new URL("./bin/transit-client-host", import.meta.url));
export const version = "0.2.0";
