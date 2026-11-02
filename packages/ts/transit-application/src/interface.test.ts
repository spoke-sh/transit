import { afterEach, expect, test, vi } from "vite-plus/test";
import { readInterface } from "./client";

afterEach(() => vi.unstubAllGlobals());

test.each(["AuthorityUnavailable", "AuthorityTimeout"])(
  "interface observation retries %s within a finite budget and respects current denial",
  async (code) => {
    const unavailable = () => Response.json({ err: code }, { status: 503 });
    const fetcher = vi
      .fn()
      .mockImplementationOnce(unavailable)
      .mockResolvedValueOnce(Response.json({ err: "AccessDenied" }, { status: 403 }));
    vi.stubGlobal("fetch", fetcher);
    await expect(readInterface()).rejects.toMatchObject({ status: 403, code: "AccessDenied" });
    expect(fetcher).toHaveBeenCalledTimes(2);
    fetcher.mockClear().mockImplementation(unavailable);
    await expect(readInterface()).rejects.toMatchObject({ status: 503, code });
    expect(fetcher).toHaveBeenCalledTimes(5);
    fetcher.mockClear();
    await expect(readInterface(AbortSignal.abort())).rejects.toMatchObject({ name: "AbortError" });
    expect(fetcher).not.toHaveBeenCalled();
  },
);

test("unknown interface failure and revoked observations never inherit availability retry", async () => {
  const fetcher = vi.fn();
  vi.stubGlobal("fetch", fetcher);
  for (const [status, code] of [
    [503, "Unavailable"],
    [403, "AccessDenied"],
    [410, "ResourceUnavailable"],
  ] as const) {
    fetcher.mockClear().mockResolvedValueOnce(Response.json({ err: code }, { status }));
    await expect(readInterface()).rejects.toMatchObject({ status, code });
    expect(fetcher).toHaveBeenCalledTimes(1);
  }
});

test("malformed interface data is typed as incompatible without automatic transport retry", async () => {
  const fetcher = vi.fn().mockResolvedValue(new Response("{malformed"));
  vi.stubGlobal("fetch", fetcher);
  await expect(readInterface()).rejects.toMatchObject({ status: 0, code: "InvalidResponse" });
  expect(fetcher).toHaveBeenCalledTimes(1);
});
