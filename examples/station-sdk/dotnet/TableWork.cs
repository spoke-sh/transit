using System.Buffers.Binary;
using Transit.Station.Sdk;

namespace Transit.Sdk.Examples;

/// <summary>Application FIFO records; native Table state remains behind the SDK.</summary>
public static class TableWork
{
    public const ulong MaxInput = (1UL << 53) - 1;
    public const ulong Initial = ulong.MaxValue;
    public sealed record Queue(ulong Head = 0, ulong Tail = 0, bool Ready = false);
    public sealed record Work(ulong Next, IQueryMessage Command);
    public sealed record Outcome(byte State, ulong Admitted, ulong Completed, ulong Matched = 0, ulong Changed = 0, byte Rejection = 0);
    private static byte[] Record(byte tag, int length) { byte[] bytes = new byte[length]; bytes[0] = 84; bytes[1] = 81; bytes[2] = tag; bytes[3] = 1; return bytes; }
    private static void Prefix(byte[] bytes, byte tag, params int[] lengths) {
        if (bytes is null || !lengths.Contains(bytes.Length) || bytes[0] != 84 || bytes[1] != 81 || bytes[2] != tag || bytes[3] != 1) throw new ArgumentException("Invalid Table application record");
    }
    private static void Put(byte[] bytes, int offset, ulong value) => BinaryPrimitives.WriteUInt64LittleEndian(bytes.AsSpan(offset), value);
    private static ulong Get(byte[] bytes, int offset) => BinaryPrimitives.ReadUInt64LittleEndian(bytes.AsSpan(offset));
    private sealed class QueueRecordCodec : ICodec<Queue> {
        public string TypeId => "transit.examples.table.queue";
        public uint Version => 1;
        public int MaxEncodedBytes => 21;
        public byte[] Encode(Queue value) {
            if (value.Tail > MaxInput || (value.Head == 0) != (value.Tail == 0) || (value.Head != Initial && value.Head > value.Tail) || (value.Head == Initial && value.Ready)) throw new ArgumentException("Invalid Table queue");
            byte[] bytes = Record(77, 21); Put(bytes, 4, value.Head); Put(bytes, 12, value.Tail); bytes[20] = value.Ready ? (byte)1 : (byte)0; return bytes;
        }
        public Queue Decode(byte[] bytes) {
            Prefix(bytes, 77, 21); if (bytes[20] > 1) throw new ArgumentException("Invalid Table queue flag");
            Queue value = new(Get(bytes, 4), Get(bytes, 12), bytes[20] == 1); _ = Encode(value); return value;
        }
    }
    private static readonly ICodec<IQueryMessage> CommandCodec = new Codecs.QueryCodec(typeof(Initialize), typeof(Insert), typeof(Update), typeof(Delete));
    private sealed class WorkRecordCodec : ICodec<Work> {
        public string TypeId => "transit.examples.table.work";
        public uint Version => 1;
        public int MaxEncodedBytes => 34;
        public byte[] Encode(Work value) {
            if (value.Next > MaxInput) throw new ArgumentException("Invalid Table queue link");
            byte[] command = CommandCodec.Encode(value.Command), bytes = Record(87, 12 + command.Length);
            Put(bytes, 4, value.Next); command.CopyTo(bytes, 12); return bytes;
        }
        public Work Decode(byte[] bytes) {
            Prefix(bytes, 87, 17, 25, 26, 34); Work value = new(Get(bytes, 4), CommandCodec.Decode(bytes[12..])); _ = Encode(value); return value;
        }
    }
    private sealed class OutcomeRecordCodec : ICodec<Outcome> {
        public string TypeId => "transit.examples.table.outcome";
        public uint Version => 1;
        public int MaxEncodedBytes => 38;
        public byte[] Encode(Outcome value) {
            if (value.State > 3 || value.Admitted == 0 || value.Completed < value.Admitted || value.Completed > MaxInput || value.Changed > value.Matched || value.Rejection > 7 ||
                (value.State != 1 && (value.Matched != 0 || value.Changed != 0)) || (value.State == 2) != (value.Rejection != 0)) throw new ArgumentException("Invalid Table outcome");
            byte[] bytes = Record(79, 38); bytes[4] = value.State;
            Put(bytes, 5, value.Admitted); Put(bytes, 13, value.Completed); Put(bytes, 21, value.Matched); Put(bytes, 29, value.Changed); bytes[37] = value.Rejection; return bytes;
        }
        public Outcome Decode(byte[] bytes) {
            Prefix(bytes, 79, 38); Outcome value = new(bytes[4], Get(bytes, 5), Get(bytes, 13), Get(bytes, 21), Get(bytes, 29), bytes[37]); _ = Encode(value); return value;
        }
    }
    public static ICodec<Queue> QueueCodec { get; } = new QueueRecordCodec();
    public static ICodec<Work> WorkCodec { get; } = new WorkRecordCodec();
    public static ICodec<Outcome> OutcomeCodec { get; } = new OutcomeRecordCodec();
    public static Key<Queue> Metadata { get; } = new("table.queue", QueueCodec);
    private static Key<T> Key<T>(string prefix, ulong identity, ICodec<T> codec) where T : notnull {
        if (identity == 0) throw new ArgumentException("Invalid Table input identity");
        return new(prefix + identity.ToString("x16", System.Globalization.CultureInfo.InvariantCulture), codec);
    }
    public static Key<Work> WorkKey(ulong identity) => Key("table.work.", identity, WorkCodec);
    public static Key<Outcome> OutcomeKey(ulong identity) => Key("table.done.", identity, OutcomeCodec);
}
