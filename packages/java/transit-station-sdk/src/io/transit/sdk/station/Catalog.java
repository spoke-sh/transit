package io.transit.sdk.station;

import com.google.gson.*;
import io.transit.client.*;
import io.transit.client.internal.Worker;
import static io.transit.client.internal.Values.*;
import java.math.BigInteger;
import java.nio.charset.StandardCharsets;
import java.util.*;
import java.util.concurrent.CompletableFuture;
import java.util.function.Supplier;

/** Typed catalog callers; shared Zig owns signing, authority and durable recovery. */
public final class Catalog {
    private Catalog() {}
    private static BigInteger positive(BigInteger value) {
        u64(value);if(value.signum()==0)throw new IllegalArgumentException("Expected positive catalog identity");return value;
    }
    private static String name(String value) {
        text(value,16);if(value.isEmpty())throw new IllegalArgumentException("Empty catalog name");return value;
    }
    private static long table(long value) {
        if(value<1 || value>0xffffffffL)throw new IllegalArgumentException("Invalid catalog Table identity");return value;
    }
    private static String tag(Enum<?> value) { return Objects.requireNonNull(value).name().toLowerCase(Locale.ROOT); }
    private static JsonObject fields(JsonElement value,String... names) {
        JsonObject out=object(value);if(!out.keySet().equals(Set.of(names)))throw incompatible("catalog-fields");return out;
    }
    private static JsonElement result(JsonElement value,String key) { return fields(value,key).get(key); }
    private static <E extends Enum<E>> E variant(Class<E> type,JsonElement value) {
        String text=string(value);
        try { E out=Enum.valueOf(type,text.toUpperCase(Locale.ROOT));if(!tag(out).equals(text))throw incompatible("catalog-variant");return out; }
        catch(IllegalArgumentException error) { throw incompatible("catalog-variant"); }
    }
    public enum Type { INT64, BOOLEAN, UTF8, BINARY }
    public enum Observation { PENDING, PROCESSED }
    public enum Outcome { APPLIED, NAME_CONFLICT, OBJECT_CONFLICT, TABLE_CONFLICT }
    public enum Origin { EXTERNAL, PROCESS, EFFECT }
    public enum DispositionOutcome { INITIALIZED, POLICY_APPLIED, INVALID_COMMAND, DENIED, IDENTITY_CONFLICT, STALE_POLICY }
    public record Scope(ResourceRef resource,BigInteger catalog) {
        public Scope { Objects.requireNonNull(resource);positive(catalog); }
        JsonObject wire() { return obj("realm",resource.realm(),"resource",resource.resource(),"catalog",catalog.toString()); }
    }
    public record Connection(ProcessRef owner,Scope scope) {
        public Connection {
            Objects.requireNonNull(owner);Objects.requireNonNull(scope);
            if(owner.realm()!=scope.resource().realm())throw new IllegalArgumentException("Catalog requires one realm");
        }
        JsonObject wire(Credential identity) {
            if(identity.realm()!=owner.realm())throw new IllegalArgumentException("Different credential realm");
            return obj("scope",scope.wire(),"owner",owner.pid(),"principal",identity.principal());
        }
    }
    public record Configuration(Scope scope,ProcessRef owner,long administrator) {
        public Configuration { new Connection(owner,scope);counter(administrator,1); }
        JsonObject wire() { return obj("scope",scope.wire(),"owner",owner.pid(),"administrator",administrator); }
    }
    public record Schema(List<String> names,Type valueType) {
        public Schema {
            names=List.copyOf(names);if(names.size()!=2)throw new IllegalArgumentException("Catalog requires two column names");
            names.forEach(Catalog::name);Objects.requireNonNull(valueType);
        }
        JsonObject wire() { JsonArray list=new JsonArray();names.forEach(list::add);return obj("names",list,"value_type",tag(valueType)); }
    }
    public record CreateTable(Scope scope,BigInteger operation,BigInteger object,long table,String name,Schema schema) {
        public CreateTable { Objects.requireNonNull(scope);positive(operation);positive(object);Catalog.table(table);Catalog.name(name);Objects.requireNonNull(schema); }
        JsonObject wire() { return obj("scope",scope.wire(),"operation",operation.toString(),"object",object.toString(),"table",table,"name",name,"schema",schema.wire()); }
    }
    public record Policy(Scope scope,long principal,BigInteger revision,boolean inspect,boolean create) {
        public Policy { Objects.requireNonNull(scope);counter(principal,0);positive(revision); }
        JsonObject wire() { return obj("scope",scope.wire(),"principal",principal,"revision",revision.toString(),"inspect",inspect,"create",create); }
    }
    public record PolicyChange(BigInteger expectedRevision,Policy policy) {
        public PolicyChange { u64(expectedRevision);Objects.requireNonNull(policy); }
        JsonObject wire() { return obj("expected_revision",expectedRevision.toString(),"policy",policy.wire()); }
    }
    public record Compiled(CreateTable request,Bytes canonical) {
        public Compiled {
            Objects.requireNonNull(request);Objects.requireNonNull(canonical);
            if(canonical.size()==0 || canonical.size()>256)throw new IllegalArgumentException("Invalid catalog canonical length");
        }
    }
    /** Save unchanged before submission, including before awaiting its future. */
    public record Prepared(Bytes bytes) {
        public Prepared {
            Objects.requireNonNull(bytes);if(bytes.size()==0 || bytes.size()>8192)throw new IllegalArgumentException("Invalid saved catalog length");text(bytes.copy());
        }
        String wire() { return text(bytes.copy()); }
    }
    public record Capabilities(int version,String definition,boolean initialize,boolean createTable,boolean conditionalPolicy,boolean currentMetadata,int maxSavedBytes,int tableColumns) {}
    public record Description(Configuration configuration,Policy policy,long resourceRevision) {}
    public record Receipt(CreateTable request,long principal,long input,Outcome outcome) {}
    public record Disposition(Scope scope,Origin origin,long principal,long input,Bytes payload,DispositionOutcome outcome) {}

    private static Scope scope(JsonElement value) {
        JsonObject v=fields(value,"realm","resource","catalog");return new Scope(new ResourceRef(number(v.get("realm"),1),number(v.get("resource"),1)),NativeValues.wide(v.get("catalog"),true));
    }
    private static Configuration configuration(JsonElement value) {
        JsonObject v=fields(value,"scope","owner","administrator");Scope s=scope(v.get("scope"));return new Configuration(s,new ProcessRef(s.resource().realm(),number(v.get("owner"),1)),number(v.get("administrator"),1));
    }
    private static Policy policy(JsonElement value) {
        JsonObject v=fields(value,"scope","principal","revision","inspect","create");return new Policy(scope(v.get("scope")),number(v.get("principal"),0),NativeValues.wide(v.get("revision"),true),bool(v.get("inspect")),bool(v.get("create")));
    }
    private static CreateTable request(JsonElement value) {
        JsonObject v=fields(value,"scope","operation","object","table","name","schema");JsonObject schema=fields(v.get("schema"),"names","value_type");
        JsonElement names=schema.get("names");if(!names.isJsonArray() || names.getAsJsonArray().size()!=2)throw incompatible("catalog-columns");
        return new CreateTable(scope(v.get("scope")),NativeValues.wide(v.get("operation"),true),NativeValues.wide(v.get("object"),true),table(number(v.get("table"),1)),name(string(v.get("name"))),new Schema(names.getAsJsonArray().asList().stream().map(item -> name(string(item))).toList(),variant(Type.class,schema.get("value_type"))));
    }
    private static Capabilities capabilities(JsonElement value) {
        JsonObject v=fields(value,"version","definition","initialize","create_table","conditional_policy","current_metadata","max_saved_bytes","table_columns");
        if(number(v.get("version"),1)!=1 || !string(v.get("definition")).equals(string(CONTRACT.get("definition"))) || number(v.get("max_saved_bytes"),1)!=8192 || number(v.get("table_columns"),1)!=2)throw incompatible("catalog-capabilities");
        return new Capabilities(1,string(v.get("definition")),bool(v.get("initialize")),bool(v.get("create_table")),bool(v.get("conditional_policy")),bool(v.get("current_metadata")),8192,2);
    }
    private static Prepared prepared(JsonElement value) { return new Prepared(new Bytes(string(value).getBytes(StandardCharsets.UTF_8))); }
    static Outcomes.AdmissionReceipt admission(JsonElement value) {
        try { return new Outcomes.AdmissionReceipt(number(fields(result(value,"receipt"),"position").get("position"),1)); }
        catch(RuntimeException | OutOfMemoryError error) { throw uncertain(); }
    }
    static Outcomes.AdmissionReceipt submission(Supplier<JsonObject> send) {
        JsonObject reply;
        try { reply=send.get(); }
        catch(TransitException error) { throw error; }
        catch(RuntimeException | OutOfMemoryError error) { throw uncertain(); }
        return admission(reply);
    }
    static Receipt receipt(JsonElement value,CreateTable original) {
        JsonObject v=fields(value,"request","principal","input","outcome");CreateTable actual=request(v.get("request"));
        if(!actual.equals(original))throw incompatible("catalog-original-request");
        return new Receipt(actual,number(v.get("principal"),0),number(v.get("input"),1),variant(Outcome.class,v.get("outcome")));
    }
    private static TransitException uncertain() { return new TransitException(TransitException.Kind.UNKNOWN_OUTCOME,6,null,"catalog-submit"); }
    /** One bounded owned port; cancelling a future does not release native work. */
    public static final class Client implements AutoCloseable {
        private final Connection connection;
        private final Worker<Bridge,Void> worker;
        private Client(ClientConfig config,Credential credential,Connection connection) {
            connection.wire(credential);this.connection=connection;
            worker=new Worker<>(() -> {
                Bridge bridge=Bridge.catalog(config,credential,connection);
                try {
                    Capabilities caps=Catalog.capabilities(result(bridge.catalog(obj("capabilities",obj())),"capabilities"));
                    if(!caps.initialize() || !caps.createTable() || !caps.conditionalPolicy() || !caps.currentMetadata())throw new TransitException(TransitException.Kind.UNSUPPORTED_CAPABILITY,"catalog-capabilities");
                    return bridge;
                } catch(RuntimeException | Error error) { bridge.close();throw error; }
            });
        }
        public static Client open(ClientConfig config,Credential credential,Connection connection) { return new Client(config,credential,connection); }
        public Connection connection() { return connection; }
        public CompletableFuture<Capabilities> capabilities() { return worker.submit(b -> Catalog.capabilities(result(b.catalog(obj("capabilities",obj())),"capabilities"))); }
        public CompletableFuture<Description> describe() {
            return worker.submit(b -> {JsonObject v=fields(result(b.catalog(obj("describe",obj())),"description"),"configuration","policy","resource_revision");return new Description(configuration(v.get("configuration")),policy(v.get("policy")),number(v.get("resource_revision"),0));});
        }
        public CompletableFuture<Compiled> compileSql(String sql,BigInteger operation,BigInteger object,long table) {
            if(text(sql,4096).isEmpty())throw new IllegalArgumentException("Empty catalog SQL");
            JsonObject action=obj("compile",obj("sql",sql,"operation",positive(operation).toString(),"object",positive(object).toString(),"table",Catalog.table(table)));
            return worker.submit(b -> {JsonObject v=fields(result(b.catalog(action),"compiled"),"request","canonical");return new Compiled(request(v.get("request")),new Bytes(unhex(v.get("canonical"),256)));});
        }
        private CompletableFuture<Prepared> prepare(String name,JsonObject value) {
            JsonObject action=obj(name,value);return worker.submit(b -> prepared(result(b.catalog(action),"prepared")));
        }
        public CompletableFuture<Prepared> prepareInitialize(Configuration configuration) { return prepare("prepare_initialize",configuration.wire()); }
        public CompletableFuture<Prepared> prepareCreate(CreateTable request) { return prepare("prepare_create",request.wire()); }
        public CompletableFuture<Prepared> preparePolicy(PolicyChange change) { return prepare("prepare_policy",change.wire()); }
        public CompletableFuture<Outcomes.AdmissionReceipt> submit(Prepared prepared) {
            JsonObject action=obj("submit",prepared.wire());
            return worker.submit(b -> submission(() -> b.catalog(action)));
        }
        private static JsonObject input(String name,Prepared prepared,long position) { return obj(name,obj("prepared",prepared.wire(),"input",counter(position,1))); }
        public CompletableFuture<Observation> observe(Prepared prepared,long position) {
            JsonObject action=input("observe",prepared,position);return worker.submit(b -> variant(Observation.class,result(b.catalog(action),"observation")));
        }
        public CompletableFuture<Optional<Disposition>> inputDisposition(Prepared prepared,long position) {
            JsonObject action=input("input_disposition",prepared,position);
            return worker.submit(b -> {
                JsonElement value=result(b.catalog(action),"disposition");if(value.isJsonNull())return Optional.empty();
                JsonObject v=fields(value,"scope","origin","principal","input","payload","outcome");Bytes payload=new Bytes(unhex(v.get("payload"),32));if(payload.size()!=32)throw incompatible("catalog-payload");
                return Optional.of(new Disposition(scope(v.get("scope")),variant(Origin.class,v.get("origin")),number(v.get("principal"),0),number(v.get("input"),1),payload,variant(DispositionOutcome.class,v.get("outcome"))));
            });
        }
        public CompletableFuture<Optional<Receipt>> status(CreateTable original) {
            JsonObject action=obj("status",original.wire());return worker.submit(b -> {JsonElement value=result(b.catalog(action),"status");return value.isJsonNull()?Optional.empty():Optional.of(receipt(value,original));});
        }
        @Override public void close() { worker.close(); }
    }
}
