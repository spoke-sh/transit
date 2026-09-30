using System.Globalization;
using System.Text;
using System.Text.Json.Nodes;
using Transit.Client;
using Transit.Station.Sdk;
using C = Transit.Station.Sdk.Catalog;

static class Program
{
    internal static void Check(bool value) { if (!value) throw new Exception("Catalog caller assertion failed"); }
    static string Text(JsonNode value, string key) => value[key]!.GetValue<string>();
    static ulong Number(JsonNode value, string key) => value[key]!.GetValue<ulong>();
    static ulong Wide(JsonNode value, string key) => ulong.Parse(Text(value, key), CultureInfo.InvariantCulture);
    static string Decimal(ulong value) => value.ToString(CultureInfo.InvariantCulture);
    static string Hex(Bytes value) => Convert.ToHexString(value.Copy()).ToLowerInvariant();
    static C.Prepared Prepared(string value) => new(new Bytes(Encoding.UTF8.GetBytes(value)));
    static string Saved(C.Prepared value) => Encoding.UTF8.GetString(value.Bytes.Copy());
    static string Name(Enum value) => string.Concat(value.ToString().Select((c, i) => (i > 0 && char.IsUpper(c) ? "_" : "") + char.ToLowerInvariant(c)));
    internal static JsonObject Obj(params (string Key, object? Value)[] fields) {
        JsonObject result = new();
        foreach (var (key, value) in fields) result[key] = value switch {
            null => null, JsonNode v => v, string v => JsonValue.Create(v), bool v => JsonValue.Create(v),
            ulong v => JsonValue.Create(v), uint v => JsonValue.Create(v), int v => JsonValue.Create(v),
            byte v => JsonValue.Create(v), ushort v => JsonValue.Create(v),
            _ => throw new Exception("Invalid test JSON")
        };
        return result;
    }
    static C.Scope Scope(JsonNode v) => new(new ResourceRef(Number(v, "realm"), Number(v, "resource")), Wide(v, "catalog"));
    static JsonObject Json(C.Scope v) => Obj(("realm", v.Resource.Realm), ("resource", v.Resource.Resource), ("catalog", Decimal(v.CatalogId)));
    static C.Configuration Configuration(JsonNode v) { var s = Scope(v["scope"]!); return new(s, new ProcessRef(s.Resource.Realm, Number(v, "owner")), Number(v, "administrator")); }
    static JsonObject Json(C.Configuration v) => Obj(("scope", Json(v.Scope)), ("owner", v.Owner.Pid), ("administrator", v.Administrator));
    static C.Policy Policy(JsonNode v) => new(Scope(v["scope"]!), Number(v, "principal"), Wide(v, "revision"), v["inspect"]!.GetValue<bool>(), v["create"]!.GetValue<bool>());
    static JsonObject Json(C.Policy v) => Obj(("scope", Json(v.Scope)), ("principal", v.Principal), ("revision", Decimal(v.Revision)), ("inspect", v.Inspect), ("create", v.Create));
    static C.CreateTable Request(JsonNode v) {
        var schema = v["schema"]!;
        return new(Scope(v["scope"]!), Wide(v, "operation"), Wide(v, "object"), checked((uint)Number(v, "table")), Text(v, "name"),
            new C.Schema(schema["names"]!.AsArray().Select(n => n!.GetValue<string>()).ToArray(), Enum.Parse<C.Type>(Text(schema, "value_type"), true)));
    }
    internal static JsonObject Json(C.CreateTable v) => Obj(("scope", Json(v.Scope)), ("operation", Decimal(v.Operation)), ("object", Decimal(v.ObjectId)), ("table", v.Table), ("name", v.Name),
        ("schema", Obj(("names", new JsonArray(v.Schema.Names.Select(n => (JsonNode?)JsonValue.Create(n)).ToArray())), ("value_type", Name(v.Schema.ValueType)))));
    static C.Cursor Cursor(JsonNode v) => new(Text(v, "definition"), Scope(v["scope"]!), Number(v, "resource_revision"), Text(v, "after"));
    static JsonObject Json(C.Cursor v) => Obj(("definition", v.Definition), ("scope", Json(v.Scope)), ("resource_revision", v.ResourceRevision), ("after", v.After));
    static JsonObject Json(C.Definition v) => Obj(("scope", Json(v.Scope)), ("object", Decimal(v.ObjectId)), ("revision", Decimal(v.Revision)), ("name", v.Name),
        ("source", Obj(("table", Obj(("id", v.Source.Table), ("schema", Obj(("names", new JsonArray(v.Source.Schema.Names.Select(n => (JsonNode?)JsonValue.Create(n)).ToArray())), ("value_type", Name(v.Source.Schema.ValueType)))))))),
        ("principal", v.Principal), ("operation", Decimal(v.Operation)), ("input", v.Input));
    static JsonObject Json(C.Page v) {
        JsonArray entries = new(v.Entries.Select(d => (JsonNode?)Json(d)).ToArray()); while (entries.Count < 8) entries.Add((JsonNode?)null);
        return Obj(("resource_revision", v.ResourceRevision), ("entries", entries), ("next", v.Next is null ? null : Json(v.Next)));
    }
    static async Task<JsonObject> Call(C.Client client, JsonObject action) {
        var entry = action.Single(); var value = entry.Value!;
        switch (entry.Key) {
            case "capabilities": { var v = await client.CapabilitiesAsync(); return Obj(("capabilities", Obj(("version", v.Version), ("definition", v.Definition), ("initialize", v.Initialize), ("create_table", v.CreateTable), ("conditional_policy", v.ConditionalPolicy), ("current_metadata", v.CurrentMetadata), ("max_saved_bytes", v.MaxSavedBytes), ("table_columns", v.TableColumns)))); }
            case "describe": { var v = await client.DescribeAsync(); return Obj(("description", Obj(("configuration", Json(v.Configuration)), ("policy", Json(v.Policy)), ("resource_revision", v.ResourceRevision)))); }
            case "lookup": { var v = await client.LookupAsync(value.GetValue<string>()); return Obj(("definition", v is null ? null : Json(v))); }
            case "definition": { var v = await client.DefinitionAsync(Wide(value, "object"), Wide(value, "revision")); return Obj(("definition", v is null ? null : Json(v))); }
            case "list": return Obj(("page", Json(await client.ListAsync(value is null ? null : Cursor(value)))));
            case "compile": { var v = await client.CompileSqlAsync(Text(value, "sql"), Wide(value, "operation"), Wide(value, "object"), checked((uint)Number(value, "table"))); return Obj(("compiled", Obj(("request", Json(v.Request)), ("canonical", Hex(v.Canonical))))); }
            case "prepare_initialize": return Obj(("prepared", Saved(await client.PrepareInitializeAsync(Configuration(value)))));
            case "prepare_create": return Obj(("prepared", Saved(await client.PrepareCreateAsync(Request(value)))));
            case "prepare_policy": return Obj(("prepared", Saved(await client.PreparePolicyAsync(new C.PolicyChange(Wide(value, "expected_revision"), Policy(value["policy"]!))))));
            case "submit": {
                string original = value.GetValue<string>(); var prepared = Prepared(original);
                try { return Obj(("receipt", Obj(("position", (await client.SubmitAsync(prepared)).Position)))); }
                finally { Check(Saved(prepared) == original); }
            }
            case "observe": return Obj(("observation", Name(await client.ObserveAsync(Prepared(Text(value, "prepared")), Number(value, "input")))));
            case "input_disposition": { var v = await client.InputDispositionAsync(Prepared(Text(value, "prepared")), Number(value, "input")); return Obj(("disposition", v is null ? null : Obj(("scope", Json(v.Scope)), ("origin", Name(v.Origin)), ("principal", v.Principal), ("input", v.Input), ("payload", Hex(v.Payload)), ("outcome", Name(v.Outcome))))); }
            case "status": { var v = await client.StatusAsync(Request(value)); return Obj(("status", v is null ? null : Obj(("request", Json(v.Request)), ("principal", v.Principal), ("input", v.Input), ("outcome", Name(v.Outcome))))); }
            default: throw new Exception("Unknown catalog action");
        }
    }
    static async Task Main(string[] args) {
        if (args[0] == "values") { await CatalogValues.Run(args[1]); return; }
        var config = JsonNode.Parse(File.ReadAllText(args[0]))!; var c = config["connection"]!; var s = Scope(c["scope"]!);
        C.Connection connection = new(new ProcessRef(s.Resource.Realm, Number(c, "owner")), s);
        await using (var client = await C.Client.OpenAsync(new ClientConfig(new Uri(Text(config, "url")), Profile.NativeV1, timeoutMillis: 10000), new Credential(s.Resource.Realm, Number(c, "principal"), Text(config, "seed_file")), connection)) {
            Console.WriteLine("{\"ready\":true}");
            while (Console.ReadLine() is {} line) {
                var action = JsonNode.Parse(line)!.AsObject(); if (action.ContainsKey("close")) break;
                try { Console.WriteLine(Obj(("status", 0), ("value", await Call(client, action))).ToJsonString()); }
                catch (TransitException error) { Console.WriteLine(Obj(("status", error.Status ?? (error.Kind == ErrorKind.UnknownOutcome ? 6u : 1u)), ("value", Obj(("err", error.Code)))).ToJsonString()); }
            }
        }
        Console.WriteLine("{\"closed\":true}");
    }
}
