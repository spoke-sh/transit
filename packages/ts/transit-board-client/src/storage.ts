import type { StorageResponse } from "./types";
import { StorageResponse as storageValidator } from "./storage-validators.js";
import { request } from "./request";
export function validateStorage(value: unknown): value is StorageResponse {
  if (!storageValidator(value)) return false;
  const observed = value as StorageResponse;
  const {
    backend,
    root,
    data_requests: data,
    control_requests: control,
    request_limit_bytes: limit,
    maintenance,
  } = observed;
  if (
    backend === "unavailable" &&
    Object.entries(observed).some(
      ([key, item]) => !["backend", "realm", "position"].includes(key) && item !== null,
    )
  )
    return false;
  if (
    root !== null &&
    (!root.startsWith("/") || root.includes("\0") || new TextEncoder().encode(root).length > 4096)
  )
    return false;
  if ((data === null) !== (control === null) || (data === null) !== (limit === null)) return false;
  for (const memory of [data, control])
    if (memory && (memory.limit === 0 || memory.used > memory.peak || memory.peak > memory.limit))
      return false;
  if (limit !== null && (limit === 0 || limit > data!.limit)) return false;
  if (
    maintenance &&
    (maintenance.enabled !== (maintenance.state !== "disabled") ||
      (maintenance.state === "failed" && maintenance.last_failure === null) ||
      (maintenance.failed_steps === 0) !== (maintenance.last_failure === null) ||
      (maintenance.enabled &&
        (maintenance.interval_ms === 0 || maintenance.operation_timeout_ms === 0)) ||
      maintenance.interval_ms > 60000 ||
      maintenance.operation_timeout_ms > 60000)
  )
    return false;
  const limits = observed.limits;
  if (
    limits &&
    (limits.bytes === 0 ||
      limits.control_bytes < 1048576 ||
      limits.candidate_bytes === 0 ||
      limits.candidate_bytes > 8388608)
  )
    return false;
  const settings = observed.settings;
  if (
    settings &&
    (settings.collection_every_records === 0 ||
      settings.compaction_rows === 0 ||
      settings.compaction_rows > 1024 ||
      settings.resident_bytes < 33554432 ||
      settings.resident_bytes > 536870912 ||
      settings.archive.work_frames === 0 ||
      settings.archive.work_frames > 8 ||
      settings.flush.rows === 0 ||
      settings.flush.rows > 1024 ||
      settings.flush.work_rows === 0 ||
      settings.flush.work_rows > 1024 ||
      settings.flush.bytes === 0 ||
      settings.flush.age_ms === 0 ||
      settings.flush.age_ms > 60000)
  )
    return false;
  return observed.realm > 0 && observed.position > 0;
}
export function storage(signal?: AbortSignal): Promise<StorageResponse> {
  return request("/api/v1/storage", validateStorage, { signal });
}
