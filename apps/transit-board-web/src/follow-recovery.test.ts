import { expect, test } from "vite-plus/test";
import { currentDefinition, LiveView, Session, type RefreshView } from "@transit/reactive-client";
import { RefreshPreparation, type Transport } from "@transit/query-client";
import { FollowRecovery } from "./follow-recovery";

const plan = {
  version: 1,
  definition: currentDefinition,
  key: "original",
  template: "1",
  limit: 2,
  captures: ["2", "3", "0", "0", "0", "0", "0", "0"],
  closing: false,
};
const selection = { session: { session: 5, generation: 6 }, generation: 9 };
const scope = {
  realm: 1,
  principal: 2,
  service: 3,
  ingress: 4,
  ...selection.session,
  subscription: 7,
  subscription_generation: 8,
};
const noQuery: Transport = async () => {
  throw new Error("Import must be inert");
};
const noRead = async (): Promise<never> => {
  throw new Error("Must not read rows");
};
function fixture() {
  const session = new Session();
  const view = new LiveView(session, noRead);
  const preparation = new RefreshPreparation(noQuery);
  return { session, view, preparation };
}
function changed(view: LiveView<unknown>, predicate: () => boolean) {
  if (predicate()) return Promise.resolve();
  return new Promise<void>((resolve) => {
    const stop = view.subscribe(() => {
      if (predicate()) {
        stop();
        resolve();
      }
    });
  });
}

test("tab recovery imports without starting, closing or displaying rows", async () => {
  const original = fixture();
  original.view.restoreRecovery(JSON.stringify({ ...plan, captures: null }));
  let bytes: string | null = null;
  const store = new FollowRecovery(() => ({
    getItem: () => bytes,
    setItem: (_key, value) => {
      bytes = value;
    },
  }));
  store.save(fixture());
  expect(bytes).toBeNull(); // Pausing an unused owner creates no stored record.
  store.save(original);
  const recovered = fixture();
  store.restore(recovered, noQuery);
  expect(store.error).toBeNull();
  await recovered.view.pause(); // A hidden renderer cannot resume saved work.
  expect(recovered.view.recoveryIdentity).toEqual(original.view.recoveryIdentity);
  expect(recovered.view.getSnapshot()).toMatchObject({ phase: "paused", snapshot: null });
  expect(recovered.view.following).toBe(false);
  // An explicit reset must replace an existing record rather than resurrect
  // the previously saved intent on the next tab load.
  store.save(fixture());
  const cleared = fixture();
  store.restore(cleared, noQuery);
  expect(cleared.view.recoveryIdentity).toBeNull();
});

test("a malformed composite leaves all operational owners and stored bytes untouched", () => {
  const original = fixture();
  original.view.restoreRecovery(JSON.stringify({ ...plan, captures: null }));
  let bytes = "";
  const store = new FollowRecovery(() => ({
    getItem: () => bytes,
    setItem: (_key, value) => {
      bytes = value;
    },
  }));
  store.save(original);
  const saved = JSON.parse(bytes);
  saved.view = JSON.stringify({ ...plan, definition: "foreign" });
  bytes = JSON.stringify(saved);
  const retained = bytes;
  const recovered = fixture();
  store.restore(recovered, noQuery);
  expect(store.error).not.toBeNull();
  expect(recovered.session.description).toBeNull();
  expect(recovered.view.recoveryIdentity).toBeNull();
  expect(recovered.preparation.recoveryIdentity).toBeNull();
  expect(bytes).toBe(retained);
  expect(() => store.save(recovered)).toThrow("follow_recovery_unavailable");
});

test("resume checks the accepted pool before opening, renewing or invalidating", async () => {
  const owner = fixture();
  owner.session.scope = scope;
  owner.session.selection = selection;
  owner.session.recoverSelection = async () => ({
    session: selection.session,
    expected: 0,
    template: "1",
    limit: 2,
    captures: ["4", ...plan.captures.slice(1)],
  });
  owner.session.open = async () => {
    throw new Error("Must not open");
  };
  owner.view.restoreRecovery(JSON.stringify(plan));
  const failed = changed(owner.view, () => owner.view.getSnapshot().phase === "reset_required");
  await owner.view.resume();
  await failed;
  expect(owner.view.getSnapshot().snapshot).toBeNull();
  expect(owner.view.recoveryIdentity?.captures).toEqual(plan.captures);
});

test("an exhausted saved Follow cannot acquire another budget", async () => {
  const owner = fixture();
  owner.session.scope = scope;
  owner.session.selection = selection;
  owner.session.recoverSelection = async () => ({
    session: selection.session,
    expected: 0,
    template: "1",
    limit: 2,
    captures: plan.captures,
  });
  owner.session.refreshStatus = async () =>
    ({ template: "1", limit: 2, starts: 2, phase: "exhausted" }) as RefreshView;
  owner.session.open = async () => {
    throw new Error("Must not open");
  };
  owner.view.restoreRecovery(JSON.stringify(plan));
  const stopped = changed(
    owner.view,
    () => owner.view.getSnapshot().refresh?.phase === "exhausted",
  );
  await owner.view.resume();
  await stopped;
  expect(owner.view.getSnapshot()).toMatchObject({ phase: "paused", snapshot: null });
  expect(owner.view.recoveryIdentity?.limit).toBe(2);
});

test("resume consumes the saved selection without preparing a replacement capture pool", async () => {
  const session = new Session();
  session.scope = scope;
  session.selection = selection;
  session.leaseBefore = Date.now() + 30000;
  session.recoverSelection = async () => ({
    session: selection.session,
    expected: 0,
    template: "1",
    limit: 2,
    captures: plan.captures,
  });
  session.refreshStatus = async () =>
    ({ template: "1", namespace: "2", limit: 2, starts: 1, phase: "idle" }) as RefreshView;
  session.open = async () => {
    expect(session.scope).toEqual(scope);
  };
  session.close = async () => {
    session.scope = null;
  };
  const basis = {
    resource: 9,
    partition: "1",
    accepted: "10",
    contract: Array(32).fill(0),
    schema: Array(32).fill(0),
  };
  session.inspect = async () => ({ observation: { basis, data_revision: "10" } }) as never;
  const controls: string[] = [];
  session.refresh = async (command) => {
    controls.push(Object.keys(command)[0]!);
    return 10;
  };
  session.follow = async (consume, signal) => {
    consume({ attached: { ...selection.session, attachment: 1 } });
    if (!signal.aborted)
      await new Promise<void>((resolve) =>
        signal.addEventListener("abort", () => resolve(), { once: true }),
      );
  };
  const view = new LiveView(
    session,
    async (_signal, namespace) => {
      expect(namespace).toBe("2");
      return { value: "freshly read", basis, namespace };
    },
    async () => {
      throw new Error("Consumed captures must not be prepared again");
    },
  );
  view.restoreRecovery(JSON.stringify(plan));
  const current = changed(view, () => view.getSnapshot().phase === "current");
  await view.resume();
  await current;
  expect(view.getSnapshot().snapshot?.value).toBe("freshly read");
  await view.pause();
  expect(controls).toEqual(["invalidate", "pause"]);
});

test("reload during closure finishes the original close without reopening", async () => {
  const owner = fixture();
  owner.session.scope = scope;
  let closed = 0;
  owner.session.close = async () => {
    ++closed;
    owner.session.scope = null;
  };
  owner.session.open = async () => {
    throw new Error("Must not open");
  };
  owner.view.restoreRecovery(JSON.stringify({ ...plan, closing: true }));
  await owner.view.resume();
  expect(closed).toBe(1);
  expect(owner.view.recoveryIdentity).toBeNull();
  expect(owner.view.getSnapshot().snapshot).toBeNull();
});
