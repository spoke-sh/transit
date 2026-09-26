#!/usr/bin/env node
import { readFile } from "node:fs/promises";
import { ProcessRef } from "@transit/client";
import { Activation, Runner, type ServiceConfig } from "@transit/station";
import { Counter, Requester } from "./counter.ts";
import { counterCodec, requesterCodec } from "./codecs.ts";

const [path, role, flag, count] = process.argv.slice(2);
if (
  !path ||
  (role !== "service" && role !== "requester") ||
  (flag !== undefined && flag !== "--commits")
)
  throw new TypeError("Usage: transit-node-counter CONFIG service|requester [--commits N]");
let remaining = count === undefined ? 1 : Number(count);
if (!Number.isSafeInteger(remaining) || remaining < 1)
  throw new TypeError("--commits must be positive");
const value = JSON.parse(await readFile(path, "utf8"));
const config: ServiceConfig = {
  url: value.url,
  profile: value.profile,
  activation: new Activation(
    new ProcessRef(value.realm, value.pid),
    value.principal,
    value.generation,
    value.seed_file,
  ),
};
const options = { failure: "stop" as const, recovery: { kind: "fence-on-restart" as const } };
const runner =
  role === "service"
    ? await Runner.open(config, new Counter(), counterCodec, options)
    : await Runner.open(
        config,
        new Requester(new ProcessRef(value.realm, value.peer)),
        requesterCodec,
        options,
      );
try {
  for await (const event of runner.run()) {
    if (event.kind !== "committed") throw new Error(`Runner stopped with ${event.kind}`);
    console.log(JSON.stringify({ input: event.inputPosition, committed: event.receipt.position }));
    if (--remaining === 0) break;
  }
} finally {
  await runner.close();
}
