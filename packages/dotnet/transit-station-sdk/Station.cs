using Transit.Client.Internal;
using Transit.Station.Sdk.Internal;
using StationBridge = Transit.Station.Sdk.Internal.Bridge;
using StationApi = Transit.Station.Sdk.Internal.NativeApi;

namespace Transit.Station.Sdk;

/// <summary>Local frame encoding through Zig, without credentials or authority work.</summary>
public static class Station
{
    public static async Task<byte[]> EncodeCastAsync<T>(T value, ICodec<T> codec, string? nativeDirectory = null) where T : notnull
    {
        var worker = await Worker<StationBridge, object?>.OpenAsync(() => new StationBridge(nativeDirectory), StationApi.MinimumStackBytes).ConfigureAwait(false);
        try {
            return await worker.Invoke(bridge => {
                byte[] bytes = NativeValues.Encode(codec, value, bridge.Limit("message_bytes"));
                uint status = bridge.Api.station_frame_encode(1, 0, bytes, (nuint)bytes.Length, out var buffer);
                return Value.Unhex(Value.Parse(bridge.Buffer(status, buffer, "encode-cast")), bridge.Limit("message_bytes") + 13);
            }).ConfigureAwait(false);
        } finally { await worker.CloseAsync().ConfigureAwait(false); }
    }
}
