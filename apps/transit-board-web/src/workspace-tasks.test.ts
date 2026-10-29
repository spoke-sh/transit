import { expect, test } from "vite-plus/test";
import { WorkspaceTasks } from "./workspace-tasks";

function deferred() {
  let resolve!: () => void;
  const promise = new Promise<void>((done) => {
    resolve = done;
  });
  return { promise, resolve };
}

test("an explicit retry waits for a poll and takes priority over further polls", async () => {
  const tasks = new WorkspaceTasks();
  const poll = deferred();
  const retry = deferred();
  const signal = new AbortController().signal;
  const events: string[] = [];
  const reading = tasks.run(async () => {
    events.push("poll");
    await poll.promise;
    events.push("poll complete");
  }, signal);
  const submitting = tasks.run(
    async () => {
      events.push("retry exact request");
      await retry.promise;
    },
    signal,
    true,
  );
  await tasks.run(async () => {
    events.push("overlapping poll");
  }, signal);
  await tasks.run(
    async () => {
      events.push("duplicate queued retry");
    },
    signal,
    true,
  );
  expect(events).toEqual(["poll"]);
  poll.resolve();
  await reading;
  expect(events).toEqual(["poll", "poll complete", "retry exact request"]);
  await tasks.run(async () => {
    events.push("overlapping poll");
  }, signal);
  retry.resolve();
  await submitting;
  await tasks.run(async () => {
    events.push("later poll");
  }, signal);
  expect(events).toEqual(["poll", "poll complete", "retry exact request", "later poll"]);
});

test("navigation or denial aborts a queued retry without dispatching it", async () => {
  const tasks = new WorkspaceTasks();
  const poll = deferred();
  const controller = new AbortController();
  const reading = tasks.run(() => poll.promise, controller.signal);
  let submitted = false;
  const submitting = tasks.run(
    async () => {
      submitted = true;
    },
    controller.signal,
    true,
  );
  controller.abort();
  poll.resolve();
  await Promise.all([reading, submitting]);
  expect(submitted).toBe(false);
  await tasks.run(async () => {
    submitted = true;
  }, new AbortController().signal);
  expect(submitted).toBe(true);
});

test("a failed operation releases the workspace for an explicit retry", async () => {
  const tasks = new WorkspaceTasks();
  const poll = deferred();
  const signal = new AbortController().signal;
  const reading = tasks.run(async () => {
    await poll.promise;
    throw new Error("unavailable");
  }, signal);
  const failure = expect(reading).rejects.toThrow("unavailable");
  let submitted = false;
  const submitting = tasks.run(
    async () => {
      submitted = true;
    },
    signal,
    true,
  );
  poll.resolve();
  await Promise.all([failure, submitting]);
  expect(submitted).toBe(true);
});
