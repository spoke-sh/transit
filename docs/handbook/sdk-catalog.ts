import type { Section } from "./catalog";

// The handbook reads language guides from their SDK owners, without copies.
export const sdkSections: Section[] = [
  {
    label: "SDK foundations",
    pages: [
      {
        source: "docs/handbook/reference/sdks.md",
        route: "reference/sdks",
        label: "Language SDKs",
      },
      {
        source: "docs/handbook/reference/callers.md",
        route: "reference/callers",
        label: "Caller semantics",
      },
      {
        source: "docs/handbook/reference/station.md",
        route: "reference/station",
        label: "Behaviors and supervision",
      },
    ],
  },
  {
    label: "Languages",
    pages: [
      { source: "sdks/zig/README.md", route: "sdks/zig", label: "Zig" },
      { source: "sdks/python/README.md", route: "sdks/python", label: "Python" },
      { source: "sdks/ts/README.md", route: "sdks/typescript", label: "TypeScript / Node.js" },
      { source: "sdks/rust/README.md", route: "sdks/rust", label: "Rust" },
      { source: "sdks/ruby/README.md", route: "sdks/ruby", label: "Ruby" },
      { source: "sdks/c/README.md", route: "sdks/c", label: "C" },
      { source: "sdks/cpp/README.md", route: "sdks/cpp", label: "C++" },
      { source: "sdks/java/README.md", route: "sdks/java", label: "Java" },
      { source: "sdks/dotnet/README.md", route: "sdks/dotnet", label: ".NET" },
      { source: "sdks/beam/README.md", route: "sdks/beam", label: "Erlang and Elixir" },
    ],
  },
];
