defmodule Transit.SdkExamples.Keys do
  alias Transit.Station.Sdk.Key
  alias Transit.Station.Sdk.Catalog.{Schema, Column, TableLimits}
  alias Transit.Station.Sdk.Logical.Element
  def total, do: %Key{name: "total", codec: Transit.SdkExamples.U64Codec}
  def request, do: %Key{name: "request", codec: Transit.SdkExamples.U64Codec}
  def observed, do: %Key{name: "observed", codec: Transit.SdkExamples.U64Codec}
  def not_ready, do: %Key{name: "not-ready", codec: Transit.SdkExamples.U64Codec}
  def signed(value), do: {:value, {:atom, {:signed, value}}}

  def limits,
    do: %TableLimits{record_bytes: 65536, staging_bytes: 8_388_608, staging_records: 1024}

  def table,
    do: %Schema{
      object: 1,
      revision: 1,
      next_column: 5,
      primary_key: [1],
      columns: [
        %Column{id: 1, name: "id", type: :int64, nullable: false},
        %Column{id: 2, name: "value", type: :int64},
        %Column{
          id: 3,
          name: "label",
          type: :utf8,
          nullable: false,
          default: {:value, {:atom, {:utf8, "example"}}}
        },
        %Column{
          id: 4,
          name: "tags",
          type: {:list, %Element{type: :int64}},
          nullable: false,
          default: {:value, {:list, [signed(1), signed(2)]}}
        }
      ]
    }
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
  alias Transit.Station.Sdk.{Table, TableMutation, Query, Turn, State, Incoming}
  alias Transit.Station.Sdk.Catalog.Assignment
  alias Transit.Station.Sdk.UnifiedQuery.Plan

  alias Transit.SdkExamples.{
    Initialize,
    Insert,
    Update,
    Delete,
    Advance,
    NotReady,
    Rows,
    Keys,
    TableWork,
    QueryServiceCodec,
    QueryRequesterCodec
  }

  @initial 18_446_744_073_709_551_615
  @impl true
  def handle_message(
        turn,
        %Incoming{kind: :cast, value: %Advance{}, origin: {:process, %{process: process}}},
        context
      ) do
    {:ok, ^process} = Turn.process(turn)
    drive(turn, context)
    {:ok, context}
  end

  def handle_message(turn, %Incoming{kind: :cast, value: command, position: id}, context) do
    true =
      match?(%Initialize{}, command) or match?(%Insert{}, command) or match?(%Update{}, command) or
        match?(%Delete{}, command)

    enqueue(turn, id, command)
    {:ok, context}
  end

  def handle_message(turn, %Incoming{kind: :call, value: %Rows{}}, context) do
    {:ok, state} = Turn.state(turn)

    case queue(state) do
      {0, 0, true} ->
        {:ok, _} = Query.start(turn, 1, %Plan{projection: [0, 1, 2, 3], limit: @initial})

      _ ->
        {:ok, :ok} = Turn.reply(turn, %NotReady{}, QueryRequesterCodec)
    end

    {:ok, context}
  end

  defp queue(state) do
    case State.find(state, TableWork.metadata()) do
      {:ok, :missing} -> {0, 0, false}
      {:ok, {:found, queue}} -> queue
    end
  end

  defp wake(turn) do
    {:ok, process} = Turn.process(turn)
    {:ok, :ok} = Turn.cast(turn, process, %Advance{}, QueryServiceCodec)
  end

  defp enqueue(turn, id, command) do
    true = is_integer(id) and id > 0 and id <= 9_007_199_254_740_991
    {:ok, state} = Turn.state(turn)
    {head, tail, ready} = queue(state)
    {:ok, :missing} = State.find(state, TableWork.work_key(id))
    {:ok, :missing} = State.find(state, TableWork.outcome_key(id))

    new_head =
      cond do
        tail != 0 ->
          true = id > tail
          {:ok, {0, previous}} = State.require(state, TableWork.work_key(tail))
          {:ok, :ok} = State.put(state, TableWork.work_key(tail), {id, previous})
          head

        not ready and not match?(%Initialize{}, command) ->
          {:ok, :ok} = State.put(state, TableWork.work_key(@initial), {id, %Initialize{}})
          @initial

        true ->
          id
      end

    {:ok, :ok} = State.put(state, TableWork.work_key(id), {0, command})
    {:ok, :ok} = State.put(state, TableWork.metadata(), {new_head, id, ready})
    if head == 0, do: wake(turn)
  end

  defp drive(turn, %{peer: peer}) do
    {:ok, state} = Turn.state(turn)

    case queue(state) do
      {0, 0, _} ->
        :ok

      {head, tail, ready} ->
        {:ok, {next, command}} = State.require(state, TableWork.work_key(head))
        true = next == 0 == (head == tail)
        true = next == 0 or head == @initial or next > head
        outcome = step(turn, head, ready, command)
        initialize = match?(%Initialize{}, command)
        {:ok, %{mutations: remaining}} = Turn.budgets(turn)
        required = if initialize and not ready, do: 4, else: 3

        if outcome == :building or remaining < required do
          wake(turn)
        else
          if initialize and not ready, do: {:ok, :ok} = Query.allow(turn, peer, 1, 0, true)
          {:ok, :ok} = State.put(state, TableWork.outcome_key(head), outcome)
          {:ok, :ok} = State.delete(state, TableWork.work_key(head))

          {:ok, :ok} =
            State.put(
              state,
              TableWork.metadata(),
              {next, if(next == 0, do: 0, else: tail), ready or initialize}
            )

          if next != 0, do: wake(turn)
        end
    end
  end

  defp step(turn, _, _, %Initialize{}) do
    {:ok, status} = Table.create(turn, Keys.table(), Keys.limits())

    if status.state == :building,
      do: :building,
      else: {0, status.admitted_input, status.completed_input, 0, 0, 0}
  end

  defp step(turn, id, true, command) when id != @initial do
    {:ok, resource} = Turn.resource(turn)
    {:ok, operation} = TableMutation.prepare(resource, 0, id, Keys.table(), mutation(command))
    {:ok, status} = TableMutation.step(operation, turn)

    if status.state == :building do
      :building
    else
      state =
        case status.state do
          :applied -> 1
          :rejected -> 2
          :cancelled -> 3
        end

      {matched, changed} =
        if status.counts, do: {status.counts.matched, status.counts.changed}, else: {0, 0}

      {state, status.admitted_input, status.completed_input, matched, changed,
       rejection(status.rejection)}
    end
  end

  defp mutation(%Insert{key: key, value: value}),
    do: {:insert, [[assignment(1, Keys.signed(key)), assignment(2, cell(value))]]}

  defp mutation(%Update{key: key, value: value}),
    do: {:update, [assignment(2, cell(value))], [{:compare, 1, :eq, {:signed, key}}]}

  defp mutation(%Delete{key: key}), do: {:delete, [{:compare, 1, :eq, {:signed, key}}]}
  defp assignment(column, value), do: %Assignment{column: column, value: value}
  defp cell(nil), do: :null
  defp cell(value), do: Keys.signed(value)

  defp rejection(reason),
    do:
      Map.fetch!(
        %{
          none: 0,
          row_exists: 1,
          row_identity_exists: 2,
          null_not_allowed: 3,
          missing_required_field: 4,
          character_limit_exceeded: 5,
          overflow: 6,
          inexact: 7
        },
        reason
      )
end

defmodule Transit.SdkExamples.QueryRequester do
  @behaviour Transit.Station.Sdk.Handler
  alias Transit.Station.Sdk.{Turn, State, Incoming, Query, ResultReader, ResultComplete, Manifest}
  alias Transit.SdkExamples.{Start, Rows, NotReady, Keys, QueryServiceCodec}
  @impl true
  def handle_message(
        turn,
        %Incoming{kind: :reply, value: %NotReady{}, correlation: correlation} = input,
        %{peer: peer} = context
      ) do
    {:ok, state} = Turn.state(turn)
    {:ok, ^correlation} = State.require(state, Keys.request())
    {:ok, :ok} = Turn.require_reply(turn, input, peer, correlation)
    {:ok, :ok} = State.put(state, Keys.not_ready(), correlation)
    {:ok, context}
  end

  def handle_message(turn, %Incoming{kind: :cast, value: %Start{}}, %{peer: peer} = context) do
    {:ok, state} = Turn.state(turn)
    {:ok, previous} = State.find(state, Keys.request())
    {:ok, not_ready} = State.find(state, Keys.not_ready())
    true = previous == :missing or previous == not_ready
    {:ok, correlation} = Turn.call(turn, peer, %Rows{}, QueryServiceCodec, :untimed)
    {:ok, :ok} = State.put(state, Keys.request(), correlation)
    if not_ready != :missing, do: {:ok, :ok} = State.delete(state, Keys.not_ready())
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
