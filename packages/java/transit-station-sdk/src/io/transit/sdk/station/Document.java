package io.transit.sdk.station;

import com.google.gson.*;
import io.transit.client.*;
import io.transit.client.internal.Worker;
import static io.transit.client.internal.Values.*;
import java.math.BigInteger;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.file.Path;
import java.util.*;
import java.util.concurrent.CompletableFuture;

/** Owned Document values. Shared Zig owns codecs, CRDTs, publication and reads. */
public final class Document {
    private Document() {}
    private static BigInteger positive(BigInteger n) { u64(n); if(n.signum()==0) throw new IllegalArgumentException("Expected nonzero Document identity"); return n; }
    private static long uint32(long n) { if(n<0 || n>0xffffffffL) throw new IllegalArgumentException("Expected u32"); return n; }
    private static String hex(Bytes b) { return HexFormat.of().formatHex(b.copy()); }
    private static BigInteger wide(JsonElement v) { return NativeValues.wide(v,false); }
    private static JsonObject local(JsonObject action,Path host) {
        try(Worker<Bridge,Void> worker=new Worker<>(() -> Bridge.local(host))) { return Worker.await(worker.submit(bridge -> bridge.documentCodec(action))); }
    }
    public record Dot(BigInteger counter,BigInteger replica) {
        public static final Dot ROOT=new Dot(BigInteger.ZERO,BigInteger.ZERO);
        public Dot { u64(counter); u64(replica); if((counter.signum()==0)!=(replica.signum()==0)) throw new IllegalArgumentException("Invalid dot"); }
        JsonObject wire() { return obj("counter",counter.toString(),"replica",replica.toString()); }
        static Dot parse(JsonElement v) { JsonObject o=object(v); return new Dot(wide(o.get("counter")),wide(o.get("replica"))); }
    }
    public sealed interface Value permits NullValue, BooleanValue, Signed, Unsigned, Floating, StringValue, Binary, Container, CharacterValue {}
    public record NullValue() implements Value {}
    public record BooleanValue(boolean value) implements Value {}
    public record Signed(long value) implements Value {}
    public record Unsigned(BigInteger value) implements Value { public Unsigned { u64(value); } }
    public record Floating(double value) implements Value { public Floating { if(!Double.isFinite(value)) throw new IllegalArgumentException("Non-finite Document number"); } }
    public record StringValue(String value) implements Value { public StringValue { text(value,96); } }
    public record Binary(Bytes value) implements Value { public Binary { Objects.requireNonNull(value); if(value.size()>96) throw new IllegalArgumentException("Oversized Document binary"); } }
    public enum Container implements Value { MAP, LIST, TEXT }
    public record CharacterValue(int codePoint) implements Value {
        public CharacterValue { if(!Character.isValidCodePoint(codePoint) || (codePoint>=0xd800 && codePoint<=0xdfff)) throw new IllegalArgumentException("Expected Unicode scalar"); }
    }
    private static JsonObject wire(Value value) {
        return switch(value) {
            case NullValue ignored -> obj("null_value",obj());
            case BooleanValue v -> obj("boolean",v.value());
            case Signed v -> obj("signed",Long.toString(v.value()));
            case Unsigned v -> obj("unsigned",v.value().toString());
            case Floating v -> obj("float_bits",HexFormat.of().formatHex(ByteBuffer.allocate(8).order(ByteOrder.LITTLE_ENDIAN).putDouble(v.value()).array()));
            case StringValue v -> obj("string",v.value());
            case Binary v -> obj("binary",hex(v.value()));
            case Container v -> obj(v.name().toLowerCase(Locale.ROOT),obj());
            case CharacterValue v -> obj("character",new String(Character.toChars(v.codePoint())));
        };
    }
    private static Value scalar(JsonElement value) {
        JsonObject v=object(value); if(v.size()!=1) throw incompatible("document-scalar");
        var entry=v.entrySet().iterator().next(); JsonElement data=entry.getValue();
        return switch(entry.getKey()) {
            case "null_value" -> new NullValue(); case "boolean" -> new BooleanValue(bool(data));
            case "signed" -> { String text=string(data); long n=Long.parseLong(text); if(!Long.toString(n).equals(text)) throw incompatible("document-signed"); yield new Signed(n); }
            case "unsigned" -> new Unsigned(wide(data));
            case "float_bits" -> { byte[] b=unhex(data,8); if(b.length!=8) throw incompatible("document-float"); yield new Floating(ByteBuffer.wrap(b).order(ByteOrder.LITTLE_ENDIAN).getDouble()); }
            case "string" -> new StringValue(string(data)); case "binary" -> new Binary(new Bytes(unhex(data,96)));
            case "map" -> Container.MAP; case "list" -> Container.LIST; case "text" -> Container.TEXT;
            case "character" -> { String s=text(string(data),4); if(s.codePointCount(0,s.length())!=1) throw incompatible("document-character"); yield new CharacterValue(s.codePointAt(0)); }
            default -> throw incompatible("document-scalar");
        };
    }
    private static List<Dot> observed(List<Dot> dots) { dots=List.copyOf(dots); if(dots.size()>8) throw new IllegalArgumentException("Too many observed assignments"); return dots; }
    private static JsonArray dots(List<Dot> dots) { JsonArray out=new JsonArray(); dots.forEach(v -> out.add(v.wire())); return out; }
    private static List<JsonElement> elements(JsonElement v,int bound) {
        if(v==null || !v.isJsonArray() || v.getAsJsonArray().size()>bound) throw incompatible("document-array"); return v.getAsJsonArray().asList();
    }
    private static List<Dot> parsedDots(JsonElement v) { return elements(v,8).stream().map(Dot::parse).toList(); }
    public sealed interface Operation permits Assign, Remove, Insert, SetElement, DeleteElement {}
    public record Assign(Dot object,String field,List<Dot> observed,Value value) implements Operation {
        public Assign { Objects.requireNonNull(object); text(field,64); observed=Document.observed(observed); Objects.requireNonNull(value); }
    }
    public record Remove(Dot object,String field,List<Dot> observed) implements Operation {
        public Remove { Objects.requireNonNull(object); text(field,64); observed=Document.observed(observed); }
    }
    public record Insert(Dot object,Dot after,Value value) implements Operation {
        public Insert { Objects.requireNonNull(object); Objects.requireNonNull(after); Objects.requireNonNull(value); }
    }
    public record SetElement(Dot object,Dot element,List<Dot> observed,Value value) implements Operation {
        public SetElement { Objects.requireNonNull(object); Objects.requireNonNull(element); observed=Document.observed(observed); Objects.requireNonNull(value); }
    }
    public record DeleteElement(Dot object,Dot element) implements Operation {
        public DeleteElement { Objects.requireNonNull(object); Objects.requireNonNull(element); }
    }
    private static JsonObject wire(Operation op) {
        return switch(op) {
            case Assign v -> obj("assign",obj("object",v.object().wire(),"field",v.field(),"observed",dots(v.observed()),"value",wire(v.value())));
            case Remove v -> obj("remove",obj("object",v.object().wire(),"field",v.field(),"observed",dots(v.observed())));
            case Insert v -> obj("insert",obj("object",v.object().wire(),"after",v.after().wire(),"value",wire(v.value())));
            case SetElement v -> obj("set_element",obj("object",v.object().wire(),"element",v.element().wire(),"observed",dots(v.observed()),"value",wire(v.value())));
            case DeleteElement v -> obj("delete_element",obj("object",v.object().wire(),"element",v.element().wire()));
        };
    }
    private static Operation operation(JsonElement value) {
        JsonObject out=object(value); if(out.size()!=1) throw incompatible("document-operation"); var entry=out.entrySet().iterator().next(); JsonObject v=object(entry.getValue()); Dot object=Dot.parse(v.get("object"));
        return switch(entry.getKey()) {
            case "assign" -> new Assign(object,string(v.get("field")),parsedDots(v.get("observed")),scalar(v.get("value")));
            case "remove" -> new Remove(object,string(v.get("field")),parsedDots(v.get("observed")));
            case "insert" -> new Insert(object,Dot.parse(v.get("after")),scalar(v.get("value")));
            case "set_element" -> new SetElement(object,Dot.parse(v.get("element")),parsedDots(v.get("observed")),scalar(v.get("value")));
            case "delete_element" -> new DeleteElement(object,Dot.parse(v.get("element")));
            default -> throw incompatible("document-operation");
        };
    }
    public record Change(BigInteger document,BigInteger epoch,long typeRevision,BigInteger replica,BigInteger previous,BigInteger first,List<Operation> operations) {
        public Change { positive(document); positive(epoch); uint32(typeRevision); positive(replica); u64(previous); positive(first); operations=List.copyOf(operations); if(operations.isEmpty() || operations.size()>8) throw new IllegalArgumentException("Expected 1..8 Document operations"); }
        JsonObject wire() { JsonArray ops=new JsonArray(); operations.forEach(v -> ops.add(Document.wire(v))); return obj("document",document.toString(),"epoch",epoch.toString(),"type_revision",typeRevision,"replica",replica.toString(),"previous",previous.toString(),"first",first.toString(),"operations",ops); }
        static Change parse(JsonElement value) { JsonObject v=object(value); return new Change(wide(v.get("document")),wide(v.get("epoch")),number(v.get("type_revision"),1),wide(v.get("replica")),wide(v.get("previous")),wide(v.get("first")),elements(v.get("operations"),8).stream().map(Document::operation).toList()); }
    }
    public static final class Prepared {
        private final BigInteger document; private final Bytes bytes;
        private Prepared(BigInteger document,Bytes bytes) { this.document=document; this.bytes=bytes; }
        public BigInteger document() { return document; } public Bytes bytes() { return bytes; }
    }
    public static Prepared prepare(Change change) { return prepare(change,null); }
    public static Prepared prepare(Change change,Path nativeHost) { JsonObject v=object(local(obj("prepare",change.wire()),nativeHost).get("prepared")); return new Prepared(change.document(),new Bytes(unhex(v.get("bytes"),4096))); }
    public static Change decode(byte[] bytes) { return decode(bytes,null); }
    public static Change decode(byte[] bytes,Path nativeHost) { return Change.parse(local(obj("decode",HexFormat.of().formatHex(bytes(bytes,4096))),nativeHost).get("change")); }
    public static final class Reference {
        private final ResourceRef resource; private final BigInteger document,epoch,revision; private final long typeRevision; private final Bytes bytes;
        private Reference(long realm,Bytes bytes,JsonObject v) { if(bytes.size()!=40) throw incompatible("document-reference"); this.bytes=bytes; resource=new ResourceRef(realm,number(v.get("resource"),1)); document=positive(wide(v.get("document"))); epoch=positive(wide(v.get("epoch"))); typeRevision=uint32(number(v.get("type_revision"),1)); revision=wide(v.get("revision")); }
        public ResourceRef resource() { return resource; } public BigInteger document() { return document; } public BigInteger epoch() { return epoch; } public long typeRevision() { return typeRevision; } public BigInteger revision() { return revision; } public Bytes bytes() { return bytes; }
        public static Reference decode(long realm,byte[] bytes) { return decode(realm,bytes,null); }
        public static Reference decode(long realm,byte[] bytes,Path nativeHost) { counter(realm,1); Bytes owned=new Bytes(io.transit.client.internal.Values.bytes(bytes,40)); return new Reference(realm,owned,object(local(obj("inspect_reference",hex(owned)),nativeHost).get("inspected_reference"))); }
    }
    public enum Status { MISSING, NULL_VALUE, SCALAR, OBJECT, CONFLICT }
    public record Assignment(Dot id,Value value) { public Assignment { Objects.requireNonNull(id); Objects.requireNonNull(value); } }
    public record Field(Status status,List<Assignment> assignments) {
        public Field { Objects.requireNonNull(status); assignments=List.copyOf(assignments); if(assignments.size()>8 || (status==Status.MISSING)!=assignments.isEmpty() || (status==Status.CONFLICT)!=(assignments.size()>1)) throw incompatible("document-register"); }
        public List<Dot> observed() { return assignments.stream().map(Assignment::id).toList(); }
        static Field parse(JsonElement value) { JsonObject v=object(value); return new Field(Status.valueOf(string(v.get("status")).toUpperCase(Locale.ROOT)),elements(v.get("assignments"),8).stream().map(item -> { JsonObject a=object(item); return new Assignment(Dot.parse(a.get("id")),scalar(a.get("value"))); }).toList()); }
    }
    public record Description(Reference reference,long sourceRevision,BigInteger floor,BigInteger mergeWindow,BigInteger activeJob,boolean retired,long changeFormat) {}
    public record PathValue(Reference reference,long sourceRevision,Field field) {}
    public record Item(Dot id,Field field) {}
    public record Page(Reference reference,long sourceRevision,List<Item> items,Optional<String> next) { public Page { items=List.copyOf(items); if(items.size()>8) throw incompatible("document-page"); next.ifPresent(v -> text(v,1024)); } }
    public record Resynchronization(Reference reference,BigInteger floor,BigInteger replica,BigInteger previousCounter,BigInteger clock) {}
    public enum Phase { PROGRESS, ACCEPTED, DUPLICATE, CHECKPOINT_COMPLETE }
    public record Progress(Phase phase,Optional<BigInteger> revision) {
        public Progress { Objects.requireNonNull(phase); Objects.requireNonNull(revision); if((phase==Phase.PROGRESS)!=revision.isEmpty()) throw incompatible("document-progress"); revision.ifPresent(v -> u64(v)); }
        static Progress parse(JsonElement value) { JsonObject v=object(value); return new Progress(Phase.valueOf(string(v.get("phase")).toUpperCase(Locale.ROOT)),v.get("revision").isJsonNull()?Optional.empty():Optional.of(wide(v.get("revision")))); }
    }
    public record Limits(long recordBytes,BigInteger stagingBytes,long stagingRecords) {
        public static final Limits DEFAULT=new Limits(4096,BigInteger.valueOf(8192),2);
        public Limits { uint32(recordBytes); u64(stagingBytes); uint32(stagingRecords); }
    }
    public static final class Owner {
        private final Turn turn; private final BigInteger document;
        Owner(Turn turn,BigInteger document) { this.turn=turn; this.document=positive(document); }
        private <T> T apply(JsonObject action,java.util.function.Function<JsonObject,T> decode) {
            return turn.access(false,() -> { turn.bridge.httpCapability("document_owner"); return decode.apply(object(turn.raw(obj("document",action)).get("document"))); });
        }
        private JsonObject job(BigInteger job) { return obj("document",document.toString(),"job",positive(job).toString()); }
        public void create(long typeRevision) { create(typeRevision,Limits.DEFAULT); }
        public void create(long typeRevision,Limits limits) { apply(obj("create",obj("document",document.toString(),"type_revision",uint32(typeRevision),"record_bytes",limits.recordBytes(),"staging_bytes",limits.stagingBytes().toString(),"staging_records",limits.stagingRecords())),v -> null); }
        public Progress stage(BigInteger job,Prepared change,long nodeLimit) { if(!change.document().equals(document)) throw new IllegalArgumentException("Different Document"); JsonObject args=job(job); args.addProperty("change",hex(change.bytes())); args.addProperty("node_limit",uint32(nodeLimit)); return apply(obj("stage",args),v -> Progress.parse(v.get("progress"))); }
        public Progress checkpoint(BigInteger job) { return apply(obj("checkpoint",job(job)),v -> Progress.parse(v.get("progress"))); }
        public void mergeWindow(BigInteger revisions) { apply(obj("merge_window",obj("document",document.toString(),"revisions",u64(revisions).toString())),v -> null); }
        public void reject(BigInteger job,boolean checkpoint) { JsonObject args=job(job); args.addProperty("checkpoint",checkpoint); apply(obj("reject",args),v -> null); }
        public boolean collect(BigInteger job,boolean checkpoint,boolean retired) { JsonObject args=job(job); args.addProperty("checkpoint",checkpoint); args.addProperty("retired",retired); return apply(obj("collect",args),v -> bool(v.get("collected"))); }
        public void retire() { apply(obj("retire",document.toString()),v -> null); }
    }
    /** Stateless reader facade; operations and close serialize on the runner. */
    public static final class Reader {
        private final Runner<?> runner; private final long realm;
        Reader(Runner<?> runner,long realm) { this.runner=runner; this.realm=realm; }
        private JsonObject identity(ResourceRef resource,BigInteger document) { if(resource.realm()!=realm) throw new IllegalArgumentException("Different realm"); return obj("resource",resource.resource(),"document",positive(document).toString()); }
        private String encoded(Reference reference) { if(reference.resource().realm()!=realm) throw new IllegalArgumentException("Different realm"); return hex(reference.bytes()); }
        private Reference reference(Bridge bridge,JsonElement value) { Bytes bytes=new Bytes(unhex(value,40)); return new Reference(realm,bytes,object(bridge.documentCodec(obj("inspect_reference",hex(bytes))).get("inspected_reference"))); }
        public CompletableFuture<Description> describe(ResourceRef resource,BigInteger document) {
            JsonObject action=obj("describe",identity(resource,document));
            return runner.documentAccess(bridge -> { JsonObject v=object(bridge.documentRead(action).get("description")); return new Description(reference(bridge,v.get("reference")),number(v.get("source_revision"),0),wide(v.get("floor")),wide(v.get("merge_window")),wide(v.get("active_job")),bool(v.get("retired")),number(v.get("change_format"),1)); });
        }
        public CompletableFuture<PathValue> path(Reference reference,List<String> names) {
            String ref=encoded(reference); names=List.copyOf(names); if(names.isEmpty() || names.size()>16) throw new IllegalArgumentException("Expected bounded path"); JsonArray path=new JsonArray(); names.forEach(v -> path.add(text(v,64)));
            JsonObject action=obj("path",obj("reference",ref,"names",path));
            return runner.documentAccess(bridge -> { JsonObject v=object(bridge.documentRead(action).get("field")); if(!string(v.get("reference")).equals(ref)) throw incompatible("document-reference"); return new PathValue(reference,number(v.get("source_revision"),0),Field.parse(v.get("value"))); });
        }
        public CompletableFuture<Page> sequence(Reference reference,Dot object,Optional<String> cursor) {
            String ref=encoded(reference); cursor.ifPresent(v -> text(v,1024)); JsonObject action=obj("sequence",obj("reference",ref,"object",object.wire(),"cursor",cursor.orElse(null)));
            return runner.documentAccess(bridge -> { JsonObject v=object(bridge.documentRead(action).get("page")); if(!string(v.get("reference")).equals(ref)) throw incompatible("document-reference"); List<Item> items=elements(v.get("items"),8).stream().map(item -> { JsonObject i=object(item); return new Item(Dot.parse(i.get("id")),Field.parse(i.get("values"))); }).toList(); return new Page(reference,number(v.get("source_revision"),0),items,v.get("next").isJsonNull()?Optional.empty():Optional.of(string(v.get("next")))); });
        }
        public CompletableFuture<Resynchronization> resynchronize(ResourceRef resource,BigInteger document,BigInteger replica) {
            JsonObject action=obj("resynchronize",obj("identity",identity(resource,document),"replica",positive(replica).toString()));
            return runner.documentAccess(bridge -> { JsonObject v=object(bridge.documentRead(action).get("resynchronization")); return new Resynchronization(reference(bridge,v.get("reference")),wide(v.get("floor")),wide(v.get("replica")),wide(v.get("previous_counter")),wide(v.get("clock"))); });
        }
        public CompletableFuture<Change> acceptedChange(Reference reference) { JsonObject action=obj("accepted_change",encoded(reference)); return runner.documentAccess(bridge -> Change.parse(bridge.documentRead(action).get("change"))); }
    }
}
