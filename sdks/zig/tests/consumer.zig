const std = @import("std");
const client = @import("transit_client");
const protocol = @import("transit_protocol");
const station = @import("transit_station");
const query = @import("transit_query");

test "consumer composes shared client, framework and query types" {
    try std.testing.expect(client == station.client);
    try std.testing.expect(protocol == client.protocol);
    try std.testing.expect(station == query.station);
    try std.testing.expect(@import("transit_fuze") == query.fuze);
    const direct = @import("transit_query_direct");
    try std.testing.expect(direct == query.direct);
    try std.testing.expect(direct.RelationalBridge == query.RelationalBridge);
    try std.testing.expect(direct.TableChangeReader == query.TableChangeReader);
    try std.testing.expect(direct.fuze.QueryValues.Plan == query.Values.Plan);
    try std.testing.expect(direct.fuze.QueryValues.Column == query.Values.Column);
    try std.testing.expect(direct.fuze.QueryValues.Cell == query.Values.Cell);
    try std.testing.expect(@import("transit_catalog") == query.catalog);
    try std.testing.expect(@import("transit_station_document") == query.document);
    _ = @import("transit_station_http");
    _ = @import("transit_station_grpc");
    _ = @import("transit_station_app");
    const sql = @import("transit_sql_client");
    try std.testing.expect(protocol == sql.results.protocol);
    _ = sql.Client.attachTransaction;
    _ = @import("transit_catalog").DirectTransactionClient;
    const data = @import("transit_data_client");
    try std.testing.expect(data.catalog == @import("transit_catalog"));
    _ = data.Catalog;
}
