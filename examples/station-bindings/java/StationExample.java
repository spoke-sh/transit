import com.google.gson.*;
import io.transit.station.NativeHost;

public class StationExample {
    private static JsonObject json(String value) { return JsonParser.parseString(value).getAsJsonObject(); }
    public static void main(String[] args) throws Exception {
        long peer = Long.parseLong(args[2]);
        if (peer <= 0 || peer > 9007199254740991L) throw new IllegalArgumentException("Peer PID");
        try (NativeHost host = NativeHost.open(System.getenv("TRANSIT_HOST"), args[0])) {
            for (;;) {
                JsonObject event = host.next().get().getAsJsonObject();
                String state = event.get("event").getAsString();
                if (state.equals("committed")) return;
                if (state.equals("idle") || state.equals("blocked")) throw new IllegalStateException(state);
                if (!state.equals("ready")) continue;
                if (event.get("initializing").getAsBoolean()) {
                    host.apply(json("{\"table_create\":{\"id\":1,\"key_name\":\"id\",\"value_name\":\"value\",\"value_type\":\"int64\"}}")).get();
                    if (args[1].equals("service")) {
                        host.apply(json("{\"query_policy\":{\"peer\":" + peer + ",\"table\":1,\"expected_revision\":0,\"allow\":true}}")).get();
                        host.apply(json("{\"table_write\":{\"id\":1,\"mode\":\"insert\",\"row\":{\"key\":\"1\",\"value\":{\"int64\":\"9007199254740993\"}}}}")).get();
                    }
                }
                JsonObject input = event.getAsJsonObject("input");
                if (input.get("payload").getAsString().equals("696e6974")) {}
                else switch (input.get("kind").getAsString()) {
                    case "cast" -> host.apply(json("{\"call\":{\"pid\":" + peer + ",\"value\":\"7175657279\"}}")).get();
                    case "call" -> host.apply(json("{\"query_reply\":{\"id\":1}}")).get();
                    case "result_complete" -> {
                        JsonObject query = new JsonObject(); query.add("query_result", input.get("correlation"));
                        String hex = host.apply(query).get().getAsJsonObject().get("arrow").getAsString();
                        byte[] ipc = java.util.HexFormat.of().parseHex(hex);
                        JsonObject cell = host.arrowCell(ipc, 0, 1).get().getAsJsonObject();
                        if (Long.parseLong(cell.getAsJsonObject("value").get("int64").getAsString()) != 9007199254740993L) throw new IllegalStateException("Lost integer precision");
                        host.apply(json("{\"put\":{\"key\":\"6f62736572766564\",\"value\":\"39303037313939323534373430393933\"}}")).get();
                    }
                    default -> throw new IllegalStateException("Unexpected Station input");
                }
                host.finish(false).get();
            }
        }
    }
}
