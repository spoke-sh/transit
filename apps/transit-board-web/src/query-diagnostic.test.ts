import fixtureValue from "../../../packages/zig/transit-protocol/src/fixtures/diagnostic-v1.json" with { type: "json" };
import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { expect, test } from "vite-plus/test";
import type { Diagnostic } from "@transit/query-client";
import { QueryDiagnostic } from "./query-diagnostic";

test("diagnostics render literal text, exact identity, missing evidence and scoped guidance", () => {
  const value = structuredClone(fixtureValue) as Diagnostic;
  value.message = '<img src=x onerror="dispatch()">';
  const html = renderToStaticMarkup(createElement(QueryDiagnostic, { value }));
  expect(html).toContain('role="alert"');
  expect(html).toContain("&lt;img");
  expect(html).not.toContain("<img");
  expect(html).not.toContain("<button");
  expect(html).toContain("18446744073709551615");
  expect(html).toContain("constraint: unrecorded");
  expect(html).toContain("Correct the input before submitting it.");
});
