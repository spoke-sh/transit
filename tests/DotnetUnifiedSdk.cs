using System.Buffers.Binary;
using System.Text;
using System.Text.Json.Nodes;
using Transit.Client;
using Transit.Station.Sdk;
using Q = Transit.Station.Sdk.UnifiedQuery;

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
    static async Task<Q.Source> Source(ResourceRef r,string kind,bool golden) {
        if(kind=="kv") return new Q.KvSource(r,new Bytes(Encoding.UTF8.GetBytes(golden?"data/":"k")),new(Q.Type.Binary),new(golden?Q.Type.UInt64:Q.Type.Utf8));
        if(kind=="table") return new Q.TableSource(r,golden?9u:1u,["id",golden?"label":"value"],Q.Type.Utf8);
        if(golden) return new Q.DocumentSource(await Reference(r,ulong.MaxValue,3,42),[new(new("title",Q.Type.Utf8),["title"]),new(new("body",Q.Type.Utf8),["body"],mode:Q.ProjectionMode.Text)]);
        return new Q.DocumentSource(await Reference(r,17,1,13),[new(new("value",Q.Type.Utf8),relative:true),new(new("counter",Q.Type.UInt64),relative:true,mode:Q.ProjectionMode.ElementCounter),new(new("replica",Q.Type.UInt64),relative:true,mode:Q.ProjectionMode.ElementReplica),new(new("optional",Q.Type.Utf8),["optional"])],["items"]);
    }
    static Task<Q.Bundle> Bundle(Q.Source source,string kind,bool golden) => Q.Bundle.PrepareAsync(source,
        new(golden?[1,0]:kind=="document"?[0,1,2,3]:[1],new Q.Compare((byte)(golden?1:kind=="document"?0:1),QueryComparison.Ne,golden&&kind=="kv"?new Q.Unsigned(ulong.MaxValue):new Q.Text(new string('x',512))),limit:golden?ulong.MaxValue:null),new(1000,golden?500u:100u,1048576));
    static void Scalar(Q.Scalar scalar,int col) {
        bool valid=col switch { 0=>scalar is Q.Signed { Value:long.MinValue },1=>scalar is Q.Unsigned { Value:ulong.MaxValue },2=>scalar is Q.Floating f && BitConverter.DoubleToInt64Bits(f.Value)==long.MinValue,
            3=>scalar is Q.BooleanValue { Value:false },4=>scalar is Q.Text { Value:"café é 東京🙂" },5=>scalar is Q.Binary b && b.Value.Copy().SequenceEqual(new byte[]{0,255,128}),_=>false }; Check(valid);
    }
    static async Task Codecs(JsonNode config) {
        var fixtures=JsonNode.Parse(File.ReadAllText(Text(config,"bundles")))!.AsArray();
        for(int i=0;i<3;i++) { string kind=new[]{"kv","table","document"}[i]; Check(Hex((await Bundle(await Source(new(46,7),kind,true),kind,true)).Bytes)==Text(fixtures[i]!,"wire_hex")); }
        Q.Column[] columns=Enum.GetValues<Q.Type>().Select(type => new Q.Column(type.ToString().ToLowerInvariant(),type)).ToArray();
        byte[] input=Read(config,"arrow").Copy(); var rows=await Q.DecodeArrowAsync(columns,new Bytes(input),5); Array.Fill(input,(byte)0); Check(rows.Count==5);
        for(int i=0;i<6;i++) {
            Check(rows[0][i] is Q.Missing && rows[1][i] is Q.Null && rows[2][i] is Q.TypeError { ActualKind:"map" }); Scalar(((Q.CellValue)rows[3][i]).Value,i);
            var a=((Q.Conflict)rows[4][i]).Alternatives; Check(a.Count==2 && a[0].Counter==ulong.MaxValue && a[0].Replica==1 && a[1].Counter==ulong.MaxValue && a[1].Replica==2 && a[1].Value is Q.Null); Scalar(((Q.CellValue)a[0].Value).Value,i);
        }
        Check((await Q.DecodeArrowAsync(columns,Read(config,"empty"),0)).Count==0);
        bool rejected=false; try { await Q.DecodeArrowAsync(columns,Read(config,"malformed"),5); }catch(TransitException) { rejected=true; } Check(rejected);
        Console.WriteLine(".NET installed unified codecs: three sources, six types, five states, immutable values and malformed rejection passed");
    }
    static async Task Serve(JsonNode config) {
        var c=config["connection"]!; ulong realm=Number(c,"realm"); ResourceRef resource=new(realm,Number(c,"resource"));
        Q.Connection connection=new(new(realm,Number(c,"source")),resource,new(realm,Number(c,"requester")),new(realm,Number(c,"requests")));
        string kind=Text(config,"kind"); var source=await Source(resource,kind,false); Check((await Bundle(source,kind,false)).Bytes.Copy().SequenceEqual(Read(config,"bundle").Copy()));
        Q.Page? saved=null;
        await using(var client=await Q.Client.OpenAsync(new(new Uri(Text(config,"url")),Profile.NativeV1,10000),new(realm,Number(c,"principal"),Text(config,"seed_file")),connection)) {
            var description=await client.DescribeAsync(source); Check(description.BundleBytes==16384 && description.BatchRows==8);
            // A cancelled wait cannot manufacture query state or dispose ownership.
            using var cancelled=new CancellationTokenSource(); cancelled.Cancel(); bool stopped=false;
            try { await client.StatusAsync(1,cancelled.Token); }catch(OperationCanceledException) { stopped=true; } Check(stopped);
            Console.WriteLine("{\"ready\":true}");
            while(Console.ReadLine() is {} line) {
                var action=JsonNode.Parse(line)!.AsObject(); if(action.ContainsKey("close"))break;
                try {
                    JsonObject result;
                    if(action["next"] is {} next) { var p=await client.PrepareNextAsync(ulong.Parse(Text(next,"namespace")),new(new Bytes(Convert.FromHexString(Text(next,"bundle"))))); result=Obj(("prepared",p is null?null:Encoding.UTF8.GetString(p.Bytes.Copy()))); }
                    else if(action["submit"] is not null) {
                        Q.Prepared p=new(new Bytes(Encoding.UTF8.GetBytes(Text(action,"submit")))); byte[] original=p.Bytes.Copy();
                        try { result=Obj(("receipt",Obj(("position",(await client.SubmitAsync(p)).Position)))); }catch(TransitException) { Check(p.Bytes.Copy().SequenceEqual(original)); throw; }
                    }else if(action["observe"] is not null) { var v=await client.ObserveAsync(Number(action,"observe")); result=Obj(("observation",Obj((v.State.ToString().ToLowerInvariant(),v.Reason is null?Obj():Hex(v.Reason))))); }
                    else if(action["status"] is not null) { var v=await client.StatusAsync(ulong.Parse(Text(action,"status"))); result=Obj(("status",v is null?null:Obj(("phase",v.Phase.ToString().ToLowerInvariant()),("correlation",v.Correlation.ToString())))); }
                    else {
                        var args=action["page"]!; var page=await client.PageAsync(ulong.Parse(Text(args,"namespace")),args["cursor"] is null?null:new(Text(args,"cursor")));
                        Check(page.Manifest.Resource==resource && page.Manifest.Kind.ToString().ToLowerInvariant()==kind); Check((await page.DecodeAsync()).Count==page.Rows); saved=page;
                        result=Obj(("page",Obj(("ordinal",page.Ordinal.ToString()),("ipc",Hex(page.Ipc)),("manifest",Obj(("segments",page.Manifest.Segments.ToString()))),("next",page.Next?.Opaque))));
                    }
                    Console.WriteLine(Obj(("status",0),("value",result)).ToJsonString());
                }catch(TransitException e) { Check(e.Status.HasValue); Console.WriteLine(Obj(("status",e.Status!.Value),("value",Obj(("err",e.Code)))).ToJsonString()); }
            }
        }
        if(saved is not null)Check((await saved.DecodeAsync()).Count==saved.Rows);
        Console.WriteLine("{\"closed\":true}");
    }
    static async Task Main(string[] args) { JsonNode config=JsonNode.Parse(File.ReadAllText(args[1]))!; if(args[0]=="codecs")await Codecs(config);else await Serve(config); }
}
