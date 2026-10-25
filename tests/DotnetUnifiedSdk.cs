using System.Buffers.Binary;
using System.Text;
using System.Text.Json.Nodes;
using Transit.Client;
using Transit.Station.Sdk;
using Q = Transit.Station.Sdk.UnifiedQuery;
using L = Transit.Station.Sdk.Logical;
using C = Transit.Station.Sdk.Catalog;

static class Program
{
    static void Check(bool v) { if(!v) throw new Exception("Unified .NET assertion failed"); }
    static string Text(JsonNode v,string key) => v[key]!.GetValue<string>();
    static ulong Number(JsonNode v,string key) => v[key]!.GetValue<ulong>();
    static string Hex(Bytes b) => Convert.ToHexString(b.Copy()).ToLowerInvariant();
    static Bytes Read(JsonNode config,string key) => new(File.ReadAllBytes(Text(config,key)));
    static JsonObject Obj(params (string Key,object? Value)[] values) {
        JsonObject v=new(); foreach(var (key,value) in values) v[key]=value switch { null=>null,JsonNode n=>n,string s=>JsonValue.Create(s),bool b=>JsonValue.Create(b),ulong n=>JsonValue.Create(n),uint n=>JsonValue.Create(n),int n=>JsonValue.Create(n),_=>throw new Exception("Invalid fixture JSON") }; return v;
    }
    static async Task<Document.Reference> Reference(ResourceRef resource,ulong document,ulong epoch,ulong revision) {
        byte[] bytes=new byte[40]; Encoding.ASCII.GetBytes("SDR1").CopyTo(bytes,0); BinaryPrimitives.WriteUInt64LittleEndian(bytes.AsSpan(4),resource.Resource);
        BinaryPrimitives.WriteUInt64LittleEndian(bytes.AsSpan(12),document); BinaryPrimitives.WriteUInt64LittleEndian(bytes.AsSpan(20),epoch); BinaryPrimitives.WriteUInt32LittleEndian(bytes.AsSpan(28),1); BinaryPrimitives.WriteUInt64LittleEndian(bytes.AsSpan(32),revision);
        return await Document.Reference.DecodeAsync(resource.Realm,bytes);
    }
    static Q.TableSource TableSource(IReadOnlyList<C.Column> columns) {
        byte[] hash=Enumerable.Repeat((byte)1,32).ToArray();
        return new Q.TableSource(new C.Scope(new ResourceRef(1,7),9),3,1,1,
            new Q.TableInterpretation(1,new Bytes(hash),200,new Bytes(Enumerable.Repeat((byte)2,32).ToArray())),new C.Schema(9,1,(ulong)columns.Count+1,columns));
    }
    static async Task<Q.Source> Source(ResourceRef r,string kind,bool golden) {
        if(kind=="kv") return new Q.KvSource(r,new Bytes(Encoding.UTF8.GetBytes(golden?"data/":"k")),new(Q.DecoderType.Binary),new(golden?Q.DecoderType.UInt64:Q.DecoderType.Utf8));
        if(kind=="table") return TableSource([new C.Column(1,"id",new L.Scalar(L.ScalarKind.Int64),nullable:false),new C.Column(2,"label",new L.Scalar(L.ScalarKind.Utf8))]);
        if(golden) return new Q.DocumentSource(await Reference(r,ulong.MaxValue,3,42),[new(new("title",Q.DecoderType.Utf8),["title"]),new(new("body",Q.DecoderType.Utf8),["body"],mode:Q.ProjectionMode.Text)]);
        return new Q.DocumentSource(await Reference(r,17,1,13),[new(new("value",Q.DecoderType.Utf8),relative:true),new(new("counter",Q.DecoderType.UInt64),relative:true,mode:Q.ProjectionMode.ElementCounter),new(new("replica",Q.DecoderType.UInt64),relative:true,mode:Q.ProjectionMode.ElementReplica),new(new("optional",Q.DecoderType.Utf8),["optional"])],["items"]);
    }
    static Task<Q.Bundle> Bundle(Q.Source source,string kind,bool golden,bool named=false,bool compound=false) {
        byte column=(byte)(golden?1:kind=="document"?0:1);
        var comparison=new Q.Compare(column,QueryComparison.Ne,golden&&kind=="kv"?new L.Unsigned(ulong.MaxValue):new L.Utf8(new string('x',512)));
        Q.Predicate predicate=comparison;
        if(compound){
            Check(!golden);string ceiling="東京🙂/"+new string('x',kind=="document"?64:128)+(kind=="document"?"/10":"/39");
            predicate=new Q.PredicateProgram([Atom(comparison),Atom(new Q.Compare(column,QueryComparison.Ge,new L.Utf8(ceiling))),
                Atom(new Q.IsState(column,Q.State.Null)),new Q.PredicateOperation(Q.PredicateOperator.Disjunction),
                new Q.PredicateOperation(Q.PredicateOperator.Negate),new Q.PredicateOperation(Q.PredicateOperator.Conjunction)]);
        }
        return Q.Bundle.PrepareAsync(source,new(golden?[1,0]:kind=="document"?[0,1,2,3]:[1],predicate,limit:golden?ulong.MaxValue:null,
            outputNames:named?(golden?["Result",null]:kind=="document"?["Result",null,null,null]:["Result"]):null),new(1000,golden?500u:100u,1048576));
    }
    static void Scalar(L.Value scalar,int col) {
        bool valid=col switch { 0=>scalar is L.Signed s && s.Number==long.MinValue,1=>scalar is L.Unsigned u && u.Number==ulong.MaxValue,2=>scalar is L.Float64 f && BitConverter.DoubleToInt64Bits(f.Number)==long.MinValue,
            3=>scalar is L.BooleanValue { Boolean:false },4=>scalar is L.Utf8 { Text:"café é 東京🙂" },5=>scalar is L.Binary b && b.Bytes.Copy().SequenceEqual(new byte[]{0,255,128}),_=>false }; Check(valid);
    }
    static Q.PredicateAtomInstruction Atom(Q.PredicateAtom value) => new(value);
    static async Task BooleanCodecs(JsonNode config) {
        var fixtures=JsonNode.Parse(File.ReadAllText(Text(config,"boolean")))!.AsArray();
        L.Atom[] values=[new L.Signed(long.MinValue),new L.Unsigned(ulong.MaxValue),new L.Float64(-0.0),new L.BooleanValue(true),new L.Utf8("café é 🙂"),new L.Binary(new L.BinaryData(new byte[]{0,255,128})),new L.Utf8(new string('x',512))];
        for(int i=0;i<fixtures.Count;i++) {
            var fixture=fixtures[i]!;
            Q.Source source=new Q.KvSource(new(46,7),new Bytes([]),new(Enum.GetValues<Q.DecoderType>()[fixture["type"]!.GetValue<int>()-1]),new(Q.DecoderType.UInt64));
            List<Q.PredicateInstruction> instructions=[];
            if(i<7)instructions.AddRange([Atom(new Q.Compare(0,QueryComparison.Eq,values[i])),new Q.PredicateOperation(Q.PredicateOperator.Negate),Atom(new Q.IsState(0,Q.State.Null)),new Q.PredicateOperation(Q.PredicateOperator.Disjunction)]);
            else if(Text(fixture,"name")=="all-and-not-null")instructions.AddRange([Atom(new Q.All()),Atom(new Q.IsState(0,Q.State.Null)),new Q.PredicateOperation(Q.PredicateOperator.Negate),new Q.PredicateOperation(Q.PredicateOperator.Conjunction)]);
            else { instructions.Add(Atom(new Q.All())); instructions.AddRange(Enumerable.Repeat<Q.PredicateInstruction>(new Q.PredicateOperation(Q.PredicateOperator.Negate),63)); }
            var program=new Q.PredicateProgram(instructions); instructions.Clear();
            var bundle=await Q.Bundle.PrepareAsync(source,new([0],program),new(1000,500,1048576));
            Check(Hex(bundle.Bytes)==Text(fixture,"wire_hex"));
        }
        Q.Source signedSource=new Q.KvSource(new(46,7),new Bytes([]),new(Q.DecoderType.Int64),new(Q.DecoderType.UInt64));
        List<Q.PredicateInstruction> oversized=[Atom(new Q.All())]; oversized.AddRange(Enumerable.Repeat<Q.PredicateInstruction>(new Q.PredicateOperation(Q.PredicateOperator.Negate),64));
        Q.PredicateInstruction[][] invalid=[[],[new Q.PredicateOperation(Q.PredicateOperator.Negate)],[Atom(new Q.All()),Atom(new Q.All())],oversized.ToArray(),
            [Atom(new Q.IsState(7,Q.State.Null))],[Atom(new Q.Compare(0,QueryComparison.Eq,new L.Utf8("wrong type")))]];
        foreach(var instructions in invalid) {
            bool rejected=false;
            try { await Q.Bundle.PrepareAsync(signedSource,new([0],new Q.PredicateProgram(instructions)),new(1,1,1024)); }
            catch(ArgumentException) { rejected=true; } catch(TransitException) { rejected=true; }
            Check(rejected);
        }
    }
    static async Task Codecs(JsonNode config) {
        var fixtures=JsonNode.Parse(File.ReadAllText(Text(config,"bundles")))!.AsArray();
        for(int i=0;i<3;i++) { string kind=new[]{"kv","table","document"}[i]; Check(Hex((await Bundle(await Source(new(46,7),kind,true),kind,true)).Bytes)==Text(fixtures[i]!,"wire_hex")); Check(Hex((await Bundle(await Source(new(46,7),kind,true),kind,true,true)).Bytes)==Text(fixtures[i]!,"named_wire_hex"));
            var counted=await Q.Bundle.PrepareAsync(await Source(new(46,7),kind,true),new([1],aggregate:QueryAggregate.CountValues,outputNames:["present"]),new(1000,500,1048576));
            Check(Hex(counted.Bytes)==Text(fixtures[i]!,"counted_wire_hex")); }
        await BooleanCodecs(config);
        Q.Column[] columns=Enum.GetValues<Q.DecoderType>().Select(type => new Q.Column(type.ToString().ToLowerInvariant(),new L.Scalar(Enum.Parse<L.ScalarKind>(type.ToString(),true)),true,true)).ToArray();
        byte[] input=Read(config,"arrow").Copy(); var rows=await Q.DecodeArrowAsync(columns,new Bytes(input),5); Array.Fill(input,(byte)0); Check(rows.Count==5);
        for(int i=0;i<6;i++) {
            Check(rows[0][i] is L.Missing && rows[1][i] is L.Null && rows[2][i] is L.SourceTypeError { Actual:L.Kind.Map }); Scalar(((L.Present)rows[3][i]).Value,i);
            var a=((L.Conflict)rows[4][i]).Alternatives; Check(a.Count==2 && a[0].Counter==ulong.MaxValue && a[0].Replica==1 && a[1].Counter==ulong.MaxValue && a[1].Replica==2 && a[1].Value is L.Null); Scalar(((L.Present)a[0].Value).Value,i);
        }
        Check((await Q.DecodeArrowAsync(columns,Read(config,"empty"),0)).Count==0);
        bool rejected=false; try { await Q.DecodeArrowAsync(columns,Read(config,"malformed"),5); }catch(TransitException) { rejected=true; } Check(rejected);
        Q.Source wide=TableSource(Enumerable.Range(0,128).Select(i=>new C.Column((ulong)i+1,$"列 {i}",new L.Scalar(L.ScalarKind.Uint128))).ToArray());
        var wideBundle=await Q.Bundle.PrepareAsync(wide,new Q.Plan(Enumerable.Range(0,128).Select(i=>(byte)i).ToArray(),new Q.Compare(127,QueryComparison.Eq,new L.Unsigned(UInt128.MaxValue))),new(1,1,65536));
        Check(wideBundle.Bytes.Length>1000);
        var datatype=new L.ListType(new L.Element(new L.Scalar(L.ScalarKind.Uint128),true));
        var nested=await Q.DecodeArrowAsync([new Q.Column("value",datatype)],Read(config,"nested"),1);
        Check(nested.Count==1 && nested[0].Count==1 && nested[0][0]==new L.Present(new L.Sequence(L.SequenceKind.List,[new L.Present(new L.Unsigned(UInt128.MaxValue)),new L.Null()])));
        Console.WriteLine(".NET installed unified codecs: three sources, nine Boolean bundles, six scalar types, 128 columns, nested uint128, five states, immutable values and malformed rejection passed");
    }
    static string Name(Enum value) => value.ToString() is "TypeError"?"type_error":value.ToString() is "CountValues"?"count_values":value.ToString().ToLowerInvariant();
    static JsonObject InspectedPredicate(Q.InspectedPredicate value) => value switch {
        Q.InspectedAll=>Obj(("all",Obj())),
        Q.InspectedState p=>Obj(("state",Obj(("column",p.Column),("value",Name(p.State))))),
        Q.InspectedComparison p=>Obj(("compare",Obj(("column",p.Column),("op",Name(p.Comparison)),("type",L.TypeWire(p.Type))))),
        Q.InspectedProgram p=>Obj(("program",new JsonArray(p.Instructions.Select(v=>(JsonNode?)(v switch {
            Q.InspectedAtomInstruction a=>Obj(("atom",InspectedPredicate(a.Atom))),
            Q.InspectedOperation op=>Obj((Name(op.Operator),Obj())),
            _=>throw new Exception("Unknown SQL instruction")
        })).ToArray()))),
        _=>throw new Exception("Unknown SQL inspection predicate")
    };
    static JsonObject Inspection(Q.Inspection value) {
        JsonArray Columns(IReadOnlyList<Q.Column> values) => new(values.Select(v=>(JsonNode?)Obj(("name",v.Name),("type",L.TypeWire(v.Type)),("nullable",v.Nullable),("optional",v.Optional))).ToArray());
        JsonArray Names(IEnumerable<string> values) => new(values.Select(v=>(JsonNode?)JsonValue.Create(v)).ToArray());
        JsonObject details;
        if(value.Details is Q.SourceDescription description) details=Obj(("description",Obj(("columns",Columns(description.Columns)))));
        else if(value.Details is Q.TableListing tables) details=Obj(("tables",Names(tables.Names)));
        else {
            var plan=(Q.Explanation)value.Details;
            JsonObject predicate=InspectedPredicate(plan.Predicate);
            details=Obj(("explanation",Obj(("operators",Names(plan.Operators.Select(v=>Name(v)))),("predicate",predicate),("projection",Names(plan.Projection)),
                ("limit",plan.Limit?.ToString()),("aggregate",Name(plan.Aggregate)),("columns",Columns(plan.Columns)),
                ("budgets",Obj(("pages",plan.Budgets.Pages.ToString()),("segments",plan.Budgets.Segments.ToString()),("result_bytes",plan.Budgets.ResultBytes.ToString()))))));
        }
        JsonArray Digest(Bytes bytes) => new(bytes.Copy().Select(v=>(JsonNode?)JsonValue.Create((int)v)).ToArray());
        return Obj(("inspection",Obj(("version",1),("scope","configured_source"),("name",value.Name),("resource",value.Resource.Resource),("source_kind",Name(value.SourceKind)),
            ("contract",Digest(value.SourceDigest)),("schema",Digest(value.SchemaDigest)),("resource_revision",value.ResourceRevision),("policy_revision",value.PolicyRevision.ToString()),("details",details))));
    }
    static async Task Serve(JsonNode config) {
        var c=config["connection"]!; ulong realm=Number(c,"realm"); ResourceRef resource=new(realm,Number(c,"resource"));
        Q.Connection connection=new(new(realm,Number(c,"source")),resource,new(realm,Number(c,"requester")),new(realm,Number(c,"requests")));
        string kind=Text(config,"kind"); Q.Tables? tables=null;
        if(kind=="table") {
            var t=config["tables"]!; var route=t["connection"]!; var scope=route["scope"]!;
            tables=new(Text(t,"url"),new C.Scope(new ResourceRef(realm,Number(scope,"resource")),ulong.Parse(Text(scope,"catalog"))),ulong.Parse(Text(route,"branch")),Number(route,"audience"));
        }
        Q.Page? saved=null;
        await using(var client=await Q.Client.OpenAsync(new(new Uri(Text(config,"url")),Profile.NativeV1,10000),new(realm,Number(c,"principal"),Text(config,"seed_file")),connection,tables)) {
            Q.Source source; Q.Capture? capture=null;
            if(kind=="table") {
                source=(await client.LookupTableAsync(1,"items")??throw new Exception("Missing direct Table")).Source;
                var spec=config["capture"]!; var expected=spec["expected"]!;
                capture=new(Number(spec,"executor"),ulong.Parse(Text(spec,"operation")),ulong.Parse(Text(expected,"partition")),ulong.Parse(Text(expected,"next_lsn")));
            } else source=await Source(resource,kind,false);
            Check((await client.AuthorizeBundleAsync(await Bundle(source,kind,false,true,config["compound"]!.GetValue<bool>()),capture)).Bytes.Copy().SequenceEqual(Read(config,"bundle").Copy()));
            var description=await client.DescribeAsync(source); Check(description.BundleBytes==25614 && description.BatchRows==8);
            // A cancelled wait cannot manufacture query state or dispose ownership.
            using var cancelled=new CancellationTokenSource(); cancelled.Cancel(); bool stopped=false;
            try { await client.StatusAsync(1,cancelled.Token); }catch(OperationCanceledException) { stopped=true; } Check(stopped);
            Console.WriteLine("{\"ready\":true}");
            while(Console.ReadLine() is {} line) {
                var action=JsonNode.Parse(line)!.AsObject(); if(action.ContainsKey("close"))break;
                try {
                    JsonObject result;
                    if(action["compile"] is {} compilation) {
                        var scope=compilation["scope"]!; var limits=scope["limits"]!;
                        var parameters=compilation["parameters"]?.AsArray().Select(L.AtomFromWire).ToArray();
                        var pending=client.CompileSqlAsync(source,Text(scope,"name"),Text(compilation,"sql"),new(ulong.Parse(Text(limits,"pages")),ulong.Parse(Text(limits,"segments")),ulong.Parse(Text(limits,"result_bytes"))),parameters);
                        if(parameters is not null)Array.Clear(parameters);
                        var compiled=await pending;
                        result=Obj(("compiled",Obj(("bundle",Hex(compiled.Bytes)))));
                    } else if(action["inspect"] is {} inspection) {
                        var scope=inspection["scope"]!; var limits=scope["limits"]!;
                        var value=await client.InspectSqlAsync(source,Text(scope,"name"),Text(inspection,"sql"),new(ulong.Parse(Text(limits,"pages")),ulong.Parse(Text(limits,"segments")),ulong.Parse(Text(limits,"result_bytes"))));
                        Check(value.Resource==source.Resource && Name(value.SourceKind)==kind); result=Inspection(value);
                    }
                    else if(action["next"] is {} next) { var p=await client.PrepareNextAsync(ulong.Parse(Text(next,"namespace")),new(new Bytes(Convert.FromHexString(Text(next,"bundle"))))); result=Obj(("prepared",p is null?null:Encoding.UTF8.GetString(p.Bytes.Copy()))); }
                    else if(action["submit"] is not null) {
                        Q.Prepared p=new(new Bytes(Encoding.UTF8.GetBytes(Text(action,"submit")))); byte[] original=p.Bytes.Copy();
                        try { result=Obj(("receipt",Obj(("position",(await client.SubmitAsync(p)).Position)))); }catch(TransitException) { Check(p.Bytes.Copy().SequenceEqual(original)); throw; }
                    }else if(action["observe"] is not null) { var v=await client.ObserveAsync(Number(action,"observe")); result=Obj(("observation",Obj((v.State.ToString().ToLowerInvariant(),v.Reason is null?Obj():Hex(v.Reason))))); }
                    else if(action["status"] is not null) { var v=await client.StatusAsync(ulong.Parse(Text(action,"status"))); result=Obj(("status",v is null?null:Obj(("phase",v.Phase.ToString().ToLowerInvariant()),("correlation",v.Correlation.ToString()),("diagnostic",v.Diagnostic?.DeepClone()),("failure",v.Failure is {} f ? Obj(("code",f.Code),("stage",f.Stage),("dimension",f.Dimension),("limit",f.Limit.ToString()),("observed",f.Observed.ToString())):null)))); }
                    else {
                        var args=action["page"]!; var page=await client.PageAsync(ulong.Parse(Text(args,"namespace")),args["cursor"] is null?null:new(Text(args,"cursor")));
                        Check(page.Manifest.Resource==source.Resource && page.Manifest.Kind.ToString().ToLowerInvariant()==kind); Check((await page.DecodeAsync()).Count==page.Rows); saved=page;
                        result=Obj(("page",Obj(("ordinal",page.Ordinal.ToString()),("ipc",Hex(page.Ipc)),("manifest",Obj(("segments",page.Manifest.Segments.ToString()),("selected",page.Manifest.Selected.ToString()),("value_count",page.Manifest.ValueCount.ToString()))),("next",page.Next?.Opaque))));
                    }
                    Console.WriteLine(Obj(("status",0),("value",result)).ToJsonString());
                }catch(TransitException e) { Check(e.Status.HasValue); Console.WriteLine(Obj(("status",e.Status!.Value),("value",Obj(("err",e.Code),("diagnostic",e.Diagnostic),("diagnostic_invalid",e.DiagnosticInvalid)))).ToJsonString()); }
            }
        }
        if(saved is not null)Check((await saved.DecodeAsync()).Count==saved.Rows);
        Console.WriteLine("{\"closed\":true}");
    }
    static async Task Main(string[] args) { JsonNode config=JsonNode.Parse(File.ReadAllText(args[1]))!; if(args[0]=="codecs")await Codecs(config);else await Serve(config); }
}
