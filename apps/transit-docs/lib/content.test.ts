import { describe, expect, it } from "vite-plus/test";
import { existsSync, readdirSync } from "node:fs";
import path from "node:path";
import { pages } from "../catalog";
import { pageContent, resolveLink } from "./content";
import { object, readSpecification, renderSpecification, specifications } from "./specs";

const root = path.resolve(import.meta.dirname, "../../..");

describe("documentation ownership and navigation", () => {
  it("includes every foundation and resolves every catalog source without route collisions", () => {
    const foundations = readdirSync(path.join(root, "docs")).filter((name) => name.endsWith(".md"));
    for (const name of foundations)
      expect(
        pages.some((entry) => entry.source === `docs/${name}`),
        name,
      ).toBe(true);
    for (const entry of pages)
      expect(existsSync(path.join(root, entry.source)), entry.source).toBe(true);
    expect(new Set(pages.map((entry) => entry.route)).size).toBe(pages.length);
    expect(new Set(pages.map((entry) => entry.source)).size).toBe(pages.length);
  });
  it("keeps page/anchor links inside a mounted site and unselected owners in source", () => {
    expect(resolveLink(root, "docs/CLIENT.md", "reference/cli.md#commands", "/handbook/")).toBe(
      "/handbook/reference/cli#commands",
    );
    expect(
      resolveLink(root, "docs/reference/cli.md", "../../apps/transit-cli/docs/console.md", "/"),
    ).toBe("/guides/console");
    expect(
      resolveLink(
        root,
        "docs/reference/native.md",
        "../../packages/zig/transit-client/README.md",
        "/",
      ),
    ).toBe("https://github.com/rupurt/rey/blob/main/packages/zig/transit-client/README.md");
    expect(resolveLink(root, "docs/README.md", "https://example.test/a#b", "/")).toBe(
      "https://example.test/a#b",
    );
    expect(resolveLink(root, "docs/README.md", "#foundations", "/")).toBe("#foundations");
    expect(() => resolveLink(root, "docs/README.md", "missing-guide.md", "/")).toThrow(
      "missing link",
    );
  });
});

describe("generated interface reference", () => {
  it("renders every current operation and named schema from each authoritative description", () => {
    for (const entry of specifications) {
      const spec = readSpecification(root, entry.source);
      const rendered = pageContent(root, entry.page);
      for (const [url, methods] of Object.entries(object(spec.paths ?? {}))) {
        for (const method of Object.keys(object(methods)))
          expect(rendered).toContain(`## ${method.toUpperCase()} ${url}`);
      }
      for (const name of Object.keys(object(spec.operations ?? {})))
        expect(rendered).toContain(`## Operation ${name}`);
      for (const name of Object.keys(object(object(spec.components).schemas)))
        expect(rendered).toContain(`### ${name}`);
      expect(
        resolveLink(
          root,
          entry.page,
          path.posix.relative(path.posix.dirname(entry.page), entry.source),
          "/handbook/",
        ),
      ).toBe(`pathname:///handbook/specs/${entry.name}`);
    }
  });
  it("preserves nested required fields, union variants, bounds and references", () => {
    const result = renderSpecification({
      info: { title: "Fixture", version: "1" },
      components: {
        schemas: {
          Envelope: {
            type: "object",
            required: ["result"],
            properties: {
              result: {
                oneOf: [
                  { type: "integer", minimum: 1 },
                  { type: "array", items: { $ref: "#/components/schemas/Value" } },
                ],
              },
              optional: { type: "string", maxLength: 32 },
            },
          },
          Value: { type: "string", enum: ["ready", "unknown"] },
        },
      },
    });
    expect(result).toContain("`$.result` | `oneOf` | yes");
    expect(result).toContain("`$.optional` | `string` | no");
    expect(result).toContain("`$.result (oneOf 1)` | `integer`");
    expect(result).toContain("`minimum`: `1`");
    expect(result).toContain("[Value](#value)");
    expect(result).toContain('`enum`: `["ready","unknown"]`');
  });
});
