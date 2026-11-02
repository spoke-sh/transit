import { expect, test } from "vite-plus/test";
import { maintenanceFacts } from "./maintenance-model";

test("missing maintenance is unavailable, not disabled or a zero counter", () => {
  const facts = maintenanceFacts({ maintenance: null, settings: null });
  expect(facts.every((fact) => fact.value === "Unavailable")).toBe(true);
});

test("maintenance state, retained failure, eligibility and work bounds stay distinct", () => {
  const facts = maintenanceFacts({
    maintenance: {
      enabled: true,
      state: "waiting",
      completed_steps: 12,
      failed_steps: 1,
      last_failure: "capacity",
      interval_ms: 2000,
      operation_timeout_ms: 30000,
    },
    settings: {
      resident_bytes: 134217728,
      collection_every_records: 64,
      compact: false,
      compaction_rows: 8,
      archive: { enabled: true, work_frames: 4 },
      flush: { enabled: true, rows: 256, bytes: 262144, age_ms: 5000, work_rows: 32 },
    },
  });
  const byKey = Object.fromEntries(facts.map((fact) => [fact.key, fact]));
  expect(byKey.state!.value).toBe("waiting");
  expect(byKey.failure!.value).toBe("capacity");
  expect(byKey.compaction!.value).toBe("Disabled");
  expect(byKey.budget!.value).toBe("128 MiB");
  expect(byKey.budget!.byteValue).toBe(134217728);
  expect(byKey.interval!.value).toBe("2 s");
  expect(byKey.interval!.milliseconds).toBe(2000);
  expect(byKey["flush-rows"]!.value).toBe("256 rows");
  expect(byKey["flush-work"]!.value).toBe("32 rows per step");
  expect(byKey["archive-work"]!.value).toBe("4 frames per step");
  expect(facts.every((fact) => fact.percent === undefined)).toBe(true);
});
