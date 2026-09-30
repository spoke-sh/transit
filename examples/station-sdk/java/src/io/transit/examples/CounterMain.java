package io.transit.examples;

import com.google.gson.*;
import com.google.gson.stream.*;
import io.transit.client.*;
import io.transit.sdk.station.*;
import io.transit.sdk.station.Types.*;
import io.transit.examples.Messages.CounterMessage;
import java.net.URI;
import java.nio.file.*;
import java.nio.charset.StandardCharsets;
import java.io.*;
import java.math.BigDecimal;

/** Installed counter roles; provisioning and delivery belong to the deployment. */
public final class CounterMain {
    private CounterMain() {}
    private static JsonObject config(String text) throws IOException {
        JsonObject object = new JsonObject();
        try (JsonReader reader = new JsonReader(new StringReader(text))) {
            reader.setStrictness(Strictness.STRICT); reader.setNestingLimit(4); reader.beginObject();
            while (reader.hasNext()) {
                String name = reader.nextName();
                if (object.has(name)) throw new IllegalArgumentException("Duplicate configuration field");
                switch (reader.peek()) {
                    case STRING -> object.addProperty(name, reader.nextString());
                    case NUMBER -> object.addProperty(name, new BigDecimal(reader.nextString()));
                    case BOOLEAN -> object.addProperty(name, reader.nextBoolean());
                    case NULL -> { reader.nextNull(); object.add(name, JsonNull.INSTANCE); }
                    default -> throw new IllegalArgumentException("Expected flat configuration values");
                }
            }
            reader.endObject();
            if (reader.peek() != JsonToken.END_DOCUMENT) throw new IllegalArgumentException("Trailing configuration");
        }
        return object;
    }
    private static long number(JsonObject config, String key) {
        JsonPrimitive value = config.getAsJsonPrimitive(key);
        if (!value.isNumber()) throw new IllegalArgumentException("Expected numeric configuration");
        return value.getAsBigDecimal().longValueExact();
    }
    public static void main(String[] args) throws Exception {
        if (args.length != 2 && args.length != 4) throw new IllegalArgumentException("CONFIG service|requester [--commits COUNT]");
        if (args.length == 4 && !args[2].equals("--commits")) throw new IllegalArgumentException("Use --commits COUNT");
        int remaining = args.length == 4 ? Integer.parseInt(args[3]) : 1;
        if (remaining < 1) throw new IllegalArgumentException("Commit count must be positive");
        String text = Files.readString(Path.of(args[0]), StandardCharsets.UTF_8);
        if (text.length() > 8192) throw new IllegalArgumentException("Configuration exceeds its bound");
        JsonObject cfg = config(text);
        if (!cfg.get("profile").getAsString().equals("native_v1")) throw new IllegalArgumentException("Select native_v1");
        long realm = number(cfg, "realm");
        var client = new ClientConfig(URI.create(cfg.get("url").getAsString()), ClientConfig.Profile.NATIVE_V1);
        var activation = new Activation(new ProcessRef(realm, number(cfg, "pid")), number(cfg, "generation"),
            new Credential(realm, number(cfg, "principal"), Path.of(cfg.get("seed_file").getAsString())));
        var peer = new ProcessRef(realm, number(cfg, "peer"));
        Handler<CounterMessage> handler;
        Codec<CounterMessage> codec;
        if (args[1].equals("service")) { handler = new Handlers.Counter(); codec = Codecs.COUNTER; }
        else if (args[1].equals("requester")) { handler = new Handlers.Requester(peer); codec = Codecs.REQUESTER; }
        else throw new IllegalArgumentException("Select service or requester");
        try (var runner = Runner.open(new ServiceConfig(client, activation), handler, codec, FailurePolicy.STOP, new Recovery.FreshOwnership())) {
            while (remaining > 0) {
                Event event = runner.next().join();
                if (event instanceof Committed committed) {
                    System.out.println("{\"input\":" + committed.input() + ",\"committed\":" + committed.receipt().position() + "}"); remaining--;
                } else if (event instanceof Idle) Thread.sleep(20);
                else if (!(event instanceof Progress)) throw new IllegalStateException("Runner stopped before requested commitment; inspect recovery evidence");
            }
        }
    }
}
