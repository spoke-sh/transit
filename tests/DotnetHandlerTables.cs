using System.Reflection;
using System.Runtime.ExceptionServices;
using System.Text.Json;
using System.Text.Json.Nodes;
using Transit.Client;
using Transit.Station.Sdk;
using C = Transit.Station.Sdk.Catalog;
using L = Transit.Station.Sdk.Logical;

internal static class HandlerTables
{
    static int rejected;
    static readonly ResourceRef Resource = new(46, 7);
    static readonly JsonSerializerOptions Json = new() { MaxDepth = 96 };
    static string Encode(JsonNode value) => value.ToJsonString(Json);
    static JsonObject Parse(string value) => JsonNode.Parse(value)!.AsObject();
    static void Check(bool value) { if (!value) throw new Exception("Handler Table assertion failed"); }
    static void Reject(Action action) {
        try { action(); } catch (Exception e) when (e is TransitException or ArgumentException or JsonException or InvalidOperationException or OverflowException or FormatException) { rejected++; return; }
        throw new Exception("Expected handler Table rejection");
    }
    static object? Invoke(Type type, object? instance, string name, params object?[] args) {
        try { return type.GetMethod(name, BindingFlags.NonPublic | (instance is null ? BindingFlags.Static : BindingFlags.Instance))!.Invoke(instance, args); }
        catch (TargetInvocationException e) { ExceptionDispatchInfo.Capture(e.InnerException!).Throw(); throw; }
    }
    static JsonObject Wire(object value) => (JsonObject)Invoke(value.GetType(), value, "Wire")!;
    static L.Cell Signed(long value) => new L.Present(new L.Signed(value));
    static C.Schema Schema() => new(ulong.MaxValue, 1, 5, [
        new(1, "id", new L.Scalar(L.ScalarKind.Int64), false),
        new(2, "amount", new L.Decimal(20, 2)), new(3, "data", new L.Scalar(L.ScalarKind.Binary)),
        new(4, "tags", new L.ListType(new(new L.Scalar(L.ScalarKind.Utf8), true)))], [1]);
    static JsonObject Reference() => new() { ["definition"] = C.ContractDefinition, ["realm"] = 46, ["resource"] = 7, ["object"] = ulong.MaxValue.ToString(), ["principal"] = 17, ["operation"] = ulong.MaxValue.ToString(), ["digest"] = new string('a', 64) };
    static JsonObject Status() => Parse(Encode(new JsonObject { ["reference"] = Reference(), ["state"] = "applied", ["route"] = "statement", ["admitted_input"] = 9, ["completed_input"] = 11,
        ["counts"] = new JsonObject { ["matched"] = "1", ["changed"] = "1" }, ["rejection"] = "none", ["witness"] = null }));
    static TableMutationStatus DecodeStatus(JsonNode value) => (TableMutationStatus)Invoke(typeof(Table).Assembly.GetType("Transit.Station.Sdk.TableValues")!, null, "Status", Parse(Encode(value)))!;
    public static void Run() {
        byte[] bytes = [1, 2, 3]; List<L.Cell> tags = [new L.Present(new L.Utf8("red")), new L.Null()];
        List<C.Assignment> assignments = [new(1, Signed(7)), new(2, new L.Present(new L.DecimalValue(12345))),
            new(3, new L.Present(new L.Binary(new L.BinaryData(bytes)))), new(4, new L.Present(new L.Sequence(L.SequenceKind.List, tags)))];
        List<IReadOnlyList<C.Assignment>> rows = [assignments];
        var intent = TableMutation.Prepare(Resource, 17, ulong.MaxValue, Schema(), new C.Insert(rows)); string saved = intent.Save();
        bytes[0] = 9; tags.Clear(); assignments.Clear(); rows.Clear();
        Check(intent.Save() == saved && intent.Schema == Schema() && intent.Operation == ulong.MaxValue);
        Check(TableMutation.Load(saved).Save() == saved);
        L.Descriptor nestedType = new L.Scalar(L.ScalarKind.Int64); L.Cell nested = Signed(1);
        for (int i = 0; i < 15; i++) {
            nestedType = new L.MapType(new L.Scalar(L.ScalarKind.Int64), new L.Element(nestedType, false));
            nested = new L.Present(new L.MapValue([new L.MapEntry(new L.Signed(0), nested)]));
        }
        var nestedIntent = TableMutation.Prepare(Resource, 0, 1, new C.Schema(1, 1, 2, [new(1, "deep", nestedType)]), new C.Insert([[new(1, nested)]]));
        Check(TableMutation.Load(nestedIntent.Save()).Schema.Columns[0].Type == nestedType);
        var envelope = new JsonObject { ["table"] = new JsonObject { ["mutate"] = JsonNode.Parse(nestedIntent.Save(), documentOptions: new JsonDocumentOptions { MaxDepth = 96 }) } };
        byte[] encoded = (byte[])Invoke(typeof(Table).Assembly.GetType("Transit.Station.Sdk.Internal.Bridge")!, null, "EncodeAction", envelope)!;
        using (JsonDocument document = JsonDocument.Parse(encoded, new JsonDocumentOptions { MaxDepth = 96 })) Check(document.RootElement.GetProperty("table").ValueKind == JsonValueKind.Object);
        Reject(() => JsonDocument.Parse(encoded));
        var decoded = (C.Insert)Invoke(typeof(C), null, "ParseMutation", Parse(saved)["mutation"])!;
        Check(((L.Binary)((L.Present)((C.CellValue)decoded.Rows[0][2].Value).Cell).Value).Bytes.Copy()[0] == 1);
        Check(decoded.Rows is not IList<IReadOnlyList<C.Assignment>>);
        byte[] idBytes = new byte[20]; idBytes[0] = 3; var identity = new RowIdentity(idBytes); idBytes[0] = 0; identity.Bytes.Copy()[0] = 0;
        List<L.Cell> cells = [Signed(7), new L.Null()]; var row = new TableRow(identity, cells); cells.Clear();
        Check(row.Cells.Count == 2 && row.Identity.Bytes.Copy()[0] == 3 && row.Cells is not IList<L.Cell>);
        Reject(() => new RowIdentity(new byte[19])); Reject(() => new TablePage(Enumerable.Repeat(row, 9).ToArray(), null));
        for (int i = 0; i < 11; i++) {
            var bad = Parse(saved); var schema = bad["schema"]!.AsObject();
            switch (i) {
                case 0: schema.Remove("definition"); break;
                case 1: schema["definition"] = new string('0', 64); break;
                case 2: bad["operation"] = "0"; break;
                case 3: bad["operation"] = "01"; break;
                case 4: bad["operation"] = "18446744073709551616"; break;
                case 5: bad["realm"] = 0; break;
                case 6: bad["unknown"] = true; break;
                case 7: schema["object"] = "0"; break;
                case 8: bad["mutation"]!["action"]!["insert"]![0]![0]!["column"] = "0"; break;
                case 9: bad["mutation"]!["action"]!["insert"]![0]![0]!["value"]!["cell"]!["value"]!["atom"]!["signed"] = "01"; break;
                case 10: bad["mutation"]!["action"]!["insert"]![0]![0]!["value"]!["cell"]!["value"]!["atom"]!["signed"] = "170141183460469231731687303715884105728"; break;
            }
            Reject(() => TableMutation.Load(Encode(bad)));
        }
        Reject(() => TableMutation.Load(" " + saved));
        Reject(() => TableMutation.Load(new string('[', 97) + "0" + new string(']', 97)));
        Reject(() => TableMutation.Load(saved.Replace("\"realm\":46", "\"realm\":46,\"realm\":46")));
        var cols = Enumerable.Range(1, 128).Select(i => new C.Column((ulong)i, "c" + i, new L.Scalar(L.ScalarKind.Int64))).ToArray();
        var wide = Enumerable.Range(1, 128).Select(i => new C.Assignment((ulong)i, Signed(i))).ToArray();
        TableMutation.Prepare(Resource, 0, 1, new C.Schema(1, 1, 129, cols), new C.Insert([wide]));
        TableMutation.Prepare(Resource, 0, 1, Schema(), new C.Insert(Enumerable.Repeat<IReadOnlyList<C.Assignment>>([new(1, Signed(1))], 1024).ToArray()));
        Reject(() => new C.Insert(Enumerable.Repeat<IReadOnlyList<C.Assignment>>([], 1025).ToArray()));
        Reject(() => new C.Insert([Enumerable.Repeat(new C.Assignment(1, Signed(1)), 129).ToArray()]));
        L.Cell oversized = new L.Present(new L.Binary(new L.BinaryData(new byte[140000])));
        Reject(() => TableMutation.Prepare(Resource, 0, 1, Schema(), new C.Insert([[new C.Assignment(3, oversized)]])));
        C.Update update = new([new(2, new C.Default())], [new C.Comparison(1, C.CompareOperator.Gt, new L.Signed(0)), new C.StatePredicate(2, C.CellState.Null), new C.BooleanPredicate(C.BooleanOperator.Disjunction)]);
        Check((C.Mutation)Invoke(typeof(C), null, "ParseMutation", Wire(update))! == update);
        Check(TableMutation.Load(TableMutation.Prepare(Resource, 0, 1, Schema(), update).Save()).Schema == Schema());
        Check((C.Mutation)Invoke(typeof(C), null, "ParseMutation", Wire(new C.Delete()))! == new C.Delete());
        var reference = TableMutationReference.Load(Encode(Reference())); Check(reference.Save() == Encode(Reference()));
        for (int i = 0; i < 4; i++) {
            var bad = Reference();
            switch (i) { case 0: bad.Remove("definition"); break; case 1: bad["digest"] = "ab"; break; case 2: bad["digest"] = new string('A', 64); break; case 3: bad["object"] = "0"; break; }
            Reject(() => TableMutationReference.Load(Encode(bad)));
        }
        var complete = DecodeStatus(Status()); Check(complete.Counts == new C.Counts(1, 1) && complete.CompletedInput == 11);
        for (int i = 0; i < 5; i++) {
            var bad = Status();
            switch (i) { case 0: bad["counts"] = null; break; case 1: bad["state"] = "building"; break; case 2: bad["completed_input"] = 8; break; case 3: bad["rejection"] = "row_exists"; break; case 4: bad["counts"]!["changed"] = "2"; break; }
            Reject(() => DecodeStatus(bad));
        }
        var building = Status(); building["state"] = "building"; building["counts"] = null; building["completed_input"] = null; Check(DecodeStatus(building).Counts is null);
        Turn MakeTurn(ulong resource) => (Turn)Activator.CreateInstance(typeof(Turn), BindingFlags.Instance | BindingFlags.NonPublic, null,
            [null, Parse($"{{\"scope\":1,\"resource\":{resource}}}"), new ProcessRef(46, 3), new StopToken()], null)!;
        var foreign = MakeTurn(8); Reject(() => intent.Step(foreign)); Reject(() => reference.Status(foreign));
        var expired = MakeTurn(7); Invoke(typeof(Turn), expired, "EndScope"); Reject(() => intent.Step(expired)); Reject(() => reference.Cancel(expired));
        var basis = new TableBasis(Resource, 4, ulong.MaxValue, new Bytes(new byte[32]));
        var table = (Table)Activator.CreateInstance(typeof(Table), BindingFlags.Instance | BindingFlags.NonPublic, null, [null, Schema(), null, basis], null)!;
        var definition = new JsonObject { ["schema"] = Wire(Schema()), ["basis"] = new JsonObject { ["resource"] = 7, ["revision"] = 4, ["object"] = ulong.MaxValue.ToString(), ["head"] = new string('0', 64) } };
        Invoke(typeof(Table), table, "CheckBasis", Parse(Encode(definition))); definition["basis"]!["head"] = new string('a', 64);
        Reject(() => Invoke(typeof(Table), table, "CheckBasis", Parse(Encode(definition))));
        List<byte> projection = [3, 1, 127]; List<string?> names = ["tags", null, "last"];
        var query = new QueryPlan(new UnifiedQuery.Plan(projection, new UnifiedQuery.Compare(1, QueryComparison.Gt, new L.DecimalValue(123)), limit: ulong.MaxValue, outputNames: names));
        var original = Wire(query); projection.Clear(); names.Clear(); Wire(query)["projection"] = new JsonArray();
        Check(JsonNode.DeepEquals(Wire(query), original)); Check(original["projection"]![2]!.GetValue<uint>() == 127);
        Check(original["limit"]!.GetValue<string>() == ulong.MaxValue.ToString());
        Console.WriteLine($".NET handler Tables: owned recursive values, exact saved identities, schema/row/byte bounds, captured basis, scoped access, applied counts and frozen general query plans passed ({rejected} rejections).");
    }
}
