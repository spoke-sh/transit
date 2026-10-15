using System.Globalization;
using System.Text;
using System.Text.Json.Nodes;
using Transit.Client;
using Transit.Station.Sdk;
using C = Transit.Station.Sdk.Catalog;
using L = Transit.Station.Sdk.Logical;

static class Program
{
    internal static void Check(bool value) { if (!value) throw new Exception("Installed Table assertion failed"); }
    static string Text(JsonNode value, string key) => value[key]!.GetValue<string>();
    static ulong Number(JsonNode value, string key) => value[key]!.GetValue<ulong>();
    static ulong Wide(JsonNode value, string key) => ulong.Parse(Text(value, key), CultureInfo.InvariantCulture);
    internal static JsonObject Obj(params (string Key, object? Value)[] fields) {
        JsonObject result = new();
        foreach (var (key, value) in fields) result[key] = value switch {
            null => null, JsonNode v => v, string v => JsonValue.Create(v), bool v => JsonValue.Create(v),
            ulong v => JsonValue.Create(v), uint v => JsonValue.Create(v), int v => JsonValue.Create(v),
            _ => throw new Exception("Invalid test JSON")
        }; return result;
    }
    static Task<C.Client> Connect(JsonNode config) {
        var c = config["connection"]!; var s = c["scope"]!; ulong realm = Number(s,"realm");
        C.Connection connection = new(new ProcessRef(realm, Number(c,"owner")), new C.Scope(new ResourceRef(realm, Number(s,"resource")), Wide(s,"catalog")), c["role"]?.GetValue<ulong>(), c["namespace"]?.GetValue<ulong>() ?? 1);
        return C.Client.OpenAsync(new ClientConfig(new Uri(Text(config,"url")), Profile.NativeV1, timeoutMillis: config["table_service_url"] is null ? 10000u : 30000u), new Credential(realm, Number(c,"principal"), Text(config,"seed_file")), connection, config["table_service_url"]?.GetValue<string>());
    }
    static void Persist(string path, byte[] bytes) {
        FileStreamOptions options = new() { Mode = FileMode.Create, Access = FileAccess.Write, Share = FileShare.None };
        if (!OperatingSystem.IsWindows()) options.UnixCreateMode = UnixFileMode.UserRead | UnixFileMode.UserWrite;
        using FileStream file = new(path, options); file.Write(bytes); file.Flush(true);
    }
    static async Task<C.Outcome> Finish(C.Client client, C.Compiled compiled, string root) {
        var saved = Obj(("definition", compiled.Saved.Definition), ("bytes", Convert.ToHexString(compiled.Saved.Copy()).ToLowerInvariant()));
        Persist(Path.Combine(root,"intent.json"), Encoding.UTF8.GetBytes(saved.ToJsonString()));
        var reference = compiled.Intent.Reference; long deadline = Environment.TickCount64 + 120000;
        for (;;) {
            Check(Environment.TickCount64 < deadline); var next = await client.NextAsync(reference);
            if (next.Kind == C.NextKind.Terminal) return next.Outcome!;
            if (next.Kind == C.NextKind.Running) continue;
            Check(next.Kind == C.NextKind.Send); var prepared = next.Prepared!;
            Persist(Path.Combine(root,"step.json"), prepared.Bytes.Copy()); ulong position = (await client.SubmitAsync(prepared)).Position;
            Persist(Path.Combine(root,"receipt.json"), Encoding.UTF8.GetBytes(position.ToString(CultureInfo.InvariantCulture)));
            for (;;) {
                Check(Environment.TickCount64 < deadline); var progress = await client.ProgressAsync(reference, prepared, position, wait: true);
                if (progress.Observation == C.Observation.Pending) continue;
                Check(progress.Disposition is null);
                if (progress.Outcome is { Terminal: true } outcome) return outcome;
                break;
            }
        }
    }
    static L.Present Atom(L.Atom value) => new(value);
    static async Task<JsonObject> Scenario(C.Client client, JsonNode config, string root, ulong index) {
        ulong start = 1100 + index * 100, objectId = 12001 + index * 10; string name = $"sdk_people_{index}";
        C.Identity Id(ulong offset) => new(start + offset, start + offset + 100000);
        var description = await client.DescribeAsync(); Check(description.Configuration.Scope == client.Connection.Scope && description.Subject.Principal == Number(config["connection"]!, "principal"));
        var create = await client.CompileSqlAsync($"CREATE TABLE {name} (id INTEGER PRIMARY KEY, payload STRUCT(data BINARY, label UTF8), amount DECIMAL(38,2))", Id(0), objectId);
        Check((await Finish(client, create, root)).Phase == C.Phase.Applied);
        var original = (await client.LookupAsync(name))!; Check(original.Schema.Columns.Count == 3 && original.Schema.Columns[1].Type is L.Structure);
        var payload = new L.Present(new L.Sequence(L.SequenceKind.Structure, [Atom(new L.Binary(new L.BinaryData([0,128,255]))), Atom(new L.Utf8("東京"))]));
        var amount = Atom(new L.DecimalValue(Int128.Parse("123456789012345678901234567890", CultureInfo.InvariantCulture)));
        var insert = await client.PrepareAsync(name, Id(1), new C.Mutate(original.Metadata.Basis, new C.Insert([[new C.Assignment(3,amount),new C.Assignment(1,Atom(new L.Signed(1))),new C.Assignment(2,payload)]])));
        var applied = await Finish(client, insert, root); Check(applied.Counts == new C.Counts(1,1));
        C.Predicate[] predicate = [new C.Comparison(1,C.CompareOperator.Eq,new L.Signed(1))];
        var update = await client.PrepareAsync(name, Id(2), new C.Mutate(original.Metadata.Basis, new C.Update([new C.Assignment(3,amount)],predicate)));
        Check((await Finish(client, update, root)).Counts == new C.Counts(1,0));
        var alter = await client.PrepareAsync(name, Id(3), new C.Alter(original.Metadata.Basis, new C.AddColumn("enabled",new L.Scalar(L.ScalarKind.Boolean),false,Atom(new L.BooleanValue(true)))));
        Check((await Finish(client, alter, root)).Phase == C.Phase.Applied);
        try { await client.PrepareAsync(name,Id(4),new C.Drop(original.Metadata.Basis)); throw new Exception("Stale basis retargeted work"); } catch (TransitException) { }
        var current = (await client.LookupAsync(name))!;
        var delete = await client.PrepareAsync(name,Id(5),new C.Mutate(current.Metadata.Basis,new C.Delete(predicate)));
        Check((await Finish(client,delete,root)).Counts == new C.Counts(1,1));
        Check((await Finish(client,await client.PrepareAsync(name,Id(6),new C.Drop(current.Metadata.Basis)),root)).Phase == C.Phase.Applied);
        Check((await Finish(client,await client.CompileSqlAsync($"CREATE TABLE {name} (replacement TEXT)",Id(7),objectId+1),root)).Phase == C.Phase.Applied);
        await client.DisposeAsync();
        await using (var replacement = await Connect(config)) {
            var loaded = await replacement.LoadAsync(new C.SavedIntent(insert.Saved.Definition,insert.Saved.Copy())); Check(loaded.ObjectId == objectId);
            Check((await replacement.StatusAsync(loaded.Reference)).Outcome == applied);
            Check((await replacement.LookupAsync(name))!.Metadata.ObjectId == objectId + 1);
            var historical = (await replacement.DefinitionAsync(objectId,original.Metadata.Revision))!;
            Check(historical.Metadata == original.Metadata && historical.Schema == original.Schema);
            Check(await replacement.DefinitionAsync(objectId,999) is null); Check((await replacement.ListAsync()).Entries.Count > 0);
        }
        return Obj(("profile","installed-dotnet-general-table"),("original_object",objectId.ToString(CultureInfo.InvariantCulture)),("replacement_object",(objectId+1).ToString(CultureInfo.InvariantCulture)),("counts",Obj(("matched","1"),("changed","1"))));
    }
    static async Task Main(string[] args) {
        if (args[0] == "values") { LogicalValues.Run(); SchemaValues.Run(); await CatalogValues.Run(args[1]); return; }
        string path = args[0]; var config = JsonNode.Parse(File.ReadAllText(path))!;
        await using (var client = await Connect(config)) {
            Console.WriteLine("{\"ready\":true}");
            while (Console.ReadLine() is {} line) {
                var action = JsonNode.Parse(line)!.AsObject(); if (action.ContainsKey("close")) break;
                if (action.ContainsKey("denied")) {
                    await using var fresh = await Connect(config);
                    bool denied = false;
                    try { await fresh.DescribeAsync(); } catch (TransitException error) { Check(error.Kind == ErrorKind.AccessDenied); denied = true; }
                    Check(denied);
                    Console.WriteLine(Obj(("status",0),("value",Obj(("denied",true)))).ToJsonString()); continue;
                }
                Console.WriteLine(Obj(("status",0),("value",await Scenario(client,config,Path.GetDirectoryName(path)!,Number(action["scenario"]!,"index")))).ToJsonString());
            }
        }
        Console.WriteLine("{\"closed\":true}");
    }
}
