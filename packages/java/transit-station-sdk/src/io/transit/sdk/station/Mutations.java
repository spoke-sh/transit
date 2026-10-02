package io.transit.sdk.station;

import com.google.gson.*;
import io.transit.client.*;
import io.transit.client.internal.Worker;
import static io.transit.client.internal.Values.*;
import java.math.BigInteger;
import java.nio.charset.StandardCharsets;
import java.util.*;
import java.util.concurrent.CompletableFuture;

/** Owned Table mutation callers; shared Zig owns validation, policy and recovery. */
public final class Mutations {
    private Mutations() {}
    private static BigInteger positive(BigInteger value) {
        u64(value); if(value.signum()==0)throw new IllegalArgumentException("Expected positive mutation namespace");return value;
    }
    private static String tag(Enum<?> value) { return Objects.requireNonNull(value).name().toLowerCase(Locale.ROOT); }
    private static String hex(Bytes bytes) { return HexFormat.of().formatHex(bytes.copy()); }
    private static Bytes fixed(JsonElement value,int size) {
        Bytes result=new Bytes(unhex(value,size));if(result.size()!=size)throw incompatible("mutation-byte-width");return result;
    }
    private static long revision(JsonElement value) {
        try { return counter(NativeValues.wide(value,false).longValueExact(),1); }
        catch(ArithmeticException | IllegalArgumentException error) { throw incompatible("mutation-revision"); }
    }
    private static <E extends Enum<E>> E variant(Class<E> type,JsonElement value) {
        try { return Enum.valueOf(type,string(value).toUpperCase(Locale.ROOT)); }
        catch(IllegalArgumentException error) { throw incompatible("mutation-variant"); }
    }
    public record Connection(ProcessRef writer,ResourceRef resource,long table) {
        public Connection {
            Objects.requireNonNull(writer);Objects.requireNonNull(resource);
            if(writer.realm()!=resource.realm() || table<1 || table>0xffffffffL)throw new IllegalArgumentException("Invalid mutation connection");
        }
        JsonObject wire(Credential identity) {
            if(identity.realm()!=writer.realm())throw new IllegalArgumentException("Different credential realm");
            return obj("realm",writer.realm(),"principal",identity.principal(),"writer",writer.pid(),"resource",resource.resource(),"table",table);
        }
    }
    public record Reference(Bytes bytes) {
        public Reference { Objects.requireNonNull(bytes);if(bytes.size()!=72)throw new IllegalArgumentException("Expected full mutation reference"); }
    }
    public record Compiled(Bytes request,Reference reference) {
        public Compiled { Objects.requireNonNull(request);Objects.requireNonNull(reference);if(request.size()==0 || request.size()>799)throw new IllegalArgumentException("Mutation request exceeds its bound"); }
    }
    /** Persist unchanged before submit; cancellation of a future does not undo it. */
    public record Prepared(Bytes bytes) {
        public Prepared { Objects.requireNonNull(bytes);if(bytes.size()==0 || bytes.size()>8192)throw new IllegalArgumentException("Invalid saved mutation length");text(bytes.copy()); }
    }
    public enum Type { INT64, BOOLEAN, UTF8, BINARY }
    public enum Permission {
        INSERT(1), UPDATE(2), DELETE(4);
        private final int bit;
        Permission(int bit) { this.bit=bit; }
        public int bit() { return bit; }
    }
    public enum Phase { UPLOADING, SEALED, APPLIED, REJECTED, CANCELLED }
    public enum Reason { NONE, ROW_EXISTS, SOURCE_CHANGED, INVALID_REQUEST, DENIED, BUDGET }
    public enum Observation { PENDING, PROCESSED }
    public enum Rejection { INVALID_COMMAND, DENIED, IDENTITY_CONFLICT, BUSY, NOT_FOUND, NOT_ACTIVE, UPLOAD_CLOSED, NOT_SEALED, INVALID_PART, INCOMPLETE_UPLOAD, SOURCE_CHANGED, STALE_POLICY }
    public enum Control { APPLY, CANCEL }
    public record Description(ResourceRef resource,long table,List<String> names,Type valueType,long resourceRevision,long policyRevision,Bytes declaration,Set<Permission> permissions,Optional<BigInteger> active) {
        public Description { names=List.copyOf(names);permissions=Set.copyOf(permissions); }
    }
    public record Conflict(long key,int row) {}
    private static Optional<Conflict> conflict(JsonElement value) {
        if(value.isJsonNull())return Optional.empty();
        var v=value.getAsJsonObject();long row=number(v.get("row"),1);
        if(row>3)throw incompatible("conflict-row");
        return Optional.of(new Conflict(NativeValues.signed(v.get("key")),(int)row));
    }
    public record Status(Reference reference,long principal,long table,Bytes declaration,long policyRevision,Phase phase,int affectedRows,Reason reason,long input,Optional<Conflict> conflict) {}
    private static Optional<Prepared> prepared(JsonElement value) {
        if(value==null)throw incompatible("mutation-prepared");
        return value.isJsonNull()?Optional.empty():Optional.of(new Prepared(new Bytes(string(value).getBytes(StandardCharsets.UTF_8))));
    }
    /** One bounded operation. Closing joins ownership even after future cancellation. */
    public static final class Client implements AutoCloseable {
        private final Connection connection;
        private final Worker<Bridge,Void> worker;
        private Client(ClientConfig config,Credential credential,Connection connection) {
            connection.wire(credential);this.connection=connection;
            worker=new Worker<>(() -> {
                Bridge bridge=Bridge.mutation(config,credential,connection);
                try {
                    JsonObject caps=object(bridge.tableMutation(obj("capabilities",obj())).get("capabilities"));
                    if(number(caps.get("version"),1)!=1 || number(caps.get("max_rows"),1)!=3 || number(caps.get("max_request_bytes"),1)!=799 || number(caps.get("max_saved_bytes"),1)!=8192)throw incompatible("mutation-capabilities");
                    for(String name:List.of("insert","update_primary_key","delete_primary_key"))if(!bool(caps.get(name)))throw incompatible("mutation-capabilities");
                    return bridge;
                } catch(RuntimeException | Error error) { bridge.close();throw error; }
            });
        }
        public static Client open(ClientConfig config,Credential credential,Connection connection) { return new Client(config,credential,connection); }
        public Connection connection() { return connection; }
        public CompletableFuture<Description> describe() {
            return worker.submit(b -> {
                JsonObject v=object(b.tableMutation(obj("describe",obj())).get("description"));
                if(number(v.get("resource"),1)!=connection.resource().resource() || number(v.get("table"),1)!=connection.table())throw incompatible("mutation-target");
                JsonElement list=v.get("names");if(!list.isJsonArray() || list.getAsJsonArray().size()!=2)throw incompatible("mutation-columns");
                List<String> names=list.getAsJsonArray().asList().stream().map(item -> text(string(item),16)).toList();
                long bits=number(v.get("permissions"),0);if(bits>7)throw incompatible("mutation-permissions");
                Set<Permission> permissions=EnumSet.noneOf(Permission.class);for(Permission p:Permission.values())if((bits&p.bit())!=0)permissions.add(p);
                Optional<BigInteger> active=v.get("active").isJsonNull()?Optional.empty():Optional.of(positive(NativeValues.wide(v.get("active"),false)));
                return new Description(connection.resource(),connection.table(),names,variant(Type.class,v.get("value_type")),number(v.get("resource_revision"),0),revision(v.get("policy_revision")),fixed(v.get("declaration"),32),permissions,active);
            });
        }
        public CompletableFuture<Compiled> compileSql(String name,String sql,BigInteger namespace) {
            JsonObject action=obj("compile",obj("name",text(name,16),"sql",text(sql,4096),"namespace",positive(namespace).toString()));
            return worker.submit(b -> {JsonObject v=object(b.tableMutation(action).get("compiled"));return new Compiled(new Bytes(unhex(v.get("request"),799)),new Reference(fixed(v.get("reference"),72)));});
        }
        public CompletableFuture<Optional<Prepared>> prepareNext(Compiled compiled) {
            JsonObject action=obj("next",obj("request",hex(compiled.request()),"reference",hex(compiled.reference().bytes())));
            return worker.submit(b -> prepared(b.tableMutation(action).get("prepared")));
        }
        public CompletableFuture<Prepared> prepareControl(Control control,Reference reference) {
            JsonObject action=obj("prepare",obj(tag(control),hex(reference.bytes())));
            return worker.submit(b -> prepared(b.tableMutation(action).get("prepared")).orElseThrow(() -> incompatible("mutation-prepared")));
        }
        public CompletableFuture<Outcomes.AdmissionReceipt> submit(Prepared prepared) {
            JsonObject action=obj("submit",text(prepared.bytes().copy()));
            return worker.submit(b -> {
                JsonObject result=b.tableMutation(action);
                try { return new Outcomes.AdmissionReceipt(number(object(result.get("receipt")).get("position"),1)); }
                catch(RuntimeException error) { throw new TransitException(TransitException.Kind.UNKNOWN_OUTCOME,6,null,"mutation-receipt"); }
            });
        }
        public CompletableFuture<Observation> observe(Prepared prepared,long input) {
            JsonObject action=obj("observe",obj("prepared",text(prepared.bytes().copy()),"input",counter(input,1)));
            return worker.submit(b -> variant(Observation.class,b.tableMutation(action).get("observation")));
        }
        public CompletableFuture<Optional<Rejection>> rejection(Prepared prepared,long input) {
            JsonObject action=obj("rejection",obj("prepared",text(prepared.bytes().copy()),"input",counter(input,1)));
            return worker.submit(b -> {JsonElement v=b.tableMutation(action).get("rejection");return v.isJsonNull()?Optional.empty():Optional.of(variant(Rejection.class,v));});
        }
        public CompletableFuture<Optional<Status>> status(Reference reference) {
            JsonObject action=obj("status",hex(reference.bytes()));
            return worker.submit(b -> {
                JsonElement result=b.tableMutation(action).get("status");if(result.isJsonNull())return Optional.empty();JsonObject v=object(result);
                Reference actual=new Reference(fixed(v.get("reference"),72));
                if(!actual.equals(reference) || number(v.get("table"),1)!=connection.table())throw incompatible("mutation-status-target");
                long affected=number(v.get("affected_rows"),0);if(affected>3)throw incompatible("mutation-row-count");
                return Optional.of(new Status(actual,number(v.get("principal"),1),connection.table(),fixed(v.get("declaration"),32),revision(v.get("policy_revision")),variant(Phase.class,v.get("phase")),(int)affected,variant(Reason.class,v.get("reason")),number(v.get("input"),0),conflict(v.get("conflict"))));
            });
        }
        @Override public void close() { worker.close(); }
    }
}
