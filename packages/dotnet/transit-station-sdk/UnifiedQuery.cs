using System.Buffers.Binary;
using System.Text.Json.Nodes;
using Transit.Client;
using Transit.Client.Internal;
using Transit.Station.Sdk.Internal;
using V = Transit.Client.Internal.Value;
using StationApi = Transit.Station.Sdk.Internal.NativeApi;
using StationBridge = Transit.Station.Sdk.Internal.Bridge;

namespace Transit.Station.Sdk;

/// <summary>Explicit v1 state queries over the shared signed Zig client.</summary>
public static class UnifiedQuery
{
    private static ulong Positive(ulong v) => v == 0 ? throw new ArgumentException("Expected positive query identity/budget") : v;
    private static string Name<T>(T v) where T : struct, Enum {
        if(!Enum.IsDefined(v)) throw new ArgumentException("Unknown query variant");
        return v.ToString() switch { "TypeError" => "type_error", "ElementCounter" => "element_counter", "ElementReplica" => "element_replica", "SourceEnd" => "source_end", var name => name.ToLowerInvariant() };
    }
    private static T Variant<T>(JsonNode? v) where T : struct, Enum {
        string name=V.String(v); foreach(T value in Enum.GetValues<T>()) if(Name(value)==name) return value; throw V.Incompatible("query-variant");
    }
    private static string Hex(Bytes v) => V.Hex(v.Copy());
    private static IReadOnlyList<T> Copy<T>(IReadOnlyList<T> v,int bound) {
        ArgumentNullException.ThrowIfNull(v); if(v.Count>bound) throw new ArgumentException("Query collection exceeds its bound");
        var outValues=v.ToArray(); foreach(var item in outValues) ArgumentNullException.ThrowIfNull(item); return System.Array.AsReadOnly(outValues);
    }
    private static JsonArray Array(JsonNode? v,int bound) => v is JsonArray a && a.Count<=bound ? a : throw V.Incompatible("query-array");
    private static JsonArray Path(IReadOnlyList<string> names) { if(names.Count>8) throw new ArgumentException("Query path exceeds eight names"); JsonArray a=new(); foreach(var n in names) a.Add(V.Text(n,64)); return a; }
    private static Bytes Encoded(JsonNode? v,int bound) => new(V.Unhex(v,bound));
    private static Bytes Fixed(JsonNode? v,int size) { Bytes b=Encoded(v,size); if(b.Length!=size) throw V.Incompatible("query-reference"); return b; }
    private static async Task<JsonObject> LocalAsync(JsonObject action,string? directory) {
        var worker=await Worker<StationBridge,object?>.OpenAsync(() => new StationBridge(directory),StationApi.MinimumStackBytes).ConfigureAwait(false);
        try { return await worker.Invoke(b => b.UnifiedCodec(action)).ConfigureAwait(false); }
        finally { worker.CloseSnapshot(); }
    }
    public enum Type { Int64,UInt64,Float64,Boolean,Utf8,Binary }
    public enum State { Missing,Null,TypeError,Value,Conflict }
    public abstract record Scalar { private protected Scalar() {} }
    public sealed record Signed(long Value) : Scalar;
    public sealed record Unsigned(ulong Value) : Scalar;
    public sealed record BooleanValue(bool Value) : Scalar;
    public sealed record Floating : Scalar {
        public double Value { get; }
        public Floating(double value) { if(!double.IsFinite(value)) throw new ArgumentException("Non-finite query scalar"); Value=value; }
    }
    public sealed record Text : Scalar { public string Value { get; } public Text(string value) { Value=V.Text(value,4096); } }
    public sealed record Binary : Scalar { public Bytes Value { get; } public Binary(Bytes value) { ArgumentNullException.ThrowIfNull(value); if(value.Length>4096) throw new ArgumentException("Query scalar exceeds 4096 bytes"); Value=value; } }
    private static string FloatHex(double value) { byte[] bytes=new byte[8]; BinaryPrimitives.WriteDoubleLittleEndian(bytes,value); return V.Hex(bytes); }
    private static JsonObject Wire(Scalar value) => value switch {
        Signed v => V.Obj(("int64",Turn.Decimal(v.Value))), Unsigned v => V.Obj(("uint64",Turn.Decimal(v.Value))), Floating v => V.Obj(("float_bits",FloatHex(v.Value))),
        BooleanValue v => V.Obj(("boolean",v.Value)), Text v => V.Obj(("utf8",v.Value)), Binary v => V.Obj(("binary",Hex(v.Value))), _ => throw new ArgumentException("Invalid query scalar")
    };
    private static Floating ParseFloat(JsonNode? value) { byte[] b=V.Unhex(value,8); if(b.Length!=8) throw V.Incompatible("query-float"); return new(BinaryPrimitives.ReadDoubleLittleEndian(b)); }
    private static Scalar ParseScalar(JsonNode? value) {
        var v=V.Object(value); if(v.Count!=1) throw V.Incompatible("query-scalar"); var a=v.Single();
        return a.Key switch { "int64"=>new Signed(NativeValues.Signed(a.Value)), "uint64"=>new Unsigned(NativeValues.Wide(a.Value)), "float_bits"=>ParseFloat(a.Value),
            "boolean"=>new BooleanValue(V.Boolean(a.Value)), "utf8"=>new Text(V.String(a.Value)), "binary"=>new Binary(Encoded(a.Value,4096)), _=>throw V.Incompatible("query-scalar") };
    }
    public sealed record Column {
        public string Name { get; } public Type Type { get; }
        public Column(string name,Type type) { Name=V.Text(name,64); _=UnifiedQuery.Name(type); Type=type; }
        internal JsonObject Wire() => V.Obj(("name",Name),("type",UnifiedQuery.Name(Type)));
        internal static Column Parse(JsonNode? v) { var a=V.Object(v); return new(V.String(a["name"]),Variant<Type>(a["type"])); }
    }
    public sealed record Decoder(Type Type,byte Version=1) { internal JsonObject Wire() => V.Obj(("version",(uint)Version),("type",Name(Type))); }
    public enum ProjectionMode { Scalar,Text,ElementCounter,ElementReplica }
    public sealed record Projection {
        public Column Column { get; } public IReadOnlyList<string> Path { get; } public bool Relative { get; } public ProjectionMode Mode { get; } public ushort TextBytes { get; } public ushort TextSteps { get; }
        public Projection(Column column,IReadOnlyList<string>? path=null,bool relative=false,ProjectionMode mode=ProjectionMode.Scalar,ushort textBytes=4096,ushort textSteps=4096) {
            ArgumentNullException.ThrowIfNull(column); Column=column; Path=Copy(path??[],8); UnifiedQuery.Path(Path); Relative=relative; _=Name(mode); Mode=mode; TextBytes=textBytes; TextSteps=textSteps;
        }
        internal JsonObject Wire() => V.Obj(("column",Column.Wire()),("path",UnifiedQuery.Path(Path)),("relative",Relative),("mode",Name(Mode)),("text_bytes",(uint)TextBytes),("text_steps",(uint)TextSteps));
    }
    public abstract record Source { private protected Source() {} public abstract ResourceRef Resource { get; } internal abstract JsonObject Definition(); internal JsonObject Wire() => V.Obj(("version",1),("resource",Resource.Resource),("source",Definition())); }
    public sealed record KvSource : Source {
        public override ResourceRef Resource { get; } public Bytes Prefix { get; } public Decoder Key { get; } public Decoder Value { get; }
        public KvSource(ResourceRef resource,Bytes prefix,Decoder key,Decoder value) {
            ArgumentNullException.ThrowIfNull(prefix); ArgumentNullException.ThrowIfNull(key); ArgumentNullException.ThrowIfNull(value); if(prefix.Length>32) throw new ArgumentException("Query prefix exceeds 32 bytes"); Resource=resource; Prefix=prefix; Key=key; Value=value;
        }
        internal override JsonObject Definition() => V.Obj(("kv",V.Obj(("prefix",Hex(Prefix)),("key",Key.Wire()),("value",Value.Wire()))));
    }
    public sealed record TableSource : Source {
        public override ResourceRef Resource { get; } public uint Id { get; } public IReadOnlyList<string> Names { get; } public Type ValueType { get; }
        public TableSource(ResourceRef resource,uint id,IReadOnlyList<string> names,Type valueType) { Resource=resource; Id=id; Names=Copy(names,2); if(id==0 || Names.Count!=2) throw new ArgumentException("Invalid query Table declaration"); foreach(var n in Names) V.Text(n,64); _=Name(valueType); ValueType=valueType; }
        internal override JsonObject Definition() { JsonArray names=new(); foreach(var n in Names) names.Add(n); return V.Obj(("table",V.Obj(("id",Id),("names",names),("value_type",Name(ValueType))))); }
    }
    public sealed record DocumentSource : Source {
        public Document.Reference Reference { get; } public override ResourceRef Resource => Reference.Resource; public IReadOnlyList<Projection> Projections { get; } public IReadOnlyList<string>? Expand { get; }
        public DocumentSource(Document.Reference reference,IReadOnlyList<Projection> projections,IReadOnlyList<string>? expand=null) {
            ArgumentNullException.ThrowIfNull(reference); Reference=reference; Projections=Copy(projections,8); if(Projections.Count==0) throw new ArgumentException("Expected query projections"); Expand=expand is null?null:Copy(expand,8); if(Expand is not null) Path(Expand);
        }
        internal override JsonObject Definition() {
            var r=Reference; JsonArray p=new(); foreach(var v in Projections) p.Add(v.Wire());
            return V.Obj(("document",V.Obj(("reference",V.Obj(("resource",r.Resource.Resource),("document",Turn.Decimal(r.DocumentId)),("epoch",Turn.Decimal(r.Epoch)),("type_revision",r.TypeRevision),("revision",Turn.Decimal(r.Revision)))),("change_format",1),("expand",Expand is null?null:Path(Expand)),("projections",p))));
        }
    }
    public abstract record Predicate { private protected Predicate() {} internal abstract JsonObject Wire(); }
    public sealed record All : Predicate { internal override JsonObject Wire() => V.Obj(("all",V.Obj())); }
    public sealed record IsState(byte Column,State State) : Predicate { internal override JsonObject Wire() => V.Obj(("state",V.Obj(("column",Index(Column)),("value",Name(State))))); }
    public sealed record Compare(byte Column,QueryComparison Comparison,Scalar Value) : Predicate { internal override JsonObject Wire() => V.Obj(("compare",V.Obj(("column",Index(Column)),("op",Name(Comparison)),("value",UnifiedQuery.Wire(Value))))); }
    private static uint Index(byte n) => n<8?n:throw new ArgumentException("Query column outside 0..7");
    public sealed record Plan {
        public IReadOnlyList<byte> Projection { get; } public Predicate Predicate { get; } public QueryAggregate Aggregate { get; } public ulong? Limit { get; }
        public Plan(IReadOnlyList<byte> projection,Predicate? predicate=null,QueryAggregate aggregate=QueryAggregate.Rows,ulong? limit=null) {
            Projection=Copy(projection,8); if(Projection.Count==0) throw new ArgumentException("Expected query projection"); foreach(byte n in Projection) Index(n); Predicate=predicate??new All(); _=Name(aggregate); Aggregate=aggregate; Limit=limit;
        }
        internal JsonObject Wire() { JsonArray p=new(); foreach(byte n in Projection) p.Add((uint)n); return V.Obj(("version",1),("projection",p),("predicate",Predicate.Wire()),("aggregate",Name(Aggregate)),("limit",Limit is {} limit?Turn.Decimal(limit):null)); }
    }
    public sealed record Budgets(ulong Pages,ulong Segments,ulong ResultBytes) { internal JsonObject Wire() => V.Obj(("pages",Turn.Decimal(Positive(Pages))),("segments",Turn.Decimal(Positive(Segments))),("result_bytes",Turn.Decimal(Positive(ResultBytes)))); }
    public sealed record Bundle {
        public Bytes Bytes { get; }
        public Bundle(Bytes bytes) { ArgumentNullException.ThrowIfNull(bytes); if(bytes.Length==0 || bytes.Length>16384) throw new ArgumentException("Expected finite query bundle"); Bytes=bytes; }
        public static async Task<Bundle> PrepareAsync(Source source,Plan plan,Budgets budgets,string? nativeDirectory=null) {
            var v=await LocalAsync(V.Obj(("prepare",V.Obj(("source",source.Wire()),("plan",plan.Wire()),("limits",budgets.Wire())))),nativeDirectory).ConfigureAwait(false); return new(Encoded(V.Object(v["prepared"])["bytes"],16384));
        }
    }
    public sealed record Prepared {
        public Bytes Bytes { get; }
        public Prepared(Bytes bytes) { ArgumentNullException.ThrowIfNull(bytes); if(bytes.Length==0 || bytes.Length>8192) throw new ArgumentException("Expected bounded prepared query command"); _=V.Utf8.GetString(bytes.Copy()); Bytes=bytes; }
    }
    public sealed record Cursor { public string Opaque { get; } public Cursor(string opaque) { Opaque=V.Text(opaque,4096); if(opaque.Length==0) throw new ArgumentException("Empty query cursor"); } }
    public abstract record Cell { private protected Cell() {} }
    public sealed record Missing : Cell;
    public sealed record Null : Cell;
    public sealed record TypeError(string ActualKind) : Cell;
    public sealed record CellValue(Scalar Value) : Cell;
    public sealed record Alternative(ulong Counter,ulong Replica,Cell Value);
    public sealed record Conflict : Cell {
        public IReadOnlyList<Alternative> Alternatives { get; }
        public Conflict(IReadOnlyList<Alternative> alternatives) { Alternatives=Copy(alternatives,8); if(Alternatives.Count<2) throw new ArgumentException("Expected 2..8 alternatives"); foreach(var a in Alternatives) { Positive(a.Counter); Positive(a.Replica); if(a.Value is not (Null or TypeError or CellValue)) throw new ArgumentException("Invalid conflict alternative"); } }
    }
    private static Cell ParseCell(JsonNode? value) {
        var v=V.Object(value); if(v.Count!=1) throw V.Incompatible("query-cell"); var e=v.Single();
        return e.Key switch { "missing"=>new Missing(), "null"=>new Null(), "type_error"=>new TypeError(V.Text(V.String(e.Value),16)), "value"=>new CellValue(ParseScalar(e.Value)),
            "conflict"=>new Conflict(Array(e.Value,8).Select(item => { var a=V.Object(item); return new Alternative(NativeValues.Wide(a["counter"]),NativeValues.Wide(a["replica"]),ParseCell(a["value"])); }).ToArray()), _=>throw V.Incompatible("query-cell") };
    }
    public static async Task<IReadOnlyList<IReadOnlyList<Cell>>> DecodeArrowAsync(IReadOnlyList<Column> columns,Bytes ipc,byte rows,string? nativeDirectory=null) {
        columns=Copy(columns,8); if(columns.Count==0 || rows>8 || ipc.Length>65536) throw new ArgumentException("Query Arrow bounds exceeded"); JsonArray schema=new(); foreach(var c in columns) schema.Add(c.Wire());
        var v=await LocalAsync(V.Obj(("inspect_arrow",V.Obj(("columns",schema),("ipc",Hex(ipc)),("rows",(uint)rows)))),nativeDirectory).ConfigureAwait(false);
        IReadOnlyList<IReadOnlyList<Cell>> output=Copy(Array(v["rows"],8).Select(row => Copy(Array(row,8).Select(ParseCell).ToArray(),8)).ToArray(),8);
        if(output.Count!=rows || output.Any(row => row.Count!=columns.Count)) throw V.Incompatible("query-shape"); return output;
    }
    public sealed record Connection {
        public ProcessRef Source { get; } public ResourceRef Resource { get; } public ProcessRef Requester { get; } public ResourceRef Requests { get; }
        public Connection(ProcessRef source,ResourceRef resource,ProcessRef requester,ResourceRef requests) {
            if(source.Realm!=resource.Realm || source.Realm!=requester.Realm || source.Realm!=requests.Realm) throw new ArgumentException("Different query realms"); Source=source; Resource=resource; Requester=requester; Requests=requests;
        }
        internal JsonObject Wire(Credential identity) {
            if(identity.Realm!=Source.Realm) throw new ArgumentException("Different credential realm"); return V.Obj(("realm",Source.Realm),("principal",identity.Principal),("source",Source.Pid),("resource",Resource.Resource),("requester",Requester.Pid),("requests",Requests.Resource));
        }
    }
    public sealed record Description(ulong ResourceRevision,ulong PolicyRevision,Budgets Budgets,ulong? Active,int BundleBytes,int SegmentBytes,int BatchRows);
    public enum InspectionOperator { Scan,Filter,Limit,Project,Count,Sum }
    public abstract record InspectedPredicate { private protected InspectedPredicate() {} }
    public sealed record InspectedAll : InspectedPredicate;
    public sealed record InspectedState(string Column,State State) : InspectedPredicate;
    public sealed record InspectedComparison(string Column,QueryComparison Comparison,Type Type) : InspectedPredicate;
    public abstract record InspectionDetails { private protected InspectionDetails() {} }
    public sealed record SourceDescription : InspectionDetails {
        public IReadOnlyList<Column> Columns { get; }
        public SourceDescription(IReadOnlyList<Column> columns) { Columns=Copy(columns,8); }
    }
    public sealed record TableListing : InspectionDetails {
        public IReadOnlyList<string> Names { get; }
        public TableListing(IReadOnlyList<string> names) { Names=Copy(names,1); }
    }
    public sealed record Explanation : InspectionDetails {
        public IReadOnlyList<InspectionOperator> Operators { get; } public InspectedPredicate Predicate { get; }
        public IReadOnlyList<string> Projection { get; } public ulong? Limit { get; } public QueryAggregate Aggregate { get; }
        public IReadOnlyList<Column> Columns { get; } public Budgets Budgets { get; }
        public Explanation(IReadOnlyList<InspectionOperator> operators,InspectedPredicate predicate,IReadOnlyList<string> projection,ulong? limit,QueryAggregate aggregate,IReadOnlyList<Column> columns,Budgets budgets) {
            Operators=Copy(operators,4); if(Operators.Count<2) throw V.Incompatible("inspection-operators");
            Predicate=predicate; Projection=Copy(projection,8); Limit=limit; Aggregate=aggregate; Columns=Copy(columns,8); Budgets=budgets;
        }
    }
    public sealed record Inspection(string Name,ResourceRef Resource,SourceKind SourceKind,Bytes SourceDigest,Bytes SchemaDigest,ulong ResourceRevision,ulong PolicyRevision,InspectionDetails Details);
    private static Inspection ParseInspection(JsonNode? value,ResourceRef resource) {
        var v=V.Object(value);
        if(V.Number(v["version"])!=1 || V.String(v["scope"])!="configured_source" || V.Number(v["resource"])!=resource.Resource) throw V.Incompatible("inspection-scope");
        var details=V.Object(v["details"]); if(details.Count!=1) throw V.Incompatible("inspection-details");
        IReadOnlyList<Column> Columns(JsonNode? data) => Array(data,8).Select(Column.Parse).ToArray();
        IReadOnlyList<string> Names(JsonNode? data,int max) => Array(data,max).Select(n=>V.Text(V.String(n),32)).ToArray();
        InspectionDetails parsed;
        if(details.ContainsKey("description")) parsed=new SourceDescription(Columns(V.Object(details["description"])["columns"]));
        else if(details.ContainsKey("tables")) parsed=new TableListing(Names(details["tables"],1));
        else if(details.ContainsKey("explanation")) {
            var plan=V.Object(details["explanation"]); var predicate=V.Object(plan["predicate"]);
            if(predicate.Count!=1) throw V.Incompatible("inspection-predicate"); var selected=predicate.Single();
            var data=V.Object(selected.Value);
            InspectedPredicate p=selected.Key switch {
                "all"=>new InspectedAll(),
                "state"=>new InspectedState(V.Text(V.String(data["column"]),32),Variant<State>(data["value"])),
                "compare"=>new InspectedComparison(V.Text(V.String(data["column"]),32),Variant<QueryComparison>(data["op"]),Variant<Type>(data["type"])),
                _=>throw V.Incompatible("inspection-predicate")
            };
            var limits=V.Object(plan["budgets"]);
            parsed=new Explanation(Array(plan["operators"],4).Select(Variant<InspectionOperator>).ToArray(),p,Names(plan["projection"],8),plan["limit"] is null?null:NativeValues.Wide(plan["limit"]),
                Variant<QueryAggregate>(plan["aggregate"]),Columns(plan["columns"]),new(Positive(NativeValues.Wide(limits["pages"])),Positive(NativeValues.Wide(limits["segments"])),Positive(NativeValues.Wide(limits["result_bytes"]))));
        } else throw V.Incompatible("inspection-details");
        return new(V.Text(V.String(v["name"]),32),resource,Variant<SourceKind>(v["source_kind"]),NativeValues.Digest(v["contract"]),NativeValues.Digest(v["schema"]),V.Number(v["resource_revision"]),Positive(NativeValues.Wide(v["policy_revision"])),parsed);
    }
    public enum Phase { Uploading,Sealed,Admitted,Complete,Cancelled,Denied,Rejected,Retired }
    public sealed record Status(Phase Phase,ulong Correlation,Bytes Reference,Bytes? Manifest,bool Collected);
    public enum Observed { Pending,Committed,Rejected }
    public sealed record Observation(Observed State,Bytes? Reason);
    public enum Control { Cancel,Retire,Collect }
    public enum SourceKind { Kv,Table,Document }
    public enum Finished { SourceEnd,Limit }
    public sealed record Manifest(ulong Job,ReadVersion Source,ProcessRef Requester,ulong Correlation,ulong PolicyRevision,Bytes Request,
        SourceKind Kind,ResourceRef Resource,ulong Revision,Bytes SourceDigest,Bytes SchemaDigest,Bytes PlanDigest,
        ulong Pages,ulong Scanned,ulong Selected,ulong Segments,ulong Rows,ulong ByteCount,long? Sum,Finished Finished,Bytes Chain);
    public sealed record Page {
        public Manifest Manifest { get; } public IReadOnlyList<Column> Columns { get; } public ulong Ordinal { get; } public byte Rows { get; } public Bytes Ipc { get; } public Cursor? Next { get; }
        internal Page(Manifest manifest,IReadOnlyList<Column> columns,ulong ordinal,byte rows,Bytes ipc,Cursor? next) { Manifest=manifest; Columns=Copy(columns,8); Ordinal=ordinal; Rows=rows; Ipc=ipc; Next=next; if(rows>8 || columns.Count==0 || ipc.Length>65536) throw V.Incompatible("query-page-bound"); }
        public Task<IReadOnlyList<IReadOnlyList<Cell>>> DecodeAsync(string? nativeDirectory=null) => DecodeArrowAsync(Columns,Ipc,Rows,nativeDirectory);
    }
    private static Manifest ParseManifest(JsonNode? value,ulong realm) {
        var v=V.Object(value); var b=V.Object(v["basis"]);
        return new(V.Number(v["job"],1),NativeValues.ReadVersion(v["source"]),new(realm,V.Number(v["requester"],1)),NativeValues.Wide(v["correlation"]),NativeValues.Wide(v["policy_revision"]),Fixed(v["request"],68),
            Variant<SourceKind>(b["kind"]),new(realm,V.Number(b["resource"],1)),V.Number(b["revision"]),NativeValues.Digest(b["contract"]),NativeValues.Digest(b["schema"]),NativeValues.Digest(v["plan"]),
            NativeValues.Wide(v["pages"]),NativeValues.Wide(v["scanned"]),NativeValues.Wide(v["selected"]),NativeValues.Wide(v["segments"]),NativeValues.Wide(v["rows"]),NativeValues.Wide(v["bytes"]),v["sum"] is null?null:NativeValues.Signed(v["sum"]),Variant<Finished>(v["finished"]),NativeValues.Digest(v["chain"]));
    }
    /// <summary>One admitted native operation; dispose joins after local cancellation.</summary>
    public sealed class Client : IAsyncDisposable {
        private readonly Worker<StationBridge,object?> worker; private readonly Connection connection;
        private Client(Worker<StationBridge,object?> worker,Connection connection) { this.worker=worker; this.connection=connection; }
        public static async Task<Client> OpenAsync(ClientConfig config,Credential identity,Connection connection) {
            connection.Wire(identity); return new(await Worker<StationBridge,object?>.OpenAsync(() => StationBridge.OpenQuery(config,identity,connection),StationApi.MinimumStackBytes).ConfigureAwait(false),connection);
        }
        public Task<Description> DescribeAsync(Source source,CancellationToken cancellation=default) {
            if(source.Resource!=connection.Resource) throw new ArgumentException("Different query resource"); var action=V.Obj(("describe",source.Wire()));
            return worker.Invoke(b => { var v=V.Object(b.UnifiedQuery(action)["description"]); var l=V.Object(v["limits"]); var c=V.Object(v["capabilities"]); return new Description(V.Number(v["resource_revision"]),NativeValues.Wide(v["policy_revision"]),new(NativeValues.Wide(l["pages"]),NativeValues.Wide(l["segments"]),NativeValues.Wide(l["result_bytes"])),v["active"] is null?null:NativeValues.Wide(v["active"]),checked((int)V.Number(c["bundle_bytes"],1)),checked((int)V.Number(c["segment_bytes"],1)),checked((int)V.Number(c["batch_rows"],1))); },cancellation);
        }
        public Task<Inspection> InspectSqlAsync(Source source,string name,string sql,Budgets budgets,CancellationToken cancellation=default) {
            if(source.Resource!=connection.Resource) throw new ArgumentException("Different query resource");
            var action=V.Obj(("inspect",V.Obj(("scope",V.Obj(("source",source.Wire()),("name",V.Text(name,32)),("limits",budgets.Wire()))),("sql",V.Text(sql,4096)))));
            return worker.Invoke(b=>ParseInspection(b.UnifiedQuery(action)["inspection"],connection.Resource),cancellation);
        }
        public Task<Prepared?> PrepareNextAsync(ulong ns,Bundle bundle,CancellationToken cancellation=default) {
            var action=V.Obj(("next",V.Obj(("namespace",Turn.Decimal(Positive(ns))),("bundle",Hex(bundle.Bytes)))));
            return worker.Invoke(b => b.UnifiedQuery(action)["prepared"] is {} v?new Prepared(new Bytes(V.Utf8.GetBytes(V.String(v)))):null,cancellation);
        }
        public Task<Prepared> PrepareControlAsync(Control control,ulong ns,CancellationToken cancellation=default) {
            var action=V.Obj(("prepare",V.Obj((Name(control),Turn.Decimal(Positive(ns))))));
            return worker.Invoke(b => new Prepared(new Bytes(V.Utf8.GetBytes(V.String(b.UnifiedQuery(action)["prepared"])))),cancellation);
        }
        public Task<AdmissionReceipt> SubmitAsync(Prepared prepared,CancellationToken cancellation=default) {
            var action=V.Obj(("submit",V.Utf8.GetString(prepared.Bytes.Copy())));
            return worker.Invoke(b => { var v=b.UnifiedQuery(action,true); try { return new AdmissionReceipt(V.Number(V.Object(v["receipt"])["position"],1)); }catch(Exception) { throw new TransitException(ErrorKind.UnknownOutcome,"query-receipt",6); } },cancellation);
        }
        public Task<Observation> ObserveAsync(ulong input,CancellationToken cancellation=default) {
            var action=V.Obj(("observe",V.Counter(input)));
            return worker.Invoke(b => { var v=V.Object(b.UnifiedQuery(action)["observation"]); if(v.ContainsKey("pending")) return new Observation(Observed.Pending,null); if(v.ContainsKey("committed")) return new Observation(Observed.Committed,null); return new Observation(Observed.Rejected,Encoded(v["rejected"],256)); },cancellation);
        }
        public Task<Status?> StatusAsync(ulong ns,CancellationToken cancellation=default) {
            var action=V.Obj(("status",Turn.Decimal(Positive(ns))));
            return worker.Invoke(b => { var v=b.UnifiedQuery(action)["status"]; return v is null?null:new Status(Variant<Phase>(v["phase"]),NativeValues.Wide(v["correlation"]),Fixed(v["reference"],68),v["manifest"] is null?null:Fixed(v["manifest"],68),V.Boolean(v["collected"])); },cancellation);
        }
        public Task<Page> PageAsync(ulong ns,Cursor? cursor=null,CancellationToken cancellation=default) {
            var action=V.Obj(("page",V.Obj(("namespace",Turn.Decimal(Positive(ns))),("cursor",cursor?.Opaque))));
            return worker.Invoke(b => { var v=V.Object(b.UnifiedQuery(action)["page"]); return new Page(ParseManifest(v["manifest"],connection.Source.Realm),Array(v["columns"],8).Select(Column.Parse).ToArray(),NativeValues.Wide(v["ordinal"]),checked((byte)V.Number(v["rows"])),Encoded(v["ipc"],65536),v["next"] is null?null:new Cursor(V.String(v["next"]))); },cancellation);
        }
        public async ValueTask DisposeAsync() { try { await worker.CloseAsync().ConfigureAwait(false); }finally { worker.CloseSnapshot(); } }
    }
}
