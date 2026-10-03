using System.Text;
using System.Text.Json.Nodes;
using Transit.Client;
using Transit.Station.Sdk;
using M = Transit.Station.Sdk.Mutations;

static class Program
{
    static void Check(bool value) { if (!value) throw new Exception("Mutation caller assertion failed"); }
    static string Text(JsonNode value, string key) => value[key]!.GetValue<string>();
    static ulong Number(JsonNode value, string key) => value[key]!.GetValue<ulong>();
    static string Hex(Bytes value) => Convert.ToHexString(value.Copy()).ToLowerInvariant();
    static M.Reference Reference(string value) => new(new Bytes(Convert.FromHexString(value)));
    static M.Prepared Prepared(string value) => new(new Bytes(Encoding.UTF8.GetBytes(value)));
    static string Saved(M.Prepared value) => Encoding.UTF8.GetString(value.Bytes.Copy());
    static string Name(Enum value) => string.Concat(value.ToString().Select((c, i) => (i > 0 && char.IsUpper(c) ? "_" : "") + char.ToLowerInvariant(c)));
    static JsonObject Obj(params (string Key, object? Value)[] fields) {
        JsonObject result = new();
        foreach (var (key, value) in fields) result[key] = value switch {
            null => null, JsonNode v => v, string v => JsonValue.Create(v), bool v => JsonValue.Create(v),
            ulong v => JsonValue.Create(v), uint v => JsonValue.Create(v), int v => JsonValue.Create(v), byte v => JsonValue.Create(v),
            _ => throw new Exception("Invalid test JSON")
        };
        return result;
    }
    static async Task<JsonObject> Call(M.Client client, JsonObject action) {
        if (action.ContainsKey("capabilities")) return Obj(("capabilities", Obj(("max_rows", 3))));
        if (action.ContainsKey("describe")) {
            var v = await client.DescribeAsync();
            if (v.Names is IList<string> list) { try { list[0] = "changed"; throw new Exception("Mutable column names"); } catch (NotSupportedException) { } }
            return Obj(("description", Obj(("resource", v.Resource.Resource), ("table", v.Table), ("names", new JsonArray(v.Names.Select(n => (JsonNode?)JsonValue.Create(n)).ToArray())),
                ("value_type", Name(v.ValueType)), ("resource_revision", v.ResourceRevision), ("policy_revision", v.PolicyRevision.ToString()), ("declaration", Hex(v.Declaration)), ("permissions", (byte)v.Permissions), ("active", v.Active?.ToString()))));
        }
        if (action["compile"] is {} compile) {
            var v = await client.CompileSqlAsync(Text(compile, "name"), Text(compile, "sql"), ulong.Parse(Text(compile, "namespace")));
            return Obj(("compiled", Obj(("request", Hex(v.Request)), ("reference", Hex(v.Reference.Bytes)))));
        }
        if (action["next"] is {} next) {
            byte[] input = Convert.FromHexString(Text(next, "request")); M.Compiled compiled = new(new Bytes(input), Reference(Text(next, "reference")));
            Array.Fill(input, (byte)0); byte[] exposed = compiled.Request.Copy(); Array.Fill(exposed, (byte)0); Check(Hex(compiled.Request) == Text(next, "request"));
            var v = await client.PrepareNextAsync(compiled); return Obj(("prepared", v is null ? null : Saved(v)));
        }
        if (action["prepare"] is JsonObject prepare) {
            var v = prepare.Single(); M.Control control = v.Key switch { "apply" => M.Control.Apply, "cancel" => M.Control.Cancel, _ => throw new Exception("Unknown control") };
            return Obj(("prepared", Saved(await client.PrepareControlAsync(control, Reference(v.Value!.GetValue<string>())))));
        }
        if (action.ContainsKey("submit")) {
            string original = Text(action, "submit"); var prepared = Prepared(original);
            try { return Obj(("receipt", Obj(("position", (await client.SubmitAsync(prepared)).Position)))); }
            finally { Check(Saved(prepared) == original); }
        }
        if (action["observe"] is {} observe) return Obj(("observation", Name(await client.ObserveAsync(Prepared(Text(observe, "prepared")), Number(observe, "input")))));
        if (action["rejection"] is {} rejection) {
            var v = await client.RejectionAsync(Prepared(Text(rejection, "prepared")), Number(rejection, "input")); return Obj(("rejection", v is null ? null : Obj(("principal",v.Principal),("input",v.Input),("payload",Hex(v.Payload)),("reason",Name(v.Reason)),("diagnostic",v.Diagnostic))));
        }
        Check(action.ContainsKey("status")); var status = await client.StatusAsync(Reference(Text(action, "status")));
        return Obj(("status", status is null ? null : Obj(("reference", Hex(status.Reference.Bytes)), ("principal", status.Principal), ("table", status.Table), ("declaration", Hex(status.Declaration)),
            ("policy_revision", status.PolicyRevision.ToString()), ("phase", Name(status.Phase)), ("affected_rows", status.AffectedRows), ("reason", Name(status.Reason)), ("input", status.Input), ("diagnostic",status.Diagnostic), ("conflict", status.Conflict is {} c ? Obj(("key", c.Key.ToString()), ("row", c.Row)) : null))));
    }
    static async Task Main(string[] args) {
        var config = JsonNode.Parse(File.ReadAllText(args[0]))!; var c = config["connection"]!; ulong realm = Number(c, "realm");
        M.Connection connection = new(new ProcessRef(realm, Number(c, "writer")), new ResourceRef(realm, Number(c, "resource")), checked((uint)Number(c, "table")));
        await using (var client = await M.Client.OpenAsync(new ClientConfig(new Uri(Text(config, "url")), Profile.NativeV1, timeoutMillis: 10000), new Credential(realm, Number(c, "principal"), Text(config, "seed_file")), connection)) {
            Console.WriteLine("{\"ready\":true}");
            while (Console.ReadLine() is {} line) {
                var action = JsonNode.Parse(line)!.AsObject(); if (action.ContainsKey("close")) break;
                try { Console.WriteLine(Obj(("status", 0), ("value", await Call(client, action))).ToJsonString()); }
                catch (TransitException error) { Console.WriteLine(Obj(("status", error.Status ?? (error.Kind == ErrorKind.UnknownOutcome ? 6u : 1u)), ("value", Obj(("err", error.Code),("diagnostic",error.Diagnostic),("diagnostic_invalid",error.DiagnosticInvalid)))).ToJsonString()); }
            }
        }
        Console.WriteLine("{\"closed\":true}");
    }
}
