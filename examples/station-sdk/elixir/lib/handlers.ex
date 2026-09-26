defmodule Transit.SdkExamples.Keys do
  alias Transit.Station.Sdk.{Key, TableSchema}
  def total, do: %Key{name: "total", codec: Transit.SdkExamples.U64Codec}
  def request, do: %Key{name: "request", codec: Transit.SdkExamples.U64Codec}
  def observed, do: %Key{name: "observed", codec: Transit.SdkExamples.U64Codec}
  def table, do: %TableSchema{id: 1, cell: :int64}
end

defmodule Transit.SdkExamples.Counter do
  @behaviour Transit.Station.Sdk.Handler
  alias Transit.Station.Sdk.{Turn, State, Incoming}
  alias Transit.SdkExamples.{Add, Read, Total, Keys, ReplyCodec}
  @impl true
  def initialize(turn, context) do
    {:ok, state} = Turn.state(turn)
    {:ok, :ok} = State.put(state, Keys.total(), 0)
    {:ok, context}
  end

  @impl true
  def handle_message(turn, %Incoming{kind: :cast, value: %Add{value: value}}, context) do
    {:ok, state} = Turn.state(turn)
    {:ok, total} = State.require(state, Keys.total())
    {:ok, :ok} = State.put(state, Keys.total(), total + value)
    {:ok, context}
  end

  def handle_message(turn, %Incoming{kind: :call, value: %Read{}}, context) do
    {:ok, state} = Turn.state(turn)
    {:ok, total} = State.require(state, Keys.total())
    {:ok, :ok} = Turn.reply(turn, %Total{value: total}, ReplyCodec)
    {:ok, context}
  end
end

defmodule Transit.SdkExamples.Requester do
  @behaviour Transit.Station.Sdk.Handler
  alias Transit.Station.Sdk.{Turn, State, Incoming}
  alias Transit.SdkExamples.{Start, Read, Total, Keys, CounterCodec}
  @impl true
  def handle_message(turn, %Incoming{kind: :cast, value: %Start{}}, %{peer: peer} = context) do
    {:ok, state} = Turn.state(turn)
    {:ok, :missing} = State.find(state, Keys.request())
    {:ok, correlation} = Turn.call(turn, peer, %Read{}, CounterCodec, :untimed)
    {:ok, :ok} = State.put(state, Keys.request(), correlation)
    {:ok, context}
  end

  def handle_message(
        turn,
        %Incoming{kind: :reply, value: %Total{value: value}} = input,
        %{peer: peer} = context
      ) do
    {:ok, state} = Turn.state(turn)
    {:ok, correlation} = State.require(state, Keys.request())
    {:ok, :ok} = Turn.require_reply(turn, input, peer, correlation)
    {:ok, :ok} = State.put(state, Keys.observed(), value)
    {:ok, context}
  end
end

defmodule Transit.SdkExamples.TableService do
  @behaviour Transit.Station.Sdk.Handler
  alias Transit.Station.Sdk.{Table, Query, QueryPlan, Row, Incoming}
  alias Transit.SdkExamples.{Initialize, Insert, Rows, Keys}
  @impl true
  def initialize(turn, %{peer: peer} = context) do
    {:ok, _table} = Table.create(turn, Keys.table())
    {:ok, :ok} = Query.allow(turn, peer, Keys.table(), 0, true)
    {:ok, context}
  end

  @impl true
  def handle_message(_turn, %Incoming{kind: :cast, value: %Initialize{}}, context),
    do: {:ok, context}

  def handle_message(
        turn,
        %Incoming{kind: :cast, value: %Insert{key: key, value: value}},
        context
      ) do
    {:ok, table} = Table.open(turn, Keys.table())
    {:ok, :ok} = Table.insert(table, %Row{key: key, value: value})
    {:ok, context}
  end

  def handle_message(turn, %Incoming{kind: :call, value: %Rows{}}, context) do
    {:ok, _job} = Query.start(turn, Keys.table(), %QueryPlan{limit: 18_446_744_073_709_551_615})
    {:ok, context}
  end
end

defmodule Transit.SdkExamples.QueryRequester do
  @behaviour Transit.Station.Sdk.Handler
  alias Transit.Station.Sdk.{Turn, State, Incoming, Query, ResultReader, ResultComplete, Manifest}
  alias Transit.SdkExamples.{Start, Rows, Keys, QueryServiceCodec}
  @impl true
  def handle_message(turn, %Incoming{kind: :cast, value: %Start{}}, %{peer: peer} = context) do
    {:ok, state} = Turn.state(turn)
    {:ok, :missing} = State.find(state, Keys.request())
    {:ok, correlation} = Turn.call(turn, peer, %Rows{}, QueryServiceCodec, :untimed)
    {:ok, :ok} = State.put(state, Keys.request(), correlation)
    {:ok, context}
  end

  @impl true
  def handle_result(
        turn,
        %ResultComplete{correlation: correlation},
        %{peer: peer, consume: consume} = context
      ) do
    {:ok, state} = Turn.state(turn)
    {:ok, ^correlation} = State.require(state, Keys.request())
    {:ok, reader} = Query.result(turn, correlation)

    {:ok, %Manifest{source: ^peer, correlation: ^correlation, segments: count, rows: rows}} =
      ResultReader.manifest(reader)

    stream(reader, 0, count, consume)
    {:ok, :ok} = State.put(state, Keys.observed(), rows)
    {:ok, context}
  end

  defp stream(_, count, count, _), do: :ok

  defp stream(reader, ordinal, count, consume) do
    {:ok, segment} = ResultReader.segment(reader, ordinal)
    :ok = consume.(segment)
    stream(reader, ordinal + 1, count, consume)
  end
end
