package io.transit.client.internal;

import com.google.gson.*;
import java.math.BigDecimal;
import java.util.Set;
import java.util.IdentityHashMap;

/** Only implements keywords emitted by Zig; unrecognized keywords fail closed. */
public final class Schema {
    private Schema() {}
    private static final Set<String> KEYS = Set.of("type", "properties", "additionalProperties", "required", "maxProperties",
        "$defs", "$ref", "anyOf", "oneOf", "enum", "const", "minimum", "maximum", "maxLength", "pattern", "items", "minItems", "maxItems");
    public static void require(JsonObject schema, JsonElement value) {
        if (!valid(schema, value)) throw Values.incompatible("native-schema");
    }
    public static boolean valid(JsonObject schema, JsonElement value) {
        try { return valid(schema, value, schema, new IdentityHashMap<>(), 0); }
        catch (RuntimeException | StackOverflowError error) { return false; }
    }
    private static boolean valid(JsonObject schema, JsonElement value, JsonObject root,
            IdentityHashMap<JsonObject, IdentityHashMap<JsonElement, Boolean>> active, int depth) {
        if (schema == null || value == null || depth > 128 || !KEYS.containsAll(schema.keySet())) return false;
        if (schema.has("$defs") && (schema != root || !schema.get("$defs").isJsonObject())) return false;
        var values = active.computeIfAbsent(schema, unused -> new IdentityHashMap<>());
        if (values.put(value, Boolean.TRUE) != null) return false;
        try { return rule(schema, value, root, active, depth); }
        finally {
            values.remove(value);
            if (values.isEmpty()) active.remove(schema);
        }
    }
    private static boolean rule(JsonObject schema, JsonElement value, JsonObject root,
            IdentityHashMap<JsonObject, IdentityHashMap<JsonElement, Boolean>> active, int depth) {
        if (schema.has("$ref")) {
            if (!Set.of("$defs", "$ref").containsAll(schema.keySet())) return false;
            JsonElement reference = schema.get("$ref");
            if (!reference.isJsonPrimitive() || !reference.getAsJsonPrimitive().isString()) return false;
            String name = reference.getAsString();
            if (!name.matches("#/\\$defs/[A-Za-z0-9_]+") || !root.has("$defs") || !root.get("$defs").isJsonObject()) return false;
            JsonElement target = root.getAsJsonObject("$defs").get(name.substring(8));
            return target != null && target.isJsonObject() && valid(target.getAsJsonObject(), value, root, active, depth);
        }
        for (String union : new String[]{"anyOf", "oneOf"}) {
            if (!schema.has(union)) continue;
            if (!schema.get(union).isJsonArray() || schema.getAsJsonArray(union).isEmpty()) return false;
            int matches = 0;
            for (JsonElement branch : schema.getAsJsonArray(union)) if (valid(branch.getAsJsonObject(), value, root, active, depth)) matches++;
            if (matches == 0 || (union.equals("oneOf") && matches != 1)) return false;
        }
        if (schema.has("const") && !schema.get("const").equals(value)) return false;
        if (schema.has("enum") && !schema.getAsJsonArray("enum").contains(value)) return false;
        if (!schema.has("type")) return true;
        return switch (schema.get("type").getAsString()) {
            case "null" -> value.isJsonNull();
            case "boolean" -> value.isJsonPrimitive() && value.getAsJsonPrimitive().isBoolean();
            case "integer", "number" -> number(schema, value);
            case "string" -> value.isJsonPrimitive() && value.getAsJsonPrimitive().isString() &&
                (!schema.has("maxLength") || value.getAsString().codePointCount(0, value.getAsString().length()) <= schema.get("maxLength").getAsInt()) &&
                (!schema.has("pattern") || java.util.regex.Pattern.compile(schema.get("pattern").getAsString()).matcher(value.getAsString()).matches());
            case "array" -> array(schema, value, root, active, depth);
            case "object" -> object(schema, value, root, active, depth);
            default -> false;
        };
    }
    private static boolean number(JsonObject schema, JsonElement value) {
        if (!value.isJsonPrimitive() || !value.getAsJsonPrimitive().isNumber()) return false;
        try {
            BigDecimal number = value.getAsBigDecimal();
            // Inspect scale without expanding an attacker-controlled exponent.
            if (number.stripTrailingZeros().scale() > 0) return false;
            return (!schema.has("minimum") || number.compareTo(schema.get("minimum").getAsBigDecimal()) >= 0) &&
                (!schema.has("maximum") || number.compareTo(schema.get("maximum").getAsBigDecimal()) <= 0);
        } catch (ArithmeticException | NumberFormatException error) { return false; }
    }
    private static boolean array(JsonObject schema, JsonElement value, JsonObject root,
            IdentityHashMap<JsonObject, IdentityHashMap<JsonElement, Boolean>> active, int depth) {
        if (!value.isJsonArray()) return false;
        JsonArray array = value.getAsJsonArray();
        if ((schema.has("minItems") && array.size() < schema.get("minItems").getAsInt()) ||
            (schema.has("maxItems") && array.size() > schema.get("maxItems").getAsInt())) return false;
        for (JsonElement item : array) if (!valid(schema.getAsJsonObject("items"), item, root, active, depth + 1)) return false;
        return true;
    }
    private static boolean object(JsonObject schema, JsonElement value, JsonObject root,
            IdentityHashMap<JsonObject, IdentityHashMap<JsonElement, Boolean>> active, int depth) {
        if (!value.isJsonObject()) return false;
        JsonObject object = value.getAsJsonObject();
        if (schema.has("maxProperties") && object.size() > schema.get("maxProperties").getAsInt()) return false;
        JsonObject properties = schema.has("properties") ? schema.getAsJsonObject("properties") : new JsonObject();
        if (schema.has("additionalProperties") && !schema.get("additionalProperties").getAsBoolean() && !properties.keySet().containsAll(object.keySet())) return false;
        if (schema.has("required")) for (JsonElement key : schema.getAsJsonArray("required")) if (!object.has(key.getAsString())) return false;
        for (var entry : properties.entrySet()) if (object.has(entry.getKey()) && !valid(entry.getValue().getAsJsonObject(), object.get(entry.getKey()), root, active, depth + 1)) return false;
        return true;
    }
}
