import { expect, test } from "vite-plus/test";
import { byteAllowance, byteCount, bytes, formatBytes } from "./quantities";

test("byte labels preserve exact input and distinguish unavailable and zero", () => {
  for (const [input, text] of [
    [0, "0 B"],
    [1023, "1023 B"],
    [1024, "1 KiB"],
    [1536, "1.5 KiB"],
    [134217728, "128 MiB"],
    [1610612736, "1.5 GiB"],
  ] as const) {
    expect(formatBytes(input).text).toBe(text);
    expect(formatBytes(input).exact).toBe(String(input));
  }
  expect(bytes(null)).toBe("Unavailable");
  expect(bytes(undefined)).toBe("Unavailable");
  expect(bytes(0)).toBe("0 B");
});

test("unit boundaries, rounding carry and full-width counts remain integer based", () => {
  const units = ["KiB", "MiB", "GiB", "TiB", "PiB", "EiB"];
  for (let index = 1; index <= units.length; index++) {
    const power = 1024n ** BigInt(index);
    expect(formatBytes(power).text).toBe(`1 ${units[index - 1]}`);
    expect(formatBytes(power - 1n).exact).toBe((power - 1n).toString());
    if (index > 1) expect(formatBytes(power - 1n).text).toBe(`≈ 1 ${units[index - 1]}`);
    expect(formatBytes(power + 1n).approximate).toBe(true);
  }
  expect(formatBytes("18446744073709551615")).toMatchObject({
    text: "≈ 16 EiB",
    exact: "18446744073709551615",
  });
  expect(formatBytes(1025).text).toBe("≈ 1 KiB");
  expect(formatBytes(1, 2).text).toBe("< 0.01 MiB");
  expect(
    ["1024", "10000000000000001", "10000000000000000"]
      .map(byteCount)
      .sort((a, b) => (a < b ? -1 : a > b ? 1 : 0)),
  ).toEqual([1024n, 10000000000000000n, 10000000000000001n]);
});

test("invalid byte inputs cannot manufacture a valid display", () => {
  for (const value of [
    -1,
    -1n,
    1.5,
    NaN,
    Infinity,
    Number.MAX_SAFE_INTEGER + 1,
    "-1",
    "01",
    "1.2",
    "",
    " 1",
  ])
    expect(() => formatBytes(value)).toThrow(RangeError);
});

test("allowances share a unit without losing tiny, near-limit or over-limit evidence", () => {
  expect(byteAllowance(134217728, 536870912).text).toBe("128 MiB of 512 MiB · 25%");
  expect(byteAllowance(1, 1048576).text).toBe("< 0.01 MiB of 1 MiB · < 0.01%");
  expect(byteAllowance("18446744073709551614", "18446744073709551615").text).toContain("99.99%");
  expect(byteAllowance(101, 100)).toMatchObject({
    percent: 100,
    text: "101 B of 100 B · 101% · above limit",
  });
  expect(() => byteAllowance(0, 0)).toThrow(RangeError);
});
