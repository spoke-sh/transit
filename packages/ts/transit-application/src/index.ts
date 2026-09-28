import * as validate from "./validators.js";
import type { Definition, Head } from "./types";
export type * from "./types";

export class ApplicationContractError extends Error {}

// Structural validation precedes rendering. The Zig owner still validates the
// complete graph, UTF-8 byte bounds, SQL and source compatibility before admission.
export function decodeDefinition(value: unknown): Definition {
  if (!validate.Definition(value))
    throw new ApplicationContractError("Invalid interface definition");
  const definition = value as Definition;
  if (
    definition.components !== 1 ||
    definition.realm === 0 ||
    !wide(definition.revision) ||
    definition.revision === "0"
  )
    throw new ApplicationContractError("Unsupported interface revision");
  return definition;
}

export function decodeHead(value: unknown): Head {
  if (!validate.Head(value)) throw new ApplicationContractError("Invalid interface publication");
  const head = value as Head;
  if (
    head.spec.format !== 0x41505031 ||
    head.spec.length > 64 * 1024 ||
    head.principal === 0 ||
    ![head.revision, head.record, head.operation].every((id) => wide(id) && id !== "0")
  )
    throw new ApplicationContractError("Invalid interface identity");
  return head;
}

function wide(value: string): boolean {
  return (
    /^(0|[1-9][0-9]*)$/.test(value) &&
    (value.length < 20 || (value.length === 20 && value <= "18446744073709551615"))
  );
}

export function presentation(definition: Definition) {
  const theme = definition.themes.find((candidate) => candidate.name === definition.theme);
  if (!theme) throw new ApplicationContractError("Missing interface theme");
  return { density: theme.density, theme: theme.name };
}

/** Generated proposals select a build's renderer artifacts. Accepted definitions
 * may evolve within that set; an artifact never supplies a publication fallback. */
export function requireArtifacts(proposal: Definition, current: Definition): void {
  const renderers = new Set(proposal.screens.map((screen) => screen.renderer));
  if (
    current.realm !== proposal.realm ||
    current.name !== proposal.name ||
    current.components !== proposal.components ||
    current.screens.some((screen) => !renderers.has(screen.renderer))
  )
    throw new ApplicationContractError(
      "Published interface requires different application artifacts",
    );
}

/** A pure visual edit. Publication requires the owning compiler and exact review. */
export function withTheme(definition: Definition, name: string): Definition {
  if (!definition.themes.some((theme) => theme.name === name))
    throw new ApplicationContractError("Unknown interface theme");
  return { ...definition, theme: name };
}

/** Exact generation for late-result rejection, never an access capability. */
export function generation(realm: number, application: string, head: Head): string {
  if (
    !Number.isSafeInteger(realm) ||
    realm <= 0 ||
    !/^[A-Za-z_][A-Za-z_0-9]{0,63}$/.test(application)
  )
    throw new ApplicationContractError("Invalid interface scope");
  decodeHead(head);
  return `${realm}/${application}/${head.revision}/${head.record}/${head.spec.digest.map((byte) => byte.toString(16).padStart(2, "0")).join("")}`;
}

export type DiagramNode = { id: string; kind: "screen" | "binding" | "action"; label: string };
export type DiagramEdge = { from: string; to: string };

/** Bounded definition projection; this graph cannot dispatch or authorize work. */
export function diagram(definition: Definition): { nodes: DiagramNode[]; edges: DiagramEdge[] } {
  const nodes: DiagramNode[] = [
    ...definition.screens.map((screen) => ({
      id: `screen:${screen.name}`,
      kind: "screen" as const,
      label: screen.label,
    })),
    ...definition.bindings.map((binding) => ({
      id: `binding:${binding.name}`,
      kind: "binding" as const,
      label: binding.name,
    })),
    ...definition.actions.map((action) => ({
      id: `action:${action.name}`,
      kind: "action" as const,
      label: action.label,
    })),
  ];
  const edges: DiagramEdge[] = definition.screens.map((screen) => ({
    from: `screen:${screen.name}`,
    to: `binding:${screen.binding}`,
  }));
  for (const action of definition.actions) {
    const target = action.target;
    edges.push({
      from: `action:${action.name}`,
      to:
        "navigate" in target
          ? `screen:${target.navigate}`
          : `binding:${"command" in target ? target.command : target.follow}`,
    });
  }
  return { nodes, edges };
}

export * from "./client";
