using System.Globalization;
using System.Text;
using System.Text.Json.Nodes;
using Transit.Client;
using Transit.Station.Sdk;
using C = Transit.Station.Sdk.Catalog;
using L = Transit.Station.Sdk.Logical;

static class Program
{
    internal static void Check(bool value) { if (!value) throw new Exception("Installed direct catalog assertion failed"); }
    static string Text(JsonNode value,string key) => value[key]!.GetValue<string>();
    static ulong Number(JsonNode value,string key) => value[key]!.GetValue<ulong>();
    static ulong Wide(JsonNode value,string key) => ulong.Parse(Text(value,key),CultureInfo.InvariantCulture);
    internal static JsonObject Obj(params (string Key,object? Value)[] fields) {
        JsonObject result = new(); foreach (var (key,value) in fields) result[key] = value switch {
            null => null, JsonNode v => v.DeepClone(), string v => JsonValue.Create(v), bool v => JsonValue.Create(v),
            ulong v => JsonValue.Create(v), uint v => JsonValue.Create(v), int v => JsonValue.Create(v), _ => throw new Exception("Invalid test JSON")
        }; return JsonNode.Parse(result.ToJsonString())!.AsObject();
    }
    static Task<C.Client> Connect(JsonNode config) {
        var c = config["connection"]!; var s = c["scope"]!; ulong realm = Number(s,"realm");
        C.Connection connection = new(new C.Scope(new ResourceRef(realm,Number(s,"resource")),Wide(s,"catalog")),Number(c,"audience"),Wide(c,"branch"),c["role"]?.GetValue<ulong>());
        return C.Client.OpenAsync(new ClientConfig(new Uri(Text(config,"url")),Profile.NativeV1,timeoutMillis:10000),new Credential(realm,Number(c,"principal"),Text(config,"seed_file")),connection,Text(config,"service_url"));
    }
    static void Persist(string path,string value) {
        FileStreamOptions options = new() { Mode = FileMode.Create, Access = FileAccess.Write, Share = FileShare.None };
        if (!OperatingSystem.IsWindows()) options.UnixCreateMode = UnixFileMode.UserRead | UnixFileMode.UserWrite;
        using FileStream file = new(path,options); file.Write(Encoding.UTF8.GetBytes(value)); file.Flush(true);
    }
    static async Task<C.Observation> Complete(C.Client client,C.Compiled work,string directory) {
        Persist(Path.Combine(directory,"work.json"),work.Saved.Save()); var original = await client.StageAsync(work.Intent);
        Persist(Path.Combine(directory,"work-reference.json"),original.Save()); var observed = await client.AdmitAsync(original);
        for (int i=0;i<16 && observed.State == C.OperationState.Admitted;i++) observed = await client.ExecuteAsync(original,32);
        Check(observed.State == C.OperationState.Committed); return observed;
    }
    static Task<C.Compiled> Compile(C.Client client,string sql,ulong operation) => client.CompileSqlAsync(sql,new C.Identity(operation));
    static async Task Uncertain(C.IRecovery original,Func<Task> action) {
        try { await action(); } catch (C.Uncertain error) {
            Check(error.Original.Save() == original.Save() && error.Failure.Status == 6 && !error.Failure.DiagnosticInvalid && error.Failure.Diagnostic?["outcome"]?.GetValue<string>() == "unknown"); return;
        } throw new Exception("Expected original operation uncertainty");
    }
    static C.Snapshot Snapshot(string directory) => C.Snapshot.Restore(File.ReadAllText(Path.Combine(directory,"snapshot.json")));
    static async Task Main(string[] args) {
        if (args[0] == "values") { LogicalValues.Run(); SchemaValues.Run(); await CatalogValues.Run(args[1]); return; }
        var config = JsonNode.Parse(File.ReadAllText(args[0]))!; string directory = Path.Combine(Path.GetDirectoryName(args[0])!,"dotnet"); Directory.CreateDirectory(directory);
        string name = "dotnet_items"; ulong objectId = ulong.MaxValue-1;
        await using (var client = await Connect(config)) {
            Console.WriteLine(Obj(("ready",true)).ToJsonString());
            while (Console.ReadLine() is {} line) {
                var action = JsonNode.Parse(line)!.AsObject(); string command = action.Single().Key; if (command == "close") break;
                JsonObject result;
                switch (command) {
                    case "prepare": {
                        Check((await client.DescribeAsync()).Subject.Principal == Number(config["connection"]!,"principal"));
                        Check((await client.NamespaceAsync(1))!.Name == "public"); Check((await client.NamespacesAsync()).Entries.Any(v => v.Id == 1));
                        await Complete(client,await client.CompileSqlAsync($"CREATE TABLE {name} (id BIGINT PRIMARY KEY, payload BINARY)",new C.Identity(1),objectId),directory);
                        var current = (await client.LookupAsync(name))!; Check(current.RowCount == 0 && current.Basis.ObjectId == objectId);
                        List<IReadOnlyList<C.Assignment>> rows = [];
                        for (int i=0;i<9;i++) {
                            byte[] bytes = new byte[32768]; Array.Fill(bytes,(byte)i);
                            rows.Add([new C.Assignment(1,new L.Present(new L.Signed(i))),new C.Assignment(2,new L.Present(new L.Binary(new L.BinaryData(bytes))))]);
                        }
                        var work = await client.PrepareAsync(name,new C.Identity(2),new C.Mutate(current.Basis,new C.Insert(rows),C.Ingestion.Bulk));
                        Check(((C.CurrentBasis)(await client.PreviewAsync(work.Intent)).Current!).RowCount == 0);
                        Persist(Path.Combine(directory,"intent.json"),work.Saved.Save()); var loaded = await client.LoadAsync(C.SavedIntent.Restore(File.ReadAllText(Path.Combine(directory,"intent.json"))));
                        var original = await client.StageAsync(loaded); Persist(Path.Combine(directory,"original.json"),original.Save());
                        Check((await client.AdmitAsync(original)).State == C.OperationState.Admitted); await Uncertain(original,() => client.ExecuteAsync(original,32));
                        result = Obj(("uncertain",true)); break;
                    }
                    case "recover": {
                        var original = C.Reference.Restore(File.ReadAllText(Path.Combine(directory,"original.json"))); var observed = await client.InspectAsync(original); var commit = observed.Commit!;
                        Check(observed.State == C.OperationState.Committed && commit.Matched == 9 && commit.Affected == 9 && commit.LiveRows == 9);
                        Check(await client.ExecuteAsync(original,32) == observed); var current = (await client.LookupAsync(name))!;
                        var acquisition = client.PrepareSnapshot(current,90000); Persist(Path.Combine(directory,"basis.json"),current.Basis.Save()); Persist(Path.Combine(directory,"acquisition.json"),acquisition.Save());
                        await Uncertain(acquisition,() => client.AcquireSnapshotAsync(acquisition)); result = Obj(("retention_uncertain",true)); break;
                    }
                    case "retained": {
                        var acquisition = C.SnapshotAcquisition.Restore(File.ReadAllText(Path.Combine(directory,"acquisition.json"))); var status = await client.SnapshotStatusAsync(acquisition.Owner);
                        Check(!status.Released && status.Snapshot is not null); var snapshot = status.Snapshot!; Persist(Path.Combine(directory,"snapshot.json"),snapshot.Save());
                        var metadata = await client.SnapshotMetadataAsync(snapshot); Check(metadata.Accepted == acquisition.Expected && metadata.RowCount == 9 && metadata.Schema.Columns.Count == 2);
                        result = Obj(("retained",true)); break;
                    }
                    case "denied": {
                        try { await client.SnapshotMetadataAsync(Snapshot(directory)); throw new Exception("Revoked retained metadata disclosed"); }
                        catch (TransitException error) { Check(error.Kind == ErrorKind.AccessDenied && error.Status == 4 && error.Diagnostic?["category"]?.GetValue<string>() == "access"); }
                        result = Obj(("denied",true)); break;
                    }
                    case "metadata": {
                        var metadata = await client.SnapshotMetadataAsync(Snapshot(directory)); var basis = C.Basis.Restore(File.ReadAllText(Path.Combine(directory,"basis.json")));
                        Check(metadata.Interpretation == basis.Interpretation); result = Obj(("rows",metadata.RowCount),("columns",metadata.Schema.Columns.Count)); break;
                    }
                    case "retire": {
                        var unchanged = (await Complete(client,await Compile(client,$"UPDATE {name} SET id=0 WHERE id=0",3),directory)).Commit!; Check(unchanged.Matched == 1 && unchanged.Affected == 0);
                        var deleted = (await Complete(client,await Compile(client,$"DELETE FROM {name} WHERE id=8",4),directory)).Commit!; Check(deleted.Matched == 1 && deleted.Affected == 1);
                        var old = (await client.LookupAsync(name))!;
                        await Complete(client,await client.PrepareAsync(name,new C.Identity(5),new C.Alter(old.Basis,new C.AddColumn("extra",new L.Scalar(L.ScalarKind.Int64)))),directory);
                        try { await client.PrepareAsync(name,new C.Identity(55),new C.Drop(old.Basis)); throw new Exception("Stale basis retargeted newer definition"); }
                        catch (TransitException error) { Check(error.Code == "TableDefinitionChanged"); }
                        await Complete(client,await Compile(client,$"ALTER TABLE {name} RENAME TO {name}_old",6),directory);
                        await Complete(client,await Compile(client,$"DROP TABLE {name}_old",7),directory);
                        await Complete(client,await client.CompileSqlAsync($"CREATE TABLE {name} (replacement BIGINT)",new C.Identity(8),objectId-1),directory);
                        Check((await client.LookupAsync(name))!.Basis.ObjectId == objectId-1 && (await client.SnapshotMetadataAsync(Snapshot(directory))).RowCount == 9);
                        result = Obj(("original",true)); break;
                    }
                    case "release": {
                        var snapshot = Snapshot(directory); Check(!(await client.SnapshotStatusAsync(snapshot.Owner)).Released);
                        await Uncertain(snapshot,() => client.ReleaseSnapshotAsync(snapshot)); result = Obj(("release_uncertain",true)); break;
                    }
                    case "verify": {
                        var snapshot = Snapshot(directory); Check((await client.SnapshotStatusAsync(snapshot.Owner)).Released); await client.ReleaseSnapshotAsync(snapshot);
                        var original = C.Reference.Restore(File.ReadAllText(Path.Combine(directory,"original.json"))); Check((await client.InspectAsync(original)).Commit!.Affected == 9);
                        Check((await client.LoadAsync(C.SavedIntent.Restore(File.ReadAllText(Path.Combine(directory,"intent.json"))))).Identity.Operation == 2);
                        Check((await client.LookupAsync(name))!.Basis.ObjectId == objectId-1 && (await client.TablesAsync()).Consistency == C.Consistency.Independent);
                        result = Obj(("recovered",true)); break;
                    }
                    default: throw new Exception($"Unknown proof phase: {command}");
                }
                Console.WriteLine(Obj(("status",0),("value",result)).ToJsonString());
            }
        }
        Console.WriteLine(Obj(("closed",true)).ToJsonString());
    }
}
