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
        return v.ToString() switch { "CountValues" => "count_values", "TypeError" => "type_error", "ElementCounter" => "element_counter", "ElementReplica" => "element_replica", "SourceEnd" => "source_end", var name => name.ToLowerInvariant() };
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
    public enum DecoderType { Int64,UInt64,Float64,Boolean,Utf8,Binary }
    public enum State { Missing,Null,TypeError,Value,Conflict }
    private static string ColumnName(string value) {
        V.Text(value,255); if(value.Length==0 || value.Contains('\0')) throw new ArgumentException("Expected nonempty query name without NUL"); return value;
    }
    private static JsonObject Wire(Logical.Atom value) {
        if(value is Logical.Utf8 text) V.Text(text.Text,4096);
        if(value is Logical.Binary bytes && bytes.Bytes.Length>4096) throw new ArgumentException("Query literal exceeds 4096 bytes");
        return Logical.AtomWire(value);
    }
    public sealed record Column {
        public string Name { get; } public Logical.Descriptor Type { get; } public bool Nullable { get; } public bool Optional { get; }
        public Column(string name,Logical.Descriptor type,bool nullable=false,bool optional=false) {
            Name=ColumnName(name); ArgumentNullException.ThrowIfNull(type); Type=type; Nullable=nullable; Optional=optional;
        }
        internal JsonObject Wire() => V.Obj(("name",Name),("type",Logical.TypeWire(Type)),("nullable",Nullable),("optional",Optional));
        internal static Column Parse(JsonNode? v) { var a=V.Object(v); return new(V.String(a["name"]),Logical.TypeFromWire(a["type"]),V.Boolean(a["nullable"]),V.Boolean(a["optional"])); }
    }
    public sealed record DecoderColumn {
        public string Name { get; } public DecoderType Type { get; }
        public DecoderColumn(string name,DecoderType type) { Name=V.Text(name,32); _=UnifiedQuery.Name(type); Type=type; }
        internal JsonObject Wire() => V.Obj(("name",Name),("type",UnifiedQuery.Name(Type)));
    }
    public sealed record Decoder(DecoderType Type,byte Version=1) { internal JsonObject Wire() => V.Obj(("version",(uint)Version),("type",Name(Type))); }
    public enum ProjectionMode { Scalar,Text,ElementCounter,ElementReplica }
    public sealed record Projection {
        public DecoderColumn Column { get; } public IReadOnlyList<string> Path { get; } public bool Relative { get; } public ProjectionMode Mode { get; } public ushort TextBytes { get; } public ushort TextSteps { get; }
        public Projection(DecoderColumn column,IReadOnlyList<string>? path=null,bool relative=false,ProjectionMode mode=ProjectionMode.Scalar,ushort textBytes=4096,ushort textSteps=4096) {
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
    private static Bytes Commitment(Bytes value) { ArgumentNullException.ThrowIfNull(value); if(value.Length!=32)throw new ArgumentException("Expected 32-byte commitment"); return value; }
    private static JsonArray DigestArray(Bytes value) { JsonArray result=new(); foreach(byte b in Commitment(value).Copy())result.Add((uint)b); return result; }
    public sealed record TableInterpretation {
        public ulong Revision { get; } public Bytes Digest { get; } public ulong ByteCount { get; } public Bytes SchemaDigest { get; }
        public TableInterpretation(ulong revision,Bytes digest,ulong byteCount,Bytes schemaDigest) { Revision=Positive(revision); Digest=Commitment(digest); ByteCount=Positive(byteCount); SchemaDigest=Commitment(schemaDigest); }
        internal JsonObject Wire() => V.Obj(("revision",Turn.Decimal(Revision)),("digest",DigestArray(Digest)),("bytes",Turn.Decimal(ByteCount)),("schema",DigestArray(SchemaDigest)));
    }
    public sealed record TableSource : Source {
        public Catalog.Scope Scope { get; } public ulong Audience { get; } public ulong Branch { get; } public ulong Namespace { get; } public TableInterpretation Interpretation { get; } public Catalog.Schema Schema { get; }
        public override ResourceRef Resource => Scope.Resource;
        public TableSource(Catalog.Scope scope,ulong audience,ulong branch,ulong schemaNamespace,TableInterpretation interpretation,Catalog.Schema schema) {
            ArgumentNullException.ThrowIfNull(scope); ArgumentNullException.ThrowIfNull(interpretation); ArgumentNullException.ThrowIfNull(schema);
            Scope=scope; Audience=V.Counter(audience); Branch=Positive(branch); Namespace=V.Counter(schemaNamespace); Interpretation=interpretation; Schema=schema;
        }
        internal override JsonObject Definition() {
            var rowType=new Logical.Structure(Schema.Columns.Select(c=>new Logical.Field(c.Name,c.Type,c.Nullable,false)).ToArray());
            JsonArray collations=new(), semantics=new(); foreach(var column in Schema.Columns){collations.Add(Logical.EnumName(column.Collation));semantics.Add(V.Obj(("rounding",null),("metric",null),("timezone",null),("spatial",null)));}
            return V.Obj(("table",V.Obj(("scope",Scope.Wire()),("owner",Audience),("branch",Turn.Decimal(Branch)),("namespace",Namespace),("object",Turn.Decimal(Schema.ObjectId)),
                ("interpretation",Interpretation.Wire()),("row_type",Logical.TypeWire(rowType)),("collations",collations),("semantics",semantics))));
        }
    }
    public sealed record Tables {
        public string Url { get; } public Catalog.Scope Scope { get; } public ulong Branch { get; } public ulong Audience { get; }
        public Tables(string url,Catalog.Scope scope,ulong branch,ulong audience) { Url=V.Text(url,2048); ArgumentNullException.ThrowIfNull(scope); Scope=scope; Branch=Positive(branch); Audience=V.Counter(audience); }
        internal JsonObject Wire(Credential identity,Connection connection) {
            if(Scope.Resource.Realm!=identity.Realm)throw new ArgumentException("Different direct Table realm");
            return V.Obj(("url",Url),("connection",V.Obj(("scope",Scope.Wire()),("branch",Turn.Decimal(Branch)),("audience",Audience),("principal",identity.Principal),("role",connection.Role))));
        }
    }
    public sealed record Capture {
        public ulong Executor { get; } public ulong Operation { get; } public ulong Partition { get; } public ulong NextLsn { get; }
        public Capture(ulong executor,ulong operation,ulong partition,ulong nextLsn) { Executor=V.Counter(executor); Operation=Positive(operation); Partition=Positive(partition); NextLsn=nextLsn; }
        internal JsonObject Wire() => V.Obj(("executor",Executor),("operation",Turn.Decimal(Operation)),("expected",V.Obj(("partition",Turn.Decimal(Partition)),("next_lsn",Turn.Decimal(NextLsn)))));
    }
    public sealed record TableDefinition {
        public TableSource Source { get; } public ulong Partition { get; } public ulong NextLsn { get; }
        public TableDefinition(TableSource source,ulong partition,ulong nextLsn) { ArgumentNullException.ThrowIfNull(source); Source=source; Partition=Positive(partition); NextLsn=nextLsn; }
        public Capture Capture(ulong executor,ulong operation) => new(executor,operation,Partition,NextLsn);
    }
    private static TableDefinition? ParseTable(JsonNode? value) {
        if(value is null)return null;
        var v=V.Object(value); var envelope=V.Object(v["source"]); var direct=V.Object(V.Object(envelope["source"])["table"]); var interpretation=V.Object(direct["interpretation"]); var expected=V.Object(v["expected"]);
        TableSource source=new(Catalog.ParseScope(direct["scope"]),V.Number(direct["owner"],1),NativeValues.Wide(direct["branch"]),V.Number(direct["namespace"],1),
            new(NativeValues.Wide(interpretation["revision"]),NativeValues.Digest(interpretation["digest"]),NativeValues.Wide(interpretation["bytes"]),NativeValues.Digest(interpretation["schema"])),Catalog.ParseSchema(v["schema"]));
        if(!JsonNode.DeepEquals(source.Wire(),envelope))throw V.Incompatible("direct-table-definition");
        return new(source,NativeValues.Wide(expected["partition"]),NativeValues.Wide(expected["next_lsn"]));
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
    public abstract record PredicateAtom : Predicate { private protected PredicateAtom() {} }
    public sealed record All : PredicateAtom { internal override JsonObject Wire() => V.Obj(("all",V.Obj())); }
    public sealed record IsState(byte Column,State State) : PredicateAtom { internal override JsonObject Wire() => V.Obj(("state",V.Obj(("column",Index(Column)),("value",Name(State))))); }
    public sealed record Compare(byte Column,QueryComparison Comparison,Logical.Atom Value) : PredicateAtom { internal override JsonObject Wire() => V.Obj(("compare",V.Obj(("column",Index(Column)),("op",Name(Comparison)),("value",UnifiedQuery.Wire(Value))))); }
    public enum PredicateOperator { Negate,Conjunction,Disjunction }
    public abstract record PredicateInstruction { private protected PredicateInstruction() {} internal abstract JsonObject Wire(); }
    public sealed record PredicateAtomInstruction(PredicateAtom Atom) : PredicateInstruction { internal override JsonObject Wire() => V.Obj(("atom",Atom.Wire())); }
    public sealed record PredicateOperation(PredicateOperator Operator) : PredicateInstruction { internal override JsonObject Wire() => V.Obj((Name(Operator),V.Obj())); }
    public sealed record PredicateProgram : Predicate {
        public IReadOnlyList<PredicateInstruction> Instructions { get; }
        public PredicateProgram(IReadOnlyList<PredicateInstruction> instructions) {
            Instructions=Copy(instructions,64); if(Instructions.Count==0)throw new ArgumentException("Expected 1..64 predicate instructions");
        }
        internal override JsonObject Wire() { JsonArray program=new(); foreach(var instruction in Instructions)program.Add(instruction.Wire()); return V.Obj(("program",program)); }
    }
    private static uint Index(byte n) => n<128?n:throw new ArgumentException("Query column outside 0..127");
    public sealed record Plan {
        public IReadOnlyList<byte> Projection { get; } public Predicate Predicate { get; } public QueryAggregate Aggregate { get; } public ulong? Limit { get; }
        public IReadOnlyList<string?>? OutputNames { get; }
        public Plan(IReadOnlyList<byte> projection,Predicate? predicate=null,QueryAggregate aggregate=QueryAggregate.Rows,ulong? limit=null,IReadOnlyList<string?>? outputNames=null) {
            Projection=Copy(projection,128); if(Projection.Count==0) throw new ArgumentException("Expected query projection"); foreach(byte n in Projection) Index(n); Predicate=predicate??new All(); _=Name(aggregate); Aggregate=aggregate; Limit=limit;
            if(outputNames is not null){if(outputNames.Count!=Projection.Count)throw new ArgumentException("Output names must match the projection width");OutputNames=System.Array.AsReadOnly(outputNames.Select(n => n is null?null:ColumnName(n)).ToArray());}
        }
        internal JsonObject Wire() { JsonArray p=new(); foreach(byte n in Projection) p.Add((uint)n); JsonArray? names=null;if(OutputNames is not null){names=new();foreach(var n in OutputNames)names.Add(n);} return V.Obj(("version",1),("scalar_program","00"),("projection",p),("output_names",names),("predicate",Predicate.Wire()),("aggregate",Name(Aggregate)),("limit",Limit is {} limit?Turn.Decimal(limit):null)); }
    }
    public sealed record Budgets(ulong Pages,ulong Segments,ulong ResultBytes) { internal JsonObject Wire() => V.Obj(("pages",Turn.Decimal(Positive(Pages))),("segments",Turn.Decimal(Positive(Segments))),("result_bytes",Turn.Decimal(Positive(ResultBytes)))); }
    public sealed record Bundle {
        public Bytes Bytes { get; }
        public Bundle(Bytes bytes) { ArgumentNullException.ThrowIfNull(bytes); if(bytes.Length==0 || bytes.Length>Catalog.Limit("query_bundle_bytes")) throw new ArgumentException("Expected finite query bundle"); Bytes=bytes; }
        public static async Task<Bundle> PrepareAsync(Source source,Plan plan,Budgets budgets,string? nativeDirectory=null) {
            var declaration=source.Wire(); var parameters=plan.Wire();
            if(source is TableSource)parameters["collations"]=declaration["source"]!["table"]!["collations"]!.DeepClone();
            var v=await LocalAsync(V.Obj(("prepare",V.Obj(("source",declaration),("plan",parameters),("limits",budgets.Wire())))),nativeDirectory).ConfigureAwait(false); return new(Encoded(V.Object(v["prepared"])["bytes"],Catalog.Limit("query_bundle_bytes")));
        }
    }
    public sealed record Prepared {
        public Bytes Bytes { get; }
        public Prepared(Bytes bytes) { ArgumentNullException.ThrowIfNull(bytes); if(bytes.Length==0 || bytes.Length>8192) throw new ArgumentException("Expected bounded prepared query command"); _=V.Utf8.GetString(bytes.Copy()); Bytes=bytes; }
    }
    public sealed record Cursor { public string Opaque { get; } public Cursor(string opaque) { Opaque=V.Text(opaque,4096); if(opaque.Length==0) throw new ArgumentException("Empty query cursor"); } }
    public static async Task<IReadOnlyList<IReadOnlyList<Logical.Cell>>> DecodeArrowAsync(IReadOnlyList<Column> columns,Bytes ipc,byte rows,string? nativeDirectory=null) {
        columns=Copy(columns,128); if(columns.Count==0 || rows>8 || ipc.Length>65536) throw new ArgumentException("Query Arrow bounds exceeded"); JsonArray schema=new(); foreach(var c in columns) schema.Add(c.Wire());
        var v=await LocalAsync(V.Obj(("inspect_arrow",V.Obj(("columns",schema),("ipc",Hex(ipc)),("rows",(uint)rows)))),nativeDirectory).ConfigureAwait(false);
        IReadOnlyList<IReadOnlyList<Logical.Cell>> output=Copy(Array(v["rows"],8).Select(row => Copy(Array(row,128).Select(Logical.CellFromWire).ToArray(),128)).ToArray(),8);
        if(output.Count!=rows || output.Any(row => row.Count!=columns.Count)) throw V.Incompatible("query-shape"); return output;
    }
    public sealed record Connection {
        public ProcessRef Source { get; } public ResourceRef Resource { get; } public ProcessRef Requester { get; } public ResourceRef Requests { get; } public ulong? Role { get; }
        public Connection(ProcessRef source,ResourceRef resource,ProcessRef requester,ResourceRef requests,ulong? role=null) {
            if(source.Realm!=resource.Realm || source.Realm!=requester.Realm || source.Realm!=requests.Realm) throw new ArgumentException("Different query realms"); Source=source; Resource=resource; Requester=requester; Requests=requests; Role=role is {} selected?V.Counter(selected,0):null;
        }
        internal JsonObject Wire(Credential identity) {
            if(identity.Realm!=Source.Realm) throw new ArgumentException("Different credential realm"); return V.Obj(("realm",Source.Realm),("principal",identity.Principal),("source",Source.Pid),("resource",Resource.Resource),("requester",Requester.Pid),("requests",Requests.Resource),("role",Role));
        }
    }
    public sealed record Description(ulong ResourceRevision,ulong PolicyRevision,Budgets Budgets,ulong? Active,int BundleBytes,int SegmentBytes,int BatchRows);
    public enum InspectionOperator { Scan,Filter,Limit,Project,Count,Sum,CountValues }
    public abstract record InspectedPredicate { private protected InspectedPredicate() {} }
    public abstract record InspectedAtom : InspectedPredicate { private protected InspectedAtom() {} }
    public sealed record InspectedAll : InspectedAtom;
    public sealed record InspectedState(string Column,State State) : InspectedAtom;
    public sealed record InspectedComparison(string Column,QueryComparison Comparison,Logical.Descriptor Type) : InspectedAtom;
    public abstract record InspectedInstruction { private protected InspectedInstruction() {} }
    public sealed record InspectedAtomInstruction(InspectedAtom Atom) : InspectedInstruction;
    public sealed record InspectedOperation(PredicateOperator Operator) : InspectedInstruction;
    public sealed record InspectedProgram : InspectedPredicate {
        public IReadOnlyList<InspectedInstruction> Instructions { get; }
        public InspectedProgram(IReadOnlyList<InspectedInstruction> instructions) {
            Instructions=Copy(instructions,64); if(Instructions.Count==0)throw V.Incompatible("inspection-program-size");
        }
    }
    private static InspectedAtom ParseInspectedAtom(JsonNode? value) {
        var atom=V.Object(value); if(atom.Count!=1)throw V.Incompatible("inspection-atom");
        var selected=atom.Single(); var data=V.Object(selected.Value);
        return selected.Key switch {
            "all" when data.Count==0=>new InspectedAll(),
            "state"=>new InspectedState(ColumnName(V.String(data["column"])),Variant<State>(data["value"])),
            "compare"=>new InspectedComparison(ColumnName(V.String(data["column"])),Variant<QueryComparison>(data["op"]),Logical.TypeFromWire(data["type"])),
            _=>throw V.Incompatible("inspection-atom")
        };
    }
    private static InspectedPredicate ParseInspectedPredicate(JsonNode? value) {
        var predicate=V.Object(value); if(predicate.Count!=1)throw V.Incompatible("inspection-predicate");
        if(!predicate.ContainsKey("program"))return ParseInspectedAtom(value);
        List<InspectedInstruction> instructions=new(); int depth=0;
        foreach(var v in Array(predicate["program"],64)) {
            var instruction=V.Object(v); if(instruction.Count!=1)throw V.Incompatible("inspection-instruction");
            var entry=instruction.Single();
            if(entry.Key=="atom") { instructions.Add(new InspectedAtomInstruction(ParseInspectedAtom(entry.Value))); depth++; }
            else {
                var op=entry.Key switch {"negate"=>PredicateOperator.Negate,"conjunction"=>PredicateOperator.Conjunction,"disjunction"=>PredicateOperator.Disjunction,_=>throw V.Incompatible("inspection-operator")};
                int needed=op==PredicateOperator.Negate?1:2;
                if(V.Object(entry.Value).Count!=0 || depth<needed)throw V.Incompatible("inspection-program-shape");
                depth-=needed-1; instructions.Add(new InspectedOperation(op));
            }
        }
        if(depth!=1)throw V.Incompatible("inspection-program-shape");
        return new InspectedProgram(instructions);
    }
    public abstract record InspectionDetails { private protected InspectionDetails() {} }
    public sealed record SourceDescription : InspectionDetails {
        public IReadOnlyList<Column> Columns { get; }
        public SourceDescription(IReadOnlyList<Column> columns) { Columns=Copy(columns,128); }
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
            Predicate=predicate; Projection=Copy(projection,128); Limit=limit; Aggregate=aggregate; Columns=Copy(columns,128); Budgets=budgets;
        }
    }
    public sealed record Inspection(string Name,ResourceRef Resource,SourceKind SourceKind,Bytes SourceDigest,Bytes SchemaDigest,ulong ResourceRevision,ulong PolicyRevision,InspectionDetails Details);
    private static Inspection ParseInspection(JsonNode? value,ResourceRef resource) {
        var v=V.Object(value);
        if(V.Number(v["version"])!=1 || V.String(v["scope"])!="configured_source" || V.Number(v["resource"])!=resource.Resource) throw V.Incompatible("inspection-scope");
        var details=V.Object(v["details"]); if(details.Count!=1) throw V.Incompatible("inspection-details");
        IReadOnlyList<Column> Columns(JsonNode? data) => Array(data,128).Select(Column.Parse).ToArray();
        IReadOnlyList<string> Names(JsonNode? data,int max) => Array(data,max).Select(n=>ColumnName(V.String(n))).ToArray();
        InspectionDetails parsed;
        if(details.ContainsKey("description")) parsed=new SourceDescription(Columns(V.Object(details["description"])["columns"]));
        else if(details.ContainsKey("tables")) parsed=new TableListing(Names(details["tables"],1));
        else if(details.ContainsKey("explanation")) {
            var plan=V.Object(details["explanation"]);
            var p=ParseInspectedPredicate(plan["predicate"]);
            var limits=V.Object(plan["budgets"]);
            parsed=new Explanation(Array(plan["operators"],4).Select(Variant<InspectionOperator>).ToArray(),p,Names(plan["projection"],128),plan["limit"] is null?null:NativeValues.Wide(plan["limit"]),
                Variant<QueryAggregate>(plan["aggregate"]),Columns(plan["columns"]),new(Positive(NativeValues.Wide(limits["pages"])),Positive(NativeValues.Wide(limits["segments"])),Positive(NativeValues.Wide(limits["result_bytes"]))));
        } else throw V.Incompatible("inspection-details");
        return new(ColumnName(V.String(v["name"])),resource,Variant<SourceKind>(v["source_kind"]),NativeValues.Digest(v["contract"]),NativeValues.Digest(v["schema"]),V.Number(v["resource_revision"]),Positive(NativeValues.Wide(v["policy_revision"])),parsed);
    }
    public enum Phase { Uploading,Sealed,Admitted,Complete,Cancelled,Denied,Rejected,Retired }
    public sealed record Failure(string Code,string Stage,string Dimension,ulong Limit,ulong Observed);
    private static Failure? ReadFailure(JsonNode? value) => value is null ? null : new Failure(V.String(value["code"]),V.String(value["stage"]),V.String(value["dimension"]),NativeValues.Wide(value["limit"]),NativeValues.Wide(value["observed"]));
    public sealed record Status(Phase Phase,ulong Correlation,Bytes Reference,Bytes? Manifest,bool Collected,Failure? Failure,JsonObject? Diagnostic);
    public enum Observed { Pending,Committed,Rejected }
    public sealed record Observation(Observed State,Bytes? Reason);
    public enum Control { Cancel,Retire,Collect }
    public enum SourceKind { Kv,Table,Document }
    public enum Finished { SourceEnd,Limit }
    public abstract record Retention { private protected Retention() {} }
    public sealed record NativeRetention(ReadVersion Version) : Retention;
    public sealed record TableRetention(ProcessRef Worker) : Retention;
    public abstract record Cut { private protected Cut() {} }
    public sealed record NativeCut : Cut { public ulong Revision { get; } public NativeCut(ulong revision) { Revision=V.Counter(revision,0); } }
    public sealed record TableCut : Cut { public Bytes Commitment { get; } public TableCut(Bytes commitment) { Commitment=UnifiedQuery.Commitment(commitment); } }
    public sealed record Manifest(ulong Job,Retention Source,ProcessRef Requester,ulong Correlation,ulong PolicyRevision,Bytes Request,
        SourceKind Kind,ResourceRef Resource,Cut Cut,Bytes SourceDigest,Bytes SchemaDigest,Bytes PlanDigest,
        ulong Pages,ulong Scanned,ulong Selected,ulong ValueCount,ulong Segments,ulong Rows,ulong ByteCount,long? Sum,Finished Finished,Bytes Chain);
    public sealed record Page {
        public Manifest Manifest { get; } public IReadOnlyList<Column> Columns { get; } public ulong Ordinal { get; } public byte Rows { get; } public Bytes Ipc { get; } public Cursor? Next { get; }
        internal Page(Manifest manifest,IReadOnlyList<Column> columns,ulong ordinal,byte rows,Bytes ipc,Cursor? next) { Manifest=manifest; Columns=Copy(columns,128); Ordinal=ordinal; Rows=rows; Ipc=ipc; Next=next; if(rows>8 || columns.Count==0 || ipc.Length>65536) throw V.Incompatible("query-page-bound"); }
        public Task<IReadOnlyList<IReadOnlyList<Logical.Cell>>> DecodeAsync(string? nativeDirectory=null) => DecodeArrowAsync(Columns,Ipc,Rows,nativeDirectory);
    }
    private static Manifest ParseManifest(JsonNode? value,ulong realm) {
        var v=V.Object(value); var b=V.Object(v["basis"]); var cut=V.Object(b["cut"]);
        var retained=V.Object(v["source"]); var position=V.Object(cut["position"]); var kind=Variant<SourceKind>(cut["kind"]);
        Retention retention; Cut captured;
        if(kind==SourceKind.Table) {
            if(retained.Count!=1 || !retained.ContainsKey("table") || position.Count!=1 || !position.ContainsKey("table"))throw V.Incompatible("direct-table-cut");
            retention=new TableRetention(new(realm,V.Number(V.Object(retained["table"])["worker"],1))); captured=new TableCut(NativeValues.Digest(position["table"]));
        } else {
            if(retained.Count!=1 || !retained.ContainsKey("native") || position.Count!=1 || !position.ContainsKey("native_revision"))throw V.Incompatible("native-source-cut");
            retention=new NativeRetention(NativeValues.ReadVersion(retained["native"])); captured=new NativeCut(V.Number(position["native_revision"]));
        }
        return new(V.Number(v["job"],1),retention,new(realm,V.Number(v["requester"],1)),NativeValues.Wide(v["correlation"]),NativeValues.Wide(v["policy_revision"]),Fixed(v["request"],72),
            kind,new(realm,V.Number(cut["resource"],1)),captured,NativeValues.Digest(b["contract"]),NativeValues.Digest(b["schema"]),NativeValues.Digest(v["plan"]),
            NativeValues.Wide(v["pages"]),NativeValues.Wide(v["scanned"]),NativeValues.Wide(v["selected"]),NativeValues.Wide(v["value_count"]),NativeValues.Wide(v["segments"]),NativeValues.Wide(v["rows"]),NativeValues.Wide(v["bytes"]),v["sum"] is null?null:NativeValues.Signed(v["sum"]),Variant<Finished>(v["finished"]),NativeValues.Digest(v["chain"]));
    }
    /// <summary>One admitted native operation; dispose joins after local cancellation.</summary>
    public sealed class Client : IAsyncDisposable {
        private readonly Worker<StationBridge,object?> worker; private readonly Connection connection;
        private Client(Worker<StationBridge,object?> worker,Connection connection) { this.worker=worker; this.connection=connection; }
        public static async Task<Client> OpenAsync(ClientConfig config,Credential identity,Connection connection,Tables? tables=null) {
            connection.Wire(identity); return new(await Worker<StationBridge,object?>.OpenAsync(() => StationBridge.OpenQuery(config,identity,connection,tables),StationApi.MinimumStackBytes).ConfigureAwait(false),connection);
        }
        public Task<TableDefinition?> LookupTableAsync(ulong schemaNamespace,string name,CancellationToken cancellation=default) {
            var action=V.Obj(("table",V.Obj(("namespace",V.Counter(schemaNamespace)),("name",ColumnName(name)))));
            return worker.Invoke(b=>ParseTable(b.UnifiedQuery(action)["table"]),cancellation);
        }
        public Task<Description> DescribeAsync(Source source,CancellationToken cancellation=default) {
            if(source.Resource.Realm!=connection.Resource.Realm || (source is not TableSource && source.Resource!=connection.Resource)) throw new ArgumentException("Different query resource"); var action=V.Obj(("describe",source.Wire()));
            return worker.Invoke(b => { var v=V.Object(b.UnifiedQuery(action)["description"]); var l=V.Object(v["limits"]); var c=V.Object(v["capabilities"]); return new Description(V.Number(v["resource_revision"]),NativeValues.Wide(v["policy_revision"]),new(NativeValues.Wide(l["pages"]),NativeValues.Wide(l["segments"]),NativeValues.Wide(l["result_bytes"])),v["active"] is null?null:NativeValues.Wide(v["active"]),checked((int)V.Number(c["bundle_bytes"],1)),checked((int)V.Number(c["segment_bytes"],1)),checked((int)V.Number(c["batch_rows"],1))); },cancellation);
        }
        public Task<Inspection> InspectSqlAsync(Source source,string name,string sql,Budgets budgets,CancellationToken cancellation=default) {
            if(source.Resource.Realm!=connection.Resource.Realm || (source is not TableSource && source.Resource!=connection.Resource)) throw new ArgumentException("Different query resource");
            var action=V.Obj(("inspect",V.Obj(("scope",V.Obj(("source",source.Wire()),("name",ColumnName(name)),("limits",budgets.Wire()))),("sql",V.Text(sql,4096)))));
            return worker.Invoke(b=>ParseInspection(b.UnifiedQuery(action)["inspection"],source.Resource),cancellation);
        }
        /// <summary>New owned finite bundle; no upload or admission. Await cancellation retains native ownership.</summary>
        public Task<Bundle> CompileSqlAsync(Source source,string name,string sql,Budgets budgets,IReadOnlyList<Logical.Atom>? parameters=null,CancellationToken cancellation=default) {
            if(source.Resource.Realm!=connection.Resource.Realm || (source is not TableSource && source.Resource!=connection.Resource)) throw new ArgumentException("Different query resource");
            JsonArray? values=null;
            if(parameters is not null) {
                if(parameters.Count>65) throw new ArgumentException("Expected at most 65 parameter atoms");
                values=new();foreach(var scalar in parameters)values.Add(Wire(scalar));
            }
            var action=V.Obj(("compile",V.Obj(("scope",V.Obj(("source",source.Wire()),("name",ColumnName(name)),("limits",budgets.Wire()))),("sql",V.Text(sql,4096)),("parameters",values))));
            return worker.Invoke(b=>new Bundle(Encoded(V.Object(b.UnifiedQuery(action)["compiled"])["bundle"],Catalog.Limit("query_bundle_bytes"))),cancellation);
        }
        /// <summary>Seal new work before persistence; recover saved bundles unchanged.</summary>
        public Task<Bundle> AuthorizeBundleAsync(Bundle bundle,Capture? capture=null,CancellationToken cancellation=default) {
            var action=V.Obj(("authorize",V.Obj(("bundle",Hex(bundle.Bytes)),("capture",capture?.Wire()))));
            return worker.Invoke(b=>new Bundle(Encoded(b.UnifiedQuery(action)["authorized"],Catalog.Limit("query_bundle_bytes"))),cancellation);
        }
        public Task<Prepared> PrepareCleanupAsync(ulong ns,Bundle originalBundle,CancellationToken cancellation=default) {
            var action=V.Obj(("cleanup",V.Obj(("namespace",Turn.Decimal(Positive(ns))),("bundle",Hex(originalBundle.Bytes)))));
            return worker.Invoke(b=>new Prepared(new Bytes(V.Utf8.GetBytes(V.String(b.UnifiedQuery(action)["prepared"])))),cancellation);
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
            return worker.Invoke(b => { var v=b.UnifiedQuery(action)["status"]; return v is null?null:new Status(Variant<Phase>(v["phase"]),NativeValues.Wide(v["correlation"]),Fixed(v["reference"],72),v["manifest"] is null?null:Fixed(v["manifest"],72),V.Boolean(v["collected"]),ReadFailure(v["failure"]),v["diagnostic"] is null?null:V.Object(v["diagnostic"]).DeepClone().AsObject()); },cancellation);
        }
        public Task<Page> PageAsync(ulong ns,Cursor? cursor=null,CancellationToken cancellation=default) {
            var action=V.Obj(("page",V.Obj(("namespace",Turn.Decimal(Positive(ns))),("cursor",cursor?.Opaque))));
            return worker.Invoke(b => { var v=V.Object(b.UnifiedQuery(action)["page"]); return new Page(ParseManifest(v["manifest"],connection.Source.Realm),Array(v["columns"],128).Select(Column.Parse).ToArray(),NativeValues.Wide(v["ordinal"]),checked((byte)V.Number(v["rows"])),Encoded(v["ipc"],65536),v["next"] is null?null:new Cursor(V.String(v["next"]))); },cancellation);
        }
        public async ValueTask DisposeAsync() { try { await worker.CloseAsync().ConfigureAwait(false); }finally { worker.CloseSnapshot(); } }
    }
}
