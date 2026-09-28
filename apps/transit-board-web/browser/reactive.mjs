// Minimal protocol harness, not a Board view or a second application client.
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { chromium } from "@playwright/test";
const config = JSON.parse(readFileSync(process.argv[2], "utf8"));
const secret = [...readFileSync(config.private_key)];
const browser = await chromium.launch({
  headless: true,
  args: [`--ignore-certificate-errors-spki-list=${config.spki}`],
});
try {
  const context = await browser.newContext();
  // Grant only this owned loopback fixture origin the normal browser permission.
  await context.grantPermissions(["local-network-access"], { origin: config.origin });
  const page = await context.newPage();
  page.on("console", (message) => {
    if (message.type() === "error") console.error(message.text());
  });
  page.on("websocket", (socket) =>
    socket.on("socketerror", (error) => console.error(String(error))),
  );
  await page.route(`${config.origin}/reactive-harness.html`, (route) =>
    route.fulfill({
      contentType: "text/html",
      body: "<!doctype html><title>Reactive protocol proof</title>",
    }),
  );
  await page.goto(`${config.origin}/reactive-harness.html`);
  const result = await page.evaluate(
    async ({ config, secret }) => {
      const key = await crypto.subtle.importKey("pkcs8", new Uint8Array(secret), "Ed25519", false, [
        "sign",
      ]);
      const utf8 = new TextEncoder();
      const bytes = (...parts) => new Uint8Array(parts.flatMap((part) => [...part]));
      const le = (...values) => {
        const buffer = new Uint8Array(values.length * 8);
        values.forEach((value, i) =>
          new DataView(buffer.buffer).setBigUint64(i * 8, BigInt(value), true),
        );
        return buffer;
      };
      const hex = (value) => [...value].map((v) => v.toString(16).padStart(2, "0")).join("");
      const hash = async (value) => new Uint8Array(await crypto.subtle.digest("SHA-256", value));
      const sign = async (domain, value) => [
        ...new Uint8Array(
          await crypto.subtle.sign(
            "Ed25519",
            key,
            await hash(bytes(utf8.encode(domain + "\0"), value)),
          ),
        ),
      ];
      const scope = config.scope;
      let sequence = config.sequence;
      const identity = async () => {
        const query = {
          version: 3,
          realm: scope.realm,
          principal: scope.principal,
          kind: { identity: {} },
        };
        return {
          query,
          signature: await sign("transit.query.v3", utf8.encode(JSON.stringify(query))),
        };
      };
      const cursorBytes = (cursor) => {
        const p = cursor.position;
        return bytes(
          utf8.encode("SV1K"),
          [p.version],
          le(...Object.values(p.scope)),
          le(p.watch_revision, p.resource),
          p.schema,
          le(p.data_revision, p.outcome_position),
          cursor.signature,
        );
      };
      const read = async (
        kind = "session",
        attachment = 0,
        nonce = Array(16).fill(0),
        cursor = null,
      ) => {
        const request = { scope, kind, attachment, nonce, cursor };
        const encoded = bytes(
          utf8.encode("SV1U"),
          le(...Object.values(scope)),
          [{ session: 1, snapshot: 2, events: 3 }[kind]],
          le(attachment),
          nonce,
          [cursor ? 1 : 0],
          cursor ? cursorBytes(cursor) : [],
        );
        return {
          read: request,
          signature: await sign("transit.reactive.read.v1", encoded),
          identity: await identity(),
        };
      };
      const command = async (payload) => {
        const request = {
          version: 3,
          realm: scope.realm,
          principal: scope.principal,
          sequence: ++sequence,
          command: {
            send: {
              pid: scope.ingress,
              value: hex(bytes(utf8.encode("STN1"), [1], le(0), payload)),
            },
          },
        };
        return {
          request,
          signature: await sign("transit.request.v3", utf8.encode(JSON.stringify(request))),
        };
      };
      const attach = async (nonce, revision, cursor = null) => ({
        version: 1,
        attach: await command(
          bytes(
            utf8.encode("SV1c"),
            [5, 3],
            le(scope.session, scope.generation, revision - 1),
            nonce,
          ),
        ),
        read: await read("events", revision, nonce, cursor),
      });
      const post = async (path, value, expected = 200) => {
        const response = await fetch(path, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(value),
        });
        if (response.status !== expected) throw new Error(`HTTP ${path}: ${response.status}`);
        return response.json();
      };
      const servingRead = async (kind, operation = 0) => {
        const request = {
          realm: scope.realm,
          principal: scope.principal,
          service: scope.service,
          ingress: scope.ingress,
          kind,
          operation,
        };
        const encoded = bytes(
          utf8.encode("SV1r"),
          le(scope.realm, scope.principal, scope.service, scope.ingress),
          [{ discovery: 1, status: 2, result: 3 }[kind]],
          le(operation),
        );
        return {
          read: request,
          signature: await sign("transit.serving.read.v1", encoded),
          identity: await identity(),
        };
      };
      const discovery = await post("/reactive/v1/discovery", await servingRead("discovery"));
      for (const format of ["openapi", "asyncapi"]) {
        const response = await fetch(`/reactive/v1/${format}.json`);
        const digest = await hash(new Uint8Array(await response.arrayBuffer()));
        if (hex(digest) !== hex(discovery[`${format}_sha256`]))
          throw new Error("description digest mismatch");
      }
      const ws = new WebSocket(
        config.origin.replace("https:", "wss:") + "/reactive/v1/websocket",
        "transit.reactive.v1",
      );
      const queue = [];
      let closed = false,
        closeCode = null;
      ws.onmessage = (event) => {
        queue.push(JSON.parse(event.data));
        if (queue.length > 32) throw new Error("unbounded test queue");
      };
      ws.onclose = (event) => {
        closeCode = event.code;
        closed = true;
      };
      const until = async (kind) => {
        const deadline = Date.now() + 10000;
        while (Date.now() < deadline && !closed) {
          while (queue.length) {
            const message = queue.shift();
            if (kind in message) return message[kind];
            if (message.terminal) throw new Error(message.terminal.reason);
          }
          await new Promise((resolve) => setTimeout(resolve, 10));
        }
        throw new Error(
          `WebSocket missing ${kind}; closed=${closed}, code=${closeCode}, ready=${ws.readyState}`,
        );
      };
      const challenge = await until("challenge");
      ws.send(JSON.stringify({ attach: await attach(challenge.nonce, 1) }));
      await until("attached");
      const initial = await until("event");
      const payload = bytes(le("-9223372036854775808", "9223372036854775807"));
      const codec = new Uint8Array([1, 0]);
      const frozen = await command(
        bytes(
          utf8.encode("SV1c"),
          [3],
          le(10, 1),
          codec,
          le(config.deadline),
          [payload.length],
          payload,
        ),
      );
      ws.send(JSON.stringify({ command: frozen }));
      ws.close(); // No application acknowledgement observed here.
      const receipt = await post("/serving/v1/command", frozen, 202);
      const duplicate = await post("/serving/v1/command", frozen, 202);
      if (JSON.stringify(receipt) !== JSON.stringify(duplicate))
        throw new Error("fallback changed receipt");
      const next = (await post("/reactive/v1/challenge", await read())).challenge;
      const bootstrap = await attach(next.nonce, 2, initial.cursor);
      const response = await fetch("/reactive/v1/events", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Last-Event-ID": hex(cursorBytes(initial.cursor)),
        },
        body: JSON.stringify(bootstrap),
      });
      if (response.status !== 200) throw new Error(`SSE ${response.status}`);
      const input = response.body.getReader();
      const decoder = new TextDecoder("utf-8", { fatal: true });
      let text = "",
        outcome = false;
      try {
        while (!outcome) {
          const part = await input.read();
          if (part.done) throw new Error("SSE interrupted");
          text += decoder.decode(part.value, { stream: true });
          if (text.length > 32768) throw new Error("SSE buffer exceeded");
          let end;
          while ((end = text.indexOf("\n\n")) >= 0) {
            const fields = Object.fromEntries(
              text
                .slice(0, end)
                .split("\n")
                .filter((line) => line.includes(":"))
                .map((line) => {
                  const i = line.indexOf(":");
                  return [line.slice(0, i), line.slice(i + 1).trimStart()];
                }),
            );
            text = text.slice(end + 2);
            const item = JSON.parse(fields.data);
            if (item.terminal) throw new Error(item.terminal.reason);
            if (item.event) {
              if (fields.id !== hex(cursorBytes(item.event.cursor)))
                throw new Error("SSE id mismatch");
              outcome ||= item.event.event.outcome?.operation === 10;
            }
          }
        }
      } finally {
        await input.cancel();
      }
      const snapshot = await post("/reactive/v1/read", await read("snapshot", 2, next.nonce));
      if (
        !snapshot.snapshot.rows.some(
          (row) => row?.key === "-9223372036854775808" && row.value === "9223372036854775807",
        )
      )
        throw new Error("snapshot lost decimal values");
      return {
        sequence,
        websocket: true,
        sse: outcome,
        fallback: true,
        discovery: discovery.websocket && discovery.sse,
      };
    },
    { config, secret },
  );
  assert.ok(result.websocket && result.sse && result.fallback && result.discovery);
  console.log(JSON.stringify(result));
} finally {
  secret.fill(0);
  await browser.close();
}
