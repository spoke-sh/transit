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
        try { action(); } catch (E error) { return error; }
        throw new Exception("Expected catalog failure");
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
        try { return JsonNode.Parse(((JsonObject)method.Invoke(value,null)!).ToJsonString())!.AsObject(); }
        catch (TargetInvocationException error) { ExceptionDispatchInfo.Capture(error.InnerException!).Throw(); throw; }
    }
    static async Task Expect(ErrorKind kind, Func<Task> action) {
        try { await action(); } catch (TransitException error) { Check(error.Kind == kind); return; }
        throw new Exception("Expected catalog task failure");
    }
    static JsonObject Metadata() { var value=JsonNode.Parse("""
        {"namespace":1,"scope":{"realm":46,"resource":7,"catalog":"18446744073709551615"},
         "object":"18446744073709551615","revision":"18446744073709551615","name":"items",
         "schema_fingerprint":"abababababababababababababababababababababababababababababababab",
         "principal":17,"operation":"18446744073709551615","admitted_input":9}
        """)!.AsObject(); value["commitment"]=Wire(new C.MetadataCommitment(200,new Bytes(new byte[32])));return value; }
    static C.Schema Schema() => new(ulong.MaxValue,1,2,[new C.Column(1,"id",new L.Scalar(L.ScalarKind.Int128))]);
    static JsonObject Entry() => Program.Obj(("metadata",Metadata()),("head",JsonNode.Parse("{\"revision\":\"1\",\"rows\":\"0\",\"pending\":\"0\"}")));
    static JsonObject Definition() { var value = Entry(); value.Add("schema",Wire(Schema())); value.Add("authorization",30); return JsonNode.Parse(value.ToJsonString())!.AsObject(); }
    static JsonObject MetadataPage() {
        JsonArray entries = new(Entry()); while (entries.Count < 8) entries.Add((JsonNode?)null);
        return JsonNode.Parse(Program.Obj(("resource_revision",9),("entries",entries),("next",Program.Obj(("definition",C.ContractDefinition),("scope",Metadata()["scope"]!.DeepClone()),("resource_revision",9),("after_object",ulong.MaxValue.ToString(System.Globalization.CultureInfo.InvariantCulture))))).ToJsonString())!.AsObject();
    }
    static void MetadataValues(C.Scope scope) {
        var wire = Definition(); var original = (C.Definition)Decode("Resolved",wire,scope,1ul,"items")!;
        Check(original.Metadata.Commitment==new C.MetadataCommitment(200,new Bytes(new byte[32])));
        Check(original.Metadata.ObjectId == ulong.MaxValue && original.Metadata.Revision == ulong.MaxValue && original.Schema == Schema());
        wire["metadata"]!["name"] = "changed"; wire["schema"]!["columns"]![0]!["name"] = "changed";
        Check(original.Metadata.Name == "items" && original.Schema.Columns[0].Name == "id");
        Check(Decode("Resolved",null,scope,1ul,"missing") is null);
        var historical = Program.Obj(("metadata",Metadata()),("schema",Wire(Schema())));
        Check(((C.HistoricalDefinition)Decode("Historical",historical,scope,ulong.MaxValue,ulong.MaxValue)!).Schema == original.Schema);
        foreach (Action action in new Action[] {
            () => Decode("Resolved",Definition(),scope,1ul,"wrong"), () => Decode("Historical",historical,scope,1ul,ulong.MaxValue),
            () => Decode("Historical",historical,scope,ulong.MaxValue,1ul), () => Decode("Resolved",Definition(),new C.Scope(scope.Resource,1),1ul,"items") })
            Check(Reject<TransitException>(action).Kind == ErrorKind.IncompatibleNative);
        var source = MetadataPage(); var page = (C.Page)Decode("ParsePage",source,scope,null)!; source["entries"]![0] = null;
        Check(page.Entries.Count == 1 && page.Entries[0].Metadata == original.Metadata);
        Check(page.Entries is not IList<C.Entry>);
        List<C.Entry> input = [page.Entries[0]]; C.Page copy = new(9,input,page.Next); input.Clear(); Check(copy == page && copy.GetHashCode() == page.GetHashCode());
        for (int index = 0; index < 15; index++) {
            var malformed = MetadataPage(); var entries = malformed["entries"]!.AsArray(); var next = malformed["next"]!; var first = entries[0]!["metadata"]!;
            switch (index) {
                case 0: entries.RemoveAt(7); break;
                case 1: entries[1] = entries[0]!.DeepClone(); entries[0] = null; break;
                case 2: entries[1] = entries[0]!.DeepClone(); break;
                case 3: first["scope"]!["catalog"] = "1"; break;
                case 4: next.AsObject().Remove("definition"); break;
                case 5: next["definition"] = new string('0',64); break;
                case 6: next["after_object"] = "1"; break;
                case 7: next["resource_revision"] = 10; break;
                case 8: first["object"] = ulong.MaxValue; break;
                case 9: first["revision"] = "01"; break;
                case 10: malformed["extra"] = true; break;
                case 11: first.AsObject().Remove("commitment"); break;
                case 12: first["commitment"]!["format"]=0; break;
                case 13: first["commitment"]!["length"]=445; break;
                case 14: first["commitment"]!["digest"]![0]=256; break;
            }
            Check(Reject<TransitException>(() => Decode("ParsePage",malformed,scope,null)).Kind == ErrorKind.IncompatibleNative);
        }
        Check(Reject<TransitException>(() => Decode("ParsePage",MetadataPage(),scope,page.Next)).Kind == ErrorKind.IncompatibleNative);
        var empty = MetadataPage(); empty["entries"]![0] = null; empty["next"] = null;
        Check(((C.Page)Decode("ParsePage",empty,scope,page.Next)!).Entries.Count == 0);
        empty["next"] = Wire(new C.Cursor(C.ContractDefinition,scope,9,9));
        Check(((C.Page)Decode("ParsePage",empty,scope,new C.Cursor(C.ContractDefinition,scope,9,8))!).Next!.AfterObject == 9);
    }
    static void AuthorityValues(C.Scope scope) {
        C.AuthorityProfile authority = new(10, 11, 12, 20, 1, 21);
        Reject<ArgumentException>(() => new C.AuthorityProfile(10, 10, 12, 20, 1, 21));
        Reject<ArgumentException>(() => new C.AuthorityProfile(10, 11, 12, 20, 1, 20));
        C.Connection connection = new(new ProcessRef(46, 3), scope, 7);
        C.Configuration configuration = new(scope, connection.Owner, 0, new C.TableLimits(4096, 32768, 8), authority, "ledger");
        var subject = Program.Obj(("principal", 17), ("login_role", 8), ("role", 7), ("credential_epoch", 1), ("audience", 3), ("context", new JsonArray(Enumerable.Range(0, 32).Select(_ => (JsonNode?)JsonValue.Create(1)).ToArray())));
        var value = Program.Obj(("configuration", Wire(configuration)), ("subject", subject), ("authorization_revision", 2), ("resource_revision", 3));
        var parsed = (C.Description)Decode("ParseDescription", JsonNode.Parse(value.ToJsonString()), connection, 17ul)!;
        Check(parsed.Subject.Role == 7 && parsed.Configuration.Authority == authority && parsed.AuthorizationRevision == 2);
        subject["context"]![0] = 2;
        Check(parsed.Subject.Context.Copy()[0] == 1);
        foreach (var (field, invalid) in new[] { ("principal", 18), ("role", 8), ("audience", 4), ("credential_epoch", 0) }) {
            var bad = value.DeepClone(); bad["subject"]![field] = invalid;
            Check(Reject<TransitException>(() => Decode("ParseDescription", bad, connection, 17ul)).Kind == ErrorKind.IncompatibleNative);
        }
        Check(Reject<TransitException>(() => Decode("Resolved", Definition(), scope, 2ul, "items")).Kind == ErrorKind.IncompatibleNative);
    }
    internal static async Task Run(string root) {
        L.Cell large = new L.Present(new L.Binary(new L.BinaryData(new byte[1024 * 1024])));
        L.Cell laterInvalid = new L.Present(new L.Sequence(L.SequenceKind.List, [large, large]));
        C.Schema oversizedSchema = new(1, 1, 3, [new C.Column(1, "data", new L.Scalar(L.ScalarKind.Binary), defaultValue: large), new C.Column(2, "later", new L.Scalar(L.ScalarKind.Binary), defaultValue: laterInvalid)]);
        Check(Reject<ArgumentException>(() => Wire(oversizedSchema)).Message == "Table wire budget exceeded");
        List<IReadOnlyList<C.Assignment>> oversizedRows = Enumerable.Repeat<IReadOnlyList<C.Assignment>>([new C.Assignment(1, large)], 9).ToList();
        oversizedRows.Add([new C.Assignment(1, laterInvalid)]);
        Check(Reject<ArgumentException>(() => Wire(new C.Insert(oversizedRows))).Message == "Table wire budget exceeded");
        C.Scope scope = new(new ResourceRef(46,7),ulong.MaxValue); MetadataValues(scope); AuthorityValues(scope);
        Reject<ArgumentException>(() => new C.Scope(scope.Resource,0)); Reject<ArgumentException>(() => new C.Connection(new ProcessRef(47,3),scope));
        foreach (byte[] bytes in new[] { Array.Empty<byte>(),new byte[8193],new byte[]{255} }) Reject<ArgumentException>(() => new C.Prepared(new Bytes(bytes)));
        byte[] original = [1,2]; C.Prepared prepared = new(new Bytes(original)); C.SavedIntent saved = new(C.ContractDefinition,original);
        original[0] = 0; prepared.Bytes.Copy()[0] = 0; saved.Copy()[0] = 0; Check(prepared.Bytes.Copy()[0] == 1 && saved.Copy()[0] == 1);
        Reject<ArgumentException>(() => new C.SavedIntent(new string('0',64),[1]));
        foreach (string json in new[] { "null","{}","{\"receipt\":{\"position\":0}}","{\"receipt\":{\"position\":\"1\"}}","{\"receipt\":{\"position\":1.5}}","{\"receipt\":{\"position\":1,\"extra\":true}}","{\"receipt\":{\"position\":1},\"extra\":true}" })
            Check(Reject<TransitException>(() => Decode("Admission",JsonNode.Parse(json))).Kind == ErrorKind.UnknownOutcome);
        Check(((AdmissionReceipt)Decode("Admission",JsonNode.Parse("{\"receipt\":{\"position\":7}}"))!).Position == 7);
        var diagnostic = JsonNode.Parse(File.ReadAllText("../diagnostic.json"))!.AsObject();
        var result = JsonNode.Parse("""
            {"kind":"insert","operation":"18446744073709551615","object":"18446744073709551615","actual_object":"18446744073709551615",
             "phase":"applied","terminal":true,"counts":{"matched":"1","changed":"1"},"admitted_input":7,"completed_input":8}
            """)!.AsObject(); result.Add("diagnostic",diagnostic);
        var retained = (C.Outcome)Decode("ParseOutcome",result)!; diagnostic["message"] = ""; retained.Diagnostic.Copy()["message"] = "";
        Check(retained.Diagnostic.Copy()["message"]!.GetValue<string>().Length > 0);
        foreach (string field in new[] { "counts","terminal","phase","object","diagnostic" }) { var bad = result.DeepClone(); bad[field] = null; Reject<TransitException>(() => Decode("ParseOutcome",bad)); }
        var connection = new C.Connection(new ProcessRef(46,3),scope); C.Identity identity = new(10,100);
        var summary = Program.Obj(("reference",Wire(new C.Reference(C.ContractDefinition,new Bytes(new byte[32])))),("scope",Metadata()["scope"]!.DeepClone()),("owner",3),("principal",17),("operation","10"),("namespace","100"),("object","1"),("kind","insert"));
        var compiled = JsonNode.Parse(Program.Obj(("intent",summary),("saved",Program.Obj(("definition",C.ContractDefinition),("bytes",new string('a',600000))))).ToJsonString())!;
        Check(((C.Compiled)Decode("ParseCompiled",compiled,connection,17ul,identity,C.Kind.Insert,1ul)!).Saved.Copy().Length == 300000);
        foreach (string field in new[] { "owner","principal","operation","namespace","object","kind" }) {
            var bad = compiled.DeepClone(); if (field is "owner" or "principal") bad["intent"]![field] = 18; else bad["intent"]![field] = field == "kind" ? "update" : "11";
            Reject<TransitException>(() => Decode("ParseCompiled",bad,connection,17ul,identity,C.Kind.Insert,1ul));
        }
        L.Cell deep = new L.Null(); for (int i = 0; i < 15; i++) deep = new L.Present(new L.MapValue([new L.MapEntry(new L.Utf8("k"),deep)]));
        JsonNode wrapped = L.CellWire(deep); for (int i = 0; i < 5; i++) wrapped = new JsonObject { ["wrapper"] = wrapped };
        byte[] encoded = System.Text.Encoding.UTF8.GetBytes(wrapped.ToJsonString(new JsonSerializerOptions { MaxDepth = 96 }));
        var rawValues = typeof(Transit.Client.Client).Assembly.GetType("Transit.Client.Internal.Value")!;
        Check(Invoke(rawValues,"Parse",encoded,96) is JsonObject); Reject<TransitException>(() => Invoke(rawValues,"Parse",encoded,64));

        // Block an actual native HTTP read. Cancellation releases only the wait;
        // the public client remains busy, and disposal must join its ABI worker.
        string seed = Path.Combine(root, "seed"); File.WriteAllText(seed, new string('1', 64));
        using TcpListener listener = new(IPAddress.Loopback, 0); listener.Start();
        var endpoint = new Uri($"http://127.0.0.1:{((IPEndPoint)listener.LocalEndpoint).Port}");
        var client = await C.Client.OpenAsync(new ClientConfig(endpoint, Profile.NativeV1, 10000), new Credential(46, 17, seed), new C.Connection(new ProcessRef(46, 3), scope));
        var worker = typeof(C.Client).GetField("worker", BindingFlags.NonPublic | BindingFlags.Instance)!.GetValue(client)!;
        var thread = (Thread)worker.GetType().GetField("thread", BindingFlags.NonPublic | BindingFlags.Instance)!.GetValue(worker)!;
        using var cancelled = new CancellationTokenSource(); cancelled.Cancel();
        try { await client.DescribeAsync(cancelled.Token); throw new Exception("Precancelled work admitted"); } catch (OperationCanceledException) { }
        Check(!listener.Pending());
        using var cancellation = new CancellationTokenSource(); var pending = client.DescribeAsync(cancellation.Token);
        using var peer = await listener.AcceptTcpClientAsync().WaitAsync(TimeSpan.FromSeconds(5));
        byte[] input = new byte[1]; Check(await peer.GetStream().ReadAsync(input).AsTask().WaitAsync(TimeSpan.FromSeconds(5)) == 1);
        Task? closing = null;
        try {
            cancellation.Cancel(); try { await pending; throw new Exception("Cancellation did not release wait"); } catch (OperationCanceledException) { }
            await Expect(ErrorKind.Busy, () => client.CapabilitiesAsync());
            closing = client.DisposeAsync().AsTask();
            try { await closing.WaitAsync(TimeSpan.FromMilliseconds(100)); throw new Exception("Close abandoned native work"); } catch (TimeoutException) { }
            Check(thread.IsAlive && prepared.Bytes.Copy()[0] == 1);
        } finally { peer.Dispose(); await (closing ?? client.DisposeAsync().AsTask()).WaitAsync(TimeSpan.FromSeconds(15)); }
        Check(!thread.IsAlive); await Expect(ErrorKind.Closed, () => client.CapabilitiesAsync());
        File.Delete(seed);
        Console.WriteLine(".NET general Table values, schema history, recursive budgets, uncertain receipts and native read cancellation/join passed.");
    }
}
