import com.google.gson.*;
import io.transit.client.internal.Schema;

/** Independent recursive shapes and failed local-reference resolution. */
public final class JavaSchemaValues {
    private JavaSchemaValues() {}
    private static JsonObject object(String value) { return new Gson().fromJson(value, JsonObject.class); }
    private static void check(boolean value) { if (!value) throw new AssertionError("Recursive schema validation"); }
    public static void main(String[] args) {
        JsonObject root = object("""
            {"$ref":"#/$defs/Cell","$defs":{"Cell":{"oneOf":[
              {"type":"null"},{"type":"integer","minimum":-128,"maximum":127},
              {"type":"array","items":{"$ref":"#/$defs/Cell"},"maxItems":4}
            ]}}}
            """);
        check(Schema.valid(root, new Gson().fromJson("[1,[null,[-128,127]],[]]", JsonElement.class)));
        for (String value : new String[]{"128", "-129", "\"1\"", "[1,2,3,4,5]", "[1,[true]]"}) {
            check(!Schema.valid(root, new Gson().fromJson(value, JsonElement.class)));
        }
        JsonObject other = object("""
            {"$ref":"#/$defs/Cell","$defs":{"Cell":{"type":"object","properties":{},"additionalProperties":false}}}
            """);
        check(Schema.valid(other, object("{}")) && !Schema.valid(other, new JsonPrimitive(1)) && !Schema.valid(root, object("{}")));
        for (String invalid : new String[]{
            "{\"$ref\":\"https://example.invalid/schema\"}",
            "{\"$ref\":\"#/$defs/Missing\",\"$defs\":{}}",
            "{\"$ref\":\"#/$defs/Cell\",\"$defs\":{\"Cell\":{}},\"type\":\"object\"}",
            "{\"$ref\":\"#/$defs/Cell\",\"$defs\":{\"Cell\":{\"$ref\":\"#/$defs/Cell\"}}}",
            "{\"$ref\":\"#/$defs/A\",\"$defs\":{\"A\":{\"$ref\":\"#/$defs/B\"},\"B\":{\"$ref\":\"#/$defs/A\"}}}",
            "{\"invented\":true}", "{\"oneOf\":[]}", "{\"anyOf\":[]}",
            "{\"$defs\":{},\"anyOf\":[{\"$defs\":{},\"type\":\"object\"}]}"
        }) check(!Schema.valid(object(invalid), object("{}")));
        JsonObject hex = object("{\"type\":\"string\",\"pattern\":\"^(?:[0-9a-f]{2})*$\",\"maxLength\":800000}");
        check(Schema.valid(hex, new JsonPrimitive("ab".repeat(300000))));
        check(!Schema.valid(hex, new JsonPrimitive("A0")) && !Schema.valid(hex, new JsonPrimitive("a")));
        check(io.transit.client.internal.Values.unhex(new JsonPrimitive("ab".repeat(300000)), 300000).length == 300000);
        JsonArray cycle = new JsonArray(); cycle.add(cycle);
        check(!Schema.valid(root, cycle));
        JsonElement deep = new JsonPrimitive(1);
        for (int i = 0; i < 129; i++) { JsonArray next = new JsonArray(); next.add(deep); deep = next; }
        check(!Schema.valid(root, deep));
        System.out.println("Java generated recursive schemas: local roots, recursive children, malformed references and cycles passed.");
    }
}
