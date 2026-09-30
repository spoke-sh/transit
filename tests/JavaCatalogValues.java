package io.transit.sdk.station;

import com.google.gson.*;
import io.transit.client.*;
import static io.transit.sdk.station.Catalog.*;
import java.math.BigInteger;
import java.nio.file.*;
import java.util.*;
import java.util.concurrent.*;

/** Installed values, decoder failures and actual owned-port cancellation. */
public final class JavaCatalogValues {
    private JavaCatalogValues() {}
    private static void check(boolean value) { if(!value)throw new AssertionError("Catalog ownership assertion failed"); }
    private static <E extends Throwable> E rejects(Class<E> type,Runnable work) {
        try{work.run();}catch(Throwable e){if(type.isInstance(e))return type.cast(e);throw new AssertionError("Wrong failure",e);}throw new AssertionError("Expected failure");
    }
    private static <T> T await(CompletableFuture<T> value) {
        try{return value.join();}catch(CompletionException e){if(e.getCause() instanceof RuntimeException r)throw r;throw e;}
    }
    private static final BigInteger MAX=BigInteger.ONE.shiftLeft(64).subtract(BigInteger.ONE);
    private static final Scope SCOPE=new Scope(new ResourceRef(46,7),MAX);
    private static final Connection CONNECTION=new Connection(new ProcessRef(46,3),SCOPE);
    private static Catalog.Client open(Path root,String mode) throws Exception {
        Files.deleteIfExists(root.resolve("entered"));Files.deleteIfExists(root.resolve("release"));Files.writeString(root.resolve("mode.json"),mode);
        return Catalog.Client.open(new ClientConfig(java.net.URI.create("http://127.0.0.1:9"),ClientConfig.Profile.NATIVE_V1,1000,root.resolve("host")),new Credential(46,17,root.resolve("seed")),CONNECTION);
    }
    private static void waitFor(Path file) throws Exception {
        long deadline=System.nanoTime()+TimeUnit.SECONDS.toNanos(5);
        while(!Files.exists(file)){if(System.nanoTime()>=deadline)throw new AssertionError("Host did not enter submission");Thread.sleep(10);}
    }
    private static void joined(Path root) throws Exception {
        long pid=Long.parseLong(Files.readString(root.resolve("host-pid")));
        check(ProcessHandle.of(pid).map(p -> !p.isAlive()).orElse(true));
        check(Thread.getAllStackTraces().keySet().stream().noneMatch(t -> t.isAlive() && (t.getName().equals("transit-owned-port") || t.getName().equals("transit-completions"))));
    }
    public static void main(String[] args) throws Exception {
        Path root=Path.of(args[0]);Files.writeString(root.resolve("seed"),"11".repeat(32));
        rejects(IllegalArgumentException.class,() -> new Scope(SCOPE.resource(),MAX.add(BigInteger.ONE)));
        rejects(IllegalArgumentException.class,() -> new Scope(SCOPE.resource(),BigInteger.ZERO));
        rejects(IllegalArgumentException.class,() -> new Connection(new ProcessRef(47,3),SCOPE));
        rejects(IllegalArgumentException.class,() -> new Prepared(new Bytes(new byte[8193])));
        rejects(IllegalArgumentException.class,() -> new Prepared(new Bytes(new byte[0])));
        rejects(IllegalArgumentException.class,() -> new Prepared(new Bytes(new byte[]{(byte)255})));
        byte[] original={1,2};Prepared prepared=new Prepared(new Bytes(original));original[0]=0;byte[] exposed=prepared.bytes().copy();exposed[0]=0;check(prepared.bytes().copy()[0]==1);
        List<String> names=new ArrayList<>(List.of("id","value"));Schema schema=new Schema(names,Type.UTF8);names.clear();check(schema.names().equals(List.of("id","value")));
        rejects(UnsupportedOperationException.class,() -> schema.names().add("changed"));
        CreateTable request=new CreateTable(SCOPE,MAX,MAX,0xffffffffL,"items",schema);
        Compiled compiled=new Compiled(request,new Bytes(original));original[0]=3;check(compiled.canonical().copy()[0]==0 && compiled.request().object().equals(MAX));
        for(String text:List.of("null","{}","{\"receipt\":{\"position\":0}}","{\"receipt\":{\"position\":\"1\"}}","{\"receipt\":{\"position\":1.5}}","{\"receipt\":{\"position\":1,\"extra\":true}}","{\"receipt\":{\"position\":1},\"extra\":true}")) {
            check(rejects(TransitException.class,() -> Catalog.admission(new Gson().fromJson(text,JsonElement.class))).kind()==TransitException.Kind.UNKNOWN_OUTCOME);
        }
        check(rejects(TransitException.class,() -> Catalog.submission(() -> {throw new OutOfMemoryError("injected result allocation");})).kind()==TransitException.Kind.UNKNOWN_OUTCOME);
        TransitException denial=new TransitException(TransitException.Kind.ACCESS_DENIED,4,"CatalogDenied","injected");
        check(rejects(TransitException.class,() -> Catalog.submission(() -> {throw denial;}))==denial);
        JsonObject receipt=new JsonObject();receipt.add("request",request.wire());receipt.addProperty("principal",17);receipt.addProperty("input",7);receipt.addProperty("outcome","applied");
        check(Catalog.receipt(receipt,request).request().object().equals(MAX));
        for(String invalid:List.of("1","01","+1","18446744073709551616")) {
            receipt.getAsJsonObject("request").addProperty("object",invalid);
            rejects(TransitException.class,() -> Catalog.receipt(receipt,request));
        }
        receipt.getAsJsonObject("request").addProperty("object",MAX);rejects(TransitException.class,() -> Catalog.receipt(receipt,request));
        for(String mode:List.of("\"loss\"","{\"status\":0,\"value\":{\"receipt\":{\"position\":\"1\"}}}","{\"status\":0,\"value\":{\"receipt\":{\"position\":7},\"extra\":true}}")) {
            try(var client=open(root,mode)){check(rejects(TransitException.class,() -> await(client.submit(prepared))).kind()==TransitException.Kind.UNKNOWN_OUTCOME);check(prepared.bytes().copy()[0]==1);}
            joined(root);
        }
        try(var client=open(root,"{\"status\":4,\"value\":{\"err\":\"CatalogDenied\"}}")) {
            TransitException e=rejects(TransitException.class,() -> await(client.submit(prepared)));check(e.kind()==TransitException.Kind.ACCESS_DENIED && e.status()==4 && e.code().equals("CatalogDenied"));
        }
        joined(root);
        try(var client=open(root,"{\"status\":0,\"value\":{\"receipt\":{\"position\":7}}}")){check(await(client.submit(prepared)).position()==7);}
        joined(root);
        Catalog.Client client=open(root,"\"block\"");CompletableFuture<?> closing=null;
        try {
            var pending=client.submit(prepared);waitFor(root.resolve("entered"));check(pending.cancel(true));
            check(rejects(TransitException.class,() -> await(client.capabilities())).kind()==TransitException.Kind.BUSY);
            CountDownLatch started=new CountDownLatch(1);closing=CompletableFuture.runAsync(() -> {started.countDown();client.close();});check(started.await(5,TimeUnit.SECONDS));
            try{closing.get(100,TimeUnit.MILLISECONDS);throw new AssertionError("Close abandoned active native work");}catch(TimeoutException expected){}
            Files.writeString(root.resolve("release"),"1");closing.get(5,TimeUnit.SECONDS);check(pending.isCancelled());check(prepared.bytes().copy()[0]==1);
        } finally {Files.writeString(root.resolve("release"),"1");client.close();if(closing!=null)closing.get(5,TimeUnit.SECONDS);}
        joined(root);check(rejects(TransitException.class,() -> await(client.capabilities())).kind()==TransitException.Kind.CLOSED);
        System.out.println("Java catalog immutable values, uncertain receipts and joined cancellation passed.");
    }
}
