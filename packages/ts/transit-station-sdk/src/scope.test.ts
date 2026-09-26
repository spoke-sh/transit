import assert from "node:assert/strict";
import test from "node:test";
import { Busy, HandlerError, TurnExpired } from "@transit/client";
import { Scope } from "./scope.ts";

const pause = (): Promise<void> => new Promise((resolve) => setTimeout(resolve, 15));

test("observed operations serialize; completed scopes reject saved continuations", async () => {
  const scope = new Scope(() => false);
  await scope.invoke(async () => {
    assert.equal(await scope.operation(async () => 37), 37);
    await assert.rejects(
      scope.operation(async () => {
        throw new Error("private validation failed");
      }),
    );
    assert.equal(await scope.operation(async () => 38), 38);
  });
  assert.equal(await scope.seal(), undefined);
  await scope.invoke(async () => {
    assert.throws(() => scope.operation(async () => 0), TurnExpired);
  });
});

test("overlap and foreign contexts cannot share an active turn", async () => {
  const scope = new Scope(() => false);
  let release!: () => void;
  const gate = new Promise<void>((resolve) => {
    release = resolve;
  });
  const handler = scope.invoke(async () => {
    const first = scope.operation(() => gate);
    assert.throws(() => scope.operation(async () => {}), Busy);
    await first;
  });
  assert.throws(() => scope.operation(async () => {}), Busy);
  release();
  await handler;
  assert.equal(await scope.seal(), undefined);
});

for (const failure of [false, true]) {
  test(`dropped ${failure ? "failed" : "successful"} operations prevent freezing success`, async () => {
    const scope = new Scope(() => false);
    let completed = false;
    await scope.invoke(async () => {
      void scope.operation(async () => {
        await pause();
        completed = true;
        if (failure) throw new Error("unobserved operation");
      });
    });
    assert.ok((await scope.seal()) instanceof HandlerError);
    assert.equal(completed, true);
  });
}
