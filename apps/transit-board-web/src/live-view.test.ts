import { expect, test } from "vite-plus/test";
import diagnosticFixture from "../../../packages/zig/transit-protocol/src/fixtures/diagnostic-v1.json" with { type: "json" };
import { LiveView, ReactiveError, Session, type Snapshot } from "@transit/reactive-client";
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
    resource: 9,
    partition: "1",
    accepted: "10",
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
      observation: { data_revision: "10", basis: snapshot.basis, schema: { columns: [] } },
    }) as never;
  session.refresh = async () => 1;
  const first = deferred<void>();
  const second = deferred<Snapshot<string>>();
  let reads = 0;
  const view = new LiveView(session, async () => {
    if (++reads === 1) return { ...snapshot, namespace: "100" };
    return second.promise;
  });
  view.subscribe(() => {
    if (view.getSnapshot().snapshot?.namespace === "100") first.resolve();
  });
  await view.start();
  await first.promise;
  await view.pause();
  expect(view.getSnapshot().snapshot?.namespace).toBe("100");
  await view.start("200");
  expect(view.getSnapshot().snapshot).toBeNull();
  const stopped = view.pause();
  second.resolve({ ...snapshot, namespace: "200" });
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

test.each(["ReactiveLeaseConflict", "ReactiveResetRequired"])(
  "later denial clears protected state and presents the original rejected control separately (%s)",
  async (reason) => {
    const session = attachedSession();
    session.open = async () => {
      session.scope = scope;
    };
    session.close = async () => {
      session.scope = null;
    };
    const observed = deferred<void>();
    const failure = new ReactiveError(409, reason);
    failure.scopeFailure = new ReactiveError(403, "denied");
    const view = new LiveView(session, async () => {
      throw failure;
    });
    view.subscribe(() => {
      if (view.getSnapshot().phase === "denied") observed.resolve();
    });
    await view.start();
    await observed.promise;
    expect(view.getSnapshot()).toMatchObject({
      snapshot: null,
      refresh: null,
      detail: `${reason}\nCurrent scope: denied.`,
    });
    await view.pause();
  },
);

test("a retained watch-change rejection stops renewal and preserves the original snapshot", async () => {
  const session = attachedSession();
  let opens = 0,
    renewals = 0,
    reads = 0;
  session.open = async () => {
    ++opens;
    session.scope = scope;
  };
  session.close = async () => {
    session.scope = null;
  };
  const failure = new ReactiveError(409, "ReactiveResetRequired", {
    ...structuredClone(diagnosticFixture),
    code: "reactive.watch_changed",
    category: "conflict",
    stage: "admission",
    outcome: "input_rejected",
    evidence: "domain_status",
    message: "The committed watch changed.",
    identity: { ...diagnosticFixture.identity, domain: "reactive" },
    actions: [{ kind: "inspect_status", target: null }, null, null, null],
  });
  session.inspect = async () =>
    ({ observation: { data_revision: "10", basis: snapshot.basis } }) as never;
  session.renew = async () => {
    ++renewals;
    throw failure;
  };
  const current = deferred<void>();
  const reset = deferred<void>();
  const view = new LiveView(session, async () => {
    ++reads;
    return snapshot;
  });
  view.subscribe(() => {
    if (view.getSnapshot().phase === "current") current.resolve();
    if (view.getSnapshot().phase === "reset_required") reset.resolve();
  });
  await view.start();
  await current.promise;
  session.leaseBefore = Date.now();
  await reset.promise;
  // The real renewal and reader loops join after the reset; they must not
  // reattach or keep renewing an obsolete watch until the lease expires.
  await new Promise((resolve) => setTimeout(resolve, 1100));
  expect(view.getSnapshot()).toMatchObject({ phase: "reset_required", snapshot });
  expect(view.getSnapshot().detail).toContain("reactive.watch_changed");
  expect(view.getSnapshot().detail).toContain("The committed watch changed.");
  expect([opens, renewals, reads]).toEqual([1, 1, 1]);
  expect(failure.reason).toBe("ReactiveResetRequired");
  expect(view.following).toBe(false);
  await view.pause();
});

test("failed refresh pauses with the exact snapshot and makes no replacement query", async () => {
  const session = attachedSession();
  session.open = async () => {
    session.scope = scope;
  };
  session.close = async () => {
    session.scope = null;
  };
  session.inspect = async () =>
    ({
      observation: { data_revision: "11", basis: snapshot.basis, schema: { columns: [] } },
    }) as never;
  const selection = { session: { session: 5, generation: 6 }, generation: 7 };
  let controls = 0;
  session.refresh = async (command) => {
    expect("follow" in command || "invalidate" in command || "pause" in command).toBe(true);
    ++controls;
    session.selection = selection;
    return 7;
  };
  session.refreshStatus = async () =>
    ({
      phase: "failed",
      generation: 7,
      session: selection.session,
      namespace: "9223372036854775809",
      failure: { stopped: { reason: "resource_unavailable", input: 12 } },
    }) as never;
  let reads = 0;
  const view = new LiveView(
    session,
    async (_signal, namespace) => {
      ++reads;
      expect(namespace).toBe("1");
      return { ...snapshot, namespace };
    },
    async (_key, template, limit) => {
      expect(template).toBe("1");
      expect(limit).toBe(8);
      return Array.from({ length: 8 }, (_, i) => String(i + 2));
    },
  );
  const failed = deferred<void>();
  view.subscribe(() => {
    if (view.getSnapshot().phase === "paused" && view.getSnapshot().refresh?.phase === "failed")
      failed.resolve();
  });
  await view.start("1");
  await failed.promise;
  expect(view.getSnapshot().snapshot?.value).toBe("protected");
  expect(view.getSnapshot().detail).toContain("Inspect the selected query outcome");
  expect(view.following).toBe(false);
  expect(reads).toBe(1);
  expect(controls).toBe(2);
  await view.pause();
});

test.each(["closed", "expired"])(
  "%s pauses the view without presenting an authorization denial",
  async (reason) => {
    const session = attachedSession();
    session.open = async () => {
      session.scope = scope;
    };
    session.close = async () => {
      session.scope = null;
    };
    const stopped = deferred<void>();
    const view = new LiveView(session, async () => {
      throw new ReactiveError(410, reason);
    });
    view.subscribe(() => {
      if (view.getSnapshot().detail === reason) stopped.resolve();
    });
    await view.start();
    await stopped.promise;
    expect(view.getSnapshot()).toMatchObject({ phase: "paused", snapshot: null, detail: reason });
    expect(view.following).toBe(false);
    await view.pause();
  },
);

test("operation failure detail survives ordinary snapshot updates without stopping Follow", async () => {
  const session = attachedSession();
  session.open = async () => {
    session.scope = scope;
  };
  session.close = async () => {
    session.scope = null;
  };
  session.inspect = async () =>
    ({
      observation: { data_revision: "10", basis: snapshot.basis, schema: { columns: [] } },
    }) as never;
  const previous = session.follow;
  session.follow = async (consume, signal) => {
    consume({
      event: {
        cursor: { position: { data_revision: "10" } } as never,
        event: {
          source_changed: true,
          resource: 9,
          data_revision: "10",
          outcome: {
            resource: 11,
            operation: 12,
            phase: "failed",
            resolution_input: 13,
            diagnostic: null,
            diagnosticInvalid: true,
          },
        },
      },
    });
    return previous(consume, signal);
  };
  const current = deferred<void>();
  const view = new LiveView(session, async () => snapshot);
  view.subscribe(() => {
    if (view.getSnapshot().phase === "current") current.resolve();
  });
  await view.start();
  await current.promise;
  expect(view.getSnapshot().operationDetail).toContain("Serving operation 12: failed");
  expect(view.getSnapshot().operationDetail).toContain("Diagnostic detail is invalid");
  expect(view.getSnapshot().snapshot).toEqual(snapshot);
  expect(view.following).toBe(true);
  await view.pause();
});

test.each(["terminal", "http"])(
  "%s source unavailability survives reconnect without inventing denial or a new snapshot",
  async (boundary) => {
    const session = attachedSession();
    let opens = 0;
    session.open = async () => {
      ++opens;
      session.scope = scope;
    };
    session.close = async () => {
      session.scope = null;
    };
    session.inspect = async () =>
      ({ observation: { data_revision: "10", basis: snapshot.basis } }) as never;
    const diagnostic = {
      ...structuredClone(diagnosticFixture),
      code: "serving.resource_unavailable",
      category: "unavailable",
      stage: "read",
      outcome: "not_applicable",
      evidence: "none",
      cause: "ResourceUnavailable",
      message: "The original source is unavailable. Inspect the retained resource.",
      identity: null,
      location: null,
      facts: Array(16).fill(null),
      actions: [{ kind: "retry_read", target: null }, null, null, null],
    };
    const current = deferred<void>();
    const interrupted = deferred<void>();
    const reconnecting = deferred<void>();
    let attachments = 0;
    session.follow = async (consume, signal) => {
      if (++attachments === 1) {
        consume({ attached: { session: 5, generation: 6, attachment: 1 } });
        await interrupted.promise;
        if (boundary === "http") throw new ReactiveError(410, "unavailable", diagnostic);
        consume({ terminal: { reason: "interrupted", diagnostic: diagnostic as never } });
      } else {
        reconnecting.resolve();
        if (!signal.aborted)
          await new Promise<void>((resolve) =>
            signal.addEventListener("abort", () => resolve(), { once: true }),
          );
      }
    };
    let reads = 0;
    const view = new LiveView(session, async () => {
      ++reads;
      return snapshot;
    });
    view.subscribe(() => {
      if (view.getSnapshot().phase === "current") current.resolve();
    });
    await view.start();
    await current.promise;
    interrupted.resolve();
    await reconnecting.promise;
    expect(view.getSnapshot()).toMatchObject({ phase: "disconnected", snapshot });
    expect(view.getSnapshot().detail).toContain(diagnostic.message);
    expect(view.getSnapshot().detail).toContain("serving.resource_unavailable");
    expect(session.scope).toEqual(scope);
    expect(opens).toBe(1);
    expect(reads).toBe(1);
    await view.pause();
  },
);
