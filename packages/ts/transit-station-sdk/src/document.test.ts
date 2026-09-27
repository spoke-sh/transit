import assert from "node:assert/strict";
import test from "node:test";
import { HandlerError, TurnExpired } from "@transit/client";
import { DocumentOwner } from "./document.ts";
import { register, Scope } from "./context.ts";
import type { Bridge } from "./bridge.ts";
import type { Turn } from "./turn.ts";
import type { GrowingEvent } from "./wire.ts";

for (const observed of [true, false]) {
  test(`Document progress remains a scoped operation when ${observed ? "awaited" : "dropped"}`, async () => {
    const scope = new Scope(() => false);
    const turn = {} as Turn;
    const bridge = {
      caps: { document_owner: true },
      async apply() {
        return {
          document: {
            progress: { phase: "checkpoint_complete", revision: "18446744073709551615" },
          },
        };
      },
    } as unknown as Bridge;
    register(turn, { scope, bridge, token: 1, event: {} as GrowingEvent });
    let owner: DocumentOwner | undefined;
    await scope.invoke(async () => {
      owner = new DocumentOwner(turn, 1n);
      const progress = owner.checkpoint(1n);
      if (observed) assert.equal((await progress).revision, 18446744073709551615n);
      // Let an unobserved operation finish before returning. Internal conversion
      // must not count as observation by the handler.
      await new Promise((resolve) => setTimeout(resolve, 5));
    });
    const failure = await scope.seal();
    if (observed) assert.equal(failure, undefined);
    else assert.ok(failure instanceof HandlerError);
    await scope.invoke(async () => {
      assert.throws(() => owner?.retire(), TurnExpired);
    });
  });
}
