import { bytes, byteAllowance, type ByteCount } from "./quantities";
import type { StorageResponse } from "@transit/board-client";
/** Scale only the picture. Exact decimal positions remain the displayed truth. */
export function positionPercent(value: string, ceiling: string): number {
  const current = BigInt(value),
    maximum = BigInt(ceiling);
  if (current < 0n || maximum <= 0n) return 0;
  return Number(((current > maximum ? maximum : current) * 10000n) / maximum) / 100;
}
export type StorageFact = {
  key: string;
  label: string;
  value: string;
  byteValue?: ByteCount | null;
  byteLimit?: ByteCount;
  explanation: string;
  milliseconds?: number;
  qualifier?: string;
  visual?: boolean;
  percent?: number;
  scale?: string;
};

export function objectTierFacts(tier: NonNullable<StorageResponse["object_tier"]>): StorageFact[] {
  const quantity = (
    key: string,
    label: string,
    value: number,
    limit: number,
    explanation: string,
  ): StorageFact => ({
    key,
    label,
    value: bytes(value),
    byteValue: value,
    byteLimit: limit,
    percent: byteAllowance(value, limit).percent,
    scale: byteAllowance(value, limit).text,
    explanation,
  });
  return [
    quantity(
      "staged",
      "Pending upload bytes",
      tier.pending_upload_bytes,
      tier.staging_limit_bytes,
      "Durable queued upload bytes, including private candidates and superseded work until consumed. Staging is retained until verified remote coverage; pressure does not authorize expiry.",
    ),
    {
      key: "pending",
      label: "Pending transfers",
      value: tier.pending_objects.toLocaleString(),
      explanation: `Queued uploads and deletions. Ordinary upload limit: ${tier.pending_object_limit.toLocaleString()}; control uploads and deletion share a separate reserve.`,
    },
    quantity(
      "cache",
      "Disk cache",
      tier.cache_used_bytes,
      tier.cache_limit_bytes,
      "Disposable verified object bytes in the bounded disk cache. Excludes durable staging, local WAL and retained recovery metadata.",
    ),
    {
      key: "hits",
      label: "Cache hits",
      value: tier.cache_hits.toLocaleString(),
      explanation: "Verified cache hits since the owner started.",
    },
    {
      key: "misses",
      label: "Cache misses",
      value: tier.cache_misses.toLocaleString(),
      explanation:
        "Cache misses since the owner started; missing cache entries are fetched from the configured tier.",
    },
    {
      key: "uploads",
      label: "Completed uploads",
      value: tier.uploads_completed.toLocaleString(),
      explanation:
        "Transfer steps completed since startup after remote verification and durable coverage publication. This is not a global accepted-data coverage watermark.",
    },
    {
      key: "deletes",
      label: "Completed deletions",
      value: tier.deletes_completed.toLocaleString(),
      explanation:
        "Recorded generation-specific deletion steps completed since startup. Logical expiry remains separately authorized.",
    },
    {
      key: "failures",
      label: "Failed transfer steps",
      value: tier.failed_steps.toLocaleString(),
      explanation: "Failures since startup; durable pending work remains available for retry.",
    },
    {
      key: "last-failure",
      label: "Last transfer failure",
      value: tier.last_failure ?? "None observed",
      explanation:
        "Coarse failure category, retained after recovery until the owner restarts. Provider addresses and credentials are excluded.",
    },
    {
      key: "recovery",
      label: "Owner recovery required",
      value: tier.recovery_required ? "Yes" : "No",
      explanation:
        "An uncertain local inventory publication requires exclusive reopen before further transfer or mutation.",
    },
  ];
}
