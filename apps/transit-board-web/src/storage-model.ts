import type { ByteCount } from "./quantities";
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
  percent?: number;
  scale?: string;
};
