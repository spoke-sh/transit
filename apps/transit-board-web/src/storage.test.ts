import { expect, test } from "vite-plus/test";
import { validateStorage, type StorageResponse } from "@transit/board-client";

const unavailable: StorageResponse = {
  realm: 1,
  position: 7,
  backend: "unavailable",
  root: null,
  allocated_bytes: null,
  limits: null,
  data_requests: null,
  control_requests: null,
  request_limit_bytes: null,
  maintenance: null,
  settings: null,
};
test("storage observations keep unavailable distinct from zero and bound memory facts", () => {
  expect(validateStorage(unavailable)).toBe(true);
  expect(validateStorage({ ...unavailable, allocated_bytes: 0 })).toBe(false);
  const local: StorageResponse = {
    ...unavailable,
    backend: "local",
    root: "/var/lib/transit",
    data_requests: { used: 32, peak: 64, limit: 128 },
    control_requests: { used: 0, peak: 0, limit: 32 },
    request_limit_bytes: 64,
  };
  expect(validateStorage(local)).toBe(true);
  for (const change of [
    { data_requests: { used: 65, peak: 64, limit: 128 } },
    { data_requests: { used: 32, peak: 129, limit: 128 } },
    { control_requests: null },
    { request_limit_bytes: 129 },
    { root: "relative" },
    { root: "/private\0ignored" },
    { root: "/" + "é".repeat(2048) },
    { allocated_bytes: Number.MAX_SAFE_INTEGER + 1 },
  ])
    expect(validateStorage({ ...local, ...change })).toBe(false);
});
