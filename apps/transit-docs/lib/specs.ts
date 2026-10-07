import { readFileSync } from "node:fs";
import path from "node:path";

type ObjectValue = Record<string, unknown>;
export const specifications = [
  {
    source: "packages/zig/transit-serving/api/openapi.json",
    name: "serving.openapi.json",
    page: "docs/reference/openapi.md",
  },
  {
    source: "contracts/transit-board-v1.openapi.json",
    name: "board.openapi.json",
    page: "docs/reference/board-api.md",
  },
  {
    source: "packages/zig/transit-serving/api/asyncapi.json",
    name: "reactive.asyncapi.json",
    page: "docs/reference/asyncapi.md",
  },
];
export function object(value: unknown): ObjectValue {
  if (!value || typeof value !== "object" || Array.isArray(value))
    throw new Error("Expected a specification object");
  return value as ObjectValue;
}
const entries = (value: unknown): [string, unknown][] => Object.entries(object(value ?? {}));
const cell = (value: unknown): string =>
  String(value ?? "")
    .replaceAll("|", "\\|")
    .replaceAll("\n", " ")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;");
const code = (value: unknown): string => `\`${cell(value)}\``;
const json = (value: unknown): string =>
  `\n\n\`\`\`json\n${JSON.stringify(value, null, 2)}\n\`\`\`\n`;
const anchor = (name: string): string => name.toLowerCase().replace(/[^\w-]/g, "");
const reference = (value: unknown): string => {
  const ref = String(value);
  const match = /^#\/components\/schemas\/([^/]+)(.*)$/.exec(ref);
  if (!match) return code(ref);
  // Nested $defs belong to the named schema; they have no separate heading.
  const owner = match[1]!.replaceAll("~1", "/").replaceAll("~0", "~");
  return `[${cell(owner + match[2])}](#${anchor(owner)})`;
};

function schemaRows(value: unknown, prefix = "$", required = true): string[] {
  const s = object(value);
  const type = s.$ref
    ? reference(s.$ref)
    : code(s.type ?? (s.oneOf ? "oneOf" : s.anyOf ? "anyOf" : "value"));
  const constraints = Object.entries(s)
    .filter(
      ([key]) =>
        ![
          "type",
          "$ref",
          "description",
          "properties",
          "required",
          "items",
          "oneOf",
          "anyOf",
          "allOf",
          "x-transit-field-order",
        ].includes(key),
    )
    .map(([key, v]) => `${code(key)}: ${code(JSON.stringify(v))}`)
    .join("; ");
  const rows = [
    `| ${code(prefix)} | ${type} | ${required ? "yes" : "no"} | ${cell(s.description)} ${constraints} |`,
  ];
  for (const [name, child] of entries(s.properties)) {
    rows.push(
      ...schemaRows(
        child,
        `${prefix}.${name}`,
        Array.isArray(s.required) && s.required.includes(name),
      ),
    );
  }
  if (s.items && typeof s.items === "object") rows.push(...schemaRows(s.items, `${prefix}[]`));
  for (const kind of ["oneOf", "anyOf", "allOf"]) {
    if (Array.isArray(s[kind]))
      s[kind].forEach((child: unknown, i: number) =>
        rows.push(...schemaRows(child, `${prefix} (${kind} ${i + 1})`)),
      );
  }
  return rows;
}
function schema(value: unknown): string {
  return (
    "\n\n| Field / variant | Type | Required in parent | Constraints |\n| --- | --- | --- | --- |\n" +
    schemaRows(value).join("\n") +
    "\n"
  );
}
function content(value: unknown): string {
  return entries(value)
    .map(([media, raw]) => {
      const item = object(raw);
      return `\n**${code(media)}**\n${item.schema ? schema(item.schema) : ""}`;
    })
    .join("\n");
}

export function renderSpecification(spec: ObjectValue): string {
  const info = object(spec.info);
  let out = `\n## Generated reference\n\n${cell(info.title)} · contract version ${code(info.version)}.\n\n${cell(info.description)}\n`;
  if (spec["x-transit-authentication"])
    out += "\n### Authentication metadata\n" + json(spec["x-transit-authentication"]);
  if (spec.servers) out += "\n### Servers\n" + json(spec.servers);
  if (spec.security) out += "\n### API security requirement\n" + json(spec.security);
  for (const [url, raw] of entries(spec.paths)) {
    const pathItem = object(raw);
    for (const [method, operationRaw] of Object.entries(pathItem)) {
      if (
        !["get", "put", "post", "delete", "options", "head", "patch", "trace", "query"].includes(
          method,
        )
      )
        continue;
      const op = object(operationRaw);
      out += `\n## ${method.toUpperCase()} ${url}\n\n${cell(op.summary)}\n\n${cell(op.description)}\n`;
      if (op.operationId) out += `\nOperation: ${code(op.operationId)}.\n`;
      if (op.security) out += "\nSecurity override:\n" + json(op.security);
      for (const param of [
        ...(Array.isArray(pathItem.parameters) ? pathItem.parameters : []),
        ...(Array.isArray(op.parameters) ? op.parameters : []),
      ]) {
        const p = object(param);
        out += `\n### Parameter ${cell(p.name)}\n\n${code(p.in)}; ${p.required ? "required" : "optional"}. ${cell(p.description)}\n`;
        if (p.schema) out += schema(p.schema);
      }
      if (op.requestBody) {
        const body = object(op.requestBody);
        out +=
          `\n### Request body\n\n${body.required ? "Required." : "Optional."} ${cell(body.description)}\n` +
          content(body.content);
      }
      for (const [status, response] of entries(op.responses)) {
        const r = object(response);
        out += `\n### Response ${status}\n\n${cell(r.description)}\n` + content(r.content);
        if (r.headers) out += "\nResponse headers:\n" + json(r.headers);
      }
    }
  }
  for (const [name, raw] of entries(spec.channels)) {
    const channel = object(raw);
    out += `\n## Channel ${name}\n\nAddress: ${code(channel.address)}.\n\n${cell(channel.description)}\n`;
    out +=
      "\nBindings and messages:\n" +
      json({ bindings: channel.bindings, messages: channel.messages });
  }
  for (const [name, raw] of entries(spec.operations)) {
    const op = object(raw);
    out +=
      `\n## Operation ${name}\n\nAction from the server's perspective: ${code(op.action)}.\n` +
      json(op);
  }
  const components = object(spec.components ?? {});
  for (const [name, raw] of entries(components.messages)) {
    const msg = object(raw);
    out += `\n## Message ${name}\n\n${cell(msg.name)} · ${code(msg.contentType)}\n\n${cell(msg.description)}\n`;
    if (msg.payload) out += schema(msg.payload);
  }
  if (components.securitySchemes)
    out += "\n## Security schemes\n" + json(components.securitySchemes);
  out +=
    "\n## Schemas\n\nNested fields use dot paths; array entries use `[]`. Required means required\nwithin the containing object or variant. Numeric, encoding and union constraints\ncome from the specification; a shape-valid request still needs current authority.\n";
  for (const [name, value] of entries(components.schemas)) out += `\n### ${name}\n` + schema(value);
  if (spec["x-transit-budgets"]) out += "\n## Protocol budgets\n" + json(spec["x-transit-budgets"]);
  return out;
}

export function readSpecification(root: string, source: string): ObjectValue {
  const spec = object(JSON.parse(readFileSync(path.join(root, source), "utf8")));
  if (!spec.openapi && !spec.asyncapi) throw new Error(`Not an API description: ${source}`);
  return spec;
}
