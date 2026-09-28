import { expect, test } from "vite-plus/test";
import { LiveView, ReactiveError, Session, type Snapshot } from "@rey/transit-reactive-client";
const scope = {
  realm: 1,
  principal: 2,
  service: 3,
  ingress: 4,
  session: 5,
  generation: 6,
  subscription: 7,
  subscription_generation: 8,
};
function attachedSession() {
  const session = new Session();
  session.leaseBefore = Date.now() + 30000;
  session.follow = async (consume, signal) => {
    consume({ attached: { session: 5, generation: 6, attachment: 1 } });
    if (!signal.aborted)
      await new Promise<void>((resolve) =>
        signal.addEventListener("abort", () => resolve(), { once: true }),
      );
  };
  return session;
}
const snapshot: Snapshot<string> = {
  value: "protected",
  basis: {
    kind: "table",
    resource: 9,
    revision: 10,
    contract: Array(32).fill(0),
    schema: Array(32).fill(0),
  },
};
function deferred<T>() {
  let resolve!: (value: T) => void;
  const promise = new Promise<T>((accept) => {
    resolve = accept;
  });
  return { promise, resolve };
}
test("pause joins acquisition and fences a late successful snapshot", async () => {
  const read = deferred<Snapshot<string>>();
  const started = deferred<void>();
  const session = attachedSession();
  session.open = async () => {
    session.scope = scope;
  };
  let closed = 0;
  session.close = async () => {
    ++closed;
    session.scope = null;
  };
  const view = new LiveView(session, async () => {
    started.resolve();
    return read.promise;
  });
  await view.start();
  await started.promise;
  const paused = view.pause();
  read.resolve(snapshot);
  await paused;
  expect(closed).toBe(1);
  expect(view.getSnapshot()).toMatchObject({ phase: "paused", snapshot: null });
  expect(view.following).toBe(false);
});
test("a pause during prior-session closure prevents a queued explicit reopen", async () => {
  const close = deferred<void>();
  const session = attachedSession();
  session.scope = scope;
  let opens = 0;
  session.open = async () => {
    ++opens;
  };
  session.close = async () => {
    await close.promise;
    session.scope = null;
  };
  const view = new LiveView(session, async () => snapshot);
  const starting = view.start();
  const paused = view.pause();
  close.resolve();
  await Promise.all([starting, paused]);
  expect(opens).toBe(0);
  expect(view.following).toBe(false);
});
test("known denial cannot publish an acquired candidate", async () => {
  const session = attachedSession();
  session.open = async () => {
    session.scope = scope;
  };
  session.close = async () => {
    session.scope = null;
  };
  const denied = deferred<void>();
  const view = new LiveView(session, async () => {
    throw new ReactiveError(403, "denied");
  });
  view.subscribe(() => {
    if (view.getSnapshot().phase === "denied") denied.resolve();
  });
  await view.start();
  await denied.promise;
  expect(view.getSnapshot().snapshot).toBeNull();
  await view.pause();
});

test("renewal progresses while complete-result acquisition is pending", async () => {
  const session = attachedSession();
  session.open = async () => {
    session.scope = scope;
  };
  session.close = async () => {
    session.scope = null;
  };
  const read = deferred<Snapshot<string>>();
  const started = deferred<void>();
  const renewed = deferred<void>();
  session.renew = async () => {
    session.leaseBefore = Date.now() + 30000;
    renewed.resolve();
  };
  const view = new LiveView(session, async () => {
    session.leaseBefore = Date.now() + 10000;
    started.resolve();
    return read.promise;
  });
  await view.start();
  await started.promise;
  await renewed.promise;
  expect(view.getSnapshot().snapshot).toBeNull();
  const stopped = view.pause();
  read.resolve(snapshot);
  await stopped;
  expect(view.getSnapshot().snapshot).toBeNull();
});

test("a new query template cannot publish the previous paused candidate", async () => {
  const session = attachedSession();
  session.open = async () => {
    session.scope = scope;
  };
  session.close = async () => {
    session.scope = null;
  };
  session.inspect = async () =>
    ({
      observation: { data_revision: 10, basis: snapshot.basis, schema: { columns: [] } },
    }) as never;
  session.refresh = async () => 1;
  const first = deferred<void>();
  const second = deferred<Snapshot<string>>();
  let reads = 0;
  const view = new LiveView(session, async () => {
    if (++reads === 1) return { ...snapshot, namespace: "old" };
    return second.promise;
  });
  view.subscribe(() => {
    if (view.getSnapshot().snapshot?.namespace === "old") first.resolve();
  });
  await view.start();
  await first.promise;
  await view.pause();
  expect(view.getSnapshot().snapshot?.namespace).toBe("old");
  await view.start("new");
  expect(view.getSnapshot().snapshot).toBeNull();
  const stopped = view.pause();
  second.resolve({ ...snapshot, namespace: "new" });
  await stopped;
  expect(view.getSnapshot().snapshot).toBeNull();
});

test("pause retries transient control capacity after joining local tasks", async () => {
  const session = attachedSession();
  session.scope = scope;
  let calls = 0;
  session.close = async () => {
    calls++;
    if (calls === 1) throw new ReactiveError(429, "unavailable");
    session.scope = null;
  };
  const view = new LiveView(session, async () => snapshot);
  await view.pause();
  expect(calls).toBe(2);
  expect(view.getSnapshot().phase).toBe("paused");
  expect(session.scope).toBeNull();
});

test("a reconnect renews before owning the sequence for attachment", async () => {
  const session = attachedSession();
  const acquired = deferred<void>();
  let renewals = 0;
  session.open = async () => {
    session.scope = scope;
    session.leaseBefore = Date.now() + 10000;
  };
  session.renew = async () => {
    ++renewals;
    session.leaseBefore = Date.now() + 30000;
  };
  const follow = session.follow.bind(session);
  session.follow = async (consume, signal) => {
    expect(renewals).toBe(1);
    expect(session.leaseBefore).toBeGreaterThan(Date.now() + 15000);
    return follow(consume, signal);
  };
  session.close = async () => {
    session.scope = null;
  };
  const view = new LiveView(session, async () => {
    acquired.resolve();
    return snapshot;
  });
  await view.start();
  await acquired.promise;
  await view.pause();
});

test.each([new ReactiveError(0, "control_uncertain"), new ReactiveError(503, "unavailable")])(
  "startup reconciles accepted control before subscribing or acquiring (%s)",
  async (failure) => {
    const session = attachedSession();
    const acquired = deferred<void>();
    const signed = { retained: "exact" } as never;
    let opens = 0,
      recoveries = 0;
    session.open = async () => {
      ++opens;
      if (opens === 1) {
        session.pending = { signed, command: { close: { session: 5, generation: 6 } }, input: 9 };
        throw failure;
      }
      expect(recoveries).toBe(1);
      expect(session.pending).toBeNull();
      session.scope = scope;
    };
    session.recover = async () => {
      expect(session.pending?.signed).toBe(signed);
      expect(session.pending?.input).toBe(9);
      ++recoveries;
      session.pending = null;
      return 9;
    };
    session.close = async () => {
      session.scope = null;
    };
    const view = new LiveView(session, async () => {
      expect(recoveries).toBe(1);
      acquired.resolve();
      return snapshot;
    });
    await view.start();
    await acquired.promise;
    await view.pause();
    expect(opens).toBe(2);
    expect(view.getSnapshot().phase).toBe("paused");
  },
);
