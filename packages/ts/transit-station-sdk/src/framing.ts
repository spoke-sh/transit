import { owned, text } from "@transit/client/internal";
import { IncompatibleNative } from "@transit/client";
import { Bridge } from "./bridge.ts";
import { encode, type Codec } from "./values.ts";

export function unhex(value: string, bound: number): Uint8Array {
  text(value, bound * 2);
  if (value.length % 2 !== 0 || !/^[0-9a-f]*$/.test(value))
    throw new IncompatibleNative("Invalid native byte encoding");
  return new Uint8Array(Buffer.from(value, "hex"));
}
export function hex(value: Uint8Array, bound: number): string {
  return Buffer.from(owned(value, bound)).toString("hex");
}
export async function encodeCast<T>(
  value: T,
  codec: Codec<T>,
  options: { nativeHost?: string } = {},
): Promise<Uint8Array> {
  const bridge = await Bridge.local(options.nativeHost);
  try {
    const payload = encode(codec, value, bridge.caps.message_bytes);
    const bytes = await bridge.port.request(
      { frame: { kind: 1, correlation: "0", payload: hex(payload, bridge.caps.message_bytes) } },
      { phase: "encode-cast" },
    );
    return unhex(text(bytes), bridge.caps.value_bytes);
  } finally {
    await bridge.close();
  }
}
