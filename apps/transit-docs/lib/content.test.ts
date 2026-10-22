import { describe, expect, it } from "vite-plus/test";
import { existsSync, readdirSync, readFileSync } from "node:fs";
import path from "node:path";
import { pages, handbookPages, sdkPages } from "../catalog";
import { pageContent, resolveLink } from "./content";
import { object, readSpecification, renderSpecification, specifications } from "./specs";

const root = path.resolve(import.meta.dirname, "../../..");

describe("documentation ownership and navigation", () => {
  it("keeps public commands independent of repository tooling and executable paths", () => {
    for (const entry of pages) {
      const content = pageContent(root, entry.source);
      // Check code spans and fences, including environment-prefixed commands.
      const examples = content.match(/```[\s\S]*?```|`[^`\n]+`/g) ?? [];
      for (const example of examples) {
        expect(example, entry.source).not.toMatch(/(?:^|[\s`])(?:nix|just)(?=[\s`]|$)/);
        expect(example, entry.source).not.toMatch(
          /[^\s`"']*\/transit\s+(?:--[\w-]+|serve|server|console|query|app)\b/,
        );
        expect(example, entry.source).not.toMatch(/(?:\.\/|\bbin\/)transit(?=[\s`"']|$)/);
      }
    }
  });
  it("describes capabilities without delivery-plan references across usage and interface sources", () => {
    const deliveryReference = /\b(?:m\d+|milestones?|roadmap)\b/i;
    for (const entry of handbookPages) {
      // The contributor index names source owners, including the separate roadmap.
      if (entry.source === "docs/README.md") continue;
      expect(
        `${entry.label}\n${entry.route}\n${pageContent(root, entry.source)}`,
        entry.source,
      ).not.toMatch(deliveryReference);
    }
    // Wire contracts remain public reference material even when linked to source.
    for (const name of readdirSync(path.join(root, "contracts"), { recursive: true })) {
      if (typeof name !== "string" || !name.endsWith(".md")) continue;
      const source = `contracts/${name.split(path.sep).join("/")}`;
      expect(readFileSync(path.join(root, source), "utf8"), source).not.toMatch(deliveryReference);
    }
    // Downloads are public too, including description fields not rendered as tables.
    for (const entry of specifications)
      expect(readFileSync(path.join(root, entry.source), "utf8"), entry.source).not.toMatch(
        deliveryReference,
      );
  });
  it("publishes every guide, reference and Internals page without route collisions", () => {
    for (const directory of ["guides", "reference", "internals"]) {
      const sources = readdirSync(path.join(root, "docs", directory), { recursive: true }).filter(
        (name): name is string => typeof name === "string" && name.endsWith(".md"),
      );
      for (const name of sources) {
        const source = `docs/${directory}/${name.split(path.sep).join("/")}`;
        expect(
          pages.some((entry) => entry.source === source),
          source,
        ).toBe(true);
      }
    }
    for (const entry of pages) {
      expect(existsSync(path.join(root, entry.source)), entry.source).toBe(true);
      expect(
        entry.source,
        "Planning and archived records stay with their repository owners",
      ).not.toMatch(/^docs\/(?:roadmap|design|history|decisions)\//);
    }
    expect(new Set(pages.map((entry) => entry.route)).size).toBe(pages.length);
    expect(new Set(pages.map((entry) => entry.source)).size).toBe(pages.length);
  });
  it("publishes SDK language owners and resolves links inside prefixed hosting", () => {
    const languages = readdirSync(path.join(root, "sdks"), { withFileTypes: true })
      .filter((entry) => entry.isDirectory())
      .map((entry) => `sdks/${entry.name}/README.md`);
    for (const source of languages) {
      expect(
        sdkPages.some((entry) => entry.source === source),
        source,
      ).toBe(true);
    }
    expect(
      resolveLink(root, "docs/reference/sdks.md", "../../sdks/zig/README.md", "/handbook/"),
    ).toBe("/handbook/sdks/zig");
    expect(
      resolveLink(root, "sdks/python/README.md", "../../docs/reference/callers.md", "/handbook/"),
    ).toBe("/handbook/reference/callers");
  });
  it("keeps page/anchor links inside a mounted site and unselected owners in source", () => {
    expect(resolveLink(root, "docs/reference/callers.md", "cli.md#commands", "/handbook/")).toBe(
      "/handbook/reference/cli#commands",
    );
    expect(
      resolveLink(root, "docs/reference/cli.md", "../../apps/transit-cli/docs/console.md", "/"),
    ).toBe("/guides/console");
    expect(resolveLink(root, "docs/guides/contributing.md", "launchers.md", "/handbook/")).toBe(
      "/handbook/guides/launchers",
    );
    expect(
      resolveLink(root, "docs/guides/launchers.md", "../../launchers/README.md", "/handbook/"),
    ).toBe("https://github.com/spoke-sh/transit/blob/main/launchers/README.md");
    expect(
      resolveLink(
        root,
        "docs/reference/native.md",
        "../../packages/zig/transit-client/README.md",
        "/",
      ),
    ).toBe("https://github.com/spoke-sh/transit/blob/main/packages/zig/transit-client/README.md");
    expect(resolveLink(root, "docs/README.md", "https://example.test/a#b", "/")).toBe(
      "https://example.test/a#b",
    );
    expect(resolveLink(root, "docs/README.md", "#where-documentation-lives", "/")).toBe(
      "#where-documentation-lives",
    );
    expect(resolveLink(root, "docs/README.md", "internals/README.md", "/handbook/")).toBe(
      "/handbook/internals",
    );
    expect(
      resolveLink(root, "docs/internals/system-model.md", "execution-model.md", "/handbook/"),
    ).toBe("/handbook/internals/execution-model");
    expect(
      resolveLink(root, "docs/internals/README.md", "../roadmap/README.md", "/handbook/"),
    ).toBe("https://github.com/spoke-sh/transit/blob/main/docs/roadmap/README.md");
    expect(resolveLink(root, "docs/internals/README.md", "../design/README.md", "/handbook/")).toBe(
      "https://github.com/spoke-sh/transit/blob/main/docs/design/README.md",
    );
    expect(() => resolveLink(root, "docs/README.md", "missing-guide.md", "/")).toThrow(
      "missing link",
    );
  });
});

describe("executable workload excerpts", () => {
  it("keeps published code identical to a complete example, allowing only common indentation", () => {
    const content = readFileSync(path.join(root, "docs/guides/workload-examples.md"), "utf8");
    const excerpts = [
      ...content.matchAll(/<!-- source-excerpt: ([^\s]+) -->\n```\w+\n([\s\S]*?)\n```/g),
    ];
    expect(excerpts.length).toBeGreaterThan(0);
    const dedent = (lines: string[]): string => {
      const indent = Math.min(
        ...lines.filter((line) => line.trim()).map((line) => line.length - line.trimStart().length),
      );
      return lines.map((line) => line.slice(indent)).join("\n");
    };
    for (const [, source, excerpt] of excerpts) {
      expect(source!.startsWith("examples/")).toBe(true);
      const owner = readFileSync(path.join(root, source!), "utf8").split("\n");
      const lines = excerpt!.split("\n");
      expect(
        owner.some(
          (_, start) => dedent(owner.slice(start, start + lines.length)) === dedent(lines),
        ),
        `Published excerpt differs from ${source}`,
      ).toBe(true);
    }
  });
});

describe("generated interface reference", () => {
  it("links nested definitions to their owning schema heading", () => {
    const rendered = renderSpecification({
      info: { title: "Recursive fixture", version: "1" },
      components: {
        schemas: {
          Plan: { $ref: "#/components/schemas/Plan/$defs/T0", $defs: { T0: { type: "object" } } },
        },
      },
    });
    expect(rendered).toContain("[Plan/$defs/T0](#plan)");
    expect(rendered).not.toContain("(#t0)");
    expect(rendered).toContain("### Plan");
  });
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
