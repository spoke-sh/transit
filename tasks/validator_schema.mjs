// Build-time sharing for reflected schemas that repeat complete nested types.
// Public schemas stay unchanged; only AJV's compilation input uses these refs.
export function shareValidatorSchemas(ajv, schemas) {
  const counts = new Map();
  const references = new Map();
  const definitions = new Map();
  const protectedAncestors = new WeakSet();
  const pointers = [];
  const documents = new Map();
  let unknownScope = false;
  const maps = new Set(["properties", "$defs", "patternProperties"]);
  const lists = new Set(["anyOf", "oneOf", "allOf", "prefixItems"]);
  const singles = new Set([
    "items",
    "additionalProperties",
    "contains",
    "not",
    "if",
    "then",
    "else",
  ]);

  function children(schema, visit) {
    return Object.fromEntries(
      Object.entries(schema).map(([key, value]) => {
        if (maps.has(key))
          return [
            key,
            Object.fromEntries(Object.entries(value).map(([name, child]) => [name, visit(child)])),
          ];
        if (lists.has(key)) return [key, value.map(visit)];
        if (singles.has(key)) return [key, visit(value)];
        return [key, value];
      }),
    );
  }

  function keyOf(schema) {
    const key = JSON.stringify(schema);
    // Moving a schema with references, identifiers or anchors can change its
    // resolution scope. Keep those scopes in place; only closed children may be shared.
    return key.length >= 40 &&
      !/"\$(?:schema|ref|id|anchor|dynamicRef|dynamicAnchor|recursiveRef|recursiveAnchor)"\s*:/.test(
        key,
      )
      ? key
      : null;
  }

  function count(schema, root) {
    if (typeof schema !== "object" || schema === null) return schema;
    // A nested resource introduces another reference scope. Leave such input
    // unchanged until its scope graph is supported explicitly.
    if (schema !== root && typeof schema.$id === "string") unknownScope = true;
    if (typeof schema.$ref === "string") {
      if (schema.$ref.includes("#")) pointers.push({ root, reference: schema.$ref });
    }
    const key = keyOf(schema);
    if (key) counts.set(key, (counts.get(key) ?? 0) + 1);
    children(schema, (child) => count(child, root));
    return schema;
  }
  function rewrite(schema) {
    if (typeof schema !== "object" || schema === null) return schema;
    const key = keyOf(schema);
    const shared = key && counts.get(key) > 1 && !protectedAncestors.has(schema);
    if (shared && references.has(key)) return { $ref: references.get(key) };
    const rewritten = children(schema, rewrite);
    if (!shared) return rewritten;
    const id = `https://transit.invalid/generated-validator/${references.size}`;
    references.set(key, id);
    definitions.set(id, rewritten);
    return { $ref: id };
  }
  for (const [name, schema] of Object.entries(schemas)) {
    documents.set(name, schema);
    if (typeof schema.$id === "string") documents.set(schema.$id, schema);
    count(schema, schema);
  }
  if (unknownScope) return schemas;
  for (const { root, reference } of pointers) {
    const separator = reference.indexOf("#");
    const document = reference.slice(0, separator);
    let path;
    try {
      const fragment = decodeURIComponent(reference.slice(separator + 1));
      if (!fragment.startsWith("/")) continue;
      path = fragment
        .slice(1)
        .split("/")
        .map((part) => part.replaceAll("~1", "/").replaceAll("~0", "~"));
    } catch {
      return schemas;
    }
    let node = document ? documents.get(document) : root;
    if (!node) return schemas;
    // Keep every ancestor in place so the original pointer remains resolvable.
    // Its target may become a reference to a shared validator; JSON Schema
    // resolves that reference normally. Siblings can still share closed types.
    for (const part of path) {
      if (typeof node !== "object" || node === null || !Object.hasOwn(node, part)) return schemas;
      protectedAncestors.add(node);
      node = node[part];
    }
  }
  const rewritten = Object.fromEntries(
    Object.entries(schemas).map(([name, schema]) => [
      name,
      typeof schema === "boolean" ? schema : children(schema, rewrite),
    ]),
  );
  for (const [id, schema] of definitions) ajv.addSchema(schema, id);
  return rewritten;
}
