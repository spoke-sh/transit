import type { StorageResponse } from "@transit/board-client";
import { bytes, durationMs } from "./quantities";
import type { StorageFact } from "./storage-model";

export function maintenanceFacts(
  page: Pick<StorageResponse, "maintenance" | "settings">,
): StorageFact[] {
  const activity = page.maintenance,
    settings = page.settings;
  const enabled = (value: boolean | undefined) =>
    value === undefined ? "Unavailable" : value ? "Enabled" : "Disabled";
  const duration = (
    key: string,
    label: string,
    value: number | undefined,
    explanation: string,
  ): StorageFact => ({ key, label, value: durationMs(value), milliseconds: value, explanation });
  return [
    {
      key: "state",
      label: "Maintenance state",
      value: activity?.state ?? "Unavailable",
      visual: true,
      explanation:
        "Aggregate node worker state, not a per-Table phase or a promise of future progress.",
    },
    {
      key: "enabled",
      label: "Maintenance worker",
      value: enabled(activity?.enabled),
      explanation:
        "Reported worker enablement. It does not establish whether a particular Table is eligible for work.",
    },
    {
      key: "complete",
      label: "Completed maintenance steps",
      value: String(activity?.completed_steps ?? "Unavailable"),
      explanation:
        "Owner-local completed steps; resets on owner restart. Steps are not rows or a completion percentage.",
    },
    {
      key: "failed",
      label: "Failed maintenance steps",
      value: String(activity?.failed_steps ?? "Unavailable"),
      explanation: "Owner-local failed steps; resets on owner restart.",
    },
    {
      key: "failure",
      label: "Last maintenance failure",
      value: activity ? (activity.last_failure ?? "None observed") : "Unavailable",
      explanation:
        "Retained failure category. A last failure does not mean the current worker state is failed.",
    },
    {
      key: "budget",
      label: "Maintenance allocation limit",
      value: bytes(settings?.resident_bytes),
      byteValue: settings?.resident_bytes,
      visual: true,
      explanation:
        "Configured resident memory budget for maintenance work; independent of request pools and backend accounting.",
    },
    duration(
      "interval",
      "Worker interval",
      activity?.interval_ms,
      "Configured worker cadence, not elapsed time since the last step or an ETA.",
    ),
    duration(
      "timeout",
      "Operation timeout",
      activity?.operation_timeout_ms,
      "Configured operation deadline. A timeout is not proof that work was rolled back.",
    ),
    {
      key: "flush",
      label: "Flush",
      value: enabled(settings?.flush.enabled),
      visual: true,
      explanation:
        "Configured flush enablement. Eligibility thresholds and work bounds do not report an active Table phase.",
    },
    {
      key: "flush-rows",
      label: "Flush row threshold",
      value: settings ? `${settings.flush.rows} rows` : "Unavailable",
      explanation:
        "Configured pending-row eligibility threshold, not observed backlog or rows completed.",
    },
    {
      key: "flush-bytes",
      label: "Flush size threshold",
      value: bytes(settings?.flush.bytes),
      byteValue: settings?.flush.bytes,
      explanation: "Configured pending-byte eligibility threshold, not observed allocation.",
    },
    duration(
      "flush-age",
      "Flush age threshold",
      settings?.flush.age_ms,
      "Configured pending-age eligibility threshold, not an observed row age.",
    ),
    {
      key: "flush-work",
      label: "Flush work bound",
      value: settings ? `${settings.flush.work_rows} rows per step` : "Unavailable",
      explanation: "Maximum configured flush rows per bounded step; no total-backlog estimate.",
    },
    {
      key: "archive",
      label: "Archive",
      value: enabled(settings?.archive.enabled),
      visual: true,
      explanation:
        "Configured archive enablement, independent of the current Table archive frontier.",
    },
    {
      key: "archive-work",
      label: "Archive work bound",
      value: settings ? `${settings.archive.work_frames} frames per step` : "Unavailable",
      explanation:
        "Configured archive frame bound per step; frames are not byte quantities or rows.",
    },
    {
      key: "compaction",
      label: "Compaction",
      value: enabled(settings?.compact),
      visual: true,
      explanation: "Configured compaction enablement. Does not establish eligibility for deletion.",
    },
    {
      key: "compaction-work",
      label: "Compaction work bound",
      value: settings ? `${settings.compaction_rows} rows per step` : "Unavailable",
      explanation: "Configured compaction work bound per step, not observed completed rows.",
    },
    {
      key: "collection",
      label: "Collection cadence",
      value: settings ? `${settings.collection_every_records} records` : "Unavailable",
      visual: true,
      explanation:
        "Configured record cadence for collection; not a time interval, queue or count of deletable records.",
    },
  ];
}
