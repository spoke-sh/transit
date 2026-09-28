import { afterEach, expect, test, vi } from "vite-plus/test";
import { httpTransport } from "./transport";
afterEach(() => vi.unstubAllGlobals());
test("throttle retries retain exact bodies while uncertain admissions are never replaced", async () => {
  const fetcher = vi
    .fn()
    .mockResolvedValueOnce(new Response("{}", { status: 429 }))
    .mockResolvedValueOnce(Response.json({ receipt: { position: 12 } }));
  vi.stubGlobal("fetch", fetcher);
  const call = httpTransport("/query");
  expect(await call({ submit: { token: "original-native-token" } })).toEqual({
    receipt: { position: 12 },
  });
  expect(fetcher.mock.calls[0]?.[1].body).toBe(fetcher.mock.calls[1]?.[1].body);
  fetcher.mockRejectedValueOnce(new Error("reply lost after admission"));
  await expect(call({ submit: { token: "original-native-token" } })).rejects.toThrow("reply lost");
  expect(fetcher).toHaveBeenCalledTimes(3);
  fetcher.mockResolvedValueOnce(Response.json({ err: "Unavailable" }, { status: 503 }));
  await expect(call({ submit: { token: "original-native-token" } })).rejects.toMatchObject({
    status: 503,
    code: "Unavailable",
  });
  expect(fetcher).toHaveBeenCalledTimes(4);
});
test("byte limits and UTF-8 validation precede exposure of an untrusted response", async () => {
  const fetcher = vi
    .fn()
    .mockResolvedValueOnce(
      new Response(
        new ReadableStream({
          start(controller) {
            controller.enqueue(new Uint8Array(1048576));
            controller.enqueue(new Uint8Array(1));
            controller.close();
          },
        }),
      ),
    )
    .mockResolvedValueOnce(new Response(new Uint8Array([255])));
  vi.stubGlobal("fetch", fetcher);
  const call = httpTransport("/query");
  await expect(call({ describe: {} })).rejects.toMatchObject({ code: "ResponseTooLarge" });
  await expect(call({ describe: {} })).rejects.toMatchObject({ code: "InvalidResponse" });
  expect(() => httpTransport("//other.example/query")).toThrow("InvalidTransport");
});
test("structurally valid but impossible draft state is rejected", async () => {
  vi.stubGlobal(
    "fetch",
    vi.fn().mockResolvedValue(
      Response.json({
        draft: {
          generation: "1",
          limit: 1,
          starts: 2,
          enabled: true,
          contract: Array(32).fill(0),
          budgets: { pages: "8", segments: "8", result_bytes: "65536" },
          namespaces: ["1", "2", ...Array(6).fill("0")],
        },
      }),
    ),
  );
  await expect(httpTransport("/query")({ draft_status: null })).rejects.toMatchObject({
    code: "InvalidResponse",
  });
});
