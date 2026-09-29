import { describe, expect, it } from "vite-plus/test";
import { existsSync, readdirSync, readFileSync } from "node:fs";
import path from "node:path";
import { pages } from "../catalog";
import { pageContent, resolveLink } from "./content";
import { object, readSpecification, renderSpecification, specifications } from "./specs";

const root = path.resolve(import.meta.dirname, "../../..");

describe("documentation ownership and navigation", () => {
  it("publishes every public page without internal prerequisites or route collisions", () => {
    for (const directory of ["guides", "reference"]) {
      const sources = readdirSync(path.join(root, "docs", directory), { recursive: true }).filter(
        (name): name is string => typeof name === "string" && name.endsWith(".md"),
      );
      for (const name of sources) {
        const source = `docs/${directory}/${name.split(path.sep).join("/")}`;
        expect(
          pages.some((entry) => entry.source === source),
          source,
        ).toBe(true);
        const content = readFileSync(path.join(root, source), "utf8");
        for (const match of content.matchAll(/\]\(([^)\s]+)\)|^\[[^\]]+\]:\s+(\S+)/gm)) {
          const url = match[1] ?? match[2]!;
          expect(resolveLink(root, source, url, "/"), `${source}: ${url}`).not.toContain(
            "/docs/internal/",
          );
        }
      }
    }
    for (const entry of pages) {
      expect(existsSync(path.join(root, entry.source)), entry.source).toBe(true);
      expect(entry.source.startsWith("docs/internal/"), entry.source).toBe(false);
    }
    expect(new Set(pages.map((entry) => entry.route)).size).toBe(pages.length);
    expect(new Set(pages.map((entry) => entry.source)).size).toBe(pages.length);
  });
  it("keeps page/anchor links inside a mounted site and unselected owners in source", () => {
    expect(resolveLink(root, "docs/reference/callers.md", "cli.md#commands", "/handbook/")).toBe(
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
    expect(resolveLink(root, "docs/README.md", "#where-documentation-lives", "/")).toBe(
      "#where-documentation-lives",
    );
    expect(resolveLink(root, "docs/README.md", "internal/README.md", "/")).toBe(
      "https://github.com/rupurt/rey/blob/main/docs/internal/README.md",
    );
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
