export type ByteCount = number | string | bigint;
const units = ["B", "KiB", "MiB", "GiB", "TiB", "PiB", "EiB"] as const;
const names = [
  "bytes",
  "kibibytes",
  "mebibytes",
  "gibibytes",
  "tebibytes",
  "pebibytes",
  "exbibytes",
];

/** Normalize exact counts before display; never round a wire integer through Number. */
export function byteCount(value: ByteCount): bigint {
  if (
    (typeof value === "number" && (!Number.isSafeInteger(value) || value < 0)) ||
    (typeof value === "string" && !/^(0|[1-9][0-9]*)$/.test(value))
  )
    throw new RangeError("Invalid byte count");
  const count = BigInt(value);
  if (count < 0n) throw new RangeError("Invalid byte count");
  return count;
}

function unitFor(count: bigint) {
  let unit = 0;
  while (unit < units.length - 1 && count >= 1024n ** BigInt(unit + 1)) unit++;
  return unit;
}

/** Three significant digits (at most two decimal places); raw bytes stay integers. */
export function formatBytes(value: ByteCount, fixedUnit?: number) {
  const count = byteCount(value);
  let unit = fixedUnit ?? unitFor(count);
  if (!Number.isInteger(unit) || unit < 0 || unit >= units.length)
    throw new RangeError("Invalid byte unit");
  let text: string, approximate: boolean;
  for (;;) {
    const scale = 1024n ** BigInt(unit);
    const whole = count / scale;
    const precision = unit === 0 || whole >= 100n ? 1n : whole >= 10n ? 10n : 100n;
    const rounded = (count * precision + scale / 2n) / scale;
    if (fixedUnit === undefined && unit < units.length - 1 && rounded >= 1024n * precision) {
      unit++;
      continue;
    }
    approximate = rounded * scale !== count * precision;
    if (count > 0n && rounded === 0n) {
      text = "< 0.01";
    } else {
      const fraction =
        precision === 1n
          ? ""
          : (rounded % precision)
              .toString()
              .padStart(precision === 100n ? 2 : 1, "0")
              .replace(/0+$/, "");
      text = `${approximate ? "≈ " : ""}${rounded / precision}${fraction ? "." + fraction : ""}`;
    }
    break;
  }
  return {
    text: `${text} ${units[unit]}`,
    accessible: `${text} ${names[unit]}`,
    exact: count.toString(),
    unit,
    approximate,
  };
}

export const bytes = (value: ByteCount | null | undefined) =>
  value == null ? "Unavailable" : formatBytes(value).text;

/** Only the visual width is capped. Ratios and over-limit labels keep their meaning. */
export function byteAllowance(used: ByteCount, limit: ByteCount) {
  const current = byteCount(used),
    maximum = byteCount(limit);
  if (maximum === 0n) throw new RangeError("Invalid byte allowance");
  const unit = unitFor(current > maximum ? current : maximum);
  const hundredths = (current * 10000n) / maximum;
  const ratio =
    current > 0n && hundredths === 0n
      ? "< 0.01"
      : `${hundredths / 100n}${hundredths % 100n ? "." + (hundredths % 100n).toString().padStart(2, "0").replace(/0$/, "") : ""}`;
  return {
    text: `${formatBytes(current, unit).text} of ${formatBytes(maximum, unit).text} · ${ratio}%${current > maximum ? " · above limit" : ""}`,
    percent: Number(hundredths > 10000n ? 10000n : hundredths) / 100,
  };
}

export function durationMs(value: number | null | undefined) {
  if (value == null) return "Unavailable";
  if (!Number.isSafeInteger(value) || value < 0) throw new RangeError("Invalid duration");
  return value < 1000 ? `${value} ms` : `${value / 1000} s`;
}
