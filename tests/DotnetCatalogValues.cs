using System.Net;
using System.Net.Sockets;
using System.Reflection;
using System.Runtime.ExceptionServices;
using System.Text.Json;
using System.Text.Json.Nodes;
using Transit.Client;
using Transit.Station.Sdk;
using C = Transit.Station.Sdk.Catalog;
using L = Transit.Station.Sdk.Logical;

internal static class CatalogValues
{
    static void Check(bool value) => Program.Check(value);
    static E Reject<E>(Action action) where E : Exception {
        try { action(); } catch (E error) { return error; } throw new Exception("Expected catalog failure");
    }
    static object? Invoke(Type type, string name, params object?[] args) {
        try { return type.GetMethod(name, BindingFlags.NonPublic | BindingFlags.Static)!.Invoke(null, args); }
        catch (TargetInvocationException error) { ExceptionDispatchInfo.Capture(error.InnerException!).Throw(); throw; }
    }
    static object? Decode(string name, params object?[] args) {
        Func<object?> action = () => Invoke(typeof(C), name, args);
        try { return typeof(C).GetMethod("Decode", BindingFlags.NonPublic | BindingFlags.Static)!.MakeGenericMethod(typeof(object)).Invoke(null, [action]); }
        catch (TargetInvocationException error) { ExceptionDispatchInfo.Capture(error.InnerException!).Throw(); throw; }
    }
    static JsonObject Wire(object value) {
        var method = value.GetType().GetMethod("Wire", BindingFlags.NonPublic | BindingFlags.Instance)!;
        try { return ((JsonObject)method.Invoke(value,null)!).DeepClone().AsObject(); }
        catch (TargetInvocationException error) { ExceptionDispatchInfo.Capture(error.InnerException!).Throw(); throw; }
    }
    static async Task Expect(ErrorKind kind, Func<Task> action) {
        try { await action(); } catch (TransitException error) { Check(error.Kind == kind); return; } throw new Exception("Expected catalog task failure");
    }
    static JsonObject Obj(params (string Key,object? Value)[] fields) => Program.Obj(fields);
    static C.Scope Scope() => new(new ResourceRef(46,7),ulong.MaxValue);
    static C.Connection Connection() => new(Scope(),3);
    static JsonObject ConnectionWire() => Obj(("scope",Wire(Scope())),("branch","1"),("audience",3),("principal",17),("role",null));
    static JsonObject ObjectIdentity() => Obj(("scope",Wire(Scope())),("branch","1"),("object",ulong.MaxValue.ToString()));
    static JsonObject Interpretation() => Obj(("object",ObjectIdentity()),("revision","1"),("digest",string.Concat(Enumerable.Repeat("ab",32))));
    static JsonObject Stored() => Obj(("interpretation",Interpretation()),("content",Obj(("bytes","300"),("sha256",string.Concat(Enumerable.Repeat("ab",32))))),("schema_fingerprint",string.Concat(Enumerable.Repeat("cd",32))),("retired",false));
    static JsonObject Basis() => Obj(("definition",C.ContractDefinition),("connection",ConnectionWire()),("namespace",1),("name","items"),("interpretation",Stored()));
    static JsonObject Position() => Obj(("partition",ulong.MaxValue.ToString()),("next_lsn",ulong.MaxValue.ToString()));
    static JsonObject Binding() => Obj(("definition",C.ContractDefinition),("identity",Obj(("scope",Wire(Scope())),("principal",17),("operation","10"))),("target",ObjectIdentity()),("action","insert"),("expected_definition",Interpretation()),("expected_data",null),("intent",new string('a',64)),("prerequisite",null));
    static JsonObject Saved() => Obj(("table",Obj(("definition",C.ContractDefinition),("namespace",1),("bytes","aabb"))));
    static JsonObject Reference() => Obj(("table",Obj(("definition",C.ContractDefinition),("connection",ConnectionWire()),("namespace",1),("binding",Binding()),("content",Obj(("bytes","200"),("sha256",new string('2',64)))))));
    static JsonObject Summary() => Obj(("id",Obj(("definition",C.ContractDefinition),("digest",new string('1',64)))),("namespace",1),("binding",Obj(("table",Binding()))));
    static JsonObject Observation() => Obj(("rows",Obj(("committed",Obj(("binding",Binding()),("resulting",Stored()),("outcome",Obj(("position",Position()),("matched","9"),("affected","9"),("live_rows","9"))))))));
    static C.Schema Schema() => new(ulong.MaxValue,1,2,[new C.Column(1,"id",new L.Scalar(L.ScalarKind.Int128))]);
    static JsonObject Page() {
        JsonArray entries = new(Obj(("interpretation",Interpretation()),("namespace",1),("name","items"),("position",Position()),("changed_lsn","3")));
        while (entries.Count < 8) entries.Add((JsonNode?)null);
        return Obj(("position",Position()),("entries",entries),("next",Obj(("definition",C.ContractDefinition),("connection",ConnectionWire()),("selection",Obj(("tables",1))),("position",Position()),("after",ulong.MaxValue.ToString()))),("consistency","independent"));
    }
    static void Values() {
        var basis = C.Basis.Restore(Basis().ToJsonString()); Check(basis.ObjectId == ulong.MaxValue && basis.Connection == Connection());
        Reject<Exception>(() => C.Basis.Restore(basis.Save()[..^1] + ",\"name\":\"other\"}")); Check(!basis.ToString().Contains("items"));
        foreach (bool missing in new[] {true,false}) {
            var value = Reference(); if (missing) value["table"]!.AsObject().Remove("definition"); else value["table"]!["definition"] = new string('0',64);
            Reject<Exception>(() => C.Reference.Restore(value.ToJsonString()));
        }
        var physical = Wire(Schema()); physical["columns"]![0]!["type"] = Obj(("utf8",Obj())); physical["columns"]![0]!["encoding"] = "ebcdic"; physical["columns"]![0]!["collation"] = "ebcdic_cp037";
        Check(((C.Schema)Decode("ParseSchema",physical)!).Columns[0].Collation == C.Collation.EbcdicCp037);
        foreach (string field in new[] {"encoding","collation"}) {
            var bad = physical.DeepClone(); bad["columns"]![0]!.AsObject().Remove(field); Reject<TransitException>(() => Decode("ParseSchema",bad));
        }
        L.Cell large = new L.Present(new L.Binary(new L.BinaryData(new byte[1024*1024]))); L.Cell invalid = new L.Present(new L.Sequence(L.SequenceKind.List,[large,large]));
        C.Schema oversized = new(1,1,3,[new C.Column(1,"data",new L.Scalar(L.ScalarKind.Binary),defaultValue:large),new C.Column(2,"later",new L.Scalar(L.ScalarKind.Binary),defaultValue:invalid)]);
        Check(Reject<ArgumentException>(() => Wire(oversized)).Message == "Table wire budget exceeded");
        List<IReadOnlyList<C.Assignment>> rows = Enumerable.Repeat<IReadOnlyList<C.Assignment>>([new C.Assignment(1,large)],9).ToList(); rows.Add([new C.Assignment(1,invalid)]);
        Check(Reject<ArgumentException>(() => Wire(new C.Insert(rows))).Message == "Table wire budget exceeded");
        JsonArray context = new(); for (int i=0;i<32;i++) context.Add(1);
        var description = Obj(("configuration",Obj(("scope",Wire(Scope())),("branch","1"),("partition",ulong.MaxValue.ToString()),("audience",3),("authority",Wire(new C.AuthorityProfile(10,11,12,20,1,21))),("database_name","ledger"),("initial_schema_name","public"))),
            ("subject",Obj(("principal",17),("login_role",17),("role",17),("credential_epoch",1),("audience",3),("context",context))),("policy_revision",2));
        Invoke(typeof(C),"ValidateResponse",Obj(("catalog",Obj(("description",description)))));
        Check(((C.Description)Decode("ParseDescription",description,Connection(),17ul)!).Configuration.Partition == ulong.MaxValue);
        foreach (string field in new[] {"principal","audience","credential_epoch"}) {
            var bad = description.DeepClone(); bad["subject"]![field] = field == "credential_epoch" ? 0 : 18; Reject<TransitException>(() => Decode("ParseDescription",bad,Connection(),17ul));
        }
        var source = Page(); Invoke(typeof(C),"ValidateResponse",Obj(("catalog",Obj(("tables",source)))));
        var page = (C.Page<C.Entry>)Decode("ParseTables",source,Connection(),17ul,1ul,null)!; source["entries"]![0] = null;
        Check(page.Entries[0].Interpretation.Object.ObjectId == ulong.MaxValue && page.Entries[0].Name == "items");
        Reject<NotSupportedException>(() => ((IList<C.Entry>)page.Entries).Clear());
        for (int i=0;i<9;i++) {
            var bad = Page(); var entries = bad["entries"]!.AsArray(); var next = bad["next"]!; var first = entries[0]!;
            switch (i) {
                case 0: entries.RemoveAt(7); break;
                case 1: entries[1] = entries[0]!.DeepClone(); entries[0] = null; break;
                case 2: entries[1] = entries[0]!.DeepClone(); break;
                case 3: first["interpretation"]!["object"]!["scope"]!["catalog"] = "1"; break;
                case 4: next.AsObject().Remove("definition"); break;
                case 5: next["after"] = "1"; break;
                case 6: next["position"]!["next_lsn"] = "1"; break;
                case 7: first["namespace"] = 2; break;
                case 8: first["interpretation"]!["object"]!["object"] = ulong.MaxValue; break;
            }
            Reject<TransitException>(() => { Invoke(typeof(C),"ValidateResponse",Obj(("catalog",Obj(("tables",bad))))); Decode("ParseTables",bad,Connection(),17ul,1ul,null); });
        }
        Reject<TransitException>(() => Decode("ParseTables",Page(),Connection(),17ul,1ul,page.Next));
        var reference = C.Reference.Restore(Reference().ToJsonString()); Check(((C.Observation)Decode("ParseObservation",Observation(),reference)!).Commit!.Position.NextLsn == ulong.MaxValue);
        var wrong = Observation(); wrong["rows"]!["committed"]!["binding"]!["identity"]!["operation"] = "11"; Reject<TransitException>(() => Decode("ParseObservation",wrong,reference));
        var acquisition = C.SnapshotAcquisition.Restore(Obj(("owner",Obj(("definition",C.ContractDefinition),("connection",ConnectionWire()),("object",ObjectIdentity()),("operation",ulong.MaxValue.ToString()))),("expected",Position())).ToJsonString());
        Check(acquisition.Owner.Operation == ulong.MaxValue);
        var snapshot = C.Snapshot.Restore(Obj(("owner",Wire(acquisition.Owner)),("content",Obj(("bytes","500"),("sha256",new string('4',64))))).ToJsonString());
        var metadata = Obj(("snapshot",Wire(snapshot)),("interpretation",Stored()),("accepted",Position()),("changed_lsn","3"),("row_count","9"),("schema",Wire(Schema())),("authority",Obj(("database",31),("schema",32),("table",33))));
        Invoke(typeof(C),"ValidateResponse",Obj(("retention",Obj(("metadata",metadata)))));
        Check(((C.SnapshotMetadata)Decode("ParseSnapshotMetadata",metadata,snapshot)!).RowCount == 9);
        metadata["snapshot"]!["content"]!["sha256"] = new string('5',64); Reject<TransitException>(() => Decode("ParseSnapshotMetadata",metadata,snapshot));
        var loaded = (C.Intent)Decode("ParseSummary",Summary(),C.SavedIntent.Restore(Saved().ToJsonString()),Connection(),17ul,new C.Identity(10))!;
        Check(loaded.Identity.Operation == 10);
    }
    internal static async Task Run(string root) {
        Values();
        // Block an actual native HTTP read. Cancelling the wait cannot disown it.
        string seed = Path.Combine(root,"seed"); File.WriteAllText(seed,new string('1',64));
        using TcpListener listener = new(IPAddress.Loopback,0); listener.Start();
        var endpoint = new Uri($"http://127.0.0.1:{((IPEndPoint)listener.LocalEndpoint).Port}");
        var client = await C.Client.OpenAsync(new ClientConfig(endpoint,Profile.NativeV1,10000),new Credential(46,17,seed),Connection());
        var worker = typeof(C.Client).GetField("worker",BindingFlags.NonPublic|BindingFlags.Instance)!.GetValue(client)!;
        var thread = (Thread)worker.GetType().GetField("thread",BindingFlags.NonPublic|BindingFlags.Instance)!.GetValue(worker)!;
        using var cancelled = new CancellationTokenSource(); cancelled.Cancel();
        try { await client.DescribeAsync(cancelled.Token); throw new Exception("Precancelled work admitted"); } catch (OperationCanceledException) { }
        Check(!listener.Pending());
        using var cancellation = new CancellationTokenSource(); var pending = client.DescribeAsync(cancellation.Token);
        using var peer = await listener.AcceptTcpClientAsync().WaitAsync(TimeSpan.FromSeconds(5));
        byte[] input = new byte[1]; Check(await peer.GetStream().ReadAsync(input).AsTask().WaitAsync(TimeSpan.FromSeconds(5)) == 1);
        Task? closing = null;
        try {
            cancellation.Cancel(); try { await pending; throw new Exception("Cancellation did not release wait"); } catch (OperationCanceledException) { }
            await Expect(ErrorKind.Busy,() => client.CapabilitiesAsync()); closing = client.DisposeAsync().AsTask();
            try { await closing.WaitAsync(TimeSpan.FromMilliseconds(100)); throw new Exception("Close abandoned native work"); } catch (TimeoutException) { }
            Check(thread.IsAlive);
        } finally { peer.Dispose(); await (closing ?? client.DisposeAsync().AsTask()).WaitAsync(TimeSpan.FromSeconds(15)); }
        Check(!thread.IsAlive); await Expect(ErrorKind.Closed,() => client.CapabilitiesAsync()); File.Delete(seed);
        Console.WriteLine(".NET direct catalog: owned logical values, complete bindings, strict metadata, retained snapshots and native cancellation/join passed.");
    }
}
