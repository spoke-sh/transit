using System.Buffers.Binary;
using Transit.Station.Sdk;

namespace Transit.Sdk.Examples;

public static class Codecs
{
    private static byte[] Output(byte family, int length, byte tag)
    {
        byte[] bytes = new byte[length]; bytes[0] = 84; bytes[1] = 83; bytes[2] = family; bytes[3] = 1;
        if (tag != 0) bytes[4] = tag;
        return bytes;
    }
    private static void Input(byte[] bytes, byte family, int minimum, int maximum)
    {
        if (bytes is null || bytes.Length < minimum || bytes.Length > maximum || bytes[0] != 84 || bytes[1] != 83 || bytes[2] != family || bytes[3] != 1)
            throw new ArgumentException("Unsupported application format");
    }
    private sealed class U64Codec : ICodec<ulong>
    {
        public string TypeId => "transit.examples.u64";
        public uint Version => 1;
        public int MaxEncodedBytes => 12;
        public byte[] Encode(ulong value) { byte[] bytes = Output(85, 12, 0); BinaryPrimitives.WriteUInt64LittleEndian(bytes.AsSpan(4), value); return bytes; }
        public ulong Decode(byte[] bytes) { Input(bytes, 85, 12, 12); return BinaryPrimitives.ReadUInt64LittleEndian(bytes.AsSpan(4)); }
    }
    public sealed class CounterCodec : ICodec<ICounterMessage>
    {
        private readonly HashSet<Type> allowed;
        public CounterCodec(params Type[] allowed) { this.allowed = allowed.ToHashSet(); }
        public string TypeId => "transit.examples.counter";
        public uint Version => 1;
        public int MaxEncodedBytes => 13;
        private void Role(ICounterMessage value) { if (!allowed.Contains(value.GetType())) throw new ArgumentException("Unsupported counter role"); }
        public byte[] Encode(ICounterMessage value)
        {
            Role(value);
            byte[] bytes = value switch {
                Add => Output(67, 13, 1), Read => Output(67, 5, 2), Start => Output(67, 5, 3), Total => Output(67, 13, 4),
                _ => throw new ArgumentException("Unknown counter message")
            };
            if (value is Add add) BinaryPrimitives.WriteUInt64LittleEndian(bytes.AsSpan(5), add.Value);
            if (value is Total total) BinaryPrimitives.WriteUInt64LittleEndian(bytes.AsSpan(5), total.Value);
            return bytes;
        }
        public ICounterMessage Decode(byte[] bytes)
        {
            Input(bytes, 67, 5, 13);
            ICounterMessage value = (bytes[4], bytes.Length) switch {
                (1, 13) => new Add(BinaryPrimitives.ReadUInt64LittleEndian(bytes.AsSpan(5))),
                (2, 5) => new Read(), (3, 5) => new Start(),
                (4, 13) => new Total(BinaryPrimitives.ReadUInt64LittleEndian(bytes.AsSpan(5))),
                _ => throw new ArgumentException("Malformed counter message")
            };
            Role(value); return value;
        }
    }
    public sealed class QueryCodec : ICodec<IQueryMessage>
    {
        private readonly HashSet<Type> allowed;
        public QueryCodec(params Type[] allowed) { this.allowed = allowed.ToHashSet(); }
        public string TypeId => "transit.examples.query";
        public uint Version => 1;
        public int MaxEncodedBytes => 22;
        private void Role(IQueryMessage value) { if (!allowed.Contains(value.GetType())) throw new ArgumentException("Unsupported query role"); }
        public byte[] Encode(IQueryMessage value)
        {
            Role(value);
            byte[] bytes = value switch {
                Initialize => Output(81, 5, 1), Insert insert => Output(81, insert.Value is null ? 14 : 22, 2),
                Rows => Output(81, 5, 3), Start => Output(81, 5, 4), _ => throw new ArgumentException("Unknown query message")
            };
            if (value is Insert row) {
                BinaryPrimitives.WriteInt64LittleEndian(bytes.AsSpan(5), row.Key); bytes[13] = row.Value is null ? (byte)0 : (byte)1;
                if (row.Value is { } cell) BinaryPrimitives.WriteInt64LittleEndian(bytes.AsSpan(14), cell);
            }
            return bytes;
        }
        public IQueryMessage Decode(byte[] bytes)
        {
            Input(bytes, 81, 5, 22);
            IQueryMessage value = (bytes[4], bytes.Length) switch {
                (1, 5) => new Initialize(), (3, 5) => new Rows(), (4, 5) => new Start(),
                (2, 14) when bytes[13] == 0 => new Insert(BinaryPrimitives.ReadInt64LittleEndian(bytes.AsSpan(5)), null),
                (2, 22) when bytes[13] == 1 => new Insert(BinaryPrimitives.ReadInt64LittleEndian(bytes.AsSpan(5)), BinaryPrimitives.ReadInt64LittleEndian(bytes.AsSpan(14))),
                _ => throw new ArgumentException("Malformed query message")
            };
            Role(value); return value;
        }
    }
    public static ICodec<ulong> U64 { get; } = new U64Codec();
    public static ICodec<ICounterMessage> Counter { get; } = new CounterCodec(typeof(Add), typeof(Read));
    public static ICodec<ICounterMessage> Requester { get; } = new CounterCodec(typeof(Start), typeof(Total));
    public static ICodec<ICounterMessage> Reply { get; } = new CounterCodec(typeof(Total));
    public static ICodec<IQueryMessage> QueryService { get; } = new QueryCodec(typeof(Initialize), typeof(Insert), typeof(Rows));
    public static ICodec<IQueryMessage> QueryRequester { get; } = new QueryCodec(typeof(Start));
}
