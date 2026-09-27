using System.Buffers.Binary;
using System.Text;
using System.Text.Json.Nodes;
using Transit.Client;
using Transit.Client.Internal;
using Transit.Station.Sdk.Internal;
using StationBridge = Transit.Station.Sdk.Internal.Bridge;
using StationApi = Transit.Station.Sdk.Internal.NativeApi;

namespace Transit.Station.Sdk;
internal interface IDocumentOwner
{
    Task<R> DocumentAccess<R>(Func<StationBridge,R> action, CancellationToken cancellation = default);
}
/// <summary>Owned Document types over the shared Zig codecs and merge implementation.</summary>
public static class Document
{
    private static ulong Positive(ulong value) => value == 0 ? throw new ArgumentException("Expected nonzero Document identity") : value;
    private static string Hex(Bytes value) => Value.Hex(value.Copy());
    private static IReadOnlyList<T> Copy<T>(IReadOnlyList<T> values, int bound)
    {
        ArgumentNullException.ThrowIfNull(values); if(values.Count>bound) throw new ArgumentException("Document collection exceeds its bound");
        T[] outValues=values.ToArray(); foreach(T value in outValues) ArgumentNullException.ThrowIfNull(value); return System.Array.AsReadOnly(outValues);
    }
    private static JsonArray Array(JsonNode? value,int bound)
    {
        if(value is not JsonArray array || array.Count>bound) throw Value.Incompatible("document-array"); return array;
    }
    public readonly record struct Dot(ulong Counter,ulong Replica)
    {
        public static Dot Root => default;
        internal JsonObject Wire() { if((Counter==0)!=(Replica==0)) throw new ArgumentException("Invalid Document dot"); return Value.Obj(("counter",Turn.Decimal(Counter)),("replica",Turn.Decimal(Replica))); }
        internal static Dot Parse(JsonNode? value) { var v=Value.Object(value); Dot outValue=new(NativeValues.Wide(v["counter"]),NativeValues.Wide(v["replica"])); outValue.Wire(); return outValue; }
    }
    public abstract record Scalar { private protected Scalar() {} }
    public sealed record NullValue : Scalar;
    public sealed record BooleanValue(bool Value) : Scalar;
    public sealed record Signed(long Value) : Scalar;
    public sealed record Unsigned(ulong Value) : Scalar;
    public sealed record Floating : Scalar
    {
        public double Value { get; }
        public Floating(double value) { if(!double.IsFinite(value)) throw new ArgumentException("Expected finite Document number"); Value=value; }
    }
    public sealed record StringValue : Scalar
    {
        public string Value { get; }
        public StringValue(string value) { Value=Client.Internal.Value.Text(value,96); }
    }
    public sealed record Binary : Scalar
    {
        public Bytes Value { get; }
        public Binary(Bytes value) { ArgumentNullException.ThrowIfNull(value); if(value.Length>96) throw new ArgumentException("Oversized Document binary"); Value=value; }
    }
    public enum ContainerKind { Map,List,Text }
    public sealed record Container(ContainerKind Kind) : Scalar;
    public sealed record CharacterValue(Rune Value) : Scalar;
    private static JsonObject Wire(Scalar value) => value switch {
        NullValue => Value.Obj(("null_value",Value.Obj())), BooleanValue v => Value.Obj(("boolean",v.Value)),
        Signed v => Value.Obj(("signed",Turn.Decimal(v.Value))), Unsigned v => Value.Obj(("unsigned",Turn.Decimal(v.Value))),
        Floating v => Value.Obj(("float_bits",FloatHex(v.Value))), StringValue v => Value.Obj(("string",v.Value)), Binary v => Value.Obj(("binary",Hex(v.Value))),
        Container { Kind:ContainerKind.Map } => Value.Obj(("map",Value.Obj())), Container { Kind:ContainerKind.List } => Value.Obj(("list",Value.Obj())), Container { Kind:ContainerKind.Text } => Value.Obj(("text",Value.Obj())),
        CharacterValue v => Value.Obj(("character",v.Value.ToString())), _ => throw new ArgumentException("Invalid Document scalar")
    };
    private static string FloatHex(double value) { byte[] bytes=new byte[8]; BinaryPrimitives.WriteDoubleLittleEndian(bytes,value); return Value.Hex(bytes); }
    private static Scalar ScalarValue(JsonNode? value)
    {
        var v=Value.Object(value); if(v.Count!=1) throw Value.Incompatible("document-scalar"); var item=v.Single();
        return item.Key switch {
            "null_value" => new NullValue(), "boolean" => new BooleanValue(Value.Boolean(item.Value)), "signed" => new Signed(NativeValues.Signed(item.Value)), "unsigned" => new Unsigned(NativeValues.Wide(item.Value)),
            "float_bits" => ParseFloat(item.Value), "string" => new StringValue(Value.String(item.Value)), "binary" => new Binary(new Bytes(Value.Unhex(item.Value,96))),
            "map" => new Container(ContainerKind.Map), "list" => new Container(ContainerKind.List), "text" => new Container(ContainerKind.Text), "character" => ParseCharacter(item.Value),
            _ => throw Value.Incompatible("document-scalar")
        };
    }
    private static Floating ParseFloat(JsonNode? value) { byte[] bytes=Value.Unhex(value,8); if(bytes.Length!=8) throw Value.Incompatible("document-float"); return new(BinaryPrimitives.ReadDoubleLittleEndian(bytes)); }
    private static CharacterValue ParseCharacter(JsonNode? value) { string text=Value.Text(Value.String(value),4); Rune[] runes=text.EnumerateRunes().ToArray(); if(runes.Length!=1) throw Value.Incompatible("document-character"); return new(runes[0]); }
    public abstract record Operation { private protected Operation() {} }
    public sealed record Assign : Operation
    {
        public Dot Object { get; } public string Field { get; } public IReadOnlyList<Dot> Observed { get; } public Scalar Value { get; }
        public Assign(Dot obj,string field,IReadOnlyList<Dot> observed,Scalar value) { Object=obj; Field=Client.Internal.Value.Text(field,64); Observed=Copy(observed,8); ArgumentNullException.ThrowIfNull(value); Value=value; }
    }
    public sealed record Remove : Operation
    {
        public Dot Object { get; } public string Field { get; } public IReadOnlyList<Dot> Observed { get; }
        public Remove(Dot obj,string field,IReadOnlyList<Dot> observed) { Object=obj; Field=Value.Text(field,64); Observed=Copy(observed,8); }
    }
    public sealed record Insert : Operation
    {
        public Dot Object { get; } public Dot After { get; } public Scalar Value { get; }
        public Insert(Dot obj,Dot after,Scalar value) { Object=obj; After=after; ArgumentNullException.ThrowIfNull(value); Value=value; }
    }
    public sealed record SetElement : Operation
    {
        public Dot Object { get; } public Dot Element { get; } public IReadOnlyList<Dot> Observed { get; } public Scalar Value { get; }
        public SetElement(Dot obj,Dot element,IReadOnlyList<Dot> observed,Scalar value) { Object=obj; Element=element; Observed=Copy(observed,8); ArgumentNullException.ThrowIfNull(value); Value=value; }
    }
    public sealed record DeleteElement(Dot Object,Dot Element) : Operation;
    private static JsonArray Dots(IReadOnlyList<Dot> dots) { JsonArray outValues=new(); foreach(var dot in dots) outValues.Add(dot.Wire()); return outValues; }
    private static IReadOnlyList<Dot> ParsedDots(JsonNode? value) => System.Array.AsReadOnly(Array(value,8).Select(Dot.Parse).ToArray());
    private static JsonObject Wire(Operation value) => value switch {
        Assign v => Value.Obj(("assign",Value.Obj(("object",v.Object.Wire()),("field",v.Field),("observed",Dots(v.Observed)),("value",Wire(v.Value))))),
        Remove v => Value.Obj(("remove",Value.Obj(("object",v.Object.Wire()),("field",v.Field),("observed",Dots(v.Observed))))),
        Insert v => Value.Obj(("insert",Value.Obj(("object",v.Object.Wire()),("after",v.After.Wire()),("value",Wire(v.Value))))),
        SetElement v => Value.Obj(("set_element",Value.Obj(("object",v.Object.Wire()),("element",v.Element.Wire()),("observed",Dots(v.Observed)),("value",Wire(v.Value))))),
        DeleteElement v => Value.Obj(("delete_element",Value.Obj(("object",v.Object.Wire()),("element",v.Element.Wire())))),
        _ => throw new ArgumentException("Invalid Document operation")
    };
    private static Operation ParseOperation(JsonNode? value)
    {
        var op=Value.Object(value); if(op.Count!=1) throw Value.Incompatible("document-operation"); var entry=op.Single(); var v=Value.Object(entry.Value); var obj=Dot.Parse(v["object"]);
        return entry.Key switch {
            "assign" => new Assign(obj,Value.String(v["field"]),ParsedDots(v["observed"]),ScalarValue(v["value"])), "remove" => new Remove(obj,Value.String(v["field"]),ParsedDots(v["observed"])),
            "insert" => new Insert(obj,Dot.Parse(v["after"]),ScalarValue(v["value"])), "set_element" => new SetElement(obj,Dot.Parse(v["element"]),ParsedDots(v["observed"]),ScalarValue(v["value"])),
            "delete_element" => new DeleteElement(obj,Dot.Parse(v["element"])), _ => throw Value.Incompatible("document-operation")
        };
    }
    public sealed record Change
    {
        public ulong DocumentId { get; } public ulong Epoch { get; } public uint TypeRevision { get; } public ulong Replica { get; } public ulong Previous { get; } public ulong First { get; } public IReadOnlyList<Operation> Operations { get; }
        public Change(ulong document,ulong epoch,uint typeRevision,ulong replica,ulong previous,ulong first,IReadOnlyList<Operation> operations) {
            DocumentId=Positive(document); Epoch=Positive(epoch); TypeRevision=typeRevision; Replica=Positive(replica); Previous=previous; First=Positive(first); Operations=Copy(operations,8); if(Operations.Count==0) throw new ArgumentException("Empty Document change");
        }
        internal JsonObject Wire() { JsonArray ops=new(); foreach(var op in Operations) ops.Add(Document.Wire(op)); return Value.Obj(("document",Turn.Decimal(DocumentId)),("epoch",Turn.Decimal(Epoch)),("type_revision",TypeRevision),("replica",Turn.Decimal(Replica)),("previous",Turn.Decimal(Previous)),("first",Turn.Decimal(First)),("operations",ops)); }
        internal static Change Parse(JsonNode? value) { var v=Value.Object(value); return new(NativeValues.Wide(v["document"]),NativeValues.Wide(v["epoch"]),checked((uint)Value.Number(v["type_revision"],1)),NativeValues.Wide(v["replica"]),NativeValues.Wide(v["previous"]),NativeValues.Wide(v["first"]),Array(v["operations"],8).Select(ParseOperation).ToArray()); }
    }
    public sealed class Prepared
    {
        public ulong DocumentId { get; } public Bytes Bytes { get; }
        internal Prepared(ulong document,Bytes bytes) { DocumentId=document; Bytes=bytes; }
    }
    private static async Task<JsonObject> LocalAsync(JsonObject action,string? directory)
    {
        var worker=await Worker<StationBridge,object?>.OpenAsync(() => new StationBridge(directory),StationApi.MinimumStackBytes).ConfigureAwait(false);
        try { return await worker.Invoke(bridge => bridge.DocumentCodec(action)).ConfigureAwait(false); }
        finally { await worker.CloseAsync().ConfigureAwait(false); }
    }
    public static async Task<Prepared> PrepareAsync(Change change,string? nativeDirectory=null) {
        JsonObject outValue=await LocalAsync(Value.Obj(("prepare",change.Wire())),nativeDirectory).ConfigureAwait(false); return new(change.DocumentId,new Bytes(Value.Unhex(Value.Object(outValue["prepared"])["bytes"],4096)));
    }
    public static async Task<Change> DecodeAsync(byte[] bytes,string? nativeDirectory=null) {
        string data=Value.Hex(Value.Bytes(bytes,4096)); return Change.Parse((await LocalAsync(Value.Obj(("decode",data)),nativeDirectory).ConfigureAwait(false))["change"]);
    }
    public sealed class Reference
    {
        public ResourceRef Resource { get; } public ulong DocumentId { get; } public ulong Epoch { get; } public uint TypeRevision { get; } public ulong Revision { get; } public Bytes Bytes { get; }
        internal Reference(ulong realm,Bytes bytes,JsonObject value) {
            if(bytes.Length!=40) throw Value.Incompatible("document-reference"); Bytes=bytes; Resource=new(realm,Value.Number(value["resource"],1)); DocumentId=NativeValues.Wide(value["document"],true); Epoch=NativeValues.Wide(value["epoch"],true); TypeRevision=checked((uint)Value.Number(value["type_revision"],1)); Revision=NativeValues.Wide(value["revision"]);
        }
        public static async Task<Reference> DecodeAsync(ulong realm,byte[] bytes,string? nativeDirectory=null) {
            Value.Counter(realm); Bytes owned=new(Value.Bytes(bytes,40)); var response=await LocalAsync(Value.Obj(("inspect_reference",Hex(owned))),nativeDirectory).ConfigureAwait(false); return new(realm,owned,Value.Object(response["inspected_reference"]));
        }
    }
    public enum Status { Missing,Null,Scalar,Object,Conflict }
    public sealed record Assignment(Dot Id,Scalar Value);
    public sealed record Field
    {
        public Status Status { get; } public IReadOnlyList<Assignment> Assignments { get; }
        internal Field(Status status,IReadOnlyList<Assignment> assignments) { Status=status; Assignments=Copy(assignments,8); if((status==Status.Missing)!=(assignments.Count==0) || (status==Status.Conflict)!=(assignments.Count>1)) throw Value.Incompatible("document-register"); }
        public IReadOnlyList<Dot> Observed() => System.Array.AsReadOnly(Assignments.Select(v => v.Id).ToArray());
        internal static Field Parse(JsonNode? value) {
            var v=Value.Object(value); Status status=Value.String(v["status"]) switch { "missing"=>Status.Missing,"null_value"=>Status.Null,"scalar"=>Status.Scalar,"object"=>Status.Object,"conflict"=>Status.Conflict,_=>throw Value.Incompatible("document-status") };
            return new(status,Array(v["assignments"],8).Select(item => { var a=Value.Object(item); return new Assignment(Dot.Parse(a["id"]),ScalarValue(a["value"])); }).ToArray());
        }
    }
    public sealed record Description(Reference Reference,ulong SourceRevision,ulong Floor,ulong MergeWindow,ulong ActiveJob,bool Retired,uint ChangeFormat);
    public sealed record PathValue(Reference Reference,ulong SourceRevision,Field Field);
    public sealed record Item(Dot Id,Field Field);
    public sealed record Page
    {
        public Reference Reference { get; } public ulong SourceRevision { get; } public IReadOnlyList<Item> Items { get; } public string? Next { get; }
        internal Page(Reference reference,ulong revision,IReadOnlyList<Item> items,string? next) { Reference=reference; SourceRevision=revision; Items=Copy(items,8); Next=next is null?null:Value.Text(next,1024); }
    }
    public sealed record Resynchronization(Reference Reference,ulong Floor,ulong Replica,ulong PreviousCounter,ulong Clock);
    public enum Phase { Progress,Accepted,Duplicate,CheckpointComplete }
    public readonly record struct Progress(Phase Phase,ulong? Revision)
    {
        internal static Progress Parse(JsonNode? value) { var v=Value.Object(value); Phase phase=Value.String(v["phase"]) switch { "progress"=>Phase.Progress,"accepted"=>Phase.Accepted,"duplicate"=>Phase.Duplicate,"checkpoint_complete"=>Phase.CheckpointComplete,_=>throw Value.Incompatible("document-progress") }; ulong? revision=v["revision"] is null?null:NativeValues.Wide(v["revision"]); if((phase==Phase.Progress)!=!revision.HasValue) throw Value.Incompatible("document-progress"); return new(phase,revision); }
    }
    public sealed record Limits(uint RecordBytes=4096,ulong StagingBytes=8192,uint StagingRecords=2);
    public sealed class Owner
    {
        private readonly Turn turn; private readonly ulong document;
        internal Owner(Turn turn,ulong document) { this.turn=turn; this.document=Positive(document); }
        private R Apply<R>(JsonObject action,Func<JsonObject,R> decode) => turn.Access(false,() => { turn.Bridge.HttpCapability("document_owner"); return decode(Value.Object(turn.Raw(Value.Obj(("document",action)))["document"])); });
        private JsonObject Job(ulong job) => Value.Obj(("document",Turn.Decimal(document)),("job",Turn.Decimal(Positive(job))));
        public void Create(uint typeRevision,Limits? limits=null) { limits??=new(); Apply(Value.Obj(("create",Value.Obj(("document",Turn.Decimal(document)),("type_revision",typeRevision),("record_bytes",limits.RecordBytes),("staging_bytes",Turn.Decimal(limits.StagingBytes)),("staging_records",limits.StagingRecords)))),v => true); }
        public Progress Stage(ulong job,Prepared change,uint nodeLimit=512) { if(change.DocumentId!=document) throw new ArgumentException("Different Document"); var args=Job(job); args["change"]=Hex(change.Bytes); args["node_limit"]=nodeLimit; return Apply(Value.Obj(("stage",args)),v => Progress.Parse(v["progress"])); }
        public Progress Checkpoint(ulong job) => Apply(Value.Obj(("checkpoint",Job(job))),v => Progress.Parse(v["progress"]));
        public void MergeWindow(ulong revisions) => Apply(Value.Obj(("merge_window",Value.Obj(("document",Turn.Decimal(document)),("revisions",Turn.Decimal(revisions))))),v => true);
        public void Reject(ulong job,bool checkpoint=false) { var args=Job(job); args["checkpoint"]=checkpoint; Apply(Value.Obj(("reject",args)),v => true); }
        public bool Collect(ulong job,bool checkpoint=false,bool retired=false) { var args=Job(job); args["checkpoint"]=checkpoint; args["retired"]=retired; return Apply(Value.Obj(("collect",args)),v => Value.Boolean(v["collected"])); }
        public void Retire() => Apply(Value.Obj(("retire",Turn.Decimal(document))),v => true);
    }
    public sealed class Reader
    {
        private readonly IDocumentOwner owner; private readonly ulong realm;
        internal Reader(IDocumentOwner owner,ulong realm) { this.owner=owner; this.realm=realm; }
        private JsonObject Identity(ResourceRef resource,ulong document) { if(resource.Realm!=realm) throw new ArgumentException("Different realm"); return Value.Obj(("resource",resource.Resource),("document",Turn.Decimal(Positive(document)))); }
        private string Encoded(Reference reference) { if(reference.Resource.Realm!=realm) throw new ArgumentException("Different realm"); return Hex(reference.Bytes); }
        private Reference ParseReference(StationBridge bridge,JsonNode? value) { Bytes bytes=new(Value.Unhex(value,40)); return new(realm,bytes,Value.Object(bridge.DocumentCodec(Value.Obj(("inspect_reference",Hex(bytes))))["inspected_reference"])); }
        public Task<Description> DescribeAsync(ResourceRef resource,ulong document,CancellationToken cancellation=default) {
            var action=Value.Obj(("describe",Identity(resource,document))); return owner.DocumentAccess(bridge => { var v=Value.Object(bridge.DocumentRead(action)["description"]); return new Description(ParseReference(bridge,v["reference"]),Value.Number(v["source_revision"]),NativeValues.Wide(v["floor"]),NativeValues.Wide(v["merge_window"]),NativeValues.Wide(v["active_job"]),Value.Boolean(v["retired"]),checked((uint)Value.Number(v["change_format"],1))); },cancellation);
        }
        public Task<PathValue> PathAsync(Reference reference,IReadOnlyList<string> names,CancellationToken cancellation=default) {
            var path=Copy(names,16); if(path.Count==0) throw new ArgumentException("Empty Document path"); JsonArray array=new(); foreach(string name in path) array.Add(Value.Text(name,64)); string encoded=Encoded(reference); var action=Value.Obj(("path",Value.Obj(("reference",encoded),("names",array))));
            return owner.DocumentAccess(bridge => { var v=Value.Object(bridge.DocumentRead(action)["field"]); if(Value.String(v["reference"])!=encoded) throw Value.Incompatible("document-reference"); return new PathValue(reference,Value.Number(v["source_revision"]),Field.Parse(v["value"])); },cancellation);
        }
        public Task<Page> SequenceAsync(Reference reference,Dot obj,string? cursor=null,CancellationToken cancellation=default) {
            if(cursor is not null) Value.Text(cursor,1024); string encoded=Encoded(reference); var action=Value.Obj(("sequence",Value.Obj(("reference",encoded),("object",obj.Wire()),("cursor",cursor))));
            return owner.DocumentAccess(bridge => { var v=Value.Object(bridge.DocumentRead(action)["page"]); if(Value.String(v["reference"])!=encoded) throw Value.Incompatible("document-reference"); var items=Array(v["items"],8).Select(item => { var i=Value.Object(item); return new Item(Dot.Parse(i["id"]),Field.Parse(i["values"])); }).ToArray(); return new Page(reference,Value.Number(v["source_revision"]),items,v["next"] is null?null:Value.String(v["next"])); },cancellation);
        }
        public Task<Resynchronization> ResynchronizeAsync(ResourceRef resource,ulong document,ulong replica,CancellationToken cancellation=default) {
            var action=Value.Obj(("resynchronize",Value.Obj(("identity",Identity(resource,document)),("replica",Turn.Decimal(Positive(replica))))));
            return owner.DocumentAccess(bridge => { var v=Value.Object(bridge.DocumentRead(action)["resynchronization"]); return new Resynchronization(ParseReference(bridge,v["reference"]),NativeValues.Wide(v["floor"]),NativeValues.Wide(v["replica"]),NativeValues.Wide(v["previous_counter"]),NativeValues.Wide(v["clock"])); },cancellation);
        }
        public Task<Change> AcceptedChangeAsync(Reference reference,CancellationToken cancellation=default) { var action=Value.Obj(("accepted_change",Encoded(reference))); return owner.DocumentAccess(bridge => Change.Parse(bridge.DocumentRead(action)["change"]),cancellation); }
    }
}
