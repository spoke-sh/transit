import { expect, test } from "vite-plus/test";
import { validateStorage, type StorageResponse } from "@transit/board-client";
import { positionPercent } from "./storage-model";

test("storage diagrams preserve u64 decimal coordinates until scaling", () => {
  expect(positionPercent("0", "100")).toBe(0);
  expect(positionPercent("0", "0")).toBe(0);
  expect(positionPercent("1", "3")).toBe(33.33);
  expect(positionPercent("18446744073709551614", "18446744073709551615")).toBe(99.99);
  expect(positionPercent("18446744073709551615", "18446744073709551615")).toBe(100);
  expect(positionPercent("101", "100")).toBe(100);
});

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
  admission: null,
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

test("aggregate storage admission preserves independent samples and rejects invalid pools", () => {
  const pool = { memory: { limit: 16, used: 7, peak: 8 }, refusals: 3 };
  const admission = {
    total: { ...pool, memory: { ...pool.memory, limit: 64 } },
    data: pool,
    control: pool,
    maintenance: pool,
    collection: pool,
  };
  const local = { ...unavailable, backend: "local", admission };
  expect(validateStorage(local)).toBe(true);
  expect(validateStorage({ ...local, admission: undefined })).toBe(false);
  for (const data of [
    { ...pool, memory: { ...pool.memory, limit: 15 } },
    { ...pool, memory: { ...pool.memory, used: 9 } },
    { ...pool, refusals: -1 },
    { ...pool, refusals: Number.MAX_SAFE_INTEGER + 1 },
  ])
    expect(validateStorage({ ...local, admission: { ...admission, data } })).toBe(false);
});
